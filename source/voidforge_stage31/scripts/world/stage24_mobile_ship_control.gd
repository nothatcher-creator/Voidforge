extends Node3D
## Active Stage 24 wrapper. Retains Stage 23 and adds a fully translation/gyro-equipped mobile control craft.

const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const THRUSTER_ID: StringName = &"pulse_thruster_large"
const GYRO_ID: StringName = &"vector_gyro_large"
const ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const THRUST_DIRECTIONS: Array[Vector3i] = [
	Vector3i.RIGHT,
	Vector3i.LEFT,
	Vector3i.UP,
	Vector3i.DOWN,
	Vector3i.BACK,
	Vector3i.FORWARD,
]
const THRUSTER_CELLS: Array[Vector3i] = [
	Vector3i(-2, 0, 0),
	Vector3i(2, 0, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 2, 0),
	Vector3i(0, 0, -2),
	Vector3i(0, 0, 2),
]

@onready var mobile_grid: RigidBody3D = $MobileControlCraft
@onready var mobile_presenter: Node3D = $MobileControlCraft/BlockPresenter

func _ready() -> void:
	_seed_mobile_control_craft()
	if mobile_presenter != null:
		mobile_presenter.call("flush_collision_now")
		mobile_presenter.call("flush_geometry_now")
		var seat_presenter := mobile_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if mobile_grid != null:
		mobile_grid.set("dynamic_gravity_scale", 0.0)
		mobile_grid.set("dynamic_linear_damp", 0.10)
		mobile_grid.set("dynamic_angular_damp", 0.24)
		mobile_grid.call("set_dynamic_simulation_enabled", true)
		DebugLog.info(
			"Stage24Test",
			"Mobile control craft ready | %d blocks | %.0f kg | %.0f kN installed thrust | %.0f kN*m gyro" % [
				int(mobile_grid.call("get_block_count")),
				float(mobile_grid.call("get_total_mass_kg")),
				float(mobile_grid.call("get_total_rated_thrust_n")) / 1000.0,
				float(mobile_grid.call("get_total_gyro_torque_nm")) / 1000.0,
			]
		)

func _seed_mobile_control_craft() -> void:
	if mobile_grid == null or int(mobile_grid.call("get_block_count")) > 0:
		return
	var seat := BlockDB.call("get_block", PILOT_SEAT_ID) as Resource
	var thruster := BlockDB.call("get_block", THRUSTER_ID) as Resource
	var gyro := BlockDB.call("get_block", GYRO_ID) as Resource
	if seat == null or thruster == null or gyro == null:
		DebugLog.error("Stage24Test", "Mobile control craft definitions are missing")
		return
	if mobile_grid.call("place_block", seat, Vector3i.ZERO, 0) == null:
		DebugLog.error("Stage24Test", "Failed to seed Pilot Cradle")
		return
	if mobile_grid.call("place_block", gyro, Vector3i(0, 1, 0), 0) == null:
		DebugLog.error("Stage24Test", "Failed to seed Vector Gyro")
		return
	for index in THRUST_DIRECTIONS.size():
		var orientation_index := _orientation_for_force_direction(THRUST_DIRECTIONS[index])
		if mobile_grid.call("place_block", thruster, THRUSTER_CELLS[index], orientation_index) == null:
			DebugLog.error("Stage24Test", "Failed to seed Pulse Thruster for %s" % str(THRUST_DIRECTIONS[index]))
			return

func _orientation_for_force_direction(direction: Vector3i) -> int:
	for orientation_index in ORIENTATION.ORIENTATION_COUNT:
		var basis := ORIENTATION.get_basis(orientation_index)
		if Vector3i(basis * Vector3(0, 0, -1)) == direction:
			return orientation_index
	return 0
