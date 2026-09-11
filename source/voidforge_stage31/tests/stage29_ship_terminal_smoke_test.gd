extends Node
## Stage 29 deterministic terminal regression: filtering/search, live grid/power inspection,
## selection details, gameplay input locking, grid mutation refresh, and Android TERM control.

const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")
const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")
const TERMINAL_SCENE := preload("res://scenes/ui/ship_terminal_ui.tscn")

var _failures: Array[String] = []
var _grid: RigidBody3D
var _presenter: Node3D
var _player: CharacterBody3D
var _touch_controls: Control
var _terminal: Control
var _ids: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	_build_grid()
	_build_player_and_ui()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(InputMap.has_action("ship_terminal"), "Stage 29 shared ship_terminal InputMap action exists")
	_assert(int(_grid.call("get_block_count")) == 8, "Terminal fixture contains eight installed blocks across mixed categories")
	_assert(is_equal_approx(float(_grid.call("get_total_mass_kg")), 4230.0), "Terminal fixture mass is authoritative 4230 kg")

	_assert(bool(_terminal.call("open_terminal", _grid)), "Terminal opens against an explicit compatible construction grid")
	await get_tree().process_frame
	_assert(bool(_terminal.call("is_terminal_open")), "Terminal reports open state")
	_assert(bool(_player.call("is_ui_input_locked")), "Opening terminal locks player/vehicle gameplay input")
	_assert(bool(_touch_controls.call("is_external_ui_blocked")), "Opening terminal blocks and clears the mobile control HUD")
	_assert((_terminal.call("get_visible_block_instance_ids") as Array).size() == 8, "ALL category lists all eight installed block instances")

	_assert(bool(_terminal.call("set_category", &"power")), "POWER terminal category is selectable")
	_assert((_terminal.call("get_visible_block_instance_ids") as Array).size() == 3, "POWER category shows reactor, battery, and auxiliary load")
	_terminal.call("set_search_query", "reactor")
	_assert((_terminal.call("get_visible_block_instance_ids") as Array).size() == 1, "Search filters the installed block list by display name/function/ID")
	_assert(int((_terminal.call("get_visible_block_instance_ids") as Array)[0]) == int(_ids[&"helix_core_reactor_large"]), "Reactor search resolves the exact installed reactor instance")

	_assert(bool(_terminal.call("select_block", int(_ids[&"helix_core_reactor_large"]))), "Installed reactor instance can be selected")
	var reactor_details := String(_terminal.call("get_selected_detail_text"))
	_assert("helix_core_reactor_large" in reactor_details and "480.0 kW" in reactor_details and "REACTOR" in reactor_details, "Selected-block panel exposes authoritative reactor identity and power generation")
	var power_summary := String(_terminal.call("get_power_summary_text"))
	var battery_summary := String(_terminal.call("get_battery_summary_text"))
	var grid_summary := String(_terminal.call("get_grid_summary_text"))
	_assert("GEN 480 kW" in power_summary and "ACTIVE 60 kW" in power_summary, "Live terminal power header reports actual 480 kW generation and current 60 kW active load")
	_assert("BATTERY  1" in battery_summary and "60.0 kWh" in battery_summary, "Live terminal battery header reports installed storage count/capacity")
	_assert("8 blocks" in grid_summary and "4230 kg" in grid_summary, "Live grid header reports block count and authoritative ship mass")

	_terminal.call("set_search_query", "")
	_terminal.call("set_category", &"control")
	_assert((_terminal.call("get_visible_block_instance_ids") as Array).size() == 2, "CONTROL category lists Pilot Cradle and Vector Gyro")
	_assert(bool(_terminal.call("select_block", int(_ids[&"vector_gyro_large"]))), "Vector Gyro instance can be selected")
	var gyro_details := String(_terminal.call("get_selected_detail_text"))
	_assert("vector_gyro_large" in gyro_details and "HIGH" in gyro_details and "90.0 kW" in gyro_details, "Selected gyro details expose high priority and rated power demand")

	# Mutating the live grid must be visible to the terminal without rebuilding the UI architecture.
	var thruster := BlockDB.call("get_block", &"pulse_thruster_large") as Resource
	var second_thruster := _grid.call("place_block", thruster, Vector3i(0, 0, 2), 0) as Resource
	_assert(second_thruster != null, "A new propulsion block can be added while the terminal query layer exists")
	_terminal.call("set_category", &"propulsion")
	_terminal.call("refresh_now")
	_assert((_terminal.call("get_visible_block_instance_ids") as Array).size() == 2, "Terminal refresh reflects live grid mutation and two installed thrusters")
	_terminal.call("set_search_query", "pulse_thruster")
	_assert((_terminal.call("get_visible_block_instance_ids") as Array).size() == 2, "Search matches stable BlockDB IDs across multiple installed instances")

	_terminal.call("close_terminal")
	await get_tree().process_frame
	_assert(not bool(_terminal.call("is_terminal_open")), "Close action hides the terminal")
	_assert(not bool(_player.call("is_ui_input_locked")), "Closing terminal restores gameplay input")
	_assert(not bool(_touch_controls.call("is_external_ui_blocked")) and _touch_controls.visible, "Closing terminal restores the mobile HUD in test-preview mode")

	# Enter the actual Pilot Cradle, then open the terminal through the Android TERM touch action.
	_presenter.call("flush_collision_now")
	_presenter.call("flush_geometry_now")
	var seat_presenter := _presenter.call("get_control_seat_presenter") as Node3D
	seat_presenter.call("flush_now")
	var seat_id := int(_ids[&"pilot_cradle_large"])
	var seat_proxy := seat_presenter.call("get_control_seat", seat_id) as Area3D
	_assert(seat_proxy != null and bool(_player.call("enter_control_seat", seat_proxy)), "Player enters the real Pilot Cradle for terminal touch-context testing")
	await get_tree().process_frame
	await get_tree().process_frame
	var terminal_button := _touch_controls.get_node("TerminalButton") as Control
	_assert(terminal_button.visible, "Android TERM button is contextual and visible while seated")
	var terminal_center := terminal_button.get_global_rect().get_center()
	_send_touch(terminal_button, 291, terminal_center, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(bool(_terminal.call("is_terminal_open")), "Android TERM touch opens the same ship terminal through shared InputMap state")
	_assert(_terminal.call("get_managed_grid") == _grid, "When seated, terminal resolves the player's physically controlled grid")
	_assert(bool(_player.call("is_ui_input_locked")) and bool(_touch_controls.call("is_external_ui_blocked")), "TERM touch transitions cleanly into terminal input ownership")
	_assert(not Input.is_action_pressed("ship_terminal"), "TERM action cannot remain stuck when opening hides/clears its touch button")

	_terminal.call("close_terminal")
	await get_tree().process_frame
	_assert(not bool(_player.call("is_ui_input_locked")) and _touch_controls.visible, "Closing touch-opened terminal restores seated vehicle HUD/input")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Terminal inspection/mutation test leaves the authoritative grid structurally valid")

	if _failures.is_empty():
		print("STAGE29_SHIP_TERMINAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE29_SHIP_TERMINAL_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _build_grid() -> void:
	_grid = GRID_SCRIPT.new() as RigidBody3D
	_grid.name = "Stage29TerminalGrid"
	_grid.set("grid_profile", LARGE_PROFILE)
	_grid.set("dynamic_gravity_scale", 0.0)
	_grid.position = Vector3(0, 24, 0)
	add_child(_grid)
	_presenter = PRESENTER_SCRIPT.new() as Node3D
	_presenter.name = "BlockPresenter"
	_grid.add_child(_presenter)
	var placements := [
		[&"pilot_cradle_large", Vector3i.ZERO],
		[&"vector_gyro_large", Vector3i(0, 1, 0)],
		[&"pulse_thruster_large", Vector3i(0, 0, 1)],
		[&"helix_core_reactor_large", Vector3i(-1, 0, 0)],
		[&"flux_reservoir_large", Vector3i(1, 0, 0)],
		[&"dev_aux_load_large", Vector3i(0, -1, 0)],
		[&"frame_lattice_large", Vector3i(0, 0, -1)],
		[&"armor_shell_heavy_large", Vector3i(2, 0, 0)],
	]
	for placement in placements:
		var block_id := StringName(placement[0])
		var definition := BlockDB.call("get_block", block_id) as Resource
		var instance := _grid.call("place_block", definition, placement[1], 0) as Resource
		if instance != null:
			_ids[block_id] = int(instance.get("instance_id"))
	_presenter.call("flush_collision_now")
	_presenter.call("flush_geometry_now")

func _build_player_and_ui() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_player.position = Vector3(0, 24, 8)
	add_child(_player)
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)
	_terminal = TERMINAL_SCENE.instantiate() as Control
	canvas.add_child(_terminal)
	_terminal.call("bind_player", _player)
	_terminal.call("bind_default_grid", _grid)
	_terminal.call("bind_mobile_touch_controls", _touch_controls)

func _send_touch(control: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	control.call("handle_screen_event", event)

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
