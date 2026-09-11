extends Node3D
## Active Stage 25 wrapper. Retains Stage 24 and adds a fully powered propulsion/gyro craft.

const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const THRUSTER_ID: StringName = &"pulse_thruster_large"
const GYRO_ID: StringName = &"vector_gyro_large"
const POWER_SOURCE_ID: StringName = &"dev_power_source_large"

@onready var power_grid: RigidBody3D = $PowerCraft
@onready var power_presenter: Node3D = $PowerCraft/BlockPresenter

func _ready() -> void:
	_seed_power_craft()
	if power_presenter != null:
		power_presenter.call("flush_collision_now")
		power_presenter.call("flush_geometry_now")
		var seat_presenter := power_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if power_grid != null:
		power_grid.set("dynamic_gravity_scale", 0.0)
		power_grid.set("dynamic_linear_damp", 0.10)
		power_grid.set("dynamic_angular_damp", 0.24)
		power_grid.call("set_dynamic_simulation_enabled", true)
		var state := power_grid.call("get_power_network_state") as Dictionary
		DebugLog.info(
			"Stage25Test",
			"Power craft ready | %d blocks | %.0f kg | %.0f/%.0f kW generation/rated demand | %.0f kN thrust | %.0f kN*m gyro" % [
				int(power_grid.call("get_block_count")),
				float(power_grid.call("get_total_mass_kg")),
				float(state.get("generation_kw", 0.0)),
				float(state.get("rated_demand_kw", 0.0)),
				float(power_grid.call("get_total_rated_thrust_n")) / 1000.0,
				float(power_grid.call("get_total_gyro_torque_nm")) / 1000.0,
			]
		)

func _seed_power_craft() -> void:
	if power_grid == null or int(power_grid.call("get_block_count")) > 0:
		return
	var seat := BlockDB.call("get_block", PILOT_SEAT_ID) as Resource
	var thruster := BlockDB.call("get_block", THRUSTER_ID) as Resource
	var gyro := BlockDB.call("get_block", GYRO_ID) as Resource
	var source := BlockDB.call("get_block", POWER_SOURCE_ID) as Resource
	if seat == null or thruster == null or gyro == null or source == null:
		DebugLog.error("Stage25Test", "Power-network craft definitions are missing")
		return
	var placements := [
		[seat, Vector3i.ZERO, 0],
		[gyro, Vector3i(0, 1, 0), 0],
		[thruster, Vector3i(0, 0, 1), 0],
		[source, Vector3i(-1, 0, 0), 0],
		[source, Vector3i(1, 0, 0), 0],
	]
	for placement in placements:
		if power_grid.call("place_block", placement[0], placement[1], placement[2]) == null:
			DebugLog.error("Stage25Test", "Failed to seed power craft at %s" % str(placement[1]))
			return
