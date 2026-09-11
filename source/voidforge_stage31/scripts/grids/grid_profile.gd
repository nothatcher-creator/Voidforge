class_name GridProfile
extends Resource
## Immutable scale/behavior metadata for one construction-grid family.

@export var id: StringName
@export var display_name: String = "Unnamed Grid"
@export_range(0.05, 10.0, 0.05, "or_greater") var cell_size_m: float = 1.0
@export var is_static: bool = false

func is_valid_profile() -> bool:
	return get_validation_errors().is_empty()

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id not in [&"small", &"large", &"static"]:
		errors.append("Grid profile ID must be one of: small, large, static.")
	if display_name.strip_edges().is_empty():
		errors.append("Grid display name cannot be empty.")
	if cell_size_m <= 0.0:
		errors.append("Grid cell size must be greater than zero.")
	if id == &"static" and not is_static:
		errors.append("The static grid profile must set is_static=true.")
	if id != &"static" and is_static:
		errors.append("Only the static grid profile may set is_static=true.")
	return errors
