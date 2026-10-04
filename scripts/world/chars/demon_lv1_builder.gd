class_name DemonLv1Builder
extends RefCounted
## 악마형 마왕 Lv.1 교체 후보(6차, docs/design/concept/sheet-3-demon-king.jpg 의 Lv.1 "기본 형태").
## 붉은 피부의 작은 군주: 둥근 머리(조각 구 한 장: 눈두덩·눈썹 능선·볼·작은 코가 한 면에 이어진다), 짙은 갈색 곡선 뿔(마디 능선이 매끈하게 이어짐),
## 짧은 뾰족 귀, 정수리 불꽃 돌기, 황금색 고양이 눈(눈두덩 속에 앉아 튀어나오지 않음), 짧고 단단한 몸통(회전체 한 장), 어깨에서 손끝까지 이어진 팔,
## 검정·금 테 군주 코트와 금 해골 장식, 버건디 망토·앞치마, 작은 박쥐 날개, 화살촉 꼬리. 왕관·견갑·지팡이(Lv.3~4)는 없다.
## 리그 규약은 기존 뿔이와 같다(뼈 이름·기준점·정면 -Z·Cape 뼈), 그래서 CharacterRig 의 자세·표정·깜빡임·2차 움직임이 그대로 동작한다.
## gray = true 면 형태 확인용 회색(정점 명암 없음).

const SKIN := Color("c6393c")
const SKIN_DEEP := Color("9e2a2f")
const FLAME := Color("d9484e")
const BLUSH := Color("d4585a")
const NOSE := Color("7e2228")
const HORN := Color("3a2824")
const HORN_TIP := Color("5a4036")
const COAT := Color("2c2530")
const COAT_DEEP := Color("1f1a22")
const GOLD := Color("d8a648")
const GOLD_DEEP := Color("a97a2c")
const CAPE := Color("7c1f2e")
const CAPE_IN := Color("46121a")
const BELT := Color("5a1c25")
const BOOT := Color("27202a")
const EYE := Color("f6c63a")
const EYE_SHADE := Color("d79a24")
const PUPIL := Color("1a1013")
const LASH := Color("3a181c")
const BROW := Color("6a1f24")
const LIP := Color("3a1216")
const MOUTH_IN := Color("4a1018")
const WING := Color("7a2231")
const WING_BONE := Color("3a2824")
const GRAY := Color(0.62, 0.62, 0.62)

# 머리 타원 중심·반지름(골격 공간). 눈·코·입·뿔·귀는 모두 이 값에서 계산한다
const HC := Vector3(0, 0.73, -0.005)
const HR := Vector3(0.205, 0.19, 0.195)
const EYE_DIR_X := 0.44
const EYE_DIR_Y := 0.1
const ES := 0.05


static func build(gray: bool = false) -> Dictionary:
	var P := {
		ankle = 0.055, knee = 0.125, hip = 0.215, hip_x = 0.088, pelvis = 0.235, spine = 0.285,
		shoulder = 0.45, shoulder_x = 0.17, elbow = 0.37, wrist = 0.3, neck = 0.51, head = 0.55,
		arm_r = 0.05, leg_r = 0.062, foot_len = 0.16,
	}
	var g := DemonGeo.new()
	g.bake = 0.0
	CharGeo.skeleton(g, P)
	var C := _palette(gray)
	_body(g, P, C)
	_arms(g, P, C)
	_legs(g, P, C)
	_coat_details(g, C)
	_cape_and_wings(g, C)
	_tail(g, C)
	_head(g, C)
	var def := g.build(CharacterRig.character_material())
	# 가리키는 손 = 오른손 끝(주먹 앞)
	def.tip = Vector3(0.195, 0.2, -0.04)
	def.H = 0.8
	def.es = ES
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


## 색표(회색 모드면 모두 같은 회색: 형태만 보인다)
static func _palette(gray: bool) -> Dictionary:
	var names := ["skin", "skin_deep", "flame", "blush", "nose", "horn", "horn_tip", "coat", "coat_deep", "gold", "gold_deep", "cape", "cape_in",
		"belt", "boot", "eye", "eye_shade", "pupil", "lash", "brow", "lip", "mouth_in", "wing", "wing_bone", "white"]
	var cols := [SKIN, SKIN_DEEP, FLAME, BLUSH, NOSE, HORN, HORN_TIP, COAT, COAT_DEEP, GOLD, GOLD_DEEP, CAPE, CAPE_IN,
		BELT, BOOT, EYE, EYE_SHADE, PUPIL, LASH, BROW, LIP, MOUTH_IN, WING, WING_BONE, Color.WHITE]
	var out := {}
	for i in names.size():
		out[names[i]] = GRAY if gray else cols[i]
	if gray:
		# 회색 모드에서도 눈동자·입선은 조금 어둡게 두어 얼굴 위치를 읽을 수 있게 한다
		out.pupil = Color(0.3, 0.3, 0.3)
		out.lip = Color(0.4, 0.4, 0.4)
		out.lash = Color(0.4, 0.4, 0.4)
		out.brow = Color(0.45, 0.45, 0.45)
	return out


# ------------------------------------------------------------------ 몸통(한 장의 회전체) + 코트

## 목에서 엉덩이까지 한 장의 회전체. 목 위 고리는 머리 속에 숨어(외곽선 0) 머리와 이음새 없이 이어진다.
## 코트는 몸통보다 조금 큰 두 번째 회전체(어깨 덮개 → 허리 → 단이 벌어짐). 아래쪽 바지도 같은 면에 이어진다.
static func _body(g: DemonGeo, P: Dictionary, C: Dictionary) -> void:
	var skin: Color = C.skin
	var coat: Color = C.coat
	# 피부 몸통(코트 안, 목·손목·다리 연결부가 보인다)
	var prof: Array = [
		{y = 0.6, rx = 0.07, rz = 0.07, bone = "Neck", col = skin},
		{y = 0.545, rx = 0.074, rz = 0.072, bone = "Neck", col = skin},
		{y = 0.5, rx = 0.082, rz = 0.078, bone = "Neck", col = skin},
		{y = 0.47, rx = 0.15, rz = 0.12, bone = "Spine", col = skin},
		{y = 0.44, rx = 0.175, rz = 0.14, bone = "Spine", col = skin},
		{y = 0.39, rx = 0.18, rz = 0.145, bone = "Spine", col = skin},
		{y = 0.335, rx = 0.172, rz = 0.14, bone = "Spine", col = skin},
		{y = 0.285, rx = 0.168, rz = 0.136, bone = "Spine", col = skin},
		{y = 0.245, rx = 0.168, rz = 0.136, bone = "Pelvis", col = skin},
		{y = 0.205, rx = 0.155, rz = 0.125, bone = "Pelvis", col = skin},
		{y = 0.17, rx = 0.11, rz = 0.095, bone = "Pelvis", col = skin},
		{y = 0.15, rx = 0.06, rz = 0.05, bone = "Pelvis", col = skin},
	]
	g.lathe(prof, 16, false, true, 0.0, 0.0, func(i: int) -> float: return 0.0 if i < 3 else 1.0)
	# 코트: 높은 깃 → 둥근 어깨 → 허리 → 벌어지는 단. 깃은 머리 뒤까지 올라오고(목 둘레) 앞은 조금 낮다(단면 타원으로 근사)
	var cprof: Array = [
		{y = 0.555, rx = 0.118, rz = 0.112, bone = "Neck", col = coat},
		{y = 0.53, rx = 0.108, rz = 0.104, bone = "Neck", col = coat},
		{y = 0.49, rx = 0.125, rz = 0.115, bone = "Spine", col = coat},
		{y = 0.465, rx = 0.185, rz = 0.15, bone = "Spine", col = coat},
		{y = 0.43, rx = 0.2, rz = 0.158, bone = "Spine", col = coat},
		{y = 0.38, rx = 0.197, rz = 0.157, bone = "Spine", col = coat},
		{y = 0.33, rx = 0.188, rz = 0.152, bone = "Spine", col = coat},
		{y = 0.3, rx = 0.185, rz = 0.15, bone = "Spine", col = coat},
		{y = 0.27, rx = 0.19, rz = 0.153, bone = "Pelvis", col = coat},
		{y = 0.235, rx = 0.2, rz = 0.16, bone = "Pelvis", col = coat},
		{y = 0.2, rx = 0.21, rz = 0.168, bone = "Pelvis", col = coat},
		{y = 0.185, rx = 0.205, rz = 0.164, bone = "Pelvis", col = C.coat_deep},
	]
	g.lathe(cprof, 18, false, false)
	# 코트 깃 안쪽(목 뒤 높은 깃이 보일 때 안감)
	g.use("Neck")
	g.tube(Vector3(0, 0.555, 0), Vector3(0, 0.5, 0), 0.113, 0.1, C.coat_deep, 16, false)


## 코트 위 장식: 금 깃 테·금 가운데 띠·단 테, 허리띠와 버클, 가슴의 금 해골
static func _coat_details(g: DemonGeo, C: Dictionary) -> void:
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	g.use("Spine")
	g.line = 0.5
	# 깃 테(금)
	g.use("Neck")
	g.torus(Vector3(0, 0.555, 0), 0.116, 0.008, C.gold, 16, 5, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.95)))
	g.use("Spine")
	# 가슴 가운데 금 띠(깃에서 허리띠까지, 코트 겉면에 얇게)
	for k in 7:
		var y := 0.5 - 0.03 * float(k)
		var rz := _coat_rz(y)
		g.box(Vector3(0, y, -rz - 0.004), Vector3(0.03, 0.034, 0.008), C.gold)
	# 허리띠(짙은 붉은 띠) + 금 버클·붉은 보석
	g.line = 0.7
	g.tube(Vector3(0, 0.318, 0), Vector3(0, 0.282, 0), 0.19, 0.192, C.belt, 20, false, 1.0, 0.8)
	g.polygon(PackedVector2Array([Vector2(-0.03, 0.02), Vector2(0.03, 0.02), Vector2(0.024, -0.016), Vector2(0, -0.028), Vector2(-0.024, -0.016)]),
		Vector3(0, 0.3, -0.192 * 0.8 - 0.006), fb, 0.01, C.gold, C.gold_deep)
	g.polygon(PackedVector2Array([Vector2(0, 0.012), Vector2(0.01, 0), Vector2(0, -0.012), Vector2(-0.01, 0)]),
		Vector3(0, 0.3, -0.192 * 0.8 - 0.014), fb, 0.008, C.cape, C.cape_in)
	# 단 테(금, 코트 아랫단)
	g.use("Pelvis")
	g.torus(Vector3(0, 0.188, 0), 0.205, 0.008, C.gold, 20, 5, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.8)))
	# 금 해골(가슴 위): 둥근 두개골 + 턱 + 검은 눈구멍 둘·코 구멍
	g.use("Spine")
	g.line = 0.6
	var sc := Vector3(0, 0.432, -_coat_rz(0.432) - 0.012)
	g.ellipsoid(sc, Vector3(0.03, 0.03, 0.016), C.gold, 10, 6)
	g.ellipsoid(sc + Vector3(0, -0.026, 0.002), Vector3(0.02, 0.014, 0.012), C.gold, 8, 4)
	g.line = 0.0
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(sc + Vector3(0.011 * side, 0.002, -0.014), Vector3(0.008, 0.009, 0.004), C.pupil, 6, 3)
	g.ellipsoid(sc + Vector3(0, -0.012, -0.015), Vector3(0.004, 0.005, 0.003), C.pupil, 5, 3)
	g.line = 1.0


## 코트 회전체의 높이 y 에서의 앞쪽 반지름(장식을 겉면에 붙일 때)
static func _coat_rz(y: float) -> float:
	var ys := [0.525, 0.49, 0.465, 0.43, 0.38, 0.33, 0.3, 0.27, 0.235, 0.2, 0.185]
	var rs := [0.1, 0.115, 0.15, 0.158, 0.157, 0.152, 0.15, 0.153, 0.16, 0.168, 0.164]
	for i in ys.size() - 1:
		var a: float = ys[i]
		var b: float = ys[i + 1]
		if y <= a and y >= b:
			return lerpf(float(rs[i]), float(rs[i + 1]), (a - y) / maxf(a - b, 0.0001))
	return float(rs[rs.size() - 1]) if y < float(ys[ys.size() - 1]) else float(rs[0])


# ------------------------------------------------------------------ 팔다리(이어진 관)

## 팔: 어깨 속에서 시작해(외곽선 0) 둥근 어깨 → 소매(코트색) → 금 소맷단 → 붉은 주먹(둥근 끝)까지 한 관
static func _arms(g: DemonGeo, P: Dictionary, C: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := float(P.shoulder_x) * side
		var nodes: Array = [
			{p = Vector3(x * 0.72, 0.448, 0.0), r = 0.05, bone = "Arm" + sfx, col = C.coat, line = 0.0},
			{p = Vector3(x * 1.04, 0.443, 0.0), r = 0.062, bone = "Arm" + sfx, col = C.coat, line = 0.0},
			{p = Vector3(x * 1.13, 0.425, 0.0), r = 0.058, bone = "Arm" + sfx, col = C.coat},
			{p = Vector3(x * 1.14, 0.395, 0.0), r = 0.053, bone = "Arm" + sfx, col = C.coat},
			{p = Vector3(x * 1.14, 0.37, 0.0), r = 0.051, bone = "Forearm" + sfx, col = C.coat},
			{p = Vector3(x * 1.14, 0.338, 0.0), r = 0.051, bone = "Forearm" + sfx, col = C.coat},
			{p = Vector3(x * 1.14, 0.316, 0.0), r = 0.056, bone = "Forearm" + sfx, col = C.gold},
			{p = Vector3(x * 1.14, 0.302, 0.0), r = 0.056, bone = "Forearm" + sfx, col = C.gold},
			{p = Vector3(x * 1.14, 0.29, -0.004), r = 0.054, bone = "Hand" + sfx, col = C.skin},
			{p = Vector3(x * 1.14, 0.255, -0.012), r = 0.058, bone = "Hand" + sfx, col = C.skin},
			{p = Vector3(x * 1.14, 0.225, -0.018), r = 0.054, bone = "Hand" + sfx, col = C.skin},
		]
		g.limb(nodes, 10, Vector3.FORWARD, false, true, 3)
		# 엄지(주먹 안쪽 앞): 작은 둥근 혹
		g.use("Hand" + sfx)
		g.line = 0.4
		g.ellipsoid(Vector3(x * 1.14 - side * 0.03, 0.262, -0.052), Vector3(0.022, 0.028, 0.024), C.skin, 8, 4)
		g.line = 1.0


## 다리: 골반 속에서 시작해 바지(코트색) → 짧은 장화(둥근 앞코)까지. 장화는 발 뼈에 붙는다
static func _legs(g: DemonGeo, P: Dictionary, C: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := float(P.hip_x) * side
		var nodes: Array = [
			{p = Vector3(x, 0.235, 0.0), r = 0.068, bone = "Leg" + sfx, col = C.coat, line = 0.0},
			{p = Vector3(x, 0.19, 0.0), r = 0.066, bone = "Leg" + sfx, col = C.coat},
			{p = Vector3(x, 0.15, 0.0), r = 0.061, bone = "Leg" + sfx, col = C.coat},
			{p = Vector3(x, 0.125, 0.0), r = 0.06, bone = "Shin" + sfx, col = C.coat},
			{p = Vector3(x, 0.095, 0.0), r = 0.06, bone = "Shin" + sfx, col = C.boot},
			{p = Vector3(x, 0.07, 0.0), r = 0.062, bone = "Foot" + sfx, col = C.boot},
			{p = Vector3(x, 0.05, 0.0), r = 0.06, bone = "Foot" + sfx, col = C.boot},
		]
		g.limb(nodes, 10, Vector3.FORWARD, false, false)
		# 장화 몸: 발 뼈. 발꿈치~앞코가 한 타원, 바닥은 지면(y 0)에 닿는다
		g.use("Foot" + sfx)
		g.rounded_box(Vector3(x, 0.055, -0.035), Vector3(0.068, 0.05, 0.1), C.boot, 0.55, 12, 6)


# ------------------------------------------------------------------ 망토·앞치마·날개·꼬리

static func _cape_and_wings(g: DemonGeo, C: Dictionary) -> void:
	var top := Vector3(0, 0.49, 0.1)
	g.add_bone("Cape", "Spine", top)
	g.use("Cape")
	g.measure = false
	g.cape(top, 0.44, 0.24, 0.42, C.cape, C.cape_in, 0.09, 0.05, 0.02, 7, 6, 0.006)
	# 날개: 어깨뼈 뒤에서 옆·위로 작게. 뼈대는 짙은 갈색, 막은 어두운 붉은색. 몸·얼굴을 가리지 않게 머리 아래 높이에 둔다
	for side: float in [-1.0, 1.0]:
		var root := Vector3(0.09 * side, 0.44, 0.095)
		var tips: Array = [Vector3(0.33 * side, 0.6, 0.11), Vector3(0.4 * side, 0.47, 0.13), Vector3(0.34 * side, 0.36, 0.125)]
		g.wing(root, tips, 0.011, C.wing_bone, C.wing, 0.28, 0.004, 4)
		# 날개 뿌리 뼈(어깨뼈에서 손목까지 팔뼈)
		g.tube(root, Vector3(0.2 * side, 0.52, 0.11), 0.014, 0.012, C.wing_bone, 6, true)
	g.measure = true
	# 앞치마(허리띠 아래 앞쪽 천 + 금 테): 골반 뼈
	g.use("Pelvis")
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	var ao := Vector3(0, 0.282, -0.158)
	var apron := PackedVector2Array([Vector2(-0.075, 0.0), Vector2(0.075, 0.0), Vector2(0.082, -0.1), Vector2(0, -0.15), Vector2(-0.082, -0.1)])
	g.line = 0.7
	g.polygon(apron, ao + Vector3(0, 0, 0.003), fb, 0.008, C.gold, C.gold_deep)
	var inner := PackedVector2Array()
	for p: Vector2 in apron:
		inner.append(p * 0.86 + Vector2(0, -0.006))
	g.polygon(inner, ao - Vector3(0, 0, 0.004), fb, 0.006, C.cape, C.cape_in)
	g.line = 1.0


## 가는 악마 꼬리: 골반 뒤에서 뒤·위로 휘어 올라가고 끝은 화살촉
static func _tail(g: DemonGeo, C: Dictionary) -> void:
	g.use("Pelvis")
	g.measure = false
	var pts: Array = [Vector3(0, 0.19, 0.1), Vector3(0, 0.14, 0.2), Vector3(0, 0.12, 0.3), Vector3(0, 0.15, 0.38), Vector3(0, 0.22, 0.43), Vector3(0, 0.3, 0.44)]
	var radii: Array = [0.03, 0.026, 0.021, 0.016, 0.012, 0.009]
	g.spline_tube(pts, radii, C.skin, 8, false, true, Vector3.RIGHT)
	# 화살촉(양면 삼각 판, 위를 향한다)
	var tipb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	g.polygon(PackedVector2Array([Vector2(-0.032, -0.012), Vector2(0.032, -0.012), Vector2(0.0, 0.055)]), Vector3(0, 0.305, 0.44), tipb, 0.012, C.skin, C.skin_deep)
	g.measure = true


# ------------------------------------------------------------------ 머리

## 머리: 조각한 구 한 장(눈두덩 패임·눈썹 능선·볼·짧은 주둥이·작은 코·턱)에 눈·눈썹·입·귀·뿔·불꽃 돌기를 더한다.
## 눈두덩 속에 눈알을 앉혀 튀어나오지 않게 하고, 눈 테두리는 두꺼운 고리 대신 윗눈꺼풀 선 하나만 둔다.
static func _head(g: DemonGeo, C: Dictionary) -> void:
	g.use("Head")
	var hc := HC
	var hr := HR
	var skin: Color = C.skin
	var blush: Color = C.blush
	var eye_l := Vector3(-EYE_DIR_X, EYE_DIR_Y, -0.9).normalized()
	var eye_r := Vector3(EYE_DIR_X, EYE_DIR_Y, -0.9).normalized()
	var shape := func(d: Vector3) -> float:
		var k := 1.0
		# 눈두덩: 눈 방향으로 살짝 패인다
		k -= 0.07 * (DemonGeo.bump(d, eye_l, 0.3) + DemonGeo.bump(d, eye_r, 0.3))
		# 눈썹 능선(눈 위)
		k += 0.02 * (DemonGeo.bump(d, Vector3(-0.42, 0.36, -0.84).normalized(), 0.3) + DemonGeo.bump(d, Vector3(0.42, 0.36, -0.84).normalized(), 0.3))
		# 볼(아래 옆 앞)
		k += 0.04 * (DemonGeo.bump(d, Vector3(-0.72, -0.3, -0.62).normalized(), 0.5) + DemonGeo.bump(d, Vector3(0.72, -0.3, -0.62).normalized(), 0.5))
		# 짧은 주둥이와 코 끝(앞으로 조금만)
		k += 0.035 * DemonGeo.bump(d, Vector3(0, -0.28, -1.0).normalized(), 0.42)
		k += 0.012 * DemonGeo.bump(d, Vector3(0, -0.16, -1.0).normalized(), 0.14)
		# 턱은 작게, 뒤통수는 둥글게 조금 더
		k -= 0.03 * DemonGeo.bump(d, Vector3(0, -0.85, -0.5).normalized(), 0.4)
		k += 0.015 * DemonGeo.bump(d, Vector3(0, 0.1, 1.0).normalized(), 0.6)
		return k
	var col_of := func(d: Vector3, _p: Vector3) -> Color:
		# 볼 홍조: 볼 방향으로 살짝 붉게(정점 색이 부드럽게 섞인다)
		var b := maxf(DemonGeo.bump(d, Vector3(-0.78, -0.22, -0.58).normalized(), 0.26), DemonGeo.bump(d, Vector3(0.78, -0.22, -0.58).normalized(), 0.26))
		return skin.lerp(blush, clampf(b * 0.9, 0.0, 1.0))
	g.sculpt(hc, hr, skin, 26, 17, shape, col_of)
	_face(g, C)
	g.use("Head")
	# 작은 코(주둥이 끝의 짙은 점)
	g.line = 0.0
	var nd := Vector3(0, -0.17, -1.0).normalized()
	var np := hc + Vector3(nd.x * hr.x, nd.y * hr.y, nd.z * hr.z) * (1.0 + 0.047)
	g.ellipsoid(np, Vector3(0.016, 0.011, 0.01), C.nose, 8, 4)
	g.line = 1.0
	# 귀: 머리 속에서 옆·뒤·위로 짧게 뻗는 뾰족 귀(뿌리가 머리 속이라 이음새가 없다)
	for side: float in [-1.0, 1.0]:
		var eb := hc + Vector3(0.14 * side, -0.005, 0.03)
		g.horn(eb, Vector3(1.0 * side, 0.42, 0.12), Vector3(0.0, 0.35, 0.15), 0.2, 0.056, skin, 5, 8)
	# 정수리 불꽃 돌기(앞뒤로 납작한 뾰족 혹, 살짝 뒤로 휨)
	g.measure = false
	var fb := hc + Vector3(0, 0.165, 0.0)
	var fpts: Array = [fb, fb + Vector3(0, 0.03, 0.0), fb + Vector3(0, 0.07, 0.008), fb + Vector3(0, 0.1, 0.02), fb + Vector3(0, 0.125, 0.035)]
	var fr: Array = [0.045, 0.04, 0.028, 0.014, 0.0]
	g.spline_tube(fpts, fr, C.flame, 8, false, true, Vector3.RIGHT, 1.0, 0.6)
	# 뿔: 머리 옆 위 속에서 시작해 바깥·위로 크게 휘어 오르고 끝이 조금 안쪽으로 모인다. 마디 능선은 반지름을 매끈하게 흔들어 만든다.
	# 키(HEIGHT)와 말풍선 높이(hp_bar_y)에 넣지 않는다(깃털·뿔과 같은 취급)
	g.measure_all = false
	for side: float in [-1.0, 1.0]:
		var p0 := hc + Vector3(0.1 * side, 0.1, 0.02)
		var p1 := hc + Vector3(0.3 * side, 0.16, 0.03)
		var p2 := hc + Vector3(0.36 * side, 0.33, 0.0)
		var p3 := hc + Vector3(0.25 * side, 0.44, -0.03)
		var nodes: Array = []
		var n := 12
		for i in n + 1:
			var t := float(i) / float(n)
			var r := 0.08 * pow(1.0 - t, 0.72) * (1.0 + 0.08 * sin(t * PI * 5.0) * (1.0 - t))
			if i == n:
				r = 0.0
			var col: Color = C.horn if t < 0.75 else (C.horn as Color).lerp(C.horn_tip, (t - 0.75) / 0.25)
			nodes.append({p = DemonGeo.bez(p0, p1, p2, p3, t), r = r, bone = "Head", col = col, line = 0.0 if i == 0 else 1.0})
		g.limb(nodes, 9, Vector3.BACK, false, true)
	g.measure_all = true
	g.measure = true


## 눈(눈두덩 속 황금 눈알 + 짙은 세로 동공 + 작은 반사광 + 윗눈꺼풀·눈꺼풀 선), 눈썹, 입 세 가지. 뼈 이름은 CharacterRig 의 표정 규약 그대로.
static func _face(g: DemonGeo, C: Dictionary) -> void:
	var hc := HC
	var hr := HR
	var es := ES
	var keep_line := g.line
	g.line = 0.0
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var d := Vector3(EYE_DIR_X * side, EYE_DIR_Y, -0.9).normalized()
		# 눈두덩 바닥(조각 구의 반지름 배수 ≈ 0.945) 조금 안쪽에 눈알 중심을 두어 앞면만 살짝 나온다
		var floor_p := hc + Vector3(d.x * hr.x, d.y * hr.y, d.z * hr.z) * 0.93
		var ec := floor_p - d * (es * 0.42)
		# -Z(타원체의 앞)가 눈 방향 d 를 향하게
		var eb := Basis.looking_at(d, Vector3.UP)
		var tilt := Basis(Vector3.BACK, side * 0.26)
		var ebt := eb * tilt
		g.add_bone("Eye" + sfx, "Head", ec)
		g.use("Eye" + sfx)
		g.ellipsoid(ec, Vector3(es * 1.14, es * 0.88, es * 0.9), C.eye, 12, 7, ebt)
		# 동공: 눈알 앞면에 붙은 세로 타원(살짝 안쪽을 본다) + 작은 반사광
		var pd := Vector3(-side * 0.1, -0.02, -1.0).normalized()
		var pc := ec + ebt * (Vector3(pd.x * es * 1.14, pd.y * es * 0.88, pd.z * es * 0.9) * 0.985)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.ellipsoid(pc, Vector3(es * 0.3, es * 0.5, es * 0.1), C.pupil, 8, 5, ebt)
		g.ellipsoid(pc + ebt * Vector3(side * es * 0.14, es * 0.3, -es * 0.06), Vector3(es * 0.07, es * 0.07, es * 0.03), C.white, 6, 3, ebt)
		# 윗눈꺼풀: 눈알보다 조금 큰 반구 덮개(피부색), 뼈 피벗은 눈 위. 표정이 Y 크기를 키우면 내려와 덮는다
		var lid_p := ec + ebt * Vector3(0, es * 0.95, 0)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.26, es * 2.3, es * 1.0), C.skin, 10, 4, ebt * Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈꺼풀 선: 눈 위 가장자리를 따라가는 가는 짙은 선(두꺼운 고리 대신)
		g.use("Head")
		var lash: Array = []
		for i in 5:
			var u := float(i) / 2.0 - 1.0
			var ang := u * 1.25
			var lp := ec + ebt * Vector3(sin(ang) * es * 1.16, cos(ang) * es * 0.88 * 0.98 - es * 0.02 - es * 0.08 * (1.0 - absf(u)), -es * 0.6)
			lash.append(lp)
		g.sweep(lash, es * 0.075, C.lash, 4)
		# 눈썹: 짙은 붉은 갈색 두툼한 능선 위의 띠, 안쪽 끝이 내려간다(기본 = 근엄)
		var bd := Vector3(EYE_DIR_X * side, 0.37, -0.84).normalized()
		var bp := hc + Vector3(bd.x * hr.x, bd.y * hr.y, bd.z * hr.z) * 0.99
		g.add_bone("Brow" + sfx, "Head", bp)
		g.use("Brow" + sfx)
		var bi := Vector3(0.14 * side, 0.2, -0.95).normalized()
		var bo := Vector3(0.66 * side, 0.3, -0.68).normalized()
		var pi_ := hc + Vector3(bi.x * hr.x, bi.y * hr.y, bi.z * hr.z) * 0.985
		var po := hc + Vector3(bo.x * hr.x, bo.y * hr.y, bo.z * hr.z) * 0.985
		g.sweep([pi_, bp, po], es * 0.26, C.brow, 6)
	# 입: 주둥이 아래 가는 선. 보통 = 살짝 다문 입(끝이 조금 내려감), 벌림 = 작은 붉은 입속 + 송곳니 둘, 아픔 = 물결선
	var md := Vector3(0, -0.36, -1.0).normalized()
	var mp := hc + Vector3(md.x * hr.x, md.y * hr.y, md.z * hr.z) * 1.03
	var mw := 0.06
	g.add_bone("MouthN", "Head", mp)
	g.use("MouthN")
	var pts: Array = []
	for i in 5:
		var u := float(i) / 2.0 - 1.0
		pts.append(mp + Vector3(u * mw * 0.5, -u * u * mw * 0.08, -absf(u) * 0.004))
	g.sweep(pts, mw * 0.05, C.lip, 4)
	# 작은 송곳니 둘(다문 입 양끝 위)
	for fu: float in [-0.62, 0.62]:
		g.polygon(PackedVector2Array([Vector2(-0.004, 0.003), Vector2(0.004, 0.003), Vector2(0, -0.012)]),
			mp + Vector3(fu * mw * 0.5, 0.004, -0.006), Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK), 0.003, C.white)
	g.add_bone("MouthA", "Head", mp)
	g.use("MouthA")
	g.ellipsoid(mp + Vector3(0, -0.008, 0.0), Vector3(mw * 0.42, mw * 0.3, 0.012), C.mouth_in, 10, 4)
	g.ellipsoid(mp + Vector3(0, -0.008, -0.004), Vector3(mw * 0.45, mw * 0.33, 0.008), C.lip, 10, 4, Basis.IDENTITY, PI, PI, 0.0)
	for fu: float in [-0.5, 0.5]:
		g.polygon(PackedVector2Array([Vector2(-0.005, 0.004), Vector2(0.005, 0.004), Vector2(0, -0.016)]),
			mp + Vector3(fu * mw * 0.5, 0.004, -0.012), Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK), 0.003, C.white)
	g.add_bone("MouthH", "Head", mp)
	g.use("MouthH")
	var wav: Array = []
	for i in 7:
		var u := float(i) / 3.0 - 1.0
		wav.append(mp + Vector3(u * mw * 0.45, sin(u * PI * 1.5) * mw * 0.08, -0.003))
	g.sweep(wav, mw * 0.05, C.lip, 4)
	g.use("Head")
	g.line = keep_line
