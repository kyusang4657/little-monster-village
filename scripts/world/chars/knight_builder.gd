class_name KnightBuilder
extends RefCounted
## 인간 기사 5종의 메시·골격 정의(5차: 컨셉 시트 「기사(5종)」 기준).
## 0 일반 기사 = 얼굴 한가운데 코가리개 막대가 달린 둥근 강철 투구 + 위로 솟았다가 앞으로 휘는 긴 상아색 깃, 열린 얼굴(갈색 도는 황갈색 피부,
##               둥근 눈·가는 눈썹), 사슬 갑옷 위 가슴판,
##               가죽 장갑, 붉은 하트 방패(흰 십자), 검
## 1 중갑 기사 = 얼굴 아래를 덮는 통투구(어두운 눈 틈에 노란 눈) + 붉은 볏, 한 단계 어두운 판금, 1.45배 두 겹 어깨 갑옷,
##               넓고 두꺼운 가슴판(가로 금 띠)과 배 판, 크고 낮게 내려온 허리 판 두 줄, 두꺼운 팔·정강이 갑옷과 장화, 붉은 방패, 검
## 2 창기사 = 통투구 + 붉은 볏, 긴 창(오른손: 창날은 주먹 아래 앞아래로, 자루는 어깨 위로 비스듬히; 금 깃 테 + 잎 모양 은 창날), 붉은 방패
## 3 망치 기사 = 통투구 + 파란 볏, 머리만 한 큰 쇠 머리(양쪽 어두운 타격면 + 금 띠)의 전쟁 망치(오른손), 두꺼운 건틀릿, 붉은 방패
## 4 성기사(정예) = 통투구 + 가장 큰 붉은 볏(다섯 가닥), 금 테를 두른 광택 갑옷, 파란 하트 방패(금 십자·별), 등 갑옷 뒤에 건 파란 망토(Cape 뼈), 검
## 공통: 은빛 갑옷 + 금 테, 3등신(머리·투구가 키의 1/3), 큰 장화·건틀릿, 정강이 위 금 띠, 가슴판 아래 갈색 가죽 벨트(금 버클)와
## 겹친 은 허리 갑옷(금 테), 빨강은 방패에만. 통투구 변형(1~4)은 컨셉대로 검은 눈 틈 속에서 노란 눈이 빛난다.
## 깃털은 투구 꼭대기에서 머리 높이의 0.8 쯤 솟았다가 뒤로 흘러내리는 긴 깃 다발(겹친 네다섯 가닥)이라 고깔모자가 아니라 날리는 깃으로 읽힌다.
## 키 1.15(변형별 배율 SCALE 은 ±5% 안).
## 리그 규약: 기준점 = 두 발 사이 지면, 정면 = -Z, 오른손 = +X(무기), 왼손 = -X(방패), Plume(·Cape) 2차 뼈.
## 외곽선(뒤집은 껍데기)이 열린 관 끝·열린 타원체 테두리에서 톱니처럼 비치므로, 밖으로 드러나는 금 테 관은 모두 뚜껑을
## 닫고 어깨 갑옷은 닫힌 타원체로 만든다. 머리와 같은 중심의 덮개(투구·뺨 가리개)는 열린 테두리가 머리 속에 묻혀 괜찮다.


## 기사 변형 5종의 키 배율(±5%)
const SCALE := [1.0, 1.05, 0.96, 1.03, 1.02]
const PLUME := ["f3ece4", "d0352a", "d0352a", "2f4fb0", "d0352a"]
const PLUME_SIZE := [1.02, 1.0, 1.0, 1.0, 1.28]

const SILVER := Color("b9c3cd")
const SILVER_LIGHT := Color("d6dde4")
const SILVER_DARK := Color("8a95a1")
const HEAVY_PLATE := Color("9aa4ae")      # 중갑 기사: 한 단계 어두운 판금
const HEAVY_PLATE_DARK := Color("6f7a86")
const HEAVY_HELM := Color("b4bdc6")       # 중갑 투구(판금보다는 밝아 위에서도 머리가 구분된다)
const STEEL := Color("5f6a76")           # 사슬 갑옷·그늘진 쇠
const GOLD := Color("e1b23c")
const GOLD_BAND := Color("c69a30")       # 투구 이마 띠(어깨 갑옷 테보다 조금 어두워 위에서도 머리가 구분된다)
const GOLD_DARK := Color("b1862b")
const RED := Color("c8343a")
const BLUE := Color("2f55b0")
const BLUE_DARK := Color("22407f")
const WHITE := Color("f4efe4")
const SKIN := Color("d9a67a")             # 일반 기사 얼굴(장난감 같지 않게 조금 더 갈색 도는 황갈색)
const SKIN_SHADE := Color("2b2630")      # 통투구 속 그늘진 얼굴(눈 틈)
const GLOW := Color("ffd86a")            # 통투구 속 빛나는 눈
const GLOW_DIM := Color("7d5f1e")        # 감은(기절한) 눈의 희미한 빛
const LEATHER := Color("6b4423")
const LEATHER_LIGHT := Color("8a5a30")
const BOOT := Color("4e3220")
const BOOT_TOE := Color("7d8893")
const WOOD := Color("7a4b26")
const BLADE := Color("e6ecf2")
const HAMMER_DARK := Color("5c636b")
const EYE_RIM := Color("241c22")
const PUPIL := Color("2a2230")
const BROW := Color("4a3222")

## 골격 비율(3등신: 머리·투구 ≈ 0.38, 몸통 ≈ 0.4, 다리 ≈ 0.37). 다리 간격(hip_x)은 넓게 벌려 아래 몸통이 잘 읽힌다.
const P := {
	ankle = 0.08, knee = 0.23, hip = 0.4, hip_x = 0.104, pelvis = 0.42, spine = 0.49,
	shoulder = 0.73, shoulder_x = 0.21, elbow = 0.585, wrist = 0.455, neck = 0.76, head = 0.8,
	arm_r = 0.05, leg_r = 0.055, foot_len = 0.21,
}
const HC := Vector3(0, 0.945, -0.01)        # 머리 중심
const HR := Vector3(0.165, 0.155, 0.158)    # 머리 반지름
const ES := 0.037                            # 눈 크기
const EYE_Y := 0.94
const EYE_DX := 0.064
const MOUTH_Y := 0.85


static func build(v: int) -> Dictionary:
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	var heavy := v == 1
	var elite := v == 4
	var A := _armor(heavy)
	_torso(g, v, heavy, elite, A)
	_limbs(g, v, heavy, elite, A)
	var es := _head(g, v, A)
	if elite:
		_cape(g)
	# 무기·방패는 키·체력 막대 측정에서 뺀다
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


## 변형별 갑옷 색: 중갑 기사는 판금·그늘·투구가 한 단계 어둡다
static func _armor(heavy: bool) -> Dictionary:
	if heavy:
		return {plate = HEAVY_PLATE, dark = HEAVY_PLATE_DARK, helm = HEAVY_HELM, light = Color("c3cbd3")}
	return {plate = SILVER, dark = SILVER_DARK, helm = SILVER_LIGHT, light = SILVER_LIGHT}


# ------------------------------------------------------------------ 몸통

## 몸통: 둥근 가슴판(금 목 테·아래 테·가운데 금 줄), 사슬 갑옷 배, 갈색 가죽 벨트와 금 버클, 겹친 은 허리 갑옷(금 테).
## 중갑은 가슴판이 넓고 아래 테가 두껍고 배 판을 한 겹 더 대고 허리 갑옷도 두 줄이다. 드러나는 금 테 관은 뚜껑을 닫아 외곽선 톱니를 막는다.
static func _torso(g: CharGeo, v: int, heavy: bool, elite: bool, A: Dictionary) -> void:
	var plate: Color = A.plate
	var cc := Vector3(0, 0.62, 0.0)
	var cr := Vector3(0.2, 0.14, 0.15)
	if heavy:
		cr = Vector3(0.252, 0.166, 0.182)
	var trim := GOLD
	g.use("Spine")
	# 사슬 갑옷(가슴판 아래로 보이는 어두운 쇠)
	g.ellipsoid(Vector3(0, 0.52, 0), Vector3(cr.x * 0.86, 0.1, cr.z * 0.9), STEEL, 8, 3)
	# 가슴판
	g.rounded_box(cc, cr, plate, 0.48 if heavy else 0.58, 12, 7)
	g.line = 0.45
	# 목 테(금)
	g.tube(Vector3(0, cc.y + cr.y * 0.9, 0), Vector3(0, cc.y + cr.y * 1.08, 0), 0.098, 0.092, trim, 12, true)
	# 아래 테(금): 중갑은 두 배 두껍다
	var band_top := 0.56 if heavy else 0.68
	g.tube(Vector3(0, cc.y - cr.y * 0.92, 0), Vector3(0, cc.y - cr.y * band_top, 0), cr.x * 0.9, cr.x * 0.99, trim, 12, true, 1.0, cr.z / cr.x)
	# 가운데 세로 금 줄
	g.rounded_box(Vector3(0, cc.y - 0.005, cc.z - cr.z * 0.96), Vector3(0.012, cr.y * 0.72, 0.012), trim, 0.5, 6, 4)
	if heavy:
		# 중갑: 가슴 한가운데를 두르는 가로 금 띠(가슴판과 같은 모난 단면이라 모서리에서 파묻히지 않는다)
		g.rounded_box(cc + Vector3(0, 0.03, 0), Vector3(cr.x * 1.025, 0.015, cr.z * 1.025), trim, 0.48, 10, 2)
	if elite:
		# 성기사: 가슴 금 별 문장
		g.polygon(CharGeo.star(5, 0.045, 0.02), Vector3(0, cc.y + 0.02, cc.z - cr.z * 0.98), Basis.IDENTITY, 0.012, trim, GOLD_DARK)
		# 어깨 망토 걸쇠
		for side: float in [-1.0, 1.0]:
			g.sphere(Vector3(0.1 * side, cc.y + cr.y * 0.92, -0.06), 0.02, trim, 5, 3)
	g.line = 1.0
	if heavy:
		# 중갑: 가슴판 아래 두꺼운 배 판(한 겹 더 앞으로 튀어나온 판 + 금 테)
		g.rounded_box(Vector3(0, 0.49, -0.008), Vector3(cr.x * 0.92, 0.066, cr.z * 1.02), plate, 0.5, 8, 4)
		g.line = 0.45
		g.tube(Vector3(0, 0.44, -0.008), Vector3(0, 0.46, -0.008), cr.x * 0.86, cr.x * 0.92, trim, 10, true, 1.0, cr.z / cr.x)
		g.line = 1.0
	# 갈색 가죽 벨트와 금 버클
	g.use("Pelvis")
	var bx := 0.2 if heavy else 0.174
	g.tube(Vector3(0, 0.436, 0), Vector3(0, 0.476, 0), bx, bx - 0.004, LEATHER, 12, true, 1.0, 0.86)
	g.line = 0.5
	g.rounded_box(Vector3(0, 0.456, -bx * 0.88), Vector3(0.036, 0.024, 0.01), GOLD, 0.4, 6, 3)
	g.rounded_box(Vector3(0, 0.456, -bx * 0.92), Vector3(0.016, 0.011, 0.006), GOLD_DARK, 0.5, 4, 2)
	g.line = 1.0
	# 허리 갑옷: 벨트 아래 아래로 벌어지는 은 띠 + 금 테, 그 밑에 겹쳐 매달린 판(앞·양옆·뒤)
	var wx := bx - 0.01
	g.tube(Vector3(0, 0.44, 0), Vector3(0, 0.392, 0), wx, wx + 0.016, plate, 12, true, 1.0, 0.86)
	g.line = 0.45
	g.tube(Vector3(0, 0.4, 0), Vector3(0, 0.386, 0), wx + 0.016, wx + 0.019, trim, 12, true, 1.0, 0.86)
	g.line = 1.0
	var tz := wx * 0.84
	# 중갑은 허리 판(태싯)이 더 크고 낮게 내려와 치마처럼 허벅지를 덮는다
	var tw := 0.096 if heavy else 0.08
	var th := 0.064 if heavy else 0.05
	var ty := 0.342 if heavy else 0.352
	_tasset(g, Vector3(0, ty, -tz), Vector3(tw, th, 0.016), Basis(Vector3.RIGHT, 0.22), trim, plate)
	_tasset(g, Vector3(0, ty, tz - 0.02), Vector3(tw, th, 0.016), Basis(Vector3.RIGHT, -0.22), trim, plate)
	for side: float in [-1.0, 1.0]:
		_tasset(g, Vector3((wx + 0.012) * side, ty, -0.01), Vector3(0.016, th, tw), Basis(Vector3.BACK, 0.22 * side), trim, plate)
		if heavy:
			# 중갑: 앞 대각선에 한 줄 더 낮게 매달린 판
			var ang := 0.75 * side
			var b2 := Basis(Vector3.UP, -ang) * Basis(Vector3.RIGHT, 0.26)
			_tasset(g, Vector3(sin(ang) * 0.172, 0.318, -cos(ang) * 0.15), Vector3(0.074, 0.062, 0.016), b2, trim, plate)
	# 엉덩이·허벅지 위(허리 갑옷 뒤로 보이는 사슬)
	g.ellipsoid(Vector3(0, 0.365, 0.01), Vector3(0.165, 0.085, 0.13), STEEL, 6, 2)
	# 목(피부)과 사슬 깃
	g.use("Neck")
	g.tube(Vector3(0, 0.73, 0), Vector3(0, 0.83, 0), 0.055, 0.052, SKIN if v == 0 else SKIN_SHADE, 8, false)
	g.use("Spine")
	g.tube(Vector3(0, 0.72, 0), Vector3(0, 0.775, 0), 0.085, 0.072, STEEL, 10, true)
	# 어깨 갑옷: 어깨에 낮게 얹힌 닫힌 둥근 판 + 뚜껑 닫은 금 테(가슴판 가운데 금 줄이 사이로 보인다).
	# 중갑은 1.45배 크고 아래에 한 겹 더 두른다(위에서 본 게임 화면에서도 어깨가 눈에 띄게 넓다)
	var pr := Vector3(0.088, 0.07, 0.088)
	if heavy:
		pr = Vector3(0.128, 0.1, 0.128)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.use("Arm" + sfx)
		var pc := Vector3(float(P.shoulder_x) * side + (0.034 if heavy else 0.014) * side, float(P.shoulder) - (0.022 if heavy else 0.028), 0)
		var tilt := Basis(Vector3.BACK, -0.28 * side)
		g.ellipsoid(pc, pr, plate, 10, 5, tilt)
		g.line = 0.45
		_pauldron_rim(g, pc, pr, tilt, PI * 0.6)
		if heavy:
			# 두 번째 겹(조금 더 크고 낮게 깔린 닫힌 판 + 테)과 꼭대기 금 징
			var pc2 := pc + tilt * Vector3(0, -0.042, 0)
			var pr2 := pr * Vector3(1.14, 0.84, 1.14)
			g.ellipsoid(pc2, pr2, plate, 8, 3, tilt)
			_pauldron_rim(g, pc2, pr2, tilt, PI * 0.56)
			g.sphere(pc + tilt * Vector3(0, pr.y * 0.98, 0), 0.024, GOLD, 5, 2)
		elif elite:
			g.ellipsoid(pc + tilt * Vector3(0, pr.y * 0.68, 0), Vector3(0.036, 0.036, 0.036), SILVER_LIGHT, 7, 2, tilt, PI * 0.5, PI * 0.5)
		g.line = 1.0


## 어깨 갑옷 테: 타원체(중심 pc, 반지름 pr)의 위도 lat 둘레에 두르는 짧은 금 관. 양 끝 반지름을 그 높이의 타원체 단면보다
## 조금 크게 잡고 분할 위상을 타원체와 맞춰, 관이 판 속으로 파고들며 생기는 톱니 교선이 없다. 양 끝을 닫아 껍데기 속도 비치지 않는다.
static func _pauldron_rim(g: CharGeo, pc: Vector3, pr: Vector3, tilt: Basis, lat: float) -> void:
	var y0 := cos(lat) * pr.y
	var dy := [-0.011, 0.013]
	var rr: Array = []
	for k in 2:
		var yy: float = clampf((y0 + float(dy[k])) / pr.y, -0.999, 0.999)
		rr.append(pr.x * sqrt(1.0 - yy * yy) * 1.045)
	var a := pc + tilt * Vector3(0, y0 + float(dy[0]), 0)
	var b := pc + tilt * Vector3(0, y0 + float(dy[1]), 0)
	g.tube(a, b, float(rr[0]), float(rr[1]), GOLD, 10, true, 1.0, pr.z / pr.x, tilt * Vector3.FORWARD)


## 허리 갑옷 판 하나(판금 + 아래 가장자리 금 테). basis 의 +Y 가 판의 위, 아래가 바깥으로 벌어지도록 기울여 넘긴다.
static func _tasset(g: CharGeo, ce: Vector3, r: Vector3, basis: Basis, trim: Color, plate: Color) -> void:
	g.rounded_box(ce, r, plate, 0.45, 6, 3, basis)
	g.line = 0.45
	g.rounded_box(ce + basis * Vector3(0, -r.y * 0.9, 0), Vector3(r.x * 1.03, 0.011, r.z * 1.03), trim, 0.45, 6, 2, basis)
	g.line = 1.0


# ------------------------------------------------------------------ 팔다리

## 팔(사슬 위팔, 은 팔꿈치·팔뚝 갑옷, 큰 건틀릿)과 다리(사슬 허벅지, 은 무릎·정강이 갑옷, 정강이 위 금 띠, 큰 장화와 쇠 앞코).
## 중갑은 정강이 갑옷·장화가 더 크고 발목에도 금 띠.
static func _limbs(g: CharGeo, v: int, heavy: bool, elite: bool, A: Dictionary) -> void:
	var plate: Color = A.plate
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	var ar: float = P.arm_r
	var lr: float = P.leg_r
	var glove: Color = plate if (heavy or elite) else LEATHER_LIGHT
	var glove_cuff: Color = A.dark if (heavy or elite) else LEATHER
	var hs := 1.6 if v == 3 else (1.52 if heavy else 1.45)
	var trim: Color = GOLD if (elite or heavy) else A.dark
	var gs := 1.22 if heavy else 1.0            # 정강이 갑옷 배율
	var ap := 1.16 if heavy else 1.0            # 팔꿈치·팔뚝·건틀릿 소매 갑옷 배율
	var bs := 1.68 if heavy else 1.5            # 장화 길이·높이 배율
	var bw := 1.44 if heavy else 1.34           # 장화 폭 배율(두 장화가 가운데서 맞닿지 않게 조금 작다)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Arm" + sfx)
		g.tube(Vector3(x, P.shoulder, 0), Vector3(x, P.elbow, 0), ar * 1.15 * ap, ar * 0.95 * ap, STEEL, 8, false)
		g.use("Forearm" + sfx)
		g.sphere(Vector3(x, P.elbow, 0), ar * 1.08 * ap, plate, 6, 3)
		g.tube(Vector3(x, float(P.elbow) - 0.01, 0), Vector3(x, P.wrist, 0), ar * 1.0 * ap, ar * 1.15 * ap, plate, 8, false)
		g.use("Hand" + sfx)
		# 건틀릿 소매(아래로 벌어진 쇠 통)
		g.tube(Vector3(x, float(P.wrist) + ar * 0.9, 0), Vector3(x, float(P.wrist) - ar * 0.35, 0), ar * 1.1 * ap, ar * 1.3 * ap * (hs / 1.45), glove_cuff, 8, true)
		g.line = 0.5
		g.tube(Vector3(x, float(P.wrist) + ar * 0.2, 0), Vector3(x, float(P.wrist) + ar * 0.42, 0), ar * 1.21 * ap, ar * 1.18 * ap, trim, 8, false)
		g.line = 1.0
		# 큰 주먹
		var hc := Vector3(x, float(P.wrist) - ar * 0.8, -ar * 0.1)
		g.ellipsoid(hc, Vector3(ar * 1.12, ar * 1.2, ar * 1.15) * hs, glove, 7, 4)
		# 손등 판(엄지 쪽은 바깥)
		g.rounded_box(hc + Vector3(ar * 0.55 * hs * side, ar * 0.45 * hs, -ar * 0.2), Vector3(ar * 0.5, ar * 0.55, ar * 0.7) * hs * 0.8,
			glove.darkened(0.12) if not (heavy or elite) else A.light, 0.5, 5, 3, Basis(Vector3.BACK, -0.5 * side))
		var lx := hx * side
		g.use("Leg" + sfx)
		g.tube(Vector3(lx, float(P.hip) + lr * 0.5, 0), Vector3(lx, P.knee, 0), lr * 1.2 * (1.1 if heavy else 1.0), lr * 0.98 * gs, STEEL, 8, false)
		g.use("Shin" + sfx)
		g.sphere(Vector3(lx, P.knee, 0), lr * 1.08 * gs, plate, 6, 3)
		g.tube(Vector3(lx, float(P.knee) - 0.01, 0), Vector3(lx, P.ankle, 0), lr * 1.0 * gs, lr * 0.95 * gs, plate, 8, false)
		# 정강이 갑옷 위 금 띠(모든 변형)
		g.line = 0.5
		g.tube(Vector3(lx, float(P.knee) - 0.062, 0), Vector3(lx, float(P.knee) - 0.038, 0), lr * 1.06 * gs, lr * 1.03 * gs, GOLD, 7, false)
		if heavy:
			# 중갑: 정강이 아래 띠
			g.tube(Vector3(lx, float(P.ankle) + 0.06, 0), Vector3(lx, float(P.ankle) + 0.078, 0), lr * 1.0 * gs, lr * 0.98 * gs, GOLD, 7, false)
		g.line = 1.0
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		var fh: float = P.ankle
		# 장화 목 테와 큰 장화, 쇠 앞코
		g.tube(Vector3(lx, float(P.ankle) + lr * 0.8, 0), Vector3(lx, float(P.ankle) - lr * 0.2, 0), lr * 1.05 * gs, lr * 1.3 * gs, BOOT.darkened(0.15), 8, false)
		g.ellipsoid(Vector3(lx, fh * 0.56 * bs, -fl * 0.2 * bs), Vector3(lr * 1.3 * bw, fh * 0.56 * bs, fl * 0.48 * bs), BOOT, 8, 4)
		g.ellipsoid(Vector3(lx, fh * 0.56 * bs - 0.004, -fl * 0.46 * bs), Vector3(lr * 1.08 * bw, fh * 0.5 * bs, fl * 0.24 * bs), BOOT_TOE, 5, 3)


# ------------------------------------------------------------------ 머리·투구

## 머리: 일반 기사(0)는 황갈색 얼굴에 테두리 또렷한 둥근 눈(반짝임 하나씩 대칭)·가는 눈썹과 가는 코가리개, 나머지(1~4)는
## 컨셉대로 얼굴 아래를 덮는 통투구 판과 검은 눈 틈 속의 노란 눈·숨구멍. 큰 둥근 투구(밝은 은, 어두운 금 이마 띠·둥근 금 볏줄),
## 머리에 붙어 턱 높이에서 끝나는 뺨 가리개, 뒤로 눕는 짧은 깃털 볏. 눈 크기를 돌려준다.
static func _head(g: CharGeo, v: int, A: Dictionary) -> float:
	var full_helm := v != 0
	var helm: Color = A.helm
	var skin := SKIN_SHADE if full_helm else SKIN
	var es := ES
	var ey := EYE_Y
	if full_helm:
		es = 0.034
		ey = 0.962
	g.use("Head")
	g.ellipsoid(HC, HR, skin, 12, 6)
	var F := {hc = HC, hr = HR, es = es, eye_y = ey, eye_dx = EYE_DX, mouth_y = MOUTH_Y, mouth_w = 0.07,
		skin = skin, pupil = PUPIL, brow = BROW, eye_rim = EYE_RIM, shine = 1.1, brow_t = 0.8, brow_w = 1.0, eye_h = 1.12,
		lid = skin.darkened(0.08), visor = full_helm}
	if full_helm:
		# 통투구 속에서 빛나는 눈: 감으면 희미한 빛줄기만 남고, 눈썹은 틈 속의 희미한 쇠 능선
		F.sclera = GLOW
		F.pupil = Color("3a2a12")
		F.eye_rim = Color("1a1410")
		F.lash = GLOW_DIM
		F.brow = Color("3b3542")
		F.lid = Color("201c26")
		F.brow_t = 1.25
		F.brow_w = 1.05
		F.eye_h = 1.25
	var keep_line := g.line
	g.line = 0.0
	_face(g, F)
	g.line = keep_line
	g.use("Head")
	if not full_helm:
		# 코(얼굴 부품처럼 외곽선을 가늘게)
		var ny := ey - es * 1.45
		g.line = 0.3
		g.ellipsoid(Vector3(0, ny, CharGeo.surf_z(HC, HR, 0, ny) - 0.007), Vector3(0.019, 0.014, 0.018), skin.darkened(0.08), 6, 3)
		g.line = 1.0
	# 투구: 얼굴은 이마까지만 덮고 옆·뒤는 깊게. 꼭대기가 HEIGHT. 어깨 갑옷보다 밝은 은이라 위에서 봐도 머리가 구분된다.
	var hc2 := HC + Vector3(0, 0.022, 0.006)
	var hr2 := Vector3(0.19, 0.185, 0.192)
	var lat_f := 1.14
	var lat_b := 2.35
	g.ellipsoid(hc2, hr2, helm, 14, 6, Basis.IDENTITY, lat_f, lat_b)
	# 투구 가장자리 금 띠(조금 어두운 금)
	g.line = 0.5
	var rim: Array = []
	for j in 12:
		var lon := TAU * float(j) / 12.0
		var lat := lerpf(lat_b, lat_f, (1.0 + cos(lon)) * 0.5)
		rim.append(hc2 + Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon)) * hr2 * 1.0)
	g.sweep(rim, 0.017, GOLD_BAND, 4, true)
	# 가운데 금 볏줄: 이마 띠에서 꼭대기를 넘어 뒤까지 둥글게 얹힌 띠(외곽선을 거의 없애 금 줄이 틈처럼 보이지 않게)
	var comb: Array = []
	var comb_r: Array = []
	var nseg := 8
	for i in nseg + 1:
		var t := float(i) / float(nseg)
		var a := lerpf(-1.02, 1.5, t)
		comb.append(hc2 + Vector3(0, cos(a) * hr2.y, sin(a) * hr2.z) * 1.015)
		comb_r.append(0.021 * (1.0 - 0.3 * absf(t * 2.0 - 1.0)))
	g.measure = false
	g.line = 0.12
	g.spline_tube(comb, comb_r, GOLD, 6, true, true, Vector3.RIGHT, 1.0, 0.5)
	g.measure = true
	g.line = 1.0
	# 뺨 가리개: 머리와 같은 중심의 둥근 덮개 둘(머리의 1.12배)을 위아래로 겹쳐 세로로 긴 판. 머리에 붙고,
	# 위는 투구 속에 묻히며 아래는 턱 높이에서 끝난다
	for side: float in [-1.0, 1.0]:
		for pole: Vector3 in [Vector3(0.92 * side, -0.2, -0.3), Vector3(0.88 * side, -0.52, -0.28)]:
			g.ellipsoid(HC, HR * 1.12, helm, 8, 3, _basis_up(pole.normalized()), 0.5, 0.5)
	if full_helm:
		# 통투구: 눈 틈 아래를 덮는 얼굴 판 + 숨구멍 세 개
		var pr := HR * Vector3(1.09, 1.08, 1.1)
		g.ellipsoid(HC + Vector3(0, 0, -0.004), pr, helm, 12, 3, Basis.IDENTITY, 2.75, 1.62, 1.62)
		g.line = 0.3
		for k in 3:
			var hx := (float(k) - 1.0) * 0.03
			var hy := 0.885
			g.ellipsoid(Vector3(hx, hy, CharGeo.surf_z(HC, pr, hx, hy) - 0.004), Vector3(0.008, 0.012, 0.006), STEEL, 4, 2)
		g.line = 1.0
	else:
		# 코가리개(이마 띠에서 코끝까지 얼굴 한가운데로 내려오는 납작한 쇠 막대: 투구보다 조금 어두운 은, 테두리를 또렷이)
		var nz0 := hc2.z - sin(lat_f) * hr2.z
		var ny0 := hc2.y + cos(lat_f) * hr2.y
		g.line = 0.9
		g.spline_tube([Vector3(0, ny0 + 0.012, nz0 + 0.004), Vector3(0, (ny0 + 0.9) * 0.5, CharGeo.surf_z(HC, HR, 0, (ny0 + 0.9) * 0.5) - 0.014),
			Vector3(0, 0.886, CharGeo.surf_z(HC, HR, 0, 0.886) - 0.013)], [0.014, 0.0125, 0.0095], SILVER, 6, false, true, Vector3.RIGHT, 1.0, 0.6)
		g.line = 1.0
	# 깃털 꽂이(금)와 깃털 볏(Plume 뼈)
	var top_y := hc2.y + hr2.y
	var plume_base := Vector3(0, top_y - 0.008, hc2.z)
	g.measure = false
	g.line = 0.5
	g.tube(plume_base, plume_base + Vector3(0, 0.03, 0), 0.036, 0.03, GOLD, 8, true)
	g.line = 1.0
	_plume(g, v, hc2, hr2)
	g.measure = true
	return es


## 단위 벡터 up 을 +Y 로 하는 직교 기저
static func _basis_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var ref := Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## 깃털 볏: 투구 꼭대기 꽂이에서 길게 솟았다가 뒤로 흘러내리는 겹친 깃 네(성기사는 다섯) 가닥. 맨 앞 가닥이 가장 길어
## 머리 높이의 0.8 쯤 곧게 솟은 뒤 뒤로 휘어 끝이 투구 뒤로 트레일처럼 흘러내리고, 뒤 가닥일수록 투구 곡면의 더 뒤에
## 뿌리를 두고 짧다. 방향 보간을 u^1.6 으로 늦춰 앞 2/3 는 거의 곧게 서고 끝에서만 뒤로 꺾이므로 고깔(세로 지느러미)이
## 아니라 뒤로 날리는 깃으로 읽힌다. 일반 기사(0)의 흰 깃은 반대로 위로 솟았다가 앞으로 휘어 끝이 이마 위에 걸린다.
## 단면은 옆으로 얇고 앞뒤로 넓은 깃털 모양이고 가운데가 볼록하다가 끝이 둥글게 맺히며, 밝기를 번갈아 달리해 겹침이 보인다.
## 모두 Plume 뼈라 함께 흔들린다. 뒤로 흘러내리는 길이는 쓰러짐 자세(고개를 옆·앞으로 돌리고 등으로 눕는다)에서도
## 땅(y -0.06) 위에 머문다.
static func _plume(g: CharGeo, v: int, hc2: Vector3, hr2: Vector3) -> void:
	var base := hc2 + Vector3(0, hr2.y, 0)
	g.add_bone("Plume", "Head", base + Vector3(0, 0.02, 0))
	g.use("Plume")
	var col := Color(PLUME[v])
	var ps: float = PLUME_SIZE[v]
	var forward := v == 0
	var n := 5 if v == 4 else 4
	var nseg := 6
	for k in n:
		var t := float(k) / float(n - 1)            # 0 = 맨 앞 가닥, 1 = 맨 뒤 가닥
		var phi := lerpf(0.0, 0.55, t)              # 뿌리 위치: 꼭대기에서 뒤로 잰 투구 각
		var length := (0.44 - 0.12 * t) * ps
		var a0 := phi + 0.1                         # 시작 방향(위에서 뒤로 잰 각): 거의 곧게 위
		var a1 := 1.95 + 0.35 * t                   # 끝 방향: 뒤·아래로 흘러내린다
		var ease := 1.6
		if forward:
			phi = lerpf(0.32, 0.62, t)              # 뿌리는 꼭대기 조금 뒤, 뒤로 살짝 젖혔다가 앞으로 활처럼 넘어오는 흰 깃
			a0 = 0.45 - 0.1 * t
			a1 = -1.75 + 0.3 * t
			ease = 1.25
		var lat := float((k % 2) * 2 - 1) * 0.013 * ps
		var p := hc2 + Vector3(lat, cos(phi) * hr2.y, sin(phi) * hr2.z) * 0.97
		var pts: Array = []
		var radii: Array = []
		var r0 := 0.034 * ps
		for i in nseg + 1:
			var u := float(i) / float(nseg)
			pts.append(p)
			radii.append(r0 * (0.5 + 0.75 * pow(sin(u * PI), 0.8)) if i < nseg else r0 * 0.25)
			var a := lerpf(a0, a1, pow((float(i) + 0.5) / float(nseg), ease))
			p += Vector3(0, cos(a), sin(a)) * (length / float(nseg))
		var shade := col.lightened(0.1) if k % 2 == 0 else col.darkened(0.12)
		g.spline_tube(pts, radii, shade, 6, true, true, Vector3.RIGHT, 0.7, 1.8 if forward else 1.6)


## 얼굴(CharGeo.face_parts 를 기사용으로 옮긴 것): 눈 테두리·흰자를 더 둥글게(10×5), 눈동자 8×4, 볼 홍조 없음.
## 눈동자 뼈는 눈알 뼈의 자식이라 눈을 감거나(깜빡임·기절) 누르면 눈동자·반짝임도 같이 눌려 사라지고 뒤의 감은 눈 선만 남는다.
## F.eye_h = 눈 세로 배수(1.12 = 둥근 타원), 반짝임은 좌우 눈에 거울처럼 대칭(눈동자 위 안쪽) 하나씩.
## F.visor 가 참이면(통투구) 입은 판 뒤에 숨은 작은 덩어리로, 눈은 더 적은 분할로 만든다. F.lash = 감은 눈 선 색.
## 뼈·입 세 가지(MouthN/MouthA/MouthH)·눈꺼풀·눈썹 규약은 공통 부품과 같다. MouthH(아픔·기절)는 옆으로 벌어진 납작한 입.
static func _face(g: CharGeo, F: Dictionary) -> void:
	var hc: Vector3 = F.hc
	var hr: Vector3 = F.hr
	var es: float = F.es
	var ey: float = F.eye_y
	var skin: Color = F.skin
	var visor: bool = F.get("visor", false)
	var eh: float = F.get("eye_h", 1.25)
	var e_seg := 8 if visor else 10
	var e_ring := 4 if visor else 5
	var lash_col: Color = F.get("lash", F.pupil)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var ex: float = float(F.eye_dx) * side
		var ez := CharGeo.surf_z(hc, hr, ex, ey)
		# 감은 눈 선(눈알 뒤에 숨어 있다가 눈알을 누르면 보인다)
		g.use("Head")
		var lash: Array = []
		for i in 5:
			var u := float(i) / 2.0 - 1.0
			var lx := ex + u * es * 0.85
			var ly := ey - es * (0.32 - 0.27 * u * u)
			lash.append(Vector3(lx, ly, CharGeo.surf_z(hc, hr, lx, ly) - es * 0.05))
		g.sweep(lash, es * 0.16, lash_col, 4)
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez + es * 0.3))
		g.use("Eye" + sfx)
		# 눈 테두리: 눈알 뒤의 조금 더 큰 짙은 타원(눈알 뼈에 붙어 같이 감긴다)
		g.ellipsoid(Vector3(ex, ey, ez + es * 0.34), Vector3(es * 1.1, es * (eh + 0.07), es * 0.6), F.eye_rim, e_seg, e_ring)
		g.ellipsoid(Vector3(ex, ey, ez + es * 0.3), Vector3(es, es * eh, es * 0.6), F.get("sclera", Color("fbfbf7")), e_seg, e_ring)
		var pc := Vector3(ex - side * es * 0.12, ey - es * 0.12, ez - es * 0.25)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.ellipsoid(pc, Vector3(es * 0.64, es * 0.82, es * 0.3), F.pupil, 6 if visor else 8, 3 if visor else 4)
		if F.has("pupil_core"):
			g.ellipsoid(Vector3(ex - side * es * 0.12, ey - es * 0.2, ez - es * 0.38), Vector3(es * 0.3, es * 0.36, es * 0.16), F.pupil_core, 6, 3)
		# 반짝임 하나(둥근 점): 눈동자 위 안쪽에 좌우 대칭으로
		g.sphere(Vector3(pc.x - side * es * 0.2, ey + es * 0.22, ez - es * 0.52), es * 0.21, Color.WHITE, 5, 3)
		# 윗눈꺼풀: 아래 반구 덮개. 뼈(눈 위쪽)에서 Y 크기를 키우면 내려와 눈을 덮는다.
		var lid_p := Vector3(ex, ey + es * 1.3, ez + es * 0.1)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.22, es * 2.7, es * 0.88), F.get("lid", skin.darkened(0.06)), 6, 3, Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹
		var by := ey + es * 2.05
		var bz := CharGeo.surf_z(hc, hr, ex, by)
		g.add_bone("Brow" + sfx, "Head", Vector3(ex, by, bz))
		g.use("Brow" + sfx)
		var bw: float = es * 1.05 * float(F.get("brow_w", 1.0))
		var bt: float = es * 0.24 * float(F.get("brow_t", 1.0))
		g.sweep([Vector3(ex - bw, by - es * 0.12, CharGeo.surf_z(hc, hr, ex - bw, by) - es * 0.1),
			Vector3(ex, by + es * 0.12, bz - es * 0.12),
			Vector3(ex + bw, by - es * 0.12, CharGeo.surf_z(hc, hr, ex + bw, by) - es * 0.1)], bt, F.brow, 3 if visor else 4)
	# 입
	var my: float = F.mouth_y
	var mw: float = F.mouth_w
	var mz := CharGeo.surf_z(hc, hr, 0.0, my)
	var dark := Color("4a1f28")
	g.add_bone("MouthN", "Head", Vector3(0, my, mz))
	g.use("MouthN")
	if visor:
		# 통투구: 입은 얼굴 판 뒤에 숨어 보이지 않는다(뼈 규약만 지킨다)
		g.ellipsoid(Vector3(0, my, mz + 0.04), Vector3(0.006, 0.006, 0.006), dark, 4, 2)
		g.add_bone("MouthA", "Head", Vector3(0, my, mz))
		g.use("MouthA")
		g.ellipsoid(Vector3(0, my, mz + 0.04), Vector3(0.006, 0.006, 0.006), dark, 4, 2)
		g.add_bone("MouthH", "Head", Vector3(0, my, mz))
		g.use("MouthH")
		g.ellipsoid(Vector3(0, my, mz + 0.04), Vector3(0.006, 0.006, 0.006), dark, 4, 2)
		g.use("Head")
		return
	var pts: Array = []
	for i in 5:
		var u := float(i) / 2.0 - 1.0
		var x := u * mw * 0.5
		var y := my + u * u * mw * 0.28
		pts.append(Vector3(x, y, CharGeo.surf_z(hc, hr, x, y) - mw * 0.04))
	g.sweep(pts, mw * 0.1, dark, 4)
	g.add_bone("MouthA", "Head", Vector3(0, my, mz))
	g.use("MouthA")
	g.ellipsoid(Vector3(0, my - mw * 0.05, mz + mw * 0.08), Vector3(mw * 0.45, mw * 0.26, mw * 0.2), dark, 8, 4)
	g.ellipsoid(Vector3(0, my + mw * 0.1, mz - mw * 0.03), Vector3(mw * 0.36, mw * 0.07, mw * 0.12), Color.WHITE, 6, 3)
	# 아픔·기절: 옆으로 벌어진 납작한 입(이를 악문 듯)
	g.add_bone("MouthH", "Head", Vector3(0, my, mz))
	g.use("MouthH")
	g.ellipsoid(Vector3(0, my - mw * 0.08, mz + mw * 0.06), Vector3(mw * 0.46, mw * 0.17, mw * 0.14), dark, 8, 3)
	g.use("Head")


# ------------------------------------------------------------------ 망토

## 성기사의 파란 망토(어깨 뒤에서 흘러내린다, Cape 뼈로 흔들림).
## 가슴판 뒤면(z 0.15)·허리 갑옷·뒤 허리 판보다 뒤(z 0.17 부터 아래로 갈수록 더 뒤)에 걸고 옆 감김을 줄여,
## 뒤에서 봐도 등 갑옷이 천을 뚫고 비치지 않는다.
static func _cape(g: CharGeo) -> void:
	var top := Vector3(0, float(P.shoulder) + 0.02, 0.17)
	g.add_bone("Cape", "Spine", top)
	g.use("Cape")
	g.cape(top, 0.42, 0.3, 0.42, BLUE, BLUE_DARK, 0.08, 0.05, 0.02, 5, 4)
	# 망토를 거는 금 막대(어깨 뒤)
	g.line = 0.45
	g.tube(Vector3(-0.15, top.y, top.z - 0.008), Vector3(0.15, top.y, top.z - 0.008), 0.012, 0.012, GOLD, 6, true)
	g.line = 1.0


# ------------------------------------------------------------------ 무기·방패

## 무기를 쥔 방향: 주먹 아래에서 앞으로 deg 만큼 기운다. 쉬는 자세는 아래팔을 40° 접으므로 그만큼 더 앞을 향하고,
## pose_attack 은 들어 올렸다가 앞으로 내려친다(검 30° = 쉬는 자세에서 앞아래로 비스듬히(더 세우면 걷기에서 칼끝이 땅에 닿는다), 창 30° = 창날이 앞아래, 자루는 어깨 위로, 망치 36°).
static func _grip_dir(deg: float = 30.0) -> Vector3:
	var gr := deg_to_rad(deg)
	return Vector3(0, -cos(gr), -sin(gr))


## 검(오른손 +X): 손잡이가 주먹 속을 지나고 금 날밑이 주먹 아래 면에 얹히며 칼자루 끝(금 공)만 주먹 위로 나온다.
## 넓고 밝은 날은 쉬는 자세에서 앞아래로 비스듬하다. 끝점을 돌려준다. (주먹 반지름 ≈ 0.087)
static func _sword(g: CharGeo, hand: Vector3, elite: bool) -> Vector3:
	g.use("HandR")
	var d := _grip_dir()
	var side := Vector3.RIGHT.cross(d)
	var sw := 0.042
	var sl := 0.46
	var fist := 0.088
	g.tube(hand - d * (fist + 0.025), hand + d * (fist + 0.01), 0.017, 0.017, LEATHER, 6, false)
	g.sphere(hand - d * (fist + 0.03), 0.027, GOLD, 6, 4)
	g.line = 0.6
	g.rounded_box(hand + d * (fist + 0.012), Vector3(sw * 2.6, 0.016, 0.022), GOLD, 0.4, 8, 4, Basis(Vector3.RIGHT, d, side))
	if elite:
		g.sphere(hand + d * (fist + 0.012) + side * 0.024, 0.016, RED, 5, 3)
	g.line = 1.0
	var b0 := hand + d * (fist + 0.026)
	var blade_end := b0 + d * sl
	g.tube(b0, blade_end, sw, sw * 0.9, BLADE, 6, false, 1.0, 0.25)
	var tip := blade_end + d * sw * 2.4
	g.tube(blade_end, tip, sw * 0.9, 0.0, BLADE, 6, true, 1.0, 0.25)
	# 날 가운데 홈(어두운 줄)
	g.line = 0.0
	g.tube(b0 + d * 0.02 - side * sw * 0.26, blade_end - d * 0.03 - side * sw * 0.26, sw * 0.18, sw * 0.14, SILVER_DARK, 4, false, 1.0, 0.4)
	g.line = 1.0
	return tip


## 창(오른손 +X): 키만큼 긴 곧은 나무 자루를 주먹 속으로 비스듬히 쥔다. 창날 쪽이 주먹 아래로 앞아래(검과 같은 방향)로 뻗고
## 자루의 긴 쪽은 뒤로 어깨 위까지 비스듬히 올라가 쇠 자루 끝이 머리 높이 뒤에 걸리므로, 어느 방향에서도 손에 붙은 막대가 아니라
## 몸을 가로지르는 긴 창으로 읽힌다. 쇠 자루 끝, 가죽 손잡이, 금 깃 테와 은 꽂이, 머리 높이의 절반쯤 되는 잎 모양 은 창날.
## 공격 자세에서 앞으로 내려 찌른다. 자루를 바깥(+X)으로 14° 틀어 정면에서도 창날이 몸·방패와 겹치지 않는다.
## (창날을 어깨 위로 세우면 고정된 내려치기 리그에서 찌르는 순간 창끝이 가장 낮다는 규약을 지킬 수 없어, 창날은 주먹 아래쪽이다.)
static func _spear(g: CharGeo, hand: Vector3) -> Vector3:
	g.use("HandR")
	var d := (Basis(Vector3.BACK, 0.25) * _grip_dir(30.0)).normalized()
	var side := Vector3.RIGHT.cross(d).normalized()
	var back := 0.5
	var fwd := 0.3
	g.spline_tube([hand - d * back, hand - d * 0.12, hand + d * 0.12, hand + d * fwd], [0.0145, 0.017, 0.017, 0.015], WOOD, 7, false, false)
	# 자루 끝 쇠 캡
	g.tube(hand - d * back, hand - d * (back + 0.035), 0.016, 0.011, SILVER_DARK, 6, true)
	# 손 쥐는 곳 가죽 띠(주먹 양쪽으로 조금씩 보인다)
	g.tube(hand - d * 0.11, hand + d * 0.11, 0.021, 0.021, LEATHER, 7, true)
	# 금 깃 테와 은 꽂이(창날 소켓)
	g.line = 0.5
	g.tube(hand + d * fwd, hand + d * (fwd + 0.042), 0.028, 0.023, GOLD, 8, true)
	g.line = 1.0
	g.tube(hand + d * (fwd + 0.042), hand + d * (fwd + 0.078), 0.02, 0.013, SILVER, 7, true)
	# 잎 모양 창날(앞뒤에서 넓게 보이도록 X 로 넓다)
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
	# 날의 넓은 면을 자루 축 둘레로 조금 돌려 정면·비스듬한 쪽 어디서도 잎 모양이 보이게 한다
	var across := d.cross(side).normalized()
	var bb := Basis(d, -0.5) * Basis(across, d, side)
	side = bb.z
	g.polygon(leaf, b0, bb, 0.02, SILVER_LIGHT, SILVER_DARK)
	# 날 가운데 등줄(양면에 가늘고 어두운 줄)
	g.line = 0.0
	for s: float in [-1.0, 1.0]:
		g.polygon(PackedVector2Array([Vector2(-0.008, 0.02), Vector2(0.008, 0.02), Vector2(0.0, bl * 0.9)]), b0 + side * (0.0105 * s), bb, 0.002, SILVER_DARK)
	g.line = 1.0
	return hand + d * (fwd + 0.065 + bl)


## 전쟁 망치(오른손 +X): 주먹 속을 지나는 긴 자루 끝에 머리만 한 은빛 쇠 머리(양쪽 어두운 타격면 + 가운데 금 띠).
## 머리 가운데를 끝점으로 돌려준다. 자루가 길어 쉬는 자세에서 머리가 어깨·방패와 겹치지 않는다.
static func _hammer(g: CharGeo, hand: Vector3) -> Vector3:
	g.use("HandR")
	# 자루를 바깥(+X)으로 34° 기울여 쥔다: 큰 머리가 몸·방패에서 멀어지고 맞는 자세(팔이 들려 옴)에서도 턱·투구와 겹치지 않는다
	var d := (Basis(Vector3.BACK, 0.6) * _grip_dir(36.0)).normalized()
	var w := Vector3.RIGHT.cross(d).normalized()
	var u := d.cross(w).normalized()
	var hl := 0.55
	g.spline_tube([hand - d * 0.28, hand - d * 0.1, hand + d * 0.1, hand + d * (hl + 0.07)], [0.019, 0.023, 0.023, 0.02], WOOD, 7, true, true)
	g.tube(hand - d * 0.115, hand + d * 0.115, 0.029, 0.029, LEATHER, 7, true)
	g.sphere(hand - d * 0.28, 0.027, SILVER_DARK, 6, 4)
	var head := hand + d * hl
	var hb := Basis(u, d, w)
	var hr := Vector3(0.125, 0.08, 0.086)    # 좌우 폭(머리 폭의 0.8), 자루 방향 높이(머리 높이의 0.5), 앞뒤
	g.rounded_box(head, hr, SILVER, 0.3, 8, 5, hb)
	# 양쪽 타격면(어두운 쇠 덮개)
	for s: float in [-1.0, 1.0]:
		g.rounded_box(head + u * (hr.x * s), Vector3(0.022, hr.y * 0.9, hr.z * 0.9), HAMMER_DARK, 0.3, 6, 3, hb)
	# 가운데 금 띠
	g.line = 0.5
	g.rounded_box(head, Vector3(0.026, hr.y * 1.06, hr.z * 1.06), GOLD, 0.3, 5, 3, hb)
	g.line = 1.0
	return head


## 방패(왼손 -X): 하트 모양(위는 평평, 아래는 뾰족) 은 테 + 색 면 + 십자. 가슴에서 무릎까지 닿는 크기.
## 창기사·망치 기사는 조금 작은 방패(0.9배).
static func _shield(g: CharGeo, v: int, hand: Vector3) -> void:
	g.use("HandL")
	var small := v == 2 or v == 3
	var sc := 0.9 if small else 1.0
	var face_col := BLUE if v == 4 else RED
	var mark := GOLD if v == 4 else WHITE
	var nrm := Vector3(-0.5, -0.45, -0.74).normalized()
	var center := hand + nrm * 0.06 + Vector3(-0.02, 0.03, 0)
	var t1 := nrm.cross(Vector3.UP).normalized()
	var t2 := t1.cross(nrm).normalized()
	if t2.y < 0.0:
		t2 = -t2
	var sb := Basis(t1, t2, nrm)
	var w := 0.185 * sc
	var ht := 0.21 * sc
	var hb := 0.285 * sc
	var outline := _heater(w, ht, hb)
	var inner := _heater(w * 0.86, ht * 0.84, hb * 0.86)
	# 손잡이(팔뚝에 묶는 띠)
	g.tube(center - nrm * 0.02, center - nrm * 0.06, 0.035, 0.03, LEATHER, 6, true)
	g.polygon(outline, center, sb, 0.03, GOLD if v == 4 else SILVER, GOLD_DARK if v == 4 else SILVER_DARK)
	g.polygon(inner, center + nrm * 0.014, sb, 0.012, face_col, face_col.darkened(0.2))
	g.line = 0.5
	var a := 0.03 * sc
	var top := 0.13 * sc
	var bot := -0.16 * sc
	var cw := 0.1 * sc
	var cross := PackedVector2Array([Vector2(-a, top), Vector2(-a, a * 2.0), Vector2(-cw, a * 2.0), Vector2(-cw, 0.0), Vector2(-a, 0.0), Vector2(-a, bot),
		Vector2(a, bot), Vector2(a, 0.0), Vector2(cw, 0.0), Vector2(cw, a * 2.0), Vector2(a, a * 2.0), Vector2(a, top)])
	g.polygon(cross, center + nrm * 0.024, sb, 0.008, mark, mark.darkened(0.15))
	if v == 4:
		g.sphere(center + nrm * 0.03 + t2 * a, 0.02 * sc, GOLD_DARK, 6, 4)
	g.line = 1.0


## 하트 방패 윤곽(2D, 반시계): 위는 평평, 옆은 곧게 내려오다 아래로 둥글게 모여 뾰족하다
static func _heater(w: float, ht: float, hb: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(-w, ht))
	pts.append(Vector2(-w, 0.0))
	var n := 5
	for i in range(1, n):
		var t := float(i) / float(n)
		var ang := t * PI * 0.5
		pts.append(Vector2(-w * pow(cos(ang), 0.8), -hb * pow(sin(ang), 1.3)))
	pts.append(Vector2(0.0, -hb))
	for i in range(n - 1, 0, -1):
		var t := float(i) / float(n)
		var ang := t * PI * 0.5
		pts.append(Vector2(w * pow(cos(ang), 0.8), -hb * pow(sin(ang), 1.3)))
	pts.append(Vector2(w, 0.0))
	pts.append(Vector2(w, ht))
	return pts


# ------------------------------------------------------------------ 이전 명세(호환)

## 이전 HumanBuilder 명세. 기사 본체는 더 이상 쓰지 않지만 SkeletonBuilder.spec() 이 바탕으로 가져다 쓴다.
static func spec(v: int) -> Dictionary:
	var old_plume := ["d8333a", "f4efe4", "e8742e", "3b6fd4", "c8343a"]
	var old_shield := ["plain", "cross", "band", "ring", "stripes"]
	var old_helmet := ["round", "pointed", "crest", "visor", "brim"]
	var old_skin := ["f2c9a0", "e6b088", "f6d6b8", "d9a27a", "efc29a"]
	return {
		H = 1.15,
		P = {
			ankle = 0.08, knee = 0.245, hip = 0.425, hip_x = 0.085, pelvis = 0.44, spine = 0.5,
			shoulder = 0.72, shoulder_x = 0.2, elbow = 0.575, wrist = 0.44, neck = 0.75, head = 0.8,
			arm_r = 0.047, leg_r = 0.052, foot_len = 0.2,
		},
		hc = Vector3(0, 0.955, -0.005), hr = Vector3(0.17, 0.165, 0.165),
		hand_s = 1.4, boot_s = 1.22,
		es = 0.034, eye_dx = 0.062, eye_y = 0.935, mouth_y = 0.868, mouth_w = 0.075,
		skin = Color(old_skin[v]),
		chest = Models.SILVER, chest_c = Vector3(0, 0.65, 0), chest_r = Vector3(0.205, 0.135, 0.135),
		waist = Color("7d8792"), waist_r = Vector2(0.092, 0.13), belt_y = 0.515,
		skirt = Models.RED, skirt_y = Vector2(0.52, 0.37), skirt_r = Vector2(0.115, 0.15),
		trouser = Color("6d6a78"), armor = Models.SILVER, armor_dark = Models.SILVER_DARK, trim = Models.GOLD,
		boot = Models.BOOT, glove = Color("8a5530"),
		pauldron = Vector3(0.13, 0.1, 0.13),
		cape = Color("b02a32"), cape_len = 0.36, cape_w = Vector2(0.12, 0.16),
		helmet = old_helmet[v], plumes = [Color(old_plume[v])], plume_size = 1.0,
		shield = old_shield[v], shield_r = 0.255, shield_c = Models.GOLD, shield_rim = Models.GOLD, shield_mark = Models.GOLD,
		sword_len = 0.46, sword_w = 0.038, mustache = (v == 3),
	}
