extends Node3D
## Active Stage 26 wrapper. Retains Stage 25 and adds a rechargeable hybrid-power craft.

const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const THRUSTER_ID: StringName = &"pulse_thruster_large"
const GYRO_ID: StringName = &"vector_gyro_large"
const POWER_SOURCE_ID: StringName = &"dev_power_source_large"
const BATTERY_ID: StringName = &"flux_reservoir_large"

@onready var battery_grid: RigidBody3D = $BatteryCraft
@onready var battery_presenter: Node3D = $BatteryCraft/BlockPresenter

func _ready() -> void:
	_seed_battery_craft()
	if battery_presenter != null:
		battery_presenter.call("flush_collision_now")
		battery_presenter.call("flush_geometry_now")
		var seat_presenter := battery_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if battery_grid != null:
		battery_grid.set("dynamic_gravity_scale", 0.0)
		battery_grid.set("dynamic_linear_damp", 0.10)
		battery_grid.set("dynamic_angular_damp", 0.24)
		battery_grid.call("set_dynamic_simulation_enabled", true)
		var power := battery_grid.call("get_power_network_state") as Dictionary
		var storage := battery_grid.call("get_battery_storage_state") as Dictionary
		DebugLog.info(
			"Stage26Test",
			"Hybrid battery craft ready | %d blocks | %.0f kg | %.0f kW generation | %.1f/%.1f kWh stored | %.0f kW max discharge" % [
				int(battery_grid.call("get_block_count")),
				float(battery_grid.call("get_total_mass_kg")),
				float(power.get("generation_kw", 0.0)),
				float(storage.get("stored_energy_kwh", 0.0)),
				float(storage.get("capacity_kwh", 0.0)),
				float(storage.get("max_discharge_kw", 0.0)),
			]
		)

func _seed_battery_craft() -> void:
	if battery_grid == null or int(battery_grid.call("get_block_count")) > 0:
		return
	var seat := BlockDB.call("get_block", PILOT_SEAT_ID) as Resource
	var thruster := BlockDB.call("get_block", THRUSTER_ID) as Resource
	var gyro := BlockDB.call("get_block", GYRO_ID) as Resource
	var source := BlockDB.call("get_block", POWER_SOURCE_ID) as Resource
	var battery := BlockDB.call("get_block", BATTERY_ID) as Resource
	if seat == null or thruster == null or gyro == null or source == null or battery == null:
		DebugLog.error("Stage26Test", "Battery craft definitions are missing")
		return
	var placements := [
		[seat, Vector3i.ZERO, 0],
		[gyro, Vector3i(0, 1, 0), 0],
		[thruster, Vector3i(0, 0, 1), 0],
		[source, Vector3i(-1, 0, 0), 0],
		[battery, Vector3i(1, 0, 0), 0],
	]
	for placement in placements:
		if battery_grid.call("place_block", placement[0], placement[1], placement[2]) == null:
			DebugLog.error("Stage26Test", "Failed to seed battery craft at %s" % str(placement[1]))
			return
