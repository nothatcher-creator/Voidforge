extends StaticBody3D
## Stage 5 functional target used to verify focus, prompts, interaction and state changes.

@onready var interaction: Node = $Interaction
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var status_label: Label3D = $StatusLabel

@export var starts_active: bool = false

var _active: bool = false
var _interaction_count: int = 0

func _ready() -> void:
	_active = starts_active
	interaction.connect("interaction_requested", _on_interaction_requested)
	interaction.connect("focus_changed", _on_focus_changed)
	_refresh_state()

func get_interaction_count() -> int:
	return _interaction_count

func is_active() -> bool:
	return _active

func _on_interaction_requested(_actor: Node) -> void:
	_interaction_count += 1
	_active = not _active
	_refresh_state()
	DebugLog.info("Interaction", "Development relay toggled | active=%s | count=%d" % [_active, _interaction_count])

func _on_focus_changed(focused: bool, _actor: Node) -> void:
	mesh_instance.scale = Vector3.ONE * (1.04 if focused else 1.0)

func _refresh_state() -> void:
	interaction.set("prompt_text", "Disable test relay" if _active else "Enable test relay")
	status_label.text = "RELAY: ON" if _active else "RELAY: OFF"
