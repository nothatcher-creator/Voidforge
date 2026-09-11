class_name HandDrillController
extends Node3D
## Stage 31 reusable held-tool controller for the Field Bore Drill.

signal drill_started(target: Node)
signal drill_stopped(target: Node)
signal drill_tick(target: Node, work_amount: float)
signal target_changed(target: Node)

const DRILL_ITEM_ID: StringName = &"tool_field_bore_drill"
const MINEABLE_COLLISION_MASK: int = 64

@export var camera_path: NodePath = NodePath("../CameraPivot/Camera3D")
@export var hotbar_path: NodePath = NodePath("../Hotbar")
@export var player_path: NodePath = NodePath("..")
@export_range(0.02, 1.0, 0.01) var tick_interval_s: float = 0.10

@onready var camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var hotbar: Node = get_node_or_null(hotbar_path)
@onready var player: Node = get_node_or_null(player_path)
@onready var drill_beam: MeshInstance3D = $DrillBeam

var _target: Node
var _active_target: Node
var _tick_accumulator_s: float = 0.0
var _is_drilling: bool = false
var _last_work_amount: float = 0.0

func _ready() -> void:
	if is_instance_valid(drill_beam):
		drill_beam.visible = false

func _physics_process(delta: float) -> void:
	_refresh_target()
	var wants_use := Input.is_action_pressed("tool_use")
	var can_use := wants_use and can_use_equipped_drill() and _target != null and not _is_gameplay_blocked()
	if not can_use:
		_stop_drilling()
		return
	if not _is_drilling or _active_target != _target:
		_stop_drilling()
		_start_drilling(_target)
	_tick_accumulator_s += delta
	while _tick_accumulator_s + 0.000001 >= tick_interval_s:
		_tick_accumulator_s -= tick_interval_s
		_apply_drill_tick(tick_interval_s)

func can_use_equipped_drill() -> bool:
	if hotbar == null or not hotbar.has_method("get_selected_item_id") or not hotbar.has_method("is_selected_item_available"):
		return false
	if StringName(hotbar.call("get_selected_item_id")) != DRILL_ITEM_ID:
		return false
	if not bool(hotbar.call("is_selected_item_available")):
		return false
	return _get_drill_definition() != null

func get_current_target() -> Node:
	return _target if is_instance_valid(_target) else null

func get_current_target_name() -> String:
	var target := get_current_target()
	if target == null:
		return ""
	if target.has_method("get_drill_target_name"):
		return String(target.call("get_drill_target_name"))
	return target.name

func is_drilling() -> bool:
	return _is_drilling

func get_tool_state() -> Dictionary:
	var definition := _get_drill_definition()
	return {
		"equipped": can_use_equipped_drill(),
		"item_id": DRILL_ITEM_ID,
		"target": get_current_target(),
		"target_name": get_current_target_name(),
		"drilling": _is_drilling,
		"range_m": float(definition.get("tool_range_m")) if definition != null else 0.0,
		"work_rate_per_s": float(definition.get("tool_work_rate_per_s")) if definition != null else 0.0,
		"last_work_amount": _last_work_amount,
	}

func force_probe() -> void:
	_refresh_target()

func _refresh_target() -> void:
	var previous := _target
	_target = _probe_target()
	if previous != _target:
		target_changed.emit(_target)
		if _is_drilling and _active_target != _target:
			_stop_drilling()

func _probe_target() -> Node:
	if camera == null or not can_use_equipped_drill() or _is_gameplay_blocked():
		return null
	var definition := _get_drill_definition()
	if definition == null:
		return null
	var max_range := float(definition.get("tool_range_m"))
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * max_range)
	var query := PhysicsRayQueryParameters3D.create(from, to, MINEABLE_COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [player] if player is CollisionObject3D else []
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider := result.get("collider") as Node
	if collider != null and collider.has_method("can_receive_drill_work") and bool(collider.call("can_receive_drill_work", self)):
		return collider
	return null

func _start_drilling(target: Node) -> void:
	_is_drilling = true
	_active_target = target
	_tick_accumulator_s = 0.0
	_last_work_amount = 0.0
	if is_instance_valid(drill_beam):
		drill_beam.visible = true
	drill_started.emit(target)

func _stop_drilling() -> void:
	if not _is_drilling:
		if is_instance_valid(drill_beam):
			drill_beam.visible = false
		return
	var previous := _active_target
	_is_drilling = false
	_active_target = null
	_tick_accumulator_s = 0.0
	if is_instance_valid(drill_beam):
		drill_beam.visible = false
	drill_stopped.emit(previous)

func _apply_drill_tick(duration_s: float) -> void:
	if not is_instance_valid(_active_target):
		_stop_drilling()
		return
	var definition := _get_drill_definition()
	if definition == null:
		_stop_drilling()
		return
	var amount := float(definition.get("tool_work_rate_per_s")) * duration_s
	var accepted := amount
	if _active_target.has_method("apply_drill_work"):
		accepted = float(_active_target.call("apply_drill_work", amount, self))
	else:
		accepted = 0.0
	_last_work_amount = accepted
	if accepted > 0.0:
		drill_tick.emit(_active_target, accepted)

func _get_drill_definition() -> Resource:
	var item_db := get_node_or_null("/root/ItemDB")
	if item_db == null or not bool(item_db.call("has_item", DRILL_ITEM_ID)):
		return null
	var definition := item_db.call("get_item", DRILL_ITEM_ID) as Resource
	if definition == null or StringName(definition.get("tool_type")) != &"hand_drill":
		return null
	return definition

func _is_gameplay_blocked() -> bool:
	if player == null:
		return false
	if player.has_method("is_ui_input_locked") and bool(player.call("is_ui_input_locked")):
		return true
	if player.has_method("is_in_control_seat") and bool(player.call("is_in_control_seat")):
		return true
	return false
