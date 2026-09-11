extends Control
## Touch-first hotbar presentation. Desktop and Android share the same slot widgets/state.

const SLOT_BUTTON_SCRIPT := preload("res://scripts/ui/hotbar_slot_button.gd")

@export var hotbar_path: NodePath
@export_range(48.0, 96.0, 1.0) var slot_size_px: float = 70.0
@export_range(2.0, 16.0, 1.0) var slot_gap_px: float = 6.0
@export_range(0.0, 80.0, 1.0) var bottom_margin_px: float = 18.0

var _hotbar: Node
var _slot_controls: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout_slots)
	if not hotbar_path.is_empty():
		bind_hotbar(get_node_or_null(hotbar_path))
	call_deferred("_layout_slots")

func bind_hotbar(hotbar: Node) -> void:
	if _hotbar == hotbar:
		_refresh()
		return
	_disconnect_hotbar()
	_hotbar = hotbar
	if _hotbar != null and _hotbar.has_signal("hotbar_changed"):
		_hotbar.connect("hotbar_changed", Callable(self, "_refresh"))
	_rebuild_slots()

func get_hotbar() -> Node:
	return _hotbar

func get_slot_control(slot_index: int) -> Control:
	if slot_index < 0 or slot_index >= _slot_controls.size():
		return null
	return _slot_controls[slot_index]

func get_slot_control_count() -> int:
	return _slot_controls.size()

func _disconnect_hotbar() -> void:
	if _hotbar != null and _hotbar.has_signal("hotbar_changed"):
		var callback := Callable(self, "_refresh")
		if _hotbar.is_connected("hotbar_changed", callback):
			_hotbar.disconnect("hotbar_changed", callback)

func _rebuild_slots() -> void:
	for control in _slot_controls:
		if is_instance_valid(control):
			control.queue_free()
	_slot_controls.clear()
	if _hotbar == null or not _hotbar.has_method("get_slot_count"):
		return
	var count := int(_hotbar.call("get_slot_count"))
	for index in count:
		var slot := Control.new()
		slot.set_script(SLOT_BUTTON_SCRIPT)
		slot.name = "Slot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(slot_size_px, slot_size_px)
		slot.size = Vector2(slot_size_px, slot_size_px)
		add_child(slot)
		slot.connect("slot_requested", Callable(self, "_on_slot_requested"))
		_slot_controls.append(slot)
	_layout_slots()
	_refresh()

func _layout_slots() -> void:
	if not is_inside_tree() or _slot_controls.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	var total_width := _slot_controls.size() * slot_size_px + (_slot_controls.size() - 1) * slot_gap_px
	var start_x := maxf((viewport_size.x - total_width) * 0.5, 0.0)
	var safe_bottom := _get_safe_bottom_inset(viewport_size)
	var y := maxf(viewport_size.y - safe_bottom - bottom_margin_px - slot_size_px, 0.0)
	for index in _slot_controls.size():
		var slot := _slot_controls[index]
		slot.position = Vector2(start_x + index * (slot_size_px + slot_gap_px), y)
		slot.size = Vector2(slot_size_px, slot_size_px)

func _refresh() -> void:
	if _hotbar == null:
		return
	for index in _slot_controls.size():
		var item_id: StringName = _hotbar.call("get_slot_item_id", index)
		var definition: Resource = _hotbar.call("get_slot_definition", index) as Resource
		var label := ""
		if definition != null:
			label = String(definition.get("display_name"))
		elif item_id != &"":
			label = String(item_id)
		var quantity := int(_hotbar.call("get_slot_quantity", index))
		var is_selected := index == int(_hotbar.call("get_selected_slot"))
		var is_available := bool(_hotbar.call("is_slot_available", index))
		_slot_controls[index].call("set_slot_state", index, label, quantity, is_selected, is_available)

func _on_slot_requested(slot_index: int) -> void:
	if _hotbar != null and _hotbar.has_method("select_slot"):
		_hotbar.call("select_slot", slot_index)

func _get_safe_bottom_inset(viewport_size: Vector2) -> float:
	if DisplayServer.get_name() == "headless":
		return 0.0
	var screen_size := DisplayServer.screen_get_size()
	var safe_rect := DisplayServer.get_display_safe_area()
	if screen_size.y <= 0 or safe_rect.size.y <= 0:
		return 0.0
	var scale_y := viewport_size.y / float(screen_size.y)
	return maxf((screen_size.y - safe_rect.end.y) * scale_y, 0.0)
