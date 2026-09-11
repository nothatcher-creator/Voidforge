#!/usr/bin/env python3
"""Static integrity checks for the current VOIDFORGE Stage 31 source snapshot."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "project.godot",
    "export_presets.cfg",
    "scenes/core/main.tscn",
    "scenes/tests/stage2_environment_test.tscn",
    "scenes/tests/stage3_player_movement_test.tscn",
    "scenes/tests/stage3_controller_smoke_test.tscn",
    "scenes/tests/stage4_touch_controls_smoke_test.tscn",
    "scenes/tests/stage5_interaction_test.tscn",
    "scenes/tests/stage5_interaction_smoke_test.tscn",
    "scenes/tests/stage6_inventory_smoke_test.tscn",
    "scenes/tests/stage7_item_database_smoke_test.tscn",
    "scenes/tests/stage8_hotbar_test.tscn",
    "scenes/tests/stage8_hotbar_smoke_test.tscn",
    "scenes/tests/stage9_grid_test.tscn",
    "scenes/tests/stage9_grid_smoke_test.tscn",
    "scenes/tests/stage10_block_placement_test.tscn",
    "scenes/tests/stage10_block_placement_smoke_test.tscn",
    "scenes/tests/stage11_block_rotation_test.tscn",
    "scenes/tests/stage11_block_rotation_smoke_test.tscn",
    "scenes/tests/stage12_block_removal_test.tscn",
    "scenes/tests/stage12_block_removal_smoke_test.tscn",
    "scenes/tests/stage13_grid_save_load_test.tscn",
    "scenes/tests/stage13_grid_save_load_smoke_test.tscn",
    "scenes/tests/stage14_block_database_test.tscn",
    "scenes/tests/stage14_block_database_smoke_test.tscn",
    "scenes/tests/stage15_structural_library_test.tscn",
    "scenes/tests/stage15_structural_library_smoke_test.tscn",
    "scenes/tests/stage16_grid_geometry_test.tscn",
    "scenes/tests/stage16_grid_geometry_smoke_test.tscn",
    "scenes/tests/stage17_grid_collision_test.tscn",
    "scenes/tests/stage17_grid_collision_smoke_test.tscn",
    "scenes/tests/stage18_dynamic_grid_test.tscn",
    "scenes/tests/stage18_dynamic_grid_smoke_test.tscn",
    "scenes/tests/stage19_ship_mass_test.tscn",
    "scenes/tests/stage19_ship_mass_smoke_test.tscn",
    "scenes/tests/stage20_control_seat_test.tscn",
    "scenes/tests/stage20_control_seat_smoke_test.tscn",
    "scenes/tests/stage21_thruster_test.tscn",
    "scenes/tests/stage21_thruster_smoke_test.tscn",
    "scenes/tests/stage22_directional_thrust_test.tscn",
    "scenes/tests/stage22_directional_thrust_smoke_test.tscn",
    "scenes/tests/stage23_gyroscope_test.tscn",
    "scenes/tests/stage23_gyroscope_smoke_test.tscn",
    "scenes/tests/stage24_mobile_ship_control_test.tscn",
    "scenes/tests/stage24_mobile_ship_controls_smoke_test.tscn",
    "scenes/tests/stage25_power_network_test.tscn",
    "scenes/tests/stage25_power_network_smoke_test.tscn",
    "scenes/tests/stage26_battery_test.tscn",
    "scenes/tests/stage26_battery_smoke_test.tscn",
    "scenes/tests/stage27_reactor_test.tscn",
    "scenes/tests/stage27_reactor_smoke_test.tscn",
    "scenes/tests/stage28_power_priority_test.tscn",
    "scenes/tests/stage28_power_priority_smoke_test.tscn",
    "scenes/tests/stage29_ship_terminal_test.tscn",
    "scenes/tests/stage29_ship_terminal_smoke_test.tscn",
    "scenes/tests/stage30_block_configuration_test.tscn",
    "scenes/tests/stage30_block_configuration_smoke_test.tscn",
    "scenes/building/placement_ghost.tscn",
    "scenes/building/removal_highlight.tscn",
    "scenes/grids/prototype_block_grid.tscn",
    "scenes/player/first_person_player.tscn",
    "scenes/interaction/test_interactable.tscn",
    "scenes/ui/performance_overlay.tscn",
    "scenes/ui/mobile_touch_controls.tscn",
    "scenes/ui/interaction_prompt.tscn",
    "scenes/ui/hotbar_ui.tscn",
    "scenes/ui/ship_terminal_ui.tscn",
    "scripts/core/bootstrap.gd",
    "scripts/core/game_config.gd",
    "scripts/core/debug_log.gd",
    "scripts/world/stage2_environment_test.gd",
    "scripts/world/stage3_player_movement_test.gd",
    "scripts/player/first_person_player.gd",
    "scripts/player/hotbar_component.gd",
    "scripts/world/stage8_hotbar_test.gd",
    "scripts/world/stage9_grid_test.gd",
    "scripts/world/stage10_block_placement_test.gd",
    "scripts/world/stage11_block_rotation_test.gd",
    "scripts/world/stage12_block_removal_test.gd",
    "scripts/world/stage13_grid_save_load_test.gd",
    "scripts/world/stage14_block_database_test.gd",
    "scripts/world/stage15_structural_library_test.gd",
    "scripts/world/stage16_grid_geometry_test.gd",
    "scripts/world/stage17_grid_collision_test.gd",
    "scripts/world/stage18_dynamic_grid_test.gd",
    "scripts/world/stage19_ship_mass_test.gd",
    "scripts/world/stage20_control_seat_test.gd",
    "scripts/world/stage21_thruster_test.gd",
    "scripts/world/stage22_directional_thrust_test.gd",
    "scripts/world/stage23_gyroscope_test.gd",
    "scripts/world/stage24_mobile_ship_control.gd",
    "scripts/world/stage25_power_network.gd",
    "scripts/world/stage26_battery.gd",
    "scripts/world/stage27_reactor.gd",
    "scripts/world/stage28_power_priority.gd",
    "scripts/world/stage29_ship_terminal.gd",
    "scripts/world/stage30_block_configuration.gd",
    "scripts/ships/control_seat_interaction.gd",
    "scripts/ships/control_seat_presenter.gd",
    "scripts/grids/grid_profile.gd",
    "scripts/grids/grid_registry.gd",
    "scripts/grids/block_orientation.gd",
    "scripts/grids/block_instance_data.gd",
    "scripts/grids/block_grid.gd",
    "scripts/grids/block_grid_presenter.gd",
    "scripts/building/block_placement_controller.gd",
    "scripts/building/placement_ghost.gd",
    "scripts/building/removal_highlight.gd",
    "scripts/interaction/interaction_component.gd",
    "scripts/interaction/player_interactor.gd",
    "scripts/interaction/test_interactable.gd",
    "scripts/input/mobile_touch_controls.gd",
    "scripts/input/virtual_joystick.gd",
    "scripts/input/touch_look_area.gd",
    "scripts/input/touch_action_button.gd",
    "scripts/ui/interaction_prompt.gd",
    "scripts/ui/hotbar_ui.gd",
    "scripts/ui/hotbar_slot_button.gd",
    "scripts/ui/ship_terminal_ui.gd",
    "scripts/optimization/performance_monitor.gd",
    "scripts/blocks/block_definition.gd",
    "scripts/blocks/block_cost_entry.gd",
    "scripts/blocks/block_catalog.gd",
    "scripts/blocks/block_database.gd",
    "scripts/inventory/item_definition.gd",
    "scripts/inventory/item_stack.gd",
    "scripts/inventory/inventory_component.gd",
    "scripts/inventory/item_catalog.gd",
    "scripts/inventory/item_database.gd",
    "data/items/item_catalog.tres",
    "data/grids/small_grid_profile.tres",
    "data/grids/large_grid_profile.tres",
    "data/grids/static_grid_profile.tres",
    "data/blocks/dev_hull_frame.tres",
    "data/blocks/dev_span_frame.tres",
    "data/blocks/block_catalog.tres",
    "data/blocks/control/pilot_cradle_large.tres",
    "data/blocks/propulsion/pulse_thruster_large.tres",
    "data/blocks/control/vector_gyro_large.tres",
    "data/blocks/power/dev_power_source_large.tres",
    "data/blocks/power/flux_reservoir_large.tres",
    "data/blocks/power/helix_core_reactor_large.tres",
    "data/blocks/power/dev_aux_load_large.tres",
    "assets/materials/block_control_material.tres",
    "assets/materials/block_propulsion_material.tres",
    "assets/materials/block_gyro_material.tres",
    "assets/materials/block_power_storage_material.tres",
    "assets/materials/block_power_generation_material.tres",
    "tests/stage3_player_controller_smoke_test.gd",
    "tests/stage4_touch_controls_smoke_test.gd",
    "tests/stage5_interaction_smoke_test.gd",
    "tests/stage6_inventory_smoke_test.gd",
    "tests/stage7_item_database_smoke_test.gd",
    "tests/stage8_hotbar_smoke_test.gd",
    "tests/stage9_grid_smoke_test.gd",
    "tests/stage10_block_placement_smoke_test.gd",
    "tests/stage11_block_rotation_smoke_test.gd",
    "tests/stage12_block_removal_smoke_test.gd",
    "tests/stage13_grid_save_load_smoke_test.gd",
    "tests/stage14_block_database_smoke_test.gd",
    "tests/stage15_structural_library_smoke_test.gd",
    "tests/stage16_grid_geometry_smoke_test.gd",
    "tests/stage17_grid_collision_smoke_test.gd",
    "tests/stage18_dynamic_grid_smoke_test.gd",
    "tests/stage19_ship_mass_smoke_test.gd",
    "tests/stage20_control_seat_smoke_test.gd",
    "tests/stage21_thruster_smoke_test.gd",
    "tests/stage22_directional_thrust_smoke_test.gd",
    "tests/stage23_gyroscope_smoke_test.gd",
    "tests/stage24_mobile_ship_controls_smoke_test.gd",
    "tests/stage25_power_network_smoke_test.gd",
    "tests/stage26_battery_smoke_test.gd",
    "tests/stage27_reactor_smoke_test.gd",
    "tests/stage28_power_priority_smoke_test.gd",
    "tests/stage29_ship_terminal_smoke_test.gd",
    "tests/stage30_block_configuration_smoke_test.gd",
    "tools/run_stage6_engine_checks.sh",
    "tools/audit_item_database.py",
    "tools/audit_block_database.py",
    "tools/run_stage7_engine_checks.sh",
    "tools/run_stage8_engine_checks.sh",
    "tools/run_stage9_engine_checks.sh",
    "tools/run_stage10_engine_checks.sh",
    "tools/run_stage11_engine_checks.sh",
    "tools/run_stage12_engine_checks.sh",
    "tools/run_stage13_engine_checks.sh",
    "tools/run_stage14_engine_checks.sh",
    "tools/run_stage15_engine_checks.sh",
    "tools/run_stage16_engine_checks.sh",
    "tools/run_stage17_engine_checks.sh",
    "tools/run_stage18_engine_checks.sh",
    "tools/run_stage19_engine_checks.sh",
    "tools/run_stage20_engine_checks.sh",
    "tools/run_stage21_engine_checks.sh",
    "tools/run_stage22_engine_checks.sh",
    "tools/run_stage23_engine_checks.sh",
    "tools/run_stage24_engine_checks.sh",
    "tools/run_stage25_engine_checks.sh",
    "tools/run_stage26_engine_checks.sh",
    "tools/run_stage27_engine_checks.sh",
    "tools/run_stage28_engine_checks.sh",
    "tools/run_stage29_engine_checks.sh",
    "tools/run_stage30_engine_checks.sh",
    "data/items/tools/field_bore_drill.tres",
    "scripts/tools/hand_drill_controller.gd",
    "scripts/tools/drill_work_target.gd",
    "scenes/mining/drill_work_target.tscn",
    "assets/materials/drill_target_material.tres",
    "assets/materials/drill_beam_material.tres",
    "scripts/world/stage31_hand_drill.gd",
    "scenes/tests/stage31_hand_drill_test.tscn",
    "tests/stage31_hand_drill_smoke_test.gd",
    "scenes/tests/stage31_hand_drill_smoke_test.tscn",
    "tools/run_stage31_engine_checks.sh",
    "android/ANDROID_BUILD_STATUS.md",
    "PROJECT_STATUS.md",
    "CHANGELOG.md",
    "ARCHITECTURE.md",
    "KNOWN_ISSUES.md",
    "CONTENT_COUNTS.md",
    "README.md",
    "STAGE31_MANIFEST.sha256",
]

RESOURCE_PATTERN = re.compile(r'path="(res://[^"]+)"')
PROJECT_RESOURCE_PATTERN = re.compile(r'"\*?(res://[^"]+)"')
MAIN_SCENE_PATTERN = re.compile(r'run/main_scene="(res://[^"]+)"')
EXT_DECL_PATTERN = re.compile(r'^\[ext_resource\b[^\]]*\bid="([^"]+)"[^\]]*\]$', re.MULTILINE)
EXT_USE_PATTERN = re.compile(r'ExtResource\("([^"]+)"\)')
SUB_DECL_PATTERN = re.compile(r'^\[sub_resource\b[^\]]*\bid="([^"]+)"[^\]]*\]$', re.MULTILINE)
SUB_USE_PATTERN = re.compile(r'SubResource\("([^"]+)"\)')


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(1)


def assert_contains(text: str, needle: str, description: str) -> None:
    if needle not in text:
        fail(f"Missing {description}: {needle}")


def validate_resource_ids(path: Path, text: str) -> None:
    ext_declared = set(EXT_DECL_PATTERN.findall(text))
    ext_used = set(EXT_USE_PATTERN.findall(text))
    missing_ext = sorted(ext_used - ext_declared)
    if missing_ext:
        fail(f"Undeclared ExtResource IDs in {path.relative_to(ROOT)}: {missing_ext}")

    sub_declared = set(SUB_DECL_PATTERN.findall(text))
    sub_used = set(SUB_USE_PATTERN.findall(text))
    missing_sub = sorted(sub_used - sub_declared)
    if missing_sub:
        fail(f"Undeclared SubResource IDs in {path.relative_to(ROOT)}: {missing_sub}")


def source_files(suffix: str) -> list[Path]:
    return [p for p in ROOT.rglob(f"*{suffix}") if ".godot" not in p.parts]


def main() -> int:
    for rel in REQUIRED:
        if not (ROOT / rel).exists():
            fail(f"Missing required file: {rel}")

    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = MAIN_SCENE_PATTERN.search(project_text)
    if not match:
        fail("project.godot has no run/main_scene")
    main_rel = match.group(1).removeprefix("res://")
    if not (ROOT / main_rel).exists():
        fail(f"Main scene does not exist: {main_rel}")

    broken: list[str] = []
    resource_files = source_files(".tscn") + source_files(".tres")
    for path in resource_files:
        text = path.read_text(encoding="utf-8")
        for res_path in RESOURCE_PATTERN.findall(text):
            rel = res_path.removeprefix("res://")
            if not (ROOT / rel).exists():
                broken.append(f"{path.relative_to(ROOT)} -> {res_path}")
        validate_resource_ids(path, text)
    if broken:
        fail("Broken resource references:\n  " + "\n  ".join(broken))

    for res_path in PROJECT_RESOURCE_PATTERN.findall(project_text):
        rel = res_path.removeprefix("res://")
        if not (ROOT / rel).exists():
            fail(f"Broken project.godot resource reference: {res_path}")

    assert_contains(project_text, 'window/handheld/orientation=0', "landscape orientation baseline")
    assert_contains(project_text, 'window/frame_pacing/android/enable_frame_pacing=true', "Android frame pacing")
    assert_contains(project_text, 'window/stretch/aspect="expand"', "wide-screen stretch aspect")
    assert_contains(project_text, 'common/physics_ticks_per_second=60', "60 Hz physics baseline")
    assert_contains(project_text, 'renderer/rendering_method.mobile="gl_compatibility"', "Android compatibility renderer")
    assert_contains(project_text, '3d_physics/layer_4="Interactable"', "Interactable physics layer")
    assert_contains(project_text, 'pointing/emulate_touch_from_mouse=true', "desktop touch emulation hook")
    assert_contains(project_text, 'pointing/emulate_mouse_from_touch=false', "duplicate touch-to-mouse suppression")
    assert_contains(project_text, 'ItemDB="*res://scripts/inventory/item_database.gd"', "central ItemDB autoload")
    assert_contains(project_text, 'GridDB="*res://scripts/grids/grid_registry.gd"', "central GridDB autoload")
    assert_contains(project_text, 'BlockDB="*res://scripts/blocks/block_database.gd"', "central BlockDB autoload")

    for action in [
        "move_forward", "move_backward", "move_left", "move_right",
        "jump", "sprint", "interact", "build_place", "build_rotate", "build_remove", "vehicle_exit", "vehicle_thrust_forward", "vehicle_thrust_backward", "vehicle_thrust_left", "vehicle_thrust_right", "vehicle_thrust_up", "vehicle_thrust_down", "vehicle_pitch_up", "vehicle_pitch_down", "vehicle_yaw_left", "vehicle_yaw_right", "vehicle_roll_left", "vehicle_roll_right", "ship_terminal", "toggle_mouse_capture",
    ]:
        assert_contains(project_text, f"{action}={{", f"InputMap action {action}")

    export_text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    assert_contains(export_text, 'platform="Android"', "Android export preset")
    assert_contains(export_text, 'architectures/arm64-v8a=true', "ARM64 Android architecture")
    assert_contains(export_text, 'permissions/internet=false', "explicit offline Android permission policy")
    assert_contains(export_text, 'version/code=31', "Stage 31 Android version code")
    assert_contains(export_text, 'version/name="0.0.31-stage31"', "Stage 31 Android version name")
    assert_contains(export_text, 'export_path="builds/android/voidforge-stage31-debug.apk"', "Stage 31 Android export filename")

    config_text = (ROOT / "scripts/core/game_config.gd").read_text(encoding="utf-8")
    assert_contains(config_text, "const BUILD_STAGE: int = 31", "Stage 31 build constant")
    assert_contains(config_text, 'const BUILD_VERSION: String = "0.0.31-stage31"', "Stage 31 build version")
    assert_contains(config_text, 'const TARGET_ENGINE: String = "Godot 4.7.2"', "reference engine version")

    main_scene = (ROOT / "scenes/core/main.tscn").read_text(encoding="utf-8")
    assert_contains(main_scene, 'path="res://scenes/tests/stage31_hand_drill_test.tscn"', "Stage 31 hand-drill integration world")
    assert_contains(main_scene, 'path="res://scenes/ui/interaction_prompt.tscn"', "target prompt retained")
    assert_contains(main_scene, 'path="res://scenes/ui/mobile_touch_controls.tscn"', "touch HUD retained")
    assert_contains(main_scene, 'path="res://scenes/ui/hotbar_ui.tscn"', "Stage 8 hotbar HUD")
    assert_contains(main_scene, 'path="res://scenes/ui/ship_terminal_ui.tscn"', "Stage 30 configurable ship terminal HUD")

    player_scene = (ROOT / "scenes/player/first_person_player.tscn").read_text(encoding="utf-8")
    assert_contains(player_scene, 'path="res://scripts/inventory/inventory_component.gd"', "player inventory component script")
    assert_contains(player_scene, '[node name="Inventory" type="Node" parent="."]', "player-owned inventory node")
    assert_contains(player_scene, 'capacity_l = 120.0', "player inventory capacity")
    assert_contains(player_scene, 'max_stacks = 24', "player inventory stack capacity")
    assert_contains(player_scene, 'path="res://scripts/player/hotbar_component.gd"', "player hotbar component script")
    assert_contains(player_scene, '[node name="Hotbar" type="Node" parent="."]', "player-owned hotbar node")
    assert_contains(player_scene, 'slot_count = 8', "eight-slot hotbar baseline")
    assert_contains(player_scene, 'path="res://scripts/building/block_placement_controller.gd"', "player build controller")
    assert_contains(player_scene, '[node name="BuildController" type="Node3D" parent="."]', "player-owned build controller node")
    assert_contains(player_scene, 'path="res://data/blocks/dev_hull_frame.tres"', "Stage 10 prototype block definition")
    assert_contains(player_scene, 'build_block_id = &"dev_hull_frame"', "Stage 14 stable build-block ID")

    item_definition = (ROOT / "scripts/inventory/item_definition.gd").read_text(encoding="utf-8")
    for contract in [
        'unit_mass_kg: float',
        'unit_volume_l: float',
        'stack_limit: int',
        'func is_valid_definition() -> bool:',
        'func get_validation_errors() -> Array[String]:',
    ]:
        assert_contains(item_definition, contract, "item definition inventory contract")

    inventory = (ROOT / "scripts/inventory/inventory_component.gd").read_text(encoding="utf-8")
    for contract in [
        'capacity_l: float = 120.0',
        'max_stacks: int = 24',
        'func get_item_count(',
        'func get_used_volume_l() -> float:',
        'func get_total_mass_kg() -> float:',
        'func get_addable_quantity(',
        'func add_item(',
        'func remove_item(',
        'func transfer_to(',
        'func resolve_definition(',
        'func can_add_by_id(',
        'func add_item_by_id(',
        'requested_quantity <= 0',
        '_has_definition_conflict',
    ]:
        assert_contains(inventory, contract, "Stage 6 inventory behavior")

    stack = (ROOT / "scripts/inventory/item_stack.gd").read_text(encoding="utf-8")
    assert_contains(stack, '@export var item_id: StringName', "stable stack item ID")
    assert_contains(stack, '@export_range(0,', "non-negative stack quantity schema")

    item_database = (ROOT / "scripts/inventory/item_database.gd").read_text(encoding="utf-8")
    for contract in [
        'const DEFAULT_CATALOG := preload("res://data/items/item_catalog.tres")',
        'func validate_definitions(definitions: Array) -> Array[String]:',
        'func get_item(item_id: StringName) -> Resource:',
        'func get_items_by_category(category: StringName) -> Array[Resource]:',
        'func get_items_with_tag(tag: StringName) -> Array[Resource]:',
        'Duplicate item ID',
    ]:
        assert_contains(item_database, contract, "Stage 7 item database behavior")

    catalog_script = (ROOT / "scripts/inventory/item_catalog.gd").read_text(encoding="utf-8")
    assert_contains(catalog_script, '@export var items: Array[Resource] = []', "explicit item catalog manifest")

    catalog = (ROOT / "data/items/item_catalog.tres").read_text(encoding="utf-8")
    item_paths = sorted(p for p in (ROOT / "data/items").rglob("*.tres") if p.name != "item_catalog.tres")
    if len(item_paths) != 21:
        fail(f"Expected 21 production item resources after Stage 31, found {len(item_paths)}")
    if catalog.count('path="res://data/items/') != 21:
        fail("Item catalog must reference all 21 production item resources exactly once")

    player_script = (ROOT / "scripts/player/first_person_player.gd").read_text(encoding="utf-8")
    assert_contains(player_script, '@onready var inventory: Node = $Inventory', "player inventory ownership")
    assert_contains(player_script, 'func get_inventory() -> Node:', "player inventory accessor")
    assert_contains(player_script, '@onready var hotbar: Node = $Hotbar', "player hotbar ownership")
    assert_contains(player_script, 'func get_hotbar() -> Node:', "player hotbar accessor")

    smoke_scene = (ROOT / "scenes/tests/stage6_inventory_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(smoke_scene, 'path="res://tests/stage6_inventory_smoke_test.gd"', "Stage 6 smoke-test script")

    stage7_smoke_scene = (ROOT / "scenes/tests/stage7_item_database_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage7_smoke_scene, 'path="res://tests/stage7_item_database_smoke_test.gd"', "Stage 7 smoke-test script")


    hotbar = (ROOT / "scripts/player/hotbar_component.gd").read_text(encoding="utf-8")
    for contract in [
        'const HOTBAR_STATE_VERSION: int = 1',
        'slot_count: int = 8',
        'func assign_item(',
        'func clear_slot(',
        'func select_slot(',
        'func select_next()',
        'func select_previous()',
        'func get_state() -> Dictionary:',
        'func load_state(state: Dictionary) -> bool:',
        'func get_slot_quantity(',
        'func is_slot_available(',
        '_is_known_item',
    ]:
        assert_contains(hotbar, contract, "Stage 8 hotbar behavior")

    hotbar_ui = (ROOT / "scripts/ui/hotbar_ui.gd").read_text(encoding="utf-8")
    assert_contains(hotbar_ui, 'func bind_hotbar(hotbar: Node) -> void:', "hotbar UI binding")
    assert_contains(hotbar_ui, 'func get_slot_control(slot_index: int) -> Control:', "touch slot exposure")
    slot_button = (ROOT / "scripts/ui/hotbar_slot_button.gd").read_text(encoding="utf-8")
    assert_contains(slot_button, 'func handle_screen_event(event: InputEvent) -> bool:', "touch hotbar selection")

    touch_controls = (ROOT / "scripts/input/mobile_touch_controls.gd").read_text(encoding="utf-8")
    assert_contains(touch_controls, 'func exclude_look_control(control: Control) -> void:', "hotbar/look touch exclusion bridge")
    assert_contains(touch_controls, '@onready var build_button: Control = $BuildButton', "Stage 10 mobile BUILD button binding")
    assert_contains(touch_controls, '@onready var rotate_button: Control = $RotateButton', "Stage 11 mobile ROT button binding")
    assert_contains(touch_controls, '@onready var remove_button: Control = $RemoveButton', "Stage 12 mobile RMV button binding")
    assert_contains(touch_controls, '@onready var exit_seat_button: Control = $ExitSeatButton', "Stage 20 mobile EXIT button binding")
    assert_contains(touch_controls, '@onready var thrust_button: Control = $ThrustButton', "Stage 21 mobile THR button binding")
    assert_contains(touch_controls, '@onready var thrust_up_button: Control = $ThrustUpButton', "Stage 22 mobile UP button binding")
    assert_contains(touch_controls, '@onready var thrust_down_button: Control = $ThrustDownButton', "Stage 22 mobile DN button binding")
    assert_contains(touch_controls, '@onready var rotation_joystick: Control = $RotationJoystick', "Stage 24 right rotation joystick binding")
    assert_contains(touch_controls, '@onready var roll_left_button: Control = $RollLeftButton', "Stage 24 roll-left button binding")
    assert_contains(touch_controls, '@onready var roll_right_button: Control = $RollRightButton', "Stage 24 roll-right button binding")
    assert_contains(touch_controls, 'vehicle_yaw_left', "Stage 24 right-stick yaw binding")
    assert_contains(touch_controls, 'vehicle_pitch_up', "Stage 24 right-stick pitch binding")
    assert_contains(touch_controls, 'func get_mobile_control_state() -> Dictionary:', "Stage 24 mobile control diagnostics")
    assert_contains(touch_controls, 'vehicle_thrust_left', "Stage 22 vehicle joystick left binding")
    assert_contains(touch_controls, 'vehicle_thrust_backward', "Stage 22 vehicle joystick backward binding")
    assert_contains(touch_controls, 'control_mode_changed', "Stage 20 contextual touch controls")

    touch_scene = (ROOT / "scenes/ui/mobile_touch_controls.tscn").read_text(encoding="utf-8")
    assert_contains(touch_scene, '[node name="BuildButton" type="Control" parent="."]', "mobile BUILD button node")
    assert_contains(touch_scene, 'action_name = &"build_place"', "BUILD button shared InputMap action")
    assert_contains(touch_scene, '[node name="RotateButton" type="Control" parent="."]', "mobile ROT button node")
    assert_contains(touch_scene, 'action_name = &"build_rotate"', "ROT button shared InputMap action")
    assert_contains(touch_scene, '[node name="RemoveButton" type="Control" parent="."]', "mobile RMV button node")
    assert_contains(touch_scene, 'action_name = &"build_remove"', "RMV button shared InputMap action")
    assert_contains(touch_scene, '[node name="ExitSeatButton" type="Control" parent="."]', "mobile EXIT button node")
    assert_contains(touch_scene, 'action_name = &"vehicle_exit"', "EXIT button shared InputMap action")
    assert_contains(touch_scene, '[node name="ThrustUpButton" type="Control" parent="."]', "Stage 22 mobile UP button node")
    assert_contains(touch_scene, 'action_name = &"vehicle_thrust_up"', "UP button shared InputMap action")
    assert_contains(touch_scene, '[node name="ThrustDownButton" type="Control" parent="."]', "Stage 22 mobile DN button node")
    assert_contains(touch_scene, 'action_name = &"vehicle_thrust_down"', "DN button shared InputMap action")
    assert_contains(touch_scene, '[node name="RotationJoystick" type="Control" parent="."]', "Stage 24 right rotation joystick node")
    assert_contains(touch_scene, 'move_left_action = &"vehicle_yaw_left"', "Stage 24 rotation joystick yaw-left action")
    assert_contains(touch_scene, 'move_forward_action = &"vehicle_pitch_up"', "Stage 24 rotation joystick pitch-up action")
    assert_contains(touch_scene, 'dead_zone = 0.18', "Stage 24 rotation joystick dead zone")
    assert_contains(touch_scene, '[node name="RollLeftButton" type="Control" parent="."]', "Stage 24 roll-left button node")
    assert_contains(touch_scene, 'action_name = &"vehicle_roll_left"', "Stage 24 roll-left shared action")
    assert_contains(touch_scene, '[node name="RollRightButton" type="Control" parent="."]', "Stage 24 roll-right button node")
    assert_contains(touch_scene, 'action_name = &"vehicle_roll_right"', "Stage 24 roll-right shared action")

    touch_button = (ROOT / "scripts/input/touch_action_button.gd").read_text(encoding="utf-8")
    assert_contains(touch_button, 'not event.pressed and event.index == _active_touch_id', "Stage 24 hidden-context touch release safety")

    stage8_smoke_scene = (ROOT / "scenes/tests/stage8_hotbar_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage8_smoke_scene, 'path="res://tests/stage8_hotbar_smoke_test.gd"', "Stage 8 smoke-test script")

    grid_profile = (ROOT / "scripts/grids/grid_profile.gd").read_text(encoding="utf-8")
    for contract in [
        '@export_range(0.05, 10.0, 0.05, "or_greater") var cell_size_m: float = 1.0',
        'func get_validation_errors() -> Array[String]:',
        'id not in [&"small", &"large", &"static"]',
    ]:
        assert_contains(grid_profile, contract, "Stage 9 grid profile contract")

    grid_registry = (ROOT / "scripts/grids/grid_registry.gd").read_text(encoding="utf-8")
    for contract in [
        'SMALL_PROFILE := preload("res://data/grids/small_grid_profile.tres")',
        'LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")',
        'STATIC_PROFILE := preload("res://data/grids/static_grid_profile.tres")',
        'func get_profile(profile_id: StringName) -> Resource:',
        'func is_database_valid() -> bool:',
    ]:
        assert_contains(grid_registry, contract, "Stage 9 GridDB behavior")

    block_instance = (ROOT / "scripts/grids/block_instance_data.gd").read_text(encoding="utf-8")
    for contract in [
        '@export var instance_id: int = 0',
        '@export var block_id: StringName',
        '@export var anchor_cell: Vector3i = Vector3i.ZERO',
        'func get_occupied_cells() -> Array[Vector3i]:',
        'func get_state() -> Dictionary:',
        '@export_range(0, 23, 1) var orientation_index: int = 0',
        'func get_orientation_basis() -> Basis:',
        'func get_oriented_dimensions_cells() -> Vector3i:',
    ]:
        assert_contains(block_instance, contract, "Stage 9/11 block-instance state")

    block_grid = (ROOT / "scripts/grids/block_grid.gd").read_text(encoding="utf-8")
    for contract in [
        'var _cells: Dictionary = {}',
        'var _instances: Dictionary = {}',
        'func can_place_block(block_definition: Resource, anchor_cell: Vector3i, orientation_index: int = 0) -> bool:',
        'func place_block(block_definition: Resource, anchor_cell: Vector3i, orientation_index: int = 0) -> Resource:',
        'func remove_block_at(cell: Vector3i) -> Resource:',
        'func grid_to_world(cell: Vector3i) -> Vector3:',
        'func world_to_grid(world_position: Vector3) -> Vector3i:',
        'func get_occupied_neighbor_blocks(cell: Vector3i) -> Array[Resource]:',
        'func get_cell_bounds() -> Dictionary:',
        'func get_integrity_errors() -> Array[String]:',
    ]:
        assert_contains(block_grid, contract, "Stage 9 sparse grid behavior")

    stage9_smoke_scene = (ROOT / "scenes/tests/stage9_grid_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage9_smoke_scene, 'path="res://tests/stage9_grid_smoke_test.gd"', "Stage 9 smoke-test script")


    grid_presenter = (ROOT / "scripts/grids/block_grid_presenter.gd").read_text(encoding="utf-8")
    for contract in [
        'const GRID_COLLISION_LAYER: int = 1 << 2',
        'func get_presented_block_count() -> int:',
        'body.set_meta("voidforge_block_grid", _grid)',
        'BoxShape3D.new()',
    ]:
        assert_contains(grid_presenter, contract, "Stage 10 grid presentation contract")

    build_controller = (ROOT / "scripts/building/block_placement_controller.gd").read_text(encoding="utf-8")
    for contract in [
        'placement_range_m: float = 12.0',
        'func refresh_targeting() -> void:',
        'func attempt_place() -> Resource:',
        'func compute_attachment_cell(',
        'func compute_grid_face(',
        'Input.is_action_just_pressed("build_place")',
        'can_place_block',
    ]:
        assert_contains(build_controller, contract, "Stage 10 placement controller behavior")

    ghost_script = (ROOT / "scripts/building/placement_ghost.gd").read_text(encoding="utf-8")
    for contract in [
        'var _edge_immediate: ImmediateMesh',
        'func set_preview(size_m: Vector3, placement_valid: bool) -> void:',
        'func is_placement_valid() -> bool:',
        'Mesh.PRIMITIVE_LINES',
    ]:
        assert_contains(ghost_script, contract, "Stage 10 holographic ghost behavior")

    dev_block = (ROOT / "data/blocks/dev_hull_frame.tres").read_text(encoding="utf-8")
    assert_contains(dev_block, 'id = &"dev_hull_frame"', "Stage 10 development block ID")
    assert_contains(dev_block, 'dimensions_cells = Vector3i(1, 1, 1)', "Stage 10 development block cell size")

    stage10_smoke_scene = (ROOT / "scenes/tests/stage10_block_placement_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage10_smoke_scene, 'path="res://tests/stage10_block_placement_smoke_test.gd"', "Stage 10 smoke-test script")

    orientation = (ROOT / "scripts/grids/block_orientation.gd").read_text(encoding="utf-8")
    for contract in [
        "const ORIENTATION_COUNT: int = 24",
        "static func get_basis(index: int) -> Basis:",
        "static func get_oriented_dimensions(base_dimensions: Vector3i, index: int) -> Vector3i:",
        "static func rotate_index_around_axis(index: int, axis: Vector3i, quarter_turns: int = 1) -> int:",
    ]:
        assert_contains(orientation, contract, "Stage 11 discrete orientation contract")

    build_controller = (ROOT / "scripts/building/block_placement_controller.gd").read_text(encoding="utf-8")
    for contract in [
        'signal orientation_changed(orientation_index: int)',
        'Input.is_action_just_pressed("build_rotate")',
        'func rotate_preview_clockwise() -> int:',
        'func get_orientation_index() -> int:',
        'func get_oriented_dimensions_cells() -> Vector3i:',
        'place_block", build_block_definition, _target_cell, _orientation_index',
    ]:
        assert_contains(build_controller, contract, "Stage 11 placement rotation behavior")

    presenter = (ROOT / "scripts/grids/block_grid_presenter.gd").read_text(encoding="utf-8")
    assert_contains(presenter, 'instance.call("get_orientation_basis")', "presenter orientation preservation")
    assert_contains(presenter, 'instance.call("get_oriented_dimensions_cells")', "presenter rotated footprint centering")

    span_block = (ROOT / "data/blocks/dev_span_frame.tres").read_text(encoding="utf-8")
    assert_contains(span_block, 'id = &"dev_span_frame"', "Stage 11 development Span Frame ID")
    assert_contains(span_block, 'dimensions_cells = Vector3i(2, 1, 1)', "Stage 11 non-cubic rotation test block")

    stage11_scene = (ROOT / "scenes/tests/stage11_block_rotation_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage11_scene, 'path="res://scripts/world/stage11_block_rotation_test.gd"', "Stage 11 integration wrapper")
    stage11_smoke_scene = (ROOT / "scenes/tests/stage11_block_rotation_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage11_smoke_scene, 'path="res://tests/stage11_block_rotation_smoke_test.gd"', "Stage 11 smoke-test script")

    removal_highlight = (ROOT / "scripts/building/removal_highlight.gd").read_text(encoding="utf-8")
    for contract in [
        'func set_target(size_m: Vector3) -> void:',
        'func clear_target() -> void:',
        'Mesh.PRIMITIVE_LINES',
        'const EDGE_COLOR := Color',
    ]:
        assert_contains(removal_highlight, contract, "Stage 12 removal highlight feedback")

    build_controller = (ROOT / "scripts/building/block_placement_controller.gd").read_text(encoding="utf-8")
    for contract in [
        'signal removal_target_changed(grid: Node3D, instance_id: int)',
        'signal block_removed(grid: Node3D, instance: Resource)',
        'signal removal_failed(reason: String)',
        'Input.is_action_just_pressed("build_remove")',
        'func attempt_remove() -> Resource:',
        'func get_removal_target_instance_id() -> int:',
        'voidforge_block_instance_id',
        'remove_block_by_instance_id',
    ]:
        assert_contains(build_controller, contract, "Stage 12 targeted removal behavior")

    project_input = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert_contains(project_input, 'build_remove={', "Stage 12 build_remove InputMap action")

    stage12_scene = (ROOT / "scenes/tests/stage12_block_removal_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage12_scene, 'path="res://scripts/world/stage12_block_removal_test.gd"', "Stage 12 integration wrapper")
    stage12_smoke_scene = (ROOT / "scenes/tests/stage12_block_removal_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage12_smoke_scene, 'path="res://tests/stage12_block_removal_smoke_test.gd"', "Stage 12 smoke-test script")

    block_instance = (ROOT / "scripts/grids/block_instance_data.gd").read_text(encoding="utf-8")
    for contract in [
        'func get_save_state() -> Dictionary:',
        '"anchor_cell": [anchor_cell.x, anchor_cell.y, anchor_cell.z]',
        '"dimensions_cells": [dimensions_cells.x, dimensions_cells.y, dimensions_cells.z]',
    ]:
        assert_contains(block_instance, contract, "Stage 13 JSON-friendly block persistence")

    block_grid = (ROOT / "scripts/grids/block_grid.gd").read_text(encoding="utf-8")
    for contract in [
        'signal grid_reloaded(block_count: int, occupied_cell_count: int)',
        'const GRID_SAVE_SCHEMA: String = "voidforge.block_grid"',
        'const GRID_SAVE_VERSION: int = 3',
        'func get_save_state() -> Dictionary:',
        'func load_save_state(state: Dictionary) -> bool:',
        'func get_next_instance_id() -> int:',
        'func _prepare_load_state(state: Dictionary) -> Dictionary:',
        'Duplicate block instance ID',
        'overlaps occupied cell',
    ]:
        assert_contains(block_grid, contract, "Stage 13 transactional grid persistence")

    presenter = (ROOT / "scripts/grids/block_grid_presenter.gd").read_text(encoding="utf-8")
    assert_contains(presenter, 'func _on_grid_reloaded(_block_count: int, _occupied_cell_count: int) -> void:', "Stage 13 presenter reload hook")

    stage13_scene = (ROOT / "scenes/tests/stage13_grid_save_load_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage13_scene, 'path="res://scripts/world/stage13_grid_save_load_test.gd"', "Stage 13 integration wrapper")
    stage13_smoke_scene = (ROOT / "scenes/tests/stage13_grid_save_load_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage13_smoke_scene, 'path="res://tests/stage13_grid_save_load_smoke_test.gd"', "Stage 13 smoke-test script")

    block_definition = (ROOT / "scripts/blocks/block_definition.gd").read_text(encoding="utf-8")
    for contract in [
        'build_cost: Array[Resource] = []',
        'construction_stages: int = 1',
        'functional_type: StringName = &"structural"',
        'attachment_faces_mask: int = ATTACHMENT_ALL',
        'func get_validation_errors(item_db: Node = null) -> Array[String]:',
        'func allows_grid(grid_id: StringName) -> bool:',
        'func get_build_cost_quantity(item_id: StringName) -> int:',
    ]:
        assert_contains(block_definition, contract, "Stage 14 block-definition metadata contract")

    block_database = (ROOT / "scripts/blocks/block_database.gd").read_text(encoding="utf-8")
    for contract in [
        'const DEFAULT_CATALOG := preload("res://data/blocks/block_catalog.tres")',
        'func validate_definitions(definitions: Array) -> Array[String]:',
        'func get_block(block_id: StringName) -> Resource:',
        'func get_blocks_by_category(category: StringName) -> Array[Resource]:',
        'func get_blocks_with_tag(tag: StringName) -> Array[Resource]:',
        'func validate_instance_state(instance: Resource, grid_profile_id: StringName) -> Array[String]:',
        'Duplicate block ID',
    ]:
        assert_contains(block_database, contract, "Stage 14 BlockDB behavior")

    block_catalog = (ROOT / "data/blocks/block_catalog.tres").read_text(encoding="utf-8")
    if block_catalog.count('path="res://data/blocks/dev_') != 2:
        fail("Stage 14 block catalog must reference both development block definitions")
    assert_contains(block_grid, 'BlockDB.call("validate_instance_state", instance, profile_id)', "catalog-backed grid load validation")
    assert_contains(build_controller, 'func set_build_block_id(block_id: StringName) -> bool:', "stable-ID construction selection")
    assert_contains(build_controller, 'BlockDB.call("get_block", block_id)', "construction resolution through BlockDB")

    stage14_scene = (ROOT / "scenes/tests/stage14_block_database_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage14_scene, 'path="res://scripts/world/stage14_block_database_test.gd"', "Stage 14 integration wrapper")
    stage14_smoke_scene = (ROOT / "scenes/tests/stage14_block_database_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage14_smoke_scene, 'path="res://tests/stage14_block_database_smoke_test.gd"', "Stage 14 smoke-test script")

    for contract in [
        'variant_group: StringName',
        'variant_key: StringName',
        'variant_order: int = 0',
        'presentation_shape: StringName = &"box"',
        'presentation_scale: Vector3 = Vector3.ONE',
        'presentation_material_id: StringName = &"structure_frame"',
        'VALID_PRESENTATION_SHAPES',
    ]:
        assert_contains(block_definition, contract, "Stage 15 structural variant/presentation metadata")
    assert_contains(block_database, 'func get_blocks_by_variant_group(variant_group: StringName) -> Array[Resource]:', "Stage 15 variant-group query")
    assert_contains(block_database, 'Duplicate variant key', "Stage 15 duplicate variant protection")
    if block_catalog.count('path="res://data/blocks/structure/') != 9:
        fail("Stage 15 catalog must reference nine production structure definitions")
    if block_catalog.count('path="res://data/blocks/armor/') != 6:
        fail("Stage 15 catalog must reference six production armor definitions")
    if block_catalog.count('path="res://data/blocks/control/') != 2:
        fail("Stage 23 catalog must reference the Pilot Cradle and Vector Gyro control definitions")
    if block_catalog.count('path="res://data/blocks/propulsion/') != 1:
        fail("Stage 21 catalog must reference exactly one production thruster definition")
    for contract in [
        'func get_block_presentation_shape(instance_id: int) -> StringName:',
        'func get_block_visual_count(instance_id: int) -> int:',
        'func _create_unit_wedge_mesh() -> ArrayMesh:',
        'func _append_frame_primitives(',
        'func _append_grating_primitives(',
        'func _append_corner_primitives(',
    ]:
        assert_contains(presenter, contract, "Stage 15 structural placeholder presentation retained by batching")
    stage15_scene = (ROOT / "scenes/tests/stage15_structural_library_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage15_scene, 'path="res://scripts/world/stage15_structural_library_test.gd"', "Stage 15 integration wrapper")
    stage15_smoke_scene = (ROOT / "scenes/tests/stage15_structural_library_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage15_smoke_scene, 'path="res://tests/stage15_structural_library_smoke_test.gd"', "Stage 15 smoke-test script")

    for contract in [
        'var _batch_nodes: Dictionary = {}',
        'var _geometry_dirty: bool = false',
        'func flush_geometry_now() -> void:',
        'func get_batch_count() -> int:',
        'func get_render_instance_count() -> int:',
        'func get_geometry_rebuild_count() -> int:',
        'func _rebuild_batched_geometry() -> void:',
        'MultiMeshInstance3D.new()',
        'MultiMesh.TRANSFORM_3D',
        'func _append_block_render_primitives(',
    ]:
        assert_contains(presenter, contract, "Stage 16 cached/batched grid renderer")
    stage16_scene = (ROOT / "scenes/tests/stage16_grid_geometry_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage16_scene, 'path="res://scripts/world/stage16_grid_geometry_test.gd"', "Stage 16 integration wrapper")
    assert_contains(stage16_scene, 'render_collision = false', "Stage 16 collision-free render stress grid")
    stage16_smoke_scene = (ROOT / "scenes/tests/stage16_grid_geometry_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage16_smoke_scene, 'path="res://tests/stage16_grid_geometry_smoke_test.gd"', "Stage 16 smoke-test script")

    for contract in [
        'var _collision_body: CollisionObject3D',
        'var _collision_owner_to_instance: Dictionary = {}',
        'var _collision_instance_to_owner: Dictionary = {}',
        'var _collision_shape_cache: Dictionary = {}',
        'func flush_collision_now() -> void:',
        'func get_collision_shape_count() -> int:',
        'func get_runtime_collision_node_count() -> int:',
        'func resolve_block_instance_id_for_shape(shape_index: int) -> int:',
        'func _rebuild_grid_collision() -> void:',
        'create_shape_owner(self)',
        'shape_owner_set_transform',
        'func _cached_box_shape(size: Vector3) -> BoxShape3D:',
        'func _cached_wedge_shape(size: Vector3) -> ConvexPolygonShape3D:',
    ]:
        assert_contains(presenter, contract, "Stage 17 cached grid collision")
    assert_contains(build_controller, 'var hit_shape_index := int(hit.get("shape", -1))', "Stage 17 shape-aware build ray")
    assert_contains(build_controller, 'voidforge_grid_collision_presenter', "Stage 17 shape-to-instance targeting resolver")
    stage17_scene = (ROOT / "scenes/tests/stage17_grid_collision_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage17_scene, 'path="res://scripts/world/stage17_grid_collision_test.gd"', "Stage 17 integration wrapper")
    stage17_smoke_scene = (ROOT / "scenes/tests/stage17_grid_collision_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage17_smoke_scene, 'path="res://tests/stage17_grid_collision_smoke_test.gd"', "Stage 17 smoke-test script")

    block_grid = (ROOT / "scripts/grids/block_grid.gd").read_text(encoding="utf-8")
    for contract in [
        "extends RigidBody3D",
        "signal simulation_mode_changed(dynamic_enabled: bool)",
        "func can_be_dynamic() -> bool:",
        "func is_dynamic_simulation_enabled() -> bool:",
        "func set_dynamic_simulation_enabled(enabled: bool, wake_body: bool = true) -> bool:",
        "func get_motion_state() -> Dictionary:",
        "func sleep_grid() -> bool:",
        "func wake_grid() -> bool:",
        "freeze = true",
    ]:
        assert_contains(block_grid, contract, "Stage 18 dynamic grid physics")
    assert_contains(presenter, '_collision_body = _grid as CollisionObject3D', "Stage 18 grid-as-physics-body collision")
    prototype_scene = (ROOT / "scenes/grids/prototype_block_grid.tscn").read_text(encoding="utf-8")
    assert_contains(prototype_scene, '[node name="PrototypeBlockGrid" type="RigidBody3D"]', "Stage 18 rigid-body prototype grid scene")
    stage18_scene = (ROOT / "scenes/tests/stage18_dynamic_grid_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage18_scene, 'path="res://scripts/world/stage18_dynamic_grid_test.gd"', "Stage 18 integration wrapper")
    assert_contains(stage18_scene, '[node name="DynamicGrid" type="RigidBody3D" parent="."]', "Stage 18 dynamic demo rigid body")
    stage18_smoke_scene = (ROOT / "scenes/tests/stage18_dynamic_grid_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage18_smoke_scene, 'path="res://tests/stage18_dynamic_grid_smoke_test.gd"', "Stage 18 smoke-test script")

    for contract in [
        "signal mass_changed(total_mass_kg: float, physics_mass_kg: float)",
        "const MIN_RIGID_BODY_MASS_KG: float = 0.001",
        "func get_total_mass_kg() -> float:",
        "func get_physics_mass_kg() -> float:",
        "func get_mass_state() -> Dictionary:",
        "func recalculate_mass_from_blocks(emit_signal: bool = true) -> bool:",
        "func get_mass_breakdown_by_block_id() -> Dictionary:",
        "func _calculate_mass_for_instances(instances: Dictionary) -> Dictionary:",
        "mass = maxf(_calculated_mass_kg, MIN_RIGID_BODY_MASS_KG)",
        "_set_calculated_mass(_calculated_mass_kg + placement_mass)",
        '"calculated_mass_kg": float(mass_result["mass_kg"])',
    ]:
        assert_contains(block_grid, contract, "Stage 19 authoritative grid mass")
    if "prototype_dynamic_mass" in block_grid or "set_prototype_dynamic_mass" in block_grid:
        fail("Stage 19 still contains provisional dynamic-mass architecture")
    stage19_scene = (ROOT / "scenes/tests/stage19_ship_mass_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage19_scene, 'path="res://scripts/world/stage19_ship_mass_test.gd"', "Stage 19 integration wrapper")
    assert_contains(stage19_scene, '[node name="MassDemoGrid" type="RigidBody3D" parent="."]', "Stage 19 mass demo rigid body")
    stage19_smoke_scene = (ROOT / "scenes/tests/stage19_ship_mass_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage19_smoke_scene, 'path="res://tests/stage19_ship_mass_smoke_test.gd"', "Stage 19 smoke-test script")

    for contract in [
        "signal pilot_changed(pilot: Node, seat_instance_id: int)",
        "func get_active_pilot() -> Node:",
        "func get_active_control_seat_instance_id() -> int:",
        "func has_valid_control_seat(instance_id: int) -> bool:",
        "func can_claim_manual_control(actor: Node, seat_instance_id: int) -> bool:",
        "func try_claim_manual_control(actor: Node, seat_instance_id: int) -> bool:",
        "func can_receive_manual_control(actor: Node) -> bool:",
        "func release_manual_control(actor: Node) -> bool:",
        '_invalidate_active_pilot("control seat removed")',
    ]:
        assert_contains(block_grid, contract, "Stage 20 grid pilot-authority contract")

    for contract in [
        "signal control_mode_changed(mode: StringName, controlled_grid: Node)",
        "signal control_seat_entered(seat: Node, controlled_grid: Node)",
        "signal control_seat_exited(seat: Node, controlled_grid: Node)",
        'Input.is_action_just_pressed("vehicle_exit")',
        "func is_in_control_seat() -> bool:",
        "func get_controlled_grid() -> Node3D:",
        "func enter_control_seat(seat: Node) -> bool:",
        "func exit_control_seat(force_exit: bool = false) -> bool:",
        'func on_control_seat_invalidated(grid: Node, seat_instance_id: int, _reason: String = "") -> void:',
        "func _sync_to_control_seat() -> void:",
    ]:
        assert_contains(player_script, contract, "Stage 20 seated player-control contract")

    for contract in [
        "const CONTROL_SEAT_PRESENTER_SCRIPT",
        "func get_control_seat_presenter()",
        '&"seat":',
        "func _append_control_seat_primitives(",
        '&"control_console"',
    ]:
        assert_contains(presenter, contract, "Stage 20 seat presentation contract")

    seat_interaction = (ROOT / "scripts/ships/control_seat_interaction.gd").read_text(encoding="utf-8")
    for contract in [
        "class_name ControlSeatInteraction",
        "extends Area3D",
        "const INTERACTABLE_LAYER: int = 1 << 3",
        "func configure(grid: Node3D, instance: Resource, definition: Resource) -> bool:",
        "func can_interact(actor: Node) -> bool:",
        "func interact(actor: Node) -> bool:",
        "func try_claim_pilot(actor: Node) -> bool:",
        "func release_pilot(actor: Node) -> bool:",
        "func get_pilot_body_transform_global() -> Transform3D:",
        "func get_exit_transform_global() -> Transform3D:",
    ]:
        assert_contains(seat_interaction, contract, "Stage 20 control-seat interaction proxy")

    seat_presenter = (ROOT / "scripts/ships/control_seat_presenter.gd").read_text(encoding="utf-8")
    for contract in [
        "class_name ControlSeatPresenter",
        'const CONTROL_SEAT_FUNCTION: StringName = &"control_seat"',
        "func get_control_seat_count() -> int:",
        "func get_control_seat(instance_id: int) -> Area3D:",
        "func flush_now() -> void:",
    ]:
        assert_contains(seat_presenter, contract, "Stage 20 functional seat-proxy presenter")

    pilot_block = (ROOT / "data/blocks/control/pilot_cradle_large.tres").read_text(encoding="utf-8")
    for contract in [
        'id = &"pilot_cradle_large"',
        'category = &"control"',
        'mass_kg = 460.0',
        'functional_type = &"control_seat"',
        'presentation_shape = &"seat"',
        'presentation_material_id = &"control_console"',
    ]:
        assert_contains(pilot_block, contract, "Stage 20 Pilot Cradle block definition")

    stage20_scene = (ROOT / "scenes/tests/stage20_control_seat_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage20_scene, 'path="res://scripts/world/stage20_control_seat_test.gd"', "Stage 20 integration wrapper")
    assert_contains(stage20_scene, '[node name="PilotCraft" type="RigidBody3D" parent="."]', "Stage 20 pilot craft rigid body")
    stage20_smoke_scene = (ROOT / "scenes/tests/stage20_control_seat_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage20_smoke_scene, 'path="res://tests/stage20_control_seat_smoke_test.gd"', "Stage 20 smoke-test script")

    for contract in [
        'thrust_force_n: float = 0.0',
        'thrust_direction_local: Vector3i = Vector3i(0, 0, -1)',
        'functional_type == &"thruster"',
        'func _is_cardinal_direction(value: Vector3i) -> bool:',
    ]:
        assert_contains(block_definition, contract, "Stage 21 propulsion block metadata")
    for contract in [
        'signal propulsion_changed(thruster_count: int, total_rated_thrust_n: float)',
        'func get_thruster_instance_ids() -> Array[int]:',
        'func get_total_rated_thrust_n() -> float:',
        'func get_thruster_local_force_n(instance_id: int) -> Vector3:',
        'func set_manual_thrust_input(actor: Node, strength: float) -> bool:',
        'func get_propulsion_state() -> Dictionary:',
        'apply_central_force(global_transform.basis * force_local)',
    ]:
        assert_contains(block_grid, contract, "Stage 21 grid propulsion contract")
    for contract in [
        'Input.get_action_strength("vehicle_thrust_forward")',
        'func _apply_vehicle_thrust_input() -> void:',
        'clear_manual_thrust_input',
    ]:
        assert_contains(player_script, contract, "Stage 21 seated thrust input contract")
    for contract in [
        '&"thruster":',
        'func _append_thruster_primitives(',
        '&"propulsion":',
        'block_propulsion_material.tres',
    ]:
        assert_contains(presenter, contract, "Stage 21 thruster presentation contract")
    thruster_block = (ROOT / "data/blocks/propulsion/pulse_thruster_large.tres").read_text(encoding="utf-8")
    for contract in [
        'id = &"pulse_thruster_large"',
        'category = &"propulsion"',
        'mass_kg = 520.0',
        'functional_type = &"thruster"',
        'thrust_force_n = 48000.0',
        'thrust_direction_local = Vector3i(0, 0, -1)',
        'presentation_shape = &"thruster"',
        'presentation_material_id = &"propulsion"',
    ]:
        assert_contains(thruster_block, contract, "Stage 21 Pulse Thruster definition")
    stage21_scene = (ROOT / "scenes/tests/stage21_thruster_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage21_scene, 'path="res://scripts/world/stage21_thruster_test.gd"', "Stage 21 integration wrapper")
    assert_contains(stage21_scene, '[node name="ThrustCraft" type="RigidBody3D" parent="."]', "Stage 21 thrust craft rigid body")
    stage21_smoke_scene = (ROOT / "scenes/tests/stage21_thruster_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage21_smoke_scene, 'path="res://tests/stage21_thruster_smoke_test.gd"', "Stage 21 smoke-test script")

    for contract in [
        'func get_directional_rated_thrust_n(direction_local: Vector3i) -> float:',
        'func get_thruster_instance_ids_for_direction(direction_local: Vector3i) -> Array[int]:',
        'func get_directional_thrust_state() -> Dictionary:',
        'func set_manual_translation_input(actor: Node, input_local: Vector3) -> bool:',
        'func get_manual_translation_input_local() -> Vector3:',
        'func get_active_manual_force_local_n() -> Vector3:',
        '_directional_rated_thrust_n',
        '_directional_thruster_instance_ids',
    ]:
        assert_contains(block_grid, contract, "Stage 22 directional thrust contract")
    for action in [
        'vehicle_thrust_backward', 'vehicle_thrust_left', 'vehicle_thrust_right',
        'vehicle_thrust_up', 'vehicle_thrust_down',
    ]:
        assert_contains(player_script, action, "Stage 22 player six-axis input contract")
    joystick = (ROOT / "scripts/input/virtual_joystick.gd").read_text(encoding="utf-8")
    assert_contains(joystick, 'func set_action_bindings(', "Stage 22 contextual joystick action rebinding")
    stage22_scene = (ROOT / "scenes/tests/stage22_directional_thrust_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage22_scene, 'path="res://scripts/world/stage22_directional_thrust_test.gd"', "Stage 22 integration wrapper")
    assert_contains(stage22_scene, '[node name="DirectionalCraft" type="RigidBody3D" parent="."]', "Stage 22 six-axis craft rigid body")
    stage22_smoke_scene = (ROOT / "scenes/tests/stage22_directional_thrust_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage22_smoke_scene, 'path="res://tests/stage22_directional_thrust_smoke_test.gd"', "Stage 22 smoke-test script")

    for contract in [
        'gyro_torque_nm: float = 0.0',
        'functional_type == &"gyroscope"',
        'Gyroscope blocks require positive torque metadata.',
    ]:
        assert_contains(block_definition, contract, "Stage 23 gyroscope block metadata")
    for contract in [
        'signal gyroscope_changed(gyroscope_count: int, total_rated_torque_nm: float)',
        'func get_gyroscope_instance_ids() -> Array[int]:',
        'func get_gyroscope_count() -> int:',
        'func get_total_gyro_torque_nm() -> float:',
        'func set_manual_rotation_input(actor: Node, input_local: Vector3) -> bool:',
        'func get_active_manual_torque_local_nm() -> Vector3:',
        'func get_rotation_control_state() -> Dictionary:',
        'apply_torque(global_transform.basis * torque_local)',
    ]:
        assert_contains(block_grid, contract, "Stage 23 grid gyroscope contract")
    for action in [
        'vehicle_pitch_up', 'vehicle_pitch_down', 'vehicle_yaw_left', 'vehicle_yaw_right', 'vehicle_roll_left', 'vehicle_roll_right',
    ]:
        assert_contains(player_script, action, "Stage 23 player rotational input contract")
    for contract in [
        '&"gyro":',
        'func _append_gyro_primitives(',
        'block_gyro_material.tres',
    ]:
        assert_contains(presenter, contract, "Stage 23 gyro presentation contract")
    gyro_block = (ROOT / "data/blocks/control/vector_gyro_large.tres").read_text(encoding="utf-8")
    for contract in [
        'id = &"vector_gyro_large"',
        'category = &"control"',
        'mass_kg = 610.0',
        'functional_type = &"gyroscope"',
        'gyro_torque_nm = 120000.0',
        'presentation_shape = &"gyro"',
        'presentation_material_id = &"gyro"',
    ]:
        assert_contains(gyro_block, contract, "Stage 23 Vector Gyro definition")
    assert_contains(block_catalog, 'path="res://data/blocks/control/vector_gyro_large.tres"', "Stage 23 gyro catalog entry")
    stage23_scene = (ROOT / "scenes/tests/stage23_gyroscope_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage23_scene, 'path="res://scripts/world/stage23_gyroscope_test.gd"', "Stage 23 integration wrapper")
    assert_contains(stage23_scene, '[node name="GyroCraft" type="RigidBody3D" parent="."]', "Stage 23 gyro craft rigid body")
    stage23_smoke_scene = (ROOT / "scenes/tests/stage23_gyroscope_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage23_smoke_scene, 'path="res://tests/stage23_gyroscope_smoke_test.gd"', "Stage 23 smoke-test script")

    stage24_scene = (ROOT / "scenes/tests/stage24_mobile_ship_control_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage24_scene, 'path="res://scripts/world/stage24_mobile_ship_control.gd"', "Stage 24 integration wrapper")
    assert_contains(stage24_scene, '[node name="MobileControlCraft" type="RigidBody3D" parent="."]', "Stage 24 dual-stick craft rigid body")
    stage24_world = (ROOT / "scripts/world/stage24_mobile_ship_control.gd").read_text(encoding="utf-8")
    assert_contains(stage24_world, 'THRUST_DIRECTIONS: Array[Vector3i]', "Stage 24 six-axis integration craft")
    assert_contains(stage24_world, 'get_total_gyro_torque_nm', "Stage 24 gyro integration diagnostics")
    stage24_smoke_scene = (ROOT / "scenes/tests/stage24_mobile_ship_controls_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage24_smoke_scene, 'path="res://tests/stage24_mobile_ship_controls_smoke_test.gd"', "Stage 24 smoke-test script")


    stage25_scene = (ROOT / "scenes/tests/stage25_power_network_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage25_scene, 'path="res://scripts/world/stage25_power_network.gd"', "Stage 25 integration wrapper")
    assert_contains(stage25_scene, '[node name="PowerCraft" type="RigidBody3D" parent="."]', "Stage 25 powered craft rigid body")
    stage25_smoke_scene = (ROOT / "scenes/tests/stage25_power_network_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage25_smoke_scene, 'path="res://tests/stage25_power_network_smoke_test.gd"', "Stage 25 smoke-test script")
    power_source = (ROOT / "data/blocks/power/dev_power_source_large.tres").read_text(encoding="utf-8")
    for contract in ['id = &"dev_power_source_large"', 'functional_type = &"power_source"', 'power_production_kw = 180.0']:
        assert_contains(power_source, contract, "Stage 25 development power source")
    for contract in [
        'signal power_network_changed(', 'power_network_enabled: bool = true',
        'func get_total_power_generation_kw() -> float:', 'func get_total_rated_power_demand_kw() -> float:',
        'func get_active_power_demand_kw() -> float:', 'func get_power_satisfaction_ratio() -> float:',
        'func get_block_power_state(instance_id: int) -> Dictionary:', 'func get_power_network_state() -> Dictionary:',
        '_power_producer_instance_ids', '_power_consumer_instance_ids', '_mark_power_cache_dirty()',
        'func _get_powered_directional_thrust_n(direction: Vector3i) -> float:',
        'powered_torque_nm += maxf(float(definition.get("gyro_torque_nm")), 0.0) * _get_effective_block_power_satisfaction_ratio(instance_id)',
    ]:
        assert_contains(block_grid, contract, "Stage 25 power-network contract")
    for path, contract in [
        ("data/blocks/control/pilot_cradle_large.tres", "power_use_kw = 6.0"),
        ("data/blocks/propulsion/pulse_thruster_large.tres", "power_use_kw = 120.0"),
        ("data/blocks/control/vector_gyro_large.tres", "power_use_kw = 90.0"),
    ]:
        assert_contains((ROOT / path).read_text(encoding="utf-8"), contract, "Stage 25 consumer power metadata")

    stage26_scene = (ROOT / "scenes/tests/stage26_battery_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage26_scene, 'path="res://scripts/world/stage26_battery.gd"', "Stage 26 integration wrapper")
    assert_contains(stage26_scene, '[node name="BatteryCraft" type="RigidBody3D" parent="."]', "Stage 26 battery craft rigid body")
    stage26_smoke_scene = (ROOT / "scenes/tests/stage26_battery_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage26_smoke_scene, 'path="res://tests/stage26_battery_smoke_test.gd"', "Stage 26 smoke-test script")
    battery_block = (ROOT / "data/blocks/power/flux_reservoir_large.tres").read_text(encoding="utf-8")
    for contract in [
        'id = &"flux_reservoir_large"', 'functional_type = &"battery"',
        'battery_capacity_kwh = 60.0', 'battery_initial_charge_fraction = 0.5',
        'battery_max_charge_kw = 180.0', 'battery_max_discharge_kw = 240.0',
        'presentation_shape = &"battery"', 'presentation_material_id = &"power_storage"',
    ]:
        assert_contains(battery_block, contract, "Stage 26 Flux Reservoir definition")
    for contract in [
        'signal battery_storage_changed(', 'GRID_SAVE_VERSION: int = 3', 'GRID_SAVE_MIN_SUPPORTED_VERSION: int = 1',
        'func get_battery_instance_ids() -> Array[int]:', 'func get_battery_stored_energy_kwh(instance_id: int) -> float:',
        'func set_battery_stored_energy_kwh(instance_id: int, stored_energy_kwh: float) -> bool:',
        'func get_battery_storage_state() -> Dictionary:', 'func get_estimated_battery_runtime_seconds() -> float:',
        'func _advance_battery_storage(delta: float) -> void:', '"battery_states": battery_states',
        'func _prepare_battery_load_state(', '_physics_power_satisfaction_override',
    ]:
        assert_contains(block_grid, contract, "Stage 26 battery runtime contract")
    for contract in ['&"battery":', 'func _append_battery_primitives(', 'block_power_storage_material.tres', '&"power_storage":']:
        assert_contains(presenter, contract, "Stage 26 battery presentation contract")
    assert_contains(block_catalog, 'path="res://data/blocks/power/flux_reservoir_large.tres"', "Stage 26 battery catalog entry")

    stage27_scene = (ROOT / "scenes/tests/stage27_reactor_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage27_scene, 'path="res://scripts/world/stage27_reactor.gd"', "Stage 27 integration wrapper")
    assert_contains(stage27_scene, '[node name="ReactorCraft" type="RigidBody3D" parent="."]', "Stage 27 reactor craft rigid body")
    stage27_smoke_scene = (ROOT / "scenes/tests/stage27_reactor_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage27_smoke_scene, 'path="res://tests/stage27_reactor_smoke_test.gd"', "Stage 27 smoke-test script")
    reactor_block = (ROOT / "data/blocks/power/helix_core_reactor_large.tres").read_text(encoding="utf-8")
    for contract in [
        'id = &"helix_core_reactor_large"', 'functional_type = &"reactor"',
        'power_production_kw = 480.0', 'heat_generation_kw = 145.0', 'mass_kg = 920.0',
        'presentation_shape = &"reactor"', 'presentation_material_id = &"power_generation"',
    ]:
        assert_contains(reactor_block, contract, "Stage 27 Helix Core Reactor definition")
    for contract in ['&"reactor"', 'functional_type == &"reactor"']:
        assert_contains(block_definition, contract, "Stage 27 reactor definition validation")
    for contract in ['&"reactor":', 'func _append_reactor_primitives(', 'block_power_generation_material.tres', '&"power_generation":']:
        assert_contains(presenter, contract, "Stage 27 reactor presentation contract")
    assert_contains(block_catalog, 'path="res://data/blocks/power/helix_core_reactor_large.tres"', "Stage 27 reactor catalog entry")

    for gd in source_files(".gd"):
        text = gd.read_text(encoding="utf-8")
        if "\t " in text:
            fail(f"Suspicious mixed indentation in {gd.relative_to(ROOT)}")
        if "<<<<<<<" in text or ">>>>>>>" in text or "=======" in text:
            fail(f"Merge-conflict marker found in {gd.relative_to(ROOT)}")

    stage28_scene = (ROOT / "scenes/tests/stage28_power_priority_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage28_scene, 'path="res://scripts/world/stage28_power_priority.gd"', "Stage 28 integration wrapper")
    assert_contains(stage28_scene, '[node name="PriorityCraft" type="RigidBody3D" parent="."]', "Stage 28 priority craft rigid body")
    stage28_smoke_scene = (ROOT / "scenes/tests/stage28_power_priority_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage28_smoke_scene, 'path="res://tests/stage28_power_priority_smoke_test.gd"', "Stage 28 smoke-test script")
    aux_block = (ROOT / "data/blocks/power/dev_aux_load_large.tres").read_text(encoding="utf-8")
    for contract in ['id = &"dev_aux_load_large"', 'functional_type = &"auxiliary_load"', 'power_use_kw = 60.0', 'power_priority = 3']:
        assert_contains(aux_block, contract, "Stage 28 development auxiliary load")
    for path, priority in [
        ("data/blocks/control/pilot_cradle_large.tres", 0),
        ("data/blocks/control/vector_gyro_large.tres", 1),
        ("data/blocks/propulsion/pulse_thruster_large.tres", 2),
    ]:
        priority_text = (ROOT / path).read_text(encoding="utf-8")
        assert_contains(priority_text, f"power_priority = {priority}", f"Stage 28 priority metadata in {path}")
    for contract in [
        'priority_load_shedding_enabled: bool = true',
        'func get_block_power_priority(instance_id: int) -> int:',
        'func get_block_allocated_power_kw(instance_id: int) -> float:',
        'func get_block_power_satisfaction_ratio(instance_id: int) -> float:',
        'func _calculate_power_allocation(delta: float = 0.0) -> Dictionary:',
        '"load_shedding_active"', '"priority_tiers"', '"shed_kw"',
    ]:
        assert_contains(block_grid, contract, "Stage 28 priority power-allocation contract")
    assert_contains(block_definition, 'var power_priority: int = POWER_PRIORITY_NORMAL', "Stage 28 data-driven power priority")
    assert_contains(block_definition, 'func get_power_priority_name() -> StringName:', "Stage 28 priority-name helper")
    assert_contains(block_catalog, 'path="res://data/blocks/power/dev_aux_load_large.tres"', "Stage 28 auxiliary-load catalog entry")

    stage29_scene = (ROOT / "scenes/tests/stage29_ship_terminal_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage29_scene, 'path="res://scripts/world/stage29_ship_terminal.gd"', "Stage 29 integration wrapper")
    assert_contains(stage29_scene, '[node name="TerminalCraft" type="RigidBody3D" parent="."]', "Stage 29 terminal craft")
    stage29_terminal_scene = (ROOT / "scenes/ui/ship_terminal_ui.tscn").read_text(encoding="utf-8")
    assert_contains(stage29_terminal_scene, 'path="res://scripts/ui/ship_terminal_ui.gd"', "Stage 29 terminal UI script")
    for contract in ['SearchEdit', 'CategoryList', 'BlockList', 'DetailText', 'PowerSummary', 'BatterySummary']:
        assert_contains(stage29_terminal_scene, contract, "Stage 29 terminal UI control")
    stage29_terminal_script = (ROOT / "scripts/ui/ship_terminal_ui.gd").read_text(encoding="utf-8")
    for contract in [
        'func open_terminal(grid: Node = null) -> bool:',
        'func close_terminal() -> void:',
        'func set_category(category: StringName) -> bool:',
        'func set_search_query(query: String) -> void:',
        'func get_visible_block_instance_ids() -> Array[int]:',
        'func select_block(instance_id: int) -> bool:',
        'func refresh_live_state() -> void:',
        'get_power_network_state', 'get_block_power_state',
    ]:
        assert_contains(stage29_terminal_script, contract, "Stage 29 terminal query contract")
    player_script = (ROOT / "scripts/player/first_person_player.gd").read_text(encoding="utf-8")
    assert_contains(player_script, 'func set_ui_input_locked(locked: bool) -> void:', "Stage 29 gameplay input lock")
    assert_contains(player_script, 'func is_ui_input_locked() -> bool:', "Stage 29 gameplay input-lock query")
    touch_script = (ROOT / "scripts/input/mobile_touch_controls.gd").read_text(encoding="utf-8")
    assert_contains(touch_script, 'func set_external_ui_blocked(blocked: bool) -> void:', "Stage 29 mobile HUD blocker")
    touch_scene = (ROOT / "scenes/ui/mobile_touch_controls.tscn").read_text(encoding="utf-8")
    assert_contains(touch_scene, '[node name="TerminalButton" type="Control" parent="."]', "Stage 29 Android TERM button")
    assert_contains(touch_scene, 'action_name = &"ship_terminal"', "Stage 29 Android terminal action")
    stage29_smoke_scene = (ROOT / "scenes/tests/stage29_ship_terminal_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage29_smoke_scene, 'path="res://tests/stage29_ship_terminal_smoke_test.gd"', "Stage 29 smoke-test script")

    stage30_scene = (ROOT / "scenes/tests/stage30_block_configuration_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage30_scene, 'path="res://scripts/world/stage30_block_configuration.gd"', "Stage 30 integration wrapper")
    assert_contains(stage30_scene, '[node name="Stage29ShipTerminal" parent="." instance=ExtResource', "Stage 30 nested Stage 29 world")
    stage30_smoke_scene = (ROOT / "scenes/tests/stage30_block_configuration_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage30_smoke_scene, 'path="res://tests/stage30_block_configuration_smoke_test.gd"', "Stage 30 smoke-test script")
    for contract in [
        'EnabledToggle', 'CustomNameEdit', 'PriorityOption', 'GroupNameEdit', 'GroupOption',
        'ToggleMembershipButton', 'DeleteGroupButton', 'ConfigStatus',
    ]:
        assert_contains(stage29_terminal_scene, contract, "Stage 30 terminal configuration control")
    for contract in [
        'func set_selected_block_enabled(enabled: bool) -> bool:',
        'func rename_selected_block(custom_name: String) -> bool:',
        'func set_selected_power_priority_override(priority: int) -> bool:',
        'func create_group(group_name: String) -> bool:',
        'func delete_group(group_name: String) -> bool:',
        'func set_selected_block_group_membership(group_name: String, member: bool) -> bool:',
        'func get_group_names() -> Array[String]:',
        'func get_selected_block_configuration() -> Dictionary:',
    ]:
        assert_contains(stage29_terminal_script, contract, "Stage 30 terminal configuration API")
    for contract in [
        'signal block_configuration_changed(instance_id: int)',
        'signal block_groups_changed',
        'func is_block_enabled(instance_id: int) -> bool:',
        'func set_block_enabled(instance_id: int, enabled: bool) -> bool:',
        'func set_block_custom_name(instance_id: int, custom_name: String) -> bool:',
        'func set_block_power_priority_override(instance_id: int, priority: int) -> bool:',
        'func create_block_group(group_name: String) -> bool:',
        'func add_block_to_group(instance_id: int, group_name: String) -> bool:',
        '"block_configurations": block_configurations',
        '"block_groups": group_states',
        'func _prepare_block_configuration_load_state(',
    ]:
        assert_contains(block_grid, contract, "Stage 30 block-configuration persistence/runtime contract")

    stage31_scene = (ROOT / "scenes/tests/stage31_hand_drill_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage31_scene, 'path="res://scripts/world/stage31_hand_drill.gd"', "Stage 31 integration wrapper")
    assert_contains(stage31_scene, 'path="res://scenes/mining/drill_work_target.tscn"', "Stage 31 drill calibration target")
    stage31_smoke = (ROOT / "scenes/tests/stage31_hand_drill_smoke_test.tscn").read_text(encoding="utf-8")
    assert_contains(stage31_smoke, 'path="res://tests/stage31_hand_drill_smoke_test.gd"', "Stage 31 smoke-test script")
    drill_item = (ROOT / "data/items/tools/field_bore_drill.tres").read_text(encoding="utf-8")
    for contract in [
        'id = &"tool_field_bore_drill"', 'category = &"tool"', 'tool_type = &"hand_drill"',
        'tool_range_m = 4.5', 'tool_work_rate_per_s = 25.0', 'stack_limit = 1',
    ]:
        assert_contains(drill_item, contract, "Stage 31 Field Bore Drill metadata")
    item_definition = (ROOT / "scripts/inventory/item_definition.gd").read_text(encoding="utf-8")
    for contract in ['@export var tool_type: StringName', 'var tool_range_m: float', 'var tool_work_rate_per_s: float']:
        assert_contains(item_definition, contract, "Stage 31 tool metadata schema")
    drill_controller = (ROOT / "scripts/tools/hand_drill_controller.gd").read_text(encoding="utf-8")
    for contract in [
        'const DRILL_ITEM_ID: StringName = &"tool_field_bore_drill"',
        'const MINEABLE_COLLISION_MASK: int = 64',
        'Input.is_action_pressed("tool_use")',
        'func can_use_equipped_drill() -> bool:',
        'func _probe_target() -> Node:',
        'func _apply_drill_tick(duration_s: float) -> void:',
    ]:
        assert_contains(drill_controller, contract, "Stage 31 held drill controller")
    drill_target = (ROOT / "scripts/tools/drill_work_target.gd").read_text(encoding="utf-8")
    assert_contains(drill_target, 'func can_receive_drill_work(', "Stage 31 drill target capability")
    assert_contains(drill_target, 'func apply_drill_work(', "Stage 31 drill work receiver")
    player_scene = (ROOT / "scenes/player/first_person_player.tscn").read_text(encoding="utf-8")
    assert_contains(player_scene, '[node name="HandDrillController" type="Node3D" parent="."]', "player hand-drill controller node")
    assert_contains(player_scene, '[node name="DrillBeam" type="MeshInstance3D" parent="HandDrillController"]', "visible drill beam feedback")
    touch_scene = (ROOT / "scenes/ui/mobile_touch_controls.tscn").read_text(encoding="utf-8")
    assert_contains(touch_scene, '[node name="ToolButton" type="Control" parent="."]', "Android TOOL button")
    assert_contains(touch_scene, 'action_name = &"tool_use"', "Android TOOL action binding")
    assert_contains(project_text, 'tool_use={', "Stage 31 shared tool InputMap action")
    assert_contains(project_text, '3d_physics/layer_7="Mineable"', "Stage 31 Mineable physics layer")

    print("VOIDFORGE Stage 31 static validation: PASS")
    print(f"Checked {len(REQUIRED)} required files and {len(resource_files)} Godot resource files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
