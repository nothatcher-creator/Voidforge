extends Node
## Stage 20 end-to-end checks for cataloged control seats, pilot authority, camera context,
## seat loss ejection, dynamic wake-up, interaction-ray entry, and Android EXIT input.

const PLAYER_SCENE := preload("res://scenes/player/first_person_player.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/mobile_touch_controls.tscn")
const GRID_SCRIPT := preload("res://scripts/grids/block_grid.gd")
const PRESENTER_SCRIPT := preload("res://scripts/grids/block_grid_presenter.gd")
const LARGE_PROFILE := preload("res://data/grids/large_grid_profile.tres")

var _failures: Array[String] = []
var _player: CharacterBody3D
var _grid: RigidBody3D
var _presenter: Node3D
var _seat_presenter: Node3D
var _seat: Area3D
var _touch_controls: Control

func _ready() -> void:
	_build_world()
	await get_tree().process_frame
	await _physics_frames(5)
	await _run_checks()

func _build_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 63
	add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30, 0.5, 30)
	floor_shape.position = Vector3(0, -0.25, 0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)

	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.set("capture_mouse_on_start", false)
	_player.position = Vector3(0, 1.05, 7.5)
	add_child(_player)

	_grid = GRID_SCRIPT.new() as RigidBody3D
	_grid.name = "SeatTestGrid"
	_grid.set("grid_profile", LARGE_PROFILE)
	_grid.position = Vector3(0, 1.25, 3.5)
	add_child(_grid)
	_presenter = PRESENTER_SCRIPT.new() as Node3D
	_presenter.name = "BlockPresenter"
	_grid.add_child(_presenter)

	var frame := BlockDB.call("get_block", &"frame_reinforced_large") as Resource
	if frame != null:
		_grid.call("place_block", frame, Vector3i(1, 0, 0), 0)
	_presenter.call("flush_collision_now")
	_presenter.call("flush_geometry_now")
	_seat_presenter = _presenter.call("get_control_seat_presenter") as Node3D
	if _seat_presenter != null:
		_seat_presenter.call("flush_now")

func _run_checks() -> void:
	var seat_def := BlockDB.call("get_block", &"pilot_cradle_large") as Resource
	_assert(seat_def != null, "Pilot Cradle L resolves from authoritative BlockDB")
	if seat_def != null:
		_assert(StringName(seat_def.get("category")) == &"control" and StringName(seat_def.get("functional_type")) == &"control_seat", "Pilot Cradle metadata marks a real control-seat function")
		_assert(is_equal_approx(float(seat_def.get("mass_kg")), 460.0), "Pilot Cradle contributes authoritative 460 kg block mass")

	_assert(not bool(_grid.call("can_receive_manual_control", _player)), "Grid rejects manual vehicle control before a valid seat is claimed")
	_assert((_grid.call("get_control_seat_instance_ids") as Array).is_empty(), "Structural-only grid reports no control seats")
	var fake_claim := bool(_grid.call("try_claim_manual_control", _player, 999))
	_assert(not fake_claim, "Grid rejects pilot claims against nonexistent seat instance IDs")

	var seat_instance := _grid.call("place_block", seat_def, Vector3i.ZERO, 0) as Resource
	_assert(seat_instance != null, "Cataloged Pilot Cradle places on a large construction grid")
	_presenter.call("flush_collision_now")
	_presenter.call("flush_geometry_now")
	_seat_presenter.call("flush_now")
	_assert((_grid.call("get_control_seat_instance_ids") as Array).size() == 1, "Grid discovers exactly one functional control-seat instance")
	_assert(int(_seat_presenter.call("get_control_seat_count")) == 1, "Functional presenter creates one lightweight seat interaction proxy")
	_seat = _seat_presenter.call("get_control_seat", int(seat_instance.get("instance_id"))) as Area3D
	_assert(_seat != null and _seat.is_in_group("interactable"), "Control-seat proxy participates in the shared interaction contract")
	_assert(_seat != null and _seat.collision_layer == 8, "Control-seat interaction uses the dedicated Interactable physics layer")

	await _physics_frames(3)
	var interactor := _player.get_node("CameraPivot/Camera3D/PlayerInteractor") as RayCast3D
	interactor.force_raycast_update()
	_assert(interactor.call("get_current_target") == _seat, "Camera-centered interaction ray resolves the Pilot Cradle proxy")
	_assert(str(interactor.call("get_current_prompt")).contains("Pilot Cradle"), "Interaction prompt identifies the Pilot Cradle")

	_grid.set("dynamic_gravity_scale", 0.0)
	_grid.set("dynamic_linear_damp", 0.0)
	_grid.set("dynamic_angular_damp", 0.0)
	_assert(bool(_grid.call("set_dynamic_simulation_enabled", true)), "Seat-bearing large grid can enter dynamic simulation")
	await _physics_frames(2)
	_assert(bool(_grid.call("sleep_grid")), "Dynamic seat grid can sleep before pilot entry")
	_assert(_grid.sleeping, "Seat grid reaches sleeping state")

	_assert(bool(interactor.call("attempt_interaction")), "Shared E/USE interaction path enters the control seat")
	await _physics_frames(2)
	_assert(bool(_player.call("is_in_control_seat")), "Player switches from on-foot to seated vehicle mode")
	_assert(StringName(_player.call("get_control_mode")) == &"vehicle", "Player exposes vehicle control mode while seated")
	_assert(_player.call("get_controlled_grid") == _grid, "Player vehicle context references the seat's constructed grid")
	_assert(_grid.call("get_active_pilot") == _player, "Grid owns the authoritative active-pilot reference")
	_assert(int(_grid.call("get_active_control_seat_instance_id")) == int(seat_instance.get("instance_id")), "Grid records the exact controlling seat instance")
	_assert(bool(_grid.call("can_receive_manual_control", _player)), "Grid grants manual-control authority only to its seated pilot")
	_assert(not _grid.sleeping, "Claiming a seat wakes a sleeping dynamic craft")
	_assert(not interactor.enabled, "On-foot interaction ray disables while piloting")
	_assert(_player.get_node("BuildController").process_mode == Node.PROCESS_MODE_DISABLED, "On-foot construction controller disables while piloting")

	var dummy := Node.new()
	add_child(dummy)
	_assert(not bool(_grid.call("try_claim_manual_control", dummy, int(seat_instance.get("instance_id")))), "Second actor cannot steal an occupied control seat")

	var before_move := _player.global_position
	_grid.global_position += Vector3(1.25, 0.0, 0.0)
	await _physics_frames(2)
	_assert(_player.global_position.distance_to(before_move) > 0.8, "Seated player body/camera context follows a transformed craft")
	var seat_body_transform := _seat.call("get_pilot_body_transform_global") as Transform3D
	_assert(_player.global_position.distance_to(seat_body_transform.origin) < 0.02, "Player remains locked to the Pilot Cradle camera/body anchor")
	var body_basis_before := _player.global_transform.basis
	_player.call("apply_look_motion", Vector2(90, -20), 1.0)
	await _physics_frames(1)
	_assert(absf((_player.get_node("CameraPivot") as Node3D).rotation.y) > 0.01, "Seated look rotates the camera pivot independently")
	_assert(_basis_equal(_player.global_transform.basis, body_basis_before), "Seated free-look does not rotate the authoritative craft/player body anchor")

	_build_touch_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var exit_button := _touch_controls.get_node("ExitSeatButton") as Control
	var look_area := _touch_controls.get_node("LookArea") as Control
	_assert(exit_button.visible, "Android HUD reveals EXIT context button while seated")
	_assert(not (_touch_controls.get_node("JumpButton") as Control).visible, "On-foot Jump control hides while seated")
	var exit_center := exit_button.get_global_rect().get_center()
	var probe := InputEventScreenTouch.new()
	probe.index = 71
	probe.position = exit_center
	probe.pressed = true
	_assert(not bool(look_area.call("handle_screen_event", probe)), "EXIT button is excluded from camera-look touch ownership")
	_send_touch(exit_button, 72, exit_center, true)
	await _physics_frames(1)
	_send_touch(exit_button, 72, exit_center, false)
	await _physics_frames(3)
	_assert(not bool(_player.call("is_in_control_seat")), "Android EXIT action returns the player to on-foot mode")
	_assert(not bool(_grid.call("has_active_pilot")), "Exiting releases grid pilot ownership")
	_assert(interactor.enabled, "On-foot interaction ray re-enables after seat exit")
	_assert(_player.get_node("BuildController").process_mode != Node.PROCESS_MODE_DISABLED, "Construction controller re-enables after seat exit")
	_assert(not exit_button.visible, "Android EXIT button hides again on foot")

	# Re-enter directly, then remove the controlling block. The grid must eject the pilot before
	# authoritative construction state loses the seat instance.
	_assert(bool(_player.call("enter_control_seat", _seat)), "Player can re-enter an available seat through the reusable seat API")
	await _physics_frames(1)
	_grid.call("remove_block_by_instance_id", int(seat_instance.get("instance_id")))
	await _physics_frames(3)
	_assert(not bool(_player.call("is_in_control_seat")), "Removing the controlling seat forcibly ejects the pilot")
	_assert(not bool(_grid.call("has_active_pilot")), "Seat removal clears authoritative grid pilot state")
	_assert(not bool(_grid.call("can_receive_manual_control", _player)), "Grid again rejects manual control after its only seat is removed")
	_assert((_grid.call("get_integrity_errors") as Array).is_empty(), "Grid integrity remains clean after occupied-seat removal and ejection")

	if _failures.is_empty():
		print("STAGE20_CONTROL_SEAT_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("STAGE20_CONTROL_SEAT_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)

func _build_touch_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as Control
	_touch_controls.set("force_visible_for_testing", true)
	canvas.add_child(_touch_controls)
	_touch_controls.call("bind_player", _player)

func _send_touch(control: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	control.call("handle_screen_event", event)

func _physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func _basis_equal(a: Basis, b: Basis, tolerance: float = 0.0001) -> bool:
	return a.x.distance_to(b.x) <= tolerance and a.y.distance_to(b.y) <= tolerance and a.z.distance_to(b.z) <= tolerance

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("[PASS] %s" % description)
	else:
		_failures.append(description)
		print("[FAIL] %s" % description)
