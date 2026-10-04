class_name ImpBuilder
extends RefCounted
## 뿔이(작은 마룡왕, 주인공)의 메시·골격 정의. level = 성 레벨 1~4. 컨셉 시트 2번(docs/design/concept)을 따른다.
## 흑자색 용의 몸(서양배꼴 짧은 몸통·짧고 굵은 팔다리), 밝은 자색 배 비늘판, 어깨·등·뒤통수의 짙은 비늘, 회색 큰 뿔(옆·뒤로 뻗다가
## 위로 말리고 마디 띠가 있다), 두개골 꼭대기에 얹힌 금 왕관(Lv.1 3톱니 → Lv.4 높은 5톱니)과 붉은 보석, 노란 아몬드 눈에 납작한 세로 렌즈 동공,
## 어깨뼈에서 위·바깥으로 펼쳐지는 박쥐 날개(가운데 띠가 밝은 붉은 막, 금 발톱), 가시 돋친 꼬리, 세 발톱 손발, 모든 레벨에 금 허리띠·붉은 앞치마·가슴 보석.
## Lv.3 부터 등 전체를 덮는 한 장의 붉은 망토(어깨는 좁고 단은 넓은 물결 단, 꼬리는 털 고리를 두른 구멍으로 빠져나온다, 아랫단·윗단 흰 털).
## 지팡이는 없고 오른손 가운데 발톱 끝이 def.tip(가리키는 손).

# 색(컨셉 시트에서 눈대중으로 읽음)
const BODY := Color("45324e")
const BODY_DEEP := Color("2e2034")
const SCALE := Color("33243b")
const BELLY := Color("6a5572")
const HORN := Color("d6cfd3")
const HORN_DEEP := Color("c3bac0")
const CLAW := Color("d9d3d6")
const GOLD := Color("e3b24a")
const GOLD_DEEP := Color("b8852a")
const GEM := Color("d8303a")
const GEM_DEEP := Color("8c1620")
const CAPE := Color("b3202c")
const CAPE_IN := Color("5a1018")
const FUR := Color("f3ece4")
const WING := Color("7a2634")
const WING_MID := Color("9c3443")
const EYE := Color("f9cf3c")
const EYE_RIM := Color("130c17")
const PUPIL := Color("0f0b0e")
const LIP := Color("1c1219")
const MOUTH_IN := Color("6b1622")
const TONGUE := Color("b8323c")
const BLUSH := Color("66405c")

# 꼬리 중심선(골반 뼈 공간)과 반지름: 망토의 꼬리 구멍도 같은 값으로 뚫는다
const TAIL_PTS: Array = [Vector3(0, 0.245, 0.06), Vector3(0, 0.205, 0.17), Vector3(0, 0.19, 0.28), Vector3(0, 0.2, 0.38), Vector3(0, 0.245, 0.46), Vector3(0, 0.32, 0.505)]
const TAIL_R: Array = [0.076, 0.066, 0.052, 0.038, 0.024, 0.0]


## 성장 단계: Lv.1 작은 왕자(작은 뿔·3톱니 왕관·작은 날개) → Lv.2 금 허리띠·가슴 보석 → Lv.3 붉은 털 망토·금 어깨 → Lv.4 높은 왕관·큰 망토·금 가슴판
static func build(lv: int) -> Dictionary:
	var P := {
		ankle = 0.055, knee = 0.125, hip = 0.215, hip_x = 0.09, pelvis = 0.235, spine = 0.285,
		shoulder = 0.455, shoulder_x = 0.18, elbow = 0.375, wrist = 0.305, neck = 0.515, head = 0.555,
		arm_r = 0.046, leg_r = 0.062, foot_len = 0.17,
	}
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	_torso(g, P, lv)
	_limbs(g, P)
	_tail(g, lv)
	_wings_and_cape(g, P, lv)
	var hc := Vector3(0, 0.71, -0.01)
	var hr := Vector3(0.21, 0.175, 0.19)
	_head(g, hc, hr, lv)
	var def := g.build(CharacterRig.character_material())
	# 가리키는 손: 오른손 가운데 발톱 끝(_limbs 의 손가락 식과 같은 값)
	var ar: float = P.arm_r
	def.tip = Vector3(float(P.shoulder_x), float(P.wrist) - ar * 0.55 - ar * 0.2 - ar * 1.5, -ar * 1.3 - ar * 0.55 - ar * 0.6)
	def.H = 0.8
	def.es = 0.05
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


# ------------------------------------------------------------------ 몸통·장식

## 비늘 한 장: 표면 점 c 에 법선 nrm 방향으로 반쯤 묻힌 짙은 둥근 판(멀리서는 어두운 점무늬, 가까이서는 비늘)
static func _scale(g: CharGeo, c: Vector3, nrm: Vector3, r: float) -> void:
	var ny := nrm.normalized()
	var nx := ny.cross(Vector3.UP)
	if nx.length() < 0.01:
		nx = Vector3.RIGHT
	nx = nx.normalized()
	var nz := nx.cross(ny)
	var keep := g.line
	g.line = 0.5
	g.ellipsoid(c - ny * r * 0.1, Vector3(r, r * 0.4, r * 0.85), SCALE, 6, 2, Basis(nx, ny, nz))
	g.line = keep


## 2차원 점들을 k 배(작은 레벨의 장식 축소)
static func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p * k)
	return out


## 몸통(아래가 넓은 둥근 배 + 가슴 타원 = 서양배꼴) + 배 비늘판 3장 + 목 + 엉덩이. 모든 레벨에 허리띠·버클·앞치마·가슴 보석(Lv.1 은 작게), Lv.4 금 가슴판.
## Lv.1~2 는 등에 비늘 무늬(Lv.3+ 는 망토가 가린다)
static func _torso(g: CharGeo, P: Dictionary, lv: int) -> void:
	g.use("Spine")
	g.rounded_box(Vector3(0, 0.345, 0.0), Vector3(0.19, 0.125, 0.15), BODY, 0.8, 14, 8)
	g.ellipsoid(Vector3(0, 0.44, 0.0), Vector3(0.175, 0.11, 0.138), BODY, 12, 6)
	# 배 비늘판: 세로로 겹친 밝은 자색 타원 3장(겹친 자리의 외곽선이 비늘 줄이 된다)
	var plates := [Vector3(0, 0.455, -0.085), Vector3(0, 0.39, -0.098), Vector3(0, 0.325, -0.095)]
	var prad := [Vector3(0.105, 0.042, 0.07), Vector3(0.12, 0.047, 0.075), Vector3(0.11, 0.042, 0.07)]
	for i in 3:
		var pc: Vector3 = plates[i]
		var pr: Vector3 = prad[i]
		g.ellipsoid(pc, pr, BELLY, 8, 4)
	if lv <= 2:
		# 등 비늘: 척추 양옆으로 어긋나게 늘어선 짙은 판
		for sc: Array in [[0.0, 0.47, 0.133], [-0.065, 0.44, 0.128], [0.065, 0.44, 0.128], [0.0, 0.41, 0.137],
				[-0.065, 0.38, 0.143], [0.065, 0.38, 0.143], [0.0, 0.35, 0.15]]:
			var sx: float = sc[0]
			_scale(g, Vector3(sx, sc[1], sc[2]), Vector3(sx * 1.5, 0.15, 1.0), 0.026)
	g.use("Neck")
	g.tube(Vector3(0, 0.5, -0.01), Vector3(0, 0.59, -0.01), 0.072, 0.066, BODY, 8, false)
	# 엉덩이(꼬리 뿌리를 받친다)
	g.use("Pelvis")
	g.ellipsoid(Vector3(0, 0.245, 0.01), Vector3(0.17, 0.085, 0.135), BODY, 10, 4)
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	# 금 허리띠(납작한 띠) + 버클(금 방패꼴 + 붉은 보석). Lv.1 은 작은 띠·작은 앞치마(컨셉 성장표의 작은 왕자)
	var ks := 0.78 if lv == 1 else 1.0
	g.use("Spine")
	g.tube(Vector3(0, 0.276 + 0.019 * ks, 0), Vector3(0, 0.276 - 0.018 * ks, 0), 0.165, 0.17, GOLD, 14, false, 1.0, 0.88)
	var bz := -0.17 * 0.88 - 0.006
	g.polygon(_scaled(PackedVector2Array([Vector2(-0.036, 0.025), Vector2(0.036, 0.025), Vector2(0.03, -0.02), Vector2(0, -0.034), Vector2(-0.03, -0.02)]), ks),
		Vector3(0, 0.277, bz), fb, 0.012, GOLD, GOLD_DEEP)
	g.polygon(_scaled(PackedVector2Array([Vector2(0, 0.016), Vector2(0.014, 0), Vector2(0, -0.016), Vector2(-0.014, 0)]), ks),
		Vector3(0, 0.275, bz - 0.009), fb, 0.008, GEM, GEM_DEEP)
	# 앞치마(붉은 천 + 금 테 + 금 왕관 문장): 골반 뼈에 붙어 다리 사이 앞에 늘어진다
	g.use("Pelvis")
	var ao := Vector3(0, 0.262, -0.148)
	var apron := _scaled(PackedVector2Array([Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.085, -0.09), Vector2(0, -0.15), Vector2(-0.085, -0.09)]), ks)
	g.polygon(apron, ao + Vector3(0, 0, 0.004), fb, 0.01, GOLD, GOLD_DEEP)
	var inner := PackedVector2Array()
	for p: Vector2 in apron:
		inner.append(p * 0.86 + Vector2(0, -0.006))
	g.polygon(inner, ao - Vector3(0, 0, 0.004), fb, 0.008, CAPE, CAPE_IN)
	g.polygon(_scaled(PackedVector2Array([Vector2(-0.03, -0.1), Vector2(-0.03, -0.065), Vector2(-0.015, -0.082), Vector2(0, -0.055),
		Vector2(0.015, -0.082), Vector2(0.03, -0.065), Vector2(0.03, -0.1)]), ks), ao - Vector3(0, 0, 0.012), fb, 0.006, GOLD, GOLD_DEEP)
	# 가슴 장식
	g.use("Spine")
	var cz := CharGeo.surf_z(plates[0], prad[0], 0.0, 0.45)
	if lv == 4:
		# 금 가슴판(위 배 비늘판을 덮는 금 띠) + 어깨로 이어지는 금 줄
		var gc := Vector3(0, 0.458, -0.082)
		var gr := Vector3(0.13, 0.052, 0.08)
		g.ellipsoid(gc, gr, GOLD, 10, 4)
		cz = CharGeo.surf_z(gc, gr, 0.0, 0.45)
		for side: float in [-1.0, 1.0]:
			g.tube(Vector3(0.05 * side, 0.48, -0.125), Vector3(0.16 * side, 0.5, -0.03), 0.014, 0.014, GOLD, 6, true)
	# 가슴 보석(금 테 마름모 + 붉은 보석): Lv.1 작게, Lv.4 크게
	var gs: float = [0.0, 0.7, 1.0, 1.0, 1.25][lv]
	g.polygon(PackedVector2Array([Vector2(0, 0.046 * gs), Vector2(0.036 * gs, 0), Vector2(0, -0.046 * gs), Vector2(-0.036 * gs, 0)]),
		Vector3(0, 0.45, cz - 0.004), fb, 0.012, GOLD, GOLD_DEEP)
	g.polygon(PackedVector2Array([Vector2(0, 0.028 * gs), Vector2(0.02 * gs, 0), Vector2(0, -0.028 * gs), Vector2(-0.02 * gs, 0)]),
		Vector3(0, 0.45, cz - 0.014), fb, 0.01, GEM, GEM_DEEP)
	# 어깨 장식: Lv.2 작은 금 징, Lv.3+ 금 어깨판(둥근 덮개 + 붉은 점)
	if lv >= 2:
		for side: float in [-1.0, 1.0]:
			g.use("ArmL" if side < 0.0 else "ArmR")
			var sc := Vector3(float(P.shoulder_x) * side, float(P.shoulder) + 0.015, 0)
			if lv == 2:
				g.sphere(sc + Vector3(0.012 * side, 0.03, 0), 0.026, GOLD, 7, 4)
			else:
				var ps := 1.0 if lv == 3 else 1.15
				g.ellipsoid(sc + Vector3(0.012 * side, 0.012, 0), Vector3(0.07, 0.052, 0.07) * ps, GOLD, 8, 4, Basis.IDENTITY, PI * 0.58, PI * 0.58)
				g.sphere(sc + Vector3(0.014 * side, 0.056 * ps, 0), 0.016 * ps, GEM, 5, 3)


## 팔(둥근 어깨·두툼해지는 아래팔·세 발톱 손, 손은 허리띠 높이에서 끝난다)과 다리(짧고 굵은 허벅지가 정강이로 이어지고 큰 세 발톱 발) + 어깨·허벅지 비늘
static func _limbs(g: CharGeo, P: Dictionary) -> void:
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	var ar: float = P.arm_r
	var lr: float = P.leg_r
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Arm" + sfx)
		g.sphere(Vector3(x, P.shoulder, 0), ar * 1.25, BODY, 8, 4)
		g.tube(Vector3(x, P.shoulder, 0), Vector3(x, P.elbow, 0), ar * 1.05, ar * 0.95, BODY, 8, false)
		_scale(g, Vector3(x + side * ar * 0.95, float(P.shoulder) + ar * 0.55, -ar * 0.3), Vector3(side * 0.8, 0.6, -0.3), 0.022)
		_scale(g, Vector3(x + side * ar * 1.05, float(P.shoulder) - ar * 0.35, ar * 0.35), Vector3(side * 0.9, 0.05, 0.4), 0.019)
		g.use("Forearm" + sfx)
		g.sphere(Vector3(x, P.elbow, 0), ar * 0.98, BODY, 7, 3)
		g.tube(Vector3(x, P.elbow, 0), Vector3(x, P.wrist, 0), ar * 0.96, ar * 1.15, BODY, 8, false)
		g.use("Hand" + sfx)
		var hcen := Vector3(x, float(P.wrist) - ar * 0.55, -ar * 0.25)
		g.ellipsoid(hcen, Vector3(ar * 1.35, ar * 1.05, ar * 1.3), BODY, 8, 4)
		# 세 손가락 + 밝은 회색 발톱(앞·아래로 굽는다)
		for k in 3:
			var u := float(k) - 1.0
			var fx := x + u * ar * 0.8
			var top := Vector3(fx, hcen.y - ar * 0.2, -ar * 1.1 - (0.2 if k == 1 else 0.0) * ar)
			var mid := top + Vector3(u * ar * 0.15, -ar * 0.75, -ar * 0.55)
			g.tube(top, mid, ar * 0.36, ar * 0.32, BODY, 5, true)
			g.tube(mid, mid + Vector3(u * ar * 0.1, -ar * 0.75, -ar * 0.6), ar * 0.3, 0.0, CLAW, 5, true)
		var lx := hx * side
		g.use("Leg" + sfx)
		g.sphere(Vector3(lx, P.hip, 0), lr * 1.15, BODY, 7, 3)
		g.tube(Vector3(lx, P.hip, 0), Vector3(lx, P.knee, 0), lr * 1.18, lr * 1.02, BODY, 8, false)
		_scale(g, Vector3(lx + side * lr * 1.05, float(P.hip) - 0.03, -lr * 0.35), Vector3(side, 0.15, -0.35), 0.022)
		g.use("Shin" + sfx)
		g.sphere(Vector3(lx, P.knee, 0), lr * 1.02, BODY, 7, 3)
		g.tube(Vector3(lx, P.knee, 0), Vector3(lx, P.ankle, 0), lr * 1.0, lr * 0.95, BODY, 8, false)
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		var fh: float = P.ankle
		g.ellipsoid(Vector3(lx, fh * 0.85, -fl * 0.2), Vector3(lr * 1.4, fh * 0.85, fl * 0.52), BODY, 9, 4)
		for k in 3:
			var u := float(k) - 1.0
			var tb := Vector3(lx + u * lr * 0.85, fh * 0.6, -fl * 0.55)
			g.tube(tb, tb + Vector3(u * lr * 0.2, -fh * 0.35, -fl * 0.36 - (0.08 if k == 1 else 0.0) * fl), lr * 0.38, 0.0, CLAW, 5, true)


## 두툼한 용 꼬리(골반 뒤 +Z, 끝이 위로 말린다) + 가시 3개(Lv.4 는 금 가시).
## 가시는 2번 마디(z 0.28)부터: 망토(Lv.3+)가 꼬리를 지나는 자리(z ≈ 0.2)보다 뒤라서 천을 뚫지 않는다
static func _tail(g: CharGeo, lv: int) -> void:
	g.use("Pelvis")
	g.spline_tube(TAIL_PTS, TAIL_R, BODY, 8, true, true, Vector3.RIGHT, 1.0, 0.9)
	var spike_c := GOLD if lv == 4 else HORN
	for i in [2, 3, 4]:
		var p: Vector3 = TAIL_PTS[i]
		var r: float = TAIL_R[i]
		var L := 0.08 - 0.017 * float(i - 2)
		g.horn(p + Vector3(0, r * 0.7, 0), Vector3(0, 0.85, 0.35), Vector3(0, 0.1, 0.5), L, maxf(r * 0.5, 0.015), spike_c, 3, 5)


## 점 p 에서 가장 가까운 꼬리 중심선 점과 그 자리의 꼬리 반지름, 그 마디의 진행 방향
static func _tail_nearest(p: Vector3) -> Dictionary:
	var best := Vector3.ZERO
	var best_r := 0.0
	var best_d := INF
	var best_t := Vector3.BACK
	for i in TAIL_PTS.size() - 1:
		var a: Vector3 = TAIL_PTS[i]
		var b: Vector3 = TAIL_PTS[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t
		var r: float = lerpf(float(TAIL_R[i]), float(TAIL_R[i + 1]), t)
		var d := p.distance_to(q) - r
		if d < best_d:
			best_d = d
			best = q
			best_r = r
			best_t = ab.normalized()
	return {p = best, r = best_r, d = best_d, tan = best_t}


# ------------------------------------------------------------------ 날개·망토

## 세 점을 잇는 얇은 삼각 막(날개 막과 몸 사이 틈 메우기)
static func _patch(g: CharGeo, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var ex := (b - a).normalized()
	var nn := (b - a).cross(c - a).normalized()
	var ey := nn.cross(ex)
	var pts := PackedVector2Array([Vector2.ZERO, Vector2((b - a).dot(ex), (b - a).dot(ey)), Vector2((c - a).dot(ex), (c - a).dot(ey))])
	var keep := g.line
	g.line = keep * 0.6
	g.polygon(pts, a, Basis(ex, ey, nn), 0.006, col)
	g.line = keep


## 박쥐 날개(CharGeo.wing 을 뿔이용으로 고친 것): 뼈대 + 양면 막. 막은 뿌리에서 가장자리까지 세 띠(zones = [[시작 비율, 끝 비율, 색], ...])로
## 나뉘어 가운데 띠를 밝은 색으로 칠할 수 있다. root = 손목(막의 꼭짓점), tips = 손가락 끝(위→아래), 손가락 사이 가장자리는 scallop 만큼 패인다.
static func _wing(g: CharGeo, root: Vector3, tips: Array, bone_r: float, zones: Array, scallop: float, thickness: float, segs: int) -> void:
	var nt := tips.size()
	for t: Vector3 in tips:
		g.tube(root, t, bone_r, bone_r * 0.45, BODY, 5, true)
	var hint := ((tips[0] as Vector3 - root).cross(tips[nt - 1] as Vector3 - root)).normalized()
	var keep := g.line
	g.line = keep * 0.6
	for s: float in [1.0, -1.0]:
		var nn := hint * s
		var off := nn * thickness
		for i in nt - 1:
			var a: Vector3 = tips[i]
			var b: Vector3 = tips[i + 1]
			var edge: Array = []
			for k in segs + 1:
				var t := float(k) / float(segs)
				edge.append(a.lerp(b, t).lerp(root, scallop * sin(t * PI)))
			for z: Array in zones:
				var f0: float = z[0]
				var f1: float = z[1]
				var col: Color = z[2]
				var b0 := g.v.size()
				if f0 <= 0.0:
					# 뿌리 부채꼴
					g._vert(root + off, nn, col)
					for k in segs + 1:
						g._vert(root.lerp(edge[k], f1) + off, nn, col)
					for k in segs:
						g.tri(b0, b0 + 1 + k, b0 + 2 + k)
				else:
					for k in segs + 1:
						g._vert(root.lerp(edge[k], f0) + off, nn, col)
					for k in segs + 1:
						g._vert(root.lerp(edge[k], f1) + off, nn, col)
					for k in segs:
						var i0 := b0 + k
						var i1 := i0 + segs + 1
						g.tri(i0, i1, i0 + 1)
						g.tri(i0 + 1, i1, i1 + 1)
	g.line = keep


## 등 전체를 덮는 한 장의 망토(양면, 안팎 다른 색). top 가운데 윗점에서 length 만큼 내려오며 폭 w_top → w_bot(어깨는 좁고 단은 넓다),
## 아래로 갈수록 뒤(+Z)로 drape 만큼 흘러내리고 양옆은 몸을 감싸듯 앞(-Z)으로 wrap 만큼 굽는다. hem_wave 만큼 단이 물결친다.
## 꼬리가 지나는 자리는 격자점을 꼬리 표면(+margin)까지 밀어내고 완전히 꼬리 안에 든 칸은 비워 꼬리 모양의 구멍을 낸다.
## 돌려주는 값 = [윗단 점들, 아랫단 점들, 구멍 {p = 꼬리 중심, r = 꼬리 반지름, tan = 꼬리 방향}]
static func _cape_sheet(g: CharGeo, top: Vector3, length: float, w_top: float, w_bot: float, drape: float, wrap: float, hem_wave: float,
		margin: float, cols: int, rows: int, thickness: float) -> Array:
	var P: Array = []
	var inside: Array = []
	var hole := {p = Vector3.ZERO, r = 0.0, d = INF, tan = Vector3.BACK}
	for i in rows + 1:
		var t := float(i) / float(rows)
		var w := lerpf(w_top, w_bot, t)
		var row: Array = []
		var irow: Array = []
		for j in cols + 1:
			var u := float(j) / float(cols) - 0.5
			var y := top.y - length * t - hem_wave * t * t * (0.5 + 0.5 * cos(u * TAU * 1.5))
			var p := Vector3(top.x + u * w, y, top.z + drape * t * t - wrap * (u * u * 4.0) * (0.3 + 0.7 * t))
			var q := _tail_nearest(p)
			var qp: Vector3 = q.p
			var need: float = float(q.r) + margin
			var d := p - qp
			var hit := d.length() < need
			if hit:
				if d.length() < 0.0001:
					d = Vector3.UP
				p = qp + d.normalized() * need
				if j * 2 == cols and float(q.d) < float(hole.d):
					hole = q
			row.append(p)
			irow.append(hit)
		P.append(row)
		inside.append(irow)
	var keep := g.line
	g.line = keep * 0.8
	for sd: float in [1.0, -1.0]:
		var col := CAPE if sd > 0.0 else CAPE_IN
		var b0 := g.v.size()
		for i in rows + 1:
			for j in cols + 1:
				var p: Vector3 = P[i][j]
				var du: Vector3 = (P[i][mini(j + 1, cols)] as Vector3) - (P[i][maxi(j - 1, 0)] as Vector3)
				var dt: Vector3 = (P[mini(i + 1, rows)][j] as Vector3) - (P[maxi(i - 1, 0)][j] as Vector3)
				var nn := du.cross(dt).normalized()
				if nn.z < 0.0:
					nn = -nn
				nn *= sd
				g._vert(p + nn * thickness, nn, col)
		for i in rows:
			for j in cols:
				if inside[i][j] and inside[i][j + 1] and inside[i + 1][j] and inside[i + 1][j + 1]:
					continue
				var a := b0 + i * (cols + 1) + j
				var d := a + cols + 1
				g.tri(a, a + 1, d)
				g.tri(a + 1, d + 1, d)
	g.line = keep
	return [P[0], P[rows], hole]


## 털 고리(목 깃): 도넛인데 단면 반지름이 둘레를 따라 울퉁불퉁해 털 뭉치처럼 보인다. 축 = basis 의 +Y
static func _fur_ring(g: CharGeo, ce: Vector3, R: float, r: float, segs: int, rings: int, basis: Basis) -> void:
	var base := g.v.size()
	for i in segs + 1:
		var a := TAU * float(i) / float(segs)
		var cdir := Vector3(cos(a), 0, sin(a))
		var rr := r * (1.0 + 0.16 * cos(a * 8.0))
		for j in rings + 1:
			var b := TAU * float(j) / float(rings)
			var nn := cdir * cos(b) + Vector3.UP * sin(b)
			g._vert(ce + basis * (cdir * R + nn * rr), basis * nn, FUR)
	for i in segs:
		for j in rings:
			var i0 := base + i * (rings + 1) + j
			var i1 := i0 + rings + 1
			g.tri(i0, i1, i0 + 1)
			g.tri(i0 + 1, i1, i1 + 1)


## 날개(박쥐 날개: 어깨뼈 뿌리 → 위·바깥으로 뻗는 팔뼈 → 손목에서 네 손가락 + 붉은 막(가운데 띠가 밝다), 손목 엄지·손가락 끝은 금 발톱)와 망토.
## 둘 다 Cape 뼈(2차 움직임)에 붙는다. 날개는 어깨 위로 펼쳐져 정면에서 머리 양옆에 보인다. 너비는 Lv.1 몸 폭의 ~0.9배 → Lv.4 ~1.4배.
## 망토는 Lv.3 부터 등 전체를 덮는 한 장(어깨는 좁고 단은 넓은 물결 단, 아랫단·윗단 털, 어깨 털 깃, 꼬리 구멍 둘레 털 고리), Lv.4 는 더 크다.
static func _wings_and_cape(g: CharGeo, P: Dictionary, lv: int) -> void:
	g.add_bone("Cape", "Spine", Vector3(0, 0.5, 0.12))
	g.use("Cape")
	g.measure = false
	var s: float = [0.0, 0.52, 0.7, 0.92, 1.05][lv]
	var br := 0.011 + 0.007 * s
	var zones := [[0.0, 0.42, WING], [0.42, 0.78, WING_MID], [0.78, 1.0, WING]]
	for side: float in [-1.0, 1.0]:
		var root := Vector3(0.1 * side, 0.5, 0.11)
		var w := root + Vector3(0.08 * side, 0.16, 0.0) * s
		var t1 := w + Vector3(0.05 * side, 0.19, 0.0) * s
		var t2 := w + Vector3(0.12 * side, 0.1, 0.01) * s
		var t3 := w + Vector3(0.13 * side, -0.05, 0.03) * s
		var t4 := w + Vector3(0.08 * side, -0.17, 0.05) * s
		var b := root + Vector3(0.0, -0.14, 0.02) * s
		g.sphere(root, br * 1.3, BODY, 6, 3)
		g.tube(root, w, br * 1.1, br, BODY, 6, false)
		g.sphere(w, br * 1.15, BODY, 6, 3)
		_wing(g, w, [t1, t2, t3, t4], br * 0.8, zones, 0.26, 0.005, 4)
		_patch(g, w, t4, b, WING_MID)
		g.tube(b, w, br * 0.75, br * 0.6, BODY, 5, true)
		# 금 발톱: 손목 엄지 + 손가락 끝
		var thumb_d := Vector3(0.3 * side, 1.0, -0.1).normalized()
		g.tube(w, w + thumb_d * (0.03 + 0.025 * s), br * 0.9, 0.0, GOLD, 5, true)
		for t: Vector3 in [t1, t2, t3, t4]:
			var d := (t - w).normalized()
			g.tube(t - d * 0.008, t + d * (0.03 * s + 0.01), br * 0.85, 0.0, GOLD, 4, true)
	if lv >= 3:
		var big := lv == 4
		var top := Vector3(0, 0.535, 0.15)
		var length := 0.44 if big else 0.43
		var w_top := 0.3 if big else 0.27
		var w_bot := 0.68 if big else 0.6
		var drape := 0.13 if big else 0.1
		var wrap := 0.1 if big else 0.085
		var margin := 0.015
		var edges := _cape_sheet(g, top, length, w_top, w_bot, drape, wrap, 0.03, margin, 8, 7, 0.006)
		# 털 단: 아랫단 전체를 따라가는 둥근 흰 관(물결 단을 따라간다) + 윗단(깃 뒤쪽)에도 한 줄
		var fur_r := 0.034 if big else 0.028
		var hem: Array = []
		var hem_r: Array = []
		for p: Vector3 in edges[1]:
			hem.append(p + Vector3(0, 0.004, -0.004))
			hem_r.append(fur_r)
		g.spline_tube(hem, hem_r, FUR, 6, true, true)
		var collar: Array = []
		var collar_r: Array = []
		var top_row: Array = edges[0]
		for j in range(0, top_row.size(), 2):
			var p: Vector3 = top_row[j]
			collar.append(p + Vector3(0, 0.012, 0.0))
			collar_r.append(fur_r * 0.95)
		g.spline_tube(collar, collar_r, FUR, 4, true, true)
		# 꼬리 구멍 둘레 털 고리: 꼬리 축을 따라 도넛을 둘러 천과 꼬리 사이 이음새를 가린다
		var hole: Dictionary = edges[2]
		if float(hole.r) > 0.0:
			var ty: Vector3 = (hole.tan as Vector3).normalized()
			var tz := Vector3.RIGHT.cross(ty).normalized()
			var tx := ty.cross(tz)
			g.torus(hole.p, float(hole.r) + margin + 0.003, 0.014, FUR, 10, 4, Basis(tx, ty, tz))
		# 털 깃: 어깨판 위에 얹히는 두툼한 흰 털 고리(앞이 조금 낮다). 몸통 뼈
		g.use("Spine")
		var cr := 0.038 if big else 0.032
		_fur_ring(g, Vector3(0, float(P.neck) + 0.01, 0.015), 0.16 if big else 0.15, cr, 14, 5, Basis(Vector3.RIGHT, -0.22))
	g.measure = true


# ------------------------------------------------------------------ 머리

## 머리: 넓은 타원 + 작은 주둥이, 눈(노란 공막·세로 동공·짙은 테), 콧구멍, 눈 위 밝은 비늘 무늬, 뒤통수 비늘, 볼 홍조, 귀, 뿔, 왕관
static func _head(g: CharGeo, hc: Vector3, hr: Vector3, lv: int) -> void:
	g.use("Head")
	g.ellipsoid(hc, hr, BODY, 20, 11)
	var mc := Vector3(0, hc.y - 0.058, -0.135)
	var mr := Vector3(0.12, 0.072, 0.085)
	g.ellipsoid(mc, mr, BODY, 12, 6)
	var es := 0.056
	var ey := hc.y + 0.03
	_face(g, {hc = hc, hr = hr, mc = mc, mr = mr, es = es, eye_y = ey, eye_dx = 0.092, mouth_y = hc.y - 0.078, mouth_w = 0.085,
		tilt = 0.2})
	g.use("Head")
	# 콧구멍 두 개
	for side: float in [-1.0, 1.0]:
		var nx := 0.028 * side
		var ny := mc.y + 0.018
		g.sphere(Vector3(nx, ny, CharGeo.surf_z(mc, mr, nx, ny) - 0.002), 0.0075, BODY_DEEP, 5, 3)
	# 눈 위 밝은 비늘 무늬(두 줄)
	g.line = 0.3
	for side: float in [-1.0, 1.0]:
		for k in 2:
			var mx := (0.07 + 0.045 * float(k)) * side
			var my := hc.y + 0.148 - 0.013 * float(k)
			var mz := CharGeo.surf_z(hc, hr, mx, my) - 0.003
			g.ellipsoid(Vector3(mx, my, mz), Vector3(0.022, 0.0075, 0.012), HORN, 6, 3, Basis(Vector3.BACK, side * 0.45))
	# 볼 홍조(옅은 분홍 타원, 외곽선 없음)
	g.line = 0.0
	for side: float in [-1.0, 1.0]:
		var bx := 0.15 * side
		var by := hc.y - 0.02
		g.ellipsoid(Vector3(bx, by, CharGeo.surf_z(hc, hr, bx, by) + 0.004), Vector3(0.034, 0.018, 0.014), BLUSH, 6, 3, Basis(Vector3.BACK, side * 0.25))
	g.line = 1.0
	# 뒤통수 비늘 세 장
	for sc: Array in [[0.0, 0.07], [-0.075, 0.025], [0.075, 0.025]]:
		var sx: float = sc[0]
		var sy: float = hc.y + float(sc[1])
		var q := 1.0 - pow(sx / hr.x, 2.0) - pow((sy - hc.y) / hr.y, 2.0)
		var sz := hc.z + hr.z * sqrt(maxf(q, 0.04))
		_scale(g, Vector3(sx, sy, sz), Vector3(sx * 2.0, (sy - hc.y) * 2.0, hr.z), 0.03)
	# 작은 뾰족 귀(옆·뒤·위로)
	for side: float in [-1.0, 1.0]:
		var eb := hc + Vector3(0.185 * side, -0.01, 0.05)
		g.horn(eb, Vector3(1.0 * side, 0.3, 0.45), Vector3(0.0, 0.5, 0.4), 0.085, 0.034, BODY, 4, 6)
	# 뿔: 머리 옆 위에서 바깥·뒤로 크게 휘어 나간 뒤 위로 말리는 매끈한 회색 뿔(마디 띠, 좌우 대칭, 레벨마다 커진다).
	# 뿌리를 왕관 바깥쪽으로 벌리고(±x) 뒤로 쓸었다가 올려 옆·3/4 시점에서 C 꼴 휨이 보인다
	g.measure = false
	var hs: float = [0.0, 0.5, 0.66, 0.84, 1.0][lv]
	var hr0: float = [0.0, 0.036, 0.046, 0.054, 0.064][lv]
	for side: float in [-1.0, 1.0]:
		var p0 := hc + Vector3(0.16 * side, 0.072, 0.03)
		var p1 := p0 + Vector3(0.2 * side, 0.0, 0.14) * hs
		var p2 := p0 + Vector3(0.26 * side, 0.17, 0.2) * hs
		var p3 := p0 + Vector3(0.17 * side, 0.36, 0.06) * hs
		_horn_curve(g, p0, p1, p2, p3, hr0, 9)
	_crown(g, hc, hr, lv)
	g.measure = true


## 3차 베지어 곡선을 따라가는 뿔: 뿌리는 조금 어둡고 끝으로 갈수록 밝은 회색, 가운데가 살짝 두툼하고 마디마다 굵기가 바뀌어 띠가 진다
static func _horn_curve(g: CharGeo, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, r0: float, segs: int) -> void:
	var n := 12
	var pts: Array = []
	var radii: Array = []
	for i in n + 1:
		var t := float(i) / float(n)
		var it := 1.0 - t
		pts.append(p0 * (it * it * it) + p1 * (3.0 * it * it * t) + p2 * (3.0 * it * t * t) + p3 * (t * t * t))
		var ridge := 1.0
		if i >= 2 and i <= 9:
			ridge = 1.09 if i % 2 == 0 else 0.95
		radii.append(r0 * pow(it, 0.7) * (1.0 + 0.2 * sin(t * PI)) * ridge)
	g.spline_tube(pts.slice(0, 5), radii.slice(0, 5), HORN_DEEP, segs, true, false)
	g.spline_tube(pts.slice(4), radii.slice(4), HORN, segs, false, true)


## 왕관: 두개골 꼭대기(머리 중심과 같은 z, 뿔 사이)에 얹힌 금 띠(머리 단면에 맞춘 타원, 아래 테 + 윗면 덮개로 머리가 뚫고 나오지 않는다)
## + 바깥으로 살짝 벌어진 뾰족 톱니 + 앞 톱니 밑의 붉은 보석. 앞 톱니가 가장 높아 이마 위에 선다.
## Lv.1 작은 3톱니 왕관 → Lv.3~4 머리 폭의 절반쯤 되는 높은 5톱니 왕관. 뒤 톱니는 낮고 뒤통수 밖으로 나가지 않는다.
static func _crown(g: CharGeo, hc: Vector3, hr: Vector3, lv: int) -> void:
	g.use("Head")
	var lat: float = [0.0, 0.3, 0.4, 0.5, 0.53][lv]
	var cy := hc.y + hr.y * cos(lat)
	var R := hr.x * sin(lat) + 0.003
	var fz := hr.z / hr.x
	var band_h: float = [0.0, 0.018, 0.026, 0.036, 0.05][lv]
	var points: int = [0, 3, 5, 5, 5][lv]
	var ph: float = [0.0, 0.05, 0.065, 0.1, 0.15][lv]
	var pw: float = [0.0, 0.016, 0.02, 0.03, 0.04][lv]
	var gem_r: float = [0.0, 0.013, 0.016, 0.022, 0.03][lv]
	var c := Vector3(hc.x, cy, hc.z - 0.01)
	var sc := Basis.from_scale(Vector3(1, 1, fz))
	g.measure = true
	g.tube(c - Vector3(0, 0.014, 0), c + Vector3(0, band_h, 0), R, R + 0.006, GOLD, 14, false, 1.0, fz)
	g.torus(c - Vector3(0, 0.004, 0), R, 0.008, GOLD_DEEP, 14, 4, sc)
	g.ellipsoid(c + Vector3(0, band_h, 0), Vector3(R + 0.006, 0.012, (R + 0.006) * fz), GOLD, 12, 3)
	g.measure = false
	var rr := R + 0.006
	var lean := 0.2
	for k in points:
		var a := TAU * float(k) / float(points)
		var ex := Vector3(cos(a), 0, sin(a))
		var ez := Vector3(sin(a), 0, -cos(a))
		var o := c + Vector3(ez.x * rr, band_h - 0.002, ez.z * rr * fz)
		# 5톱니: 앞 톱니가 가장 높고 뒤로 갈수록 낮다(옆선이 살짝 오목)
		var h := ph
		if points == 5:
			h = ph * (1.0 if k == 0 else (0.78 if k == 1 or k == 4 else 0.6))
		var up := (Vector3.UP + ez * lean).normalized()
		g.polygon(PackedVector2Array([Vector2(-pw, 0), Vector2(pw, 0), Vector2(pw * 0.32, h * 0.45), Vector2(0, h), Vector2(-pw * 0.32, h * 0.45)]),
			o, Basis(ex, up, ez), 0.012, GOLD, GOLD_DEEP)
	# 앞 보석(마름모, 깎인 면은 짙은 빨강): 띠 앞면(Lv.1~2) 또는 앞 톱니 밑동(Lv.3~4)에 붙는다
	var fz0 := c.z - rr * fz - 0.006
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	var gy := cy + band_h * 0.5
	var gz := fz0 - 0.007
	if lv >= 3:
		gy = cy + band_h + gem_r * 0.9
		gz = fz0 - lean * (gy - cy - band_h + 0.002) / sqrt(1.0 + lean * lean) - 0.007
	g.polygon(PackedVector2Array([Vector2(0, gem_r * 1.25), Vector2(gem_r * 0.8, 0), Vector2(0, -gem_r * 1.1), Vector2(-gem_r * 0.8, 0)]),
		Vector3(0, gy, gz), fb, 0.014, GEM, GEM_DEEP)


## 눈알 겉면에 붙는 얇은 볼록 판(동공 렌즈·반사광): 공막 타원체(ce, r, basis)의 겉면을 따라가며 lift 만큼 떠 있고 가운데가 depth 만큼 더 솟는다.
## (lx, ly) = 공막 공간의 중심, (w, h) = 반폭·반높이, taper > 1 이면 위아래가 뾰족한 렌즈꼴(1 = 타원)
static func _dome(g: CharGeo, ce: Vector3, r: Vector3, basis: Basis, lx: float, ly: float, w: float, h: float, taper: float,
		lift: float, depth: float, col: Color, segs: int) -> void:
	var base := g.v.size()
	for k in 3:
		var f := float(k) * 0.5
		var cnt := 1 if k == 0 else segs + 1
		for j in cnt:
			var a := TAU * float(j) / float(segs)
			var ca := cos(a)
			var x := lx + w * f * signf(ca) * pow(absf(ca), taper)
			var y := ly + h * f * sin(a)
			var q := 1.0 - pow(x / r.x, 2.0) - pow(y / r.y, 2.0)
			var z := -r.z * sqrt(maxf(q, 0.02)) - lift - depth * (1.0 - f * f)
			var nn := Vector3(x / (r.x * r.x), y / (r.y * r.y), z / (r.z * r.z))
			g._vert(ce + basis * Vector3(x, y, z), basis * nn, col)
	for j in segs:
		g.tri(base, base + 1 + j, base + 2 + j)
	for j in segs:
		var i0 := base + 1 + j
		var i1 := i0 + segs + 1
		g.tri(i0, i1, i0 + 1)
		g.tri(i0 + 1, i1, i1 + 1)


## 얼굴(CharGeo.face 를 뿔이용으로 고친 것): 눈은 바깥쪽이 올라간 아몬드꼴(가로가 세로보다 넓다), 노란 공막 위에 납작하게 붙은 세로 렌즈 동공과
## 위·바깥 모서리의 작은 둥근 반사광, 위쪽이 두꺼운 짙은 테(윗눈꺼풀 선). 눈썹은 안쪽 끝이 내려간 위엄 있는 눈매,
## 입은 주둥이 타원 위의 가는 선(보통: 입가가 올라간 미소 + 작은 송곳니 둘, 벌림(웃음·분노): 입꼬리가 올라간 붉은 웃는 입 + 혀 + 송곳니 둘, 아픔: 가는 물결선).
## F: hc, hr(머리), mc, mr(주둥이), es, eye_y, eye_dx, mouth_y, mouth_w, tilt(눈 기울기)
static func _face(g: CharGeo, F: Dictionary) -> void:
	var keep_line := g.line
	g.line = 0.0
	var hc: Vector3 = F.hc
	var hr: Vector3 = F.hr
	var es: float = F.es
	var ey: float = F.eye_y
	var tilt: float = F.tilt
	var ew := 1.25
	var eh := 0.88
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var ex: float = float(F.eye_dx) * side
		var ez := CharGeo.surf_z(hc, hr, ex, ey) - 0.004
		var eb := Basis(Vector3.BACK, side * tilt)
		# 감은 눈 선: 눈알 속(공막 뒤)에 숨어 있다가 눈알을 누르면(깜빡임·기절) 보인다. 눌린 눈알이 가로로 남는 자리(ey - 0.2es)를 따라 길게 긋는다
		g.use("Head")
		var lash: Array = []
		for i in 5:
			var u := float(i) / 2.0 - 1.0
			lash.append(Vector3(ex + u * es * 1.25, ey - es * (0.26 - 0.08 * u * u), ez + es * 0.15))
		g.sweep(lash, es * 0.14, EYE_RIM, 3)
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez + es * 0.3))
		g.use("Eye" + sfx)
		# 짙은 테: 공막보다 조금 크고 위로 치우쳐 위쪽 테가 두껍다(무거운 윗눈꺼풀 선)
		g.ellipsoid(Vector3(ex, ey, ez + es * 0.42) + eb * Vector3(0, es * 0.13, 0), Vector3(es * (ew + 0.1), es * (eh + 0.2), es * 0.58), EYE_RIM, 10, 5, eb)
		var sc := Vector3(ex, ey, ez + es * 0.3)
		var sr := Vector3(es * ew, es * eh, es * 0.6)
		g.ellipsoid(sc, sr, EYE, 12, 6, eb)
		# 동공: 공막 겉면에 붙은 납작한 세로 렌즈(공막 높이의 0.72, 폭의 0.2). 동공 뼈는 공막 앞에 두어 표정으로 줄여도 공막 속에 묻히지 않는다
		var px := -side * es * 0.1
		var py := -es * 0.03
		var pz := -sr.z * sqrt(1.0 - pow(px / sr.x, 2.0) - pow(py / sr.y, 2.0))
		var pc := sc + eb * Vector3(px, py, pz - es * 0.3)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		_dome(g, sc, sr, eb, px, py, sr.x * 0.2, sr.y * 0.72, 1.6, es * 0.02, es * 0.07, PUPIL, 10)
		# 반사광: 동공 위·바깥 모서리에 걸친 작은 둥근 판 하나
		_dome(g, sc, sr, eb, px + side * es * 0.2, py + es * 0.42, es * 0.09, es * 0.09, 1.0, es * 0.07, es * 0.03, Color.WHITE, 6)
		# 윗눈꺼풀: 아래 반구 덮개(눈과 같은 기울기). 뼈에서 Y 크기를 키우면 내려와 눈을 덮는다. 기본 표정에서도 공막 위 테까지 덮여 위엄 있는 눈매
		var lid_p := Vector3(ex, ey + es * 1.4, ez + es * 0.1)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.55, es * 2.9, es * 0.9), BODY, 8, 3, Basis(Vector3.BACK, PI + side * tilt), PI * 0.5, PI * 0.5)
		# 눈썹: 짙고 두툼하며 안쪽 끝이 내려가고 바깥쪽이 올라간다(기본 표정 = 위엄). 눈알 앞으로 나오지 않게 머리 표면에 붙인다
		var by := ey + es * 1.65
		var bz := CharGeo.surf_z(hc, hr, ex, by)
		g.add_bone("Brow" + sfx, "Head", Vector3(ex, by, bz))
		g.use("Brow" + sfx)
		var bw := es * 1.15
		var xi := ex - side * bw * 0.95
		var xo := ex + side * bw
		var yi := by - es * 0.45
		var yo := by + es * 0.2
		g.sweep([Vector3(xi, yi, CharGeo.surf_z(hc, hr, xi, yi) - es * 0.08),
			Vector3(ex - side * bw * 0.2, by - es * 0.05, bz - es * 0.1),
			Vector3(xo, yo, CharGeo.surf_z(hc, hr, xo, yo) - es * 0.08)], es * 0.27, BODY_DEEP, 4)
	# 입(주둥이 타원 위)
	var mc: Vector3 = F.mc
	var mr: Vector3 = F.mr
	var my: float = F.mouth_y
	var mw: float = F.mouth_w
	var mz := CharGeo.surf_z(mc, mr, 0.0, my)
	var fb := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	# 보통: 가는 어두운 곡선(입가가 올라간 미소) + 양쪽 입가 가까이에 작은 흰 삼각 송곳니 둘
	g.add_bone("MouthN", "Head", Vector3(0, my, mz))
	g.use("MouthN")
	var pts: Array = []
	for i in 7:
		var u := float(i) / 3.0 - 1.0
		var x := u * mw * 0.5
		var y := my + u * u * mw * 0.2 - u * mw * 0.03
		pts.append(Vector3(x, y, CharGeo.surf_z(mc, mr, x, y) - mw * 0.03))
	g.sweep(pts, mw * 0.045, LIP, 4)
	for fu: float in [-0.7, 0.62]:
		var fx := fu * mw * 0.5
		var fy := my + fu * fu * mw * 0.2 - fu * mw * 0.03
		var fs := 1.0 if fu < 0.0 else 0.8
		g.polygon(PackedVector2Array([Vector2(-mw * 0.065 * fs, mw * 0.03), Vector2(mw * 0.065 * fs, mw * 0.03), Vector2(0.0, -mw * 0.26 * fs)]),
			Vector3(fx, fy, CharGeo.surf_z(mc, mr, fx, fy - mw * 0.1) - mw * 0.06), fb, mw * 0.03, Color.WHITE)
	# 벌림(웃음·분노): 입꼬리가 올라간 초승달꼴 붉은 입속(평판) + 혀 + 윗입술에서 내려오는 송곳니 둘 + 가는 입술선
	g.add_bone("MouthA", "Head", Vector3(0, my, mz))
	g.use("MouthA")
	var grin := PackedVector2Array()
	var rim: Array = []
	for i in 9:
		var u := float(i) / 4.0 - 1.0
		var x := u * mw * 0.47
		var y := my + mw * 0.03 + u * u * mw * 0.15
		grin.append(Vector2(x, y - my))
		rim.append(Vector3(x, y, CharGeo.surf_z(mc, mr, x, y) - mw * 0.05))
	for i in range(7, 0, -1):
		var u := float(i) / 4.0 - 1.0
		var x := u * mw * 0.47
		var y := my + mw * 0.03 + u * u * mw * 0.15 - (1.0 - u * u) * mw * 0.32
		grin.append(Vector2(x, y - my))
		rim.append(Vector3(x, y, CharGeo.surf_z(mc, mr, x, y) - mw * 0.05))
	g.polygon(grin, Vector3(0, my, mz - mw * 0.07), fb, 0.0, MOUTH_IN)
	g.sweep(rim, mw * 0.035, LIP, 3, true)
	g.ellipsoid(Vector3(0, my - mw * 0.2, mz - mw * 0.06), Vector3(mw * 0.2, mw * 0.08, mw * 0.06), TONGUE, 7, 3)
	for side: float in [-1.0, 1.0]:
		var tx := mw * 0.26 * side
		var ty := my + mw * 0.1
		g.polygon(PackedVector2Array([Vector2(-mw * 0.065, mw * 0.02), Vector2(mw * 0.065, mw * 0.02), Vector2(0.0, -mw * 0.24)]),
			Vector3(tx, ty, mz - mw * 0.09), fb, mw * 0.03, Color.WHITE)
	# 아픔·기절: 가는 물결선(색 채움 없음)
	g.add_bone("MouthH", "Head", Vector3(0, my, mz))
	g.use("MouthH")
	var wav: Array = []
	for i in 7:
		var u := float(i) / 3.0 - 1.0
		var x := u * mw * 0.4
		var y := my - mw * 0.04 + sin(u * PI * 1.5) * mw * 0.07
		wav.append(Vector3(x, y, CharGeo.surf_z(mc, mr, x, y) - mw * 0.03))
	g.sweep(wav, mw * 0.045, LIP, 4)
	g.use("Head")
	g.line = keep_line
