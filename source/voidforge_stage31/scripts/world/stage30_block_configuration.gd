extends Node3D
## Active Stage 30 wrapper. Retains Stage 29 and seeds persistent terminal configuration examples.

@onready var terminal_grid: RigidBody3D = $Stage29ShipTerminal/TerminalCraft

func _ready() -> void:
	if terminal_grid == null:
		return
	var thruster_id := _find_instance_id(&"pulse_thruster_large")
	var gyro_id := _find_instance_id(&"vector_gyro_large")
	if thruster_id > 0:
		terminal_grid.call("set_block_custom_name", thruster_id, "Main Drive")
		terminal_grid.call("set_block_power_priority_override", thruster_id, 1)
	if not bool(terminal_grid.call("create_block_group", "Flight Systems")):
		# The wrapper may be re-entered during development; existing groups are fine.
		pass
	if thruster_id > 0:
		terminal_grid.call("add_block_to_group", thruster_id, "Flight Systems")
	if gyro_id > 0:
		terminal_grid.call("add_block_to_group", gyro_id, "Flight Systems")
	var save_state := terminal_grid.call("get_save_state") as Dictionary
	DebugLog.info(
		"Stage30Config",
		"Configuration terminal ready | schema v%d | Main Drive #%d | Flight Systems %d members" % [
			int(save_state.get("version", 0)), thruster_id,
			(terminal_grid.call("get_group_instance_ids", "Flight Systems") as Array).size(),
		]
	)

func _find_instance_id(block_id: StringName) -> int:
	for raw_instance in terminal_grid.call("get_all_blocks") as Array:
		var instance := raw_instance as Resource
		if instance != null and StringName(instance.get("block_id")) == block_id:
			return int(instance.get("instance_id"))
	return 0
