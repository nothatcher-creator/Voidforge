extends Node3D
## Active Stage 13 wrapper. Keeps the Stage 12 construction/removal slice intact while
## verifying that the live prototype grid exposes a versioned persistence contract.

@onready var prototype_grid: Node3D = $Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/PrototypeBlockGrid

func _ready() -> void:
	if prototype_grid == null:
		DebugLog.error("Stage13Test", "Stage 13 prototype grid is missing")
		return
	var save_state := prototype_grid.call("get_save_state") as Dictionary
	if String(save_state.get("schema", "")) != "voidforge.block_grid" or int(save_state.get("version", 0)) != 3:
		DebugLog.error("Stage13Test", "Prototype grid persistence contract is invalid")
		return
	DebugLog.info(
		"Stage13Test",
		"Versioned grid persistence active | %d blocks are serialization-ready" % int(prototype_grid.call("get_block_count"))
	)
