extends Node3D
## Active Stage 9 development wrapper. It keeps the Stage 8 playable slice intact and
## creates a small construction-grid state sample for runtime validation. Stage 10 may present that state visually through the reusable grid presenter.

const HULL_FRAME := preload("res://data/blocks/dev_hull_frame.tres")
const SPAN_FRAME := preload("res://data/blocks/dev_span_frame.tres")

@onready var prototype_grid: Node3D = $PrototypeBlockGrid

func _ready() -> void:
	_seed_prototype_grid()
	var errors: Array = prototype_grid.call("get_integrity_errors")
	if errors.is_empty():
		DebugLog.info(
			"Stage9Test",
			"Prototype grid ready | %d blocks | %d occupied cells" % [
				int(prototype_grid.call("get_block_count")),
				int(prototype_grid.call("get_occupied_cell_count")),
			]
		)
	else:
		DebugLog.error("Stage9Test", "Prototype grid integrity failed: %s" % " | ".join(PackedStringArray(errors)))

func _seed_prototype_grid() -> void:
	if prototype_grid == null:
		DebugLog.error("Stage9Test", "PrototypeBlockGrid is missing")
		return
	prototype_grid.call("place_block", HULL_FRAME, Vector3i.ZERO)
	prototype_grid.call("place_block", HULL_FRAME, Vector3i(0, 1, 0))
	prototype_grid.call("place_block", SPAN_FRAME, Vector3i(1, 0, 0))
