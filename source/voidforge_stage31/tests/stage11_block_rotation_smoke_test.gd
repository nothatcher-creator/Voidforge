extends Node
## Stage 11 regression coverage for 24-state orthogonal orientation, rotated footprints,
## presenter transforms, pre-placement ghost rotation, shared InputMap control, and touch ROT.

const STAGE11_WORLD := preload("res://scenes/tests/stage11_block_rotation_test.tscn")
const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")
const BLOCK_DEFINITION_SCRIPT := preload("res://scripts/blocks/block_definition.gd")
const BLOCK_ORIENTATION := preload("res://scripts/grids/block_orientation.gd")

const PLAYER_PATH := NodePath("Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer")
const GRID_PATH := NodePath("Stage10BlockPlacementTest/Stage9GridTest/PrototypeBlockGrid")

var _failures: Array[String] = []
var _world: Node3D
var _player: CharacterBody3D
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
	_world = STAGE11_WORLD.instantiate() as Node3D
	_player = _world.get_node(PLAYER_PATH) as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_grid = _world.get_node(GRID_PATH) as Node3D
	_presenter = _grid.get_node("BlockPresenter") as Node3D
	_builder = _player.get_node("BuildController") as Node3D
	add_child(_world)

func _run_checks() -> void:
	_assert(BLOCK_ORIENTATION.ORIENTATION_COUNT == 24, "Orientation helper exposes exactly 24 right-angle cube orientations")
	_assert(_basis_equal(BLOCK_ORIENTATION.get_basis(0), Basis.IDENTITY), "Orientation index 0 is identity")

	var seen_bases: Dictionary = {}
	var all_round_trip := true
	var all_right_handed := true
	for index in BLOCK_ORIENTATION.ORIENTATION_COUNT:
		var basis := BLOCK_ORIENTATION.get_basis(index)
		seen_bases[_basis_key(basis)] = true
		if BLOCK_ORIENTATION.find_index_from_basis(basis) != index:
			all_round_trip = false
		if not is_equal_approx(basis.determinant(), 1.0):
			all_right_handed = false
	_assert(seen_bases.size() == 24, "All 24 orientation indices resolve to unique bases")
	_assert(all_round_trip, "Every orientation basis round-trips to its stable index")
	_assert(all_right_handed, "Every stored orientation is a proper right-handed rotation")

	var span_dimensions := Vector3i(2, 1, 1)
	var z_quarter := BLOCK_ORIENTATION.rotate_index_around_axis(0, Vector3i(0, 0, 1), 1)
	_assert(z_quarter != 0, "Quarter-turn rotation produces a non-identity orientation")
	_assert(BLOCK_ORIENTATION.get_oriented_dimensions(span_dimensions, z_quarter) == Vector3i(1, 2, 1), "90-degree face rotation swaps the Span Frame X/Y footprint")
	var z_full_turn := z_quarter
	for _turn in 3:
		z_full_turn = BLOCK_ORIENTATION.rotate_index_around_axis(z_full_turn, Vector3i(0, 0, 1), 1)
	_assert(z_full_turn == 0, "Four quarter-turns around one axis return to identity")
	_assert(BLOCK_ORIENTATION.rotate_index_around_axis(0, Vector3i.ZERO, 1) == 0, "Zero rotation axis is a safe no-op")

	await _check_rotated_grid_footprint(z_quarter)

	_builder.call("refresh_targeting")
	_assert(StringName((_builder.call("get_build_definition") as Resource).get("id")) == &"dev_span_frame", "Stage 11 active build definition is the two-cell Span Frame")
	_assert(int(_builder.call("get_orientation_index")) == 0, "Construction orientation starts at identity")
	_assert(Vector3i(_builder.call("get_oriented_dimensions_cells")) == Vector3i(2, 1, 1), "Builder exposes unrotated Span Frame footprint")
	_assert(Vector3i(_builder.call("get_target_face")) == Vector3i(0, 0, 1), "Development camera initially targets the grid's front face")
	_assert(bool(_builder.call("is_target_valid")), "Unrotated Span Frame has a valid initial target")

	var ghost := _builder.call("get_ghost") as Node3D
	_assert(ghost != null and ghost.visible, "Rotatable construction target displays its hologram")
	_assert((ghost.call("get_preview_size_m") as Vector3).is_equal_approx(Vector3(5.0, 2.5, 2.5)), "Span Frame hologram retains definition-local dimensions")
	var ghost_basis_before := ghost.global_transform.basis
	var orientation_events: Array[int] = []
	_builder.connect("orientation_changed", func(index: int) -> void: orientation_events.append(index))
	var rotated_index := int(_builder.call("rotate_preview_clockwise"))
	_assert(rotated_index != 0, "Direct pre-placement rotation changes orientation index")
	_assert(Vector3i(_builder.call("get_oriented_dimensions_cells")) == Vector3i(1, 2, 1), "Builder validity footprint updates after face-relative rotation")
	_assert(bool(_builder.call("is_target_valid")), "Rotated Span Frame remains placeable on the test face")
	_assert(not _basis_equal(ghost.global_transform.basis, ghost_basis_before), "Hologram transform visibly rotates with orientation state")
	_assert(orientation_events.size() == 1 and orientation_events[0] == rotated_index, "Rotation emits deterministic orientation_changed signal")

	var before_input_index := int(_builder.call("get_orientation_index"))
	Input.action_press("build_rotate")
	await _physics_frames(1)
	Input.action_release("build_rotate")
	await _physics_frames(1)
	_assert(int(_builder.call("get_orientation_index")) != before_input_index, "Shared InputMap build_rotate action rotates pre-placement state")

	_builder.call("reset_orientation")
	_builder.call("rotate_preview_clockwise")
	_builder.call("refresh_targeting")
	var target_cell := Vector3i(_builder.call("get_target_cell"))
	var expected_orientation := int(_builder.call("get_orientation_index"))
	var before_place := int(_grid.call("get_block_count"))
	var placed := _builder.call("attempt_place") as Resource
	await _physics_frames(3)
	_assert(placed != null and int(_grid.call("get_block_count")) == before_place + 1, "Rotated Span Frame places successfully through the normal construction path")
	_assert(int(placed.get("orientation_index")) == expected_orientation, "Placed block preserves pre-placement orientation index")
	_assert(Vector3i(placed.call("get_oriented_dimensions_cells")) == Vector3i(1, 2, 1), "Placed block preserves rotated multi-cell footprint")
	_assert(bool(placed.call("contains_cell", target_cell + Vector3i(0, 1, 0))), "Rotated placed block occupies its vertical second cell")
	_assert(not bool(placed.call("contains_cell", target_cell + Vector3i(1, 0, 0))), "Rotated placed block no longer occupies identity-orientation X extension")
	var placed_state: Dictionary = placed.call("get_state")
	_assert(int(placed_state["orientation_index"]) == expected_orientation, "Serializable block state records orientation index")
	_assert(Vector3i(placed_state["oriented_dimensions_cells"]) == Vector3i(1, 2, 1), "Serializable state exposes derived rotated dimensions")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Grid integrity audit remains clean after rotated placement")

	var placed_id := int(placed.get("instance_id"))
	var placed_body := _presenter.call("get_block_body", placed_id) as CollisionObject3D
	_assert(placed_body != null, "Presenter maps the rotated block into the shared grid collision body")
	if placed_body != null:
		var collision_transform := _presenter.call("get_block_collision_transform", placed_id) as Transform3D
		_assert(_basis_equal(collision_transform.basis, placed.call("get_orientation_basis") as Basis), "Shared collision shape owner preserves placed block orientation basis")

	_build_touch_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var rotate_button := _touch_controls.get_node("RotateButton") as Control
	var look_area := _touch_controls.get_node("LookArea") as Control
	_assert(rotate_button != null, "Android touch HUD exposes Stage 11 ROT button")
	var rotate_center := rotate_button.get_global_rect().get_center()
	var look_probe := InputEventScreenTouch.new()
	look_probe.index = 41
	look_probe.position = rotate_center
	look_probe.pressed = true
	_assert(not bool(look_area.call("handle_screen_event", look_probe)), "ROT button rectangle is excluded from camera-look touch ownership")

	var before_touch_index := int(_builder.call("get_orientation_index"))
	_send_touch(rotate_button, 42, rotate_center, true)
	await _physics_frames(1)
	_send_touch(rotate_button, 42, rotate_center, false)
	await _physics_frames(1)
	_assert(int(_builder.call("get_orientation_index")) != before_touch_index, "Touch ROT button rotates through the same build_rotate action")

	if _failures.is_empty():
		print("STAGE11_BLOCK_ROTATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE11_BLOCK_ROTATION_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _check_rotated_grid_footprint(z_quarter: int) -> void:
	var test_grid := GRID_SCENE.instantiate() as Node3D
	test_grid.name = "RotationFootprintGrid"
	test_grid.position = Vector3(100.0, 0.0, 0.0)
	add_child(test_grid)
	await get_tree().process_frame
	var span := _make_block(&"rotation_span", Vector3i(2, 1, 1), [&"large"])
	var unit := _make_block(&"rotation_unit", Vector3i.ONE, [&"large"])
	_assert(not bool(test_grid.call("can_place_block", span, Vector3i.ZERO, 24)), "Grid rejects invalid orientation indices")
	_assert(bool(test_grid.call("can_place_block", span, Vector3i.ZERO, z_quarter)), "Grid accepts free rotated multi-cell footprint")
	var instance := test_grid.call("place_block", span, Vector3i.ZERO, z_quarter) as Resource
	_assert(instance != null, "Grid places rotated multi-cell block")
	_assert(int(test_grid.call("get_occupied_cell_count")) == 2, "Rotated two-cell block still occupies exactly two cells")
	_assert(test_grid.call("get_block_at", Vector3i(0, 1, 0)) == instance, "Rotated footprint occupies Y-adjacent cell")
	_assert(not bool(test_grid.call("has_occupied_cell", Vector3i(1, 0, 0))), "Rotated footprint does not reserve old identity X-adjacent cell")
	_assert(bool(test_grid.call("can_place_block", unit, Vector3i(1, 0, 0), 0)), "Cell freed by rotated footprint remains available")
	_assert(not bool(test_grid.call("can_place_block", unit, Vector3i(0, 1, 0), 0)), "Overlap check uses rotated occupied cells")
	_assert((_grid_errors(test_grid)).is_empty(), "Standalone rotated grid passes integrity audit")
	var removed := test_grid.call("remove_block_at", Vector3i(0, 1, 0)) as Resource
	_assert(removed == instance and int(test_grid.call("get_occupied_cell_count")) == 0, "Removing from rotated interior cell releases full rotated footprint")
	test_grid.queue_free()

func _grid_errors(grid: Node3D) -> Array:
	return grid.call("get_integrity_errors") as Array

func _make_block(block_id: StringName, dimensions: Vector3i, profiles: Array[StringName]) -> Resource:
	var definition: Resource = BLOCK_DEFINITION_SCRIPT.new()
	definition.set("id", block_id)
	definition.set("display_name", String(block_id))
	definition.set("dimensions_cells", dimensions)
	definition.set("allowed_grid_sizes", profiles)
	return definition

func _build_touch_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)

func _send_touch(target: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	target.call("handle_screen_event", event)

func _basis_equal(a: Basis, b: Basis) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.z.is_equal_approx(b.z)

func _basis_key(basis: Basis) -> String:
	return "%s|%s|%s" % [str(basis.x.round()), str(basis.y.round()), str(basis.z.round())]

func _physics_frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
