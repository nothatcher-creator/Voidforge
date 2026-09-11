extends Node
## Authoritative Stage 9 registry for construction-grid profiles.

const SMALL_PROFILE := preload("res://data/grids/small_grid_profile.tres")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")
const STATIC_PROFILE := preload("res://data/grids/static_grid_profile.tres")

var _profiles: Dictionary = {}
var _validation_errors: Array[String] = []

func _ready() -> void:
	_rebuild_registry()
	if _validation_errors.is_empty():
		DebugLog.info("GridDB", "Loaded %d grid profiles" % _profiles.size())
	else:
		DebugLog.error("GridDB", "Grid profile validation failed: %s" % " | ".join(PackedStringArray(_validation_errors)))

func _rebuild_registry() -> void:
	_profiles.clear()
	_validation_errors.clear()
	for profile in [SMALL_PROFILE, LARGE_PROFILE, STATIC_PROFILE]:
		_register_profile(profile)

func _register_profile(profile: Resource) -> void:
	if profile == null:
		_validation_errors.append("Grid registry contains a null profile.")
		return
	var errors: Array = profile.call("get_validation_errors") if profile.has_method("get_validation_errors") else ["Profile has no validation contract."]
	for error in errors:
		_validation_errors.append(String(error))
	var profile_id := StringName(profile.get("id"))
	if profile_id == &"":
		return
	if _profiles.has(profile_id):
		_validation_errors.append("Duplicate grid profile ID '%s'." % String(profile_id))
		return
	_profiles[profile_id] = profile

func get_profile(profile_id: StringName) -> Resource:
	return _profiles.get(profile_id) as Resource

func get_profile_count() -> int:
	return _profiles.size()

func get_all_profiles() -> Array[Resource]:
	var result: Array[Resource] = []
	for profile_id in [&"small", &"large", &"static"]:
		var profile := get_profile(profile_id)
		if profile != null:
			result.append(profile)
	return result

func is_database_valid() -> bool:
	return _validation_errors.is_empty() and _profiles.size() == 3

func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()
