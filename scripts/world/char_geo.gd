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
		g.sweep(lash, es * 0.15, F.pupil, 4)
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez + es * 0.3))
		g.use("Eye" + sfx)
		g.ellipsoid(Vector3(ex, ey, ez + es * 0.3), Vector3(es, es * 1.25, es * 0.6), Color("fbfbf7"), 8, 4)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, Vector3(ex - side * es * 0.12, ey - es * 0.12, ez - es * 0.25))
		g.use("Pupil" + sfx)
		var ir: float = F.get("iris", 1.0)
		g.ellipsoid(Vector3(ex - side * es * 0.12, ey - es * 0.12, ez - es * 0.25), Vector3(es * 0.62 * ir, es * 0.8 * ir, es * 0.3), F.pupil, 8 if ir > 1.0 else 6, 4)
		if F.has("pupil_core"):
			g.ellipsoid(Vector3(ex - side * es * 0.12, ey - es * 0.18, ez - es * 0.38), Vector3(es * 0.24, es * 0.32, es * 0.16), F.pupil_core, 6, 3)
		g.sphere(Vector3(ex - side * es * 0.12 + es * 0.22, ey + es * 0.22, ez - es * 0.52), es * 0.2 * ir, Color.WHITE, 4, 3)
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
		var bw := es * 1.05
		g.sweep([Vector3(ex - bw, by - es * 0.12, surf_z(hc, hr, ex - bw, by) - es * 0.1),
			Vector3(ex, by + es * 0.12, bz - es * 0.12),
			Vector3(ex + bw, by - es * 0.12, surf_z(hc, hr, ex + bw, by) - es * 0.1)], es * 0.24, F.brow, 4)
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

