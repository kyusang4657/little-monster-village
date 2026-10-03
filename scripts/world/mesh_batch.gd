class_name MeshBatch
extends RefCounted
## 기본 도형을 정점 색과 함께 하나의 메시로 합친다(모바일 그리기 호출 수 절감).

static var _cache: Dictionary = {}
static var _material: StandardMaterial3D

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


static func shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.metallic_specular = 0.15
		_material.roughness = 0.9
	return _material


static func _arrays(key: String, make: Callable) -> Array:
	if not _cache.has(key):
		var m: PrimitiveMesh = make.call()
		_cache[key] = m.get_mesh_arrays()
	return _cache[key]


func _add(arrays: Array, xf: Transform3D, color: Color) -> void:
	var base := _verts.size()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var basis_n := xf.basis.inverse().transposed()
	for i in v.size():
		_verts.append(xf * v[i])
		_normals.append((basis_n * n[i]).normalized())
		_colors.append(color)
	var idx = arrays[Mesh.ARRAY_INDEX]
	if idx == null or (idx as PackedInt32Array).is_empty():
		for i in v.size():
			_indices.append(base + i)
	else:
		for i in idx:
			_indices.append(base + i)


static func xform(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	return Transform3D(b, pos)


func box(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshBatch:
	var a := _arrays("box", func(): return BoxMesh.new())
	_add(a, Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(size), pos), color)
	return self


## 원기둥/원뿔. 축은 기본 Y. r_top=0 이면 원뿔.
func cyl(r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, segments: int = 12) -> MeshBatch:
	var key := "cyl:%.3f:%.3f:%d" % [r_top, r_bot, segments]
	var a := _arrays(key, func():
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bot
		m.height = 1.0
		m.radial_segments = segments
		m.rings = 1
		return m)
	_add(a, Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(Vector3(1, h, 1)), pos), color)
	return self


func sphere(r: float, pos: Vector3, color: Color, scl: Vector3 = Vector3.ONE, rot_deg: Vector3 = Vector3.ZERO) -> MeshBatch:
	var a := _arrays("sphere", func():
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = 14
		m.rings = 8
		return m)
	_add(a, Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl * r), pos), color)
	return self


## 삼각 기둥: 삼각형 면이 ±Z, 높이 Y.
func prism(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshBatch:
	var a := _arrays("prism", func(): return PrismMesh.new())
	_add(a, Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(size), pos), color)
	return self


func is_empty() -> bool:
	return _verts.is_empty()


func mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	if _verts.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _verts
	arr[Mesh.ARRAY_NORMAL] = _normals
	arr[Mesh.ARRAY_COLOR] = _colors
	arr[Mesh.ARRAY_INDEX] = _indices
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, shared_material())
	return m


func instance(node_name: String = "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh()
	return mi
