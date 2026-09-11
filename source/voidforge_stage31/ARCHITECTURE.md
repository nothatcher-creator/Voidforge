# VOIDFORGE Architecture

## Stage 31 handheld-tool/mining interaction layer

Handheld tools remain inventory-backed content rather than player abilities. `ItemDefinition` now optionally describes a `tool_type`, operating range, and work rate. `HandDrillController` lives on the player but resolves the currently selected hotbar item through ItemDB before it can act. This keeps equipment authority in Inventory/Hotbar while allowing tools to share one future controller family.

Mineable targets advertise capability through `can_receive_drill_work()` / `apply_drill_work()` rather than requiring a specific asteroid class. The drill performs one camera-centered physics ray against the dedicated Mineable layer and accumulates deterministic fixed-interval work while `tool_use` is held. Stage 31's calibration stone stores work only; Stage 32 can implement ore depletion behind the same interface and Stages 33–34 can replace it with deformable chunk/voxel material without changing the player's input contract.

Mobile and desktop remain single-path: left mouse and Android TOOL both drive `tool_use`. The mobile TOOL region is excluded from free-look touch ownership and is included in global touch-action clearing for modal/context transitions.

## Runtime roots and registries

`Main` owns stable `WorldRoot`, `Systems`, and `UI` roots. The active Stage 30 wrapper retains the complete Stage 2–29 playable slice and seeds a configured terminal craft used to validate authoritative per-instance block settings.

Global autoload registries remain `GameConfig`, `DebugLog`, `ItemDB`, `GridDB`, and `BlockDB`.

## Authoritative construction + physics state

`BlockGrid` is both the sparse construction source of truth and the single physics carrier:

- base type: `RigidBody3D`;
- `_instances`: instance ID → `BlockInstanceData`;
- `_cells`: occupied `Vector3i` → owning logical block;
- `_calculated_mass_kg`: authoritative block-mass total;
- orientation: compact 0–23 index;
- JSON-friendly grid persistence is schema version 3, with schema-v1/v2 migration support;
- rendering/collision caches are derived and never serialized.

Every grid starts frozen. Small/Large profiles may be released into dynamic simulation; Static Grid profiles cannot.

## Stage 16 batched rendering

`BlockGridPresenter` builds local `MultiMeshInstance3D` batches grouped by material + primitive type. Render transforms remain local to the `BlockGrid`, so a complete craft follows rigid-body motion without rebuilding its geometry every physics frame.

## Stage 17 cached collision

Collision shape owners live directly on the parent `BlockGrid : RigidBody3D`.

For each logical block the presenter resolves a cached `Shape3D`, creates one shape owner, applies the block-local transform/orientation, and maps the owner back to the stable block instance ID. A ray therefore hits the grid body while Godot's returned shape index can still resolve the exact logical block.

## Stage 18 dynamic simulation

Key motion APIs remain:

- `can_be_dynamic()`;
- `is_dynamic_simulation_enabled()`;
- `set_dynamic_simulation_enabled(enabled, wake_body)`;
- `get_motion_state()`;
- `stop_motion()`;
- `sleep_grid()`;
- `wake_grid()`.

Dynamic mode applies configured gravity/damping, sleeping, and world collision. Frozen mode disables gravity/world response and clears velocity while preserving transform.

The Stage 18 provisional mass override has been removed.

## Stage 19 authoritative mass

Each successful logical block placement contributes exactly one canonical BlockDB `mass_kg` value regardless of how many grid cells that block occupies. Removal subtracts the same logical-block mass.

Primary APIs:

- `get_total_mass_kg()`;
- `get_physics_mass_kg()`;
- `get_mass_state()`;
- `get_mass_breakdown_by_block_id()`;
- `recalculate_mass_from_blocks()`;
- `mass_changed(total_mass_kg, physics_mass_kg)`.

### Why mass is not serialized separately

Grid schema v3 still persists stable block IDs. Mass is derived data, so trusting an additional saved mass field would create corruption/desynchronization risk. During load, all block entries are validated, a new total is calculated from BlockDB into temporary state, and only then are construction state and calculated mass committed together.

### Canonical lookup

Registered block IDs always use the current canonical BlockDB definition for mass. A transient Resource cannot spoof a production block's mass simply by reusing its ID. Temporary unregistered blocks remain supported only for isolated legacy regression fixtures and are not accepted by persistent grid loading.

### Empty-grid safety floor

An empty grid has `get_total_mass_kg() == 0.0`. Godot's `RigidBody3D.mass` must stay positive, so the engine property uses `MIN_RIGID_BODY_MASS_KG = 0.001` until a logical block gives the craft real mass. All occupied production grids use their exact calculated total.

### Integrity

The grid integrity audit recalculates expected mass from every live logical block and checks both the cached total and the actual Godot physics mass. `recalculate_mass_from_blocks()` can repair physics-property drift without changing construction state.

## Moving-grid construction

Construction remains transform-local. `BlockPlacementController` uses physics hit position/normal plus the current grid transform to calculate attachment cells/faces. Adding/removing blocks on a dynamic grid updates mass on the same rigid body; no physics-body replacement occurs.

## Persistence boundary

Grid save schema version 3 stores construction state, battery storage, per-instance configuration, and groups. Versions 1 and 2 remain supported through migration. Dynamic world transform/velocity are not yet part of this payload; full world saves will own that later. Loading a grid returns it to frozen construction state.

## Current mass boundary

Stage 19 is intentionally scalar mass only. Later systems will add cargo/inventory mass, fuel mass, center-of-mass weighting, inertia tuning, structural splitting, and mass transfer between detached/docked grids. Godot's current automatic center-of-mass/inertia behavior is the temporary physical approximation.

## Mobile physics budget

`GameConfig.MAX_ACTIVE_RIGID_BODIES` remains the early global safety budget. One rigid body per grid plus derived batched geometry/collision and cached mass state is the foundation for later sleeping/dormant simulation budgets on Android.

## Stage 20 manual-control / seat architecture

Manual vehicle control is grid-owned runtime state. `BlockGrid` stores only the active pilot reference and the stable instance ID of the occupied control-seat block. Authority is valid only while that instance still resolves through BlockDB with `functional_type == &"control_seat"`.

The central checks are `can_claim_manual_control(actor, seat_instance_id)`, `try_claim_manual_control(...)`, `can_receive_manual_control(actor)`, and `release_manual_control(actor)`. Future propulsion, gyroscope, wheel, weapon, and automation command layers can therefore verify one common authority contract rather than each inventing seat logic.

`ControlSeatPresenter` derives functional interaction nodes from grid construction state. Structural blocks stay inside the sparse grid + batched renderer, while each real control-seat block receives one small `Area3D` proxy. `ControlSeatInteraction` is on the Interactable layer and delegates pilot claims to the grid.

`FirstPersonPlayer` has two runtime modes: `on_foot` and `vehicle`. Entering a seat suspends on-foot movement, interaction, and construction processing; the player's transform follows the seat proxy, while CameraPivot keeps a local seated free-look yaw/pitch. Exiting restores the on-foot systems and inherits the current grid linear velocity.

Pilot runtime state is intentionally excluded from grid persistence schema v3. Loading, clearing, or removing the occupied seat invalidates/ejects the pilot before construction state changes. This avoids serializing live Node references and leaves world/session persistence free to decide how pilots are restored later.

Stage 20 established the authority contract now used by propulsion and future rotational systems.

## Stage 21 propulsion architecture

Propulsion is derived from physical block instances, not a ship-class statistic. `BlockDefinition` exposes `thrust_force_n` and a cardinal `thrust_direction_local`. For a live block, `BlockGrid.get_thruster_local_force_n()` rotates that local axis through the block's 24-state orientation Basis and multiplies it by rated force.

`BlockGrid` maintains a mutation-driven propulsion cache containing stable thruster instance IDs, total rated thrust, and the combined grid-local force vector. The cache becomes dirty after construction mutations, persistence load, or BlockDB reload and is rebuilt on demand. This avoids an O(total blocks) scan every physics tick on large Android craft.

Manual thrust is authority-gated by the Stage 20 Pilot Cradle contract. `FirstPersonPlayer` only forwards `vehicle_thrust_forward` while seated. `set_manual_thrust_input(actor, strength)` rejects non-pilots. The grid transforms the cached local force into world space and applies it centrally to the same `RigidBody3D` carrying construction collision and authoritative Stage 19 mass.

Stage 21 introduced the physical thruster and its compatibility forward-throttle API. Stage 22 now supersedes the shared-set behavior with direction-selective translation while retaining Stage 21 APIs for regression compatibility. Off-center torque, resource consumption, per-block enable/disable, power/fuel availability, and damage-dependent thrust remain later layers.


## Stage 22 directional thrust architecture

Stage 22 classifies each cached thruster by the grid-local cardinal direction of its **actual oriented force vector**. The same Pulse Thruster definition can therefore belong to any of six translation groups depending solely on how the player mounted it.

`BlockGrid` keeps two additional mutation-driven caches: direction → total rated thrust and direction → stable thruster instance IDs. Public queries expose `get_directional_rated_thrust_n()`, `get_thruster_instance_ids_for_direction()`, and `get_directional_thrust_state()`. Balanced opposed engines may have a zero combined vector while still exposing full directional authority in both directions.

Manual translation uses `set_manual_translation_input(actor, Vector3)`. Components represent grid-local right/up/back axes and are independently clamped to ±1. `get_active_manual_force_local_n()` selects only the appropriate positive or negative axis group for each component and sums those groups. The result is transformed to world space once and applied centrally to the authoritative grid rigid body.

`FirstPersonPlayer` reads six InputMap actions while seated: forward/backward/left/right/up/down. On touch, `VirtualJoystick.set_action_bindings()` allows the same left joystick to publish on-foot movement actions normally and vehicle translation actions while seated. Dedicated UP/DN touch buttons provide vertical thrust. This contextual rebinding keeps gameplay logic InputMap-driven and avoids a separate mobile-only propulsion implementation.

Stage 22 deliberately remains translation-only. Stage 23 adds installed-gyroscope rotational torque; Stage 24 builds the dedicated dual-stick Android vehicle interface around both translation and rotation.

## Stage 23 gyroscope and rotational-control architecture

Rotational control is derived from installed functional blocks rather than a grid class or craft blueprint. `BlockDefinition` now exposes `gyro_torque_nm`; only definitions with `functional_type == &"gyroscope"` may declare positive gyro torque, and every gyroscope must declare a positive rating.

`BlockGrid` keeps a mutation-driven gyroscope cache containing stable gyroscope instance IDs and total rated torque. `get_gyroscope_instance_ids()`, `get_gyroscope_count()`, `get_total_gyro_torque_nm()`, and `get_rotation_control_state()` expose the derived state. Placement, removal, clear, persistence load, and BlockDB reload mark the cache dirty; ordinary physics frames do not scan all logical blocks.

Manual rotation uses `set_manual_rotation_input(actor, Vector3)`. The vector convention is grid-local:

- X: pitch (`+` up, `-` down);
- Y: yaw (`+` left, `-` right);
- Z: roll (`+` right, `-` left).

Each component is independently clamped to ±1. `get_active_manual_torque_local_nm()` multiplies that command by total installed gyroscope torque. During the physics tick, the grid transforms the local torque through its current Basis and calls `apply_torque()` on the same authoritative `RigidBody3D` used by construction collision and Stage 22 propulsion.

This deliberately avoids writing angular velocity directly. The engine resolves angular acceleration from torque and the rigid body's current inertia approximation, so installed torque and physical craft properties determine response. Multiple gyroscopes add their ratings; zero installed gyroscopes means zero manual torque.

`FirstPersonPlayer` forwards the six rotational InputMap actions only while it owns valid Pilot Cradle authority. Leaving/losing the seat clears rotation input immediately. The actions are already platform-independent; Stage 24 can map a right touch joystick/roll controls onto them without creating a second mobile rotational-physics implementation.

Stage 23 does not yet provide attitude hold, target angular velocity, artificial horizon stabilization, damage-dependent gyro output, or custom block-weighted center-of-mass/inertia. Gyro power draw was added in Stage 25. Those are layered later without changing the installed-machinery authority model.

## Stage 24 — Android dual-stick ship controls

Stage 24 remains InputMap-first. `MobileTouchControls` does not call propulsion or gyroscope methods directly. It changes which shared actions its controls press according to the player's current control mode.

On foot, `MoveJoystick` maps to `move_left/right/forward/backward` and the right-side `LookArea` remains the camera surface. In vehicle mode, `MoveJoystick` maps to the four horizontal `vehicle_thrust_*` actions and the new `RotationJoystick` maps horizontal input to yaw and vertical input to pitch. `RollLeftButton`/`RollRightButton`, UP/DN, THR, and EXIT are ordinary touch-to-InputMap buttons.

The right rotation stick uses a fixed origin rather than the on-foot stick's dynamic origin. That produces a predictable attitude-control center on mobile. Its `dead_zone = 0.18` is remapped by the shared joystick implementation so analog output begins smoothly outside neutral rather than jumping from zero.

Touch ownership stays distributed. Each joystick tracks one touch index independently, action buttons track their own touch, and `TouchLookArea` rejects touches whose positions fall inside any visible excluded control. This supports simultaneous translation, pitch/yaw, and roll without global gesture arbitration or a single monolithic touch state machine.

The player remains the bridge from InputMap state to grid commands. While seated it samples translation and rotation actions each physics tick, then calls the Pilot-Cradle-authorized `set_manual_translation_input()` and `set_manual_rotation_input()` APIs. `BlockGrid` continues to derive force/torque from physically installed thrusters and gyroscopes.

`TouchActionButton` also accepts release from its currently owned touch before testing visibility. This is required for contextual controls such as EXIT: the press can cause the HUD to hide the button immediately, but the eventual finger-up must still clear the simulated InputMap action.

Stage 24 deliberately does not add a second mobile flight simulation, direct angular-velocity steering, or arbitrary ship stats. Future control customization can change layout/sensitivity/dead zones without changing the underlying propulsion/gyro authority model.

## Stage 25 — Electrical power network

Electrical power is currently modeled as one logical bus per `BlockGrid`. This is intentionally cheaper than simulating wires or individual electrons and matches the mobile-first architecture. BlockDB remains authoritative for `power_use_kw` and `power_production_kw`; `BlockGrid` caches producer/consumer instance IDs plus installed generation/rated demand after structural mutations.

Active demand is evaluated from current functional use: occupied Pilot Cradles consume their control load, thrusters scale demand by the command component aligned with their mounted direction, and gyroscopes scale demand by the strongest active rotational axis. The grid computes one satisfaction ratio `min(generation / active_demand, 1)` and applies it uniformly to commanded thruster force and gyro torque. This gives deterministic proportional brownout behavior with no extra physics bodies or per-frame block scans.

`get_power_network_state()` and `get_block_power_state()` expose diagnostics for later terminal UI. Power cache state is derived from stable block IDs and is rebuilt after persistence load rather than serialized redundantly.

`power_network_enabled` defaults true. Only historical Stage 21–24 smoke fixtures disable it to preserve their original isolated test contracts. The temporary `dev_power_source_large` remains development-only; Stage 26 adds real rechargeable storage and Stage 27 will add the first production generator/reactor.


## Stage 26 — Rechargeable battery storage

Battery definition metadata remains data-driven in BlockDB: `battery_capacity_kwh`, `battery_initial_charge_fraction`, `battery_max_charge_kw`, and `battery_max_discharge_kw`. The production `flux_reservoir_large` defines 60 kWh capacity, 50% initial charge, a 180 kW charge ceiling, and a 240 kW discharge ceiling. Battery blocks must use `functional_type == &"battery"` and may not simultaneously declare fixed power production/consumption.

`BlockGrid` stores mutable battery energy in `_battery_stored_energy_kwh`, keyed by the same stable logical block instance IDs used throughout construction/persistence. Aggregate battery IDs/capacity/rates are mutation-cached, so ordinary physics frames do not scan every grid block. Battery storage has no dedicated Node, Area, or physics body.

The physics tick computes active electrical demand and fixed generation, then determines the battery contribution required for that tick. Deficits discharge storage subject to each battery's maximum discharge rate and the energy physically available over `delta`. Surplus fixed generation charges storage subject to maximum charge rate and remaining capacity. Conversion is explicit: `delta_kwh = power_kw * delta_seconds / 3600`. Battery flow therefore remains simulation-time based rather than frame-count based. Frozen/static grids still advance storage, allowing non-moving stations to recharge.

Power-limited force/torque uses the effective satisfaction ratio calculated from fixed generation plus currently available battery discharge. A final partial-energy tick is scaled correctly before stored energy reaches zero. `get_power_network_state()`, `get_battery_storage_state()`, and `get_battery_state(instance_id)` expose aggregate/per-block diagnostics without changing authoritative storage.

Grid persistence advances to schema **version 2**. Top-level `battery_states` entries contain stable `instance_id` plus exact `stored_energy_kwh`. The loader validates the complete construction and battery payload transactionally before commit, including battery identity, finite/ranged energy, duplicates, and capacity. Schema **version 1** remains loadable; migrated battery blocks initialize from the current BlockDB `battery_initial_charge_fraction`. Mass, power-cache membership, and battery capacity/rates remain derived and are not redundantly trusted from saves.

The current battery bus is intentionally simplified for Android: multiple batteries are charged/discharged in deterministic stable-instance order rather than solving voltage/current or equalized SoC. User charge modes, priority/load shedding, fuel generators, disconnected electrical islands, and damaged bus topology remain future layers.

## Stage 27 — Production reactor generation

`Helix Core Reactor L` is the first production fixed electrical generator. It is represented entirely through authoritative BlockDB metadata (`functional_type == &"reactor"`, `power_production_kw = 480.0`, `heat_generation_kw = 145.0`) and therefore plugs into the existing Stage 25 producer cache without a per-reactor runtime Node or special physics carrier.

The grid power cache treats reactor output as fixed generation. Multiple reactors add their ratings, structural mutations/load rebuild the producer cache, and grid persistence stores the stable block ID rather than serializing redundant generation totals. Battery simulation remains layered on top: fixed reactor generation first satisfies active consumer demand, then any surplus may charge installed Flux Reservoirs subject to their charge limits.

The dedicated reactor presenter is still derived/non-authoritative. `BlockGridPresenter` expands one logical reactor block into nine local batched primitives using the `power_generation` material family. Rendering can therefore change later without changing power simulation or save compatibility.

Stage 27 deliberately does not consume reactor fuel. Fuel items, reactor inventories, conveyor delivery, and burn rates are deferred until the dedicated fuel/network layers exist. The `heat_generation_kw` field is already authoritative so a future thermal system can consume it without changing the reactor block definition schema.


## Stage 28 power-priority and load-shedding architecture

`BlockDefinition.power_priority` is a validated integer tier: 0 Critical, 1 High, 2 Normal, 3 Low. Consumer metadata remains authoritative in BlockDB and therefore automatically reconstructs after grid save/load without duplicating priority data into instance persistence.

`BlockGrid._calculate_power_allocation()` first computes active demand and available bus supply from fixed generation plus currently available battery discharge. With priority shedding enabled, active consumers are grouped by cached priority. Each tier receives power in order. A fully affordable tier receives 100%; if the remaining bus cannot satisfy a tier, all active members of that tier receive the same proportional satisfaction ratio and every lower tier receives zero. This is deterministic, avoids per-structural-block work, and gives mobile hardware a predictable approximation rather than electrical-circuit simulation.

Propulsion and gyroscope outputs now query their own block-level satisfaction instead of multiplying the whole craft by one global ratio. Network-wide satisfaction remains `allocated_kw / active_demand_kw` for backward-compatible diagnostics. `get_block_power_state()` exposes priority, allocated kW, and `load_shed` when a lower tier receives no allocation while power exists elsewhere on the bus.

`priority_load_shedding_enabled` defaults true. It can be disabled for proportional allocation; this exists mainly to preserve the Stage 25 regression contract and may later support simplified/custom sandbox rules.

## Stage 29 — Ship terminal UI architecture

`ShipTerminalUI` is a presentation/query layer rather than an alternate ship-state model. It binds to one managed `BlockGrid` and resolves definitions through BlockDB while reading live grid APIs for mass, simulation mode, power allocation, battery storage, and per-instance state. When the player is seated, `open_terminal()` prefers `FirstPersonPlayer.get_controlled_grid()`; otherwise the scene may provide a default development grid.

The terminal owns no authoritative block copies. Its instance list is rebuilt from `BlockGrid.get_all_blocks()` and stable instance IDs, while search filters display name, stable block ID, category, and functional type. Thirteen fixed touch-friendly category tabs provide the management taxonomy that later content can populate without changing the UI contract. Selected-block details are regenerated from the live block instance and canonical BlockDefinition.

Live diagnostics refresh every 0.20 seconds rather than every render frame. Grid, power, and battery summaries therefore remain responsive while avoiding unnecessary UI churn on mobile. Structural mutation can trigger an explicit refresh, and selection is kept stable only while that instance continues to exist.

The terminal is modal. `FirstPersonPlayer.set_ui_input_locked(true)` suppresses on-foot movement/look/construction and clears seated translation/rotation commands. `MobileTouchControls.set_external_ui_blocked(true)` hides the touch HUD and clears simulated InputMap actions. Closing reverses both operations and restores the correct current control context. The shared `ship_terminal` InputMap action is mapped to desktop `T` and the seated Android TERM touch button.

Stage 29 is intentionally read-only. It establishes list/search/category/detail/live-diagnostics and modal-control contracts. Stage 30 can add configuration writes—enable/disable, rename, groups and settings—without replacing the query/UI foundation or duplicating simulation state.
## Stage 30 — Authoritative block configuration

Stage 30 extends the Stage 29 terminal without introducing a second configuration model. `BlockGrid` owns runtime dictionaries keyed by stable logical block instance ID for enabled state, custom name, and optional power-priority override. Named block groups are also grid-owned and store stable instance IDs. `ShipTerminalUI` only calls those APIs and refreshes from the authoritative result.

The configuration primitives are deliberately generic:

- `is_block_enabled()` / `set_block_enabled()`;
- `get_block_custom_name()` / `set_block_custom_name()` / `get_block_effective_display_name()`;
- `get_block_power_priority_override()` / `set_block_power_priority_override()`;
- create/delete group and add/remove membership APIs.

Enabled state participates in simulation caches. Disabled producers/consumers disappear from the active power bus, disabled thrusters/gyros disappear from propulsion/torque caches, and disabled Pilot Cradles cannot hold control authority. A disabled battery retains stored kWh in runtime state but is excluded from active capacity/charge/discharge until re-enabled. Configuration mutation emits `block_configuration_changed`; group mutation emits `block_groups_changed`.

Power priority uses `POWER_PRIORITY_USE_DEFINITION = -1` as the no-override sentinel. The Stage 28 allocator queries each installed consumer's effective per-instance priority, so terminal changes immediately alter shortage allocation without mutating BlockDB definitions.

Persistence advances to schema v3. Every installed block receives one validated `block_configurations` entry, and named groups are serialized separately. Versions 1/2 migrate to enabled=true, blank custom names, canonical definition priorities, and no groups. Incoming v3 configuration is prepared and validated transactionally before live grid state is replaced; bad names, invalid priorities, nonexistent/duplicate group members, or malformed coverage reject the entire load.

Stage 30 still leaves block-family-specific settings for later stages. The generic configuration/persistence/group contract is now stable enough for future thruster overrides, batteries, doors, production machines, toolbar groups, and automation to layer on without replacing the terminal architecture.

