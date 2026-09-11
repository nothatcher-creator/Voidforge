# Android Build Environment Status

Stage 31 does not claim an APK yet. Gameplay/editor verification works with Godot 4.7.2, and project-side architecture includes touch-first on-foot controls, dedicated dual-stick ship controls, modal TERM access, block configuration UI, batched construction rendering, one rigid body per grid, authoritative mass, pilot-seat authority, six-axis thrust, gyro torque, electrical power, rechargeable batteries, a production reactor, and priority load shedding.

## External Android tools validated

Two user-supplied archives remain outside project source:

- `android-sdk-tools-static-x86_64.zip`: working `adb`, `aapt`/`aapt2`, `zipalign`, `aidl`, `fastboot`, and related utilities.
- `commandlinetools-linux-15859902_latest.zip`: working Android SDK command-line tools including `sdkmanager` and `avdmanager`.

OpenJDK/Javac are available and `sdkmanager` launches successfully from the staged external SDK directory.

## Remaining blocker

This sandbox cannot connect to Google's Android SDK package repository, so `sdkmanager` cannot install the missing platform/build-tools packages. The local SDK therefore lacks the complete versioned `build-tools` directory and platform `android.jar` layout Godot requires. The Android SDK/tool archives are deliberately not bundled in VOIDFORGE source packages.

## Project-side Android state

- ARM64 enabled.
- Internet/network/Wi-Fi permissions disabled.
- Landscape + immersive mode.
- GL Compatibility renderer and Android frame pacing.
- Android multi-touch on-foot controls.
- Dedicated seated left translation and right pitch/yaw joysticks.
- Contextual roll, vertical thrust, forward thrust, exit, and TERM buttons.
- Modal terminal blocks/clears mobile gameplay controls and restores the correct context on close.
- Touch-sized Stage 30 block configuration controls.
- On-foot Stage 31 **TOOL** button mapped to the shared `tool_use` InputMap action and excluded from camera-look ownership.
- Local JSON-compatible grid persistence schema v3 with v1/v2 migration.
- Per-instance enabled state, custom names, electrical-priority overrides, and persistent block groups.
- Manifest-driven ItemDB and BlockDB.
- 21 production items/resources including the Field Bore Drill; 20 production buildable blocks plus 4 development definitions.
- Flux Reservoir L: 60 kWh, 180 kW max charge, 240 kW max discharge, 680 kg.
- Helix Core Reactor L: 480 kW fixed production, 145 kW heat metadata, 920 kg.
- Critical/High/Normal/Low load-shedding allocator with per-instance override support.
- Cached MultiMesh rendering and one `RigidBody3D` carrier per grid.
- Version code `31` / `0.0.31-stage31`.
- Debug export filename `voidforge-stage31-debug.apk`.

No claim of installable APK readiness or Android-device physics/performance is made at Stage 31.
