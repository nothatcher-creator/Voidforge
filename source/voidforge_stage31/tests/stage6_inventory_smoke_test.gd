extends Node
## Headless unit/integration checks for Stage 6 inventory architecture.

const INVENTORY_SCRIPT := preload("res://scripts/inventory/inventory_component.gd")
const ITEM_DEFINITION_SCRIPT := preload("res://scripts/inventory/item_definition.gd")
const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")

var _failures: Array[String] = []

func _ready() -> void:
	_test_stacking_mass_volume_and_remove()
	_test_volume_capacity_and_invalid_quantities()
	_test_stack_slot_capacity()
	_test_transfer_integrity()
	_test_definition_validation_and_conflicts()
	_test_player_inventory_ownership()

	if _failures.is_empty():
		print("STAGE6_INVENTORY_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE6_INVENTORY_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _test_stacking_mass_volume_and_remove() -> void:
	var inventory = _make_inventory(5.0, 4)
	var iron = _make_item(&"test_iron", 2.0, 0.5, 3)
	var changed_count := [0]
	inventory.inventory_changed.connect(func() -> void: changed_count[0] += 1)

	_assert(inventory.add_item(iron, 5) == 5, "Add accepts requested quantity inside capacity")
	_assert(inventory.get_item_count(&"test_iron") == 5, "Item count totals split stacks")
	_assert(inventory.get_stack_count() == 2, "Stack limit splits five units into two stacks")
	var snapshot: Array[Dictionary] = inventory.get_stack_snapshot()
	_assert(snapshot.size() == 2 and int(snapshot[0]["quantity"]) == 3 and int(snapshot[1]["quantity"]) == 2, "Stack snapshot preserves stack-limit quantities")
	_assert(is_equal_approx(inventory.get_used_volume_l(), 2.5), "Used volume sums item unit volume")
	_assert(is_equal_approx(inventory.get_total_mass_kg(), 10.0), "Total mass sums item unit mass")
	_assert(inventory.has_item(&"test_iron", 5), "has_item recognizes sufficient quantity")
	_assert(not inventory.has_item(&"test_iron", 6), "has_item rejects insufficient quantity")
	_assert(inventory.remove_item(&"test_iron", 4) == 4, "Remove spans multiple stacks")
	_assert(inventory.get_item_count(&"test_iron") == 1 and inventory.get_stack_count() == 1, "Empty stacks are removed after mutation")
	_assert(changed_count[0] == 2, "Inventory mutation signal fires once for add and remove operations")
	inventory.queue_free()

func _test_volume_capacity_and_invalid_quantities() -> void:
	var inventory = _make_inventory(1.1, 8)
	var ore = _make_item(&"test_ore", 1.0, 0.5, 50)
	_assert(inventory.get_addable_quantity(ore, 10) == 2, "Volume capacity reports partial addable quantity")
	_assert(not inventory.can_add(ore, 3), "can_add requires the full requested quantity to fit")
	_assert(inventory.add_item(ore, 10) == 2, "Add clamps to remaining volume capacity")
	_assert(is_equal_approx(inventory.get_used_volume_l(), 1.0), "Partial volume fill remains within capacity")
	var before = int(inventory.get_item_count(&"test_ore"))
	_assert(inventory.add_item(ore, 0) == 0 and inventory.add_item(ore, -4) == 0, "Zero and negative adds are rejected")
	_assert(inventory.remove_item(&"test_ore", 0) == 0 and inventory.remove_item(&"test_ore", -2) == 0, "Zero and negative removals are rejected")
	_assert(inventory.get_item_count(&"test_ore") == before, "Invalid quantities never mutate inventory state")
	inventory.queue_free()

func _test_stack_slot_capacity() -> void:
	var inventory = _make_inventory(100.0, 2)
	var chip = _make_item(&"test_chip", 0.1, 0.0, 3)
	_assert(inventory.add_item(chip, 10) == 6, "Max-stack count limits even zero-volume items")
	_assert(inventory.get_stack_count() == 2, "Stack slot limit is enforced")
	_assert(inventory.get_addable_quantity(chip, 1) == 0, "Full stack slots reject additional items")
	inventory.queue_free()

func _test_transfer_integrity() -> void:
	var source = _make_inventory(20.0, 8)
	var target = _make_inventory(1.5, 8)
	var plate = _make_item(&"test_plate", 3.0, 0.5, 10)
	_assert(source.add_item(plate, 6) == 6, "Transfer source setup succeeds")
	_assert(source.transfer_to(target, &"test_plate", 6) == 3, "Transfer clamps to destination capacity")
	_assert(source.get_item_count(&"test_plate") == 3, "Partial transfer removes only accepted source quantity")
	_assert(target.get_item_count(&"test_plate") == 3, "Partial transfer adds matching destination quantity")
	_assert(source.get_item_count(&"test_plate") + target.get_item_count(&"test_plate") == 6, "Transfer conserves total item quantity")
	_assert(source.transfer_to(source, &"test_plate", 1) == 0, "Self-transfer is rejected without mutation")
	_assert(source.transfer_to(target, &"test_plate", -1) == 0, "Negative transfer is rejected")
	source.queue_free()
	target.queue_free()

func _test_definition_validation_and_conflicts() -> void:
	var inventory = _make_inventory(20.0, 8)
	var invalid = _make_item(&"", 1.0, 1.0, 10)
	_assert(not invalid.is_valid_definition(), "Empty item IDs fail definition validation")
	_assert(inventory.add_item(invalid, 1) == 0, "Invalid item definitions cannot enter inventories")

	var valid = _make_item(&"test_conflict", 1.0, 1.0, 10)
	var conflicting = _make_item(&"test_conflict", 9.0, 1.0, 10)
	_assert(inventory.add_item(valid, 1) == 1, "Initial runtime item definition registers")
	_assert(inventory.add_item(conflicting, 1) == 0, "Conflicting metadata for one item ID is rejected")
	_assert(inventory.get_total_mass_kg() == 1.0, "Rejected metadata conflict cannot alter existing mass calculations")
	inventory.queue_free()

func _test_player_inventory_ownership() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.set("capture_mouse_on_start", false)
	add_child(player)
	var inventory = player.get_node_or_null("Inventory")
	_assert(inventory != null, "Production player owns an inventory component")
	if inventory != null:
		_assert(is_equal_approx(float(inventory.get("capacity_l")), 120.0), "Player inventory has 120 L initial capacity")
		_assert(int(inventory.get("max_stacks")) == 24, "Player inventory has 24 initial stack slots")
		_assert(player.call("get_inventory") == inventory, "Player exposes its owned inventory through a stable accessor")
	player.queue_free()

func _make_inventory(capacity: float, stacks: int):
	var inventory = INVENTORY_SCRIPT.new()
	inventory.capacity_l = capacity
	inventory.max_stacks = stacks
	add_child(inventory)
	return inventory

func _make_item(id: StringName, mass_kg: float, volume_l: float, stack_limit: int):
	var item = ITEM_DEFINITION_SCRIPT.new()
	item.id = id
	item.display_name = String(id)
	item.unit_mass_kg = mass_kg
	item.unit_volume_l = volume_l
	item.stack_limit = stack_limit
	return item

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
