extends Node3D
## Lightweight Stage 12 removal selection feedback.
## Uses one transparent face box plus edge lines and never participates in physics.

const FACE_COLOR := Color(1.0, 0.28, 0.08, 0.22)
const EDGE_COLOR := Color(1.0, 0.48, 0.12, 0.98)
const SIZE_EXPANSION: float = 1.025

@onready var face_mesh: MeshInstance3D = $FaceMesh
@onready var edge_mesh: MeshInstance3D = $EdgeMesh

var _box_mesh: BoxMesh
var _face_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _edge_immediate: ImmediateMesh
var _target_size_m: Vector3 = Vector3.ZERO

func _ready() -> void:
	_box_mesh = BoxMesh.new()
	_face_material = StandardMaterial3D.new()
	_face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_face_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_face_material.albedo_color = FACE_COLOR
	_face_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_face_material.no_depth_test = false
	_box_mesh.material = _face_material
	face_mesh.mesh = _box_mesh
	face_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_edge_material = StandardMaterial3D.new()
	_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edge_material.vertex_color_use_as_albedo = true
	_edge_material.albedo_color = EDGE_COLOR
	_edge_immediate = ImmediateMesh.new()
	edge_mesh.mesh = _edge_immediate
	edge_mesh.material_override = _edge_material
	edge_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

func set_target(size_m: Vector3) -> void:
	_target_size_m = Vector3(maxf(size_m.x, 0.01), maxf(size_m.y, 0.01), maxf(size_m.z, 0.01))
	var expanded := _target_size_m * SIZE_EXPANSION
	_box_mesh.size = expanded
	_draw_edges(expanded)
	visible = true

func clear_target() -> void:
	visible = false
	_target_size_m = Vector3.ZERO

func get_target_size_m() -> Vector3:
	return _target_size_m

func _draw_edges(size_m: Vector3) -> void:
	_edge_immediate.clear_surfaces()
	var half := size_m * 0.5
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
	_edge_immediate.surface_begin(Mesh.PRIMITIVE_LINES, _edge_material)
	for edge in edges:
		_edge_immediate.surface_set_color(EDGE_COLOR)
		_edge_immediate.surface_add_vertex(corners[edge.x])
		_edge_immediate.surface_set_color(EDGE_COLOR)
		_edge_immediate.surface_add_vertex(corners[edge.y])
	_edge_immediate.surface_end()
