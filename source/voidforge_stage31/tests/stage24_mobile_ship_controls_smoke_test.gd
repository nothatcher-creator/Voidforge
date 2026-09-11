extends Node
## Stage 24 verification for dual-stick Android ship controls, touch ownership,
## dead zones, context switching, roll controls, and real translation/gyro physics.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")
const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")
const ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")
const DIRECTIONS: Array[Vector3i] = [
	Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD,
]
const CELLS: Array[Vector3i] = [
	Vector3i(-2, 0, 0), Vector3i(2, 0, 0), Vector3i(0, -1, 0),
	Vector3i(0, 2, 0), Vector3i(0, 0, -2), Vector3i(0, 0, 2),
]

var _failures: Array[String] = []
var _player: CharacterBody3D
var _grid: RigidBody3D
var _touch_controls: Control

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	var seat := BlockDB.call("get_block", &"pilot_cradle_large") as Resource
	var thruster := BlockDB.call("get_block", &"pulse_thruster_large") as Resource
	var gyro := BlockDB.call("get_block", &"vector_gyro_large") as Resource
	_assert(seat != null and thruster != null and gyro != null, "Stage 24 fixtures resolve from authoritative BlockDB")

	_grid = _make_grid("MobileDualStickGrid", Vector3(0, 28, 0))
	var presenter := PRESENTER_SCRIPT.new() as Node3D
	presenter.name = "BlockPresenter"
	_grid.add_child(presenter)
	var seat_instance := _grid.call("place_block", seat, Vector3i.ZERO, 0) as Resource
	_grid.call("place_block", gyro, Vector3i(0, 1, 0), 0)
	for index in DIRECTIONS.size():
		_grid.call("place_block", thruster, CELLS[index], _orientation_for_force_direction(DIRECTIONS[index]))
	presenter.call("flush_collision_now")
	presenter.call("flush_geometry_now")
	var seat_presenter := presenter.call("get_control_seat_presenter") as Node3D
	seat_presenter.call("flush_now")
	var seat_proxy := seat_presenter.call("get_control_seat", int(seat_instance.get("instance_id"))) as Area3D
	_assert(int(_grid.call("get_thruster_count")) == 6 and int(_grid.call("get_gyroscope_count")) == 1, "Dual-stick craft physically contains six translation thrusters and one gyro")
	_assert(is_equal_approx(float(_grid.call("get_total_rated_thrust_n")), 288000.0), "Dual-stick craft exposes 288 kN installed translation thrust")
	_assert(is_equal_approx(float(_grid.call("get_total_gyro_torque_nm")), 120000.0), "Dual-stick craft exposes 120 kN*m gyro authority")

	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_player.position = Vector3(0, 28, 8)
	add_child(_player)
	_build_touch_controls()
	await get_tree().process_frame
	await get_tree().process_frame

	var move_joystick := _touch_controls.get_node("MoveJoystick") as Control
	var rotation_joystick := _touch_controls.get_node("RotationJoystick") as Control
	var look_area := _touch_controls.get_node("LookArea") as Control
	var roll_left := _touch_controls.get_node("RollLeftButton") as Control
	var roll_right := _touch_controls.get_node("RollRightButton") as Control
	var up_button := _touch_controls.get_node("ThrustUpButton") as Control
	var down_button := _touch_controls.get_node("ThrustDownButton") as Control
	var exit_button := _touch_controls.get_node("ExitSeatButton") as Control

	var move_bindings := move_joystick.call("get_action_bindings") as Dictionary
	_assert(not rotation_joystick.visible and not roll_left.visible and not roll_right.visible, "Vehicle rotation controls stay hidden while the player is on foot")
	_assert(move_bindings.get("left") == &"move_left" and move_bindings.get("forward") == &"move_forward", "Left stick starts in on-foot movement mode")

	_assert(bool(_player.call("enter_control_seat", seat_proxy)), "Player enters the actual Pilot Cradle before mobile flight testing")
	_assert(bool(_grid.call("set_dynamic_simulation_enabled", true)), "Dual-stick craft enters real rigid-body simulation")
	await get_tree().process_frame
	await get_tree().process_frame

	move_bindings = move_joystick.call("get_action_bindings") as Dictionary
	var rotation_bindings := rotation_joystick.call("get_action_bindings") as Dictionary
	_assert(rotation_joystick.visible and roll_left.visible and roll_right.visible, "Seated mode reveals right rotation stick and both roll controls")
	_assert(up_button.visible and down_button.visible and exit_button.visible, "Seated mode reveals vertical thrust and EXIT context controls")
	_assert(move_bindings.get("left") == &"vehicle_thrust_left" and move_bindings.get("forward") == &"vehicle_thrust_forward", "Left stick switches to four-axis vehicle translation")
	_assert(rotation_bindings.get("left") == &"vehicle_yaw_left" and rotation_bindings.get("right") == &"vehicle_yaw_right", "Right stick horizontal axis is bound to yaw")
	_assert(rotation_bindings.get("forward") == &"vehicle_pitch_up" and rotation_bindings.get("backward") == &"vehicle_pitch_down", "Right stick vertical axis is bound to pitch")

	var rotation_center := rotation_joystick.get_global_rect().get_center()
	var ownership_probe := InputEventScreenTouch.new()
	ownership_probe.index = 141
	ownership_probe.position = rotation_center
	ownership_probe.pressed = true
	_assert(not bool(look_area.call("handle_screen_event", ownership_probe)), "Right rotation stick is excluded from free-look touch ownership")

	# Dead-zone check: a small displacement must not command gyro actions.
	_send_touch(rotation_joystick, 142, rotation_center, true)
	_send_drag(rotation_joystick, 142, rotation_center + Vector2(6.0, -6.0), Vector2(6.0, -6.0))
	_assert(Input.get_action_strength("vehicle_yaw_right") < 0.001 and Input.get_action_strength("vehicle_pitch_up") < 0.001, "Right rotation stick suppresses motion inside its configured dead zone")
	_send_touch(rotation_joystick, 142, rotation_center + Vector2(6.0, -6.0), false)

	# Three simultaneous fingers: translate, pitch/yaw, and roll. All must retain independent ownership.
	_grid.call("stop_motion")
	var move_center := move_joystick.get_global_rect().get_center()
	var roll_center := roll_right.get_global_rect().get_center()
	_send_touch(move_joystick, 151, move_center, true)
	_send_touch(rotation_joystick, 152, rotation_center, true)
	_send_touch(roll_right, 153, roll_center, true)
	_send_drag(move_joystick, 151, move_center + Vector2(62.0, -78.0), Vector2(62.0, -78.0))
	_send_drag(rotation_joystick, 152, rotation_center + Vector2(70.0, -70.0), Vector2(70.0, -70.0))
	var state := _touch_controls.call("get_mobile_control_state") as Dictionary
	_assert(int(state.get("move_touch_id", -1)) == 151 and int(state.get("rotation_touch_id", -1)) == 152 and int(state.get("look_touch_id", -1)) == -1, "Translation and rotation sticks independently own separate fingers without stealing free-look")
	_assert(roll_right.call("get_active_touch_id") == 153, "Roll button owns a third simultaneous touch independently")
	await _physics_frames(10)
	var translation_input := _grid.call("get_manual_translation_input_local") as Vector3
	var rotation_input := _grid.call("get_manual_rotation_input_local") as Vector3
	_assert(translation_input.x > 0.30 and translation_input.z < -0.30, "Left vehicle stick sends simultaneous right + forward analog translation")
	_assert(rotation_input.x > 0.30 and rotation_input.y < -0.30 and rotation_input.z > 0.90, "Right stick plus R-R button sends pitch + yaw + roll through one gyro command vector")
	_assert(_grid.linear_velocity.length() > 0.25, "Dual-stick translation produces real rigid-body linear velocity")
	_assert(_grid.angular_velocity.length() > 0.03, "Right stick/roll input produces real rigid-body angular velocity")

	_send_touch(roll_right, 153, roll_center, false)
	_send_touch(rotation_joystick, 152, rotation_center + Vector2(70.0, -70.0), false)
	_send_touch(move_joystick, 151, move_center + Vector2(62.0, -78.0), false)
	await _physics_frames(3)
	_assert((_grid.call("get_manual_translation_input_local") as Vector3).length_squared() < 0.0001, "Releasing left stick clears vehicle translation command")
	_assert((_grid.call("get_manual_rotation_input_local") as Vector3).length_squared() < 0.0001, "Releasing right stick/roll clears gyro command")

	# Roll-left is independently mapped and signed opposite roll-right.
	var roll_left_center := roll_left.get_global_rect().get_center()
	_send_touch(roll_left, 161, roll_left_center, true)
	await _physics_frames(2)
	_assert((_grid.call("get_manual_rotation_input_local") as Vector3).z < -0.99, "R-L touch button drives negative roll through the shared InputMap")
	_send_touch(roll_left, 161, roll_left_center, false)
	await _physics_frames(2)

	# EXIT must survive the context switch that hides the button and clear its owned touch/action.
	var exit_center := exit_button.get_global_rect().get_center()
	_send_touch(exit_button, 171, exit_center, true)
	await _physics_frames(2)
	_send_touch(exit_button, 171, exit_center, false)
	await _physics_frames(2)
	move_bindings = move_joystick.call("get_action_bindings") as Dictionary
	_assert(not bool(_player.call("is_in_control_seat")), "Android EXIT returns the pilot to on-foot mode")
	_assert(not rotation_joystick.visible and not roll_left.visible and not roll_right.visible, "Vehicle rotation controls hide immediately after exit")
	_assert(move_bindings.get("left") == &"move_left" and move_bindings.get("forward") == &"move_forward", "Left joystick restores on-foot bindings after vehicle exit")
	_assert(not Input.is_action_pressed("vehicle_exit"), "EXIT touch action cannot remain stuck after the context button hides")
	_assert((_grid.call("get_manual_rotation_input_local") as Vector3).length_squared() < 0.0001 and (_grid.call("get_manual_translation_input_local") as Vector3).length_squared() < 0.0001, "Exiting clears all mobile vehicle command state")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Stage 24 dual-stick craft remains structurally valid after mobile physics testing")

	if _failures.is_empty():
		print("STAGE24_MOBILE_SHIP_CONTROLS_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE24_MOBILE_SHIP_CONTROLS_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _make_grid(grid_name: String, position: Vector3) -> RigidBody3D:
	var grid := GRID_SCRIPT.new() as RigidBody3D
	grid.name = grid_name
	grid.set("grid_profile", LARGE_PROFILE)
	grid.set("power_network_enabled", false)
	grid.set("dynamic_gravity_scale", 0.0)
	grid.set("dynamic_linear_damp", 0.0)
	grid.set("dynamic_angular_damp", 0.0)
	grid.position = position
	add_child(grid)
	return grid

func _build_touch_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)

func _orientation_for_force_direction(direction: Vector3i) -> int:
	for orientation_index in ORIENTATION.ORIENTATION_COUNT:
		var basis := ORIENTATION.get_basis(orientation_index)
		if Vector3i(basis * Vector3(0, 0, -1)) == direction:
			return orientation_index
	return 0

func _send_touch(control: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	control.call("handle_screen_event", event)

func _send_drag(control: Control, index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	control.call("handle_screen_event", event)

func _physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
