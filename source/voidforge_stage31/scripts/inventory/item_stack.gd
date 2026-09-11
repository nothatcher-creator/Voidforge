extends Resource
## Minimal serializable inventory stack payload.
## Item metadata is resolved separately from the stable item_id.

@export var item_id: StringName = &""
@export_range(0, 1000000000, 1, "or_greater") var quantity: int = 0

func is_valid() -> bool:
	return item_id != &"" and quantity > 0

func to_dictionary() -> Dictionary:
	return {
		"item_id": String(item_id),
		"quantity": quantity,
	}
