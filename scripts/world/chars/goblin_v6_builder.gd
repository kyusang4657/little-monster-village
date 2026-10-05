class_name GoblinV6Builder
extends RefCounted
## 고블린 일꾼 3종의 6차 교체 후보(디자인은 5차 GoblinBuilder 그대로, 만드는 방식만 악마형 Lv.1 방식).
## 머리 = 조각 구 한 장(눈두덩 패임·눈썹 능선·넓은 볼·큰 둥근 코·주걱턱 아랫입술이 한 면에 이어진다),
## 몸통 = 회전체 한 장(목 → 어깨 → 가슴 → 벨트 → 바지 엉덩이), 조끼 = 앞이 V 자로 열린 회전체, 팔·다리 = 몸속에서 시작하는 이어진 관.
## 0 일반 = 이마의 놋쇠 고글 + 작은 나무 망치, 1 건설형 = 같은 고글 + 큰 두손 돌망치·벨트 주머니·가죽 어깨받이,
## 2 방어탑 조작수 = 놋쇠 테 두른 짙은 쇠 투구(뿔 둘·마름모 문장) + 중간 쇠망치. with_hammer = false 면 망치 없음.
## 뼈 이름·기준점·정면 -Z·EarL/EarR 뼈는 5차와 같아 CharacterRig 의 자세·표정·깜빡임·귀 펄럭임이 그대로 동작한다.

const SKIN := Color("7fbd45")
const SKIN_DARK := Color("5f9c32")
const NOSE := Color("8cc853")
const EAR_IN := Color("d0948a")
const BROW := Color("2a1a10")
const EYE_RIM := Color("1d1613")
const PUPIL := Color("221a1c")
const SCLERA := Color("fbfbf7")
const HAIR := Color("4b2b17")
const VEST := Color("5c3f8e")
const VEST_DARK := Color("3f2a6c")
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
const FANG := Color("ede4c8")
const MOUTH_IN := Color("3d1a22")
const MOUTH_OPEN := Color("3a1a1a")
const STRAP := Color("6b4a2a")

## 골격(5차와 같음: 약 2.8등신, 키 1.0)
const P := {
	ankle = 0.07, knee = 0.195, hip = 0.325, hip_x = 0.082, pelvis = 0.335, spine = 0.395,
	shoulder = 0.555, shoulder_x = 0.17, elbow = 0.44, wrist = 0.325, neck = 0.6, head = 0.645,
	arm_r = 0.038, leg_r = 0.045, foot_len = 0.19,
}
const HC := Vector3(0, 0.812, -0.005)      # 머리 중심
const HR := Vector3(0.2, 0.17, 0.182)    # 머리 기본 타원 반지름(볼·코·턱은 조각으로 더한다)
const ES := 0.048                           # 눈 크기
const EYE_DX := 0.43                        # 눈 방향(머리 타원 공간)
const EYE_DY := 0.05
const NOSE_DIR := Vector3(0, -0.2306, -0.973)   # 코 방향(단위)
const BELT_TOP := 0.392
const BELT_BOT := 0.345

## 몸통 회전체 단면(위 → 아래): y, rx(가로), rz(앞뒤). 조끼·끈·버클은 이 겉면을 따라간다
const BODY_Y := [0.7, 0.64, 0.605, 0.585, 0.56, 0.52, 0.46, 0.405]
const BODY_RX := [0.052, 0.056, 0.064, 0.118, 0.16, 0.172, 0.172, 0.16]
const BODY_RZ := [0.052, 0.054, 0.06, 0.098, 0.126, 0.137, 0.139, 0.132]


static func build(v: int, with_hammer: bool) -> Dictionary:
	var g := DemonGeo.new()
	g.bake = 0.0
	CharGeo.skeleton(g, P)
	_body(g, v)
	_vest(g)
	_arms(g, v)
	_legs(g)
	_head(g, v)
	# 망치(오른손 +X): 자루는 주먹 아래로 앞쪽·바깥으로 기울여 쥔다. 무기는 키·체력 막대 측정에서 뺀다
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


# ------------------------------------------------------------------ 표 보간

## 몸통 단면표에서 높이 y 의 (rx, rz)
static func _body_r(y: float) -> Vector2:
	var n := BODY_Y.size()
	if y >= float(BODY_Y[0]):
		return Vector2(BODY_RX[0], BODY_RZ[0])
	for i in n - 1:
		var a: float = BODY_Y[i]
		var b: float = BODY_Y[i + 1]
		if y <= a and y >= b:
			var t := (a - y) / maxf(a - b, 0.0001)
			return Vector2(lerpf(BODY_RX[i], BODY_RX[i + 1], t), lerpf(BODY_RZ[i], BODY_RZ[i + 1], t))
	return Vector2(BODY_RX[n - 1], BODY_RZ[n - 1])


## 조끼 겉면(몸통 + 두께)의 단면
static func _vest_r(y: float) -> Vector2:
	return _body_r(y) + Vector2(0.011, 0.011) * clampf((0.6 - y) / 0.03, 0.0, 1.0) + Vector2(0.004, 0.004)


## 타원 단면 (rx, rz) 위에서 가로 x 인 앞쪽 점
static func _front(x: float, y: float, r: Vector2, lift: float) -> Vector3:
	var q := sqrt(maxf(1.0 - pow(x / r.x, 2.0), 0.0))
	var nn := Vector3(x / (r.x * r.x), 0.0, -q / r.y).normalized()
	return Vector3(x, y, -r.y * q) + nn * lift


# ------------------------------------------------------------------ 몸통(한 장의 회전체)

## 목(머리 속에서 시작) → 승모근 비탈 → 어깨 → 가슴(초록, 조끼 V 사이로 보인다) → 벨트(한 단 부푼 고리) → 갈색 바지 엉덩이(가랑이에서 닫힘)
static func _body(g: DemonGeo, v: int) -> void:
	var prof: Array = []
	for i in BODY_Y.size():
		var bone := "Neck" if float(BODY_Y[i]) >= 0.6 else "Spine"
		prof.append({y = BODY_Y[i], rx = BODY_RX[i], rz = BODY_RZ[i], bone = bone, col = SKIN})
	# 벨트: 겉면에서 한 단 올라선 띠(같은 높이 고리 둘로 색 경계를 또렷하게)
	prof.append({y = BELT_TOP, rx = 0.17, rz = 0.143, bone = "Pelvis", col = BELT})
	prof.append({y = 0.368, rx = 0.171, rz = 0.144, bone = "Pelvis", col = BELT})
	prof.append({y = BELT_BOT, rx = 0.17, rz = 0.143, bone = "Pelvis", col = BELT})
	prof.append({y = BELT_BOT, rx = 0.162, rz = 0.135, bone = "Pelvis", col = TROUSERS})
	prof.append({y = 0.29, rx = 0.162, rz = 0.135, bone = "Pelvis", col = TROUSERS})
	prof.append({y = 0.235, rx = 0.118, rz = 0.1, bone = "Pelvis", col = TROUSERS})
	prof.append({y = 0.218, rx = 0.06, rz = 0.05, bone = "Pelvis", col = TROUSERS})
	g.lathe(prof, 12, false, true, 0.0, 0.0, func(i: int) -> float: return 0.0 if i < 2 else 1.0)
	# 놋쇠 버클(벨트 앞)
	g.use("Pelvis")
	g.line = 0.5
	var by := (BELT_TOP + BELT_BOT) * 0.5
	g.rounded_box(Vector3(0, by, -0.144), Vector3(0.032, 0.026, 0.008), BRASS, 0.4, 8, 3)
	g.line = 0.0
	g.rounded_box(Vector3(0, by, -0.151), Vector3(0.015, 0.012, 0.004), BRASS_DARK, 0.5, 6, 2)
	g.line = 1.0
	if v == 1:
		# 건설형: 벨트에 매단 연장 주머니(오른쪽 앞), 덮개와 놋쇠 단추
		g.line = 0.6
		g.rounded_box(Vector3(0.128, by - 0.035, -0.105), Vector3(0.04, 0.04, 0.03), LEATHER_LIGHT, 0.4, 6, 3, Basis(Vector3.UP, -0.55))
		g.rounded_box(Vector3(0.13, by - 0.006, -0.108), Vector3(0.043, 0.012, 0.033), LEATHER, 0.4, 6, 2, Basis(Vector3.UP, -0.55))
		g.line = 0.0
		g.sphere(Vector3(0.112, by - 0.024, -0.135), 0.008, BRASS, 6, 3)
		g.line = 1.0


# ------------------------------------------------------------------ 조끼(앞이 열린 회전체)

## 보라 조끼: 몸통보다 조금 큰 회전체인데 앞쪽이 칼라에서 벨트 위 한 점까지 좁아지는 V 자로 열려 초록 가슴이 보인다.
## 열린 가장자리는 짙은 보라 테(이어진 관)로 감싸고, 아랫단은 벨트 위에서 살짝 벌어진다. 가슴을 가로지르는 가죽 끈.
static func _vest(g: DemonGeo) -> void:
	var ys := [0.6, 0.582, 0.56, 0.52, 0.47, 0.43, 0.395]
	var top_w := 0.072
	var bot_w := 0.008
	var segs := 14
	var base := g.v.size()
	var rings: Array = []
	g.use("Spine")
	for i in ys.size():
		var y: float = ys[i]
		var r := _vest_r(y)
		if i == ys.size() - 1:
			r += Vector2(0.008, 0.008)   # 아랫단이 벨트 위로 살짝 벌어진다
		var t := (0.6 - y) / (0.6 - 0.395)
		var hw := lerpf(top_w, bot_w, pow(t, 0.85))
		var gap := asin(clampf(hw / r.x, 0.0, 0.99))
		var ring: Array = []
		var yp: float = ys[maxi(i - 1, 0)]
		var yn: float = ys[mini(i + 1, ys.size() - 1)]
		var rp := _vest_r(yp)
		var rn := _vest_r(yn)
		var dy := yn - yp
		for j in segs + 1:
			var a := gap + (TAU - 2.0 * gap) * float(j) / float(segs)
			var sa := sin(a)
			var ca := cos(a)
			var p := Vector3(sa * r.x, y, -ca * r.y)
			var nr := Vector3(sa / r.x, 0.0, -ca / r.y).normalized()
			var slope := 0.0
			if absf(dy) > 0.00001:
				slope = -((rn.x - rp.x) * absf(sa) + (rn.y - rp.y) * absf(ca)) / dy
			g.line = 0.0 if i == 0 else 1.0
			g._vert(p, (nr + Vector3(0, slope, 0)).normalized(), VEST)
			ring.append(p)
		rings.append(ring)
	for i in ys.size() - 1:
		for j in segs:
			var i0 := base + i * (segs + 1) + j
			var i1 := i0 + segs + 1
			g.tri(i0, i0 + 1, i1)
			g.tri(i0 + 1, i1 + 1, i1)
	g.line = 1.0
	# V 자 가장자리 테(짙은 보라): 열린 양 끝 정점을 잇는 이어진 관(칼라 뒤 목둘레까지 이어진다)
	for k in 2:
		var pts: Array = []
		var radii: Array = []
		for i in rings.size():
			var ring: Array = rings[i]
			var p: Vector3 = ring[0] if k == 0 else ring[segs]
			pts.append(p + Vector3(0, 0, -0.002))
			radii.append(0.0085)
		g.line = 0.5
		g.spline_tube(pts, radii, VEST_DARK, 4, false, true, Vector3.BACK, 1.0, 0.7)
	# 가슴을 가로지르는 가죽 끈: 등 조끼 속에서 올라와 왼쪽 어깨를 넘고 가슴을 비스듬히 가로질러 오른쪽 벨트 속으로 들어간다
	var strap: Array = []
	var strap_r: Array = []
	var rb := _vest_r(0.5)
	strap.append(Vector3(-0.115, 0.49, rb.y * 0.72))
	strap.append(_front(-0.125, 0.545, _vest_r(0.545), 0.006) * Vector3(1, 1, -1))
	strap.append(Vector3(-0.133, 0.602, 0.006))
	strap.append(_front(-0.133, 0.566, _vest_r(0.566), 0.007))
	for i in range(1, 6):
		var t := float(i) / 5.0
		var x := lerpf(-0.133, 0.115, t)
		var y := lerpf(0.566, BELT_TOP - 0.004, t)
		strap.append(_front(x, y, _vest_r(y), 0.007 if i < 5 else -0.004))
	strap.append(_front(0.12, 0.352, _vest_r(0.352), -0.03))
	for i in strap.size():
		strap_r.append(0.014)
	g.line = 0.5
	g.spline_tube(strap, strap_r, STRAP, 4, false, false, Vector3.BACK, 0.35, 1.0)
	g.line = 1.0


# ------------------------------------------------------------------ 팔다리(이어진 관)

## 팔: 몸통 속 깊이 시작해(외곽선 0) 승모근 비탈에 반쯤 잠긴 둥근 어깨(몸통과 겹치는 고리는 외곽선 없음) → 위팔 → 팔꿈치 → 굵어지는 아래팔 → 한 단 올라선 가죽 손목 띠 → 큰 주먹(둥근 끝)
static func _arms(g: DemonGeo, v: int) -> void:
	var bulk := 1.15 if v == 1 else 1.0
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := float(P.shoulder_x) * side
		var arm := "Arm" + sfx
		var fore := "Forearm" + sfx
		var hand := "Hand" + sfx
		var nodes: Array = [
			{p = Vector3(x * 0.45, 0.542, 0.0), r = 0.046 * bulk, bone = arm, col = SKIN, line = 0.0},
			{p = Vector3(x * 0.78, 0.548, 0.0), r = 0.054 * bulk, bone = arm, col = SKIN, line = 0.0},
			{p = Vector3(x * 0.97, 0.532, 0.0), r = 0.055 * bulk, bone = arm, col = SKIN, line = 0.0},
			{p = Vector3(x * 1.03, 0.492, 0.0), r = 0.046 * bulk, bone = arm, col = SKIN, line = 0.35},
			{p = Vector3(x, 0.44, 0.0), r = 0.039, bone = fore, col = SKIN},
			{p = Vector3(x, 0.372, 0.0), r = 0.045, bone = fore, col = SKIN},
			{p = Vector3(x, 0.355, 0.0), r = 0.052, bone = fore, col = LEATHER},
			{p = Vector3(x, 0.33, 0.0), r = 0.053, bone = hand, col = LEATHER},
			{p = Vector3(x, 0.324, 0.0), r = 0.047, bone = hand, col = SKIN},
			{p = Vector3(x, 0.3, -0.008), r = 0.058, bone = hand, col = SKIN},
			{p = Vector3(x, 0.27, -0.014), r = 0.058, bone = hand, col = SKIN},
		]
		g.limb(nodes, 7, Vector3.FORWARD, false, true, 2)
		# 엄지(주먹 안쪽 앞, 반쯤 묻힘)
		g.use(hand)
		g.line = 0.0
		var fc := Vector3(x, 0.27, -0.014)
		g.line = 0.4
		g.ellipsoid(fc + Vector3(-side * 0.046, 0.022, -0.028), Vector3(0.019, 0.026, 0.02), SKIN, 6, 3)
		g.line = 1.0
		if v == 1 and side > 0.0:
			# 건설형: 오른쪽 어깨 가죽 어깨받이(어깨를 감싸는 덮개 + 놋쇠 징)
			g.use(arm)
			g.line = 0.6
			var sc := Vector3(x * 0.98, 0.528, 0.0)
			g.ellipsoid(sc, Vector3(0.07, 0.07, 0.07), LEATHER_LIGHT, 10, 3, Basis(Vector3.BACK, -0.3), PI * 0.5, PI * 0.5)
			g.line = 0.0
			g.sphere(sc + Vector3(0.03, 0.062, 0.0), 0.009, BRASS, 6, 3)
			g.line = 1.0


## 다리: 골반 속에서 시작해 갈색 바지 → 무릎 → 접힌 밝은 장화 윗단 → 장화 목. 발은 발꿈치에서 둥근 앞코까지 한 관(밝은 앞코)
static func _legs(g: DemonGeo) -> void:
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := float(P.hip_x) * side
		var leg := "Leg" + sfx
		var shin := "Shin" + sfx
		var foot := "Foot" + sfx
		var nodes: Array = [
			{p = Vector3(x * 0.9, 0.335, 0.0), r = 0.064, bone = leg, col = TROUSERS, line = 0.0},
			{p = Vector3(x, 0.27, 0.0), r = 0.064, bone = leg, col = TROUSERS},
			{p = Vector3(x, 0.205, 0.0), r = 0.055, bone = leg, col = TROUSERS},
			{p = Vector3(x, 0.178, 0.0), r = 0.054, bone = shin, col = BOOT_TOE},
			{p = Vector3(x, 0.172, 0.0), r = 0.063, bone = shin, col = BOOT_TOE},
			{p = Vector3(x, 0.148, 0.0), r = 0.062, bone = shin, col = BOOT_TOE},
			{p = Vector3(x, 0.142, 0.0), r = 0.054, bone = shin, col = BOOT},
			{p = Vector3(x, 0.09, 0.0), r = 0.056, bone = shin, col = BOOT},
			{p = Vector3(x, 0.065, 0.0), r = 0.058, bone = foot, col = BOOT, line = 0.0},
		]
		g.limb(nodes, 7, Vector3.FORWARD, false, false)
		# 장화 발: 발꿈치(작은 고리)에서 앞코까지, 위아래로 조금 납작한 단면. 바닥은 지면(y 0)
		var fnodes: Array = [
			{p = Vector3(x, 0.05, 0.072), r = 0.022, bone = foot, col = BOOT},
			{p = Vector3(x, 0.054, 0.06), r = 0.046, bone = foot, col = BOOT},
			{p = Vector3(x, 0.057, 0.03), r = 0.06, bone = foot, col = BOOT},
			{p = Vector3(x, 0.056, -0.04), r = 0.062, bone = foot, col = BOOT},
			{p = Vector3(x, 0.054, -0.066), r = 0.062, bone = foot, col = BOOT_TOE},
			{p = Vector3(x, 0.052, -0.098), r = 0.058, bone = foot, col = BOOT_TOE},
		]
		for N: Dictionary in fnodes:
			N.fu = 0.9
			N.fw = 1.12
		g.limb(fnodes, 7, Vector3.UP, true, true, 2)


# ------------------------------------------------------------------ 머리(조각 구 한 장)

## 머리 타원 공간의 방향 d(단위)에 대한 반지름 배수: 깊은 눈구멍·눈썹 능선·넓은 볼·주둥이·큰 둥근 코·주걱턱 아랫입술
static func _hk(d: Vector3) -> float:
	var el := Vector3(-EYE_DX, EYE_DY, -0.89).normalized()
	var er := Vector3(EYE_DX, EYE_DY, -0.89).normalized()
	var k := 1.0
	# 눈두덩(눈 방향으로 패임)
	k -= 0.115 * (DemonGeo.bump(d, el, 0.3) + DemonGeo.bump(d, er, 0.3))
	# 눈썹 능선(눈 위, 조금 바깥)
	k += 0.025 * (DemonGeo.bump(d, Vector3(-0.38, 0.5, -0.78).normalized(), 0.25) + DemonGeo.bump(d, Vector3(0.38, 0.5, -0.78).normalized(), 0.25))
	# 넓은 볼(아래 옆 앞): 5차의 통통한 볼 덩어리를 한 면으로. 아래 얼굴이 머리통보다 넓은 서양배 꼴
	k += 0.2 * (DemonGeo.bump(d, Vector3(-0.78, -0.5, -0.4).normalized(), 0.5) + DemonGeo.bump(d, Vector3(0.78, -0.5, -0.4).normalized(), 0.5))
	# 주둥이·턱 앞
	k += 0.07 * DemonGeo.bump(d, Vector3(0, -0.6, -0.8).normalized(), 0.38)
	# 코 뿌리 살(코 덩어리가 얼굴에서 자라 나오도록 둔덕을 깐다)
	k += 0.07 * DemonGeo.bump(d, NOSE_DIR, 0.2)
	# 주걱턱 아랫입술: 입 아래 가로로 긴 둔덕
	if d.z < 0.0:
		k += 0.045 * exp(-pow(d.x / 0.3, 2.0) - pow((d.y + 0.72) / 0.075, 2.0)) * minf(-d.z * 2.0, 1.0)
	# 뒤통수는 둥글게
	k += 0.02 * DemonGeo.bump(d, Vector3(0, 0.15, 1.0).normalized(), 0.7)
	return k


## 방향 d 의 머리 겉면 점
static func _hp(d: Vector3) -> Vector3:
	var dn := d.normalized()
	return HC + Vector3(dn.x * HR.x, dn.y * HR.y, dn.z * HR.z) * _hk(dn)


## 앞 얼굴의 (u, w) = 머리 타원 공간 가로·세로 좌표로 방향을 만든다(앞 = -Z)
static func _fd(u: float, w: float) -> Vector3:
	return Vector3(u, w, -sqrt(maxf(1.0 - u * u - w * w, 0.02))).normalized()


## 조각 구(DemonGeo.sculpt 와 같은 식)인데 얼굴 쪽(앞·적도)에 분할을 모은다: 같은 삼각형 수로 코·눈두덩을 더 매끈하게
static func _sculpt_dense(g: DemonGeo, ce: Vector3, r: Vector3, segs: int, rings: int, shape: Callable, col_of: Callable) -> void:
	var base := g.v.size()
	for i in rings + 1:
		var t := float(i) / float(rings)
		var lat := PI * t + 0.15 * sin(TAU * t)
		for j in segs + 1:
			var s := float(j) / float(segs)
			var lon := TAU * s - 0.5 * sin(TAU * s)
			var p := DemonGeo._sculpt_p(r, lat, lon, shape)
			var nn: Vector3
			if i == 0:
				nn = Vector3.UP
			elif i == rings:
				nn = Vector3.DOWN
			else:
				var pa := DemonGeo._sculpt_p(r, lat + 0.01, lon, shape) - DemonGeo._sculpt_p(r, lat - 0.01, lon, shape)
				var pb := DemonGeo._sculpt_p(r, lat, lon + 0.01, shape) - DemonGeo._sculpt_p(r, lat, lon - 0.01, shape)
				nn = pb.cross(pa).normalized()
				if nn.dot(p) < 0.0:
					nn = -nn
			g._vert(ce + p, nn, col_of.call(p.normalized(), p))
	for i in rings:
		for j in segs:
			var a := base + i * (segs + 1) + j
			var b := a + 1
			var d := a + segs + 1
			var e := d + 1
			if i > 0:
				g.tri(a, b, d)
			if i < rings - 1:
				g.tri(b, e, d)


static func _head(g: DemonGeo, v: int) -> void:
	g.use("Head")
	var shape := func(d: Vector3) -> float: return _hk(d)
	var col_of := func(d: Vector3, _p: Vector3) -> Color:
		# 코 뿌리 둔덕은 코 색으로 부드럽게 물든다(코 덩어리와 이음새가 보이지 않게)
		return SKIN.lerp(NOSE, DemonGeo.bump(d, NOSE_DIR, 0.12))
	_sculpt_dense(g, HC, HR, 22, 14, shape, col_of)
	_nose(g)
	_face(g)
	_ears(g)
	match v:
		0:
			_hair(g, 3, 0.1)
			_goggles(g)
		1:
			_hair(g, 4, 0.115)
			_goggles(g)
		_:
			_helmet(g)


## 큰 둥근 코: 코 뿌리 둔덕 속(외곽선 0)에서 앞·아래로 자라 둥근 끝으로 닫히는 짧은 관(구를 붙이지 않는다)
static func _nose(g: DemonGeo) -> void:
	g.use("Head")
	var s0 := _hp(NOSE_DIR)
	var dn := (NOSE_DIR + Vector3(0, -0.15, 0)).normalized()
	var nodes: Array = [
		{p = s0 - dn * 0.02, r = 0.026, bone = "Head", col = NOSE, line = 0.0},
		{p = s0 + dn * 0.004, r = 0.032, bone = "Head", col = NOSE, line = 0.0},
		{p = s0 + dn * 0.022, r = 0.04, bone = "Head", col = NOSE, line = 0.25},
		{p = s0 + dn * 0.036, r = 0.039, bone = "Head", col = NOSE, line = 0.25},
	]
	g.limb(nodes, 10, Vector3.UP, false, true, 3)


## 얼굴 겉면을 따라가는 띠(입속·이빨 줄): u0..u1 을 n 등분해 위 가장자리 w_top(u)·아래 가장자리 w_bot(u) 를
## 겉면에서 lift 만큼 띄워 잇는다(앞면만). 납작한 다각형과 달리 둥근 주둥이를 따라 휘므로 입꼬리가 머리 속으로 파묻히지 않는다.
static func _face_band(g: DemonGeo, u0: float, u1: float, n: int, w_top: Callable, w_bot: Callable, lift: float, col: Color) -> void:
	var base := g.v.size()
	for i in n + 1:
		var u := lerpf(u0, u1, float(i) / float(n))
		var wt: float = w_top.call(u)
		var wb: float = w_bot.call(u)
		for w: float in [wt, wb]:
			var d := _fd(u, w)
			var nn := Vector3(d.x / HR.x, d.y / HR.y, d.z / HR.z).normalized()
			g._vert(_hp(d) + nn * lift, nn, col)
	for i in n:
		var a := base + i * 2
		g.tri(a, a + 1, a + 2)
		g.tri(a + 1, a + 3, a + 2)


## 입선: 얼굴 겉면을 따라 휘는 굵은 짙은 관(가운데 굵고 입꼬리로 갈수록 가늘다). w_of(u) = 입선 높이
static func _mouth_line(g: DemonGeo, uw: float, cnt: int, w_of: Callable, r: float) -> void:
	var pts: Array = []
	var radii: Array = []
	for i in cnt:
		var u := uw * (float(i) / float(cnt - 1) * 2.0 - 1.0)
		var w: float = w_of.call(u)
		var d := _fd(u, w)
		var nn := Vector3(d.x / HR.x, d.y / HR.y, d.z / HR.z).normalized()
		pts.append(_hp(d) + nn * 0.002)
		var t := absf(u) / uw
		radii.append(r * (0.55 if t > 0.99 else (0.92 if t > 0.6 else 1.0)))
	g.spline_tube(pts, radii, MOUTH_IN, 4, true, true, Vector3.UP)


## 윗니 줄: 입선 바로 아래에 매달린 뼈색 띠, 아래 가장자리가 톱니(이빨 n/2 개). w_line(u) = 입선 높이
static func _upper_teeth(g: DemonGeo, uw: float, n: int, w_line: Callable, lift: float) -> void:
	var top := func(u: float) -> float: return float(w_line.call(u)) - 0.02
	var bot := func(u: float) -> float:
		var i := roundf((u / uw + 1.0) * 0.5 * float(n))
		return float(w_line.call(u)) - 0.02 - (0.058 if int(i) % 2 == 1 else 0.026)
	_face_band(g, -uw, uw, n, top, bot, lift, FANG)


## 아랫니 송곳니 둘(이가 매달린 입 뼈에 붙어 표정과 함께 바뀐다): 아랫입술 속에 뿌리를 두고 위·바깥으로 기울어 솟는 납작한 삼각 기둥.
## u = 입꼬리 쪽 가로 위치, w = 뿌리 높이, h = 높이(보통 입에서는 코 높이의 1/3 쯤), 끝이 입선 위로 올라온다
static func _fangs(g: DemonGeo, u: float, w: float, h: float) -> void:
	var keep_line := g.line
	g.line = 0.4
	for side: float in [-1.0, 1.0]:
		var d := _fd(u * side, w)
		var nn := Vector3(d.x / HR.x, d.y / HR.y, d.z / HR.z).normalized()
		var root := _hp(d) + nn * 0.006
		# 위로 서되 겉면 앞쪽(nn.z)으로만 조금 기울고 바깥으로는 살짝만 기운다(입꼬리의 겉면 법선은 옆을 보므로 그대로 쓰면 누워 버린다)
		var ey := (Vector3.UP + Vector3(0, 0, nn.z) * 0.12 + Vector3.RIGHT * side * 0.08).normalized()
		var ez := Vector3.RIGHT.cross(ey).normalized()
		var ex := ey.cross(ez).normalized()
		var hw := h * 0.42
		g.polygon(PackedVector2Array([Vector2(-hw, -h * 0.2), Vector2(hw, -h * 0.2), Vector2(hw * 0.15 * side, h)]),
			root, Basis(ex, ey, ez), h * 0.4, FANG, FANG.darkened(0.12))
	g.line = keep_line


## 커다란 나뭇잎꼴 뾰족 귀: 머리 속(외곽선 0)에서 바깥·위로 뻗고 끝이 살짝 들린다. 앞뒤로 납작, 앞면 안쪽은 분홍. EarL/EarR 뼈(2차 움직임)
static func _ears(g: DemonGeo) -> void:
	g.measure = false
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var base := Vector3(0.15 * side, HC.y + 0.02, 0.005)
		g.add_bone("Ear" + sfx, "Head", Vector3(0.175 * side, HC.y + 0.02, 0.005))
		g.use("Ear" + sfx)
		var dir := Vector3(side, 0.28, 0.12).normalized()
		var L := 0.33
		var prof := [0.045, 0.066, 0.07, 0.054, 0.03, 0.012]
		var nodes: Array = []
		var inner: Array = []
		var inner_r: Array = []
		for i in prof.size():
			var t := float(i) / float(prof.size() - 1)
			var p := base + dir * (L * t) + Vector3(0, 0.06 * t * t, 0.03 * t * t)
			nodes.append({p = p, r = prof[i], bone = "Ear" + sfx, col = SKIN, line = 0.0 if i == 0 else 1.0, fu = 1.0, fw = 0.3})
			if i >= 2 and i <= 4:
				inner.append(p + Vector3(0, -0.003, -0.012) + dir * 0.012)
				inner_r.append(float(prof[i]) * 0.62)
		g.limb(nodes, 6, Vector3.UP, false, true, 1)
		g.line = 0.0
		inner.append((inner[inner.size() - 1] as Vector3) + dir * 0.05)
		inner_r.append(0.0)
		g.spline_tube(inner, inner_r, EAR_IN, 4, true, true, Vector3.UP, 1.0, 0.22)
		g.line = 1.0
	g.measure = true
	g.use("Head")


## 정수리의 짙은 갈색 뾰족 머리털 n 가닥(앞은 앞으로, 뒤는 뒤로 휜다)과 옆머리 한 가닥씩. 뿌리는 머리 속
static func _hair(g: DemonGeo, n: int, L: float) -> void:
	g.measure = false
	g.use("Head")
	for i in n:
		var t := (float(i) / float(n - 1) - 0.5) * 2.0
		var d := Vector3(0, 1.0, t * 0.5 + 0.1).normalized()
		var base := _hp(d) - Vector3(0, 0.03, 0)
		var dir := Vector3(0, 1, t * 0.4 + 0.05).normalized()
		g.horn(base, dir, Vector3(0, 0, t * 0.6), L * (1.0 - absf(t) * 0.2) + 0.03, 0.04, HAIR, 3, 5)
	for side: float in [-1.0, 1.0]:
		var base := _hp(Vector3(0.45 * side, 0.85, 0.1)) - Vector3(0.02 * side, 0.02, 0)
		g.horn(base, Vector3(side * 0.8, 1, 0.1).normalized(), Vector3(side * 0.6, 0, 0), L * 0.6 + 0.02, 0.026, HAIR, 2, 5)
	g.measure = true


## 놋쇠 둥근 고글(이마 위): 머리 겉면을 두르는 가죽 띠(앞이 높은 비스듬한 띠, 겉면을 따라 이어진 관) 위에 둥근 렌즈 통 둘(연파랑 렌즈·반사광)과 가운데 다리
static func _goggles(g: DemonGeo) -> void:
	g.use("Head")
	# 가죽 띠: 머리 둘레를 도는 닫힌 고리. 앞(이마) 위도 0.62, 뒤 0.25 높이로 기울어 정수리 쪽 머리털 앞을 지난다
	var band: Array = []
	var band_r: Array = []
	var nb := 10
	for i in nb + 1:
		var lon := TAU * float(i) / float(nb)
		var fw := (1.0 + cos(lon)) * 0.5
		var wy := lerpf(0.3, 0.74, fw)
		var horiz := sqrt(1.0 - wy * wy)
		var d := Vector3(sin(lon) * horiz, wy, -cos(lon) * horiz)
		band.append(_hp(d) + d * 0.004)
		band_r.append(0.012)
	g.line = 0.5
	g.spline_tube(band, band_r, LEATHER, 4, false, false, Vector3.UP, 0.5, 1.4)
	var cups: Array = []
	for side: float in [-1.0, 1.0]:
		var d := _fd(0.42 * side, 0.74)
		var p := _hp(d)
		# 렌즈는 겉면 법선보다 조금 더 앞을 본다(정면에서도 파란 렌즈가 보이게)
		var nn := (d * 0.55 + Vector3(0.05 * side, 0.1, -0.9)).normalized()
		cups.append(p)
		var r := 0.052
		var nodes: Array = [
			{p = p - nn * 0.012, r = r * 0.92, bone = "Head", col = BRASS, line = 0.0},
			{p = p + nn * 0.012, r = r, bone = "Head", col = BRASS, line = 0.6},
			{p = p + nn * 0.034, r = r * 1.08, bone = "Head", col = BRASS_DARK},
			{p = p + nn * 0.046, r = r * 1.06, bone = "Head", col = BRASS_DARK},
			{p = p + nn * 0.048, r = r * 0.86, bone = "Head", col = BRASS_DARK},
		]
		g.limb(nodes, 8, Vector3.UP, false, false)
		g.line = 0.0
		var lx := Vector3.UP.cross(nn).normalized()
		var lb := Basis(lx, nn, lx.cross(nn).normalized())
		g.ellipsoid(p + nn * 0.04, Vector3(r * 0.86, 0.012, r * 0.86), LENS, 10, 2, lb)
		g.ellipsoid(p + nn * 0.051 + lb * Vector3(-r * 0.32, 0, -r * 0.32), Vector3(r * 0.2, 0.004, r * 0.2), LENS_LIGHT, 6, 1, lb)
		g.line = 1.0
	# 가운데 다리(렌즈 통 사이)
	var c0: Vector3 = cups[0]
	var c1: Vector3 = cups[1]
	var mid := _hp(_fd(0.0, 0.76)) + Vector3(0, 0, -0.012)
	g.line = 0.5
	g.spline_tube([c0 + Vector3(0.04, 0, -0.01), mid, c1 + Vector3(-0.04, 0, -0.01)], [0.012, 0.013, 0.012], BRASS_DARK, 6, true, true)
	g.line = 1.0


## 투구 껍질(한 장): 돔(앞 위도 lat_f, 뒤 lat_b 까지) 아래 가장자리에서 바깥으로 말린 놋쇠 테가 같은 면으로 이어진다.
## 행 = [위도 비율, 반지름 배수, 색]. 법선은 격자 이웃 차이로 계산해 매끈하다.
static func _shell(g: DemonGeo, ce: Vector3, r: Vector3, lat_f: float, lat_b: float, segs: int, rows: Array) -> void:
	var base := g.v.size()
	var grid: Array = []
	for i in rows.size():
		var R: Array = rows[i]
		var row: Array = []
		for j in segs + 1:
			var lon := TAU * float(j) / float(segs)
			var fw := (1.0 + cos(lon)) * 0.5
			var lat := lerpf(lat_b, lat_f, fw) * float(R[0])
			var dir := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
			row.append(ce + Vector3(dir.x * r.x, dir.y * r.y, dir.z * r.z) * float(R[1]))
		grid.append(row)
	for i in rows.size():
		var R: Array = rows[i]
		var keep := g.line
		g.line = float(R[3]) if R.size() > 3 else 1.0
		for j in segs + 1:
			var p: Vector3 = grid[i][j]
			var nn: Vector3
			if i == 0:
				nn = Vector3.UP
			else:
				var du: Vector3 = (grid[i][mini(j + 1, segs)] as Vector3) - (grid[i][maxi(j - 1, 0)] as Vector3)
				if j == 0 or j == segs:
					du = (grid[i][1] as Vector3) - (grid[i][segs - 1] as Vector3)
				var dt: Vector3 = (grid[mini(i + 1, rows.size() - 1)][j] as Vector3) - (grid[maxi(i - 1, 0)][j] as Vector3)
				nn = du.cross(dt).normalized()
				var out := p - ce
				out.y *= 0.3
				if nn.dot(out) < 0.0:
					nn = -nn
			g._vert(p, nn, R[2])
		g.line = keep
	for i in rows.size() - 1:
		for j in segs:
			var a := base + i * (segs + 1) + j
			var d := a + segs + 1
			if i > 0:
				g.tri(a, a + 1, d)
			g.tri(a + 1, d + 1, d)


## 방어탑 조작수 투구: 짙은 쇠 돔(가운데 세로 이음 띠) + 바깥으로 말린 놋쇠 테(한 장의 껍질), 테의 징, 앞 마름모 문장,
## 놋쇠 고리에서 솟는 두툼한 황갈색 뿔 둘(첫 마디는 돔 겉면 법선 방향), 정수리 놋쇠 징. 고글 없음
static func _helmet(g: DemonGeo) -> void:
	g.use("Head")
	var hc := HC + Vector3(0, 0.014, 0.004)
	var hr := Vector3(HR.x * 1.12, HR.y * 1.1, HR.z * 1.12)
	var lat_f := PI * 0.32
	var lat_b := PI * 0.56
	var rows: Array = [
		[0.0, 1.0, HELMET], [0.35, 1.0, HELMET], [0.65, 1.0, HELMET], [0.88, 1.0, HELMET],
		[0.97, 1.005, HELMET], [0.985, 1.03, BRASS], [1.075, 1.08, BRASS], [1.15, 1.03, BRASS_DARK], [1.15, 0.95, BRASS_DARK, 0.0],
	]
	_shell(g, hc, hr, lat_f, lat_b, 16, rows)
	# 돔 가운데 세로 이음 띠(앞뒤로 지나는 짙은 쇠 띠, 끝은 테 속)
	g.line = 0.4
	var seam: Array = []
	var seam_r: Array = []
	for i in 7:
		var lat := lerpf(-lat_f * 0.95, lat_b * 0.95, float(i) / 6.0)
		seam.append(hc + Vector3(0, cos(lat) * hr.y, sin(lat) * hr.z) * 1.006)
		seam_r.append(0.011)
	g.spline_tube(seam, seam_r, HELMET_DARK, 4, false, false, Vector3.RIGHT, 1.0, 0.45)
	# 테의 징(옆 넷)
	g.line = 0.0
	for lon: float in [0.75, 1.55, TAU - 1.55, TAU - 0.75]:
		var fw := (1.0 + cos(lon)) * 0.5
		var lat := lerpf(lat_b, lat_f, fw) * 1.04
		var d := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
		g.ellipsoid(hc + Vector3(d.x * hr.x, d.y * hr.y, d.z * hr.z) * 1.08, Vector3(0.011, 0.011, 0.011), BRASS_DARK, 5, 2)
	# 앞 마름모 문장과 흰 보석(돔 겉면에 기울여 붙인다)
	var lat_e := lat_f * 0.82
	var ep := hc + Vector3(0, cos(lat_e) * hr.y, -sin(lat_e) * hr.z)
	var nn := Vector3(0, cos(lat_e) / hr.y, -sin(lat_e) / hr.z).normalized()
	var bas := Basis(Vector3.RIGHT, nn.cross(Vector3.RIGHT).normalized(), nn)
	g.line = 0.5
	g.polygon(PackedVector2Array([Vector2(0, 0.046), Vector2(-0.038, 0), Vector2(0, -0.046), Vector2(0.038, 0)]), ep + nn * 0.004, bas, 0.012, BRASS, BRASS_DARK)
	g.line = 0.0
	g.ellipsoid(ep + nn * 0.012, Vector3(0.015, 0.015, 0.009), Color("f4efe6"), 6, 3, bas)
	g.line = 1.0
	# 뿔: 놋쇠 고리 속에서 돔 법선 방향으로 나와 위·바깥으로 자라며 끝이 안쪽으로 굽는다. 키 측정에서 뺀다
	g.measure = false
	for side: float in [-1.0, 1.0]:
		var hd := Vector3(0.5 * side, 0.8, -0.3).normalized()
		var root := hc + Vector3(hd.x * hr.x, hd.y * hr.y, hd.z * hr.z)
		var hn := Vector3(hd.x / hr.x, hd.y / hr.y, hd.z / hr.z).normalized()
		g.line = 0.6
		var ax := hn.cross(Vector3.BACK).normalized()
		g.torus(root + hn * 0.006, 0.03, 0.009, BRASS_DARK, 8, 3, Basis(ax, hn, ax.cross(hn).normalized()))
		var p0 := root - hn * 0.02
		var p1 := root + hn * 0.06
		var p2 := root + Vector3(0.07 * side, 0.15, 0.0)
		var p3 := root + Vector3(0.03 * side, 0.21, 0.01)
		var nodes: Array = []
		var n := 5
		for i in n + 1:
			var t := float(i) / float(n)
			var r := 0.036 * pow(1.0 - t, 0.8) + 0.002
			var col: Color = HORN.lerp(HORN_TIP, clampf((t - 0.55) / 0.45, 0.0, 1.0))
			nodes.append({p = DemonGeo.bez(p0, p1, p2, p3, t), r = r, bone = "Head", col = col, line = 0.0 if i == 0 else 1.0})
		g.limb(nodes, 7, Vector3.BACK, false, true, 0)
	g.line = 0.0
	g.ellipsoid(hc + Vector3(0, hr.y * 1.0, 0.0), Vector3(0.017, 0.012, 0.017), BRASS, 6, 2)
	g.line = 1.0
	g.measure = true


# ------------------------------------------------------------------ 얼굴

## 눈(눈구멍에 들어앉은 납작한 흰 눈알(앞면이 볼과 나란) + 큰 검은 눈동자 + 둥근 반사광, 눈알 윗부분의 짙은 뚜껑), 윗눈꺼풀, 끝이 가는 짙은 눈썹(코 쪽이 내려감), 감은 눈 선, 입 세 가지.
## 뼈 이름은 CharacterRig 의 표정 규약 그대로(EyeL/R, PupilL/R, LidL/R, BrowL/R, MouthN/A/H)
static func _face(g: DemonGeo) -> void:
	var es := ES
	var keep_line := g.line
	g.line = 0.0
	var er := Vector3(es * 1.22, es * 1.42, es * 0.42)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var d := Vector3(EYE_DX * side, EYE_DY, -0.89).normalized()
		var floor_p := _hp(d)
		var ec := floor_p + d * 0.004
		var eb := Basis.looking_at(d, Vector3.UP)
		var ebt := eb * Basis(Vector3.BACK, side * 0.12)
		# 앞을 극으로 둔 틀(정면 윤곽이 경도 분할로 둥글게 나온다): 지역 Y = 바깥(d), 지역 Z = 위
		var ef := ebt * Basis(Vector3.RIGHT, -PI * 0.5)
		# 감은 눈 선(머리 뼈, 눈알 속에 숨어 있다가 눈알을 누르면 보인다): 아래로 볼록한 곡선
		g.use("Head")
		var lash: Array = []
		var lash_r: Array = []
		for i in 5:
			var u := float(i) / 2.0 - 1.0
			var lx := u * er.x * 0.8
			var ly := -er.y * (0.05 + 0.25 * (1.0 - u * u))
			var zz := er.z * sqrt(maxf(1.0 - pow(lx / er.x, 2.0) - pow(ly / er.y, 2.0), 0.0))
			lash.append(ec + ebt * Vector3(lx, ly, -zz * 0.8))
			lash_r.append(es * (0.13 if absf(u) < 0.9 else 0.05))
		g.spline_tube(lash, lash_r, EYE_RIM, 4, false, false)
		g.add_bone("Eye" + sfx, "Head", ec)
		g.use("Eye" + sfx)
		g.ellipsoid(ec, Vector3(er.x, er.z, er.y), SCLERA, 12, 4, ef)
		# 윗부분 짙은 뚜껑(눈알보다 아주 조금 큰 윗 껍질): 굵은 윗눈꺼풀 선
		g.ellipsoid(ec, er * 1.03, EYE_RIM, 14, 2, ebt, PI * 0.28, PI * 0.28, 0.0)
		# 큰 검은 눈동자(앞면에 붙은 납작한 타원, 살짝 안쪽·아래를 본다) + 둥근 반사광
		var pd := Vector3(-side * 0.1, -0.08, -1.0).normalized()
		var pc := ec + ebt * (Vector3(pd.x * er.x, pd.y * er.y, pd.z * er.z) * 0.97)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.ellipsoid(pc, Vector3(es * 0.74, es * 0.16, es * 0.92), PUPIL, 10, 2, ef)
		g.ellipsoid(pc + ebt * Vector3(es * 0.24, es * 0.32, -es * 0.13), Vector3(es * 0.2, es * 0.05, es * 0.2), Color.WHITE, 8, 1, ef)
		# 윗눈꺼풀: 눈알보다 조금 큰 아래로 열린 반구 덮개(피부색). 표정이 Y 크기를 키우면 내려와 덮는다
		var lid_p := ec + ebt * Vector3(0, er.y * 0.96, 0)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(er.x * 1.14, es * 2.6, er.z * 1.12), SKIN.darkened(0.06), 10, 2, ebt * Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹: 짙은 굵은 띠, 바깥쪽이 높고 코 쪽이 내려간다(노려봄). 양 끝은 가늘어져 표정으로 움직여도 눈 속에 박히지 않는다
		var bp := _hp(_fd(0.4 * side, 0.55))
		g.add_bone("Brow" + sfx, "Head", bp)
		g.use("Brow" + sfx)
		var bpts: Array = []
		for q: Vector2 in [Vector2(0.15, 0.43), Vector2(0.26, 0.5), Vector2(0.4, 0.55), Vector2(0.54, 0.57), Vector2(0.66, 0.54)]:
			var dq := _fd(q.x * side, q.y)
			bpts.append(_hp(dq) + Vector3(dq.x / HR.x, dq.y / HR.y, dq.z / HR.z).normalized() * 0.004)
		g.spline_tube(bpts, [0.0, es * 0.36, es * 0.42, es * 0.32, 0.0], BROW, 6, false, false, Vector3.FORWARD, 0.5, 1.0)
	# 입(원화의 넓은 장난기 어린 웃음): 얼굴 너비의 6할을 가로지르는 입꼬리 올라간 굵은 입선 + 그 밑의 짙은 입속 쐐기 + 윗니 줄 + 입꼬리의 큰 아랫니 송곳니 둘.
	# 보통 = 다문 웃음(입속은 얇게 보인다), 벌림(화남·기쁨) = 입속이 아래로 크게 열리고 아랫니 줄이 보인다, 아픔·기절 = 작은 오므린 입. 송곳니는 입 뼈마다 그 입 크기에 맞춰 붙는다
	var mc := _hp(_fd(0.0, -0.61))
	g.add_bone("MouthN", "Head", mc)
	g.use("MouthN")
	var wn := func(u: float) -> float: return -0.6 + 0.09 * u * u
	_mouth_line(g, 0.66, 7, wn, 0.0095)
	var wn_top := func(u: float) -> float: return float(wn.call(u)) - 0.02
	var wn_bot := func(u: float) -> float: return float(wn.call(u)) - 0.02 - 0.12 * pow(maxf(1.0 - pow(u / 0.62, 2.0), 0.0), 0.6)
	_face_band(g, -0.6, 0.6, 8, wn_top, wn_bot, 0.003, MOUTH_OPEN)
	_upper_teeth(g, 0.36, 8, wn, 0.0045)
	_fangs(g, 0.41, -0.668, 0.033)
	g.add_bone("MouthA", "Head", mc)
	g.use("MouthA")
	var wa := func(u: float) -> float: return -0.58 + 0.1 * u * u
	_mouth_line(g, 0.66, 4, wa, 0.0075)
	var wa_top := func(u: float) -> float: return float(wa.call(u)) - 0.02
	var wa_bot := func(u: float) -> float: return float(wa.call(u)) - 0.02 - 0.3 * pow(maxf(1.0 - pow(u / 0.64, 2.0), 0.0), 0.55)
	_face_band(g, -0.62, 0.62, 8, wa_top, wa_bot, 0.003, MOUTH_OPEN)
	_upper_teeth(g, 0.38, 6, wa, 0.0045)
	var wl_top := func(u: float) -> float: return float(wa_bot.call(u)) + 0.06
	var wl_bot := func(u: float) -> float: return float(wa_bot.call(u)) + 0.01
	_face_band(g, -0.42, 0.42, 3, wl_top, wl_bot, 0.004, FANG)
	_fangs(g, 0.43, float(wa_bot.call(0.43)) + 0.012, 0.036)
	g.add_bone("MouthH", "Head", mc)
	g.use("MouthH")
	var dn := _fd(0.0, -0.61)
	var mb := Basis.looking_at(dn, Vector3.UP)
	g.ellipsoid(mc - dn * 0.004, Vector3(0.022, 0.024, 0.012), MOUTH_IN, 6, 2, mb)
	_fangs(g, 0.11, -0.705, 0.016)
	g.use("Head")
	g.line = keep_line


# ------------------------------------------------------------------ 망치

## 쉬는 자세(pose_idle)에서 오른손 뼈가 도는 만큼 미리 되돌린 틀(5차와 같음)
static func _idle_hand_basis() -> Basis:
	var r := Basis.from_euler(Vector3(-0.03, 0, 0)) * Basis.from_euler(Vector3(0.06, 0, 0.1)) * Basis.from_euler(Vector3(0.3, 0, 0))
	return r.inverse()


## 망치(오른손). 0 = 작은 나무 망치, 1 = 큰 두손 돌망치, 2 = 중간 쇠망치. 자루·머리는 이어진 관(둥근 자루 끝·가죽 손잡이 띠는 색 고리).
## 방향·길이는 5차와 같아 망치질 충격 위상(def.tip 최저점 p≈0)이 그대로다. 돌려주는 값 = 망치 머리(def.tip)
static func _hammer(g: DemonGeo, v: int, hand: Vector3) -> Vector3:
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var ib := _idle_hand_basis()
	var d_w := Vector3(0.26, -0.93, 0.26) if v != 1 else Vector3(0.54, -0.62, -0.57)
	var d := (ib * d_w.normalized()).normalized()
	var perp := (ib * d_w.cross(Vector3.RIGHT).normalized()).normalized()
	var side := perp.cross(d).normalized()
	var bas := Basis(side, perp, d)
	var end: Vector3
	var hb := "HandR"
	match v:
		0:
			end = hand + d * 0.19
			g.limb([
				{p = hand - d * 0.055, r = 0.012, bone = hb, col = WOOD_DARK},
				{p = hand - d * 0.045, r = 0.015, bone = hb, col = WOOD},
				{p = hand - d * 0.025, r = 0.015, bone = hb, col = WOOD},
				{p = hand - d * 0.022, r = 0.018, bone = hb, col = LEATHER},
				{p = hand + d * 0.03, r = 0.018, bone = hb, col = LEATHER},
				{p = hand + d * 0.033, r = 0.015, bone = hb, col = WOOD},
				{p = end, r = 0.016, bone = hb, col = WOOD, line = 0.0},
			], 7, side, true, false)
			# 나무 머리: 가운데가 조금 불룩한 통, 양 끝 짙은 테, 가운데 놋쇠 띠
			var hn: Array = []
			var spec := [[-0.072, 0.038, WOOD_DARK], [-0.066, 0.045, WOOD_DARK], [-0.05, 0.045, WOOD], [-0.012, 0.048, BRASS_DARK],
				[0.012, 0.048, BRASS_DARK], [0.05, 0.045, WOOD], [0.066, 0.045, WOOD_DARK], [0.072, 0.038, WOOD_DARK]]
			for s: Array in spec:
				hn.append({p = end + perp * float(s[0]), r = s[1], bone = hb, col = s[2]})
			g.limb(hn, 10, side, true, true)
		1:
			# 건설형: 머리 너비만 한 네모난 돌 머리(가죽 띠로 묶고 양 끝은 밝은 돌), 주먹 위로 길게 솟은 두손 자루
			end = hand + d * 0.195
			g.limb([
				{p = hand - d * 0.12, r = 0.012, bone = hb, col = WOOD_DARK},
				{p = hand - d * 0.11, r = 0.018, bone = hb, col = WOOD},
				{p = hand - d * 0.1, r = 0.021, bone = hb, col = LEATHER},
				{p = hand - d * 0.07, r = 0.021, bone = hb, col = LEATHER},
				{p = hand - d * 0.066, r = 0.018, bone = hb, col = WOOD},
				{p = hand - d * 0.04, r = 0.021, bone = hb, col = LEATHER},
				{p = hand + d * 0.036, r = 0.021, bone = hb, col = LEATHER},
				{p = hand + d * 0.04, r = 0.019, bone = hb, col = WOOD},
				{p = end, r = 0.02, bone = hb, col = WOOD, line = 0.0},
			], 7, side, true, false)
			g.line = 1.0
			g.rounded_box(end, Vector3(0.084, 0.14, 0.084), STONE, 0.3, 8, 5, bas)
			g.line = 0.6
			g.rounded_box(end, Vector3(0.09, 0.034, 0.09), LEATHER_LIGHT, 0.25, 8, 2, bas)
			g.rounded_box(end + perp * 0.122, Vector3(0.088, 0.02, 0.088), STONE_LIGHT, 0.3, 8, 2, bas)
			g.rounded_box(end - perp * 0.122, Vector3(0.088, 0.02, 0.088), STONE_LIGHT, 0.3, 8, 2, bas)
			g.line = 1.0
		_:
			end = hand + d * 0.19
			g.limb([
				{p = hand - d * 0.055, r = 0.012, bone = hb, col = WOOD_DARK},
				{p = hand - d * 0.045, r = 0.016, bone = hb, col = WOOD},
				{p = hand - d * 0.025, r = 0.016, bone = hb, col = WOOD},
				{p = hand - d * 0.022, r = 0.019, bone = hb, col = LEATHER},
				{p = hand + d * 0.03, r = 0.019, bone = hb, col = LEATHER},
				{p = hand + d * 0.033, r = 0.016, bone = hb, col = WOOD},
				{p = end, r = 0.017, bone = hb, col = WOOD, line = 0.0},
			], 7, side, true, false)
			g.rounded_box(end, Vector3(0.05, 0.078, 0.05), IRON, 0.36, 8, 5, bas)
			g.line = 0.6
			g.rounded_box(end + perp * 0.072, Vector3(0.053, 0.012, 0.053), IRON_LIGHT, 0.3, 8, 2, bas)
			g.rounded_box(end - perp * 0.072, Vector3(0.053, 0.012, 0.053), IRON_LIGHT, 0.3, 8, 2, bas)
			g.line = 1.0
	g.measure = true
	g.measure_all = true
	return end
