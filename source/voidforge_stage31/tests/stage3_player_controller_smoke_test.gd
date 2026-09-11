extends Node3D
## Headless physics smoke test for movement, collision, jump/landing, and player camera ownership.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const EPSILON: float = 0.001

var _failures: Array[String] = []
var _player: CharacterBody3D

func _ready() -> void:
	_build_test_world()
	await get_tree().physics_frame
	await _run_checks()

func _run_checks() -> void:
	await _physics_frames(45)
	_assert(_player.is_on_floor(), "Player settles onto the floor")
	var player_camera := _player.get_node("CameraPivot/Camera3D") as Camera3D
	_assert(player_camera != null and player_camera.current, "Player camera owns the viewport")

	var start_z := _player.global_position.z
	Input.action_press("move_forward")
	await _physics_frames(18)
	Input.action_release("move_forward")
	var moved_distance := start_z - _player.global_position.z
	_assert(moved_distance > 0.35, "Forward input moves the player")

	Input.action_press("move_forward")
	await _physics_frames(120)
	Input.action_release("move_forward")
	_assert(_player.global_position.z > -2.5, "World collision prevents passing through the test wall")

	await _physics_frames(20)
	var grounded_y := _player.global_position.y
	Input.action_press("jump")
	await _physics_frames(1)
	Input.action_release("jump")
	await _physics_frames(12)
	_assert(_player.global_position.y > grounded_y + 0.08, "Jump input raises the player")

	await _physics_frames(120)
	_assert(_player.is_on_floor(), "Gravity returns the player to the floor")
	_assert(absf(_player.velocity.y) < EPSILON, "Vertical velocity settles after landing")

	if _failures.is_empty():
		print("STAGE3_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE3_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _build_test_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 63
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 0.5, 20)
	floor_shape.position = Vector3(0, -0.25, 0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)

	var wall_body := StaticBody3D.new()
	wall_body.position = Vector3(0, 1.25, -3)
	wall_body.collision_layer = 1
	wall_body.collision_mask = 63
	add_child(wall_body)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(8, 2.5, 0.5)
	wall_shape.shape = wall_box
	wall_body.add_child(wall_shape)

	var player_instance := PLAYER_SCENE.instantiate()
	player_instance.set("capture_mouse_on_start", false)
	_player = player_instance as CharacterBody3D
	_player.position = Vector3(0, 1.1, 2)
	add_child(_player)

func _physics_frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
