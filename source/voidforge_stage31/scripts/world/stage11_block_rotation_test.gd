extends Node3D
## Active Stage 11 wrapper. Keeps the Stage 10 construction slice intact while switching the
## active build definition to a two-cell frame so 90-degree rotation is visibly meaningful.

const SPAN_FRAME := preload("res://data/blocks/dev_span_frame.tres")

@onready var prototype_grid: Node3D = $Stage10BlockPlacementTest/Stage9GridTest/PrototypeBlockGrid
@onready var player: CharacterBody3D = $Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer
@onready var build_controller: Node3D = $Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/BuildController

func _ready() -> void:
	if prototype_grid == null or player == null or build_controller == null:
		DebugLog.error("Stage11Test", "Stage 11 rotation integration nodes are missing")
		return
	build_controller.call("set_build_definition", SPAN_FRAME)
	build_controller.call("reset_orientation")
	DebugLog.info(
		"Stage11Test",
		"Rotatable Span Frame active | R / ROT rotates 90 degrees around targeted face"
	)
