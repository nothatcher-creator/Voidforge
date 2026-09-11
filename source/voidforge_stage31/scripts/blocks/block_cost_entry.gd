class_name BlockCostEntry
extends Resource
## One immutable construction-cost row for a BlockDefinition.
## Item references use ItemDB stable IDs so block data stays save-friendly and Android-safe.

@export var item_id: StringName
@export_range(1, 1000000, 1, "or_greater") var quantity: int = 1

func is_valid_entry(item_db: Node = null) -> bool:
	return get_validation_errors(item_db).is_empty()

func get_validation_errors(item_db: Node = null) -> Array[String]:
	var errors: Array[String] = []
	if item_id == &"":
		errors.append("Construction-cost item ID cannot be empty.")
	elif quantity <= 0:
		errors.append("Construction-cost quantity must be greater than zero.")
	if item_id != &"" and item_db != null and item_db.has_method("has_item") and not bool(item_db.call("has_item", item_id)):
		errors.append("Construction-cost item '%s' is not registered in ItemDB." % String(item_id))
	return errors
