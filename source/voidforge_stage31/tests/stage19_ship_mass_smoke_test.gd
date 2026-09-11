extends Node
## Stage 19 regression coverage for authoritative BlockDB-derived ship mass and its
## synchronization with the single BlockGrid RigidBody3D physics carrier.

const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const BLOCK_DEFINITION_SCRIPT := preload("res://scripts/blocks/block_definition.gd")
const REINFORCED_ID: StringName = &"frame_reinforced_large"
const HEAVY_ID: StringName = &"armor_shell_heavy_large"
const BEAM_ID: StringName = &"beam_long_large"
const LIGHT_ID: StringName = &"armor_shell_light_large"
const EXPECT_REINFORCED_KG: float = 280.0
const EXPECT_HEAVY_KG: float = 720.0
const EXPECT_BEAM_KG: float = 190.0
const EXPECT_TOTAL_KG: float = 1190.0

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	await _run_checks()

func _run_checks() -> void:
	var reinforced := BlockDB.call("get_block", REINFORCED_ID) as Resource
	var heavy := BlockDB.call("get_block", HEAVY_ID) as Resource
	var beam := BlockDB.call("get_block", BEAM_ID) as Resource
	var light := BlockDB.call("get_block", LIGHT_ID) as Resource
	_assert(reinforced != null and heavy != null and beam != null and light != null, "Stage 19 mass fixtures resolve from BlockDB")
	if reinforced == null or heavy == null or beam == null or light == null:
		_finish()
		return
	_assert(is_equal_approx(float(reinforced.get("mass_kg")), EXPECT_REINFORCED_KG), "Reinforced frame mass metadata matches production catalog")
	_assert(is_equal_approx(float(heavy.get("mass_kg")), EXPECT_HEAVY_KG), "Heavy armor mass metadata matches production catalog")
	_assert(is_equal_approx(float(beam.get("mass_kg")), EXPECT_BEAM_KG), "Two-cell beam carries one authoritative block mass")

	var grid := GRID_SCENE.instantiate() as RigidBody3D
	grid.name = "MassCalculationGrid"
	add_child(grid)
	await get_tree().process_frame
	_assert(is_zero_approx(float(grid.call("get_total_mass_kg"))), "Empty grid reports zero authoritative block mass")
	_assert(grid.mass > 0.0 and grid.mass < 0.01, "Empty rigid body uses only the tiny nonzero Godot mass safety floor")

	var mass_events: Array[float] = []
	grid.connect("mass_changed", func(total_mass_kg: float, _physics_mass_kg: float) -> void: mass_events.append(total_mass_kg))
	var reinforced_instance := grid.call("place_block", reinforced, Vector3i.ZERO, 0) as Resource
	_assert(reinforced_instance != null, "Reinforced frame can be placed for mass calculation")
	_assert(is_equal_approx(float(grid.call("get_total_mass_kg")), EXPECT_REINFORCED_KG), "Placement adds BlockDB mass exactly once")
	_assert(is_equal_approx(grid.mass, EXPECT_REINFORCED_KG), "RigidBody3D mass follows calculated grid mass after placement")

	var heavy_instance := grid.call("place_block", heavy, Vector3i(1, 0, 0), 0) as Resource
	var beam_instance := grid.call("place_block", beam, Vector3i(-2, 0, 0), 0) as Resource
	_assert(heavy_instance != null and beam_instance != null, "Mixed-mass blocks can be added to the same grid")
	_assert(is_equal_approx(float(grid.call("get_total_mass_kg")), EXPECT_TOTAL_KG), "Mixed grid mass equals the sum of authoritative block masses")
	_assert(is_equal_approx(grid.mass, EXPECT_TOTAL_KG), "Rigid-body mass equals mixed grid catalog mass")
	_assert(mass_events == [280.0, 1000.0, 1190.0], "Mass changes emit deterministic cumulative totals")

	var mass_state := grid.call("get_mass_state") as Dictionary
	_assert(is_equal_approx(float(mass_state.get("total_mass_kg", -1.0)), EXPECT_TOTAL_KG), "Mass diagnostics expose authoritative total")
	_assert(is_equal_approx(float(mass_state.get("physics_mass_kg", -1.0)), EXPECT_TOTAL_KG), "Mass diagnostics expose synchronized physics mass")
	_assert(int(mass_state.get("block_count", -1)) == 3 and not bool(mass_state.get("uses_safety_floor", true)), "Mass diagnostics expose block count and occupied-grid physics state")
	var breakdown := grid.call("get_mass_breakdown_by_block_id") as Dictionary
	_assert(int((breakdown[String(REINFORCED_ID)] as Dictionary).get("count", 0)) == 1, "Mass breakdown counts reinforced frames")
	_assert(is_equal_approx(float((breakdown[String(HEAVY_ID)] as Dictionary).get("subtotal_kg", 0.0)), EXPECT_HEAVY_KG), "Mass breakdown reports per-block-type subtotal")
	_assert(is_equal_approx(float((breakdown[String(BEAM_ID)] as Dictionary).get("subtotal_kg", 0.0)), EXPECT_BEAM_KG), "Multi-cell block contributes one beam subtotal, not per occupied cell")

	var removed := grid.call("remove_block_by_instance_id", int(heavy_instance.get("instance_id"))) as Resource
	_assert(removed == heavy_instance, "Mass test removes the intended heavy armor instance")
	_assert(is_equal_approx(float(grid.call("get_total_mass_kg")), EXPECT_REINFORCED_KG + EXPECT_BEAM_KG), "Removal subtracts the removed block mass exactly once")
	_assert(is_equal_approx(grid.mass, EXPECT_REINFORCED_KG + EXPECT_BEAM_KG), "Rigid-body mass updates immediately after removal")

	# Re-add heavy armor so persistence can prove mass is recomputed rather than serialized as
	# a trusted standalone number.
	heavy_instance = grid.call("place_block", heavy, Vector3i(1, 0, 0), 0) as Resource
	_assert(heavy_instance != null and is_equal_approx(float(grid.call("get_total_mass_kg")), EXPECT_TOTAL_KG), "Re-adding heavy armor restores the expected total")
	var json_text := JSON.stringify(grid.call("get_save_state") as Dictionary)
	var parsed = JSON.parse_string(json_text)
	_assert(typeof(parsed) == TYPE_DICTIONARY, "Grid mass fixture survives JSON serialization")

	var loaded := GRID_SCENE.instantiate() as RigidBody3D
	loaded.name = "LoadedMassGrid"
	add_child(loaded)
	await get_tree().process_frame
	_assert(loaded.call("place_block", light, Vector3i.ZERO, 0) != null, "Load target starts with different preexisting mass")
	_assert(bool(loaded.call("load_save_state", parsed as Dictionary)), "Grid save state loads transactionally with Stage 19 mass calculation")
	_assert(is_equal_approx(float(loaded.call("get_total_mass_kg")), EXPECT_TOTAL_KG), "Load recomputes authoritative mass from restored block IDs")
	_assert(is_equal_approx(loaded.mass, EXPECT_TOTAL_KG), "Loaded rigid body receives the restored calculated mass")
	_assert((loaded.call("get_integrity_errors") as Array).is_empty(), "Loaded grid integrity audit includes a clean mass-cache/physics-mass check")

	# Deliberately desynchronize the engine property and prove the audit detects and the public
	# recalculation API repairs it without changing authoritative block state.
	loaded.mass = 9999.0
	var drift_errors := loaded.call("get_integrity_errors") as Array
	_assert(_array_contains_text(drift_errors, "Rigid-body mass"), "Integrity audit detects external rigid-body mass drift")
	_assert(bool(loaded.call("recalculate_mass_from_blocks")), "Public mass recalculation succeeds on valid registered blocks")
	_assert(is_equal_approx(loaded.mass, EXPECT_TOTAL_KG), "Mass recalculation repairs rigid-body mass drift")
	_assert((loaded.call("get_integrity_errors") as Array).is_empty(), "Mass integrity audit is clean after recalculation")

	# Registered block IDs are canonical even if a transient Resource attempts to spoof mass.
	var spoof := BLOCK_DEFINITION_SCRIPT.new() as Resource
	spoof.set("id", REINFORCED_ID)
	spoof.set("display_name", "Spoof")
	spoof.set("description", "Transient mass-spoof fixture")
	var spoof_profiles: Array[StringName] = [&"large", &"static"]
	spoof.set("allowed_grid_sizes", spoof_profiles)
	spoof.set("dimensions_cells", Vector3i.ONE)
	spoof.set("mass_kg", 1.0)
	var spoof_grid := GRID_SCENE.instantiate() as RigidBody3D
	spoof_grid.name = "CanonicalMassGrid"
	add_child(spoof_grid)
	await get_tree().process_frame
	_assert(spoof_grid.call("place_block", spoof, Vector3i.ZERO, 0) != null, "Registered-ID transient fixture can exercise canonical mass lookup")
	_assert(is_equal_approx(float(spoof_grid.call("get_total_mass_kg")), EXPECT_REINFORCED_KG), "Registered block ID uses BlockDB mass instead of spoofed Resource mass")

	# Same impulse on two otherwise equivalent dynamic grids demonstrates that the calculated
	# block mass now directly affects real rigid-body acceleration.
	var light_grid := GRID_SCENE.instantiate() as RigidBody3D
	var heavy_grid := GRID_SCENE.instantiate() as RigidBody3D
	light_grid.name = "LightImpulseGrid"
	heavy_grid.name = "HeavyImpulseGrid"
	light_grid.position = Vector3(-10.0, 10.0, 0.0)
	heavy_grid.position = Vector3(10.0, 10.0, 0.0)
	for physics_grid in [light_grid, heavy_grid]:
		physics_grid.set("dynamic_gravity_scale", 0.0)
		physics_grid.set("dynamic_linear_damp", 0.0)
		physics_grid.set("dynamic_angular_damp", 0.0)
		add_child(physics_grid)
	await get_tree().process_frame
	_assert(light_grid.call("place_block", light, Vector3i.ZERO, 0) != null, "Light impulse grid receives light armor")
	_assert(heavy_grid.call("place_block", heavy, Vector3i.ZERO, 0) != null, "Heavy impulse grid receives heavy armor")
	_assert(bool(light_grid.call("set_dynamic_simulation_enabled", true)) and bool(heavy_grid.call("set_dynamic_simulation_enabled", true)), "Mass comparison grids enter dynamic simulation")
	light_grid.apply_central_impulse(Vector3(720.0, 0.0, 0.0))
	heavy_grid.apply_central_impulse(Vector3(720.0, 0.0, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert(light_grid.linear_velocity.x > heavy_grid.linear_velocity.x * 1.8, "Same impulse accelerates the lighter BlockDB-mass grid substantially more")
	_assert(light_grid.linear_velocity.x > 1.8 and heavy_grid.linear_velocity.x > 0.8 and heavy_grid.linear_velocity.x < 1.2, "Rigid-body impulse response is consistent with 350 kg versus 720 kg craft mass")

	grid.call("clear_grid")
	_assert(is_zero_approx(float(grid.call("get_total_mass_kg"))), "Clearing a grid returns authoritative block mass to zero")
	_assert(grid.mass > 0.0 and grid.mass < 0.01, "Cleared rigid body returns to the nonzero engine safety floor")
	_assert((grid.call("get_integrity_errors") as Array).is_empty(), "Cleared grid mass state passes integrity audit")

	_finish()

func _array_contains_text(values: Array, fragment: String) -> bool:
	for value in values:
		if fragment in String(value):
			return true
	return false

func _finish() -> void:
	if _failures.is_empty():
		print("STAGE19_SHIP_MASS_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE19_SHIP_MASS_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
