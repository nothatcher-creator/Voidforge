class_name BlockInstanceData
extends Resource
## Compact authoritative runtime state for one placed block.
## Stage 13 adds a JSON-friendly persistence representation while keeping runtime vectors native.

const BLOCK_ORIENTATION := preload("res://scripts/grids/block_orientation.gd")

@export var instance_id: int = 0
@export var block_id: StringName
@export var anchor_cell: Vector3i = Vector3i.ZERO
@export var dimensions_cells: Vector3i = Vector3i.ONE
@export_range(0, 23, 1) var orientation_index: int = 0

func configure(
	new_instance_id: int,
	new_block_id: StringName,
	new_anchor_cell: Vector3i,
	new_dimensions_cells: Vector3i,
	new_orientation_index: int = 0
) -> void:
	instance_id = new_instance_id
	block_id = new_block_id
	anchor_cell = new_anchor_cell
	dimensions_cells = new_dimensions_cells
	orientation_index = new_orientation_index if BLOCK_ORIENTATION.is_valid_index(new_orientation_index) else 0

func is_valid_instance() -> bool:
	return (
		instance_id > 0
		and block_id != &""
		and dimensions_cells.x > 0
		and dimensions_cells.y > 0
		and dimensions_cells.z > 0
		and BLOCK_ORIENTATION.is_valid_index(orientation_index)
	)

func get_orientation_basis() -> Basis:
	return BLOCK_ORIENTATION.get_basis(orientation_index)

func get_oriented_dimensions_cells() -> Vector3i:
	return BLOCK_ORIENTATION.get_oriented_dimensions(dimensions_cells, orientation_index)

func get_occupied_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var oriented_dimensions := get_oriented_dimensions_cells()
	if oriented_dimensions.x <= 0 or oriented_dimensions.y <= 0 or oriented_dimensions.z <= 0:
		return cells
	for x in oriented_dimensions.x:
		for y in oriented_dimensions.y:
			for z in oriented_dimensions.z:
				cells.append(anchor_cell + Vector3i(x, y, z))
	return cells

func contains_cell(cell: Vector3i) -> bool:
	var oriented_dimensions := get_oriented_dimensions_cells()
	var offset := cell - anchor_cell
	return (
		offset.x >= 0 and offset.x < oriented_dimensions.x
		and offset.y >= 0 and offset.y < oriented_dimensions.y
		and offset.z >= 0 and offset.z < oriented_dimensions.z
	)

func get_state() -> Dictionary:
	return {
		"instance_id": instance_id,
		"block_id": String(block_id),
		"anchor_cell": anchor_cell,
		"dimensions_cells": dimensions_cells,
		"orientation_index": orientation_index,
		"oriented_dimensions_cells": get_oriented_dimensions_cells(),
	}

func get_save_state() -> Dictionary:
	return {
		"instance_id": instance_id,
		"block_id": String(block_id),
		"anchor_cell": [anchor_cell.x, anchor_cell.y, anchor_cell.z],
		"dimensions_cells": [dimensions_cells.x, dimensions_cells.y, dimensions_cells.z],
		"orientation_index": orientation_index,
	}
