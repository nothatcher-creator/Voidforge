class_name ControlSeatInteraction
extends Area3D
## Runtime interaction proxy for one functional control-seat block on a BlockGrid.
## The proxy moves with its parent grid and delegates pilot authority to the grid itself.

signal focus_changed(focused: bool, actor: Node)
signal pilot_state_changed(pilot: Node)

const INTERACTABLE_LAYER: int = 1 << 3
const DEFAULT_PLAYER_CAMERA_PIVOT_HEIGHT_M: float = 0.65

var _grid: Node3D
var _instance_id: int = 0
var _block_id: StringName
var _display_name: String = "Control Seat"
var _focused: bool = false
var _cell_size_m: float = 1.0
var _collision_shape: CollisionShape3D

func _init() -> void:
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	input_ray_pickable = false

func _ready() -> void:
	add_to_group("interactable")

func configure(grid: Node3D, instance: Resource, definition: Resource) -> bool:
	if grid == null or instance == null or definition == null:
		return false
	if not grid.has_method("get_cell_size_m") or not instance.has_method("get_orientation_basis"):
		return false
	_grid = grid
	_instance_id = int(instance.get("instance_id"))
	_block_id = StringName(instance.get("block_id"))
	_display_name = String(grid.call("get_block_effective_display_name", _instance_id)) if grid.has_method("get_block_effective_display_name") else str(definition.get("display_name"))
	_cell_size_m = maxf(float(grid.call("get_cell_size_m")), 0.001)
	name = "ControlSeat_%d" % _instance_id
	transform = _calculate_local_transform(instance)
	_ensure_collision_shape(instance)
	return _instance_id > 0 and _block_id != &""

func get_controlled_grid() -> Node3D:
	return _grid

func get_block_instance_id() -> int:
	return _instance_id

func get_block_id() -> StringName:
	return _block_id

func get_pilot() -> Node:
	if not is_instance_valid(_grid) or not _grid.has_method("get_active_pilot"):
		return null
	return _grid.call("get_active_pilot") as Node

func has_pilot() -> bool:
	return is_instance_valid(get_pilot())

func can_interact(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if not actor.has_method("enter_control_seat"):
		return false
	if not is_instance_valid(_grid) or not _grid.has_method("can_claim_manual_control"):
		return false
	if _grid.has_method("is_block_enabled") and not bool(_grid.call("is_block_enabled", _instance_id)):
		return false
	return bool(_grid.call("can_claim_manual_control", actor, _instance_id))

func get_interaction_prompt(actor: Node) -> String:
	if is_instance_valid(_grid) and _grid.has_method("is_block_enabled") and not bool(_grid.call("is_block_enabled", _instance_id)):
		return "%s disabled" % _display_name
	var pilot := get_pilot()
	if pilot == actor:
		return "%s already occupied" % _display_name
	if is_instance_valid(pilot):
		return "%s occupied" % _display_name
	return "Enter %s" % _display_name

func interact(actor: Node) -> bool:
	if not can_interact(actor):
		return false
	var accepted := bool(actor.call("enter_control_seat", self))
	if accepted:
		pilot_state_changed.emit(actor)
	return accepted

func set_focused(focused: bool, actor: Node) -> void:
	if _focused == focused:
		return
	_focused = focused
	focus_changed.emit(focused, actor)

func is_focused() -> bool:
	return _focused

func try_claim_pilot(actor: Node) -> bool:
	if not is_instance_valid(_grid) or not _grid.has_method("try_claim_manual_control"):
		return false
	var accepted := bool(_grid.call("try_claim_manual_control", actor, _instance_id))
	if accepted:
		pilot_state_changed.emit(actor)
	return accepted

func release_pilot(actor: Node) -> bool:
	if not is_instance_valid(_grid) or not _grid.has_method("release_manual_control"):
		return false
	var released := bool(_grid.call("release_manual_control", actor))
	if released:
		pilot_state_changed.emit(null)
	return released

func get_pilot_body_transform_global() -> Transform3D:
	var seat_basis := global_transform.basis.orthonormalized()
	var eye_origin := global_transform.origin \
		+ seat_basis.y * (_cell_size_m * 0.18) \
		+ seat_basis.z * (_cell_size_m * 0.08)
	var body_origin := eye_origin - seat_basis.y * DEFAULT_PLAYER_CAMERA_PIVOT_HEIGHT_M
	return Transform3D(seat_basis, body_origin)

func get_exit_transform_global() -> Transform3D:
	var seat_basis := global_transform.basis.orthonormalized()
	var exit_origin := global_transform.origin \
		+ seat_basis.x * (_cell_size_m * 0.85) \
		+ seat_basis.y * (_cell_size_m * 0.28)
	return Transform3D(seat_basis, exit_origin)

func _calculate_local_transform(instance: Resource) -> Transform3D:
	var anchor := Vector3i(instance.get("anchor_cell"))
	var oriented_dimensions := Vector3i(instance.call("get_oriented_dimensions_cells"))
	var orientation_basis: Basis = instance.call("get_orientation_basis")
	var anchor_center := _grid.call("grid_to_local", anchor) as Vector3
	var extent_offset := Vector3(oriented_dimensions - Vector3i.ONE) * (_cell_size_m * 0.5)
	return Transform3D(orientation_basis, anchor_center + extent_offset)

func _ensure_collision_shape(instance: Resource) -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "SeatInteractionShape"
		add_child(_collision_shape)
	var base_dimensions := Vector3i(instance.get("dimensions_cells"))
	var shape := BoxShape3D.new()
	var full_size := Vector3(base_dimensions) * _cell_size_m
	shape.size = Vector3(
		maxf(full_size.x * 0.72, 0.25),
		maxf(full_size.y * 0.72, 0.25),
		maxf(full_size.z * 0.72, 0.25)
	)
	_collision_shape.shape = shape
