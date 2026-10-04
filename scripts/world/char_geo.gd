class_name CharGeo
extends RefCounted
## 캐릭터 기하 도우미: 기본 도형을 뼈 번호와 함께 하나의 스킨 메시로 모은다. 모든 좌표는 골격 공간(쉬는 자세)이다.
## 공통 부품(표준 골격·얼굴·팔다리)은 static 함수. 캐릭터별 빌더는 scripts/world/chars/ 에 있다.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()
var vb := PackedInt32Array()
var idx := PackedInt32Array()
var names := PackedStringArray()
var parents := PackedInt32Array()
var pos := PackedVector3Array()
var bone := 0
var measure := true        # HEIGHT(머리 꼭대기)에 넣는가
var measure_all := true    # 체력 막대 높이에 넣는가(무기 제외)
var line := 1.0            # 외곽선 두께 배율(정점 색 알파에 저장, 얼굴 부품은 0)
var top := 0.0
var all_top := 0.0

func add_bone(bname: String, parent: String, p: Vector3) -> void:
	names.append(bname)
	parents.append(names.find(parent) if parent != "" else -1)
	pos.append(p)

func use(bname: String) -> void:
	bone = names.find(bname)
	assert(bone >= 0, "뼈 없음: " + bname)

func _vert(p: Vector3, nn: Vector3, col: Color) -> void:
	v.append(p)
	var nm := nn.normalized()
	n.append(nm)
	# 칠한 듯한 입체감: 위를 보는 면은 밝게, 아래를 보는 면은 어둡게 정점 색에 미리 넣는다
	var shaded := col.lightened(0.16 * maxf(nm.y, 0.0)).darkened(0.2 * maxf(-nm.y, 0.0))
	shaded.a = line
	c.append(shaded)
	vb.append(bone)
	if measure:
		top = maxf(top, p.y)
	if measure_all:
		all_top = maxf(all_top, p.y)

## 삼각형(바깥 법선 기준으로 앞면 방향을 자동으로 맞춘다)
func tri(a: int, b: int, d: int) -> void:
	var cr := (v[b] - v[a]).cross(v[d] - v[a])
	var nn := n[a] + n[b] + n[d]
	idx.append(a)
	if cr.dot(nn) > 0.0:
		idx.append(d)
		idx.append(b)
	else:
		idx.append(b)
		idx.append(d)

## 타원체(위 극 = basis 의 +Y). lat_front/lat_back 으로 앞·뒤를 다른 깊이까지 자른 덮개도 만든다.
func ellipsoid(ce: Vector3, r: Vector3, col: Color, segs: int = 10, rings: int = 6, basis: Basis = Basis.IDENTITY,
		lat_front: float = PI, lat_back: float = PI, lat_min: float = 0.0) -> void:
	var base := v.size()
	for i in rings + 1:
		for j in segs + 1:
			var lon := TAU * float(j) / float(segs)
			var fw := (1.0 + cos(lon)) * 0.5
			var lat := lerpf(lat_min, lerpf(lat_back, lat_front, fw), float(i) / float(rings))
			var dir := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
			var nn := Vector3(dir.x / r.x, dir.y / r.y, dir.z / r.z)
			_vert(ce + basis * (dir * r), basis * nn, col)
	var closed_bottom := lat_front >= PI - 0.001 and lat_back >= PI - 0.001
	for i in rings:
		for j in segs:
			var a := base + i * (segs + 1) + j
			var b := a + 1
			var d := a + segs + 1
			var e := d + 1
			if not (i == 0 and lat_min <= 0.0):
				tri(a, b, d)
			if not (i == rings - 1 and closed_bottom):
				tri(b, e, d)

func sphere(ce: Vector3, r: float, col: Color, segs: int = 8, rings: int = 5) -> void:
	ellipsoid(ce, Vector3(r, r, r), col, segs, rings)

## 원뿔대(a→b, 반지름 ra→rb). fu/fw = 단면 납작 비율(u 는 ref 쪽 축).
func tube(a: Vector3, b: Vector3, ra: float, rb: float, col: Color, segs: int = 8, caps: bool = true,
		fu: float = 1.0, fw: float = 1.0, ref_axis: Vector3 = Vector3.RIGHT) -> void:
	var axis := b - a
	var l := axis.length()
	if l < 0.00001:
		return
	var d := axis / l
	var ref := ref_axis
	if absf(d.dot(ref)) > 0.95:
		ref = Vector3.BACK if absf(d.z) < 0.95 else Vector3.UP
	var u := (ref - d * ref.dot(d)).normalized()
	var w := d.cross(u)
	var slope := (ra - rb) / l
	var base := v.size()
	for k in 2:
		var p0 := a if k == 0 else b
		var r := ra if k == 0 else rb
		for j in segs + 1:
			var ang := TAU * float(j) / float(segs)
			var off := u * (cos(ang) * r * fu) + w * (sin(ang) * r * fw)
			var nn := (u * (cos(ang) / fu) + w * (sin(ang) / fw)).normalized() + d * slope
			_vert(p0 + off, nn, col)
	for j in segs:
		var i0 := base + j
		var i2 := base + segs + 1 + j
		tri(i0, i2, i0 + 1)
		tri(i0 + 1, i2, i2 + 1)
	if caps:
		for k in 2:
			var p0 := a if k == 0 else b
			var r := ra if k == 0 else rb
			if r <= 0.0001:
				continue
			var nn := -d if k == 0 else d
			var cb := v.size()
			_vert(p0, nn, col)
			for j in segs:
				var ang := TAU * float(j) / float(segs)
				_vert(p0 + u * (cos(ang) * r * fu) + w * (sin(ang) * r * fw), nn, col)
			for j in segs:
				tri(cb, cb + 1 + j, cb + 1 + (j + 1) % segs)

## 점들을 잇는 가는 관(눈썹·입·테두리)
func sweep(pts: Array, r: float, col: Color, segs: int = 5, closed: bool = false) -> void:
	var cnt := pts.size() if closed else pts.size() - 1
	for i in cnt:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		var ext := (b - a).normalized() * r * 0.5
		tube(a - ext, b + ext, r, r, col, segs, not closed and (i == 0 or i == cnt - 1))

## 상자(basis 의 열 = 축 방향)
func box(ce: Vector3, size: Vector3, col: Color, basis: Basis = Basis.IDENTITY) -> void:
	var axes := [basis.x.normalized(), basis.y.normalized(), basis.z.normalized()]
	for f in 6:
		var ax: int = f >> 1
		var sgn := 1.0 if f % 2 == 0 else -1.0
		var nn: Vector3 = axes[ax] * sgn
		var ua: Vector3 = axes[(ax + 1) % 3]
		var wa: Vector3 = axes[(ax + 2) % 3]
		var hn := size[ax] * 0.5
		var hu := size[(ax + 1) % 3] * 0.5
		var hw := size[(ax + 2) % 3] * 0.5
		var b0 := v.size()
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			_vert(ce + nn * hn + ua * (hu * q.x) + wa * (hw * q.y), nn, col)
		tri(b0, b0 + 1, b0 + 2)
		tri(b0, b0 + 2, b0 + 3)


# ------------------------------------------------------------------ 둥근·휘는 도형(5차)

static func _sp(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)


## 모서리가 둥근 상자(초타원체). n = 1 이면 타원체, 작을수록 상자에 가깝다(0.35~0.6 추천). 위 극 = basis 의 +Y, 정면 = -Z.
func rounded_box(ce: Vector3, r: Vector3, col: Color, n: float = 0.45, segs: int = 12, rings: int = 8, basis: Basis = Basis.IDENTITY) -> void:
	var base := v.size()
	for i in rings + 1:
		var lat := PI * float(i) / float(rings)
		var cy := cos(lat)
		var sy := sin(lat)
		for j in segs + 1:
			var lon := TAU * float(j) / float(segs)
			var sx := sin(lon)
			var cz := -cos(lon)
			var p := Vector3(_sp(sy, n) * _sp(sx, n) * r.x, _sp(cy, n) * r.y, _sp(sy, n) * _sp(cz, n) * r.z)
			var nn := Vector3(_sp(sy, 2.0 - n) * _sp(sx, 2.0 - n) / r.x, _sp(cy, 2.0 - n) / r.y, _sp(sy, 2.0 - n) * _sp(cz, 2.0 - n) / r.z)
			_vert(ce + basis * p, basis * nn, col)
	for i in rings:
		for j in segs:
			var a := base + i * (segs + 1) + j
			var b := a + 1
			var d := a + segs + 1
			var e := d + 1
			if i > 0:
				tri(a, b, d)
			if i < rings - 1:
				tri(b, e, d)


## 점들을 지나는 매끈한 관(뿔·꼬리·몽둥이·깃털·창): 마디마다 반지름이 다르고(radii, pts 와 같은 수) 고리 정점을 공유해 법선이 이어진다.
## 프레임은 앞 마디의 축을 이어 받아(평행 이동) 꼬이지 않는다. 끝 반지름을 0 으로 주면 뾰족하다. fu/fw = 단면 납작 비율.
func spline_tube(pts: Array, radii: Array, col: Color, segs: int = 8, cap_start: bool = true, cap_end: bool = true,
		ref_axis: Vector3 = Vector3.RIGHT, fu: float = 1.0, fw: float = 1.0) -> void:
	var cnt := pts.size()
	if cnt < 2 or radii.size() != cnt:
		return
	var tan: Array[Vector3] = []
	for i in cnt:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, cnt - 1)]
		var t := b - a
		tan.append(t.normalized() if t.length() > 0.00001 else Vector3.UP)
	var u := ref_axis
	if absf(tan[0].dot(u)) > 0.95:
		u = Vector3.BACK if absf(tan[0].z) < 0.95 else Vector3.UP
	u = (u - tan[0] * u.dot(tan[0])).normalized()
	var us: Array[Vector3] = []
	var ws: Array[Vector3] = []
	var base := v.size()
	for i in cnt:
		var d: Vector3 = tan[i]
		u = (u - d * u.dot(d)).normalized()
		var w := d.cross(u)
		us.append(u)
		ws.append(w)
		var r: float = radii[i]
		var r_prev: float = radii[maxi(i - 1, 0)]
		var r_next: float = radii[mini(i + 1, cnt - 1)]
		var span: float = (pts[mini(i + 1, cnt - 1)] - pts[maxi(i - 1, 0)]).length()
		var slope := (r_prev - r_next) / maxf(span, 0.0001)
		for j in segs + 1:
			var ang := TAU * float(j) / float(segs)
			var off := u * (cos(ang) * r * fu) + w * (sin(ang) * r * fw)
			var nn := (u * (cos(ang) / fu) + w * (sin(ang) / fw)).normalized() + d * slope
			_vert(pts[i] + off, nn, col)
	for i in cnt - 1:
		for j in segs:
			var i0 := base + i * (segs + 1) + j
			var i2 := i0 + segs + 1
			tri(i0, i2, i0 + 1)
			tri(i0 + 1, i2, i2 + 1)
	for k in 2:
		if (k == 0 and not cap_start) or (k == 1 and not cap_end):
			continue
		var ii := 0 if k == 0 else cnt - 1
		var r: float = radii[ii]
		if r <= 0.0001:
			continue
		var nn: Vector3 = -tan[ii] if k == 0 else tan[ii]
		var cb := v.size()
		var p0: Vector3 = pts[ii]
		_vert(p0, nn, col)
		for j in segs:
			var ang := TAU * float(j) / float(segs)
			_vert(p0 + us[ii] * (cos(ang) * r * fu) + ws[ii] * (sin(ang) * r * fw), nn, col)
		for j in segs:
			tri(cb, cb + 1 + j, cb + 1 + (j + 1) % segs)


## 휘는 뿔·가시: base 에서 dir 쪽으로 길이 L 만큼 자라며 bend(단위 벡터 쪽)로 점점 휜다. 뿌리 반지름 r0, 끝은 뾰족. 마디 n 개.
func horn(base: Vector3, dir: Vector3, bend: Vector3, L: float, r0: float, col: Color, n: int = 6, segs: int = 8, tip_col: Color = Color(0, 0, 0, 0)) -> void:
	var d := dir.normalized()
	var pts: Array = []
	var radii: Array = []
	for i in n + 1:
		var t := float(i) / float(n)
		pts.append(base + d * (L * t) + bend * (L * t * t))
		radii.append(r0 * pow(1.0 - t, 0.85))
	if tip_col.a > 0.0 and n >= 3:
		var cut := n - 2
		spline_tube(pts.slice(0, cut + 1), radii.slice(0, cut + 1), col, segs, true, false)
		spline_tube(pts.slice(cut), radii.slice(cut), tip_col, segs, false, true)
	else:
		spline_tube(pts, radii, col, segs, true, true)


## 도넛(털 테두리·왕관 띠·팔찌·목걸이). 축 = basis 의 +Y
func torus(ce: Vector3, R: float, r: float, col: Color, segs: int = 12, rings: int = 6, basis: Basis = Basis.IDENTITY) -> void:
	var base := v.size()
	for i in segs + 1:
		var a := TAU * float(i) / float(segs)
		var cdir := Vector3(cos(a), 0, sin(a))
		for j in rings + 1:
			var b := TAU * float(j) / float(rings)
			var nn := cdir * cos(b) + Vector3.UP * sin(b)
			_vert(ce + basis * (cdir * R + nn * r), basis * nn, col)
	for i in segs:
		for j in rings:
			var i0 := base + i * (rings + 1) + j
			var i1 := i0 + rings + 1
			tri(i0, i1, i0 + 1)
			tri(i0 + 1, i1, i1 + 1)


## 평면 다각형 기둥(가슴 문장·별·방패 모양·왕관 톱니·망토 깃). pts2 = basis 의 x/y 평면 좌표(시계 반대), origin 기준, 두께 th(basis.z 방향 ±).
func polygon(pts2: PackedVector2Array, origin: Vector3, basis: Basis, th: float, col: Color, side_col: Color = Color(0, 0, 0, 0)) -> void:
	var tri_idx := Geometry2D.triangulate_polygon(pts2)
	if tri_idx.is_empty():
		return
	var ex := basis.x.normalized()
	var ey := basis.y.normalized()
	var ez := basis.z.normalized()
	var sc := side_col if side_col.a > 0.0 else col
	for s: float in [1.0, -1.0]:
		var nn := ez * s
		var b0 := v.size()
		for p in pts2:
			_vert(origin + ex * p.x + ey * p.y + nn * (th * 0.5), nn, col)
		for k in range(0, tri_idx.size(), 3):
			tri(b0 + tri_idx[k], b0 + tri_idx[k + 1], b0 + tri_idx[k + 2])
	if th <= 0.0001:
		return
	var n2 := pts2.size()
	for i in n2:
		var p: Vector2 = pts2[i]
		var q: Vector2 = pts2[(i + 1) % n2]
		var e := q - p
		var nn := (ex * e.y - ey * e.x).normalized()
		var b0 := v.size()
		_vert(origin + ex * p.x + ey * p.y + ez * (th * 0.5), nn, sc)
		_vert(origin + ex * q.x + ey * q.y + ez * (th * 0.5), nn, sc)
		_vert(origin + ex * q.x + ey * q.y - ez * (th * 0.5), nn, sc)
		_vert(origin + ex * p.x + ey * p.y - ez * (th * 0.5), nn, sc)
		tri(b0, b0 + 1, b0 + 2)
		tri(b0, b0 + 2, b0 + 3)


## 별 다각형 좌표(문장·왕관 보석·성기사 방패). points = 꼭짓점 수, r_out/r_in = 바깥·안쪽 반지름
static func star(points: int, r_out: float, r_in: float, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * 0.5 + TAU * float(i) / float(points * 2)
		var r := r_out if i % 2 == 0 else r_in
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


## 박쥐 날개(양면 막 + 뼈대). root = 어깨 뿌리, tips = 손가락 끝 점들(위→아래 순서). 손가락 사이 막 가장자리는 안쪽으로 패인다(scallop 0~1).
func wing(root: Vector3, tips: Array, bone_r: float, bone_c: Color, mem_c: Color, scallop: float = 0.3, thickness: float = 0.004, segs: int = 4) -> void:
	var nt := tips.size()
	if nt < 2:
		return
	for t in tips:
		tube(root, t, bone_r, bone_r * 0.45, bone_c, 5, true)
	var hint := ((tips[0] as Vector3 - root).cross(tips[nt - 1] as Vector3 - root)).normalized()
	var keep := line
	line = keep * 0.6
	for s: float in [1.0, -1.0]:
		var nn := hint * s
		var off := nn * thickness
		for i in nt - 1:
			var a: Vector3 = tips[i]
			var b: Vector3 = tips[i + 1]
			var b0 := v.size()
			_vert(root + off, nn, mem_c)
			for k in segs + 1:
				var t := float(k) / float(segs)
				var p := a.lerp(b, t).lerp(root, scallop * sin(t * PI))
				_vert(p + off, nn, mem_c)
			for k in segs:
				tri(b0, b0 + 1 + k, b0 + 2 + k)
	line = keep


## 망토 천(양면, 안팎 다른 색). top 가운데 윗점에서 length 만큼 내려오며 폭 w_top → w_bot, 아래로 갈수록 뒤(+Z)로 drape 만큼 흘러내리고
## 양옆은 몸을 감싸듯 앞(-Z)으로 wrap 만큼 굽는다. hem_wave > 0 이면 단이 물결친다.
func cape(top: Vector3, length: float, w_top: float, w_bot: float, col_out: Color, col_in: Color,
		drape: float = 0.1, wrap: float = 0.06, hem_wave: float = 0.0, cols: int = 6, rows: int = 5, thickness: float = 0.006) -> void:
	var P: Array = []
	for i in rows + 1:
		var t := float(i) / float(rows)
		var w := lerpf(w_top, w_bot, t)
		var row: Array = []
		for j in cols + 1:
			var u := float(j) / float(cols) - 0.5
			var y := top.y - length * t
			if hem_wave > 0.0:
				y -= hem_wave * t * t * (0.5 + 0.5 * cos(u * TAU * 1.5))
			var z := top.z + drape * t * t - wrap * (u * u * 4.0) * (0.3 + 0.7 * t)
			row.append(Vector3(top.x + u * w, y, z))
		P.append(row)
	var keep := line
	line = keep * 0.8
	for s: float in [1.0, -1.0]:
		var col := col_out if s > 0.0 else col_in
		var b0 := v.size()
		for i in rows + 1:
			for j in cols + 1:
				var p: Vector3 = P[i][j]
				var du: Vector3 = (P[i][mini(j + 1, cols)] as Vector3) - (P[i][maxi(j - 1, 0)] as Vector3)
				var dt: Vector3 = (P[mini(i + 1, rows)][j] as Vector3) - (P[maxi(i - 1, 0)][j] as Vector3)
				var nn := du.cross(dt).normalized()
				if nn.z < 0.0:
					nn = -nn
				nn *= s
				_vert(p + nn * thickness, nn, col)
		for i in rows:
			for j in cols:
				var a := b0 + i * (cols + 1) + j
				var d := a + cols + 1
				tri(a, a + 1, d)
				tri(a + 1, d + 1, d)
	line = keep


func build(material: Material) -> Dictionary:
	var m := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(v.size() * 4)
	weights.resize(v.size() * 4)
	for i in v.size():
		bones[i * 4] = vb[i]
		weights[i * 4] = 1.0
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, material)
	var skin := Skin.new()
	for i in names.size():
		skin.add_bind(i, Transform3D(Basis.IDENTITY, -pos[i]))
	return {mesh = m, skin = skin, names = names, parents = parents, pos = pos, verts = v, vbones = vb,
		top = top, all_top = all_top, tris = int(idx.size() / 3.0)}



# ================================================================== 공통 부품

## 표준 골격(쉬는 자세: 팔은 어깨 아래로 곧게, 다리는 엉덩이 아래로 곧게)
static func skeleton(g: CharGeo, P: Dictionary) -> void:
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	g.add_bone("Root", "", Vector3.ZERO)
	g.add_bone("Pelvis", "Root", Vector3(0, P.pelvis, 0))
	g.add_bone("Spine", "Pelvis", Vector3(0, P.spine, 0))
	g.add_bone("Neck", "Spine", Vector3(0, P.neck, 0))
	g.add_bone("Head", "Neck", Vector3(0, P.head, 0))
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.add_bone("Arm" + sfx, "Spine", Vector3(sx * side, P.shoulder, 0))
		g.add_bone("Forearm" + sfx, "Arm" + sfx, Vector3(sx * side, P.elbow, 0))
		g.add_bone("Hand" + sfx, "Forearm" + sfx, Vector3(sx * side, P.wrist, 0))
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.add_bone("Leg" + sfx, "Pelvis", Vector3(hx * side, P.hip, 0))
		g.add_bone("Shin" + sfx, "Leg" + sfx, Vector3(hx * side, P.knee, 0))
		g.add_bone("Foot" + sfx, "Shin" + sfx, Vector3(hx * side, P.ankle, 0))


static func surf_z(hc: Vector3, hr: Vector3, x: float, y: float) -> float:
	var q := 1.0 - pow((x - hc.x) / hr.x, 2.0) - pow((y - hc.y) / hr.y, 2.0)
	return hc.z - hr.z * sqrt(maxf(0.04, q))


## 얼굴: 흰자+눈동자+반사광, 눈꺼풀(깜빡임/표정), 눈썹, 입 세 가지(보통·화남·아픔), 코, 볼
## F 필수: hc, hr(머리 타원), es(눈 크기), eye_y, eye_dx, mouth_y, mouth_w, skin, pupil, brow
## F 선택: sclera(흰자 색, 용은 노랑), pupil_shape("round"/"slit"), eye_rim(눈 테두리 색), eye_w(눈 가로 배수), iris, pupil_core,
##         shine(반사광 크기), lash(감은 눈 선 색), lid(눈꺼풀 색), brow_w/brow_t(눈썹 길이·두께 배수), blush
static func face(g: CharGeo, F: Dictionary) -> void:
	# 눈·입 같은 작은 얼굴 부품에는 외곽선을 두르지 않는다(얼굴이 지저분해 보이지 않게)
	var keep_line := g.line
	g.line = 0.0
	face_parts(g, F)
	g.line = keep_line


static func face_parts(g: CharGeo, F: Dictionary) -> void:
	var hc: Vector3 = F.hc
	var hr: Vector3 = F.hr
	var es: float = F.es
	var ey: float = F.eye_y
	var skin: Color = F.skin
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var ex: float = float(F.eye_dx) * side
		var ez := surf_z(hc, hr, ex, ey)
		# 감은 눈 선(눈알 뒤에 숨어 있다가 눈알을 누르면 보인다)
		g.use("Head")
		var lash: Array = []
		for i in 5:
			var u := float(i) / 2.0 - 1.0
			var lx := ex + u * es * 0.85
			var ly := ey - es * (0.32 - 0.27 * u * u)
			lash.append(Vector3(lx, ly, surf_z(hc, hr, lx, ly) - es * 0.05))
		g.sweep(lash, es * 0.15, F.get("lash", F.pupil), 4)
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez + es * 0.3))
		g.use("Eye" + sfx)
		# 눈 테두리(eye_rim): 눈알 뒤에 조금 더 큰 짙은 타원 → 그림처럼 눈이 또렷해진다. 눈알 뼈에 붙어 같이 감긴다
		var ew: float = F.get("eye_w", 1.0)
		if F.has("eye_rim"):
			g.ellipsoid(Vector3(ex, ey, ez + es * 0.34), Vector3(es * 1.16 * ew, es * 1.4, es * 0.6), F.eye_rim, 8, 4)
		g.ellipsoid(Vector3(ex, ey, ez + es * 0.3), Vector3(es * ew, es * 1.25, es * 0.6), F.get("sclera", Color("fbfbf7")), 8, 4)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, Vector3(ex - side * es * 0.12, ey - es * 0.12, ez - es * 0.25))
		g.use("Pupil" + sfx)
		var ir: float = F.get("iris", 1.0)
		var pc := Vector3(ex - side * es * 0.12, ey - es * 0.12, ez - es * 0.25)
		if String(F.get("pupil_shape", "round")) == "slit":
			# 세로 동공(용·고양이 눈): 좁고 긴 타원
			g.ellipsoid(pc, Vector3(es * 0.2 * ir, es * 0.86 * ir, es * 0.3), F.pupil, 6, 4)
		else:
			g.ellipsoid(pc, Vector3(es * 0.62 * ir, es * 0.8 * ir, es * 0.3), F.pupil, 8 if ir > 1.0 else 6, 4)
		if F.has("pupil_core"):
			g.ellipsoid(Vector3(ex - side * es * 0.12, ey - es * 0.18, ez - es * 0.38), Vector3(es * 0.24, es * 0.32, es * 0.16), F.pupil_core, 6, 3)
		g.sphere(Vector3(ex - side * es * 0.12 + es * 0.22, ey + es * 0.22, ez - es * 0.52), es * 0.2 * F.get("shine", ir), Color.WHITE, 4, 3)
		# 윗눈꺼풀: 아래 반구 덮개. 뼈(눈 위쪽)에서 Y 크기를 키우면 내려와 눈을 덮는다.
		var lid_p := Vector3(ex, ey + es * 1.3, ez + es * 0.1)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.22, es * 2.7, es * 0.88), F.get("lid", skin.darkened(0.06)), 6, 3, Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹
		var by := ey + es * 2.05
		var bz := surf_z(hc, hr, ex, by)
		g.add_bone("Brow" + sfx, "Head", Vector3(ex, by, bz))
		g.use("Brow" + sfx)
		var bw: float = es * 1.05 * float(F.get("brow_w", 1.0))
		var bt: float = es * 0.24 * float(F.get("brow_t", 1.0))
		g.sweep([Vector3(ex - bw, by - es * 0.12, surf_z(hc, hr, ex - bw, by) - es * 0.1),
			Vector3(ex, by + es * 0.12, bz - es * 0.12),
			Vector3(ex + bw, by - es * 0.12, surf_z(hc, hr, ex + bw, by) - es * 0.1)], bt, F.brow, 4)
	# 입
	var my: float = F.mouth_y
	var mw: float = F.mouth_w
	var mz := surf_z(hc, hr, 0.0, my)
	var dark := Color("4a1f28")
	g.add_bone("MouthN", "Head", Vector3(0, my, mz))
	g.use("MouthN")
	var pts: Array = []
	for i in 5:
		var u := float(i) / 2.0 - 1.0
		var x := u * mw * 0.5
		var y := my + u * u * mw * 0.28
		pts.append(Vector3(x, y, surf_z(hc, hr, x, y) - mw * 0.03))
	g.sweep(pts, mw * 0.09, dark, 4)
	g.add_bone("MouthA", "Head", Vector3(0, my, mz))
	g.use("MouthA")
	g.ellipsoid(Vector3(0, my - mw * 0.05, mz + mw * 0.08), Vector3(mw * 0.45, mw * 0.26, mw * 0.2), dark, 8, 4)
	g.ellipsoid(Vector3(0, my + mw * 0.1, mz - mw * 0.03), Vector3(mw * 0.36, mw * 0.07, mw * 0.12), Color.WHITE, 6, 3)
	g.add_bone("MouthH", "Head", Vector3(0, my, mz))
	g.use("MouthH")
	g.ellipsoid(Vector3(0, my - mw * 0.05, mz + mw * 0.05), Vector3(mw * 0.2, mw * 0.24, mw * 0.14), dark, 6, 4)
	g.use("Head")
	# 볼 홍조
	if F.has("blush"):
		for side: float in [-1.0, 1.0]:
			var x: float = float(F.eye_dx) * side * 1.35
			var y := ey - es * 1.6
			g.ellipsoid(Vector3(x, y, surf_z(hc, hr, x, y) + es * 0.15), Vector3(es * 0.7, es * 0.4, es * 0.3), F.blush, 6, 3)


## 팔(어깨 공·위팔·팔꿈치 공·아래팔·주먹)과 다리(허벅지·무릎 공·정강이·신발 앞코)
static func limbs(g: CharGeo, P: Dictionary, C: Dictionary) -> void:
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	var ar: float = P.arm_r
	var lr: float = P.leg_r
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Arm" + sfx)
		if C.has("shoulder"):
			g.sphere(Vector3(x, P.shoulder, 0), ar * 1.3, C.shoulder, 8, 5)
		g.tube(Vector3(x, P.shoulder, 0), Vector3(x, P.elbow, 0), ar * 1.1, ar * 0.95, C.upper, 7, false)
		g.use("Forearm" + sfx)
		g.sphere(Vector3(x, P.elbow, 0), ar * 1.02, C.elbow, 7, 4)
		g.tube(Vector3(x, P.elbow, 0), Vector3(x, P.wrist, 0), ar * 0.98, ar * 0.82, C.fore, 7, false)
		g.use("Hand" + sfx)
		if C.has("cuff"):
			g.tube(Vector3(x, P.wrist + ar * 0.9, 0), Vector3(x, P.wrist - ar * 0.2, 0), ar * 1.05, ar * 1.12, C.cuff, 7, true)
		var hs: float = C.get("hand_s", 1.0)
		g.ellipsoid(Vector3(x, P.wrist - ar * 0.75, -ar * 0.1), Vector3(ar * 1.12, ar * 1.2, ar * 1.15) * hs, C.hand, 8, 5)
		var lx := hx * side
		g.use("Leg" + sfx)
		g.tube(Vector3(lx, P.hip + lr * 0.4, 0), Vector3(lx, P.knee, 0), lr * 1.15, lr * 0.95, C.thigh, 7, false)
		g.use("Shin" + sfx)
		g.sphere(Vector3(lx, P.knee, 0), lr * 1.0, C.knee, 7, 4)
		g.tube(Vector3(lx, P.knee, 0), Vector3(lx, P.ankle, 0), lr * 0.95, lr * 0.78, C.shin, 7, false)
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		var fh: float = P.ankle
		g.tube(Vector3(lx, P.ankle + lr * 0.6, 0), Vector3(lx, P.ankle - lr * 0.3, 0), lr * 0.95, lr * 1.0, C.cuff_leg, 7, true)
		var bs: float = C.get("boot_s", 1.0)
		g.ellipsoid(Vector3(lx, fh * 0.55 * bs, -fl * 0.22 * bs), Vector3(lr * 1.3 * bs, fh * 0.56 * bs, fl * 0.5 * bs), C.boot, 8, 5)
		if C.has("toe"):
			g.tube(Vector3(lx, fh * 0.55, -fl * 0.55), Vector3(lx, fh * 1.2, -fl * 0.95), lr * 0.75, 0.0, C.toe, 6, true)

