extends Node
## Stage 26 verification for persistent battery energy, rate-limited charge/discharge,
## generator-loss operation, v1->v2 migration, and real time-based physics depletion.

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
	var battery := BlockDB.call("get_block", &"flux_reservoir_large") as Resource
	_assert(seat != null and thruster != null and gyro != null and source != null and battery != null, "Stage 26 fixtures resolve from authoritative BlockDB")
	if battery == null:
		_finish()
		return
	_assert(StringName(battery.get("functional_type")) == &"battery", "Flux Reservoir uses the battery functional type")
	_assert(is_equal_approx(float(battery.get("battery_capacity_kwh")), 60.0), "Flux Reservoir stores 60 kWh")
	_assert(is_equal_approx(float(battery.get("battery_initial_charge_fraction")), 0.5), "Flux Reservoir starts at 50% state of charge")
	_assert(is_equal_approx(float(battery.get("battery_max_charge_kw")), 180.0), "Flux Reservoir charge rate is capped at 180 kW")
	_assert(is_equal_approx(float(battery.get("battery_max_discharge_kw")), 240.0), "Flux Reservoir discharge rate is capped at 240 kW")
	_assert((battery.call("get_validation_errors", ItemDB) as Array).is_empty(), "Flux Reservoir passes BlockDefinition validation")

	var grid := _make_grid("BatteryOnlyCraft", Vector3(0, 30, 0))
	var seat_instance := grid.call("place_block", seat, Vector3i.ZERO, 0) as Resource
	var thruster_instance := grid.call("place_block", thruster, Vector3i(0, 0, 1), 0) as Resource
	var battery_instance := grid.call("place_block", battery, Vector3i(1, 0, 0), 0) as Resource
	var battery_id := int(battery_instance.get("instance_id"))
	_assert(int(grid.call("get_battery_count")) == 1, "Power cache discovers one installed battery")
	_assert(is_equal_approx(float(grid.call("get_total_battery_capacity_kwh")), 60.0), "Grid aggregates installed battery capacity")
	_assert(is_equal_approx(float(grid.call("get_battery_stored_energy_kwh", battery_id)), 30.0), "New battery initializes to 30 kWh")
	_assert(is_equal_approx(float(grid.call("get_battery_state_of_charge")), 0.5), "New battery reports 50% state of charge")
	_assert(int(grid.call("get_power_producer_instance_ids").size()) == 0, "Battery storage is not misclassified as fixed generation")

	var actor := Node.new()
	add_child(actor)
	_assert(bool(grid.call("try_claim_manual_control", actor, int(seat_instance.get("instance_id")))), "Pilot can claim battery-only craft")
	grid.call("set_dynamic_simulation_enabled", true)
	grid.call("set_manual_translation_input", actor, Vector3(0, 0, -1))
	_assert(is_equal_approx(float(grid.call("get_active_power_demand_kw")), 126.0), "Occupied seat plus full thruster requests 126 kW")
	_assert(is_equal_approx(float(grid.call("get_power_satisfaction_ratio")), 1.0), "Charged battery fully powers a 126 kW craft without a generator")
	_assert((grid.call("get_active_manual_force_local_n") as Vector3).distance_to(Vector3(0, 0, -48000)) < 0.2, "Battery-only craft receives the thruster's full 48 kN force")

	var signal_count := [0]
	grid.battery_storage_changed.connect(func(_stored: float, _capacity: float, _soc: float) -> void: signal_count[0] += 1)
	_assert(bool(grid.call("set_battery_stored_energy_kwh", battery_id, 0.01)), "Battery energy can be set through the guarded runtime API")
	_assert(signal_count[0] == 1, "Explicit battery energy changes emit battery_storage_changed")
	var runtime_seconds := float(grid.call("get_estimated_battery_runtime_seconds"))
	_assert(absf(runtime_seconds - (0.01 / 126.0 * 3600.0)) < 0.01, "Battery diagnostics estimate runtime from live deficit and stored energy")
	grid.call("stop_motion")
	await _physics_frames(8)
	var mid_energy := float(grid.call("get_battery_stored_energy_kwh", battery_id))
	_assert(mid_energy > 0.0 and mid_energy < 0.01, "Real physics time depletes battery energy while the thruster is active")
	_assert(grid.linear_velocity.length() > 0.01, "Battery-backed power produces real rigid-body motion with no generator")
	await _physics_frames(30)
	_assert(float(grid.call("get_battery_stored_energy_kwh", battery_id)) <= 0.00001, "Battery reaches empty after its stored energy is consumed")
	_assert(float(grid.call("get_power_satisfaction_ratio")) <= 0.0001, "Generator-less craft loses electrical satisfaction when the battery is empty")
	_assert((grid.call("get_active_manual_force_local_n") as Vector3).length() < 0.1, "Empty battery can no longer power the thruster")
	var empty_state := grid.call("get_battery_state", battery_id) as Dictionary
	_assert(StringName(empty_state.get("status", &"")) == &"empty", "Battery diagnostics report the empty state")

	grid.call("clear_manual_thrust_input", actor)
	grid.call("release_manual_control", actor)
	var source_instance := grid.call("place_block", source, Vector3i(-1, 0, 0), 0) as Resource
	_assert(source_instance != null, "Development source can be added to the depleted battery craft")
	await _physics_frames(3)
	var charging_state := grid.call("get_battery_state", battery_id) as Dictionary
	_assert(float(charging_state.get("charge_kw", 0.0)) > 179.0, "Excess generation recharges the battery at its 180 kW charge limit")
	var before_charge := float(grid.call("get_battery_stored_energy_kwh", battery_id))
	await _physics_frames(20)
	var after_charge := float(grid.call("get_battery_stored_energy_kwh", battery_id))
	_assert(after_charge > before_charge + 0.01, "Battery stored energy increases over real idle physics time")

	var rate_grid := _make_grid("RateLimitedBatteryCraft", Vector3(0, 42, 0))
	var rate_seat := rate_grid.call("place_block", seat, Vector3i.ZERO, 0) as Resource
	var rate_battery := rate_grid.call("place_block", battery, Vector3i(1, 0, 0), 0) as Resource
	for z in [1, 2, 3]:
		rate_grid.call("place_block", thruster, Vector3i(0, 0, z), 0)
	var rate_actor := Node.new()
	add_child(rate_actor)
	rate_grid.call("try_claim_manual_control", rate_actor, int(rate_seat.get("instance_id")))
	rate_grid.call("set_manual_translation_input", rate_actor, Vector3(0, 0, -1))
	rate_grid.call("set_battery_stored_energy_kwh", int(rate_battery.get("instance_id")), 1.0)
	_assert(is_equal_approx(float(rate_grid.call("get_active_power_demand_kw")), 366.0), "Three thrusters plus occupied seat request 366 kW")
	_assert(absf(float(rate_grid.call("get_power_satisfaction_ratio")) - (240.0 / 366.0)) < 0.0001, "Battery discharge is capped at its 240 kW maximum rate")

	grid.call("set_battery_stored_energy_kwh", battery_id, 12.345)
	var save_state := grid.call("get_save_state") as Dictionary
	_assert(int(save_state.get("version", 0)) == 3, "Grid persistence remains compatible with battery runtime state in current save version 3")
	_assert((save_state.get("battery_states", []) as Array).size() == 1, "Version 2 save contains one battery runtime state")
	var restored := _make_grid("RestoredBatteryCraft", Vector3(0, 54, 0))
	_assert(bool(restored.call("load_save_state", save_state)), "Version 2 battery craft save loads successfully")
	var restored_batteries := restored.call("get_battery_instance_ids") as Array
	_assert(restored_batteries.size() == 1, "Loaded grid reconstructs the battery cache")
	if restored_batteries.size() == 1:
		_assert(absf(float(restored.call("get_battery_stored_energy_kwh", int(restored_batteries[0]))) - 12.345) < 0.0001, "Exact stored kWh survives save/load")
	_assert((restored.call("get_integrity_errors") as Array).is_empty(), "Loaded battery grid passes integrity auditing")

	var v1_state := save_state.duplicate(true)
	v1_state["version"] = 1
	v1_state.erase("battery_states")
	var migrated := _make_grid("MigratedV1BatteryCraft", Vector3(0, 66, 0))
	_assert(bool(migrated.call("load_save_state", v1_state)), "Save-version-1 grid payload migrates through the Stage 26 loader")
	var migrated_ids := migrated.call("get_battery_instance_ids") as Array
	if migrated_ids.size() == 1:
		_assert(is_equal_approx(float(migrated.call("get_battery_stored_energy_kwh", int(migrated_ids[0]))), 30.0), "Version 1 migration initializes batteries from their 50% definition charge")

	var corrupted := save_state.duplicate(true)
	var corrupted_states := corrupted["battery_states"] as Array
	(corrupted_states[0] as Dictionary)["stored_energy_kwh"] = 999.0
	var preserved_energy := float(restored.call("get_total_battery_stored_energy_kwh"))
	_assert(not bool(restored.call("load_save_state", corrupted)), "Battery save with energy above capacity is rejected transactionally")
	_assert(absf(float(restored.call("get_total_battery_stored_energy_kwh")) - preserved_energy) < 0.0001, "Rejected battery save leaves live runtime energy unchanged")

	grid.call("remove_block_by_instance_id", battery_id)
	_assert(int(grid.call("get_battery_count")) == 0 and is_equal_approx(float(grid.call("get_total_battery_capacity_kwh")), 0.0), "Removing a battery clears storage cache and capacity immediately")

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

func _finish() -> void:
	if _failures.is_empty():
		print("STAGE26_BATTERY_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE26_BATTERY_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
