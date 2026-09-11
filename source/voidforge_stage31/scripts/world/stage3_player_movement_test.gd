extends Node3D
## Integration harness for the production player controller against stable Stage 2 world geometry.

@onready var environment: Node3D = $Stage2Environment
@onready var player: CharacterBody3D = $FirstPersonPlayer
@onready var course: Node3D = $MovementCourse

func _ready() -> void:
	_validate_scene_contract()
	DebugLog.info("Stage3Test", "Player movement test world ready")

func _validate_scene_contract() -> void:
	var missing: Array[String] = []
	if environment == null:
		missing.append("Stage2Environment")
	if player == null:
		missing.append("FirstPersonPlayer")
	if course == null:
		missing.append("MovementCourse")
	if player != null and player.get_node_or_null("CameraPivot/Camera3D") == null:
		missing.append("FirstPersonPlayer/CameraPivot/Camera3D")

	if missing.is_empty():
		DebugLog.info("Stage3Test", "Movement test scene contract validated")
	else:
		DebugLog.error("Stage3Test", "Missing required nodes: %s" % ", ".join(PackedStringArray(missing)))
