extends Node
## Composition-based interaction contract used by raycastable world objects.
## Parent collision bodies stay free to use whatever physics type they need.

signal interaction_requested(actor: Node)
signal focus_changed(focused: bool, actor: Node)

@export var prompt_text: String = "Interact"
@export var interaction_enabled: bool = true

var _focused: bool = false

func _ready() -> void:
	add_to_group("interactable")

func can_interact(_actor: Node) -> bool:
	return interaction_enabled

func get_interaction_prompt(_actor: Node) -> String:
	return prompt_text

func interact(actor: Node) -> bool:
	if not can_interact(actor):
		return false
	interaction_requested.emit(actor)
	return true

func set_focused(focused: bool, actor: Node) -> void:
	if _focused == focused:
		return
	_focused = focused
	focus_changed.emit(focused, actor)

func is_focused() -> bool:
	return _focused
