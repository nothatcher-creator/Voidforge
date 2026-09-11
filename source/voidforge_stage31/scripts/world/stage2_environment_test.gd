extends Node3D
## Lightweight Stage 2 world used to validate scale, lighting, camera framing, and ground collision.
## Its fixed development camera can be disabled when a later integration scene supplies a player camera.

@export var activate_development_camera: bool = true

@onready var test_camera: Camera3D = $CameraRig/Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var ground_body: StaticBody3D = $TestGeometry/Ground/StaticBody3D

func _ready() -> void:
	_configure_camera()
	_validate_scene_contract()
	DebugLog.info("Stage2World", "3D environment test scene ready")

func _configure_camera() -> void:
	if test_camera == null:
		return
	test_camera.current = activate_development_camera
	if activate_development_camera:
		test_camera.look_at(Vector3(0.0, 1.4, 0.0), Vector3.UP)

func _validate_scene_contract() -> void:
	var missing: Array[String] = []
	if test_camera == null:
		missing.append("CameraRig/Camera3D")
	if world_environment == null:
		missing.append("WorldEnvironment")
	if sun == null:
		missing.append("Sun")
	if ground_body == null:
		missing.append("TestGeometry/Ground/StaticBody3D")

	if missing.is_empty():
		DebugLog.info("Stage2World", "Environment scene contract validated")
	else:
		DebugLog.error("Stage2World", "Missing required nodes: %s" % ", ".join(PackedStringArray(missing)))
