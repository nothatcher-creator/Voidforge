extends Control
## Lightweight touch/mouse slot renderer used by the Stage 8 hotbar HUD.

signal slot_requested(slot_index: int)

var slot_index: int = 0
var item_label: String = ""
var quantity: int = 0
var selected: bool = false
var available: bool = false
var _active_touch_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	queue_redraw()

func set_slot_state(index: int, label: String, item_quantity: int, is_selected: bool, is_available: bool) -> void:
	slot_index = index
	item_label = label
	quantity = maxi(item_quantity, 0)
	selected = is_selected
	available = is_available
	queue_redraw()

func handle_screen_event(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_id != -1 or not get_global_rect().has_point(event.position):
				return false
			_active_touch_id = event.index
			slot_requested.emit(slot_index)
			queue_redraw()
			return true
		if event.index == _active_touch_id:
			_active_touch_id = -1
			queue_redraw()
			return true
	return false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_requested.emit(slot_index)
		accept_event()
	elif event is InputEventScreenTouch:
		if handle_screen_event(event):
			accept_event()

func _draw() -> void:
	var rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	var fill := Color(0.035, 0.055, 0.07, 0.72 if available else 0.48)
	var edge := Color(0.24, 0.58, 0.68, 0.82)
	if selected:
		fill = Color(0.06, 0.16, 0.19, 0.9)
		edge = Color(0.32, 0.93, 1.0, 1.0)
	if _active_touch_id != -1:
		fill = fill.lightened(0.12)
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, 3.0 if selected else 1.5)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8.0, 18.0), str(slot_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.78, 0.91, 0.94, 0.95))
	if not item_label.is_empty():
		var short_label := item_label.left(10)
		draw_string(font, Vector2(6.0, 44.0), short_label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 12.0, 13, Color(0.94, 0.98, 1.0, 0.96))
		draw_string(font, Vector2(6.0, size.y - 8.0), "x%d" % quantity, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 12.0, 13, Color(0.86, 0.94, 0.98, 0.92 if quantity > 0 else 0.52))
