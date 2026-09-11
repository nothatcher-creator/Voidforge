extends Node3D
## Android-oriented presenter for sparse BlockGrid state.
## Stage 16 batches placeholder visuals into a tiny set of MultiMeshInstance3D nodes.
## Stage 17 collapsed per-block physics bodies into one shared collider. Stage 18 moves
## those shape owners directly onto the BlockGrid RigidBody3D so a released grid can move
## through physics without introducing a second transform authority. Exact block targeting
## remains shape-index based and does not require CollisionShape3D nodes per block.

const GRID_COLLISION_LAYER: int = 1 << 2
const DEV_STRUCTURE_MATERIAL := preload("res://assets/materials/dev_structure_material.tres")
const STRUCTURE_FRAME_MATERIAL := preload("res://assets/materials/block_structure_frame_material.tres")
const STRUCTURE_HEAVY_MATERIAL := preload("res://assets/materials/block_structure_heavy_material.tres")
const ARMOR_LIGHT_MATERIAL := preload("res://assets/materials/block_armor_light_material.tres")
const ARMOR_HEAVY_MATERIAL := preload("res://assets/materials/block_armor_heavy_material.tres")
const SERVICE_PANEL_MATERIAL := preload("res://assets/materials/block_service_panel_material.tres")
const GRATING_MATERIAL := preload("res://assets/materials/block_grating_material.tres")
const CONTROL_MATERIAL := preload("res://assets/materials/block_control_material.tres")
const PROPULSION_MATERIAL := preload("res://assets/materials/block_propulsion_material.tres")
const GYRO_MATERIAL := preload("res://assets/materials/block_gyro_material.tres")
const POWER_STORAGE_MATERIAL := preload("res://assets/materials/block_power_storage_material.tres")
const POWER_GENERATION_MATERIAL := preload("res://assets/materials/block_power_generation_material.tres")
const CONTROL_SEAT_PRESENTER_SCRIPT := preload("res://scripts/ships/control_seat_presenter.gd")

const PRIMITIVE_BOX: StringName = &"box"
const PRIMITIVE_WEDGE: StringName = &"wedge"

@export var render_geometry: bool = true
@export var render_collision: bool = true
@export var defer_geometry_rebuilds: bool = true
@export var defer_collision_rebuilds: bool = true

var _grid: Node3D
var _geometry_root: Node3D
var _collision_body: CollisionObject3D
var _collision_owner_to_instance: Dictionary = {}
var _collision_instance_to_owner: Dictionary = {}
var _collision_shape_cache: Dictionary = {}
var _batch_nodes: Dictionary = {}
var _geometry_dirty: bool = false
var _rebuild_queued: bool = false
var _geometry_rebuild_count: int = 0
var _collision_dirty: bool = false
var _collision_rebuild_queued: bool = false
var _collision_rebuild_count: int = 0
var _render_instance_count: int = 0
var _unit_box_mesh: BoxMesh
var _unit_wedge_mesh: ArrayMesh
var _control_seat_presenter: Node3D

func _ready() -> void:
	_grid = get_parent() as Node3D
	if _grid == null or not _grid.has_method("get_all_blocks"):
		DebugLog.error("GridPresenter", "%s must be a child of a BlockGrid-compatible node" % name)
		set_process(false)
		return
	_grid.add_to_group("voidforge_block_grid")
	_create_runtime_roots()
	_create_unit_mesh_cache()
	_create_functional_presenters()
	_grid.connect("block_added", Callable(self, "_on_block_added"))
	_grid.connect("block_removed", Callable(self, "_on_block_removed"))
	_grid.connect("grid_changed", Callable(self, "_on_grid_changed"))
	if _grid.has_signal("grid_reloaded"):
		_grid.connect("grid_reloaded", Callable(self, "_on_grid_reloaded"))
	_mark_collision_dirty()
	_mark_geometry_dirty()
	flush_collision_now()
	flush_geometry_now()

func get_control_seat_presenter() -> Node3D:
	return _control_seat_presenter

func get_block_grid() -> Node3D:
	return _grid

func get_presented_block_count() -> int:
	return _grid_block_count()

func get_collision_proxy_count() -> int:
	# Compatibility name retained for older diagnostics. Stage 17 proxies are shape owners, not nodes.
	return _collision_instance_to_owner.size() if render_collision else 0

func get_collision_shape_count() -> int:
	return _collision_instance_to_owner.size() if render_collision else 0

func get_collision_shape_resource_count() -> int:
	return _collision_shape_cache.size()

func get_collision_rebuild_count() -> int:
	return _collision_rebuild_count

func is_collision_dirty() -> bool:
	return _collision_dirty

func get_collision_body() -> CollisionObject3D:
	return _collision_body

func get_collision_body_node_instance_id() -> int:
	return _collision_body.get_instance_id() if _collision_body != null else 0

func get_block_body(instance_id: int) -> CollisionObject3D:
	# Compatibility helper: all block shapes share the BlockGrid physics body.
	return _collision_body if _collision_instance_to_owner.has(instance_id) else null

func get_block_collision_transform(instance_id: int) -> Transform3D:
	if _collision_body == null or not _collision_instance_to_owner.has(instance_id):
		return Transform3D.IDENTITY
	var owner_id := int(_collision_instance_to_owner[instance_id])
	return _collision_body.shape_owner_get_transform(owner_id)

func get_block_collision_shape(instance_id: int) -> Shape3D:
	if _collision_body == null or not _collision_instance_to_owner.has(instance_id):
		return null
	var owner_id := int(_collision_instance_to_owner[instance_id])
	if _collision_body.shape_owner_get_shape_count(owner_id) <= 0:
		return null
	return _collision_body.shape_owner_get_shape(owner_id, 0)

func resolve_block_instance_id_for_shape(shape_index: int) -> int:
	if _collision_body == null or shape_index < 0:
		return 0
	var owner_id := _collision_body.shape_find_owner(shape_index)
	return int(_collision_owner_to_instance.get(owner_id, 0))

func get_block_presentation_shape(instance_id: int) -> StringName:
	var definition := _definition_for_instance_id(instance_id)
	if definition == null:
		return &""
	return StringName(definition.get("presentation_shape"))

func get_block_visual_count(instance_id: int) -> int:
	var shape := get_block_presentation_shape(instance_id)
	match shape:
		&"frame":
			return 12
		&"grating":
			return 10
		&"corner":
			return 2
		&"seat":
			return 5
		&"thruster":
			return 4
		&"gyro":
			return 5
		&"battery":
			return 5
		&"reactor":
			return 9
		&"box", &"beam", &"panel", &"wedge":
			return 1
		_:
			return 0

func get_batch_count() -> int:
	return _batch_nodes.size()

func get_render_instance_count() -> int:
	return _render_instance_count

func get_geometry_rebuild_count() -> int:
	return _geometry_rebuild_count

func is_geometry_dirty() -> bool:
	return _geometry_dirty

func get_batch_instance_count(material_id: StringName, primitive_kind: StringName) -> int:
	var node := _batch_nodes.get(_batch_key(material_id, primitive_kind)) as MultiMeshInstance3D
	if node == null or node.multimesh == null:
		return 0
	return node.multimesh.instance_count

func get_batch_mesh(material_id: StringName, primitive_kind: StringName) -> Mesh:
	var node := _batch_nodes.get(_batch_key(material_id, primitive_kind)) as MultiMeshInstance3D
	if node == null or node.multimesh == null:
		return null
	return node.multimesh.mesh

func get_batch_node_instance_id(material_id: StringName, primitive_kind: StringName) -> int:
	var node := _batch_nodes.get(_batch_key(material_id, primitive_kind)) as MultiMeshInstance3D
	if node == null:
		return 0
	return node.get_instance_id()

func get_runtime_render_node_count() -> int:
	if _geometry_root == null:
		return 0
	return _geometry_root.get_child_count()

func get_runtime_collision_node_count() -> int:
	# The single collision node is now the parent BlockGrid RigidBody3D itself.
	return 1 if render_collision and _collision_body != null else 0

func rebuild() -> void:
	_mark_collision_dirty()
	_mark_geometry_dirty()
	flush_collision_now()
	flush_geometry_now()

func flush_collision_now() -> void:
	_collision_rebuild_queued = false
	if not _collision_dirty or _grid == null:
		return
	_collision_dirty = false
	_rebuild_grid_collision()

func flush_geometry_now() -> void:
	_rebuild_queued = false
	if not _geometry_dirty or _grid == null:
		return
	_geometry_dirty = false
	_rebuild_batched_geometry()

func _on_block_added(_instance_id: int, _block_id: StringName) -> void:
	_mark_collision_dirty()
	_mark_geometry_dirty()

func _on_block_removed(_instance_id: int, _block_id: StringName) -> void:
	_mark_collision_dirty()
	_mark_geometry_dirty()

func _on_grid_changed(_block_count: int, _occupied_cell_count: int) -> void:
	_mark_collision_dirty()
	_mark_geometry_dirty()

func _on_grid_reloaded(_block_count: int, _occupied_cell_count: int) -> void:
	_mark_collision_dirty()
	_mark_geometry_dirty()

func _create_runtime_roots() -> void:
	_geometry_root = Node3D.new()
	_geometry_root.name = "BatchedGeometry"
	add_child(_geometry_root)
	_collision_body = _grid as CollisionObject3D
	if _collision_body == null:
		DebugLog.error("GridPresenter", "%s requires a CollisionObject3D-compatible BlockGrid" % name)
		return
	_collision_body.collision_layer = GRID_COLLISION_LAYER if render_collision else 0
	_collision_body.set_meta("voidforge_block_grid", _grid)
	_collision_body.set_meta("voidforge_grid_collision_presenter", self)

func _create_functional_presenters() -> void:
	_control_seat_presenter = CONTROL_SEAT_PRESENTER_SCRIPT.new() as Node3D
	_control_seat_presenter.name = "ControlSeatPresenter"
	add_child(_control_seat_presenter)
	_control_seat_presenter.call("bind_grid", _grid)

func _create_unit_mesh_cache() -> void:
	_unit_box_mesh = BoxMesh.new()
	_unit_box_mesh.size = Vector3.ONE
	_unit_wedge_mesh = _create_unit_wedge_mesh()

func _mark_collision_dirty() -> void:
	_collision_dirty = true
	if not render_collision:
		flush_collision_now()
		return
	if not defer_collision_rebuilds:
		flush_collision_now()
		return
	if _collision_rebuild_queued:
		return
	_collision_rebuild_queued = true
	call_deferred("_deferred_collision_rebuild")

func _deferred_collision_rebuild() -> void:
	if not is_inside_tree():
		return
	flush_collision_now()

func _mark_geometry_dirty() -> void:
	_geometry_dirty = true
	if not render_geometry:
		flush_geometry_now()
		return
	if not defer_geometry_rebuilds:
		flush_geometry_now()
		return
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_deferred_geometry_rebuild")

func _deferred_geometry_rebuild() -> void:
	if not is_inside_tree():
		return
	flush_geometry_now()

func _rebuild_batched_geometry() -> void:
	if not render_geometry:
		for raw_node in _batch_nodes.values():
			var node := raw_node as Node
			if is_instance_valid(node):
				node.queue_free()
		_batch_nodes.clear()
		_render_instance_count = 0
		_geometry_rebuild_count += 1
		return
	var transforms_by_batch: Dictionary = {}
	var batch_metadata: Dictionary = {}
	for raw_instance in _grid.call("get_all_blocks"):
		var instance := raw_instance as Resource
		if instance == null:
			continue
		_append_block_render_primitives(instance, transforms_by_batch, batch_metadata)

	var active_keys: Dictionary = {}
	_render_instance_count = 0
	for raw_key in transforms_by_batch.keys():
		var key := String(raw_key)
		active_keys[key] = true
		var transforms := transforms_by_batch[key] as Array
		var metadata := batch_metadata[key] as Dictionary
		var material_id := StringName(metadata["material_id"])
		var primitive_kind := StringName(metadata["primitive_kind"])
		var node := _ensure_batch_node(key, material_id, primitive_kind)
		_configure_batch(node, transforms, material_id, primitive_kind)
		_render_instance_count += transforms.size()

	for raw_key in _batch_nodes.keys().duplicate():
		var key := String(raw_key)
		if active_keys.has(key):
			continue
		var stale := _batch_nodes[key] as Node
		_batch_nodes.erase(key)
		if is_instance_valid(stale):
			stale.queue_free()
	_geometry_rebuild_count += 1

func _append_block_render_primitives(instance: Resource, transforms_by_batch: Dictionary, batch_metadata: Dictionary) -> void:
	var definition := _resolve_definition(StringName(instance.get("block_id")))
	var presentation_shape := StringName(definition.get("presentation_shape")) if definition != null else &"box"
	var presentation_scale := Vector3(definition.get("presentation_scale")) if definition != null else Vector3.ONE
	var offset_cells := Vector3(definition.get("presentation_offset_cells")) if definition != null else Vector3.ZERO
	var material_id := StringName(definition.get("presentation_material_id")) if definition != null else &"dev_structure"
	var dimensions := Vector3i(instance.get("dimensions_cells"))
	var oriented_dimensions := Vector3i(instance.call("get_oriented_dimensions_cells"))
	var orientation_basis: Basis = instance.call("get_orientation_basis")
	var anchor := Vector3i(instance.get("anchor_cell"))
	var cell_size := float(_grid.call("get_cell_size_m"))
	if cell_size <= 0.0:
		return
	var center := _get_block_local_center(anchor, oriented_dimensions, cell_size)
	var block_transform := Transform3D(orientation_basis, center)
	var full_size := Vector3(dimensions) * cell_size
	var local_offset := offset_cells * cell_size
	match presentation_shape:
		&"frame":
			_append_frame_primitives(transforms_by_batch, batch_metadata, material_id, block_transform, full_size, presentation_scale, local_offset)
		&"grating":
			_append_grating_primitives(transforms_by_batch, batch_metadata, material_id, block_transform, full_size, presentation_scale, local_offset)
		&"wedge":
			_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_WEDGE, block_transform, local_offset, full_size * presentation_scale)
		&"corner":
			_append_corner_primitives(transforms_by_batch, batch_metadata, material_id, block_transform, full_size, presentation_scale, local_offset)
		&"seat":
			_append_control_seat_primitives(transforms_by_batch, batch_metadata, material_id, block_transform, full_size, local_offset)
		&"thruster":
			_append_thruster_primitives(transforms_by_batch, batch_metadata, material_id, block_transform, full_size, local_offset)
		&"gyro":
			_append_gyro_primitives(transforms_by_batch, batch_metadata, material_id, block_transform, full_size, local_offset)
		&"battery":
			_append_battery_primitives(transforms_by_batch, batch_metadata, material_id, block_transform, full_size, local_offset)
		&"reactor":
			_append_reactor_primitives(transforms_by_batch, batch_metadata, material_id, block_transform, full_size, local_offset)
		_:
			_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset, full_size * presentation_scale)

func _append_frame_primitives(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, block_transform: Transform3D, full_size: Vector3, scale: Vector3, local_offset: Vector3) -> void:
	var thickness := maxf(minf(full_size.x, minf(full_size.y, full_size.z)) * maxf(scale.x, 0.04), 0.025)
	var x_positions: Array[float] = [-full_size.x * 0.5 + thickness * 0.5, full_size.x * 0.5 - thickness * 0.5]
	var y_positions: Array[float] = [-full_size.y * 0.5 + thickness * 0.5, full_size.y * 0.5 - thickness * 0.5]
	var z_positions: Array[float] = [-full_size.z * 0.5 + thickness * 0.5, full_size.z * 0.5 - thickness * 0.5]
	for y in y_positions:
		for z in z_positions:
			_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, y, z), Vector3(full_size.x, thickness, thickness))
	for x in x_positions:
		for z in z_positions:
			_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(x, 0.0, z), Vector3(thickness, full_size.y, thickness))
	for x in x_positions:
		for y in y_positions:
			_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(x, y, 0.0), Vector3(thickness, thickness, full_size.z))

func _append_grating_primitives(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, block_transform: Transform3D, full_size: Vector3, scale: Vector3, local_offset: Vector3) -> void:
	var height := maxf(full_size.y * scale.y, 0.02)
	var bar := maxf(minf(full_size.x, full_size.z) * 0.055, 0.025)
	var count := 5
	for index in count:
		var t := float(index) / float(count - 1) - 0.5
		var x := t * (full_size.x - bar)
		var z := t * (full_size.z - bar)
		_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(x, 0.0, 0.0), Vector3(bar, height, full_size.z))
		_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, 0.0, z), Vector3(full_size.x, height, bar))

func _append_corner_primitives(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, block_transform: Transform3D, full_size: Vector3, scale: Vector3, local_offset: Vector3) -> void:
	var thickness := maxf(minf(full_size.x, full_size.z) * maxf(scale.x, 0.06), 0.025)
	var x_offset := -full_size.x * 0.5 + thickness * 0.5
	var z_offset := -full_size.z * 0.5 + thickness * 0.5
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(x_offset, 0.0, 0.0), Vector3(thickness, full_size.y, full_size.z))
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, 0.0, z_offset), Vector3(full_size.x, full_size.y, thickness))

func _append_control_seat_primitives(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, block_transform: Transform3D, full_size: Vector3, local_offset: Vector3) -> void:
	var base_height := full_size.y * 0.16
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, -full_size.y * 0.34, 0.05 * full_size.z), Vector3(full_size.x * 0.72, base_height, full_size.z * 0.72))
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, -full_size.y * 0.12, full_size.z * 0.18), Vector3(full_size.x * 0.56, full_size.y * 0.22, full_size.z * 0.42))
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, full_size.y * 0.13, full_size.z * 0.34), Vector3(full_size.x * 0.58, full_size.y * 0.48, full_size.z * 0.12))
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, full_size.y * 0.05, -full_size.z * 0.28), Vector3(full_size.x * 0.74, full_size.y * 0.14, full_size.z * 0.16))
	_append_primitive(transforms_by_batch, batch_metadata, &"service_panel", PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, full_size.y * 0.13, -full_size.z * 0.37), Vector3(full_size.x * 0.44, full_size.y * 0.20, full_size.z * 0.05))

func _append_thruster_primitives(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, block_transform: Transform3D, full_size: Vector3, local_offset: Vector3) -> void:
	# Placeholder nozzle points toward local +Z while thrust acts toward local -Z.
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, 0.0, -full_size.z * 0.05), Vector3(full_size.x * 0.72, full_size.y * 0.72, full_size.z * 0.62))
	_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, 0.0, full_size.z * 0.31), Vector3(full_size.x * 0.88, full_size.y * 0.88, full_size.z * 0.18))
	_append_primitive(transforms_by_batch, batch_metadata, &"service_panel", PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, full_size.y * 0.34, -full_size.z * 0.12), Vector3(full_size.x * 0.42, full_size.y * 0.12, full_size.z * 0.38))
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, 0.0, -full_size.z * 0.40), Vector3(full_size.x * 0.38, full_size.y * 0.38, full_size.z * 0.16))

func _append_gyro_primitives(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, block_transform: Transform3D, full_size: Vector3, local_offset: Vector3) -> void:
	# Three-axis placeholder cage: dense core plus orthogonal flywheel housings.
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset, full_size * 0.38)
	_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset, Vector3(full_size.x * 0.82, full_size.y * 0.14, full_size.z * 0.14))
	_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset, Vector3(full_size.x * 0.14, full_size.y * 0.82, full_size.z * 0.14))
	_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset, Vector3(full_size.x * 0.14, full_size.y * 0.14, full_size.z * 0.82))
	_append_primitive(transforms_by_batch, batch_metadata, &"service_panel", PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, full_size.y * 0.31, -full_size.z * 0.31), Vector3(full_size.x * 0.34, full_size.y * 0.08, full_size.z * 0.24))

func _append_battery_primitives(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, block_transform: Transform3D, full_size: Vector3, local_offset: Vector3) -> void:
	# Original reservoir silhouette: recessed energy core inside four protective rails.
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset, Vector3(full_size.x * 0.58, full_size.y * 0.72, full_size.z * 0.58))
	var rail := full_size.x * 0.12
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset + Vector3(x_sign * full_size.x * 0.36, 0.0, z_sign * full_size.z * 0.36), Vector3(rail, full_size.y * 0.86, rail))

func _append_reactor_primitives(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, block_transform: Transform3D, full_size: Vector3, local_offset: Vector3) -> void:
	# Original sealed-core silhouette: luminous central chamber, cross-braced containment cage, and service cap.
	_append_primitive(transforms_by_batch, batch_metadata, material_id, PRIMITIVE_BOX, block_transform, local_offset, Vector3(full_size.x * 0.44, full_size.y * 0.70, full_size.z * 0.44))
	_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset, Vector3(full_size.x * 0.82, full_size.y * 0.12, full_size.z * 0.12))
	_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset, Vector3(full_size.x * 0.12, full_size.y * 0.82, full_size.z * 0.12))
	_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset, Vector3(full_size.x * 0.12, full_size.y * 0.12, full_size.z * 0.82))
	var post := full_size.x * 0.10
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_append_primitive(transforms_by_batch, batch_metadata, &"structure_heavy", PRIMITIVE_BOX, block_transform, local_offset + Vector3(x_sign * full_size.x * 0.36, 0.0, z_sign * full_size.z * 0.36), Vector3(post, full_size.y * 0.72, post))
	_append_primitive(transforms_by_batch, batch_metadata, &"service_panel", PRIMITIVE_BOX, block_transform, local_offset + Vector3(0.0, full_size.y * 0.40, 0.0), Vector3(full_size.x * 0.48, full_size.y * 0.08, full_size.z * 0.48))

func _append_primitive(transforms_by_batch: Dictionary, batch_metadata: Dictionary, material_id: StringName, primitive_kind: StringName, block_transform: Transform3D, local_position: Vector3, size: Vector3) -> void:
	var key := _batch_key(material_id, primitive_kind)
	if not transforms_by_batch.has(key):
		transforms_by_batch[key] = []
		batch_metadata[key] = {"material_id": material_id, "primitive_kind": primitive_kind}
	var local_transform := Transform3D(Basis.IDENTITY.scaled(size), local_position)
	(transforms_by_batch[key] as Array).append(block_transform * local_transform)

func _ensure_batch_node(key: String, material_id: StringName, primitive_kind: StringName) -> MultiMeshInstance3D:
	var existing := _batch_nodes.get(key) as MultiMeshInstance3D
	if existing != null:
		return existing
	var node := MultiMeshInstance3D.new()
	node.name = "Batch_%s_%s" % [_safe_node_token(String(material_id)), _safe_node_token(String(primitive_kind))]
	node.set_meta("voidforge_material_id", material_id)
	node.set_meta("voidforge_primitive_kind", primitive_kind)
	_geometry_root.add_child(node)
	_batch_nodes[key] = node
	return node

func _configure_batch(node: MultiMeshInstance3D, transforms: Array, material_id: StringName, primitive_kind: StringName) -> void:
	var multimesh := node.multimesh
	if multimesh == null:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh = multimesh
	multimesh.mesh = _mesh_for_primitive(primitive_kind)
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index] as Transform3D)
	node.material_override = _resolve_material(material_id)
	node.visible = transforms.size() > 0

func _mesh_for_primitive(primitive_kind: StringName) -> Mesh:
	if primitive_kind == PRIMITIVE_WEDGE:
		return _unit_wedge_mesh
	return _unit_box_mesh

func _batch_key(material_id: StringName, primitive_kind: StringName) -> String:
	return "%s|%s" % [String(material_id), String(primitive_kind)]

func _safe_node_token(value: String) -> String:
	return value.replace("/", "_").replace("|", "_").replace(" ", "_")

func _rebuild_grid_collision() -> void:
	if _collision_body == null:
		return
	for raw_owner_id in _collision_owner_to_instance.keys().duplicate():
		var owner_id := int(raw_owner_id)
		if owner_id in _collision_body.get_shape_owners():
			_collision_body.remove_shape_owner(owner_id)
	_collision_owner_to_instance.clear()
	_collision_instance_to_owner.clear()
	_collision_body.collision_layer = GRID_COLLISION_LAYER if render_collision else 0
	if not render_collision or _grid == null:
		_collision_rebuild_count += 1
		return
	for raw_instance in _grid.call("get_all_blocks"):
		var instance := raw_instance as Resource
		if instance == null:
			continue
		_add_block_collision_shape(instance)
	_collision_rebuild_count += 1

func _add_block_collision_shape(instance: Resource) -> void:
	var instance_id := int(instance.get("instance_id"))
	if instance_id <= 0:
		return
	var shape := _collision_shape_for_instance(instance)
	if shape == null:
		return
	var owner_id := _collision_body.create_shape_owner(self)
	_collision_body.shape_owner_set_transform(owner_id, _collision_transform_for_instance(instance))
	_collision_body.shape_owner_add_shape(owner_id, shape)
	_collision_owner_to_instance[owner_id] = instance_id
	_collision_instance_to_owner[instance_id] = owner_id

func _collision_transform_for_instance(instance: Resource) -> Transform3D:
	var dimensions := Vector3i(instance.get("dimensions_cells"))
	var oriented_dimensions := Vector3i(instance.call("get_oriented_dimensions_cells"))
	var orientation_basis: Basis = instance.call("get_orientation_basis")
	var anchor := Vector3i(instance.get("anchor_cell"))
	var cell_size := float(_grid.call("get_cell_size_m"))
	var definition := _resolve_definition(StringName(instance.get("block_id")))
	var presentation_shape := StringName(definition.get("presentation_shape")) if definition != null else &"box"
	var offset_cells := Vector3(definition.get("presentation_offset_cells")) if definition != null else Vector3.ZERO
	var center := _get_block_local_center(anchor, oriented_dimensions, cell_size)
	if presentation_shape in [&"beam", &"panel", &"grating", &"box", &"wedge", &"thruster", &"gyro", &"battery", &"reactor"]:
		center += orientation_basis * (offset_cells * cell_size)
	return Transform3D(orientation_basis, center)

func _collision_shape_for_instance(instance: Resource) -> Shape3D:
	var definition := _resolve_definition(StringName(instance.get("block_id")))
	var presentation_shape := StringName(definition.get("presentation_shape")) if definition != null else &"box"
	var presentation_scale := Vector3(definition.get("presentation_scale")) if definition != null else Vector3.ONE
	var dimensions := Vector3i(instance.get("dimensions_cells"))
	var cell_size := float(_grid.call("get_cell_size_m"))
	if cell_size <= 0.0:
		return null
	var full_size := Vector3(dimensions) * cell_size
	if presentation_shape == &"wedge":
		return _cached_wedge_shape(full_size * presentation_scale)
	if presentation_shape in [&"beam", &"panel", &"grating", &"box", &"thruster", &"gyro", &"battery", &"reactor"]:
		return _cached_box_shape(full_size * presentation_scale)
	# Open frame and corner presentation remains conservatively targetable as the full block footprint.
	return _cached_box_shape(full_size)

func _cached_box_shape(size: Vector3) -> BoxShape3D:
	var key := _collision_shape_cache_key(&"box", size)
	var existing := _collision_shape_cache.get(key) as BoxShape3D
	if existing != null:
		return existing
	var shape := BoxShape3D.new()
	shape.size = size
	_collision_shape_cache[key] = shape
	return shape

func _cached_wedge_shape(size: Vector3) -> ConvexPolygonShape3D:
	var key := _collision_shape_cache_key(&"wedge", size)
	var existing := _collision_shape_cache.get(key) as ConvexPolygonShape3D
	if existing != null:
		return existing
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz),
		Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz),
		Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz),
	])
	_collision_shape_cache[key] = shape
	return shape

func _collision_shape_cache_key(kind: StringName, size: Vector3) -> String:
	return "%s|%.5f|%.5f|%.5f" % [String(kind), size.x, size.y, size.z]

func _resolve_definition(block_id: StringName) -> Resource:
	if block_id != &"" and BlockDB.call("has_block", block_id):
		return BlockDB.call("get_block", block_id) as Resource
	return null

func _definition_for_instance_id(instance_id: int) -> Resource:
	if _grid == null:
		return null
	var instance := _grid.call("get_block_by_instance_id", instance_id) as Resource
	if instance == null:
		return null
	return _resolve_definition(StringName(instance.get("block_id")))

func _resolve_material(material_id: StringName) -> Material:
	match material_id:
		&"structure_frame":
			return STRUCTURE_FRAME_MATERIAL
		&"structure_heavy":
			return STRUCTURE_HEAVY_MATERIAL
		&"armor_light":
			return ARMOR_LIGHT_MATERIAL
		&"armor_heavy":
			return ARMOR_HEAVY_MATERIAL
		&"service_panel":
			return SERVICE_PANEL_MATERIAL
		&"grating":
			return GRATING_MATERIAL
		&"control_console":
			return CONTROL_MATERIAL
		&"propulsion":
			return PROPULSION_MATERIAL
		&"gyro":
			return GYRO_MATERIAL
		&"power_storage":
			return POWER_STORAGE_MATERIAL
		&"power_generation":
			return POWER_GENERATION_MATERIAL
		_:
			return DEV_STRUCTURE_MATERIAL

func _create_unit_wedge_mesh() -> ArrayMesh:
	var a := Vector3(-0.5, -0.5, -0.5)
	var b := Vector3(0.5, -0.5, -0.5)
	var c := Vector3(-0.5, -0.5, 0.5)
	var d := Vector3(0.5, -0.5, 0.5)
	var e := Vector3(-0.5, 0.5, -0.5)
	var f := Vector3(0.5, 0.5, -0.5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_triangle(surface, a, d, b)
	_add_triangle(surface, a, c, d)
	_add_triangle(surface, a, b, f)
	_add_triangle(surface, a, f, e)
	_add_triangle(surface, c, e, f)
	_add_triangle(surface, c, f, d)
	_add_triangle(surface, a, e, c)
	_add_triangle(surface, b, d, f)
	surface.generate_normals()
	return surface.commit() as ArrayMesh

func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

func _get_block_local_center(anchor: Vector3i, dimensions: Vector3i, cell_size: float) -> Vector3:
	var anchor_center := _grid.call("grid_to_local", anchor) as Vector3
	var offset_cells := Vector3(dimensions - Vector3i.ONE) * 0.5
	return anchor_center + offset_cells * cell_size

func _grid_block_count() -> int:
	if _grid == null:
		return 0
	return int(_grid.call("get_block_count"))
