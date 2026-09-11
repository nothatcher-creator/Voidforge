extends Node
## Stage 25 verification for cached grid power generation/demand, functional states,
## brownout scaling, persistence reconstruction, and real powered propulsion/gyro physics.

const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	var seat := BlockDB.call("get_block", &"pilot_cradle_large") as Resource
	var thruster := BlockDB.call("get_block", &"pulse_thruster_large") as Resource
	var gyro := BlockDB.call("get_block", &"vector_gyro_large") as Resource
	var source := BlockDB.call("get_block", &"dev_power_source_large") as Resource
	_assert(seat != null and thruster != null and gyro != null and source != null, "Stage 25 power fixtures resolve from authoritative BlockDB")
	if seat != null and thruster != null and gyro != null and source != null:
		_assert(is_equal_approx(float(seat.get("power_use_kw")), 6.0), "Pilot Cradle exposes 6 kW rated control demand")
		_assert(is_equal_approx(float(thruster.get("power_use_kw")), 120.0), "Pulse Thruster exposes 120 kW full-throttle demand")
		_assert(is_equal_approx(float(gyro.get("power_use_kw")), 90.0), "Vector Gyro exposes 90 kW full-authority demand")
		_assert(StringName(source.get("functional_type")) == &"power_source" and is_equal_approx(float(source.get("power_production_kw")), 180.0), "Development power source exposes 180 kW deterministic generation")

	var grid := _make_grid("PowerGrid", Vector3(0, 30, 0))
	var seat_instance := grid.call("place_block", seat, Vector3i.ZERO, 0) as Resource
	var thruster_instance := grid.call("place_block", thruster, Vector3i(0, 0, 1), 0) as Resource
	var gyro_instance := grid.call("place_block", gyro, Vector3i(0, 1, 0), 0) as Resource
	_assert(int(grid.call("get_power_consumer_instance_ids").size()) == 3, "Power cache discovers seat, thruster, and gyro consumers")
	_assert(is_equal_approx(float(grid.call("get_total_rated_power_demand_kw")), 216.0), "Installed functional blocks expose 216 kW total rated demand")
	_assert(is_equal_approx(float(grid.call("get_total_power_generation_kw")), 0.0), "Craft without a source reports zero electrical generation")

	var actor := Node.new()
	add_child(actor)
	_assert(bool(grid.call("try_claim_manual_control", actor, int(seat_instance.get("instance_id")))), "Pilot can claim the unpowered craft for diagnostics")
	grid.call("set_dynamic_simulation_enabled", true)
	grid.call("set_manual_translation_input", actor, Vector3(0, 0, -1))
	grid.call("set_manual_rotation_input", actor, Vector3(0, 1, 0))
	_assert(is_equal_approx(float(grid.call("get_active_power_demand_kw")), 216.0), "Active full thrust + gyro + occupied seat requests 216 kW")
	_assert(is_equal_approx(float(grid.call("get_power_satisfaction_ratio")), 0.0), "No-source craft has zero power satisfaction under active load")
	_assert((grid.call("get_active_manual_force_local_n") as Vector3).length() < 0.1, "Unpowered thruster produces zero force")
	_assert((grid.call("get_active_manual_torque_local_nm") as Vector3).length() < 0.1, "Unpowered gyro produces zero torque")
	var dead_thruster_state := grid.call("get_block_power_state", int(thruster_instance.get("instance_id"))) as Dictionary
	_assert(StringName(dead_thruster_state.get("status", &"")) == &"unpowered" and not bool(dead_thruster_state.get("powered", true)), "Functional state reports active thruster as unpowered")

	var source_one := grid.call("place_block", source, Vector3i(2, 0, 0), 0) as Resource
	_assert(source_one != null and int(grid.call("get_power_producer_instance_ids").size()) == 1, "Adding one source immediately rebuilds the cached producer list")
	_assert(is_equal_approx(float(grid.call("get_total_power_generation_kw")), 180.0), "One development source generates 180 kW")
	var brownout_ratio := float(grid.call("get_power_satisfaction_ratio"))
	_assert(absf(brownout_ratio - (180.0 / 216.0)) < 0.0001, "180/216 kW load produces the expected proportional brownout ratio")
	_assert((grid.call("get_active_manual_force_local_n") as Vector3).distance_to(Vector3(0, 0, -40000)) < 0.2, "Brownout scales 48 kN thruster output to 40 kN")
	_assert((grid.call("get_active_manual_torque_local_nm") as Vector3).distance_to(Vector3(0, 100000, 0)) < 0.2, "Brownout scales 120 kN*m gyro torque to 100 kN*m")
	var brownout_state := grid.call("get_block_power_state", int(gyro_instance.get("instance_id"))) as Dictionary
	_assert(StringName(brownout_state.get("status", &"")) == &"brownout" and not bool(brownout_state.get("powered", true)), "Functional state reports partial-power gyro as brownout")

	var source_two := grid.call("place_block", source, Vector3i(-2, 0, 0), 0) as Resource
	_assert(source_two != null and is_equal_approx(float(grid.call("get_total_power_generation_kw")), 360.0), "Two sources provide 360 kW generation")
	_assert(bool(grid.call("has_sufficient_power")) and is_equal_approx(float(grid.call("get_power_satisfaction_ratio")), 1.0), "360 kW supply fully satisfies the 216 kW active demand")
	_assert((grid.call("get_active_manual_force_local_n") as Vector3).distance_to(Vector3(0, 0, -48000)) < 0.2, "Fully powered thruster restores its complete 48 kN force")
	_assert((grid.call("get_active_manual_torque_local_nm") as Vector3).distance_to(Vector3(0, 120000, 0)) < 0.2, "Fully powered gyro restores its complete 120 kN*m torque")
	var producer_state := grid.call("get_block_power_state", int(source_two.get("instance_id"))) as Dictionary
	_assert(StringName(producer_state.get("status", &"")) == &"producer" and is_equal_approx(float(producer_state.get("generation_kw", 0.0)), 180.0), "Power-source functional state exposes producer generation")

	grid.call("stop_motion")
	await _physics_frames(12)
	_assert(grid.linear_velocity.length() > 0.01 and grid.angular_velocity.length() > 0.01, "Fully powered network drives real rigid-body translation and rotation")

	var state := grid.call("get_power_network_state") as Dictionary
	_assert(int(state.get("producer_count", 0)) == 2 and int(state.get("consumer_count", 0)) == 3, "Power diagnostics report exact producer/consumer counts")
	_assert(is_equal_approx(float(state.get("generation_kw", 0.0)), 360.0) and is_equal_approx(float(state.get("active_demand_kw", 0.0)), 216.0), "Power diagnostics expose generation and live demand")
	_assert(absf(float(state.get("surplus_kw", 0.0)) - 144.0) < 0.001, "Power diagnostics expose 144 kW active surplus")

	var save_state := grid.call("get_save_state") as Dictionary
	var restored := _make_grid("RestoredPowerGrid", Vector3(0, 45, 0))
	_assert(bool(restored.call("load_save_state", save_state)), "Power-network craft survives versioned grid save/load")
	_assert(is_equal_approx(float(restored.call("get_total_power_generation_kw")), 360.0), "Loaded grid reconstructs producer generation from stable block IDs")
	_assert(is_equal_approx(float(restored.call("get_total_rated_power_demand_kw")), 216.0), "Loaded grid reconstructs rated consumer demand from stable block IDs")
	_assert((restored.call("get_integrity_errors") as Array).is_empty(), "Loaded powered grid passes the authoritative integrity audit")

	grid.call("remove_block_by_instance_id", int(source_one.get("instance_id")))
	_assert(is_equal_approx(float(grid.call("get_total_power_generation_kw")), 180.0), "Removing a source invalidates and rebuilds generation immediately")

	if _failures.is_empty():
		print("STAGE25_POWER_NETWORK_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE25_POWER_NETWORK_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _make_grid(grid_name: String, position: Vector3) -> RigidBody3D:
	var grid := GRID_SCRIPT.new() as RigidBody3D
	grid.name = grid_name
	grid.set("grid_profile", LARGE_PROFILE)
	grid.set("dynamic_gravity_scale", 0.0)
	grid.set("dynamic_linear_damp", 0.0)
	grid.set("dynamic_angular_damp", 0.0)
	grid.set("priority_load_shedding_enabled", false)
	grid.position = position
	add_child(grid)
	return grid

func _physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
