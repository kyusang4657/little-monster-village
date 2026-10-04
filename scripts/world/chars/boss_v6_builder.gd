class_name BossV6Builder
extends RefCounted
## 보스 2종 6차 교체 후보(CharacterRig.model_set = "v6" 일 때만 쓰인다). 디자인은 5차(boss_builder.gd)와 같고,
## 조립한 기본 도형 대신 이어지는 곡면(DemonGeo: 조각 구·회전체·이어진 관·망토 격자)으로 다시 만들었다. 정점 명암(bake)은 쓰지 않는다.
## "commander" = 기사단장 번쩍경: 조각 구 한 장의 투구(닫힌 면갑 창이 살짝 패이고 가운데 능선·뺨 가리개·목 가리개가 한 면에 이어짐),
##   면갑의 T자 틈과 틈 속 빛나는 눈, 금 창 테·눈썹 바, 붉은 크레스트(Plume), 회전체 한 장의 판금 몸통(금 띠·짙은 허리띠·판금 치마),
##   어깨 속에서 시작해 큰 건틀릿 주먹까지 이어진 팔, 금 테 가시 어깨 갑옷, 금 테 붉은 망토(Cape), 오른손 대검·왼손 건틀릿.
## "hero" = 용사 루루: 조각 구 머리(볼·작은 턱·얕은 눈두덩), 눈두덩에 앉은 크고 파란 눈(위 짙은 속눈썹 뚜껑), 머리 덮개 + 앞머리 다섯 갈래 +
##   머리에서 허리까지 이어지는 물결 뒷머리 다섯 가닥 + 어깨 앞 옆 가닥(관, 머리→몸 뼈로 이어짐), 남색 리본, 회전체 남색 베레모(금 띠·붉은 깃 Plume),
##   회전체 한 장의 파란 상의·흰 치마(파란 단·금 선), 은 가슴판·남색 앞자락(겉면을 따라가는 띠), 금 테 보라 망토(Cape), 맨손, 오른손 검.
## 골격 규약은 5차와 같다: 기준점 = 두 발 사이 지면, 정면 = -Z, 오른손 = +X, 얼굴 뼈(Eye/Pupil/Lid/Brow/Mouth N·A·H), 2차 뼈 Cape·Plume.

const BOSS_H := 1.3            ## 키 등급(자세 진폭 기준)
const GOLD := Color("e1b23c")
const GOLD_DARK := Color("b4862a")
const RED := Color("c0282c")
const CREST := Color("c8343a")
const RED_DARK := Color("7d161c")
const BLADE := Color("dfe6ee")

# 기사단장 투구(조각 구) 중심·반지름
const CMD_HC := Vector3(0, 1.122, 0.007)
const CMD_HR := Vector3(0.2, 0.19, 0.2)
# 루루 머리(조각 구) 중심·반지름과 눈 방향
const HERO_HC := Vector3(0, 1.105, -0.005)
const HERO_HR := Vector3(0.165, 0.16, 0.16)
const HERO_EYE_X := 0.4
const HERO_EYE_Y := -0.04
const HERO_ES := 0.044


static func build(k: String) -> Dictionary:
	return _commander() if k == "commander" else _hero()


# ================================================================== 공통 도우미

static func _ring(y: float, rx: float, rz: float, bone: String, col: Color) -> Dictionary:
	return {y = y, rx = rx, rz = rz, bone = bone, col = col}


## 회전체 프로파일의 높이 y 에서 (rx, rz)
static func _prof_at(prof: Array, y: float) -> Vector2:
	for i in prof.size() - 1:
		var a: Dictionary = prof[i]
		var b: Dictionary = prof[i + 1]
		var ya: float = a.y
		var yb: float = b.y
		if y <= ya and y >= yb:
			var t := (ya - y) / maxf(ya - yb, 0.0001)
			return Vector2(lerpf(float(a.rx), float(b.rx), t), lerpf(float(a.rz), float(b.rz), t))
	var first: Dictionary = prof[0]
	var e: Dictionary = first if y > float(first.y) else prof[prof.size() - 1]
	return Vector2(float(e.rx), float(e.rz))


## 회전체 앞(-Z) 겉면 위 점(x, y), lift 만큼 바깥으로
static func _on_front(prof: Array, x: float, y: float, lift: float) -> Vector3:
	var r := _prof_at(prof, y)
	var q := 1.0 - pow(clampf(x / r.x, -0.999, 0.999), 2.0)
	return Vector3(x, y, -r.y * sqrt(q) - lift)


## 회전체 겉면을 따라가는 띠(front_strip)를 프로파일로 부른다
static func _strip(g: DemonGeo, prof: Array, x0: float, x1: float, y_top: float, y_bot: float, lift: float, col: Color, steps: int = 6) -> void:
	var rz_of := func(y: float) -> float: return _prof_at(prof, y).y
	var rx_of := func(y: float) -> float: return _prof_at(prof, y).x
	g.front_strip(x0, x1, y_top, y_bot, rz_of, rx_of, lift, col, steps)


## 회전체 둘레를 도는 테(타원 단면에 맞춰 눌린 도넛)
static func _band(g: DemonGeo, prof: Array, y: float, r: float, col: Color, segs: int = 16) -> void:
	var rr := _prof_at(prof, y)
	g.torus(Vector3(0, y, 0), rr.x + r * 0.3, r, col, segs, 4, Basis.IDENTITY.scaled(Vector3(1.0, 1.0, rr.y / rr.x)))


## 조각 구 겉면 점: 방향 d(단위), 반지름 배수 k
static func _sp(hc: Vector3, hr: Vector3, d: Vector3, k: float) -> Vector3:
	return hc + Vector3(d.x * hr.x, d.y * hr.y, d.z * hr.z) * k


## 경도(정면 0, 오른쪽 +)·위도(적도 0, 위 +)로 방향
static func _dir(lon: float, lat: float) -> Vector3:
	return Vector3(sin(lon) * cos(lat), sin(lat), -cos(lon) * cos(lat))


static func _diamond(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, h), Vector2(-w, 0), Vector2(0, -h), Vector2(w, 0)])


static func _finish(g: DemonGeo, tip: Vector3, es: float, P: Dictionary) -> Dictionary:
	var def := g.build(CharacterRig.character_material())
	def.tip = tip
	def.H = BOSS_H
	def.es = es
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


## 검(오른손 +X): 주먹 hand 에 쥐고 아래로 tilt_deg, 그 기울기를 앞(-Z)과 바깥(+X, out_deg)으로 나눈다.
## 손잡이·자루 끝 구슬·휘어진 코등이·날(납작한 이어진 관, 끝이 뾰족)·가운데 능선. 돌려주는 값 = 검 끝
static func _sword(g: DemonGeo, hand: Vector3, sl: float, sw: float, gem: Color, guard_w: float, tilt_deg: float, out_deg: float, grip: float) -> Vector3:
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var keep := g.line
	var gr := deg_to_rad(tilt_deg)
	var og := deg_to_rad(out_deg)
	var d := Vector3(sin(gr) * sin(og), -cos(gr), -sin(gr) * cos(og))
	var ax := (Vector3.RIGHT - d * Vector3.RIGHT.dot(d)).normalized()
	var fr := ax.cross(d).normalized()
	if fr.z > 0.0:
		fr = -fr
	# 손잡이(가죽) + 자루 끝 금 구슬
	g.line = 0.7
	g.spline_tube([hand - d * grip, hand, hand + d * 0.055], [sw * 0.3, sw * 0.32, sw * 0.3], Color("4a2f1c"), 7, false, false)
	g.ellipsoid(hand - d * (grip + 0.008), Vector3(sw * 0.5, sw * 0.5, sw * 0.5), GOLD, 6, 4)
	# 코등이: 가운데가 굵고 양 끝이 날 쪽으로 살짝 휘는 금 관
	var gc := hand + d * 0.062
	var gpts: Array = []
	var grad: Array = []
	for i in 7:
		var u := float(i) / 6.0 * 2.0 - 1.0
		gpts.append(gc + ax * (u * guard_w * 0.5) + d * (u * u * sw * 0.45))
		grad.append(sw * (0.42 - 0.16 * absf(u)))
	g.spline_tube(gpts, grad, GOLD, 7, true, true, d)
	g.ellipsoid(gc + fr * sw * 0.36, Vector3(sw * 0.34, sw * 0.34, sw * 0.2), gem, 8, 4)
	# 날: 넓은 면이 X 쪽(정면에서 보인다), 끝은 뾰족
	var b0 := hand + d * 0.07
	var bpts: Array = []
	var brad: Array = []
	var n := 6
	for i in n + 1:
		var t := float(i) / float(n)
		bpts.append(b0 + d * (sl * t))
		brad.append(sw * lerpf(1.0, 0.9, t))
	bpts.append(b0 + d * (sl + sw * 1.4))
	brad.append(sw * 0.55)
	bpts.append(b0 + d * (sl + sw * 2.6))
	brad.append(0.0)
	g.line = 0.6
	g.spline_tube(bpts, brad, BLADE, 8, true, true, ax, 1.0, 0.28)
	# 가운데 능선(조금 짙은 강철)
	g.line = 0.0
	g.spline_tube([b0 + d * 0.02, b0 + d * (sl * 0.5), b0 + d * (sl - 0.02)], [sw * 0.26, sw * 0.24, sw * 0.18], BLADE.darkened(0.2), 4, true, true, ax, 1.0, 1.3)
	g.line = keep
	g.measure = true
	g.measure_all = true
	return b0 + d * (sl + sw * 2.6)


## 금 테 망토(2차 움직임 뼈 Cape). 양옆·아랫단에 금 테
static func _cape(g: DemonGeo, top: Vector3, length: float, w_top: float, w_bot: float, col_out: Color, col_in: Color,
		drape: float, wrap: float, wave: float, edge_r: float) -> void:
	g.add_bone("Cape", "Spine", top)
	g.use("Cape")
	var keep := g.line
	var P: Array = g.cape_grid(top, length, w_top, w_bot, col_out, col_in, drape, wrap, wave, 8, 7, 0.006)
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
	g.spline_tube(left, _const(left.size(), edge_r), GOLD, 4, false, false)
	g.spline_tube(right, _const(right.size(), edge_r), GOLD, 4, false, false)
	g.spline_tube(hem, _const(hem.size(), edge_r), GOLD, 4, true, true)
	g.line = keep


static func _const(cnt: int, r: float) -> Array:
	var out: Array = []
	for i in cnt:
		out.append(r)
	return out


# ================================================================== 기사단장 번쩍경

## 투구 조각 구의 반지름 배수: 면갑 창(얕게 패임), 가운데 능선, 뺨 가리개, 목 가리개
static func _helm_k(d: Vector3) -> float:
	var w := _visor_w(d)
	var k := 1.0 - 0.055 * w
	# 가운데 능선(창 위에서 정수리를 넘어 뒤까지)
	k += 0.03 * exp(-pow(d.x / 0.09, 2.0)) * smoothstep(-0.05, 0.35, d.y) * (1.0 - w)
	# 뺨 가리개(창 아래 양옆이 조금 앞·밖으로)
	k += 0.05 * (DemonGeo.bump(d, Vector3(-0.78, -0.42, -0.46).normalized(), 0.32) + DemonGeo.bump(d, Vector3(0.78, -0.42, -0.46).normalized(), 0.32))
	# 목 가리개(뒤 아래로 벌어짐)
	k += 0.07 * DemonGeo.bump(d, Vector3(0, -0.55, 0.83).normalized(), 0.45)
	return k


## 면갑 창 안쪽 정도(0~1): 경도 ±0.9, 위도 -0.82~0.42 의 둥근 사각
static func _visor_a(d: Vector3) -> float:
	var lon := atan2(d.x, -d.z)
	var lat := asin(clampf(d.y, -1.0, 1.0))
	return pow(pow(absf(lon) / 0.86, 3.0) + pow(absf(lat + 0.2) / 0.62, 3.0), 1.0 / 3.0)


static func _visor_w(d: Vector3) -> float:
	return 1.0 - smoothstep(0.84, 1.0, _visor_a(d))


static func _commander() -> Dictionary:
	var P := {ankle = 0.09, knee = 0.26, hip = 0.46, hip_x = 0.11, pelvis = 0.48, spine = 0.56,
		shoulder = 0.86, shoulder_x = 0.27, elbow = 0.69, wrist = 0.54, neck = 0.9, head = 0.95,
		arm_r = 0.06, leg_r = 0.066, foot_len = 0.24}
	var steel := Color("8e99a6")
	var steel_dk := Color("5f6873")
	var silver := Color("a9b2bb")
	var visor := Color("5c6571")
	var slit := Color("14171c")
	var boot := Color("6b7580")
	var leather := Color("3a2a20")
	var g := DemonGeo.new()
	g.bake = 0.0
	CharGeo.skeleton(g, P)
	# ---- 몸통: 목 → 고깃 → 넓은 가슴판 → 금 띠 → 허리 → 짙은 허리띠 → 판금 치마(금 단)까지 한 장
	var prof: Array = [
		_ring(1.0, 0.062, 0.062, "Neck", steel_dk),
		_ring(0.93, 0.068, 0.066, "Neck", steel_dk),
		_ring(0.905, 0.1, 0.095, "Spine", steel_dk),
		_ring(0.88, 0.125, 0.115, "Spine", steel_dk),
		_ring(0.862, 0.17, 0.135, "Spine", steel),
		_ring(0.835, 0.232, 0.15, "Spine", steel),
		_ring(0.785, 0.268, 0.16, "Spine", steel),
		_ring(0.72, 0.27, 0.158, "Spine", steel),
		_ring(0.668, 0.246, 0.15, "Spine", steel),
		_ring(0.648, 0.23, 0.146, "Spine", steel),
		_ring(0.642, 0.226, 0.145, "Spine", GOLD),
		_ring(0.622, 0.208, 0.14, "Spine", GOLD),
		_ring(0.615, 0.198, 0.136, "Spine", steel_dk),
		_ring(0.592, 0.175, 0.132, "Spine", steel_dk),
		_ring(0.586, 0.176, 0.134, "Spine", leather),
		_ring(0.548, 0.178, 0.136, "Pelvis", leather),
		_ring(0.54, 0.19, 0.145, "Pelvis", steel),
		_ring(0.47, 0.215, 0.165, "Pelvis", steel),
		_ring(0.4, 0.236, 0.18, "Pelvis", steel),
		_ring(0.382, 0.24, 0.183, "Pelvis", steel),
		_ring(0.377, 0.241, 0.184, "Pelvis", GOLD),
		_ring(0.356, 0.244, 0.186, "Pelvis", GOLD),
		_ring(0.35, 0.236, 0.18, "Pelvis", steel_dk),
	]
	g.lathe(prof, 14, false, true, 0.0, 0.0, func(i: int) -> float: return 0.0 if i < 2 else 1.0)
	# 고깃 위 금 테, 가슴 마름모 문장 + 붉은 보석, 버클
	g.use("Spine")
	g.line = 0.5
	_band(g, prof, 0.9, 0.012, GOLD, 12)
	var fb := Basis.IDENTITY
	var em := _on_front(prof, 0.0, 0.745, 0.004)
	g.polygon(_diamond(0.06, 0.08), em, fb, 0.012, GOLD, GOLD_DARK)
	g.line = 0.0
	g.ellipsoid(em + Vector3(0, 0, -0.008), Vector3(0.03, 0.045, 0.012), RED, 10, 5)
	# 가슴판 위 금 테 두 줄(목에서 어깨 쪽으로 벌어지는 V)
	g.line = 0.4
	for side: float in [-1.0, 1.0]:
		var vp: Array = []
		for i in 4:
			var t := float(i) / 3.0
			var x := lerpf(0.07, 0.2, t) * side
			var y := lerpf(0.86, 0.79, t * t)
			vp.append(_on_front(prof, x, y, 0.004))
		g.spline_tube(vp, _const(vp.size(), 0.011), GOLD, 5, true, true)
	g.line = 0.6
	var bk := _on_front(prof, 0.0, 0.567, 0.004)
	g.polygon(_diamond(0.045, 0.058), bk, fb, 0.014, GOLD, GOLD_DARK)
	g.line = 0.0
	g.ellipsoid(bk + Vector3(0, 0, -0.008), Vector3(0.022, 0.03, 0.01), RED, 8, 4)
	# 망토 걸쇠(가슴 위 양쪽 금 단추)
	g.line = 0.4
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(_on_front(prof, 0.15 * side, 0.83, 0.0), Vector3(0.022, 0.022, 0.014), GOLD, 8, 4)
	# 앞 붉은 천(허리띠 아래 치마 겉면을 따라 단 아래까지) + 금 테
	g.use("Pelvis")
	g.line = 0.6
	_strip(g, prof, -0.06, 0.06, 0.54, 0.31, 0.006, RED, 6)
	for side: float in [-1.0, 1.0]:
		_strip(g, prof, 0.058 * side, 0.07 * side, 0.54, 0.31, 0.007, GOLD, 6)
	g.line = 1.0
	# ---- 팔: 어깨 속 → 위팔(짙은 판금) → 팔꿈치 → 아래팔 → 넓게 벌어지는 건틀릿 소매(금 테) → 큰 주먹(둥근 끝)
	var sx: float = P.shoulder_x
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		var nodes: Array = [
			{p = Vector3(x * 0.7, 0.84, 0.0), r = 0.06, bone = "Arm" + sfx, col = steel_dk, line = 0.0},
			{p = Vector3(x * 0.98, 0.84, 0.0), r = 0.07, bone = "Arm" + sfx, col = steel_dk, line = 0.0},
			{p = Vector3(x * 1.02, 0.8, 0.0), r = 0.068, bone = "Arm" + sfx, col = steel_dk},
			{p = Vector3(x, 0.745, 0.0), r = 0.062, bone = "Arm" + sfx, col = steel_dk},
			{p = Vector3(x, 0.7, 0.0), r = 0.064, bone = "Forearm" + sfx, col = steel},
			{p = Vector3(x, 0.665, 0.0), r = 0.062, bone = "Forearm" + sfx, col = steel},
			{p = Vector3(x, 0.625, 0.0), r = 0.072, bone = "Forearm" + sfx, col = steel},
			{p = Vector3(x, 0.585, 0.0), r = 0.09, bone = "Forearm" + sfx, col = steel},
			{p = Vector3(x, 0.566, 0.0), r = 0.096, bone = "Forearm" + sfx, col = GOLD},
			{p = Vector3(x, 0.553, 0.0), r = 0.094, bone = "Forearm" + sfx, col = GOLD},
			{p = Vector3(x, 0.545, 0.0), r = 0.07, bone = "Hand" + sfx, col = steel_dk},
			{p = Vector3(x, 0.51, -0.006), r = 0.085, bone = "Hand" + sfx, col = steel_dk},
			{p = Vector3(x, 0.472, -0.01), r = 0.094, bone = "Hand" + sfx, col = steel_dk},
			{p = Vector3(x, 0.44, -0.012), r = 0.086, bone = "Hand" + sfx, col = steel_dk},
		]
		g.limb(nodes, 8, Vector3.FORWARD, false, true, 3)
		# 팔꿈치 덮개, 주먹 등 금 띠와 마디 징
		g.use("Forearm" + sfx)
		g.line = 0.5
		g.ellipsoid(Vector3(x, 0.695, 0.035), Vector3(0.05, 0.045, 0.04), steel, 8, 4)
		g.use("Hand" + sfx)
		g.torus(Vector3(x, 0.49, -0.008), 0.088, 0.01, GOLD, 10, 3)
		for k in 3:
			g.ellipsoid(Vector3(x + float(k - 1) * 0.04, 0.476, -0.1), Vector3(0.016, 0.016, 0.012), GOLD, 5, 3)
		g.line = 1.0
	# ---- 다리: 골반 속 → 허벅지 → 금 띠 무릎 → 정강이 → 금 발목 띠 → 장화
	var hx: float = P.hip_x
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var lx := hx * side
		var nodes: Array = [
			{p = Vector3(lx, 0.5, 0.0), r = 0.075, bone = "Leg" + sfx, col = steel_dk, line = 0.0},
			{p = Vector3(lx, 0.44, 0.0), r = 0.075, bone = "Leg" + sfx, col = steel_dk},
			{p = Vector3(lx, 0.34, 0.0), r = 0.071, bone = "Leg" + sfx, col = steel_dk},
			{p = Vector3(lx, 0.295, 0.0), r = 0.069, bone = "Shin" + sfx, col = steel},
			{p = Vector3(lx, 0.275, 0.0), r = 0.073, bone = "Shin" + sfx, col = GOLD},
			{p = Vector3(lx, 0.258, 0.0), r = 0.073, bone = "Shin" + sfx, col = GOLD},
			{p = Vector3(lx, 0.245, 0.0), r = 0.067, bone = "Shin" + sfx, col = steel},
			{p = Vector3(lx, 0.16, 0.0), r = 0.064, bone = "Shin" + sfx, col = steel},
			{p = Vector3(lx, 0.125, 0.0), r = 0.071, bone = "Foot" + sfx, col = GOLD},
			{p = Vector3(lx, 0.108, 0.0), r = 0.071, bone = "Foot" + sfx, col = GOLD},
			{p = Vector3(lx, 0.095, 0.0), r = 0.07, bone = "Foot" + sfx, col = boot},
			{p = Vector3(lx, 0.07, 0.0), r = 0.068, bone = "Foot" + sfx, col = boot},
		]
		g.limb(nodes, 8, Vector3.FORWARD, false, false)
		g.use("Shin" + sfx)
		g.line = 0.5
		g.ellipsoid(Vector3(lx, 0.268, -0.05), Vector3(0.05, 0.05, 0.035), steel, 8, 4)
		g.use("Foot" + sfx)
		g.line = 1.0
		g.rounded_box(Vector3(lx, 0.058, -0.055), Vector3(0.1, 0.058, 0.14), boot, 0.6, 10, 5)
	# ---- 어깨 갑옷: 머리만 한 돔 + 아래 겹판, 금 테, 표면에서 솟는 가시(금 끝), 앞 금 걸쇠
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.use("Arm" + sfx)
		var pc := Vector3(sx * side + 0.055 * side, 0.87, 0.0)
		var pr := Vector3(0.19, 0.15, 0.18)
		g.line = 1.0
		g.ellipsoid(pc + Vector3(0.025 * side, -0.07, 0.0), pr * Vector3(0.92, 0.8, 0.95), steel_dk, 12, 3, Basis.IDENTITY, PI * 0.56, PI * 0.56)
		g.ellipsoid(pc, pr, steel, 14, 5, Basis.IDENTITY, PI * 0.58, PI * 0.58)
		g.line = 0.4
		g.ellipsoid(pc, pr * 1.035, GOLD, 16, 1, Basis.IDENTITY, PI * 0.59, PI * 0.59, PI * 0.52)
		g.ellipsoid(pc + Vector3(0.025 * side, -0.07, 0.0), pr * Vector3(0.92, 0.8, 0.95) * 1.035, GOLD, 14, 1, Basis.IDENTITY, PI * 0.57, PI * 0.57, PI * 0.5)
		# 가시: 첫 마디는 돔 겉면 법선 방향(뿌리가 표면 속), 끝은 금
		var sn := Vector3(0.5 * side, 0.85, 0.0).normalized()
		var s0 := pc + Vector3(sn.x * pr.x, sn.y * pr.y, sn.z * pr.z) * 0.8
		var s1 := pc + Vector3(sn.x * pr.x, sn.y * pr.y, sn.z * pr.z) * 1.15
		var s2 := s1 + Vector3(0.06 * side, 0.07, 0.0)
		var sp: Array = []
		for i in 6:
			var t := float(i) / 5.0
			var p := s0.lerp(s1, minf(t * 2.0, 1.0)).lerp(s2, maxf(t * 2.0 - 1.0, 0.0))
			sp.append({p = p, r = 0.036 * (1.0 - t), bone = "Arm" + sfx, col = steel if t < 0.6 else GOLD, line = 0.0 if i == 0 else 0.8})
		g.limb(sp, 8, Vector3.BACK, false, true)
		g.line = 0.4
		g.ellipsoid(pc + Vector3(-0.05 * side, 0.1, -0.13), Vector3(0.028, 0.028, 0.018), GOLD, 8, 4)
		g.line = 0.0
		g.ellipsoid(pc + Vector3(-0.05 * side, 0.1, -0.147), Vector3(0.012, 0.012, 0.008), RED, 6, 3)
		g.line = 1.0
	# ---- 망토: 어깨 갑옷 밖까지 넓은 붉은 천, 금 테
	_cape(g, Vector3(0, 0.95, 0.165), 0.82, 0.8, 1.1, RED, RED_DARK, 0.03, 0.16, 0.03, 0.012)
	# ---- 투구: 조각 구 한 장(창 = 어두운 강철, 나머지 = 밝은 은)
	g.use("Head")
	g.line = 1.0
	var hc := CMD_HC
	var hr := CMD_HR
	var shape := func(d: Vector3) -> float: return _helm_k(d)
	var col_of := func(d: Vector3, _p: Vector3) -> Color: return silver.lerp(visor, _visor_w(d))
	g.sculpt(hc, hr, silver, 22, 13, shape, col_of)
	# 창 테(금, 창 가장자리를 한 바퀴) + 굵은 금 눈썹 바(창 위 가장자리)
	g.line = 0.4
	var rim: Array = []
	for j in 17:
		var th := TAU * float(j) / 16.0
		var dd := _visor_edge(th, 0.97)
		rim.append(_sp(hc, hr, dd, _helm_k(dd)) + dd * 0.002)
	g.sweep(rim, 0.011, GOLD, 5, true)
	var bar: Array = []
	var bar_r: Array = []
	for j in 9:
		var th := lerpf(0.42, PI - 0.42, float(j) / 8.0)
		var dd := _visor_edge(th, 0.99)
		bar.append(_sp(hc, hr, dd, _helm_k(dd)) + dd * 0.004)
		bar_r.append(0.02 * (1.0 - 0.45 * pow(absf(float(j) / 4.0 - 1.0), 2.0)))
	g.spline_tube(bar, bar_r, GOLD, 6, true, true, Vector3.BACK, 0.7, 1.0)
	# 귀 원판(금 고리)
	for side: float in [-1.0, 1.0]:
		var dd := Vector3(side, -0.05, 0.05).normalized()
		g.torus(_sp(hc, hr, dd, _helm_k(dd)) + Vector3(0.004 * side, 0, 0), 0.038, 0.011, GOLD, 10, 3, Basis(Vector3.BACK, PI * 0.5))
	# 얼굴(면갑 T자 틈과 빛나는 눈)
	var es := 0.021
	_visor_face(g, hc, hr, es, slit)
	# ---- 크레스트(Plume): 투구 이마 위에서 정수리를 넘어 목덜미까지 뒤로 휘는 두툼한 붉은 솔
	g.use("Head")
	var pd := _dir(0.0, 0.66)
	var plume_base := _sp(hc, hr, pd, _helm_k(pd)) - pd * 0.01
	g.add_bone("Plume", "Head", plume_base)
	g.use("Plume")
	g.measure = false
	g.line = 1.0
	var arc: Array = [Vector3(0, -0.02, 0.0), Vector3(0, 0.08, 0.02), Vector3(0, 0.165, 0.08), Vector3(0, 0.195, 0.17),
		Vector3(0, 0.16, 0.27), Vector3(0, 0.07, 0.35), Vector3(0, -0.09, 0.4), Vector3(0, -0.15, 0.405)]
	var pts: Array = []
	for p: Vector3 in arc:
		pts.append(plume_base + p)
	g.spline_tube(pts, [0.04, 0.068, 0.082, 0.085, 0.08, 0.066, 0.04, 0.0], CREST, 10, true, true, Vector3.RIGHT, 0.85, 1.2)
	g.measure = true
	# ---- 대검(오른손): 주먹에 쥐고 날을 앞·아래·바깥으로
	var hand_r := Vector3(sx, 0.472, -0.01)
	var tip := _sword(g, hand_r, 0.62, 0.058, RED, 0.19, 42.0, 16.0, 0.1)
	return _finish(g, tip, es, P)


## 면갑 창 가장자리 방향(th = 0 오른쪽, π/2 위). s = 창 크기 배율
static func _visor_edge(th: float, s: float) -> Vector3:
	# 둥근 사각(초타원 지수 3) 둘레
	var c := cos(th)
	var sn := sin(th)
	var lon := 0.86 * s * signf(c) * pow(absf(c), 2.0 / 3.0)
	var lat := -0.2 + 0.62 * s * signf(sn) * pow(absf(sn), 2.0 / 3.0)
	return _dir(lon, lat)


## 면갑 T자 틈(가로 눈 틈 + 세로 턱 틈) 과 틈 속 작은 빛 눈. 눈썹 = 틈 윗변의 굵은 어두운 선(화나면 찌푸린 틈이 된다).
## 눈꺼풀·입은 틈 색이라 눈이 감기면 빛이 꺼진 듯 보인다. 얼굴 뼈 규약 그대로.
static func _visor_face(g: DemonGeo, hc: Vector3, hr: Vector3, es: float, slit: Color) -> void:
	var keep := g.line
	g.line = 0.0
	var glow := Color("fff4bd")
	var pupil := Color("f0b232")
	var eye_lat := -0.13
	g.use("Head")
	var band: Array = []
	for j in 9:
		var lon := (float(j) / 8.0 - 0.5) * 0.9
		var dd := _dir(lon, eye_lat)
		band.append(_sp(hc, hr, dd, _helm_k(dd)) - dd * 0.0015)
	g.spline_tube(band, _const(band.size(), 0.017), slit, 6, true, true, Vector3.BACK, 0.35, 1.0)
	var vert: Array = []
	for j in 5:
		var dd := _dir(0.0, lerpf(eye_lat - 0.05, -0.62, float(j) / 4.0))
		vert.append(_sp(hc, hr, dd, _helm_k(dd)) - dd * 0.0015)
	g.spline_tube(vert, _const(vert.size(), 0.011), slit, 6, true, true, Vector3.RIGHT, 1.0, 0.4)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var dd := _dir(0.27 * side, eye_lat)
		var ec := _sp(hc, hr, dd, _helm_k(dd)) - dd * 0.004
		var eb := Basis.looking_at(dd, Vector3.UP)
		g.add_bone("Eye" + sfx, "Head", ec)
		g.use("Eye" + sfx)
		g.ellipsoid(ec, Vector3(es * 1.45, es * 0.7, es * 0.6), glow, 10, 5, eb)
		var pc := ec + dd * (es * 0.42)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.ellipsoid(pc, Vector3(es * 0.55, es * 0.5, es * 0.25), pupil, 8, 4, eb)
		g.ellipsoid(pc + eb * Vector3(es * 0.2, es * 0.18, -es * 0.2), Vector3(es * 0.14, es * 0.14, es * 0.08), Color.WHITE, 5, 3, eb)
		var lid_p := ec + eb * Vector3(0, es * 0.9, 0)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.55, es * 2.0, es * 0.8), slit, 8, 3, eb * Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹: 틈 윗변의 굵은 어두운 선. 양 끝은 가늘다
		var bd := _dir(0.27 * side, eye_lat + 0.11)
		var bp := _sp(hc, hr, bd, _helm_k(bd)) - bd * 0.002
		g.add_bone("Brow" + sfx, "Head", bp)
		g.use("Brow" + sfx)
		var bpts: Array = []
		for i in 5:
			var t := float(i) / 4.0
			var b2 := _dir((0.27 + lerpf(-0.17, 0.17, t)) * side, eye_lat + 0.11 - 0.02 * pow(absf(t * 2.0 - 1.0), 2.0))
			bpts.append(_sp(hc, hr, b2, _helm_k(b2)) - b2 * 0.002)
		g.spline_tube(bpts, [es * 0.2, es * 0.48, es * 0.55, es * 0.48, es * 0.2], slit, 6, true, true, Vector3.BACK, 0.6, 1.0)
	# 입 세 가지: 세로 틈 아래 끝의 작은 어두운 자국
	var md := _dir(0.0, -0.5)
	var mp := _sp(hc, hr, md, _helm_k(md)) - md * 0.002
	var mw := 0.022
	g.add_bone("MouthN", "Head", mp)
	g.use("MouthN")
	g.ellipsoid(mp, Vector3(mw * 0.6, mw * 0.22, mw * 0.25), slit, 6, 3)
	g.add_bone("MouthA", "Head", mp)
	g.use("MouthA")
	g.ellipsoid(mp + Vector3(0, -mw * 0.1, 0), Vector3(mw * 0.8, mw * 0.45, mw * 0.3), slit, 6, 3)
	g.add_bone("MouthH", "Head", mp)
	g.use("MouthH")
	g.ellipsoid(mp, Vector3(mw * 0.45, mw * 0.5, mw * 0.3), slit, 6, 3)
	g.use("Head")
	g.line = keep


# ================================================================== 용사 루루

static func _hero() -> Dictionary:
	var P := {ankle = 0.08, knee = 0.27, hip = 0.47, hip_x = 0.075, pelvis = 0.49, spine = 0.57,
		shoulder = 0.84, shoulder_x = 0.2, elbow = 0.69, wrist = 0.55, neck = 0.88, head = 0.93,
		arm_r = 0.042, leg_r = 0.045, foot_len = 0.19}
	var skin := Color("f3dcc7")
	var blue := Color("3d6fd6")
	var blue_dk := Color("2f55b0")
	var navy := Color("1f2a5e")
	var white := Color("e6ebf1")
	var silver := Color("c3ccd6")
	var cloak := Color("5a4a8a")
	var cloak_in := Color("7b6bb3")
	var cream := Color("e8d9b8")
	var gem := Color("4fc3f7")
	var g := DemonGeo.new()
	g.bake = 0.0
	CharGeo.skeleton(g, P)
	# ---- 몸통 + 치마: 목(피부) → 흰 깃 → 파란 상의 → 금 허리띠 → 흰 긴 치마 → 파란 단·금 선 까지 한 장
	var prof: Array = [
		_ring(1.0, 0.045, 0.045, "Neck", skin),
		_ring(0.888, 0.05, 0.05, "Neck", skin),
		_ring(0.876, 0.072, 0.068, "Spine", white),
		_ring(0.858, 0.1, 0.086, "Spine", white),
		_ring(0.848, 0.115, 0.093, "Spine", blue),
		_ring(0.83, 0.14, 0.103, "Spine", blue),
		_ring(0.795, 0.155, 0.114, "Spine", blue),
		_ring(0.74, 0.153, 0.116, "Spine", blue),
		_ring(0.685, 0.133, 0.106, "Spine", blue),
		_ring(0.635, 0.11, 0.09, "Spine", blue),
		_ring(0.607, 0.107, 0.089, "Spine", GOLD),
		_ring(0.582, 0.108, 0.09, "Pelvis", GOLD),
		_ring(0.577, 0.11, 0.091, "Pelvis", white),
		_ring(0.53, 0.135, 0.108, "Pelvis", white),
		_ring(0.44, 0.172, 0.136, "Pelvis", white),
		_ring(0.33, 0.208, 0.164, "Pelvis", white),
		_ring(0.2, 0.243, 0.19, "Pelvis", white),
		_ring(0.172, 0.25, 0.195, "Pelvis", white),
		_ring(0.166, 0.252, 0.197, "Pelvis", blue),
		_ring(0.118, 0.264, 0.206, "Pelvis", blue),
		_ring(0.112, 0.265, 0.207, "Pelvis", GOLD),
		_ring(0.098, 0.268, 0.209, "Pelvis", GOLD),
		_ring(0.092, 0.262, 0.204, "Pelvis", blue_dk),
	]
	g.lathe(prof, 14, false, true, 0.0, 0.0, func(i: int) -> float: return 0.0 if i < 1 else 1.0)
	# 은 가슴판(상의 겉면을 따라가는 판) + 금 테 + 금 별, 깃의 금 브로치(파란 보석), 허리 버클
	g.use("Spine")
	g.line = 0.6
	_strip(g, prof, -0.085, 0.085, 0.825, 0.69, 0.004, silver, 6)
	g.line = 0.3
	for side: float in [-1.0, 1.0]:
		_strip(g, prof, 0.08 * side, 0.092 * side, 0.828, 0.687, 0.006, GOLD, 6)
	g.line = 0.5
	var fb := Basis.IDENTITY
	g.polygon(CharGeo.star(4, 0.034, 0.013), _on_front(prof, 0.0, 0.775, 0.012), fb, 0.01, GOLD, GOLD_DARK)
	var br := _on_front(prof, 0.0, 0.855, 0.006)
	g.ellipsoid(br, Vector3(0.026, 0.026, 0.016), GOLD, 10, 5)
	g.line = 0.0
	g.ellipsoid(br + Vector3(0, 0, -0.013), Vector3(0.012, 0.012, 0.007), gem, 6, 3)
	g.line = 0.5
	g.polygon(_diamond(0.03, 0.036), _on_front(prof, 0.0, 0.595, 0.006), fb, 0.012, GOLD, GOLD_DARK)
	# 치마 앞 남색 자락(허리띠에서 단까지 겉면을 따라가며 금 테)
	g.use("Pelvis")
	g.line = 0.5
	_strip(g, prof, -0.055, 0.055, 0.575, 0.1, 0.005, blue_dk, 8)
	g.line = 0.3
	for side: float in [-1.0, 1.0]:
		_strip(g, prof, 0.052 * side, 0.064 * side, 0.575, 0.1, 0.007, GOLD, 8)
	g.line = 1.0
	# ---- 팔: 어깨 속 → 둥근 소매(파랑) → 흰 소맷부리 → 금 띠 → 맨손(둥근 끝)
	var sx: float = P.shoulder_x
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		var nodes: Array = [
			{p = Vector3(x * 0.6, 0.82, 0.0), r = 0.045, bone = "Arm" + sfx, col = blue, line = 0.0},
			{p = Vector3(x * 0.95, 0.825, 0.0), r = 0.053, bone = "Arm" + sfx, col = blue, line = 0.0},
			{p = Vector3(x * 1.02, 0.79, 0.0), r = 0.052, bone = "Arm" + sfx, col = blue},
			{p = Vector3(x, 0.74, 0.0), r = 0.044, bone = "Arm" + sfx, col = blue},
			{p = Vector3(x, 0.695, 0.0), r = 0.041, bone = "Forearm" + sfx, col = blue},
			{p = Vector3(x, 0.635, 0.0), r = 0.042, bone = "Forearm" + sfx, col = blue},
			{p = Vector3(x, 0.592, 0.0), r = 0.049, bone = "Forearm" + sfx, col = white},
			{p = Vector3(x, 0.575, 0.0), r = 0.05, bone = "Forearm" + sfx, col = GOLD},
			{p = Vector3(x, 0.566, 0.0), r = 0.048, bone = "Forearm" + sfx, col = GOLD},
			{p = Vector3(x, 0.56, 0.0), r = 0.033, bone = "Hand" + sfx, col = skin},
			{p = Vector3(x, 0.535, -0.003), r = 0.039, bone = "Hand" + sfx, col = skin},
			{p = Vector3(x, 0.51, -0.006), r = 0.04, bone = "Hand" + sfx, col = skin},
		]
		g.limb(nodes, 8, Vector3.FORWARD, false, true, 3)
		g.use("Hand" + sfx)
		g.line = 0.4
		g.ellipsoid(Vector3(x - side * 0.022, 0.525, -0.03), Vector3(0.016, 0.022, 0.016), skin, 6, 4)
		g.line = 1.0
	# ---- 다리: 흰 스타킹(치마 속) → 크림색 장화(금 띠)
	var hx: float = P.hip_x
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var lx := hx * side
		var nodes: Array = [
			{p = Vector3(lx, 0.5, 0.0), r = 0.05, bone = "Leg" + sfx, col = white, line = 0.0},
			{p = Vector3(lx, 0.4, 0.0), r = 0.048, bone = "Leg" + sfx, col = white},
			{p = Vector3(lx, 0.29, 0.0), r = 0.044, bone = "Shin" + sfx, col = white},
			{p = Vector3(lx, 0.2, 0.0), r = 0.041, bone = "Shin" + sfx, col = white},
			{p = Vector3(lx, 0.16, 0.0), r = 0.043, bone = "Shin" + sfx, col = cream},
			{p = Vector3(lx, 0.14, 0.0), r = 0.047, bone = "Shin" + sfx, col = GOLD},
			{p = Vector3(lx, 0.125, 0.0), r = 0.047, bone = "Foot" + sfx, col = GOLD},
			{p = Vector3(lx, 0.112, 0.0), r = 0.045, bone = "Foot" + sfx, col = cream},
			{p = Vector3(lx, 0.07, 0.0), r = 0.044, bone = "Foot" + sfx, col = cream},
		]
		g.limb(nodes, 6, Vector3.FORWARD, false, false)
		g.use("Foot" + sfx)
		g.rounded_box(Vector3(lx, 0.045, -0.035), Vector3(0.058, 0.045, 0.1), cream, 0.6, 10, 5)
	# ---- 작은 은 어깨 갑옷(금 테)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.use("Arm" + sfx)
		var pc := Vector3(sx * side + 0.025 * side, 0.845, 0.0)
		var pr := Vector3(0.085, 0.065, 0.085)
		g.line = 1.0
		g.ellipsoid(pc, pr, silver, 12, 4, Basis.IDENTITY, PI * 0.58, PI * 0.58)
		g.line = 0.4
		g.ellipsoid(pc, pr * 1.04, GOLD, 12, 1, Basis.IDENTITY, PI * 0.59, PI * 0.59, PI * 0.52)
		g.line = 1.0
	# ---- 망토: 보라(밝은 보라 안감), 금 테. 어깨 밖까지 넓고 치맛단 바로 위까지
	_cape(g, Vector3(0, 0.865, 0.1), 0.76, 0.62, 0.86, cloak, cloak_in, 0.13, 0.1, 0.02, 0.009)
	# ---- 머리·얼굴
	_hero_head(g, skin)
	_hero_hair(g)
	# ---- 검(오른손, 파란 보석)
	var hand_r := Vector3(sx, 0.516, -0.004)
	var tip := _sword(g, hand_r, 0.55, 0.05, gem, 0.13, 30.0, 0.0, 0.07)
	return _finish(g, tip, HERO_ES, P)


## 루루 머리: 조각 구 한 장(둥근 볼·작은 턱·얕은 눈두덩·아주 작은 코), 볼 홍조는 정점 색으로 섞는다
static func _hero_head(g: DemonGeo, skin: Color) -> void:
	g.use("Head")
	var hc := HERO_HC
	var hr := HERO_HR
	var blush := Color("f4a9a0")
	var eye_l := Vector3(-HERO_EYE_X, HERO_EYE_Y, -0.9).normalized()
	var eye_r := Vector3(HERO_EYE_X, HERO_EYE_Y, -0.9).normalized()
	var shape := func(d: Vector3) -> float:
		var k := 1.0
		k -= 0.04 * (DemonGeo.bump(d, eye_l, 0.25) + DemonGeo.bump(d, eye_r, 0.25))
		k += 0.04 * (DemonGeo.bump(d, Vector3(-0.6, -0.45, -0.66).normalized(), 0.42) + DemonGeo.bump(d, Vector3(0.6, -0.45, -0.66).normalized(), 0.42))
		k -= 0.035 * (DemonGeo.bump(d, Vector3(-0.8, -0.6, -0.1).normalized(), 0.4) + DemonGeo.bump(d, Vector3(0.8, -0.6, -0.1).normalized(), 0.4))
		k += 0.02 * DemonGeo.bump(d, Vector3(0, -0.75, -0.66).normalized(), 0.3)
		k += 0.022 * DemonGeo.bump(d, Vector3(0, -0.25, -1.0).normalized(), 0.1)
		k += 0.02 * DemonGeo.bump(d, Vector3(0, 0.1, 1.0).normalized(), 0.6)
		return k
	var col_of := func(d: Vector3, _p: Vector3) -> Color:
		var b := maxf(DemonGeo.bump(d, Vector3(-0.62, -0.32, -0.72).normalized(), 0.17), DemonGeo.bump(d, Vector3(0.62, -0.32, -0.72).normalized(), 0.17))
		return skin.lerp(blush, clampf(b * 0.75, 0.0, 1.0))
	g.line = 1.0
	g.sculpt(hc, hr, skin, 20, 12, shape, col_of)
	var keep := g.line
	g.line = 0.0
	var es := HERO_ES
	var sclera := Color("fbfbf7")
	var iris := Color("3f7de0")
	var core := Color("1c2a5c")
	var lash := Color("3a2618")
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var d := Vector3(HERO_EYE_X * side, HERO_EYE_Y, -0.9).normalized()
		var floor_p := _sp(hc, hr, d, 0.94)
		var er := Vector3(es * 0.95, es * 1.22, es * 0.62)
		var ec := floor_p - d * (es * 0.2)
		var eb := Basis.looking_at(d, Vector3.UP) * Basis(Vector3.BACK, side * 0.08)
		g.add_bone("Eye" + sfx, "Head", ec)
		g.use("Eye" + sfx)
		g.ellipsoid(ec, er, sclera, 12, 6, eb)
		# 홍채(크고 파란 세로 타원) + 짙은 동공 + 반사광 둘
		var pd := Vector3(-side * 0.06, -0.08, -1.0).normalized()
		var pc := ec + eb * (Vector3(pd.x * er.x, pd.y * er.y, pd.z * er.z) * 0.97)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.ellipsoid(pc, Vector3(es * 0.66, es * 0.86, es * 0.12), iris, 10, 4, eb)
		g.ellipsoid(pc + eb * Vector3(0, -es * 0.06, -es * 0.04), Vector3(es * 0.34, es * 0.46, es * 0.08), core, 8, 3, eb)
		g.ellipsoid(pc + eb * Vector3(side * es * 0.22, es * 0.32, -es * 0.1), Vector3(es * 0.17, es * 0.19, es * 0.05), Color.WHITE, 6, 3, eb)
		g.ellipsoid(pc + eb * Vector3(-side * es * 0.2, -es * 0.38, -es * 0.1), Vector3(es * 0.08, es * 0.08, es * 0.04), Color.WHITE, 5, 3, eb)
		# 윗눈꺼풀(피부색 덮개, 뼈 피벗 = 눈 위)
		var lid_p := ec + eb * Vector3(0, er.y * 0.95, 0)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(er.x * 1.15, er.y * 2.0, er.z * 1.1), skin, 8, 3, eb * Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 위 속눈썹: 눈알 윗부분을 덮는 짙은 뚜껑 + 바깥 끝으로 살짝 뻗는 꼬리(눈 뼈에 붙어 깜빡임과 같이 움직인다)
		g.use("Eye" + sfx)
		g.ellipsoid(ec, er * Vector3(1.05, 1.03, 1.04), lash, 12, 3, eb, PI * 0.22, PI * 0.22, 0.0)
		var w0 := ec + eb * Vector3(side * er.x * 0.8, er.y * 0.55, -er.z * 0.6)
		var w1 := ec + eb * Vector3(side * er.x * 1.15, er.y * 0.55, -er.z * 0.2)
		var w2 := ec + eb * Vector3(side * er.x * 1.38, er.y * 0.72, er.z * 0.05)
		g.spline_tube([w0, w1, w2], [es * 0.14, es * 0.11, 0.0], lash, 5, false, true)
		# 눈썹: 가는 갈색, 양 끝이 머리 겉면 속으로
		var bd := Vector3(HERO_EYE_X * side, 0.38, -0.86).normalized()
		var bp := _sp(hc, hr, bd, 1.0)
		g.add_bone("Brow" + sfx, "Head", bp)
		g.use("Brow" + sfx)
		var bi := Vector3(0.18 * side, 0.33, -0.93).normalized()
		var bo := Vector3(0.58 * side, 0.36, -0.73).normalized()
		g.spline_tube([_sp(hc, hr, bi, 0.985), _sp(hc, hr, bi.lerp(bd, 0.5).normalized(), 1.0), bp, _sp(hc, hr, bd.lerp(bo, 0.5).normalized(), 1.0), _sp(hc, hr, bo, 0.98)],
			[0.0, es * 0.12, es * 0.14, es * 0.1, 0.0], Color("8a5a2a"), 6, false, false)
	# 입: 보통 = 작은 웃는 선, 벌림 = 작은 붉은 입속, 아픔 = 작은 물결
	var md := Vector3(0, -0.47, -1.0).normalized()
	var mp := _sp(hc, hr, md, 1.03)
	var mw := 0.042
	var lip := Color("8a3a3a")
	g.add_bone("MouthN", "Head", mp)
	g.use("MouthN")
	var pts: Array = []
	for i in 5:
		var u := float(i) / 2.0 - 1.0
		pts.append(mp + Vector3(u * mw * 0.45, u * u * mw * 0.16, absf(u) * 0.003))
	g.spline_tube(pts, [0.0, mw * 0.06, mw * 0.07, mw * 0.06, 0.0], lip, 5, false, false)
	g.add_bone("MouthA", "Head", mp)
	g.use("MouthA")
	g.ellipsoid(mp + Vector3(0, -0.006, 0.002), Vector3(mw * 0.36, mw * 0.3, 0.01), Color("6a1f2a"), 10, 4)
	g.ellipsoid(mp + Vector3(0, -0.012, -0.004), Vector3(mw * 0.2, mw * 0.1, 0.006), Color("e07a80"), 8, 3)
	g.add_bone("MouthH", "Head", mp)
	g.use("MouthH")
	var wav: Array = []
	for i in 7:
		var u := float(i) / 3.0 - 1.0
		wav.append(mp + Vector3(u * mw * 0.4, sin(u * PI * 1.5) * mw * 0.07, absf(u) * 0.003))
	g.sweep(wav, mw * 0.06, lip, 4)
	g.use("Head")
	g.line = keep


## 루루 머리카락·베레모: 머리 덮개(머리를 감싸는 껍데기) + 앞머리 다섯 갈래 + 어깨 앞 옆 가닥 + 허리까지 이어지는 물결 뒷머리 다섯 가닥
## (뿌리는 머리 덮개 속, 위 마디는 Head 뼈 → 아래 마디는 Spine 뼈로 이어져 고개를 돌려도 끊기지 않는다) + 리본 + 베레모(Plume 깃)
static func _hero_hair(g: DemonGeo) -> void:
	var hair := Color("f0c040")
	var hair_dk := Color("d9a530")
	var navy := Color("1f2a5e")
	var hc := HERO_HC
	var hr := HERO_HR
	g.use("Head")
	g.line = 1.0
	var cap_c := hc + Vector3(0, 0.012, 0.012)
	var cap_r := hr * 1.09
	g.ellipsoid(cap_c, cap_r, hair, 18, 8, Basis.IDENTITY, 0.95, 2.75)
	# 앞머리: 정수리 쪽에서 이마로 흘러내리는 납작한 갈래(끝이 뾰족). 가운데는 짧고 바깥은 관자놀이까지
	g.line = 0.7
	var lobes: Array = [[-1.0, 1.32, 0.04], [-0.5, 1.12, 0.045], [0.0, 1.02, 0.048], [0.5, 1.12, 0.045], [1.0, 1.32, 0.04]]
	for L: Array in lobes:
		var lon: float = L[0]
		var le: float = L[1]
		var lr: float = L[2]
		var bp: Array = []
		var bradii: Array = []
		for i in 5:
			var t := float(i) / 4.0
			var lat := lerpf(0.35, le, t)
			var lo := lon * lerpf(0.35, 1.0, t) * 0.95
			var dd := Vector3(sin(lat) * sin(lo), cos(lat), -sin(lat) * cos(lo))
			bp.append(cap_c + Vector3(dd.x * cap_r.x, dd.y * cap_r.y, dd.z * cap_r.z) * lerpf(1.0, 1.05, t))
			bradii.append(lr * (1.0 - pow(t, 2.2)) * lerpf(0.8, 1.0, minf(t * 3.0, 1.0)))
		var nrm: Vector3 = ((bp[2] as Vector3) - cap_c).normalized()
		g.spline_tube(bp, bradii, hair, 6, false, true, nrm, 0.45, 1.0)
	# 옆 가닥: 관자놀이에서 어깨 앞으로(위 = Head, 아래 = Spine)
	for side: float in [-1.0, 1.0]:
		var nodes: Array = [
			{p = Vector3(0.14 * side, 1.12, -0.05), r = 0.03, bone = "Head", col = hair, line = 0.0},
			{p = Vector3(0.17 * side, 1.05, -0.075), r = 0.034, bone = "Head", col = hair},
			{p = Vector3(0.185 * side, 0.96, -0.095), r = 0.036, bone = "Head", col = hair},
			{p = Vector3(0.195 * side, 0.86, -0.11), r = 0.033, bone = "Spine", col = hair},
			{p = Vector3(0.21 * side, 0.76, -0.112), r = 0.029, bone = "Spine", col = hair},
			{p = Vector3(0.22 * side, 0.67, -0.1), r = 0.018, bone = "Spine", col = hair_dk},
		]
		g.limb(nodes, 7, Vector3.RIGHT, false, true, 2)
	# 뒷머리: 다섯 가닥이 뒤통수(머리 덮개 속)에서 나와 목덜미에서 모였다가 허리까지 물결치며 퍼진다. 앞뒤로 납작
	for li in 5:
		var u := float(li) / 2.0 - 1.0
		var wv := 0.018 * (1.0 if li % 2 == 0 else -1.0)
		var col_t := hair if absf(u) < 0.6 else hair.lerp(hair_dk, 0.3)
		var nodes: Array = [
			{p = Vector3(u * 0.08, 1.15, 0.13), r = 0.05, bone = "Head", col = hair, line = 0.0},
			{p = Vector3(u * 0.1, 1.08, 0.165), r = 0.06, bone = "Head", col = hair},
			{p = Vector3(u * 0.105, 0.99, 0.185), r = 0.05, bone = "Head", col = hair},
			{p = Vector3(u * 0.13 + wv, 0.88, 0.195), r = 0.052, bone = "Spine", col = hair},
			{p = Vector3(u * 0.16 - wv, 0.77, 0.205), r = 0.054, bone = "Spine", col = col_t},
			{p = Vector3(u * 0.18 + wv, 0.67, 0.205), r = 0.048, bone = "Spine", col = col_t},
			{p = Vector3(u * 0.19 - wv * 0.5, 0.585 - absf(u) * 0.03, 0.198), r = 0.032, bone = "Spine", col = hair_dk},
		]
		for N: Dictionary in nodes:
			N.fu = 0.55
			N.fw = 1.45
		g.limb(nodes, 6, Vector3.BACK, false, true, 2)
	# 리본(목덜미 뒤): 남색 고리 둘 + 금 매듭 + 짧은 꼬리 둘
	g.use("Head")
	g.line = 0.6
	var kn := Vector3(0, 1.0, 0.225)
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(kn + Vector3(0.045 * side, 0.012, 0.0), Vector3(0.042, 0.026, 0.016), navy, 8, 4, Basis(Vector3.BACK, 0.35 * side))
		g.spline_tube([kn + Vector3(0.012 * side, -0.01, 0.002), kn + Vector3(0.035 * side, -0.06, 0.008), kn + Vector3(0.05 * side, -0.11, 0.006)],
			[0.012, 0.016, 0.0], navy, 6, false, true, Vector3.BACK, 0.5, 1.0)
	g.ellipsoid(kn + Vector3(0, 0, 0.004), Vector3(0.018, 0.018, 0.014), GOLD, 8, 4)
	# 베레모: 머리 덮개 속에서 시작해 금 띠 위로 부풀고 위가 납작한 남색 회전체 + 금 띠 + 앞 금 장식(파란 보석)
	g.line = 1.0
	var bz := 0.015
	var beret: Array = [
		_ring(1.212, 0.13, 0.13, "Head", navy),
		_ring(1.232, 0.163, 0.162, "Head", navy),
		_ring(1.258, 0.188, 0.186, "Head", navy),
		_ring(1.286, 0.2, 0.198, "Head", navy),
		_ring(1.31, 0.186, 0.184, "Head", navy),
		_ring(1.327, 0.14, 0.139, "Head", navy),
		_ring(1.335, 0.07, 0.07, "Head", navy),
	]
	g.lathe(beret, 14, true, false, 0.0, bz, func(i: int) -> float: return 0.0 if i < 1 else 1.0)
	g.line = 0.5
	g.torus(Vector3(0, 1.238, bz), 0.168, 0.011, GOLD, 14, 3)
	g.ellipsoid(Vector3(0, 1.245, bz - 0.172), Vector3(0.022, 0.026, 0.012), GOLD, 8, 4)
	g.line = 0.0
	g.ellipsoid(Vector3(0, 1.245, bz - 0.184), Vector3(0.011, 0.013, 0.006), Color("4fc3f7"), 6, 3)
	# 깃털(Plume): 베레모 꼭대기 앞에서 뒤로 휘는 작은 붉은 깃
	var plume_base := Vector3(0.03, 1.325, bz - 0.02)
	g.add_bone("Plume", "Head", plume_base)
	g.use("Plume")
	g.measure = false
	g.line = 0.8
	var feather: Array = []
	for p: Vector3 in [Vector3(0, -0.015, 0), Vector3(0.008, 0.04, 0.015), Vector3(0.018, 0.08, 0.05), Vector3(0.028, 0.095, 0.095)]:
		feather.append(plume_base + p)
	g.spline_tube(feather, [0.016, 0.026, 0.02, 0.0], CREST, 8, true, true, Vector3.RIGHT, 1.0, 0.55)
	g.measure = true
	g.use("Head")
	g.line = 1.0
