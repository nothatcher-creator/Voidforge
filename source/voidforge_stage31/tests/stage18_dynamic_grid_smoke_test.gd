extends Node
## Stage 18 regression coverage for static-to-dynamic grid conversion and the single-body
## rigid-body foundation used by future ship mass, thruster, gyro, and cockpit systems.

const GRID_SCENE := preload("res://scenes/grids/prototype_block_grid.tscn")
const BUILD_CONTROLLER_SCRIPT := preload("res://scripts/building/block_placement_controller.gd")
const GRID_COLLISION_MASK: int = 1 << 2
const TEST_BLOCK_ID: StringName = &"armor_shell_light_large"
const BUILD_BLOCK_ID: StringName = &"frame_lattice_large"

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	await _run_checks()

func _run_checks() -> void:
	var definition := BlockDB.call("get_block", TEST_BLOCK_ID) as Resource
	_assert(definition != null, "Stage 18 test block resolves from BlockDB")
	if definition == null:
		_finish()
		return

	var grid := GRID_SCENE.instantiate() as RigidBody3D
	grid.name = "DynamicTestGrid"
	grid.position = Vector3(3.0, 4.0, -10.0)
	grid.set("dynamic_gravity_scale", 0.0)
	grid.set("dynamic_linear_damp", 0.0)
	grid.set("dynamic_angular_damp", 0.0)
	add_child(grid)
	await get_tree().process_frame
	var presenter := grid.get_node("BlockPresenter") as Node
	_assert(presenter != null, "Dynamic grid retains the Stage 16/17 presenter")
	_assert(grid.freeze, "Large grid starts frozen until explicitly released")
	_assert(bool(grid.call("can_be_dynamic")), "Large grid profile is dynamic-capable")
	_assert(not bool(grid.call("is_dynamic_simulation_enabled")), "Frozen large grid reports static simulation mode")
	_assert(grid.call("place_block", definition, Vector3i.ZERO, 0) != null, "Dynamic test block can be placed while grid is frozen")
	presenter.call("flush_collision_now")
	presenter.call("flush_geometry_now")
	_assert(presenter.call("get_collision_body") == grid, "Grid itself is the shared Stage 18 collision/physics body")
	_assert(int(presenter.call("get_runtime_collision_node_count")) == 1, "Grid uses one physics-body node for all block collision")
	_assert(int(presenter.call("get_collision_shape_count")) == 1, "Single logical block produces one targetable shape owner")
	_assert(int(presenter.call("get_collision_body_node_instance_id")) == grid.get_instance_id(), "Presenter collision identity matches the BlockGrid rigid body")

	var expected_test_mass := float(definition.get("mass_kg"))
	_assert(is_equal_approx(float(grid.call("get_total_mass_kg")), expected_test_mass), "Dynamic grid exposes authoritative mass from its placed block")
	_assert(is_equal_approx(grid.mass, expected_test_mass), "Authoritative block mass reaches the rigid body")

	var mode_events: Array[bool] = []
	grid.connect("simulation_mode_changed", func(enabled: bool) -> void: mode_events.append(enabled))
	_assert(bool(grid.call("set_dynamic_simulation_enabled", true)), "Large grid can convert from frozen construction state to dynamic simulation")
	_assert(not grid.freeze and bool(grid.call("is_dynamic_simulation_enabled")), "Dynamic conversion unfreezes the BlockGrid rigid body")
	_assert(is_equal_approx(grid.gravity_scale, 0.0), "Stage 18 dynamic gravity setting is applied")
	_assert(grid.collision_mask == 1, "Dynamic grid enables world collision mask")
	_assert(mode_events == [true], "Dynamic conversion emits one simulation-mode signal")

	var start_position := grid.global_position
	var start_basis := grid.global_transform.basis
	grid.linear_velocity = Vector3(2.0, 0.0, 0.0)
	grid.angular_velocity = Vector3(0.0, 1.0, 0.0)
	for _step in 12:
		await get_tree().physics_frame
	var moved_distance := grid.global_position.distance_to(start_position)
	_assert(moved_distance > 0.15, "Dynamic grid translates under real rigid-body linear velocity")
	_assert(not grid.global_transform.basis.is_equal_approx(start_basis), "Dynamic grid rotates under real rigid-body angular velocity")
	_assert(grid.linear_velocity.length() > 1.5, "Linear velocity remains available as ship-motion foundation")
	_assert(grid.angular_velocity.length() > 0.7, "Angular velocity remains available as rotation foundation")

	# Ray from local +Z toward the moved/rotated grid proves the shape-owner mapping follows
	# the rigid-body transform rather than remaining at its original construction location.
	var ray_origin := grid.to_global(Vector3(0.0, 0.0, 7.0))
	var ray_target := grid.to_global(Vector3.ZERO)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target, GRID_COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = grid.get_world_3d().direct_space_state.intersect_ray(query)
	_assert(not hit.is_empty(), "Physics ray hits the grid after rigid-body translation/rotation")
	if not hit.is_empty():
		var collider := hit.get("collider") as Object
		var shape_index := int(hit.get("shape", -1))
		_assert(collider == grid, "Moved-grid ray resolves the BlockGrid rigid body as collider")
		_assert(int(presenter.call("resolve_block_instance_id_for_shape", shape_index)) == 1, "Moved-grid ray shape still resolves exact logical block instance")

	grid.call("stop_motion")
	await get_tree().physics_frame
	_assert(bool(grid.call("sleep_grid")), "Dynamic grid can enter an explicit sleeping state")
	await get_tree().physics_frame
	_assert(grid.sleeping, "Sleeping foundation reaches the physics body")
	_assert(bool(grid.call("wake_grid")), "Sleeping dynamic grid can be explicitly awakened")
	_assert(not grid.sleeping, "Wake operation clears physics sleeping state")

	# Keep the body dynamically enabled but stationary, then use the real Stage 10+ camera
	# controller against its moved/rotated transform. This ensures construction remains
	# grid-local and does not assume a world-axis-aligned static body.
	grid.call("stop_motion")
	await get_tree().physics_frame
	var rig := Node3D.new()
	rig.name = "DynamicConstructionRig"
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	rig.add_child(camera)
	var controller := BUILD_CONTROLLER_SCRIPT.new()
	controller.name = "BuildController"
	controller.set("camera_path", NodePath("../Camera3D"))
	controller.set("build_block_id", BUILD_BLOCK_ID)
	rig.add_child(controller)
	add_child(rig)
	await get_tree().process_frame
	await get_tree().physics_frame
	camera.global_position = grid.to_global(Vector3(0.0, 0.0, 7.0))
	camera.look_at(grid.to_global(Vector3.ZERO), grid.global_transform.basis.y.normalized())
	controller.call("refresh_targeting")
	_assert(controller.call("get_target_grid") == grid, "Construction controller acquires a dynamically enabled moved grid")
	_assert(Vector3i(controller.call("get_target_cell")) == Vector3i(0, 0, 1), "Moving-grid attachment cell is computed in grid-local coordinates")
	_assert(bool(controller.call("is_target_valid")), "Moving-grid adjacent placement is valid")
	var body_id_before := int(presenter.call("get_collision_body_node_instance_id"))
	var placed := controller.call("attempt_place") as Resource
	_assert(placed != null, "Construction can add a block while the target grid remains dynamic")
	presenter.call("flush_collision_now")
	presenter.call("flush_geometry_now")
	_assert(int(grid.call("get_block_count")) == 2, "Dynamic construction mutates authoritative sparse grid state")
	_assert(int(presenter.call("get_collision_shape_count")) == 2, "Dynamic construction rebuilds shared collision with the new block")
	_assert(int(presenter.call("get_collision_body_node_instance_id")) == body_id_before, "Dynamic construction keeps the same rigid-body node")
	_assert(bool(grid.call("is_dynamic_simulation_enabled")), "Grid remains dynamically enabled after construction mutation")
	_assert((grid.call("get_integrity_errors") as Array).is_empty(), "Dynamic grid integrity audit passes after construction")

	var transform_before_freeze := grid.global_transform
	_assert(bool(grid.call("set_dynamic_simulation_enabled", false)), "Dynamic grid can return to frozen construction state")
	_assert(grid.freeze and not bool(grid.call("is_dynamic_simulation_enabled")), "Returning to frozen state disables dynamic simulation")
	_assert(grid.linear_velocity.is_zero_approx() and grid.angular_velocity.is_zero_approx(), "Freezing grid clears linear and angular velocity")
	_assert(grid.global_transform.is_equal_approx(transform_before_freeze), "Freezing preserves the grid world transform")
	_assert(mode_events == [true, false], "Static conversion emits the matching simulation-mode signal")

	var static_grid := GRID_SCENE.instantiate() as RigidBody3D
	static_grid.name = "StaticProfileGrid"
	add_child(static_grid)
	await get_tree().process_frame
	static_grid.call("clear_grid")
	var static_profile := GridDB.call("get_profile", &"static") as Resource
	_assert(bool(static_grid.call("configure", static_profile)), "Empty grid can adopt Static Grid profile for physics test")
	_assert(not bool(static_grid.call("can_be_dynamic")), "Static Grid profile is never dynamic-capable")
	_assert(not bool(static_grid.call("set_dynamic_simulation_enabled", true)), "Static Grid profile rejects rigid-body release")
	_assert(static_grid.freeze and static_grid.collision_mask == 0, "Static profile remains frozen with no world-physics response mask")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("STAGE18_DYNAMIC_GRID_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE18_DYNAMIC_GRID_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
