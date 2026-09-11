extends Node3D
## Active Stage 19 wrapper. Retains the complete Stage 18 playable slice and adds a
## mixed-mass craft whose rigid-body mass is derived exclusively from BlockDB metadata.

const MASS_DEMO_BLOCKS: Array[StringName] = [
	&"frame_reinforced_large",
	&"armor_shell_heavy_large",
	&"beam_long_large",
]

@onready var mass_grid: RigidBody3D = $MassDemoGrid
@onready var mass_presenter: Node = $MassDemoGrid/BlockPresenter

func _ready() -> void:
	_seed_mass_demo()
	if mass_presenter != null:
		mass_presenter.call("flush_collision_now")
		mass_presenter.call("flush_geometry_now")
	if mass_grid != null:
		mass_grid.set("dynamic_gravity_scale", 0.0)
		mass_grid.set("dynamic_linear_damp", 0.0)
		mass_grid.set("dynamic_angular_damp", 0.0)
		if mass_grid.call("set_dynamic_simulation_enabled", true):
			mass_grid.linear_velocity = Vector3(-0.18, 0.0, 0.0)
			DebugLog.info(
				"Stage19Test",
				"Mass demo released | %d blocks | %.0f kg from BlockDB | rigid body %.0f kg" % [
					int(mass_grid.call("get_block_count")),
					float(mass_grid.call("get_total_mass_kg")),
					mass_grid.mass,
				]
			)

func _seed_mass_demo() -> void:
	if mass_grid == null or int(mass_grid.call("get_block_count")) > 0:
		return
	var cells: Array[Vector3i] = [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-2, 0, 0)]
	for index in MASS_DEMO_BLOCKS.size():
		var definition := BlockDB.call("get_block", MASS_DEMO_BLOCKS[index]) as Resource
		if definition == null:
			DebugLog.error("Stage19Test", "Missing mass demo block '%s'" % String(MASS_DEMO_BLOCKS[index]))
			return
		if mass_grid.call("place_block", definition, cells[index], 0) == null:
			DebugLog.error("Stage19Test", "Failed to seed mass demo block '%s'" % String(MASS_DEMO_BLOCKS[index]))
			return
