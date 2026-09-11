extends Node3D
## Active Stage 20 wrapper. Retains Stage 19 and adds the first pilotable constructed craft.

const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const FRAME_ID: StringName = &"frame_reinforced_large"

@onready var pilot_grid: RigidBody3D = $PilotCraft
@onready var pilot_presenter: Node3D = $PilotCraft/BlockPresenter

func _ready() -> void:
	_seed_pilot_craft()
	if pilot_presenter != null:
		pilot_presenter.call("flush_collision_now")
		pilot_presenter.call("flush_geometry_now")
		var seat_presenter := pilot_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if pilot_grid != null:
		pilot_grid.set("dynamic_gravity_scale", 0.0)
		pilot_grid.set("dynamic_linear_damp", 0.12)
		pilot_grid.set("dynamic_angular_damp", 0.2)
		DebugLog.info(
			"Stage20Test",
			"Pilot craft ready | %d blocks | %.0f kg | %d control seat(s) | frozen until later propulsion stages" % [
				int(pilot_grid.call("get_block_count")),
				float(pilot_grid.call("get_total_mass_kg")),
				(pilot_grid.call("get_control_seat_instance_ids") as Array).size(),
			]
		)

func _seed_pilot_craft() -> void:
	if pilot_grid == null or int(pilot_grid.call("get_block_count")) > 0:
		return
	var seat := BlockDB.call("get_block", PILOT_SEAT_ID) as Resource
	var frame := BlockDB.call("get_block", FRAME_ID) as Resource
	if seat == null or frame == null:
		DebugLog.error("Stage20Test", "Pilot craft block definitions are missing")
		return
	for cell in [Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if pilot_grid.call("place_block", frame, cell, 0) == null:
			DebugLog.error("Stage20Test", "Failed to seed pilot craft frame at %s" % str(cell))
			return
	if pilot_grid.call("place_block", seat, Vector3i.ZERO, 0) == null:
		DebugLog.error("Stage20Test", "Failed to seed Pilot Cradle")
