extends Node3D
## Active Stage 29 wrapper. Retains Stage 28 and adds a mixed-system craft for terminal inspection.

const PILOT_SEAT_ID: StringName = &"pilot_cradle_large"
const THRUSTER_ID: StringName = &"pulse_thruster_large"
const GYRO_ID: StringName = &"vector_gyro_large"
const REACTOR_ID: StringName = &"helix_core_reactor_large"
const BATTERY_ID: StringName = &"flux_reservoir_large"
const AUX_LOAD_ID: StringName = &"dev_aux_load_large"
const FRAME_ID: StringName = &"frame_lattice_large"
const ARMOR_ID: StringName = &"armor_shell_heavy_large"

@onready var terminal_grid: RigidBody3D = $TerminalCraft
@onready var terminal_presenter: Node3D = $TerminalCraft/BlockPresenter

func _ready() -> void:
	_seed_terminal_craft()
	if terminal_presenter != null:
		terminal_presenter.call("flush_collision_now")
		terminal_presenter.call("flush_geometry_now")
		var seat_presenter := terminal_presenter.call("get_control_seat_presenter") as Node3D
		if seat_presenter != null:
			seat_presenter.call("flush_now")
	if terminal_grid != null:
		var power := terminal_grid.call("get_power_network_state") as Dictionary
		DebugLog.info(
			"Stage29Terminal",
			"Terminal craft ready | %d blocks | %.0f kg | %.0f kW generation | %.0f kWh battery capacity" % [
				int(terminal_grid.call("get_block_count")),
				float(terminal_grid.call("get_total_mass_kg")),
				float(power.get("generation_kw", 0.0)),
				float(power.get("battery_capacity_kwh", 0.0)),
			]
		)

func _seed_terminal_craft() -> void:
	if terminal_grid == null or int(terminal_grid.call("get_block_count")) > 0:
		return
	var placements := [
		[PILOT_SEAT_ID, Vector3i.ZERO],
		[GYRO_ID, Vector3i(0, 1, 0)],
		[THRUSTER_ID, Vector3i(0, 0, 1)],
		[REACTOR_ID, Vector3i(-1, 0, 0)],
		[BATTERY_ID, Vector3i(1, 0, 0)],
		[AUX_LOAD_ID, Vector3i(0, -1, 0)],
		[FRAME_ID, Vector3i(0, 0, -1)],
		[ARMOR_ID, Vector3i(2, 0, 0)],
	]
	for placement in placements:
		var definition := BlockDB.call("get_block", placement[0]) as Resource
		if definition == null:
			DebugLog.error("Stage29Terminal", "Missing terminal craft block definition %s" % String(placement[0]))
			return
		if terminal_grid.call("place_block", definition, placement[1], 0) == null:
			DebugLog.error("Stage29Terminal", "Failed to place %s at %s" % [String(placement[0]), str(placement[1])])
			return
