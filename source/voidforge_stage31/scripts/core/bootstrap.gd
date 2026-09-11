extends Node3D
## Main bootstrap node. It owns only stable high-level runtime roots and stage-level validation.

@onready var world_root: Node3D = $WorldRoot
@onready var systems_root: Node = $Systems
@onready var ui_root: CanvasLayer = $UI
@onready var stage_test: Node3D = $WorldRoot/Stage31HandDrill
@onready var prototype_grid: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/PrototypeBlockGrid
@onready var grid_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/PrototypeBlockGrid/BlockPresenter
@onready var stage16_stress_grid: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/BatchStressGrid
@onready var stage16_stress_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/BatchStressGrid/BlockPresenter
@onready var stage17_collision_grid: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/CollisionStressGrid
@onready var stage17_collision_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/CollisionStressGrid/BlockPresenter
@onready var stage18_dynamic_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/DynamicGrid
@onready var stage18_dynamic_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/DynamicGrid/BlockPresenter
@onready var stage19_mass_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/MassDemoGrid
@onready var stage19_mass_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/MassDemoGrid/BlockPresenter
@onready var stage20_pilot_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/PilotCraft
@onready var stage20_pilot_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/PilotCraft/BlockPresenter
@onready var stage21_thrust_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/ThrustCraft
@onready var stage21_thrust_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/ThrustCraft/BlockPresenter
@onready var stage22_directional_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/DirectionalCraft
@onready var stage22_directional_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/DirectionalCraft/BlockPresenter
@onready var stage23_gyro_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/GyroCraft
@onready var stage23_gyro_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/GyroCraft/BlockPresenter
@onready var stage24_mobile_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/MobileControlCraft
@onready var stage24_mobile_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/MobileControlCraft/BlockPresenter
@onready var stage25_power_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/PowerCraft
@onready var stage25_power_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/PowerCraft/BlockPresenter
@onready var stage26_battery_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/BatteryCraft
@onready var stage26_battery_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/BatteryCraft/BlockPresenter
@onready var stage27_reactor_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/ReactorCraft
@onready var stage27_reactor_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/ReactorCraft/BlockPresenter
@onready var stage28_priority_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/PriorityCraft
@onready var stage28_priority_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/PriorityCraft/BlockPresenter
@onready var stage29_terminal_grid: RigidBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/TerminalCraft
@onready var stage29_terminal_presenter: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/TerminalCraft/BlockPresenter
@onready var player: CharacterBody3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer
@onready var player_interactor: RayCast3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/CameraPivot/Camera3D/PlayerInteractor
@onready var build_controller: Node3D = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/BuildController
@onready var player_inventory: Node = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/Inventory
@onready var player_hotbar: Node = $WorldRoot/Stage31HandDrill/Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/Hotbar
@onready var status_label: Label = $UI/StageStatus
@onready var performance_overlay: Control = $UI/PerformanceOverlay
@onready var interaction_prompt: Control = $UI/InteractionPrompt
@onready var hotbar_ui: Control = $UI/HotbarUI
@onready var touch_controls: Control = $UI/MobileTouchControls
@onready var ship_terminal_ui: Control = $UI/ShipTerminalUI

func _ready() -> void:
	DebugLog.info("Bootstrap", "Starting %s %s" % [GameConfig.GAME_NAME, GameConfig.BUILD_VERSION])
	_validate_scene_contract()
	_validate_item_database()
	_validate_grid_database()
	_validate_block_database()
	_validate_prototype_grid()
	_validate_batched_geometry()
	_validate_grid_collision()
	_validate_dynamic_grid()
	_validate_ship_mass()
	_validate_control_seat()
	_validate_thruster()
	_validate_directional_thrust()
	_validate_gyroscope()
	_validate_mobile_ship_controls()
	_validate_power_network()
	_validate_battery_storage()
	_validate_reactor()
	_validate_power_priorities()
	_validate_ship_terminal()
	_validate_block_configuration()
	_validate_hand_drill()
	if touch_controls != null and hotbar_ui != null and touch_controls.has_method("exclude_look_control"):
		var slot_count := int(hotbar_ui.call("get_slot_control_count"))
		for slot_index in slot_count:
			var slot_control := hotbar_ui.call("get_slot_control", slot_index) as Control
			if slot_control != null:
				touch_controls.call("exclude_look_control", slot_control)
	if status_label != null:
		status_label.text = "%s\nStage %d hand drill active" % [GameConfig.GAME_NAME, GameConfig.BUILD_STAGE]

func _validate_scene_contract() -> void:
	var missing: Array[String] = []
	if world_root == null:
		missing.append("WorldRoot")
	if systems_root == null:
		missing.append("Systems")
	if ui_root == null:
		missing.append("UI")
	if stage_test == null:
		missing.append("WorldRoot/Stage31HandDrill")
	if prototype_grid == null:
		missing.append("Stage16GridGeometryTest/Stage15StructuralLibraryTest/.../PrototypeBlockGrid")
	if grid_presenter == null:
		missing.append("PrototypeBlockGrid/BlockPresenter")
	if stage16_stress_grid == null:
		missing.append("Stage16GridGeometryTest/BatchStressGrid")
	if stage16_stress_presenter == null:
		missing.append("BatchStressGrid/BlockPresenter")
	if stage17_collision_grid == null:
		missing.append("Stage17GridCollisionTest/CollisionStressGrid")
	if stage17_collision_presenter == null:
		missing.append("CollisionStressGrid/BlockPresenter")
	if stage18_dynamic_grid == null:
		missing.append("Stage18DynamicGridTest/DynamicGrid")
	if stage18_dynamic_presenter == null:
		missing.append("DynamicGrid/BlockPresenter")
	if stage19_mass_grid == null:
		missing.append("Stage19ShipMassTest/MassDemoGrid")
	if stage19_mass_presenter == null:
		missing.append("MassDemoGrid/BlockPresenter")
	if stage20_pilot_grid == null:
		missing.append("Stage20ControlSeatTest/PilotCraft")
	if stage20_pilot_presenter == null:
		missing.append("PilotCraft/BlockPresenter")
	if stage21_thrust_grid == null:
		missing.append("Stage21ThrusterTest/ThrustCraft")
	if stage21_thrust_presenter == null:
		missing.append("ThrustCraft/BlockPresenter")
	if stage22_directional_grid == null:
		missing.append("Stage22DirectionalThrustTest/DirectionalCraft")
	if stage22_directional_presenter == null:
		missing.append("DirectionalCraft/BlockPresenter")
	if stage23_gyro_grid == null:
		missing.append("Stage23GyroscopeTest/GyroCraft")
	if stage23_gyro_presenter == null:
		missing.append("GyroCraft/BlockPresenter")
	if stage24_mobile_grid == null:
		missing.append("Stage24MobileShipControl/MobileControlCraft")
	if stage24_mobile_presenter == null:
		missing.append("MobileControlCraft/BlockPresenter")
	if stage25_power_grid == null:
		missing.append("Stage25PowerNetwork/PowerCraft")
	if stage25_power_presenter == null:
		missing.append("PowerCraft/BlockPresenter")
	if stage26_battery_grid == null:
		missing.append("Stage26Battery/BatteryCraft")
	if stage26_battery_presenter == null:
		missing.append("BatteryCraft/BlockPresenter")
	if stage27_reactor_grid == null:
		missing.append("Stage27Reactor/ReactorCraft")
	if stage27_reactor_presenter == null:
		missing.append("ReactorCraft/BlockPresenter")
	if stage28_priority_grid == null:
		missing.append("Stage28PowerPriority/PriorityCraft")
	if stage28_priority_presenter == null:
		missing.append("PriorityCraft/BlockPresenter")
	if stage29_terminal_grid == null:
		missing.append("Stage29ShipTerminal/TerminalCraft")
	if stage29_terminal_presenter == null:
		missing.append("TerminalCraft/BlockPresenter")
	if player == null:
		missing.append("Stage16GridGeometryTest/Stage15StructuralLibraryTest/.../FirstPersonPlayer")
	if player_interactor == null:
		missing.append("FirstPersonPlayer/.../PlayerInteractor")
	if build_controller == null:
		missing.append("FirstPersonPlayer/BuildController")
	if player_inventory == null:
		missing.append("FirstPersonPlayer/Inventory")
	if player_hotbar == null:
		missing.append("FirstPersonPlayer/Hotbar")
	if status_label == null:
		missing.append("UI/StageStatus")
	if performance_overlay == null:
		missing.append("UI/PerformanceOverlay")
	if interaction_prompt == null:
		missing.append("UI/InteractionPrompt")
	if hotbar_ui == null:
		missing.append("UI/HotbarUI")
	if touch_controls == null:
		missing.append("UI/MobileTouchControls")
	if ship_terminal_ui == null:
		missing.append("UI/ShipTerminalUI")

	if missing.is_empty():
		DebugLog.info("Bootstrap", "Stage %d scene contract validated" % GameConfig.BUILD_STAGE)
	else:
		DebugLog.error("Bootstrap", "Missing required nodes: %s" % ", ".join(PackedStringArray(missing)))

func _validate_item_database() -> void:
	var item_db := get_node_or_null("/root/ItemDB")
	if item_db == null:
		DebugLog.error("Bootstrap", "ItemDB autoload is missing")
		return
	if not bool(item_db.call("is_database_valid")):
		var errors = item_db.call("get_validation_errors")
		DebugLog.error("Bootstrap", "Item database is invalid: %s" % " | ".join(PackedStringArray(errors)))
		return
	DebugLog.info("Bootstrap", "Item database ready with %d definitions" % int(item_db.call("get_item_count")))

func _validate_grid_database() -> void:
	var grid_db := get_node_or_null("/root/GridDB")
	if grid_db == null:
		DebugLog.error("Bootstrap", "GridDB autoload is missing")
		return
	if not bool(grid_db.call("is_database_valid")):
		var errors = grid_db.call("get_validation_errors")
		DebugLog.error("Bootstrap", "Grid profile database is invalid: %s" % " | ".join(PackedStringArray(errors)))
		return
	DebugLog.info("Bootstrap", "Grid profile database ready with %d profiles" % int(grid_db.call("get_profile_count")))


func _validate_block_database() -> void:
	var block_db := get_node_or_null("/root/BlockDB")
	if block_db == null:
		DebugLog.error("Bootstrap", "BlockDB autoload is missing")
		return
	if not bool(block_db.call("is_database_valid")):
		var errors = block_db.call("get_validation_errors")
		DebugLog.error("Bootstrap", "Block database is invalid: %s" % " | ".join(PackedStringArray(errors)))
		return
	DebugLog.info("Bootstrap", "Block database ready with %d definitions" % int(block_db.call("get_block_count")))

func _validate_prototype_grid() -> void:
	if prototype_grid == null:
		return
	var errors: Array = prototype_grid.call("get_integrity_errors")
	if errors.is_empty():
		DebugLog.info(
			"Bootstrap",
			"Prototype grid integrity valid | %d blocks | %d cells | %d presented" % [
				int(prototype_grid.call("get_block_count")),
				int(prototype_grid.call("get_occupied_cell_count")),
				int(grid_presenter.call("get_presented_block_count")) if grid_presenter != null else -1,
			]
		)
	else:
		DebugLog.error("Bootstrap", "Prototype grid integrity errors: %s" % " | ".join(PackedStringArray(errors)))

func _validate_batched_geometry() -> void:
	if stage16_stress_grid == null or stage16_stress_presenter == null:
		return
	stage16_stress_presenter.call("flush_geometry_now")
	var block_count := int(stage16_stress_grid.call("get_block_count"))
	var batch_count := int(stage16_stress_presenter.call("get_batch_count"))
	var render_count := int(stage16_stress_presenter.call("get_render_instance_count"))
	var render_nodes := int(stage16_stress_presenter.call("get_runtime_render_node_count"))
	if block_count == 100 and batch_count == 1 and render_count == 100 and render_nodes == 1:
		DebugLog.info("Bootstrap", "Stage 16 render batching valid | 100 blocks | 1 batch | 1 render node")
	else:
		DebugLog.error(
			"Bootstrap",
			"Stage 16 render batching mismatch | %d blocks | %d batches | %d instances | %d render nodes" % [block_count, batch_count, render_count, render_nodes]
		)

func _validate_grid_collision() -> void:
	if stage17_collision_grid == null or stage17_collision_presenter == null:
		return
	stage17_collision_presenter.call("flush_collision_now")
	var block_count := int(stage17_collision_grid.call("get_block_count"))
	var collision_nodes := int(stage17_collision_presenter.call("get_runtime_collision_node_count"))
	var shape_count := int(stage17_collision_presenter.call("get_collision_shape_count"))
	var shape_resources := int(stage17_collision_presenter.call("get_collision_shape_resource_count"))
	if block_count == 100 and collision_nodes == 1 and shape_count == 100 and shape_resources == 1:
		DebugLog.info("Bootstrap", "Stage 17 collision batching valid | 100 blocks | 1 body | 100 shapes | 1 cached shape resource")
	else:
		DebugLog.error(
			"Bootstrap",
			"Stage 17 collision batching mismatch | %d blocks | %d nodes | %d shapes | %d shape resources" % [block_count, collision_nodes, shape_count, shape_resources]
		)

func _validate_dynamic_grid() -> void:
	if stage18_dynamic_grid == null or stage18_dynamic_presenter == null:
		return
	stage18_dynamic_presenter.call("flush_collision_now")
	var block_count := int(stage18_dynamic_grid.call("get_block_count"))
	var shape_count := int(stage18_dynamic_presenter.call("get_collision_shape_count"))
	var same_body: bool = stage18_dynamic_presenter.call("get_collision_body") == stage18_dynamic_grid
	var dynamic_enabled: bool = bool(stage18_dynamic_grid.call("is_dynamic_simulation_enabled"))
	var calculated_mass := float(stage18_dynamic_grid.call("get_total_mass_kg"))
	if block_count == 5 and shape_count == 5 and same_body and dynamic_enabled and is_equal_approx(calculated_mass, 1400.0):
		DebugLog.info("Bootstrap", "Stage 18 dynamic grid valid | 5 blocks | 1400 kg calculated mass | one rigid body | dynamic simulation enabled")
	else:
		DebugLog.error(
			"Bootstrap",
			"Stage 18 dynamic grid mismatch | %d blocks | %d shapes | mass=%.1f kg | same_body=%s | dynamic=%s" % [block_count, shape_count, calculated_mass, str(same_body), str(dynamic_enabled)]
		)

func _validate_ship_mass() -> void:
	if stage19_mass_grid == null or stage19_mass_presenter == null:
		return
	stage19_mass_presenter.call("flush_collision_now")
	var expected_mass := 0.0
	for block_id in [&"frame_reinforced_large", &"armor_shell_heavy_large", &"beam_long_large"]:
		var definition := BlockDB.call("get_block", block_id) as Resource
		if definition != null:
			expected_mass += float(definition.get("mass_kg"))
	var calculated_mass := float(stage19_mass_grid.call("get_total_mass_kg"))
	var physics_mass := stage19_mass_grid.mass
	var block_count := int(stage19_mass_grid.call("get_block_count"))
	var shape_count := int(stage19_mass_presenter.call("get_collision_shape_count"))
	var integrity_errors := stage19_mass_grid.call("get_integrity_errors") as Array
	if block_count == 3 and shape_count == 3 and is_equal_approx(calculated_mass, expected_mass) and is_equal_approx(physics_mass, expected_mass) and integrity_errors.is_empty():
		DebugLog.info("Bootstrap", "Stage 19 ship mass valid | 3 mixed blocks | %.0f kg authoritative/physics mass" % calculated_mass)
	else:
		DebugLog.error("Bootstrap", "Stage 19 ship mass mismatch | blocks=%d | shapes=%d | calculated=%.1f | physics=%.1f | expected=%.1f | errors=%s" % [block_count, shape_count, calculated_mass, physics_mass, expected_mass, " | ".join(PackedStringArray(integrity_errors))])

func _validate_control_seat() -> void:
	if stage20_pilot_grid == null or stage20_pilot_presenter == null:
		return
	stage20_pilot_presenter.call("flush_collision_now")
	stage20_pilot_presenter.call("flush_geometry_now")
	var seat_presenter := stage20_pilot_presenter.call("get_control_seat_presenter") as Node3D
	if seat_presenter != null:
		seat_presenter.call("flush_now")
	var seat_ids := stage20_pilot_grid.call("get_control_seat_instance_ids") as Array
	var seat_count := int(seat_presenter.call("get_control_seat_count")) if seat_presenter != null else 0
	var total_mass := float(stage20_pilot_grid.call("get_total_mass_kg"))
	var expected_mass := 460.0 + 4.0 * 280.0
	if seat_ids.size() == 1 and seat_count == 1 and is_equal_approx(total_mass, expected_mass) and not bool(stage20_pilot_grid.call("has_active_pilot")):
		DebugLog.info("Bootstrap", "Stage 20 control seat valid | 1 Pilot Cradle | no pilot until interaction | %.0f kg craft" % total_mass)
	else:
		DebugLog.error("Bootstrap", "Stage 20 control-seat mismatch | seat_ids=%d | proxies=%d | mass=%.1f | expected=%.1f | active_pilot=%s" % [seat_ids.size(), seat_count, total_mass, expected_mass, str(stage20_pilot_grid.call("has_active_pilot"))])

func _validate_thruster() -> void:
	if stage21_thrust_grid == null or stage21_thrust_presenter == null:
		return
	stage21_thrust_presenter.call("flush_collision_now")
	stage21_thrust_presenter.call("flush_geometry_now")
	var thruster_ids := stage21_thrust_grid.call("get_thruster_instance_ids") as Array
	var total_mass := float(stage21_thrust_grid.call("get_total_mass_kg"))
	var rated_force := float(stage21_thrust_grid.call("get_total_rated_thrust_n"))
	var combined_force := stage21_thrust_grid.call("get_combined_thruster_local_force_n") as Vector3
	var expected_mass := 460.0 + 3.0 * 280.0 + 520.0
	var dynamic_enabled := bool(stage21_thrust_grid.call("is_dynamic_simulation_enabled"))
	if thruster_ids.size() == 1 and is_equal_approx(total_mass, expected_mass) and is_equal_approx(rated_force, 48000.0) and combined_force.distance_to(Vector3(0, 0, -48000)) < 0.1 and dynamic_enabled and not bool(stage21_thrust_grid.call("has_active_pilot")):
		DebugLog.info("Bootstrap", "Stage 21 propulsion valid | 1 Pulse Thruster | 48 kN | %.0f kg dynamic craft" % total_mass)
	else:
		DebugLog.error("Bootstrap", "Stage 21 propulsion mismatch | thrusters=%d | mass=%.1f | rated=%.1f | combined=%s | dynamic=%s | pilot=%s" % [thruster_ids.size(), total_mass, rated_force, str(combined_force), str(dynamic_enabled), str(stage21_thrust_grid.call("has_active_pilot"))])
func _validate_directional_thrust() -> void:
	if stage22_directional_grid == null or stage22_directional_presenter == null:
		return
	stage22_directional_presenter.call("flush_collision_now")
	stage22_directional_presenter.call("flush_geometry_now")
	var thruster_ids := stage22_directional_grid.call("get_thruster_instance_ids") as Array
	var rated_force := float(stage22_directional_grid.call("get_total_rated_thrust_n"))
	var combined_force := stage22_directional_grid.call("get_combined_thruster_local_force_n") as Vector3
	var total_mass := float(stage22_directional_grid.call("get_total_mass_kg"))
	var expected_mass := 460.0 + 6.0 * 520.0
	var all_directions_ready := true
	for direction in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]:
		if not is_equal_approx(float(stage22_directional_grid.call("get_directional_rated_thrust_n", direction)), 48000.0):
			all_directions_ready = false
			break
	if thruster_ids.size() == 6 and is_equal_approx(rated_force, 288000.0) and combined_force.length() < 0.1 and is_equal_approx(total_mass, expected_mass) and all_directions_ready and bool(stage22_directional_grid.call("is_dynamic_simulation_enabled")):
		DebugLog.info("Bootstrap", "Stage 22 directional thrust valid | 6 axes | 288 kN installed | %.0f kg craft" % total_mass)
	else:
		DebugLog.error("Bootstrap", "Stage 22 directional thrust mismatch | thrusters=%d | rated=%.1f | combined=%s | mass=%.1f | expected=%.1f | directions=%s" % [thruster_ids.size(), rated_force, str(combined_force), total_mass, expected_mass, str(all_directions_ready)])


func _validate_gyroscope() -> void:
	if stage23_gyro_grid == null or stage23_gyro_presenter == null:
		return
	stage23_gyro_presenter.call("flush_collision_now")
	stage23_gyro_presenter.call("flush_geometry_now")
	var gyro_count := int(stage23_gyro_grid.call("get_gyroscope_count"))
	var torque_nm := float(stage23_gyro_grid.call("get_total_gyro_torque_nm"))
	if gyro_count == 1 and is_equal_approx(torque_nm, 120000.0):
		DebugLog.info("Bootstrap", "Stage 23 gyroscope valid | 1 gyro | 120000 N*m rated torque")
	else:
		DebugLog.error("Bootstrap", "Stage 23 gyroscope mismatch | %d gyros | %.0f N*m" % [gyro_count, torque_nm])


func _validate_mobile_ship_controls() -> void:
	if stage24_mobile_grid == null or stage24_mobile_presenter == null:
		return
	stage24_mobile_presenter.call("flush_collision_now")
	stage24_mobile_presenter.call("flush_geometry_now")
	var seat_presenter := stage24_mobile_presenter.call("get_control_seat_presenter") as Node3D
	if seat_presenter != null:
		seat_presenter.call("flush_now")
	var thruster_count := int(stage24_mobile_grid.call("get_thruster_count"))
	var gyro_count := int(stage24_mobile_grid.call("get_gyroscope_count"))
	var rated_force := float(stage24_mobile_grid.call("get_total_rated_thrust_n"))
	var torque_nm := float(stage24_mobile_grid.call("get_total_gyro_torque_nm"))
	var total_mass := float(stage24_mobile_grid.call("get_total_mass_kg"))
	var all_axes_ready := true
	for direction in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]:
		if not is_equal_approx(float(stage24_mobile_grid.call("get_directional_rated_thrust_n", direction)), 48000.0):
			all_axes_ready = false
			break
	if thruster_count == 6 and gyro_count == 1 and is_equal_approx(rated_force, 288000.0) and is_equal_approx(torque_nm, 120000.0) and is_equal_approx(total_mass, 4190.0) and all_axes_ready and bool(stage24_mobile_grid.call("is_dynamic_simulation_enabled")):
		DebugLog.info("Bootstrap", "Stage 24 mobile ship-control craft valid | 6-axis thrust | 1 gyro | dual-stick HUD ready | %.0f kg" % total_mass)
	else:
		DebugLog.error("Bootstrap", "Stage 24 mobile-control mismatch | thrusters=%d | gyros=%d | thrust=%.0f | torque=%.0f | mass=%.1f | axes=%s | dynamic=%s" % [thruster_count, gyro_count, rated_force, torque_nm, total_mass, str(all_axes_ready), str(stage24_mobile_grid.call("is_dynamic_simulation_enabled"))])


func _validate_power_network() -> void:
	if stage25_power_grid == null or stage25_power_presenter == null:
		return
	stage25_power_presenter.call("flush_collision_now")
	stage25_power_presenter.call("flush_geometry_now")
	var power_state := stage25_power_grid.call("get_power_network_state") as Dictionary
	var generation_kw := float(power_state.get("generation_kw", 0.0))
	var rated_demand_kw := float(power_state.get("rated_demand_kw", 0.0))
	var source_count := int(power_state.get("producer_count", 0))
	var consumer_count := int(power_state.get("consumer_count", 0))
	var thruster_count := int(stage25_power_grid.call("get_thruster_count"))
	var gyro_count := int(stage25_power_grid.call("get_gyroscope_count"))
	if source_count == 2 and consumer_count == 3 and thruster_count == 1 and gyro_count == 1 and is_equal_approx(generation_kw, 360.0) and is_equal_approx(rated_demand_kw, 216.0):
		DebugLog.info("Bootstrap", "Stage 25 power network valid | 2 sources | 360 kW generation | 216 kW rated demand | powered propulsion/gyro ready")
	else:
		DebugLog.error("Bootstrap", "Stage 25 power mismatch | sources=%d | consumers=%d | generation=%.1f | rated=%.1f | thrusters=%d | gyros=%d" % [source_count, consumer_count, generation_kw, rated_demand_kw, thruster_count, gyro_count])

func _validate_battery_storage() -> void:
	if stage26_battery_grid == null or stage26_battery_presenter == null:
		return
	stage26_battery_presenter.call("flush_collision_now")
	stage26_battery_presenter.call("flush_geometry_now")
	var storage := stage26_battery_grid.call("get_battery_storage_state") as Dictionary
	var power := stage26_battery_grid.call("get_power_network_state") as Dictionary
	var battery_count := int(storage.get("battery_count", 0))
	var stored_kwh := float(storage.get("stored_energy_kwh", 0.0))
	var capacity_kwh := float(storage.get("capacity_kwh", 0.0))
	var max_discharge_kw := float(storage.get("max_discharge_kw", 0.0))
	var generation_kw := float(power.get("generation_kw", 0.0))
	if battery_count == 1 and is_equal_approx(capacity_kwh, 60.0) and stored_kwh > 0.0 and stored_kwh <= capacity_kwh and is_equal_approx(max_discharge_kw, 240.0) and is_equal_approx(generation_kw, 180.0):
		DebugLog.info("Bootstrap", "Stage 26 battery valid | %.1f/%.1f kWh | %.0f kW max discharge | %.0f kW installed generation" % [stored_kwh, capacity_kwh, max_discharge_kw, generation_kw])
	else:
		DebugLog.error("Bootstrap", "Stage 26 battery mismatch | batteries=%d | stored=%.3f/%.3f kWh | max_discharge=%.1f kW | generation=%.1f kW" % [battery_count, stored_kwh, capacity_kwh, max_discharge_kw, generation_kw])
func _validate_reactor() -> void:
	if stage27_reactor_grid == null or stage27_reactor_presenter == null:
		return
	stage27_reactor_presenter.call("flush_collision_now")
	stage27_reactor_presenter.call("flush_geometry_now")
	var power := stage27_reactor_grid.call("get_power_network_state") as Dictionary
	var storage := stage27_reactor_grid.call("get_battery_storage_state") as Dictionary
	var generation_kw := float(power.get("generation_kw", 0.0))
	var rated_demand_kw := float(power.get("rated_demand_kw", 0.0))
	var producer_count := int(power.get("producer_count", 0))
	var battery_count := int(storage.get("battery_count", 0))
	var total_mass := float(stage27_reactor_grid.call("get_total_mass_kg"))
	if producer_count == 1 and battery_count == 1 and is_equal_approx(generation_kw, 480.0) and is_equal_approx(rated_demand_kw, 216.0) and is_equal_approx(total_mass, 3190.0):
		DebugLog.info("Bootstrap", "Stage 27 reactor valid | 480 kW generation | 216 kW rated demand | 60 kWh battery | %.0f kg" % total_mass)
	else:
		DebugLog.error("Bootstrap", "Stage 27 reactor mismatch | producers=%d | batteries=%d | generation=%.1f | rated=%.1f | mass=%.1f" % [producer_count, battery_count, generation_kw, rated_demand_kw, total_mass])

func _validate_power_priorities() -> void:
	if stage28_priority_grid == null or stage28_priority_presenter == null:
		return
	stage28_priority_presenter.call("flush_collision_now")
	stage28_priority_presenter.call("flush_geometry_now")
	var power := stage28_priority_grid.call("get_power_network_state") as Dictionary
	var generation_kw := float(power.get("generation_kw", 0.0))
	var rated_demand_kw := float(power.get("rated_demand_kw", 0.0))
	var total_mass := float(stage28_priority_grid.call("get_total_mass_kg"))
	var aux := BlockDB.call("get_block", &"dev_aux_load_large") as Resource
	var seat := BlockDB.call("get_block", &"pilot_cradle_large") as Resource
	var gyro := BlockDB.call("get_block", &"vector_gyro_large") as Resource
	var thruster := BlockDB.call("get_block", &"pulse_thruster_large") as Resource
	var priorities_valid := aux != null and seat != null and gyro != null and thruster != null and int(seat.get("power_priority")) == 0 and int(gyro.get("power_priority")) == 1 and int(thruster.get("power_priority")) == 2 and int(aux.get("power_priority")) == 3
	if priorities_valid and is_equal_approx(generation_kw, 180.0) and is_equal_approx(rated_demand_kw, 276.0) and is_equal_approx(total_mass, 2070.0) and bool(power.get("priority_load_shedding_enabled", false)):
		DebugLog.info("Bootstrap", "Stage 28 priorities valid | Critical seat > High gyro > Normal thruster > Low auxiliary | 180/276 kW installed")
	else:
		DebugLog.error("Bootstrap", "Stage 28 priority mismatch | generation=%.1f | rated=%.1f | mass=%.1f | metadata=%s" % [generation_kw, rated_demand_kw, total_mass, str(priorities_valid)])
func _validate_ship_terminal() -> void:
	if stage29_terminal_grid == null or stage29_terminal_presenter == null or ship_terminal_ui == null:
		return
	stage29_terminal_presenter.call("flush_collision_now")
	stage29_terminal_presenter.call("flush_geometry_now")
	ship_terminal_ui.call("bind_grid", stage29_terminal_grid)
	var power := stage29_terminal_grid.call("get_power_network_state") as Dictionary
	var block_count := int(stage29_terminal_grid.call("get_block_count"))
	var total_mass := float(stage29_terminal_grid.call("get_total_mass_kg"))
	var generation_kw := float(power.get("generation_kw", 0.0))
	var battery_count := int(power.get("battery_count", 0))
	var terminal_ready := ship_terminal_ui.has_method("set_category") and ship_terminal_ui.has_method("set_search_query") and ship_terminal_ui.has_method("select_block")
	if block_count == 8 and is_equal_approx(total_mass, 4230.0) and is_equal_approx(generation_kw, 480.0) and battery_count == 1 and terminal_ready:
		DebugLog.info("Bootstrap", "Stage 29 ship terminal valid | 8-block mixed craft | 4230 kg | 480 kW generation | 60 kWh storage")
	else:
		DebugLog.error("Bootstrap", "Stage 29 ship terminal mismatch | blocks=%d | mass=%.1f | generation=%.1f | batteries=%d | ui=%s" % [block_count, total_mass, generation_kw, battery_count, str(terminal_ready)])
func _validate_block_configuration() -> void:
	if stage29_terminal_grid == null or ship_terminal_ui == null:
		return
	var thruster_id := 0
	var gyro_id := 0
	for raw_instance in stage29_terminal_grid.call("get_all_blocks") as Array:
		var instance := raw_instance as Resource
		if instance == null:
			continue
		match StringName(instance.get("block_id")):
			&"pulse_thruster_large": thruster_id = int(instance.get("instance_id"))
			&"vector_gyro_large": gyro_id = int(instance.get("instance_id"))
	var save_state := stage29_terminal_grid.call("get_save_state") as Dictionary
	var groups := stage29_terminal_grid.call("get_group_instance_ids", "Flight Systems") as Array[int]
	var config_ready := (
		ship_terminal_ui.has_method("set_selected_block_enabled")
		and ship_terminal_ui.has_method("rename_selected_block")
		and ship_terminal_ui.has_method("set_selected_power_priority_override")
		and ship_terminal_ui.has_method("create_group")
	)
	var valid := (
		int(save_state.get("version", 0)) == 3
		and thruster_id > 0
		and gyro_id > 0
		and String(stage29_terminal_grid.call("get_block_effective_display_name", thruster_id)) == "Main Drive"
		and int(stage29_terminal_grid.call("get_block_power_priority_override", thruster_id)) == 1
		and groups == [gyro_id, thruster_id]
		and config_ready
	)
	if valid:
		DebugLog.info("Bootstrap", "Stage 30 block configuration valid | save schema v3 | Main Drive High priority | Flight Systems group")
	else:
		DebugLog.error("Bootstrap", "Stage 30 block configuration mismatch | save_v=%d | thruster=%d | gyro=%d | groups=%s | ui=%s" % [int(save_state.get("version", 0)), thruster_id, gyro_id, str(groups), str(config_ready)])



func _validate_hand_drill() -> void:
	var drill := ItemDB.call("get_item", &"tool_field_bore_drill") as Resource
	var controller := player.get_node_or_null("HandDrillController") if player != null else null
	var hotbar_selected := StringName(player_hotbar.call("get_selected_item_id")) if player_hotbar != null else &""
	var target := get_node_or_null("WorldRoot/Stage31HandDrill/DrillWorkTarget")
	var valid := (
		drill != null
		and StringName(drill.get("tool_type")) == &"hand_drill"
		and is_equal_approx(float(drill.get("tool_range_m")), 4.5)
		and is_equal_approx(float(drill.get("tool_work_rate_per_s")), 25.0)
		and controller != null
		and target != null
		and hotbar_selected == &"tool_field_bore_drill"
	)
	if valid:
		DebugLog.info("Bootstrap", "Stage 31 hand drill valid | Field Bore Drill | 4.5 m | 25 work/s | hotbar equipped")
	else:
		DebugLog.error("Bootstrap", "Stage 31 hand drill mismatch | item=%s | controller=%s | target=%s | selected=%s" % [str(drill != null), str(controller != null), str(target != null), String(hotbar_selected)])
