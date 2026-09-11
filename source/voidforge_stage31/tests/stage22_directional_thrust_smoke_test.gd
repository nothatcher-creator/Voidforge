extends Node
## Stage 22 verification: directional grouping, six-axis selection, pilot authority, physics, and touch translation controls.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")
const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")
const ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")
const DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _failures: Array[String] = []
var _player: CharacterBody3D
var _touch_controls: Control

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	var thruster := BlockDB.call("get_block", &"pulse_thruster_large") as Resource
	var seat := BlockDB.call("get_block", &"pilot_cradle_large") as Resource
	_assert(thruster != null and seat != null, "Stage 22 resolves Pilot Cradle and Pulse Thruster definitions")

	var grid := _make_grid("SixAxisGrid", Vector3(0, 20, 0))
	var presenter := PRESENTER_SCRIPT.new() as Node3D
	presenter.name = "BlockPresenter"
	grid.add_child(presenter)
	var seat_instance := grid.call("place_block", seat, Vector3i.ZERO, 0) as Resource
	var cells: Array[Vector3i] = [
		Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, -1, 0),
		Vector3i(0, 1, 0), Vector3i(0, 0, -1), Vector3i(0, 0, 1),
	]
	for index in DIRECTIONS.size():
		grid.call("place_block", thruster, cells[index], _orientation_for_force_direction(DIRECTIONS[index]))
	presenter.call("flush_collision_now")
	presenter.call("flush_geometry_now")
	var seat_presenter := presenter.call("get_control_seat_presenter") as Node3D
	seat_presenter.call("flush_now")
	var seat_proxy := seat_presenter.call("get_control_seat", int(seat_instance.get("instance_id"))) as Area3D

	_assert(int(grid.call("get_thruster_count")) == 6, "Six-axis craft discovers six installed thrusters")
	_assert(is_equal_approx(float(grid.call("get_total_rated_thrust_n")), 288000.0), "Six 48 kN thrusters report 288 kN total installed rating")
	_assert((grid.call("get_combined_thruster_local_force_n") as Vector3).length() < 0.1, "Opposed six-axis thrusters have a zero idle vector sum")
	for direction in DIRECTIONS:
		_assert(is_equal_approx(float(grid.call("get_directional_rated_thrust_n", direction)), 48000.0), "Direction %s has exactly one 48 kN translation group" % str(direction))
		_assert((grid.call("get_thruster_instance_ids_for_direction", direction) as Array).size() == 1, "Direction %s maps to one exact thruster instance" % str(direction))

	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_player.position = Vector3(0, 20, 8)
	add_child(_player)
	await get_tree().process_frame
	_assert(not bool(grid.call("set_manual_translation_input", _player, Vector3(1, 0, 0))), "Six-axis commands reject actors without Pilot Cradle authority")
	_assert(bool(_player.call("enter_control_seat", seat_proxy)), "Player claims the six-axis craft through its Pilot Cradle")
	_assert(bool(grid.call("set_dynamic_simulation_enabled", true)), "Six-axis craft enters dynamic simulation")

	var command_cases := [
		{"input": Vector3(1, 0, 0), "force": Vector3(48000, 0, 0), "name": "right"},
		{"input": Vector3(-1, 0, 0), "force": Vector3(-48000, 0, 0), "name": "left"},
		{"input": Vector3(0, 1, 0), "force": Vector3(0, 48000, 0), "name": "up"},
		{"input": Vector3(0, -1, 0), "force": Vector3(0, -48000, 0), "name": "down"},
		{"input": Vector3(0, 0, 1), "force": Vector3(0, 0, 48000), "name": "backward"},
		{"input": Vector3(0, 0, -1), "force": Vector3(0, 0, -48000), "name": "forward"},
	]
	for case in command_cases:
		grid.call("set_manual_translation_input", _player, case["input"])
		var active_force := grid.call("get_active_manual_force_local_n") as Vector3
		_assert(active_force.distance_to(case["force"]) < 0.1, "%s command fires only the matching directional thruster group" % String(case["name"]))

	grid.call("set_manual_translation_input", _player, Vector3(1, 1, -1))
	_assert((grid.call("get_active_manual_force_local_n") as Vector3).distance_to(Vector3(48000, 48000, -48000)) < 0.1, "Diagonal translation combines independent axis thruster groups without firing opposed engines")
	grid.call("clear_manual_thrust_input", _player)

	var physics_cases := [
		{"action": "vehicle_thrust_forward", "expected": Vector3.FORWARD, "name": "forward"},
		{"action": "vehicle_thrust_right", "expected": Vector3.RIGHT, "name": "right"},
		{"action": "vehicle_thrust_up", "expected": Vector3.UP, "name": "up"},
		{"action": "vehicle_thrust_backward", "expected": Vector3.BACK, "name": "backward"},
		{"action": "vehicle_thrust_left", "expected": Vector3.LEFT, "name": "left"},
		{"action": "vehicle_thrust_down", "expected": Vector3.DOWN, "name": "down"},
	]
	for case in physics_cases:
		grid.call("stop_motion")
		Input.action_press(case["action"], 1.0)
		await _physics_frames(12)
		Input.action_release(case["action"])
		await _physics_frames(2)
		var velocity := grid.linear_velocity
		_assert(velocity.length() > 0.5 and velocity.normalized().dot(case["expected"]) > 0.94, "InputMap %s command produces real local-axis rigid-body translation" % String(case["name"]))

	_build_touch_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var joystick := _touch_controls.get_node("MoveJoystick") as Control
	var bindings := joystick.call("get_action_bindings") as Dictionary
	_assert(bindings.get("left") == &"vehicle_thrust_left" and bindings.get("forward") == &"vehicle_thrust_forward", "Mobile left stick switches from on-foot movement to vehicle translation actions while seated")
	var up_button := _touch_controls.get_node("ThrustUpButton") as Control
	var down_button := _touch_controls.get_node("ThrustDownButton") as Control
	var look_area := _touch_controls.get_node("LookArea") as Control
	_assert(up_button.visible and down_button.visible, "Android HUD exposes contextual UP/DN translation controls while seated")
	var up_center := up_button.get_global_rect().get_center()
	var probe := InputEventScreenTouch.new()
	probe.index = 91
	probe.position = up_center
	probe.pressed = true
	_assert(not bool(look_area.call("handle_screen_event", probe)), "Vertical thrust buttons are excluded from camera-look touch ownership")
	_send_touch(up_button, 92, up_center, true)
	await _physics_frames(2)
	_assert((grid.call("get_manual_translation_input_local") as Vector3).y > 0.99, "Android UP drives the shared six-axis translation input")
	_send_touch(up_button, 92, up_center, false)
	await _physics_frames(2)
	var down_center := down_button.get_global_rect().get_center()
	_send_touch(down_button, 93, down_center, true)
	await _physics_frames(2)
	_assert((grid.call("get_manual_translation_input_local") as Vector3).y < -0.99, "Android DN drives negative vertical translation")
	_send_touch(down_button, 93, down_center, false)
	await _physics_frames(2)

	_player.call("exit_control_seat")
	await _physics_frames(1)
	bindings = joystick.call("get_action_bindings") as Dictionary
	_assert(bindings.get("left") == &"move_left" and bindings.get("forward") == &"move_forward", "Mobile left stick restores on-foot movement bindings after exiting the seat")
	_assert(not up_button.visible and not down_button.visible, "Android vertical vehicle controls hide on foot")
	_assert((grid.call("get_manual_translation_input_local") as Vector3).length_squared() < 0.0001, "Exiting the Pilot Cradle clears all six-axis translation input")
	_assert((grid.call("get_integrity_errors") as Array).is_empty(), "Six-axis craft integrity remains clean after directional propulsion testing")

	if _failures.is_empty():
		print("STAGE22_DIRECTIONAL_THRUST_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE22_DIRECTIONAL_THRUST_SMOKE_TEST: %s" % failure)
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

func _orientation_for_force_direction(direction: Vector3i) -> int:
	for orientation_index in ORIENTATION.ORIENTATION_COUNT:
		var basis := ORIENTATION.get_basis(orientation_index)
		if Vector3i(basis * Vector3(0, 0, -1)) == direction:
			return orientation_index
	return 0

func _build_touch_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)

func _send_touch(control: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
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
