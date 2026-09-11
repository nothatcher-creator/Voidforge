extends Node
## Headless integration checks for joystick, action buttons, look drag, and simultaneous touch ownership.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")

var _failures: Array[String] = []
var _player: CharacterBody3D
var _touch_controls: Control
var _joystick: Control
var _look_area: Control
var _jump_button: Control
var _sprint_button: Control

func _ready() -> void:
	_build_test_world()
	await get_tree().process_frame
	await get_tree().physics_frame
	await _run_checks()

func _run_checks() -> void:
	await _physics_frames(45)
	_assert(_player.is_on_floor(), "Player settles before touch tests")

	var joy_rect := _joystick.get_global_rect()
	var joy_center := joy_rect.get_center()
	_send_touch(_joystick, 2, joy_center, true)
	_send_drag(_joystick, 2, joy_center + Vector2(0.0, -82.0), Vector2(0.0, -82.0))
	_assert(Input.get_action_strength("move_forward") > 0.45, "Joystick drives forward InputMap strength")
	var start_z := _player.global_position.z
	await _physics_frames(18)
	_assert(start_z - _player.global_position.z > 0.25, "Joystick moves the player through shared controller logic")

	var start_yaw := _player.rotation.y
	var look_start := Vector2(get_viewport().get_visible_rect().size.x * 0.72, 230.0)
	_send_touch(_look_area, 9, look_start, true)
	_send_drag(_look_area, 9, look_start + Vector2(80.0, -25.0), Vector2(80.0, -25.0))
	_assert(absf(_player.rotation.y - start_yaw) > 0.02, "Right-side touch drag rotates the player camera body")
	_assert(Input.get_action_strength("move_forward") > 0.45, "Look finger coexists with movement finger")
	_assert(int(_joystick.call("get_active_touch_id")) == 2 and int(_look_area.call("get_active_touch_id")) == 9, "Separate touch IDs remain independently owned")
	_send_touch(_look_area, 9, look_start + Vector2(80.0, -25.0), false)
	_send_touch(_joystick, 2, joy_center + Vector2(0.0, -82.0), false)
	_assert(Input.get_action_strength("move_forward") < 0.001, "Joystick release clears movement InputMap state")

	var sprint_center := _sprint_button.get_global_rect().get_center()
	_send_touch(_sprint_button, 4, sprint_center, true)
	_assert(Input.is_action_pressed("sprint"), "Sprint touch button presses shared InputMap action")
	_send_touch(_sprint_button, 4, sprint_center, false)
	_assert(not Input.is_action_pressed("sprint"), "Sprint touch button releases shared InputMap action")

	await _physics_frames(18)
	var grounded_y := _player.global_position.y
	var jump_center := _jump_button.get_global_rect().get_center()
	_send_touch(_jump_button, 6, jump_center, true)
	await _physics_frames(1)
	_send_touch(_jump_button, 6, jump_center, false)
	await _physics_frames(10)
	_assert(_player.global_position.y > grounded_y + 0.08, "Jump touch button triggers normal jump behavior")

	if _failures.is_empty():
		print("STAGE4_TOUCH_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE4_TOUCH_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _build_test_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 63
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(24, 0.5, 24)
	floor_shape.position = Vector3(0, -0.25, 0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)

	var player_instance := PLAYER_SCENE.instantiate()
	player_instance.set("capture_mouse_on_start", false)
	_player = player_instance as CharacterBody3D
	_player.position = Vector3(0, 1.1, 3)
	add_child(_player)

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)
	_joystick = _touch_controls.get_node("MoveJoystick") as Control
	_look_area = _touch_controls.get_node("LookArea") as Control
	_jump_button = _touch_controls.get_node("JumpButton") as Control
	_sprint_button = _touch_controls.get_node("SprintButton") as Control

func _send_touch(target: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	target.call("handle_screen_event", event)

func _send_drag(target: Control, index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	target.call("handle_screen_event", event)

func _physics_frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
