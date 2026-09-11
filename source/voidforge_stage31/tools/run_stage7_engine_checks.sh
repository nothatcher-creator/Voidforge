#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4}"

python3 "$ROOT/tools/validate_project.py"
python3 "$ROOT/tools/audit_item_database.py"
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --editor --path "$ROOT" --quit
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --path "$ROOT" --quit-after 2
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --path "$ROOT" res://scenes/tests/stage3_controller_smoke_test.tscn
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --path "$ROOT" res://scenes/tests/stage4_touch_controls_smoke_test.tscn
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --path "$ROOT" res://scenes/tests/stage5_interaction_smoke_test.tscn
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --path "$ROOT" res://scenes/tests/stage6_inventory_smoke_test.tscn
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --path "$ROOT" res://scenes/tests/stage7_item_database_smoke_test.tscn
