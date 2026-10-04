class_name ImpBuilder
extends RefCounted
## 뿔이(어린 마왕, 주인공)의 메시·골격 정의. level = 성 레벨 1~4


# ================================================================== 뿔이(어린 마왕)

## 2.3등신. 짝짝이 뿔(왼쪽이 덜 자람), 물려받은 큰 망토(Lv.1 은 바닥에 끌림), 사탕 보석 지팡이, 연두 눈, 라벤더 피부.
## 성 레벨: Lv.2 뿔이 자라고 망토 끝을 묶음, Lv.3 금 어깨 장식·빛나는 보석, Lv.4 왕관·몸에 맞는 망토(왼뿔은 여전히 작음).
static func build(lv: int) -> Dictionary:
	var P := {
		ankle = 0.06, knee = 0.135, hip = 0.225, hip_x = 0.065, pelvis = 0.235, spine = 0.275,
		shoulder = 0.405, shoulder_x = 0.118, elbow = 0.315, wrist = 0.232, neck = 0.43, head = 0.47,
		arm_r = 0.031, leg_r = 0.034, foot_len = 0.15,
	}
	var skin := Color("c9b3ea")
	var skin_dark := Color("a68ccf")
	var robe := Color("553292")
	var cape_c := Color("6a3fb0")
	var cape_in := Color("2c1450")
	var gold := Models.GOLD
	var horn := Color("f3e6c8")
	var horn_tip := Color("8a6a9e")
	var eye_green := Color("2f9a3c")
	var gem := Color("b86bff") if lv < 3 else Color("d9a6ff")
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	# 몸통: 동그란 배의 짙은 보라 옷, 금단추
	g.use("Spine")
	g.ellipsoid(Vector3(0, 0.33, 0.0), Vector3(0.118, 0.105, 0.105), robe, 12, 7)
	g.tube(Vector3(0, 0.27, 0), Vector3(0, 0.37, 0), 0.1, 0.09, robe, 10, false)
	for i in 2:
		var by := 0.355 - i * 0.05
		g.sphere(Vector3(0, by, CharGeo.surf_z(Vector3(0, 0.33, 0), Vector3(0.118, 0.105, 0.105), 0, by) - 0.004), 0.011, gold, 5, 3)
	g.use("Pelvis")
	g.tube(Vector3(0, 0.29, 0), Vector3(0, 0.17, 0), 0.1, 0.122, robe, 10, false)
	g.tube(Vector3(0, 0.185, 0), Vector3(0, 0.168, 0), 0.124, 0.126, gold if lv >= 3 else Color("5b3a8f"), 10, false)
	# 꼬리(뒤 +Z, 끝은 스페이드)
	var tail := [Vector3(0, 0.22, 0.09), Vector3(0, 0.17, 0.17), Vector3(0, 0.15, 0.25), Vector3(0, 0.2, 0.31)]
	g.sweep(tail, 0.014, skin_dark, 5)
	g.tube(Vector3(0, 0.2, 0.3), Vector3(0, 0.27, 0.33), 0.035, 0.0, skin_dark, 6, true, 1.0, 0.35, Vector3.BACK)
	g.use("Neck")
	g.tube(Vector3(0, 0.41, 0), Vector3(0, 0.5, 0), 0.04, 0.04, skin, 7, false)
	CharGeo.limbs(g, P, {shoulder = robe, upper = robe, elbow = skin, fore = skin, hand = skin, cuff = Color("5b3a8f"),
		thigh = skin, knee = skin, shin = skin, boot = Color("2a1a3a"), cuff_leg = Color("4a2d6a"), toe = Color("2a1a3a"),
		hand_s = 1.2, boot_s = 1.15})
	# Lv.3+: 금 어깨 장식
	if lv >= 3:
		for side: float in [-1.0, 1.0]:
			g.use("ArmL" if side < 0.0 else "ArmR")
			var pc := Vector3(float(P.shoulder_x) * side, float(P.shoulder) + 0.005, 0)
			g.ellipsoid(pc, Vector3(0.05, 0.035, 0.05), gold, 8, 3, Basis.IDENTITY, PI * 0.55, PI * 0.55)
	# 망토(2차 움직임 뼈): Lv.1 은 몸보다 커서 바닥에 끌리고 깃이 크다
	var cape_len: float = [0.0, 0.44, 0.37, 0.35, 0.34][lv]
	var cape_w: Vector2 = [Vector2.ZERO, Vector2(0.12, 0.22), Vector2(0.11, 0.19), Vector2(0.11, 0.18), Vector2(0.11, 0.18)][lv]
	var cape_top := Vector3(0, float(P.shoulder) + 0.012, 0.085)
	g.add_bone("Cape", "Spine", cape_top)
	g.use("Cape")
	var cape_bot := cape_top + Vector3(0, -cape_len, 0.1 if lv == 1 else 0.07)
	g.tube(cape_top, cape_bot, cape_w.x, cape_w.y, cape_c, 9, true, 1.0, 0.12)
	g.tube(cape_top + Vector3(0, -0.01, -0.012), cape_bot + Vector3(0, 0.01, -0.012), cape_w.x * 0.96, cape_w.y * 0.96, cape_in, 9, false, 1.0, 0.1)
	if lv == 1:
		# 바닥에 끌리는 끝단(접힌 천)
		g.ellipsoid(cape_bot + Vector3(0, 0.012, 0.02), Vector3(cape_w.y * 1.05, 0.02, 0.06), cape_c, 9, 3)
	elif lv == 2:
		g.sphere(cape_bot + Vector3(cape_w.y * 0.55, 0.05, 0.005), 0.03, cape_c.darkened(0.15), 6, 4)
	else:
		g.tube(cape_bot + Vector3(0, 0.022, -0.003), cape_bot - Vector3(0, 0.002, 0), cape_w.y + 0.003, cape_w.y + 0.004, gold, 9, true, 1.0, 0.16)
	# 깃(Lv.1 은 크고 펄럭, Lv.4 는 높이 선 깃)
	var collar_r := 0.12 if lv == 1 else (0.1 if lv < 4 else 0.105)
	g.use("Spine")
	g.ellipsoid(Vector3(0, float(P.shoulder) + 0.02, 0.01), Vector3(collar_r, 0.035 if lv < 4 else 0.06, collar_r * 0.85), cape_c, 10, 3,
		Basis.IDENTITY, PI * 0.55, PI * 0.55, 0.0)
	if lv == 4:
		g.ellipsoid(Vector3(0, 0.335, CharGeo.surf_z(Vector3(0, 0.33, 0), Vector3(0.118, 0.105, 0.105), 0, 0.335) - 0.005), Vector3(0.03, 0.03, 0.012), gold, 8, 3)
		g.sphere(Vector3(0, 0.335, CharGeo.surf_z(Vector3(0, 0.33, 0), Vector3(0.118, 0.105, 0.105), 0, 0.335) - 0.016), 0.014, Color("7ee06a"), 5, 3)
	# 머리: 아주 큰 머리(2.3등신)
	var hc := Vector3(0, 0.625, -0.005)
	var hr := Vector3(0.19, 0.172, 0.172)
	g.use("Head")
	g.ellipsoid(hc, hr, skin, 14, 9)
	# 눈은 머리 가운데보다 아래(아기 같은 비율), 눈썹은 연한 색으로 부드럽게
	CharGeo.face(g, {hc = hc, hr = hr, es = 0.052, eye_y = 0.6, eye_dx = 0.08, mouth_y = 0.517, mouth_w = 0.07,
		skin = skin, pupil = eye_green, brow = skin_dark.darkened(0.1), blush = Color("f2a0c8"), iris = 1.12, pupil_core = Color("173d1c"),
		lid = skin})
	g.use("Head")
	# 작은 코, 오른쪽 송곳니 하나(빼꼼)
	g.sphere(Vector3(0, 0.553, CharGeo.surf_z(hc, hr, 0, 0.553) - 0.006), 0.013, skin_dark, 5, 3)
	var fz := CharGeo.surf_z(hc, hr, 0.022, 0.515) - 0.006
	g.tube(Vector3(0.022, 0.521, fz), Vector3(0.024, 0.5, fz - 0.002), 0.009, 0.0, Color.WHITE, 5, true)
	# 정수리 위 동그랗게 말린 머리카락 한 가닥
	var curl: Array = []
	for j in 8:
		var a := float(j) / 7.0 * PI * 1.6
		curl.append(Vector3(sin(a) * 0.03, hc.y + hr.y * 0.97 + 0.03 - cos(a) * 0.03, hc.z - 0.03))
	g.sweep(curl, 0.012, Color("4a2d6a"), 5)
	# 짝짝이 뿔: 바깥·위·뒤로 휘어지는 원뿔 마디. 오른쪽(+X)이 더 크고, 왼쪽은 Lv.4 에서도 작다.
	g.measure = false
	var horn_len: Vector2 = {1: Vector2(0.06, 0.12), 2: Vector2(0.08, 0.16), 3: Vector2(0.095, 0.19), 4: Vector2(0.11, 0.23)}[lv]
	for side: float in [-1.0, 1.0]:
		var L: float = horn_len.x if side < 0.0 else horn_len.y
		var base := hc + Vector3(0.105 * side, hr.y * 0.78, 0.01)
		var r0 := 0.032 + L * 0.12
		var pts: Array = []
		for i in 5:
			var u := float(i) / 4.0
			pts.append(base + Vector3(side * (L * 0.55 * u + L * 0.25 * u * u), L * (0.95 * u - 0.15 * u * u), L * 0.35 * u * u))
		for i in 4:
			var ra := r0 * (1.0 - float(i) / 4.0)
			var rb := r0 * (1.0 - float(i + 1) / 4.0)
			g.tube(pts[i], pts[i + 1], ra, maxf(rb, 0.0), horn if i < 3 else horn_tip, 7, i == 3)
	g.measure = true
	# Lv.4 왕관(금테 + 뾰족 다섯 + 연두 보석)
	if lv == 4:
		var ring: Array = []
		for j in 14:
			var lon := TAU * float(j) / 14.0
			var lat := 0.62
			ring.append(hc + Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon)) * hr * 1.02)
		g.sweep(ring, 0.016, gold, 4, true)
		g.measure = false
		for k in 5:
			var lon := TAU * float(k) / 5.0
			var b := hc + Vector3(sin(0.62) * sin(lon), cos(0.62), -sin(0.62) * cos(lon)) * hr * 1.02
			g.tube(b, b + Vector3(0, 0.055, 0), 0.022, 0.0, gold, 5, true)
		g.measure = true
		g.sphere(ring[0] + Vector3(0, 0.01, -0.012), 0.018, Color("7ee06a"), 6, 4)
	# 사탕 보석 지팡이(오른손 +X). 쉬는 자세에서 앞으로 기울어 있어 팔을 굽히면(대기) 곧게 선다.
	var hand := Vector3(float(P.shoulder_x), float(P.wrist) - float(P.arm_r) * 0.75, -0.004)
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var sa := 0.75
	# 머리(큰 공) 옆을 지나 보석이 머리 위 바깥쪽에 오도록 살짝 바깥(+X)으로 기울인 긴 지팡이
	var d := Vector3(0.2, cos(sa), -sin(sa)).normalized()
	var top := hand + d * 0.52
	g.tube(hand - d * 0.1, top, 0.012, 0.013, Models.WOOD, 6, true)
	g.tube(top - d * 0.02, top + d * 0.012, 0.022, 0.022, gold, 6, true)
	var gc := top + d * 0.05
	g.sphere(gc, 0.05 if lv < 3 else 0.058, gem, 8, 6)
	# 사탕 소용돌이 띠
	var swirl: Array = []
	for j in 9:
		var a := TAU * float(j) / 8.0
		swirl.append(gc + Basis(Vector3.RIGHT, -sa) * (Vector3(cos(a), 0.35 * sin(a * 2.0) * 0.0 + (float(j) / 8.0 - 0.5) * 0.06, sin(a)) * (0.051 if lv < 3 else 0.059)))
	g.sweep(swirl, 0.008, Color("fdf3ff"), 4)
	if lv >= 3:
		# 빛나는 보석: 바깥 후광 고리
		g.sweep([gc + Vector3(-0.075, 0, 0), gc + Vector3(0, 0.075, 0), gc + Vector3(0.075, 0, 0), gc + Vector3(0, -0.075, 0)], 0.006, Color("f2dcff"), 4, true)
	var def := g.build(CharacterRig.character_material())
	def.tip = gc
	def.H = 0.8
	def.es = 0.054
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def
