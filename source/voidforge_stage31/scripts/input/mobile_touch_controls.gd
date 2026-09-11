extends Control
## Android-first landscape touch HUD. Layout is safe-area aware and gameplay stays InputMap-driven.
## Stage 24 adds a dedicated dual-stick vehicle layout while retaining on-foot touch controls.

@export var player_path: NodePath
@export var force_visible_for_testing: bool = false
@export_range(0.0, 96.0, 1.0) var edge_padding_px: float = 24.0

@onready var look_area: Control = $LookArea
@onready var move_joystick: Control = $MoveJoystick
@onready var rotation_joystick: Control = $RotationJoystick
@onready var sprint_button: Control = $SprintButton
@onready var jump_button: Control = $JumpButton
@onready var interact_button: Control = $InteractButton
@onready var build_button: Control = $BuildButton
@onready var rotate_button: Control = $RotateButton
@onready var remove_button: Control = $RemoveButton
@onready var tool_button: Control = $ToolButton
@onready var exit_seat_button: Control = $ExitSeatButton
@onready var thrust_button: Control = $ThrustButton
@onready var thrust_up_button: Control = $ThrustUpButton
@onready var thrust_down_button: Control = $ThrustDownButton
@onready var roll_left_button: Control = $RollLeftButton
@onready var roll_right_button: Control = $RollRightButton
@onready var terminal_button: Control = $TerminalButton
@onready var touch_mode_label: Label = $TouchModeLabel

var _player: Node3D
var _desktop_preview_enabled: bool = false
var _additional_look_exclusions: Array[Control] = []
var _external_ui_blocked: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_key_input(true)
	visibility_changed.connect(_on_visibility_changed)
	get_viewport().size_changed.connect(_layout_for_safe_area)

	if not player_path.is_empty():
		bind_player(get_node_or_null(player_path) as Node3D)
	_refresh_look_exclusions()
	_bind_player_mode_signal()
	_refresh_context_buttons()

	var mobile_runtime := OS.has_feature("mobile")
	_desktop_preview_enabled = force_visible_for_testing and not mobile_runtime
	_refresh_root_visibility()
	call_deferred("_layout_for_safe_area")

	if mobile_runtime:
		DebugLog.info("TouchControls", "Android/mobile touch controls enabled")
	elif force_visible_for_testing:
		DebugLog.info("TouchControls", "Touch controls forced visible for test harness")

func bind_player(player: Node3D) -> void:
	_player = player
	if is_instance_valid(look_area):
		look_area.bind_player(_player)
	_bind_player_mode_signal()
	_refresh_context_buttons()

func exclude_look_control(control: Control) -> void:
	if control == null or control in _additional_look_exclusions:
		return
	_additional_look_exclusions.append(control)
	_refresh_look_exclusions()

func _refresh_look_exclusions() -> void:
	if not is_instance_valid(look_area):
		return
	var exclusions: Array = [
		move_joystick,
		rotation_joystick,
		sprint_button,
		jump_button,
		interact_button,
		build_button,
		rotate_button,
		remove_button,
		tool_button,
		exit_seat_button,
		thrust_button,
		thrust_up_button,
		thrust_down_button,
		roll_left_button,
		roll_right_button,
		terminal_button,
	]
	for control in _additional_look_exclusions:
		if is_instance_valid(control):
			exclusions.append(control)
	look_area.set_excluded_controls(exclusions)

func _unhandled_key_input(event: InputEvent) -> void:
	if OS.has_feature("mobile"):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		_desktop_preview_enabled = not _desktop_preview_enabled
		_refresh_root_visibility()
		if _desktop_preview_enabled:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			_clear_all_touch_input()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _layout_for_safe_area() -> void:
	if not is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var insets := _get_safe_area_insets(viewport_size)
	var joystick_size := Vector2(292.0, 292.0)
	var rotation_size := Vector2(292.0, 292.0)
	var jump_size := Vector2(128.0, 128.0)
	var sprint_size := Vector2(112.0, 112.0)
	var interact_size := Vector2(112.0, 112.0)
	var build_size := Vector2(112.0, 112.0)
	var rotate_size := Vector2(96.0, 96.0)
	var remove_size := Vector2(96.0, 96.0)
	var tool_size := Vector2(108.0, 108.0)
	var exit_size := Vector2(108.0, 108.0)
	var thrust_size := Vector2(104.0, 104.0)
	var vertical_thrust_size := Vector2(88.0, 88.0)
	var roll_size := Vector2(88.0, 88.0)

	move_joystick.position = Vector2(
		insets.x + edge_padding_px,
		viewport_size.y - insets.w - edge_padding_px - joystick_size.y
	)
	move_joystick.size = joystick_size

	rotation_joystick.position = Vector2(
		viewport_size.x - insets.z - edge_padding_px - rotation_size.x,
		viewport_size.y - insets.w - edge_padding_px - rotation_size.y
	)
	rotation_joystick.size = rotation_size

	jump_button.position = Vector2(
		viewport_size.x - insets.z - edge_padding_px - jump_size.x,
		viewport_size.y - insets.w - edge_padding_px - jump_size.y
	)
	jump_button.size = jump_size

	sprint_button.position = Vector2(
		jump_button.position.x - sprint_size.x - 34.0,
		jump_button.position.y - 94.0
	)
	sprint_button.size = sprint_size

	interact_button.position = Vector2(
		jump_button.position.x,
		jump_button.position.y - interact_size.y - 30.0
	)
	interact_button.size = interact_size

	build_button.position = Vector2(
		jump_button.position.x - build_size.x - 34.0,
		jump_button.position.y - build_size.y - 110.0
	)
	build_button.size = build_size

	rotate_button.position = Vector2(
		build_button.position.x - rotate_size.x - 22.0,
		build_button.position.y + 8.0
	)
	rotate_button.size = rotate_size

	remove_button.position = Vector2(
		rotate_button.position.x - remove_size.x - 22.0,
		build_button.position.y + 8.0
	)
	remove_button.size = remove_size

	tool_button.position = Vector2(
		sprint_button.position.x - tool_size.x - 22.0,
		jump_button.position.y
	)
	tool_button.size = tool_size

	# Vehicle layout: dual sticks at the lower corners, auxiliary controls between/above them.
	exit_seat_button.position = Vector2(
		viewport_size.x - insets.z - edge_padding_px - exit_size.x,
		insets.y + edge_padding_px + 70.0
	)
	exit_seat_button.size = exit_size

	thrust_button.position = Vector2(
		move_joystick.position.x + move_joystick.size.x + 28.0,
		viewport_size.y - insets.w - edge_padding_px - thrust_size.y
	)
	thrust_button.size = thrust_size

	thrust_down_button.position = Vector2(
		rotation_joystick.position.x - vertical_thrust_size.x - 28.0,
		rotation_joystick.position.y + rotation_joystick.size.y - vertical_thrust_size.y
	)
	thrust_down_button.size = vertical_thrust_size

	thrust_up_button.position = Vector2(
		thrust_down_button.position.x,
		thrust_down_button.position.y - vertical_thrust_size.y - 18.0
	)
	thrust_up_button.size = vertical_thrust_size

	roll_left_button.position = Vector2(
		rotation_joystick.position.x + 42.0,
		rotation_joystick.position.y - roll_size.y - 14.0
	)
	roll_left_button.size = roll_size

	roll_right_button.position = Vector2(
		rotation_joystick.position.x + rotation_joystick.size.x - roll_size.x - 42.0,
		rotation_joystick.position.y - roll_size.y - 14.0
	)
	roll_right_button.size = roll_size

	terminal_button.position = Vector2(
		exit_seat_button.position.x - 124.0,
		exit_seat_button.position.y
	)
	terminal_button.size = Vector2(108.0, 108.0)

	look_area.position = Vector2.ZERO
	look_area.size = viewport_size

	touch_mode_label.position = Vector2(insets.x + edge_padding_px, insets.y + 92.0)
	touch_mode_label.size = Vector2(maxf(480.0, viewport_size.x - insets.x - insets.z - edge_padding_px * 2.0), 32.0)

func _get_safe_area_insets(viewport_size: Vector2) -> Vector4:
	# Returns left, top, right, bottom in viewport coordinates.
	if DisplayServer.get_name() == "headless":
		return Vector4.ZERO

	var screen_size_i := DisplayServer.screen_get_size()
	var safe_rect_i := DisplayServer.get_display_safe_area()
	if screen_size_i.x <= 0 or screen_size_i.y <= 0 or safe_rect_i.size.x <= 0 or safe_rect_i.size.y <= 0:
		return Vector4.ZERO

	var scale := Vector2(viewport_size.x / float(screen_size_i.x), viewport_size.y / float(screen_size_i.y))
	var left := safe_rect_i.position.x * scale.x
	var top := safe_rect_i.position.y * scale.y
	var right := (screen_size_i.x - safe_rect_i.end.x) * scale.x
	var bottom := (screen_size_i.y - safe_rect_i.end.y) * scale.y
	return Vector4(maxf(left, 0.0), maxf(top, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))

func _bind_player_mode_signal() -> void:
	if not is_instance_valid(_player) or not _player.has_signal("control_mode_changed"):
		return
	var callback := Callable(self, "_on_player_control_mode_changed")
	if not _player.is_connected("control_mode_changed", callback):
		_player.connect("control_mode_changed", callback)

func _on_player_control_mode_changed(_mode: StringName, _grid: Node) -> void:
	_refresh_context_buttons()

func _refresh_context_buttons() -> void:
	if not is_instance_valid(exit_seat_button):
		return
	var seated := is_instance_valid(_player) and _player.has_method("is_in_control_seat") and bool(_player.call("is_in_control_seat"))
	if is_instance_valid(move_joystick) and move_joystick.has_method("set_action_bindings"):
		if seated:
			move_joystick.call("set_action_bindings", &"vehicle_thrust_left", &"vehicle_thrust_right", &"vehicle_thrust_forward", &"vehicle_thrust_backward")
		else:
			move_joystick.call("set_action_bindings", &"move_left", &"move_right", &"move_forward", &"move_backward")
	if is_instance_valid(rotation_joystick) and rotation_joystick.has_method("set_action_bindings"):
		rotation_joystick.call("set_action_bindings", &"vehicle_yaw_left", &"vehicle_yaw_right", &"vehicle_pitch_up", &"vehicle_pitch_down")

	rotation_joystick.visible = seated
	exit_seat_button.visible = seated
	thrust_button.visible = seated
	thrust_up_button.visible = seated
	thrust_down_button.visible = seated
	roll_left_button.visible = seated
	roll_right_button.visible = seated
	terminal_button.visible = seated
	if not seated:
		for vehicle_control in [rotation_joystick, exit_seat_button, thrust_button, thrust_up_button, thrust_down_button, roll_left_button, roll_right_button, terminal_button]:
			if is_instance_valid(vehicle_control) and vehicle_control.has_method("clear_input"):
				vehicle_control.call("clear_input")
	if is_instance_valid(touch_mode_label):
		touch_mode_label.text = "VEHICLE  •  LEFT STICK TRANSLATE  •  RIGHT STICK PITCH/YAW  •  ROLL  •  UP/DN  •  EXIT" if seated else "TOUCH  •  LEFT STICK MOVE  •  RIGHT DRAG LOOK  •  USE  •  TOOL  •  BUILD  •  ROT  •  RMV"
	for control in [sprint_button, jump_button, interact_button, build_button, rotate_button, remove_button, tool_button]:
		if is_instance_valid(control):
			control.visible = not seated

func get_mobile_control_state() -> Dictionary:
	var seated := is_instance_valid(_player) and _player.has_method("is_in_control_seat") and bool(_player.call("is_in_control_seat"))
	return {
		"mode": &"vehicle" if seated else &"on_foot",
		"move_bindings": move_joystick.call("get_action_bindings") if is_instance_valid(move_joystick) else {},
		"rotation_bindings": rotation_joystick.call("get_action_bindings") if is_instance_valid(rotation_joystick) else {},
		"move_touch_id": move_joystick.call("get_active_touch_id") if is_instance_valid(move_joystick) else -1,
		"rotation_touch_id": rotation_joystick.call("get_active_touch_id") if is_instance_valid(rotation_joystick) else -1,
		"look_touch_id": look_area.call("get_active_touch_id") if is_instance_valid(look_area) else -1,
	}

func set_external_ui_blocked(blocked: bool) -> void:
	if _external_ui_blocked == blocked:
		return
	_external_ui_blocked = blocked
	if _external_ui_blocked:
		_clear_all_touch_input()
	_refresh_root_visibility()

func is_external_ui_blocked() -> bool:
	return _external_ui_blocked

func _refresh_root_visibility() -> void:
	var mobile_runtime := OS.has_feature("mobile")
	var wants_visible := mobile_runtime or _desktop_preview_enabled
	visible = wants_visible and not _external_ui_blocked

func _on_visibility_changed() -> void:
	if visible:
		return
	_clear_all_touch_input()

func _clear_all_touch_input() -> void:
	for control in [move_joystick, rotation_joystick, sprint_button, jump_button, interact_button, build_button, rotate_button, remove_button, tool_button, exit_seat_button, thrust_button, thrust_up_button, thrust_down_button, roll_left_button, roll_right_button, terminal_button]:
		if is_instance_valid(control) and control.has_method("clear_input"):
			control.call("clear_input")
