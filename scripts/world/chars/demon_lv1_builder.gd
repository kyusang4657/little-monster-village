class_name DemonLv1Builder
extends RefCounted
## 악마형 마왕 Lv.1 교체 후보(6차, docs/design/concept/sheet-3-demon-king.jpg 의 Lv.1 "기본 형태").
## 붉은 피부의 작은 군주: 둥근 머리(조각 구 한 장: 눈두덩·눈썹 능선·볼·작은 코가 한 면에 이어진다), 짙은 갈색 곡선 뿔(마디 능선이 매끈하게 이어짐),
## 짧은 뾰족 귀, 정수리 불꽃 돌기, 황금색 고양이 눈(눈두덩 속에 앉아 튀어나오지 않음), 짧고 단단한 몸통(회전체 한 장), 어깨에서 손끝까지 이어진 팔,
## 검정·금 테 군주 코트와 금 해골 장식, 버건디 망토·앞치마, 작은 박쥐 날개, 화살촉 꼬리. 왕관·견갑·지팡이(Lv.3~4)는 없다.
## 리그 규약은 기존 뿔이와 같다(뼈 이름·기준점·정면 -Z·Cape 뼈), 그래서 CharacterRig 의 자세·표정·깜빡임·2차 움직임이 그대로 동작한다.
## gray = true 면 형태 확인용 회색(정점 명암 없음).

const SKIN := Color("d6504f")
const SKIN_DEEP := Color("9e2a2f")
const TAIL := Color("7a2a2c")
const FLAME := Color("d9484e")
const BLUSH := Color("f58c6e")
const NOSE := Color("2a1416")
const HORN := Color("3a2824")
const HORN_TIP := Color("5a4036")
const COAT := Color("2c2530")
const COAT_DEEP := Color("1f1a22")
const GOLD := Color("d8a648")
const GOLD_DEEP := Color("a97a2c")
const CAPE := Color("6e2332")
const CAPE_IN := Color("421018")
const SIGIL := Color("be464b")
const EAR_IN := Color("ef8a7a")
const BELT := Color("5a1c25")
const BOOT := Color("27202a")
const EYE := Color("f6c63a")
const EYE_SHADE := Color("d79a24")
const PUPIL := Color("1a1013")
const LASH := Color("3a181c")
const BROW := Color("ee7a6a")
const LIP := Color("3a1216")
const MOUTH_IN := Color("4a1018")
const WING := Color("a52a35")
const WING_BONE := Color("3a2824")
const GRAY := Color(0.62, 0.62, 0.62)

# 머리 타원 중심·반지름(골격 공간). 눈·코·입·뿔·귀는 모두 이 값에서 계산한다
const HC := Vector3(0, 0.73, -0.005)
const HR := Vector3(0.205, 0.19, 0.195)
const EYE_DIR_X := 0.44
const EYE_DIR_Y := 0.02
const ES := 0.058


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
		"belt", "boot", "eye", "eye_shade", "pupil", "lash", "brow", "lip", "mouth_in", "wing", "wing_bone", "white", "tail", "sigil", "ear_in", "horn_groove"]
	var cols := [SKIN, SKIN_DEEP, FLAME, BLUSH, NOSE, HORN, HORN_TIP, COAT, COAT_DEEP, GOLD, GOLD_DEEP, CAPE, CAPE_IN,
		BELT, BOOT, EYE, EYE_SHADE, PUPIL, LASH, BROW, LIP, MOUTH_IN, WING, WING_BONE, Color.WHITE, TAIL, SIGIL, EAR_IN, Color("2a1b18")]
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
	g.lathe(prof, 14, false, true, 0.0, 0.0, func(i: int) -> float: return 0.0 if i < 3 else 1.0)
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
		{y = 0.19, rx = 0.21, rz = 0.168, bone = "Pelvis", col = coat},
		{y = 0.15, rx = 0.216, rz = 0.173, bone = "Pelvis", col = coat},
		{y = 0.12, rx = 0.215, rz = 0.172, bone = "Pelvis", col = C.coat_deep},
	]
	g.lathe(cprof, 16, false, false)
	# 코트 깃 안쪽(목 뒤 높은 깃이 보일 때 안감)
	g.use("Neck")
	g.tube(Vector3(0, 0.555, 0), Vector3(0, 0.5, 0), 0.113, 0.1, C.coat_deep, 16, false)


## 코트 위 장식: 금 깃 테, 어깨에서 가슴 걸쇠로 모이는 금 테 옷깃(V), 가슴 걸쇠 아래 금 해골, 버건디 가슴판과 양옆 금 세로 테,
## 금 테 어깨 덮개, 허리띠와 버클, 단 테. 띠·판은 코트 겉면 곡면을 따라간다(front_strip).
static func _coat_details(g: DemonGeo, C: Dictionary) -> void:
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	var rz_of := func(y: float) -> float: return _coat_rz(y)
	var rx_of := func(y: float) -> float: return _coat_rz(y) * 1.25
	g.use("Spine")
	g.line = 0.4
	# 깃 테(금)
	g.use("Neck")
	g.torus(Vector3(0, 0.555, 0), 0.116, 0.008, C.gold, 12, 4, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.95)))
	g.use("Spine")
	# 버건디 가슴판(걸쇠 아래 ~ 허리띠 위)과 양옆 금 세로 테, 허리띠 아래로도 금 테가 단까지 이어진다
	g.front_strip(-0.05, 0.05, 0.445, 0.33, rz_of, rx_of, 0.004, C.cape, 5)
	for side: float in [-1.0, 1.0]:
		g.front_strip(0.046 * side, 0.062 * side, 0.45, 0.33, rz_of, rx_of, 0.006, C.gold, 5)
	g.use("Pelvis")
	for side: float in [-1.0, 1.0]:
		g.front_strip(0.046 * side, 0.062 * side, 0.27, 0.125, rz_of, rx_of, 0.006, C.gold, 5)
	g.use("Spine")
	# 옷깃: 어깨 위(±0.15, 0.47)에서 가슴 걸쇠(0, 0.45)로 모이는 금 테 띠 두 줄(각 띠는 짧은 조각 여러 개로 곡면을 따라간다)
	for side: float in [-1.0, 1.0]:
		var a := Vector2(0.16 * side, 0.478)
		var b := Vector2(0.03 * side, 0.448)
		var n := 4
		for k in n:
			var t0 := float(k) / float(n)
			var t1 := float(k + 1) / float(n)
			var p0 := a.lerp(b, t0)
			var p1 := a.lerp(b, t1)
			var xm := (p0.x + p1.x) * 0.5
			var ym := (p0.y + p1.y) * 0.5
			var ang := atan2(p1.y - p0.y, p1.x - p0.x)
			var rz := _coat_rz(ym)
			var rx := rz * 1.25
			var q := 1.0 - pow(clampf(xm / rx, -0.999, 0.999), 2.0)
			var z := -rz * sqrt(q) - 0.006
			var seg := p0.distance_to(p1)
			g.box(Vector3(xm, ym, z), Vector3(seg + 0.004, 0.016, 0.006), C.gold, Basis(Vector3.BACK, ang))
	# 어깨 덮개(금 테 반원 판): 몸통 뼈에 붙어 어깨 위를 덮는다
	for side: float in [-1.0, 1.0]:
		var sc := Vector3(0.165 * side, 0.468, 0.0)
		g.ellipsoid(sc, Vector3(0.095, 0.045, 0.085), C.coat, 10, 3, Basis.IDENTITY, PI * 0.5, PI * 0.5)
		g.torus(sc + Vector3(0, 0.004, 0), 0.09, 0.006, C.gold, 10, 4, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.9)))
	# 허리띠(짙은 붉은 띠) + 금 버클·붉은 보석
	g.line = 0.7
	g.tube(Vector3(0, 0.318, 0), Vector3(0, 0.282, 0), 0.19, 0.192, C.belt, 20, false, 1.0, 0.8)
	g.polygon(PackedVector2Array([Vector2(-0.03, 0.02), Vector2(0.03, 0.02), Vector2(0.024, -0.016), Vector2(0, -0.028), Vector2(-0.024, -0.016)]),
		Vector3(0, 0.3, -0.192 * 0.8 - 0.006), fb, 0.01, C.gold, C.gold_deep)
	g.polygon(PackedVector2Array([Vector2(0, 0.012), Vector2(0.01, 0), Vector2(0, -0.012), Vector2(-0.01, 0)]),
		Vector3(0, 0.3, -0.192 * 0.8 - 0.014), fb, 0.008, C.cape, C.cape_in)
	# 단 테(금, 코트 아랫단)
	g.use("Pelvis")
	g.torus(Vector3(0, 0.123, 0), 0.215, 0.008, C.gold, 14, 4, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.8)))
	# 금 해골(가슴 걸쇠 바로 아래, 턱 밑): 둥근 두개골 + 턱 + 검은 눈구멍 둘·코 구멍
	g.use("Spine")
	g.line = 0.6
	var sc2 := Vector3(0, 0.44, -_coat_rz(0.44) - 0.006)
	g.ellipsoid(sc2, Vector3(0.05, 0.048, 0.016), C.gold, 8, 4)
	g.ellipsoid(sc2 + Vector3(0, -0.04, 0.002), Vector3(0.032, 0.022, 0.012), C.gold, 6, 3)
	g.line = 0.0
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(sc2 + Vector3(0.018 * side, 0.004, -0.014), Vector3(0.013, 0.015, 0.005), C.pupil, 6, 3)
	g.ellipsoid(sc2 + Vector3(0, -0.018, -0.016), Vector3(0.006, 0.008, 0.004), C.pupil, 5, 3)
	g.line = 1.0


## 코트 회전체의 높이 y 에서의 앞쪽 반지름(장식을 겉면에 붙일 때)
static func _coat_rz(y: float) -> float:
	var ys := [0.555, 0.53, 0.49, 0.465, 0.43, 0.38, 0.33, 0.3, 0.27, 0.235, 0.19, 0.15, 0.12]
	var rs := [0.112, 0.104, 0.115, 0.15, 0.158, 0.157, 0.152, 0.15, 0.153, 0.16, 0.168, 0.173, 0.172]
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
		g.limb(nodes, 8, Vector3.FORWARD, false, true, 3)
		# 엄지(주먹 안쪽 앞): 작은 둥근 혹
		g.use("Hand" + sfx)
		g.line = 0.4
		g.ellipsoid(Vector3(x * 1.14 - side * 0.022, 0.262, -0.044), Vector3(0.024, 0.03, 0.026), C.skin, 8, 4)
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
		g.limb(nodes, 8, Vector3.FORWARD, false, false)
		# 장화 몸: 발 뼈. 발꿈치~앞코가 한 타원, 바닥은 지면(y 0)에 닿는다
		g.use("Foot" + sfx)
		g.rounded_box(Vector3(x, 0.055, -0.035), Vector3(0.068, 0.05, 0.1), C.boot, 0.55, 12, 6)


# ------------------------------------------------------------------ 망토·앞치마·날개·꼬리

static func _cape_and_wings(g: DemonGeo, C: Dictionary) -> void:
	# 망토: 코트 등판 바깥(z 0.175)의 어깨 높이에서 발목까지, 어깨는 좁고 단은 넓다. 양옆이 앞으로 감겨 정면에서도 버건디 자락이 보인다
	var top := Vector3(0, 0.5, 0.175)
	g.add_bone("Cape", "Spine", top)
	g.use("Cape")
	g.measure = false
	var P: Array = g.cape_grid(top, 0.42, 0.34, 0.54, C.cape, C.cape_in, 0.07, 0.1, 0.02, 7, 6, 0.006)
	# 금 테: 양옆 가장자리와 아랫단
	var rows := P.size() - 1
	var cols := (P[0] as Array).size() - 1
	var left: Array = []
	var right: Array = []
	var hem: Array = []
	for i in rows + 1:
		left.append(P[i][0])
		right.append(P[i][cols])
	for j in cols + 1:
		hem.append(P[rows][j])
	g.line = 0.3
	g.sweep(left, 0.007, C.gold, 4)
	g.sweep(right, 0.007, C.gold, 4)
	g.sweep(hem, 0.007, C.gold, 4)
	# 등의 악마 문장(짙은 붉은 평판: 가운데 뿔 달린 왕관꼴)
	var mid: Vector3 = P[2][cols / 2]
	# 악마 머리 문장: 위로 휘는 뿔 둘 + 턱이 뾰족한 머리(망토 폭의 약 35%)
	var sig := PackedVector2Array()
	for pt: Vector2 in [Vector2(-0.085, 0.07), Vector2(-0.06, 0.0), Vector2(-0.045, 0.045), Vector2(-0.035, -0.005), Vector2(0.0, 0.01),
			Vector2(0.035, -0.005), Vector2(0.045, 0.045), Vector2(0.06, 0.0), Vector2(0.085, 0.07), Vector2(0.055, -0.02), Vector2(0.03, -0.055),
			Vector2(0.0, -0.085), Vector2(-0.03, -0.055), Vector2(-0.055, -0.02)]:
		sig.append(pt)
	g.line = 0.0
	g.polygon(sig, mid + Vector3(0, 0, 0.012), Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK), 0.0, C.sigil)
	g.line = 1.0
	# 날개: 어깨뼈(코트 밖 z 0.17)에서 귀 높이의 손목까지 팔뼈가 솟고, 손목에서 세 손가락이 옆·뒤로 펼쳐진 밝은 붉은 막. 손목에 금 발톱
	for side: float in [-1.0, 1.0]:
		var root := Vector3(0.1 * side, 0.47, 0.17)
		var wrist := Vector3(0.24 * side, 0.66, 0.2)
		var tips: Array = [Vector3(0.4 * side, 0.6, 0.32), Vector3(0.43 * side, 0.45, 0.36), Vector3(0.35 * side, 0.33, 0.35)]
		g.tube(root, wrist, 0.016, 0.012, C.wing_bone, 6, true)
		g.wing(wrist, tips, 0.011, C.wing_bone, C.wing, 0.3, 0.004, 4)
		# 뿌리~손목~아래 손가락 사이 막(몸 쪽 막)
		var keep := g.line
		g.line = 0.4
		for sgn: float in [1.0, -1.0]:
			var nn := Vector3(0, 0, sgn)
			var b0 := g.v.size()
			g._vert(root + nn * 0.004, nn, C.wing)
			g._vert(wrist + nn * 0.004, nn, C.wing)
			g._vert((tips[2] as Vector3) + nn * 0.004, nn, C.wing)
			g.tri(b0, b0 + 1, b0 + 2)
		g.line = keep
		g.horn(wrist, Vector3(0.3 * side, 1.0, -0.2), Vector3(0.2 * side, 0.0, -0.2), 0.04, 0.012, C.gold, 3, 6)
	g.measure = true
	# 앞치마(허리띠 아래 앞쪽 천 + 금 테): 골반 뼈, 끝이 y 0.08 까지
	g.use("Pelvis")
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	var ao := Vector3(0, 0.282, -0.17)
	var apron := PackedVector2Array([Vector2(-0.1, 0.0), Vector2(0.1, 0.0), Vector2(0.105, -0.13), Vector2(0, -0.2), Vector2(-0.105, -0.13)])
	g.line = 0.7
	g.polygon(apron, ao + Vector3(0, 0, 0.003), fb, 0.008, C.gold, C.gold_deep)
	var inner := PackedVector2Array()
	for p: Vector2 in apron:
		inner.append(p * 0.88 + Vector2(0, -0.006))
	g.polygon(inner, ao - Vector3(0, 0, 0.004), fb, 0.006, C.cape, C.cape_in)
	g.line = 1.0


## 가는 악마 꼬리: 골반 뒤에서 뒤·위로 휘어 올라가고 끝은 화살촉
static func _tail(g: DemonGeo, C: Dictionary) -> void:
	g.use("Pelvis")
	g.measure = false
	var pts: Array = [Vector3(0, 0.165, 0.1), Vector3(0, 0.1, 0.21), Vector3(0, 0.09, 0.31), Vector3(0, 0.13, 0.39), Vector3(0, 0.21, 0.44), Vector3(0, 0.3, 0.45)]
	var radii: Array = [0.03, 0.026, 0.021, 0.016, 0.012, 0.009]
	g.spline_tube(pts, radii, C.tail, 8, false, true, Vector3.RIGHT)
	# 화살촉: 삼각 판 두 장을 90° 로 교차시켜 어느 쪽에서 봐도 읽힌다
	var tipb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	var tipc := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
	var head := PackedVector2Array([Vector2(-0.032, -0.012), Vector2(0.032, -0.012), Vector2(0.0, 0.055)])
	g.polygon(head, Vector3(0, 0.305, 0.45), tipb, 0.008, C.tail, C.tail)
	g.polygon(head, Vector3(0, 0.305, 0.45), tipc, 0.008, C.tail, C.tail)
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
		k += 0.008 * (DemonGeo.bump(d, Vector3(-0.42, 0.36, -0.84).normalized(), 0.45) + DemonGeo.bump(d, Vector3(0.42, 0.36, -0.84).normalized(), 0.45))
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
		var b := maxf(DemonGeo.bump(d, Vector3(-0.7, -0.18, -0.7).normalized(), 0.2), DemonGeo.bump(d, Vector3(0.7, -0.18, -0.7).normalized(), 0.2))
		return skin.lerp(blush, clampf(b * 0.6, 0.0, 1.0))
	g.sculpt(hc, hr, skin, 22, 13, shape, col_of)
	_face(g, C)
	g.use("Head")
	# 작은 코: 주둥이 끝의 짙은 역삼각 판
	g.line = 0.0
	var nd := Vector3(0, -0.17, -1.0).normalized()
	var np := hc + Vector3(nd.x * hr.x, nd.y * hr.y, nd.z * hr.z) * (1.0 + 0.047)
	g.polygon(PackedVector2Array([Vector2(-0.011, 0.007), Vector2(0.011, 0.007), Vector2(0.0, -0.011)]), np, Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK), 0.006, C.nose)
	g.line = 1.0
	# 귀: 머리 속에서 옆으로(눈 높이) 뻗는 잎 모양 뾰족 귀(앞뒤로 납작, 뿌리가 머리 속이라 이음새가 없다)
	for side: float in [-1.0, 1.0]:
		var eb := hc + Vector3(0.12 * side, 0.0, 0.03)
		var ed := Vector3(1.0 * side, 0.36, 0.47).normalized()
		var epts: Array = []
		var erad: Array = []
		for i in 6:
			var t := float(i) / 5.0
			epts.append(eb + ed * (0.24 * t) + Vector3(0, 0.02, 0.01) * (t * t))
			erad.append((0.072 * (1.0 - 0.25 * t) if t < 0.45 else 0.072 * 0.89 * pow((1.0 - t) / 0.55, 0.85)) if i < 5 else 0.0)
		# 앞뒤로 납작한 잎(단면 fu = 앞뒤 0.45, fw = 위아래 1)
		g.spline_tube(epts, erad, skin, 8, false, true, Vector3.BACK, 0.45, 1.0)
		# 안쪽 귀(밝은 오목 판): 귀 앞면에 얇은 잎 판
		g.line = 0.0
		var e1: Vector3 = epts[1]
		var e4: Vector3 = epts[4]
		var fwd := Vector3(0, 0, -1)
		var ex := (e4 - e1).normalized()
		var eup := fwd.cross(ex).normalized()
		g.polygon(PackedVector2Array([Vector2(0.0, -0.035), Vector2(0.06, -0.018), Vector2(0.11, 0.0), Vector2(0.06, 0.02), Vector2(0.0, 0.035)]),
			e1 + fwd * 0.022, Basis(ex, eup, -fwd), 0.0, C.ear_in)
		g.line = 1.0
	# 정수리 불꽃 돌기: 가운데 큰 돌기 + 양옆 작은 곁가지(40%)
	g.measure = false
	var fb := hc + Vector3(0, 0.165, 0.0)
	var fpts: Array = [fb, fb + Vector3(0, 0.03, 0.0), fb + Vector3(0, 0.07, 0.008), fb + Vector3(0, 0.1, 0.02), fb + Vector3(0, 0.125, 0.035)]
	var fr: Array = [0.045, 0.04, 0.028, 0.014, 0.0]
	g.spline_tube(fpts, fr, C.flame, 8, false, true, Vector3.RIGHT, 1.0, 0.6)
	for side: float in [-1.0, 1.0]:
		var sb := hc + Vector3(0.06 * side, 0.15, 0.03)
		var spts: Array = [sb, sb + Vector3(0.01 * side, 0.025, 0.004), sb + Vector3(0.02 * side, 0.05, 0.014)]
		g.spline_tube(spts, [0.024, 0.014, 0.0], C.flame, 6, false, true, Vector3.RIGHT, 1.0, 0.6)
	# 뿔: 머리 옆 위 속에서 시작해 바깥·위로 크게 휘어 오르고 끝이 조금 안쪽으로 모인다. 마디 능선은 반지름을 매끈하게 흔들어 만든다.
	# 키(HEIGHT)와 말풍선 높이(hp_bar_y)에 넣지 않는다(깃털·뿔과 같은 취급)
	g.measure_all = false
	for side: float in [-1.0, 1.0]:
		# 첫 마디는 머리 겉면 법선 방향으로 곧게 나와(뿌리가 표면을 스치지 않게) 둥근 깃이 되고, 그 다음 바깥·위로 휜다
		var hn := Vector3(0.72 * side, 0.62, 0.1).normalized()
		var p0 := hc + Vector3(hn.x * hr.x, hn.y * hr.y, hn.z * hr.z) * 0.7
		var p1 := hc + Vector3(hn.x * hr.x, hn.y * hr.y, hn.z * hr.z) * 1.45
		var p2 := hc + Vector3(0.36 * side, 0.3, 0.13)
		var p3 := hc + Vector3(0.25 * side, 0.4, 0.03)
		var nodes: Array = []
		var n := 14
		for i in n + 1:
			var t := float(i) / float(n)
			# 뿌리 0.066 → 가운데 ≥ 60% → 끝 25%(뭉툭), 홈 5개는 좁고 깊은 골(어두운 색)
			var r := 0.066 * (1.0 - 0.75 * pow(t, 1.5))
			var groove := pow(maxf(sin(t * PI * 5.0 - 0.3), 0.0), 3.0)
			r *= 1.0 - 0.14 * groove * (1.0 - t * 0.5)
			var col: Color = (C.horn as Color).lerp(C.horn_groove, groove * 0.8)
			if t > 0.8:
				col = col.lerp(C.horn_tip, (t - 0.8) / 0.2)
			nodes.append({p = DemonGeo.bez(p0, p1, p2, p3, t), r = r, bone = "Head", col = col, line = 0.0 if i < 2 else 1.0})
		g.limb(nodes, 8, Vector3.BACK, false, true, 2)
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
		g.ellipsoid(ec, Vector3(es * 1.14, es * 0.88, es * 0.9), C.eye, 16, 8, ebt)
		# 동공: 눈알 앞면에 붙은 세로 타원(살짝 안쪽을 본다) + 작은 반사광
		var pd := Vector3(-side * 0.1, -0.02, -1.0).normalized()
		var pc := ec + ebt * (Vector3(pd.x * es * 1.14, pd.y * es * 0.88, pd.z * es * 0.9) * 0.985)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.ellipsoid(pc, Vector3(es * 0.22, es * 0.62, es * 0.1), C.pupil, 10, 5, ebt)
		g.ellipsoid(pc + ebt * Vector3(side * es * 0.14, es * 0.3, -es * 0.06), Vector3(es * 0.07, es * 0.07, es * 0.03), C.white, 6, 3, ebt)
		# 윗눈꺼풀: 눈알보다 조금 큰 반구 덮개(피부색), 뼈 피벗은 눈 위. 표정이 Y 크기를 키우면 내려와 덮는다
		var lid_p := ec + ebt * Vector3(0, es * 0.95, 0)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.26, es * 2.3, es * 1.0), C.skin, 10, 4, ebt * Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈꺼풀 선: 눈알 윗부분을 덮는 짙은 띠(눈알보다 아주 조금 큰 윗 뚜껑). 눈 뼈에 붙어 깜빡임·표정과 같이 움직이고 떠다니지 않는다
		g.use("Eye" + sfx)
		g.ellipsoid(ec, Vector3(es * 1.16, es * 0.9, es * 0.92), C.lash, 16, 3, ebt, PI * 0.36, PI * 0.36, 0.0)
		# 눈썹: 짙은 붉은 갈색 능선 위의 띠, 안쪽 끝이 내려간다(기본 = 근엄). 양 끝은 가늘어져 표정(회전·내림)으로 움직여도 눈 속에 쐐기처럼 박히지 않는다
		var bd := Vector3(EYE_DIR_X * side, 0.4, -0.84).normalized()
		var bp := hc + Vector3(bd.x * hr.x, bd.y * hr.y, bd.z * hr.z) * 0.985
		g.add_bone("Brow" + sfx, "Head", bp)
		g.use("Brow" + sfx)
		var bi := Vector3(0.2 * side, 0.25, -0.95).normalized()
		var bo := Vector3(0.56 * side, 0.36, -0.72).normalized()
		var pi_ := hc + Vector3(bi.x * hr.x, bi.y * hr.y, bi.z * hr.z) * 0.96
		var po := hc + Vector3(bo.x * hr.x, bo.y * hr.y, bo.z * hr.z) * 0.96
		var bpts: Array = [pi_, pi_.lerp(bp, 0.5), bp, bp.lerp(po, 0.5), po]
		g.spline_tube(bpts, [0.0, es * 0.2, es * 0.24, es * 0.18, 0.0], C.brow, 8, false, false)
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
