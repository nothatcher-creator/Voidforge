extends Node3D
## Development wrapper that seeds the Stage 8 hotbar with a small deterministic inventory.

@onready var player: CharacterBody3D = $Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer
@onready var inventory: Node = $Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/Inventory
@onready var hotbar: Node = $Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/Hotbar

func _ready() -> void:
	_seed_development_loadout()
	DebugLog.info("Stage8Test", "Hotbar development loadout ready")

func _seed_development_loadout() -> void:
	if inventory == null or hotbar == null:
		DebugLog.error("Stage8Test", "Player inventory/hotbar missing")
		return
	inventory.call("add_item_by_id", &"component_structural_plate", 18)
	inventory.call("add_item_by_id", &"component_conductive_wire", 48)
	inventory.call("add_item_by_id", &"component_drive_motor", 6)
	inventory.call("add_item_by_id", &"ore_ferrite", 40)
	hotbar.call("assign_item", 0, &"component_structural_plate")
	hotbar.call("assign_item", 1, &"component_conductive_wire")
	hotbar.call("assign_item", 2, &"component_drive_motor")
	hotbar.call("assign_item", 3, &"ore_ferrite")
	hotbar.call("select_slot", 0)
