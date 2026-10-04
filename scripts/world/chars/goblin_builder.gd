class_name GoblinBuilder
extends RefCounted
## 고블린 일꾼(변형 3종)과 꼬마 오크(orc = true)의 메시·골격 정의


# ================================================================== 고블린

static func build(v: int, with_hammer: bool, orc: bool = false) -> Dictionary:
	var P := {
		ankle = 0.075, knee = 0.18, hip = 0.3, hip_x = 0.075, pelvis = 0.31, spine = 0.36,
		shoulder = 0.54, shoulder_x = 0.15, elbow = 0.41, wrist = 0.285, neck = 0.57, head = 0.62,
		arm_r = 0.035, leg_r = 0.038, foot_len = 0.17,
	}
	var tunic: Color = [Models.TUNIC, Color("2f8f8a"), Color("c0602f")][v]
	var skin := Models.GOBLIN_SKIN
	if orc:
		tunic = Color("7a4a26")
		skin = Color("7f9a3a")
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	# 몸통: 넓은 가슴, 잘록한 허리, 반바지
	g.use("Spine")
	g.ellipsoid(Vector3(0, 0.465, 0.005), Vector3(0.155, 0.12, 0.12), tunic, 12, 7)
	g.tube(Vector3(0, 0.335, 0), Vector3(0, 0.44, 0), 0.105, 0.125, tunic, 10, false)
	g.tube(Vector3(0, 0.345, 0), Vector3(0, 0.382, 0), 0.118, 0.12, Models.WOOD_DARK, 10, true)
	g.box(Vector3(0, 0.363, -0.12), Vector3(0.05, 0.04, 0.015), Models.BRASS)
	g.use("Pelvis")
	g.ellipsoid(Vector3(0, 0.3, 0), Vector3(0.125, 0.075, 0.1), Models.SHORTS, 10, 5)
	g.use("Neck")
	g.tube(Vector3(0, 0.54, 0), Vector3(0, 0.66, 0), 0.045, 0.045, skin, 7, false)
	CharGeo.limbs(g, P, {shoulder = tunic, upper = skin, elbow = skin, fore = skin, hand = skin,
		thigh = skin, knee = skin, shin = skin, boot = Models.BOOT, cuff_leg = Color("5e3a1e"), toe = Models.BOOT,
		hand_s = 1.55 if orc else 1.35, boot_s = 1.3 if orc else 1.2})
	for side: float in [-1.0, 1.0]:
		g.use("LegL" if side < 0.0 else "LegR")
		g.tube(Vector3(0.075 * side, 0.32, 0), Vector3(0.075 * side, 0.235, 0), 0.062, 0.058, Models.SHORTS, 8, true)
	# 머리(3등신: 큰 머리)
	var hc := Vector3(0, 0.79, -0.005)
	var hr := Vector3(0.2, 0.18, 0.18)
	g.use("Head")
	g.ellipsoid(hc, hr, skin, 14, 9)
	CharGeo.face(g, {hc = hc, hr = hr, es = 0.046, eye_y = 0.8, eye_dx = 0.082, mouth_y = 0.705, mouth_w = 0.12,
		skin = skin, pupil = Color("2b2233"), brow = Color("3f6b1a"), blush = Color("6aa22c")})
	g.use("Head")
	# 긴 코와 아랫니 송곳니
	g.ellipsoid(Vector3(0, 0.755, CharGeo.surf_z(hc, hr, 0, 0.755) - 0.03), Vector3(0.034, 0.03, 0.055), Models.GOBLIN_SKIN_DARK, 7, 4)
	for side: float in [-1.0, 1.0]:
		var fx := 0.04 * side
		var fz := CharGeo.surf_z(hc, hr, fx, 0.69) - 0.004
		if orc:
			# 오크: 위로 솟은 큰 엄니
			g.tube(Vector3(fx * 1.3, 0.672, fz - 0.005), Vector3(fx * 1.6, 0.745, fz - 0.03), 0.02, 0.0, Color("f3ead2"), 6, true)
		else:
			g.tube(Vector3(fx, 0.682, fz), Vector3(fx, 0.718, fz - 0.004), 0.012, 0.0, Color.WHITE, 5, true)
	# 과장된 큰 뾰족 귀(2차 움직임용 뼈)
	g.measure = false
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var base := Vector3(0.17 * side, 0.81, 0.01)
		g.add_bone("Ear" + sfx, "Head", base)
		g.use("Ear" + sfx)
		g.tube(base, Vector3(0.47 * side, 0.92, 0.06), 0.08, 0.0, skin, 8, true, 0.45, 1.0, Vector3.BACK)
		g.tube(base + Vector3(0.02 * side, 0, -0.03), Vector3(0.4 * side, 0.9, 0.03), 0.045, 0.0, Color("c97b7b"), 6, true, 0.35, 1.0, Vector3.BACK)
	# 머리 모양: 0 = 뾰족 머리털, 1 = 닭벼슬 머리, 2 = 상투
	g.use("Head")
	match v:
		0:
			for t in [[0.0, 0.0, 0.0, 0.13], [0.07, 0.03, -25.0, 0.1], [-0.07, 0.03, 25.0, 0.1]]:
				var b := Vector3(t[0], 0.95, t[1])
				var tip := b + Vector3(sin(deg_to_rad(-t[2])) * t[3], cos(deg_to_rad(t[2])) * t[3], 0.03)
				g.tube(b, tip, 0.05, 0.0, Models.HAIR, 6, true)
		1:
			for i in 5:
				var z := -0.12 + i * 0.06
				var y := hc.y + hr.y * sqrt(maxf(0.0, 1.0 - pow(z / hr.z, 2.0))) - 0.02
				g.tube(Vector3(0, y, z), Vector3(0, y + 0.11 - absf(z) * 0.3, z + 0.03), 0.04, 0.0, Color("d0532a"), 5, true, 0.5, 1.0)
		_:
			g.sphere(Vector3(0, 0.985, 0.03), 0.055, Color("3b2a1a"), 8, 5)
			g.tube(Vector3(0, 1.02, 0.04), Vector3(0, 1.07, 0.07), 0.025, 0.0, Color("3b2a1a"), 5, true)
	# 고글: 0, 2 번 변형(오크는 없음)
	g.measure = true
	if v != 1 and not orc:
		g.ellipsoid(hc, hr * 1.04, Models.WOOD_DARK, 14, 1, Basis.IDENTITY, 0.98, 1.12, 0.84)
		for side: float in [-1.0, 1.0]:
			var gx := 0.075 * side
			var gy := 0.905
			var gz := CharGeo.surf_z(hc, hr, gx, gy)
			var nn := Vector3(gx / (hr.x * hr.x), (gy - hc.y) / (hr.y * hr.y), (gz - hc.z) / (hr.z * hr.z)).normalized()
			var p := Vector3(gx, gy, gz)
			g.tube(p - nn * 0.01, p + nn * 0.035, 0.05, 0.05, Models.BRASS, 10, true)
			g.ellipsoid(p + nn * 0.035, Vector3(0.038, 0.038, 0.012), Color("9fd8e8"), 8, 3, Basis(Quaternion(Vector3.FORWARD, nn)))
	# 망치(오른손 +X). 손잡이는 손 아래로 35° 앞으로 기울어 쥔다.
	var hand := Vector3(P.shoulder_x, float(P.wrist) - float(P.arm_r) * 0.75, -0.004)
	var tip := hand
	if with_hammer:
		g.use("HandR")
		g.measure = false
		g.measure_all = false
		var gr := deg_to_rad(35.0)
		var d := Vector3(0, -cos(gr), -sin(gr))
		var perp := Vector3(0, -sin(gr), cos(gr))
		var end := hand + d * 0.3
		g.tube(hand - d * 0.04, end, 0.017, 0.017, Models.WOOD, 6, true)
		g.tube(end - perp * 0.075, end + perp * 0.075, 0.048, 0.048, Models.WOOD_DARK, 8, true)
		g.tube(end - perp * 0.08, end - perp * 0.05, 0.052, 0.052, Models.SILVER_DARK, 8, true)
		g.tube(end + perp * 0.05, end + perp * 0.08, 0.052, 0.052, Models.SILVER_DARK, 8, true)
		tip = end
	var def := g.build(CharacterRig.character_material())
	def.tip = tip
	def.H = 1.0
	def.es = 0.046
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def
