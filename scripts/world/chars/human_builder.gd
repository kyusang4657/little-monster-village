class_name HumanBuilder
extends RefCounted
## 인간형 몸(기사·보스·해골)의 공용 메시·골격 빌더. 명세 S 의 키로 투구·무기·방패·망토가 달라진다


static func build(S: Dictionary) -> Dictionary:
	var P: Dictionary = S.P
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	var hcen: Vector3 = S.hc
	var hr: Vector3 = S.hr
	var skin: Color = S.skin
	var trim: Color = S.trim
	var armor: Color = S.armor
	var cc: Vector3 = S.chest_c
	var cr: Vector3 = S.chest_r
	var spine_y: float = P.spine
	var pel: float = P.pelvis
	# 몸통: 넓은 가슴판, 잘록한 허리, 벨트, 치마(튜닉)
	g.use("Spine")
	g.ellipsoid(cc, cr, S.chest, 10, 6)
	g.ellipsoid(cc + Vector3(0, cr.y * 0.55, -cr.z * 0.05), Vector3(cr.x * 0.55, cr.y * 0.35, cr.z * 1.0), trim, 8, 3, Basis.IDENTITY, 0.9, 0.9, 0.5)
	var wr: Vector2 = S.waist_r
	g.tube(Vector3(0, spine_y - 0.04, 0), Vector3(0, cc.y - cr.y * 0.3, 0), wr.x, wr.y, S.waist, 10, false)
	if S.has("gem"):
		# 보스 가슴 문장(금 원판 + 보석)
		var ez := cc.z - cr.z * 0.93
		var ey := cc.y + cr.y * 0.05
		g.ellipsoid(Vector3(0, ey, ez), Vector3(0.05, 0.05, 0.02), trim, 10, 4)
		g.ellipsoid(Vector3(0, ey, ez - 0.015), Vector3(0.025, 0.03, 0.015), S.gem, 6, 4)
	var by: float = S.belt_y
	g.tube(Vector3(0, by - 0.02, 0), Vector3(0, by + 0.02, 0), wr.x + 0.012, wr.x + 0.016, Models.WOOD_DARK, 10, true)
	g.box(Vector3(0, by, -wr.x - 0.016), Vector3(0.05, 0.045, 0.015), trim)
	g.use("Pelvis")
	g.ellipsoid(Vector3(0, pel, 0), Vector3(wr.x * 1.15, 0.07, wr.x * 0.95), S.trouser, 8, 4)
	var sy: Vector2 = S.skirt_y
	var sr: Vector2 = S.skirt_r
	g.tube(Vector3(0, sy.x, 0), Vector3(0, sy.y, 0), sr.x, sr.y, S.skirt, 10, false)
	g.tube(Vector3(0, sy.y + 0.022, 0), Vector3(0, sy.y - 0.002, 0), sr.y + 0.004, sr.y + 0.008, trim, 10, false)
	g.use("Neck")
	g.tube(Vector3(0, float(P.neck) - 0.03, 0), Vector3(0, float(P.head) + 0.04, 0), 0.05, 0.048, skin, 7, false)
	g.use("Spine")
	g.tube(Vector3(0, float(P.neck) - 0.04, 0), Vector3(0, float(P.neck) + 0.005, 0), 0.085, 0.07, S.armor_dark, 10, true)
	# 팔다리
	CharGeo.limbs(g, P, {upper = S.trouser, elbow = armor, fore = armor, hand = S.glove, cuff = S.armor_dark,
		thigh = S.trouser, knee = armor, shin = armor, boot = S.boot, cuff_leg = S.boot.darkened(0.2),
		hand_s = S.get("hand_s", 1.0), boot_s = S.get("boot_s", 1.0)})
	# 어깨 갑옷(넓은 어깨 실루엣)
	var pd: Vector3 = S.pauldron
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.use("Arm" + sfx)
		var pc := Vector3(float(P.shoulder_x) * side + pd.x * 0.15 * side, float(P.shoulder) - pd.y * 0.2, 0)
		g.ellipsoid(pc, pd, armor, 10, 4, Basis.IDENTITY, PI * 0.55, PI * 0.55)
		g.ellipsoid(pc, pd * 1.04, trim, 10, 1, Basis.IDENTITY, PI * 0.56, PI * 0.56, PI * 0.5)
		if S.get("spikes", false):
			g.measure = false
			g.tube(pc + Vector3(0, pd.y * 0.6, 0), pc + Vector3(pd.x * 0.7 * side, pd.y * 1.9, 0), 0.025, 0.0, trim, 5, true)
			g.measure = true
	# 망토(2차 움직임 뼈)
	var cape_top := Vector3(0, float(P.shoulder) + 0.01, cr.z * 0.85)
	g.add_bone("Cape", "Spine", cape_top)
	g.use("Cape")
	var cw: Vector2 = S.cape_w
	var cl: float = S.cape_len
	var cape_bot := cape_top + Vector3(0, -cl, 0.08)
	g.tube(cape_top, cape_bot, cw.x, cw.y, S.cape, 8, true, 1.0, 0.12)
	if S.has("cape_hem"):
		g.tube(cape_bot + Vector3(0, 0.025, -0.003), cape_bot - Vector3(0, 0.002, 0), cw.y + 0.003, cw.y + 0.004, S.cape_hem, 8, true, 1.0, 0.16)
	# 머리·얼굴
	g.use("Head")
	g.ellipsoid(hcen, hr, skin, 12, 8)
	var es: float = S.es
	var ey: float = S.eye_y
	CharGeo.face(g, {hc = hcen, hr = hr, es = es, eye_y = ey, eye_dx = S.eye_dx, mouth_y = S.mouth_y, mouth_w = S.mouth_w,
		skin = skin, pupil = S.get("pupil", Color("2b2233")), brow = Color("5a3a22") if S.get("hair", null) == null else Color(S.hair).darkened(0.35),
		blush = Color("f19a8f") if not S.get("no_blush", false) else skin})
	g.use("Head")
	var ny := ey - es * 1.55
	g.sphere(Vector3(0, ny, CharGeo.surf_z(hcen, hr, 0, ny) - 0.008), 0.022, skin.darkened(0.1), 6, 4)
	# 귀(사람, 투구가 없을 때만 보인다)
	for side: float in ([] if String(S.helmet) != "" else [-1.0, 1.0]):
		g.ellipsoid(hcen + Vector3(hr.x * 0.97 * side, -0.02, 0.01), Vector3(0.025, 0.04, 0.03), skin.darkened(0.06), 6, 3)
	if S.get("mustache", false):
		for side: float in [-1.0, 1.0]:
			var mx := 0.032 * side
			var my2: float = float(S.mouth_y) + float(S.mouth_w) * 0.42
			g.ellipsoid(Vector3(mx, my2, CharGeo.surf_z(hcen, hr, mx, my2) - 0.006), Vector3(0.036, 0.014, 0.014), Color("7a5a3a"), 6, 3, Basis(Vector3.BACK, -0.35 * side))
	# 투구 또는 머리카락
	var helmet: String = S.helmet
	var plume_base := Vector3(0, hcen.y + hr.y + 0.03, 0.02)
	if helmet != "":
		var hc2 := hcen + Vector3(0, 0.012, 0.012)
		var hr2 := hr * Vector3(1.11, 1.15, 1.13)
		# 앞은 눈썹 위까지만 덮어 얼굴(표정)이 보이게, 옆·뒤는 깊게
		var lat_f := 1.2
		var lat_b := 2.15
		g.ellipsoid(hc2, hr2, armor, 12, 5, Basis.IDENTITY, lat_f, lat_b)
		var rim: Array = []
		for j in 10:
			var lon := TAU * float(j) / 10.0
			var lat := lerpf(lat_b, lat_f, (1.0 + cos(lon)) * 0.5)
			rim.append(hc2 + Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon)) * hr2 * 1.01)
		g.sweep(rim, 0.016, trim, 4, true)
		for side: float in [-1.0, 1.0]:
			g.ellipsoid(hcen + Vector3(hr.x * 0.95 * side, -0.055, -0.03), Vector3(0.035, 0.08, 0.075), S.armor_dark, 6, 4)
		var top_y := hc2.y + hr2.y
		g.measure = false
		match helmet:
			"round":
				g.sphere(Vector3(0, top_y + 0.01, hc2.z), 0.03, trim, 6, 4)
			"pointed":
				g.tube(Vector3(0, top_y - 0.04, hc2.z), Vector3(0, top_y + 0.13, hc2.z + 0.02), 0.08, 0.0, armor, 10, false)
				plume_base = Vector3(0, top_y + 0.1, hc2.z + 0.03)
			"crest":
				g.ellipsoid(Vector3(0, top_y - 0.005, hc2.z), Vector3(0.022, 0.06, hr2.z * 0.95), trim, 8, 5)
			"visor":
				g.ellipsoid(Vector3(0, hc2.y + hr2.y * 0.58, hc2.z - hr2.z * 0.72), Vector3(hr2.x * 0.9, 0.04, 0.06), S.armor_dark, 10, 4, Basis(Vector3.RIGHT, -0.5))
			"brim":
				g.tube(Vector3(0, hc2.y + hr2.y * 0.36, hc2.z), Vector3(0, hc2.y + hr2.y * 0.36 + 0.018, hc2.z), hr2.x * 1.35, hr2.x * 1.3, armor, 14, true)
		g.measure = true
	else:
		# 용사: 금빛 뾰족 머리 + 금관(이마띠)
		var hair: Color = S.hair
		g.ellipsoid(hcen + Vector3(0, 0.012, 0.008), hr * 1.07, hair, 14, 6, Basis.IDENTITY, 1.05, 2.0)
		g.measure = false
		for t in [[0.0, 0.0, 0.14], [0.35, 0.6, 0.12], [-0.35, 0.6, 0.12], [0.7, 1.4, 0.1], [-0.7, 1.4, 0.1], [0.2, 2.3, 0.11], [-0.2, 2.3, 0.11], [0.0, 2.8, 0.1]]:
			var lat: float = t[1] * 0.45
			var lon: float = PI + t[0] * 1.6 if t[1] > 1.0 else t[0] * 1.6
			var dir := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
			var b := hcen + dir * hr * 0.98
			g.tube(b, b + (dir + Vector3(0, 0.6, 0.25)).normalized() * float(t[2]), 0.05, 0.0, hair, 6, true)
		for side: float in [-1.0, 0.0, 1.0]:
			var b := hcen + Vector3(0.06 * side, hr.y * 0.72, -hr.z * 0.7)
			g.tube(b, b + Vector3(0.025 * side, -0.06, -0.035), 0.035, 0.0, hair, 5, true)
		g.measure = true
		if S.get("circlet", false):
			var ring: Array = []
			for j in 14:
				var lon := TAU * float(j) / 14.0
				var lat := 1.05 + 0.05 * cos(lon)
				ring.append(hcen + Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon)) * hr * 1.09)
			g.sweep(ring, 0.014, trim, 4, true)
			g.sphere(ring[0] + Vector3(0, 0.0, -0.012), 0.022, S.gem, 6, 4)
		plume_base = Vector3(0, hcen.y + hr.y, 0.0)
	# 깃털(2차 움직임 뼈) — 기사의 붉은 깃은 멀리서도 보이게 크게
	var plumes: Array = S.plumes
	if not plumes.is_empty():
		g.add_bone("Plume", "Head", plume_base)
		g.use("Plume")
		g.measure = false
		var ps: float = S.get("plume_size", 1.0)
		for pi_ in plumes.size():
			var pc: Color = plumes[pi_]
			var ox := 0.0 if plumes.size() == 1 else (float(pi_) - 0.5) * 0.06
			var arc := [Vector3(ox, 0.04, 0.0), Vector3(ox, 0.11, 0.03), Vector3(ox, 0.15, 0.1), Vector3(ox, 0.14, 0.18), Vector3(ox * 1.2, 0.09, 0.24)]
			var rad := [0.045, 0.055, 0.055, 0.045, 0.032]
			for i in arc.size():
				var p: Vector3 = plume_base + (arc[i] as Vector3) * ps
				var rr: float = float(rad[i]) * ps
				g.ellipsoid(p, Vector3(rr * 0.8, rr * 1.15, rr * 1.2), pc if i % 2 == 0 else pc.darkened(0.12), 6, 4, Basis(Vector3.RIGHT, -0.4 - 0.25 * i))
		g.measure = true
	if S.get("ribs", false):
		# 해골: 가슴의 갈비뼈 띠
		g.use("Spine")
		for i in 3:
			var ry := cc.y + cr.y * (0.35 - 0.3 * float(i))
			g.box(Vector3(0, ry, cc.z - cr.z * 0.92), Vector3(cr.x * 1.3, 0.022, 0.02), Color("ece6d6"))
	var hand_r := Vector3(float(P.shoulder_x), float(P.wrist) - float(P.arm_r) * 0.75, -float(P.arm_r) * 0.1)
	if String(S.get("weapon", "sword")) == "bow":
		# 활(왼손 -X): 세로로 휜 활대와 시위, 등에 화살통
		g.use("HandL")
		g.measure = false
		g.measure_all = false
		var hl := Vector3(-float(P.shoulder_x), hand_r.y, hand_r.z - 0.02)
		var arc: Array = []
		for i in 7:
			var u := float(i) / 6.0 * 2.0 - 1.0
			arc.append(hl + Vector3(0, u * 0.32, -0.09 * (1.0 - u * u)))
		g.sweep(arc, 0.016, Models.WOOD_DARK, 5)
		g.sweep([hl + Vector3(0, 0.32, 0.0), hl + Vector3(0, -0.32, 0.0)], 0.005, Color("f4efe4"), 4)
		g.measure_all = true
		g.use("Spine")
		g.tube(Vector3(0.06, cc.y - 0.05, cr.z + 0.02), Vector3(0.1, cc.y + 0.2, cr.z + 0.06), 0.04, 0.045, Color("6b3f1f"), 7, true)
		for i in 3:
			g.tube(Vector3(0.09 + i * 0.012 - 0.012, cc.y + 0.18, cr.z + 0.05), Vector3(0.09 + i * 0.012 - 0.012, cc.y + 0.27, cr.z + 0.08), 0.008, 0.008, Color("f4efe4"), 4, true)
		g.measure = true
		var bdef := g.build(CharacterRig.character_material())
		bdef.tip = hl
		bdef.H = float(S.H)
		bdef.es = es
		bdef.thigh = float(P.hip) - float(P.knee)
		bdef.shin = float(P.knee) - float(P.ankle)
		return bdef
	# 검(오른손 +X): 손 아래로 30° 앞으로 기울어 쥔다. 날은 앞뒤에서 넓게 보이도록 X 로 넓다.
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var gr := deg_to_rad(30.0)
	var d := Vector3(0, -cos(gr), -sin(gr))
	var sl: float = S.sword_len
	var sw: float = S.sword_w
	g.tube(hand_r - d * 0.065, hand_r + d * 0.05, 0.015, 0.015, Models.WOOD_DARK, 6, false)
	g.sphere(hand_r - d * 0.075, 0.024, trim, 6, 4)
	var guard_c := hand_r + d * 0.058
	g.box(guard_c, Vector3(sw * 5.0, 0.026, 0.026), trim, Basis(Vector3.RIGHT, d, Vector3.RIGHT.cross(d)))
	if S.has("gem"):
		g.sphere(guard_c + d.cross(Vector3.RIGHT) * 0.016, 0.018, S.gem, 6, 4)
	var blade_end := hand_r + d * (0.07 + sl)
	g.tube(hand_r + d * 0.07, blade_end, sw, sw * 0.9, Color("dfe6ee"), 6, false, 1.0, 0.28)
	var tip := blade_end + d * sw * 2.6
	g.tube(blade_end, tip, sw * 0.9, 0.0, Color("dfe6ee"), 6, true, 1.0, 0.28)
	# 둥근 방패(왼손 -X): 바깥·앞을 본다. 무늬는 변형마다 다르다.
	g.use("HandL")
	var hand_l := Vector3(-float(P.shoulder_x), hand_r.y, hand_r.z)
	var nrm := Vector3(-0.55, -0.5, -0.67).normalized()
	var sc := hand_l + nrm * 0.055
	var r_sh: float = S.shield_r
	g.measure_all = true
	g.tube(sc - nrm * 0.022, sc + nrm * 0.012, r_sh * 1.07, r_sh * 1.07, S.shield_rim, 14, true)
	g.tube(sc - nrm * 0.01, sc + nrm * 0.022, r_sh, r_sh, S.shield_c, 14, true)
	var t1 := nrm.cross(Vector3.UP).normalized()
	var t2 := t1.cross(nrm).normalized()
	if t2.y < 0.0:
		t2 = -t2
	var face := sc + nrm * 0.026
	var sb := Basis(t1, t2, nrm)
	var mark: Color = S.shield_mark
	match String(S.shield):
		"cross":
			g.box(face, Vector3(r_sh * 1.7, 0.045, 0.012), mark, sb)
			g.box(face, Vector3(0.045, r_sh * 1.7, 0.012), mark, sb)
		"band":
			g.box(face, Vector3(r_sh * 1.85, 0.075, 0.012), Color("f4efe4"), Basis(nrm, PI * 0.25) * sb)
		"ring":
			g.tube(face - nrm * 0.006, face + nrm * 0.004, r_sh * 0.62, r_sh * 0.62, mark, 14, true)
			g.tube(face - nrm * 0.004, face + nrm * 0.008, r_sh * 0.48, r_sh * 0.48, S.shield_c, 14, true)
		"stripes":
			# 흰 가로 띠 두 줄
			for sgn: float in [-1.0, 1.0]:
				g.box(face + t2 * (r_sh * 0.32 * sgn), Vector3(r_sh * 1.6, 0.055, 0.012), Color("f4efe4"), sb)
		"star":
			for k in 4:
				g.box(face, Vector3(r_sh * 1.5, 0.05, 0.012), mark, Basis(nrm, PI * 0.25 * k) * sb)
		"crown":
			g.box(face - t2 * r_sh * 0.15, Vector3(r_sh * 0.95, r_sh * 0.28, 0.012), mark, sb)
			for k in 3:
				var off := t1 * (float(k - 1) * r_sh * 0.36) + t2 * r_sh * 0.02
				g.tube(face + off - nrm * 0.004, face + off + t2 * r_sh * 0.35, 0.05, 0.0, mark, 5, true, 1.0, 0.25, nrm)
	g.sphere(face + nrm * 0.012, 0.045 * r_sh / 0.21, trim, 8, 5)
	var def := g.build(CharacterRig.character_material())
	def.tip = tip
	def.H = float(S.H)
	def.es = es
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def
