class_name ItemDefinition
extends Resource
## Shared immutable-content metadata contract for inventory items/resources.

@export_group("Identity")
@export var id: StringName
@export var display_name: String = "Unnamed Item"
@export_multiline var description: String = ""
@export var category: StringName = &"component"
@export var tags: Array[StringName] = []

@export_group("Inventory")
@export_range(0.0, 100000.0, 0.0001, "or_greater") var unit_mass_kg: float = 0.0
@export_range(0.0, 100000.0, 0.0001, "or_greater") var unit_volume_l: float = 0.0
@export_range(1, 1000000, 1, "or_greater") var stack_limit: int = 100

@export_group("Tool")
@export var tool_type: StringName = &""
@export_range(0.0, 100.0, 0.01, "or_greater") var tool_range_m: float = 0.0
@export_range(0.0, 10000.0, 0.01, "or_greater") var tool_work_rate_per_s: float = 0.0

@export_group("Presentation")
@export var icon: Texture2D

func is_valid_definition() -> bool:
	return get_validation_errors().is_empty()

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var id_text := String(id)
	if id == &"":
		errors.append("Item ID cannot be empty.")
	elif not _is_valid_content_id(id_text):
		errors.append("Item ID '%s' must use lowercase snake_case ASCII characters." % id_text)
	if display_name.strip_edges().is_empty():
		errors.append("Display name cannot be empty.")
	if category == &"":
		errors.append("Category cannot be empty.")
	elif not _is_valid_content_id(String(category)):
		errors.append("Category '%s' must use lowercase snake_case ASCII characters." % String(category))
	if stack_limit <= 0:
		errors.append("Stack limit must be greater than zero.")
	if unit_mass_kg < 0.0:
		errors.append("Unit mass cannot be negative.")
	if unit_volume_l < 0.0:
		errors.append("Unit volume cannot be negative.")
	if tool_type != &"":
		if not _is_valid_content_id(String(tool_type)):
			errors.append("Tool type '%s' must use lowercase snake_case ASCII characters." % String(tool_type))
		if tool_range_m <= 0.0:
			errors.append("Tool range must be greater than zero when a tool type is configured.")
		if tool_work_rate_per_s <= 0.0:
			errors.append("Tool work rate must be greater than zero when a tool type is configured.")
	elif tool_range_m > 0.0 or tool_work_rate_per_s > 0.0:
		errors.append("Tool range/work metadata requires a non-empty tool type.")

	var seen_tags: Dictionary = {}
	for tag in tags:
		var tag_text := String(tag)
		if tag == &"":
			errors.append("Tags cannot contain an empty value.")
		elif not _is_valid_content_id(tag_text):
			errors.append("Tag '%s' must use lowercase snake_case ASCII characters." % tag_text)
		elif seen_tags.has(tag):
			errors.append("Duplicate tag '%s'." % tag_text)
		else:
			seen_tags[tag] = true
	return errors

func _is_valid_content_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	var first := value.unicode_at(0)
	if not ((first >= 97 and first <= 122)):
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not (is_lower or is_digit or code == 95):
			return false
	return true
