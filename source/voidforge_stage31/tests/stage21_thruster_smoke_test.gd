extends Node
## Stage 21 end-to-end checks for data-driven thrust, orientation, pilot authority,
## mass-dependent acceleration, persistence, and the temporary Android THR control.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")
const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")
const ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")

var _failures: Array[String] = []
var _player: CharacterBody3D
var _touch_controls: Control

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	var thruster := BlockDB.call("get_block", &"pulse_thruster_large") as Resource
	var seat := BlockDB.call("get_block", &"pilot_cradle_large") as Resource
	var frame := BlockDB.call("get_block", &"frame_reinforced_large") as Resource
	var heavy := BlockDB.call("get_block", &"armor_shell_heavy_large") as Resource
	_assert(thruster != null, "Pulse Thruster L resolves from authoritative BlockDB")
	if thruster != null:
		_assert(StringName(thruster.get("category")) == &"propulsion" and StringName(thruster.get("functional_type")) == &"thruster", "Pulse Thruster carries propulsion/thruster functional metadata")
		_assert(is_equal_approx(float(thruster.get("thrust_force_n")), 48000.0), "Pulse Thruster exposes a 48 kN rated force")
		_assert(Vector3i(thruster.get("thrust_direction_local")) == Vector3i(0, 0, -1), "Pulse Thruster declares a local negative-Z thrust axis")

	var orientation_grid := _make_grid("OrientationGrid", Vector3(0, 20, 0))
	var identity_instance := orientation_grid.call("place_block", thruster, Vector3i.ZERO, 0) as Resource
	var yaw_index := ORIENTATION.rotate_index_around_axis(0, Vector3i(0, 1, 0), 1)
	var rotated_instance := orientation_grid.call("place_block", thruster, Vector3i(2, 0, 0), yaw_index) as Resource
	_assert(identity_instance != null and rotated_instance != null, "Two independently oriented thrusters place on the same grid")
	var identity_force := orientation_grid.call("get_thruster_local_force_n", int(identity_instance.get("instance_id"))) as Vector3
	var rotated_force := orientation_grid.call("get_thruster_local_force_n", int(rotated_instance.get("instance_id"))) as Vector3
	_assert(identity_force.distance_to(Vector3(0, 0, -48000)) < 0.1, "Identity thruster force follows its declared local negative-Z axis")
	var expected_rotated := ORIENTATION.get_basis(yaw_index) * Vector3(0, 0, -48000)
	_assert(rotated_force.distance_to(expected_rotated) < 0.1 and rotated_force.distance_to(identity_force) > 1000.0, "Rotated block orientation rotates the physical thrust vector")
	_assert(int(orientation_grid.call("get_thruster_count")) == 2 and is_equal_approx(float(orientation_grid.call("get_total_rated_thrust_n")), 96000.0), "Grid propulsion cache discovers both thrusters and sums rated force")
	var combined := orientation_grid.call("get_combined_thruster_local_force_n") as Vector3
	_assert(combined.distance_to(identity_force + rotated_force) < 0.1, "Grid caches the vector sum of installed thrusters")

	var save_state := orientation_grid.call("get_save_state") as Dictionary
	var restored_grid := _make_grid("RestoredOrientationGrid", Vector3(0, 30, 0))
	_assert(bool(restored_grid.call("load_save_state", save_state)), "Thruster orientation survives versioned grid save/load")
	_assert(int(restored_grid.call("get_thruster_count")) == 2 and (restored_grid.call("get_combined_thruster_local_force_n") as Vector3).distance_to(combined) < 0.1, "Loaded grid rebuilds its propulsion cache from authoritative block state")
	restored_grid.call("remove_block_by_instance_id", int(rotated_instance.get("instance_id")))
	_assert(int(restored_grid.call("get_thruster_count")) == 1, "Removing a thruster invalidates and rebuilds propulsion cache correctly")

	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_player.position = Vector3(0, 20, 8)
	add_child(_player)
	await get_tree().process_frame

	var light := _make_powered_craft("LightCraft", Vector3(-8, 30, 0), seat, thruster, frame, 0)
	var heavy_craft := _make_powered_craft("HeavyCraft", Vector3(8, 30, 0), seat, thruster, heavy, 4)
	await _physics_frames(3)
	var light_grid := light["grid"] as RigidBody3D
	var light_seat := light["seat"] as Area3D
	var heavy_grid := heavy_craft["grid"] as RigidBody3D
	var heavy_seat := heavy_craft["seat"] as Area3D
	_assert(not bool(light_grid.call("set_manual_thrust_input", _player, 1.0)), "Thruster command is rejected before the player claims a control seat")
	_assert(bool(_player.call("enter_control_seat", light_seat)), "Player claims the light craft through its real Pilot Cradle")
	_assert(bool(light_grid.call("set_dynamic_simulation_enabled", true)), "Light craft enters dynamic simulation")
	light_grid.call("stop_motion")
	Input.action_press("vehicle_thrust_forward", 1.0)
	await _physics_frames(30)
	Input.action_release("vehicle_thrust_forward")
	await _physics_frames(2)
	var light_speed := light_grid.linear_velocity.length()
	var light_direction := light_grid.linear_velocity.normalized() if light_speed > 0.001 else Vector3.ZERO
	_assert(light_speed > 2.0, "Pilot-authorized forward input produces real rigid-body acceleration")
	_assert(light_direction.dot(-light_grid.global_transform.basis.z) > 0.95, "Craft acceleration follows the installed thruster's oriented force direction")
	_assert(float(light_grid.call("get_manual_thrust_strength")) < 0.001, "Releasing forward input clears manual thrust strength")
	_player.call("exit_control_seat")
	await _physics_frames(2)

	_assert(bool(_player.call("enter_control_seat", heavy_seat)), "Player can transfer to a heavier craft")
	_assert(bool(heavy_grid.call("set_dynamic_simulation_enabled", true)), "Heavy craft enters dynamic simulation")
	heavy_grid.call("stop_motion")
	Input.action_press("vehicle_thrust_forward", 1.0)
	await _physics_frames(30)
	Input.action_release("vehicle_thrust_forward")
	await _physics_frames(2)
	var heavy_speed := heavy_grid.linear_velocity.length()
	_assert(float(heavy_grid.call("get_total_mass_kg")) > float(light_grid.call("get_total_mass_kg")), "Heavy comparison craft has greater authoritative block mass")
	_assert(light_speed > heavy_speed * 1.35, "The same 48 kN thruster accelerates the lighter craft substantially more")

	_build_touch_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var thrust_button := _touch_controls.get_node("ThrustButton") as Control
	var look_area := _touch_controls.get_node("LookArea") as Control
	_assert(thrust_button.visible, "Android HUD reveals contextual THR control while seated")
	var center := thrust_button.get_global_rect().get_center()
	var probe := InputEventScreenTouch.new()
	probe.index = 81
	probe.position = center
	probe.pressed = true
	_assert(not bool(look_area.call("handle_screen_event", probe)), "THR button is excluded from camera-look touch ownership")
	_send_touch(thrust_button, 82, center, true)
	await _physics_frames(2)
	_assert(float(heavy_grid.call("get_manual_thrust_strength")) > 0.99, "Android THR button drives the shared vehicle_thrust_forward action")
	_send_touch(thrust_button, 82, center, false)
	await _physics_frames(2)
	_assert(float(heavy_grid.call("get_manual_thrust_strength")) < 0.001, "Releasing Android THR clears thrust input")
	_player.call("exit_control_seat")
	await _physics_frames(1)
	_assert(not thrust_button.visible, "Android THR control hides again on foot")
	_assert(not bool(heavy_grid.call("set_manual_thrust_input", _player, 1.0)), "Former pilot cannot command thrust after exiting the seat")
	_assert((heavy_grid.call("get_integrity_errors") as Array).is_empty(), "Thruster craft grid integrity remains clean after real propulsion tests")

	if _failures.is_empty():
		print("STAGE21_THRUSTER_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE21_THRUSTER_SMOKE_TEST: %s" % failure)
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

func _make_powered_craft(craft_name: String, position: Vector3, seat_def: Resource, thruster_def: Resource, ballast_def: Resource, ballast_count: int) -> Dictionary:
	var grid := _make_grid(craft_name, position)
	var presenter := PRESENTER_SCRIPT.new() as Node3D
	presenter.name = "BlockPresenter"
	grid.add_child(presenter)
	var seat_instance := grid.call("place_block", seat_def, Vector3i.ZERO, 0) as Resource
	grid.call("place_block", thruster_def, Vector3i(0, 0, 1), 0)
	for index in ballast_count:
		grid.call("place_block", ballast_def, Vector3i(index + 1, 0, 0), 0)
	presenter.call("flush_collision_now")
	presenter.call("flush_geometry_now")
	var seat_presenter := presenter.call("get_control_seat_presenter") as Node3D
	seat_presenter.call("flush_now")
	var seat_proxy := seat_presenter.call("get_control_seat", int(seat_instance.get("instance_id"))) as Area3D
	return {"grid": grid, "presenter": presenter, "seat": seat_proxy}

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
