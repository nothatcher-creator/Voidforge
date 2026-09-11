# VOIDFORGE

**Current snapshot:** Stage 31 — Field Bore Drill / held-tool foundation (`0.0.31-stage31`). The drill is inventory/hotbar-backed, works through shared desktop/Android input, targets the dedicated Mineable layer, and drives reusable held-work targets. Stage 32 will make the first asteroid actually yield resources.

VOIDFORGE is an original mobile-first 3D engineering, spacecraft-building, mining, exploration, and survival sandbox being developed incrementally in Godot 4.7.2 for completely offline Android play.

Current verified milestone: **Stage 31 — Functional block configuration UI** (`0.0.30-stage30`).

The playable engineering vertical slice now includes first-person/mobile controls, modular grid construction, rotation/removal, versioned persistence, an original structural library, batched rendering/collision, dynamic rigid-body craft, block-derived mass, Pilot Cradles, six-axis thrusters, gyroscopes, Android dual-stick flight, an electrical bus, rechargeable Flux Reservoir batteries, the 480 kW Helix Core Reactor, priority load shedding, and a touch-first ship terminal.

Stage 30 turns that terminal into a real management surface. Installed functional blocks can be enabled/disabled, renamed, assigned per-instance power-priority overrides, and organized into named groups. Changes affect authoritative simulation immediately: disabling generation/thrust/gyro/control blocks changes the craft rather than only changing UI text. Disabled batteries keep their stored energy while leaving the active bus.

Grid persistence is now schema version 3 and stores block configuration plus groups while retaining v1/v2 migration support. Custom names and groups use stable logical block instance IDs; malformed v3 state is rejected transactionally.

The Stage 30 demonstration configuration renames the Pulse Thruster to **Main Drive**, overrides it to High power priority, and groups it with the Vector Gyro in **Flight Systems**. The underlying mixed terminal craft remains 8 blocks / 4,230 kg / 480 kW generation / 60 kWh battery capacity.

Run `tools/run_stage30_engine_checks.sh` with `GODOT_BIN` pointing at Godot 4.7.2 to execute static validation, ItemDB/BlockDB audits, clean editor parsing, main startup, and every Stage 3–30 smoke test. The runner scans logs for script/runtime errors instead of trusting process exit codes alone.

The project is configured for landscape Android, ARM64, GL Compatibility rendering, offline operation, and no Internet permission. Android SDK command-line tools run locally, but this sandbox cannot download the missing Android platform/build-tools packages, so APK export/installability remains unverified.

See `PROJECT_STATUS.md`, `ARCHITECTURE.md`, `KNOWN_ISSUES.md`, `CONTENT_COUNTS.md`, and `CHANGELOG.md` for the authoritative project record.
