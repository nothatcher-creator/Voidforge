extends Node3D
## Active Stage 22 wrapper. Retains Stage 21 and adds a six-axis translation craft.

const ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const THRUSTER_ID: StringName = &"pulse_thruster_large"
const DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const THRUSTER_CELLS: Array[Vector3i] = [
	Vector3i(-1, 0, 0), Vector3i(1, 0, 0),
	Vector3i(0, -1, 0), Vector3i(0, 1, 0),
	Vector3i(0, 0, -1), Vector3i(0, 0, 1),
]

@onready var directional_grid: RigidBody3D = $DirectionalCraft
@onready var directional_presenter: Node3D = $DirectionalCraft/BlockPresenter

func _ready() -> void:
	_seed_directional_craft()
	if directional_presenter != null:
		directional_presenter.call("flush_collision_now")
		directional_presenter.call("flush_geometry_now")
		var seat_presenter := directional_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if directional_grid != null:
		directional_grid.set("dynamic_gravity_scale", 0.0)
		directional_grid.set("dynamic_linear_damp", 0.08)
		directional_grid.set("dynamic_angular_damp", 0.15)
		directional_grid.call("set_dynamic_simulation_enabled", true)
		DebugLog.info(
			"Stage22Test",
			"Directional craft ready | %d blocks | %.0f kg | %d thrusters | %.0f N total rated" % [
				int(directional_grid.call("get_block_count")),
				float(directional_grid.call("get_total_mass_kg")),
				int(directional_grid.call("get_thruster_count")),
				float(directional_grid.call("get_total_rated_thrust_n")),
			]
		)

func _seed_directional_craft() -> void:
	if directional_grid == null or int(directional_grid.call("get_block_count")) > 0:
		return
	var seat := BlockDB.call("get_block", PILOT_SEAT_ID) as Resource
	var thruster := BlockDB.call("get_block", THRUSTER_ID) as Resource
	if seat == null or thruster == null:
		DebugLog.error("Stage22Test", "Directional craft definitions are missing")
		return
	if directional_grid.call("place_block", seat, Vector3i.ZERO, 0) == null:
		DebugLog.error("Stage22Test", "Failed to seed Pilot Cradle")
		return
	for index in DIRECTIONS.size():
		var orientation_index := _orientation_for_force_direction(DIRECTIONS[index])
		if directional_grid.call("place_block", thruster, THRUSTER_CELLS[index], orientation_index) == null:
			DebugLog.error("Stage22Test", "Failed to seed thruster for %s" % str(DIRECTIONS[index]))
			return

func _orientation_for_force_direction(direction: Vector3i) -> int:
	for orientation_index in ORIENTATION.ORIENTATION_COUNT:
		var basis := ORIENTATION.get_basis(orientation_index)
		var force_direction := Vector3i(basis * Vector3(0, 0, -1))
		if force_direction == direction:
			return orientation_index
	return 0
