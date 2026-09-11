extends Node
## Stage 16 regression coverage for cached MultiMesh grid rendering, dirty coalescing,
## shape preservation, node-count reduction, and progressive collision-free stress grids.

const STAGE16_WORLD := preload("res://scenes/tests/stage16_grid_geometry_test.tscn")
const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")

const STRESS_MILESTONES: Array[int] = [100, 500, 1000, 2500]
const STRESS_BLOCK_ID: StringName = &"armor_shell_light_large"

var _failures: Array[String] = []
var _world: Node3D

func _ready() -> void:
	await get_tree().process_frame
	_world = STAGE16_WORLD.instantiate() as Node3D
	var player := _world.get_node("Stage15StructuralLibraryTest/Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer") as CharacterBody3D
	player.set("capture_mouse_on_start", false)
	add_child(_world)
	await get_tree().process_frame
	await get_tree().physics_frame
	_run_active_world_checks()
	await _run_dirty_cache_checks()
	await _run_progressive_stress_checks()
	_finish()

func _run_active_world_checks() -> void:
	var stress_grid := _world.get_node("BatchStressGrid") as Node3D
	var stress_presenter := stress_grid.get_node("BlockPresenter") as Node3D
	_assert(int(stress_grid.call("get_block_count")) == 100, "Active Stage 16 stress grid contains 100 blocks")
	_assert(int(stress_presenter.call("get_batch_count")) == 1, "One-material box stress grid renders through a single batch node")
	_assert(int(stress_presenter.call("get_render_instance_count")) == 100, "Stress grid MultiMesh contains one transform per block")
	_assert(int(stress_presenter.call("get_runtime_render_node_count")) == 1, "100 stress blocks require one runtime render node")
	_assert(int(stress_presenter.call("get_collision_proxy_count")) == 0, "Render stress grid disables collision proxies to isolate geometry scaling")

	var gallery := _world.get_node("Stage15StructuralLibraryTest/LargeStructuralGallery") as Node3D
	var gallery_presenter := gallery.get_node("BlockPresenter") as Node3D
	_assert(int(gallery_presenter.call("get_presented_block_count")) == 11, "Stage 15 large gallery retains one targetable collision proxy per block")
	_assert(int(gallery_presenter.call("get_render_instance_count")) == 43, "Stage 15 structural forms retain all 43 semantic render primitives")
	_assert(int(gallery_presenter.call("get_batch_count")) == 7, "43 mixed structural primitives collapse into seven material/mesh batches")
	_assert(int(gallery_presenter.call("get_runtime_render_node_count")) == 7, "Mixed structural gallery uses seven render nodes instead of 43 MeshInstance3D nodes")
	_assert(gallery_presenter.call("get_batch_mesh", &"armor_light", &"wedge") is ArrayMesh, "Procedural wedge geometry remains present inside the shared wedge batch")

func _run_dirty_cache_checks() -> void:
	var grid := GRID_SCENE.instantiate() as Node3D
	grid.name = "DirtyBatchGrid"
	grid.set("grid_profile", LARGE_PROFILE)
	var presenter := grid.get_node("BlockPresenter") as Node3D
	presenter.set("render_collision", false)
	add_child(grid)
	await get_tree().process_frame
	var definition := BlockDB.call("get_block", STRESS_BLOCK_ID) as Resource
	var rebuild_before := int(presenter.call("get_geometry_rebuild_count"))
	for index in 32:
		grid.call("place_block", definition, Vector3i(index, 0, 0), 0)
	_assert(bool(presenter.call("is_geometry_dirty")), "Multiple same-frame mutations mark batched geometry dirty")
	_assert(int(presenter.call("get_geometry_rebuild_count")) == rebuild_before, "Dirty mutations are coalesced instead of rebuilding once per placement")
	presenter.call("flush_geometry_now")
	_assert(int(presenter.call("get_geometry_rebuild_count")) == rebuild_before + 1, "One explicit flush rebuilds all 32 pending placements together")
	_assert(int(presenter.call("get_batch_count")) == 1 and int(presenter.call("get_render_instance_count")) == 32, "Coalesced rebuild produces one 32-instance MultiMesh batch")
	var cached_node_id := int(presenter.call("get_batch_node_instance_id", &"armor_light", &"box"))
	for index in range(32, 48):
		grid.call("place_block", definition, Vector3i(index, 0, 0), 0)
	presenter.call("flush_geometry_now")
	_assert(int(presenter.call("get_batch_node_instance_id", &"armor_light", &"box")) == cached_node_id, "Existing batch node is reused across dirty rebuilds")
	_assert(int(presenter.call("get_render_instance_count")) == 48, "Cached batch updates its instance transforms after additional placement")
	grid.call("remove_block_at", Vector3i(0, 0, 0))
	presenter.call("flush_geometry_now")
	_assert(int(presenter.call("get_render_instance_count")) == 47, "Removal invalidates and rebuilds the batch without stale render instances")
	grid.queue_free()
	await get_tree().process_frame

func _run_progressive_stress_checks() -> void:
	var grid := RigidBody3D.new()
	grid.name = "Stage16ProgressiveStressGrid"
	grid.set_script(load("res://scripts/grids/block_grid.gd"))
	grid.set("grid_profile", LARGE_PROFILE)
	var presenter := Node3D.new()
	presenter.name = "BlockPresenter"
	presenter.set_script(PRESENTER_SCRIPT)
	presenter.set("render_collision", false)
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
				_failures.append("Stress placement failed at block %d" % placed)
				break
			placed += 1
		presenter.call("flush_geometry_now")
		var elapsed_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
		print("STAGE16_STRESS: %d blocks | %.2f ms mutation+batch flush | %d render nodes | %d instances" % [
			milestone,
			elapsed_ms,
			int(presenter.call("get_runtime_render_node_count")),
			int(presenter.call("get_render_instance_count")),
		])
		_assert(int(grid.call("get_block_count")) == milestone, "Stress grid reaches %d blocks without occupancy corruption" % milestone)
		_assert((grid.call("get_integrity_errors") as Array).is_empty(), "%d-block stress grid passes sparse-grid integrity audit" % milestone)
		_assert(int(presenter.call("get_batch_count")) == 1, "%d identical blocks remain in one render batch" % milestone)
		_assert(int(presenter.call("get_runtime_render_node_count")) == 1, "%d identical blocks still use one render node" % milestone)
		_assert(int(presenter.call("get_render_instance_count")) == milestone, "%d-block MultiMesh instance count matches authoritative grid state" % milestone)
	grid.queue_free()
	await get_tree().process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("STAGE16_GRID_GEOMETRY_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE16_GRID_GEOMETRY_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
