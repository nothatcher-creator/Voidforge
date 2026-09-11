extends Control
## Dedicated right-side look surface. It owns one finger and can coexist with joystick/buttons.

@export_range(0.25, 0.8, 0.01) var activation_start_ratio: float = 0.42
@export_range(0.1, 4.0, 0.05) var sensitivity_scale: float = 1.35

var _active_touch_id: int = -1
var _player: Node3D
var _excluded_controls: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	handle_screen_event(event)

func bind_player(player: Node3D) -> void:
	_player = player

func set_excluded_controls(controls: Array) -> void:
	_excluded_controls = controls

func get_active_touch_id() -> int:
	return _active_touch_id

func handle_screen_event(event: InputEvent) -> bool:
	if not is_visible_in_tree() or _player == null:
		return false

	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_id != -1 or not _can_start_look(event.position):
				return false
			_active_touch_id = event.index
			return true
		if event.index == _active_touch_id:
			_active_touch_id = -1
			return true

	if event is InputEventScreenDrag and event.index == _active_touch_id:
		if _player.has_method("apply_look_motion"):
			_player.call("apply_look_motion", event.relative, sensitivity_scale)
		return true

	return false

func _can_start_look(global_position: Vector2) -> bool:
	var viewport_width := get_viewport_rect().size.x
	if global_position.x < viewport_width * activation_start_ratio:
		return false
	for control in _excluded_controls:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(global_position):
			return false
	return true
