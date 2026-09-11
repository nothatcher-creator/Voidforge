extends Node
## Stage 30 deterministic configuration regression: functional enable/disable, names, priority
## overrides, persistent groups, save-schema v3 migration, terminal writes, and real machinery effects.

const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")
const TERMINAL_SCENE := preload("res://scenes/ui/ship_terminal_ui.tscn")

var _failures: Array[String] = []
var _grid: RigidBody3D
var _ids: Dictionary = {}
var _pilot: Node
var _terminal: Control

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	_build_grid()
	_build_terminal()
	await get_tree().process_frame

	var reactor_id := int(_ids[&"helix_core_reactor_large"])
	var battery_id := int(_ids[&"flux_reservoir_large"])
	var seat_id := int(_ids[&"pilot_cradle_large"])
	var thruster_id := int(_ids[&"pulse_thruster_large"])
	var gyro_id := int(_ids[&"vector_gyro_large"])
	var aux_id := int(_ids[&"dev_aux_load_large"])
	var source_id := int(_ids[&"dev_power_source_large"])

	_assert(int(_grid.call("GRID_SAVE_VERSION")) == 3 if _grid.has_method("GRID_SAVE_VERSION") else true, "Stage 30 uses the v3 configuration-capable grid save schema")
	_assert(bool(_grid.call("is_block_enabled", reactor_id)), "Production reactor starts enabled from BlockDB metadata")
	_assert(is_equal_approx(float(_grid.call("get_total_power_generation_kw")), 660.0), "480 kW reactor plus 180 kW development source provide 660 kW")
	_assert(bool(_grid.call("set_block_enabled", reactor_id, false)), "Functional reactor can be disabled by instance ID")
	_assert(is_equal_approx(float(_grid.call("get_total_power_generation_kw")), 180.0), "Disabled reactor immediately stops contributing 480 kW generation")
	_assert(StringName((_grid.call("get_block_power_state", reactor_id) as Dictionary).get("status")) == &"disabled", "Disabled reactor reports a disabled functional state")
	_assert(bool(_grid.call("set_block_enabled", reactor_id, true)), "Reactor can be re-enabled")
	_assert(is_equal_approx(float(_grid.call("get_total_power_generation_kw")), 660.0), "Re-enabled reactor immediately rejoins the power bus")

	var battery_energy_before := float(_grid.call("get_battery_stored_energy_kwh", battery_id))
	_assert(bool(_grid.call("set_block_enabled", battery_id, false)), "Battery can be isolated from the electrical bus")
	_assert(int(_grid.call("get_battery_count")) == 0, "Disabled battery is excluded from active storage capacity")
	_assert(bool(_grid.call("set_block_enabled", battery_id, true)), "Battery can be re-enabled")
	_assert(int(_grid.call("get_battery_count")) == 1 and is_equal_approx(float(_grid.call("get_battery_stored_energy_kwh", battery_id)), battery_energy_before), "Battery stored kWh survives disable/re-enable")

	_assert(int(_grid.call("get_thruster_count")) == 1 and int(_grid.call("get_gyroscope_count")) == 1, "Enabled propulsion and gyro are present in functional caches")
	_assert(bool(_grid.call("set_block_enabled", thruster_id, false)), "Thruster can be disabled")
	_assert(int(_grid.call("get_thruster_count")) == 0 and Vector3(_grid.call("get_active_manual_force_local_n")).is_zero_approx(), "Disabled thruster contributes no propulsion authority")
	_assert(bool(_grid.call("set_block_enabled", thruster_id, true)), "Thruster can be re-enabled")
	_assert(bool(_grid.call("set_block_enabled", gyro_id, false)), "Gyroscope can be disabled")
	_assert(int(_grid.call("get_gyroscope_count")) == 0, "Disabled gyroscope contributes no rotational authority")
	_assert(bool(_grid.call("set_block_enabled", gyro_id, true)), "Gyroscope can be re-enabled")

	_pilot = Node.new()
	_pilot.name = "Stage30Pilot"
	add_child(_pilot)
	_assert(bool(_grid.call("try_claim_manual_control", _pilot, seat_id)), "Pilot can claim an enabled control seat")
	_assert(bool(_grid.call("has_active_pilot")), "Grid records active pilot before seat configuration change")
	_assert(bool(_grid.call("set_block_enabled", seat_id, false)), "Occupied control seat can be disabled")
	_assert(not bool(_grid.call("has_active_pilot")), "Disabling occupied control seat forcibly clears pilot authority")
	_assert(not bool(_grid.call("can_claim_manual_control", _pilot, seat_id)), "Disabled control seat cannot be reclaimed")
	_assert(bool(_grid.call("set_block_enabled", seat_id, true)) and bool(_grid.call("try_claim_manual_control", _pilot, seat_id)), "Re-enabled seat restores manual-control eligibility")

	_assert(bool(_grid.call("set_block_custom_name", thruster_id, "Main Drive")), "Per-instance custom block name is accepted")
	_assert(String(_grid.call("get_block_effective_display_name", thruster_id)) == "Main Drive", "Custom name becomes the effective terminal/display name")
	_assert(not bool(_grid.call("set_block_custom_name", thruster_id, "X".repeat(49))), "Overlong custom names are rejected")

	# Priority override must alter real load-shedding behavior, not merely terminal text.
	_grid.call("set_block_enabled", reactor_id, false)
	_grid.call("set_block_enabled", battery_id, false)
	_assert(is_equal_approx(float(_grid.call("get_total_power_generation_kw")), 180.0), "Priority fixture runs from only the 180 kW development source")
	_grid.call("set_manual_translation_input", _pilot, Vector3(0, 0, -1))
	_grid.call("set_manual_rotation_input", _pilot, Vector3(1, 0, 0))
	var default_force := Vector3(_grid.call("get_active_manual_force_local_n")).length()
	var default_torque := Vector3(_grid.call("get_active_manual_torque_local_nm")).length()
	_assert(is_equal_approx(default_force, 33600.0) and is_equal_approx(default_torque, 120000.0), "Default priorities preserve gyro and brown out normal thruster under 180/276 kW shortage")
	_assert(bool(_grid.call("set_block_power_priority_override", thruster_id, 0)), "Thruster priority can be overridden to Critical")
	var override_force := Vector3(_grid.call("get_active_manual_force_local_n")).length()
	var override_torque := Vector3(_grid.call("get_active_manual_torque_local_nm")).length()
	_assert(int(_grid.call("get_block_power_priority", thruster_id)) == 0 and StringName(_grid.call("get_block_power_priority_name", thruster_id)) == &"critical", "Runtime priority override changes authoritative priority queries")
	_assert(is_equal_approx(override_force, 48000.0) and override_torque < default_torque, "Critical thruster now receives full 48 kN while lower-priority gyro absorbs the shortage")
	_assert(bool(_grid.call("set_block_power_priority_override", thruster_id, -1)) and int(_grid.call("get_block_power_priority", thruster_id)) == 2, "Definition priority can be restored with the -1 override sentinel")

	_assert(bool(_grid.call("create_block_group", "Flight")), "Named block group can be created")
	_assert(bool(_grid.call("add_block_to_group", thruster_id, "Flight")) and bool(_grid.call("add_block_to_group", gyro_id, "Flight")), "Multiple installed blocks can join one group")
	var flight_ids := _grid.call("get_group_instance_ids", "flight") as Array[int]
	_assert(flight_ids == [gyro_id, thruster_id], "Group lookup is case-insensitive and returns deterministic sorted instance IDs")
	_assert((_grid.call("get_block_group_names", thruster_id) as Array[String]) == ["Flight"], "Block configuration reports group membership")
	_assert(not bool(_grid.call("create_block_group", "flight")), "Duplicate group names are rejected case-insensitively")

	# Final persistent state: renamed critical thruster, disabled auxiliary load, and Flight group.
	_grid.call("set_block_power_priority_override", thruster_id, 0)
	_grid.call("set_block_enabled", aux_id, false)
	_grid.call("set_block_enabled", reactor_id, true)
	_grid.call("set_block_enabled", battery_id, true)
	var saved := _grid.call("get_save_state") as Dictionary
	_assert(int(saved.get("version", 0)) == 3 and (saved.get("block_configurations", []) as Array).size() == int(_grid.call("get_block_count")), "v3 save stores one configuration record per installed block")
	_assert((saved.get("block_groups", []) as Array).size() == 1, "v3 save persists named groups")
	var json_text := JSON.stringify(saved)
	var parsed = JSON.parse_string(json_text)
	_assert(typeof(parsed) == TYPE_DICTIONARY, "Stage 30 configuration save remains JSON-compatible")
	var loaded := _new_grid("Stage30LoadedGrid")
	_assert(bool(loaded.call("load_save_state", parsed as Dictionary)), "Fresh grid loads v3 block configuration state transactionally")
	_assert(String(loaded.call("get_block_effective_display_name", thruster_id)) == "Main Drive", "Custom name survives save/load")
	_assert(int(loaded.call("get_block_power_priority_override", thruster_id)) == 0, "Power-priority override survives save/load")
	_assert(not bool(loaded.call("is_block_enabled", aux_id)), "Disabled functional state survives save/load")
	_assert((loaded.call("get_group_instance_ids", "Flight") as Array[int]) == [gyro_id, thruster_id], "Block groups survive save/load with stable instance IDs")
	_assert(is_equal_approx(float(loaded.call("get_battery_stored_energy_kwh", battery_id)), battery_energy_before), "Battery energy remains compatible with v3 configuration persistence")

	# v2 migration initializes configuration from current BlockDB defaults and no groups.
	var legacy := saved.duplicate(true)
	legacy["version"] = 2
	legacy.erase("block_configurations")
	legacy.erase("block_groups")
	var migrated := _new_grid("Stage30MigratedGrid")
	_assert(bool(migrated.call("load_save_state", legacy)), "Stage 26-29 v2 grid save migrates into Stage 30")
	_assert(String(migrated.call("get_block_custom_name", thruster_id)).is_empty() and int(migrated.call("get_block_power_priority_override", thruster_id)) == -1, "v2 migration uses default names/priorities rather than inventing overrides")
	_assert((migrated.call("get_block_group_names") as Array[String]).is_empty(), "v2 migration starts with no configured groups")

	# Malformed v3 configuration must reject atomically.
	var corrupt := saved.duplicate(true)
	var configs := corrupt["block_configurations"] as Array
	(configs[0] as Dictionary)["custom_name"] = "Y".repeat(60)
	var before_corrupt_name := String(loaded.call("get_block_effective_display_name", thruster_id))
	_assert(not bool(loaded.call("load_save_state", corrupt)), "Overlong custom name causes malformed v3 save rejection")
	_assert(String(loaded.call("get_block_effective_display_name", thruster_id)) == before_corrupt_name, "Rejected configuration save leaves live grid state unchanged")

	# Terminal writes use the same grid APIs.
	_assert(bool(_terminal.call("open_terminal", _grid)), "Stage 30 configuration terminal opens on the authoritative fixture")
	_terminal.call("set_category", &"propulsion")
	_terminal.call("set_search_query", "Main Drive")
	_assert((_terminal.call("get_visible_block_instance_ids") as Array[int]) == [thruster_id], "Terminal search includes per-instance custom names")
	_assert(bool(_terminal.call("select_block", thruster_id)), "Custom-named thruster can be selected for configuration")
	_assert(bool(_terminal.call("rename_selected_block", "Port Drive")), "Terminal rename API writes authoritative grid configuration")
	_assert(String(_grid.call("get_block_effective_display_name", thruster_id)) == "Port Drive", "Terminal rename immediately changes effective installed-block name")
	_terminal.call("set_search_query", "")
	_terminal.call("select_block", thruster_id)
	_assert(bool(_terminal.call("set_selected_block_enabled", false)) and int(_grid.call("get_thruster_count")) == 0, "Terminal enable toggle actually removes thruster authority")
	_assert(bool(_terminal.call("set_selected_block_enabled", true)) and int(_grid.call("get_thruster_count")) == 1, "Terminal enable toggle restores thruster authority")
	_assert(bool(_terminal.call("set_selected_power_priority_override", 1)) and int(_grid.call("get_block_power_priority", thruster_id)) == 1, "Terminal priority control writes a High override")
	_assert(bool(_terminal.call("create_group", "Maneuver")) and bool(_terminal.call("set_selected_block_group_membership", "Maneuver", true)), "Terminal group controls create a group and add the selected block")
	_assert((_grid.call("get_group_instance_ids", "Maneuver") as Array[int]) == [thruster_id], "Terminal group membership is authoritative")
	var config_panel := _terminal.get_node("Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel") as Control
	var enabled_control := _terminal.get_node("Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/EnabledToggle") as Control
	var priority_control := _terminal.get_node("Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/PriorityRow/PriorityOption") as Control
	_assert(config_panel.visible and enabled_control.custom_minimum_size.y >= 44.0 and priority_control.custom_minimum_size.y >= 44.0, "Configuration controls are visible and sized for touch targets")
	_terminal.call("close_terminal")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Configuration operations leave grid integrity valid")

	if _failures.is_empty():
		print("STAGE30_BLOCK_CONFIGURATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE30_BLOCK_CONFIGURATION_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _build_grid() -> void:
	_grid = _new_grid("Stage30ConfigGrid")
	var placements := [
		[&"pilot_cradle_large", Vector3i.ZERO],
		[&"vector_gyro_large", Vector3i(0, 1, 0)],
		[&"pulse_thruster_large", Vector3i(0, 0, 1)],
		[&"helix_core_reactor_large", Vector3i(-1, 0, 0)],
		[&"flux_reservoir_large", Vector3i(1, 0, 0)],
		[&"dev_aux_load_large", Vector3i(0, -1, 0)],
		[&"dev_power_source_large", Vector3i(-2, 0, 0)],
	]
	for placement in placements:
		var block_id := StringName(placement[0])
		var definition := BlockDB.call("get_block", block_id) as Resource
		var instance := _grid.call("place_block", definition, placement[1], 0) as Resource
		if instance != null:
			_ids[block_id] = int(instance.get("instance_id"))

func _new_grid(grid_name: String) -> RigidBody3D:
	var grid := GRID_SCRIPT.new() as RigidBody3D
	grid.name = grid_name
	grid.set("grid_profile", LARGE_PROFILE)
	grid.set("dynamic_gravity_scale", 0.0)
	add_child(grid)
	return grid

func _build_terminal() -> void:
	_terminal = TERMINAL_SCENE.instantiate() as Control
	add_child(_terminal)
	_terminal.call("bind_default_grid", _grid)

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
