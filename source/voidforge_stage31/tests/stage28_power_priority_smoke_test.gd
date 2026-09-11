extends Node
## Stage 28 deterministic power-priority and load-shedding regression test.

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
	var aux := BlockDB.call("get_block", &"dev_aux_load_large") as Resource
	var battery := BlockDB.call("get_block", &"flux_reservoir_large") as Resource
	_assert(seat != null and thruster != null and gyro != null and source != null and aux != null and battery != null, "Stage 28 power-priority fixtures resolve from BlockDB")
	if seat == null or thruster == null or gyro == null or source == null or aux == null or battery == null:
		_finish()
		return

	_assert(int(seat.get("power_priority")) == 0 and StringName(seat.call("get_power_priority_name")) == &"critical", "Pilot Cradle is Critical priority")
	_assert(int(gyro.get("power_priority")) == 1 and StringName(gyro.call("get_power_priority_name")) == &"high", "Vector Gyro is High priority")
	_assert(int(thruster.get("power_priority")) == 2 and StringName(thruster.call("get_power_priority_name")) == &"normal", "Pulse Thruster is Normal priority")
	_assert(int(aux.get("power_priority")) == 3 and StringName(aux.call("get_power_priority_name")) == &"low", "Development auxiliary load is Low priority")

	var grid := _make_grid("PriorityGrid", Vector3(0, 30, 0))
	var seat_instance := grid.call("place_block", seat, Vector3i.ZERO, 0) as Resource
	var gyro_instance := grid.call("place_block", gyro, Vector3i(0, 1, 0), 0) as Resource
	var thruster_instance := grid.call("place_block", thruster, Vector3i(0, 0, 1), 0) as Resource
	var source_instance := grid.call("place_block", source, Vector3i(-1, 0, 0), 0) as Resource
	var aux_instance := grid.call("place_block", aux, Vector3i(1, 0, 0), 0) as Resource
	_assert(seat_instance != null and gyro_instance != null and thruster_instance != null and source_instance != null and aux_instance != null, "Priority test craft places all five blocks")
	if seat_instance == null or gyro_instance == null or thruster_instance == null or source_instance == null or aux_instance == null:
		_finish()
		return

	var actor := Node.new()
	actor.name = "PriorityPilot"
	add_child(actor)
	_assert(bool(grid.call("try_claim_manual_control", actor, int(seat_instance.get("instance_id")))), "Pilot claims priority test craft")
	grid.call("set_manual_translation_input", actor, Vector3(0, 0, -1))
	grid.call("set_manual_rotation_input", actor, Vector3(0, 1, 0))

	_assert(is_equal_approx(float(grid.call("get_active_power_demand_kw")), 276.0), "Full seat + gyro + thruster + auxiliary load requests 276 kW")
	_assert(is_equal_approx(float(grid.call("get_total_power_generation_kw")), 180.0), "Priority test craft has 180 kW fixed generation")
	var expected_overall := 180.0 / 276.0
	_assert(absf(float(grid.call("get_power_satisfaction_ratio")) - expected_overall) < 0.0001, "Network-wide satisfaction still reports allocated/active demand")

	var seat_id := int(seat_instance.get("instance_id"))
	var gyro_id := int(gyro_instance.get("instance_id"))
	var thruster_id := int(thruster_instance.get("instance_id"))
	var aux_id := int(aux_instance.get("instance_id"))
	_assert(absf(float(grid.call("get_block_allocated_power_kw", seat_id)) - 6.0) < 0.001, "Critical Pilot Cradle receives its full 6 kW")
	_assert(absf(float(grid.call("get_block_allocated_power_kw", gyro_id)) - 90.0) < 0.001, "High-priority gyro receives its full 90 kW")
	_assert(absf(float(grid.call("get_block_allocated_power_kw", thruster_id)) - 84.0) < 0.001, "Normal thruster receives the remaining 84 kW")
	_assert(float(grid.call("get_block_allocated_power_kw", aux_id)) < 0.001, "Low-priority auxiliary load is fully shed")
	_assert(absf(float(grid.call("get_block_power_satisfaction_ratio", thruster_id)) - 0.7) < 0.0001, "Normal thruster brownout ratio is exactly 70 percent")
	_assert(is_equal_approx(float(grid.call("get_block_power_satisfaction_ratio", gyro_id)), 1.0), "High-priority gyro remains fully powered")
	_assert(is_equal_approx(float(grid.call("get_block_power_satisfaction_ratio", aux_id)), 0.0), "Low-priority auxiliary load receives zero power")

	var seat_state := grid.call("get_block_power_state", seat_id) as Dictionary
	var gyro_state := grid.call("get_block_power_state", gyro_id) as Dictionary
	var thruster_state := grid.call("get_block_power_state", thruster_id) as Dictionary
	var aux_state := grid.call("get_block_power_state", aux_id) as Dictionary
	_assert(StringName(seat_state.get("status", &"")) == &"powered" and StringName(seat_state.get("priority_name", &"")) == &"critical", "Critical seat state reports powered")
	_assert(StringName(gyro_state.get("status", &"")) == &"powered" and StringName(gyro_state.get("priority_name", &"")) == &"high", "High gyro state reports powered")
	_assert(StringName(thruster_state.get("status", &"")) == &"brownout" and StringName(thruster_state.get("priority_name", &"")) == &"normal", "Normal thruster reports brownout")
	_assert(StringName(aux_state.get("status", &"")) == &"load_shed" and StringName(aux_state.get("priority_name", &"")) == &"low", "Low auxiliary consumer reports load_shed")

	var force := grid.call("get_active_manual_force_local_n") as Vector3
	var torque := grid.call("get_active_manual_torque_local_nm") as Vector3
	_assert(force.distance_to(Vector3(0, 0, -33600)) < 0.2, "Priority allocator reduces 48 kN thruster to 33.6 kN without touching higher tiers")
	_assert(torque.distance_to(Vector3(0, 120000, 0)) < 0.2, "High-priority gyro retains full 120 kN*m torque")

	var network := grid.call("get_power_network_state") as Dictionary
	_assert(bool(network.get("priority_load_shedding_enabled", false)), "Priority load shedding is enabled by default")
	_assert(bool(network.get("load_shedding_active", false)), "Network diagnostics report active load shedding")
	_assert(absf(float(network.get("allocated_kw", 0.0)) - 180.0) < 0.001 and absf(float(network.get("shed_kw", 0.0)) - 96.0) < 0.001, "Diagnostics expose 180 kW allocated and 96 kW shed")
	var tiers := network.get("priority_tiers", []) as Array
	_assert(tiers.size() == 4, "Diagnostics expose four ordered priority tiers")
	if tiers.size() == 4:
		_assert(StringName((tiers[0] as Dictionary).get("name", &"")) == &"critical" and is_equal_approx(float((tiers[0] as Dictionary).get("satisfaction_ratio", 0.0)), 1.0), "Critical tier diagnostics are fully satisfied")
		_assert(StringName((tiers[1] as Dictionary).get("name", &"")) == &"high" and is_equal_approx(float((tiers[1] as Dictionary).get("satisfaction_ratio", 0.0)), 1.0), "High tier diagnostics are fully satisfied")
		_assert(StringName((tiers[2] as Dictionary).get("name", &"")) == &"normal" and absf(float((tiers[2] as Dictionary).get("satisfaction_ratio", 0.0)) - 0.7) < 0.0001, "Normal tier diagnostics report 70 percent satisfaction")
		_assert(StringName((tiers[3] as Dictionary).get("name", &"")) == &"low" and is_equal_approx(float((tiers[3] as Dictionary).get("satisfaction_ratio", 1.0)), 0.0), "Low tier diagnostics report complete shedding")

	grid.call("set_dynamic_simulation_enabled", true)
	grid.call("stop_motion")
	await _physics_frames(12)
	_assert(grid.linear_velocity.length() > 0.01 and grid.angular_velocity.length() > 0.01, "Priority-limited force and full high-priority torque drive real rigid-body physics")

	var battery_instance := grid.call("place_block", battery, Vector3i(2, 0, 0), 0) as Resource
	_assert(battery_instance != null, "Adding a Flux Reservoir succeeds")
	_assert(is_equal_approx(float(grid.call("get_power_satisfaction_ratio")), 1.0), "Battery discharge capacity eliminates load shedding when enough bus power is available")
	_assert((grid.call("get_active_manual_force_local_n") as Vector3).distance_to(Vector3(0, 0, -48000)) < 0.2, "Battery-backed network restores full thruster force")
	var battery_network := grid.call("get_power_network_state") as Dictionary
	_assert(not bool(battery_network.get("load_shedding_active", true)) and float(battery_network.get("shed_kw", 1.0)) < 0.001, "Battery-backed diagnostics show no shed load")

	grid.call("remove_block_by_instance_id", int(battery_instance.get("instance_id")))
	_assert(absf(float(grid.call("get_block_power_satisfaction_ratio", thruster_id)) - 0.7) < 0.0001, "Removing the battery immediately restores priority brownout")

	grid.set("priority_load_shedding_enabled", false)
	var proportional := 180.0 / 276.0
	_assert(absf(float(grid.call("get_block_power_satisfaction_ratio", seat_id)) - proportional) < 0.0001, "Compatibility mode can still apply proportional brownout to Critical consumers")
	_assert(absf(float(grid.call("get_block_power_satisfaction_ratio", aux_id)) - proportional) < 0.0001, "Compatibility mode applies the same ratio to Low consumers")
	grid.set("priority_load_shedding_enabled", true)

	var save_state := grid.call("get_save_state") as Dictionary
	var restored := _make_grid("RestoredPriorityGrid", Vector3(0, 45, 0))
	_assert(bool(restored.call("load_save_state", save_state)), "Priority craft survives grid save/load")
	var restored_seats := restored.call("get_control_seat_instance_ids") as Array[int]
	_assert(restored_seats.size() == 1, "Restored priority craft recovers its control seat")
	var restored_actor := Node.new()
	add_child(restored_actor)
	if restored_seats.size() == 1:
		_assert(bool(restored.call("try_claim_manual_control", restored_actor, restored_seats[0])), "Restored pilot claims control")
		restored.call("set_manual_translation_input", restored_actor, Vector3(0, 0, -1))
		restored.call("set_manual_rotation_input", restored_actor, Vector3(0, 1, 0))
		var restored_thrusters := restored.call("get_thruster_instance_ids") as Array[int]
		_assert(restored_thrusters.size() == 1 and absf(float(restored.call("get_block_power_satisfaction_ratio", restored_thrusters[0])) - 0.7) < 0.0001, "Loaded craft reconstructs data-driven Normal-priority thruster allocation")
	_assert((restored.call("get_integrity_errors") as Array).is_empty(), "Restored priority grid passes integrity audit")

	_finish()

func _make_grid(grid_name: String, position: Vector3) -> RigidBody3D:
	var grid := GRID_SCRIPT.new() as RigidBody3D
	grid.name = grid_name
	grid.set("grid_profile", LARGE_PROFILE)
	grid.set("dynamic_gravity_scale", 0.0)
	grid.set("dynamic_linear_damp", 0.0)
	grid.set("dynamic_angular_damp", 0.0)
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

func _finish() -> void:
	if _failures.is_empty():
		print("STAGE28_POWER_PRIORITY_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE28_POWER_PRIORITY_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)
