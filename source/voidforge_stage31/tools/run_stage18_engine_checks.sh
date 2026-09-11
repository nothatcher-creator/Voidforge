#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4}"
TMP_DIR="${TMPDIR:-/tmp}/voidforge_stage18_checks_$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

check_log() {
  local log="$1"
  if grep -qE 'SCRIPT ERROR:|^ERROR:' "$log"; then
    echo "Engine error detected in $log" >&2
    grep -nE 'SCRIPT ERROR:|^ERROR:' "$log" >&2 || true
    return 1
  fi
}
run_godot() {
  local label="$1"; shift
  local log="$TMP_DIR/$label.log"
  GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" "$@" >"$log" 2>&1
  check_log "$log"
  cat "$log"
}

python3 "$ROOT/tools/validate_project.py"
python3 "$ROOT/tools/audit_item_database.py"
python3 "$ROOT/tools/audit_block_database.py"
run_godot editor --headless --editor --path "$ROOT" --quit
run_godot main --headless --path "$ROOT" --quit-after 2
for scene in \
  stage3_controller_smoke_test \
  stage4_touch_controls_smoke_test \
  stage5_interaction_smoke_test \
  stage6_inventory_smoke_test \
  stage7_item_database_smoke_test \
  stage8_hotbar_smoke_test \
  stage9_grid_smoke_test \
  stage10_block_placement_smoke_test \
  stage11_block_rotation_smoke_test \
  stage12_block_removal_smoke_test \
  stage13_grid_save_load_smoke_test \
  stage14_block_database_smoke_test \
  stage15_structural_library_smoke_test \
  stage16_grid_geometry_smoke_test \
  stage17_grid_collision_smoke_test \
  stage18_dynamic_grid_smoke_test; do
  run_godot "$scene" --headless --path "$ROOT" "res://scenes/tests/${scene}.tscn"
done
