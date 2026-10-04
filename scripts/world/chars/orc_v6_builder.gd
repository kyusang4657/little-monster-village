class_name OrcV6Builder
extends RefCounted
## 6차 교체 후보(꼬마 오크). 5차 디자인(OrcBuilder)을 그대로 두고 조립한 기본 도형 대신 이어지는 곡면으로 다시 만든다.
## 머리 = 조각 구 한 장(넓은 아래턱·주걱턱·굵은 눈썹 능선·둥근 코·눈두덩 패임), 눈은 눈두덩 속 크림색 눈알 + 눈알 위 짙은 뚜껑,
## 모히칸 = 정수리 가운데 줄을 따라가는 한 장의 쐐기 지느러미(뒤로 쓸린 큰 볏 셋이 겹친다, 뿌리는 주황빛 갈색 → 붉은 볏),
## 몸통 = 회전체 두 장(목 피부·짙은 가죽 조끼와 치마), 둥근 어깨 받이 = 어깨 위 가죽 회전체(아래 테가 짙고, 안쪽 반은 가슴 속에 묻힌다),
## 팔다리 = 몸속에서 시작하는 이어진 관(팔뚝이 손목 쪽으로 굵어지고 가죽 손목 띠, 바지 → 장화), 왕주먹·장화 = 조각 구,
## 옹이 몽둥이 = 축을 따라 반지름이 부푸는 관 한 장(옹이 혹이 면에 이어짐) + 놋쇠 징. 기본 키 HEIGHT 1.0(게임에서 1.3 배).

const SKIN := Color("6b8e3a")
const SKIN_DARK := Color("53722a")
const SKIN_LIGHT := Color("7fa24a")
const EAR_IN := Color("486424")
const MOHAWK := Color("d0352a")
const MOHAWK_HI := Color("ee6a40")
const ROOT := Color("b9652c")
const BROW := Color("1c2411")
const LASH := Color("1a1512")
const SCLERA := Color("f6f0e0")
const PUPIL := Color("221c20")
const ARMOR := Color("4b4752")
const ARMOR_DARK := Color("36323c")
const STRAP := Color("a0622e")
const STRAP_DARK := Color("74441e")
const PAD := Color("6e4a2a")
const PAD_LIGHT := Color("7e5832")
const PAD_RIM := Color("4a3018")
const BRASS := Color("cfa548")
const BRASS_DARK := Color("9c7a2e")
const TROUSER := Color("6e4524")
const BOOT := Color("46301b")
const BOOT_TOE := Color("6a4a2a")
const CLUB := Color("8f5c2e")
const CLUB_DARK := Color("5e3a1c")
const CLUB_LIGHT := Color("a8743c")
const TUSK := Color("f3ead2")
const TEETH := Color("f6f2e6")
const MOUTH := Color("3a1820")

const P := {
	ankle = 0.07, knee = 0.16, hip = 0.27, hip_x = 0.1, pelvis = 0.285, spine = 0.34,
	shoulder = 0.535, shoulder_x = 0.245, elbow = 0.42, wrist = 0.315, neck = 0.57, head = 0.61,
	arm_r = 0.05, leg_r = 0.058, foot_len = 0.19,
}
const HC := Vector3(0, 0.78, -0.005)       # 머리 중심
const HR := Vector3(0.2, 0.19, 0.195)      # 머리 반지름(조각 전)
const ES := 0.046                           # 눈 크기(작고 매서운 눈)
const EYE_DX := 0.43
const EYE_DY := 0.12

# 조끼 회전체 프로파일(y, rx, rz) — 띠·버클을 겉면에 붙일 때 같은 값으로 보간한다
const VEST := [
	[0.585, 0.105, 0.098], [0.567, 0.13, 0.12], [0.552, 0.195, 0.152], [0.525, 0.236, 0.17], [0.475, 0.252, 0.18],
	[0.415, 0.257, 0.186], [0.365, 0.248, 0.181], [0.335, 0.238, 0.174], [0.3, 0.24, 0.176],
	[0.215, 0.258, 0.194], [0.2, 0.262, 0.196], [0.188, 0.256, 0.19], [0.182, 0.2, 0.15],
]


static func build() -> Dictionary:
	var g := DemonGeo.new()
	g.bake = 0.0
	CharGeo.skeleton(g, P)
	_torso(g)
	_arms(g)
	_legs(g)
	_head(g)
	var hand := Vector3(float(P.shoulder_x) + 0.012, float(P.wrist) - float(P.arm_r) * 1.15, -0.04)
	var tip := _club(g, hand)
	var def := g.build(CharacterRig.character_material())
	def.tip = tip
	def.H = 1.0
	def.es = ES
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


# ------------------------------------------------------------------ 공용 도우미

## 격자 곡면 한 장: P[i][j] = 점(i 행, j 열). wrap 이면 열이 둥글게 닫힌다(마지막 열 → 첫 열).
## 법선은 이웃 점 차분으로 계산하고, 방향은 center 에서 바깥을 보도록 면 전체에 한 번 맞춘다(매개변수가 이어져 있어 부호가 일정).
## col_of.call(i, j) -> Color. bones 가 있으면 행마다 뼈, lines 가 있으면 행마다 외곽선 세기.
static func _grid(g: DemonGeo, pts: Array, col_of: Callable, wrap: bool, center: Vector3, bones: Array = [], lines: Array = []) -> void:
	var rows := pts.size()
	var cols := (pts[0] as Array).size()
	var nrm: Array = []
	var score := 0.0
	for i in rows:
		var row: Array = pts[i]
		var up_row: Array = pts[maxi(i - 1, 0)]
		var dn_row: Array = pts[mini(i + 1, rows - 1)]
		var nrow: Array = []
		for j in cols:
			var jm := (j - 1 + cols) % cols if wrap else maxi(j - 1, 0)
			var jp := (j + 1) % cols if wrap else mini(j + 1, cols - 1)
			var du: Vector3 = (row[jp] as Vector3) - (row[jm] as Vector3)
			var dv: Vector3 = (dn_row[j] as Vector3) - (up_row[j] as Vector3)
			var nn := du.cross(dv)
			var p: Vector3 = row[j]
			if nn.length() < 0.0000001:
				nn = p - center
			nn = nn.normalized()
			score += nn.dot((p - center).normalized())
			nrow.append(nn)
		nrm.append(nrow)
	var sgn := 1.0 if score >= 0.0 else -1.0
	var keep_line := g.line
	var base := g.v.size()
	for i in rows:
		if not bones.is_empty():
			g.use(String(bones[i]))
		if not lines.is_empty():
			g.line = float(lines[i])
		var row: Array = pts[i]
		var nrow: Array = nrm[i]
		for j in cols:
			var p: Vector3 = row[j]
			var nn: Vector3 = nrow[j]
			var cc: Color = col_of.call(i, j)
			g._vert(p, nn * sgn, cc)
	g.line = keep_line
	var jn := cols if wrap else cols - 1
	for i in rows - 1:
		for j in jn:
			var a := base + i * cols + j
			var b := base + i * cols + (j + 1) % cols
			var d := a + cols
			var e := b + cols
			g.tri(a, b, d)
			g.tri(b, e, d)


## 조끼 회전체의 높이 y 에서 (rx, rz)
static func _vest_r(y: float) -> Vector2:
	for i in VEST.size() - 1:
		var a: Array = VEST[i]
		var b: Array = VEST[i + 1]
		var ya: float = a[0]
		var yb: float = b[0]
		if y <= ya and y >= yb:
			var t := (ya - y) / maxf(ya - yb, 0.0001)
			return Vector2(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t))
	var last: Array = VEST[VEST.size() - 1] if y < 0.3 else VEST[0]
	return Vector2(float(last[1]), float(last[2]))


## 조끼 겉면 위의 점(x, y). front = 앞면(-Z)인가. lift = 겉면에서 띄우는 거리. 돌려주는 값 = [점, 법선]
static func _on_vest(x: float, y: float, front: bool, lift: float) -> Array:
	var r := _vest_r(y)
	var q := sqrt(maxf(1.0 - pow(clampf(x / r.x, -0.999, 0.999), 2.0), 0.0))
	var z := r.y * q * (-1.0 if front else 1.0)
	var nn := Vector3(x / (r.x * r.x), 0.0, z / (r.y * r.y)).normalized()
	return [Vector3(x, y, z) + nn * lift, nn]


## 조끼 겉면을 따라가는 끈(path = 앞에서 본 (x, y) 점들). 폭 hw*2, 겉면에서 lift 만큼 띄운다.
static func _band(g: DemonGeo, path: Array, hw: float, front: bool, lift: float, col: Color, steps: int = 10) -> void:
	var keep := g.line
	g.line = 0.0
	var base := g.v.size()
	var cnt := path.size()
	var samples: Array = []
	for k in steps + 1:
		var t := float(k) / float(steps) * float(cnt - 1)
		var i0 := mini(int(floor(t)), cnt - 2)
		var a: Vector2 = path[i0]
		var b: Vector2 = path[i0 + 1]
		var q := a.lerp(b, t - float(i0))
		samples.append(_on_vest(q.x, q.y, front, lift))
	for k in steps + 1:
		var s0: Array = samples[maxi(k - 1, 0)]
		var s1: Array = samples[mini(k + 1, steps)]
		var cur: Array = samples[k]
		var p: Vector3 = cur[0]
		var nn: Vector3 = cur[1]
		var tng := ((s1[0] as Vector3) - (s0[0] as Vector3)).normalized()
		var side := nn.cross(tng).normalized()
		g._vert(p - side * hw, nn, col)
		g._vert(p + side * hw, nn, col)
	for k in steps:
		var a := base + k * 2
		g.tri(a, a + 1, a + 2)
		g.tri(a + 1, a + 3, a + 2)
	g.line = keep


## 타원 다각형 좌표(눈동자·반사광 원판)
static func _ellipse(rx: float, ry: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(Vector2(cos(a) * rx, sin(a) * ry))
	return out


# ------------------------------------------------------------------ 몸통

## 몸통: 목 피부(머리·조끼 속으로 숨는 고리는 외곽선 0) + 짙은 가죽 조끼·치마 한 장(목 깃 → 넓은 가슴 → 통통한 배 → 퍼지는 치마 → 갈색 단),
## 겉면을 따라가는 비스듬한 앞 끈·X 자 뒤 끈과 놋쇠 징, 둥근 가장자리의 벨트(회전체)와 놋쇠 버클
static func _torso(g: DemonGeo) -> void:
	var neck: Array = [
		{y = 0.67, rx = 0.08, rz = 0.078, bone = "Neck", col = SKIN},
		{y = 0.55, rx = 0.092, rz = 0.088, bone = "Spine", col = SKIN},
	]
	g.lathe(neck, 8, false, false, 0.0, 0.0, func(i: int) -> float: return 0.0 if i == 0 else 1.0)
	var prof: Array = []
	for i in VEST.size():
		var r: Array = VEST[i]
		var y: float = r[0]
		var col := ARMOR
		if i <= 1:
			col = ARMOR_DARK
		elif i >= 11:
			col = STRAP_DARK
		prof.append({y = y, rx = r[1], rz = r[2], bone = "Spine" if y > 0.32 else "Pelvis", col = col})
	g.lathe(prof, 12, false, true)
	# 앞 끈: 왼쪽 어깨 → 오른쪽 허리(비스듬히), 가운데 놋쇠 징
	g.use("Spine")
	_band(g, [Vector2(-0.17, 0.545), Vector2(-0.05, 0.47), Vector2(0.06, 0.41), Vector2(0.15, 0.36)], 0.016, true, 0.004, STRAP)
	var stud: Array = _on_vest(-0.005, 0.44, true, 0.004)
	g.line = 0.3
	g.ellipsoid(stud[0] as Vector3, Vector3(0.02, 0.02, 0.012), BRASS, 6, 3, Basis.looking_at(-(stud[1] as Vector3), Vector3.UP))
	# 뒤 끈: X 자 + 가운데 징
	for side: float in [-1.0, 1.0]:
		_band(g, [Vector2(-0.16 * side, 0.545), Vector2(0.0, 0.445), Vector2(0.16 * side, 0.355)], 0.015, false, 0.004, STRAP)
	var bstud: Array = _on_vest(0.0, 0.445, false, 0.004)
	g.ellipsoid(bstud[0] as Vector3, Vector3(0.018, 0.018, 0.01), BRASS, 6, 3, Basis.looking_at(-(bstud[1] as Vector3), Vector3.UP))
	g.line = 1.0
	# 벨트: 둥근 가장자리의 짙은 가죽 띠(회전체)와 놋쇠 버클
	g.use("Pelvis")
	var belt: Array = [
		{y = 0.362, rx = 0.236, rz = 0.172, bone = "Pelvis", col = STRAP_DARK},
		{y = 0.356, rx = 0.252, rz = 0.186, bone = "Pelvis", col = STRAP_DARK},
		{y = 0.318, rx = 0.254, rz = 0.188, bone = "Pelvis", col = STRAP_DARK},
		{y = 0.311, rx = 0.238, rz = 0.176, bone = "Pelvis", col = STRAP_DARK},
	]
	g.lathe(belt, 12, false, false)
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	g.line = 0.6
	var bz := -0.188 - 0.004
	g.polygon(PackedVector2Array([Vector2(-0.046, 0.026), Vector2(0.046, 0.026), Vector2(0.05, -0.02), Vector2(0.036, -0.03), Vector2(-0.036, -0.03), Vector2(-0.05, -0.02)]),
		Vector3(0, 0.337, bz), fb, 0.01, BRASS, BRASS_DARK)
	g.line = 0.0
	g.polygon(PackedVector2Array([Vector2(-0.024, 0.012), Vector2(0.024, 0.012), Vector2(0.024, -0.016), Vector2(-0.024, -0.016)]),
		Vector3(0, 0.335, bz - 0.007), fb, 0.004, BRASS_DARK)
	g.line = 1.0
	# 치마 판 이음새(앞쪽 짙은 세로 홈 두 줄): 치마 겉면을 따라가는 얇은 띠
	for x: float in [-0.13, 0.13]:
		_band(g, [Vector2(x, 0.3), Vector2(x * 1.06, 0.21)], 0.005, true, 0.002, ARMOR_DARK, 3)


# ------------------------------------------------------------------ 팔다리

## 팔: 어깨 속에서 시작해 굵은 위팔 → 팔꿈치 → 손목 쪽으로 굵어지는 팔뚝 → 가죽 손목 띠(반지름이 부푼 고리)까지 한 관,
## 끝은 왕주먹(조각 구: 손가락 마디 셋·엄지 혹·납작한 바닥) 속에 숨는다. 둥근 어깨 받이는 어깨 위 회전체(짙은 회색 → 갈색 테).
static func _arms(g: DemonGeo) -> void:
	var ar: float = P.arm_r
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := float(P.shoulder_x) * side
		var nodes: Array = [
			{p = Vector3(x * 0.72, 0.53, 0.0), r = 0.062, bone = "Arm" + sfx, col = SKIN, line = 0.0},
			{p = Vector3(x * 1.0, 0.535, 0.0), r = 0.07, bone = "Arm" + sfx, col = SKIN, line = 0.0},
			{p = Vector3(x * 1.04, 0.455, 0.0), r = 0.063, bone = "Arm" + sfx, col = SKIN},
			{p = Vector3(x * 1.04, 0.425, 0.0), r = 0.06, bone = "Forearm" + sfx, col = SKIN},
			{p = Vector3(x * 1.04, 0.395, 0.0), r = 0.066, bone = "Forearm" + sfx, col = SKIN},
			{p = Vector3(x * 1.045, 0.37, 0.0), r = 0.073, bone = "Forearm" + sfx, col = SKIN},
			{p = Vector3(x * 1.045, 0.36, 0.0), r = 0.08, bone = "Forearm" + sfx, col = STRAP},
			{p = Vector3(x * 1.045, 0.335, 0.0), r = 0.082, bone = "Forearm" + sfx, col = STRAP},
			{p = Vector3(x * 1.045, 0.318, 0.0), r = 0.074, bone = "Hand" + sfx, col = SKIN},
			{p = Vector3(x * 1.045, 0.29, -0.01), r = 0.068, bone = "Hand" + sfx, col = SKIN, line = 0.0},
		]
		g.limb(nodes, 8, Vector3.FORWARD, false, false)
		# 왕주먹(조각 구): 앞 아래쪽에 손가락 마디 혹 셋, 안쪽 앞에 엄지, 바닥은 조금 납작
		g.use("Hand" + sfx)
		var fc := Vector3(x + side * 0.012, float(P.wrist) - ar * 1.15, -0.04)
		var knuck: Array = []
		for k in 3:
			knuck.append(Vector3((float(k) - 1.0) * 0.42, -0.28, -0.86).normalized())
		var thumb := Vector3(-side * 0.82, 0.05, -0.57).normalized()
		var fshape := func(d: Vector3) -> float:
			var k := 1.0
			for kd: Vector3 in knuck:
				k += 0.2 * DemonGeo.bump(d, kd, 0.17)
			k += 0.22 * DemonGeo.bump(d, thumb, 0.26)
			k -= 0.08 * DemonGeo.bump(d, Vector3.DOWN, 0.5)
			k -= 0.05 * DemonGeo.bump(d, Vector3(side, 0.0, 0.3).normalized(), 0.6)
			return k
		var fcol := func(d: Vector3, _p: Vector3) -> Color:
			# 손가락 사이 홈은 조금 어둡게(앞 아래쪽, 마디 사이)
			var groove := 0.0
			for k in 2:
				groove = maxf(groove, DemonGeo.bump(d, Vector3((float(k) - 0.5) * 0.42, -0.3, -0.86).normalized(), 0.09))
			groove = maxf(groove, DemonGeo.bump(d, Vector3(-side * 0.55, -0.1, -0.78).normalized(), 0.07) * 0.8)
			return SKIN.lerp(SKIN_DARK.darkened(0.15), clampf(groove, 0.0, 1.0))
		g.sculpt(fc, Vector3(ar * 1.82, ar * 1.72, ar * 1.85), SKIN, 10, 7, fshape, fcol)
		# 어깨 받이(가죽 회전체: 밝은 꼭대기 → 둥근 지붕 → 짙은 아래 테). 안쪽 반은 가슴 속에 묻히고 아래는 팔 위로 늘어진다.
		# 가슴 속에 들어가는 아래 고리는 외곽선 0(받이와 가슴 사이에 이음새 테가 생기지 않는다). 팔 뼈에 붙는다
		g.use("Arm" + sfx)
		var pc := Vector3(x - 0.004 * side, 0.0, 0.0)
		var pad: Array = [
			{y = 0.665, rx = 0.012, rz = 0.011, bone = "Arm" + sfx, col = PAD_LIGHT},
			{y = 0.64, rx = 0.095, rz = 0.085, bone = "Arm" + sfx, col = PAD},
			{y = 0.61, rx = 0.12, rz = 0.106, bone = "Arm" + sfx, col = PAD},
			{y = 0.578, rx = 0.134, rz = 0.118, bone = "Arm" + sfx, col = PAD},
			{y = 0.557, rx = 0.142, rz = 0.125, bone = "Arm" + sfx, col = PAD_RIM},
			{y = 0.53, rx = 0.145, rz = 0.127, bone = "Arm" + sfx, col = PAD_RIM},
			{y = 0.506, rx = 0.136, rz = 0.119, bone = "Arm" + sfx, col = PAD_RIM},
		]
		g.lathe(pad, 10, true, false, pc.x, pc.z, func(i: int) -> float: return 0.0 if i >= 5 else 1.0)
		# 놋쇠 징(어깨 받이 꼭대기 바깥)
		g.line = 0.3
		g.ellipsoid(Vector3(pc.x + 0.05 * side, 0.648, 0.0), Vector3(0.017, 0.012, 0.017), BRASS, 6, 2, Basis(Vector3.BACK, -side * 0.45))
		g.line = 1.0


## 다리: 치마 속에서 시작하는 굵은 갈색 바지 → 무릎 아래 장화 목(테가 부푼 고리)까지 한 관, 장화 발은 바닥이 납작한 조각 구(앞코는 밝은 갈색)
static func _legs(g: DemonGeo) -> void:
	var fl: float = P.foot_len
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var lx := float(P.hip_x) * side
		var nodes: Array = [
			{p = Vector3(lx, 0.31, 0.0), r = 0.086, bone = "Leg" + sfx, col = TROUSER, line = 0.0},
			{p = Vector3(lx, 0.2, 0.0), r = 0.078, bone = "Leg" + sfx, col = TROUSER},
			{p = Vector3(lx, 0.168, 0.0), r = 0.074, bone = "Shin" + sfx, col = TROUSER},
			{p = Vector3(lx, 0.158, 0.0), r = 0.083, bone = "Shin" + sfx, col = BOOT_TOE},
			{p = Vector3(lx, 0.14, 0.0), r = 0.083, bone = "Shin" + sfx, col = BOOT_TOE},
			{p = Vector3(lx, 0.132, 0.0), r = 0.075, bone = "Shin" + sfx, col = BOOT},
			{p = Vector3(lx, 0.1, 0.0), r = 0.073, bone = "Shin" + sfx, col = BOOT},
			{p = Vector3(lx, 0.075, 0.0), r = 0.074, bone = "Foot" + sfx, col = BOOT, line = 0.0},
		]
		g.limb(nodes, 8, Vector3.FORWARD, false, false)
		g.use("Foot" + sfx)
		var ce := Vector3(lx, 0.0525, -fl * 0.2)
		var rr := Vector3(0.088, 0.075, fl * 0.52)
		var shape := func(d: Vector3) -> float:
			# 바닥은 납작(y = -0.7 r 에서 잘린 평면), 앞코는 조금 둥글게 부푼다
			var k := 1.0 + 0.06 * DemonGeo.bump(d, Vector3(0, 0.3, -1).normalized(), 0.5)
			if d.y < -0.7:
				k = minf(k, 0.7 / -d.y)
			return k
		var col_of := func(d: Vector3, _p: Vector3) -> Color:
			if d.y < -0.66:
				return BOOT.darkened(0.35)
			return BOOT.lerp(BOOT_TOE, clampf((-d.z - 0.55) * 2.2, 0.0, 1.0))
		g.sculpt(ce, rr, BOOT, 8, 6, shape, col_of)


# ------------------------------------------------------------------ 머리

## 머리 조각 함수(방향 → 반지름 배수): 넓은 아래턱과 주걱턱, 앞으로 나온 주둥이와 둥근 코, 굵은 눈썹 능선, 눈두덩 패임, 조금 납작한 정수리
static func _shape(d: Vector3) -> float:
	var k := 1.0
	for side: float in [-1.0, 1.0]:
		k += 0.13 * DemonGeo.bump(d, Vector3(0.75 * side, -0.48, -0.45).normalized(), 0.42)
		k -= 0.075 * DemonGeo.bump(d, Vector3(EYE_DX * side, EYE_DY, -0.9).normalized(), 0.2)
		k += 0.06 * DemonGeo.bump(d, Vector3(0.36 * side, 0.36, -0.86).normalized(), 0.2)
		k += 0.025 * DemonGeo.bump(d, Vector3(0.13 * side, -0.14, -1.0).normalized(), 0.09)
	k += 0.11 * DemonGeo.bump(d, Vector3(0, -0.6, -0.8).normalized(), 0.32)
	k += 0.05 * DemonGeo.bump(d, Vector3(0, -0.3, -1.0).normalized(), 0.4)
	k += 0.2 * DemonGeo.bump(d, Vector3(0, -0.1, -1.0).normalized(), 0.14)
	k += 0.025 * DemonGeo.bump(d, Vector3(0, 0.3, -1.0).normalized(), 0.18)
	k -= 0.05 * DemonGeo.bump(d, Vector3.UP, 0.45)
	return k


## 머리 겉면 위의 점(방향 d, 배수 k = 1 이면 겉면)
static func _hs(d: Vector3, k: float = 1.0) -> Vector3:
	var dn := d.normalized()
	return HC + Vector3(dn.x * HR.x, dn.y * HR.y, dn.z * HR.z) * (_shape(dn) * k)


static func _head(g: DemonGeo) -> void:
	g.use("Head")
	var col_of := func(d: Vector3, _p: Vector3) -> Color:
		var c := SKIN
		# 주둥이·코는 조금 밝게, 눈두덩은 조금 어둡게
		c = c.lerp(SKIN_LIGHT, clampf(DemonGeo.bump(d, Vector3(0, -0.06, -1).normalized(), 0.13) * 1.1, 0.0, 1.0))
		var sock := maxf(DemonGeo.bump(d, Vector3(-EYE_DX, EYE_DY, -0.9).normalized(), 0.16), DemonGeo.bump(d, Vector3(EYE_DX, EYE_DY, -0.9).normalized(), 0.16))
		return c.lerp(SKIN_DARK, clampf(sock * 0.7, 0.0, 1.0))
	g.sculpt(HC, HR, SKIN, 18, 12, func(d: Vector3) -> float: return _shape(d), col_of)
	# 콧구멍: 둥근 코 아래쪽 양옆의 짙은 작은 타원 판(외곽선 없음)
	g.line = 0.0
	for side: float in [-1.0, 1.0]:
		var nd := Vector3(0.075 * side, -0.17, -1.0).normalized()
		g.polygon(_ellipse(0.011, 0.008, 6), _hs(nd, 1.0) + nd * 0.002, Basis.looking_at(nd, Vector3.UP) * Basis(Vector3.BACK, side * 0.4), 0.0, MOUTH)
	g.line = 1.0
	_face(g)
	_tusks(g)
	_ears(g)
	_mohawk(g)


## 엄니: 아래턱 속 깊이(아랫입술 아래)에서 뿌리가 시작해 겉면 법선 방향으로 나와 바깥쪽으로 20° 벌어지며 위로 길게 솟고, 끝만 살짝 안으로 휜다
## (턱에서 자라는 느낌, 게임 화면에서도 읽히게 크게)
static func _tusks(g: DemonGeo) -> void:
	g.use("Head")
	var keep := g.line
	for side: float in [-1.0, 1.0]:
		var d := Vector3(0.4 * side, -0.62, -0.7).normalized()
		var p0 := _hs(d, 0.76)
		var p1 := _hs(d, 1.04)
		var p2 := p1 + Vector3(0.03 * side, 0.072, -0.024)
		var p3 := p1 + Vector3(0.036 * side, 0.138, -0.012)
		var nodes: Array = []
		var n := 5
		for i in n + 1:
			var t := float(i) / float(n)
			var r := 0.04 * (1.0 - pow(t, 1.7))
			if i == n:
				r = 0.0
			nodes.append({p = DemonGeo.bez(p0, p1, p2, p3, t), r = r, bone = "Head", col = TUSK, line = 0.0 if i < 2 else 0.5})
		g.limb(nodes, 6, Vector3.BACK, false, false)
	g.line = keep


## 옆으로 뻗은 뾰족 귀(두께가 있는 잎: 뿌리는 머리 속, 끝으로 갈수록 위·뒤로 말린다), 앞면에 짙은 초록 안쪽 귀. EarL/EarR 뼈(2차 움직임)
static func _ears(g: DemonGeo) -> void:
	g.measure = false
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var base := Vector3(0.165 * side, 0.8, 0.0)
		g.add_bone("Ear" + sfx, "Head", base)
		g.use("Ear" + sfx)
		var dir := Vector3(side, 0.46, -0.1).normalized()
		var L := 0.2
		var pts: Array = []
		var radii: Array = []
		var prof: Array = [0.055, 0.068, 0.062, 0.046, 0.024, 0.0]
		for i in 6:
			var t := float(i) / 5.0
			pts.append(base + dir * (L * t) + Vector3(0, 0.07 * t * t, 0.045 * t * t))
			radii.append(prof[i])
		g.spline_tube(pts, radii, SKIN, 6, false, false, Vector3.UP, 1.0, 0.52)
		# 안쪽 귀: 귀 앞면에 얇게 붙은 짙은 잎(외곽선 없음)
		var inner: Array = []
		var inner_r: Array = []
		for i in range(1, 6):
			var t := float(i) / 5.0
			inner.append((pts[i] as Vector3) + Vector3(0, -0.004, -0.02) + dir * 0.008)
			inner_r.append(float(prof[i]) * 0.55)
		var keep := g.line
		g.line = 0.0
		g.spline_tube(inner, inner_r, EAR_IN, 4, false, false, Vector3.UP, 1.0, 0.3)
		g.line = keep
	g.measure = true
	g.use("Head")


## 붉은 모히칸: 정수리 가운데 줄(이마 위 → 뒤통수, 머리 앞뒤 길이의 60%)을 따라가는 한 장의 쐐기 지느러미. 행 = 앞→뒤, 열 = 왼쪽 뿌리 → 꼭대기 → 오른쪽 뿌리.
## 뿌리는 두피 속에 묻히고, 윗날은 크고 뾰족한 볏 셋(높이 ≈ 머리 높이의 절반, 뒤로 쓸려 앞 볏의 끝이 뒷 볏의 뿌리 위에 겹친다,
## 번갈아 좌우로 아주 조금 기울어 정면에서도 끝이 보인다). 색은 뿌리 주황빛 갈색 → 붉은색 → 끝 밝은 주황.
static func _mohawk(g: DemonGeo) -> void:
	g.measure = false
	g.use("Head")
	var S := 15
	var N := 4
	var spikes := 3.0
	var pts: Array = []
	var tcol: Array = []
	for i in S + 1:
		var s := float(i) / float(S)
		var phi := lerpf(-0.6, 0.68, s)                  # 앞(-Z) → 뒤(+Z)
		var d := Vector3(0, cos(phi), sin(phi))
		var root := _hs(d, 0.955)
		var env := pow(sin(PI * s), 0.3)
		var saw := 1.0 - absf(fposmod(s * spikes, 1.0) - 0.5) * 2.0    # 볏 꼭대기에서 1
		var hgt := 0.26 * env * (0.3 + 0.7 * pow(saw, 1.2)) * (1.0 + 0.12 * (1.0 - s))
		var wid := 0.095 * pow(sin(PI * s), 0.4) + 0.004
		var fdir := (d * 0.55 + Vector3.UP * 0.6 + Vector3.BACK * (0.42 + 0.22 * s)).normalized()
		var spike_i := int(floor(s * spikes))
		var sway := (0.05 if spike_i % 2 == 0 else -0.05) * saw
		var row: Array = []
		var crow: Array = []
		for j in 2 * N + 1:
			var t := 1.0 - absf(float(j - N)) / float(N)
			var sd := signf(float(j - N))
			var x := sd * wid * pow(1.0 - t, 0.75)
			var p := root + fdir * (hgt * t) + Vector3(x + sway * t * t, 0.0, 0.09 * hgt * t * t / 0.2)
			row.append(p)
			crow.append(t)
		pts.append(row)
		tcol.append(crow)
	var col_of := func(i: int, j: int) -> Color:
		var t: float = (tcol[i] as Array)[j]
		var c := ROOT.lerp(MOHAWK, smoothstep(0.06, 0.32, t))
		return c.lerp(MOHAWK_HI, smoothstep(0.72, 1.0, t) * 0.55)
	_grid(g, pts, col_of, false, HC)
	g.measure = true


# ------------------------------------------------------------------ 얼굴

## 눈: 눈두덩 속 작은 크림색 눈알(앞면만 조금 나옴) + 둥근 짙은 눈동자·작은 반사광 + 눈알 윗부분을 덮는 짙은 뚜껑(눈 뼈),
## 윗눈꺼풀(피부색 반구, 표정·깜빡임), 굵고 끝이 가는 짙은 눈썹(안쪽이 내려가 기본이 사나운 얼굴).
## 입: 보통 = 짙은 찡그림 띠와 윗니 넷, 화남 = 크게 벌린 입과 위·아래 이, 아픔 = 작은 ○. 뼈 이름은 CharacterRig 표정 규약 그대로.
static func _face(g: DemonGeo) -> void:
	var es := ES
	var keep_line := g.line
	g.line = 0.0
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var d := Vector3(EYE_DX * side, EYE_DY, -0.9).normalized()
		var ec := _hs(d, 1.0) - d * (es * 0.6)
		var ebt := Basis.looking_at(d, Vector3.UP) * Basis(Vector3.BACK, side * 0.12)
		# 감은 눈 선(◡): 눈두덩 겉면에 붙어 눈알 뒤에 숨어 있다가 눈알이 눌리면(깜빡임·기절) 보인다
		g.use("Head")
		var lash: Array = []
		for i in 5:
			var u := float(i) / 2.0 - 1.0
			lash.append(_hs(d + Vector3(u * 0.17, -0.04 - 0.035 * (1.0 - u * u), 0.0), 0.995))
		g.spline_tube(lash, [0.0, 0.0045, 0.005, 0.0045, 0.0], LASH, 4, false, false)
		var er := Vector3(es * 1.15, es * 0.98, es * 0.9)
		g.add_bone("Eye" + sfx, "Head", ec)
		g.use("Eye" + sfx)
		g.ellipsoid(ec, er, SCLERA, 12, 6, ebt)
		# 눈알 윗부분을 덮는 짙은 뚜껑(눈알보다 아주 조금 크다)
		g.ellipsoid(ec, er * 1.03, LASH, 12, 2, ebt, PI * 0.33, PI * 0.33, 0.0)
		var pd := Vector3(-side * 0.08, -0.06, -1.0).normalized()
		var pc := ec + ebt * (Vector3(pd.x * er.x, pd.y * er.y, pd.z * er.z) * 0.99)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		# 눈동자·반사광: 눈알 앞면에 바로 붙인 얇은 원판(둥근 테두리가 매끈하다)
		g.polygon(_ellipse(es * 0.42, es * 0.48, 14), pc + d * 0.005, ebt, 0.0, PUPIL)
		g.polygon(_ellipse(es * 0.13, es * 0.13, 6), pc + ebt * Vector3(side * es * 0.16, es * 0.2, 0.0) + d * 0.006, ebt, 0.0, Color.WHITE)
		# 윗눈꺼풀(피부색 반구 덮개, 눈 위 피벗): 표정이 Y 크기를 키우면 내려와 덮는다
		var lid_p := ec + ebt * Vector3(0, es * 0.95, 0)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.3, es * 2.2, es * 1.0), SKIN.darkened(0.05), 6, 3, ebt * Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹: 눈썹 능선 위 굵은 띠, 바깥 끝이 올라가고 안쪽 끝은 코 쪽으로 내려간다. 양 끝은 가늘어져 겉면 속으로 들어간다
		var bp := _hs(Vector3(EYE_DX * side, 0.33, -0.86), 1.0)
		g.add_bone("Brow" + sfx, "Head", bp)
		g.use("Brow" + sfx)
		var pi_ := _hs(Vector3(0.1 * side, 0.17, -0.97), 0.975)
		var pin := _hs(Vector3(0.24 * side, 0.22, -0.93), 1.0)
		var pout := _hs(Vector3(0.6 * side, 0.38, -0.68), 1.0)
		var po := _hs(Vector3(0.72 * side, 0.4, -0.54), 0.975)
		g.spline_tube([pi_, pin, bp, pout, po], [0.0, es * 0.36, es * 0.42, es * 0.32, 0.0], BROW, 6, false, false, Vector3.RIGHT, 0.55, 1.0)
	# 입
	var md := Vector3(0, -0.4, -0.92).normalized()
	var mp := _hs(md, 1.0)
	var mw := 0.17
	g.add_bone("MouthN", "Head", mp)
	g.use("MouthN")
	var band: Array = []
	var br: Array = []
	for i in 7:
		var u := float(i) / 3.0 - 1.0
		var dd := Vector3(u * 0.4, -0.4 - 0.07 * u * u, -0.92)
		band.append(_hs(dd, 0.995))
		br.append(0.0 if absf(u) > 0.99 else 0.0135 * (1.0 - 0.45 * u * u))
	g.spline_tube(band, br, MOUTH, 6, false, false, Vector3.RIGHT, 0.6, 1.0)
	for k in 4:
		var u := (float(k) - 1.5) * 0.22
		var tp := _hs(Vector3(u * 0.4, -0.38, -0.92), 1.004)
		g.box(tp, Vector3(0.019, 0.017, 0.01), TEETH, Basis.looking_at(md, Vector3.UP))
	g.add_bone("MouthA", "Head", mp)
	g.use("MouthA")
	var mb := Basis.looking_at(md, Vector3.UP)
	g.ellipsoid(mp + md * 0.012 + Vector3(0, -0.012, 0), Vector3(mw * 0.44, mw * 0.22, 0.03), MOUTH, 8, 4, mb)
	for k in 4:
		var u := (float(k) - 1.5) * 0.24
		g.box(_hs(Vector3(u * 0.4, -0.355, -0.92), 1.012), Vector3(0.02, 0.018, 0.01), TEETH, mb)
	for k in 2:
		var u := (float(k) - 0.5) * 0.55
		g.box(_hs(Vector3(u * 0.4, -0.5, -0.86), 1.01), Vector3(0.016, 0.02, 0.01), TEETH, mb)
	g.add_bone("MouthH", "Head", mp)
	g.use("MouthH")
	g.ellipsoid(mp + md * 0.008 + Vector3(0, -0.006, 0), Vector3(mw * 0.15, mw * 0.14, 0.02), MOUTH, 8, 3, mb)
	g.use("Head")
	g.line = keep_line


# ------------------------------------------------------------------ 몽둥이

## 길고 굵은 옹이 몽둥이(오른손): 손잡이는 주먹 아래로 앞쪽 50°·바깥쪽으로 조금 기울어 쥔다(v5 와 같은 축).
## 축을 따라 고리마다 반지름이 바뀌는 관 한 장: 끝 마디 → 가죽 감은 손잡이 → 부푸는 머리. 옹이 혹은 반지름을 부풀린 자리(어두운 색)라
## 따로 붙인 공이 아니고, 머리 둘레의 놋쇠 징 네 개만 겉면에 박힌 짧은 원뿔. 돌려주는 값 = 몽둥이 머리(def.tip)
static func _club(g: DemonGeo, hand: Vector3) -> Vector3:
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var gr := deg_to_rad(50.0)
	var d := Vector3(0.28, -cos(gr), -sin(gr)).normalized()
	var u := Vector3.RIGHT
	u = (u - d * u.dot(d)).normalized()
	var w := d.cross(u).normalized()
	var dist: Array = [-0.11, -0.095, -0.075, -0.05, 0.0, 0.05, 0.12, 0.2, 0.26, 0.31, 0.36, 0.41, 0.46, 0.51, 0.55, 0.585, 0.612, 0.628]
	var rads: Array = [0.0, 0.03, 0.04, 0.036, 0.035, 0.036, 0.033, 0.042, 0.055, 0.069, 0.087, 0.101, 0.107, 0.1, 0.082, 0.056, 0.03, 0.0]
	var knots: Array = []
	for k in 6:
		knots.append(Vector2(0.37 + 0.045 * float(k % 3) + 0.03 * sin(float(k) * 2.3), TAU * float(k) / 6.0 + 0.4))
	var segs := 8
	var pts: Array = []
	var knot_t: Array = []
	for i in dist.size():
		var s: float = dist[i]
		var r0: float = rads[i]
		var row: Array = []
		var krow: Array = []
		for j in segs:
			var a := TAU * float(j) / float(segs)
			var kk := 0.0
			for kn: Vector2 in knots:
				var da := wrapf(a - kn.y, -PI, PI)
				kk = maxf(kk, exp(-(pow(s - kn.x, 2.0) / (2.0 * 0.028 * 0.028) + da * da / (2.0 * 0.32 * 0.32))))
			var r := r0 * (1.0 + 0.28 * kk)
			row.append(hand + d * s + (u * cos(a) + w * sin(a)) * r)
			krow.append(kk)
		pts.append(row)
		knot_t.append(krow)
	var col_of := func(i: int, j: int) -> Color:
		var s: float = dist[i]
		if s < -0.07:
			return CLUB_DARK
		if s > -0.05 and s < 0.05:
			return STRAP_DARK if (i % 2 == 0) else STRAP_DARK.lightened(0.12)
		var c := CLUB
		if s > 0.24 and s < 0.27:
			c = CLUB_LIGHT
		var kk: float = (knot_t[i] as Array)[j]
		return c.lerp(CLUB_DARK, clampf(kk * 1.1, 0.0, 1.0))
	_grid(g, pts, col_of, true, hand + d * 0.3)
	# 놋쇠 징: 머리 겉면에 뿌리가 박힌 짧은 원뿔 넷
	g.line = 0.4
	for k in 4:
		var a := TAU * float(k) / 4.0 + 1.2
		var s := 0.46 + 0.04 * cos(float(k) * 1.7)
		var rd := (u * cos(a) + w * sin(a))
		var b0 := hand + d * s + rd * 0.09
		g.spline_tube([b0, b0 + rd * 0.022, b0 + rd * 0.04], [0.02, 0.016, 0.0], BRASS, 6, false, false)
	g.line = 1.0
	g.measure = true
	g.measure_all = true
	return hand + d * 0.5
