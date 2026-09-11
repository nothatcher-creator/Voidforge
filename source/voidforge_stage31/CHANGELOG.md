# VOIDFORGE Changelog

## 0.0.31-stage31 — Field Bore Drill and held-tool foundation

### Added
- Production `Field Bore Drill` item (`tool_field_bore_drill`) with handheld mining metadata.
- Data-driven ItemDefinition tool type, range, and work-rate fields with validation.
- Reusable `HandDrillController` bound to the existing inventory/hotbar and shared InputMap architecture.
- Dedicated Mineable 3D collision layer and camera-centered 4.5 m drill ray.
- Held 25 work/s drill timing with start/stop/tick/target signals.
- Visible emissive orange drill-beam feedback while drilling.
- Reusable non-deforming `DrillWorkTarget` capability contract and Bore Calibration Stone development target.
- Android **TOOL** button with independent touch ownership and camera-look exclusion.
- Stage 31 integration world and automated hand-drill smoke test.

### Changed
- Production ItemDB count increased from 20 to 21; a new `tool` category is now present.
- Stage 31 development wrapper equips one Field Bore Drill in hotbar slot 5.
- Main development world advanced to Stage 31.
- Android version advanced to code 31 / `0.0.31-stage31`; debug filename is `voidforge-stage31-debug.apk`.

### Verified
- Inventory/hotbar gating, correct range/work metadata, ray hit/miss/range behavior, repeated held work, wrong-tool rejection, release cleanup, visible feedback, and Android TOOL touch routing.
- Historical Stage 7 ItemDB regression updated to preserve its original content checks while accepting the new Stage 31 tool category.

## 0.0.30-stage30 — Functional block configuration UI

### Added
- Per-instance functional block enable/disable state backed by authoritative `BlockGrid`.
- Per-instance custom names with validation and terminal search integration.
- Per-instance electrical priority overrides (`-1` = canonical BlockDB default; Critical/High/Normal/Low otherwise).
- Persistent named block groups using stable logical block instance IDs.
- Touch-sized terminal controls for enable state, naming, priority selection, group creation/membership, and group deletion.
- Stage 30 terminal write APIs for automated UI/runtime testing.
- Grid save schema version 3 with `block_configurations` and `block_groups`.
- Backward migration for version-1/version-2 grids.
- Stage 30 integration wrapper and dedicated configuration smoke test.

### Changed
- Disabled reactors/producers are removed from generation.
- Disabled thrusters and gyros are removed from their cached physical authority.
- Disabled control seats cannot be claimed; disabling an occupied seat forces safe pilot ejection.
- Disabled batteries leave the active electrical bus while retaining stored kWh for re-enable/save-load.
- Power allocation uses per-instance priority overrides when present.
- Control-seat interaction prompts use effective per-instance names.
- Main development world advanced to Stage 30.
- Android version advanced to code 30 / `0.0.30-stage30`; debug filename is `voidforge-stage30-debug.apk`.

### Verified
- Real generation/thrust/torque/control changes from enable state.
- 180 kW shortage allocation changes when the Pulse Thruster is overridden from Normal to Critical.
- Custom names, group membership, battery energy, enabled state, and priority override persistence.
- v1/v2 migration to safe defaults and transactional rejection of malformed v3 configuration.
- Stage 29 read-only terminal behavior remains compatible.
- Complete Stage 3–30 Godot 4.7.2 regression coverage with strict log scanning.

## 0.0.29-stage29 — Ship terminal UI

### Added
- Touch-first, read-only ship terminal overlay backed by live BlockGrid/BlockDB state.
- Thirteen terminal categories: All, Power, Propulsion, Control, Production, Storage, Weapons, Life Support, Automation, Doors, Lighting, Structure, and Armor.
- Search across block display name, stable ID, category, and functional type.
- Per-instance block list and selected-block inspection with stable instance ID, grid cell, orientation, mass, integrity, category/function, construction costs, and electrical state.
- Live grid summary for profile, block count, authoritative mass, and simulation state.
- Live power summary for generation, active demand, available supply, allocated/shed load, and satisfaction.
- Live battery summary for installed storage, state of charge, charging, and discharging.
- Modal player input lock so movement, construction, thrust, and gyro commands cannot continue behind the terminal.
- Android/desktop `ship_terminal` InputMap action (`T` on desktop) and contextual **TERM** touch button while seated.
- External mobile-HUD blocking API used by modal interfaces.
- Stage 29 eight-block mixed-system terminal craft and dedicated automated terminal smoke test.

### Changed
- Main development world advanced to Stage 29.
- Android version advanced to code 29 / `0.0.29-stage29`; debug filename is `voidforge-stage29-debug.apk`.
- Regression runner advanced to Stage 29 and now includes terminal search/filter/detail/live-mutation/input-lock/touch tests.
- Stage 29 remains deliberately read-only; configuration writes are reserved for Stage 30.

### Fixed
- Programmatic terminal search now rebuilds the visible block list immediately instead of relying on `LineEdit.text_changed`.
- Visible terminal block IDs are cleared before rebuilding, preventing stale list state.
- Contextual terminal opening clears mobile control actions and prevents held vehicle inputs from continuing behind the modal UI.

## 0.0.28-stage28 — Power priorities and load shedding

### Added
- Four data-driven consumer priority tiers: Critical, High, Normal, Low.
- `power_priority` metadata and validated priority-name helpers in BlockDefinition.
- Deterministic tier-by-tier grid power allocator using fixed generation plus available battery discharge.
- Per-block allocated-kW and satisfaction queries.
- `load_shed` functional state for lower-priority consumers receiving zero allocation while power exists elsewhere on the bus.
- Network diagnostics for available supply, allocated kW, shed kW, active load shedding, and ordered priority-tier state.
- Development-only 60 kW `Development Auxiliary Load L` for Low-priority regression coverage.
- Stage 28 priority integration craft and dedicated real-physics smoke test.

### Changed
- Pilot Cradle L is Critical priority.
- Vector Gyro L is High priority.
- Pulse Thruster L is Normal priority.
- Thruster force and gyro torque now use their own block allocations rather than one grid-wide brownout multiplier.
- Equal-priority consumers proportionally share a constrained tier before lower tiers receive power.
- Stage 25 proportional brownout remains available through an explicit compatibility toggle used by its historical regression fixture.
- BlockDB increased from 23 to 24 definitions; production buildable count remains 20.
- Main development world advanced to Stage 28.
- Android version advanced to code 28 / `0.0.28-stage28`; debug filename is `voidforge-stage28-debug.apk`.

### Verified
- Exact 6/90/84/0 kW allocation across Critical/High/Normal/Low tiers under a 180 kW supply and 276 kW demand.
- 70% Normal thruster output (33.6 kN), full 120 kN·m High gyro torque, and complete Low-tier shedding.
- Battery discharge restoring all consumers to full power.
- Real rigid-body motion, persistence reconstruction, and complete Stage 3–28 Godot regression coverage.

## 0.0.27-stage27 — Helix Core production reactor

### Added
- Production Large Grid `Helix Core Reactor L` (`helix_core_reactor_large`).
- 480 kW fixed electrical generation metadata.
- 145 kW heat-generation metadata for future thermal gameplay.
- 920 kg authoritative block mass and 980 integrity.
- Original nine-primitive containment-core presentation and dedicated `power_generation` material.
- Stage 27 reactor integration craft and dedicated reactor/power/battery physics smoke test.
- Reactor-specific source-audit and static-validation contracts.

### Changed
- BlockDB increased from 22 to 23 definitions and production buildable blocks from 19 to 20.
- Normal production generation now has a real cataloged reactor; Development Power Source L remains only as a regression fixture.
- Main development world advanced to Stage 27.
- Android version advanced to code 27 / `0.0.27-stage27`.
- Android debug export filename advanced to `voidforge-stage27-debug.apk`.
- Android command-line tools are now available locally; SDK package installation is still blocked by sandbox network access.

### Verified
- Exact 480 kW single-reactor and 960 kW dual-reactor generation.
- Full 216 kW seat/thruster/gyro load satisfaction.
- Full 48 kN thrust and 120 kN·m torque under reactor power.
- Real reactor-powered rigid-body translation/rotation.
- Flux Reservoir charging from reactor surplus at its 180 kW charge ceiling.
- Version-2 save/load reactor reconstruction and battery takeover after reactor removal.
- Complete Stage 3–27 Godot 4.7.2 regression suite with strict log-error scanning.

## 0.0.26-stage26 — Rechargeable battery storage

### Added
- Production Large Grid `Flux Reservoir L` (`flux_reservoir_large`).
- 60 kWh battery capacity, 50% default charge, 180 kW max charge, and 240 kW max discharge metadata.
- Per-block battery runtime storage keyed by stable logical block instance IDs.
- Time-based kW↔kWh charge/discharge simulation on the Stage 25 grid power bus.
- Battery-only craft operation when fixed generation is unavailable.
- Surplus-generation battery charging and deficit-driven discharging.
- Battery count/capacity/state-of-charge/rate/live-flow/runtime diagnostics.
- `battery_storage_changed` aggregate storage signal.
- Original battery presentation shape and `power_storage` material.
- Stage 26 hybrid battery integration craft and dedicated battery smoke test.

### Changed
- Grid save schema advanced from version 1 to version 2 with transactional `battery_states` persistence.
- Grid loader remains backward-compatible with version 1 and initializes migrated battery blocks from their BlockDB starting charge.
- Power satisfaction now considers both fixed generation and battery discharge availability.
- Battery simulation runs on frozen/static grids too, allowing stations to recharge while not dynamically moving.
- BlockDB increased from 21 to 22 total definitions and from 18 to 19 production blocks.
- Main development scene advanced to Stage 26.
- Android version advanced to code 26 / `0.0.26-stage26`.
- Android debug export filename advanced to `voidforge-stage26-debug.apk`.

### Verified
- Battery-only full-power thrust and real rigid-body motion.
- Real-time depletion and empty-state shutdown.
- 180 kW surplus charging.
- 240 kW discharge-rate limiting under a 366 kW request.
- Exact battery-kWh save/load restoration.
- Version-1 save migration.
- Transactional rejection of over-capacity corrupted storage.
- Complete Stage 3–26 Godot 4.7.2 regression suite with strict log-error scanning.

## 0.0.25-stage25 — Basic electrical power network

- Added cached grid-wide power producer/consumer discovery.
- Added total generation, rated demand, active demand, surplus, and satisfaction diagnostics.
- Added per-block power state reporting for producers, idle consumers, powered consumers, brownouts, and unpowered consumers.
- Added 6 kW Pilot Cradle occupancy demand.
- Added 120 kW full-throttle Pulse Thruster demand.
- Added 90 kW full-authority Vector Gyro demand.
- Thruster force and gyro torque now scale by available electrical power on power-enforced grids.
- Added development-only 180 kW Development Power Source L for pre-battery/generator network validation.
- Added power-cache invalidation on block mutation, save/load, and BlockDB reload.
- Added Stage 25 powered integration craft and automated no-power/brownout/full-power physics tests.
- Historical Stage 21–24 smoke fixtures explicitly bypass Stage 25 enforcement so they remain isolated regression tests.
- Android version advanced to code 25 / `0.0.25-stage25`.
- Android debug export filename advanced to `voidforge-stage25-debug.apk`.

## 0.0.24-stage24 — Android ship-control interface

### Added
- Dedicated fixed-origin Android right joystick for pitch/yaw control.
- 18% right-stick dead zone for precision around neutral.
- Contextual **R-L** and **R-R** roll buttons.
- Stage 24 mobile control-state diagnostics.
- Eight-block / 4,190 kg mobile-control integration craft with six directional thrusters and one gyro.
- Stage 24 dual-stick physics smoke test and Stage 3–24 full regression runner.

### Changed
- Seated Android HUD is now a true dual-stick layout: left translation, right pitch/yaw, separate roll and vertical translation controls.
- Vehicle controls automatically appear on Pilot Cradle entry and restore the on-foot HUD on exit.
- Right rotation stick and all seated context buttons are excluded from free-look touch ownership.
- `TouchActionButton` now releases its owned touch even if a context switch hides the button before finger-up, preventing stuck EXIT/actions.
- Main development scene advanced to Stage 24.
- Android version advanced to code 24 / `0.0.24-stage24`.
- Android debug export filename advanced to `voidforge-stage24-debug.apk`.

### Verified
- Right-stick pitch/yaw bindings and neutral dead zone.
- Three-finger simultaneous translation + rotation + roll ownership.
- Real rigid-body linear and angular response from mobile controls.
- Roll-left/right signed action behavior.
- EXIT context-switch release safety.
- Automatic on-foot control restoration.
- Complete Stage 3–24 Godot 4.7.2 regression suite with strict log-error scanning.

## 0.0.23-stage23 — Gyroscope and rotational control

### Added
- Production Large Grid `Vector Gyro L` (`vector_gyro_large`).
- Data-driven `gyro_torque_nm` gyroscope metadata with a 120 kN·m rating.
- Mutation-driven per-grid gyroscope cache with stable instance IDs and total installed torque.
- Pilot-authorized three-axis manual rotation input and active local-torque diagnostics.
- Real `RigidBody3D.apply_torque()` rotational physics using grid-local → world-space torque conversion.
- Six desktop/InputMap actions: pitch up/down, yaw left/right, and roll left/right.
- Original procedural five-part gyroscope presentation and dedicated material.
- Five-block / 1,910 kg / 120 kN·m Stage 23 Gyro Craft integration fixture.
- Stage 23 gyroscope physics smoke test and Stage 3–23 full regression runner.

### Changed
- BlockDB increased from 19 to 20 definitions.
- `BlockGrid` physics processing now handles both manual translation force and manual rotation torque under the same Pilot Cradle authority contract.
- Gyroscope cache invalidates after placement, removal, clear, load, or BlockDB reload.
- Pilot release/failure clears both translation and rotation commands.
- Main development scene advanced to Stage 23.
- Android version advanced to code 23 / `0.0.23-stage23`.
- Android debug export filename advanced to `voidforge-stage23-debug.apk`.

### Verified
- Exact 120 kN·m single-gyro torque and additive 240 kN·m two-gyro authority.
- Gyroscope cache removal/save-load reconstruction.
- Non-pilot command rejection and Pilot Cradle authority.
- Real rigid-body torque for all six signed pitch/yaw/roll actions.
- Independent multi-axis rotation-input clamping.
- Lower angular response from a heavier craft under identical gyro torque.
- Complete Stage 3–23 Godot 4.7.2 regression suite with strict log-error scanning.

## 0.0.22-stage22 — Directional thrust calculations

### Added
- Six-axis grid-local translation command model.
- Directional thruster classification for ±X, ±Y, and ±Z from each block's real mounted orientation.
- Cached per-direction rated thrust and stable thruster-instance lookup.
- `set_manual_translation_input()` and active local-force diagnostics.
- Desktop vehicle thrust actions for backward, left, right, up, and down.
- Contextual mobile joystick rebinding from on-foot movement to seated vehicle translation.
- Android **UP** and **DN** vertical-thrust buttons.
- Seven-block / six-thruster / 3,580 kg Stage 22 directional craft.
- Stage 22 directional-thrust smoke test and full regression runner.

### Changed
- Seated player input now forwards a three-axis translation vector rather than one forward scalar.
- Only thrusters physically capable of contributing to the requested local direction fire.
- Stage 21 forward-thrust API remains as a compatibility wrapper around local -Z translation.
- Mobile THR remains available as forward compatibility while the left stick now handles horizontal translation.
- Main development scene advanced to Stage 22.
- Android version advanced to code 22 / `0.0.22-stage22`.
- Android debug export filename advanced to `voidforge-stage22-debug.apk`.

### Verified
- Exact 48 kN groups on all six local translation directions.
- Balanced opposed-thruster zero idle vector with 288 kN total installed rating.
- Forward/back/left/right/up/down real rigid-body translation.
- Diagonal translation without opposed-thruster activation.
- Pilot authority gating.
- Android joystick mode switching and UP/DN controls.
- Complete Stage 3–22 Godot 4.7.2 regression suite.

## 0.0.21-stage21 — First functional thruster

### Added
- Production Large Grid `Pulse Thruster L` (`pulse_thruster_large`).
- Data-driven `thrust_force_n` and cardinal `thrust_direction_local` BlockDefinition metadata.
- Cached per-grid thruster discovery, rated force, and oriented local force-vector summation.
- Pilot-authorized `vehicle_thrust_forward` command path.
- Real `RigidBody3D.apply_central_force()` propulsion.
- Contextual Android **THR** button using the same InputMap action as desktop.
- Original propulsion material and procedural four-part thruster placeholder geometry.
- Stage 21 five-block 1,820 kg / 48 kN Thrust Craft integration fixture.
- Stage 21 propulsion smoke test and full regression runner.

### Changed
- BlockDB increased from 18 to 19 definitions.
- `BlockGrid` propulsion cache invalidates on place/remove/clear/load/BlockDB reload.
- Seated player physics processing now forwards vehicle thrust input to the controlled grid.
- Leaving/failing pilot authority clears manual thrust immediately.
- Mobile seated HUD now shows THR + EXIT and hides on-foot controls.
- Main development scene advanced to Stage 21.
- Android version advanced to code 21 / `0.0.21-stage21`.
- Android debug export filename advanced to `voidforge-stage21-debug.apk`.

### Verified
- Orientation-derived thrust vectors.
- Propulsion cache save/load/removal behavior.
- Pilot-authority rejection/acceptance.
- Real rigid-body thrust direction and acceleration.
- Mass-dependent acceleration from the same 48 kN thruster.
- Android THR action and touch-look exclusion.
- Complete Stage 3–21 Godot 4.7.2 regression suite.

## 0.0.20-stage20 — Basic cockpit/control seat

### Added
- Production Large Grid `Pilot Cradle L` control-seat block (`pilot_cradle_large`).
- Grid-owned manual pilot authority keyed to a stable control-seat block instance.
- `pilot_changed` signaling and pilot/seat claim/release/query APIs.
- Lightweight `ControlSeatPresenter` functional proxy layer.
- Interactable `ControlSeatInteraction` proxy on the dedicated Interactable physics layer.
- Player vehicle-control context with seat entry, exit, forced ejection, camera following, and seated free-look.
- Contextual Android **EXIT** action using the shared `vehicle_exit` InputMap action.
- Original procedural control-seat/console placeholder presentation and material.
- Stage 20 five-block 1,580 kg Pilot Craft integration fixture.
- Stage 20 control-seat smoke test and regression runner.

### Changed
- BlockDB increased from 17 to 18 definitions.
- `BlockGrid` invalidates active pilot authority before occupied-seat removal, clear, or load.
- Sleeping dynamic grids wake when a pilot successfully claims control.
- On-foot interaction/build/movement systems suspend while seated and restore on exit.
- Mobile on-foot action buttons hide contextually while seated.
- Stage 15 historical production assertions now scope themselves to structural/armor categories so future functional production blocks do not create false regressions.
- Main development scene advanced to Stage 20.
- Android version advanced to code 20 / `0.0.20-stage20`.
- Android debug export filename advanced to `voidforge-stage20-debug.apk`.

### Verified
- Camera-ray seat entry and prompt.
- Exclusive pilot ownership and invalid-seat rejection.
- Dynamic-grid wake on pilot claim.
- Seated camera/body following translated and rotated grids.
- Independent seated free-look.
- Android EXIT action and touch-look exclusion.
- Forced ejection when the occupied seat block is removed.
- Complete Stage 3–20 Godot 4.7.2 regression suite.

## 0.0.19-stage19 — Authoritative ship mass calculation

### Added
- Authoritative per-grid block mass cache derived from canonical BlockDB `mass_kg` metadata.
- `mass_changed(total_mass_kg, physics_mass_kg)` signal.
- `get_total_mass_kg()` and `get_physics_mass_kg()` APIs.
- `get_mass_state()` diagnostics.
- `get_mass_breakdown_by_block_id()` diagnostics.
- `recalculate_mass_from_blocks()` repair/rebuild API.
- 0.001 kg empty-rigid-body safety floor while preserving a true 0 kg authoritative empty-grid mass.
- Mass validation inside the grid integrity audit.
- Transactional load-time mass calculation.
- Canonical registered-ID mass protection against transient resource spoofing.
- Stage 19 three-block 1,190 kg mixed-mass development craft.
- Stage 19 mass/physics smoke test.
- Stage 19 regression runner.

### Changed
- Removed the Stage 18 provisional `prototype_dynamic_mass_kg` override and setter.
- `RigidBody3D.mass` now follows calculated construction state instead of a manual prototype value.
- Placement, removal, clear, and grid reload now synchronize mass immediately.
- Sleeping dynamic grids wake when their calculated mass actually changes.
- `get_motion_state()` now reports authoritative block mass and physics mass separately.
- Stage 18 dynamic demo now derives 1,400 kg automatically from five reinforced frames.
- Stage 18 regression updated to validate authoritative mass instead of provisional mass configuration.
- Main development scene advanced to Stage 19.
- Android version advanced to code 19 / `0.0.19-stage19`.
- Android debug export filename advanced to `voidforge-stage19-debug.apk`.

### Verified
- Exact 280 + 720 + 190 = 1,190 kg mixed-grid total.
- Multi-cell beam contributes mass once per logical block.
- Mass synchronization after placement/removal/clear/load.
- Canonical BlockDB mass lookup.
- Integrity detection/repair of physics-mass drift.
- Real impulse response of 350 kg versus 720 kg dynamic grids.
- Complete Stage 3–19 Godot 4.7.2 regression suite.

## Earlier stages
Stages 1–18 established the Android-ready project foundation, player/mobile controls, interaction/inventory/hotbar, sparse construction grids, placement/rotation/removal, persistence, authoritative data registries, the first structural/armor library, MultiMesh rendering, cached one-body grid collision, and dynamic rigid-body grid motion.
