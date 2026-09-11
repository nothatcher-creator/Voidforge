class_name BlockDefinition
extends Resource
## Authoritative data contract for buildable block types.
## Stage 15 extends the data-driven contract with variant grouping and lightweight placeholder presentation metadata.

const BLOCK_COST_SCRIPT := preload("res://scripts/blocks/block_cost_entry.gd")
const VALID_GRID_IDS: Array[StringName] = [&"small", &"large", &"static"]
const ATTACHMENT_FACE_COUNT: int = 6
const ATTACHMENT_ALL: int = 0b111111
const POWER_PRIORITY_CRITICAL: int = 0
const POWER_PRIORITY_HIGH: int = 1
const POWER_PRIORITY_NORMAL: int = 2
const POWER_PRIORITY_LOW: int = 3
const POWER_PRIORITY_NAMES: Array[StringName] = [&"critical", &"high", &"normal", &"low"]
const VALID_PRESENTATION_SHAPES: Array[StringName] = [&"box", &"frame", &"beam", &"panel", &"grating", &"wedge", &"corner", &"seat", &"thruster", &"gyro", &"battery", &"reactor"]
const VALID_PRESENTATION_MATERIAL_IDS: Array[StringName] = [&"dev_structure", &"structure_frame", &"structure_heavy", &"armor_light", &"armor_heavy", &"service_panel", &"grating", &"control_console", &"propulsion", &"gyro", &"power_storage", &"power_generation"]

@export_group("Identity")
@export var id: StringName
@export var display_name: String = "Unnamed Block"
@export_multiline var description: String = ""
@export var category: StringName = &"structure"
@export var tags: Array[StringName] = []

@export_group("Grid")
@export var allowed_grid_sizes: Array[StringName] = [&"small", &"large", &"static"]
@export var dimensions_cells: Vector3i = Vector3i.ONE
@export_range(0, ATTACHMENT_ALL, 1) var attachment_faces_mask: int = ATTACHMENT_ALL

@export_group("Construction")
@export var build_cost: Array[Resource] = []
@export_range(1, 16, 1) var construction_stages: int = 1

@export_group("Physical")
@export_range(0.001, 1000000.0, 0.01, "or_greater") var mass_kg: float = 1.0
@export_range(1.0, 10000000.0, 1.0, "or_greater") var max_integrity: float = 100.0
@export var material_id: StringName = &"industrial_alloy"

@export_group("Function")
@export var functional_type: StringName = &"structural"
@export var enabled_by_default: bool = true
@export_range(0.0, 1000000.0, 0.01, "or_greater") var power_use_kw: float = 0.0
@export_range(0.0, 1000000.0, 0.01, "or_greater") var power_production_kw: float = 0.0
@export_range(POWER_PRIORITY_CRITICAL, POWER_PRIORITY_LOW, 1) var power_priority: int = POWER_PRIORITY_NORMAL
@export_range(0.0, 1000000.0, 0.01, "or_greater") var heat_generation_kw: float = 0.0
@export_range(0.0, 1000000.0, 0.01, "or_greater") var inventory_volume_l: float = 0.0
@export_range(0, 64, 1) var conveyor_port_count: int = 0
@export var recipe_id: StringName
@export var unlock_id: StringName

@export_group("Propulsion")
@export_range(0.0, 100000000.0, 1.0, "or_greater") var thrust_force_n: float = 0.0
@export var thrust_direction_local: Vector3i = Vector3i(0, 0, -1)

@export_group("Gyroscope")
@export_range(0.0, 1000000000.0, 1.0, "or_greater") var gyro_torque_nm: float = 0.0

@export_group("Battery")
@export_range(0.0, 1000000.0, 0.01, "or_greater") var battery_capacity_kwh: float = 0.0
@export_range(0.0, 1.0, 0.01) var battery_initial_charge_fraction: float = 0.0
@export_range(0.0, 1000000.0, 0.01, "or_greater") var battery_max_charge_kw: float = 0.0
@export_range(0.0, 1000000.0, 0.01, "or_greater") var battery_max_discharge_kw: float = 0.0

@export_group("Variants")
@export var variant_group: StringName
@export var variant_key: StringName
@export_range(0, 999, 1) var variant_order: int = 0

@export_group("Placeholder Presentation")
@export var presentation_shape: StringName = &"box"
@export var presentation_scale: Vector3 = Vector3.ONE
@export var presentation_offset_cells: Vector3 = Vector3.ZERO
@export var presentation_material_id: StringName = &"structure_frame"

@export_group("Resources")
@export var scene: PackedScene
@export var icon: Texture2D
@export var lod_scenes: Array[PackedScene] = []

func is_valid_definition(item_db: Node = null) -> bool:
	return get_validation_errors(item_db).is_empty()

func get_validation_errors(item_db: Node = null) -> Array[String]:
	var errors: Array[String] = []
	var id_text := String(id)
	if id == &"":
		errors.append("Block ID cannot be empty.")
	elif not _is_valid_content_id(id_text):
		errors.append("Block ID '%s' must use lowercase snake_case ASCII characters." % id_text)
	if display_name.strip_edges().is_empty():
		errors.append("Display name cannot be empty.")
	if description.strip_edges().is_empty():
		errors.append("Description cannot be empty.")
	if category == &"":
		errors.append("Category cannot be empty.")
	elif not _is_valid_content_id(String(category)):
		errors.append("Category '%s' must use lowercase snake_case ASCII characters." % String(category))

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

	if allowed_grid_sizes.is_empty():
		errors.append("At least one allowed grid size is required.")
	var seen_grids: Dictionary = {}
	for grid_id in allowed_grid_sizes:
		if grid_id not in VALID_GRID_IDS:
			errors.append("Unknown allowed grid ID '%s'." % String(grid_id))
		elif seen_grids.has(grid_id):
			errors.append("Duplicate allowed grid ID '%s'." % String(grid_id))
		else:
			seen_grids[grid_id] = true
	if dimensions_cells.x <= 0 or dimensions_cells.y <= 0 or dimensions_cells.z <= 0:
		errors.append("Block dimensions must be positive on every axis.")
	if attachment_faces_mask < 0 or attachment_faces_mask > ATTACHMENT_ALL:
		errors.append("Attachment-face mask must stay within the six orthogonal grid faces.")

	if build_cost.is_empty():
		errors.append("Build cost cannot be empty.")
	var seen_cost_items: Dictionary = {}
	for index in build_cost.size():
		var entry := build_cost[index]
		if not _is_cost_entry(entry):
			errors.append("Build-cost entry %d is not a BlockCostEntry resource." % index)
			continue
		var entry_errors: Array = entry.call("get_validation_errors", item_db)
		for error in entry_errors:
			errors.append("Build-cost entry %d: %s" % [index, String(error)])
		var cost_item_id := StringName(entry.get("item_id"))
		if cost_item_id != &"":
			if seen_cost_items.has(cost_item_id):
				errors.append("Duplicate build-cost item '%s'." % String(cost_item_id))
			else:
				seen_cost_items[cost_item_id] = true
	if construction_stages <= 0:
		errors.append("Construction stages must be greater than zero.")

	if mass_kg <= 0.0:
		errors.append("Block mass must be greater than zero.")
	if max_integrity <= 0.0:
		errors.append("Maximum integrity must be greater than zero.")
	if material_id == &"" or not _is_valid_content_id(String(material_id)):
		errors.append("Material ID must be a lowercase snake_case content ID.")
	if functional_type == &"" or not _is_valid_content_id(String(functional_type)):
		errors.append("Functional type must be a lowercase snake_case content ID.")
	if power_use_kw < 0.0 or power_production_kw < 0.0 or heat_generation_kw < 0.0 or inventory_volume_l < 0.0:
		errors.append("Functional numeric metadata cannot be negative.")
	if power_priority < POWER_PRIORITY_CRITICAL or power_priority > POWER_PRIORITY_LOW:
		errors.append("Power priority must stay within the Critical..Low tier range.")
	if conveyor_port_count < 0:
		errors.append("Conveyor-port count cannot be negative.")
	if recipe_id != &"" and not _is_valid_content_id(String(recipe_id)):
		errors.append("Recipe ID must use lowercase snake_case when present.")
	if unlock_id != &"" and not _is_valid_content_id(String(unlock_id)):
		errors.append("Unlock ID must use lowercase snake_case when present.")

	if thrust_force_n < 0.0 or not is_finite(thrust_force_n):
		errors.append("Thruster force must be finite and cannot be negative.")
	if functional_type == &"thruster":
		if thrust_force_n <= 0.0:
			errors.append("Thruster blocks require positive thrust force metadata.")
		if not _is_cardinal_direction(thrust_direction_local):
			errors.append("Thruster direction must be one orthogonal local grid axis.")
	elif thrust_force_n > 0.0:
		errors.append("Only thruster blocks may declare positive thrust force.")

	if gyro_torque_nm < 0.0 or not is_finite(gyro_torque_nm):
		errors.append("Gyroscope torque must be finite and cannot be negative.")
	if functional_type == &"gyroscope":
		if gyro_torque_nm <= 0.0:
			errors.append("Gyroscope blocks require positive torque metadata.")
	elif gyro_torque_nm > 0.0:
		errors.append("Only gyroscope blocks may declare positive gyroscope torque.")

	if battery_capacity_kwh < 0.0 or battery_max_charge_kw < 0.0 or battery_max_discharge_kw < 0.0:
		errors.append("Battery capacity and charge/discharge rates cannot be negative.")
	if not is_finite(battery_capacity_kwh) or not is_finite(battery_initial_charge_fraction) or not is_finite(battery_max_charge_kw) or not is_finite(battery_max_discharge_kw):
		errors.append("Battery metadata must be finite.")
	if battery_initial_charge_fraction < 0.0 or battery_initial_charge_fraction > 1.0:
		errors.append("Battery initial charge fraction must stay between 0 and 1.")
	if functional_type == &"battery":
		if battery_capacity_kwh <= 0.0:
			errors.append("Battery blocks require positive stored-energy capacity.")
		if battery_max_charge_kw <= 0.0:
			errors.append("Battery blocks require a positive maximum charge rate.")
		if battery_max_discharge_kw <= 0.0:
			errors.append("Battery blocks require a positive maximum discharge rate.")
		if power_use_kw > 0.0 or power_production_kw > 0.0:
			errors.append("Battery blocks use storage metadata instead of fixed power use/production metadata.")
	elif battery_capacity_kwh > 0.0 or battery_initial_charge_fraction > 0.0 or battery_max_charge_kw > 0.0 or battery_max_discharge_kw > 0.0:
		errors.append("Only battery blocks may declare battery storage metadata.")

	if functional_type == &"reactor":
		if power_production_kw <= 0.0:
			errors.append("Reactor blocks require positive electrical production metadata.")
		if power_use_kw > 0.0:
			errors.append("Reactor blocks cannot simultaneously declare consumer power demand.")

	if variant_group != &"" and not _is_valid_content_id(String(variant_group)):
		errors.append("Variant group must use lowercase snake_case when present.")
	if variant_key != &"" and not _is_valid_content_id(String(variant_key)):
		errors.append("Variant key must use lowercase snake_case when present.")
	if (variant_group == &"") != (variant_key == &""):
		errors.append("Variant group and variant key must either both be set or both be empty.")
	if variant_order < 0:
		errors.append("Variant order cannot be negative.")
	if presentation_shape not in VALID_PRESENTATION_SHAPES:
		errors.append("Unknown placeholder presentation shape '%s'." % String(presentation_shape))
	if presentation_scale.x <= 0.0 or presentation_scale.y <= 0.0 or presentation_scale.z <= 0.0:
		errors.append("Placeholder presentation scale must be positive on every axis.")
	if presentation_scale.x > 1.0 or presentation_scale.y > 1.0 or presentation_scale.z > 1.0:
		errors.append("Placeholder presentation scale cannot exceed the occupied cell extent.")
	if presentation_offset_cells.x < -0.5 or presentation_offset_cells.x > 0.5 or presentation_offset_cells.y < -0.5 or presentation_offset_cells.y > 0.5 or presentation_offset_cells.z < -0.5 or presentation_offset_cells.z > 0.5:
		errors.append("Placeholder presentation offset must remain inside half a grid cell on each axis.")
	if presentation_material_id == &"" or not _is_valid_content_id(String(presentation_material_id)):
		errors.append("Placeholder presentation material ID must be a lowercase snake_case content ID.")
	elif presentation_material_id not in VALID_PRESENTATION_MATERIAL_IDS:
		errors.append("Unknown placeholder presentation material ID '%s'." % String(presentation_material_id))
	return errors

func get_power_priority_name() -> StringName:
	if power_priority < 0 or power_priority >= POWER_PRIORITY_NAMES.size():
		return &"invalid"
	return POWER_PRIORITY_NAMES[power_priority]

func allows_grid(grid_id: StringName) -> bool:
	return grid_id != &"" and grid_id in allowed_grid_sizes

func has_attachment_face(face_index: int) -> bool:
	return face_index >= 0 and face_index < ATTACHMENT_FACE_COUNT and (attachment_faces_mask & (1 << face_index)) != 0

func get_attachment_face_count() -> int:
	var count := 0
	for face_index in ATTACHMENT_FACE_COUNT:
		if has_attachment_face(face_index):
			count += 1
	return count

func get_build_cost_quantity(item_id: StringName) -> int:
	if item_id == &"":
		return 0
	for entry in build_cost:
		if _is_cost_entry(entry) and StringName(entry.get("item_id")) == item_id:
			return int(entry.get("quantity"))
	return 0

func get_total_build_cost_units() -> int:
	var total := 0
	for entry in build_cost:
		if _is_cost_entry(entry):
			total += int(entry.get("quantity"))
	return total

func _is_cost_entry(value) -> bool:
	return value is Resource and value.get_script() == BLOCK_COST_SCRIPT

func _is_valid_content_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	var first := value.unicode_at(0)
	if first < 97 or first > 122:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not (is_lower or is_digit or code == 95):
			return false
	return true

func _is_cardinal_direction(value: Vector3i) -> bool:
	var absolute := value.abs()
	return absolute.x + absolute.y + absolute.z == 1
