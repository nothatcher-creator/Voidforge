extends Node
## Central read-only-at-runtime registry for production ItemDefinition resources.
##
## The database owns stable ID -> definition indexing and query helpers. Content resources
## are treated as immutable after load. Runtime inventories keep stable IDs in their stack
## payloads and resolve definitions through this registry when needed.

signal database_reloaded(item_count: int)
signal database_validation_failed(errors: Array[String])

const ITEM_DEFINITION_SCRIPT := preload("res://scripts/inventory/item_definition.gd")
const DEFAULT_CATALOG := preload("res://data/items/item_catalog.tres")

var _items_by_id: Dictionary = {}
var _ordered_items: Array[Resource] = []
var _validation_errors: Array[String] = []
var _loaded: bool = false

func _ready() -> void:
	reload_default_catalog()

func reload_default_catalog() -> bool:
	return load_catalog(DEFAULT_CATALOG)

func load_catalog(catalog: Resource) -> bool:
	_items_by_id.clear()
	_ordered_items.clear()
	_validation_errors.clear()
	_loaded = false

	if catalog == null:
		_validation_errors.append("Item catalog resource is null.")
		_emit_validation_failure()
		return false

	var raw_items = catalog.get("items")
	if not raw_items is Array:
		_validation_errors.append("Item catalog has no valid items array.")
		_emit_validation_failure()
		return false

	_validation_errors = validate_definitions(raw_items)
	if not _validation_errors.is_empty():
		_emit_validation_failure()
		return false

	for definition in raw_items:
		var item_id: StringName = definition.get("id")
		_items_by_id[item_id] = definition
		_ordered_items.append(definition)

	_loaded = true
	database_reloaded.emit(_ordered_items.size())
	if has_node("/root/DebugLog"):
		get_node("/root/DebugLog").call("info", "ItemDB", "Loaded %d production item definitions" % _ordered_items.size())
	return true

func validate_definitions(definitions: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}

	if definitions.is_empty():
		errors.append("Item catalog cannot be empty.")
		return errors

	for index in definitions.size():
		var definition = definitions[index]
		if not _is_item_definition(definition):
			errors.append("Catalog entry %d is not an ItemDefinition resource." % index)
			continue

		var definition_errors = definition.call("get_validation_errors")
		for error in definition_errors:
			errors.append("Entry %d: %s" % [index, String(error)])

		var item_id: StringName = definition.get("id")
		if item_id == &"":
			continue
		if seen_ids.has(item_id):
			errors.append("Duplicate item ID '%s' at entries %d and %d." % [String(item_id), int(seen_ids[item_id]), index])
		else:
			seen_ids[item_id] = index

	return errors

func is_database_valid() -> bool:
	return _loaded and _validation_errors.is_empty()

func get_item_count() -> int:
	return _ordered_items.size()

func has_item(item_id: StringName) -> bool:
	return item_id != &"" and _items_by_id.has(item_id)

func get_item(item_id: StringName) -> Resource:
	return _items_by_id.get(item_id) as Resource

func get_all_items() -> Array[Resource]:
	return _ordered_items.duplicate()

func get_items_by_category(category: StringName) -> Array[Resource]:
	var matches: Array[Resource] = []
	if category == &"":
		return matches
	for definition in _ordered_items:
		if definition.get("category") == category:
			matches.append(definition)
	return matches

func get_items_with_tag(tag: StringName) -> Array[Resource]:
	var matches: Array[Resource] = []
	if tag == &"":
		return matches
	for definition in _ordered_items:
		var tags = definition.get("tags")
		if tags is Array and tag in tags:
			matches.append(definition)
	return matches

func get_categories() -> Array[StringName]:
	var unique: Dictionary = {}
	for definition in _ordered_items:
		var category: StringName = definition.get("category")
		if category != &"":
			unique[category] = true
	var categories: Array[StringName] = []
	for category in unique.keys():
		categories.append(category)
	categories.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return categories

func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func _is_item_definition(definition) -> bool:
	return definition is Resource and definition.get_script() == ITEM_DEFINITION_SCRIPT

func _emit_validation_failure() -> void:
	database_validation_failed.emit(_validation_errors.duplicate())
	var combined := " | ".join(PackedStringArray(_validation_errors))
	if has_node("/root/DebugLog"):
		get_node("/root/DebugLog").call("error", "ItemDB", "Database validation failed: %s" % combined)
	else:
		push_error("ItemDB validation failed: %s" % combined)
