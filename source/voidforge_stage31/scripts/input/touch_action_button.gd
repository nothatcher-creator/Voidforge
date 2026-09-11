extends Control
## Multi-touch action button that presses/releases a shared InputMap action.

signal pressed_changed(pressed: bool)

@export var action_name: StringName = &"jump"
@export var label_text: String = "ACTION"
@export var accent_color: Color = Color(0.25, 0.86, 1.0, 0.72)
@export_range(0.25, 1.0, 0.01) var idle_opacity: float = 0.52
@export_range(0.25, 1.0, 0.01) var pressed_opacity: float = 0.88

var _active_touch_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _exit_tree() -> void:
	_release_action()

func _input(event: InputEvent) -> void:
	handle_screen_event(event)

func handle_screen_event(event: InputEvent) -> bool:
	# Always honor release for the finger this button already owns, even if a
	# context switch hid the button between press and release (for example EXIT).
	if event is InputEventScreenTouch and not event.pressed and event.index == _active_touch_id:
		_release_action()
		return true
	if not is_visible_in_tree():
		return false

	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_id != -1 or not get_global_rect().has_point(event.position):
				return false
			_active_touch_id = event.index
			Input.action_press(action_name)
			pressed_changed.emit(true)
			queue_redraw()
			return true
		if event.index == _active_touch_id:
			_release_action()
			return true

	return false

func is_touch_pressed() -> bool:
	return _active_touch_id != -1

func get_active_touch_id() -> int:
	return _active_touch_id

func clear_input() -> void:
	_release_action()

func _release_action() -> void:
	if _active_touch_id == -1:
		return
	_active_touch_id = -1
	Input.action_release(action_name)
	pressed_changed.emit(false)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(1.0, minf(size.x, size.y) * 0.5 - 3.0)
	var alpha := pressed_opacity if is_touch_pressed() else idle_opacity
	var fill := Color(accent_color.r * 0.24, accent_color.g * 0.30, accent_color.b * 0.34, alpha)
	var edge := Color(accent_color.r, accent_color.g, accent_color.b, minf(alpha + 0.18, 1.0))
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 40, edge, 3.0, true)

	var font := ThemeDB.fallback_font
	var font_size := 20
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		center - Vector2(text_size.x * 0.5, -text_size.y * 0.32),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(0.93, 0.99, 1.0, 0.96)
	)
