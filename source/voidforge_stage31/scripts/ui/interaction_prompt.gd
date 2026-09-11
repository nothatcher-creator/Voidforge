extends Control
## Minimal target prompt driven by the player's interaction raycast.

@export var interactor_path: NodePath

@onready var prompt_label: Label = $Panel/Margin/PromptLabel

var _interactor: Node
var _last_text: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not interactor_path.is_empty():
		bind_interactor(get_node_or_null(interactor_path))
	visible = false

func bind_interactor(interactor: Node) -> void:
	_interactor = interactor
	_refresh_prompt()

func _process(_delta: float) -> void:
	_refresh_prompt()

func _refresh_prompt() -> void:
	if _interactor == null or not is_instance_valid(_interactor):
		visible = false
		return
	if not _interactor.has_method("has_target") or not bool(_interactor.call("has_target")):
		visible = false
		return
	if not _interactor.has_method("can_interact_with_current") or not bool(_interactor.call("can_interact_with_current")):
		visible = false
		return
	var prompt := str(_interactor.call("get_current_prompt"))
	if prompt.is_empty():
		visible = false
		return
	var display_text := "INTERACT  •  %s" % prompt
	if display_text != _last_text:
		_last_text = display_text
		prompt_label.text = display_text
	visible = true
