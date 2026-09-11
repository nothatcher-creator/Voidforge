extends Node3D
## Active Stage 14 wrapper. Retains the complete Stage 13 playable slice while verifying
## that every live prototype block resolves through the authoritative BlockDB catalog.

@onready var prototype_grid: Node3D = $Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/PrototypeBlockGrid

func _ready() -> void:
	if prototype_grid == null:
		DebugLog.error("Stage14Test", "Stage 14 prototype grid is missing")
		return
	if not bool(BlockDB.call("is_database_valid")):
		DebugLog.error("Stage14Test", "BlockDB is not valid in the active world")
		return
	var unresolved: Array[String] = []
	for instance in prototype_grid.call("get_all_blocks"):
		var block_id := StringName((instance as Resource).get("block_id"))
		if not bool(BlockDB.call("has_block", block_id)):
			unresolved.append(String(block_id))
	if unresolved.is_empty():
		DebugLog.info(
			"Stage14Test",
			"Authoritative block catalog active | %d definitions | live prototype IDs resolved" % int(BlockDB.call("get_block_count"))
		)
	else:
		DebugLog.error("Stage14Test", "Live prototype contains unregistered block IDs: %s" % ", ".join(PackedStringArray(unresolved)))
