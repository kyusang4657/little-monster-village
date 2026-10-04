class_name KnightV6Builder
extends RefCounted
## 인간 기사 5종 6차 교체 후보(디자인은 5차 KnightBuilder·컨셉 시트 「기사(5종)」 그대로, 만드는 방식만 악마 Lv.1 방식).
## 0 일반 기사 = 열린 투구(코가리개) + 앞으로 휘는 흰 깃, 붉은 하트 방패(흰 십자), 검
## 1 중갑 기사 = 통투구(어두운 눈 틈 + 빛나는 눈), 1.4배 두 겹 어깨, 한 단계 어두운 판금, 붉은 볏, 검
## 2 창기사 = 통투구 + 붉은 볏, 긴 창    3 망치 기사 = 통투구 + 파란 볏, 전쟁 망치
## 4 성기사 = 금 테 갑옷, 파란 망토(Cape 뼈), 파란 방패(금 십자), 붉은 볏, 검
## 만드는 방식(5차의 "조립한 도형" 대신 이어진 곡면):
## - 머리와 투구가 격자 조각 구 한 장: 위도·경도 격자선을 경계에 촘촘히 두고 영역(얼굴·금 테·투구·눈 틈)마다 반지름 배수와 색을 정해,
##   투구 가장자리(금 테 턱)·눈 틈 홈·얼굴의 눈두덩·볼·코가 한 면에서 또렷한 경계로 나뉜다(겹친 덮개·뺨 가리개 없음).
## - 몸통 = 회전체 한 장(목 → 금 깃 → 가슴판 → 금 아래 테 → 사슬 → 가죽 벨트 → 벌어진 허리 갑옷 + 금 단). 색은 고리마다 바뀐다.
## - 팔·다리 = 몸속에서 시작하는 이어진 관(사슬 → 팔꿈치·무릎 판 → 팔뚝·정강이 판 → 금 띠 → 건틀릿·장화 목), 관절에 구 없음.
## - 어깨 갑옷 = 종 모양 회전 껍데기(금 테가 같은 면의 고리), 장화 = 조각 구(쇠 앞코가 같은 면의 색).
## - 정점 명암 굽기 없음(bake 0), 공유 재질 CharacterRig.character_material(). 얼굴 부품·몸속 고리는 외곽선 0.
## 리그 규약은 5차와 같다: 기준점 = 두 발 사이 지면, 정면 -Z, 오른손 +X(무기, def.tip), 왼손 -X(방패), Plume(·Cape) 2차 뼈, 얼굴 뼈.
## 변형별 키 배율은 KnightBuilder.SCALE 을 그대로 쓴다(CharacterRig 이 적용).

const PLUME := ["f3ece4", "d0352a", "d0352a", "2f4fb0", "d0352a"]
const PLUME_SIZE := [1.02, 1.0, 1.0, 1.0, 1.28]

const SILVER := Color("9aa3ad")           # 판금(강철, 흰기 없음)
const SILVER_LIGHT := Color("a9b2bb")     # 투구·밝은 면
const SILVER_DARK := Color("76808a")
const HEAVY_PLATE := Color("7e8792")      # 중갑 기사: 한 단계 어두운 판금
const HEAVY_PLATE_DARK := Color("4f5862")
const HEAVY_HELM := Color("8b949e")
const STEEL := Color("5b6670")            # 사슬·어깨 밑·치마 밑 그늘 띠
const GOLD := Color("e1b23c")
const EYE_GLOW := Color("e8b23c")         # 통투구의 빛나는 눈
const GOLD_BAND := Color("c69a30")
const GOLD_DARK := Color("b1862b")
const RED := Color("c8343a")
const BLUE := Color("2f55b0")
const BLUE_DARK := Color("22407f")
const WHITE := Color("f4efe4")
const SKIN := Color("d9a67a")
const SKIN_SHADE := Color("2b2630")
const SLIT := Color("1e1a24")
const GLOW := Color("ffd86a")
const GLOW_DIM := Color("7d5f1e")
const LEATHER := Color("6b4a2b")
const LEATHER_LIGHT := Color("7d5a35")
const BOOT := Color("4e3220")
const BOOT_TOE := Color("7d8893")
const WOOD := Color("7a4b26")
const BLADE := Color("e6ecf2")
const HAMMER_DARK := Color("5c636b")
const IRIS := Color("3a2a1a")
const LASH := Color("2a1a14")
const BROW := Color("4a3222")
const LIP := Color("7a3a34")
const MOUTH_IN := Color("4a1f28")

## 골격(5차 3등신에서 머리를 8% 줄이고 그만큼 몸통을 올려 다리를 늘렸다. 키 1.15 는 그대로)
const DY := 0.03      # 몸통·팔이 5차 자리에서 올라간 높이
const LS := 1.075     # 다리 마디 높이 배율(발목 0.06 기준)
const P := {
	ankle = 0.08, knee = 0.243, hip = 0.425, hip_x = 0.104, pelvis = 0.45, spine = 0.52,
	shoulder = 0.76, shoulder_x = 0.21, elbow = 0.615, wrist = 0.485, neck = 0.79, head = 0.83,
	arm_r = 0.05, leg_r = 0.055, foot_len = 0.21,
}
const HC := Vector3(0, 0.9618, -0.0095)      # 얼굴(머리) 타원 중심
const HR := Vector3(0.1518, 0.1426, 0.1454)  # 얼굴 반지름(5차의 0.92배)
const HELM_C := Vector3(0, 0.982, -0.004)    # 투구 타원(꼭대기 1.152 = 5차와 같은 키)
const HELM_R := Vector3(0.1748, 0.1702, 0.1766)
## 머리 가로(x·z) 배율. 중갑 기사만 1.1(큰 체격). build() 가 변형마다 정한다
static var HW := 1.0

# 영역 번호(머리 격자)
const R_FACE := 0
const R_WALL := 1
const R_RIM := 2
const R_HELM := 3
const R_SLIT := 4
const R_SLIT_WALL_TOP := 5
const R_SLIT_WALL := 6

# 열린 투구(일반 기사): 얼굴 창 위 경계 위도, 반폭 경도, 금 테 폭
const LT := 1.08
const FW := 0.74
const RB := 0.17
const RBS := 0.1    # 얼굴 창 옆 금 테 폭(경도)
# 통투구: 눈 틈 위·아래 위도, 반폭 경도, 금 이마 띠 위쪽 위도
const S1 := 1.2
const S2 := 1.85
const SW := 1.18
const B1 := 1.0
const EPS := 0.004


static func build(v: int) -> Dictionary:
	var g := DemonGeo.new()
	g.bake = 0.0
	CharGeo.skeleton(g, P)
	var heavy := v == 1
	var elite := v == 4
	HW = 1.1 if heavy else 1.0
	var A := _armor(heavy)
	_body(g, v, heavy, elite, A)
	_pauldrons(g, heavy, A)
	_arms(g, v, heavy, elite, A)
	_legs(g, heavy, A)
	var es := _head(g, v, A)
	if elite:
		_cape(g)
	var hand_r := Vector3(float(P.shoulder_x), float(P.wrist) - float(P.arm_r) * 0.8, -float(P.arm_r) * 0.1)
	var hand_l := Vector3(-float(P.shoulder_x), hand_r.y, hand_r.z)
	g.measure = false
	g.measure_all = false
	var tip := hand_r
	match v:
		2:
			tip = _spear(g, hand_r)
		3:
			tip = _hammer(g, hand_r)
		_:
			tip = _sword(g, hand_r, elite)
	g.measure_all = true
	_shield(g, v, hand_l)
	g.measure = true
	var def := g.build(CharacterRig.character_material())
	def.tip = tip
	def.H = 1.15
	def.es = es
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


static func _armor(heavy: bool) -> Dictionary:
	if heavy:
		return {plate = HEAVY_PLATE, dark = HEAVY_PLATE_DARK, helm = HEAVY_HELM, light = Color("98a1ab")}
	return {plate = SILVER, dark = SILVER_DARK, helm = SILVER_LIGHT, light = SILVER_LIGHT}


## 몸통 프로파일 고리(높이는 5차 값 그대로 적고 DY 만큼 올린다)
static func _ring(y: float, rx: float, rz: float, bone: String, col: Color) -> Dictionary:
	return {y = y + DY, rx = rx, rz = rz, bone = bone, col = col}


## 회전체 프로파일에서 높이 y 의 반지름(key = "rx"/"rz")
static func _prof_r(prof: Array, y: float, key: String) -> float:
	for i in prof.size() - 1:
		var a: Dictionary = prof[i]
		var b: Dictionary = prof[i + 1]
		var ya: float = a.y
		var yb: float = b.y
		if y <= ya and y >= yb:
			return lerpf(float(a[key]), float(b[key]), (ya - y) / maxf(ya - yb, 0.0001))
	var last: Dictionary = prof[prof.size() - 1]
	return float(last[key])


# ------------------------------------------------------------------ 몸통(한 장의 회전체)

## 목(투구 속) → 사슬 깃 → 금 깃 테 → 둥근 가슴판 → 금 아래 테 → 사슬 배 → 가죽 벨트 → 아래로 벌어지는 허리 갑옷 → 금 단 → 사슬 엉덩이.
## 중갑은 가슴이 넓고 깊으며 가슴 가운데 가로 금 띠, 배 판 한 겹, 허리 갑옷이 두 단으로 더 낮게 내려온다.
static func _body(g: DemonGeo, v: int, heavy: bool, elite: bool, A: Dictionary) -> void:
	var plate: Color = A.plate
	var neck_col := SKIN if v == 0 else SKIN_SHADE
	var sx := 1.3 if heavy else 1.0
	var sz := 1.24 if heavy else 1.0
	var prof: Array = [
		_ring(0.83, 0.05, 0.05, "Neck", neck_col),
		_ring(0.778, 0.062, 0.06, "Neck", STEEL),
		_ring(0.762, 0.09, 0.086, "Spine", STEEL),
		_ring(0.752, 0.1, 0.094, "Spine", GOLD),
		_ring(0.736, 0.112, 0.1, "Spine", GOLD),
		_ring(0.73, 0.13 * sx, 0.11 * sz, "Spine", plate),
		_ring(0.708, 0.175 * sx, 0.134 * sz, "Spine", plate),
		_ring(0.672, 0.2 * sx, 0.15 * sz, "Spine", plate),
	]
	if heavy:
		prof.append_array([
			_ring(0.656, 0.206 * sx, 0.154 * sz, "Spine", plate),
			_ring(0.652, 0.207 * sx, 0.155 * sz, "Spine", GOLD),
			_ring(0.63, 0.207 * sx, 0.155 * sz, "Spine", GOLD),
			_ring(0.626, 0.206 * sx, 0.155 * sz, "Spine", plate),
		])
	else:
		prof.append(_ring(0.63, 0.206, 0.155, "Spine", plate))
	prof.append_array([
		_ring(0.575, 0.194 * sx, 0.147 * sz, "Spine", plate),
		_ring(0.564, 0.19 * sx, 0.145 * sz, "Spine", GOLD),
		_ring(0.524, 0.178 * sx, 0.137 * sz, "Spine", GOLD),
	])
	if heavy:
		# 배 판(가슴판 아래 한 겹 더 대는 판, 아랫단은 벨트에 묻힌다)
		prof.append_array([
			_ring(0.518, 0.176 * sx, 0.136 * sz, "Spine", plate),
			_ring(0.476, 0.17 * sx, 0.133 * sz, "Pelvis", plate),
		])
	else:
		prof.append_array([
			_ring(0.518, 0.166, 0.128, "Spine", STEEL),
			_ring(0.49, 0.161, 0.126, "Pelvis", STEEL),
		])
	var bx := 0.2 if heavy else 0.172
	prof.append_array([
		_ring(0.484 if not heavy else 0.468, bx, bx * 0.84, "Pelvis", LEATHER),
		_ring(0.442, bx + 0.002, bx * 0.84 + 0.002, "Pelvis", LEATHER),
		_ring(0.436, bx - 0.004, bx * 0.84 - 0.004, "Pelvis", plate),
	])
	if heavy:
		# 허리 갑옷 두 단(위 단 금 단 → 아래 단이 허벅지를 덮는다)
		prof.append_array([
			_ring(0.38, bx + 0.024, bx * 0.88 + 0.018, "Pelvis", plate),
			_ring(0.374, bx + 0.026, bx * 0.88 + 0.02, "Pelvis", GOLD),
			_ring(0.36, bx + 0.028, bx * 0.88 + 0.022, "Pelvis", GOLD),
			_ring(0.356, bx + 0.02, bx * 0.88 + 0.014, "Pelvis", plate),
			_ring(0.318, bx + 0.04, bx * 0.9 + 0.032, "Pelvis", plate),
			_ring(0.312, bx + 0.042, bx * 0.9 + 0.034, "Pelvis", GOLD),
			_ring(0.298, bx + 0.042, bx * 0.9 + 0.034, "Pelvis", GOLD),
			_ring(0.294, 0.15, 0.12, "Pelvis", STEEL),
		])
	else:
		prof.append_array([
			_ring(0.37, bx + 0.024, bx * 0.88 + 0.02, "Pelvis", plate),
			_ring(0.362, bx + 0.026, bx * 0.88 + 0.022, "Pelvis", GOLD),
			_ring(0.346, bx + 0.028, bx * 0.88 + 0.024, "Pelvis", GOLD),
			_ring(0.341, 0.15, 0.125, "Pelvis", STEEL),
		])
	g.lathe(prof, 12, false, true, 0.0, 0.0, func(i: int) -> float: return 0.0 if i < 1 else 1.0)
	# 가슴 가운데 세로 금 줄(가슴판 겉면을 따라간다)
	var rz_of := func(y: float) -> float: return _prof_r(prof, y, "rz")
	var rx_of := func(y: float) -> float: return _prof_r(prof, y, "rx")
	g.use("Spine")
	g.line = 0.35
	g.front_strip(-0.009, 0.009, 0.722 + DY, 0.566 + DY, rz_of, rx_of, 0.003, GOLD, 6)
	# 벨트 금 버클
	g.use("Pelvis")
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	var by := (0.462 if not heavy else 0.455) + DY
	var bz := -_prof_r(prof, by, "rz")
	g.line = 0.5
	g.polygon(PackedVector2Array([Vector2(-0.034, 0.022), Vector2(0.034, 0.022), Vector2(0.034, -0.022), Vector2(-0.034, -0.022)]),
		Vector3(0, by, bz - 0.004), fb, 0.008, GOLD, GOLD_DARK)
	g.line = 0.0
	g.polygon(PackedVector2Array([Vector2(-0.016, 0.01), Vector2(0.016, 0.01), Vector2(0.016, -0.01), Vector2(-0.016, -0.01)]),
		Vector3(0, by, bz - 0.009), fb, 0.004, GOLD_DARK)
	# 허리 갑옷 앞 판 나눔(앞 가운데 판 양옆 짙은 줄 두 개: 겹친 판으로 읽힌다)
	g.line = 0.0
	for s: float in [-1.0, 1.0]:
		g.front_strip(0.058 * s - 0.004, 0.058 * s + 0.004, 0.43 + DY, (0.37 if not heavy else 0.31) + DY, rz_of, rx_of, 0.002, A.dark, 4)
	if elite:
		# 성기사: 가슴 금 별 문장
		g.use("Spine")
		g.line = 0.4
		var sy := 0.645 + DY
		g.polygon(CharGeo.star(5, 0.046, 0.02), Vector3(0, sy, -_prof_r(prof, sy, "rz") - 0.004), fb, 0.008, GOLD, GOLD_DARK)
	g.line = 1.0


# ------------------------------------------------------------------ 어깨 갑옷(종 모양 껍데기)

## 어깨 갑옷: 꼭대기에서 아래로 벌어지는 종 모양 회전 껍데기(이어진 관 하나). 아랫단 금 테는 같은 면의 고리 색이고
## 단 아래에서 안쪽으로 말려 들어가 열린 테두리가 없다. 중갑은 1.4배에 한 겹(아래 판) 더, 꼭대기 금 징.
static func _pauldrons(g: DemonGeo, heavy: bool, A: Dictionary) -> void:
	var plate: Color = A.plate
	var pr := Vector3(0.123, 0.098, 0.123) if heavy else Vector3(0.088, 0.07, 0.088)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var bone := "Arm" + sfx
		var pc := Vector3(float(P.shoulder_x) * side + (0.05 if heavy else 0.014) * side, float(P.shoulder) - (0.02 if heavy else 0.028), 0)
		var tilt := Basis(Vector3.BACK, -0.28 * side)
		var up := tilt * Vector3.UP
		# (위도 각, 반지름 배수, 색): 꼭대기 → 단 → 안으로 말림(단 밑은 짙은 그늘 띠)
		var shape: Array = [[0.15, 1.0, plate], [0.55, 1.0, plate], [0.98, 1.0, plate], [1.3, 1.0, plate],
			[1.5, 1.0, plate], [1.53, 1.03, GOLD], [1.74, 1.04, GOLD], [1.88, 0.8, STEEL]]
		if heavy:
			# 두 번째 겹: 금 테 아래로 한 단 내려서며 더 벌어진다
			shape = [[0.15, 1.0, plate], [0.55, 1.0, plate], [0.98, 1.0, plate], [1.32, 1.0, plate],
				[1.36, 1.03, GOLD], [1.52, 1.03, GOLD], [1.56, 0.98, plate],
				[1.85, 1.13, plate], [1.9, 1.15, GOLD], [2.1, 1.14, GOLD], [2.2, 0.86, STEEL]]
		var nodes: Array = []
		for S: Array in shape:
			var a: float = S[0]
			var k: float = S[1]
			var yk := cos(a) * pr.y
			if a > 1.6 and heavy:
				# 아래 겹은 위 겹보다 더 낮게 내려온다
				yk = cos(1.6) * pr.y - (a - 1.6) * pr.y * 0.42
			nodes.append({p = pc + up * yk, r = pr.x * sin(minf(a, 1.57)) * k, bone = bone, col = S[2]})
		g.line = 1.0
		g.limb(nodes, 8, Vector3.FORWARD, true, true)
		g.use(bone)
		if heavy:
			g.line = 0.4
			g.sphere(pc + up * pr.y * 1.0, 0.022, GOLD, 5, 2)
		g.line = 1.0


# ------------------------------------------------------------------ 팔다리(이어진 관)

## 팔: 어깨 속(외곽선 0)에서 사슬 위팔 → 팔꿈치 판(불룩) → 팔뚝 판 → 건틀릿 소매(벌어짐) → 금 소매 테까지 한 관,
## 테 속에서 시작하는 모서리 둥근 상자 벙어리장갑(판금 색, 손 뼈) + 안쪽 엄지. 손 뼈 원점(손목)이 장갑 가운데라 무기 자루가 장갑 속을 지난다.
static func _arms(g: DemonGeo, v: int, heavy: bool, _elite: bool, A: Dictionary) -> void:
	var plate: Color = A.plate
	var ap := 1.16 if heavy else 1.0
	var hs := 1.1 if v == 3 else (1.05 if heavy else 1.0)
	var hy := float(P.wrist) - float(P.arm_r) * 0.8
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := (float(P.shoulder_x) + (0.025 if heavy else 0.0)) * side
		var nodes: Array = [
			{p = Vector3(x * 0.68, 0.7 + DY, 0.0), r = 0.05, bone = "Arm" + sfx, col = STEEL, line = 0.0},
			{p = Vector3(x * 0.98, 0.7 + DY, 0.0), r = 0.058 * ap, bone = "Arm" + sfx, col = STEEL, line = 0.0},
			{p = Vector3(x, 0.665 + DY, 0.0), r = 0.056 * ap, bone = "Arm" + sfx, col = STEEL},
			{p = Vector3(x, 0.625 + DY, 0.0), r = 0.053 * ap, bone = "Arm" + sfx, col = STEEL},
			{p = Vector3(x, 0.598 + DY, 0.0), r = 0.058 * ap, bone = "Forearm" + sfx, col = plate},
			{p = Vector3(x, 0.582 + DY, 0.004), r = 0.063 * ap, bone = "Forearm" + sfx, col = plate},
			{p = Vector3(x, 0.52 + DY, 0.0), r = 0.055 * ap, bone = "Forearm" + sfx, col = plate},
			{p = Vector3(x, 0.5 + DY, 0.0), r = 0.058 * ap, bone = "Hand" + sfx, col = plate},
			{p = Vector3(x, 0.482 + DY, 0.0), r = 0.062 * ap * hs, bone = "Hand" + sfx, col = GOLD},
			{p = Vector3(x, 0.462 + DY, 0.0), r = 0.062 * ap * hs, bone = "Hand" + sfx, col = GOLD},
			{p = Vector3(x, 0.454 + DY, 0.0), r = 0.056 * ap * hs, bone = "Hand" + sfx, col = plate, line = 0.0},
		]
		g.limb(nodes, 8, Vector3.FORWARD, false, true)
		# 벙어리장갑: 손목(손 뼈 원점)을 가운데로 둔 둥근 상자. 위쪽은 금 테 속에 묻힌다
		g.use("Hand" + sfx)
		g.line = 1.0
		var mc := Vector3(x, hy - 0.004, -0.004)
		var mr := Vector3(0.05 * ap, 0.046, 0.037) * hs
		g.rounded_box(mc, mr, plate, 0.5, 10, 5)
		# 엄지(안쪽 앞): 장갑에 반쯤 묻힌 작은 혹
		g.line = 0.35
		g.ellipsoid(mc + Vector3(-side * mr.x * 0.9, 0.008, -mr.z * 0.6), Vector3(0.018, 0.026, 0.02) * hs, plate, 6, 2)
		g.line = 1.0


## 다리: 허리 갑옷 속(외곽선 0)에서 사슬 허벅지 → 무릎 판(불룩) → 정강이 판 → 금 띠 → 장화 목까지 한 관,
## 장화는 쇠 앞코가 같은 면의 색인 조각 구(발 뼈). 중갑은 정강이·장화가 크다.
## 다리 마디 높이: 5차 값을 발목 기준으로 LS 배 늘린다
static func _ly(y: float) -> float:
	return 0.06 + (y - 0.06) * LS


static func _legs(g: DemonGeo, heavy: bool, A: Dictionary) -> void:
	var plate: Color = A.plate
	var gs := 1.2 if heavy else 1.0
	var bs := 1.68 if heavy else 1.5
	var bw := 1.44 if heavy else 1.34
	var lr: float = P.leg_r
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := float(P.hip_x) * side
		var nodes: Array = [
			{p = Vector3(x * 0.8, _ly(0.46), 0.0), r = 0.066, bone = "Leg" + sfx, col = STEEL, line = 0.0},
			{p = Vector3(x, _ly(0.4), 0.0), r = 0.067 * (1.08 if heavy else 1.0), bone = "Leg" + sfx, col = STEEL},
			{p = Vector3(x, _ly(0.262), 0.0), r = 0.056 * gs, bone = "Leg" + sfx, col = STEEL},
			{p = Vector3(x, _ly(0.252), 0.0), r = 0.058 * gs, bone = "Shin" + sfx, col = plate},
			{p = Vector3(x, _ly(0.232), -0.006), r = 0.064 * gs, bone = "Shin" + sfx, col = plate},
			{p = Vector3(x, _ly(0.194), 0.0), r = 0.056 * gs, bone = "Shin" + sfx, col = plate},
			{p = Vector3(x, _ly(0.19), 0.0), r = 0.0585 * gs, bone = "Shin" + sfx, col = GOLD},
			{p = Vector3(x, _ly(0.168), 0.0), r = 0.058 * gs, bone = "Shin" + sfx, col = GOLD},
			{p = Vector3(x, _ly(0.163), 0.0), r = 0.055 * gs, bone = "Shin" + sfx, col = plate},
		]
		if heavy:
			nodes.append_array([
				{p = Vector3(x, _ly(0.146), 0.0), r = 0.056 * gs, bone = "Shin" + sfx, col = GOLD},
				{p = Vector3(x, _ly(0.132), 0.0), r = 0.056 * gs, bone = "Shin" + sfx, col = GOLD},
			])
		nodes.append_array([
			{p = Vector3(x, _ly(0.118), 0.0), r = 0.054 * gs, bone = "Foot" + sfx, col = plate},
			{p = Vector3(x, _ly(0.112), 0.0), r = 0.062 * gs, bone = "Foot" + sfx, col = BOOT.darkened(0.15)},
			{p = Vector3(x, _ly(0.06), 0.0), r = 0.07 * gs, bone = "Foot" + sfx, col = BOOT, line = 0.0},
		])
		g.limb(nodes, 8, Vector3.FORWARD, false, false)
		# 장화: 발꿈치~앞코 조각 구. 바닥은 평평하게 눌리고 앞코 쪽은 쇠(색만 바뀐다), 바닥 둘레는 짙은 밑창
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		var fh: float = P.ankle
		var br := Vector3(lr * 1.3 * bw, fh * 0.6 * bs, fl * 0.48 * bs)
		var bc := Vector3(x, br.y * 0.86, -fl * 0.2 * bs)
		var bshape := func(d: Vector3) -> float:
			var k := 1.0
			# 바닥은 평평한 밑창(아래 방향일수록 반지름을 줄여 y = -0.86 r 평면에 맞춘다)
			if d.y < -0.1:
				k = minf(k, 0.86 / -d.y)
			# 발등은 조금 낮다
			k -= 0.05 * DemonGeo.bump(d, Vector3(0, 0.7, -0.7).normalized(), 0.35)
			return maxf(k, 0.5)
		var bcol := func(_d: Vector3, q: Vector3) -> Color:
			if q.y < -br.y * 0.78:
				return BOOT.darkened(0.35)
			if q.z < -br.z * 0.62:
				return BOOT_TOE
			return BOOT
		g.sculpt(bc, br, BOOT, 8, 5, bshape, bcol)


# ------------------------------------------------------------------ 머리(격자 조각 구 한 장)

## 격자 조각 구: lats(0 = 정수리 → PI = 아래), lons(-PI → PI, 0 = 정면 -Z) 격자선을 받아 정점마다 영역 rf(lat, lon) 을 정하고,
## 영역별 반지름 배수 kf(reg, lat, lon) 와 색 cf(reg, lat, lon) 로 겉면을 만든다. 영역 경계에 격자선을 두 줄 가깝게 두면
## 색·높이가 그 사이에서 또렷하게 바뀐다(투구 테 턱·눈 틈 홈). 법선은 정점 자기 영역의 매끈한 면에서 계산한다.
## 정점 위치 = HC + (방향 ∘ HR) × k.
static func _grid_head(g: DemonGeo, lats: Array, lons: Array, rf: Callable, kf: Callable, cf: Callable) -> void:
	var nl := lats.size()
	var nm := lons.size()
	var base := g.v.size()
	var dl := 0.01
	for i in nl:
		var la: float = lats[i]
		for j in nm:
			var lo: float = lons[j]
			var reg: int = rf.call(la, lo)
			var p := _hp(la, lo, float(kf.call(reg, la, lo)))
			var nn: Vector3
			if i == 0:
				nn = Vector3.UP
			elif i == nl - 1:
				nn = Vector3.DOWN
			else:
				var pa := _hp(la + dl, lo, float(kf.call(reg, la + dl, lo))) - _hp(la - dl, lo, float(kf.call(reg, la - dl, lo)))
				var pb := _hp(la, lo + dl, float(kf.call(reg, la, lo + dl))) - _hp(la, lo - dl, float(kf.call(reg, la, lo - dl)))
				nn = pb.cross(pa).normalized()
				if nn.dot(p - HC) < 0.0:
					nn = -nn
			g._vert(p, nn, cf.call(reg, la, lo))
	for i in nl - 1:
		for j in nm - 1:
			var a := base + i * nm + j
			var b := a + 1
			var d := a + nm
			var e := d + 1
			if i > 0:
				g.tri(a, b, d)
			if i < nl - 2:
				g.tri(b, e, d)


static func _hdir(la: float, lo: float) -> Vector3:
	return Vector3(sin(la) * sin(lo), cos(la), -sin(la) * cos(lo))


static func _hp(la: float, lo: float, k: float) -> Vector3:
	return _hpt(_hdir(la, lo), k)


## 얼굴 타원 위 방향 d 의 배수 k 지점(머리 가로 배율 HW 적용)
static func _hpt(d: Vector3, k: float) -> Vector3:
	return HC + Vector3(d.x * HR.x * HW, d.y * HR.y, d.z * HR.z * HW) * k


## 얼굴 타원 위 방향 d 의 반직선이 투구 타원(HELM_C, HELM_R, 가로 HW 배)과 만나는 배수 k
static func _helm_k(d: Vector3) -> float:
	var e := Vector3(d.x * HR.x * HW, d.y * HR.y, d.z * HR.z * HW)
	var hr := Vector3(HELM_R.x * HW, HELM_R.y, HELM_R.z * HW)
	var o := (HC - HELM_C) / hr
	var dd := e / hr
	var a := dd.dot(dd)
	var b := 2.0 * o.dot(dd)
	var c := o.dot(o) - 1.0
	return (-b + sqrt(maxf(b * b - 4.0 * a * c, 0.0))) / (2.0 * a)


## 눈 방향(얼굴 타원 위 단위 방향)
static func _eye_dir(side: float, full_helm: bool) -> Vector3:
	if full_helm:
		return _hdir(1.5, 0.42 * side)
	return Vector3(0.39 * side, -0.02, -0.92).normalized()


## 일반 기사 얼굴의 조각(눈두덩 패임·눈썹 능선·볼·코·턱)
static func _face_k(d: Vector3) -> float:
	var k := 1.0
	k -= 0.06 * (DemonGeo.bump(d, _eye_dir(-1.0, false), 0.26) + DemonGeo.bump(d, _eye_dir(1.0, false), 0.26))
	k += 0.012 * (DemonGeo.bump(d, Vector3(-0.4, 0.34, -0.85).normalized(), 0.3) + DemonGeo.bump(d, Vector3(0.4, 0.34, -0.85).normalized(), 0.3))
	k += 0.035 * (DemonGeo.bump(d, Vector3(-0.62, -0.38, -0.68).normalized(), 0.42) + DemonGeo.bump(d, Vector3(0.62, -0.38, -0.68).normalized(), 0.42))
	k += 0.05 * DemonGeo.bump(d, Vector3(0, -0.2, -1.0).normalized(), 0.13)
	k += 0.02 * DemonGeo.bump(d, Vector3(0, -0.6, -0.8).normalized(), 0.3)
	return k


## 경도 격자: 앞(±front) 은 촘촘히(fs 칸), 경계 둘레(extra: 양수 값, 좌우 대칭)에는 겹친 선, 뒤는 성기게(bs 칸)
static func _lon_list(front: float, fs: int, extra: Array, back_from: float, bs: int) -> Array:
	var vals: Array = []
	for i in fs + 1:
		vals.append(lerpf(-front, front, float(i) / float(fs)))
	for e: float in extra:
		vals.append(e)
		vals.append(-e)
	for i in bs + 1:
		var t := lerpf(back_from, PI, float(i) / float(bs))
		vals.append(t)
		vals.append(-t)
	vals.sort()
	var out: Array = []
	for x: float in vals:
		if out.is_empty() or x - float(out[out.size() - 1]) > 0.001:
			out.append(x)
	return out


## 머리: 일반 기사(0) = 얼굴 창이 열린 둥근 투구(금 테가 투구 면 가장자리의 턱, 코가리개), 1~4 = 통투구(금 이마 띠 아래 어두운 눈 틈 홈 +
## 빛나는 눈, 아래는 얼굴 판과 숨구멍). 볏줄·깃 꽂이·깃털. 눈 크기를 돌려준다.
static func _head(g: DemonGeo, v: int, A: Dictionary) -> float:
	var full := v != 0
	var helm: Color = A.helm
	g.use("Head")
	var lats: Array
	var lons: Array
	var rf: Callable
	if not full:
		lats = [0.0, 0.48, LT - RB - EPS, LT - RB, LT - EPS, LT - EPS * 0.5, LT, 1.25, 1.42, 1.58, 1.74, 1.92, 2.14, 2.42, 2.78, PI]
		lons = _lon_list(FW, 8, [FW + EPS * 0.5, FW + EPS, FW + RBS, FW + RBS + EPS], FW + RBS + EPS + 0.4, 3)
		rf = func(la: float, lo: float) -> int:
			var a := absf(lo)
			if la >= LT - 0.0005 and a <= FW + 0.0005:
				return R_FACE
			if la >= LT - EPS * 0.5 - 0.0005 and a <= FW + EPS * 0.5 + 0.0005:
				return R_WALL
			if la >= LT - RB - 0.0005 and la < LT - 0.0005:
				return R_RIM
			if la >= LT - 0.0005 and a <= FW + RBS + 0.0005:
				return R_RIM
			return R_HELM
	else:
		lats = [0.0, 0.5, B1 - EPS, B1, S1 - EPS, S1 - EPS * 0.5, S1, 1.42, 1.64, S2, S2 + EPS * 0.5, S2 + EPS, 2.06, 2.34, 2.72, PI]
		lons = _lon_list(SW, 10, [SW + EPS * 0.5, SW + EPS], SW + EPS + 0.35, 3)
		rf = func(la: float, lo: float) -> int:
			var a := absf(lo)
			if la >= S1 - 0.0005 and la <= S2 + 0.0005 and a <= SW + 0.0005:
				return R_SLIT
			if la >= S1 - EPS * 0.5 - 0.0005 and la <= S2 + EPS * 0.5 + 0.0005 and a <= SW + EPS * 0.5 + 0.0005:
				return R_SLIT_WALL_TOP if la < S1 else R_SLIT_WALL
			if la >= B1 - 0.0005 and la < S1 - 0.0005:
				return R_RIM
			return R_HELM
	var kf := func(reg: int, la: float, lo: float) -> float:
		var d := _hdir(la, lo)
		match reg:
			R_FACE, R_WALL:
				return _face_k(d)
			R_SLIT, R_SLIT_WALL_TOP, R_SLIT_WALL:
				return 1.0 + 0.004 * absf(d.x)
			R_RIM:
				return _helm_k(d) * 1.018
		return _helm_k(d)
	var cf := func(reg: int, _la: float, _lo: float) -> Color:
		match reg:
			R_FACE:
				return SKIN
			R_WALL:
				return Color("3a3138")
			R_RIM, R_SLIT_WALL_TOP:
				return GOLD_BAND
			R_SLIT:
				return SLIT
			R_SLIT_WALL:
				return (helm as Color).darkened(0.35)
		return helm
	g.line = 1.0
	_grid_head(g, lats, lons, rf, kf, cf)
	var es := 0.025 if full else 0.036
	_face(g, full, es)
	g.use("Head")
	if full:
		# 숨구멍 셋(얼굴 판에 반쯤 묻힌 짙은 점)
		g.line = 0.0
		for k in 3:
			var d := _hdir(2.18, (float(k) - 1.0) * 0.2)
			var p := _hpt(d, _helm_k(d))
			g.ellipsoid(p, Vector3(0.009, 0.013, 0.006), SLIT, 5, 2, Basis.looking_at(d, Vector3.UP))
		g.line = 1.0
	else:
		# 코가리개: 이마 금 테 한가운데에서 코끝까지 내려오는 납작한 쇠 막대(뿌리는 테 속)
		var top_d := _hdir(LT - RB * 0.5, 0.0)
		var p0 := _hpt(top_d, (_helm_k(top_d) * 0.99))
		var pts: Array = [p0]
		var rad: Array = [0.0135]
		for la: float in [LT + 0.05, 1.32, 1.56, 1.72]:
			var d := _hdir(la, 0.0)
			pts.append(_hpt(d, (_face_k(d) + 0.075)))
			rad.append(0.0125 if la < 1.6 else 0.0105)
		g.line = 0.8
		g.spline_tube(pts, rad, SILVER, 6, false, true, Vector3.RIGHT, 1.0, 0.55)
		g.line = 1.0
	# 볏줄: 이마 띠에서 꼭대기를 넘어 뒤까지 투구 면을 따라가는 금 띠(외곽선 거의 없음)
	var comb: Array = []
	var comb_r: Array = []
	var a0 := (LT - RB) if not full else B1
	var nseg := 7
	for i in nseg + 1:
		var t := float(i) / float(nseg)
		var la := lerpf(-a0 + 0.04, 1.55, t)
		var d := _hdir(absf(la), 0.0 if la < 0.0 else PI)
		comb.append(_hpt(d, (_helm_k(d) * 1.012)))
		comb_r.append(0.02 * (1.0 - 0.3 * absf(t * 2.0 - 1.0)))
	g.measure = false
	g.line = 0.12
	g.spline_tube(comb, comb_r, GOLD, 5, true, true, Vector3.RIGHT, 1.0, 0.45)
	# 깃 꽂이(금)와 깃털(Plume 뼈)
	var top_y := HELM_C.y + HELM_R.y
	var plume_base := Vector3(0, top_y - 0.01, HELM_C.z)
	g.line = 0.5
	g.tube(plume_base, plume_base + Vector3(0, 0.032, 0), 0.034, 0.029, GOLD, 8, true)
	g.line = 1.0
	_plume(g, v)
	g.measure = true
	return es


## 눈·눈썹·입. 일반 기사: 눈두덩 속 흰 눈알 + 큰 갈색 눈동자 + 반사광, 눈알 윗부분을 덮는 짙은 뚜껑(속눈썹 선), 끝이 가는 눈썹, 입 세 가지.
## 통투구: 눈 틈 홈 속의 빛나는 노란 눈(짙은 뚜껑이 위를 덮는다), 틈 위쪽 가장자리 아래의 짙은 쇠 능선 눈썹, 입은 얼굴 판 뒤에 숨는다.
## 뼈 이름·피벗은 CharacterRig 표정 규약 그대로(눈꺼풀 = Y 크기로 내려 덮음, 눈썹 = 회전·내림, 입 = 크기 0/1).
static func _face(g: DemonGeo, full: bool, es: float) -> void:
	var keep := g.line
	g.line = 0.0
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var d := _eye_dir(side, full)
		var surf_k := 1.0 if full else _face_k(d)
		var floor_p := _hpt(d, surf_k)
		var eb := Basis.looking_at(d, Vector3.UP)
		# 납작한 타원 눈(20각): 앞면이 눈두덩(통투구는 눈 틈 바닥)과 거의 같은 높이라 투구 밖으로 튀어나오지 않는다
		var er := Vector3(es * 1.0, es * 1.12, es * 0.3) if not full else Vector3(es * 1.1, es * 0.9, es * 0.22)
		var ec := floor_p - d * (es * 0.26) if not full else floor_p + d * 0.004
		if full:
			# 감은 눈의 희미한 빛줄기(눈 틈 바닥, 뜬 눈알 렌즈 속에 숨어 있다가 눈알이 눌리면 보인다)
			g.use("Head")
			var lx := eb * Vector3(es * 0.7, 0, 0)
			g.spline_tube([floor_p - lx + d * 0.001, floor_p + d * 0.003, floor_p + lx + d * 0.001], [es * 0.1, es * 0.14, es * 0.1], GLOW_DIM, 4, true, true)
		g.add_bone("Eye" + sfx, "Head", ec)
		g.use("Eye" + sfx)
		# 극축을 시선 방향으로 돌린 납작한 렌즈: 정면에서 20각 타원 윤곽
		var fb := eb * Basis(Vector3.RIGHT, -PI * 0.5)
		g.ellipsoid(ec, Vector3(er.x, er.z, er.y), EYE_GLOW if full else Color("f6f3ea"), 20, 2, fb)
		# 눈동자: 일반 기사 = 눈알 앞면의 큰 짙은 갈색 홍채 판 + 반사광 하나. 통투구 = 빛나는 타원뿐(뼈만 둔다)
		var pd := Vector3(-side * 0.08, -0.06, -1.0).normalized()
		var pc := ec + eb * (Vector3(pd.x * er.x, pd.y * er.y, pd.z * er.z) * 0.75)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		if not full:
			g.ellipsoid(pc, Vector3(es * 0.6, es * 0.1, es * 0.74), IRIS, 20, 2, fb)
			g.ellipsoid(pc + eb * Vector3(-side * es * 0.22, es * 0.3, -es * 0.1), Vector3(es * 0.16, es * 0.16, es * 0.05), Color.WHITE, 8, 2, eb)
		# 윗눈꺼풀: 눈 위 피벗의 반구 덮개. 표정이 Y 크기를 키우면 내려와 덮는다
		var lid_p := ec + eb * Vector3(0, er.y * 0.95, 0)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(er.x * 1.14, er.y * 2.2, er.z * 1.6), SLIT if full else SKIN.darkened(0.05), 8, 2, eb * Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		if not full:
			# 눈 위 가장자리를 따라가는 짙은 속눈썹 선(눈 뼈에 붙어 깜빡임과 같이 움직인다)
			g.use("Eye" + sfx)
			var arc: Array = []
			var arc_r: Array = []
			for k in 5:
				var a := lerpf(PI * 0.15, PI * 0.85, float(k) / 4.0)
				arc.append(ec + eb * Vector3(cos(a) * er.x * 1.02, sin(a) * er.y * 1.02, -er.z * 0.35))
				arc_r.append(es * (0.05 if k == 0 or k == 4 else 0.09))
			g.spline_tube(arc, arc_r, LASH, 4, true, true, Vector3.FORWARD)
		# 눈썹
		var bd: Vector3
		var bi: Vector3
		var bo: Vector3
		if full:
			bd = _hdir(S1 + 0.07, 0.42 * side)
			bi = _hdir(S1 + 0.1, 0.2 * side)
			bo = _hdir(S1 + 0.07, 0.62 * side)
		else:
			bd = Vector3(0.38 * side, 0.36, -0.85).normalized()
			bi = Vector3(0.17 * side, 0.3, -0.94).normalized()
			bo = Vector3(0.58 * side, 0.32, -0.75).normalized()
		var bp := _hpt(bd, ((1.0 if full else _face_k(bd)) + 0.004))
		var pi_ := _hpt(bi, ((1.0 if full else _face_k(bi)) - 0.01))
		var po := _hpt(bo, ((1.0 if full else _face_k(bo)) - 0.01))
		g.add_bone("Brow" + sfx, "Head", bp)
		g.use("Brow" + sfx)
		var bt := es * (0.2 if full else 0.24)
		g.spline_tube([pi_, pi_.lerp(bp, 0.5), bp, bp.lerp(po, 0.5), po], [0.0, bt * 0.85, bt, bt * 0.75, 0.0],
			Color("3b3542") if full else BROW, 6, false, false)
	# 입
	var md := Vector3(0, -0.6, -0.8).normalized()
	var mp := _hpt(md, (_face_k(md) + 0.004))
	var mw := 0.07
	g.add_bone("MouthN", "Head", mp)
	g.use("MouthN")
	if full:
		# 통투구: 입은 얼굴 판 뒤에 숨는다(뼈 규약만 지킨다)
		var hid := mp + Vector3(0, 0, 0.05)
		g.ellipsoid(hid, Vector3(0.006, 0.006, 0.006), MOUTH_IN, 4, 2)
		g.add_bone("MouthA", "Head", mp)
		g.use("MouthA")
		g.ellipsoid(hid, Vector3(0.006, 0.006, 0.006), MOUTH_IN, 4, 2)
		g.add_bone("MouthH", "Head", mp)
		g.use("MouthH")
		g.ellipsoid(hid, Vector3(0.006, 0.006, 0.006), MOUTH_IN, 4, 2)
		g.use("Head")
		g.line = keep
		return
	var pts: Array = []
	for i in 5:
		var u := float(i) / 2.0 - 1.0
		pts.append(mp + Vector3(u * mw * 0.5, u * u * mw * 0.16, absf(u) * 0.01))
	g.sweep(pts, mw * 0.07, LIP, 4)
	g.add_bone("MouthA", "Head", mp)
	g.use("MouthA")
	g.ellipsoid(mp + Vector3(0, -0.006, 0.004), Vector3(mw * 0.4, mw * 0.25, 0.012), MOUTH_IN, 10, 4)
	g.ellipsoid(mp + Vector3(0, 0.006, -0.002), Vector3(mw * 0.3, mw * 0.06, 0.008), Color.WHITE, 8, 3)
	g.add_bone("MouthH", "Head", mp)
	g.use("MouthH")
	var wav: Array = []
	for i in 7:
		var u := float(i) / 3.0 - 1.0
		wav.append(mp + Vector3(u * mw * 0.45, sin(u * PI * 1.5) * mw * 0.06, absf(u) * 0.008))
	g.sweep(wav, mw * 0.06, MOUTH_IN, 4)
	g.use("Head")
	g.line = keep


## 깃털 볏(5차와 같은 모양): 투구 꼭대기에서 솟았다가 뒤로 흘러내리는 겹친 깃(성기사 다섯 가닥). 일반 기사(0)의 흰 깃은 앞으로 휜다.
## 모두 Plume 뼈. 단면은 옆으로 얇고 앞뒤로 넓다.
static func _plume(g: DemonGeo, v: int) -> void:
	var hc2 := HELM_C
	var hr2 := HELM_R
	var base := hc2 + Vector3(0, hr2.y, 0)
	g.add_bone("Plume", "Head", base + Vector3(0, 0.02, 0))
	g.use("Plume")
	var col := Color(PLUME[v])
	var ps: float = PLUME_SIZE[v]
	var forward := v == 0
	var n := 5 if v == 4 else 4
	var nseg := 5
	for k in n:
		var t := float(k) / float(n - 1)
		var phi := lerpf(0.0, 0.55, t)
		var length := (0.44 - 0.12 * t) * ps
		var a0 := phi + 0.1
		var a1 := 1.95 + 0.35 * t
		var ez := 1.6
		if forward:
			phi = lerpf(0.32, 0.62, t)
			a0 = 0.45 - 0.1 * t
			a1 = -1.75 + 0.3 * t
			ez = 1.25
		var lat := float((k % 2) * 2 - 1) * 0.013 * ps
		var p := hc2 + Vector3(lat, cos(phi) * hr2.y, sin(phi) * hr2.z * HW) * 0.97
		var pts: Array = []
		var radii: Array = []
		var r0 := 0.034 * ps
		for i in nseg + 1:
			var u := float(i) / float(nseg)
			pts.append(p)
			radii.append(r0 * (0.5 + 0.75 * pow(sin(u * PI), 0.8)) if i < nseg else r0 * 0.25)
			var a := lerpf(a0, a1, pow((float(i) + 0.5) / float(nseg), ez))
			p += Vector3(0, cos(a), sin(a)) * (length / float(nseg))
		var shade := col.lightened(0.1) if k % 2 == 0 else col.darkened(0.12)
		g.spline_tube(pts, radii, shade, 4, true, true, Vector3.RIGHT, 0.7, 1.8 if forward else 1.6)


# ------------------------------------------------------------------ 망토(성기사)

## 성기사의 파란 망토: 어깨 높이에서 양쪽 어깨 갑옷 끝까지 걸쳐 늘어지는 두 겹 천(앞·뒤 면이 두께만큼 떨어짐), 세로 주름 둘(u = ±¼ 골),
## 양옆·아랫단에 굵은 금 테(두께가 보인다). 아래로 넓어져 뒤에서 보면 방패를 가린다. Cape 뼈로 흔들린다.
static func _cape(g: DemonGeo) -> void:
	var top := Vector3(0, float(P.shoulder) + 0.012, 0.148)
	g.add_bone("Cape", "Spine", top)
	g.use("Cape")
	g.measure = false
	var length := 0.47
	var w_top := 0.66
	var w_bot := 0.9
	var rows := 5
	var cols := 6
	var th := 0.009
	var grid: Array = []
	for i in rows + 1:
		var t := float(i) / float(rows)
		var w := lerpf(w_top, w_bot, t)
		var row: Array = []
		for j in cols + 1:
			var u := float(j) / float(cols) - 0.5
			var y := top.y - length * t - 0.02 * t * t * (0.5 + 0.5 * cos(u * TAU * 1.5))
			# 뒤로 늘어짐 + 양옆이 몸을 감쌈 + 세로 주름(가운데·양끝 능선, ±¼ 골)
			var z := top.z + 0.06 * t * t - 0.05 * (u * u * 4.0) * (0.3 + 0.7 * t) + 0.02 * (0.15 + 0.85 * t) * cos(u * TAU * 2.0)
			row.append(Vector3(top.x + u * w, y, z))
		grid.append(row)
	var keep := g.line
	g.line = 0.8
	for sgn: float in [1.0, -1.0]:
		var col := BLUE if sgn > 0.0 else BLUE_DARK
		var b0 := g.v.size()
		for i in rows + 1:
			for j in cols + 1:
				var pt: Vector3 = grid[i][j]
				var du: Vector3 = (grid[i][mini(j + 1, cols)] as Vector3) - (grid[i][maxi(j - 1, 0)] as Vector3)
				var dt: Vector3 = (grid[mini(i + 1, rows)][j] as Vector3) - (grid[maxi(i - 1, 0)][j] as Vector3)
				var nn := du.cross(dt).normalized()
				if nn.z < 0.0:
					nn = -nn
				nn *= sgn
				g._vert(pt + nn * th, nn, col)
		for i in rows:
			for j in cols:
				var q := b0 + i * (cols + 1) + j
				var dq := q + cols + 1
				g.tri(q, q + 1, dq)
				g.tri(q + 1, dq + 1, dq)
	g.line = keep
	var left: Array = []
	var right: Array = []
	var hem: Array = []
	for i in rows + 1:
		left.append(grid[i][0])
		right.append(grid[i][cols])
	for j in cols + 1:
		hem.append(grid[rows][j])
	g.line = 0.3
	for edge: Array in [left, right, hem]:
		var er: Array = []
		for _q: Vector3 in edge:
			er.append(th * 1.4)
		g.spline_tube(edge, er, GOLD, 4, true, true)
	# 망토를 거는 금 막대(어깨 뒤, 양쪽 어깨 갑옷 사이)
	g.line = 0.45
	g.tube(Vector3(-w_top * 0.5, top.y, top.z - 0.004), Vector3(w_top * 0.5, top.y, top.z - 0.004), 0.013, 0.013, GOLD, 6, true)
	g.line = 1.0
	g.measure = true


# ------------------------------------------------------------------ 무기·방패(5차 규약 그대로)

static func _grip_dir(deg: float = 30.0) -> Vector3:
	var gr := deg_to_rad(deg)
	return Vector3(0, -cos(gr), -sin(gr))


## 검(오른손): 가죽 손잡이·금 공·금 날밑, 넓고 밝은 날(가운데 홈). 끝점을 돌려준다.
static func _sword(g: DemonGeo, hand: Vector3, elite: bool) -> Vector3:
	g.use("HandR")
	var d := _grip_dir()
	var side := Vector3.RIGHT.cross(d)
	var sw := 0.042
	var sl := 0.46
	var fist := 0.045
	g.tube(hand - d * (fist + 0.025), hand + d * (fist + 0.01), 0.017, 0.017, LEATHER, 6, false)
	g.sphere(hand - d * (fist + 0.03), 0.027, GOLD, 8, 4)
	g.line = 0.6
	g.rounded_box(hand + d * (fist + 0.012), Vector3(sw * 2.6, 0.016, 0.022), GOLD, 0.4, 8, 4, Basis(Vector3.RIGHT, d, side))
	if elite:
		g.sphere(hand + d * (fist + 0.012) + side * 0.024, 0.016, RED, 5, 2)
	g.line = 1.0
	var b0 := hand + d * (fist + 0.026)
	var blade_end := b0 + d * sl
	var tip := blade_end + d * sw * 2.4
	# 날: 이어진 관 하나(납작한 단면, 끝이 뾰족)
	g.limb([{p = b0, r = sw, bone = "HandR", col = BLADE, fu = 1.0, fw = 0.25},
		{p = blade_end, r = sw * 0.9, bone = "HandR", col = BLADE, fu = 1.0, fw = 0.25},
		{p = blade_end.lerp(tip, 0.55), r = sw * 0.55, bone = "HandR", col = BLADE, fu = 1.0, fw = 0.25},
		{p = tip, r = 0.0, bone = "HandR", col = BLADE, fu = 1.0, fw = 0.25}], 6, Vector3.RIGHT, true, false)
	g.line = 0.0
	g.tube(b0 + d * 0.02 - side * sw * 0.26, blade_end - d * 0.03 - side * sw * 0.26, sw * 0.18, sw * 0.14, SILVER_DARK, 4, false, 1.0, 0.4)
	g.line = 1.0
	return tip


## 창(오른손): 긴 나무 자루, 쇠 자루 끝, 가죽 손잡이, 금 깃 테와 은 꽂이, 잎 모양 은 창날(창날은 주먹 아래 앞쪽).
static func _spear(g: DemonGeo, hand: Vector3) -> Vector3:
	g.use("HandR")
	var d := (Basis(Vector3.BACK, 0.25) * _grip_dir(30.0)).normalized()
	var side := Vector3.RIGHT.cross(d).normalized()
	var back := 0.5
	var fwd := 0.3
	g.spline_tube([hand - d * back, hand - d * 0.12, hand + d * 0.12, hand + d * fwd], [0.0145, 0.017, 0.017, 0.015], WOOD, 7, false, false)
	g.tube(hand - d * back, hand - d * (back + 0.035), 0.016, 0.011, SILVER_DARK, 6, true)
	g.tube(hand - d * 0.11, hand + d * 0.11, 0.021, 0.021, LEATHER, 7, true)
	g.line = 0.5
	g.tube(hand + d * fwd, hand + d * (fwd + 0.042), 0.028, 0.023, GOLD, 8, true)
	g.line = 1.0
	g.tube(hand + d * (fwd + 0.042), hand + d * (fwd + 0.078), 0.02, 0.013, SILVER, 7, true)
	var bl := 0.24
	var leaf := PackedVector2Array()
	var nseg := 7
	for i in nseg + 1:
		var t := float(i) / float(nseg)
		leaf.append(Vector2(-0.058 * sin(pow(t, 0.8) * PI), t * bl))
	for i in nseg + 1:
		var t := 1.0 - float(i) / float(nseg)
		if i > 0 and i < nseg:
			leaf.append(Vector2(0.058 * sin(pow(t, 0.8) * PI), t * bl))
	var b0 := hand + d * (fwd + 0.065)
	var across := d.cross(side).normalized()
	var bb := Basis(d, -0.5) * Basis(across, d, side)
	side = bb.z
	g.polygon(leaf, b0, bb, 0.02, SILVER_LIGHT, SILVER_DARK)
	g.line = 0.0
	for s: float in [-1.0, 1.0]:
		g.polygon(PackedVector2Array([Vector2(-0.008, 0.02), Vector2(0.008, 0.02), Vector2(0.0, bl * 0.9)]), b0 + side * (0.0105 * s), bb, 0.002, SILVER_DARK)
	g.line = 1.0
	return hand + d * (fwd + 0.065 + bl)


## 전쟁 망치(오른손): 긴 자루 끝의 큰 쇠 머리(양쪽 어두운 타격면 + 가운데 금 띠). 머리 가운데를 끝점으로 돌려준다.
static func _hammer(g: DemonGeo, hand: Vector3) -> Vector3:
	g.use("HandR")
	var d := (Basis(Vector3.BACK, 0.6) * _grip_dir(36.0)).normalized()
	var w := Vector3.RIGHT.cross(d).normalized()
	var u := d.cross(w).normalized()
	var hl := 0.55
	g.spline_tube([hand - d * 0.28, hand - d * 0.1, hand + d * 0.1, hand + d * (hl + 0.07)], [0.019, 0.023, 0.023, 0.02], WOOD, 7, true, true)
	g.tube(hand - d * 0.115, hand + d * 0.115, 0.029, 0.029, LEATHER, 7, true)
	g.sphere(hand - d * 0.28, 0.027, SILVER_DARK, 6, 4)
	var head := hand + d * hl
	var hb := Basis(u, d, w)
	var hr := Vector3(0.125, 0.08, 0.086)
	g.rounded_box(head, hr, SILVER, 0.3, 10, 6, hb)
	for s: float in [-1.0, 1.0]:
		g.rounded_box(head + u * (hr.x * s), Vector3(0.022, hr.y * 0.9, hr.z * 0.9), HAMMER_DARK, 0.3, 8, 4, hb)
	g.line = 0.5
	g.rounded_box(head, Vector3(0.026, hr.y * 1.06, hr.z * 1.06), GOLD, 0.3, 6, 3, hb)
	g.line = 1.0
	return head


## 하트 방패 반폭(위는 곧고 아래로 둥글게 모여 뾰족): y ≥ 0 이면 w, 아래는 (1 - s²)^0.4 로 모인다
static func _heater_w(y: float, w: float, hb: float) -> float:
	if y >= 0.0:
		return w
	var s := pow(clampf(-y / hb, 0.0, 1.0), 1.0 / 1.3)
	return w * pow(maxf(1.0 - s * s, 0.0), 0.4)


## 휜 판(방패 겉면): 행 = 위(ht)→아래(-hb), 열 = 그 높이의 반폭 안에서 고르게. 가로로 휘어(z = -curve·x²) 앞면(+basis.z)이 볼록하다.
## both = 참이면 뒷면과 옆 테두리까지 닫는다.
static func _bent_plate(g: DemonGeo, center: Vector3, b: Basis, w_of: Callable, ht: float, hb: float, z: float, th: float, curve: float,
		col: Color, side_col: Color, rows: int, cols: int, both: bool) -> void:
	var grid: Array = []
	for i in rows + 1:
		var t := float(i) / float(rows)
		var y := lerpf(ht, -hb, pow(t, 0.85))
		var hw: float = w_of.call(y)
		var row: Array = []
		for j in cols + 1:
			var x := lerpf(-hw, hw, float(j) / float(cols))
			row.append(Vector2(x, y))
		grid.append(row)
	var faces: Array = [1.0, -1.0] if both else [1.0]
	for s: float in faces:
		var b0 := g.v.size()
		for i in rows + 1:
			for j in cols + 1:
				var q: Vector2 = grid[i][j]
				var zz := z + s * th * 0.5 - curve * q.x * q.x
				var nn := (b.z + b.x * (2.0 * curve * q.x)).normalized() * s
				g._vert(center + b.x * q.x + b.y * q.y + b.z * zz, nn, col)
		for i in rows:
			for j in cols:
				var a := b0 + i * (cols + 1) + j
				var d := a + cols + 1
				g.tri(a, a + 1, d)
				g.tri(a + 1, d + 1, d)
	if not both:
		return
	# 옆 테두리: 윤곽(위 가장자리 → 오른쪽 → 아래 → 왼쪽)을 따라 앞·뒤를 잇는 띠
	var ring: Array = []
	for j in cols + 1:
		ring.append(grid[0][j])
	for i in range(1, rows + 1):
		ring.append(grid[i][cols])
	for i in range(rows - 1, 0, -1):
		ring.append(grid[i][0])
	var cnt := ring.size()
	for k in cnt:
		var q0: Vector2 = ring[k]
		var q1: Vector2 = ring[(k + 1) % cnt]
		var e := q1 - q0
		if e.length() < 0.0001:
			continue
		var nn := (b.x * e.y - b.y * e.x).normalized()
		if nn.dot(b.x * q0.x + b.y * q0.y) < 0.0:
			nn = -nn
		var b0 := g.v.size()
		for q: Vector2 in [q0, q1]:
			for s: float in [1.0, -1.0]:
				var zz := z + s * th * 0.5 - curve * q.x * q.x
				g._vert(center + b.x * q.x + b.y * q.y + b.z * zz, nn, side_col)
		g.tri(b0, b0 + 2, b0 + 1)
		g.tri(b0 + 1, b0 + 2, b0 + 3)


## 방패(왼손 -X): 가로로 휜 하트 방패. 은(성기사는 금) 테 판 위에 색 면, 그 위에 십자(면을 따라 휜다).
static func _shield(g: DemonGeo, v: int, hand: Vector3) -> void:
	g.use("HandL")
	var small := v == 2 or v == 3
	var sc := 0.9 if small else (0.86 if v == 4 else 1.0)
	var face_col := BLUE if v == 4 else RED
	var mark := GOLD if v == 4 else WHITE
	# 성기사 방패는 조금 작고 더 옆을 향하며 안쪽에 둬 뒤에서 보면 망토에 가려진다
	var nrm := (Vector3(-0.6, -0.42, -0.68) if v == 4 else Vector3(-0.5, -0.45, -0.74)).normalized()
	var center := hand + nrm * 0.06 + Vector3(0.0 if v == 4 else -0.02, 0.03, 0)
	var t1 := nrm.cross(Vector3.UP).normalized()
	var t2 := t1.cross(nrm).normalized()
	if t2.y < 0.0:
		t2 = -t2
	var sb := Basis(t1, t2, nrm)
	var w := 0.185 * sc
	var ht := 0.21 * sc
	var hb := 0.285 * sc
	var curve := 0.9
	# 손잡이(팔뚝에 묶는 띠)
	g.tube(center - nrm * 0.02, center - nrm * 0.06, 0.035, 0.03, LEATHER, 6, true)
	var rim_col := GOLD if v == 4 else SILVER
	g.line = 1.0
	_bent_plate(g, center, sb, func(y: float) -> float: return _heater_w(y, w, hb), ht, hb, 0.0, 0.028, curve,
		rim_col, GOLD_DARK if v == 4 else SILVER_DARK, 6, 4, true)
	g.line = 0.0
	var wi := w * 0.86
	var hbi := hb * 0.86
	_bent_plate(g, center + t2 * (-0.004), sb, func(y: float) -> float: return _heater_w(y, wi, hbi), ht * 0.86, hbi, 0.0155, 0.0, curve,
		face_col, face_col, 6, 4, false)
	# 십자: 세로 막대·가로 막대(면을 따라 휜 얇은 판)
	var a := 0.03 * sc
	var top := 0.13 * sc
	var bot := 0.16 * sc
	var cw := 0.1 * sc
	g.line = 0.3
	_bent_plate(g, center, sb, func(_y: float) -> float: return a, top, bot, 0.021, 0.006, curve, mark, mark.darkened(0.15), 4, 1, true)
	_bent_plate(g, center + t2 * a, sb, func(_y: float) -> float: return cw, a, a, 0.0215, 0.006, curve, mark, mark.darkened(0.15), 1, 4, true)
	if v == 4:
		g.line = 0.3
		g.sphere(center + nrm * 0.026 + t2 * a, 0.02 * sc, GOLD_DARK, 8, 4)
	g.line = 1.0
