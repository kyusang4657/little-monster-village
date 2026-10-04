class_name SkeletonBuilder
extends RefCounted
## 해골 궁수(막사 유닛)의 메시·골격 정의(5차: 컨셉 시트 「해골 궁수」 기준).
## 밝은 뼈색 큰 해골(둥근 머리통 + 따로 붙인 둥근 턱, 커다란 새까만 눈구멍 속의 작은 붉은 빛점, 코 구멍, 이빨 줄,
## 눈구멍 위에 가늘게 파인 짙은 눈두덩 능선), 두개골을 바짝 감싸는 둥근 자색 두건(얼굴 전체가 드러나는 넓은 구멍과 밝은 테,
## 정수리 뒤로 축 처진 뭉툭한 꼭지. 모든 두건 부품은 Head 뼈)이 어깨를 덮는 망토 깃과 한 덩어리로 이어지고
## 무릎까지 늘어진 너덜거리는 망토(Cape 뼈로 흔들림)가 된다.
## 가슴은 자색 로브로 덮이고(깃에 작은 뼈 V 자), 놋쇠 버클 가죽 벨트 아래로 너덜거리는 자색 치마,
## 가는 뼈 팔다리와 관절 공, 갈색 팔 보호대, 갈색 장화, 왼손의 크고 비스듬히 바깥으로 든 황금빛 활과 시위(def.tip = 활 쥔 손),
## 등의 화살통. 기본 키 HEIGHT 1.15(게임에서 0.95 배). 2.5등신.
## 색은 게임 조명(해 0.5 + 주변광 0.2)에서 어두워지는 만큼 팔레트보다 한 단계 밝게 잡았다(후드가 화면에서 #3f3350 근처로 보이도록).

const BONE := Color("faf5e8")
const BONE_DARK := Color("e4dcc6")
const BONE_SHADE := Color("cfc5aa")
const RIDGE := Color("6e6252")
const SOCKET := Color("0d0a10")
const EYE := Color("ff4a44")
const EYE_CORE := Color("ffb49a")
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
const HC := Vector3(0, 0.95, -0.005)       # 머리통(두개골) 중심
const HR := Vector3(0.215, 0.198, 0.21)    # 머리통 반지름(후드 구멍에 비해 크게)
const JC := Vector3(0, 0.822, -0.03)       # 턱 중심
const JR := Vector3(0.15, 0.09, 0.14)      # 턱 반지름
const ES := 0.06                            # 눈구멍 크기(크고 둥근 타원)
const EYE_Y := 0.95


static func build() -> Dictionary:
	var g := CharGeo.new()
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


# ------------------------------------------------------------------ 몸통

## 몸통: 가슴을 덮는 자색 로브(앞 주름 두 줄, 깃의 작은 뼈 V 자), 어깨를 덮는 망토 깃, 가죽 벨트와 놋쇠 버클, 너덜거리는 치마, 목뼈
static func _torso(g: CharGeo) -> void:
	var tc := Vector3(0, 0.575, 0.0)
	var tr := Vector3(0.13, 0.11, 0.105)
	g.use("Spine")
	g.ellipsoid(tc, tr, ROBE, 12, 6)
	g.tube(Vector3(0, 0.46, 0), Vector3(0, 0.55, 0), 0.09, 0.12, ROBE, 10, false)
	# 로브 앞 주름(세로 두 줄, 조금 짙은 자색)
	for side: float in [-1.0, 1.0]:
		var fold: Array = []
		for k in 3:
			var y := 0.62 - float(k) * 0.075
			var x := side * (0.03 + 0.012 * float(k))
			fold.append(Vector3(x, y, CharGeo.surf_z(tc, tr, x, y) - 0.004))
		g.sweep(fold, 0.007, ROBE_FOLD, 3)
	# 깃의 작은 뼈 V 자(쇄골)
	g.sweep([Vector3(-0.05, 0.655, CharGeo.surf_z(tc, tr, -0.05, 0.655) - 0.008), Vector3(0, 0.6, CharGeo.surf_z(tc, tr, 0, 0.6) - 0.008),
		Vector3(0.05, 0.655, CharGeo.surf_z(tc, tr, 0.05, 0.655) - 0.008)], 0.011, BONE, 4)
	# 망토 깃(어깨를 둥글게 덮는 자색 덮개와 목 둘레): 후드 밑단과 겹쳐 한 덩어리로 이어진다
	g.ellipsoid(Vector3(0, 0.655, 0.01), Vector3(0.215, 0.085, 0.17), HOOD, 12, 4, Basis.IDENTITY, PI * 0.56, PI * 0.6)
	g.ellipsoid(Vector3(0, 0.655, 0.01), Vector3(0.215, 0.085, 0.17) * 1.03, HOOD_EDGE, 12, 1, Basis.IDENTITY, PI * 0.58, PI * 0.62, PI * 0.47)
	g.tube(Vector3(0, 0.74, 0.0), Vector3(0, 0.67, 0.0), 0.08, 0.115, HOOD, 10, false)
	# 벨트와 놋쇠 버클
	g.use("Pelvis")
	g.tube(Vector3(0, 0.395, 0), Vector3(0, 0.44, 0), 0.118, 0.114, LEATHER, 10, false)
	g.rounded_box(Vector3(0, 0.418, -0.118), Vector3(0.03, 0.02, 0.008), GOLD, 0.4, 6, 3)
	g.rounded_box(Vector3(0, 0.418, -0.124), Vector3(0.013, 0.009, 0.005), GOLD_DARK, 0.5, 4, 2)
	# 치마(아래로 퍼지는 자색 천)와 너덜거리는 단(삼각 조각 8장)
	g.tube(Vector3(0, 0.4, 0), Vector3(0, 0.3, 0), 0.115, 0.15, ROBE, 12, false)
	g.ellipsoid(Vector3(0, 0.395, 0), Vector3(0.12, 0.06, 0.1), ROBE_FOLD, 10, 4)
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		var dx := sin(a)
		var dz := -cos(a)
		var radial := Vector3(dx, 0, dz)
		var tangent := Vector3(dz, 0, -dx)
		var bas := Basis(tangent, Vector3.UP, radial)
		var w := 0.055 + 0.015 * float(k % 2)
		var h := 0.06 + 0.025 * float((k * 3) % 2)
		g.polygon(PackedVector2Array([Vector2(-w, 0.012), Vector2(w, 0.012), Vector2(0.01, -h)]),
			radial * 0.148 + Vector3(0, 0.305, 0), bas, 0.008, ROBE, HOOD_DARK)
	# 목뼈
	g.use("Neck")
	g.tube(Vector3(0, 0.66, 0), Vector3(0, 0.78, 0), 0.034, 0.038, BONE_DARK, 7, false)
	g.sphere(Vector3(0, 0.7, 0), 0.04, BONE, 6, 3)


# ------------------------------------------------------------------ 팔다리

## 가는 뼈 팔다리: 어깨·팔꿈치·무릎 관절 공, 갈색 팔 보호대, 세 손가락 뼈 손, 갈색 장화와 접힌 윗단
static func _limbs(g: CharGeo) -> void:
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	var ar: float = P.arm_r
	var lr: float = P.leg_r
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Arm" + sfx)
		g.sphere(Vector3(x, P.shoulder, 0), ar * 1.35, BONE, 7, 4)
		g.tube(Vector3(x, P.shoulder, 0), Vector3(x, P.elbow, 0), ar * 0.85, ar * 0.72, BONE, 7, false)
		g.use("Forearm" + sfx)
		g.sphere(Vector3(x, P.elbow, 0), ar * 1.1, BONE, 6, 3)
		g.tube(Vector3(x, P.elbow, 0), Vector3(x, P.wrist, 0), ar * 0.78, ar * 0.7, BONE, 7, false)
		# 갈색 가죽 팔 보호대(아래팔 아래쪽 절반)
		g.tube(Vector3(x, float(P.elbow) - 0.045, 0), Vector3(x, float(P.wrist) + 0.012, 0), ar * 1.1, ar * 1.2, LEATHER_LIGHT, 7, true)
		g.sweep([Vector3(x - ar * 1.25, float(P.wrist) + 0.04, 0), Vector3(x + ar * 1.25, float(P.wrist) + 0.04, 0)], 0.005, LEATHER, 4)
		g.use("Hand" + sfx)
		g.sphere(Vector3(x, P.wrist, 0), ar * 0.95, BONE, 6, 3)
		var hcn := Vector3(x, float(P.wrist) - ar * 1.0, -0.012)
		g.ellipsoid(hcn, Vector3(ar * 1.3, ar * 1.25, ar * 1.35), BONE, 7, 4)
		for k in 3:
			var fx := (float(k) - 1.0) * ar * 0.85
			g.ellipsoid(hcn + Vector3(fx, -ar * 0.6, -ar * 1.0), Vector3(ar * 0.4, ar * 0.55, ar * 0.62), BONE, 4, 2)
		# 다리
		var lx := hx * side
		g.use("Leg" + sfx)
		g.tube(Vector3(lx, float(P.hip) + lr * 0.3, 0), Vector3(lx, float(P.knee), 0), lr * 0.95, lr * 0.8, BONE, 7, false)
		g.use("Shin" + sfx)
		g.sphere(Vector3(lx, P.knee, 0), lr * 1.15, BONE, 6, 3)
		g.tube(Vector3(lx, float(P.knee), 0), Vector3(lx, float(P.ankle) + 0.05, 0), lr * 0.82, lr * 0.75, BONE, 7, false)
		# 장화 목과 접힌 윗단
		g.tube(Vector3(lx, float(P.ankle) + 0.075, 0), Vector3(lx, float(P.ankle) - 0.01, 0), lr * 1.1, lr * 1.2, BOOT, 7, false)
		g.tube(Vector3(lx, float(P.ankle) + 0.095, 0), Vector3(lx, float(P.ankle) + 0.065, 0), lr * 1.25, lr * 1.18, BOOT_CUFF, 7, true)
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		g.ellipsoid(Vector3(lx, 0.05, -fl * 0.2), Vector3(lr * 1.4, 0.05, fl * 0.48), BOOT, 8, 4)
		g.ellipsoid(Vector3(lx, 0.045, -fl * 0.5), Vector3(lr * 1.2, 0.045, fl * 0.3), BOOT, 6, 3)


# ------------------------------------------------------------------ 망토

## 등 뒤로 무릎까지 늘어진 자색 망토(양옆은 몸을 감싸고, 단은 물결). 윗단은 후드 밑과 망토 깃 속에 묻힌다. Cape 뼈(2차 움직임)
static func _cape(g: CharGeo) -> void:
	var top := Vector3(0, 0.72, 0.085)
	g.add_bone("Cape", "Spine", top)
	g.use("Cape")
	g.cape(top, 0.465, 0.32, 0.42, HOOD, HOOD_DARK, 0.05, 0.11, 0.06, 8, 5)


# ------------------------------------------------------------------ 머리

## 머리: 매끈한 둥근 머리통 하나와 그 아래 따로 붙인 둥근 턱, 얼굴, 후드
static func _head(g: CharGeo) -> void:
	g.use("Head")
	g.ellipsoid(HC, HR, BONE, 16, 9)
	g.ellipsoid(JC, JR, BONE, 12, 5)
	# 관자놀이의 금 간 자국
	var keep_line := g.line
	g.line = 0.0
	g.sweep([Vector3(0.135, 1.04, CharGeo.surf_z(HC, HR, 0.135, 1.04) - 0.003), Vector3(0.158, 1.0, CharGeo.surf_z(HC, HR, 0.158, 1.0) - 0.003),
		Vector3(0.14, 0.965, CharGeo.surf_z(HC, HR, 0.14, 0.965) - 0.003)], 0.004, BONE_SHADE, 3)
	g.line = keep_line
	_face(g)
	g.use("Head")
	_hood(g)


## 두건: 두개골을 바짝 감싸는 둥근 자색 껍데기(머리통보다 한 치수 큰 타원체). 극을 앞(-Z, 살짝 아래)으로 눕히고 극 둘레(lat_min)를
## 둥글게 잘라 내서 관자놀이·이마·턱 밑을 도는 넓은 구멍을 만든다(구멍 테두리 = 두툼한 밝은 단). 꼭대기는 두개골 꼭대기보다 조금 높을 뿐이고
## 정수리 뒤에서 뭉툭한 꼭지가 뒤로 축 처진다. 밑단은 망토 깃과 망토 속으로 들어간다. 모두 Head 뼈라 고개와 함께 움직인다.
static func _hood(g: CharGeo) -> void:
	g.use("Head")
	var hc := Vector3(0, 0.918, 0.03)
	var pole := Vector3(0, -0.12, -1).normalized()
	var bas := Basis(Vector3.RIGHT, pole, Vector3.RIGHT.cross(pole))
	var hr := Vector3(0.252, 0.262, 0.252)   # 좌우 · 앞뒤(극 방향) · 위아래
	var lat_min := 1.0
	g.ellipsoid(hc, hr, HOOD, 16, 7, bas, PI, PI, lat_min)
	# 구멍 테두리 단(구멍 둘레 한 바퀴, 조금 밝은 자색)
	var rim: Array = []
	for j in 16:
		var lon := TAU * float(j) / 16.0
		var dir := Vector3(sin(lat_min) * sin(lon), cos(lat_min), -sin(lat_min) * cos(lon))
		rim.append(hc + bas * (dir * (hr * 1.015)) - pole * 0.006)
	g.sweep(rim, 0.022, HOOD_EDGE, 5, true)
	# 작은 금 핀(이마 위 테두리 가운데)
	g.sphere(hc + bas * (Vector3(0, cos(lat_min), -sin(lat_min)) * (hr * 1.015)) - pole * 0.02, 0.016, GOLD, 6, 3)
	# 뭉툭한 꼭지(정수리 뒤에서 솟았다가 뒤로 축 처진다). 키(HEIGHT)에는 넣지 않는다
	g.measure = false
	var t0 := hc + Vector3(0, 0.175, 0.1)
	g.spline_tube([t0, t0 + Vector3(0, 0.06, 0.05), t0 + Vector3(0, 0.07, 0.115), t0 + Vector3(0, 0.04, 0.165), t0 + Vector3(0, -0.01, 0.195)],
		[0.1, 0.08, 0.058, 0.038, 0.02], HOOD, 8, false, true)
	g.measure = true


# ------------------------------------------------------------------ 얼굴(공통 얼굴을 해골용으로 고친 복사본)

## 공통 face_parts 와 같은 뼈(EyeL/R, PupilL/R, LidL/R, BrowL/R, MouthN/A/H)를 쓴다.
## 눈 = 머리통 곡면을 따라 기울인 커다란 새까만 타원 눈구멍(가로의 1/4 크기 붉은 빛점과 밝은 심이 그 안에 떠 있다),
## 눈꺼풀은 뼈색 두덩(깜빡임·표정에서 눈구멍을 덮는다), 눈썹 뼈는 눈구멍 위에 가늘게 파인 짙은 능선(표정에서 기울어 눈구멍 모양을 바꾼다),
## 코 = 거꾸로 선 삼각 구멍, 보통 입 = 턱 위의 이빨 줄, 화난 입 = 벌린 턱, 아픈 입 = 작은 ○.
static func _face(g: CharGeo) -> void:
	var keep_line := g.line
	g.line = 0.0
	var es := ES
	var ey := EYE_Y
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var ex := 0.094 * side
		var ez := CharGeo.surf_z(HC, HR, ex, ey)
		# 눈구멍 자리의 곡면 법선: 눈구멍을 머리통에 붙여 기울인다
		var nrm := Vector3(ex / (HR.x * HR.x), (ey - HC.y) / (HR.y * HR.y), (ez - HC.z) / (HR.z * HR.z)).normalized()
		var yaw := asin(clampf(nrm.x, -1.0, 1.0))
		var tilt := Basis(Vector3.UP, -yaw) * Basis(Vector3.BACK, -0.15 * side)
		# 감은 눈 선(눈구멍 뒤에 숨어 있다가 눈구멍을 누르면 보인다)
		g.use("Head")
		var lash: Array = []
		for i in 3:
			var u := float(i) - 1.0
			var lx := ex + u * es * 0.9
			var ly := ey - es * (0.32 - 0.27 * u * u)
			lash.append(Vector3(lx, ly, CharGeo.surf_z(HC, HR, lx, ly) - es * 0.05))
		g.sweep(lash, es * 0.16, SOCKET, 3)
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez + es * 0.3))
		g.use("Eye" + sfx)
		# 눈구멍: 새까만 큰 타원(nrm 은 바깥쪽 법선. 중심을 머리통 안쪽에 두어 겉으로는 조금만 나온다)
		var sc := Vector3(ex, ey, ez) - nrm * (es * 0.25)
		g.ellipsoid(sc, Vector3(es * 1.3, es * 1.5, es * 0.6), SOCKET, 10, 5, tilt)
		# 붉은 빛점(눈구멍 가로의 1/4)과 밝은 심: 눈구멍 겉면 바로 앞에 떠 있다
		var pc := sc + nrm * (es * 0.5) + Vector3(0, -es * 0.12, 0)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.sphere(pc, es * 0.3, EYE, 7, 4)
		g.sphere(pc + nrm * (es * 0.18) + Vector3(es * 0.1, es * 0.1, 0), es * 0.11, EYE_CORE, 5, 3)
		# 윗눈꺼풀(뼈색): 아래 반구 덮개. 뼈(눈 위쪽)에서 Y 크기를 키우면 내려와 눈구멍을 덮는다.
		var lid_p := Vector3(ex, ey + es * 1.4, ez + es * 0.1)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.45, es * 3.0, es * 0.95), BONE, 7, 3, Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈두덩 능선: 눈구멍 위 가장자리를 따라 두개골에 파인 가는 짙은 홈(반지름의 2/3 가 곡면 속에 묻힌다). 표정에서 기울어 눈구멍 모양을 바꾼다
		var by := ey + es * 1.62
		var bz := CharGeo.surf_z(HC, HR, ex, by)
		g.add_bone("Brow" + sfx, "Head", Vector3(ex, by, bz))
		g.use("Brow" + sfx)
		var bw := es * 1.15
		var br := es * 0.11
		var ox := ex + side * bw
		var ix := ex - side * bw * 0.85
		g.sweep([Vector3(ox, by - es * 0.28, CharGeo.surf_z(HC, HR, ox, by - es * 0.28) + br * 0.65),
			Vector3(ex, by + es * 0.04, bz + br * 0.65),
			Vector3(ix, by - es * 0.18, CharGeo.surf_z(HC, HR, ix, by - es * 0.18) + br * 0.65)], br, RIDGE, 4)
	g.use("Head")
	# 코 구멍(거꾸로 선 삼각)
	var ny := ey - es * 1.5
	var nz := CharGeo.surf_z(HC, HR, 0, ny) - 0.004
	var nb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	g.polygon(PackedVector2Array([Vector2(-0.022, 0.013), Vector2(0.022, 0.013), Vector2(0, -0.03)]), Vector3(0, ny, nz), nb, 0.012, SOCKET)
	# 입(턱 곡면 위)
	var my := 0.815
	var mw := 0.165
	var mz := CharGeo.surf_z(JC, JR, 0.0, my)
	g.add_bone("MouthN", "Head", Vector3(0, my, mz))
	g.use("MouthN")
	g.ellipsoid(Vector3(0, my, mz + mw * 0.05), Vector3(mw * 0.5, mw * 0.1, mw * 0.16), MOUTH, 10, 4)
	_teeth(g, my + mw * 0.005, mw * 0.46, mw * 0.065, mw)
	g.add_bone("MouthA", "Head", Vector3(0, my, mz))
	g.use("MouthA")
	g.ellipsoid(Vector3(0, my - mw * 0.1, mz + mw * 0.08), Vector3(mw * 0.46, mw * 0.3, mw * 0.2), MOUTH, 10, 4)
	_teeth(g, my + mw * 0.1, mw * 0.42, mw * 0.06, mw)
	g.add_bone("MouthH", "Head", Vector3(0, my, mz))
	g.use("MouthH")
	g.ellipsoid(Vector3(0, my - mw * 0.03, mz + mw * 0.05), Vector3(mw * 0.18, mw * 0.2, mw * 0.14), MOUTH, 6, 3)
	g.use("Head")
	g.line = keep_line


## 이빨 줄: 네모난 이 6개를 입 가로폭 w 에 나란히(턱 곡면을 따라 조금 내민다)
static func _teeth(g: CharGeo, y: float, w: float, h: float, mw: float) -> void:
	for k in 6:
		var x := (float(k) - 2.5) * w * 0.38
		var z := CharGeo.surf_z(JC, JR, x, y) - mw * 0.05
		g.box(Vector3(x, y, z), Vector3(w * 0.3, h * 2.0, mw * 0.1), BONE, Basis(Vector3.RIGHT, -0.2))


# ------------------------------------------------------------------ 활·화살통

## 큰 황금빛 활(왼손, 길이 ≈ 키의 0.9): 축은 손에서 위로 뻗되 앞쪽 30°·바깥쪽 22° 기울어 몸에서 비스듬히 벌어지고,
## 활대는 바깥·앞으로 휘며 끝은 되감긴다(정면·옆·게임 화면 어디서도 활 모양이 읽힌다). 가죽 손잡이, 금 끝, 시위.
static func _bow(g: CharGeo, hl: Vector3) -> void:
	g.use("HandL")
	g.measure = false
	g.measure_all = false
	var tilt := deg_to_rad(30.0)
	var out := deg_to_rad(22.0)
	var a := Vector3(-sin(out), cos(out) * cos(tilt), -cos(out) * sin(tilt)).normalized()
	# 활대가 휘는 방향: 바깥(-X)과 앞(-Z) 사이(축에 수직)
	var f := Vector3(-0.72, 0, -0.6)
	f = (f - a * f.dot(a)).normalized()
	var ts: Array = [-1.0, -0.86, -0.68, -0.45, -0.2, 0.0, 0.2, 0.45, 0.68, 0.86, 1.0]
	var pts: Array = []
	var radii: Array = []
	var half := 0.52
	var mid := hl + a * 0.12   # 활 가운데는 손보다 조금 위(아래 끝이 땅에 닿지 않게)
	for t: float in ts:
		var bow := 0.2 * (1.0 - t * t)
		var curl := 0.055 * maxf(0.0, absf(t) - 0.75) / 0.25
		var off := bow - 0.2 + curl
		pts.append(mid + a * (t * half) + f * off)
		radii.append(0.017 + 0.022 * (1.0 - absf(t)) * (1.0 - absf(t)))
	g.spline_tube(pts, radii, BOW, 7, true, true)
	# 가죽 손잡이와 금 끝 장식
	g.sweep([hl - a * 0.07, hl + a * 0.07], 0.04, LEATHER, 6)
	var last := pts.size() - 1
	g.sweep([pts[1], pts[0]], 0.022, GOLD, 5)
	g.sweep([pts[last - 1], pts[last]], 0.022, GOLD, 5)
	# 시위(두 끝 사이 직선, 가운데 화살 거는 매듭)
	var tip0: Vector3 = pts[0]
	var tip1: Vector3 = pts[last]
	g.sweep([tip0, tip1], 0.0075, STRING, 4)
	g.sphere((tip0 + tip1) * 0.5, 0.013, LEATHER, 5, 3)
	g.measure = true
	g.measure_all = true


## 등의 가죽 화살통(오른쪽 어깨 뒤로 비스듬히)과 화살 넉 대(붉은·흰 깃)
static func _quiver(g: CharGeo) -> void:
	g.use("Spine")
	var q0 := Vector3(0.09, 0.5, 0.15)
	var q1 := Vector3(0.15, 0.73, 0.2)
	var d := (q1 - q0).normalized()
	g.tube(q0, q1, 0.038, 0.046, LEATHER, 8, true)
	g.tube(q1 - d * 0.03, q1 + d * 0.002, 0.049, 0.05, LEATHER_LIGHT, 8, true)
	g.tube(q0 + d * 0.05, q0 + d * 0.075, 0.042, 0.043, LEATHER_LIGHT, 8, true)
	g.measure = false
	for k in 4:
		var ang := TAU * float(k) / 4.0 + 0.5
		var off := Vector3(cos(ang), 0, sin(ang)) * 0.02
		var s0 := q1 + off + d * 0.0
		var s1 := q1 + off + d * (0.12 + 0.015 * float(k % 2))
		g.tube(s0, s1, 0.006, 0.006, BOW_DARK, 4, true)
		g.ellipsoid(s1 - d * 0.03, Vector3(0.016, 0.03, 0.006), FLETCH if k % 2 == 0 else FLETCH2, 4, 2, Basis(Quaternion(Vector3.UP, d)))
	g.measure = true
