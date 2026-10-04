class_name GoblinBuilder
extends RefCounted
## 고블린 일꾼(변형 3종)의 메시·골격 정의(5차: 컨셉 시트 「고블린 일꾼(3종)」 기준).
## 0 일반 = 이마에 올린 놋쇠 고글 + 보라 조끼 + 작은 나무 망치
## 1 건설형 = 같은 고글, 큰 두손 돌망치, 벨트 주머니, 두툼한 어깨와 가죽 어깨받이
## 2 방어탑 조작수 = 뿔 둘 달린 짙은 쇠 투구(놋쇠 띠·마름모 문장·정수리 징, 고글 없음), 중간 크기 쇠망치
## 공통: 밝은 초록 피부, 분홍 안쪽의 커다란 뾰족 귀(EarL/EarR 뼈로 펄럭임), 둥근 코, 아랫니 송곳니 둘,
## 이마에 박힌 납작한 짙은 눈썹(코 쪽이 내려간 노려보는 눈), 흰자가 깨끗한 큰 눈과 큰 검은 눈동자,
## 약 2.8등신의 땅딸막한 몸, 세 손가락 큰 주먹, 짧은 다리에 큰 갈색 장화.
## orc = true 는 예전 호출 호환용 최소 경로(올리브 피부·붉은 볏·엄니, 고글 없음). 꼬마 오크 본 모델은 OrcBuilder 가 맡는다.

const SKIN := Color("7fbd45")
const SKIN_DARK := Color("5f9c32")
const EAR_IN := Color("d0948a")
const BROW := Color("2a1a10")
const EYE_RIM := Color("1d1613")
const PUPIL := Color("221a1c")
const HAIR := Color("4b2b17")
const VEST := Color("5c3f8e")
const VEST_DARK := Color("46307a")
const LEATHER := Color("5e3b1f")
const LEATHER_LIGHT := Color("8b5b30")
const BELT := Color("4a2f17")
const TROUSERS := Color("8a5a30")
const BOOT := Color("4e2f19")
const BOOT_TOE := Color("8e6238")
const BRASS := Color("cfa548")
const BRASS_DARK := Color("9c7a2e")
const LENS := Color("9fd8e8")
const LENS_LIGHT := Color("e4f8fc")
const STONE := Color("7f7c7a")
const STONE_LIGHT := Color("a09c99")
const IRON := Color("6a6b70")
const IRON_LIGHT := Color("9598a0")
const HELMET := Color("4b4a52")
const HELMET_DARK := Color("313037")
const HORN := Color("d9a85a")
const HORN_TIP := Color("f2dfb0")
const WOOD := Color("b57a3f")
const WOOD_DARK := Color("7e4f24")
const FANG := Color("f6f2e6")

## 골격 높이. 머리를 10% 줄이고 다리·몸통을 늘려 약 2.8등신(키 1.0)으로 맞춘다.
const P := {
	ankle = 0.07, knee = 0.195, hip = 0.325, hip_x = 0.082, pelvis = 0.335, spine = 0.395,
	shoulder = 0.555, shoulder_x = 0.17, elbow = 0.44, wrist = 0.325, neck = 0.6, head = 0.645,
	arm_r = 0.038, leg_r = 0.045, foot_len = 0.19,
}
const HC := Vector3(0, 0.812, -0.005)      # 머리 중심
const HR := Vector3(0.196, 0.172, 0.183)   # 머리 반지름(가로가 넓은 머리)
const ES := 0.048                           # 눈 크기
const TC := Vector3(0, 0.48, 0)             # 몸통(조끼) 중심
const TR := Vector3(0.172, 0.135, 0.142)    # 몸통 반지름
const BELT_TOP := 0.385                     # 벨트 윗단 = 조끼 통 아랫단
const V_TOP_Y := 0.58                       # 조끼 V 넥 윗단(칼라) 높이
const V_TOP_W := 0.076                      # V 넥 윗단 반너비
const V_BOT_Y := 0.418                      # V 넥 아래 꼭짓점 높이(벨트 바로 위)
const V_BOT_W := 0.012                      # V 넥 꼭짓점 반너비


# ================================================================== 고블린

static func build(v: int, with_hammer: bool, orc: bool = false) -> Dictionary:
	var C := {skin = SKIN, skin_dark = SKIN_DARK, vest = VEST, vest_dark = VEST_DARK, hair = HAIR, trousers = TROUSERS}
	if orc:
		C = {skin = Color("6f9a3a"), skin_dark = Color("55782a"), vest = Color("6b4423"), vest_dark = Color("4a2f17"),
			hair = Color("d0352a"), trousers = Color("7a4a26")}
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	_torso(g, v, C)
	_limbs(g, v, C)
	_head(g, v, C, orc)
	# 망치(오른손 +X). 손잡이는 주먹 아래로 앞쪽 45° 기울어 쥔다. 무기는 키·체력 막대 측정에서 뺀다.
	var hand := Vector3(float(P.shoulder_x), float(P.wrist) - float(P.arm_r) * 0.95, -0.012)
	var tip := hand
	if with_hammer:
		tip = _hammer(g, v, hand)
	var def := g.build(CharacterRig.character_material())
	def.tip = tip
	def.H = 1.0
	def.es = ES
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


# ------------------------------------------------------------------ 몸통

## 몸통 겉면 깊이(-Z): 조끼 타원체와 조끼 통 중 더 바깥쪽. 끈·앞섶을 겉면에 붙일 때 쓴다.
static func _torso_z(x: float, y: float) -> float:
	var ze := CharGeo.surf_z(TC, TR, x, y)
	var zt := 0.0
	if y >= BELT_TOP and y <= TC.y:
		var rr := lerpf(0.16, 0.172, (y - BELT_TOP) / (TC.y - BELT_TOP))
		zt = -sqrt(maxf(rr * rr - x * x, 0.0))
	return minf(ze, zt)


## 몸통: 보라 조끼의 열린 V 넥 사이로 드러난 초록 가슴, 가슴을 가로지르는 가죽 끈(끝은 벨트 밑으로 들어감), 놋쇠 버클 벨트, 갈색 바지 엉덩이
static func _torso(g: CharGeo, v: int, C: Dictionary) -> void:
	var skin: Color = C.skin
	var vest: Color = C.vest
	g.use("Spine")
	# 조끼(어깨 쪽이 살짝 좁은 통)
	g.ellipsoid(TC, TR, vest, 12, 5)
	g.tube(Vector3(0, BELT_TOP, 0), TC, 0.16, 0.172, vest, 10, false)
	# 조끼 앞섶: 칼라에서 벨트 위 한 점까지 좁아지는 V 자 틈으로 초록 가슴이 보인다(막힌 마름모가 아니라 열린 V 넥)
	_chest_v(g, skin)
	# 조끼 앞섶 가장자리(V 자 양변을 따라가는 짙은 보라 두 줄)
	for side: float in [-1.0, 1.0]:
		var edge: Array = []
		for i in 4:
			var t := float(i) / 3.0
			var x := side * lerpf(V_TOP_W + 0.006, V_BOT_W, t)
			var y := lerpf(V_TOP_Y + 0.004, V_BOT_Y - 0.006, t)
			edge.append(Vector3(x, y, _torso_z(x, y) - 0.005))
		g.sweep(edge, 0.011, C.vest_dark, 3)
	# 가슴을 가로지르는 가죽 끈(왼쪽 어깨 공 속에서 나와 오른쪽 벨트 밑으로 들어간다)
	var strap: Array = []
	for i in 7:
		var t := float(i) / 6.0
		var x := lerpf(-0.14, 0.1, t)
		var y := lerpf(TC.y + 0.108, BELT_TOP - 0.012, t)
		var z := _torso_z(x, y) - 0.004
		if i == 6:
			z += 0.014   # 끝은 벨트 안쪽으로 밀어 넣어 벨트가 덮는다
		strap.append(Vector3(x, y, z))
	g.sweep(strap, 0.012, LEATHER, 4)
	# 벨트와 놋쇠 버클
	g.use("Pelvis")
	g.tube(Vector3(0, BELT_TOP - 0.045, 0), Vector3(0, BELT_TOP, 0), 0.168, 0.166, BELT, 10, false)
	var by := BELT_TOP - 0.022
	g.rounded_box(Vector3(0, by, -0.168), Vector3(0.034, 0.024, 0.009), BRASS, 0.4, 6, 4)
	g.rounded_box(Vector3(0, by, -0.174), Vector3(0.016, 0.011, 0.006), BRASS_DARK, 0.5, 5, 3)
	# 갈색 바지 엉덩이
	g.ellipsoid(Vector3(0, BELT_TOP - 0.07, 0.0), Vector3(0.162, 0.095, 0.135), C.trousers, 9, 4)
	if v == 1:
		# 건설형: 벨트에 매단 연장 주머니(오른쪽 앞)
		g.rounded_box(Vector3(0.135, by - 0.033, -0.095), Vector3(0.042, 0.04, 0.03), LEATHER_LIGHT, 0.4, 7, 4)
		g.rounded_box(Vector3(0.135, by - 0.005, -0.097), Vector3(0.045, 0.012, 0.033), LEATHER, 0.4, 6, 3)
		g.sphere(Vector3(0.135, by - 0.023, -0.13), 0.008, BRASS, 4, 3)
	# 목
	g.use("Neck")
	g.tube(Vector3(0, float(P.neck) - 0.06, 0), Vector3(0, float(P.neck) + 0.06, 0), 0.058, 0.062, skin, 6, false)


## 조끼 V 넥 안으로 보이는 초록 가슴: 몸통 겉면에 살짝 띄워 붙인 얇은 격자 조각.
## 위는 칼라 너비로 목 밑동에 닿고 아래는 벨트 위 한 점으로 모인다(여러 줄로 나눠 몸통 곡면을 따라간다).
static func _chest_v(g: CharGeo, skin: Color) -> void:
	var rows := 5
	var cols := 4
	var base := g.v.size()
	for i in rows + 1:
		var t := float(i) / float(rows)
		var y := lerpf(V_TOP_Y, V_BOT_Y, t)
		var w := lerpf(V_TOP_W, V_BOT_W, t)
		for j in cols + 1:
			var x := lerpf(-w, w, float(j) / float(cols))
			var z := _torso_z(x, y) - 0.004
			g._vert(Vector3(x, y, z), Vector3(x / TR.x, (y - TC.y) / TR.y, (z - TC.z) / TR.z), skin)
	for i in rows:
		for j in cols:
			var a := base + i * (cols + 1) + j
			g.tri(a, a + 1, a + cols + 1)
			g.tri(a + 1, a + cols + 2, a + cols + 1)


# ------------------------------------------------------------------ 팔다리

## 팔(초록 맨팔, 가죽 손목 띠, 세 손가락 큰 주먹)과 다리(갈색 바지, 큰 장화와 밝은 앞코)
static func _limbs(g: CharGeo, v: int, C: Dictionary) -> void:
	var skin: Color = C.skin
	var trousers: Color = C.trousers
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	var ar: float = P.arm_r
	var lr: float = P.leg_r
	var bulk := 1.18 if v == 1 else 1.0
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Arm" + sfx)
		g.sphere(Vector3(x, P.shoulder, 0), ar * 1.5 * bulk, skin, 7, 4)
		if v == 1 and side > 0.0:
			# 건설형: 오른쪽 어깨 가죽 어깨받이
			g.ellipsoid(Vector3(x + 0.004, float(P.shoulder) + 0.012, 0), Vector3(ar * 1.95, ar * 1.3, ar * 1.8), LEATHER_LIGHT, 8, 3,
				Basis.IDENTITY, PI * 0.58, PI * 0.58)
			g.sphere(Vector3(x + 0.01, float(P.shoulder) + 0.058, 0), 0.009, BRASS, 4, 3)
		g.tube(Vector3(x, P.shoulder, 0), Vector3(x, P.elbow, 0), ar * 1.15 * bulk, ar * 0.98, skin, 7, false)
		g.use("Forearm" + sfx)
		g.sphere(Vector3(x, P.elbow, 0), ar * 1.02, skin, 5, 2)
		g.tube(Vector3(x, P.elbow, 0), Vector3(x, P.wrist, 0), ar * 1.0, ar * 1.18, skin, 7, false)
		g.use("Hand" + sfx)
		# 가죽 손목 띠
		g.tube(Vector3(x, float(P.wrist) + ar * 0.55, 0), Vector3(x, float(P.wrist) - ar * 0.35, 0), ar * 1.3, ar * 1.36, LEATHER, 7, true)
		# 큰 주먹 + 세 손가락 마디 + 엄지
		var fc := Vector3(x, float(P.wrist) - ar * 0.95, -0.012)
		g.ellipsoid(fc, Vector3(ar * 1.55, ar * 1.5, ar * 1.6), skin, 8, 4)
		for k in 3:
			var fx := (float(k) - 1.0) * ar * 0.95
			g.ellipsoid(fc + Vector3(fx, -ar * 0.55, -ar * 1.15), Vector3(ar * 0.52, ar * 0.5, ar * 0.62), skin, 4, 2)
		g.ellipsoid(fc + Vector3(-side * ar * 1.2, ar * 0.1, -ar * 0.75), Vector3(ar * 0.5, ar * 0.62, ar * 0.5), skin, 4, 2)
		# 다리
		var lx := hx * side
		g.use("Leg" + sfx)
		g.tube(Vector3(lx, float(P.hip) + lr * 0.5, 0), Vector3(lx, float(P.knee) - 0.01, 0), lr * 1.4, lr * 1.2, trousers, 7, false)
		g.use("Shin" + sfx)
		g.sphere(Vector3(lx, P.knee, 0), lr * 1.05, trousers, 5, 2)
		# 장화 목(무릎 아래부터)과 접힌 윗단
		g.tube(Vector3(lx, float(P.knee) - 0.015, 0), Vector3(lx, float(P.ankle) - 0.01, 0), lr * 1.12, lr * 1.25, BOOT, 7, false)
		g.tube(Vector3(lx, float(P.knee) + 0.005, 0), Vector3(lx, float(P.knee) - 0.03, 0), lr * 1.3, lr * 1.22, BOOT_TOE, 7, true)
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		# 큰 장화(바닥이 y=0) + 밝은 앞코
		g.ellipsoid(Vector3(lx, 0.06, -fl * 0.2), Vector3(lr * 1.55, 0.06, fl * 0.5), BOOT, 8, 4)
		g.ellipsoid(Vector3(lx, 0.05, -fl * 0.52), Vector3(lr * 1.3, 0.05, fl * 0.32), BOOT_TOE, 6, 3)


# ------------------------------------------------------------------ 머리

## 머리: 넓적한 머리통과 통통한 볼, 얼굴, 코·아랫입술·송곳니, 큰 귀, 머리털 또는 투구, 고글
static func _head(g: CharGeo, v: int, C: Dictionary, orc: bool) -> void:
	var skin: Color = C.skin
	var skin_dark: Color = C.skin_dark
	g.use("Head")
	g.ellipsoid(HC, HR, skin, 18, 10)
	# 통통한 볼(아래턱을 넓게)
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(HC + Vector3(0.112 * side, -0.058, -0.02), Vector3(0.11, 0.08, 0.12), skin, 9, 5)
	var ey := HC.y + 0.02
	_face(g, {hc = HC, hr = HR, es = ES, eye_y = ey, eye_dx = 0.082, mouth_y = HC.y - 0.1, mouth_w = 0.115,
		skin = skin, pupil = PUPIL, brow = BROW, eye_rim = EYE_RIM, eye_w = 1.08, iris = 1.15,
		brow_w = 1.3, brow_t = 1.0, lid = skin.darkened(0.05), lash = EYE_RIM})
	g.use("Head")
	# 둥근 코(이전보다 20% 작게, 더 매끈하게)
	var ny := HC.y - 0.034
	g.ellipsoid(Vector3(0, ny, CharGeo.surf_z(HC, HR, 0, ny) - 0.028), Vector3(0.037, 0.032, 0.04), skin_dark.lightened(0.12), 11, 5)
	# 아랫입술(주걱턱)과 아랫니 송곳니 둘
	var ly := HC.y - 0.12
	g.ellipsoid(Vector3(0, ly, CharGeo.surf_z(HC, HR, 0, ly) - 0.012), Vector3(0.066, 0.015, 0.03), skin_dark, 8, 3)
	var keep_line := g.line
	g.line = 0.5
	for side: float in [-1.0, 1.0]:
		var fx := 0.043 * side
		var fy := HC.y - 0.105
		var fz := CharGeo.surf_z(HC, HR, fx, fy) - 0.02
		if orc:
			g.tube(Vector3(fx * 1.2, fy - 0.015, fz), Vector3(fx * 1.5, fy + 0.055, fz - 0.015), 0.016, 0.0, FANG, 6, true)
		else:
			g.tube(Vector3(fx, fy - 0.01, fz), Vector3(fx * 1.08, fy + 0.028, fz - 0.004), 0.01, 0.0, FANG, 6, true)
	g.line = keep_line
	_ears(g, skin)
	if orc:
		_hair(g, 4, 0.13, C.hair)
		return
	match v:
		0:
			_hair(g, 3, 0.1, C.hair)
			_goggles(g, HC, HR, HC.y + 0.128, 1.15, 9)
		1:
			_hair(g, 4, 0.115, C.hair)
			_goggles(g, HC, HR, HC.y + 0.128, 1.15, 9)
		_:
			_helmet(g)


## 커다란 나뭇잎꼴 뾰족 귀: 바깥·위로 뻗고 끝이 살짝 들린다. 앞면 안쪽은 분홍. EarL/EarR 뼈(2차 움직임)
static func _ears(g: CharGeo, skin: Color) -> void:
	g.measure = false
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var base := Vector3(0.175 * side, HC.y + 0.02, 0.005)
		g.add_bone("Ear" + sfx, "Head", base)
		g.use("Ear" + sfx)
		var dir := Vector3(side, 0.28, 0.12).normalized()
		var L := 0.3
		var pts: Array = []
		var radii: Array = []
		var inner: Array = []
		var inner_r: Array = []
		var prof: Array = [0.048, 0.07, 0.068, 0.051, 0.027, 0.0]
		for i in 6:
			var t := float(i) / 5.0
			var p := base + dir * (L * t) + Vector3(0, 0.06 * t * t, 0.03 * t * t)
			pts.append(p)
			radii.append(prof[i])
			if i >= 1:
				inner.append(p + Vector3(0, -0.004, -0.014) + dir * 0.015)
				inner_r.append(float(prof[i]) * 0.6)
		g.spline_tube(pts, radii, skin, 8, true, true, Vector3.UP, 1.0, 0.3)
		var keep := g.line
		g.line = 0.4
		g.spline_tube(inner, inner_r, EAR_IN, 6, false, true, Vector3.UP, 1.0, 0.26)
		g.line = keep
	g.measure = true
	g.use("Head")


## 정수리의 짙은 갈색 뾰족 머리털 n 가닥(앞은 앞으로, 뒤는 뒤로 휜다)과 옆머리 한 가닥씩
static func _hair(g: CharGeo, n: int, L: float, col: Color) -> void:
	g.measure = false
	g.use("Head")
	for i in n:
		var t := (float(i) / float(n - 1) - 0.5) * 2.0   # -1(앞) ~ 1(뒤)
		var z := HC.z + t * 0.08
		var y := HC.y + HR.y * sqrt(maxf(0.0, 1.0 - pow(z / HR.z, 2.0))) * 0.995
		var base := Vector3(0.0, y - 0.02, z)
		var dir := Vector3(0, 1, t * 0.35).normalized()
		g.horn(base, dir, Vector3(0, 0, t * 0.6), L * (1.0 - absf(t) * 0.2), 0.04, col, 3, 6)
	for side: float in [-1.0, 1.0]:
		var base := Vector3(0.09 * side, HC.y + 0.145, -0.015)
		g.horn(base, Vector3(side * 0.8, 1, 0).normalized(), Vector3(side * 0.6, 0, 0), L * 0.6, 0.026, col, 2, 5)
	g.measure = true


## 놋쇠 둥근 고글: 머리를 두르는 가죽 띠 위에 큰 렌즈 통 둘(연파랑 렌즈·반사광)과 가운데 다리.
## cy = 렌즈 중심 높이, scale = 크기 배수, segs = 렌즈 통 분할 수
static func _goggles(g: CharGeo, hc: Vector3, hr: Vector3, cy: float, scale: float, segs: int) -> void:
	g.use("Head")
	# 가죽 띠: 앞이 조금 높은 비스듬한 얇은 띠(타원 껍질 한 고리)
	var tilt := deg_to_rad(14.0)
	var lat := tilt + acos(clampf((cy - hc.y) / hr.y, -1.0, 1.0))
	var keep := g.line
	g.line = 0.6
	g.ellipsoid(hc, hr * 1.03, LEATHER, 14, 1, Basis(Vector3.RIGHT, tilt), lat + 0.085, lat + 0.085, lat - 0.085)
	var cups: Array = []
	for side: float in [-1.0, 1.0]:
		var gx := 0.078 * side * scale
		var gz := CharGeo.surf_z(hc, hr, gx, cy)
		# 렌즈는 겉면 법선보다 조금 더 앞을 본다(정면에서도 파란 렌즈가 보이게)
		var nn := (Vector3(gx / (hr.x * hr.x), (cy - hc.y) / (hr.y * hr.y), (gz - hc.z) / (hr.z * hr.z)).normalized() * 0.6
			+ Vector3(0, 0.3, -0.8)).normalized()
		var p := Vector3(gx, cy, gz)
		cups.append(p)
		var r := 0.047 * scale
		g.tube(p - nn * 0.006, p + nn * 0.034 * scale, r, r * 0.96, BRASS, segs, true)
		g.tube(p + nn * 0.03 * scale, p + nn * 0.04 * scale, r * 1.06, r * 1.02, BRASS_DARK, segs, true)
		g.line = 0.0
		g.ellipsoid(p + nn * 0.041 * scale, Vector3(r * 0.8, r * 0.8, 0.011), LENS, segs, 3, Basis(Quaternion(Vector3.FORWARD, nn)))
		g.sphere(p + nn * 0.049 * scale + Vector3(-r * 0.3, r * 0.3, 0), r * 0.17, LENS_LIGHT, 4, 2)
		g.line = 0.6
	# 가운데 다리
	var c0: Vector3 = cups[0]
	var c1: Vector3 = cups[1]
	g.tube(c0 + Vector3(0.03 * scale, 0, 0), c1 - Vector3(0.03 * scale, 0, 0), 0.011 * scale, 0.011 * scale, BRASS_DARK, 5, true)
	g.sphere(c0.lerp(c1, 0.5) + Vector3(0, 0, -0.006), 0.014 * scale, BRASS, 5, 3)
	g.line = keep


## 방어탑 조작수 투구: 짙은 쇠 돔, 놋쇠 테두리 띠와 징, 앞 마름모 문장, 두툼하게 휜 황갈색 뿔 둘, 정수리 작은 징(고글 없음)
static func _helmet(g: CharGeo) -> void:
	g.use("Head")
	var hc := HC + Vector3(0, 0.012, 0.004)
	var hr := Vector3(HR.x * 1.1, HR.y * 1.08, HR.z * 1.1)
	var lat_f := PI * 0.31
	var lat_b := PI * 0.56
	g.ellipsoid(hc, hr, HELMET, 16, 6, Basis.IDENTITY, lat_f, lat_b)
	# 돔 가운데 세로 이음선(앞뒤로 지나는 짙은 쇠 띠)
	var keep := g.line
	g.line = 0.5
	var seam: Array = []
	for i in 5:
		var lat := lerpf(-lat_f * 0.75, lat_b * 0.7, float(i) / 4.0)
		seam.append(hc + Vector3(0, cos(lat) * hr.y, sin(lat) * hr.z) * 1.004)
	g.sweep(seam, 0.012, HELMET_DARK, 4)
	# 테두리 놋쇠 띠: 돔 바로 안쪽의 껍질이 돔 가장자리 아래로 조금 더 내려와 띠로 보인다
	g.line = 0.7
	g.ellipsoid(hc, hr * 0.995, BRASS, 16, 2, Basis.IDENTITY, lat_f + 0.13, lat_b + 0.12, lat_f - 0.12)
	# 띠의 징
	for lon: float in [0.5, 1.4, TAU - 1.4, TAU - 0.5]:
		var fw := (1.0 + cos(lon)) * 0.5
		var lat := lerpf(lat_b, lat_f, fw) + 0.07
		var d := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
		g.sphere(hc + d * hr * 1.0, 0.012, BRASS_DARK, 4, 2)
	# 앞 마름모 문장과 흰 보석
	var lat_e := lat_f + 0.07
	var fz := hc.z - hr.z * sin(lat_e) - 0.01
	var fy := hc.y + hr.y * cos(lat_e)
	var nn := Vector3(0, cos(lat_e), -sin(lat_e)).normalized()
	var bas := Basis(Vector3.RIGHT, Vector3.RIGHT.cross(nn), nn)
	g.polygon(PackedVector2Array([Vector2(0, 0.046), Vector2(-0.036, 0), Vector2(0, -0.046), Vector2(0.036, 0)]),
		Vector3(0, fy, fz), bas, 0.012, BRASS, BRASS_DARK)
	g.line = 0.0
	g.sphere(Vector3(0, fy, fz) + nn * 0.01, 0.015, Color("f4efe6"), 5, 3)
	g.line = keep
	# 두툼하게 휜 뿔 둘(위·바깥으로 자라며 끝이 안쪽으로 굽는다, 끝은 밝게). 정수리에는 작은 놋쇠 징 하나(긴 볏 가시는 컨셉에 없다)
	g.measure = false
	for side: float in [-1.0, 1.0]:
		var base := hc + Vector3(0.1 * side, hr.y * 0.8, -0.035)
		g.sphere(base, 0.03, BRASS_DARK, 5, 2)   # 뿔 뿌리를 감싼 놋쇠 테
		g.horn(base, Vector3(side * 0.55, 1, -0.08).normalized(), Vector3(-side * 0.25, 0.25, 0), 0.19, 0.046, HORN, 4, 7, HORN_TIP)
	g.sphere(hc + Vector3(0, hr.y * 0.98, 0.0), 0.017, BRASS, 6, 3)
	g.measure = true


# ------------------------------------------------------------------ 얼굴(공통 얼굴을 고블린용으로 고친 복사본)

## 공통 face_parts 와 같은 뼈(EyeL/R, PupilL/R, LidL/R, BrowL/R, MouthN/A/H)를 쓰되
## 눈은 테두리 없이 깨끗한 흰자 위에 큰 검은 눈동자와 둥근 반사광 하나, 윗눈꺼풀 자리에 짙은 굵은 선(덮개),
## 눈썹은 이마에 반쯤 박힌 납작한 짙은 막대로 코 쪽이 내려간 모양(노려보는 표정),
## 보통 입은 살짝 내려간 입꼬리(찡그림), 화난 입에는 아랫니가 보인다.
static func _face(g: CharGeo, F: Dictionary) -> void:
	var keep_line := g.line
	g.line = 0.0
	var hc: Vector3 = F.hc
	var hr: Vector3 = F.hr
	var es: float = F.es
	var ey: float = F.eye_y
	var skin: Color = F.skin
	var ew: float = F.get("eye_w", 1.0)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var ex: float = float(F.eye_dx) * side
		var ez := CharGeo.surf_z(hc, hr, ex, ey)
		# 감은 눈 선(눈알 뒤에 숨어 있다가 눈알을 누르면 보인다)
		g.use("Head")
		var lash: Array = []
		for i in 3:
			var u := float(i) - 1.0
			var lx := ex + u * es * 0.85
			var ly := ey - es * (0.32 - 0.27 * u * u)
			lash.append(Vector3(lx, ly, CharGeo.surf_z(hc, hr, lx, ly) - es * 0.05))
		g.sweep(lash, es * 0.15, F.get("lash", F.pupil), 3)
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez + es * 0.3))
		g.use("Eye" + sfx)
		# 흰자(매끈한 분할)
		var ec := Vector3(ex, ey, ez + es * 0.3)
		var er := Vector3(es * ew, es * 1.25, es * 0.6)
		g.ellipsoid(ec, er, F.get("sclera", Color("fbfbf7")), 12, 6)
		# 윗눈꺼풀 선: 흰자보다 조금 큰 짙은 덮개가 눈 위쪽 2할을 덮는다
		g.ellipsoid(ec + Vector3(0, 0, es * 0.01), er * Vector3(1.05, 1.04, 1.06), F.eye_rim, 12, 2, Basis.IDENTITY, PI * 0.29, PI * 0.29)
		# 아랫눈꺼풀 선(가는 짙은 테)
		g.ellipsoid(ec + Vector3(0, 0, es * 0.01), er * Vector3(1.04, 1.03, 1.05), F.eye_rim, 12, 1, Basis.IDENTITY, PI, PI, PI * 0.86)
		# 큰 검은 눈동자(홍채)와 둥근 반사광 하나
		var pc := Vector3(ex - side * es * 0.06, ey - es * 0.06, ez - es * 0.26)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		var ir: float = F.get("iris", 1.0)
		g.ellipsoid(pc, Vector3(es * 0.64 * ir, es * 0.8 * ir, es * 0.3), F.pupil, 12, 5)
		g.sphere(Vector3(pc.x + es * 0.2, pc.y + es * 0.27, ez - es * 0.55), es * 0.2, Color.WHITE, 6, 3)
		# 윗눈꺼풀: 아래 반구 덮개. 뼈(눈 위쪽)에서 Y 크기를 키우면 내려와 눈을 덮는다.
		var lid_p := Vector3(ex, ey + es * 1.3, ez + es * 0.1)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.24, es * 2.7, es * 0.9), F.get("lid", skin.darkened(0.06)), 6, 3, Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹: 눈 바로 위 이마에 반쯤 박힌 납작한 짙은 막대. 바깥쪽이 높고 코 쪽이 내려간다(노려봄)
		var by := ey + es * 1.0
		var bz := CharGeo.surf_z(hc, hr, ex, by)
		g.add_bone("Brow" + sfx, "Head", Vector3(ex, by, bz))
		g.use("Brow" + sfx)
		var bw: float = es * 1.05 * float(F.get("brow_w", 1.0))
		var bt: float = es * 0.3 * float(F.get("brow_t", 1.0))
		var brow: Array = []
		var brow_r: Array = []
		for i in 4:
			var t := float(i) / 3.0
			var x := ex + side * lerpf(-bw * 0.85, bw, t)
			var y := lerpf(by - es * 0.3, by + es * 0.2, t)
			brow.append(Vector3(x, y, CharGeo.surf_z(hc, hr, x, y) + bt * 0.2))
			brow_r.append(bt)
		g.spline_tube(brow, brow_r, F.brow, 5, true, true, Vector3.FORWARD, 0.45, 1.0)
	# 입
	var my: float = F.mouth_y
	var mw: float = F.mouth_w
	var mz := CharGeo.surf_z(hc, hr, 0.0, my)
	var dark := Color("3d1a22")
	g.add_bone("MouthN", "Head", Vector3(0, my, mz))
	g.use("MouthN")
	var pts: Array = []
	for i in 5:
		var u := float(i) / 2.0 - 1.0
		var x := u * mw * 0.5
		var y := my - u * u * mw * 0.1 + absf(u) * mw * 0.02
		pts.append(Vector3(x, y, CharGeo.surf_z(hc, hr, x, y) - mw * 0.04))
	g.sweep(pts, mw * 0.075, dark, 4)
	g.add_bone("MouthA", "Head", Vector3(0, my, mz))
	g.use("MouthA")
	g.ellipsoid(Vector3(0, my - mw * 0.02, mz + mw * 0.08), Vector3(mw * 0.46, mw * 0.27, mw * 0.2), dark, 8, 4)
	g.ellipsoid(Vector3(0, my - mw * 0.2, mz - mw * 0.02), Vector3(mw * 0.34, mw * 0.07, mw * 0.12), Color.WHITE, 6, 3)
	g.add_bone("MouthH", "Head", Vector3(0, my, mz))
	g.use("MouthH")
	g.ellipsoid(Vector3(0, my - mw * 0.03, mz + mw * 0.05), Vector3(mw * 0.2, mw * 0.22, mw * 0.14), dark, 6, 3)
	g.use("Head")
	g.line = keep_line


# ------------------------------------------------------------------ 망치

## 쉬는 자세(pose_idle)에서 오른손 뼈가 도는 만큼 미리 되돌린 틀. 이 틀 기준으로 망치를 그리면 쉬는 자세에서 설계한 방향 그대로 보인다.
## (허리 -0.03, 위팔 x 0.06 z 0.1, 아래팔 0.3 — character_rig.pose_idle 의 고블린 값)
static func _idle_hand_basis() -> Basis:
	var r := Basis.from_euler(Vector3(-0.03, 0, 0)) * Basis.from_euler(Vector3(0.06, 0, 0.1)) * Basis.from_euler(Vector3(0.3, 0, 0))
	return r.inverse()


## 망치(오른손). 0 = 작은 나무 망치, 1 = 큰 두손 돌망치(긴 자루, 머리가 발 옆 땅 가까이 쉰다), 2 = 중간 쇠망치.
## 자루는 주먹에서 아래로, 바깥쪽(그리고 0·2 는 뒤쪽)으로 살짝 기울여 쥔다: 맞는 자세(팔이 앞·바깥으로 들림)에서 망치 머리가
## 가슴 앞을 가리지 않고 엉덩이 옆에 오고, 걷기·망치질에서는 얼굴 아래(허리·무릎 높이)에 머문다. 돌려주는 값 = 망치 머리(def.tip)
static func _hammer(g: CharGeo, v: int, hand: Vector3) -> Vector3:
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var ib := _idle_hand_basis()
	var d_w := Vector3(0.26, -0.93, 0.26) if v != 1 else Vector3(0.34, -0.94, 0.0)
	var d := (ib * d_w.normalized()).normalized()                                 # 자루 방향(주먹 → 머리)
	var perp := (ib * d_w.cross(Vector3.RIGHT).normalized()).normalized()         # 머리의 긴 축(쉬는 자세에서 수평)
	var side := perp.cross(d).normalized()
	var bas := Basis(side, perp, d)
	var end: Vector3
	match v:
		0:
			end = hand + d * 0.19
			g.tube(hand - d * 0.05, end, 0.014, 0.015, WOOD, 6, true)
			g.sweep([hand - d * 0.02, hand + d * 0.02], 0.016, LEATHER, 5)
			g.tube(end - perp * 0.07, end + perp * 0.07, 0.042, 0.042, WOOD, 10, true)
			g.tube(end - perp * 0.072, end - perp * 0.05, 0.045, 0.045, WOOD_DARK, 8, true)
			g.tube(end + perp * 0.05, end + perp * 0.072, 0.045, 0.045, WOOD_DARK, 8, true)
			g.tube(end - perp * 0.012, end + perp * 0.012, 0.045, 0.045, BRASS_DARK, 8, true)
		1:
			# 건설형: 머리 너비만 한 네모난 돌 머리(가죽 띠로 묶고 양 끝은 밝은 돌), 주먹 위로 길게 솟은 두손 자루
			end = hand + d * 0.195
			g.tube(hand - d * 0.11, end + d * 0.02, 0.017, 0.019, WOOD, 6, true)
			g.sweep([hand - d * 0.035, hand + d * 0.035], 0.02, LEATHER, 5)
			g.sweep([hand - d * 0.1, hand - d * 0.07], 0.02, LEATHER, 5)
			g.rounded_box(end, Vector3(0.084, 0.14, 0.084), STONE, 0.3, 8, 5, bas)
			g.tube(end - perp * 0.032, end + perp * 0.032, 0.089, 0.089, LEATHER_LIGHT, 8, false)
			g.tube(end - perp * 0.14, end - perp * 0.108, 0.086, 0.08, STONE_LIGHT, 8, true)
			g.tube(end + perp * 0.108, end + perp * 0.14, 0.086, 0.08, STONE_LIGHT, 8, true)
			g.sphere(hand - d * 0.115, 0.014, BRASS, 4, 3)
		_:
			end = hand + d * 0.19
			g.tube(hand - d * 0.05, end + d * 0.01, 0.015, 0.016, WOOD, 6, true)
			g.sweep([hand - d * 0.02, hand + d * 0.02], 0.017, LEATHER, 5)
			g.rounded_box(end, Vector3(0.05, 0.078, 0.05), IRON, 0.36, 8, 5, bas)
			g.tube(end - perp * 0.08, end - perp * 0.06, 0.052, 0.049, IRON_LIGHT, 8, true)
			g.tube(end + perp * 0.06, end + perp * 0.08, 0.052, 0.049, IRON_LIGHT, 8, true)
	g.measure = true
	g.measure_all = true
	return end
