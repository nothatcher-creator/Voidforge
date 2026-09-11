extends Node3D
## Active Stage 16 wrapper. Keeps the Stage 15 playable slice and adds a collision-free
## 100-block grid whose geometry is rendered through a single MultiMesh batch.

const STRESS_BLOCK_ID: StringName = &"armor_shell_light_large"
const ACTIVE_STRESS_BLOCKS: int = 100

@onready var stress_grid: Node3D = $BatchStressGrid
@onready var stress_presenter: Node3D = $BatchStressGrid/BlockPresenter

func _ready() -> void:
	_seed_stress_grid()
	if stress_presenter != null:
		stress_presenter.call("flush_geometry_now")
	var errors := stress_grid.call("get_integrity_errors") as Array if stress_grid != null else ["Stress grid missing"]
	if errors.is_empty():
		DebugLog.info(
			"Stage16Test",
			"Batched grid renderer active | %d stress blocks | %d render batches | %d render instances" % [
				int(stress_grid.call("get_block_count")),
				int(stress_presenter.call("get_batch_count")) if stress_presenter != null else -1,
				int(stress_presenter.call("get_render_instance_count")) if stress_presenter != null else -1,
			]
		)
	else:
		DebugLog.error("Stage16Test", "Stress grid integrity failed: %s" % str(errors))

func _seed_stress_grid() -> void:
	if stress_grid == null or int(stress_grid.call("get_block_count")) > 0:
		return
	var definition := BlockDB.call("get_block", STRESS_BLOCK_ID) as Resource
	if definition == null:
		DebugLog.error("Stage16Test", "Missing stress block '%s'" % String(STRESS_BLOCK_ID))
		return
	var width := 10
	for index in ACTIVE_STRESS_BLOCKS:
		var cell := Vector3i(index % width, 0, index / width)
		if stress_grid.call("place_block", definition, cell, 0) == null:
			DebugLog.error("Stage16Test", "Failed to place stress block at %s" % str(cell))
			return
