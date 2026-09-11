extends Node
## Stage 23 end-to-end checks for data-driven gyroscope torque, pilot authority,
## yaw/pitch/roll InputMap control, persistence, and mass/physics-aware response.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")

var _failures: Array[String] = []
var _player: CharacterBody3D

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	var gyro := BlockDB.call("get_block", &"vector_gyro_large") as Resource
	var seat := BlockDB.call("get_block", &"pilot_cradle_large") as Resource
	var heavy := BlockDB.call("get_block", &"armor_shell_heavy_large") as Resource
	_assert(gyro != null and seat != null and heavy != null, "Stage 23 control fixtures resolve from authoritative BlockDB")
	if gyro != null:
		_assert(StringName(gyro.get("category")) == &"control" and StringName(gyro.get("functional_type")) == &"gyroscope", "Vector Gyro L carries control/gyroscope functional metadata")
		_assert(is_equal_approx(float(gyro.get("gyro_torque_nm")), 120000.0), "Vector Gyro L exposes 120 kN·m rated torque")
		_assert(is_equal_approx(float(gyro.get("mass_kg")), 610.0), "Vector Gyro L contributes 610 kg authoritative mass")

	var grid := _make_grid("GyroGrid", Vector3(0, 25, 0))
	var presenter := _attach_presenter(grid)
	var seat_instance := grid.call("place_block", seat, Vector3i.ZERO, 0) as Resource
	var gyro_instance := grid.call("place_block", gyro, Vector3i(0, 1, 0), 0) as Resource
	presenter.call("flush_collision_now")
	presenter.call("flush_geometry_now")
	var seat_presenter := presenter.call("get_control_seat_presenter") as Node3D
	seat_presenter.call("flush_now")
	var seat_proxy := seat_presenter.call("get_control_seat", int(seat_instance.get("instance_id"))) as Area3D
	_assert(int(grid.call("get_gyroscope_count")) == 1, "Grid discovers one installed Vector Gyro")
	_assert(is_equal_approx(float(grid.call("get_total_gyro_torque_nm")), 120000.0), "Single gyro contributes exactly 120 kN·m rotational authority")
	_assert((grid.call("get_gyroscope_instance_ids") as Array).has(int(gyro_instance.get("instance_id"))), "Gyroscope cache records the exact block instance ID")
	_assert(int(presenter.call("get_block_visual_count", int(gyro_instance.get("instance_id")))) == 5, "Vector Gyro placeholder uses five batched visual primitives")

	var second_gyro := grid.call("place_block", gyro, Vector3i(1, 1, 0), 7) as Resource
	_assert(second_gyro != null and int(grid.call("get_gyroscope_count")) == 2, "A second gyro is independently installable at another orientation")
	_assert(is_equal_approx(float(grid.call("get_total_gyro_torque_nm")), 240000.0), "Two gyros add to 240 kN·m available torque")
	grid.call("remove_block_by_instance_id", int(second_gyro.get("instance_id")))
	_assert(int(grid.call("get_gyroscope_count")) == 1 and is_equal_approx(float(grid.call("get_total_gyro_torque_nm")), 120000.0), "Removing a gyro immediately reduces cached torque authority")

	var save_state := grid.call("get_save_state") as Dictionary
	var restored := _make_grid("RestoredGyroGrid", Vector3(0, 35, 0))
	_assert(bool(restored.call("load_save_state", save_state)), "Gyroscope block survives versioned grid save/load")
	_assert(int(restored.call("get_gyroscope_count")) == 1 and is_equal_approx(float(restored.call("get_total_gyro_torque_nm")), 120000.0), "Loaded grid reconstructs gyroscope cache from stable BlockDB IDs")

	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_player.position = Vector3(0, 25, 7)
	add_child(_player)
	await get_tree().process_frame
	_assert(not bool(grid.call("set_manual_rotation_input", _player, Vector3(1, 0, 0))), "Rotation commands reject actors without Pilot Cradle authority")
	_assert(bool(_player.call("enter_control_seat", seat_proxy)), "Player claims gyro craft through its real Pilot Cradle")
	_assert(bool(grid.call("set_dynamic_simulation_enabled", true)), "Gyro craft enters dynamic rigid-body simulation")
	_assert(bool(grid.call("set_manual_rotation_input", _player, Vector3(2.0, -2.0, 0.5))), "Authorized pilot can command tri-axis gyro input")
	_assert((grid.call("get_manual_rotation_input_local") as Vector3).distance_to(Vector3(1.0, -1.0, 0.5)) < 0.001, "Manual gyro input clamps independently on pitch/yaw/roll")
	_assert((grid.call("get_active_manual_torque_local_nm") as Vector3).distance_to(Vector3(120000.0, -120000.0, 60000.0)) < 0.1, "Active local torque equals clamped pilot input multiplied by installed gyro authority")
	grid.call("clear_manual_rotation_input", _player)

	var input_cases := [
		{"action": "vehicle_pitch_up", "expected": Vector3.RIGHT, "name": "pitch up"},
		{"action": "vehicle_pitch_down", "expected": Vector3.LEFT, "name": "pitch down"},
		{"action": "vehicle_yaw_left", "expected": Vector3.UP, "name": "yaw left"},
		{"action": "vehicle_yaw_right", "expected": Vector3.DOWN, "name": "yaw right"},
		{"action": "vehicle_roll_right", "expected": Vector3.BACK, "name": "roll right"},
		{"action": "vehicle_roll_left", "expected": Vector3.FORWARD, "name": "roll left"},
	]
	for case in input_cases:
		_reset_dynamic_grid(grid)
		Input.action_press(case["action"], 1.0)
		await _physics_frames(10)
		Input.action_release(case["action"])
		await _physics_frames(2)
		var omega := grid.angular_velocity
		_assert(omega.length() > 0.05 and omega.normalized().dot(case["expected"]) > 0.82, "InputMap %s applies real rigid-body torque around the expected craft-local axis" % String(case["name"]))

	for action in ["vehicle_pitch_up", "vehicle_pitch_down", "vehicle_yaw_left", "vehicle_yaw_right", "vehicle_roll_left", "vehicle_roll_right"]:
		_assert(InputMap.has_action(action), "Stage 24 mobile-rotation foundation exposes InputMap action '%s'" % action)

	var light := _make_gyro_craft("LightGyroCraft", Vector3(-12, 45, 0), seat, gyro, heavy, 0)
	var heavy_craft := _make_gyro_craft("HeavyGyroCraft", Vector3(12, 45, 0), seat, gyro, heavy, 4)
	var light_grid := light["grid"] as RigidBody3D
	var heavy_grid := heavy_craft["grid"] as RigidBody3D
	var light_actor := Node.new()
	var heavy_actor := Node.new()
	add_child(light_actor)
	add_child(heavy_actor)
	_assert(bool(light_grid.call("try_claim_manual_control", light_actor, int(light["seat_id"]))) and bool(heavy_grid.call("try_claim_manual_control", heavy_actor, int(heavy_craft["seat_id"]))), "Physics comparison crafts claim valid control-seat authority")
	light_grid.call("set_dynamic_simulation_enabled", true)
	heavy_grid.call("set_dynamic_simulation_enabled", true)
	light_grid.call("set_manual_rotation_input", light_actor, Vector3(0, 1, 0))
	heavy_grid.call("set_manual_rotation_input", heavy_actor, Vector3(0, 1, 0))
	await _physics_frames(18)
	var light_spin := light_grid.angular_velocity.length()
	var heavy_spin := heavy_grid.angular_velocity.length()
	_assert(float(heavy_grid.call("get_total_mass_kg")) > float(light_grid.call("get_total_mass_kg")), "Heavy gyro comparison craft has greater authoritative block mass")
	_assert(light_spin > heavy_spin * 1.15, "Identical gyro torque produces a slower rotational response on the heavier rigid-body craft")

	_player.call("exit_control_seat")
	await _physics_frames(2)
	_assert((grid.call("get_manual_rotation_input_local") as Vector3).length_squared() < 0.0001, "Exiting the Pilot Cradle clears gyro command state")
	_assert(not bool(grid.call("set_manual_rotation_input", _player, Vector3(0, 1, 0))), "Former pilot cannot command gyros after exiting the seat")
	_assert((grid.call("get_integrity_errors") as Array).is_empty(), "Gyro craft grid integrity remains clean after rotational physics testing")

	if _failures.is_empty():
		print("STAGE23_GYROSCOPE_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE23_GYROSCOPE_SMOKE_TEST: %s" % failure)
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

func _attach_presenter(grid: RigidBody3D) -> Node3D:
	var presenter := PRESENTER_SCRIPT.new() as Node3D
	presenter.name = "BlockPresenter"
	grid.add_child(presenter)
	return presenter

func _make_gyro_craft(craft_name: String, position: Vector3, seat_def: Resource, gyro_def: Resource, ballast_def: Resource, ballast_count: int) -> Dictionary:
	var grid := _make_grid(craft_name, position)
	var presenter := _attach_presenter(grid)
	var seat_instance := grid.call("place_block", seat_def, Vector3i.ZERO, 0) as Resource
	grid.call("place_block", gyro_def, Vector3i(0, 1, 0), 0)
	for index in ballast_count:
		grid.call("place_block", ballast_def, Vector3i(index + 1, 0, 0), 0)
	presenter.call("flush_collision_now")
	presenter.call("flush_geometry_now")
	return {"grid": grid, "seat_id": int(seat_instance.get("instance_id"))}

func _reset_dynamic_grid(grid: RigidBody3D) -> void:
	grid.call("clear_manual_rotation_input", _player)
	grid.call("set_dynamic_simulation_enabled", false)
	grid.global_transform = Transform3D(Basis.IDENTITY, grid.global_position)
	grid.call("stop_motion")
	grid.call("set_dynamic_simulation_enabled", true)
	await get_tree().physics_frame

func _physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
