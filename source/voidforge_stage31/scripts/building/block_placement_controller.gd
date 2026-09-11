extends Node3D
## Camera-centered construction controller with Stage 11 rotation and Stage 12 removal.
## Targeting stays grid-authoritative; placement/removal both operate on stable block instance state.

signal target_changed(grid: Node3D, cell: Vector3i, valid: bool)
signal removal_target_changed(grid: Node3D, instance_id: int)
signal block_placed(grid: Node3D, instance: Resource)
signal block_removed(grid: Node3D, instance: Resource)
signal placement_failed(reason: String)
signal removal_failed(reason: String)
signal orientation_changed(orientation_index: int)

const GHOST_SCENE := preload("res://scenes/building/placement_ghost.tscn")
const REMOVAL_HIGHLIGHT_SCENE := preload("res://scenes/building/removal_highlight.tscn")
const BLOCK_ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const GRID_COLLISION_MASK: int = 1 << 2

@export var camera_path: NodePath = NodePath("../CameraPivot/Camera3D")
@export var build_block_id: StringName = &"dev_hull_frame"
@export var build_block_definition: Resource
@export_range(1.0, 30.0, 0.25) var placement_range_m: float = 12.0
@export_flags_3d_physics var grid_collision_mask: int = GRID_COLLISION_MASK
@export var enabled: bool = true

var _camera: Camera3D
var _ghost: Node3D
var _removal_highlight: Node3D
var _target_grid: Node3D
var _target_cell: Vector3i = Vector3i.ZERO
var _target_face: Vector3i = Vector3i.ZERO
var _target_valid: bool = false
var _target_distance_m: float = 0.0
var _orientation_index: int = 0
var _removal_target_grid: Node3D
var _removal_target_instance_id: int = 0

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_ghost = GHOST_SCENE.instantiate() as Node3D
	_ghost.name = "PlacementGhost"
	add_child(_ghost)
	_ghost.visible = false
	_removal_highlight = REMOVAL_HIGHLIGHT_SCENE.instantiate() as Node3D
	_removal_highlight.name = "RemovalHighlight"
	add_child(_removal_highlight)
	_removal_highlight.visible = false
	if _camera == null:
		DebugLog.error("BuildController", "Camera path is invalid: %s" % camera_path)
		set_physics_process(false)
		return
	_resolve_exported_build_definition()
	if build_block_definition == null:
		DebugLog.warn("BuildController", "No build block definition assigned")

func _physics_process(_delta: float) -> void:
	if not enabled:
		_clear_target()
		return
	refresh_targeting()
	if Input.is_action_just_pressed("build_rotate"):
		rotate_preview_clockwise()
	if Input.is_action_just_pressed("build_place"):
		attempt_place()
	if Input.is_action_just_pressed("build_remove"):
		attempt_remove()

func set_build_definition(definition: Resource) -> void:
	build_block_definition = _canonicalize_definition(definition)
	build_block_id = StringName(build_block_definition.get("id")) if build_block_definition != null else &""
	refresh_targeting()

func set_build_block_id(block_id: StringName) -> bool:
	if block_id == &"" or not BlockDB.call("has_block", block_id):
		return false
	build_block_id = block_id
	build_block_definition = BlockDB.call("get_block", block_id) as Resource
	refresh_targeting()
	return build_block_definition != null

func get_build_block_id() -> StringName:
	if build_block_definition != null:
		return StringName(build_block_definition.get("id"))
	return build_block_id

func get_build_definition() -> Resource:
	return build_block_definition

func get_target_grid() -> Node3D:
	return _target_grid

func get_target_cell() -> Vector3i:
	return _target_cell

func get_target_face() -> Vector3i:
	return _target_face

func get_target_distance_m() -> float:
	return _target_distance_m

func is_target_valid() -> bool:
	return _target_valid

func get_ghost() -> Node3D:
	return _ghost

func get_removal_highlight() -> Node3D:
	return _removal_highlight

func get_removal_target_grid() -> Node3D:
	return _removal_target_grid

func get_removal_target_instance_id() -> int:
	return _removal_target_instance_id

func has_removal_target() -> bool:
	return _removal_target_grid != null and _removal_target_instance_id > 0

func get_orientation_index() -> int:
	return _orientation_index

func get_orientation_basis() -> Basis:
	return BLOCK_ORIENTATION.get_basis(_orientation_index)

func get_oriented_dimensions_cells() -> Vector3i:
	if build_block_definition == null:
		return Vector3i.ZERO
	return BLOCK_ORIENTATION.get_oriented_dimensions(
		Vector3i(build_block_definition.get("dimensions_cells")),
		_orientation_index
	)

func set_orientation_index(index: int) -> bool:
	if not BLOCK_ORIENTATION.is_valid_index(index):
		return false
	if index == _orientation_index:
		return true
	_orientation_index = index
	orientation_changed.emit(_orientation_index)
	refresh_targeting()
	return true

func reset_orientation() -> void:
	set_orientation_index(0)

func rotate_preview_clockwise() -> int:
	var rotation_axis := _target_face
	if rotation_axis == Vector3i.ZERO:
		rotation_axis = Vector3i(0, 1, 0)
	var next_index := BLOCK_ORIENTATION.rotate_index_around_axis(_orientation_index, rotation_axis, 1)
	if next_index != _orientation_index:
		_orientation_index = next_index
		orientation_changed.emit(_orientation_index)
		refresh_targeting()
	return _orientation_index

func refresh_targeting() -> void:
	if _camera == null or not is_instance_valid(_camera) or build_block_definition == null:
		_clear_target()
		return
	var origin := _camera.global_position
	var end := origin + (-_camera.global_transform.basis.z) * placement_range_m
	var query := PhysicsRayQueryParameters3D.create(origin, end, grid_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_clear_target()
		return
	var collider := hit.get("collider") as Object
	var grid := _resolve_grid_from_collider(collider)
	if grid == null:
		_clear_target()
		return
	var hit_position := Vector3(hit.get("position", Vector3.ZERO))
	var hit_normal := Vector3(hit.get("normal", Vector3.ZERO)).normalized()
	var candidate := compute_attachment_cell(grid, hit_position, hit_normal)
	var face := compute_grid_face(grid, hit_normal)
	var valid := bool(grid.call("can_place_block", build_block_definition, candidate, _orientation_index))
	_target_distance_m = origin.distance_to(hit_position)
	_set_target(grid, candidate, face, valid)
	var hit_shape_index := int(hit.get("shape", -1))
	_set_removal_target(grid, _resolve_instance_id_from_hit(collider, hit_shape_index))

func attempt_place() -> Resource:
	if not enabled or _target_grid == null:
		placement_failed.emit("No construction grid targeted.")
		return null
	if not _target_valid:
		placement_failed.emit("Target footprint is occupied or incompatible.")
		return null
	var instance := _target_grid.call("place_block", build_block_definition, _target_cell, _orientation_index) as Resource
	if instance == null:
		_target_valid = false
		_update_ghost()
		placement_failed.emit("Grid rejected placement.")
		return null
	block_placed.emit(_target_grid, instance)
	DebugLog.info(
		"BuildController",
		"Placed %s at %s on %s | orientation %d" % [
			String(build_block_definition.get("id")),
			str(_target_cell),
			String(_target_grid.call("get_grid_type")),
			_orientation_index,
		]
	)
	# Re-query after the physics server sees the presenter's new collider on the next frame.
	_target_valid = false
	_update_ghost()
	return instance

func attempt_remove() -> Resource:
	if not enabled or _removal_target_grid == null or _removal_target_instance_id <= 0:
		removal_failed.emit("No removable construction block targeted.")
		return null
	var grid := _removal_target_grid
	var instance_id := _removal_target_instance_id
	var instance := grid.call("get_block_by_instance_id", instance_id) as Resource
	if instance == null:
		_clear_removal_target()
		removal_failed.emit("Target block no longer exists.")
		return null
	var removed := grid.call("remove_block_by_instance_id", instance_id) as Resource
	if removed == null:
		removal_failed.emit("Grid rejected block removal.")
		return null
	block_removed.emit(grid, removed)
	DebugLog.info(
		"BuildController",
		"Removed %s instance %d from %s" % [
			String(removed.get("block_id")),
			instance_id,
			String(grid.call("get_grid_type")),
		]
	)
	# Stage 17 rebuilds the shared grid collision body's shapes after the grid signal. Clear
	# visual target immediately so there is never a one-frame stale removal selection.
	_clear_target()
	return removed

func compute_attachment_cell(grid: Node3D, hit_position: Vector3, hit_normal: Vector3) -> Vector3i:
	if grid == null or not grid.has_method("world_to_grid"):
		return Vector3i.ZERO
	var cell_size := float(grid.call("get_cell_size_m"))
	if cell_size <= 0.0 or hit_normal.length_squared() < 0.5:
		return Vector3i(grid.call("world_to_grid", hit_position))
	var sample_position := hit_position + hit_normal.normalized() * (cell_size * 0.52)
	return Vector3i(grid.call("world_to_grid", sample_position))

func compute_grid_face(grid: Node3D, world_normal: Vector3) -> Vector3i:
	if grid == null or world_normal.length_squared() < 0.5:
		return Vector3i.ZERO
	var local_normal := grid.global_transform.basis.inverse() * world_normal.normalized()
	var abs_normal := local_normal.abs()
	if abs_normal.x >= abs_normal.y and abs_normal.x >= abs_normal.z:
		return Vector3i(1 if local_normal.x >= 0.0 else -1, 0, 0)
	if abs_normal.y >= abs_normal.x and abs_normal.y >= abs_normal.z:
		return Vector3i(0, 1 if local_normal.y >= 0.0 else -1, 0)
	return Vector3i(0, 0, 1 if local_normal.z >= 0.0 else -1)

func _resolve_grid_from_collider(collider: Object) -> Node3D:
	if collider == null or not collider.has_meta("voidforge_block_grid"):
		return null
	var grid_variant = collider.get_meta("voidforge_block_grid")
	if grid_variant is Node3D and is_instance_valid(grid_variant):
		return grid_variant as Node3D
	return null

func _resolve_instance_id_from_hit(collider: Object, shape_index: int) -> int:
	if collider == null:
		return 0
	# Stage 10-16 compatibility path for any legacy per-block collider still present.
	if collider.has_meta("voidforge_block_instance_id"):
		return maxi(int(collider.get_meta("voidforge_block_instance_id", 0)), 0)
	# Stage 17+ grid collision uses one shared grid physics body with one shape owner per logical block.
	if collider.has_meta("voidforge_grid_collision_presenter"):
		var presenter_variant = collider.get_meta("voidforge_grid_collision_presenter")
		if presenter_variant is Node and is_instance_valid(presenter_variant):
			var presenter := presenter_variant as Node
			if presenter.has_method("resolve_block_instance_id_for_shape"):
				return maxi(int(presenter.call("resolve_block_instance_id_for_shape", shape_index)), 0)
	return 0

func _set_target(grid: Node3D, cell: Vector3i, face: Vector3i, valid: bool) -> void:
	var changed := grid != _target_grid or cell != _target_cell or face != _target_face or valid != _target_valid
	_target_grid = grid
	_target_cell = cell
	_target_face = face
	_target_valid = valid
	_update_ghost()
	if changed:
		target_changed.emit(_target_grid, _target_cell, _target_valid)

func _set_removal_target(grid: Node3D, instance_id: int) -> void:
	if grid == null or instance_id <= 0 or grid.call("get_block_by_instance_id", instance_id) == null:
		_clear_removal_target()
		return
	var changed := grid != _removal_target_grid or instance_id != _removal_target_instance_id
	_removal_target_grid = grid
	_removal_target_instance_id = instance_id
	_update_removal_highlight()
	if changed:
		removal_target_changed.emit(_removal_target_grid, _removal_target_instance_id)

func _clear_target() -> void:
	var had_target := _target_grid != null
	_target_grid = null
	_target_cell = Vector3i.ZERO
	_target_face = Vector3i.ZERO
	_target_valid = false
	_target_distance_m = 0.0
	if _ghost != null:
		_ghost.visible = false
	_clear_removal_target()
	if had_target:
		target_changed.emit(null, Vector3i.ZERO, false)

func _clear_removal_target() -> void:
	var had_target := _removal_target_grid != null or _removal_target_instance_id > 0
	_removal_target_grid = null
	_removal_target_instance_id = 0
	if _removal_highlight != null:
		_removal_highlight.call("clear_target")
	if had_target:
		removal_target_changed.emit(null, 0)

func _update_ghost() -> void:
	if _ghost == null:
		return
	if _target_grid == null or build_block_definition == null:
		_ghost.visible = false
		return
	var base_dimensions := Vector3i(build_block_definition.get("dimensions_cells"))
	var oriented_dimensions := BLOCK_ORIENTATION.get_oriented_dimensions(base_dimensions, _orientation_index)
	var cell_size := float(_target_grid.call("get_cell_size_m"))
	var local_anchor := _target_grid.call("grid_to_local", _target_cell) as Vector3
	var local_center := local_anchor + Vector3(oriented_dimensions - Vector3i.ONE) * (cell_size * 0.5)
	var world_center := _target_grid.to_global(local_center)
	var grid_basis := _target_grid.global_transform.basis.orthonormalized()
	var orientation_basis := BLOCK_ORIENTATION.get_basis(_orientation_index)
	_ghost.global_transform = Transform3D(grid_basis * orientation_basis, world_center)
	_ghost.call("set_preview", Vector3(base_dimensions) * cell_size, _target_valid)
	_ghost.visible = true

func _update_removal_highlight() -> void:
	if _removal_highlight == null:
		return
	if _removal_target_grid == null or _removal_target_instance_id <= 0:
		_removal_highlight.call("clear_target")
		return
	var instance := _removal_target_grid.call("get_block_by_instance_id", _removal_target_instance_id) as Resource
	if instance == null:
		_removal_highlight.call("clear_target")
		return
	var base_dimensions := Vector3i(instance.get("dimensions_cells"))
	var oriented_dimensions := Vector3i(instance.call("get_oriented_dimensions_cells"))
	var orientation_basis: Basis = instance.call("get_orientation_basis")
	var anchor := Vector3i(instance.get("anchor_cell"))
	var cell_size := float(_removal_target_grid.call("get_cell_size_m"))
	var local_anchor := _removal_target_grid.call("grid_to_local", anchor) as Vector3
	var local_center := local_anchor + Vector3(oriented_dimensions - Vector3i.ONE) * (cell_size * 0.5)
	var world_center := _removal_target_grid.to_global(local_center)
	var grid_basis := _removal_target_grid.global_transform.basis.orthonormalized()
	_removal_highlight.global_transform = Transform3D(grid_basis * orientation_basis, world_center)
	_removal_highlight.call("set_target", Vector3(base_dimensions) * cell_size)

func _resolve_exported_build_definition() -> void:
	if build_block_id != &"" and BlockDB.call("has_block", build_block_id):
		build_block_definition = BlockDB.call("get_block", build_block_id) as Resource
		return
	build_block_definition = _canonicalize_definition(build_block_definition)
	if build_block_definition != null:
		build_block_id = StringName(build_block_definition.get("id"))

func _canonicalize_definition(definition: Resource) -> Resource:
	if definition == null:
		return null
	var block_id := StringName(definition.get("id"))
	if block_id != &"" and BlockDB.call("has_block", block_id):
		return BlockDB.call("get_block", block_id) as Resource
	return definition
