extends RefCounted
## Discrete orthogonal block orientation helper.
## Stage 11 stores a compact 0..23 index and derives a proper right-handed Basis on demand.

const ORIENTATION_COUNT: int = 24
const CARDINAL_AXES: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, 0, 1),
	Vector3i(-1, 0, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, -1),
]

static func is_valid_index(index: int) -> bool:
	return index >= 0 and index < ORIENTATION_COUNT

static func get_basis(index: int) -> Basis:
	var bases := _generate_bases()
	if not is_valid_index(index) or index >= bases.size():
		return Basis.IDENTITY
	return bases[index]

static func get_oriented_dimensions(base_dimensions: Vector3i, index: int) -> Vector3i:
	if base_dimensions.x <= 0 or base_dimensions.y <= 0 or base_dimensions.z <= 0:
		return Vector3i.ZERO
	var basis := get_basis(index)
	var x_axis := _basis_axis_abs_i(basis.x)
	var y_axis := _basis_axis_abs_i(basis.y)
	var z_axis := _basis_axis_abs_i(basis.z)
	return x_axis * base_dimensions.x + y_axis * base_dimensions.y + z_axis * base_dimensions.z

static func rotate_index_around_axis(index: int, axis: Vector3i, quarter_turns: int = 1) -> int:
	if not is_valid_index(index):
		return 0
	var cardinal_axis := snap_to_cardinal_axis(axis)
	if cardinal_axis == Vector3i.ZERO:
		return index
	var turns := posmod(quarter_turns, 4)
	if turns == 0:
		return index
	var basis := get_basis(index)
	var x_axis := _vector3_to_cardinal(basis.x)
	var y_axis := _vector3_to_cardinal(basis.y)
	var z_axis := _vector3_to_cardinal(basis.z)
	for _turn in turns:
		x_axis = _rotate_cardinal_quarter_turn(x_axis, cardinal_axis)
		y_axis = _rotate_cardinal_quarter_turn(y_axis, cardinal_axis)
		z_axis = _rotate_cardinal_quarter_turn(z_axis, cardinal_axis)
	return find_index_from_axes(x_axis, y_axis, z_axis)

static func find_index_from_basis(basis: Basis) -> int:
	return find_index_from_axes(
		_vector3_to_cardinal(basis.x),
		_vector3_to_cardinal(basis.y),
		_vector3_to_cardinal(basis.z)
	)

static func find_index_from_axes(x_axis: Vector3i, y_axis: Vector3i, z_axis: Vector3i) -> int:
	var bases := _generate_bases()
	for index in bases.size():
		var basis := bases[index]
		if (
			_vector3_to_cardinal(basis.x) == x_axis
			and _vector3_to_cardinal(basis.y) == y_axis
			and _vector3_to_cardinal(basis.z) == z_axis
		):
			return index
	return 0

static func snap_to_cardinal_axis(axis: Vector3i) -> Vector3i:
	if axis == Vector3i.ZERO:
		return Vector3i.ZERO
	var abs_axis := axis.abs()
	if abs_axis.x >= abs_axis.y and abs_axis.x >= abs_axis.z:
		return Vector3i(1 if axis.x >= 0 else -1, 0, 0)
	if abs_axis.y >= abs_axis.x and abs_axis.y >= abs_axis.z:
		return Vector3i(0, 1 if axis.y >= 0 else -1, 0)
	return Vector3i(0, 0, 1 if axis.z >= 0 else -1)

static func _generate_bases() -> Array[Basis]:
	var result: Array[Basis] = []
	for x_axis in CARDINAL_AXES:
		for y_axis in CARDINAL_AXES:
			if _dot_i(x_axis, y_axis) != 0:
				continue
			var z_axis := _cross_i(x_axis, y_axis)
			if z_axis == Vector3i.ZERO:
				continue
			result.append(Basis(Vector3(x_axis), Vector3(y_axis), Vector3(z_axis)))
	return result

static func _rotate_cardinal_quarter_turn(vector: Vector3i, axis: Vector3i) -> Vector3i:
	# Positive 90 degrees by the right-hand rule. Parallel components remain unchanged.
	return _cross_i(axis, vector) + axis * _dot_i(axis, vector)

static func _basis_axis_abs_i(axis: Vector3) -> Vector3i:
	return Vector3i(roundi(absf(axis.x)), roundi(absf(axis.y)), roundi(absf(axis.z)))

static func _vector3_to_cardinal(vector: Vector3) -> Vector3i:
	if vector.length_squared() < 0.5:
		return Vector3i.ZERO
	var abs_vector := vector.abs()
	if abs_vector.x >= abs_vector.y and abs_vector.x >= abs_vector.z:
		return Vector3i(1 if vector.x >= 0.0 else -1, 0, 0)
	if abs_vector.y >= abs_vector.x and abs_vector.y >= abs_vector.z:
		return Vector3i(0, 1 if vector.y >= 0.0 else -1, 0)
	return Vector3i(0, 0, 1 if vector.z >= 0.0 else -1)

static func _dot_i(a: Vector3i, b: Vector3i) -> int:
	return a.x * b.x + a.y * b.y + a.z * b.z

static func _cross_i(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(
		a.y * b.z - a.z * b.y,
		a.z * b.x - a.x * b.z,
		a.x * b.y - a.y * b.x
	)
