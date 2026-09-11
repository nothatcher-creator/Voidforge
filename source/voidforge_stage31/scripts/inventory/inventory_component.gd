class_name InventoryComponent
extends Node
## Reusable volume-limited inventory container.
##
## Stacks retain only stable IDs and integer quantities. Production definitions resolve
## through the Stage 7 ItemDB registry, while direct Resource-based mutation remains
## available for isolated tests and future dynamically generated content. The component
## caches validated definitions used by occupied stacks for deterministic mass/volume math.

signal inventory_changed
signal item_added(item_id: StringName, quantity: int)
signal item_removed(item_id: StringName, quantity: int)

const ITEM_DEFINITION_SCRIPT := preload("res://scripts/inventory/item_definition.gd")
const ITEM_STACK_SCRIPT := preload("res://scripts/inventory/item_stack.gd")
const EPSILON: float = 0.000001

@export_group("Capacity")
@export_range(0.0, 1000000000.0, 0.01, "or_greater") var capacity_l: float = 120.0
@export_range(1, 4096, 1, "or_greater") var max_stacks: int = 24

var _stacks: Array[Resource] = []
var _definitions: Dictionary = {}

func get_stack_count() -> int:
	return _stacks.size()

func get_item_count(item_id: StringName) -> int:
	if item_id == &"":
		return 0
	var total := 0
	for stack in _stacks:
		if stack.item_id == item_id:
			total += maxi(int(stack.quantity), 0)
	return total

func has_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	return get_item_count(item_id) >= quantity

func get_used_volume_l() -> float:
	var total := 0.0
	for stack in _stacks:
		var definition := _definitions.get(stack.item_id) as Resource
		if definition == null:
			continue
		total += maxf(float(definition.get("unit_volume_l")), 0.0) * maxi(int(stack.quantity), 0)
	return total

func get_remaining_volume_l() -> float:
	return maxf(capacity_l - get_used_volume_l(), 0.0)

func get_total_mass_kg() -> float:
	var total := 0.0
	for stack in _stacks:
		var definition := _definitions.get(stack.item_id) as Resource
		if definition == null:
			continue
		total += maxf(float(definition.get("unit_mass_kg")), 0.0) * maxi(int(stack.quantity), 0)
	return total

func get_definition(item_id: StringName) -> Resource:
	return _definitions.get(item_id) as Resource

func get_stack_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for stack in _stacks:
		snapshot.append(stack.to_dictionary())
	return snapshot

func get_addable_quantity(definition: Resource, requested_quantity: int) -> int:
	if requested_quantity <= 0 or not _is_valid_definition(definition):
		return 0
	if _has_definition_conflict(definition):
		return 0

	var item_id: StringName = definition.get("id")
	var stack_limit := int(definition.get("stack_limit"))
	var unit_volume_l := float(definition.get("unit_volume_l"))
	var remaining := requested_quantity

	if unit_volume_l > EPSILON:
		var volume_units := int(floor((get_remaining_volume_l() + EPSILON) / unit_volume_l))
		remaining = mini(remaining, maxi(volume_units, 0))
	if remaining <= 0:
		return 0

	var stack_room := 0
	for stack in _stacks:
		if stack.item_id == item_id:
			stack_room += maxi(stack_limit - int(stack.quantity), 0)

	var free_slots := maxi(max_stacks - _stacks.size(), 0)
	stack_room += free_slots * stack_limit
	return mini(remaining, stack_room)

func can_add(definition: Resource, requested_quantity: int) -> bool:
	if requested_quantity <= 0:
		return false
	return get_addable_quantity(definition, requested_quantity) >= requested_quantity

func resolve_definition(item_id: StringName) -> Resource:
	if item_id == &"":
		return null
	var cached := get_definition(item_id)
	if cached != null:
		return cached
	var item_db := get_node_or_null("/root/ItemDB")
	if item_db == null or not bool(item_db.call("has_item", item_id)):
		return null
	return item_db.call("get_item", item_id) as Resource

func can_add_by_id(item_id: StringName, requested_quantity: int) -> bool:
	var definition := resolve_definition(item_id)
	return definition != null and can_add(definition, requested_quantity)

func add_item_by_id(item_id: StringName, requested_quantity: int) -> int:
	var definition := resolve_definition(item_id)
	if definition == null:
		return 0
	return add_item(definition, requested_quantity)

func add_item(definition: Resource, requested_quantity: int) -> int:
	var accepted := get_addable_quantity(definition, requested_quantity)
	if accepted <= 0:
		return 0
	if not _register_definition(definition):
		return 0

	var item_id: StringName = definition.get("id")
	var stack_limit := int(definition.get("stack_limit"))
	var remaining := accepted

	for stack in _stacks:
		if remaining <= 0:
			break
		if stack.item_id != item_id:
			continue
		var room := maxi(stack_limit - int(stack.quantity), 0)
		if room <= 0:
			continue
		var amount := mini(room, remaining)
		stack.quantity += amount
		remaining -= amount

	while remaining > 0 and _stacks.size() < max_stacks:
		var amount := mini(stack_limit, remaining)
		var stack := ITEM_STACK_SCRIPT.new() as Resource
		stack.item_id = item_id
		stack.quantity = amount
		_stacks.append(stack)
		remaining -= amount

	var actually_added := accepted - remaining
	if actually_added > 0:
		item_added.emit(item_id, actually_added)
		inventory_changed.emit()
	return actually_added

func remove_item(item_id: StringName, requested_quantity: int) -> int:
	if item_id == &"" or requested_quantity <= 0:
		return 0

	var remaining := mini(requested_quantity, get_item_count(item_id))
	var removed := 0
	for index in range(_stacks.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var stack := _stacks[index]
		if stack.item_id != item_id:
			continue
		var amount := mini(int(stack.quantity), remaining)
		stack.quantity -= amount
		remaining -= amount
		removed += amount
		if int(stack.quantity) <= 0:
			_stacks.remove_at(index)

	if removed > 0:
		item_removed.emit(item_id, removed)
		inventory_changed.emit()
	return removed

func transfer_to(target, item_id: StringName, requested_quantity: int) -> int:
	if target == null or target == self or item_id == &"" or requested_quantity <= 0:
		return 0
	var definition := get_definition(item_id)
	if definition == null:
		return 0
	var available := mini(get_item_count(item_id), requested_quantity)
	var transferable = int(target.get_addable_quantity(definition, available))
	if transferable <= 0:
		return 0

	var removed := remove_item(item_id, transferable)
	if removed <= 0:
		return 0
	var added = int(target.add_item(definition, removed))
	if added < removed:
		# A single-threaded transfer should not normally reach this branch, but restore
		# anything the target unexpectedly refused so transfers cannot delete items.
		add_item(definition, removed - added)
	return added

func clear_inventory() -> void:
	if _stacks.is_empty():
		return
	_stacks.clear()
	inventory_changed.emit()

func _register_definition(definition: Resource) -> bool:
	if not _is_valid_definition(definition) or _has_definition_conflict(definition):
		return false
	var item_id: StringName = definition.get("id")
	if not _definitions.has(item_id):
		_definitions[item_id] = definition
	return true

func _is_valid_definition(definition: Resource) -> bool:
	if definition == null or definition.get_script() != ITEM_DEFINITION_SCRIPT:
		return false
	var item_id: StringName = definition.get("id")
	var stack_limit := int(definition.get("stack_limit"))
	var mass := float(definition.get("unit_mass_kg"))
	var volume := float(definition.get("unit_volume_l"))
	return item_id != &"" and stack_limit > 0 and mass >= 0.0 and volume >= 0.0

func _has_definition_conflict(definition: Resource) -> bool:
	if not _is_valid_definition(definition):
		return true
	var item_id: StringName = definition.get("id")
	if not _definitions.has(item_id):
		return false
	var existing := _definitions[item_id] as Resource
	if existing == definition:
		return false
	return (
		int(existing.get("stack_limit")) != int(definition.get("stack_limit"))
		or not is_equal_approx(float(existing.get("unit_mass_kg")), float(definition.get("unit_mass_kg")))
		or not is_equal_approx(float(existing.get("unit_volume_l")), float(definition.get("unit_volume_l")))
	)
