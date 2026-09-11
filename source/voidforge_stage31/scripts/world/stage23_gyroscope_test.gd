extends Node3D
## Active Stage 23 wrapper. Retains Stage 22 and adds a gyroscope-equipped attitude-control craft.

const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const GYRO_ID: StringName = &"vector_gyro_large"
const FRAME_ID: StringName = &"frame_reinforced_large"

@onready var gyro_grid: RigidBody3D = $GyroCraft
@onready var gyro_presenter: Node3D = $GyroCraft/BlockPresenter

func _ready() -> void:
	_seed_gyro_craft()
	if gyro_presenter != null:
		gyro_presenter.call("flush_collision_now")
		gyro_presenter.call("flush_geometry_now")
		var seat_presenter := gyro_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if gyro_grid != null:
		gyro_grid.set("dynamic_gravity_scale", 0.0)
		gyro_grid.set("dynamic_linear_damp", 0.08)
		gyro_grid.set("dynamic_angular_damp", 0.18)
		gyro_grid.call("set_dynamic_simulation_enabled", true)
		DebugLog.info(
			"Stage23Test",
			"Gyro craft ready | %d blocks | %.0f kg | %d gyros | %.0f N*m torque" % [
				int(gyro_grid.call("get_block_count")),
				float(gyro_grid.call("get_total_mass_kg")),
				int(gyro_grid.call("get_gyroscope_count")),
				float(gyro_grid.call("get_total_gyro_torque_nm")),
			]
		)

func _seed_gyro_craft() -> void:
	if gyro_grid == null or int(gyro_grid.call("get_block_count")) > 0:
		return
	var seat := BlockDB.call("get_block", PILOT_SEAT_ID) as Resource
	var gyro := BlockDB.call("get_block", GYRO_ID) as Resource
	var frame := BlockDB.call("get_block", FRAME_ID) as Resource
	if seat == null or gyro == null or frame == null:
		DebugLog.error("Stage23Test", "Gyro craft definitions are missing")
		return
	var placements := [
		[seat, Vector3i.ZERO],
		[gyro, Vector3i(0, 1, 0)],
		[frame, Vector3i(1, 0, 0)],
		[frame, Vector3i(-1, 0, 0)],
		[frame, Vector3i(0, 0, 1)],
	]
	for placement in placements:
		if gyro_grid.call("place_block", placement[0], placement[1], 0) == null:
			DebugLog.error("Stage23Test", "Failed to seed gyro craft at %s" % str(placement[1]))
			return
