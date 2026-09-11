extends Node
## Headless runtime checks for Stage 7 item database/content registration.

const INVENTORY_SCRIPT := preload("res://scripts/inventory/inventory_component.gd")
const ITEM_DEFINITION_SCRIPT := preload("res://scripts/inventory/item_definition.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_test_default_catalog_load()
	_test_lookup_and_queries()
	_test_validation_guards()
	_test_inventory_registry_integration()
	_test_query_results_are_defensive()

	if _failures.is_empty():
		print("STAGE7_ITEM_DATABASE_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE7_ITEM_DATABASE_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _test_default_catalog_load() -> void:
	_assert(ItemDB.is_database_valid(), "Default production item catalog validates at runtime")
	_assert(ItemDB.get_validation_errors().is_empty(), "Loaded production catalog reports no validation errors")
	_assert(ItemDB.get_item_count() == 21, "Production catalog contains the original Stage 7 content plus the Stage 31 hand tool")
	_assert(ItemDB.get_items_by_category(&"raw_ore").size() == 11, "Catalog contains 11 raw resources/ores")
	_assert(ItemDB.get_items_by_category(&"component").size() == 9, "Catalog contains 9 manufactured components")

func _test_lookup_and_queries() -> void:
	var ferrite = ItemDB.get_item(&"ore_ferrite")
	_assert(ferrite != null, "Stable ID lookup resolves Ferrite Ore")
	if ferrite != null:
		_assert(String(ferrite.get("display_name")) == "Ferrite Ore", "Lookup returns expected display metadata")
		_assert(ferrite.get("category") == &"raw_ore", "Lookup returns expected category")

	var plate = ItemDB.get_item(&"component_structural_plate")
	_assert(plate != null and String(plate.get("display_name")) == "Structural Plate", "Component lookup resolves Structural Plate")
	_assert(ItemDB.get_item(&"missing_item") == null and not ItemDB.has_item(&"missing_item"), "Unknown IDs fail lookup cleanly")
	_assert(ItemDB.get_items_with_tag(&"starter").size() == 10, "Starter tag query includes the Stage 31 hand drill")
	_assert(ItemDB.get_items_with_tag(&"rare").size() == 2, "Rare tag query returns the two Stage 7 rare resources")
	var categories: Array[StringName] = ItemDB.get_categories()
	_assert(categories.size() == 3 and categories[0] == &"component" and categories[1] == &"raw_ore" and categories[2] == &"tool", "Category query remains unique and deterministic after tools are introduced")

func _test_validation_guards() -> void:
	var first = _make_item(&"duplicate_probe", "Duplicate Probe")
	var second = _make_item(&"duplicate_probe", "Duplicate Probe 2")
	var duplicate_errors: Array[String] = ItemDB.validate_definitions([first, second])
	_assert(_contains_fragment(duplicate_errors, "Duplicate item ID"), "Database validation detects duplicate IDs")

	var invalid = _make_item(&"Bad-ID", "Invalid Probe")
	var invalid_errors: Array[String] = invalid.get_validation_errors()
	_assert(_contains_fragment(invalid_errors, "lowercase snake_case"), "ItemDefinition rejects invalid stable-ID format")
	invalid.id = &"valid_probe"
	invalid.category = &"Bad Category"
	_assert(_contains_fragment(invalid.get_validation_errors(), "Category"), "ItemDefinition validates category format")
	invalid.category = &"test"
	var duplicate_tags: Array[StringName] = [&"probe", &"probe"]
	invalid.tags = duplicate_tags
	_assert(_contains_fragment(invalid.get_validation_errors(), "Duplicate tag"), "ItemDefinition rejects duplicate tags")

func _test_inventory_registry_integration() -> void:
	var inventory = INVENTORY_SCRIPT.new()
	inventory.capacity_l = 100.0
	inventory.max_stacks = 8
	add_child(inventory)

	_assert(inventory.resolve_definition(&"component_structural_plate") == ItemDB.get_item(&"component_structural_plate"), "Inventory resolves production metadata through ItemDB")
	_assert(inventory.can_add_by_id(&"component_structural_plate", 10), "Inventory capacity query accepts stable production item ID")
	_assert(inventory.add_item_by_id(&"component_structural_plate", 10) == 10, "Inventory adds registered production items by stable ID")
	_assert(inventory.get_item_count(&"component_structural_plate") == 10, "Registry-backed add creates correct stack quantity")
	_assert(is_equal_approx(inventory.get_total_mass_kg(), 25.0), "Registry-backed inventory uses catalog mass metadata")
	_assert(is_equal_approx(inventory.get_used_volume_l(), 6.5), "Registry-backed inventory uses catalog volume metadata")
	_assert(inventory.add_item_by_id(&"missing_item", 10) == 0, "Unknown stable IDs cannot enter inventory")
	inventory.queue_free()

func _test_query_results_are_defensive() -> void:
	var all_items: Array[Resource] = ItemDB.get_all_items()
	all_items.clear()
	_assert(ItemDB.get_item_count() == 21, "Clearing returned item arrays cannot clear the registry")
	var errors: Array[String] = ItemDB.get_validation_errors()
	errors.append("synthetic caller mutation")
	_assert(ItemDB.get_validation_errors().is_empty(), "Validation error queries return defensive copies")

func _make_item(id: StringName, name: String):
	var item = ITEM_DEFINITION_SCRIPT.new()
	item.id = id
	item.display_name = name
	item.category = &"test"
	var probe_tags: Array[StringName] = [&"probe"]
	item.tags = probe_tags
	item.unit_mass_kg = 1.0
	item.unit_volume_l = 1.0
	item.stack_limit = 10
	return item

func _contains_fragment(values: Array[String], fragment: String) -> bool:
	for value in values:
		if fragment in value:
			return true
	return false

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
