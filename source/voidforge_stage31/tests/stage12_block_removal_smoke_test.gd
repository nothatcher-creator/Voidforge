extends Node
## Stage 12 regression coverage for targeted instance removal, synchronized presentation,
## failure handling, InputMap control, removal highlight feedback, and touchscreen RMV.

const STAGE12_WORLD := preload("res://scenes/tests/stage12_block_removal_test.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")
const BLOCK_DEFINITION_SCRIPT := preload("res://scripts/blocks/block_definition.gd")
const BLOCK_ORIENTATION := preload("res://scripts/grids/block_orientation.gd")

const PLAYER_PATH := NodePath("Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer")
const GRID_PATH := NodePath("Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/PrototypeBlockGrid")

var _failures: Array[String] = []
var _world: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _grid: Node3D
var _presenter: Node3D
var _builder: Node3D
var _touch_controls: Control

func _ready() -> void:
	_build_world()
	await get_tree().process_frame
	await _physics_frames(8)
	await _run_checks()

func _build_world() -> void:
	_world = STAGE12_WORLD.instantiate() as Node3D
	_player = _world.get_node(PLAYER_PATH) as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_camera = _player.get_node("CameraPivot/Camera3D") as Camera3D
	_grid = _world.get_node(GRID_PATH) as Node3D
	_presenter = _grid.get_node("BlockPresenter") as Node3D
	_builder = _player.get_node("BuildController") as Node3D
	add_child(_world)

func _run_checks() -> void:
	_builder.call("refresh_targeting")
	_assert(bool(_builder.call("has_removal_target")), "Camera-centered construction ray resolves a removable block instance")
	_assert(_builder.call("get_removal_target_grid") == _grid, "Removal target resolves the authoritative prototype grid")
	var first_target_id := int(_builder.call("get_removal_target_instance_id"))
	_assert(first_target_id > 0, "Removal target exposes a stable positive block instance ID")
	var first_instance := _grid.call("get_block_by_instance_id", first_target_id) as Resource
	_assert(first_instance != null, "Removal target instance ID resolves back to authoritative block state")
	var highlight := _builder.call("get_removal_highlight") as Node3D
	_assert(highlight != null and highlight.visible, "Targeted block displays Stage 12 removal highlight feedback")
	if first_instance != null and highlight != null:
		var expected_size := Vector3(Vector3i(first_instance.get("dimensions_cells"))) * float(_grid.call("get_cell_size_m"))
		_assert((highlight.call("get_target_size_m") as Vector3).is_equal_approx(expected_size), "Removal highlight dimensions match targeted block definition-local size")

	var removed_events: Array[int] = []
	var failed_events: Array[String] = []
	_builder.connect("block_removed", func(_grid_node: Node3D, instance: Resource) -> void: removed_events.append(int(instance.get("instance_id"))))
	_builder.connect("removal_failed", func(reason: String) -> void: failed_events.append(reason))
	var blocks_before := int(_grid.call("get_block_count"))
	var cells_before := int(_grid.call("get_occupied_cell_count"))
	var first_cells: Array = first_instance.call("get_occupied_cells") if first_instance != null else []
	var removed := _builder.call("attempt_remove") as Resource
	await _physics_frames(3)
	_assert(removed != null, "Direct targeted removal returns the removed block state")
	_assert(int(_grid.call("get_block_count")) == blocks_before - 1, "Removing one target decrements authoritative grid block count exactly once")
	_assert(int(_grid.call("get_occupied_cell_count")) == cells_before - first_cells.size(), "Removal releases the complete targeted block footprint")
	_assert(_grid.call("get_block_by_instance_id", first_target_id) == null, "Removed instance ID is no longer registered by the grid")
	_assert(removed_events.size() == 1 and removed_events[0] == first_target_id, "Successful removal emits deterministic block_removed feedback")
	_assert(int(_presenter.call("get_presented_block_count")) == int(_grid.call("get_block_count")), "Presenter count stays synchronized after targeted removal")
	_assert(not bool(_builder.call("has_removal_target")), "Successful removal immediately clears stale removal targeting")
	_assert(highlight != null and not highlight.visible, "Successful removal immediately hides stale highlight feedback")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Grid integrity remains clean after targeted removal")

	_camera.rotation_degrees.y = 180.0
	_builder.call("refresh_targeting")
	_assert(not bool(_builder.call("has_removal_target")), "Looking away clears removal target state")
	var no_target_result := _builder.call("attempt_remove") as Resource
	_assert(no_target_result == null, "Removal safely rejects input when no block is targeted")
	_assert(failed_events.size() >= 1, "Rejected removal emits a player-feedback failure signal")
	_camera.rotation = Vector3.ZERO

	await _check_inputmap_removal()
	await _check_rotated_touch_removal()

	if _failures.is_empty():
		print("STAGE12_BLOCK_REMOVAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE12_BLOCK_REMOVAL_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _check_inputmap_removal() -> void:
	var unit := _make_block(&"stage12_inputmap_unit", Vector3i.ONE, [&"large"])
	_grid.call("clear_grid")
	var instance := _grid.call("place_block", unit, Vector3i.ZERO, 0) as Resource
	await _physics_frames(4)
	_builder.call("refresh_targeting")
	_assert(instance != null and int(_grid.call("get_block_count")) == 1, "InputMap removal fixture contains one authoritative block")
	_assert(int(_builder.call("get_removal_target_instance_id")) == int(instance.get("instance_id")), "InputMap fixture is selected by the camera ray")
	Input.action_press("build_remove")
	await _physics_frames(1)
	Input.action_release("build_remove")
	await _physics_frames(3)
	_assert(int(_grid.call("get_block_count")) == 0, "Shared build_remove InputMap action removes the targeted block")
	_assert(int(_presenter.call("get_presented_block_count")) == 0, "Presenter synchronizes after InputMap removal")

func _check_rotated_touch_removal() -> void:
	var span := _make_block(&"stage12_rotated_span", Vector3i(2, 1, 1), [&"large"])
	var rotated_index := BLOCK_ORIENTATION.rotate_index_around_axis(0, Vector3i(0, 0, 1), 1)
	_grid.call("clear_grid")
	var rotated := _grid.call("place_block", span, Vector3i.ZERO, rotated_index) as Resource
	await _physics_frames(4)
	_builder.call("refresh_targeting")
	_assert(rotated != null, "Rotated multi-cell removal fixture is created")
	_assert(Vector3i(rotated.call("get_oriented_dimensions_cells")) == Vector3i(1, 2, 1), "Removal fixture uses rotated 1×2×1 footprint")
	_assert(int(_grid.call("get_occupied_cell_count")) == 2, "Rotated fixture reserves both occupied cells before removal")
	_assert(int(_builder.call("get_removal_target_instance_id")) == int(rotated.get("instance_id")), "Any visible face of rotated fixture resolves the stable instance ID")
	var highlight := _builder.call("get_removal_highlight") as Node3D
	_assert(highlight != null and highlight.visible, "Rotated multi-cell target receives removal highlight")
	if highlight != null:
		_assert(_basis_equal(highlight.global_transform.basis, _grid.global_transform.basis.orthonormalized() * (rotated.call("get_orientation_basis") as Basis)), "Removal highlight preserves rotated block orientation")
		_assert((highlight.call("get_target_size_m") as Vector3).is_equal_approx(Vector3(5.0, 2.5, 2.5)), "Rotated highlight preserves definition-local 2×1×1 dimensions")

	_build_touch_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var remove_button := _touch_controls.get_node("RemoveButton") as Control
	var look_area := _touch_controls.get_node("LookArea") as Control
	_assert(remove_button != null, "Android touch HUD exposes Stage 12 RMV button")
	var remove_center := remove_button.get_global_rect().get_center()
	var look_probe := InputEventScreenTouch.new()
	look_probe.index = 51
	look_probe.position = remove_center
	look_probe.pressed = true
	_assert(not bool(look_area.call("handle_screen_event", look_probe)), "RMV button rectangle is excluded from camera-look touch ownership")

	_send_touch(remove_button, 52, remove_center, true)
	await _physics_frames(1)
	_send_touch(remove_button, 52, remove_center, false)
	await _physics_frames(4)
	_assert(int(_grid.call("get_block_count")) == 0, "Touch RMV removes the complete rotated multi-cell block instance")
	_assert(int(_grid.call("get_occupied_cell_count")) == 0, "Touch removal releases every cell in the rotated footprint")
	_assert(not bool(_grid.call("has_occupied_cell", Vector3i.ZERO)), "Rotated anchor cell is released")
	_assert(not bool(_grid.call("has_occupied_cell", Vector3i(0, 1, 0))), "Rotated secondary cell is released")
	_assert(int(_presenter.call("get_presented_block_count")) == 0, "Presenter removes rotated multi-cell visual/collision body exactly once")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Grid integrity remains clean after touchscreen rotated-block removal")

func _build_touch_controls() -> void:
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)

func _make_block(block_id: StringName, dimensions: Vector3i, allowed_profiles: Array[StringName]) -> Resource:
	var definition: Resource = BLOCK_DEFINITION_SCRIPT.new()
	definition.set("id", block_id)
	definition.set("display_name", String(block_id))
	definition.set("dimensions_cells", dimensions)
	definition.set("allowed_grid_sizes", allowed_profiles)
	return definition

func _send_touch(control: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	control.call("handle_screen_event", event)

func _physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _basis_equal(a: Basis, b: Basis, tolerance: float = 0.0001) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.z.is_equal_approx(b.z) and absf(a.determinant() - b.determinant()) <= tolerance

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
