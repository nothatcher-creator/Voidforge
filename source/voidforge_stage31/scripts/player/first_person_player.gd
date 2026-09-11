class_name FirstPersonPlayer
extends CharacterBody3D
## Mobile-ready first-person locomotion core.
## Keyboard, controller, and touch movement all converge on the same InputMap actions.

signal grounded_changed(is_grounded: bool)
signal mouse_capture_changed(captured: bool)
signal control_mode_changed(mode: StringName, controlled_grid: Node)
signal control_seat_entered(seat: Node, controlled_grid: Node)
signal control_seat_exited(seat: Node, controlled_grid: Node)
signal ui_input_lock_changed(locked: bool)

@export_group("Movement")
@export_range(0.1, 30.0, 0.1) var walk_speed_mps: float = 5.0
@export_range(0.1, 40.0, 0.1) var sprint_speed_mps: float = 8.0
@export_range(0.1, 100.0, 0.1) var ground_acceleration_mps2: float = 22.0
@export_range(0.1, 100.0, 0.1) var ground_deceleration_mps2: float = 26.0
@export_range(0.1, 100.0, 0.1) var air_acceleration_mps2: float = 7.0
@export_range(0.1, 100.0, 0.1) var air_deceleration_mps2: float = 2.0
@export_range(0.1, 20.0, 0.1) var jump_velocity_mps: float = 5.1
@export_range(0.0, 2.0, 0.01) var floor_snap_distance_m: float = 0.3
@export_range(1.0, 89.0, 0.5) var max_walkable_slope_degrees: float = 46.0

@export_group("Look")
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0024
@export_range(30.0, 89.9, 0.1) var vertical_look_limit_degrees: float = 88.0
@export var capture_mouse_on_start: bool = true

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var inventory: Node = $Inventory
@onready var hotbar: Node = $Hotbar
@onready var build_controller: Node3D = $BuildController
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var player_interactor: RayCast3D = $CameraPivot/Camera3D/PlayerInteractor

var _gravity_strength_mps2: float = 9.8
var _pitch_radians: float = 0.0
var _was_grounded: bool = false
var _active_control_seat: Node
var _controlled_grid: Node3D
var _seat_look_yaw_radians: float = 0.0
var _ui_input_locked: bool = false

func _ready() -> void:
	_gravity_strength_mps2 = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	floor_snap_length = floor_snap_distance_m
	floor_max_angle = deg_to_rad(max_walkable_slope_degrees)
	camera.current = true
	_was_grounded = is_on_floor()

	if capture_mouse_on_start and not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		_set_mouse_captured(true)

	DebugLog.info(
		"Player",
		"First-person controller ready | walk %.1f m/s | sprint %.1f m/s" % [
			walk_speed_mps,
			sprint_speed_mps,
		]
	)

func _unhandled_input(event: InputEvent) -> void:
	if _ui_input_locked:
		return
	if is_in_control_seat() and event.is_action_pressed("vehicle_exit"):
		exit_control_seat()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_mouse_capture"):
		_set_mouse_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_motion(event.relative)

func _physics_process(delta: float) -> void:
	if _ui_input_locked:
		if is_in_control_seat():
			_sync_to_control_seat()
			_clear_vehicle_control_input()
			return
		_apply_vertical_motion(delta)
		_apply_locked_horizontal_deceleration(delta)
		move_and_slide()
		_update_grounded_state()
		return
	if is_in_control_seat():
		if Input.is_action_just_pressed("vehicle_exit"):
			exit_control_seat()
			return
		_sync_to_control_seat()
		_apply_vehicle_thrust_input()
		return
	_apply_vertical_motion(delta)
	_apply_horizontal_motion(delta)
	_try_jump()
	move_and_slide()
	_update_grounded_state()

func _apply_locked_horizontal_deceleration(delta: float) -> void:
	var acceleration := _get_horizontal_acceleration(false)
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

func _clear_vehicle_control_input() -> void:
	if not is_instance_valid(_controlled_grid):
		return
	if _controlled_grid.has_method("clear_manual_thrust_input"):
		_controlled_grid.call("clear_manual_thrust_input", self)
	if _controlled_grid.has_method("clear_manual_rotation_input"):
		_controlled_grid.call("clear_manual_rotation_input", self)

func set_ui_input_locked(locked: bool) -> void:
	if _ui_input_locked == locked:
		return
	_ui_input_locked = locked
	if _ui_input_locked:
		_clear_vehicle_control_input()
	ui_input_lock_changed.emit(_ui_input_locked)

func is_ui_input_locked() -> bool:
	return _ui_input_locked

func _apply_vehicle_thrust_input() -> void:
	if not is_in_control_seat() or not is_instance_valid(_controlled_grid):
		return
	var translation_input := Vector3(
		Input.get_action_strength("vehicle_thrust_right") - Input.get_action_strength("vehicle_thrust_left"),
		Input.get_action_strength("vehicle_thrust_up") - Input.get_action_strength("vehicle_thrust_down"),
		Input.get_action_strength("vehicle_thrust_backward") - Input.get_action_strength("vehicle_thrust_forward")
	)
	if _controlled_grid.has_method("set_manual_translation_input"):
		_controlled_grid.call("set_manual_translation_input", self, translation_input)
	elif _controlled_grid.has_method("set_manual_thrust_input"):
		_controlled_grid.call("set_manual_thrust_input", self, maxf(-translation_input.z, 0.0))

	var rotation_input := Vector3(
		Input.get_action_strength("vehicle_pitch_up") - Input.get_action_strength("vehicle_pitch_down"),
		Input.get_action_strength("vehicle_yaw_left") - Input.get_action_strength("vehicle_yaw_right"),
		Input.get_action_strength("vehicle_roll_right") - Input.get_action_strength("vehicle_roll_left")
	)
	if _controlled_grid.has_method("set_manual_rotation_input"):
		_controlled_grid.call("set_manual_rotation_input", self, rotation_input)

func _apply_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity_strength_mps2 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

func _apply_horizontal_motion(delta: float) -> void:
	var input_axis := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var local_direction := Vector3(input_axis.x, 0.0, input_axis.y)
	var world_direction := transform.basis * local_direction
	world_direction.y = 0.0
	if world_direction.length_squared() > 1.0:
		world_direction = world_direction.normalized()

	var target_speed := sprint_speed_mps if Input.is_action_pressed("sprint") else walk_speed_mps
	var target_velocity := world_direction * target_speed
	var has_input := input_axis.length_squared() > 0.0001
	var acceleration := _get_horizontal_acceleration(has_input)

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

func _get_horizontal_acceleration(has_input: bool) -> float:
	if is_on_floor():
		return ground_acceleration_mps2 if has_input else ground_deceleration_mps2
	return air_acceleration_mps2 if has_input else air_deceleration_mps2

func _try_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity_mps

func apply_look_motion(relative_motion: Vector2, sensitivity_scale: float = 1.0) -> void:
	if _ui_input_locked:
		return
	var scaled_sensitivity := mouse_sensitivity * maxf(sensitivity_scale, 0.0)
	if is_in_control_seat():
		_seat_look_yaw_radians = wrapf(_seat_look_yaw_radians - relative_motion.x * scaled_sensitivity, -PI, PI)
	else:
		rotate_y(-relative_motion.x * scaled_sensitivity)
	_pitch_radians = clampf(
		_pitch_radians - relative_motion.y * scaled_sensitivity,
		-deg_to_rad(vertical_look_limit_degrees),
		deg_to_rad(vertical_look_limit_degrees)
	)
	camera_pivot.rotation = Vector3(_pitch_radians, _seat_look_yaw_radians if is_in_control_seat() else 0.0, 0.0)

func _set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	mouse_capture_changed.emit(captured)

func _update_grounded_state() -> void:
	var grounded := is_on_floor()
	if grounded == _was_grounded:
		return
	_was_grounded = grounded
	grounded_changed.emit(grounded)

func is_in_control_seat() -> bool:
	return is_instance_valid(_active_control_seat) and is_instance_valid(_controlled_grid)

func get_active_control_seat() -> Node:
	return _active_control_seat if is_instance_valid(_active_control_seat) else null

func get_controlled_grid() -> Node3D:
	return _controlled_grid if is_instance_valid(_controlled_grid) else null

func get_control_mode() -> StringName:
	return &"vehicle" if is_in_control_seat() else &"on_foot"

func enter_control_seat(seat: Node) -> bool:
	if seat == null or not is_instance_valid(seat) or is_in_control_seat():
		return false
	if not seat.has_method("get_controlled_grid") or not seat.has_method("try_claim_pilot"):
		return false
	var grid := seat.call("get_controlled_grid") as Node3D
	if grid == null or not is_instance_valid(grid) or not grid.has_method("can_receive_manual_control"):
		return false
	if not bool(seat.call("try_claim_pilot", self)):
		return false
	if not bool(grid.call("can_receive_manual_control", self)):
		seat.call("release_pilot", self)
		return false
	_active_control_seat = seat
	_controlled_grid = grid
	velocity = Vector3.ZERO
	_seat_look_yaw_radians = 0.0
	_pitch_radians = 0.0
	camera_pivot.rotation = Vector3.ZERO
	collision_shape.set_deferred("disabled", true)
	player_interactor.enabled = false
	build_controller.process_mode = Node.PROCESS_MODE_DISABLED
	_sync_to_control_seat()
	control_mode_changed.emit(&"vehicle", _controlled_grid)
	control_seat_entered.emit(_active_control_seat, _controlled_grid)
	return true

func exit_control_seat(force_exit: bool = false) -> bool:
	if not is_in_control_seat():
		return false
	var seat := _active_control_seat
	var grid := _controlled_grid
	var exit_transform := global_transform
	if is_instance_valid(seat) and seat.has_method("get_exit_transform_global"):
		exit_transform = seat.call("get_exit_transform_global") as Transform3D
	if is_instance_valid(grid) and grid.has_method("clear_manual_thrust_input"):
		grid.call("clear_manual_thrust_input", self)
	if is_instance_valid(seat) and seat.has_method("release_pilot") and not force_exit:
		seat.call("release_pilot", self)
	elif is_instance_valid(grid) and grid.has_method("release_manual_control"):
		grid.call("release_manual_control", self)
	_active_control_seat = null
	_controlled_grid = null
	global_transform = exit_transform
	_seat_look_yaw_radians = 0.0
	_pitch_radians = 0.0
	camera_pivot.rotation = Vector3.ZERO
	collision_shape.set_deferred("disabled", false)
	player_interactor.enabled = true
	build_controller.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(grid) and grid is RigidBody3D:
		velocity = (grid as RigidBody3D).linear_velocity
	else:
		velocity = Vector3.ZERO
	control_mode_changed.emit(&"on_foot", null)
	control_seat_exited.emit(seat, grid)
	return true

func on_control_seat_invalidated(grid: Node, seat_instance_id: int, _reason: String = "") -> void:
	if not is_in_control_seat() or grid != _controlled_grid:
		return
	if is_instance_valid(_active_control_seat) and _active_control_seat.has_method("get_block_instance_id"):
		if int(_active_control_seat.call("get_block_instance_id")) != seat_instance_id:
			return
	exit_control_seat(true)

func _sync_to_control_seat() -> void:
	if not is_in_control_seat():
		return
	if not _active_control_seat.has_method("get_pilot_body_transform_global"):
		exit_control_seat(true)
		return
	global_transform = _active_control_seat.call("get_pilot_body_transform_global") as Transform3D
	velocity = Vector3.ZERO

func get_inventory() -> Node:
	return inventory

func get_hotbar() -> Node:
	return hotbar

func get_build_controller() -> Node3D:
	return build_controller
