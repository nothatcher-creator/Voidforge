extends RayCast3D
## Camera-centered interaction query. The ray only checks the Interactable physics layer.

signal target_changed(target: Node)
signal interaction_performed(target: Node)
signal interaction_rejected(target: Node)

@export_range(0.5, 12.0, 0.1) var interaction_range_m: float = 4.0
@export var actor_path: NodePath = NodePath("../../..")

var _actor: Node
var _current_target: Node

func _ready() -> void:
	_actor = get_node_or_null(actor_path)
	enabled = true
	collide_with_bodies = true
	collide_with_areas = true
	target_position = Vector3(0.0, 0.0, -interaction_range_m)

func _exit_tree() -> void:
	_set_target(null)

func _physics_process(_delta: float) -> void:
	if not is_equal_approx(absf(target_position.z), interaction_range_m):
		target_position = Vector3(0.0, 0.0, -interaction_range_m)

	force_raycast_update()
	var resolved := _resolve_interactable(get_collider()) if is_colliding() else null
	_set_target(resolved)

	if Input.is_action_just_pressed("interact"):
		attempt_interaction()

func get_current_target() -> Node:
	return _current_target

func has_target() -> bool:
	return is_instance_valid(_current_target)

func can_interact_with_current() -> bool:
	if not has_target():
		return false
	if not _current_target.has_method("can_interact"):
		return false
	return bool(_current_target.call("can_interact", _actor))

func get_current_prompt() -> String:
	if not has_target() or not _current_target.has_method("get_interaction_prompt"):
		return ""
	return str(_current_target.call("get_interaction_prompt", _actor))

func attempt_interaction() -> bool:
	if not has_target():
		interaction_rejected.emit(null)
		return false
	if not can_interact_with_current():
		interaction_rejected.emit(_current_target)
		return false
	var accepted := bool(_current_target.call("interact", _actor))
	if accepted:
		interaction_performed.emit(_current_target)
	else:
		interaction_rejected.emit(_current_target)
	return accepted

func _resolve_interactable(collider: Object) -> Node:
	if collider == null or not collider is Node:
		return null
	var node := collider as Node
	if _is_interaction_contract(node):
		return node

	for child in node.get_children():
		if child is Node and child.is_in_group("interactable") and _is_interaction_contract(child):
			return child

	var parent := node.get_parent()
	var depth := 0
	while parent != null and depth < 3:
		if _is_interaction_contract(parent):
			return parent
		for child in parent.get_children():
			if child is Node and child.is_in_group("interactable") and _is_interaction_contract(child):
				return child
		parent = parent.get_parent()
		depth += 1
	return null

func _is_interaction_contract(node: Node) -> bool:
	return node.has_method("can_interact") \
		and node.has_method("get_interaction_prompt") \
		and node.has_method("interact")

func _set_target(next_target: Node) -> void:
	if next_target == _current_target:
		return
	if is_instance_valid(_current_target) and _current_target.has_method("set_focused"):
		_current_target.call("set_focused", false, _actor)
	_current_target = next_target
	if is_instance_valid(_current_target) and _current_target.has_method("set_focused"):
		_current_target.call("set_focused", true, _actor)
	target_changed.emit(_current_target)
