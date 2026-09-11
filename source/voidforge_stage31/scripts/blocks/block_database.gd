extends Node
## Central immutable-at-runtime registry for buildable BlockDefinition resources.
## Stable IDs are the bridge between construction, persistence, future recipes/UI, and presentation.

signal database_reloaded(block_count: int)
signal database_validation_failed(errors: Array[String])

const BLOCK_DEFINITION_SCRIPT := preload("res://scripts/blocks/block_definition.gd")
const DEFAULT_CATALOG := preload("res://data/blocks/block_catalog.tres")

var _blocks_by_id: Dictionary = {}
var _ordered_blocks: Array[Resource] = []
var _validation_errors: Array[String] = []
var _loaded: bool = false

func _ready() -> void:
	reload_default_catalog()

func reload_default_catalog() -> bool:
	return load_catalog(DEFAULT_CATALOG)

func load_catalog(catalog: Resource) -> bool:
	_blocks_by_id.clear()
	_ordered_blocks.clear()
	_validation_errors.clear()
	_loaded = false
	if catalog == null:
		_validation_errors.append("Block catalog resource is null.")
		_emit_validation_failure()
		return false
	var raw_blocks = catalog.get("blocks")
	if not raw_blocks is Array:
		_validation_errors.append("Block catalog has no valid blocks array.")
		_emit_validation_failure()
		return false
	_validation_errors = validate_definitions(raw_blocks)
	if not _validation_errors.is_empty():
		_emit_validation_failure()
		return false
	for definition in raw_blocks:
		var block_id := StringName(definition.get("id"))
		_blocks_by_id[block_id] = definition
		_ordered_blocks.append(definition)
	_loaded = true
	database_reloaded.emit(_ordered_blocks.size())
	if has_node("/root/DebugLog"):
		get_node("/root/DebugLog").call("info", "BlockDB", "Loaded %d block definitions" % _ordered_blocks.size())
	return true

func validate_definitions(definitions: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	var seen_variant_keys: Dictionary = {}
	if definitions.is_empty():
		errors.append("Block catalog cannot be empty.")
		return errors
	var item_db := get_node_or_null("/root/ItemDB")
	for index in definitions.size():
		var definition = definitions[index]
		if not _is_block_definition(definition):
			errors.append("Catalog entry %d is not a BlockDefinition resource." % index)
			continue
		var definition_errors: Array = definition.call("get_validation_errors", item_db)
		for error in definition_errors:
			errors.append("Entry %d: %s" % [index, String(error)])
		var block_id := StringName(definition.get("id"))
		if block_id == &"":
			continue
		if seen_ids.has(block_id):
			errors.append("Duplicate block ID '%s' at entries %d and %d." % [String(block_id), int(seen_ids[block_id]), index])
		else:
			seen_ids[block_id] = index
		var variant_group := StringName(definition.get("variant_group"))
		var variant_key := StringName(definition.get("variant_key"))
		if variant_group != &"" and variant_key != &"":
			var variant_token := "%s:%s" % [String(variant_group), String(variant_key)]
			if seen_variant_keys.has(variant_token):
				errors.append("Duplicate variant key '%s' in group '%s'." % [String(variant_key), String(variant_group)])
			else:
				seen_variant_keys[variant_token] = index
	return errors

func is_database_valid() -> bool:
	return _loaded and _validation_errors.is_empty()

func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func get_block_count() -> int:
	return _ordered_blocks.size()

func has_block(block_id: StringName) -> bool:
	return block_id != &"" and _blocks_by_id.has(block_id)

func get_block(block_id: StringName) -> Resource:
	return _blocks_by_id.get(block_id) as Resource

func get_all_blocks() -> Array[Resource]:
	return _ordered_blocks.duplicate()

func get_blocks_by_category(category: StringName) -> Array[Resource]:
	var matches: Array[Resource] = []
	for definition in _ordered_blocks:
		if StringName(definition.get("category")) == category:
			matches.append(definition)
	return matches

func get_blocks_with_tag(tag: StringName) -> Array[Resource]:
	var matches: Array[Resource] = []
	if tag == &"":
		return matches
	for definition in _ordered_blocks:
		var tags = definition.get("tags")
		if tags is Array and tag in tags:
			matches.append(definition)
	return matches

func get_blocks_by_variant_group(variant_group: StringName) -> Array[Resource]:
	var matches: Array[Resource] = []
	if variant_group == &"":
		return matches
	for definition in _ordered_blocks:
		if StringName(definition.get("variant_group")) == variant_group:
			matches.append(definition)
	matches.sort_custom(func(a: Resource, b: Resource) -> bool:
		var order_a := int(a.get("variant_order"))
		var order_b := int(b.get("variant_order"))
		if order_a == order_b:
			return String(a.get("id")) < String(b.get("id"))
		return order_a < order_b
	)
	return matches

func get_categories() -> Array[StringName]:
	var seen: Dictionary = {}
	for definition in _ordered_blocks:
		seen[StringName(definition.get("category"))] = true
	var categories: Array[StringName] = []
	for raw_category in seen.keys():
		categories.append(StringName(raw_category))
	categories.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return categories

func is_block_allowed_on_grid(block_id: StringName, grid_profile_id: StringName) -> bool:
	var definition := get_block(block_id)
	return definition != null and bool(definition.call("allows_grid", grid_profile_id))

func validate_instance_state(instance: Resource, grid_profile_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if instance == null:
		errors.append("Block instance is null.")
		return errors
	var block_id := StringName(instance.get("block_id"))
	var definition := get_block(block_id)
	if definition == null:
		errors.append("Unknown registered block ID '%s'." % String(block_id))
		return errors
	if not bool(definition.call("allows_grid", grid_profile_id)):
		errors.append("Block '%s' is not allowed on grid profile '%s'." % [String(block_id), String(grid_profile_id)])
	var saved_dimensions := Vector3i(instance.get("dimensions_cells"))
	var canonical_dimensions := Vector3i(definition.get("dimensions_cells"))
	if saved_dimensions != canonical_dimensions:
		errors.append("Block '%s' dimensions %s do not match catalog dimensions %s." % [String(block_id), str(saved_dimensions), str(canonical_dimensions)])
	return errors

func _is_block_definition(value) -> bool:
	return value is Resource and value.get_script() == BLOCK_DEFINITION_SCRIPT

func _emit_validation_failure() -> void:
	database_validation_failed.emit(_validation_errors.duplicate())
	if has_node("/root/DebugLog"):
		get_node("/root/DebugLog").call("error", "BlockDB", "Block database validation failed: %s" % " | ".join(PackedStringArray(_validation_errors)))
