class_name SkeletonV6Builder
extends RefCounted
## 6차 교체 후보(해골 궁수). 5차 디자인(SkeletonBuilder)을 그대로 두고 조립한 기본 도형 대신 이어지는 곡면으로 다시 만든다.
## 해골 = 조각 구 한 장(둥근 머리통 → 광대뼈 → 좁아지는 턱, 크게 파인 눈구멍·코 구멍 자리, 눈구멍 안쪽은 정점 색으로 새까맣게),
## 붉은 빛점은 눈구멍 바닥에 앉고, 눈두덩 능선은 끝이 가는 짙은 띠. 이빨 줄은 입 뼈(표정)로 바뀐다.
## 두건 = 머리통을 바짝 감싸는 한 장의 껍데기(앞 구멍 가장자리가 두툼하게 안으로 말린 밝은 단이 같은 면에 이어지고, 정수리 뒤 뾰족한 꼭지도
## 같은 면을 부풀려 만든다. 모두 Head 뼈), 어깨 덮개·로브는 회전체(밑단은 너덜너덜한 톱니), 등 망토(Cape 뼈), 가는 뼈 팔다리는 이어진 관
## (팔꿈치·무릎은 고리 반지름을 부풀린 마디, 팔 보호대·장화는 고리 색), 왼손의 큰 활(def.tip = 활 쥔 손)과 등의 화살통.
## 기본 키 HEIGHT 1.15(게임에서 0.95 배).

const BONE := Color("faf5e8")
const BONE_DARK := Color("e4dcc6")
const BONE_SHADE := Color("cfc5aa")
const RIDGE := Color("6e6252")
const SOCKET := Color("0d0a10")
const EYE := Color("ff4a44")
const EYE_CORE := Color("ffd0b0")
const HOOD := Color("5c4b78")
const HOOD_DARK := Color("3f3254")
const HOOD_EDGE := Color("72608f")
const ROBE := Color("4d3e66")
const ROBE_FOLD := Color("40335a")
const GOLD := Color("e8b852")
const GOLD_DARK := Color("ad8430")
const LEATHER := Color("6b3f1f")
const LEATHER_LIGHT := Color("925c2c")
const BOOT := Color("6b4a2a")
const BOOT_CUFF := Color("8a6238")
const BOW := Color("d8a048")
const BOW_DARK := Color("8f5a2b")
const STRING := Color("f0e8d8")
const FLETCH := Color("c8343a")
const FLETCH2 := Color("f4efe4")
const MOUTH := Color("1a1218")

const P := {
	ankle = 0.075, knee = 0.235, hip = 0.4, hip_x = 0.07, pelvis = 0.415, spine = 0.47,
	shoulder = 0.665, shoulder_x = 0.165, elbow = 0.535, wrist = 0.415, neck = 0.7, head = 0.745,
	arm_r = 0.028, leg_r = 0.032, foot_len = 0.17,
}
const HC := Vector3(0, 0.95, -0.005)       # 머리통 중심
const HR := Vector3(0.212, 0.198, 0.205)   # 머리통 반지름(조각 전)
const ES := 0.06                            # 눈구멍 크기
const EYE_DX := 0.42
const EYE_DY := 0.03


static func build() -> Dictionary:
	var g := DemonGeo.new()
	g.bake = 0.0
	CharGeo.skeleton(g, P)
	_torso(g)
	_limbs(g)
	_cape(g)
	_head(g)
	_quiver(g)
	var hl := Vector3(-float(P.shoulder_x), float(P.wrist) - float(P.arm_r) * 1.0, -0.02)
	_bow(g, hl)
	var def := g.build(CharacterRig.character_material())
	def.tip = hl
	def.H = 1.15
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


## 회전체인데 고리마다 밑단 톱니(hem 가중치 × 톱니 함수)를 줄 수 있다. prof = [{y, rx, rz, bone, col, [hem], [line]}] 위→아래
static func _lathe_hem(g: DemonGeo, prof: Array, segs: int, teeth: int, depth: float, phase: float = 0.0) -> void:
	var pts: Array = []
	var bones: Array = []
	var lines: Array = []
	var cols: Array = []
	for Pr: Dictionary in prof:
		var row: Array = []
		var hem: float = Pr.get("hem", 0.0)
		for j in segs:
			var a := TAU * float(j) / float(segs)
			# 톱니: 삼각파(뾰족한 끝이 아래로), 이빨마다 깊이가 조금씩 다르다
			var f := fposmod(a / TAU * float(teeth) + phase, 1.0)
			var tri_w := 1.0 - absf(f - 0.5) * 2.0
			var idx := int(floor(a / TAU * float(teeth) + phase))
			var var_d := 0.75 + 0.25 * sin(float(idx) * 2.7)
			var dy := -depth * tri_w * var_d * hem
			row.append(Vector3(cos(a) * float(Pr.rx), float(Pr.y) + dy, sin(a) * float(Pr.rz)))
		pts.append(row)
		bones.append(Pr.bone)
		lines.append(Pr.get("line", 1.0))
		cols.append(Pr.col)
	var y0: float = (prof[0] as Dictionary).y
	_grid(g, pts, func(i: int, _j: int) -> Color: return cols[i], true, Vector3(0, y0 - 0.05, 0), bones, lines)


## 타원 다각형 좌표(빛점 심·버클)
static func _ellipse(rx: float, ry: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(Vector2(cos(a) * rx, sin(a) * ry))
	return out


# ------------------------------------------------------------------ 몸통

## 몸통: 가슴을 덮는 자색 로브(회전체: 가슴 → 허리 → 퍼지는 치마, 밑단은 너덜너덜한 톱니), 어깨를 덮는 망토 깃(회전체, 아랫단 톱니),
## 둥근 가장자리의 가죽 벨트와 놋쇠 버클, 깃의 작은 금 브로치, 목뼈
static func _torso(g: DemonGeo) -> void:
	var robe: Array = [
		{y = 0.68, rx = 0.1, rz = 0.085, bone = "Spine", col = ROBE, line = 0.0},
		{y = 0.62, rx = 0.128, rz = 0.105, bone = "Spine", col = ROBE},
		{y = 0.56, rx = 0.13, rz = 0.106, bone = "Spine", col = ROBE},
		{y = 0.5, rx = 0.12, rz = 0.1, bone = "Spine", col = ROBE},
		{y = 0.45, rx = 0.112, rz = 0.095, bone = "Pelvis", col = ROBE},
		{y = 0.4, rx = 0.122, rz = 0.104, bone = "Pelvis", col = ROBE},
		{y = 0.35, rx = 0.142, rz = 0.122, bone = "Pelvis", col = ROBE, hem = 0.3},
		{y = 0.31, rx = 0.156, rz = 0.134, bone = "Pelvis", col = ROBE_FOLD, hem = 1.0},
	]
	_lathe_hem(g, robe, 16, 8, 0.05)
	# 망토 깃(어깨 덮개): 두건 밑단 속(목)에서 시작해 어깨를 둥글게 덮고, 아랫단은 넓은 톱니
	var mantle: Array = [
		{y = 0.765, rx = 0.085, rz = 0.08, bone = "Spine", col = HOOD, line = 0.0},
		{y = 0.71, rx = 0.13, rz = 0.115, bone = "Spine", col = HOOD},
		{y = 0.68, rx = 0.195, rz = 0.155, bone = "Spine", col = HOOD},
		{y = 0.645, rx = 0.222, rz = 0.172, bone = "Spine", col = HOOD},
		{y = 0.61, rx = 0.228, rz = 0.178, bone = "Spine", col = HOOD_EDGE, hem = 0.7},
		{y = 0.6, rx = 0.226, rz = 0.176, bone = "Spine", col = HOOD_EDGE, hem = 1.0},
	]
	_lathe_hem(g, mantle, 18, 6, 0.045, 0.5)
	# 깃 앞 금 브로치(마름모)
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	g.use("Spine")
	g.line = 0.4
	g.polygon(PackedVector2Array([Vector2(0, 0.024), Vector2(0.02, 0), Vector2(0, -0.024), Vector2(-0.02, 0)]), Vector3(0, 0.69, -0.142), Basis(Vector3.RIGHT, -0.5) * fb, 0.008, GOLD, GOLD_DARK)
	# 벨트(둥근 가장자리 회전체)와 놋쇠 버클
	g.line = 1.0
	var belt: Array = [
		{y = 0.448, rx = 0.112, rz = 0.095, bone = "Pelvis", col = LEATHER},
		{y = 0.443, rx = 0.124, rz = 0.106, bone = "Pelvis", col = LEATHER},
		{y = 0.408, rx = 0.13, rz = 0.111, bone = "Pelvis", col = LEATHER},
		{y = 0.402, rx = 0.12, rz = 0.104, bone = "Pelvis", col = LEATHER},
	]
	g.lathe(belt, 14, false, false)
	g.use("Pelvis")
	g.line = 0.5
	g.polygon(PackedVector2Array([Vector2(-0.028, 0.02), Vector2(0.028, 0.02), Vector2(0.028, -0.02), Vector2(-0.028, -0.02)]), Vector3(0, 0.425, -0.112), fb, 0.008, GOLD, GOLD_DARK)
	g.line = 0.0
	g.polygon(_ellipse(0.011, 0.009, 6), Vector3(0, 0.425, -0.118), fb, 0.0, GOLD_DARK)
	g.line = 1.0


# ------------------------------------------------------------------ 팔다리

## 가는 뼈 팔다리: 어깨 속에서 손끝까지 이어진 관(팔꿈치는 부푼 마디, 아래팔 아래쪽 절반은 갈색 가죽 팔 보호대 고리),
## 세 손가락 뼈(짧은 관). 다리는 치마 속에서 장화까지 한 관(무릎 마디, 장화 목의 접힌 단 = 부푼 고리), 장화 발은 바닥이 납작한 조각 구
static func _limbs(g: DemonGeo) -> void:
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := float(P.shoulder_x) * side
		var arm: Array = [
			{p = Vector3(x * 0.7, 0.662, 0.0), r = 0.03, bone = "Arm" + sfx, col = BONE, line = 0.0},
			{p = Vector3(x * 1.0, 0.662, 0.0), r = 0.036, bone = "Arm" + sfx, col = BONE, line = 0.0},
			{p = Vector3(x * 1.02, 0.63, 0.0), r = 0.024, bone = "Arm" + sfx, col = BONE},
			{p = Vector3(x * 1.03, 0.58, 0.0), r = 0.02, bone = "Arm" + sfx, col = BONE},
			{p = Vector3(x * 1.03, 0.548, 0.0), r = 0.029, bone = "Forearm" + sfx, col = BONE},
			{p = Vector3(x * 1.03, 0.52, 0.0), r = 0.021, bone = "Forearm" + sfx, col = BONE},
			{p = Vector3(x * 1.03, 0.5, 0.0), r = 0.031, bone = "Forearm" + sfx, col = LEATHER_LIGHT},
			{p = Vector3(x * 1.03, 0.445, 0.0), r = 0.035, bone = "Forearm" + sfx, col = LEATHER_LIGHT},
			{p = Vector3(x * 1.03, 0.432, 0.0), r = 0.035, bone = "Forearm" + sfx, col = LEATHER},
			{p = Vector3(x * 1.03, 0.424, 0.0), r = 0.02, bone = "Hand" + sfx, col = BONE},
			{p = Vector3(x * 1.03, 0.4, -0.006), r = 0.028, bone = "Hand" + sfx, col = BONE},
			{p = Vector3(x * 1.03, 0.38, -0.012), r = 0.028, bone = "Hand" + sfx, col = BONE},
		]
		g.limb(arm, 8, Vector3.FORWARD, false, true, 2)
		# 세 손가락 뼈 + 엄지(손바닥 속에서 앞·아래로 굽는다)
		g.use("Hand" + sfx)
		var hc := Vector3(x * 1.03, 0.385, -0.012)
		var keep := g.line
		g.line = 0.5
		for k in 3:
			var fx := (float(k) - 1.0) * 0.016
			var b0 := hc + Vector3(fx, -0.006, -0.012)
			g.spline_tube([b0, b0 + Vector3(fx * 0.2, -0.022, -0.012), b0 + Vector3(fx * 0.3, -0.038, 0.0)], [0.009, 0.008, 0.006], BONE, 4, false, true)
		var tb := hc + Vector3(-side * 0.02, 0.004, -0.012)
		g.spline_tube([tb, tb + Vector3(-side * 0.008, -0.01, -0.018)], [0.009, 0.007], BONE, 4, false, true)
		g.line = keep
		# 다리
		var lx := float(P.hip_x) * side
		var leg: Array = [
			{p = Vector3(lx, 0.44, 0.0), r = 0.03, bone = "Leg" + sfx, col = BONE, line = 0.0},
			{p = Vector3(lx, 0.39, 0.0), r = 0.03, bone = "Leg" + sfx, col = BONE, line = 0.0},
			{p = Vector3(lx, 0.31, 0.0), r = 0.023, bone = "Leg" + sfx, col = BONE},
			{p = Vector3(lx, 0.255, 0.0), r = 0.024, bone = "Leg" + sfx, col = BONE},
			{p = Vector3(lx, 0.235, 0.0), r = 0.034, bone = "Shin" + sfx, col = BONE},
			{p = Vector3(lx, 0.212, 0.0), r = 0.022, bone = "Shin" + sfx, col = BONE},
			{p = Vector3(lx, 0.185, 0.0), r = 0.022, bone = "Shin" + sfx, col = BONE},
			{p = Vector3(lx, 0.172, 0.0), r = 0.045, bone = "Shin" + sfx, col = BOOT_CUFF},
			{p = Vector3(lx, 0.148, 0.0), r = 0.046, bone = "Shin" + sfx, col = BOOT_CUFF},
			{p = Vector3(lx, 0.14, 0.0), r = 0.038, bone = "Shin" + sfx, col = BOOT},
			{p = Vector3(lx, 0.09, 0.0), r = 0.038, bone = "Foot" + sfx, col = BOOT},
			{p = Vector3(lx, 0.06, 0.0), r = 0.04, bone = "Foot" + sfx, col = BOOT, line = 0.0},
		]
		g.limb(leg, 8, Vector3.FORWARD, false, false)
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		var ce := Vector3(lx, 0.0455, -fl * 0.22)
		var rr := Vector3(0.05, 0.065, fl * 0.5)
		var shape := func(d: Vector3) -> float:
			var k := 1.0 + 0.05 * DemonGeo.bump(d, Vector3(0, 0.3, -1).normalized(), 0.5)
			if d.y < -0.7:
				k = minf(k, 0.7 / -d.y)
			return k
		var col_of := func(d: Vector3, _p: Vector3) -> Color:
			if d.y < -0.66:
				return BOOT.darkened(0.35)
			return BOOT.lerp(BOOT_CUFF, clampf((-d.z - 0.6) * 2.0, 0.0, 1.0) * 0.6)
		g.sculpt(ce, rr, BOOT, 8, 6, shape, col_of)
	# 목뼈(두건·깃 속, 턱 아래로만 조금 보인다)
	g.use("Neck")
	g.limb([{p = Vector3(0, 0.69, 0.01), r = 0.032, bone = "Neck", col = BONE_DARK, line = 0.0},
		{p = Vector3(0, 0.75, 0.01), r = 0.034, bone = "Neck", col = BONE_DARK},
		{p = Vector3(0, 0.8, 0.0), r = 0.036, bone = "Neck", col = BONE_DARK, line = 0.0}], 6, Vector3.FORWARD, false, false)


# ------------------------------------------------------------------ 망토

## 등 뒤로 무릎까지 늘어진 자색 망토(양옆은 몸을 감싸고, 단은 물결). 윗단은 망토 깃 속에 묻힌다. Cape 뼈(2차 움직임)
static func _cape(g: DemonGeo) -> void:
	var top := Vector3(0, 0.7, 0.1)
	g.add_bone("Cape", "Spine", top)
	g.use("Cape")
	g.cape_grid(top, 0.445, 0.3, 0.42, HOOD, HOOD_DARK, 0.05, 0.11, 0.07, 8, 5, 0.006)


# ------------------------------------------------------------------ 머리

## 해골 조각 함수(방향 → 반지름 배수)
static func _shape(d: Vector3) -> float:
	var k := 1.0
	for side: float in [-1.0, 1.0]:
		# 눈구멍(크고 깊게), 그 위 눈두덩, 광대뼈, 광대 아래·턱 옆이 들어가 턱이 좁아진다, 관자놀이
		k -= 0.17 * DemonGeo.bump(d, Vector3(EYE_DX * side, EYE_DY, -0.9).normalized(), 0.28)
		k += 0.03 * DemonGeo.bump(d, Vector3(0.4 * side, 0.36, -0.84).normalized(), 0.2)
		k += 0.05 * DemonGeo.bump(d, Vector3(0.72 * side, -0.3, -0.62).normalized(), 0.24)
		k -= 0.15 * DemonGeo.bump(d, Vector3(0.85 * side, -0.55, -0.05).normalized(), 0.45)
		k -= 0.04 * DemonGeo.bump(d, Vector3(0.95 * side, 0.15, -0.2).normalized(), 0.3)
	# 코 구멍 자리(얕은 패임), 이빨 줄이 있는 위턱(조금 앞으로), 턱 끝, 턱 아래 뒤쪽은 들어간다
	k -= 0.07 * DemonGeo.bump(d, Vector3(0, -0.3, -0.96).normalized(), 0.1)
	k += 0.04 * DemonGeo.bump(d, Vector3(0, -0.52, -0.86).normalized(), 0.3)
	k += 0.06 * DemonGeo.bump(d, Vector3(0, -0.82, -0.58).normalized(), 0.25)
	k -= 0.12 * DemonGeo.bump(d, Vector3(0, -0.8, 0.6).normalized(), 0.5)
	return k


static func _hs(d: Vector3, k: float = 1.0) -> Vector3:
	var dn := d.normalized()
	return HC + Vector3(dn.x * HR.x, dn.y * HR.y, dn.z * HR.z) * (_shape(dn) * k)


static func _head(g: DemonGeo) -> void:
	g.use("Head")
	var col_of := func(d: Vector3, _p: Vector3) -> Color:
		var s := 0.0
		for side: float in [-1.0, 1.0]:
			s = maxf(s, DemonGeo.bump(d, Vector3(EYE_DX * side, EYE_DY, -0.9).normalized(), 0.28))
		var c := BONE.lerp(BONE_SHADE, smoothstep(0.25, 0.5, s) * 0.35)
		c = c.lerp(SOCKET, smoothstep(0.5, 0.7, s))
		# 광대 아래·턱 옆은 조금 그늘진 뼈색
		var hol := maxf(DemonGeo.bump(d, Vector3(-0.85, -0.55, -0.05).normalized(), 0.3), DemonGeo.bump(d, Vector3(0.85, -0.55, -0.05).normalized(), 0.3))
		return c.lerp(BONE_DARK, hol * 0.6)
	g.sculpt(HC, HR, BONE, 20, 13, func(d: Vector3) -> float: return _shape(d), col_of)
	# 관자놀이의 금 간 자국(얇은 선, 외곽선 없음)
	g.line = 0.0
	g.spline_tube([_hs(Vector3(0.62, 0.5, -0.6), 0.99), _hs(Vector3(0.72, 0.36, -0.58), 1.003), _hs(Vector3(0.66, 0.24, -0.7), 1.003), _hs(Vector3(0.7, 0.14, -0.7), 0.99)],
		[0.0, 0.0035, 0.003, 0.0], BONE_SHADE.darkened(0.25), 4, false, false)
	# 코 구멍(거꾸로 선 삼각): 코 자리 패임 바닥에 붙인 짙은 판
	var nd := Vector3(0, -0.3, -0.96).normalized()
	g.polygon(PackedVector2Array([Vector2(-0.024, 0.014), Vector2(-0.008, 0.018), Vector2(0, 0.012), Vector2(0.008, 0.018), Vector2(0.024, 0.014), Vector2(0, -0.03)]), _hs(nd, 1.0) + nd * 0.004,
		Basis.looking_at(nd, Vector3.UP), 0.0, SOCKET)
	g.line = 1.0
	_face(g)
	_hood(g)


## 두건: 머리통을 바짝 감싸는 한 장의 껍데기. 극을 앞(-Z, 살짝 아래)으로 눕히고 극 둘레를 둥글게 잘라 넓은 얼굴 구멍을 낸다.
## 행 = 구멍 안쪽 안감 → 두툼하게 말린 밝은 단 → 바깥 겉면 → 뒤 극, 열 = 극 둘레. 정수리 뒤의 뾰족한 꼭지는 겉면을 그 방향으로 부풀려 만든다.
## 밑단은 망토 깃 속으로 들어간다. 모두 Head 뼈, 키(HEIGHT)에는 넣지 않는다(머리통 꼭대기가 키).
static func _hood(g: DemonGeo) -> void:
	g.use("Head")
	g.measure = false
	var hc := Vector3(0, 0.92, 0.03)
	var pole := Vector3(0, -0.12, -1).normalized()
	var bas := Basis(Vector3.RIGHT, pole, Vector3.RIGHT.cross(pole))
	var hr := Vector3(0.25, 0.262, 0.25)   # 좌우 · 앞뒤(극 방향) · 위아래
	var lm := 1.02
	var tipd := Vector3(0, 0.78, 0.62).normalized()
	# (위도, 반지름 배수, 색 번호 0 = 안감 1 = 단 2 = 겉면)
	var rows: Array = [[lm + 0.16, 0.9, 0], [lm + 0.05, 0.92, 1], [lm - 0.02, 0.965, 1], [lm + 0.0, 1.02, 1], [lm + 0.07, 1.035, 1],
		[lm + 0.16, 1.0, 2], [1.45, 1.0, 2], [1.75, 1.0, 2], [2.05, 1.0, 2], [2.35, 1.0, 2], [2.75, 1.0, 2], [PI, 1.0, 2]]
	var segs := 20
	var pts: Array = []
	var cidx: Array = []
	for R: Array in rows:
		var lat: float = R[0]
		var sc: float = R[1]
		var row: Array = []
		for j in segs:
			var lon := TAU * float(j) / float(segs)
			var dir := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
			var p := bas * (dir * hr)
			var wd := p.normalized()
			# 꼭지: 정수리 뒤 방향으로 겉면을 부풀린다(안감·단은 그대로)
			var bulge := 1.0 + 0.36 * pow(DemonGeo.bump(wd, tipd, 0.3), 1.3)
			row.append(hc + p * (sc * bulge))
		pts.append(row)
		cidx.append(R[2])
	var col_of := func(i: int, _j: int) -> Color:
		var ci: int = cidx[i]
		return HOOD_DARK if ci == 0 else (HOOD_EDGE if ci == 1 else HOOD)
	_grid(g, pts, col_of, true, hc, [], [0.0, 0.6, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	# 작은 금 핀(이마 위 단 가운데)
	var top_dir := Vector3(0, cos(lm), -sin(lm))
	var pin := hc + bas * (top_dir * hr) * 1.04 - pole * 0.01
	g.line = 0.4
	g.polygon(PackedVector2Array([Vector2(0, 0.018), Vector2(0.014, 0), Vector2(0, -0.018), Vector2(-0.014, 0)]), pin, Basis.looking_at(-pole + Vector3(0, 0.5, 0), Vector3.UP), 0.008, GOLD, GOLD_DARK)
	g.line = 1.0
	g.measure = true


## 눈구멍 속 붉은 빛점(밝은 심), 눈꺼풀 = 뼈색 두덩(깜빡임·표정에서 눈구멍을 덮는다), 눈두덩 능선 = 눈구멍 위 가장자리의 끝이 가는 짙은 띠,
## 입 = 보통(짙은 틈 위 이빨 줄)·화남(벌린 입)·아픔(작은 ○). 뼈 이름은 CharacterRig 표정 규약 그대로.
static func _face(g: DemonGeo) -> void:
	var es := ES
	var keep_line := g.line
	g.line = 0.0
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var d := Vector3(EYE_DX * side, EYE_DY, -0.9).normalized()
		var floor_p := _hs(d, 1.0)
		var eb := Basis.looking_at(d, Vector3.UP)
		# 눈 뼈: 눈구멍 바닥에 붙은 짙은 안쪽 판(깜빡임에서 눌린다)
		# 눈구멍을 채우는 새까만 납작한 타원(앞면이 눈구멍 벽과 만나는 선이 또렷한 구멍 가장자리가 된다). 머리 뼈라 깜빡여도 구멍은 그대로이고,
		# 눈 뼈(빛점의 부모)가 눌리면 붉은 빛만 꺼진다(기절·웃음)
		var ec := floor_p + d * 0.002
		g.use("Head")
		g.ellipsoid(ec, Vector3(es * 1.25, es * 1.35, es * 0.3), SOCKET, 10, 4, eb * Basis(Vector3.BACK, side * 0.12))
		g.add_bone("Eye" + sfx, "Head", ec)
		# 붉은 빛점과 밝은 심: 눈구멍 바닥 바로 앞에 떠 있다
		var pc := floor_p + d * 0.016 + Vector3(0, -es * 0.05, 0)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.ellipsoid(pc, Vector3(es * 0.3, es * 0.32, es * 0.18), EYE, 10, 5, eb)
		g.polygon(_ellipse(es * 0.11, es * 0.11, 6), pc + d * (es * 0.19) + eb * Vector3(es * 0.06 * side, es * 0.08, 0), eb, 0.0, EYE_CORE)
		# 윗눈꺼풀(뼈색 반구 덮개): 눈구멍 위 가장자리에 피벗, 표정이 Y 크기를 키우면 내려와 눈구멍을 덮는다
		var ud := (d + Vector3(0, 0.3, 0)).normalized()
		var lid_p := _hs(ud, 0.985)
		var lb := Basis.looking_at(ud.lerp(d, 0.5).normalized(), Vector3.UP)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.3, es * 2.1, es * 0.75), BONE_DARK, 8, 3, lb * Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈두덩 능선: 눈구멍 위 가장자리를 따라가는 짙은 띠(양 끝은 가늘어져 뼈 속으로)
		var bp := _hs(Vector3(EYE_DX * side, 0.3, -0.88), 1.0)
		g.add_bone("Brow" + sfx, "Head", bp)
		g.use("Brow" + sfx)
		var bpts: Array = [
			_hs(Vector3(0.16 * side, 0.18, -0.97), 0.985),
			_hs(Vector3(0.26 * side, 0.27, -0.93), 1.0),
			bp,
			_hs(Vector3(0.62 * side, 0.27, -0.74), 1.0),
			_hs(Vector3(0.72 * side, 0.16, -0.66), 0.985),
		]
		g.spline_tube(bpts, [0.0, es * 0.1, es * 0.12, es * 0.1, 0.0], RIDGE, 5, false, false, Vector3.RIGHT, 0.6, 1.0)
	# 입: 위턱 이빨 줄 자리
	var md := Vector3(0, -0.56, -0.83).normalized()
	var mp := _hs(md, 1.0)
	var mb := Basis.looking_at(md, Vector3.UP)
	g.add_bone("MouthN", "Head", mp)
	g.use("MouthN")
	var band: Array = []
	var br: Array = []
	for i in 7:
		var u := float(i) / 3.0 - 1.0
		band.append(_hs(Vector3(u * 0.36, -0.56 + 0.03 * u * u, -0.83), 0.998))
		br.append(0.0 if absf(u) > 0.99 else 0.014 * (1.0 - 0.3 * u * u))
	g.spline_tube(band, br, MOUTH, 5, false, false, Vector3.RIGHT, 0.6, 1.0)
	for k in 6:
		var u := (float(k) - 2.5) * 0.33
		g.box(_hs(Vector3(u * 0.36, -0.56 + 0.03 * u * u, -0.83), 1.008), Vector3(0.019, 0.034, 0.012), BONE, mb)
	g.add_bone("MouthA", "Head", mp)
	g.use("MouthA")
	g.ellipsoid(mp + md * 0.012 + Vector3(0, -0.018, 0), Vector3(0.068, 0.045, 0.03), MOUTH, 10, 4, mb)
	for k in 5:
		var u := (float(k) - 2.0) * 0.36
		g.box(_hs(Vector3(u * 0.36, -0.5, -0.86), 1.01), Vector3(0.017, 0.022, 0.01), BONE, mb)
	for k in 4:
		var u := (float(k) - 1.5) * 0.4
		g.box(_hs(Vector3(u * 0.36, -0.72, -0.7), 1.01), Vector3(0.016, 0.018, 0.01), BONE, mb)
	g.add_bone("MouthH", "Head", mp)
	g.use("MouthH")
	g.ellipsoid(mp + md * 0.008 + Vector3(0, -0.01, 0), Vector3(0.028, 0.03, 0.02), MOUTH, 8, 3, mb)
	g.use("Head")
	g.line = keep_line


# ------------------------------------------------------------------ 활·화살통

## 큰 황금빛 활(왼손, 길이 ≈ 키의 0.9): 축은 손에서 위로 뻗되 앞쪽 30°·바깥쪽 22° 기울어 몸에서 비스듬히 벌어지고(v5 와 같은 축),
## 활대는 바깥·앞으로 휘며 끝은 되감긴다. 활대·가죽 손잡이·금 끝이 한 관(마디마다 색이 바뀐다), 시위는 가는 관.
static func _bow(g: DemonGeo, hl: Vector3) -> void:
	g.use("HandL")
	g.measure = false
	g.measure_all = false
	var tilt := deg_to_rad(30.0)
	var out := deg_to_rad(22.0)
	var a := Vector3(-sin(out), cos(out) * cos(tilt), -cos(out) * sin(tilt)).normalized()
	var f := Vector3(-0.72, 0, -0.6)
	f = (f - a * f.dot(a)).normalized()
	var ts: Array = [-1.0, -0.93, -0.84, -0.68, -0.45, -0.2, -0.1, 0.0, 0.1, 0.2, 0.45, 0.68, 0.84, 0.93, 1.0]
	var nodes: Array = []
	var half := 0.52
	var mid := hl + a * 0.12
	var tips: Array = []
	for t: float in ts:
		var bow := 0.2 * (1.0 - t * t)
		var curl := 0.055 * maxf(0.0, absf(t) - 0.75) / 0.25
		var off := bow - 0.2 + curl
		var p := mid + a * (t * half) + f * off
		var r := 0.016 + 0.022 * (1.0 - absf(t)) * (1.0 - absf(t))
		var col := BOW
		if absf(t) >= 0.84:
			col = GOLD
		var grip := absf((mid + a * (t * half)).distance_to(hl))
		if grip < 0.075:
			col = LEATHER
			r += 0.008
		if absf(t) >= 0.999:
			r = 0.012
		nodes.append({p = p, r = r, bone = "HandL", col = col})
		if absf(t) >= 0.999:
			tips.append(p)
	g.limb(nodes, 6, Vector3.FORWARD, true, true)
	# 시위
	var keep := g.line
	g.line = 0.4
	g.spline_tube([tips[0], tips[1]], [0.006, 0.006], STRING, 4, false, false)
	g.line = keep
	g.measure = true
	g.measure_all = true


## 등의 가죽 화살통(오른쪽 어깨 뒤로 비스듬히): 바닥 → 몸통 → 밝은 테 → 열린 입구가 한 관. 화살 넉 대(붉은·흰 깃은 엇갈린 두 장의 판)
static func _quiver(g: DemonGeo) -> void:
	g.use("Spine")
	var q0 := Vector3(0.09, 0.5, 0.15)
	var q1 := Vector3(0.15, 0.73, 0.2)
	var d := (q1 - q0).normalized()
	var L := q0.distance_to(q1)
	var nodes: Array = [
		{p = q0, r = 0.034, bone = "Spine", col = LEATHER},
		{p = q0 + d * 0.05, r = 0.042, bone = "Spine", col = LEATHER_LIGHT},
		{p = q0 + d * 0.075, r = 0.042, bone = "Spine", col = LEATHER},
		{p = q0 + d * (L - 0.03), r = 0.046, bone = "Spine", col = LEATHER},
		{p = q0 + d * (L - 0.025), r = 0.05, bone = "Spine", col = LEATHER_LIGHT},
		{p = q1, r = 0.05, bone = "Spine", col = LEATHER_LIGHT},
	]
	g.limb(nodes, 8, Vector3.FORWARD, true, true)
	g.measure = false
	var keep := g.line
	for k in 4:
		var ang := TAU * float(k) / 4.0 + 0.5
		var off := Vector3(cos(ang), 0, sin(ang)) * 0.02
		var s0 := q1 + off - d * 0.02
		var s1 := q1 + off + d * (0.12 + 0.015 * float(k % 2))
		g.line = 0.5
		g.spline_tube([s0, s1], [0.006, 0.006], BOW_DARK, 4, false, true)
		g.line = 0.3
		var fc: Color = FLETCH if k % 2 == 0 else FLETCH2
		var fl := PackedVector2Array([Vector2(0, 0.0), Vector2(0.014, 0.012), Vector2(0.014, 0.05), Vector2(0, 0.04)])
		var fl2 := PackedVector2Array([Vector2(0, 0.0), Vector2(0, 0.04), Vector2(-0.014, 0.05), Vector2(-0.014, 0.012)])
		var base := s1 - d * 0.055
		var b1 := Basis(Quaternion(Vector3.UP, d))
		var b2 := b1 * Basis(Vector3.UP, PI * 0.5)
		g.polygon(fl, base, b1, 0.0, fc)
		g.polygon(fl2, base, b1, 0.0, fc)
		g.polygon(fl, base, b2, 0.0, fc)
		g.polygon(fl2, base, b2, 0.0, fc)
	g.line = keep
	g.measure = true
