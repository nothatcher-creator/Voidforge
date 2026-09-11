extends Node

const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	var world := get_node("Stage31HandDrill")
	var base_path := "Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer"
	var player := world.get_node(base_path) as CharacterBody3D
	var inventory := player.get_node("Inventory")
	var hotbar := player.get_node("Hotbar")
	var controller := player.get_node("HandDrillController")
	var target := world.get_node("DrillWorkTarget")
	_check(ItemDB.has_item(&"tool_field_bore_drill"), "Field Bore Drill is registered")
	var drill_def := ItemDB.get_item(&"tool_field_bore_drill")
	_check(drill_def != null and StringName(drill_def.get("tool_type")) == &"hand_drill", "tool metadata resolves")
	_check(is_equal_approx(float(drill_def.get("tool_range_m")), 4.5), "4.5 m drill range")
	_check(is_equal_approx(float(drill_def.get("tool_work_rate_per_s")), 25.0), "25 work/s drill rate")
	_check(int(inventory.call("get_item_count", &"tool_field_bore_drill")) == 1, "drill exists in inventory")
	_check(StringName(hotbar.call("get_selected_item_id")) == &"tool_field_bore_drill", "drill equipped through hotbar")
	controller.call("force_probe")
	_check(controller.call("get_current_target") == target, "camera ray acquires mineable target")
	_check(String(controller.call("get_current_target_name")) == "Bore Calibration Stone", "target name feedback")
	Input.action_press("tool_use")
	for i in 8:
		await get_tree().physics_frame
	Input.action_release("tool_use")
	await get_tree().physics_frame
	_check(float(target.get("total_drill_work")) > 0.0, "held input applies repeated drill work")
	_check(not bool(controller.call("is_drilling")), "releasing tool input stops drilling")
	_check(not bool(controller.get_node("DrillBeam").visible), "beam feedback clears on stop")
	var work_after := float(target.get("total_drill_work"))
	hotbar.call("select_slot", 0)
	Input.action_press("tool_use")
	for i in 4:
		await get_tree().physics_frame
	Input.action_release("tool_use")
	_check(is_equal_approx(float(target.get("total_drill_work")), work_after), "wrong hotbar item cannot drill")
	hotbar.call("select_slot", 4)
	target.position.z = 1.0
	await get_tree().physics_frame
	controller.call("force_probe")
	_check(controller.call("get_current_target") == null, "out-of-range target rejected")
	target.position.z = 6.6
	await get_tree().physics_frame
	controller.call("force_probe")
	_check(controller.call("get_current_target") == target, "target reacquired in range")
	_check(InputMap.has_action("tool_use"), "shared tool_use InputMap action exists")
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var touch_controls := TOUCH_CONTROLS_SCENE.instantiate() as Control
	touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(touch_controls)
	touch_controls.call("bind_player", player)
	await get_tree().process_frame
	await get_tree().process_frame
	var tool_button := touch_controls.get_node("ToolButton") as Control
	var look_area := touch_controls.get_node("LookArea") as Control
	_check(tool_button.visible, "Android TOOL button is visible on foot")
	var center := tool_button.get_global_rect().get_center()
	var look_probe := InputEventScreenTouch.new()
	look_probe.index = 231
	look_probe.position = center
	look_probe.pressed = true
	_check(not bool(look_area.call("handle_screen_event", look_probe)), "TOOL button is excluded from camera-look touch ownership")
	var before_touch_work := float(target.get("total_drill_work"))
	var press := InputEventScreenTouch.new()
	press.index = 232
	press.position = center
	press.pressed = true
	tool_button.call("handle_screen_event", press)
	for i in 8:
		await get_tree().physics_frame
	var release := InputEventScreenTouch.new()
	release.index = 232
	release.position = center
	release.pressed = false
	tool_button.call("handle_screen_event", release)
	await get_tree().physics_frame
	_check(float(target.get("total_drill_work")) > before_touch_work, "Android TOOL touch drives the shared drill action")
	_check(not Input.is_action_pressed("tool_use"), "Android TOOL release clears tool_use action")
	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.append(label)
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures.is_empty():
		print("STAGE 31 HAND DRILL SMOKE TEST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE 31 HAND DRILL SMOKE TEST: FAIL -> ", failures)
		get_tree().quit(1)
