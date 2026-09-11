extends Node3D
## Stage 31 wrapper: equips the first production hand drill and provides a non-deforming calibration target.

@onready var player: CharacterBody3D = $Stage30BlockConfiguration/Stage29ShipTerminal/Stage28PowerPriority/Stage27Reactor/Stage26Battery/Stage25PowerNetwork/Stage24MobileShipControl/Stage23GyroscopeTest/Stage22DirectionalThrustTest/Stage21ThrusterTest/Stage20ControlSeatTest/Stage19ShipMassTest/Stage18DynamicGridTest/Stage17GridCollisionTest/Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer
@onready var drill_target: StaticBody3D = $DrillWorkTarget

func _ready() -> void:
	var inventory: Node = player.get_node("Inventory")
	var hotbar: Node = player.get_node("Hotbar")
	if int(inventory.call("get_item_count", &"tool_field_bore_drill")) <= 0:
		inventory.call("add_item_by_id", &"tool_field_bore_drill", 1)
	hotbar.call("assign_item", 4, &"tool_field_bore_drill")
	hotbar.call("select_slot", 4)
	DebugLog.info("Stage31Drill", "Field Bore Drill equipped | slot 5 | 4.5 m range | 25 work/s | target ready")
