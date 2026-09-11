extends Node
## Stage 8 regression coverage for persistent slots, inventory backing, keyboard/wheel, and touch UI.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const HOTBAR_UI_SCENE := preload("res://scenes/ui/hotbar_ui.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")

var _failures: Array[String] = []
var _player: CharacterBody3D
var _inventory: Node
var _hotbar: Node
var _hotbar_ui: Control
var _touch_controls: Control
var _look_area: Control
var _selection_events: Array[int] = []

func _ready() -> void:
	_build_world()
	await get_tree().process_frame
	await get_tree().process_frame
	_run_checks()

func _run_checks() -> void:
	_assert(int(_hotbar.call("get_slot_count")) == 8, "Hotbar exposes eight default slots")
	_assert(int(_hotbar.call("get_selected_slot")) == 0, "Hotbar starts on slot 1")
	_assert(StringName(_hotbar.call("get_slot_item_id", 0)) == &"", "Empty slots resolve to an empty stable ID")
	_assert(not bool(_hotbar.call("assign_item", -1, &"component_structural_plate")), "Negative slot indexes are rejected")
	_assert(not bool(_hotbar.call("assign_item", 8, &"component_structural_plate")), "Out-of-range slot indexes are rejected")
	_assert(not bool(_hotbar.call("assign_item", 0, &"not_a_real_item")), "Unknown item IDs are rejected")

	_assert(int(_inventory.call("add_item_by_id", &"component_structural_plate", 12)) == 12, "Inventory accepts production item for hotbar test")
	_assert(int(_inventory.call("add_item_by_id", &"component_conductive_wire", 25)) == 25, "Inventory accepts second production item")
	_assert(bool(_hotbar.call("assign_item", 0, &"component_structural_plate")), "Known item can be assigned to slot 1")
	_assert(bool(_hotbar.call("assign_item", 1, &"component_conductive_wire")), "Known item can be assigned to slot 2")
	_assert(int(_hotbar.call("get_slot_quantity", 0)) == 12, "Hotbar quantity comes from bound inventory")
	_assert(bool(_hotbar.call("is_slot_available", 0)), "Assigned item is available while inventory quantity is positive")
	var selected_definition := _hotbar.call("get_selected_definition") as Resource
	_assert(selected_definition != null and StringName(selected_definition.get("id")) == &"component_structural_plate", "Selected slot resolves ItemDB metadata")

	_hotbar.call("select_slot", 1)
	_assert(int(_hotbar.call("get_selected_slot")) == 1, "Direct selection changes selected slot")
	_assert(StringName(_hotbar.call("get_selected_item_id")) == &"component_conductive_wire", "Selected item follows selected slot")
	_hotbar.call("select_next")
	_assert(int(_hotbar.call("get_selected_slot")) == 2 and StringName(_hotbar.call("get_selected_item_id")) == &"", "Selection can land on an empty slot")
	_hotbar.call("select_previous")
	_assert(int(_hotbar.call("get_selected_slot")) == 1, "Previous selection returns to prior slot")

	var saved_state: Dictionary = _hotbar.call("get_state")
	_hotbar.call("clear_all_slots")
	_hotbar.call("select_slot", 6)
	_assert(bool(_hotbar.call("load_state", saved_state)), "Serialized hotbar state restores successfully")
	_assert(int(_hotbar.call("get_selected_slot")) == 1 and StringName(_hotbar.call("get_slot_item_id", 0)) == &"component_structural_plate", "Persistent state restores selection and stable IDs")
	var bad_state := saved_state.duplicate(true)
	bad_state["slots"][0] = "unknown_item"
	_assert(not bool(_hotbar.call("load_state", bad_state)), "Persistent state rejects unknown item IDs")

	_inventory.call("remove_item", &"component_structural_plate", 12)
	_assert(int(_hotbar.call("get_slot_quantity", 0)) == 0 and not bool(_hotbar.call("is_slot_available", 0)), "Hotbar reflects inventory depletion without deleting assignment")
	_assert(StringName(_hotbar.call("get_slot_item_id", 0)) == &"component_structural_plate", "Zero-count items remain assigned for later reacquisition")

	_send_number_key(KEY_4)
	_assert(int(_hotbar.call("get_selected_slot")) == 3, "Number-key development control selects slot 4")
	_send_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_assert(int(_hotbar.call("get_selected_slot")) == 4, "Mouse wheel down selects next slot")
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	_assert(int(_hotbar.call("get_selected_slot")) == 3, "Mouse wheel up selects previous slot")

	_assert(int(_hotbar_ui.call("get_slot_control_count")) == 8, "Hotbar UI creates one touch control per slot")
	var slot_two := _hotbar_ui.call("get_slot_control", 1) as Control
	_assert(slot_two != null, "Hotbar UI exposes slot controls for testing")
	if slot_two != null:
		var center := slot_two.get_global_rect().get_center()
		_send_touch(slot_two, 12, center, true)
		_send_touch(slot_two, 12, center, false)
		_assert(int(_hotbar.call("get_selected_slot")) == 1, "Touching a hotbar slot changes shared selection state")
		var blocked_touch := InputEventScreenTouch.new()
		blocked_touch.index = 20
		blocked_touch.position = center
		blocked_touch.pressed = true
		_assert(not bool(_look_area.call("handle_screen_event", blocked_touch)), "Hotbar slot touch is excluded from camera look")

	var look_touch := InputEventScreenTouch.new()
	look_touch.index = 21
	look_touch.position = Vector2(get_viewport().get_visible_rect().size.x * 0.78, 220.0)
	look_touch.pressed = true
	_assert(bool(_look_area.call("handle_screen_event", look_touch)), "Camera look remains available outside hotbar slot rectangles")
	look_touch.pressed = false
	_look_area.call("handle_screen_event", look_touch)

	_assert(_selection_events.size() >= 3, "Selection-change signal fires across input paths")

	if _failures.is_empty():
		print("STAGE8_HOTBAR_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE8_HOTBAR_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _build_world() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	add_child(_player)
	_inventory = _player.get_node("Inventory")
	_hotbar = _player.get_node("Hotbar")
	_hotbar.connect("selection_changed", Callable(self, "_on_selection_changed"))

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_hotbar_ui = HOTBAR_UI_SCENE.instantiate() as Control
	canvas.add_child(_hotbar_ui)
	_hotbar_ui.call("bind_hotbar", _hotbar)

	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)
	_look_area = _touch_controls.get_node("LookArea") as Control
	for slot_index in int(_hotbar_ui.call("get_slot_control_count")):
		var slot_control := _hotbar_ui.call("get_slot_control", slot_index) as Control
		_touch_controls.call("exclude_look_control", slot_control)

func _send_number_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_hotbar.call("_unhandled_input", event)

func _send_wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	_hotbar.call("_unhandled_input", event)

func _send_touch(target: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	target.call("handle_screen_event", event)

func _on_selection_changed(slot_index: int, _item_id: StringName) -> void:
	_selection_events.append(slot_index)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
