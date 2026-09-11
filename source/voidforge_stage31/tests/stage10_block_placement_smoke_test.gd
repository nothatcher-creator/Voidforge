extends Node
## Stage 10 integration coverage for presented grid collision, snapped attachment targeting,
## holographic validity feedback, shared build input, and touchscreen BUILD placement.

const STAGE10_WORLD := preload("res://scenes/tests/stage10_block_placement_test.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")
const BLOCK_DEFINITION_SCRIPT := preload("res://scripts/blocks/block_definition.gd")

const PLAYER_PATH := NodePath("Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer")
const GRID_PATH := NodePath("Stage9GridTest/PrototypeBlockGrid")

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
	_world = STAGE10_WORLD.instantiate() as Node3D
	_player = _world.get_node(PLAYER_PATH) as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_grid = _world.get_node(GRID_PATH) as Node3D
	_presenter = _grid.get_node("BlockPresenter") as Node3D
	_builder = _player.get_node("BuildController") as Node3D
	add_child(_world)

func _run_checks() -> void:
	_builder.call("refresh_targeting")
	_assert(int(_grid.call("get_block_count")) == 3, "Stage 10 starts from the three-block Stage 9 construction sample")
	_assert(int(_presenter.call("get_presented_block_count")) == 3, "Presenter exposes one targetable presentation entry per prototype block")
	_assert(_builder.call("get_target_grid") == _grid, "Camera-centered build ray resolves the presented BlockGrid")
	_assert(Vector3i(_builder.call("get_target_cell")) == Vector3i(0, 0, 1), "Front-face hit snaps to the adjacent grid cell")
	_assert(Vector3i(_builder.call("get_target_face")) == Vector3i(0, 0, 1), "Attachment face normal is converted into grid-local axis coordinates")
	_assert(bool(_builder.call("is_target_valid")), "Free compatible adjacent cell reports valid placement")
	_assert(float(_builder.call("get_target_distance_m")) > 0.0 and float(_builder.call("get_target_distance_m")) < 12.0, "Target distance is measured inside construction range")

	var ghost := _builder.call("get_ghost") as Node3D
	_assert(ghost != null and ghost.visible, "Placement target displays holographic ghost geometry")
	_assert(bool(ghost.call("is_placement_valid")), "Valid target uses the ghost's valid state")
	_assert((ghost.call("get_preview_size_m") as Vector3).is_equal_approx(Vector3(2.5, 2.5, 2.5)), "Ghost size matches one large-grid cell")

	var cell_size := float(_grid.call("get_cell_size_m"))
	var base_center := _grid.call("grid_to_world", Vector3i.ZERO) as Vector3
	var top_hit := base_center + _grid.global_transform.basis.y.normalized() * (cell_size * 0.5)
	var top_cell := Vector3i(_builder.call("compute_attachment_cell", _grid, top_hit, _grid.global_transform.basis.y.normalized()))
	_assert(top_cell == Vector3i(0, 1, 0), "Attachment-cell math selects the neighboring cell on a known top face")

	var incompatible := _make_block(&"small_only_preview", [&"small"])
	_builder.call("set_build_definition", incompatible)
	_assert(_builder.call("get_target_grid") == _grid and not bool(_builder.call("is_target_valid")), "Incompatible block definition keeps target but marks preview invalid")
	_assert(ghost.visible and not bool(ghost.call("is_placement_valid")), "Invalid placement switches hologram into invalid state")

	var build_definition := load("res://data/blocks/dev_hull_frame.tres") as Resource
	_builder.call("set_build_definition", build_definition)
	_builder.set("placement_range_m", 2.0)
	_builder.call("refresh_targeting")
	_assert(_builder.call("get_target_grid") == null and not ghost.visible, "Out-of-range target clears construction target and hides ghost")
	_builder.set("placement_range_m", 12.0)
	_builder.call("refresh_targeting")
	_assert(bool(_builder.call("is_target_valid")), "Restoring build range reacquires valid snapped target")

	var before_input_place := int(_grid.call("get_block_count"))
	Input.action_press("build_place")
	await _physics_frames(1)
	Input.action_release("build_place")
	await _physics_frames(2)
	_assert(int(_grid.call("get_block_count")) == before_input_place + 1, "Shared InputMap build_place action mutates the target grid")
	_assert(int(_presenter.call("get_presented_block_count")) == int(_grid.call("get_block_count")), "Presenter stays synchronized after InputMap placement")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Grid integrity remains valid after visible placement")

	_builder.call("refresh_targeting")
	_assert(bool(_builder.call("is_target_valid")), "Build ray advances to the new outer face after placement")

	_build_touch_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var build_button := _touch_controls.get_node("BuildButton") as Control
	var look_area := _touch_controls.get_node("LookArea") as Control
	_assert(build_button != null, "Android touch HUD exposes Stage 10 BUILD button")
	var build_center := build_button.get_global_rect().get_center()
	var look_probe := InputEventScreenTouch.new()
	look_probe.index = 31
	look_probe.position = build_center
	look_probe.pressed = true
	_assert(not bool(look_area.call("handle_screen_event", look_probe)), "BUILD button rectangle is excluded from camera-look touch ownership")

	var before_touch_place := int(_grid.call("get_block_count"))
	_send_touch(build_button, 32, build_center, true)
	await _physics_frames(1)
	_send_touch(build_button, 32, build_center, false)
	await _physics_frames(2)
	_assert(int(_grid.call("get_block_count")) == before_touch_place + 1, "Touch BUILD button places through the same build_place action")
	_assert(int(_presenter.call("get_presented_block_count")) == int(_grid.call("get_block_count")), "Touch placement immediately gains visible/collidable presentation")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Grid integrity remains clean after touchscreen placement")

	if _failures.is_empty():
		print("STAGE10_BLOCK_PLACEMENT_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE10_BLOCK_PLACEMENT_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _build_touch_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)

func _make_block(block_id: StringName, profiles: Array[StringName]) -> Resource:
	var definition: Resource = BLOCK_DEFINITION_SCRIPT.new()
	definition.set("id", block_id)
	definition.set("display_name", String(block_id))
	definition.set("dimensions_cells", Vector3i.ONE)
	definition.set("allowed_grid_sizes", profiles)
	return definition

func _send_touch(target: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	target.call("handle_screen_event", event)

func _physics_frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
