extends Node3D
## Active Stage 12 wrapper. Keeps the Stage 11 construction slice intact while enabling
## authoritative targeted removal through the existing BuildController.

@onready var prototype_grid: Node3D = $Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/PrototypeBlockGrid
@onready var player: CharacterBody3D = $Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer
@onready var build_controller: Node3D = $Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/BuildController

func _ready() -> void:
	if prototype_grid == null or player == null or build_controller == null:
		DebugLog.error("Stage12Test", "Stage 12 removal integration nodes are missing")
		return
	DebugLog.info(
		"Stage12Test",
		"Targeted block removal active | X / RMV removes the highlighted block instance"
	)
