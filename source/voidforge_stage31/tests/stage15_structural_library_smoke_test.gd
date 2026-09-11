extends Node
## Stage 15 regression coverage for the first production structural/armor library,
## variant metadata, grid compatibility, procedural placeholder forms, and persistence.

const STAGE15_WORLD := preload("res://scenes/tests/stage15_structural_library_test.tscn")
const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const SMALL_PROFILE := preload("res://data/grids/small_grid_profile.tres")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")

const PLAYER_PATH := NodePath("Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer")

var _failures: Array[String] = []
var _world: Node3D
var _large_gallery: Node3D
var _small_gallery: Node3D

func _ready() -> void:
	await get_tree().process_frame
	_world = STAGE15_WORLD.instantiate() as Node3D
	var player := _world.get_node(PLAYER_PATH) as CharacterBody3D
	player.set("capture_mouse_on_start", false)
	add_child(_world)
	await get_tree().process_frame
	await get_tree().physics_frame
	_large_gallery = _world.get_node("LargeStructuralGallery") as Node3D
	_small_gallery = _world.get_node("SmallStructuralGallery") as Node3D
	_run_catalog_checks()
	_run_variant_checks()
	_run_grid_compatibility_checks()
	_run_presentation_checks()
	await _run_persistence_check()
	_run_active_world_check()
	_finish()

func _run_catalog_checks() -> void:
	_assert(bool(BlockDB.call("is_database_valid")), "BlockDB remains valid with Stage 15 structural content")
	_assert(int(BlockDB.call("get_block_count")) >= 17, "Catalog retains the 15 Stage 15 production blocks plus development/future-stage definitions")
	var production: Array = []
	for definition in BlockDB.call("get_blocks_with_tag", &"production") as Array:
		var resource := definition as Resource
		if resource != null and StringName(resource.get("category")) in [&"structure", &"armor"]:
			production.append(resource)
	_assert(production.size() == 15, "Exactly 15 Stage 15 production structural/armor definitions are cataloged")
	_assert((BlockDB.call("get_blocks_by_category", &"structure") as Array).size() == 11, "Structure category contains nine production blocks plus two development fixtures")
	_assert((BlockDB.call("get_blocks_by_category", &"armor") as Array).size() == 6, "Armor category contains six original production blocks")
	var seen_shapes: Dictionary = {}
	var all_valid := true
	for definition in production:
		var resource := definition as Resource
		seen_shapes[StringName(resource.get("presentation_shape"))] = true
		if not (resource.call("get_validation_errors", ItemDB) as Array).is_empty():
			all_valid = false
	_assert(all_valid, "Every production block passes BlockDefinition and ItemDB-linked construction-cost validation")
	for expected_shape in [&"box", &"frame", &"beam", &"panel", &"grating", &"wedge", &"corner"]:
		_assert(seen_shapes.has(expected_shape), "Production library exercises placeholder form '%s'" % String(expected_shape))

	var light := BlockDB.call("get_block", &"armor_shell_light_large") as Resource
	var heavy := BlockDB.call("get_block", &"armor_shell_heavy_large") as Resource
	_assert(float(heavy.get("mass_kg")) > float(light.get("mass_kg")), "Heavy armor trades substantially more mass for protection")
	_assert(float(heavy.get("max_integrity")) > float(light.get("max_integrity")), "Heavy armor provides higher integrity than light armor")
	_assert(int(heavy.call("get_total_build_cost_units")) > int(light.call("get_total_build_cost_units")), "Heavy armor has a higher construction cost")
	_assert(Vector3i((BlockDB.call("get_block", &"beam_long_large") as Resource).get("dimensions_cells")) == Vector3i(2, 1, 1), "Long Span Beam reserves a real two-cell footprint")
	_assert(Vector3i((BlockDB.call("get_block", &"pillar_tall_large") as Resource).get("dimensions_cells")) == Vector3i(1, 2, 1), "Tall Support Pillar reserves a real two-cell vertical footprint")

func _run_variant_checks() -> void:
	var frame_variants := BlockDB.call("get_blocks_by_variant_group", &"frame_family") as Array
	_assert(frame_variants.size() == 4, "Frame variant group exposes four ordered structural choices")
	var expected_frame_keys: Array[StringName] = [&"spar_small", &"truss_small", &"lattice_large", &"reinforced_large"]
	var frame_order_ok := frame_variants.size() == expected_frame_keys.size()
	for index in mini(frame_variants.size(), expected_frame_keys.size()):
		if StringName((frame_variants[index] as Resource).get("variant_key")) != expected_frame_keys[index]:
			frame_order_ok = false
	_assert(frame_order_ok, "Frame variants are returned in deterministic variant_order")
	var panel_variants := BlockDB.call("get_blocks_by_variant_group", &"service_panel") as Array
	_assert(panel_variants.size() == 2 and StringName((panel_variants[0] as Resource).get("variant_key")) == &"small" and StringName((panel_variants[1] as Resource).get("variant_key")) == &"large", "Service panels group small/large variants for future build-menu grouping")
	var armor_variants := BlockDB.call("get_blocks_by_variant_group", &"armor_shell") as Array
	_assert(armor_variants.size() == 3, "Armor Shell variants group small, light-large, and heavy-large choices")

func _run_grid_compatibility_checks() -> void:
	var small_frame := BlockDB.call("get_block", &"frame_spar_small") as Resource
	var large_frame := BlockDB.call("get_block", &"frame_lattice_large") as Resource
	var large_armor := BlockDB.call("get_block", &"armor_wedge_large") as Resource
	_assert(bool(small_frame.call("allows_grid", &"small")) and not bool(small_frame.call("allows_grid", &"large")), "Small production frame is restricted to small-grid construction")
	_assert(not bool(large_frame.call("allows_grid", &"small")) and bool(large_frame.call("allows_grid", &"large")) and bool(large_frame.call("allows_grid", &"static")), "Large production frame supports dynamic large and static grids only")
	_assert(int(_large_gallery.call("get_block_count")) == 11 and ( _large_gallery.call("get_integrity_errors") as Array).is_empty(), "Large gallery places all 11 large/static-compatible production blocks without overlaps")
	_assert(int(_small_gallery.call("get_block_count")) == 4 and (_small_gallery.call("get_integrity_errors") as Array).is_empty(), "Small gallery places all four small-grid production blocks")

	var temp_small := GRID_SCENE.instantiate() as Node3D
	temp_small.set("grid_profile", SMALL_PROFILE)
	add_child(temp_small)
	_assert(temp_small.call("place_block", small_frame, Vector3i.ZERO, 0) != null, "Small grid accepts a small production frame")
	_assert(temp_small.call("place_block", large_armor, Vector3i(2, 0, 0), 0) == null, "Small grid rejects incompatible large armor")
	temp_small.queue_free()

	var temp_large := GRID_SCENE.instantiate() as Node3D
	temp_large.set("grid_profile", LARGE_PROFILE)
	add_child(temp_large)
	_assert(temp_large.call("place_block", large_frame, Vector3i.ZERO, 0) != null, "Large grid accepts a large production frame")
	_assert(temp_large.call("place_block", small_frame, Vector3i(2, 0, 0), 0) == null, "Large grid rejects small-only production frame")
	temp_large.queue_free()

func _run_presentation_checks() -> void:
	var presenter := _large_gallery.get_node("BlockPresenter") as Node3D
	var frame_instance := _find_block(_large_gallery, &"frame_lattice_large")
	var grate_instance := _find_block(_large_gallery, &"grate_walkway_large")
	var wedge_instance := _find_block(_large_gallery, &"armor_wedge_large")
	var corner_instance := _find_block(_large_gallery, &"armor_corner_large")
	_assert(frame_instance != null and int(presenter.call("get_block_visual_count", int(frame_instance.get("instance_id")))) == 12, "Open frame placeholder is presented as twelve edge members instead of a solid cube")
	_assert(grate_instance != null and int(presenter.call("get_block_visual_count", int(grate_instance.get("instance_id")))) == 10, "Grating placeholder uses intersecting bars")
	_assert(corner_instance != null and int(presenter.call("get_block_visual_count", int(corner_instance.get("instance_id")))) == 2, "Armor corner placeholder uses two perpendicular protective planes")
	if wedge_instance != null:
		var wedge_id := int(wedge_instance.get("instance_id"))
		var wedge_body := presenter.call("get_block_body", wedge_id) as CollisionObject3D
		_assert(StringName(presenter.call("get_block_presentation_shape", wedge_id)) == &"wedge", "Presenter records the authoritative wedge presentation shape")
		var batch_mesh := presenter.call("get_batch_mesh", &"armor_light", &"wedge") as Mesh
		var collision_shape := presenter.call("get_block_collision_shape", wedge_id) as Shape3D
		_assert(batch_mesh is ArrayMesh, "Armor Wedge uses original procedural sloped mesh geometry through the batched renderer")
		_assert(wedge_body != null and collision_shape is ConvexPolygonShape3D, "Armor Wedge receives a convex shape inside the shared grid collision body")

func _run_persistence_check() -> void:
	var source := GRID_SCENE.instantiate() as Node3D
	source.set("grid_profile", LARGE_PROFILE)
	add_child(source)
	var wedge := BlockDB.call("get_block", &"armor_wedge_large") as Resource
	var placed := source.call("place_block", wedge, Vector3i(3, -1, 2), 0) as Resource
	_assert(placed != null, "Production armor block can be placed before persistence round-trip")
	var json_text := JSON.stringify(source.call("get_save_state"))
	var parsed = JSON.parse_string(json_text)
	var target := GRID_SCENE.instantiate() as Node3D
	target.set("grid_profile", LARGE_PROFILE)
	add_child(target)
	_assert(parsed is Dictionary and bool(target.call("load_save_state", parsed as Dictionary)), "Production structural metadata survives JSON grid save/load validation")
	var restored := target.call("get_block_at", Vector3i(3, -1, 2)) as Resource
	_assert(restored != null and StringName(restored.get("block_id")) == &"armor_wedge_large", "Grid persistence restores Stage 15 stable production block ID")
	source.queue_free()
	target.queue_free()
	await get_tree().process_frame

func _run_active_world_check() -> void:
	var builder := _world.get_node(PLAYER_PATH).get_node("BuildController") as Node3D
	_assert(StringName(builder.call("get_build_block_id")) == &"frame_lattice_large", "Active Stage 15 playable slice selects the production Lattice Frame instead of a development fixture")

func _find_block(grid: Node3D, block_id: StringName) -> Resource:
	for instance in grid.call("get_all_blocks"):
		var resource := instance as Resource
		if StringName(resource.get("block_id")) == block_id:
			return resource
	return null

func _finish() -> void:
	if _failures.is_empty():
		print("STAGE15_STRUCTURAL_LIBRARY_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE15_STRUCTURAL_LIBRARY_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
