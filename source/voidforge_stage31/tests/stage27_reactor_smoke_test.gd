extends Node
## Stage 27 verification for the first production reactor/generator block and its integration
## with the Stage 25 power bus and Stage 26 battery storage.

const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	var seat := BlockDB.call("get_block", &"pilot_cradle_large") as Resource
	var thruster := BlockDB.call("get_block", &"pulse_thruster_large") as Resource
	var gyro := BlockDB.call("get_block", &"vector_gyro_large") as Resource
	var battery := BlockDB.call("get_block", &"flux_reservoir_large") as Resource
	var reactor := BlockDB.call("get_block", &"helix_core_reactor_large") as Resource
	_assert(seat != null and thruster != null and gyro != null and battery != null and reactor != null, "Stage 27 fixtures resolve from authoritative BlockDB")
	if reactor == null:
		_finish()
		return

	_assert(StringName(reactor.get("functional_type")) == &"reactor", "Helix Core uses the reactor functional type")
	_assert(is_equal_approx(float(reactor.get("power_production_kw")), 480.0), "Helix Core provides 480 kW fixed electrical generation")
	_assert(is_equal_approx(float(reactor.get("heat_generation_kw")), 145.0), "Helix Core carries 145 kW heat-generation metadata")
	_assert(is_equal_approx(float(reactor.get("mass_kg")), 920.0), "Helix Core contributes 920 kg authoritative mass")
	_assert(StringName(reactor.get("presentation_shape")) == &"reactor", "Helix Core uses its dedicated reactor presentation family")
	_assert(StringName(reactor.get("presentation_material_id")) == &"power_generation", "Helix Core uses the production-generation material family")
	_assert((reactor.call("get_validation_errors", ItemDB) as Array).is_empty(), "Helix Core passes BlockDefinition validation")

	var grid := _make_grid("ReactorPoweredCraft", Vector3(0, 30, 0), true)
	var presenter := PRESENTER_SCRIPT.new() as Node3D
	presenter.name = "BlockPresenter"
	grid.add_child(presenter)
	var seat_instance := grid.call("place_block", seat, Vector3i.ZERO, 0) as Resource
	grid.call("place_block", thruster, Vector3i(0, 0, 1), 0)
	grid.call("place_block", gyro, Vector3i(0, 1, 0), 0)
	var battery_instance := grid.call("place_block", battery, Vector3i(1, 0, 0), 0) as Resource
	var reactor_instance := grid.call("place_block", reactor, Vector3i(-1, 0, 0), 0) as Resource
	var reactor_id := int(reactor_instance.get("instance_id"))
	var battery_id := int(battery_instance.get("instance_id"))
	presenter.call("flush_geometry_now")
	presenter.call("flush_collision_now")

	_assert((grid.call("get_power_producer_instance_ids") as Array).has(reactor_id), "Power cache discovers the production reactor as a generator")
	_assert(is_equal_approx(float(grid.call("get_total_power_generation_kw")), 480.0), "One Helix Core contributes exactly 480 kW")
	_assert(is_equal_approx(float(grid.call("get_total_rated_power_demand_kw")), 216.0), "Seat, thruster, and gyro retain 216 kW rated demand")
	var reactor_state := grid.call("get_block_power_state", reactor_id) as Dictionary
	_assert(StringName(reactor_state.get("status", &"")) == &"producer" and bool(reactor_state.get("powered", false)), "Reactor diagnostics report a powered producer")
	_assert(int(presenter.call("get_block_visual_count", reactor_id)) == 9, "Reactor placeholder uses nine batched visual primitives")

	var actor := Node.new()
	add_child(actor)
	_assert(bool(grid.call("try_claim_manual_control", actor, int(seat_instance.get("instance_id")))), "Pilot can claim the reactor-powered craft")
	grid.call("set_dynamic_simulation_enabled", true)
	grid.call("set_manual_translation_input", actor, Vector3(0, 0, -1))
	grid.call("set_manual_rotation_input", actor, Vector3(1, 0, 0))
	_assert(is_equal_approx(float(grid.call("get_active_power_demand_kw")), 216.0), "Full seat + thruster + gyro activity requests 216 kW")
	_assert(is_equal_approx(float(grid.call("get_power_satisfaction_ratio")), 1.0), "480 kW reactor fully satisfies simultaneous propulsion and gyro load")
	_assert((grid.call("get_active_manual_force_local_n") as Vector3).distance_to(Vector3(0, 0, -48000)) < 0.2, "Reactor power permits full 48 kN thrust")
	_assert((grid.call("get_active_manual_torque_local_nm") as Vector3).distance_to(Vector3(120000, 0, 0)) < 0.2, "Reactor power permits full 120 kN·m gyro torque")
	grid.call("stop_motion")
	await _physics_frames(8)
	_assert(grid.linear_velocity.length() > 0.01 and grid.angular_velocity.length() > 0.01, "Reactor-powered craft produces real translation and rotation")

	grid.call("clear_manual_thrust_input", actor)
	grid.call("clear_manual_rotation_input", actor)
	grid.call("release_manual_control", actor)
	grid.call("set_battery_stored_energy_kwh", battery_id, 10.0)
	var before_charge := float(grid.call("get_battery_stored_energy_kwh", battery_id))
	await _physics_frames(16)
	var after_charge := float(grid.call("get_battery_stored_energy_kwh", battery_id))
	var battery_state := grid.call("get_battery_state", battery_id) as Dictionary
	_assert(after_charge > before_charge, "Idle reactor surplus recharges the Flux Reservoir over real physics time")
	_assert(absf(float(battery_state.get("charge_kw", 0.0)) - 180.0) < 0.5, "Battery charging remains capped at its 180 kW input rate")

	var second_reactor := grid.call("place_block", reactor, Vector3i(-2, 0, 0), 0) as Resource
	_assert(second_reactor != null and is_equal_approx(float(grid.call("get_total_power_generation_kw")), 960.0), "Two Helix Core reactors add to 960 kW generation")
	grid.call("remove_block_by_instance_id", int(second_reactor.get("instance_id")))
	_assert(is_equal_approx(float(grid.call("get_total_power_generation_kw")), 480.0), "Removing one reactor immediately rebuilds generation to 480 kW")

	var save_state := grid.call("get_save_state") as Dictionary
	var restored := _make_grid("RestoredReactorCraft", Vector3(0, 46, 0), false)
	_assert(bool(restored.call("load_save_state", save_state)), "Reactor craft persists through the version-2 grid save format")
	var restored_reactors := []
	for instance in restored.call("get_all_blocks") as Array:
		if StringName(instance.get("block_id")) == &"helix_core_reactor_large":
			restored_reactors.append(instance)
	_assert(restored_reactors.size() == 1, "Save/load restores exactly one production reactor")
	_assert(is_equal_approx(float(restored.call("get_total_power_generation_kw")), 480.0), "Loaded reactor rebuilds the power-generation cache")
	_assert((restored.call("get_integrity_errors") as Array).is_empty(), "Loaded reactor grid passes integrity auditing")

	grid.call("remove_block_by_instance_id", reactor_id)
	_assert(is_equal_approx(float(grid.call("get_total_power_generation_kw")), 0.0), "Removing the final reactor leaves no fixed generation")
	_assert(float(grid.call("get_power_satisfaction_ratio")) >= 0.999, "Stored battery energy takes over after reactor removal when demand resumes")

	_finish()

func _make_grid(grid_name: String, position: Vector3, with_power: bool) -> RigidBody3D:
	var grid := GRID_SCRIPT.new() as RigidBody3D
	grid.name = grid_name
	grid.set("grid_profile", LARGE_PROFILE)
	grid.set("dynamic_gravity_scale", 0.0)
	grid.set("dynamic_linear_damp", 0.0)
	grid.set("dynamic_angular_damp", 0.0)
	grid.set("power_network_enabled", with_power)
	grid.position = position
	add_child(grid)
	return grid

func _physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _finish() -> void:
	if _failures.is_empty():
		print("STAGE27_REACTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE27_REACTOR_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
