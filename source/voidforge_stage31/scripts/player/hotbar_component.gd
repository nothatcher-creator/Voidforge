class_name HotbarComponent
extends Node
## Persistent hotbar/tool-selection state backed by stable inventory item IDs.
##
## Slot assignments do not duplicate inventory contents. Each slot stores only a stable
## ItemDefinition ID and resolves quantity/metadata through the player's InventoryComponent.

signal selection_changed(slot_index: int, item_id: StringName)
signal slot_changed(slot_index: int, item_id: StringName)
signal hotbar_changed

const HOTBAR_STATE_VERSION: int = 1

@export_range(1, 12, 1) var slot_count: int = 8
@export_range(0, 11, 1) var selected_slot: int = 0
@export var inventory_path: NodePath = NodePath("../Inventory")

var _slot_item_ids: Array[StringName] = []
var _inventory: Node

func _ready() -> void:
	_ensure_slot_storage()
	selected_slot = clampi(selected_slot, 0, slot_count - 1)
	if not inventory_path.is_empty():
		bind_inventory(get_node_or_null(inventory_path))

func bind_inventory(inventory: Node) -> void:
	if _inventory == inventory:
		return
	if _inventory != null and _inventory.has_signal("inventory_changed"):
		var old_callable := Callable(self, "_on_inventory_changed")
		if _inventory.is_connected("inventory_changed", old_callable):
			_inventory.disconnect("inventory_changed", old_callable)
	_inventory = inventory
	if _inventory != null and _inventory.has_signal("inventory_changed"):
		_inventory.connect("inventory_changed", Callable(self, "_on_inventory_changed"))
	hotbar_changed.emit()

func get_inventory() -> Node:
	return _inventory

func get_slot_count() -> int:
	_ensure_slot_storage()
	return _slot_item_ids.size()

func get_selected_slot() -> int:
	return selected_slot

func get_slot_item_id(slot_index: int) -> StringName:
	_ensure_slot_storage()
	if not _is_valid_slot(slot_index):
		return &""
	return _slot_item_ids[slot_index]

func get_selected_item_id() -> StringName:
	return get_slot_item_id(selected_slot)

func get_slot_definition(slot_index: int) -> Resource:
	var item_id := get_slot_item_id(slot_index)
	if item_id == &"":
		return null
	if _inventory != null and _inventory.has_method("resolve_definition"):
		return _inventory.call("resolve_definition", item_id) as Resource
	var item_db := get_node_or_null("/root/ItemDB")
	if item_db != null and bool(item_db.call("has_item", item_id)):
		return item_db.call("get_item", item_id) as Resource
	return null

func get_selected_definition() -> Resource:
	return get_slot_definition(selected_slot)

func get_slot_quantity(slot_index: int) -> int:
	var item_id := get_slot_item_id(slot_index)
	if item_id == &"" or _inventory == null or not _inventory.has_method("get_item_count"):
		return 0
	return int(_inventory.call("get_item_count", item_id))

func get_selected_quantity() -> int:
	return get_slot_quantity(selected_slot)

func is_slot_available(slot_index: int) -> bool:
	return get_slot_item_id(slot_index) != &"" and get_slot_quantity(slot_index) > 0

func is_selected_item_available() -> bool:
	return is_slot_available(selected_slot)

func assign_item(slot_index: int, item_id: StringName) -> bool:
	_ensure_slot_storage()
	if not _is_valid_slot(slot_index) or item_id == &"" or not _is_known_item(item_id):
		return false
	if _slot_item_ids[slot_index] == item_id:
		return true
	_slot_item_ids[slot_index] = item_id
	slot_changed.emit(slot_index, item_id)
	hotbar_changed.emit()
	if slot_index == selected_slot:
		selection_changed.emit(selected_slot, item_id)
	return true

func clear_slot(slot_index: int) -> bool:
	_ensure_slot_storage()
	if not _is_valid_slot(slot_index):
		return false
	if _slot_item_ids[slot_index] == &"":
		return true
	_slot_item_ids[slot_index] = &""
	slot_changed.emit(slot_index, &"")
	hotbar_changed.emit()
	if slot_index == selected_slot:
		selection_changed.emit(selected_slot, &"")
	return true

func clear_all_slots() -> void:
	_ensure_slot_storage()
	var changed := false
	for index in _slot_item_ids.size():
		if _slot_item_ids[index] != &"":
			_slot_item_ids[index] = &""
			slot_changed.emit(index, &"")
			changed = true
	if changed:
		hotbar_changed.emit()
		selection_changed.emit(selected_slot, &"")

func select_slot(slot_index: int) -> bool:
	_ensure_slot_storage()
	if not _is_valid_slot(slot_index):
		return false
	if selected_slot == slot_index:
		return true
	selected_slot = slot_index
	selection_changed.emit(selected_slot, get_selected_item_id())
	hotbar_changed.emit()
	return true

func select_next() -> void:
	_ensure_slot_storage()
	select_slot((selected_slot + 1) % slot_count)

func select_previous() -> void:
	_ensure_slot_storage()
	select_slot(posmod(selected_slot - 1, slot_count))

func get_state() -> Dictionary:
	_ensure_slot_storage()
	var slots: Array[String] = []
	for item_id in _slot_item_ids:
		slots.append(String(item_id))
	return {
		"version": HOTBAR_STATE_VERSION,
		"selected_slot": selected_slot,
		"slots": slots,
	}

func load_state(state: Dictionary) -> bool:
	_ensure_slot_storage()
	if int(state.get("version", -1)) != HOTBAR_STATE_VERSION:
		return false
	var raw_slots = state.get("slots", null)
	if not raw_slots is Array or raw_slots.size() != slot_count:
		return false
	var new_selected := int(state.get("selected_slot", -1))
	if not _is_valid_slot(new_selected):
		return false

	var validated: Array[StringName] = []
	validated.resize(slot_count)
	for index in slot_count:
		var item_id := StringName(String(raw_slots[index]))
		if item_id != &"" and not _is_known_item(item_id):
			return false
		validated[index] = item_id

	_slot_item_ids = validated
	selected_slot = new_selected
	for index in slot_count:
		slot_changed.emit(index, _slot_item_ids[index])
	hotbar_changed.emit()
	selection_changed.emit(selected_slot, get_selected_item_id())
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var slot_index := _number_key_to_slot(event.keycode)
		if slot_index >= 0 and slot_index < slot_count:
			select_slot(slot_index)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_next()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_previous()
			get_viewport().set_input_as_handled()

func _number_key_to_slot(keycode: Key) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
		KEY_0: return 9
	return -1

func _ensure_slot_storage() -> void:
	slot_count = maxi(slot_count, 1)
	if _slot_item_ids.size() == slot_count:
		return
	var resized: Array[StringName] = []
	resized.resize(slot_count)
	for index in mini(_slot_item_ids.size(), slot_count):
		resized[index] = _slot_item_ids[index]
	_slot_item_ids = resized
	selected_slot = clampi(selected_slot, 0, slot_count - 1)

func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slot_count

func _is_known_item(item_id: StringName) -> bool:
	if item_id == &"":
		return false
	if _inventory != null and _inventory.has_method("resolve_definition"):
		if _inventory.call("resolve_definition", item_id) != null:
			return true
	var item_db := get_node_or_null("/root/ItemDB")
	return item_db != null and bool(item_db.call("has_item", item_id))

func _on_inventory_changed() -> void:
	# Quantities/availability are presentation state for assigned slots.
	hotbar_changed.emit()
