extends Node
## Stage 17 regression coverage for one-body-per-grid collision generation, shape-owner
## instance mapping, dirty rebuild coalescing, targeting compatibility, and stress scaling.

const STAGE17_WORLD := preload("res://scenes/tests/stage17_grid_collision_test.tscn")
const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")

const GRID_COLLISION_MASK: int = 1 << 2
const STRESS_MILESTONES: Array[int] = [100, 500, 1000, 2500]
const STRESS_BLOCK_ID: StringName = &"armor_shell_light_large"

var _failures: Array[String] = []
var _world: Node3D

func _ready() -> void:
	await get_tree().process_frame
	_world = STAGE17_WORLD.instantiate() as Node3D
	var player := _world.get_node("Stage16GridGeometryTest/Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer") as CharacterBody3D
	player.set("capture_mouse_on_start", false)
	add_child(_world)
	await get_tree().process_frame
	await get_tree().physics_frame
	_run_active_world_checks()
	await _run_dirty_cache_checks()
	await _run_progressive_stress_checks()
	_finish()

func _run_active_world_checks() -> void:
	var grid := _world.get_node("CollisionStressGrid") as Node3D
	var presenter := grid.get_node("BlockPresenter") as Node3D
	var body := presenter.call("get_collision_body") as CollisionObject3D
	_assert(int(grid.call("get_block_count")) == 100, "Active Stage 17 collision stress grid contains 100 blocks")
	_assert(body != null, "Collision-enabled grid owns one shared physics body")
	_assert(int(presenter.call("get_runtime_collision_node_count")) == 1, "100 targetable blocks require one runtime collision node")
	_assert(int(presenter.call("get_collision_shape_count")) == 100, "Shared collision body contains one logical shape owner per block")
	_assert(body != null and body.get_shape_owners().size() == 100, "Shared grid physics body exposes 100 non-node shape owners")
	_assert(int(presenter.call("get_collision_shape_resource_count")) == 1, "Identical armor blocks reuse one cached BoxShape3D resource")
	_assert(body != null and body.has_meta("voidforge_block_grid") and body.get_meta("voidforge_block_grid") == grid, "Shared collider retains authoritative grid metadata")
	_assert(body != null and body.has_meta("voidforge_grid_collision_presenter"), "Shared collider exposes presenter resolver metadata")
	_check_raycast_mapping(grid, presenter, Vector3i(0, 0, 0), "first")
	_check_raycast_mapping(grid, presenter, Vector3i(9, 0, 9), "last")

func _check_raycast_mapping(grid: Node3D, presenter: Node3D, cell: Vector3i, label: String) -> void:
	var expected := grid.call("get_block_at", cell) as Resource
	_assert(expected != null, "%s ray probe cell resolves an authoritative block" % label.capitalize())
	if expected == null:
		return
	var center := grid.call("grid_to_world", cell) as Vector3
	var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 8.0, center + Vector3.DOWN * 8.0, GRID_COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := grid.get_world_3d().direct_space_state.intersect_ray(query)
	_assert(not hit.is_empty(), "%s downward ray hits the shared collision body" % label.capitalize())
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Object
	var shape_index := int(hit.get("shape", -1))
	var mapped_id := int(presenter.call("resolve_block_instance_id_for_shape", shape_index))
	_assert(collider == presenter.call("get_collision_body"), "%s ray reports the grid-level collider rather than a per-block body" % label.capitalize())
	_assert(mapped_id == int(expected.get("instance_id")), "%s ray shape index maps back to the exact block instance ID" % label.capitalize())

func _run_dirty_cache_checks() -> void:
	var grid := GRID_SCENE.instantiate() as Node3D
	grid.name = "DirtyCollisionGrid"
	grid.set("grid_profile", LARGE_PROFILE)
	var presenter := grid.get_node("BlockPresenter") as Node3D
	presenter.set("render_geometry", false)
	add_child(grid)
	await get_tree().process_frame
	var definition := BlockDB.call("get_block", STRESS_BLOCK_ID) as Resource
	var rebuild_before := int(presenter.call("get_collision_rebuild_count"))
	var body_id_before := int(presenter.call("get_collision_body_node_instance_id"))
	for index in 32:
		grid.call("place_block", definition, Vector3i(index, 0, 0), 0)
	_assert(bool(presenter.call("is_collision_dirty")), "Multiple same-frame mutations mark grid collision dirty")
	_assert(int(presenter.call("get_collision_rebuild_count")) == rebuild_before, "Same-frame collision mutations coalesce instead of rebuilding per block")
	presenter.call("flush_collision_now")
	_assert(int(presenter.call("get_collision_rebuild_count")) == rebuild_before + 1, "One collision flush rebuilds all 32 pending blocks together")
	_assert(int(presenter.call("get_collision_shape_count")) == 32, "Coalesced collision rebuild contains 32 logical block shapes")
	_assert(int(presenter.call("get_runtime_collision_node_count")) == 1, "Dirty collision rebuild still uses one physics node")
	_assert(int(presenter.call("get_collision_shape_resource_count")) == 1, "Collision shape resource cache deduplicates identical block geometry")
	for index in range(32, 48):
		grid.call("place_block", definition, Vector3i(index, 0, 0), 0)
	presenter.call("flush_collision_now")
	_assert(int(presenter.call("get_collision_body_node_instance_id")) == body_id_before, "Collision rebuild reuses the same grid physics body node")
	_assert(int(presenter.call("get_collision_shape_count")) == 48, "Cached body updates to 48 shapes after additional placement")
	var removed := grid.call("remove_block_at", Vector3i(0, 0, 0)) as Resource
	presenter.call("flush_collision_now")
	_assert(removed != null and int(presenter.call("get_collision_shape_count")) == 47, "Removal rebuild drops exactly one stale collision mapping")
	_assert(presenter.call("get_block_body", int(removed.get("instance_id"))) == null, "Removed instance no longer resolves through collision mapping")
	grid.queue_free()
	await get_tree().process_frame

func _run_progressive_stress_checks() -> void:
	var grid := RigidBody3D.new()
	grid.name = "Stage17ProgressiveCollisionStressGrid"
	grid.set_script(load("res://scripts/grids/block_grid.gd"))
	grid.set("grid_profile", LARGE_PROFILE)
	var presenter := Node3D.new()
	presenter.name = "BlockPresenter"
	presenter.set_script(PRESENTER_SCRIPT)
	presenter.set("render_geometry", false)
	grid.add_child(presenter)
	add_child(grid)
	await get_tree().process_frame
	var definition := BlockDB.call("get_block", STRESS_BLOCK_ID) as Resource
	var placed := 0
	var width := 50
	for milestone in STRESS_MILESTONES:
		var start_usec := Time.get_ticks_usec()
		while placed < milestone:
			var cell := Vector3i(placed % width, placed / width, 0)
			var instance := grid.call("place_block", definition, cell, 0) as Resource
			if instance == null:
				_failures.append("Collision stress placement failed at block %d" % placed)
				break
			placed += 1
		presenter.call("flush_collision_now")
		var elapsed_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
		print("STAGE17_COLLISION_STRESS: %d blocks | %.2f ms mutation+collision flush | %d collision nodes | %d shapes | %d cached resources" % [
			milestone,
			elapsed_ms,
			int(presenter.call("get_runtime_collision_node_count")),
			int(presenter.call("get_collision_shape_count")),
			int(presenter.call("get_collision_shape_resource_count")),
		])
		_assert(int(grid.call("get_block_count")) == milestone, "Collision stress grid reaches %d blocks without occupancy corruption" % milestone)
		_assert((grid.call("get_integrity_errors") as Array).is_empty(), "%d-block collision stress grid passes sparse-grid integrity audit" % milestone)
		_assert(int(presenter.call("get_runtime_collision_node_count")) == 1, "%d targetable blocks still use one collision node" % milestone)
		_assert(int(presenter.call("get_collision_shape_count")) == milestone, "%d-block collision shape count matches authoritative grid state" % milestone)
		_assert(int(presenter.call("get_collision_shape_resource_count")) == 1, "%d identical blocks reuse one Shape3D resource" % milestone)
	grid.queue_free()
	await get_tree().process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("STAGE17_GRID_COLLISION_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE17_GRID_COLLISION_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
