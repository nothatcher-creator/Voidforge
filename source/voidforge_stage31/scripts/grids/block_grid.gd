class_name BlockGrid
extends RigidBody3D
## Sparse construction grid. Runtime occupancy stays native and compact; Stage 13 adds
## persistence, Stage 14 validates registered block metadata, and Stage 19 keeps rigid-body mass
## synchronized with authoritative BlockDB block masses.

signal block_added(instance_id: int, block_id: StringName)
signal block_removed(instance_id: int, block_id: StringName)
signal grid_changed(block_count: int, occupied_cell_count: int)
signal grid_reloaded(block_count: int, occupied_cell_count: int)
signal simulation_mode_changed(dynamic_enabled: bool)
signal mass_changed(total_mass_kg: float, physics_mass_kg: float)
signal pilot_changed(pilot: Node, seat_instance_id: int)
signal propulsion_changed(thruster_count: int, total_rated_thrust_n: float)
signal gyroscope_changed(gyroscope_count: int, total_rated_torque_nm: float)
signal power_network_changed(generation_kw: float, rated_demand_kw: float, active_demand_kw: float, satisfaction_ratio: float)
signal battery_storage_changed(stored_energy_kwh: float, capacity_kwh: float, state_of_charge: float)
signal block_configuration_changed(instance_id: int)
signal block_groups_changed

const BLOCK_INSTANCE_SCRIPT := preload("res://scripts/grids/block_instance_data.gd")
const BLOCK_ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const GRID_SAVE_SCHEMA: String = "voidforge.block_grid"
const GRID_SAVE_VERSION: int = 3
const GRID_SAVE_MIN_SUPPORTED_VERSION: int = 1
const WORLD_COLLISION_MASK: int = 1 << 0
const GRID_COLLISION_LAYER: int = 1 << 2
const MIN_RIGID_BODY_MASS_KG: float = 0.001
const MASS_EPSILON_KG: float = 0.0001
const BATTERY_ENERGY_EPSILON_KWH: float = 0.000001
const BATTERY_SIGNAL_STEP_KWH: float = 0.01
const MAX_BLOCK_CUSTOM_NAME_LENGTH: int = 48
const MAX_GROUP_NAME_LENGTH: int = 32
const POWER_PRIORITY_USE_DEFINITION: int = -1
const ORTHOGONAL_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]

@export var grid_profile: Resource
@export var start_dynamic: bool = false
@export_range(0.0, 10.0, 0.05, "or_greater") var dynamic_gravity_scale: float = 1.0
@export_range(0.0, 10.0, 0.01, "or_greater") var dynamic_linear_damp: float = 0.05
@export_range(0.0, 10.0, 0.01, "or_greater") var dynamic_angular_damp: float = 0.1
@export var allow_sleeping: bool = true
@export var power_network_enabled: bool = true
@export var priority_load_shedding_enabled: bool = true

var _cells: Dictionary = {}
var _instances: Dictionary = {}
var _next_instance_id: int = 1
var _calculated_mass_kg: float = 0.0
var _runtime_block_masses: Dictionary = {}
var _active_pilot: Node
var _active_control_seat_instance_id: int = 0
var _manual_translation_input_local: Vector3 = Vector3.ZERO
var _manual_rotation_input_local: Vector3 = Vector3.ZERO
var _thruster_cache_dirty: bool = true
var _thruster_instance_ids: Array[int] = []
var _combined_thruster_local_force_n: Vector3 = Vector3.ZERO
var _total_rated_thrust_n: float = 0.0
var _directional_rated_thrust_n: Dictionary = {}
var _directional_thruster_instance_ids: Dictionary = {}
var _gyroscope_cache_dirty: bool = true
var _gyroscope_instance_ids: Array[int] = []
var _total_gyro_torque_nm: float = 0.0
var _power_cache_dirty: bool = true
var _power_producer_instance_ids: Array[int] = []
var _power_consumer_instance_ids: Array[int] = []
var _power_consumer_instance_ids_by_priority: Dictionary = {}
var _total_power_generation_kw: float = 0.0
var _total_rated_power_demand_kw: float = 0.0
var _battery_instance_ids: Array[int] = []
var _battery_stored_energy_kwh: Dictionary = {}
var _battery_charge_rate_kw_by_instance: Dictionary = {}
var _battery_discharge_rate_kw_by_instance: Dictionary = {}
var _total_battery_capacity_kwh: float = 0.0
var _total_battery_max_charge_kw: float = 0.0
var _total_battery_max_discharge_kw: float = 0.0
var _last_battery_charge_kw: float = 0.0
var _last_battery_discharge_kw: float = 0.0
var _last_emitted_battery_stored_kwh: float = -1.0
var _physics_power_satisfaction_override: float = -1.0
var _physics_power_allocation_override: Dictionary = {}
var _block_enabled_state: Dictionary = {}
var _block_custom_names: Dictionary = {}
var _block_power_priority_overrides: Dictionary = {}
var _block_groups: Dictionary = {}

func _init() -> void:
	# Every construction grid starts as a frozen rigid body. Dynamic simulation is opt-in so
	# the Stage 9-17 construction behavior remains deterministic until a craft is released.
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	continuous_cd = true
	contact_monitor = false
	max_contacts_reported = 0
	collision_layer = GRID_COLLISION_LAYER
	collision_mask = 0

func _ready() -> void:
	if grid_profile == null:
		DebugLog.warn("BlockGrid", "%s has no grid profile assigned" % name)
	elif not _is_profile_valid(grid_profile):
		DebugLog.error("BlockGrid", "%s has an invalid grid profile" % name)
	var block_db := get_node_or_null("/root/BlockDB")
	if block_db != null and block_db.has_signal("database_reloaded") and not block_db.is_connected("database_reloaded", Callable(self, "_on_block_database_reloaded")):
		block_db.connect("database_reloaded", Callable(self, "_on_block_database_reloaded"))
	recalculate_mass_from_blocks(false)
	_mark_thruster_cache_dirty(false)
	_mark_gyroscope_cache_dirty(false)
	_mark_power_cache_dirty(false)
	_apply_simulation_settings(start_dynamic and not is_static_grid(), false)

func _physics_process(delta: float) -> void:
	# Storage simulation runs even on frozen/static grids so batteries can recharge while a
	# station is idle. A per-tick satisfaction override ensures the final fraction of stored
	# energy can still power the same physics tick that consumes it.
	_physics_power_allocation_override = _calculate_power_allocation(delta) if power_network_enabled else {}
	_physics_power_satisfaction_override = float(_physics_power_allocation_override.get("satisfaction_ratio", 1.0)) if power_network_enabled else 1.0

	if is_dynamic_simulation_enabled() and has_active_pilot():
		if not can_receive_manual_control(get_active_pilot()):
			_manual_translation_input_local = Vector3.ZERO
			_manual_rotation_input_local = Vector3.ZERO
		else:
			var force_local := get_active_manual_force_local_n()
			if force_local.length_squared() > 0.0001:
				apply_central_force(global_transform.basis * force_local)
			var torque_local := get_active_manual_torque_local_nm()
			if torque_local.length_squared() > 0.0001:
				apply_torque(global_transform.basis * torque_local)

	if power_network_enabled:
		_advance_battery_storage(delta)
	else:
		_reset_battery_flow_rates()
	_physics_power_satisfaction_override = -1.0
	_physics_power_allocation_override.clear()

func configure(profile: Resource) -> bool:
	if not _instances.is_empty():
		return false
	if not _is_profile_valid(profile):
		return false
	grid_profile = profile
	recalculate_mass_from_blocks(false)
	_apply_simulation_settings(false, false)
	return true

func get_grid_type() -> StringName:
	if grid_profile == null:
		return &""
	return StringName(grid_profile.get("id"))

func get_cell_size_m() -> float:
	if grid_profile == null:
		return 0.0
	return float(grid_profile.get("cell_size_m"))

func is_static_grid() -> bool:
	return grid_profile != null and bool(grid_profile.get("is_static"))

func get_next_instance_id() -> int:
	return _next_instance_id

func can_be_dynamic() -> bool:
	return _is_profile_valid(grid_profile) and not is_static_grid()

func is_dynamic_simulation_enabled() -> bool:
	return can_be_dynamic() and not freeze

func set_dynamic_simulation_enabled(enabled: bool, wake_body: bool = true) -> bool:
	if enabled and not can_be_dynamic():
		return false
	_apply_simulation_settings(enabled, wake_body)
	simulation_mode_changed.emit(is_dynamic_simulation_enabled())
	return true

func get_total_mass_kg() -> float:
	return _calculated_mass_kg

func get_physics_mass_kg() -> float:
	return mass

func get_mass_state() -> Dictionary:
	return {
		"total_mass_kg": _calculated_mass_kg,
		"physics_mass_kg": mass,
		"block_count": get_block_count(),
		"uses_safety_floor": _calculated_mass_kg < MIN_RIGID_BODY_MASS_KG,
	}

func recalculate_mass_from_blocks(emit_signal: bool = true) -> bool:
	var calculated := _calculate_mass_for_instances(_instances)
	if not bool(calculated.get("ok", false)):
		DebugLog.error("BlockGrid", "Unable to calculate grid mass: %s" % String(calculated.get("error", "unknown mass error")))
		return false
	_set_calculated_mass(float(calculated["mass_kg"]), emit_signal)
	return true

func get_active_pilot() -> Node:
	return _active_pilot if is_instance_valid(_active_pilot) else null

func get_active_control_seat_instance_id() -> int:
	return _active_control_seat_instance_id

func has_active_pilot() -> bool:
	return is_instance_valid(get_active_pilot()) and _active_control_seat_instance_id > 0

func has_valid_control_seat(instance_id: int) -> bool:
	if instance_id <= 0:
		return false
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return false
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	return definition != null and StringName(definition.get("functional_type")) == &"control_seat" and is_block_enabled(instance_id)

func get_control_seat_instance_ids() -> Array[int]:
	var result: Array[int] = []
	for instance in get_all_blocks():
		var instance_id := int(instance.get("instance_id"))
		if has_valid_control_seat(instance_id):
			result.append(instance_id)
	return result

func can_claim_manual_control(actor: Node, seat_instance_id: int) -> bool:
	if actor == null or not is_instance_valid(actor) or not has_valid_control_seat(seat_instance_id):
		return false
	var pilot := get_active_pilot()
	if pilot != null and pilot != actor:
		return false
	return _active_control_seat_instance_id in [0, seat_instance_id]

func try_claim_manual_control(actor: Node, seat_instance_id: int) -> bool:
	if not can_claim_manual_control(actor, seat_instance_id):
		return false
	_active_pilot = actor
	_active_control_seat_instance_id = seat_instance_id
	if is_dynamic_simulation_enabled():
		wake_grid()
	pilot_changed.emit(_active_pilot, _active_control_seat_instance_id)
	return true

func can_receive_manual_control(actor: Node) -> bool:
	return has_active_pilot() and get_active_pilot() == actor and has_valid_control_seat(_active_control_seat_instance_id)

func release_manual_control(actor: Node) -> bool:
	if not has_active_pilot() or get_active_pilot() != actor:
		return false
	_clear_manual_control_state()
	return true

func _clear_manual_control_state() -> void:
	_manual_translation_input_local = Vector3.ZERO
	_manual_rotation_input_local = Vector3.ZERO
	_active_pilot = null
	_active_control_seat_instance_id = 0
	pilot_changed.emit(null, 0)

func _invalidate_active_pilot(reason: String = "control seat unavailable") -> void:
	if not has_active_pilot():
		_active_pilot = null
		_active_control_seat_instance_id = 0
		return
	var pilot := get_active_pilot()
	var seat_instance_id := _active_control_seat_instance_id
	if pilot != null and pilot.has_method("on_control_seat_invalidated"):
		pilot.call("on_control_seat_invalidated", self, seat_instance_id, reason)
	if has_active_pilot():
		_clear_manual_control_state()

func is_functional_block(instance_id: int) -> bool:
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return false
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	return definition != null and StringName(definition.get("functional_type")) != &"structural"

func is_block_enabled(instance_id: int) -> bool:
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return false
	if _block_enabled_state.has(instance_id):
		return bool(_block_enabled_state[instance_id])
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	return bool(definition.get("enabled_by_default")) if definition != null else false

func set_block_enabled(instance_id: int, enabled: bool) -> bool:
	if not is_functional_block(instance_id):
		return false
	if is_block_enabled(instance_id) == enabled:
		return true
	_block_enabled_state[instance_id] = enabled
	if instance_id == _active_control_seat_instance_id and not enabled:
		_invalidate_active_pilot("control seat disabled")
	_mark_thruster_cache_dirty()
	_mark_gyroscope_cache_dirty()
	_mark_power_cache_dirty()
	block_configuration_changed.emit(instance_id)
	return true

func get_block_custom_name(instance_id: int) -> String:
	if get_block_by_instance_id(instance_id) == null:
		return ""
	return String(_block_custom_names.get(instance_id, ""))

func get_block_effective_display_name(instance_id: int) -> String:
	var custom_name := get_block_custom_name(instance_id)
	if not custom_name.is_empty():
		return custom_name
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return "Unknown Block"
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	return String(definition.get("display_name")) if definition != null else String(instance.get("block_id"))

func set_block_custom_name(instance_id: int, custom_name: String) -> bool:
	if get_block_by_instance_id(instance_id) == null:
		return false
	var cleaned := custom_name.strip_edges()
	if cleaned.length() > MAX_BLOCK_CUSTOM_NAME_LENGTH or "\n" in cleaned or "\r" in cleaned or "\t" in cleaned:
		return false
	if cleaned.is_empty():
		_block_custom_names.erase(instance_id)
	else:
		_block_custom_names[instance_id] = cleaned
	block_configuration_changed.emit(instance_id)
	return true

func get_block_power_priority_override(instance_id: int) -> int:
	if get_block_by_instance_id(instance_id) == null:
		return POWER_PRIORITY_USE_DEFINITION
	return int(_block_power_priority_overrides.get(instance_id, POWER_PRIORITY_USE_DEFINITION))

func set_block_power_priority_override(instance_id: int, priority: int) -> bool:
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return false
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	if definition == null or float(definition.get("power_use_kw")) <= 0.0:
		return false
	if priority < POWER_PRIORITY_USE_DEFINITION or priority > 3:
		return false
	if priority == POWER_PRIORITY_USE_DEFINITION:
		_block_power_priority_overrides.erase(instance_id)
	else:
		_block_power_priority_overrides[instance_id] = priority
	_mark_power_cache_dirty()
	block_configuration_changed.emit(instance_id)
	return true

func get_block_configuration(instance_id: int) -> Dictionary:
	if get_block_by_instance_id(instance_id) == null:
		return {"valid": false, "instance_id": instance_id}
	return {
		"valid": true,
		"instance_id": instance_id,
		"enabled": is_block_enabled(instance_id),
		"custom_name": get_block_custom_name(instance_id),
		"display_name": get_block_effective_display_name(instance_id),
		"power_priority_override": get_block_power_priority_override(instance_id),
		"power_priority": get_block_power_priority(instance_id),
		"power_priority_name": get_block_power_priority_name(instance_id),
		"groups": get_block_group_names(instance_id),
	}

func create_block_group(group_name: String) -> bool:
	var cleaned := _sanitize_group_name(group_name)
	if cleaned.is_empty() or _find_group_key_case_insensitive(cleaned) != "":
		return false
	_block_groups[cleaned] = []
	block_groups_changed.emit()
	return true

func delete_block_group(group_name: String) -> bool:
	var key := _find_group_key_case_insensitive(group_name)
	if key.is_empty():
		return false
	_block_groups.erase(key)
	block_groups_changed.emit()
	return true

func add_block_to_group(instance_id: int, group_name: String) -> bool:
	if get_block_by_instance_id(instance_id) == null:
		return false
	var key := _find_group_key_case_insensitive(group_name)
	if key.is_empty():
		return false
	var ids := _block_groups[key] as Array
	if instance_id not in ids:
		ids.append(instance_id)
		ids.sort()
		_block_groups[key] = ids
		block_groups_changed.emit()
		block_configuration_changed.emit(instance_id)
	return true

func remove_block_from_group(instance_id: int, group_name: String) -> bool:
	var key := _find_group_key_case_insensitive(group_name)
	if key.is_empty():
		return false
	var ids := _block_groups[key] as Array
	if instance_id not in ids:
		return true
	ids.erase(instance_id)
	_block_groups[key] = ids
	block_groups_changed.emit()
	block_configuration_changed.emit(instance_id)
	return true

func get_block_group_names(instance_id: int = 0) -> Array[String]:
	var names: Array[String] = []
	for raw_name in _block_groups.keys():
		var group_name := String(raw_name)
		if instance_id > 0:
			var ids := _block_groups[raw_name] as Array
			if instance_id not in ids:
				continue
		names.append(group_name)
	names.sort_custom(func(a: String, b: String) -> bool: return a.to_lower() < b.to_lower())
	return names

func get_group_instance_ids(group_name: String) -> Array[int]:
	var key := _find_group_key_case_insensitive(group_name)
	var result: Array[int] = []
	if key.is_empty():
		return result
	for raw_id in _block_groups[key] as Array:
		var instance_id := int(raw_id)
		if get_block_by_instance_id(instance_id) != null:
			result.append(instance_id)
	result.sort()
	return result

func _sanitize_group_name(group_name: String) -> String:
	var cleaned := group_name.strip_edges()
	if cleaned.is_empty() or cleaned.length() > MAX_GROUP_NAME_LENGTH or "\n" in cleaned or "\r" in cleaned or "\t" in cleaned:
		return ""
	return cleaned

func _find_group_key_case_insensitive(group_name: String) -> String:
	var cleaned := group_name.strip_edges().to_lower()
	if cleaned.is_empty():
		return ""
	for raw_key in _block_groups.keys():
		var key := String(raw_key)
		if key.to_lower() == cleaned:
			return key
	return ""

func _purge_block_configuration(instance_id: int) -> void:
	_block_enabled_state.erase(instance_id)
	_block_custom_names.erase(instance_id)
	_block_power_priority_overrides.erase(instance_id)
	var groups_changed := false
	for raw_name in _block_groups.keys():
		var ids := _block_groups[raw_name] as Array
		if instance_id in ids:
			ids.erase(instance_id)
			_block_groups[raw_name] = ids
			groups_changed = true
	if groups_changed:
		block_groups_changed.emit()

func get_thruster_instance_ids() -> Array[int]:
	_ensure_thruster_cache()
	return _thruster_instance_ids.duplicate()

func get_thruster_count() -> int:
	_ensure_thruster_cache()
	return _thruster_instance_ids.size()

func get_total_rated_thrust_n() -> float:
	_ensure_thruster_cache()
	return _total_rated_thrust_n

func get_combined_thruster_local_force_n() -> Vector3:
	_ensure_thruster_cache()
	return _combined_thruster_local_force_n

func get_thruster_local_force_n(instance_id: int) -> Vector3:
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return Vector3.ZERO
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	if definition == null or StringName(definition.get("functional_type")) != &"thruster":
		return Vector3.ZERO
	var rated_force := float(definition.get("thrust_force_n"))
	var local_axis_i := Vector3i(definition.get("thrust_direction_local"))
	if rated_force <= 0.0 or local_axis_i == Vector3i.ZERO:
		return Vector3.ZERO
	var orientation_basis := instance.call("get_orientation_basis") as Basis
	return orientation_basis * Vector3(local_axis_i) * rated_force

func get_thruster_direction_local(instance_id: int) -> Vector3i:
	var force := get_thruster_local_force_n(instance_id)
	if force.length_squared() <= 0.0001:
		return Vector3i.ZERO
	return _cardinalize_direction(force)

func get_directional_rated_thrust_n(direction_local: Vector3i) -> float:
	if not _is_cardinal_direction(direction_local):
		return 0.0
	_ensure_thruster_cache()
	return float(_directional_rated_thrust_n.get(direction_local, 0.0))

func get_thruster_instance_ids_for_direction(direction_local: Vector3i) -> Array[int]:
	var result: Array[int] = []
	if not _is_cardinal_direction(direction_local):
		return result
	_ensure_thruster_cache()
	var raw_ids = _directional_thruster_instance_ids.get(direction_local, [])
	for raw_id in raw_ids:
		result.append(int(raw_id))
	return result

func get_directional_thrust_state() -> Dictionary:
	_ensure_thruster_cache()
	var state: Dictionary = {}
	for direction in ORTHOGONAL_DIRECTIONS:
		state[_direction_name(direction)] = {
			"direction_local": direction,
			"rated_thrust_n": float(_directional_rated_thrust_n.get(direction, 0.0)),
			"thruster_count": (get_thruster_instance_ids_for_direction(direction) as Array).size(),
		}
	return state

func set_manual_translation_input(actor: Node, input_local: Vector3) -> bool:
	if actor == null or not can_receive_manual_control(actor):
		return false
	_manual_translation_input_local = Vector3(
		clampf(input_local.x, -1.0, 1.0),
		clampf(input_local.y, -1.0, 1.0),
		clampf(input_local.z, -1.0, 1.0)
	)
	if _manual_translation_input_local.length_squared() > 0.0001 and is_dynamic_simulation_enabled():
		wake_grid()
	return true

func get_manual_translation_input_local() -> Vector3:
	return _manual_translation_input_local

# Stage 21 compatibility API: forward thrust is the local -Z translation axis.
func set_manual_thrust_input(actor: Node, strength: float) -> bool:
	return set_manual_translation_input(actor, Vector3(0.0, 0.0, -clampf(strength, 0.0, 1.0)))

func clear_manual_thrust_input(actor: Node = null) -> bool:
	if actor != null and has_active_pilot() and get_active_pilot() != actor:
		return false
	_manual_translation_input_local = Vector3.ZERO
	return true

func get_manual_thrust_strength() -> float:
	return maxf(-_manual_translation_input_local.z, 0.0)

func get_active_manual_force_local_n() -> Vector3:
	_ensure_thruster_cache()
	var input := _manual_translation_input_local
	var force := Vector3.ZERO
	if input.x > 0.0001:
		force += Vector3.RIGHT * _get_powered_directional_thrust_n(Vector3i(1, 0, 0)) * input.x
	elif input.x < -0.0001:
		force += Vector3.LEFT * _get_powered_directional_thrust_n(Vector3i(-1, 0, 0)) * -input.x
	if input.y > 0.0001:
		force += Vector3.UP * _get_powered_directional_thrust_n(Vector3i(0, 1, 0)) * input.y
	elif input.y < -0.0001:
		force += Vector3.DOWN * _get_powered_directional_thrust_n(Vector3i(0, -1, 0)) * -input.y
	if input.z > 0.0001:
		force += Vector3.BACK * _get_powered_directional_thrust_n(Vector3i(0, 0, 1)) * input.z
	elif input.z < -0.0001:
		force += Vector3.FORWARD * _get_powered_directional_thrust_n(Vector3i(0, 0, -1)) * -input.z
	return force

func _get_powered_directional_thrust_n(direction: Vector3i) -> float:
	_ensure_thruster_cache()
	var total := 0.0
	var ids := _directional_thruster_instance_ids.get(direction, []) as Array
	for raw_id in ids:
		var instance_id := int(raw_id)
		var instance := get_block_by_instance_id(instance_id)
		if instance == null:
			continue
		var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
		if definition == null:
			continue
		total += maxf(float(definition.get("thrust_force_n")), 0.0) * _get_effective_block_power_satisfaction_ratio(instance_id)
	return total

func get_propulsion_state() -> Dictionary:
	_ensure_thruster_cache()
	return {
		"thruster_count": _thruster_instance_ids.size(),
		"total_rated_thrust_n": _total_rated_thrust_n,
		"combined_local_force_n": _combined_thruster_local_force_n,
		"manual_translation_input_local": _manual_translation_input_local,
		"manual_thrust_strength": get_manual_thrust_strength(),
		"active_force_local_n": get_active_manual_force_local_n(),
		"directional": get_directional_thrust_state(),
		"rotation_control": get_rotation_control_state(),
		"power": get_power_network_state(),
	}

func _mark_thruster_cache_dirty(emit_signal_after_rebuild: bool = true) -> void:
	_thruster_cache_dirty = true
	if emit_signal_after_rebuild and is_inside_tree():
		call_deferred("_emit_propulsion_after_cache_refresh")

func _emit_propulsion_after_cache_refresh() -> void:
	if not is_inside_tree():
		return
	_ensure_thruster_cache()
	propulsion_changed.emit(_thruster_instance_ids.size(), _total_rated_thrust_n)

func _ensure_thruster_cache() -> void:
	if not _thruster_cache_dirty:
		return
	_thruster_cache_dirty = false
	_thruster_instance_ids.clear()
	_combined_thruster_local_force_n = Vector3.ZERO
	_total_rated_thrust_n = 0.0
	_directional_rated_thrust_n.clear()
	_directional_thruster_instance_ids.clear()
	for direction in ORTHOGONAL_DIRECTIONS:
		_directional_rated_thrust_n[direction] = 0.0
		_directional_thruster_instance_ids[direction] = []
	for instance in get_all_blocks():
		var instance_id := int(instance.get("instance_id"))
		var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
		if definition == null or StringName(definition.get("functional_type")) != &"thruster" or not is_block_enabled(instance_id):
			continue
		var local_force := get_thruster_local_force_n(instance_id)
		if local_force.length_squared() <= 0.0001:
			continue
		var direction := _cardinalize_direction(local_force)
		if not _is_cardinal_direction(direction):
			continue
		_thruster_instance_ids.append(instance_id)
		_combined_thruster_local_force_n += local_force
		var rated_force := float(definition.get("thrust_force_n"))
		_total_rated_thrust_n += rated_force
		_directional_rated_thrust_n[direction] = float(_directional_rated_thrust_n.get(direction, 0.0)) + rated_force
		var ids := _directional_thruster_instance_ids.get(direction, []) as Array
		ids.append(instance_id)
		_directional_thruster_instance_ids[direction] = ids
	_thruster_instance_ids.sort()
	for direction in ORTHOGONAL_DIRECTIONS:
		var ids := _directional_thruster_instance_ids.get(direction, []) as Array
		ids.sort()
		_directional_thruster_instance_ids[direction] = ids

func _cardinalize_direction(vector: Vector3) -> Vector3i:
	if vector.length_squared() <= 0.0001:
		return Vector3i.ZERO
	var normalized := vector.normalized()
	var abs_vector := normalized.abs()
	if abs_vector.x >= abs_vector.y and abs_vector.x >= abs_vector.z:
		return Vector3i(1 if normalized.x >= 0.0 else -1, 0, 0)
	if abs_vector.y >= abs_vector.x and abs_vector.y >= abs_vector.z:
		return Vector3i(0, 1 if normalized.y >= 0.0 else -1, 0)
	return Vector3i(0, 0, 1 if normalized.z >= 0.0 else -1)

func _is_cardinal_direction(direction: Vector3i) -> bool:
	return direction in ORTHOGONAL_DIRECTIONS

func _direction_name(direction: Vector3i) -> StringName:
	match direction:
		Vector3i(1, 0, 0): return &"right"
		Vector3i(-1, 0, 0): return &"left"
		Vector3i(0, 1, 0): return &"up"
		Vector3i(0, -1, 0): return &"down"
		Vector3i(0, 0, 1): return &"backward"
		Vector3i(0, 0, -1): return &"forward"
	return &"invalid"

func get_gyroscope_instance_ids() -> Array[int]:
	_ensure_gyroscope_cache()
	return _gyroscope_instance_ids.duplicate()

func get_gyroscope_count() -> int:
	_ensure_gyroscope_cache()
	return _gyroscope_instance_ids.size()

func get_total_gyro_torque_nm() -> float:
	_ensure_gyroscope_cache()
	return _total_gyro_torque_nm

func set_manual_rotation_input(actor: Node, input_local: Vector3) -> bool:
	if actor == null or not can_receive_manual_control(actor):
		return false
	_manual_rotation_input_local = Vector3(
		clampf(input_local.x, -1.0, 1.0),
		clampf(input_local.y, -1.0, 1.0),
		clampf(input_local.z, -1.0, 1.0)
	)
	if _manual_rotation_input_local.length_squared() > 0.0001 and is_dynamic_simulation_enabled():
		wake_grid()
	return true

func get_manual_rotation_input_local() -> Vector3:
	return _manual_rotation_input_local

func clear_manual_rotation_input(actor: Node = null) -> bool:
	if actor != null and has_active_pilot() and get_active_pilot() != actor:
		return false
	_manual_rotation_input_local = Vector3.ZERO
	return true

func get_active_manual_torque_local_nm() -> Vector3:
	_ensure_gyroscope_cache()
	var powered_torque_nm := 0.0
	for instance_id in _gyroscope_instance_ids:
		var instance := get_block_by_instance_id(instance_id)
		if instance == null:
			continue
		var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
		if definition == null:
			continue
		powered_torque_nm += maxf(float(definition.get("gyro_torque_nm")), 0.0) * _get_effective_block_power_satisfaction_ratio(instance_id)
	return _manual_rotation_input_local * powered_torque_nm

func get_rotation_control_state() -> Dictionary:
	_ensure_gyroscope_cache()
	return {
		"gyroscope_count": _gyroscope_instance_ids.size(),
		"total_rated_torque_nm": _total_gyro_torque_nm,
		"manual_rotation_input_local": _manual_rotation_input_local,
		"active_torque_local_nm": get_active_manual_torque_local_nm(),
		"power_satisfaction_ratio": get_power_satisfaction_ratio(),
	}

func _mark_gyroscope_cache_dirty(emit_signal_after_rebuild: bool = true) -> void:
	_gyroscope_cache_dirty = true
	if emit_signal_after_rebuild and is_inside_tree():
		call_deferred("_emit_gyroscope_after_cache_refresh")

func _emit_gyroscope_after_cache_refresh() -> void:
	if not is_inside_tree():
		return
	_ensure_gyroscope_cache()
	gyroscope_changed.emit(_gyroscope_instance_ids.size(), _total_gyro_torque_nm)

func _ensure_gyroscope_cache() -> void:
	if not _gyroscope_cache_dirty:
		return
	_gyroscope_cache_dirty = false
	_gyroscope_instance_ids.clear()
	_total_gyro_torque_nm = 0.0
	for instance in get_all_blocks():
		var instance_id := int(instance.get("instance_id"))
		var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
		if definition == null or StringName(definition.get("functional_type")) != &"gyroscope" or not is_block_enabled(instance_id):
			continue
		var rated_torque := float(definition.get("gyro_torque_nm"))
		if rated_torque <= 0.0 or not is_finite(rated_torque):
			continue
		_gyroscope_instance_ids.append(instance_id)
		_total_gyro_torque_nm += rated_torque
	_gyroscope_instance_ids.sort()

func get_power_producer_instance_ids() -> Array[int]:
	_ensure_power_cache()
	return _power_producer_instance_ids.duplicate()

func get_power_consumer_instance_ids() -> Array[int]:
	_ensure_power_cache()
	return _power_consumer_instance_ids.duplicate()

func get_total_power_generation_kw() -> float:
	_ensure_power_cache()
	return _total_power_generation_kw

func get_total_rated_power_demand_kw() -> float:
	_ensure_power_cache()
	return _total_rated_power_demand_kw

func get_block_active_power_demand_kw(instance_id: int) -> float:
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return 0.0
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	if definition == null or not is_block_enabled(instance_id):
		return 0.0
	var rated_kw := float(definition.get("power_use_kw"))
	if rated_kw <= 0.0 or not is_finite(rated_kw):
		return 0.0
	match StringName(definition.get("functional_type")):
		&"thruster":
			var direction := get_thruster_direction_local(instance_id)
			if not _is_cardinal_direction(direction):
				return 0.0
			return rated_kw * clampf(Vector3(direction).dot(_manual_translation_input_local), 0.0, 1.0)
		&"gyroscope":
			var gyro_strength := maxf(absf(_manual_rotation_input_local.x), maxf(absf(_manual_rotation_input_local.y), absf(_manual_rotation_input_local.z)))
			return rated_kw * clampf(gyro_strength, 0.0, 1.0)
		&"control_seat":
			return rated_kw if has_active_pilot() and _active_control_seat_instance_id == instance_id else 0.0
		_:
			return rated_kw

func get_active_power_demand_kw() -> float:
	_ensure_power_cache()
	var demand_kw := 0.0
	for instance_id in _power_consumer_instance_ids:
		demand_kw += get_block_active_power_demand_kw(instance_id)
	return demand_kw

func get_power_satisfaction_ratio() -> float:
	if not power_network_enabled:
		return 1.0
	return float(_calculate_power_allocation(0.0).get("satisfaction_ratio", 1.0))

func get_block_power_priority(instance_id: int) -> int:
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return 2
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	if definition == null:
		return 2
	var override := get_block_power_priority_override(instance_id)
	if override >= 0:
		return clampi(override, 0, 3)
	return clampi(int(definition.get("power_priority")), 0, 3)

func get_block_power_priority_name(instance_id: int) -> StringName:
	match get_block_power_priority(instance_id):
		0: return &"critical"
		1: return &"high"
		2: return &"normal"
		3: return &"low"
	return &"normal"

func get_block_allocated_power_kw(instance_id: int) -> float:
	if not power_network_enabled:
		return get_block_active_power_demand_kw(instance_id)
	var allocation := _physics_power_allocation_override if not _physics_power_allocation_override.is_empty() else _calculate_power_allocation(0.0)
	var allocations := allocation.get("allocations_kw", {}) as Dictionary
	return maxf(float(allocations.get(instance_id, 0.0)), 0.0)

func get_block_power_satisfaction_ratio(instance_id: int) -> float:
	if not power_network_enabled:
		return 1.0
	var demand_kw := get_block_active_power_demand_kw(instance_id)
	if demand_kw <= 0.0001:
		return 1.0
	var allocation := _physics_power_allocation_override if not _physics_power_allocation_override.is_empty() else _calculate_power_allocation(0.0)
	var ratios := allocation.get("ratios", {}) as Dictionary
	return clampf(float(ratios.get(instance_id, 0.0)), 0.0, 1.0)

func _get_effective_power_satisfaction_ratio() -> float:
	if _physics_power_satisfaction_override >= 0.0:
		return _physics_power_satisfaction_override
	return get_power_satisfaction_ratio()

func _get_effective_block_power_satisfaction_ratio(instance_id: int) -> float:
	if not power_network_enabled:
		return 1.0
	if not _physics_power_allocation_override.is_empty():
		var ratios := _physics_power_allocation_override.get("ratios", {}) as Dictionary
		if ratios.has(instance_id):
			return clampf(float(ratios[instance_id]), 0.0, 1.0)
	return get_block_power_satisfaction_ratio(instance_id)

func _calculate_power_satisfaction_ratio(delta: float = 0.0) -> float:
	return float(_calculate_power_allocation(delta).get("satisfaction_ratio", 1.0))

func _calculate_power_allocation(delta: float = 0.0) -> Dictionary:
	_ensure_power_cache()
	var active_demand_kw := get_active_power_demand_kw()
	var battery_discharge_kw := _get_total_available_battery_discharge_kw(delta)
	var available_supply_kw := maxf(_total_power_generation_kw, 0.0) + battery_discharge_kw
	var usable_supply_kw := minf(active_demand_kw, available_supply_kw)
	var allocations_kw: Dictionary = {}
	var ratios: Dictionary = {}
	var tier_states: Array[Dictionary] = []
	for priority in 4:
		tier_states.append({
			"priority": priority,
			"name": _power_priority_name(priority),
			"consumer_count": 0,
			"demand_kw": 0.0,
			"allocated_kw": 0.0,
			"satisfaction_ratio": 1.0,
		})
	if active_demand_kw <= 0.0001:
		return {
			"active_demand_kw": 0.0,
			"available_supply_kw": available_supply_kw,
			"allocated_kw": 0.0,
			"shed_kw": 0.0,
			"satisfaction_ratio": 1.0,
			"load_shedding_active": false,
			"allocations_kw": allocations_kw,
			"ratios": ratios,
			"tiers": tier_states,
		}

	if not priority_load_shedding_enabled:
		var shared_ratio := clampf(usable_supply_kw / active_demand_kw, 0.0, 1.0)
		for instance_id in _power_consumer_instance_ids:
			var demand_kw := get_block_active_power_demand_kw(instance_id)
			if demand_kw <= 0.0001:
				continue
			var allocated_kw := demand_kw * shared_ratio
			allocations_kw[instance_id] = allocated_kw
			ratios[instance_id] = shared_ratio
			var priority := get_block_power_priority(instance_id)
			var tier := tier_states[priority]
			tier["consumer_count"] = int(tier["consumer_count"]) + 1
			tier["demand_kw"] = float(tier["demand_kw"]) + demand_kw
			tier["allocated_kw"] = float(tier["allocated_kw"]) + allocated_kw
			tier["satisfaction_ratio"] = shared_ratio
			tier_states[priority] = tier
		return {
			"active_demand_kw": active_demand_kw,
			"available_supply_kw": available_supply_kw,
			"allocated_kw": usable_supply_kw,
			"shed_kw": maxf(active_demand_kw - usable_supply_kw, 0.0),
			"satisfaction_ratio": shared_ratio,
			"load_shedding_active": shared_ratio < 0.9999,
			"allocations_kw": allocations_kw,
			"ratios": ratios,
			"tiers": tier_states,
		}

	var remaining_kw := usable_supply_kw
	for priority in 4:
		var ids := _power_consumer_instance_ids_by_priority.get(priority, []) as Array
		var tier_demand_kw := 0.0
		var active_ids: Array[int] = []
		for raw_id in ids:
			var instance_id := int(raw_id)
			var demand_kw := get_block_active_power_demand_kw(instance_id)
			if demand_kw <= 0.0001:
				continue
			active_ids.append(instance_id)
			tier_demand_kw += demand_kw
		var tier_ratio := 1.0 if tier_demand_kw <= 0.0001 else clampf(remaining_kw / tier_demand_kw, 0.0, 1.0)
		var tier_allocated_kw := minf(tier_demand_kw, remaining_kw)
		for instance_id in active_ids:
			var demand_kw := get_block_active_power_demand_kw(instance_id)
			allocations_kw[instance_id] = demand_kw * tier_ratio
			ratios[instance_id] = tier_ratio
		var tier := tier_states[priority]
		tier["consumer_count"] = active_ids.size()
		tier["demand_kw"] = tier_demand_kw
		tier["allocated_kw"] = tier_allocated_kw
		tier["satisfaction_ratio"] = tier_ratio
		tier_states[priority] = tier
		remaining_kw = maxf(remaining_kw - tier_allocated_kw, 0.0)

	var total_allocated_kw := 0.0
	for raw_value in allocations_kw.values():
		total_allocated_kw += float(raw_value)
	var overall_ratio := clampf(total_allocated_kw / active_demand_kw, 0.0, 1.0)
	return {
		"active_demand_kw": active_demand_kw,
		"available_supply_kw": available_supply_kw,
		"allocated_kw": total_allocated_kw,
		"shed_kw": maxf(active_demand_kw - total_allocated_kw, 0.0),
		"satisfaction_ratio": overall_ratio,
		"load_shedding_active": total_allocated_kw < active_demand_kw - 0.0001,
		"allocations_kw": allocations_kw,
		"ratios": ratios,
		"tiers": tier_states,
	}

func _power_priority_name(priority: int) -> StringName:
	match priority:
		0: return &"critical"
		1: return &"high"
		2: return &"normal"
		3: return &"low"
	return &"normal"

func has_sufficient_power() -> bool:
	return get_power_satisfaction_ratio() >= 0.9999

func get_power_surplus_kw() -> float:
	return get_total_power_generation_kw() - get_active_power_demand_kw()

func get_battery_instance_ids() -> Array[int]:
	_ensure_power_cache()
	return _battery_instance_ids.duplicate()

func get_battery_count() -> int:
	_ensure_power_cache()
	return _battery_instance_ids.size()

func get_battery_stored_energy_kwh(instance_id: int) -> float:
	_ensure_power_cache()
	return maxf(float(_battery_stored_energy_kwh.get(instance_id, 0.0)), 0.0)

func set_battery_stored_energy_kwh(instance_id: int, stored_energy_kwh: float) -> bool:
	_ensure_power_cache()
	if instance_id not in _battery_instance_ids or not is_finite(stored_energy_kwh):
		return false
	var definition := _get_battery_definition(instance_id)
	if definition == null:
		return false
	var capacity := maxf(float(definition.get("battery_capacity_kwh")), 0.0)
	_battery_stored_energy_kwh[instance_id] = clampf(stored_energy_kwh, 0.0, capacity)
	_emit_battery_storage_changed(true)
	return true

func get_total_battery_capacity_kwh() -> float:
	_ensure_power_cache()
	return _total_battery_capacity_kwh

func get_total_battery_stored_energy_kwh() -> float:
	_ensure_power_cache()
	var total := 0.0
	for instance_id in _battery_instance_ids:
		total += maxf(float(_battery_stored_energy_kwh.get(instance_id, 0.0)), 0.0)
	return total

func get_total_battery_max_charge_kw() -> float:
	_ensure_power_cache()
	return _total_battery_max_charge_kw

func get_total_battery_max_discharge_kw() -> float:
	_ensure_power_cache()
	return _total_battery_max_discharge_kw

func get_battery_state_of_charge() -> float:
	var capacity := get_total_battery_capacity_kwh()
	if capacity <= BATTERY_ENERGY_EPSILON_KWH:
		return 0.0
	return clampf(get_total_battery_stored_energy_kwh() / capacity, 0.0, 1.0)

func get_battery_state(instance_id: int) -> Dictionary:
	_ensure_power_cache()
	if instance_id not in _battery_instance_ids:
		return {"valid": false, "instance_id": instance_id}
	var definition := _get_battery_definition(instance_id)
	if definition == null:
		return {"valid": false, "instance_id": instance_id}
	var capacity := float(definition.get("battery_capacity_kwh"))
	var stored := get_battery_stored_energy_kwh(instance_id)
	var charge_kw := maxf(float(_battery_charge_rate_kw_by_instance.get(instance_id, 0.0)), 0.0)
	var discharge_kw := maxf(float(_battery_discharge_rate_kw_by_instance.get(instance_id, 0.0)), 0.0)
	var status: StringName = &"idle"
	if charge_kw > 0.0001:
		status = &"charging"
	elif discharge_kw > 0.0001:
		status = &"discharging"
	elif stored <= BATTERY_ENERGY_EPSILON_KWH:
		status = &"empty"
	elif stored >= capacity - BATTERY_ENERGY_EPSILON_KWH:
		status = &"full"
	return {
		"valid": true,
		"enabled": true,
		"instance_id": instance_id,
		"stored_energy_kwh": stored,
		"capacity_kwh": capacity,
		"state_of_charge": clampf(stored / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0,
		"max_charge_kw": float(definition.get("battery_max_charge_kw")),
		"max_discharge_kw": float(definition.get("battery_max_discharge_kw")),
		"charge_kw": charge_kw,
		"discharge_kw": discharge_kw,
		"status": status,
	}

func get_battery_storage_state() -> Dictionary:
	_ensure_power_cache()
	var stored := get_total_battery_stored_energy_kwh()
	var capacity := _total_battery_capacity_kwh
	return {
		"battery_count": _battery_instance_ids.size(),
		"stored_energy_kwh": stored,
		"capacity_kwh": capacity,
		"state_of_charge": clampf(stored / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0,
		"max_charge_kw": _total_battery_max_charge_kw,
		"max_discharge_kw": _total_battery_max_discharge_kw,
		"charge_kw": _last_battery_charge_kw,
		"discharge_kw": _last_battery_discharge_kw,
		"estimated_runtime_seconds": get_estimated_battery_runtime_seconds(),
	}

func get_estimated_battery_runtime_seconds() -> float:
	_ensure_power_cache()
	var deficit_kw := maxf(get_active_power_demand_kw() - _total_power_generation_kw, 0.0)
	if deficit_kw <= 0.0001:
		return -1.0
	var discharge_kw := minf(deficit_kw, _get_total_available_battery_discharge_kw(0.0))
	if discharge_kw <= 0.0001:
		return 0.0
	return get_total_battery_stored_energy_kwh() / discharge_kw * 3600.0

func _get_total_available_battery_discharge_kw(delta: float = 0.0) -> float:
	_ensure_power_cache()
	var total := 0.0
	for instance_id in _battery_instance_ids:
		var definition := _get_battery_definition(instance_id)
		if definition == null:
			continue
		var stored := get_battery_stored_energy_kwh(instance_id)
		if stored <= BATTERY_ENERGY_EPSILON_KWH:
			continue
		var available_kw := maxf(float(definition.get("battery_max_discharge_kw")), 0.0)
		if delta > 0.0:
			available_kw = minf(available_kw, stored * 3600.0 / delta)
		total += available_kw
	return total

func _advance_battery_storage(delta: float) -> void:
	_reset_battery_flow_rates()
	if delta <= 0.0:
		return
	_ensure_power_cache()
	if _battery_instance_ids.is_empty():
		return
	var demand_kw := get_active_power_demand_kw()
	var generation_kw := _total_power_generation_kw
	var changed := false
	if demand_kw > generation_kw + 0.0001:
		var remaining_deficit_kw := demand_kw - generation_kw
		for instance_id in _battery_instance_ids:
			if remaining_deficit_kw <= 0.0001:
				break
			var definition := _get_battery_definition(instance_id)
			if definition == null:
				continue
			var stored := get_battery_stored_energy_kwh(instance_id)
			if stored <= BATTERY_ENERGY_EPSILON_KWH:
				continue
			var rate_limit := maxf(float(definition.get("battery_max_discharge_kw")), 0.0)
			var energy_limit_kw := stored * 3600.0 / delta
			var discharge_kw := minf(remaining_deficit_kw, minf(rate_limit, energy_limit_kw))
			if discharge_kw <= 0.0001:
				continue
			_battery_stored_energy_kwh[instance_id] = maxf(stored - discharge_kw * delta / 3600.0, 0.0)
			_battery_discharge_rate_kw_by_instance[instance_id] = discharge_kw
			_last_battery_discharge_kw += discharge_kw
			remaining_deficit_kw -= discharge_kw
			changed = true
	elif generation_kw > demand_kw + 0.0001:
		var remaining_surplus_kw := generation_kw - demand_kw
		for instance_id in _battery_instance_ids:
			if remaining_surplus_kw <= 0.0001:
				break
			var definition := _get_battery_definition(instance_id)
			if definition == null:
				continue
			var capacity := maxf(float(definition.get("battery_capacity_kwh")), 0.0)
			var stored := get_battery_stored_energy_kwh(instance_id)
			var room := maxf(capacity - stored, 0.0)
			if room <= BATTERY_ENERGY_EPSILON_KWH:
				continue
			var rate_limit := maxf(float(definition.get("battery_max_charge_kw")), 0.0)
			var room_limit_kw := room * 3600.0 / delta
			var charge_kw := minf(remaining_surplus_kw, minf(rate_limit, room_limit_kw))
			if charge_kw <= 0.0001:
				continue
			_battery_stored_energy_kwh[instance_id] = minf(stored + charge_kw * delta / 3600.0, capacity)
			_battery_charge_rate_kw_by_instance[instance_id] = charge_kw
			_last_battery_charge_kw += charge_kw
			remaining_surplus_kw -= charge_kw
			changed = true
	if changed:
		_emit_battery_storage_changed(false)

func _reset_battery_flow_rates() -> void:
	_battery_charge_rate_kw_by_instance.clear()
	_battery_discharge_rate_kw_by_instance.clear()
	_last_battery_charge_kw = 0.0
	_last_battery_discharge_kw = 0.0

func _emit_battery_storage_changed(force_emit: bool) -> void:
	var stored := get_total_battery_stored_energy_kwh()
	if not force_emit and _last_emitted_battery_stored_kwh >= 0.0 and absf(stored - _last_emitted_battery_stored_kwh) < BATTERY_SIGNAL_STEP_KWH:
		return
	_last_emitted_battery_stored_kwh = stored
	battery_storage_changed.emit(stored, _total_battery_capacity_kwh, get_battery_state_of_charge())

func _get_battery_definition(instance_id: int) -> Resource:
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return null
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	if definition == null or StringName(definition.get("functional_type")) != &"battery":
		return null
	return definition

func _initial_battery_energy_kwh(definition: Resource) -> float:
	if definition == null:
		return 0.0
	var capacity := maxf(float(definition.get("battery_capacity_kwh")), 0.0)
	var fraction := clampf(float(definition.get("battery_initial_charge_fraction")), 0.0, 1.0)
	return capacity * fraction

func get_block_power_state(instance_id: int) -> Dictionary:
	_ensure_power_cache()
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return {"valid": false, "status": &"missing", "powered": false}
	var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
	if definition == null:
		return {"valid": false, "status": &"unknown", "powered": false}
	if not is_block_enabled(instance_id):
		return {
			"valid": true, "instance_id": instance_id, "block_id": StringName(instance.get("block_id")),
			"status": &"disabled", "powered": false, "enabled": false,
			"generation_kw": 0.0, "rated_demand_kw": maxf(float(definition.get("power_use_kw")), 0.0),
			"active_demand_kw": 0.0, "allocated_kw": 0.0, "satisfaction_ratio": 0.0,
			"priority": get_block_power_priority(instance_id), "priority_name": get_block_power_priority_name(instance_id),
		}
	if StringName(definition.get("functional_type")) == &"battery":
		var battery_state := get_battery_state(instance_id)
		battery_state["powered"] = float(battery_state.get("stored_energy_kwh", 0.0)) > BATTERY_ENERGY_EPSILON_KWH
		battery_state["block_id"] = StringName(instance.get("block_id"))
		battery_state["priority"] = get_block_power_priority(instance_id)
		battery_state["priority_name"] = get_block_power_priority_name(instance_id)
		return battery_state
	var generation_kw := maxf(float(definition.get("power_production_kw")), 0.0)
	var rated_demand_kw := maxf(float(definition.get("power_use_kw")), 0.0)
	var active_demand_kw := get_block_active_power_demand_kw(instance_id)
	var allocated_kw := get_block_allocated_power_kw(instance_id)
	var satisfaction := get_block_power_satisfaction_ratio(instance_id)
	var powered := true
	var status: StringName = &"passive"
	if generation_kw > 0.0:
		status = &"producer"
	elif rated_demand_kw > 0.0:
		if not power_network_enabled:
			status = &"bypass"
		elif active_demand_kw <= 0.0001:
			var potential_supply := _total_power_generation_kw + _get_total_available_battery_discharge_kw(0.0)
			powered = potential_supply > 0.0001
			status = &"idle" if powered else &"unpowered"
		elif satisfaction >= 0.9999:
			status = &"powered"
		elif satisfaction > 0.0001:
			powered = false
			status = &"brownout"
		else:
			powered = false
			var potential_supply := _total_power_generation_kw + _get_total_available_battery_discharge_kw(0.0)
			status = &"load_shed" if potential_supply > 0.0001 else &"unpowered"
	return {
		"valid": true,
		"enabled": true,
		"instance_id": instance_id,
		"block_id": StringName(instance.get("block_id")),
		"status": status,
		"powered": powered,
		"generation_kw": generation_kw,
		"rated_demand_kw": rated_demand_kw,
		"active_demand_kw": active_demand_kw,
		"allocated_kw": allocated_kw,
		"satisfaction_ratio": satisfaction,
		"priority": get_block_power_priority(instance_id),
		"priority_name": get_block_power_priority_name(instance_id),
	}

func get_power_network_state() -> Dictionary:
	_ensure_power_cache()
	var allocation := _calculate_power_allocation(0.0) if power_network_enabled else {
		"active_demand_kw": get_active_power_demand_kw(),
		"available_supply_kw": get_active_power_demand_kw(),
		"allocated_kw": get_active_power_demand_kw(),
		"shed_kw": 0.0,
		"satisfaction_ratio": 1.0,
		"load_shedding_active": false,
		"tiers": [],
	}
	var active_demand_kw := float(allocation.get("active_demand_kw", 0.0))
	var satisfaction := float(allocation.get("satisfaction_ratio", 1.0))
	return {
		"enabled": power_network_enabled,
		"priority_load_shedding_enabled": priority_load_shedding_enabled,
		"producer_count": _power_producer_instance_ids.size(),
		"consumer_count": _power_consumer_instance_ids.size(),
		"generation_kw": _total_power_generation_kw,
		"rated_demand_kw": _total_rated_power_demand_kw,
		"active_demand_kw": active_demand_kw,
		"available_supply_kw": float(allocation.get("available_supply_kw", 0.0)),
		"allocated_kw": float(allocation.get("allocated_kw", active_demand_kw)),
		"shed_kw": float(allocation.get("shed_kw", 0.0)),
		"surplus_kw": _total_power_generation_kw - active_demand_kw,
		"load_shedding_active": bool(allocation.get("load_shedding_active", false)),
		"priority_tiers": allocation.get("tiers", []),
		"battery_count": _battery_instance_ids.size(),
		"battery_stored_energy_kwh": get_total_battery_stored_energy_kwh(),
		"battery_capacity_kwh": _total_battery_capacity_kwh,
		"battery_state_of_charge": get_battery_state_of_charge(),
		"battery_max_charge_kw": _total_battery_max_charge_kw,
		"battery_max_discharge_kw": _total_battery_max_discharge_kw,
		"battery_charge_kw": _last_battery_charge_kw,
		"battery_discharge_kw": _last_battery_discharge_kw,
		"available_battery_discharge_kw": _get_total_available_battery_discharge_kw(0.0),
		"satisfaction_ratio": satisfaction,
		"sufficient": satisfaction >= 0.9999,
	}

func _mark_power_cache_dirty(emit_signal_after_rebuild: bool = true) -> void:
	_power_cache_dirty = true
	if emit_signal_after_rebuild and is_inside_tree():
		call_deferred("_emit_power_network_after_cache_refresh")

func _emit_power_network_after_cache_refresh() -> void:
	if not is_inside_tree():
		return
	_ensure_power_cache()
	power_network_changed.emit(_total_power_generation_kw, _total_rated_power_demand_kw, get_active_power_demand_kw(), get_power_satisfaction_ratio())

func _ensure_power_cache() -> void:
	if not _power_cache_dirty:
		return
	_power_cache_dirty = false
	_power_producer_instance_ids.clear()
	_power_consumer_instance_ids.clear()
	_power_consumer_instance_ids_by_priority.clear()
	for priority in 4:
		_power_consumer_instance_ids_by_priority[priority] = []
	_battery_instance_ids.clear()
	_total_power_generation_kw = 0.0
	_total_rated_power_demand_kw = 0.0
	_total_battery_capacity_kwh = 0.0
	_total_battery_max_charge_kw = 0.0
	_total_battery_max_discharge_kw = 0.0
	var valid_battery_ids: Dictionary = {}
	for instance in get_all_blocks():
		var instance_id := int(instance.get("instance_id"))
		var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
		if definition == null:
			continue
		var functional_type := StringName(definition.get("functional_type"))
		if functional_type == &"battery":
			valid_battery_ids[instance_id] = true
			var capacity := maxf(float(definition.get("battery_capacity_kwh")), 0.0)
			if not _battery_stored_energy_kwh.has(instance_id):
				_battery_stored_energy_kwh[instance_id] = _initial_battery_energy_kwh(definition)
			else:
				_battery_stored_energy_kwh[instance_id] = clampf(float(_battery_stored_energy_kwh[instance_id]), 0.0, capacity)
			if is_block_enabled(instance_id):
				_battery_instance_ids.append(instance_id)
				_total_battery_capacity_kwh += capacity
				_total_battery_max_charge_kw += maxf(float(definition.get("battery_max_charge_kw")), 0.0)
				_total_battery_max_discharge_kw += maxf(float(definition.get("battery_max_discharge_kw")), 0.0)
			continue
		if not is_block_enabled(instance_id):
			continue
		var generation_kw := float(definition.get("power_production_kw"))
		var demand_kw := float(definition.get("power_use_kw"))
		if generation_kw > 0.0 and is_finite(generation_kw):
			_power_producer_instance_ids.append(instance_id)
			_total_power_generation_kw += generation_kw
		if demand_kw > 0.0 and is_finite(demand_kw):
			_power_consumer_instance_ids.append(instance_id)
			var priority := get_block_power_priority(instance_id)
			var priority_ids := _power_consumer_instance_ids_by_priority.get(priority, []) as Array
			priority_ids.append(instance_id)
			_power_consumer_instance_ids_by_priority[priority] = priority_ids
			_total_rated_power_demand_kw += demand_kw
	for raw_id in _battery_stored_energy_kwh.keys():
		var instance_id := int(raw_id)
		if not valid_battery_ids.has(instance_id):
			_battery_stored_energy_kwh.erase(raw_id)
			_battery_charge_rate_kw_by_instance.erase(raw_id)
			_battery_discharge_rate_kw_by_instance.erase(raw_id)
	_power_producer_instance_ids.sort()
	_power_consumer_instance_ids.sort()
	for priority in 4:
		var priority_ids := _power_consumer_instance_ids_by_priority.get(priority, []) as Array
		priority_ids.sort()
		_power_consumer_instance_ids_by_priority[priority] = priority_ids
	_battery_instance_ids.sort()

func get_motion_state() -> Dictionary:
	return {
		"dynamic": is_dynamic_simulation_enabled(),
		"sleeping": sleeping,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity,
		"mass_kg": _calculated_mass_kg,
		"physics_mass_kg": mass,
		"gravity_scale": gravity_scale,
	}

func stop_motion() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func sleep_grid() -> bool:
	if not is_dynamic_simulation_enabled() or not can_sleep:
		return false
	stop_motion()
	sleeping = true
	return true

func wake_grid() -> bool:
	if not is_dynamic_simulation_enabled():
		return false
	sleeping = false
	return true

func _apply_simulation_settings(dynamic_enabled: bool, wake_body: bool) -> void:
	var should_be_dynamic := dynamic_enabled and can_be_dynamic()
	_apply_physics_mass()
	linear_damp = maxf(dynamic_linear_damp, 0.0)
	angular_damp = maxf(dynamic_angular_damp, 0.0)
	can_sleep = allow_sleeping
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = not should_be_dynamic
	gravity_scale = maxf(dynamic_gravity_scale, 0.0) if should_be_dynamic else 0.0
	collision_layer = GRID_COLLISION_LAYER
	collision_mask = WORLD_COLLISION_MASK if should_be_dynamic else 0
	if should_be_dynamic:
		if wake_body:
			sleeping = false
	else:
		_manual_translation_input_local = Vector3.ZERO
		_manual_rotation_input_local = Vector3.ZERO
		stop_motion()
		sleeping = false

func can_place_block(block_definition: Resource, anchor_cell: Vector3i, orientation_index: int = 0) -> bool:
	if not _is_block_definition_compatible(block_definition):
		return false
	if not BLOCK_ORIENTATION.is_valid_index(orientation_index):
		return false
	var dimensions := Vector3i(block_definition.get("dimensions_cells"))
	var oriented_dimensions := BLOCK_ORIENTATION.get_oriented_dimensions(dimensions, orientation_index)
	for cell in _cells_for_extent(anchor_cell, oriented_dimensions):
		if _cells.has(cell):
			return false
	return true

func place_block(block_definition: Resource, anchor_cell: Vector3i, orientation_index: int = 0) -> Resource:
	if not can_place_block(block_definition, anchor_cell, orientation_index):
		return null
	var block_id := StringName(block_definition.get("id"))
	var dimensions := Vector3i(block_definition.get("dimensions_cells"))
	var instance: Resource = BLOCK_INSTANCE_SCRIPT.new()
	instance.call("configure", _next_instance_id, block_id, anchor_cell, dimensions, orientation_index)
	_next_instance_id += 1
	_instances[int(instance.get("instance_id"))] = instance
	for cell in instance.call("get_occupied_cells"):
		_cells[cell] = instance
	var placement_mass := _resolve_definition_mass(block_definition)
	if not BlockDB.call("has_block", block_id):
		_runtime_block_masses[block_id] = placement_mass
	_set_calculated_mass(_calculated_mass_kg + placement_mass)
	var canonical_definition := BlockDB.call("get_block", block_id) as Resource
	if canonical_definition != null and StringName(canonical_definition.get("functional_type")) == &"battery":
		_battery_stored_energy_kwh[int(instance.get("instance_id"))] = _initial_battery_energy_kwh(canonical_definition)
	_mark_thruster_cache_dirty()
	_mark_gyroscope_cache_dirty()
	_mark_power_cache_dirty()
	block_added.emit(int(instance.get("instance_id")), block_id)
	grid_changed.emit(get_block_count(), get_occupied_cell_count())
	return instance

func remove_block_at(cell: Vector3i) -> Resource:
	var instance := get_block_at(cell)
	if instance == null:
		return null
	return remove_block_by_instance_id(int(instance.get("instance_id")))

func remove_block_by_instance_id(instance_id: int) -> Resource:
	var instance := get_block_by_instance_id(instance_id)
	if instance == null:
		return null
	if instance_id == _active_control_seat_instance_id:
		_invalidate_active_pilot("control seat removed")
	for cell in instance.call("get_occupied_cells"):
		if _cells.get(cell) == instance:
			_cells.erase(cell)
	_instances.erase(instance_id)
	_battery_stored_energy_kwh.erase(instance_id)
	_battery_charge_rate_kw_by_instance.erase(instance_id)
	_battery_discharge_rate_kw_by_instance.erase(instance_id)
	_purge_block_configuration(instance_id)
	var block_id := StringName(instance.get("block_id"))
	var removed_mass := _resolve_block_id_mass(block_id)
	if removed_mass > 0.0:
		_set_calculated_mass(maxf(_calculated_mass_kg - removed_mass, 0.0))
	else:
		recalculate_mass_from_blocks()
	_mark_thruster_cache_dirty()
	_mark_gyroscope_cache_dirty()
	_mark_power_cache_dirty()
	block_removed.emit(instance_id, block_id)
	grid_changed.emit(get_block_count(), get_occupied_cell_count())
	return instance

func clear_grid() -> void:
	if has_active_pilot():
		_invalidate_active_pilot("grid cleared")
	if _instances.is_empty() and _cells.is_empty():
		_block_enabled_state.clear()
		_block_custom_names.clear()
		_block_power_priority_overrides.clear()
		if not _block_groups.is_empty():
			_block_groups.clear()
			block_groups_changed.emit()
		if not is_zero_approx(_calculated_mass_kg):
			_set_calculated_mass(0.0)
		return
	_cells.clear()
	_instances.clear()
	_block_enabled_state.clear()
	_block_custom_names.clear()
	_block_power_priority_overrides.clear()
	_block_groups.clear()
	_battery_stored_energy_kwh.clear()
	_reset_battery_flow_rates()
	_set_calculated_mass(0.0)
	_mark_thruster_cache_dirty()
	_mark_gyroscope_cache_dirty()
	_mark_power_cache_dirty()
	grid_changed.emit(0, 0)

func get_block_at(cell: Vector3i) -> Resource:
	return _cells.get(cell) as Resource

func get_block_by_instance_id(instance_id: int) -> Resource:
	return _instances.get(instance_id) as Resource

func has_occupied_cell(cell: Vector3i) -> bool:
	return _cells.has(cell)

func get_block_count() -> int:
	return _instances.size()

func get_occupied_cell_count() -> int:
	return _cells.size()

func get_all_blocks() -> Array[Resource]:
	var ids: Array[int] = []
	for raw_id in _instances.keys():
		ids.append(int(raw_id))
	ids.sort()
	var result: Array[Resource] = []
	for instance_id in ids:
		var instance := get_block_by_instance_id(instance_id)
		if instance != null:
			result.append(instance)
	return result

func get_save_state() -> Dictionary:
	_ensure_power_cache()
	var block_states: Array[Dictionary] = []
	for instance in get_all_blocks():
		block_states.append(instance.call("get_save_state") as Dictionary)
	var battery_states: Array[Dictionary] = []
	for instance in get_all_blocks():
		var instance_id := int(instance.get("instance_id"))
		var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
		if definition != null and StringName(definition.get("functional_type")) == &"battery":
			battery_states.append({
				"instance_id": instance_id,
				"stored_energy_kwh": maxf(float(_battery_stored_energy_kwh.get(instance_id, _initial_battery_energy_kwh(definition))), 0.0),
			})
	var block_configurations: Array[Dictionary] = []
	for instance in get_all_blocks():
		var instance_id := int(instance.get("instance_id"))
		block_configurations.append({
			"instance_id": instance_id,
			"enabled": is_block_enabled(instance_id),
			"custom_name": get_block_custom_name(instance_id),
			"power_priority_override": get_block_power_priority_override(instance_id),
		})
	var group_states: Array[Dictionary] = []
	for group_name in get_block_group_names():
		group_states.append({"name": group_name, "instance_ids": get_group_instance_ids(group_name)})
	return {
		"schema": GRID_SAVE_SCHEMA,
		"version": GRID_SAVE_VERSION,
		"grid_profile_id": String(get_grid_type()),
		"next_instance_id": _next_instance_id,
		"blocks": block_states,
		"battery_states": battery_states,
		"block_configurations": block_configurations,
		"block_groups": group_states,
	}

func load_save_state(state: Dictionary) -> bool:
	var prepared := _prepare_load_state(state)
	if not bool(prepared.get("ok", false)):
		DebugLog.warn("BlockGrid", "Rejected grid save state: %s" % String(prepared.get("error", "unknown validation error")))
		return false

	if has_active_pilot():
		_invalidate_active_pilot("grid reloaded")
	grid_profile = prepared["profile"] as Resource
	_apply_simulation_settings(false, false)
	_instances = prepared["instances"] as Dictionary
	_cells = prepared["cells"] as Dictionary
	_next_instance_id = int(prepared["next_instance_id"])
	_battery_stored_energy_kwh = (prepared["battery_states"] as Dictionary).duplicate()
	_block_enabled_state = (prepared["enabled_states"] as Dictionary).duplicate()
	_block_custom_names = (prepared["custom_names"] as Dictionary).duplicate()
	_block_power_priority_overrides = (prepared["priority_overrides"] as Dictionary).duplicate()
	_block_groups = (prepared["block_groups"] as Dictionary).duplicate(true)
	_reset_battery_flow_rates()
	_set_calculated_mass(float(prepared["calculated_mass_kg"]))
	_mark_thruster_cache_dirty()
	_mark_gyroscope_cache_dirty()
	_mark_power_cache_dirty()
	grid_reloaded.emit(get_block_count(), get_occupied_cell_count())
	grid_changed.emit(get_block_count(), get_occupied_cell_count())
	return true

func get_neighbor_cells(cell: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for direction in ORTHOGONAL_DIRECTIONS:
		result.append(cell + direction)
	return result

func get_occupied_neighbor_blocks(cell: Vector3i) -> Array[Resource]:
	var result: Array[Resource] = []
	var seen_ids: Dictionary = {}
	for neighbor_cell in get_neighbor_cells(cell):
		var instance := get_block_at(neighbor_cell)
		if instance == null:
			continue
		var instance_id := int(instance.get("instance_id"))
		if seen_ids.has(instance_id):
			continue
		seen_ids[instance_id] = true
		result.append(instance)
	return result

func grid_to_local(cell: Vector3i) -> Vector3:
	var cell_size := get_cell_size_m()
	return Vector3(cell.x, cell.y, cell.z) * cell_size

func local_to_grid(local_position: Vector3) -> Vector3i:
	var cell_size := get_cell_size_m()
	if cell_size <= 0.0:
		return Vector3i.ZERO
	return Vector3i(
		roundi(local_position.x / cell_size),
		roundi(local_position.y / cell_size),
		roundi(local_position.z / cell_size)
	)

func grid_to_world(cell: Vector3i) -> Vector3:
	return to_global(grid_to_local(cell))

func world_to_grid(world_position: Vector3) -> Vector3i:
	return local_to_grid(to_local(world_position))

func get_cell_bounds() -> Dictionary:
	if _cells.is_empty():
		return {"has_cells": false, "min": Vector3i.ZERO, "max": Vector3i.ZERO}
	var cells: Array = _cells.keys()
	var min_cell := Vector3i(cells[0])
	var max_cell := min_cell
	for raw_cell in cells:
		var cell := Vector3i(raw_cell)
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		min_cell.z = mini(min_cell.z, cell.z)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
		max_cell.z = maxi(max_cell.z, cell.z)
	return {"has_cells": true, "min": min_cell, "max": max_cell}

func get_local_aabb() -> AABB:
	var bounds := get_cell_bounds()
	if not bool(bounds["has_cells"]):
		return AABB()
	var cell_size := get_cell_size_m()
	var min_cell := Vector3i(bounds["min"])
	var max_cell := Vector3i(bounds["max"])
	var position := grid_to_local(min_cell) - Vector3.ONE * (cell_size * 0.5)
	var extent_cells := max_cell - min_cell + Vector3i.ONE
	return AABB(position, Vector3(extent_cells) * cell_size)

func get_integrity_errors() -> Array[String]:
	var errors: Array[String] = []
	if not _is_profile_valid(grid_profile):
		errors.append("Grid profile is missing or invalid.")
	var highest_instance_id := 0
	for raw_id in _instances.keys():
		var instance_id := int(raw_id)
		highest_instance_id = maxi(highest_instance_id, instance_id)
		var instance := _instances[raw_id] as Resource
		if instance == null:
			errors.append("Instance %d is null." % instance_id)
			continue
		if int(instance.get("instance_id")) != instance_id:
			errors.append("Instance registry key %d does not match instance state." % instance_id)
		if not bool(instance.call("is_valid_instance")):
			errors.append("Instance %d contains invalid state." % instance_id)
		for cell in instance.call("get_occupied_cells"):
			if _cells.get(cell) != instance:
				errors.append("Instance %d is missing occupied cell %s." % [instance_id, str(cell)])
	for raw_cell in _cells.keys():
		var cell := Vector3i(raw_cell)
		var instance := _cells[raw_cell] as Resource
		if instance == null:
			errors.append("Occupied cell %s maps to null." % str(cell))
			continue
		var instance_id := int(instance.get("instance_id"))
		if not _instances.has(instance_id) or _instances[instance_id] != instance:
			errors.append("Occupied cell %s maps to an unregistered instance." % str(cell))
		elif not bool(instance.call("contains_cell", cell)):
			errors.append("Occupied cell %s is outside instance %d extent." % [str(cell), instance_id])
	if _next_instance_id <= highest_instance_id:
		errors.append("Next instance ID %d is not greater than highest live instance ID %d." % [_next_instance_id, highest_instance_id])
	var mass_result := _calculate_mass_for_instances(_instances)
	if not bool(mass_result.get("ok", false)):
		errors.append("Mass calculation failed: %s" % String(mass_result.get("error", "unknown mass error")))
	else:
		var expected_mass := float(mass_result["mass_kg"])
		if absf(expected_mass - _calculated_mass_kg) > MASS_EPSILON_KG:
			errors.append("Cached mass %.4f kg does not match catalog mass %.4f kg." % [_calculated_mass_kg, expected_mass])
		var expected_physics_mass := maxf(expected_mass, MIN_RIGID_BODY_MASS_KG)
		if absf(mass - expected_physics_mass) > MASS_EPSILON_KG:
			errors.append("Rigid-body mass %.4f kg does not match expected physics mass %.4f kg." % [mass, expected_physics_mass])
	_ensure_thruster_cache()
	for instance_id in _thruster_instance_ids:
		if get_thruster_local_force_n(instance_id).length_squared() <= 0.0001:
			errors.append("Thruster instance %d has invalid force metadata or orientation." % instance_id)
	_ensure_power_cache()
	if _total_power_generation_kw < 0.0 or _total_rated_power_demand_kw < 0.0:
		errors.append("Power network cache contains negative generation or demand.")
	for instance_id in _battery_instance_ids:
		var definition := _get_battery_definition(instance_id)
		if definition == null:
			errors.append("Battery instance %d has no valid battery definition." % instance_id)
			continue
		var stored := float(_battery_stored_energy_kwh.get(instance_id, -1.0))
		var capacity := float(definition.get("battery_capacity_kwh"))
		if not is_finite(stored) or stored < -BATTERY_ENERGY_EPSILON_KWH or stored > capacity + BATTERY_ENERGY_EPSILON_KWH:
			errors.append("Battery instance %d stored energy %.6f kWh is outside 0..%.6f kWh." % [instance_id, stored, capacity])
	for raw_id in _battery_stored_energy_kwh.keys():
		var stored_instance_id := int(raw_id)
		var stored_definition := _get_battery_definition(stored_instance_id)
		if stored_definition == null:
			errors.append("Battery runtime state exists for non-battery instance %d." % stored_instance_id)
			continue
		var stored_energy := float(_battery_stored_energy_kwh[raw_id])
		var stored_capacity := float(stored_definition.get("battery_capacity_kwh"))
		if not is_finite(stored_energy) or stored_energy < -BATTERY_ENERGY_EPSILON_KWH or stored_energy > stored_capacity + BATTERY_ENERGY_EPSILON_KWH:
			errors.append("Battery instance %d stored energy %.6f kWh is outside 0..%.6f kWh." % [stored_instance_id, stored_energy, stored_capacity])
	for raw_id in _block_enabled_state.keys():
		if not _instances.has(int(raw_id)):
			errors.append("Enabled-state override references missing instance %d." % int(raw_id))
	for raw_id in _block_custom_names.keys():
		var configured_id := int(raw_id)
		var configured_name := String(_block_custom_names[raw_id])
		if not _instances.has(configured_id):
			errors.append("Custom name references missing instance %d." % configured_id)
		elif configured_name.length() > MAX_BLOCK_CUSTOM_NAME_LENGTH or "\n" in configured_name or "\r" in configured_name or "\t" in configured_name:
			errors.append("Custom name for instance %d is invalid." % configured_id)
	for raw_id in _block_power_priority_overrides.keys():
		var configured_id := int(raw_id)
		var priority := int(_block_power_priority_overrides[raw_id])
		if not _instances.has(configured_id) or priority < 0 or priority > 3:
			errors.append("Power-priority override for instance %d is invalid." % configured_id)
	for raw_name in _block_groups.keys():
		var group_name := String(raw_name)
		if _sanitize_group_name(group_name).is_empty():
			errors.append("Block group '%s' has an invalid name." % group_name)
		var seen_group_members: Dictionary = {}
		for raw_member in _block_groups[raw_name] as Array:
			var member_id := int(raw_member)
			if not _instances.has(member_id):
				errors.append("Block group '%s' references missing instance %d." % [group_name, member_id])
			elif seen_group_members.has(member_id):
				errors.append("Block group '%s' contains duplicate instance %d." % [group_name, member_id])
			seen_group_members[member_id] = true
	if has_active_pilot() and not has_valid_control_seat(_active_control_seat_instance_id):
		errors.append("Active pilot is bound to an invalid control-seat instance.")
	elif not has_active_pilot() and _active_control_seat_instance_id != 0:
		errors.append("Control-seat instance is recorded without a valid active pilot.")
	return errors

func _prepare_load_state(state: Dictionary) -> Dictionary:
	if String(state.get("schema", "")) != GRID_SAVE_SCHEMA:
		return _load_error("Unknown or missing grid save schema.")
	var version_result := _parse_integer(state.get("version", null), GRID_SAVE_MIN_SUPPORTED_VERSION)
	if not bool(version_result["ok"]):
		return _load_error("Unsupported or malformed grid save version.")
	var save_version := int(version_result["value"])
	if save_version < GRID_SAVE_MIN_SUPPORTED_VERSION or save_version > GRID_SAVE_VERSION:
		return _load_error("Unsupported grid save version %d." % save_version)

	var profile_id := StringName(String(state.get("grid_profile_id", "")))
	if profile_id == &"":
		return _load_error("Grid profile ID is missing.")
	var profile := GridDB.call("get_profile", profile_id) as Resource
	if not _is_profile_valid(profile):
		return _load_error("Unknown grid profile '%s'." % String(profile_id))

	var raw_blocks = state.get("blocks", null)
	if typeof(raw_blocks) != TYPE_ARRAY:
		return _load_error("Grid block list is missing or malformed.")
	var next_id_result := _parse_integer(state.get("next_instance_id", null), 1)
	if not bool(next_id_result["ok"]):
		return _load_error("Next instance ID is missing or malformed.")

	var new_instances: Dictionary = {}
	var new_cells: Dictionary = {}
	var highest_instance_id := 0
	for raw_block in raw_blocks:
		if typeof(raw_block) != TYPE_DICTIONARY:
			return _load_error("Grid block entry is not a dictionary.")
		var parsed := _parse_block_save_state(raw_block as Dictionary, profile_id)
		if not bool(parsed["ok"]):
			return _load_error(String(parsed["error"]))
		var instance := parsed["instance"] as Resource
		var instance_id := int(instance.get("instance_id"))
		if new_instances.has(instance_id):
			return _load_error("Duplicate block instance ID %d." % instance_id)
		for cell in instance.call("get_occupied_cells"):
			if new_cells.has(cell):
				return _load_error("Block instance %d overlaps occupied cell %s." % [instance_id, str(cell)])
		new_instances[instance_id] = instance
		for cell in instance.call("get_occupied_cells"):
			new_cells[cell] = instance
		highest_instance_id = maxi(highest_instance_id, instance_id)

	var mass_result := _calculate_mass_for_instances(new_instances)
	if not bool(mass_result.get("ok", false)):
		return _load_error("Grid mass validation failed: %s" % String(mass_result.get("error", "unknown mass error")))
	var battery_result := _prepare_battery_load_state(new_instances, state.get("battery_states", null), save_version)
	if not bool(battery_result.get("ok", false)):
		return _load_error(String(battery_result.get("error", "Battery state validation failed.")))
	var config_result := _prepare_block_configuration_load_state(new_instances, state.get("block_configurations", null), state.get("block_groups", null), save_version)
	if not bool(config_result.get("ok", false)):
		return _load_error(String(config_result.get("error", "Block configuration validation failed.")))
	var requested_next_id := int(next_id_result["value"])
	var safe_next_id := maxi(maxi(requested_next_id, highest_instance_id + 1), 1)
	return {
		"ok": true,
		"profile": profile,
		"instances": new_instances,
		"cells": new_cells,
		"next_instance_id": safe_next_id,
		"calculated_mass_kg": float(mass_result["mass_kg"]),
		"battery_states": battery_result["battery_states"] as Dictionary,
		"enabled_states": config_result["enabled_states"] as Dictionary,
		"custom_names": config_result["custom_names"] as Dictionary,
		"priority_overrides": config_result["priority_overrides"] as Dictionary,
		"block_groups": config_result["block_groups"] as Dictionary,
	}

func _prepare_block_configuration_load_state(instances: Dictionary, raw_configurations, raw_groups, save_version: int) -> Dictionary:
	var enabled_states: Dictionary = {}
	var custom_names: Dictionary = {}
	var priority_overrides: Dictionary = {}
	var groups: Dictionary = {}
	if save_version < 3:
		for raw_id in instances.keys():
			var instance_id := int(raw_id)
			var instance := instances[raw_id] as Resource
			var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
			enabled_states[instance_id] = bool(definition.get("enabled_by_default")) if definition != null else false
		return {"ok": true, "enabled_states": enabled_states, "custom_names": custom_names, "priority_overrides": priority_overrides, "block_groups": groups}
	if typeof(raw_configurations) != TYPE_ARRAY:
		return _load_error("Block configuration list is missing or malformed for grid save version %d." % save_version)
	var seen: Dictionary = {}
	for raw_config in raw_configurations as Array:
		if typeof(raw_config) != TYPE_DICTIONARY:
			return _load_error("Block configuration entry is not a dictionary.")
		var config := raw_config as Dictionary
		var id_result := _parse_integer(config.get("instance_id", null), 1)
		if not bool(id_result.get("ok", false)):
			return _load_error("Block configuration instance ID is missing or malformed.")
		var instance_id := int(id_result["value"])
		if not instances.has(instance_id):
			return _load_error("Block configuration references unknown instance %d." % instance_id)
		if seen.has(instance_id):
			return _load_error("Duplicate block configuration for instance %d." % instance_id)
		if typeof(config.get("enabled", null)) != TYPE_BOOL:
			return _load_error("Enabled state is malformed for instance %d." % instance_id)
		var custom_name = config.get("custom_name", "")
		if typeof(custom_name) != TYPE_STRING:
			return _load_error("Custom name is malformed for instance %d." % instance_id)
		var cleaned_name := String(custom_name).strip_edges()
		if cleaned_name.length() > MAX_BLOCK_CUSTOM_NAME_LENGTH or "\n" in cleaned_name or "\r" in cleaned_name or "\t" in cleaned_name:
			return _load_error("Custom name is invalid for instance %d." % instance_id)
		var priority_result := _parse_integer(config.get("power_priority_override", POWER_PRIORITY_USE_DEFINITION), POWER_PRIORITY_USE_DEFINITION)
		if not bool(priority_result.get("ok", false)) or int(priority_result["value"]) > 3:
			return _load_error("Power-priority override is invalid for instance %d." % instance_id)
		enabled_states[instance_id] = bool(config["enabled"])
		if not cleaned_name.is_empty():
			custom_names[instance_id] = cleaned_name
		var priority := int(priority_result["value"])
		if priority >= 0:
			var instance := instances[instance_id] as Resource
			var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
			if definition == null or float(definition.get("power_use_kw")) <= 0.0:
				return _load_error("Power-priority override targets non-consumer instance %d." % instance_id)
			priority_overrides[instance_id] = priority
		seen[instance_id] = true
	if seen.size() != instances.size():
		return _load_error("Block configuration list does not cover every installed block.")
	if typeof(raw_groups) != TYPE_ARRAY:
		return _load_error("Block group list is missing or malformed for grid save version %d." % save_version)
	var seen_group_names: Dictionary = {}
	for raw_group in raw_groups as Array:
		if typeof(raw_group) != TYPE_DICTIONARY:
			return _load_error("Block group entry is not a dictionary.")
		var group := raw_group as Dictionary
		if typeof(group.get("name", null)) != TYPE_STRING:
			return _load_error("Block group name is missing or malformed.")
		var group_name := _sanitize_group_name(String(group["name"]))
		if group_name.is_empty():
			return _load_error("Block group name is invalid.")
		var folded := group_name.to_lower()
		if seen_group_names.has(folded):
			return _load_error("Duplicate block group name '%s'." % group_name)
		if typeof(group.get("instance_ids", null)) != TYPE_ARRAY:
			return _load_error("Block group '%s' has malformed members." % group_name)
		var members: Array[int] = []
		var seen_members: Dictionary = {}
		for raw_member in group["instance_ids"] as Array:
			var member_result := _parse_integer(raw_member, 1)
			if not bool(member_result.get("ok", false)):
				return _load_error("Block group '%s' contains an invalid member ID." % group_name)
			var member_id := int(member_result["value"])
			if not instances.has(member_id):
				return _load_error("Block group '%s' references missing instance %d." % [group_name, member_id])
			if seen_members.has(member_id):
				return _load_error("Block group '%s' contains duplicate instance %d." % [group_name, member_id])
			members.append(member_id)
			seen_members[member_id] = true
		members.sort()
		groups[group_name] = members
		seen_group_names[folded] = true
	return {"ok": true, "enabled_states": enabled_states, "custom_names": custom_names, "priority_overrides": priority_overrides, "block_groups": groups}

func _prepare_battery_load_state(instances: Dictionary, raw_battery_states, save_version: int) -> Dictionary:
	var battery_ids: Array[int] = []
	var definitions: Dictionary = {}
	for raw_id in instances.keys():
		var instance := instances[raw_id] as Resource
		if instance == null:
			continue
		var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
		if definition != null and StringName(definition.get("functional_type")) == &"battery":
			var instance_id := int(raw_id)
			battery_ids.append(instance_id)
			definitions[instance_id] = definition
	battery_ids.sort()
	var result_states: Dictionary = {}
	if save_version == 1:
		for instance_id in battery_ids:
			result_states[instance_id] = _initial_battery_energy_kwh(definitions[instance_id] as Resource)
		return {"ok": true, "battery_states": result_states}
	if typeof(raw_battery_states) != TYPE_ARRAY:
		return _load_error("Battery state list is missing or malformed for grid save version %d." % save_version)
	var seen: Dictionary = {}
	for raw_state in raw_battery_states as Array:
		if typeof(raw_state) != TYPE_DICTIONARY:
			return _load_error("Battery state entry is not a dictionary.")
		var state := raw_state as Dictionary
		var id_result := _parse_integer(state.get("instance_id", null), 1)
		if not bool(id_result.get("ok", false)):
			return _load_error("Battery state instance ID is missing or malformed.")
		var instance_id := int(id_result["value"])
		if instance_id not in battery_ids:
			return _load_error("Battery state references non-battery instance %d." % instance_id)
		if seen.has(instance_id):
			return _load_error("Duplicate battery state for instance %d." % instance_id)
		var energy_result := _parse_number(state.get("stored_energy_kwh", null), 0.0)
		if not bool(energy_result.get("ok", false)):
			return _load_error("Stored battery energy is missing or malformed for instance %d." % instance_id)
		var capacity := float((definitions[instance_id] as Resource).get("battery_capacity_kwh"))
		var energy := float(energy_result["value"])
		if energy > capacity + BATTERY_ENERGY_EPSILON_KWH:
			return _load_error("Stored battery energy %.6f kWh exceeds %.6f kWh capacity for instance %d." % [energy, capacity, instance_id])
		result_states[instance_id] = clampf(energy, 0.0, capacity)
		seen[instance_id] = true
	if seen.size() != battery_ids.size():
		return _load_error("Battery state list does not cover every battery block.")
	return {"ok": true, "battery_states": result_states}

func _parse_block_save_state(raw: Dictionary, profile_id: StringName) -> Dictionary:
	var instance_result := _parse_integer(raw.get("instance_id", null), 1)
	if not bool(instance_result["ok"]):
		return _load_error("Block instance ID is missing or invalid.")
	var block_id := StringName(String(raw.get("block_id", "")))
	if block_id == &"":
		return _load_error("Block ID is missing for instance %d." % int(instance_result["value"]))
	var anchor_result := _parse_vector3i_triplet(raw.get("anchor_cell", null), false)
	if not bool(anchor_result["ok"]):
		return _load_error("Anchor cell is malformed for instance %d." % int(instance_result["value"]))
	var dimensions_result := _parse_vector3i_triplet(raw.get("dimensions_cells", null), true)
	if not bool(dimensions_result["ok"]):
		return _load_error("Dimensions are malformed for instance %d." % int(instance_result["value"]))
	var orientation_result := _parse_integer(raw.get("orientation_index", null), 0)
	if not bool(orientation_result["ok"]) or not BLOCK_ORIENTATION.is_valid_index(int(orientation_result["value"])):
		return _load_error("Orientation is invalid for instance %d." % int(instance_result["value"]))

	var instance: Resource = BLOCK_INSTANCE_SCRIPT.new()
	instance.call(
		"configure",
		int(instance_result["value"]),
		block_id,
		Vector3i(anchor_result["value"]),
		Vector3i(dimensions_result["value"]),
		int(orientation_result["value"])
	)
	if not bool(instance.call("is_valid_instance")):
		return _load_error("Block instance %d failed runtime validation." % int(instance_result["value"]))
	var metadata_errors := BlockDB.call("validate_instance_state", instance, profile_id) as Array
	if not metadata_errors.is_empty():
		return _load_error("Block instance %d failed catalog validation: %s" % [int(instance_result["value"]), " | ".join(PackedStringArray(metadata_errors))])
	return {"ok": true, "instance": instance}

func _parse_vector3i_triplet(value, require_positive: bool) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {"ok": false}
	var values := value as Array
	if values.size() != 3:
		return {"ok": false}
	var parsed: Array[int] = []
	for component in values:
		var result := _parse_integer(component, 1 if require_positive else -2147483648)
		if not bool(result["ok"]):
			return {"ok": false}
		parsed.append(int(result["value"]))
	return {"ok": true, "value": Vector3i(parsed[0], parsed[1], parsed[2])}

func _parse_integer(value, minimum_value: int) -> Dictionary:
	if typeof(value) == TYPE_INT:
		var integer_value := int(value)
		return {"ok": integer_value >= minimum_value, "value": integer_value}
	if typeof(value) == TYPE_FLOAT:
		var float_value := float(value)
		if not is_finite(float_value) or not is_equal_approx(float_value, roundf(float_value)):
			return {"ok": false, "value": 0}
		var integer_value := int(roundf(float_value))
		return {"ok": integer_value >= minimum_value, "value": integer_value}
	return {"ok": false, "value": 0}

func _parse_number(value, minimum_value: float) -> Dictionary:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return {"ok": false, "value": 0.0}
	var number := float(value)
	return {"ok": is_finite(number) and number >= minimum_value, "value": number}

func _load_error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _set_calculated_mass(value_kg: float, emit_signal: bool = true) -> void:
	var safe_mass := maxf(value_kg, 0.0) if is_finite(value_kg) else 0.0
	var changed := absf(safe_mass - _calculated_mass_kg) > MASS_EPSILON_KG
	_calculated_mass_kg = safe_mass
	_apply_physics_mass()
	if changed and is_dynamic_simulation_enabled() and sleeping:
		sleeping = false
	if changed and emit_signal:
		mass_changed.emit(_calculated_mass_kg, mass)

func _apply_physics_mass() -> void:
	mass = maxf(_calculated_mass_kg, MIN_RIGID_BODY_MASS_KG)

func _calculate_mass_for_instances(instances: Dictionary) -> Dictionary:
	var total_mass := 0.0
	for raw_id in instances.keys():
		var instance := instances[raw_id] as Resource
		if instance == null:
			return {"ok": false, "error": "Instance %s is null." % str(raw_id)}
		var block_id := StringName(instance.get("block_id"))
		var block_mass := _resolve_block_id_mass(block_id)
		if not is_finite(block_mass) or block_mass <= 0.0:
			return {"ok": false, "error": "Block '%s' has no valid mass metadata." % String(block_id)}
		total_mass += block_mass
	return {"ok": true, "mass_kg": total_mass}

func _resolve_definition_mass(block_definition: Resource) -> float:
	if block_definition == null:
		return 0.0
	var block_id := StringName(block_definition.get("id"))
	var canonical := BlockDB.call("get_block", block_id) as Resource
	var source := canonical if canonical != null else block_definition
	var block_mass := float(source.get("mass_kg"))
	return block_mass if is_finite(block_mass) and block_mass > 0.0 else 0.0

func _resolve_block_id_mass(block_id: StringName) -> float:
	var canonical := BlockDB.call("get_block", block_id) as Resource
	if canonical != null:
		var canonical_mass := float(canonical.get("mass_kg"))
		return canonical_mass if is_finite(canonical_mass) and canonical_mass > 0.0 else 0.0
	if _runtime_block_masses.has(block_id):
		var runtime_mass := float(_runtime_block_masses[block_id])
		return runtime_mass if is_finite(runtime_mass) and runtime_mass > 0.0 else 0.0
	return 0.0

func get_mass_breakdown_by_block_id() -> Dictionary:
	var breakdown: Dictionary = {}
	for instance in get_all_blocks():
		var block_id := StringName(instance.get("block_id"))
		var block_mass := _resolve_block_id_mass(block_id)
		var key := String(block_id)
		if not breakdown.has(key):
			breakdown[key] = {"count": 0, "unit_mass_kg": block_mass, "subtotal_kg": 0.0}
		var entry := breakdown[key] as Dictionary
		entry["count"] = int(entry["count"]) + 1
		entry["subtotal_kg"] = float(entry["subtotal_kg"]) + block_mass
		breakdown[key] = entry
	return breakdown

func _on_block_database_reloaded(_block_count: int) -> void:
	recalculate_mass_from_blocks()
	_mark_thruster_cache_dirty()
	_mark_gyroscope_cache_dirty()
	_mark_power_cache_dirty()

func _is_profile_valid(profile: Resource) -> bool:
	return profile != null and profile.has_method("is_valid_profile") and bool(profile.call("is_valid_profile"))

func _is_block_definition_compatible(block_definition: Resource) -> bool:
	if block_definition == null or not _is_profile_valid(grid_profile):
		return false
	var block_id = block_definition.get("id")
	var dimensions = block_definition.get("dimensions_cells")
	var allowed_grid_sizes = block_definition.get("allowed_grid_sizes")
	if block_id == null or StringName(block_id) == &"":
		return false
	if dimensions == null:
		return false
	var dimensions_cells := Vector3i(dimensions)
	if dimensions_cells.x <= 0 or dimensions_cells.y <= 0 or dimensions_cells.z <= 0:
		return false
	if allowed_grid_sizes == null:
		return false
	var profile_id := get_grid_type()
	var allowed := false
	for allowed_id in allowed_grid_sizes:
		if StringName(allowed_id) == profile_id:
			allowed = true
			break
	if not allowed:
		return false
	# Registered IDs are canonical: a transient definition may not spoof a production ID
	# with different dimensions or grid compatibility. Unregistered definitions remain useful
	# for isolated regression fixtures until Stage 15 replaces more test-only content.
	if BlockDB.call("has_block", StringName(block_id)):
		var canonical := BlockDB.call("get_block", StringName(block_id)) as Resource
		if canonical == null or Vector3i(canonical.get("dimensions_cells")) != dimensions_cells:
			return false
	return true

func _cells_for_extent(anchor_cell: Vector3i, dimensions: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if dimensions.x <= 0 or dimensions.y <= 0 or dimensions.z <= 0:
		return cells
	for x in dimensions.x:
		for y in dimensions.y:
			for z in dimensions.z:
				cells.append(anchor_cell + Vector3i(x, y, z))
	return cells
