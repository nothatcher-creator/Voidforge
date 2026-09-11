extends Node
## Stage 9 regression coverage for sparse grid occupancy and coordinate/state invariants.

const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const BLOCK_DEFINITION_SCRIPT := preload("res://scripts/blocks/block_definition.gd")

var _failures: Array[String] = []
var _grid: Node3D
var _added_events: Array[int] = []
var _removed_events: Array[int] = []

func _ready() -> void:
	await get_tree().process_frame
	_run_checks()

func _run_checks() -> void:
	_assert(GridDB != null and bool(GridDB.call("is_database_valid")), "Grid profile registry validates")
	_assert(int(GridDB.call("get_profile_count")) == 3, "Exactly three Stage 9 grid profiles are registered")
	var small_profile := GridDB.call("get_profile", &"small") as Resource
	var large_profile := GridDB.call("get_profile", &"large") as Resource
	var static_profile := GridDB.call("get_profile", &"static") as Resource
	_assert(small_profile != null and is_equal_approx(float(small_profile.get("cell_size_m")), 0.5), "Small grid uses 0.5 m cells")
	_assert(large_profile != null and is_equal_approx(float(large_profile.get("cell_size_m")), 2.5), "Large grid uses 2.5 m cells")
	_assert(static_profile != null and bool(static_profile.get("is_static")), "Static grid profile is explicitly static")
	_assert(GridDB.call("get_profile", &"unknown") == null, "Unknown grid profile lookup returns null")

	_grid = GRID_SCENE.instantiate() as Node3D
	_grid.position = Vector3(10.0, 3.0, -5.0)
	add_child(_grid)
	_grid.connect("block_added", Callable(self, "_on_block_added"))
	_grid.connect("block_removed", Callable(self, "_on_block_removed"))
	_assert(StringName(_grid.call("get_grid_type")) == &"large", "Prototype scene defaults to large grid")
	_assert(is_equal_approx(float(_grid.call("get_cell_size_m")), 2.5), "Grid exposes profile cell size")
	_assert(not bool(_grid.call("is_static_grid")), "Large prototype grid is dynamic-capable")

	var local_point := _grid.call("grid_to_local", Vector3i(2, -1, 3)) as Vector3
	_assert(local_point.is_equal_approx(Vector3(5.0, -2.5, 7.5)), "Grid-to-local conversion uses cell centers")
	_assert(Vector3i(_grid.call("local_to_grid", Vector3(5.1, -2.4, 7.4))) == Vector3i(2, -1, 3), "Local-to-grid conversion snaps to nearest cell center")
	var world_point := _grid.call("grid_to_world", Vector3i(2, 0, -1)) as Vector3
	_assert(world_point.is_equal_approx(Vector3(15.0, 3.0, -7.5)), "Grid-to-world conversion respects grid transform")
	_assert(Vector3i(_grid.call("world_to_grid", world_point)) == Vector3i(2, 0, -1), "World-to-grid round trip is stable")

	var frame := _make_block(&"test_frame", Vector3i.ONE, [&"small", &"large", &"static"])
	var beam := _make_block(&"test_beam", Vector3i(2, 1, 2), [&"large"])
	var small_only := _make_block(&"test_small_only", Vector3i.ONE, [&"small"])
	var invalid_extent := _make_block(&"test_invalid_extent", Vector3i(0, 1, 1), [&"large"])

	var frame_instance := _grid.call("place_block", frame, Vector3i.ZERO) as Resource
	_assert(frame_instance != null, "Single-cell block placement succeeds")
	_assert(int(frame_instance.get("instance_id")) == 1, "First placed block receives deterministic instance ID 1")
	_assert(_grid.call("place_block", frame, Vector3i.ZERO) == null, "Duplicate occupied-cell placement is rejected")
	_assert(not bool(_grid.call("can_place_block", small_only, Vector3i(5, 0, 0))), "Block incompatible with current grid type is rejected")
	_assert(not bool(_grid.call("can_place_block", invalid_extent, Vector3i(5, 0, 0))), "Zero-sized block extent is rejected")

	var beam_instance := _grid.call("place_block", beam, Vector3i(1, 0, 0)) as Resource
	_assert(beam_instance != null, "Multi-cell block placement succeeds when all cells are free")
	_assert(int(_grid.call("get_block_count")) == 2, "Block count tracks unique block instances")
	_assert(int(_grid.call("get_occupied_cell_count")) == 5, "Occupied-cell count includes full multi-cell extent")
	_assert(_grid.call("get_block_at", Vector3i(2, 0, 1)) == beam_instance, "Any occupied cell resolves to the owning multi-cell block")
	_assert(_grid.call("place_block", frame, Vector3i(2, 0, 1)) == null, "Overlap on any multi-cell occupied coordinate is rejected")

	var occupied_cells: Array = beam_instance.call("get_occupied_cells")
	_assert(occupied_cells.size() == 4, "Block instance reports all occupied cells")
	_assert(bool(beam_instance.call("contains_cell", Vector3i(1, 0, 1))), "Block instance containment recognizes interior occupied cell")
	var state: Dictionary = beam_instance.call("get_state")
	_assert(String(state["block_id"]) == "test_beam" and Vector3i(state["dimensions_cells"]) == Vector3i(2, 1, 2), "Block instance exposes stable serializable state")

	var neighbor_cells: Array = _grid.call("get_neighbor_cells", Vector3i.ZERO)
	_assert(neighbor_cells.size() == 6, "Cell neighbor query returns six orthogonal coordinates")
	var neighbor_blocks: Array = _grid.call("get_occupied_neighbor_blocks", Vector3i.ZERO)
	_assert(neighbor_blocks.size() == 1 and neighbor_blocks[0] == beam_instance, "Occupied-neighbor query deduplicates multi-cell block instances")

	var bounds: Dictionary = _grid.call("get_cell_bounds")
	_assert(bool(bounds["has_cells"]), "Occupied grid reports cell bounds")
	_assert(Vector3i(bounds["min"]) == Vector3i.ZERO and Vector3i(bounds["max"]) == Vector3i(2, 0, 1), "Cell bounds encompass all occupied cells")
	var local_aabb: AABB = _grid.call("get_local_aabb")
	_assert(local_aabb.position.is_equal_approx(Vector3(-1.25, -1.25, -1.25)), "Local AABB begins half a cell before minimum cell center")
	_assert(local_aabb.size.is_equal_approx(Vector3(7.5, 2.5, 5.0)), "Local AABB scales from inclusive cell bounds")

	var removed := _grid.call("remove_block_at", Vector3i(2, 0, 1)) as Resource
	_assert(removed == beam_instance, "Removing from an interior occupied cell removes the owning block")
	_assert(int(_grid.call("get_block_count")) == 1 and int(_grid.call("get_occupied_cell_count")) == 1, "Multi-cell removal frees its complete footprint")
	_assert(not bool(_grid.call("has_occupied_cell", Vector3i(1, 0, 0))) and not bool(_grid.call("has_occupied_cell", Vector3i(2, 0, 1))), "All removed multi-cell coordinates become free")
	_assert(_grid.call("remove_block_at", Vector3i(99, 99, 99)) == null, "Removing an empty cell is a safe no-op")

	var replacement := _grid.call("place_block", frame, Vector3i(-2, -1, -3)) as Resource
	_assert(replacement != null and int(replacement.get("instance_id")) == 3, "Instance IDs remain monotonic after removal")
	var all_blocks: Array = _grid.call("get_all_blocks")
	_assert(all_blocks.size() == 2 and int(all_blocks[0].get("instance_id")) == 1 and int(all_blocks[1].get("instance_id")) == 3, "Block enumeration is deterministic by instance ID")
	bounds = _grid.call("get_cell_bounds")
	_assert(Vector3i(bounds["min"]) == Vector3i(-2, -1, -3), "Bounds support negative grid coordinates")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Grid integrity audit passes after placement/removal sequence")

	var static_grid := GRID_SCENE.instantiate() as Node3D
	add_child(static_grid)
	static_grid.call("clear_grid")
	_assert(bool(static_grid.call("configure", static_profile)), "Empty grid can be configured with a different valid profile")
	_assert(StringName(static_grid.call("get_grid_type")) == &"static" and bool(static_grid.call("is_static_grid")), "Static grid configuration exposes static behavior")
	_assert(static_grid.call("place_block", frame, Vector3i.ZERO) != null, "Block allowing static profile can be placed on static grid")
	_assert(not bool(static_grid.call("configure", small_profile)), "Grid profile cannot be changed after blocks exist")

	var small_grid := GRID_SCENE.instantiate() as Node3D
	add_child(small_grid)
	_assert(bool(small_grid.call("configure", small_profile)), "Empty grid can switch to small profile")
	_assert(small_grid.call("place_block", small_only, Vector3i.ZERO) != null, "Small-only block can be placed on small grid")
	_assert(is_equal_approx(float(small_grid.call("get_cell_size_m")), 0.5), "Small configured grid exposes 0.5 m cell size")

	_grid.call("clear_grid")
	_assert(int(_grid.call("get_block_count")) == 0 and int(_grid.call("get_occupied_cell_count")) == 0, "Grid clear releases all block/cell state")
	bounds = _grid.call("get_cell_bounds")
	_assert(not bool(bounds["has_cells"]), "Empty grid reports empty bounds")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Cleared grid remains structurally valid")
	_assert(_added_events.size() == 3 and _removed_events.size() == 1, "Placement/removal signals fire once per successful mutation")

	if _failures.is_empty():
		print("STAGE9_GRID_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE9_GRID_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _make_block(block_id: StringName, dimensions: Vector3i, allowed_profiles: Array[StringName]) -> Resource:
	var definition: Resource = BLOCK_DEFINITION_SCRIPT.new()
	definition.set("id", block_id)
	definition.set("display_name", String(block_id))
	definition.set("dimensions_cells", dimensions)
	definition.set("allowed_grid_sizes", allowed_profiles)
	return definition

func _on_block_added(instance_id: int, _block_id: StringName) -> void:
	_added_events.append(instance_id)

func _on_block_removed(instance_id: int, _block_id: StringName) -> void:
	_removed_events.append(instance_id)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
