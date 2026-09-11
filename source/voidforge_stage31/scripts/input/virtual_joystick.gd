extends Control
## Multi-touch four-direction analog joystick that bridges touch input into shared InputMap actions.
## Reused for on-foot movement, vehicle translation, and Stage 24 pitch/yaw control.

signal vector_changed(value: Vector2)

@export_range(48.0, 180.0, 1.0) var stick_radius_px: float = 92.0
@export_range(20.0, 100.0, 1.0) var knob_radius_px: float = 42.0
@export_range(0.0, 0.75, 0.01) var dead_zone: float = 0.14
@export var dynamic_origin: bool = true
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var move_forward_action: StringName = &"move_forward"
@export var move_backward_action: StringName = &"move_backward"

var _active_touch_id: int = -1
var _value: Vector2 = Vector2.ZERO
var _origin_local: Vector2 = Vector2.ZERO
var _knob_local: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_visual_origin()
	resized.connect(_on_resized)
	queue_redraw()

func _exit_tree() -> void:
	clear_input()

func _input(event: InputEvent) -> void:
	handle_screen_event(event)

func handle_screen_event(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false

	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_id != -1 or not get_global_rect().has_point(event.position):
				return false
			_active_touch_id = event.index
			if dynamic_origin:
				_origin_local = _clamp_origin(_to_local_point(event.position))
			else:
				_reset_visual_origin()
			_update_from_local_position(_to_local_point(event.position))
			return true
		if event.index == _active_touch_id:
			clear_input()
			return true

	if event is InputEventScreenDrag and event.index == _active_touch_id:
		_update_from_local_position(_to_local_point(event.position))
		return true

	return false

func _to_local_point(global_position: Vector2) -> Vector2:
	return global_position - get_global_rect().position

func set_action_bindings(left_action: StringName, right_action: StringName, forward_action: StringName, backward_action: StringName) -> void:
	clear_input()
	move_left_action = left_action
	move_right_action = right_action
	move_forward_action = forward_action
	move_backward_action = backward_action

func get_action_bindings() -> Dictionary:
	return {
		"left": move_left_action,
		"right": move_right_action,
		"forward": move_forward_action,
		"backward": move_backward_action,
	}

func get_value() -> Vector2:
	return _value

func get_active_touch_id() -> int:
	return _active_touch_id

func clear_input() -> void:
	_active_touch_id = -1
	_value = Vector2.ZERO
	_release_actions()
	_reset_visual_origin()
	vector_changed.emit(_value)
	queue_redraw()

func _update_from_local_position(local_position: Vector2) -> void:
	var raw := (local_position - _origin_local) / maxf(stick_radius_px, 1.0)
	if raw.length() > 1.0:
		raw = raw.normalized()

	var magnitude := raw.length()
	if magnitude <= dead_zone:
		_value = Vector2.ZERO
	else:
		var remapped_magnitude := inverse_lerp(dead_zone, 1.0, magnitude)
		_value = raw.normalized() * remapped_magnitude

	_knob_local = _origin_local + _value * stick_radius_px
	_apply_actions()
	vector_changed.emit(_value)
	queue_redraw()

func _apply_actions() -> void:
	_set_action_strength(move_left_action, maxf(-_value.x, 0.0))
	_set_action_strength(move_right_action, maxf(_value.x, 0.0))
	_set_action_strength(move_forward_action, maxf(-_value.y, 0.0))
	_set_action_strength(move_backward_action, maxf(_value.y, 0.0))

func _set_action_strength(action: StringName, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _release_actions() -> void:
	Input.action_release(move_left_action)
	Input.action_release(move_right_action)
	Input.action_release(move_forward_action)
	Input.action_release(move_backward_action)

func _reset_visual_origin() -> void:
	_origin_local = size * 0.5
	_knob_local = _origin_local

func _clamp_origin(local_position: Vector2) -> Vector2:
	var pad := stick_radius_px + 4.0
	return Vector2(
		clampf(local_position.x, pad, maxf(pad, size.x - pad)),
		clampf(local_position.y, pad, maxf(pad, size.y - pad))
	)

func _on_resized() -> void:
	if _active_touch_id == -1:
		_reset_visual_origin()
		queue_redraw()

func _draw() -> void:
	var base_color := Color(0.04, 0.08, 0.12, 0.34)
	var ring_color := Color(0.25, 0.86, 1.0, 0.62)
	var knob_color := Color(0.19, 0.76, 0.94, 0.62 if _active_touch_id == -1 else 0.84)
	draw_circle(_origin_local, stick_radius_px, base_color)
	draw_arc(_origin_local, stick_radius_px, 0.0, TAU, 48, ring_color, 3.0, true)
	draw_circle(_knob_local, knob_radius_px, knob_color)
	draw_arc(_knob_local, knob_radius_px, 0.0, TAU, 32, Color(0.8, 0.97, 1.0, 0.8), 2.0, true)
