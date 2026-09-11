extends Node3D
## Active Stage 10 wrapper. Repositions the Stage 9 prototype into the player's forward build range
## while retaining every prior playable/test system beneath it.

@onready var prototype_grid: Node3D = $Stage9GridTest/PrototypeBlockGrid
@onready var player: CharacterBody3D = $Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer
@onready var build_controller: Node3D = $Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/BuildController

func _ready() -> void:
	if prototype_grid == null or player == null or build_controller == null:
		DebugLog.error("Stage10Test", "Stage 10 build integration nodes are missing")
		return
	prototype_grid.position = Vector3(0.0, 1.25, 2.0)
	prototype_grid.rotation = Vector3.ZERO
	DebugLog.info(
		"Stage10Test",
		"Visible grid placement slice ready | B / BUILD to place | range %.1f m" % float(build_controller.get("placement_range_m"))
	)
