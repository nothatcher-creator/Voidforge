extends Node3D
## Active Stage 28 wrapper. Retains Stage 27 and adds a deterministic priority/load-shedding craft.

const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const THRUSTER_ID: StringName = &"pulse_thruster_large"
const GYRO_ID: StringName = &"vector_gyro_large"
const POWER_SOURCE_ID: StringName = &"dev_power_source_large"
const AUX_LOAD_ID: StringName = &"dev_aux_load_large"

@onready var priority_grid: RigidBody3D = $PriorityCraft
@onready var priority_presenter: Node3D = $PriorityCraft/BlockPresenter

func _ready() -> void:
	_seed_priority_craft()
	if priority_presenter != null:
		priority_presenter.call("flush_collision_now")
		priority_presenter.call("flush_geometry_now")
		var seat_presenter := priority_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if priority_grid != null:
		priority_grid.set("dynamic_gravity_scale", 0.0)
		priority_grid.set("dynamic_linear_damp", 0.10)
		priority_grid.set("dynamic_angular_damp", 0.24)
		var power := priority_grid.call("get_power_network_state") as Dictionary
		DebugLog.info(
			"Stage28Test",
			"Priority craft ready | %d blocks | %.0f kg | %.0f kW generation | %.0f kW rated demand | priorities Critical>High>Normal>Low" % [
				int(priority_grid.call("get_block_count")),
				float(priority_grid.call("get_total_mass_kg")),
				float(power.get("generation_kw", 0.0)),
				float(power.get("rated_demand_kw", 0.0)),
			]
		)

func _seed_priority_craft() -> void:
	if priority_grid == null or int(priority_grid.call("get_block_count")) > 0:
		return
	var seat := BlockDB.call("get_block", PILOT_SEAT_ID) as Resource
	var thruster := BlockDB.call("get_block", THRUSTER_ID) as Resource
	var gyro := BlockDB.call("get_block", GYRO_ID) as Resource
	var source := BlockDB.call("get_block", POWER_SOURCE_ID) as Resource
	var aux := BlockDB.call("get_block", AUX_LOAD_ID) as Resource
	if seat == null or thruster == null or gyro == null or source == null or aux == null:
		DebugLog.error("Stage28Test", "Priority craft definitions are missing")
		return
	var placements := [
		[seat, Vector3i.ZERO, 0],
		[gyro, Vector3i(0, 1, 0), 0],
		[thruster, Vector3i(0, 0, 1), 0],
		[source, Vector3i(-1, 0, 0), 0],
		[aux, Vector3i(1, 0, 0), 0],
	]
	for placement in placements:
		if priority_grid.call("place_block", placement[0], placement[1], placement[2]) == null:
			DebugLog.error("Stage28Test", "Failed to seed priority craft at %s" % str(placement[1]))
			return
