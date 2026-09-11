extends Node3D
## Active Stage 17 wrapper. Keeps the Stage 16 playable/rendering slice and adds a
## collision-enabled 100-block grid represented by one shared grid physics body node.

const STRESS_BLOCK_ID: StringName = &"armor_shell_light_large"
const ACTIVE_COLLISION_BLOCKS: int = 100

@onready var collision_grid: Node3D = $CollisionStressGrid
@onready var collision_presenter: Node3D = $CollisionStressGrid/BlockPresenter

func _ready() -> void:
	_seed_collision_stress_grid()
	if collision_presenter != null:
		collision_presenter.call("flush_collision_now")
	var errors := collision_grid.call("get_integrity_errors") as Array if collision_grid != null else ["Collision stress grid missing"]
	if errors.is_empty():
		DebugLog.info(
			"Stage17Test",
			"Grid collision batching active | %d blocks | %d collision body nodes | %d shapes" % [
				int(collision_grid.call("get_block_count")),
				int(collision_presenter.call("get_runtime_collision_node_count")) if collision_presenter != null else -1,
				int(collision_presenter.call("get_collision_shape_count")) if collision_presenter != null else -1,
			]
		)
	else:
		DebugLog.error("Stage17Test", "Collision stress grid integrity failed: %s" % str(errors))

func _seed_collision_stress_grid() -> void:
	if collision_grid == null or int(collision_grid.call("get_block_count")) > 0:
		return
	var definition := BlockDB.call("get_block", STRESS_BLOCK_ID) as Resource
	if definition == null:
		DebugLog.error("Stage17Test", "Missing collision stress block '%s'" % String(STRESS_BLOCK_ID))
		return
	var width := 10
	for index in ACTIVE_COLLISION_BLOCKS:
		var cell := Vector3i(index % width, 0, index / width)
		if collision_grid.call("place_block", definition, cell, 0) == null:
			DebugLog.error("Stage17Test", "Failed to place collision stress block at %s" % str(cell))
			return
