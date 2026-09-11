extends Node3D
## Active Stage 21 wrapper. Retains Stage 20 and adds the first constructed craft with functional thrust.

const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const FRAME_ID: StringName = &"frame_reinforced_large"
const THRUSTER_ID: StringName = &"pulse_thruster_large"

@onready var thrust_grid: RigidBody3D = $ThrustCraft
@onready var thrust_presenter: Node3D = $ThrustCraft/BlockPresenter

func _ready() -> void:
	_seed_thrust_craft()
	if thrust_presenter != null:
		thrust_presenter.call("flush_collision_now")
		thrust_presenter.call("flush_geometry_now")
		var seat_presenter := thrust_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if thrust_grid != null:
		thrust_grid.set("dynamic_gravity_scale", 0.0)
		thrust_grid.set("dynamic_linear_damp", 0.08)
		thrust_grid.set("dynamic_angular_damp", 0.15)
		thrust_grid.call("set_dynamic_simulation_enabled", true)
		DebugLog.info(
			"Stage21Test",
			"Thrust craft ready | %d blocks | %.0f kg | %d thruster(s) | %.0f N rated" % [
				int(thrust_grid.call("get_block_count")),
				float(thrust_grid.call("get_total_mass_kg")),
				int(thrust_grid.call("get_thruster_count")),
				float(thrust_grid.call("get_total_rated_thrust_n")),
			]
		)

func _seed_thrust_craft() -> void:
	if thrust_grid == null or int(thrust_grid.call("get_block_count")) > 0:
		return
	var seat := BlockDB.call("get_block", PILOT_SEAT_ID) as Resource
	var frame := BlockDB.call("get_block", FRAME_ID) as Resource
	var thruster := BlockDB.call("get_block", THRUSTER_ID) as Resource
	if seat == null or frame == null or thruster == null:
		DebugLog.error("Stage21Test", "Thrust craft block definitions are missing")
		return
	for cell in [Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
		if thrust_grid.call("place_block", frame, cell, 0) == null:
			DebugLog.error("Stage21Test", "Failed to seed thrust craft frame at %s" % str(cell))
			return
	if thrust_grid.call("place_block", seat, Vector3i.ZERO, 0) == null:
		DebugLog.error("Stage21Test", "Failed to seed Pilot Cradle")
		return
	if thrust_grid.call("place_block", thruster, Vector3i(0, 0, 2), 0) == null:
		DebugLog.error("Stage21Test", "Failed to seed Pulse Thruster")
