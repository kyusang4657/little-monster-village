class_name MeshBatch
extends RefCounted
## 기본 도형을 정점 색과 함께 하나의 메시로 합친다(모바일 그리기 호출 수 절감).

static var _cache: Dictionary = {}
static var _material: StandardMaterial3D

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
## 정점 색에 위·아래 명암을 넣을지(바닥·격자처럼 평평한 것은 끈다)
var shade := true
## 부품별 정점 범위(외곽선용 부드러운 법선을 부품 안에서만 평균낸다)
var _parts: Array[Vector2i] = []
static var _outline_mat: ShaderMaterial = null
const OUTLINE_WIDTH := 0.028
## 메뉴의 "외곽선" 설정(느린 기기에서 끌 수 있음). 새로 만드는 모델도 이 값을 따른다
static var outlines_on := true


## 건물·나무용 외곽선: 모서리가 갈라지지 않게 부품마다 같은 위치의 법선을 평균낸 방향(CUSTOM0)으로 부풀린다
static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
uniform vec4 line_color : source_color = vec4(0.17, 0.09, 0.05, 1.0);
uniform float width = 0.028;
void vertex() { VERTEX += CUSTOM0.xyz * width * CUSTOM0.w; }
void fragment() { ALBEDO = line_color.rgb; }
"""
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = sh
		_outline_mat.set_shader_parameter("width", OUTLINE_WIDTH)
	return _outline_mat


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
	_parts.append(Vector2i(base, base + v.size()))
	for i in v.size():
		_verts.append(xf * v[i])
		var nm := (basis_n * n[i]).normalized()
		_normals.append(nm)
		# 칠한 듯한 입체감(캐릭터와 같은 규칙): 윗면은 밝게, 아랫면은 어둡게
		_colors.append(color.lightened(0.12 * maxf(nm.y, 0.0)).darkened(0.15 * maxf(-nm.y, 0.0)) if shade else color)
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


## 사각 뿔대(모임지붕·탑 몸통). half = 바닥 반폭(x,z), top_ratio = 윗면/바닥 비율.
func quad_frustum(half: Vector2, top_ratio: float, h: float, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshBatch:
	var key := "qf:%.3f" % top_ratio
	var a := _arrays(key, func():
		var m := CylinderMesh.new()
		m.top_radius = top_ratio
		m.bottom_radius = 1.0
		m.height = 1.0
		m.radial_segments = 4
		m.rings = 1
		return m)
	var k := 1.0 / 0.70710678
	var basis := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(Vector3(half.x * k, h, half.y * k)) * Basis(Vector3.UP, PI * 0.25)
	_add(a, Transform3D(basis, pos), color)
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
	arr[Mesh.ARRAY_CUSTOM0] = _smooth_normals()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	m.surface_set_material(0, shared_material())
	return m


## 같은 부품 안에서 위치가 같은 정점들의 법선 평균(상자 모서리에서 외곽선이 끊기지 않게)
func _smooth_normals() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_verts.size() * 4)
	for part in _parts:
		var acc := {}
		# 작은 부품(문·창틀·장식)은 외곽선을 가늘게: 부품 크기 0.6 이상이면 1, 작을수록 최소 0.25
		var lo := _verts[part.x]
		var hi := _verts[part.x]
		for i in range(part.x, part.y):
			lo = lo.min(_verts[i])
			hi = hi.max(_verts[i])
		var ext := hi - lo
		var fw := clampf(maxf(ext.x, maxf(ext.y, ext.z)) / 0.6, 0.25, 1.0)
		for i in range(part.x, part.y):
			var k := Vector3i((_verts[i] * 1000.0).round())
			acc[k] = acc.get(k, Vector3.ZERO) + _normals[i]
		for i in range(part.x, part.y):
			var sn: Vector3 = acc[Vector3i((_verts[i] * 1000.0).round())]
			sn = sn.normalized() if sn.length() > 0.0001 else _normals[i]
			out[i * 4] = sn.x
			out[i * 4 + 1] = sn.y
			out[i * 4 + 2] = sn.z
			out[i * 4 + 3] = fw
	return out


## outline = 만화풍 외곽선(건물·나무·울타리). 바닥·꽃·격자 같은 평평한 것은 끈다.
func instance(node_name: String = "Mesh", outline: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh()
	if outline and OUTLINE_WIDTH > 0.0:
		mi.set_meta("outline", outline_material())
		if outlines_on:
			mi.material_overlay = outline_material()
	return mi
