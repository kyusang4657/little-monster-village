class_name OrcBuilder
extends RefCounted
## 꼬마 오크(훈련장 유닛)의 메시·골격 정의(5차: 컨셉 시트 「꼬마 오크」 기준).
## 올리브색 민머리에 붉은 모히칸 볏(뿌리는 주황빛 갈색), 옆으로 뻗은 뾰족 귀(EarL/EarR 뼈로 펄럭임),
## 눈 위에 바짝 얹힌 짙은 눈썹 아래 작은 크림색 눈, 윗니가 드러난 넓은 입과 입꼬리에서 위로 솟은 큰 엄니 둘,
## 머리 폭의 1.4 배쯤 되는 땅딸막한 탱크 몸통: 짙은 회색 가죽 흉갑과 주황빛 갈색 끈(앞은 비스듬히, 뒤는 X 자), 놋쇠 버클 벨트,
## 크고 둥근 어깨 받이, 가죽 치마, 굵은 초록 팔뚝과 손목 띠, 무릎까지 늘어진 세 손가락 왕주먹, 굵고 짧은 다리에 큰 장화,
## 오른손의 길고 굵은 옹이 몽둥이(둥근 머리에 징 네 개, def.tip = 몽둥이 머리). 기본 키 HEIGHT 1.0(게임에서 1.3 배로 쓴다). 2.6등신.

const SKIN := Color("6f9a3a")
const SKIN_DARK := Color("577d2c")
const SKIN_LIGHT := Color("83ad48")
const EAR_IN := Color("4c6e27")
const MOHAWK := Color("d0352a")
const MOHAWK_HI := Color("e8663e")
const ROOT := Color("b9652c")
const BROW := Color("1c2411")
const EYE_RIM := Color("1a1512")
const SCLERA := Color("f6f0e0")
const PUPIL := Color("221c20")
const ARMOR := Color("4b4752")
const ARMOR_DARK := Color("36323c")
const ARMOR_LIGHT := Color("5c5864")
const STRAP := Color("a0622e")
const STRAP_DARK := Color("74441e")
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
const HR := Vector3(0.2, 0.19, 0.195)      # 머리 반지름
const ES := 0.046                           # 눈 크기(작고 매서운 눈)


static func build() -> Dictionary:
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	_torso(g)
	_limbs(g)
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


# ------------------------------------------------------------------ 몸통

## 몸통: 머리보다 훨씬 넓은 짙은 회색 가죽 흉갑(통통한 배), 비스듬한 앞 끈과 X 자 뒤 끈, 놋쇠 버클 벨트, 가죽 치마, 굵은 목
static func _torso(g: CharGeo) -> void:
	var tc := Vector3(0, 0.435, 0.0)
	var tr := Vector3(0.24, 0.15, 0.17)
	g.use("Spine")
	g.rounded_box(tc, tr, ARMOR, 0.72, 12, 7)
	# 가슴판 위쪽의 밝은 판(어깨 사이)
	g.ellipsoid(Vector3(0, 0.525, -0.02), Vector3(0.18, 0.04, 0.14), ARMOR_LIGHT, 10, 3)
	# 목 둘레 깃(짙은 가죽 띠)
	g.tube(Vector3(0, 0.56, 0), Vector3(0, 0.525, 0), 0.09, 0.115, ARMOR_DARK, 10, true)
	# 앞 끈: 왼쪽 어깨 → 오른쪽 허리(비스듬히), 가운데 놋쇠 징
	var strap: Array = []
	for i in 6:
		var t := float(i) / 5.0
		var x := lerpf(-0.15, 0.13, t)
		var y := lerpf(0.54, 0.335, t)
		strap.append(Vector3(x, y, CharGeo.surf_z(tc, tr, x, y) - 0.006))
	g.sweep(strap, 0.017, STRAP, 5)
	g.sphere(Vector3(-0.01, 0.437, CharGeo.surf_z(tc, tr, -0.01, 0.437) - 0.018), 0.018, BRASS, 6, 4)
	# 뒤 끈: X 자
	for side: float in [-1.0, 1.0]:
		var back: Array = []
		for i in 5:
			var t := float(i) / 4.0
			var x := lerpf(-0.15 * side, 0.15 * side, t)
			var y := lerpf(0.54, 0.345, t)
			var zz := tc.z + tr.z * sqrt(maxf(0.04, 1.0 - pow(x / tr.x, 2.0) - pow((y - tc.y) / tr.y, 2.0))) + 0.004
			back.append(Vector3(x, y, zz))
		g.sweep(back, 0.015, STRAP, 4)
	g.sphere(Vector3(0, 0.44, tc.z + tr.z + 0.012), 0.016, BRASS, 6, 4)
	# 벨트와 놋쇠 버클
	g.use("Pelvis")
	g.tube(Vector3(0, 0.29, 0), Vector3(0, 0.34, 0), 0.232, 0.228, STRAP_DARK, 12, false, 1.0, 0.8)
	g.rounded_box(Vector3(0, 0.315, -0.228), Vector3(0.046, 0.032, 0.01), BRASS, 0.4, 6, 3)
	g.rounded_box(Vector3(0, 0.315, -0.236), Vector3(0.02, 0.014, 0.006), BRASS_DARK, 0.5, 5, 3)
	# 가죽 치마(허리 아래로 퍼지는 짙은 회색 판, 아래 단은 갈색 테). 앞뒤는 조금 납작하게(쓰러질 때 땅에 묻히지 않게)
	g.tube(Vector3(0, 0.295, 0), Vector3(0, 0.2, 0), 0.232, 0.245, ARMOR, 12, false, 1.0, 0.78)
	g.tube(Vector3(0, 0.215, 0), Vector3(0, 0.195, 0), 0.246, 0.248, STRAP_DARK, 12, true, 1.0, 0.78)
	# 치마 세로 홈(판 이음새)
	for k in 4:
		var a := TAU * (float(k) + 0.5) / 4.0
		var dx := sin(a)
		var dz := -cos(a)
		g.sweep([Vector3(dx * 0.234, 0.285, dz * 0.234 * 0.78), Vector3(dx * 0.247, 0.215, dz * 0.247 * 0.78)], 0.006, ARMOR_DARK, 3)
	# 엉덩이(치마 안쪽 바지)
	g.ellipsoid(Vector3(0, 0.255, 0.0), Vector3(0.2, 0.085, 0.15), TROUSER, 8, 4)
	# 굵은 목
	g.use("Neck")
	g.tube(Vector3(0, 0.5, 0), Vector3(0, 0.64, 0), 0.08, 0.088, SKIN, 8, false)


# ------------------------------------------------------------------ 팔다리

## 팔(크고 둥근 어깨 받이, 굵은 초록 팔뚝, 손목 띠 두 줄, 무릎까지 늘어진 세 손가락 왕주먹)과 다리(굵고 짧은 갈색 바지, 큰 장화)
static func _limbs(g: CharGeo) -> void:
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	var ar: float = P.arm_r
	var lr: float = P.leg_r
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Arm" + sfx)
		g.sphere(Vector3(x, P.shoulder, 0), ar * 1.4, SKIN, 6, 3)
		g.tube(Vector3(x, P.shoulder, 0), Vector3(x, P.elbow, 0), ar * 1.3, ar * 1.1, SKIN, 8, false)
		# 어깨 받이: 크고 둥근 짙은 회색 덮개 + 갈색 테 + 놋쇠 징
		var pc := Vector3(x + 0.02 * side, float(P.shoulder) + 0.02, 0)
		var pr := Vector3(0.112, 0.098, 0.105)
		g.ellipsoid(pc, pr, ARMOR, 10, 4, Basis.IDENTITY, PI * 0.62, PI * 0.62)
		g.ellipsoid(pc, pr * 1.035, STRAP, 10, 1, Basis.IDENTITY, PI * 0.64, PI * 0.64, PI * 0.52)
		g.sphere(pc + Vector3(0.025 * side, 0.088, 0), 0.016, BRASS, 4, 2)
		g.use("Forearm" + sfx)
		g.sphere(Vector3(x, P.elbow, 0), ar * 1.15, SKIN, 6, 3)
		# 굵은 팔뚝(손목 쪽이 더 굵다)
		g.tube(Vector3(x, P.elbow, 0), Vector3(x, P.wrist, 0), ar * 1.15, ar * 1.5, SKIN, 8, false)
		g.use("Hand" + sfx)
		# 손목 띠 두 줄(주황빛 갈색 가죽)
		g.tube(Vector3(x, float(P.wrist) + ar * 0.8, 0), Vector3(x, float(P.wrist) - ar * 0.35, 0), ar * 1.6, ar * 1.68, STRAP, 8, true)
		g.sweep([Vector3(x - ar * 1.7, float(P.wrist) + ar * 0.2, -ar * 0.2), Vector3(x + ar * 1.7, float(P.wrist) + ar * 0.2, -ar * 0.2)], 0.007, STRAP_DARK, 4)
		# 왕주먹(hand_s ≈ 1.8) + 세 손가락 마디 + 엄지. 조금 앞·바깥으로 내밀어 치마와 겹치지 않게 한다
		var fc := Vector3(x + side * 0.012, float(P.wrist) - ar * 1.15, -0.04)
		g.ellipsoid(fc, Vector3(ar * 1.85, ar * 1.75, ar * 1.9), SKIN, 8, 4)
		for k in 3:
			var fx := (float(k) - 1.0) * ar * 1.15
			g.ellipsoid(fc + Vector3(fx, -ar * 0.65, -ar * 1.4), Vector3(ar * 0.62, ar * 0.6, ar * 0.75), SKIN, 4, 2)
		g.ellipsoid(fc + Vector3(-side * ar * 1.45, ar * 0.15, -ar * 0.9), Vector3(ar * 0.6, ar * 0.75, ar * 0.6), SKIN, 4, 2)
		# 다리(굵고 짧게)
		var lx := hx * side
		g.use("Leg" + sfx)
		g.tube(Vector3(lx, float(P.hip) + lr * 0.5, 0), Vector3(lx, float(P.knee) - 0.01, 0), lr * 1.4, lr * 1.2, TROUSER, 8, false)
		g.use("Shin" + sfx)
		g.sphere(Vector3(lx, P.knee, 0), lr * 1.1, TROUSER, 5, 3)
		g.tube(Vector3(lx, float(P.knee) - 0.015, 0), Vector3(lx, float(P.ankle) - 0.01, 0), lr * 1.15, lr * 1.3, BOOT, 7, false)
		g.tube(Vector3(lx, float(P.knee) + 0.005, 0), Vector3(lx, float(P.knee) - 0.03, 0), lr * 1.33, lr * 1.25, STRAP_DARK, 7, true)
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		g.ellipsoid(Vector3(lx, 0.064, -fl * 0.2), Vector3(lr * 1.5, 0.064, fl * 0.5), BOOT, 8, 4)
		g.ellipsoid(Vector3(lx, 0.054, -fl * 0.52), Vector3(lr * 1.28, 0.054, fl * 0.32), BOOT_TOE, 6, 3)


# ------------------------------------------------------------------ 머리

## 머리: 둥근 민머리와 넓은 턱, 얼굴, 납작한 코, 엄니, 뾰족 귀, 모히칸
static func _head(g: CharGeo) -> void:
	g.use("Head")
	g.ellipsoid(HC, HR, SKIN, 12, 7)
	# 넓은 턱(아래쪽 양 볼)
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(Vector3(0.11 * side, 0.71, -0.02), Vector3(0.112, 0.085, 0.135), SKIN, 6, 3)
	g.ellipsoid(Vector3(0, 0.67, -0.07), Vector3(0.11, 0.05, 0.1), SKIN, 6, 3)
	_face(g, {hc = HC, hr = HR, es = ES, eye_y = 0.805, eye_dx = 0.086, mouth_y = 0.69, mouth_w = 0.17,
		skin = SKIN, pupil = PUPIL, brow = BROW, eye_rim = EYE_RIM, sclera = SCLERA, eye_w = 1.1, iris = 0.85,
		brow_w = 1.2, brow_t = 2.0, lid = SKIN.darkened(0.05), lash = EYE_RIM})
	g.use("Head")
	# 둥글게 불룩한 코(눈 사이 아래, 엄니 위): 콧등은 조금 밝은 초록, 양쪽 콧방울
	var ny := 0.747
	var nc := Vector3(0, ny, CharGeo.surf_z(HC, HR, 0, ny) - 0.03)
	g.ellipsoid(nc, Vector3(0.048, 0.038, 0.046), SKIN_LIGHT, 8, 4)
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(nc + Vector3(0.036 * side, -0.012, 0.012), Vector3(0.026, 0.022, 0.026), SKIN, 5, 3)
	# 엄니: 입꼬리에서 위·바깥으로 솟았다가 안쪽으로 휜다(게임 화면에서도 읽히도록 크게)
	var keep_line := g.line
	g.line = 0.5
	for side: float in [-1.0, 1.0]:
		var fx := 0.086 * side
		var fz := CharGeo.surf_z(HC, HR, fx, 0.7) - 0.034
		g.horn(Vector3(fx, 0.665, fz), Vector3(side * 0.2, 1, -0.2).normalized(), Vector3(-side * 0.45, 0, -0.1), 0.11, 0.03, TUSK, 4, 7)
	g.line = keep_line
	_ears(g)
	_mohawk(g)


## 옆으로 뻗은 뾰족 귀(안쪽은 짙은 초록). EarL/EarR 뼈(2차 움직임)
static func _ears(g: CharGeo) -> void:
	g.measure = false
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var base := Vector3(0.18 * side, 0.805, 0.0)
		g.add_bone("Ear" + sfx, "Head", base)
		g.use("Ear" + sfx)
		var dir := Vector3(side, 0.5, -0.15).normalized()
		var L := 0.17
		var pts: Array = []
		var radii: Array = []
		var inner: Array = []
		var inner_r: Array = []
		var prof: Array = [0.05, 0.068, 0.062, 0.045, 0.024, 0.0]
		for i in 6:
			var t := float(i) / 5.0
			var p := base + dir * (L * t) + Vector3(0, 0.03 * t * t, 0.01 * t * t)
			pts.append(p)
			radii.append(prof[i])
			if i >= 1:
				inner.append(p + Vector3(0, -0.003, -0.012) + dir * 0.012)
				inner_r.append(float(prof[i]) * 0.58)
		g.spline_tube(pts, radii, SKIN, 7, true, true, Vector3.UP, 1.0, 0.32)
		var keep := g.line
		g.line = 0.4
		g.spline_tube(inner, inner_r, EAR_IN, 5, false, true, Vector3.UP, 1.0, 0.26)
		g.line = keep
	g.measure = true
	g.use("Head")


## 붉은 모히칸: 이마 위에서 뒤통수까지 정수리 가운데 줄을 따라 뒤로 쓸린 두툼한 쐐기 볏 5장(밑동 폭 ≈ 머리 폭의 0.45,
## 앞뒤로 겹쳐 한 덩어리 쐐기가 된다). 밑동은 두피를 앞뒤로 가로지르는 두툼한 주황빛 갈색 띠라 정면·게임 화면에서도 덩어리로 읽힌다.
## 볏은 번갈아 왼쪽·오른쪽으로 아주 조금 기울어 끝이 셋쯤 정면에서 보인다. 볏마다 앞면에 밝은 주황빛 띠.
static func _mohawk(g: CharGeo) -> void:
	g.measure = false
	g.use("Head")
	# 밑동 띠(두피 위에 앞뒤로 길게 얹은 두툼한 주황빛 갈색 타원)
	g.ellipsoid(Vector3(0, HC.y + HR.y - 0.03, HC.z + 0.005), Vector3(0.088, 0.062, 0.205), ROOT, 8, 3)
	var lens: Array = [0.15, 0.215, 0.245, 0.215, 0.15]
	var n := lens.size()
	for i in n:
		var t := (float(i) / float(n - 1) - 0.5) * 2.0   # -1(앞) ~ 1(뒤)
		var sway := (1.0 if i % 2 == 0 else -1.0) * (0.14 if i > 0 and i < n - 1 else 0.08)
		var z := HC.z + t * 0.14
		var y := HC.y + HR.y * sqrt(maxf(0.0, 1.0 - pow((z - HC.z) / HR.z, 2.0))) - 0.025
		var base := Vector3(0.0, y, z)
		var dir := Vector3(sway * 0.5, 1, 0.12 + t * 0.42).normalized()
		var bend := Vector3(sway * 0.3, 0, 0.32 + t * 0.2)
		_spike(g, base, dir, bend, float(lens[i]), 0.07, 0.078)
	g.measure = true


## 볏 한 장: 밑동 반지름이 앞뒤 rz·좌우 rx 인 통통한 쐐기(spline_tube, 끝은 뾰족). 앞면 가운데에 밝은 띠를 덧댄다.
static func _spike(g: CharGeo, base: Vector3, dir: Vector3, bend: Vector3, L: float, rz: float, rx: float) -> void:
	var d := dir.normalized()
	var pts: Array = []
	var radii: Array = []
	var hi: Array = []
	var hi_r: Array = []
	var prof: Array = [1.0, 0.88, 0.64, 0.34, 0.0]
	for i in 5:
		var t := float(i) / 4.0
		var p := base + d * (L * t) + bend * (L * t * t)
		var r := rz * float(prof[i])
		pts.append(p)
		radii.append(r)
		if i <= 3:
			# 앞면(−Z 쪽) 표면 바로 위에 띄운 밝은 띠
			hi.append(p + Vector3(0, 0.004, -r * 0.82 - 0.006))
			hi_r.append(maxf(r * 0.32, 0.007))
	g.spline_tube(pts, radii, MOHAWK, 6, true, true, Vector3.RIGHT, rx / rz, 1.0)
	var keep := g.line
	g.line = 0.0
	g.spline_tube(hi, hi_r, MOHAWK_HI, 3, false, true, Vector3.RIGHT, 1.0, 0.6)
	g.line = keep


# ------------------------------------------------------------------ 얼굴(공통 얼굴을 오크용으로 고친 복사본)

## 공통 face_parts 와 같은 뼈(EyeL/R, PupilL/R, LidL/R, BrowL/R, MouthN/A/H)를 쓴다.
## 작은 크림색 눈알에 얇은 짙은 테두리와 둥근 눈동자, 눈 윗부분에 바로 얹혀 안쪽이 내려간 아주 굵은 눈썹(기본이 사나운 얼굴),
## 보통 입은 윗니 줄이 드러난 넓은 찡그림, 화난 입은 크게 벌린 입에 윗니, 아픈 입은 작은 ○.
static func _face(g: CharGeo, F: Dictionary) -> void:
	var keep_line := g.line
	g.line = 0.0
	var hc: Vector3 = F.hc
	var hr: Vector3 = F.hr
	var es: float = F.es
	var ey: float = F.eye_y
	var skin: Color = F.skin
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var ex: float = float(F.eye_dx) * side
		var ez := CharGeo.surf_z(hc, hr, ex, ey)
		# 감은 눈 선(눈알 뒤에 숨어 있다가 눈알을 누르면 보인다)
		g.use("Head")
		var lash: Array = []
		for i in 3:
			var u := float(i) - 1.0
			var lx := ex + u * es * 0.62
			var ly := ey - es * (0.32 - 0.27 * u * u)
			lash.append(Vector3(lx, ly, CharGeo.surf_z(hc, hr, lx, ly) + es * 0.03))
		g.sweep(lash, es * 0.13, F.get("lash", F.pupil), 3)
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez + es * 0.3))
		g.use("Eye" + sfx)
		var ew: float = F.get("eye_w", 1.0)
		# 작은 크림색 눈알에 얇은 짙은 테두리(테두리는 눈알보다 조금만 크다), 둥근 짙은 눈동자와 반사광
		g.ellipsoid(Vector3(ex, ey, ez + es * 0.38), Vector3(es * (ew + 0.08), es * 1.32, es * 0.45), F.eye_rim, 10, 4)
		g.ellipsoid(Vector3(ex, ey, ez + es * 0.3), Vector3(es * ew, es * 1.22, es * 0.6), F.get("sclera", Color("fbfbf7")), 10, 4)
		var pc := Vector3(ex - side * es * 0.06, ey - es * 0.1, ez - es * 0.25)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		var ir: float = F.get("iris", 1.0)
		g.ellipsoid(pc, Vector3(es * 0.62 * ir, es * 0.66 * ir, es * 0.3), F.pupil, 8, 3)
		g.sphere(Vector3(pc.x + es * 0.16, pc.y + es * 0.2, ez - es * 0.54), es * 0.15, Color.WHITE, 4, 2)
		# 윗눈꺼풀: 아래 반구 덮개. 뼈(눈 위쪽)에서 Y 크기를 키우면 내려와 눈을 덮는다.
		var lid_p := Vector3(ex, ey + es * 1.3, ez + es * 0.1)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.3, es * 2.7, es * 0.9), F.get("lid", skin.darkened(0.06)), 6, 3, Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹: 눈 윗부분을 덮으며 바로 얹힌 짧고 굵은 눈썹. 바깥쪽이 올라가고 안쪽은 코 쪽으로 내려가 찡그린 얼굴이 된다
		var by := ey + es * 0.85
		var bz := CharGeo.surf_z(hc, hr, ex, by)
		g.add_bone("Brow" + sfx, "Head", Vector3(ex, by, bz))
		g.use("Brow" + sfx)
		var bw: float = es * 1.05 * float(F.get("brow_w", 1.0))
		var bt: float = es * 0.24 * float(F.get("brow_t", 1.0))
		var bpts: Array = []
		var bradii: Array = []
		var prof: Array = [0.55, 1.0, 1.0, 0.7]
		for i in 4:
			var t := float(i) / 3.0                     # 0 = 바깥 끝, 1 = 코 쪽 끝
			var px := ex + side * bw * (1.0 - 1.8 * t)
			var py := by + es * (0.4 - 0.8 * t)
			bpts.append(Vector3(px, py, CharGeo.surf_z(hc, hr, px, py) - es * 0.45))
			bradii.append(bt * float(prof[i]))
		# 눈알 앞에 얹힌 납작한 띠(앞뒤로 얇게)
		g.spline_tube(bpts, bradii, F.brow, 6, true, true, Vector3.UP, 1.0, 0.5)
	# 입
	var my: float = F.mouth_y
	var mw: float = F.mouth_w
	var mz := CharGeo.surf_z(hc, hr, 0.0, my)
	g.add_bone("MouthN", "Head", Vector3(0, my, mz))
	g.use("MouthN")
	# 보통: 넓은 찡그림(짙은 띠) 위에 윗니 줄
	g.ellipsoid(Vector3(0, my, mz + mw * 0.05), Vector3(mw * 0.5, mw * 0.11, mw * 0.16), MOUTH, 10, 4)
	_teeth(g, my + mw * 0.015, mw * 0.44, mw * 0.065, hc, hr, mw)
	g.add_bone("MouthA", "Head", Vector3(0, my, mz))
	g.use("MouthA")
	g.ellipsoid(Vector3(0, my - mw * 0.05, mz + mw * 0.08), Vector3(mw * 0.5, mw * 0.27, mw * 0.2), MOUTH, 10, 4)
	_teeth(g, my + mw * 0.12, mw * 0.44, mw * 0.07, hc, hr, mw)
	g.add_bone("MouthH", "Head", Vector3(0, my, mz))
	g.use("MouthH")
	g.ellipsoid(Vector3(0, my - mw * 0.03, mz + mw * 0.05), Vector3(mw * 0.2, mw * 0.2, mw * 0.14), MOUTH, 6, 3)
	g.use("Head")
	g.line = keep_line


## 윗니 줄: 네모난 이 5개를 입 가로폭 w 에 나란히(머리 곡면을 따라 앞으로 조금 내밀고 살짝 아래를 본다)
static func _teeth(g: CharGeo, y: float, w: float, h: float, hc: Vector3, hr: Vector3, mw: float) -> void:
	for k in 5:
		var x := (float(k) - 2.0) * w * 0.47
		var z := CharGeo.surf_z(hc, hr, x, y) - mw * 0.06
		g.box(Vector3(x, y, z), Vector3(w * 0.36, h * 2.0, mw * 0.1), TEETH, Basis(Vector3.RIGHT, -0.25))


# ------------------------------------------------------------------ 몽둥이

## 길고 굵은 옹이 몽둥이(오른손): 손잡이는 주먹 아래로 앞쪽 50°·바깥쪽 15° 기울어 쥔다(쉬는 자세에서 팔꿈치가 굽으면 거의 수평으로 앞을 향한다).
## 둥글게 부푼 머리에 짙은 옹이 혹과 놋쇠 징 네 개. 돌려주는 값 = 몽둥이 머리(def.tip)
static func _club(g: CharGeo, hand: Vector3) -> Vector3:
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var gr := deg_to_rad(50.0)
	var d := Vector3(0.28, -cos(gr), -sin(gr)).normalized()   # 바깥쪽으로도 조금 기울어 어느 자세에서도 몸통과 떨어진다
	var pts: Array = []
	var radii: Array = [0.034, 0.03, 0.033, 0.045, 0.072, 0.1, 0.108, 0.09, 0.045]
	var dist: Array = [-0.09, 0.0, 0.1, 0.2, 0.3, 0.39, 0.47, 0.54, 0.6]
	for i in dist.size():
		pts.append(hand + d * float(dist[i]))
	g.spline_tube(pts, radii, CLUB, 9, true, true)
	# 손잡이 가죽 감기와 끝 마디
	g.sweep([hand - d * 0.045, hand + d * 0.045], 0.034, STRAP_DARK, 6)
	g.sweep([hand - d * 0.1, hand - d * 0.085], 0.036, CLUB_DARK, 6)
	# 옹이(머리 둘레의 짙은 혹)와 놋쇠 징 네 개, 밝은 나뭇결 띠
	var head := hand + d * 0.465
	var u := Vector3.RIGHT
	u = (u - d * u.dot(d)).normalized()
	var w := d.cross(u).normalized()
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.4
		var along := d * (0.035 * sin(float(k) * 2.1))
		var off := (u * cos(a) + w * sin(a)) * 0.102
		g.sphere(head + along + off, 0.03, CLUB_DARK, 5, 3)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 1.2
		var along := d * (0.045 * cos(float(k) * 1.7))
		var off := (u * cos(a) + w * sin(a)) * 0.106
		g.sphere(head + along + off, 0.02, BRASS, 5, 3)
	g.sweep([hand + d * 0.3 - u * 0.07, hand + d * 0.315 + w * 0.064, hand + d * 0.33 + u * 0.07], 0.009, CLUB_LIGHT, 4)
	g.measure = true
	g.measure_all = true
	return hand + d * 0.5
