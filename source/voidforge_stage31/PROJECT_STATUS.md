# VOIDFORGE Project Status

## Current milestone

**Stage 31 — Player hand drill and held-tool foundation: COMPLETE**

Build version: `0.0.31-stage31`  
Reference engine: **Godot 4.7.2 stable**  
Primary target: offline Android, landscape, GL Compatibility renderer

## Stage 31 result

The player now has the first real handheld tool pipeline. **Field Bore Drill** is a production ItemDB entry, must exist in inventory, must be equipped through the existing eight-slot hotbar, and exposes data-driven tool type/range/work-rate metadata. A reusable `HandDrillController` performs camera-centered mineable-target raycasts, enforces a 4.5 m range, applies repeated work while the shared `tool_use` action is held, and emits start/stop/tick/target feedback.

Stage 31 adds a dedicated Mineable 3D physics layer and a non-deforming **Bore Calibration Stone** test target implementing the reusable drill-work receiver contract. The target records applied work only; actual asteroid material extraction/deformation intentionally begins in Stages 32–34. Active drilling has visible orange beam feedback.

Android now has a contextual **TOOL** touch button on foot. It uses the same `tool_use` InputMap action as desktop left mouse, owns an independent touch ID, is excluded from right-side camera-look ownership, and is cleared by the same modal/context input safeguards as other mobile actions.

The Stage 31 wrapper adds one Field Bore Drill to the player inventory, assigns it to hotbar slot 5, selects it for immediate testing, and places the calibration stone inside tool range.

## Verification

Godot 4.7.2 verifies ItemDB registration, hotbar/inventory requirements, correct tool metadata, camera-ray target acquisition, range rejection/reacquisition, held work ticks, release cleanup, wrong-tool rejection, visible drill-beam cleanup, Android TOOL touch ownership, Android camera-look exclusion, and real touch-driven drill work. Historical Stage 3–30 regressions are retained in the Stage 31 runner.

Static project validation, ItemDB audit, and BlockDB audit pass. Final packaging uses `STAGE31_MANIFEST.sha256` and excludes generated caches/logs, the Godot executable, and Android SDK/toolchain files.

## Android status

Project-side Android configuration remains landscape, ARM64, offline/no Internet permission, GL Compatibility, touch-first on-foot controls, dual-stick flight controls, modal terminal/configuration UI, and now handheld TOOL input. The supplied Android command-line tools work locally, but this sandbox still cannot download the missing Android platform/build-tools packages from Google's SDK repository, so a truthful APK export/installability test remains blocked externally.

## Next stage

Stage 32 will implement the first mineable asteroid prototype on top of the Stage 31 tool contract: asteroid material state, ore identity/quantity, drill depletion, extraction events, and a visible mined-resource loop before terrain deformation is introduced in Stages 33–34.
