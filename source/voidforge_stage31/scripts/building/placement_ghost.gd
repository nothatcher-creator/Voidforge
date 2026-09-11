extends Node3D
## Procedural holographic construction preview: translucent volume + high-contrast edge cage.

@export_range(0.0, 0.2, 0.001) var outline_inset_m: float = 0.012

var _fill_mesh: MeshInstance3D
var _edge_mesh: MeshInstance3D
var _box_mesh: BoxMesh
var _edge_immediate: ImmediateMesh
var _valid_fill: StandardMaterial3D
var _invalid_fill: StandardMaterial3D
var _valid_edges: StandardMaterial3D
var _invalid_edges: StandardMaterial3D
var _size_m: Vector3 = Vector3.ONE
var _is_valid: bool = false

func _ready() -> void:
	_build_materials()
	_fill_mesh = MeshInstance3D.new()
	_fill_mesh.name = "HologramFill"
	_box_mesh = BoxMesh.new()
	_fill_mesh.mesh = _box_mesh
	add_child(_fill_mesh)

	_edge_mesh = MeshInstance3D.new()
	_edge_mesh.name = "HologramEdges"
	_edge_immediate = ImmediateMesh.new()
	_edge_mesh.mesh = _edge_immediate
	add_child(_edge_mesh)
	set_preview(Vector3.ONE, false)
	visible = false

func set_preview(size_m: Vector3, placement_valid: bool) -> void:
	_size_m = Vector3(maxf(size_m.x, 0.01), maxf(size_m.y, 0.01), maxf(size_m.z, 0.01))
	_is_valid = placement_valid
	if _box_mesh == null:
		return
	_box_mesh.size = _size_m
	_fill_mesh.material_override = _valid_fill if _is_valid else _invalid_fill
	_rebuild_edges()

func set_valid(placement_valid: bool) -> void:
	if placement_valid == _is_valid:
		return
	_is_valid = placement_valid
	if _fill_mesh != null:
		_fill_mesh.material_override = _valid_fill if _is_valid else _invalid_fill
	_rebuild_edges()

func is_placement_valid() -> bool:
	return _is_valid

func get_preview_size_m() -> Vector3:
	return _size_m

func _build_materials() -> void:
	_valid_fill = _make_material(Color(0.08, 0.9, 1.0, 0.22), Color(0.05, 1.0, 0.9, 1.0), 1.6)
	_invalid_fill = _make_material(Color(1.0, 0.13, 0.09, 0.25), Color(1.0, 0.08, 0.04, 1.0), 1.8)
	_valid_edges = _make_material(Color(0.15, 1.0, 0.95, 0.94), Color(0.05, 1.0, 0.9, 1.0), 2.4)
	_invalid_edges = _make_material(Color(1.0, 0.22, 0.12, 0.96), Color(1.0, 0.06, 0.02, 1.0), 2.6)

func _make_material(albedo: Color, emission: Color, emission_multiplier: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = emission_multiplier
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _rebuild_edges() -> void:
	if _edge_immediate == null:
		return
	_edge_immediate.clear_surfaces()
	var half := _size_m * 0.5 + Vector3.ONE * outline_inset_m
	var corners: Array[Vector3] = [
		Vector3(-half.x, -half.y, -half.z),
		Vector3( half.x, -half.y, -half.z),
		Vector3( half.x,  half.y, -half.z),
		Vector3(-half.x,  half.y, -half.z),
		Vector3(-half.x, -half.y,  half.z),
		Vector3( half.x, -half.y,  half.z),
		Vector3( half.x,  half.y,  half.z),
		Vector3(-half.x,  half.y,  half.z),
	]
	var edges: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7),
	]
	_edge_immediate.surface_begin(Mesh.PRIMITIVE_LINES, _valid_edges if _is_valid else _invalid_edges)
	for edge in edges:
		_edge_immediate.surface_add_vertex(corners[edge.x])
		_edge_immediate.surface_add_vertex(corners[edge.y])
	_edge_immediate.surface_end()
