class_name ControlSeatPresenter
extends Node3D
## Maintains lightweight interaction proxies only for functional control-seat blocks.
## Structural blocks remain node-free; functional nodes scale with machinery count, not hull size.

const CONTROL_SEAT_SCRIPT := preload("res://scripts/ships/control_seat_interaction.gd")
const CONTROL_SEAT_FUNCTION: StringName = &"control_seat"

var _grid: Node3D
var _seat_proxies: Dictionary = {}
var _sync_queued: bool = false
var _sync_count: int = 0

func bind_grid(grid: Node3D) -> bool:
	if grid == null or not grid.has_method("get_all_blocks"):
		return false
	_grid = grid
	_connect_grid_signals()
	flush_now()
	return true

func _ready() -> void:
	if _grid == null:
		var parent := get_parent() as Node3D
		if parent != null and parent.has_method("get_all_blocks"):
			bind_grid(parent)

func get_grid() -> Node3D:
	return _grid

func get_control_seat_count() -> int:
	return _seat_proxies.size()

func get_control_seat(instance_id: int) -> Area3D:
	return _seat_proxies.get(instance_id) as Area3D

func get_all_control_seats() -> Array[Area3D]:
	var ids: Array[int] = []
	for raw_id in _seat_proxies.keys():
		ids.append(int(raw_id))
	ids.sort()
	var result: Array[Area3D] = []
	for instance_id in ids:
		var proxy := get_control_seat(instance_id)
		if is_instance_valid(proxy):
			result.append(proxy)
	return result

func get_sync_count() -> int:
	return _sync_count

func queue_sync() -> void:
	if _sync_queued:
		return
	_sync_queued = true
	call_deferred("flush_now")

func flush_now() -> void:
	_sync_queued = false
	if _grid == null or not is_instance_valid(_grid):
		_clear_proxies()
		return
	var desired: Dictionary = {}
	for raw_instance in _grid.call("get_all_blocks"):
		var instance := raw_instance as Resource
		if instance == null:
			continue
		var definition := BlockDB.call("get_block", StringName(instance.get("block_id"))) as Resource
		if definition == null or StringName(definition.get("functional_type")) != CONTROL_SEAT_FUNCTION:
			continue
		var instance_id := int(instance.get("instance_id"))
		desired[instance_id] = {"instance": instance, "definition": definition}

	for raw_id in _seat_proxies.keys().duplicate():
		var instance_id := int(raw_id)
		if desired.has(instance_id):
			continue
		var stale := _seat_proxies.get(instance_id) as Node
		_seat_proxies.erase(instance_id)
		if is_instance_valid(stale):
			stale.queue_free()

	for raw_id in desired.keys():
		var instance_id := int(raw_id)
		var payload := desired[instance_id] as Dictionary
		var proxy := _seat_proxies.get(instance_id) as Area3D
		if proxy == null:
			proxy = CONTROL_SEAT_SCRIPT.new() as Area3D
			add_child(proxy)
			_seat_proxies[instance_id] = proxy
		proxy.call("configure", _grid, payload["instance"] as Resource, payload["definition"] as Resource)
	_sync_count += 1

func _connect_grid_signals() -> void:
	for signal_name in [&"block_added", &"block_removed", &"grid_changed", &"grid_reloaded", &"block_configuration_changed"]:
		if _grid.has_signal(signal_name):
			var callable := Callable(self, "_on_grid_mutated")
			if not _grid.is_connected(signal_name, callable):
				_grid.connect(signal_name, callable)

func _on_grid_mutated(_a = null, _b = null) -> void:
	queue_sync()

func _clear_proxies() -> void:
	for raw_proxy in _seat_proxies.values():
		var proxy := raw_proxy as Node
		if is_instance_valid(proxy):
			proxy.queue_free()
	_seat_proxies.clear()
