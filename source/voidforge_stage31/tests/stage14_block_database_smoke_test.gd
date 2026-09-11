extends Node
## Stage 14 regression coverage for authoritative block metadata, catalog queries,
## construction resolution, and catalog-backed persistent grid restoration.

const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const BLOCK_DEFINITION_SCRIPT := preload("res://scripts/blocks/block_definition.gd")
const BLOCK_COST_SCRIPT := preload("res://scripts/blocks/block_cost_entry.gd")
const BUILD_CONTROLLER_SCRIPT := preload("res://scripts/building/block_placement_controller.gd")
const BLOCK_ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const HULL_FRAME := preload("res://data/blocks/dev_hull_frame.tres")
const SPAN_FRAME := preload("res://data/blocks/dev_span_frame.tres")

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	_run_registry_checks()
	await _run_persistence_checks()
	_run_construction_resolution_checks()
	if _failures.is_empty():
		print("STAGE14_BLOCK_DATABASE_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE14_BLOCK_DATABASE_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _run_registry_checks() -> void:
	_assert(bool(BlockDB.call("is_database_valid")), "BlockDB loads a valid explicit block catalog")
	_assert(int(BlockDB.call("get_block_count")) >= 2, "BlockDB retains the two Stage 14 development block definitions after later catalog expansion")
	_assert(bool(BlockDB.call("has_block", &"dev_hull_frame")) and bool(BlockDB.call("has_block", &"dev_span_frame")), "Stable block IDs resolve through BlockDB")
	var hull := BlockDB.call("get_block", &"dev_hull_frame") as Resource
	var span := BlockDB.call("get_block", &"dev_span_frame") as Resource
	_assert(hull != null and hull.resource_path == HULL_FRAME.resource_path, "Hull Frame lookup resolves the catalog resource")
	_assert(span != null and span.resource_path == SPAN_FRAME.resource_path, "Span Frame lookup resolves the catalog resource")
	_assert(String(hull.get("display_name")) == "Hull Frame" and not String(hull.get("description")).is_empty(), "Identity metadata exposes readable name and description")
	_assert(StringName(hull.get("category")) == &"structure", "Block category metadata is available")
	_assert(Vector3i(hull.get("dimensions_cells")) == Vector3i.ONE and Vector3i(span.get("dimensions_cells")) == Vector3i(2, 1, 1), "Catalog preserves discrete block dimensions")
	_assert(float(hull.get("mass_kg")) == 180.0 and float(span.get("mass_kg")) == 320.0, "Catalog exposes block mass metadata")
	_assert(float(hull.get("max_integrity")) == 240.0 and float(span.get("max_integrity")) == 410.0, "Catalog exposes integrity metadata")
	_assert(bool(hull.call("allows_grid", &"large")) and bool(hull.call("allows_grid", &"static")) and not bool(hull.call("allows_grid", &"small")), "Grid compatibility metadata is queryable")
	_assert(int(hull.call("get_attachment_face_count")) == 6 and bool(hull.call("has_attachment_face", 0)) and bool(hull.call("has_attachment_face", 5)), "Six-face attachment metadata is queryable")
	_assert(int(hull.call("get_build_cost_quantity", &"component_structural_plate")) == 12 and int(hull.call("get_build_cost_quantity", &"component_machine_frame")) == 2, "Hull Frame construction cost resolves ItemDB stable IDs")
	_assert(int(span.call("get_total_build_cost_units")) == 24 and int(span.get("construction_stages")) == 4, "Span Frame exposes total build units and construction-stage metadata")
	_assert(StringName(hull.get("functional_type")) == &"structural" and float(hull.get("power_use_kw")) == 0.0 and int(hull.get("conveyor_port_count")) == 0, "Functional metadata foundation has explicit structural defaults")
	_assert((hull.call("get_validation_errors", ItemDB) as Array).is_empty() and (span.call("get_validation_errors", ItemDB) as Array).is_empty(), "Production block resources pass full metadata and ItemDB-reference validation")

	var categories := BlockDB.call("get_categories") as Array
	_assert(categories.size() >= 1 and &"structure" in categories, "BlockDB returns deterministic category queries including structure")
	_assert((BlockDB.call("get_blocks_by_category", &"structure") as Array).size() >= 2, "Category query retains both structural development blocks")
	_assert((BlockDB.call("get_blocks_with_tag", &"structural") as Array).size() >= 2, "Tag query retains both structural development blocks")
	_assert((BlockDB.call("get_blocks_with_tag", &"rotation_test") as Array).size() == 1, "Tag query isolates the rotation-test block")
	var copied := BlockDB.call("get_all_blocks") as Array
	copied.clear()
	_assert(int(BlockDB.call("get_block_count")) >= 2, "BlockDB query arrays are defensive copies")

	var duplicate_errors := BlockDB.call("validate_definitions", [HULL_FRAME, HULL_FRAME]) as Array
	_assert(_contains_text(duplicate_errors, "Duplicate block ID"), "BlockDB rejects duplicate stable block IDs")

	var invalid := HULL_FRAME.duplicate(true) as Resource
	invalid.set("id", &"Bad-ID")
	var duplicate_grids: Array[StringName] = [&"large", &"large"]
	invalid.set("allowed_grid_sizes", duplicate_grids)
	invalid.set("dimensions_cells", Vector3i(0, 1, 1))
	invalid.set("mass_kg", 0.0)
	var invalid_errors := invalid.call("get_validation_errors", ItemDB) as Array
	_assert(_contains_text(invalid_errors, "lowercase snake_case") and _contains_text(invalid_errors, "Duplicate allowed grid ID") and _contains_text(invalid_errors, "dimensions") and _contains_text(invalid_errors, "mass"), "BlockDefinition rejects malformed identity/grid/physical metadata")

	var unknown_cost := BLOCK_COST_SCRIPT.new() as Resource
	unknown_cost.set("item_id", &"does_not_exist")
	unknown_cost.set("quantity", 1)
	var bad_cost_block := HULL_FRAME.duplicate(true) as Resource
	bad_cost_block.set("id", &"bad_cost_block")
	var bad_costs: Array[Resource] = [unknown_cost]
	bad_cost_block.set("build_cost", bad_costs)
	var bad_cost_errors := bad_cost_block.call("get_validation_errors", ItemDB) as Array
	_assert(_contains_text(bad_cost_errors, "not registered in ItemDB"), "Construction costs reject missing item references")

func _run_persistence_checks() -> void:
	var static_profile := GridDB.call("get_profile", &"static") as Resource
	var source := GRID_SCENE.instantiate() as Node3D
	add_child(source)
	_assert(bool(source.call("configure", static_profile)), "Stage 14 persistence source can use Static Grid profile")
	var quarter_turn := BLOCK_ORIENTATION.rotate_index_around_axis(0, Vector3i(0, 0, 1), 1)
	_assert(source.call("place_block", HULL_FRAME, Vector3i.ZERO, 0) != null, "Catalog Hull Frame places on an allowed grid")
	_assert(source.call("place_block", SPAN_FRAME, Vector3i(2, 0, 0), quarter_turn) != null, "Catalog Span Frame places with rotated footprint")
	var saved := source.call("get_save_state") as Dictionary

	var target := GRID_SCENE.instantiate() as Node3D
	add_child(target)
	_assert(bool(target.call("load_save_state", saved)), "Catalog-backed grid state loads successfully")
	_assert(int(target.call("get_block_count")) == 2 and (target.call("get_integrity_errors") as Array).is_empty(), "Loaded catalog-backed grid remains structurally valid")

	var before := JSON.stringify(target.call("get_save_state") as Dictionary)
	var unknown := saved.duplicate(true)
	((unknown["blocks"] as Array)[0] as Dictionary)["block_id"] = "missing_block_type"
	_assert(not bool(target.call("load_save_state", unknown)) and JSON.stringify(target.call("get_save_state") as Dictionary) == before, "Unknown persisted block IDs are rejected transactionally")

	var mismatched_dimensions := saved.duplicate(true)
	((mismatched_dimensions["blocks"] as Array)[0] as Dictionary)["dimensions_cells"] = [2, 1, 1]
	_assert(not bool(target.call("load_save_state", mismatched_dimensions)) and JSON.stringify(target.call("get_save_state") as Dictionary) == before, "Persisted dimensions that disagree with BlockDB are rejected transactionally")

	var forbidden_profile := saved.duplicate(true)
	forbidden_profile["grid_profile_id"] = "small"
	_assert(not bool(target.call("load_save_state", forbidden_profile)) and JSON.stringify(target.call("get_save_state") as Dictionary) == before, "Persisted blocks incompatible with the restored grid profile are rejected transactionally")

	var spoof := BLOCK_DEFINITION_SCRIPT.new() as Resource
	spoof.set("id", &"dev_hull_frame")
	spoof.set("display_name", "Spoof")
	spoof.set("description", "Transient definition attempting to reuse a registered stable ID.")
	var spoof_grids: Array[StringName] = [&"large"]
	spoof.set("allowed_grid_sizes", spoof_grids)
	spoof.set("dimensions_cells", Vector3i(2, 1, 1))
	_assert(not bool(target.call("can_place_block", spoof, Vector3i(8, 0, 0), 0)), "Transient definitions cannot spoof a registered ID with different canonical dimensions")

	source.queue_free()
	target.queue_free()
	await get_tree().process_frame

func _run_construction_resolution_checks() -> void:
	var controller := BUILD_CONTROLLER_SCRIPT.new() as Node3D
	_assert(bool(controller.call("set_build_block_id", &"dev_span_frame")), "Construction controller can select a block by stable BlockDB ID")
	var resolved := controller.call("get_build_definition") as Resource
	_assert(resolved != null and resolved.resource_path == SPAN_FRAME.resource_path and StringName(controller.call("get_build_block_id")) == &"dev_span_frame", "Stable-ID construction selection resolves the canonical catalog resource")
	_assert(not bool(controller.call("set_build_block_id", &"missing_block")), "Construction controller rejects unknown stable block IDs")
	var spoof := BLOCK_DEFINITION_SCRIPT.new() as Resource
	spoof.set("id", &"dev_hull_frame")
	controller.call("set_build_definition", spoof)
	resolved = controller.call("get_build_definition") as Resource
	_assert(resolved != null and resolved.resource_path == HULL_FRAME.resource_path, "Direct construction assignment canonicalizes registered block IDs through BlockDB")
	controller.free()

func _contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if needle.to_lower() in String(value).to_lower():
			return true
	return false

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
