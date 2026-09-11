# VOIDFORGE Known Issues / Deliberate Stage Boundaries

## Stage 31 handheld-tool boundaries

- The Bore Calibration Stone records drill work but does not yet yield ore or alter geometry. Stage 32 adds mineable asteroid resource depletion; Stages 33–34 choose/implement the mobile-friendly deformable terrain representation.
- Field Bore Drill currently has no suit-power draw, durability, heat, animation rig, sound, particles, or inventory output. These are intentionally deferred until the mining/resource loop exists.
- Tool targeting is one camera-centered ray on the Mineable collision layer. Area/cone mining, surface-normal effects, material hardness, and tool upgrades are later work.
- The orange drill beam is lightweight placeholder feedback, not final art/VFX.
- Hotbar slot assignment is still the development loadout; the later survival/tutorial flow will control player starting equipment.

## Stage 30 configuration boundaries

- Configuration currently covers enabled/disabled state, per-instance custom names, electrical priority overrides, and named groups. Stage 30 does not yet expose arbitrary block-specific sliders/settings such as thruster override, gyro strength, battery modes, reactor output, door behavior, or wheel tuning.
- Groups persist membership but do not yet provide batch actions such as toggle group, toolbar action, automation trigger, or group priority edits. Those become useful in later terminal/automation stages.
- Group names are local to one grid and use stable logical block instance IDs; there is no multi-grid/fleet group namespace.
- Deleting a group currently acts immediately; confirmation dialogs and broader terminal UX polish are later work.
- Disabled batteries preserve stored kWh but do not participate in charge/discharge until re-enabled.
- Disabling an occupied Pilot Cradle ejects the pilot immediately by design.
- The terminal remains modal but does not pause world simulation; power, batteries, rigid bodies, and later NPC/world systems may continue running while it is open.
- Terminal UI has been validated headlessly at project resolution, but physical Android-device usability/performance awaits a verified APK/device run.

## Persistence boundary

- Current grid payload is `voidforge.block_grid` schema version 3. Versions 1 and 2 migrate forward.
- Version 3 stores construction state, per-instance battery energy, enabled state, custom name, priority override, and named groups.
- Dynamic world transform/velocity, player position, mission/world state, and atomic backup files are not yet owned by this grid payload; the later world save manager will persist them.
- Custom names are capped at 48 characters and group names at 32 characters; malformed configuration rejects the whole incoming grid transactionally.

## Electrical-system boundaries

- The electrical system remains one grid-wide logical bus; disconnected electrical islands are not implemented yet.
- Priority order is Critical → High → Normal → Low. Per-instance overrides can now replace the canonical BlockDB priority.
- Equal-priority consumers proportionally share a constrained tier before lower tiers receive power.
- Batteries contribute available discharge to the allocator, but multiple batteries still charge/discharge deterministically by stable instance ID rather than electrically equalizing state of charge.
- Battery Auto/Recharge/Discharge modes are not implemented yet.
- Helix Core Reactor still supplies fixed generation without replaceable fuel; fuel storage/transport/consumption arrives in later fuel-network stages.
- Reactor heat metadata exists but thermal simulation does not.
- Development Power Source L and Development Auxiliary Load L remain regression fixtures rather than production progression content.

## Android build limitation

Godot 4.7.2 runtime/editor testing works with the supplied Linux executable. Android command-line tools launch successfully, but package installation cannot reach Google's Android SDK repository from this sandbox. The required Android platform/build-tools packages remain absent, so Godot cannot yet perform a truthful APK export/installability test.

## Existing later-stage boundaries

- Pulse Thrusters consume electricity but not propellant yet.
- Center-of-mass/inertia still use Godot's rigid-body approximation rather than custom block-weighted inertia.
- Grid collision uses one rigid body and cached shape owners, but dirty collision flushes still rebuild the grid collision-owner set.
- Planet/asteroid mining, production, conveyors, damage, NPCs, and world streaming remain future roadmap stages.
