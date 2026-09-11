extends Control
## Stage 30 touch-first ship terminal. Inspection and persistent per-instance configuration
## share one authoritative grid query/write layer so mobile and desktop behavior stay identical.

signal terminal_opened(grid: Node)
signal terminal_closed
signal managed_grid_changed(grid: Node)
signal selected_block_changed(instance_id: int)

const CATEGORY_ORDER: Array[StringName] = [
	&"all", &"power", &"propulsion", &"control", &"production", &"storage",
	&"weapons", &"life_support", &"automation", &"doors", &"lighting", &"structure", &"armor",
]
const CATEGORY_LABELS := {
	&"all": "ALL",
	&"power": "POWER",
	&"propulsion": "PROPULSION",
	&"control": "CONTROL",
	&"production": "PRODUCTION",
	&"storage": "STORAGE",
	&"weapons": "WEAPONS",
	&"life_support": "LIFE SUPPORT",
	&"automation": "AUTOMATION",
	&"doors": "DOORS",
	&"lighting": "LIGHTING",
	&"structure": "STRUCTURE",
	&"armor": "ARMOR",
}

@export var player_path: NodePath
@export var default_grid_path: NodePath
@export var mobile_touch_controls_path: NodePath
@export_range(0.05, 2.0, 0.05) var live_refresh_interval_seconds: float = 0.20

@onready var title_label: Label = $Dimmer/TerminalPanel/Margin/VBox/Header/Title
@onready var close_button: Button = $Dimmer/TerminalPanel/Margin/VBox/Header/CloseButton
@onready var grid_summary_label: Label = $Dimmer/TerminalPanel/Margin/VBox/Diagnostics/GridSummary
@onready var power_summary_label: Label = $Dimmer/TerminalPanel/Margin/VBox/Diagnostics/PowerSummary
@onready var battery_summary_label: Label = $Dimmer/TerminalPanel/Margin/VBox/Diagnostics/BatterySummary
@onready var category_list: VBoxContainer = $Dimmer/TerminalPanel/Margin/VBox/Body/CategoryPanel/CategoryMargin/CategoryScroll/CategoryList
@onready var search_edit: LineEdit = $Dimmer/TerminalPanel/Margin/VBox/Body/BlockPanel/BlockMargin/BlockVBox/SearchEdit
@onready var result_count_label: Label = $Dimmer/TerminalPanel/Margin/VBox/Body/BlockPanel/BlockMargin/BlockVBox/ResultCount
@onready var block_list: VBoxContainer = $Dimmer/TerminalPanel/Margin/VBox/Body/BlockPanel/BlockMargin/BlockVBox/BlockScroll/BlockList
@onready var detail_title: Label = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailTitle
@onready var detail_text: RichTextLabel = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/DetailText
@onready var config_panel: Control = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel
@onready var enabled_toggle: CheckButton = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/EnabledToggle
@onready var custom_name_edit: LineEdit = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/NameRow/CustomNameEdit
@onready var apply_name_button: Button = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/NameRow/ApplyNameButton
@onready var priority_option: OptionButton = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/PriorityRow/PriorityOption
@onready var group_name_edit: LineEdit = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/GroupCreateRow/GroupNameEdit
@onready var create_group_button: Button = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/GroupCreateRow/CreateGroupButton
@onready var group_option: OptionButton = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/GroupManageRow/GroupOption
@onready var toggle_membership_button: Button = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/GroupManageRow/ToggleMembershipButton
@onready var delete_group_button: Button = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/GroupManageRow/DeleteGroupButton
@onready var config_status_label: Label = $Dimmer/TerminalPanel/Margin/VBox/Body/DetailPanel/DetailMargin/DetailVBox/ConfigPanel/ConfigMargin/ConfigVBox/ConfigStatus
@onready var footer_label: Label = $Dimmer/TerminalPanel/Margin/VBox/Footer

var _player: Node
var _default_grid: Node
var _managed_grid: Node
var _mobile_touch_controls: Node
var _selected_category: StringName = &"all"
var _selected_instance_id: int = 0
var _refresh_accumulator: float = 0.0
var _category_buttons: Dictionary = {}
var _block_buttons: Dictionary = {}
var _visible_instance_ids: Array[int] = []
var _last_block_signature: String = ""
var _mouse_was_captured: bool = false
var _syncing_configuration_controls: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not player_path.is_empty():
		_player = get_node_or_null(player_path)
	if not default_grid_path.is_empty():
		_default_grid = get_node_or_null(default_grid_path)
	if not mobile_touch_controls_path.is_empty():
		_mobile_touch_controls = get_node_or_null(mobile_touch_controls_path)
	close_button.pressed.connect(close_terminal)
	search_edit.text_changed.connect(_on_search_text_changed)
	enabled_toggle.toggled.connect(_on_enabled_toggled)
	apply_name_button.pressed.connect(_on_apply_name_pressed)
	custom_name_edit.text_submitted.connect(_on_custom_name_submitted)
	priority_option.item_selected.connect(_on_priority_selected)
	create_group_button.pressed.connect(_on_create_group_pressed)
	group_name_edit.text_submitted.connect(_on_group_name_submitted)
	toggle_membership_button.pressed.connect(_on_toggle_group_membership_pressed)
	delete_group_button.pressed.connect(_on_delete_group_pressed)
	_build_priority_options()
	_build_category_buttons()
	_refresh_empty_state()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ship_terminal"):
		toggle_terminal()
	if not visible:
		return
	_refresh_accumulator += delta
	if _refresh_accumulator >= live_refresh_interval_seconds:
		_refresh_accumulator = 0.0
		refresh_live_state()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_terminal()
		get_viewport().set_input_as_handled()

func bind_player(player: Node) -> void:
	_player = player

func bind_default_grid(grid: Node) -> void:
	_default_grid = grid
	if _managed_grid == null and visible:
		bind_grid(grid)

func bind_mobile_touch_controls(controls: Node) -> void:
	_mobile_touch_controls = controls

func bind_grid(grid: Node) -> bool:
	if grid != null and not _is_supported_grid(grid):
		return false
	_disconnect_grid_signals()
	_managed_grid = grid
	_connect_grid_signals()
	_selected_instance_id = 0
	_last_block_signature = ""
	_rebuild_block_list(true)
	refresh_live_state()
	managed_grid_changed.emit(_managed_grid)
	return _managed_grid != null

func get_managed_grid() -> Node:
	return _managed_grid if is_instance_valid(_managed_grid) else null

func is_terminal_open() -> bool:
	return visible

func toggle_terminal() -> void:
	if visible:
		close_terminal()
	else:
		open_terminal()

func open_terminal(grid: Node = null) -> bool:
	var target := grid
	if target == null:
		target = _resolve_preferred_grid()
	if target == null or not _is_supported_grid(target):
		DebugLog.warn("ShipTerminal", "No compatible grid is available for terminal inspection")
		return false
	if not bind_grid(target):
		return false
	_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	visible = true
	_refresh_accumulator = 0.0
	_set_gameplay_ui_locked(true)
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	search_edit.grab_focus()
	refresh_live_state()
	terminal_opened.emit(_managed_grid)
	return true

func close_terminal() -> void:
	if not visible:
		return
	visible = false
	search_edit.release_focus()
	_set_gameplay_ui_locked(false)
	if _mouse_was_captured and not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	terminal_closed.emit()

func set_category(category: StringName) -> bool:
	if category not in CATEGORY_ORDER:
		return false
	if _selected_category == category:
		return true
	_selected_category = category
	_update_category_button_states()
	_rebuild_block_list(true)
	return true

func get_selected_category() -> StringName:
	return _selected_category

func set_search_query(query: String) -> void:
	if search_edit.text != query:
		search_edit.text = query
	_rebuild_block_list(true)

func get_search_query() -> String:
	return search_edit.text

func get_visible_block_instance_ids() -> Array[int]:
	return _visible_instance_ids.duplicate()

func select_block(instance_id: int) -> bool:
	if not is_instance_valid(_managed_grid) or not _managed_grid.has_method("get_block_by_instance_id"):
		return false
	var instance := _managed_grid.call("get_block_by_instance_id", instance_id) as Resource
	if instance == null:
		return false
	_selected_instance_id = instance_id
	_update_block_button_states()
	_refresh_selected_details()
	selected_block_changed.emit(instance_id)
	return true

func get_selected_instance_id() -> int:
	return _selected_instance_id

func get_selected_detail_text() -> String:
	return detail_text.text

func get_power_summary_text() -> String:
	return power_summary_label.text

func get_grid_summary_text() -> String:
	return grid_summary_label.text

func get_battery_summary_text() -> String:
	return battery_summary_label.text

func set_selected_block_enabled(enabled: bool) -> bool:
	if not _has_selected_block() or not _managed_grid.has_method("set_block_enabled"):
		return false
	var accepted := bool(_managed_grid.call("set_block_enabled", _selected_instance_id, enabled))
	if accepted:
		_set_config_status("Function %s" % ("enabled" if enabled else "disabled"))
		refresh_now()
	return accepted

func rename_selected_block(custom_name: String) -> bool:
	if not _has_selected_block() or not _managed_grid.has_method("set_block_custom_name"):
		return false
	var accepted := bool(_managed_grid.call("set_block_custom_name", _selected_instance_id, custom_name))
	if accepted:
		_set_config_status("Block name updated")
		_last_block_signature = ""
		refresh_now()
	return accepted

func set_selected_power_priority_override(priority: int) -> bool:
	if not _has_selected_block() or not _managed_grid.has_method("set_block_power_priority_override"):
		return false
	var accepted := bool(_managed_grid.call("set_block_power_priority_override", _selected_instance_id, priority))
	if accepted:
		_set_config_status("Power priority updated")
		refresh_now()
	return accepted

func create_group(group_name: String) -> bool:
	if not is_instance_valid(_managed_grid) or not _managed_grid.has_method("create_block_group"):
		return false
	var accepted := bool(_managed_grid.call("create_block_group", group_name))
	if accepted:
		_set_config_status("Group created")
		_refresh_group_controls(group_name.strip_edges())
	return accepted

func delete_group(group_name: String) -> bool:
	if not is_instance_valid(_managed_grid) or not _managed_grid.has_method("delete_block_group"):
		return false
	var accepted := bool(_managed_grid.call("delete_block_group", group_name))
	if accepted:
		_set_config_status("Group deleted")
		_refresh_group_controls()
		_refresh_selected_details()
	return accepted

func set_selected_block_group_membership(group_name: String, member: bool) -> bool:
	if not _has_selected_block() or not is_instance_valid(_managed_grid):
		return false
	var method := "add_block_to_group" if member else "remove_block_from_group"
	if not _managed_grid.has_method(method):
		return false
	var accepted := bool(_managed_grid.call(method, _selected_instance_id, group_name))
	if accepted:
		_set_config_status("Group membership updated")
		_refresh_group_controls(group_name)
		_refresh_selected_details()
	return accepted

func get_group_names() -> Array[String]:
	if not is_instance_valid(_managed_grid) or not _managed_grid.has_method("get_block_group_names"):
		return []
	return _managed_grid.call("get_block_group_names") as Array[String]

func get_selected_block_configuration() -> Dictionary:
	if not _has_selected_block() or not _managed_grid.has_method("get_block_configuration"):
		return {"valid": false}
	return _managed_grid.call("get_block_configuration", _selected_instance_id) as Dictionary

func _has_selected_block() -> bool:
	return is_instance_valid(_managed_grid) and _selected_instance_id > 0 and _managed_grid.call("get_block_by_instance_id", _selected_instance_id) != null

func refresh_now() -> void:
	_rebuild_block_list(false)
	refresh_live_state()

func refresh_live_state() -> void:
	if not is_instance_valid(_managed_grid):
		_refresh_empty_state()
		return
	_rebuild_block_list(false)
	_refresh_grid_summary()
	_refresh_power_summary()
	_refresh_battery_summary()
	_refresh_block_row_states()
	_refresh_selected_details()

func _resolve_preferred_grid() -> Node:
	if is_instance_valid(_player) and _player.has_method("get_controlled_grid"):
		var controlled := _player.call("get_controlled_grid") as Node
		if controlled != null and _is_supported_grid(controlled):
			return controlled
	if is_instance_valid(_default_grid) and _is_supported_grid(_default_grid):
		return _default_grid
	return null

func _is_supported_grid(grid: Node) -> bool:
	return (
		grid != null
		and grid.has_method("get_all_blocks")
		and grid.has_method("get_power_network_state")
		and grid.has_method("get_block_power_state")
		and grid.has_method("get_block_configuration")
		and grid.has_method("set_block_enabled")
		and grid.has_method("set_block_custom_name")
		and grid.has_method("set_block_power_priority_override")
	)

func _build_category_buttons() -> void:
	for child in category_list.get_children():
		child.queue_free()
	_category_buttons.clear()
	var group := ButtonGroup.new()
	for category in CATEGORY_ORDER:
		var button := Button.new()
		button.name = "%sCategory" % String(category).to_pascal_case()
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.toggle_mode = true
		button.button_group = group
		button.text = String(CATEGORY_LABELS.get(category, String(category).to_upper()))
		button.pressed.connect(_on_category_pressed.bind(category))
		category_list.add_child(button)
		_category_buttons[category] = button
	_update_category_button_states()

func _on_category_pressed(category: StringName) -> void:
	set_category(category)

func _on_search_text_changed(_new_text: String) -> void:
	_rebuild_block_list(true)

func _update_category_button_states() -> void:
	for category in _category_buttons.keys():
		var button := _category_buttons[category] as Button
		if is_instance_valid(button):
			button.button_pressed = StringName(category) == _selected_category

func _rebuild_block_list(force: bool) -> void:
	if not is_instance_valid(_managed_grid):
		_clear_block_buttons()
		return
	var visible_ids := _query_visible_instance_ids()
	var signature := "%s|%s|%s" % [String(_selected_category), search_edit.text.strip_edges().to_lower(), _instance_id_signature(visible_ids)]
	if not force and signature == _last_block_signature:
		return
	_last_block_signature = signature
	_clear_block_buttons()
	_visible_instance_ids = visible_ids
	for instance_id in _visible_instance_ids:
		var button := Button.new()
		button.name = "Block%d" % instance_id
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.pressed.connect(select_block.bind(instance_id))
		block_list.add_child(button)
		_block_buttons[instance_id] = button
	result_count_label.text = "%d installed block%s shown" % [_visible_instance_ids.size(), "" if _visible_instance_ids.size() == 1 else "s"]
	_update_category_counts()
	_update_block_button_states()
	_refresh_block_row_states()
	if _selected_instance_id not in _visible_instance_ids:
		_selected_instance_id = _visible_instance_ids[0] if not _visible_instance_ids.is_empty() else 0
	_update_block_button_states()
	_refresh_selected_details()

func _instance_id_signature(ids: Array[int]) -> String:
	var parts: PackedStringArray = []
	for instance_id in ids:
		parts.append(str(instance_id))
	return ",".join(parts)

func _query_visible_instance_ids() -> Array[int]:
	var result: Array[int] = []
	if not is_instance_valid(_managed_grid):
		return result
	var query := search_edit.text.strip_edges().to_lower()
	var blocks := _managed_grid.call("get_all_blocks") as Array
	for raw_instance in blocks:
		var instance := raw_instance as Resource
		if instance == null:
			continue
		var instance_id := int(instance.get("instance_id"))
		var definition := _definition_for_instance(instance)
		if definition == null:
			continue
		var category := StringName(definition.get("category"))
		if _selected_category != &"all" and category != _selected_category:
			continue
		if not query.is_empty():
			var effective_name := String(_managed_grid.call("get_block_effective_display_name", instance_id)) if _managed_grid.has_method("get_block_effective_display_name") else String(definition.get("display_name"))
			var group_names := ",".join(_managed_grid.call("get_block_group_names", instance_id) as Array[String]) if _managed_grid.has_method("get_block_group_names") else ""
			var haystack := "%s %s %s %s %s %s" % [
				String(definition.get("display_name")), effective_name,
				String(definition.get("id")), String(category),
				String(definition.get("functional_type")), group_names,
			]
			if query not in haystack.to_lower():
				continue
		result.append(instance_id)
	result.sort()
	return result

func _update_category_counts() -> void:
	var counts: Dictionary = {}
	for category in CATEGORY_ORDER:
		counts[category] = 0
	if is_instance_valid(_managed_grid):
		for raw_instance in _managed_grid.call("get_all_blocks") as Array:
			var instance := raw_instance as Resource
			var definition := _definition_for_instance(instance)
			if definition == null:
				continue
			counts[&"all"] = int(counts[&"all"]) + 1
			var category := StringName(definition.get("category"))
			if counts.has(category):
				counts[category] = int(counts[category]) + 1
	for category in _category_buttons.keys():
		var button := _category_buttons[category] as Button
		if not is_instance_valid(button):
			continue
		var base := String(CATEGORY_LABELS.get(category, String(category).to_upper()))
		button.text = "%s  %d" % [base, int(counts.get(category, 0))]

func _clear_block_buttons() -> void:
	for child in block_list.get_children():
		child.queue_free()
	_block_buttons.clear()
	_visible_instance_ids.clear()

func _update_block_button_states() -> void:
	for raw_id in _block_buttons.keys():
		var instance_id := int(raw_id)
		var button := _block_buttons[raw_id] as Button
		if is_instance_valid(button):
			button.disabled = instance_id == _selected_instance_id

func _refresh_block_row_states() -> void:
	if not is_instance_valid(_managed_grid):
		return
	for raw_id in _block_buttons.keys():
		var instance_id := int(raw_id)
		var button := _block_buttons[raw_id] as Button
		if not is_instance_valid(button):
			continue
		var instance := _managed_grid.call("get_block_by_instance_id", instance_id) as Resource
		var definition := _definition_for_instance(instance)
		if definition == null:
			button.text = "#%d  UNKNOWN BLOCK" % instance_id
			continue
		var state := _managed_grid.call("get_block_power_state", instance_id) as Dictionary
		var status := StringName(state.get("status", &"passive"))
		var status_text := String(status).replace("_", " ").to_upper()
		var display_name := String(_managed_grid.call("get_block_effective_display_name", instance_id)) if _managed_grid.has_method("get_block_effective_display_name") else String(definition.get("display_name"))
		button.text = "#%d   %s   ·   %s" % [instance_id, display_name, status_text]

func _refresh_grid_summary() -> void:
	var block_count := int(_managed_grid.call("get_block_count"))
	var total_mass := float(_managed_grid.call("get_total_mass_kg"))
	var grid_type := String(_managed_grid.call("get_grid_type")).to_upper()
	var mode := "DYNAMIC" if bool(_managed_grid.call("is_dynamic_simulation_enabled")) else "FROZEN"
	grid_summary_label.text = "GRID  %s  ·  %d blocks  ·  %.0f kg  ·  %s" % [grid_type, block_count, total_mass, mode]
	title_label.text = "VOIDFORGE SHIP TERMINAL  ·  %s" % String(_managed_grid.name)

func _refresh_power_summary() -> void:
	var power := _managed_grid.call("get_power_network_state") as Dictionary
	var generation := float(power.get("generation_kw", 0.0))
	var active := float(power.get("active_demand_kw", 0.0))
	var supply := float(power.get("available_supply_kw", 0.0))
	var shed := float(power.get("shed_kw", 0.0))
	var ratio := float(power.get("satisfaction_ratio", 1.0)) * 100.0
	var shedding := bool(power.get("load_shedding_active", false))
	power_summary_label.text = "POWER  GEN %.0f kW  ·  ACTIVE %.0f kW  ·  SUPPLY %.0f kW  ·  SHED %.0f kW  ·  %.0f%%  %s" % [
		generation, active, supply, shed, ratio, "LOAD SHEDDING" if shedding else "STABLE",
	]

func _refresh_battery_summary() -> void:
	var power := _managed_grid.call("get_power_network_state") as Dictionary
	var battery_count := int(power.get("battery_count", 0))
	var stored := float(power.get("battery_stored_energy_kwh", 0.0))
	var capacity := float(power.get("battery_capacity_kwh", 0.0))
	var soc := float(power.get("battery_state_of_charge", 0.0)) * 100.0
	var charge_kw := float(power.get("battery_charge_kw", 0.0))
	var discharge_kw := float(power.get("battery_discharge_kw", 0.0))
	battery_summary_label.text = "BATTERY  %d  ·  %.1f / %.1f kWh  ·  %.0f%%  ·  CHG %.0f kW  ·  DIS %.0f kW" % [battery_count, stored, capacity, soc, charge_kw, discharge_kw]

func _refresh_selected_details() -> void:
	if not is_instance_valid(_managed_grid) or _selected_instance_id <= 0:
		detail_title.text = "NO BLOCK SELECTED"
		detail_text.text = "Choose an installed block to inspect or configure its authoritative runtime state."
		_set_configuration_controls_enabled(false)
		return
	var instance := _managed_grid.call("get_block_by_instance_id", _selected_instance_id) as Resource
	var definition := _definition_for_instance(instance)
	if instance == null or definition == null:
		_selected_instance_id = 0
		detail_title.text = "BLOCK UNAVAILABLE"
		detail_text.text = "The selected block no longer exists on this grid."
		return
	var state := _managed_grid.call("get_block_power_state", _selected_instance_id) as Dictionary
	var status := String(state.get("status", "passive")).replace("_", " ").to_upper()
	var functional_type := String(definition.get("functional_type")).replace("_", " ").to_upper()
	var category := String(definition.get("category")).replace("_", " ").to_upper()
	var anchor := Vector3i(instance.get("anchor_cell"))
	var orientation_index := int(instance.get("orientation_index"))
	var priority := String(state.get("priority_name", definition.call("get_power_priority_name"))).to_upper()
	var rated_demand := float(state.get("rated_demand_kw", definition.get("power_use_kw")))
	var active_demand := float(state.get("active_demand_kw", 0.0))
	var allocated := float(state.get("allocated_kw", 0.0))
	var generation := float(state.get("generation_kw", definition.get("power_production_kw")))
	var satisfaction := float(state.get("satisfaction_ratio", 1.0)) * 100.0

	var effective_name := String(_managed_grid.call("get_block_effective_display_name", _selected_instance_id)) if _managed_grid.has_method("get_block_effective_display_name") else String(definition.get("display_name"))
	detail_title.text = "%s  ·  #%d" % [effective_name, _selected_instance_id]
	_refresh_configuration_controls(instance, definition)
	var lines: Array[String] = []
	lines.append("[b]Identity[/b]")
	lines.append("ID: %s" % String(definition.get("id")))
	lines.append("Configured name: %s" % effective_name)
	lines.append("Enabled: %s" % ("YES" if bool(_managed_grid.call("is_block_enabled", _selected_instance_id)) else "NO"))
	var groups := _managed_grid.call("get_block_group_names", _selected_instance_id) as Array[String] if _managed_grid.has_method("get_block_group_names") else []
	lines.append("Groups: %s" % (", ".join(groups) if not groups.is_empty() else "None"))
	lines.append("Category: %s" % category)
	lines.append("Function: %s" % functional_type)
	lines.append("Description: %s" % String(definition.get("description")))
	lines.append("")
	lines.append("[b]Physical[/b]")
	lines.append("Mass: %.1f kg" % float(definition.get("mass_kg")))
	lines.append("Max integrity: %.0f" % float(definition.get("max_integrity")))
	lines.append("Anchor cell: (%d, %d, %d)" % [anchor.x, anchor.y, anchor.z])
	lines.append("Orientation index: %d" % orientation_index)
	lines.append("")
	lines.append("[b]Power[/b]")
	lines.append("State: %s" % status)
	lines.append("Priority: %s" % priority)
	lines.append("Generation: %.1f kW" % generation)
	lines.append("Rated demand: %.1f kW" % rated_demand)
	lines.append("Active demand: %.1f kW" % active_demand)
	lines.append("Allocated: %.1f kW" % allocated)
	lines.append("Satisfaction: %.0f%%" % satisfaction)
	if StringName(definition.get("functional_type")) == &"battery":
		lines.append("")
		lines.append("[b]Storage[/b]")
		lines.append("Stored: %.2f kWh" % float(state.get("stored_energy_kwh", 0.0)))
		lines.append("Capacity: %.2f kWh" % float(state.get("capacity_kwh", 0.0)))
		lines.append("Charge: %.0f%%" % (float(state.get("state_of_charge", 0.0)) * 100.0))
		lines.append("Max charge: %.0f kW" % float(state.get("max_charge_kw", 0.0)))
		lines.append("Max discharge: %.0f kW" % float(state.get("max_discharge_kw", 0.0)))
	lines.append("")
	lines.append("[b]Construction cost[/b]")
	for raw_entry in definition.get("build_cost") as Array:
		var entry := raw_entry as Resource
		if entry == null:
			continue
		var item_id := StringName(entry.get("item_id"))
		var quantity := int(entry.get("quantity"))
		var item := ItemDB.call("get_item", item_id) as Resource
		var item_name := String(item.get("display_name")) if item != null else String(item_id)
		lines.append("%d × %s" % [quantity, item_name])
	detail_text.text = "\n".join(lines)

func _build_priority_options() -> void:
	priority_option.clear()
	priority_option.add_item("DEFINITION", -1)
	priority_option.add_item("CRITICAL", 0)
	priority_option.add_item("HIGH", 1)
	priority_option.add_item("NORMAL", 2)
	priority_option.add_item("LOW", 3)

func _refresh_configuration_controls(instance: Resource, definition: Resource) -> void:
	_syncing_configuration_controls = true
	var valid := instance != null and definition != null and is_instance_valid(_managed_grid)
	_set_configuration_controls_enabled(valid)
	if not valid:
		_syncing_configuration_controls = false
		return
	var instance_id := int(instance.get("instance_id"))
	var functional := StringName(definition.get("functional_type")) != &"structural"
	enabled_toggle.disabled = not functional
	enabled_toggle.button_pressed = bool(_managed_grid.call("is_block_enabled", instance_id))
	custom_name_edit.text = String(_managed_grid.call("get_block_custom_name", instance_id))
	var consumer := float(definition.get("power_use_kw")) > 0.0
	priority_option.disabled = not consumer
	var override := int(_managed_grid.call("get_block_power_priority_override", instance_id))
	var selected_index := priority_option.get_item_index(override)
	priority_option.select(selected_index if selected_index >= 0 else 0)
	_refresh_group_controls()
	_syncing_configuration_controls = false

func _set_configuration_controls_enabled(enabled: bool) -> void:
	config_panel.visible = true
	enabled_toggle.disabled = not enabled
	custom_name_edit.editable = enabled
	apply_name_button.disabled = not enabled
	priority_option.disabled = not enabled
	group_name_edit.editable = enabled
	create_group_button.disabled = not enabled
	group_option.disabled = not enabled or group_option.item_count == 0
	toggle_membership_button.disabled = not enabled or group_option.item_count == 0
	delete_group_button.disabled = not enabled or group_option.item_count == 0

func _refresh_group_controls(preferred_group: String = "") -> void:
	var selected_name := preferred_group
	if selected_name.is_empty() and group_option.item_count > 0 and group_option.selected >= 0:
		selected_name = group_option.get_item_text(group_option.selected)
	group_option.clear()
	var names: Array[String] = []
	if is_instance_valid(_managed_grid) and _managed_grid.has_method("get_block_group_names"):
		names = _managed_grid.call("get_block_group_names") as Array[String]
	for group_name in names:
		group_option.add_item(group_name)
	var index := -1
	for i in group_option.item_count:
		if group_option.get_item_text(i).to_lower() == selected_name.to_lower():
			index = i
			break
	if group_option.item_count > 0:
		group_option.select(index if index >= 0 else 0)
	var has_group := group_option.item_count > 0
	group_option.disabled = not has_group or not _has_selected_block()
	toggle_membership_button.disabled = not has_group or not _has_selected_block()
	delete_group_button.disabled = not has_group
	_update_membership_button_text()

func _update_membership_button_text() -> void:
	if not _has_selected_block() or group_option.item_count <= 0 or group_option.selected < 0:
		toggle_membership_button.text = "ADD"
		return
	var group_name := group_option.get_item_text(group_option.selected)
	var ids := _managed_grid.call("get_group_instance_ids", group_name) as Array[int]
	toggle_membership_button.text = "REMOVE" if _selected_instance_id in ids else "ADD"

func _on_enabled_toggled(enabled: bool) -> void:
	if _syncing_configuration_controls:
		return
	set_selected_block_enabled(enabled)

func _on_apply_name_pressed() -> void:
	rename_selected_block(custom_name_edit.text)

func _on_custom_name_submitted(text: String) -> void:
	rename_selected_block(text)

func _on_priority_selected(index: int) -> void:
	if _syncing_configuration_controls or index < 0:
		return
	set_selected_power_priority_override(priority_option.get_item_id(index))

func _on_create_group_pressed() -> void:
	var group_name := group_name_edit.text.strip_edges()
	if create_group(group_name):
		group_name_edit.clear()
		set_selected_block_group_membership(group_name, true)

func _on_group_name_submitted(text: String) -> void:
	if create_group(text):
		group_name_edit.clear()
		set_selected_block_group_membership(text, true)

func _on_toggle_group_membership_pressed() -> void:
	if group_option.item_count <= 0 or group_option.selected < 0 or not _has_selected_block():
		return
	var group_name := group_option.get_item_text(group_option.selected)
	var ids := _managed_grid.call("get_group_instance_ids", group_name) as Array[int]
	set_selected_block_group_membership(group_name, _selected_instance_id not in ids)

func _on_delete_group_pressed() -> void:
	if group_option.item_count <= 0 or group_option.selected < 0:
		return
	delete_group(group_option.get_item_text(group_option.selected))

func _set_config_status(text: String) -> void:
	config_status_label.text = text

func _definition_for_instance(instance: Resource) -> Resource:
	if instance == null:
		return null
	return BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource

func _refresh_empty_state() -> void:
	title_label.text = "VOIDFORGE SHIP TERMINAL"
	grid_summary_label.text = "GRID  NO TARGET"
	power_summary_label.text = "POWER  NO GRID CONNECTED"
	battery_summary_label.text = "BATTERY  --"
	result_count_label.text = "0 installed blocks shown"
	detail_title.text = "NO GRID CONNECTED"
	detail_text.text = "Enter a control seat or connect a development target grid."
	_set_configuration_controls_enabled(false)
	_refresh_group_controls()
	_clear_block_buttons()
	_update_category_counts()

func _connect_grid_signals() -> void:
	if not is_instance_valid(_managed_grid):
		return
	for signal_name in [&"grid_changed", &"grid_reloaded", &"power_network_changed", &"battery_storage_changed", &"block_configuration_changed", &"block_groups_changed"]:
		if _managed_grid.has_signal(signal_name):
			var callback := Callable(self, "_on_managed_grid_state_changed")
			if not _managed_grid.is_connected(signal_name, callback):
				_managed_grid.connect(signal_name, callback)

func _disconnect_grid_signals() -> void:
	if not is_instance_valid(_managed_grid):
		return
	for signal_name in [&"grid_changed", &"grid_reloaded", &"power_network_changed", &"battery_storage_changed", &"block_configuration_changed", &"block_groups_changed"]:
		if _managed_grid.has_signal(signal_name):
			var callback := Callable(self, "_on_managed_grid_state_changed")
			if _managed_grid.is_connected(signal_name, callback):
				_managed_grid.disconnect(signal_name, callback)

func _on_managed_grid_state_changed(_a = null, _b = null, _c = null, _d = null) -> void:
	_last_block_signature = ""
	call_deferred("refresh_now")

func _set_gameplay_ui_locked(locked: bool) -> void:
	if is_instance_valid(_player) and _player.has_method("set_ui_input_locked"):
		_player.call("set_ui_input_locked", locked)
	if is_instance_valid(_mobile_touch_controls) and _mobile_touch_controls.has_method("set_external_ui_blocked"):
		_mobile_touch_controls.call("set_external_ui_blocked", locked)

