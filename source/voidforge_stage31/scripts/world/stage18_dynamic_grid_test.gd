extends Node3D
## Active Stage 18 wrapper. Keeps the complete Stage 17 playable slice and adds a small
## rigid-body craft demonstrator that moves using the same sparse block/cached collision data.

const DEMO_BLOCK_ID: StringName = &"frame_reinforced_large"

@onready var dynamic_grid: RigidBody3D = $DynamicGrid
@onready var dynamic_presenter: Node = $DynamicGrid/BlockPresenter

func _ready() -> void:
	_seed_dynamic_grid()
	if dynamic_presenter != null:
		dynamic_presenter.call("flush_collision_now")
		dynamic_presenter.call("flush_geometry_now")
	if dynamic_grid != null:
		dynamic_grid.set("dynamic_gravity_scale", 0.0)
		dynamic_grid.set("dynamic_linear_damp", 0.0)
		dynamic_grid.set("dynamic_angular_damp", 0.0)
		if dynamic_grid.call("set_dynamic_simulation_enabled", true):
			dynamic_grid.linear_velocity = Vector3(0.35, 0.0, 0.0)
			dynamic_grid.angular_velocity = Vector3(0.0, 0.08, 0.0)
			DebugLog.info(
				"Stage18Test",
				"Dynamic grid released | %d blocks | calculated %.0f kg | one shared rigid body" % [
					int(dynamic_grid.call("get_block_count")),
					float(dynamic_grid.call("get_total_mass_kg")),
				]
			)

func _seed_dynamic_grid() -> void:
	if dynamic_grid == null or int(dynamic_grid.call("get_block_count")) > 0:
		return
	var definition := BlockDB.call("get_block", DEMO_BLOCK_ID) as Resource
	if definition == null:
		DebugLog.error("Stage18Test", "Missing dynamic demo block '%s'" % String(DEMO_BLOCK_ID))
		return
	for cell in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if dynamic_grid.call("place_block", definition, cell, 0) == null:
			DebugLog.error("Stage18Test", "Failed to seed dynamic demo at %s" % str(cell))
