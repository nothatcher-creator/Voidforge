extends Node
## Stage 13 regression coverage for versioned JSON-friendly grid persistence, transactional
## malformed-data rejection, safe instance-ID restoration, and presenter rebuild after load.

const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const BLOCK_DEFINITION_SCRIPT := preload("res://scripts/blocks/block_definition.gd")
const BLOCK_ORIENTATION := preload("res://scripts/grids/block_orientation.gd")
const HULL_FRAME := preload("res://data/blocks/dev_hull_frame.tres")
const SPAN_FRAME := preload("res://data/blocks/dev_span_frame.tres")

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_checks()

func _run_checks() -> void:
	var static_profile := GridDB.call("get_profile", &"static") as Resource
	_assert(static_profile != null, "Static grid profile is available for persistence fixture")

	var source := GRID_SCENE.instantiate() as Node3D
	add_child(source)
	_assert(bool(source.call("configure", static_profile)), "Source grid can switch from large to static before construction")
	var unit := HULL_FRAME
	var span := SPAN_FRAME
	var quarter_turn := BLOCK_ORIENTATION.rotate_index_around_axis(0, Vector3i(0, 0, 1), 1)

	var first := source.call("place_block", unit, Vector3i.ZERO, 0) as Resource
	var rotated := source.call("place_block", span, Vector3i(2, 0, 0), quarter_turn) as Resource
	_assert(first != null and rotated != null, "Source persistence fixture places single and rotated multi-cell blocks")
	_assert(source.call("remove_block_by_instance_id", int(first.get("instance_id"))) != null, "Source fixture creates a non-contiguous instance-ID history")
	var third := source.call("place_block", unit, Vector3i(-2, -1, 0), 0) as Resource
	_assert(third != null and int(third.get("instance_id")) == 3, "Source fixture preserves monotonic instance IDs before save")
	_assert(int(source.call("get_next_instance_id")) == 4, "Source fixture exposes next instance ID 4")

	var saved := source.call("get_save_state") as Dictionary
	_assert(String(saved.get("schema", "")) == "voidforge.block_grid", "Grid save state carries stable schema ID")
	_assert(int(saved.get("version", 0)) == 3, "Grid save state carries current version 3")
	_assert(String(saved.get("grid_profile_id", "")) == "static", "Grid save state records grid profile/type")
	_assert(int(saved.get("next_instance_id", 0)) == 4, "Grid save state records next instance ID")
	var blocks := saved.get("blocks", []) as Array
	_assert(blocks.size() == 2, "Grid save state serializes one record per live block instance")
	_assert(_state_uses_primitive_triplets(saved), "Grid persistence uses JSON-friendly integer triplets instead of Vector3i values")

	var json_text := JSON.stringify(saved)
	var parsed_variant = JSON.parse_string(json_text)
	_assert(typeof(parsed_variant) == TYPE_DICTIONARY, "Grid save state survives JSON stringify/parse round trip")
	var parsed := parsed_variant as Dictionary

	var target := GRID_SCENE.instantiate() as Node3D
	add_child(target)
	var presenter := target.get_node("BlockPresenter") as Node3D
	var stale_a := _make_block(&"stale_a", Vector3i.ONE, [&"large"])
	var stale_b := _make_block(&"stale_b", Vector3i.ONE, [&"large"])
	target.call("place_block", stale_a, Vector3i.ZERO, 0)
	target.call("place_block", stale_b, Vector3i(3, 0, 0), 0)
	await _process_frames(3)
	_assert(int(target.call("get_block_count")) == 2 and int(presenter.call("get_presented_block_count")) == 2, "Target begins with same-count stale presenter state")
	var reload_events: Array[int] = []
	target.connect("grid_reloaded", func(block_count: int, _cell_count: int) -> void: reload_events.append(block_count))

	_assert(bool(target.call("load_save_state", parsed)), "JSON-parsed Stage 13 state loads transactionally")
	await _process_frames(3)
	_assert(StringName(target.call("get_grid_type")) == &"static" and bool(target.call("is_static_grid")), "Load restores grid profile/type over previous target profile")
	_assert(int(target.call("get_block_count")) == 2 and int(target.call("get_occupied_cell_count")) == 3, "Load restores unique blocks and rotated occupied-cell footprint")
	_assert(reload_events.size() == 1 and reload_events[0] == 2, "Successful load emits one grid_reloaded event")
	_assert(int(target.call("get_next_instance_id")) == 4, "Load restores saved next instance ID when already safe")
	_assert((_grid_state_json(target)) == JSON.stringify(saved), "Save-load-save round trip is deterministic")
	_assert((target.call("get_integrity_errors") as Array).is_empty(), "Loaded grid passes structural integrity audit")

	var loaded_rotated := target.call("get_block_by_instance_id", 2) as Resource
	var loaded_third := target.call("get_block_by_instance_id", 3) as Resource
	_assert(loaded_rotated != null and StringName(loaded_rotated.get("block_id")) == &"dev_span_frame", "Load restores stable block ID and instance ID")
	_assert(loaded_rotated != null and Vector3i(loaded_rotated.get("anchor_cell")) == Vector3i(2, 0, 0), "Load restores block anchor cell")
	_assert(loaded_rotated != null and Vector3i(loaded_rotated.get("dimensions_cells")) == Vector3i(2, 1, 1), "Load restores definition-local dimensions")
	_assert(loaded_rotated != null and int(loaded_rotated.get("orientation_index")) == quarter_turn, "Load restores compact orientation index")
	_assert(loaded_rotated != null and Vector3i(loaded_rotated.call("get_oriented_dimensions_cells")) == Vector3i(1, 2, 1), "Loaded orientation recreates rotated footprint")
	_assert(loaded_third != null and Vector3i(loaded_third.get("anchor_cell")) == Vector3i(-2, -1, 0), "Load preserves negative grid coordinates")

	_assert(presenter.call("get_block_body", 1) == null, "Presenter rebuild removes stale same-count collision mapping after load")
	var restored_body := presenter.call("get_block_body", 2) as CollisionObject3D
	var restored_body_three := presenter.call("get_block_body", 3) as CollisionObject3D
	_assert(restored_body != null and restored_body_three != null and restored_body == restored_body_three, "Presenter rebuild maps all loaded instances into one shared collision body")
	if restored_body != null and loaded_rotated != null:
		var restored_transform := presenter.call("get_block_collision_transform", 2) as Transform3D
		_assert(_basis_equal(restored_transform.basis, loaded_rotated.call("get_orientation_basis") as Basis), "Presenter rebuild preserves loaded block orientation in shape-owner transform")
	_assert(int(presenter.call("get_presented_block_count")) == 2, "Presenter remains synchronized when load replaces state with same block count")

	await _check_safe_next_id_restoration(target, saved, unit)
	await _check_malformed_rejection(target, saved)

	if _failures.is_empty():
		print("STAGE13_GRID_SAVE_LOAD_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE13_GRID_SAVE_LOAD_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _check_safe_next_id_restoration(target: Node3D, saved: Dictionary, unit: Resource) -> void:
	var clamped := saved.duplicate(true)
	clamped["next_instance_id"] = 1
	_assert(bool(target.call("load_save_state", clamped)), "Loader accepts stale-but-positive next instance ID")
	_assert(int(target.call("get_next_instance_id")) == 4, "Loader clamps next instance ID above highest restored live ID")
	var next_block := target.call("place_block", unit, Vector3i(6, 0, 0), 0) as Resource
	_assert(next_block != null and int(next_block.get("instance_id")) == 4, "Placement after clamped restore cannot reuse a live instance ID")

	var high := saved.duplicate(true)
	high["next_instance_id"] = 99
	_assert(bool(target.call("load_save_state", high)), "Loader accepts intentionally advanced next instance ID")
	_assert(int(target.call("get_next_instance_id")) == 99, "Loader preserves a safe advanced next instance ID")
	var high_block := target.call("place_block", unit, Vector3i(6, 0, 0), 0) as Resource
	_assert(high_block != null and int(high_block.get("instance_id")) == 99, "Placement continues from preserved advanced next instance ID")

func _check_malformed_rejection(target: Node3D, saved: Dictionary) -> void:
	_assert_rejected_unchanged(target, _with_value(saved, "schema", "wrong.schema"), "Unknown save schema is rejected atomically")
	_assert_rejected_unchanged(target, _with_value(saved, "version", 999), "Unsupported save version is rejected atomically")
	_assert_rejected_unchanged(target, _with_value(saved, "grid_profile_id", "unknown"), "Unknown grid profile is rejected atomically")
	_assert_rejected_unchanged(target, _with_value(saved, "next_instance_id", "bad"), "Malformed next instance ID is rejected atomically")
	_assert_rejected_unchanged(target, _with_value(saved, "blocks", "not-an-array"), "Malformed block list is rejected atomically")

	var duplicate_id := saved.duplicate(true)
	var duplicate_blocks := duplicate_id["blocks"] as Array
	duplicate_blocks.append((duplicate_blocks[0] as Dictionary).duplicate(true))
	_assert_rejected_unchanged(target, duplicate_id, "Duplicate block instance IDs are rejected atomically")

	var overlap := saved.duplicate(true)
	var overlap_blocks := overlap["blocks"] as Array
	var overlapping_entry := (overlap_blocks[0] as Dictionary).duplicate(true)
	overlapping_entry["instance_id"] = 77
	overlap_blocks.append(overlapping_entry)
	_assert_rejected_unchanged(target, overlap, "Overlapping restored block footprints are rejected atomically")

	var bad_orientation := saved.duplicate(true)
	((bad_orientation["blocks"] as Array)[0] as Dictionary)["orientation_index"] = 24
	_assert_rejected_unchanged(target, bad_orientation, "Out-of-range orientation index is rejected atomically")

	var zero_dimensions := saved.duplicate(true)
	((zero_dimensions["blocks"] as Array)[0] as Dictionary)["dimensions_cells"] = [0, 1, 1]
	_assert_rejected_unchanged(target, zero_dimensions, "Zero block dimensions are rejected atomically")

	var bad_anchor := saved.duplicate(true)
	((bad_anchor["blocks"] as Array)[0] as Dictionary)["anchor_cell"] = [1, 2]
	_assert_rejected_unchanged(target, bad_anchor, "Malformed anchor triplet is rejected atomically")

	var fractional_anchor := saved.duplicate(true)
	((fractional_anchor["blocks"] as Array)[0] as Dictionary)["anchor_cell"] = [0.5, 0, 0]
	_assert_rejected_unchanged(target, fractional_anchor, "Fractional grid coordinates are rejected atomically")

	var empty_block_id := saved.duplicate(true)
	((empty_block_id["blocks"] as Array)[0] as Dictionary)["block_id"] = ""
	_assert_rejected_unchanged(target, empty_block_id, "Empty block IDs are rejected atomically")

func _assert_rejected_unchanged(target: Node3D, candidate: Dictionary, description: String) -> void:
	var before := _grid_state_json(target)
	var profile_before := StringName(target.call("get_grid_type"))
	var block_count_before := int(target.call("get_block_count"))
	var cell_count_before := int(target.call("get_occupied_cell_count"))
	var result := bool(target.call("load_save_state", candidate))
	var unchanged := (
		not result
		and _grid_state_json(target) == before
		and StringName(target.call("get_grid_type")) == profile_before
		and int(target.call("get_block_count")) == block_count_before
		and int(target.call("get_occupied_cell_count")) == cell_count_before
		and (target.call("get_integrity_errors") as Array).is_empty()
	)
	_assert(unchanged, description)

func _with_value(source: Dictionary, key: String, value) -> Dictionary:
	var copy := source.duplicate(true)
	copy[key] = value
	return copy

func _state_uses_primitive_triplets(state: Dictionary) -> bool:
	for raw_block in state.get("blocks", []):
		if typeof(raw_block) != TYPE_DICTIONARY:
			return false
		var block := raw_block as Dictionary
		if typeof(block.get("anchor_cell")) != TYPE_ARRAY or typeof(block.get("dimensions_cells")) != TYPE_ARRAY:
			return false
		if (block["anchor_cell"] as Array).size() != 3 or (block["dimensions_cells"] as Array).size() != 3:
			return false
	return true

func _grid_state_json(grid: Node3D) -> String:
	return JSON.stringify(grid.call("get_save_state") as Dictionary)

func _make_block(block_id: StringName, dimensions: Vector3i, profiles: Array[StringName]) -> Resource:
	var definition: Resource = BLOCK_DEFINITION_SCRIPT.new()
	definition.set("id", block_id)
	definition.set("display_name", String(block_id))
	definition.set("dimensions_cells", dimensions)
	definition.set("allowed_grid_sizes", profiles)
	return definition

func _process_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _basis_equal(a: Basis, b: Basis) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.z.is_equal_approx(b.z)

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
