extends Node
## Headless integration checks for Stage 5 camera raycast interaction and prompt/input bridges.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const TARGET_SCENE := preload("res://scenes/interaction/test_interactable.tscn")
const PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")

var _failures: Array[String] = []
var _player: CharacterBody3D
var _interactor: RayCast3D
var _target: StaticBody3D
var _interaction: Node
var _prompt: Control
var _touch_controls: Control

func _ready() -> void:
	_build_test_world()
	await get_tree().process_frame
	await _physics_frames(45)
	await _run_checks()

func _run_checks() -> void:
	_assert(_player.is_on_floor(), "Player settles before interaction tests")
	await _physics_frames(2)
	_assert(bool(_interactor.call("has_target")), "Centered ray acquires near interactable")
	_assert(str(_interactor.call("get_current_prompt")) == "Enable test relay", "Near target exposes interaction prompt")
	_assert(bool(_interaction.call("is_focused")), "Focused target receives focus state")
	await get_tree().process_frame
	_assert(_prompt.visible, "Interaction prompt UI becomes visible for usable target")
	_assert("Enable test relay" in _prompt.get_node("Panel/Margin/PromptLabel").text, "Prompt UI reflects target text")

	var accepted := bool(_interactor.call("attempt_interaction"))
	_assert(accepted, "Direct interaction attempt is accepted")
	_assert(int(_target.call("get_interaction_count")) == 1, "Interactable receives interaction request")
	_assert(bool(_target.call("is_active")), "Functional test target changes state")
	_assert(str(_interactor.call("get_current_prompt")) == "Disable test relay", "Prompt updates after target state change")

	Input.action_press("interact")
	await _physics_frames(1)
	Input.action_release("interact")
	await _physics_frames(1)
	_assert(int(_target.call("get_interaction_count")) == 2, "Shared InputMap interact action triggers raycast interaction")

	_target.global_position = Vector3(0.0, 0.9, -2.0)
	await _physics_frames(2)
	_assert(not bool(_interactor.call("has_target")), "Target beyond interaction range is rejected")
	await _process_frames(2)
	_assert(not _prompt.visible, "Prompt hides when target leaves range")

	_target.global_position = Vector3(3.0, 0.9, 0.0)
	await _physics_frames(2)
	_assert(not bool(_interactor.call("has_target")), "Off-axis target produces a raycast miss")

	_target.global_position = Vector3(0.0, 0.9, 0.0)
	_interaction.set("interaction_enabled", false)
	await _physics_frames(2)
	_assert(bool(_interactor.call("has_target")), "Disabled interactable can still be focused")
	_assert(not bool(_interactor.call("can_interact_with_current")), "Disabled interactable rejects interaction")
	var count_before_reject := int(_target.call("get_interaction_count"))
	_assert(not bool(_interactor.call("attempt_interaction")), "Rejected target reports failed interaction")
	_assert(int(_target.call("get_interaction_count")) == count_before_reject, "Rejected interaction does not mutate target")

	_interaction.set("interaction_enabled", true)
	await _physics_frames(2)
	var interact_button := _touch_controls.get_node("InteractButton") as Control
	var button_center := interact_button.get_global_rect().get_center()
	_send_touch(interact_button, 12, button_center, true)
	await _physics_frames(1)
	_send_touch(interact_button, 12, button_center, false)
	await _physics_frames(1)
	_assert(int(_target.call("get_interaction_count")) == count_before_reject + 1, "Touch USE button triggers shared interact action")

	if _failures.is_empty():
		print("STAGE5_INTERACTION_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE5_INTERACTION_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _build_test_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 63
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(24.0, 0.5, 24.0)
	floor_shape.position = Vector3(0.0, -0.25, 0.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)

	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_player.position = Vector3(0.0, 1.1, 3.0)
	add_child(_player)
	_interactor = _player.get_node("CameraPivot/Camera3D/PlayerInteractor") as RayCast3D

	_target = TARGET_SCENE.instantiate() as StaticBody3D
	_target.position = Vector3(0.0, 0.9, 0.0)
	add_child(_target)
	_interaction = _target.get_node("Interaction")

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_prompt = PROMPT_SCENE.instantiate() as Control
	canvas.add_child(_prompt)
	_prompt.call("bind_interactor", _interactor)

	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)

func _send_touch(target: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	target.call("handle_screen_event", event)

func _physics_frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame

func _process_frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
