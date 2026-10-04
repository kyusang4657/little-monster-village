class_name BossBuilder
extends RefCounted
## 보스 2종의 메시·골격 빌더(6차: 컨셉 시트 docs/design/concept/crops/s1-commander.jpg, s1-hero-ruru.jpg 기준).
## "commander" = 기사단장 번쩍경: 짙은 무거운 강철 판금(#8e99a6, 그늘 #5f6873)에 금 테, 한 단계 밝은 돔 투구(#a9b2bb),
##   투구 창을 메우는 어두운 강철 면갑에 좁은 T자 틈(가로 눈 틈 + 세로 턱 틈)과 틈 속에서 빛나는 작은 창백한 눈 2개,
##   돔 표면에 붙은 금 눈썹 바, 이마에서 목덜미까지 뒤로 휘어 넘어가는 두툼한 붉은 크레스트(Plume),
##   머리보다 큰 둥근 어깨 갑옷(금 테 + 가시 하나씩), 어깨 밖까지 넓은 붉은 망토(Cape, 금 단), 양손 큰 건틀릿(금 테·주먹 징),
##   기사 검의 1.3배쯤 되는 굵고 긴 대검을 주먹에 쥐고 날을 앞·아래로 기울인다(왼손은 방패 없이 건틀릿만).
## "hero" = 용사 루루: 금발(#f0c040, 안쪽 그늘색) 긴 머리 — 두개골 머리 덮개 + 이마 위 물결 앞머리 3갈래,
##   뒤통수 아래 묶음에서 허리까지 흘러내리는 넓은 뒷머리 판(안팎 두 색), 어깨 앞으로 내려오는 가는 옆 가닥 하나씩, 남색 리본,
##   위로 솟은 남색 베레모에 금 띠와 작은 붉은 깃털(Plume), 파란 상의·은 가슴판, 흰 치마에 파란 단과 금 선,
##   어깨 밖까지 넓은 보라 망토(Cape)와 깃의 금 브로치, 맨손(피부색), 굵은 검(오른손)과 작은 별 버클러(왼손), 크고 파란 눈.
## 몸은 HumanBuilder.build() 를 바탕으로 보스마다 따로 특수화했다(human_builder.gd 는 손대지 않는다).
## 골격 규약: 기준점 = 두 발 사이 지면, 정면 = -Z, 오른손 = +X. 2차 움직임 뼈 Cape(망토)·Plume(깃).

const BOSS_H := 1.3            ## 키 등급(자세 진폭 기준)
const GOLD := Color("e1b23c")
const GOLD_DARK := Color("b4862a")
const RED := Color("c0282c")
const CREST := Color("c8343a")
const RED_DARK := Color("7d161c")
const BLADE := Color("dfe6ee")


static func build(k: String) -> Dictionary:
	return _commander() if k == "commander" else _hero()


# ================================================================== 공통 도우미

## 머리 타원 표면 점. lat = 위 극에서 내려오는 각, lon = 정면(-Z)에서 오른쪽(+X)으로 도는 각, s = 반지름 배율
static func _hp(hc: Vector3, hr: Vector3, lat: float, lon: float, s: float = 1.0) -> Vector3:
	return hc + Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon)) * hr * s


## 마름모(문장·버클) 좌표
static func _diamond(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, h), Vector2(-w, 0), Vector2(0, -h), Vector2(w, 0)])


static func _finish(g: CharGeo, tip: Vector3, es: float, P: Dictionary) -> Dictionary:
	var def := g.build(CharacterRig.character_material())
	def.tip = tip
	def.H = BOSS_H
	def.es = es
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


## 팔다리: 위팔, 팔꿈치 공, 아래팔(소매·건틀릿, fore_flare 로 손목 쪽을 넓힘), 손목 띠, 주먹(둥근 상자),
## 허벅지, 무릎 공(+금 띠 선택), 정강이, 발목 띠, 장화(둥근 상자), 발끝 덮개(선택)
static func _limbs(g: CharGeo, P: Dictionary, C: Dictionary) -> void:
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	var ar: float = P.arm_r
	var lr: float = P.leg_r
	var hs: float = C.get("hand_s", 1.0)
	var bs: float = C.get("boot_s", 1.0)
	var sh: float = P.shoulder
	var el: float = P.elbow
	var wr: float = P.wrist
	var hip: float = P.hip
	var knee: float = P.knee
	var ankle: float = P.ankle
	var fl: float = P.foot_len
	var fr: float = C.get("fore_flare", 1.0)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Arm" + sfx)
		g.tube(Vector3(x, sh, 0), Vector3(x, el, 0), ar * 1.12, ar * 0.95, C.upper, 8, false)
		g.use("Forearm" + sfx)
		g.sphere(Vector3(x, el, 0), ar * 1.05, C.elbow, 8, 4)
		g.tube(Vector3(x, el, 0), Vector3(x, wr + ar * 0.3, 0), ar * 0.98, ar * fr, C.fore, 8, false)
		g.use("Hand" + sfx)
		g.torus(Vector3(x, wr + ar * 0.3, 0), ar * fr, ar * 0.24, C.cuff, 10, 5)
		g.rounded_box(Vector3(x, wr - ar * 0.8 * hs, -ar * 0.1), Vector3(ar * 1.1, ar * 1.15, ar * 1.1) * hs, C.hand, 0.75, 10, 6)
		var lx := hx * side
		g.use("Leg" + sfx)
		g.tube(Vector3(lx, hip + lr * 0.5, 0), Vector3(lx, knee, 0), lr * 1.2, lr * 0.95, C.thigh, 8, false)
		g.use("Shin" + sfx)
		g.sphere(Vector3(lx, knee, 0), lr * 1.02, C.knee, 8, 4)
		if C.has("knee_rim"):
			g.torus(Vector3(lx, knee + lr * 0.3, 0), lr * 0.9, lr * 0.2, C.knee_rim, 10, 4)
		g.tube(Vector3(lx, knee, 0), Vector3(lx, ankle, 0), lr * 0.95, lr * 0.85, C.shin, 8, false)
		g.use("Foot" + sfx)
		g.torus(Vector3(lx, ankle + lr * 0.35, 0), lr * 0.9, lr * 0.25, C.cuff_leg, 10, 4)
		g.rounded_box(Vector3(lx, ankle * 0.52 * bs, -fl * 0.2 * bs), Vector3(lr * 1.35 * bs, ankle * 0.53 * bs, fl * 0.5 * bs), C.boot, 0.6, 10, 6)
		if C.has("toe"):
			g.ellipsoid(Vector3(lx, ankle * 0.5 * bs, -fl * 0.55 * bs), Vector3(lr * 1.2 * bs, ankle * 0.42 * bs, fl * 0.22 * bs), C.toe, 8, 4)


## 검(오른손 +X): 손 아래로 tilt_deg 만큼 기울여 쥐되 그 기울기를 앞(-Z)과 바깥(+X, out_deg)으로 나눈다
## (긴 검일수록 더 눕혀 걷기 중 땅에 닿지 않게 하고, 바깥으로 벌려 정면에서도 날이 보이게). 날은 X 로 넓고(두께 비 fw) 가운데 능선이 있다.
## grip = 주먹 위아래로 뻗는 손잡이 길이. 돌려주는 값 = 검 끝
static func _sword(g: CharGeo, hand_r: Vector3, sl: float, sw: float, gem: Color, guard_w: float, tilt_deg: float, out_deg: float,
		fw: float = 0.3, grip: float = 0.07) -> Vector3:
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var gr := deg_to_rad(tilt_deg)
	var og := deg_to_rad(out_deg)
	var d := Vector3(sin(gr) * sin(og), -cos(gr), -sin(gr) * cos(og))
	g.tube(hand_r - d * grip, hand_r + d * 0.05, sw * 0.3, sw * 0.3, Color("4a2f1c"), 6, false)
	g.sphere(hand_r - d * (grip + 0.012), sw * 0.5, GOLD, 7, 4)
	var guard_c := hand_r + d * 0.06
	g.rounded_box(guard_c, Vector3(guard_w, sw * 0.32, sw * 0.42), GOLD, 0.6, 8, 4, Basis(Vector3.RIGHT, d, Vector3.RIGHT.cross(d)))
	g.sphere(guard_c + d.cross(Vector3.RIGHT) * sw * 0.35, sw * 0.36, gem, 6, 4)
	var blade_end := hand_r + d * (0.075 + sl)
	g.tube(hand_r + d * 0.075, blade_end, sw, sw * 0.92, BLADE, 6, false, 1.0, fw)
	var tip := blade_end + d * sw * 2.6
	g.tube(blade_end, tip, sw * 0.92, 0.0, BLADE, 6, true, 1.0, fw)
	g.tube(hand_r + d * 0.09, blade_end - d * 0.02, sw * 0.3, sw * 0.22, BLADE.darkened(0.2), 4, false, 1.0, 1.25)
	g.measure = true
	g.measure_all = true
	return tip


## 작은 버클러(왼손 -X): 주먹 바깥쪽에 붙어 바깥·앞을 본다. out = 주먹 중심에서 바깥 면까지 거리. 가운데 금 별
static func _buckler(g: CharGeo, hand_l: Vector3, out: float, r_sh: float, field: Color, rim: Color, mark: Color) -> void:
	g.use("HandL")
	g.measure = false
	var nrm := Vector3(-0.86, -0.1, -0.5).normalized()
	var sc := hand_l + Vector3(-out - 0.01, r_sh * 0.25, -r_sh * 0.1)
	g.tube(sc - nrm * 0.02, sc + nrm * 0.01, r_sh * 1.08, r_sh * 1.08, rim, 14, true)
	g.tube(sc - nrm * 0.008, sc + nrm * 0.02, r_sh, r_sh, field, 14, true)
	var t1 := nrm.cross(Vector3.UP).normalized()
	var t2 := t1.cross(nrm).normalized()
	if t2.y < 0.0:
		t2 = -t2
	var fc := sc + nrm * 0.024
	var sb := Basis(t1, t2, nrm)
	g.polygon(CharGeo.star(5, r_sh * 0.62, r_sh * 0.27), fc, sb, 0.012, mark, GOLD_DARK)
	g.sphere(fc + nrm * 0.008, r_sh * 0.14, rim, 6, 4)
	g.measure = true


## 천 판(망토·뒷머리): 양면 천 + 아랫단·양옆 테두리 선(CharGeo.cape 와 같은 곡면 식으로 가장자리를 따라간다). 현재 뼈에 붙는다.
static func _cloth(g: CharGeo, top: Vector3, length: float, w_top: float, w_bot: float, col_out: Color, col_in: Color,
		hem: Color, drape: float, wrap: float, wave: float, edge_r: float, cols: int = 8, rows: int = 6) -> void:
	g.cape(top, length, w_top, w_bot, col_out, col_in, drape, wrap, wave, cols, rows)
	var pts: Array = []
	for j in 9:
		var u := float(j) / 8.0 - 0.5
		var y := top.y - length - wave * (0.5 + 0.5 * cos(u * TAU * 1.5))
		var z := top.z + drape - wrap * (u * u * 4.0)
		pts.append(Vector3(top.x + u * w_bot, y, z))
	g.sweep(pts, edge_r, hem, 4)
	for side: float in [-1.0, 1.0]:
		var edge: Array = []
		for i in 7:
			var t := float(i) / 6.0
			var w := lerpf(w_top, w_bot, t)
			var y := top.y - length * t - wave * t * t * (0.5 + 0.5 * cos(0.5 * TAU * 1.5))
			var z := top.z + drape * t * t - wrap * (0.3 + 0.7 * t)
			edge.append(Vector3(top.x + 0.5 * side * w, y, z))
		g.sweep(edge, edge_r * 0.8, hem, 4)


## 망토(2차 움직임 뼈 Cape)
static func _cape(g: CharGeo, top: Vector3, length: float, w_top: float, w_bot: float, col_out: Color, col_in: Color,
		hem: Color, drape: float, wrap: float, wave: float, edge_r: float) -> void:
	g.add_bone("Cape", "Spine", top)
	g.use("Cape")
	_cloth(g, top, length, w_top, w_bot, col_out, col_in, hem, drape, wrap, wave, edge_r)


## 기사단장 면갑 얼굴(CharGeo.face_parts 를 바탕으로 고쳐 씀): 면갑 표면(hc, hr)에 T자 틈을 파고 — 가로 눈 틈(납작한 띠)과
## 세로 턱 틈 — 틈 속에 작은 창백한 빛 눈 2개를 앞으로 살짝 내민다. 눈썹은 틈 윗변에 붙은 굵은 어두운 선이라
## 화난 표정이면 틈 자체가 찌푸린 모양이 된다. 눈꺼풀·입은 틈 색이라 눈이 감기면 빛이 꺼진 듯 보인다.
## 리그 규약대로 Eye/Pupil/Lid/Brow/Mouth 뼈를 모두 만든다.
static func _visor_face(g: CharGeo, hc: Vector3, hr: Vector3, es: float, ey: float, dx: float, slit: Color) -> void:
	var keep_line := g.line
	g.line = 0.0
	var glow := Color("fff4bd")
	var pupil := Color("f0b232")
	g.use("Head")
	# 가로 눈 틈: 면갑 곡면을 따라가는 납작한 어두운 띠(두께는 깊이의 0.35)
	var band: Array = []
	var band_r: Array = []
	for j in 9:
		var x := (float(j) / 8.0 - 0.5) * 0.215
		var y := ey - 0.002
		band.append(Vector3(x, y, CharGeo.surf_z(hc, hr, x, y) - 0.003))
		band_r.append(0.018)
	g.spline_tube(band, band_r, slit, 6, true, true, Vector3.BACK, 0.35, 1.0)
	# 세로 턱 틈
	var vert: Array = []
	var vert_r: Array = []
	for j in 5:
		var y := lerpf(ey - 0.012, 0.995, float(j) / 4.0)
		vert.append(Vector3(0, y, CharGeo.surf_z(hc, hr, 0.0, y) - 0.003))
		vert_r.append(0.011)
	g.spline_tube(vert, vert_r, slit, 6, true, true, Vector3.RIGHT, 1.0, 0.4)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var ex := dx * side
		var ez := CharGeo.surf_z(hc, hr, ex, ey) - 0.005
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez))
		g.use("Eye" + sfx)
		g.ellipsoid(Vector3(ex, ey, ez), Vector3(es * 1.45, es * 0.72, es * 0.6), glow, 8, 4)
		var pc := Vector3(ex - side * es * 0.1, ey - es * 0.05, ez - es * 0.3)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, pc)
		g.use("Pupil" + sfx)
		g.ellipsoid(pc, Vector3(es * 0.55, es * 0.5, es * 0.3), pupil, 6, 4)
		g.sphere(pc + Vector3(es * 0.2, es * 0.18, -es * 0.25), es * 0.14, Color.WHITE, 4, 3)
		# 윗눈꺼풀: 틈 색 반구 덮개. 뼈에서 Y 크기를 키우면 내려와 빛을 가린다
		var lid_p := Vector3(ex, ey + es * 0.9, ez + es * 0.1)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.5, es * 2.0, es * 0.8), slit, 6, 3, Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹 = 틈 윗변의 굵은 어두운 선
		var by := ey + es * 1.5
		var bz := ez - es * 0.1
		g.add_bone("Brow" + sfx, "Head", Vector3(ex, by, bz))
		g.use("Brow" + sfx)
		var bw := es * 2.3
		g.sweep([Vector3(ex - bw, by - es * 0.15, CharGeo.surf_z(hc, hr, ex - bw, by) - 0.007),
			Vector3(ex, by + es * 0.1, bz),
			Vector3(ex + bw, by - es * 0.15, CharGeo.surf_z(hc, hr, ex + bw, by) - 0.007)], es * 0.55, slit, 4)
	# 입 세 가지: 세로 틈 위의 작은 어두운 자국(표정마다 바뀌지만 면갑 속이라 거의 보이지 않는다)
	var my := 1.02
	var mz := CharGeo.surf_z(hc, hr, 0.0, my) - 0.006
	var mw := 0.022
	g.add_bone("MouthN", "Head", Vector3(0, my, mz))
	g.use("MouthN")
	g.ellipsoid(Vector3(0, my, mz), Vector3(mw * 0.45, mw * 0.2, mw * 0.25), slit, 6, 3)
	g.add_bone("MouthA", "Head", Vector3(0, my, mz))
	g.use("MouthA")
	g.ellipsoid(Vector3(0, my - mw * 0.1, mz), Vector3(mw * 0.7, mw * 0.4, mw * 0.3), slit, 6, 3)
	g.add_bone("MouthH", "Head", Vector3(0, my, mz))
	g.use("MouthH")
	g.ellipsoid(Vector3(0, my, mz), Vector3(mw * 0.4, mw * 0.45, mw * 0.3), slit, 6, 3)
	g.use("Head")
	g.line = keep_line


# ================================================================== 기사단장 번쩍경

static func _commander() -> Dictionary:
	var P := {ankle = 0.09, knee = 0.26, hip = 0.46, hip_x = 0.11, pelvis = 0.48, spine = 0.56,
		shoulder = 0.86, shoulder_x = 0.27, elbow = 0.69, wrist = 0.54, neck = 0.9, head = 0.95,
		arm_r = 0.06, leg_r = 0.066, foot_len = 0.24}
	var steel := Color("8e99a6")       # 몸 판금(짙은 무거운 강철, 컨셉 README)
	var steel_dk := Color("5f6873")    # 판금 그늘(위팔·허벅지·허리·목 가리개)
	var silver := Color("a9b2bb")      # 투구(몸보다 한 단계 밝게)
	var visor := Color("6e7885")       # 투구 창을 메우는 어두운 강철 면갑(그늘 속에서도 강철로 읽히게 조금 밝게)
	var slit := Color("14171c")        # 면갑 T자 틈
	var boot := Color("6b7580")        # 회색 강철 장화
	var sx: float = P.shoulder_x
	var ar: float = P.arm_r
	var wr: float = P.wrist
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	# ---- 몸통: 넓은 가슴판(둥근 상자) + 금 목테 + 마름모 문장, 허리, 벨트
	g.use("Spine")
	var cc := Vector3(0, 0.75, 0)
	var cr := Vector3(0.27, 0.17, 0.155)
	g.rounded_box(cc, cr, steel, 0.65, 14, 8)
	g.torus(Vector3(0, cc.y + cr.y * 0.8, 0), 0.115, 0.016, GOLD, 12, 5)
	var ez := cc.z - cr.z
	g.polygon(_diamond(0.06, 0.08), Vector3(0, cc.y - 0.005, ez - 0.006), Basis.IDENTITY, 0.018, GOLD, GOLD_DARK)
	g.ellipsoid(Vector3(0, cc.y - 0.005, ez - 0.016), Vector3(0.03, 0.045, 0.014), RED, 8, 4)
	# 가슴판 아래 가장자리 금 선
	g.torus(Vector3(0, cc.y - cr.y * 0.82, 0), 0.2, 0.012, GOLD, 14, 4, Basis.IDENTITY.scaled(Vector3(1.15, 1.0, 0.8)))
	g.tube(Vector3(0, float(P.spine) - 0.04, 0), Vector3(0, cc.y - cr.y * 0.35, 0), 0.15, 0.21, steel_dk, 12, false, 1.0, 0.8)
	var by := 0.565
	g.tube(Vector3(0, by - 0.026, 0), Vector3(0, by + 0.026, 0), 0.168, 0.168, Color("3a2a20"), 12, true)
	g.polygon(_diamond(0.045, 0.058), Vector3(0, by, -0.17), Basis.IDENTITY, 0.016, GOLD, GOLD_DARK)
	g.ellipsoid(Vector3(0, by, -0.18), Vector3(0.022, 0.03, 0.012), RED, 6, 4)
	# 목 가리개(고깃) + 금 테
	g.tube(Vector3(0, 0.84, 0), Vector3(0, 0.905, 0), 0.125, 0.095, steel_dk, 12, true)
	g.torus(Vector3(0, 0.9, 0), 0.095, 0.012, GOLD, 12, 4)
	# 가슴 앞 망토 걸쇠
	for side: float in [-1.0, 1.0]:
		g.sphere(Vector3(0.15 * side, 0.885, -0.1), 0.022, GOLD, 7, 4)
	g.use("Neck")
	g.tube(Vector3(0, 0.87, 0), Vector3(0, 1.0, 0), 0.07, 0.065, steel_dk, 8, false)
	# ---- 엉덩이·판금 치마(금 단)·앞 붉은 천
	g.use("Pelvis")
	g.ellipsoid(Vector3(0, 0.49, 0), Vector3(0.19, 0.09, 0.15), steel_dk, 10, 4)
	g.tube(Vector3(0, 0.545, 0), Vector3(0, 0.36, 0), 0.17, 0.235, steel, 12, false, 1.0, 0.78)
	g.tube(Vector3(0, 0.375, 0), Vector3(0, 0.35, 0), 0.236, 0.243, GOLD, 12, true, 1.0, 0.78)
	var tab := PackedVector2Array([Vector2(-0.05, 0.095), Vector2(0.05, 0.095), Vector2(0.075, -0.1), Vector2(-0.075, -0.1)])
	g.polygon(tab, Vector3(0, 0.45, -0.212), Basis(Vector3.RIGHT, 0.35), 0.012, RED, RED_DARK)
	# ---- 팔다리(건틀릿·무릎 금 띠·회색 강철 장화에 금 발목 띠)
	var hand_s := 1.45
	_limbs(g, P, {upper = steel_dk, elbow = steel, fore = steel, fore_flare = 1.25, cuff = GOLD, hand = steel_dk, hand_s = hand_s,
		thigh = steel_dk, knee = steel, knee_rim = GOLD, shin = steel, boot = boot, cuff_leg = GOLD, toe = boot, boot_s = 1.2})
	# ---- 큰 건틀릿(양손): 아래팔 끝의 넓은 통 소매(금 테) + 주먹 등의 금 띠와 손가락 마디 징. 왼손은 방패 없이 건틀릿만
	var fist_y := wr - ar * 0.8 * hand_s
	var fist_r := ar * 1.1 * hand_s
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Forearm" + sfx)
		g.tube(Vector3(x, wr + 0.12, 0), Vector3(x, wr + 0.02, 0), ar * 1.15, ar * 1.6, steel, 10, false)
		g.torus(Vector3(x, wr + 0.025, 0), ar * 1.58, 0.014, GOLD, 12, 4)
		g.use("Hand" + sfx)
		g.torus(Vector3(x, fist_y + fist_r * 0.35, -ar * 0.1), fist_r * 0.9, 0.012, GOLD, 12, 4)
		for k in 3:
			g.sphere(Vector3(x + float(k - 1) * fist_r * 0.5, fist_y + fist_r * 0.35, -ar * 0.1 - fist_r * 0.93), 0.016, GOLD, 6, 3)
	# ---- 어깨 갑옷: 머리보다 큰 둥근 돔(몸과 같은 강철색) + 금 테두리 + 위로 뻗은 가시(금 끝) + 앞 위쪽 금 걸쇠
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.use("Arm" + sfx)
		var pc := Vector3(sx * side + 0.055 * side, float(P.shoulder) + 0.01, 0)
		var pr := Vector3(0.19, 0.15, 0.18)
		g.ellipsoid(pc, pr, steel, 14, 6, Basis.IDENTITY, PI * 0.6, PI * 0.6)
		g.ellipsoid(pc, pr * 1.04, GOLD, 14, 1, Basis.IDENTITY, PI * 0.61, PI * 0.61, PI * 0.53)
		g.horn(pc + Vector3(0.075 * side, 0.12, 0), Vector3(0.45 * side, 1.0, 0).normalized(), Vector3(0.3 * side, 0, 0), 0.14, 0.034, steel, 5, 8, GOLD)
		g.sphere(pc + Vector3(-0.05 * side, 0.1, -0.13), 0.03, GOLD, 7, 4)
		g.sphere(pc + Vector3(-0.05 * side, 0.1, -0.158), 0.012, RED, 5, 3)
	# ---- 망토(붉은 천, 짙은 안감, 금 단·옆 테): 어깨 갑옷 밖까지 넓어 정면에서도 양옆 빨강이 보인다
	_cape(g, Vector3(0, 0.95, 0.165), 0.82, 0.8, 1.1, RED, RED_DARK, GOLD, 0.03, 0.16, 0.03, 0.014)
	# ---- 투구 돔(얼굴 창만 트임, 옆·뒤는 턱 높이까지) + 창을 메우는 어두운 강철 면갑
	g.use("Head")
	var hc2 := Vector3(0, 1.125, 0.007)
	var hr2 := Vector3(0.2, 0.19, 0.2)
	var hc := hc2 + Vector3(0, -0.01, 0)
	var hr := hr2 * 0.93
	g.ellipsoid(hc, hr, visor, 14, 8)
	var lat_f := 1.22
	var lat_b := 2.75
	g.ellipsoid(hc2, hr2, silver, 14, 7, Basis.IDENTITY, lat_f, lat_b)
	# ---- 얼굴: 면갑의 T자 틈과 틈 속 작은 빛 눈
	var es := 0.021
	var ey := 1.1
	_visor_face(g, hc, hr, es, ey, 0.054, slit)
	# ---- 투구 장식: 창 테두리 금 선, 뺨 가리개, 돔 표면을 따라가는 금 눈썹 바(이마 능선 위), 귀 원판
	var lon_bar := 0.95
	var rim: Array = []
	for j in 11:
		var lon := lon_bar + (TAU - 2.0 * lon_bar) * float(j) / 10.0
		var lat := lerpf(lat_b, lat_f, (1.0 + cos(lon)) * 0.5)
		rim.append(_hp(hc2, hr2, lat, lon, 1.01))
	g.sweep(rim, 0.016, GOLD, 4)
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(Vector3(0.158 * side, hc2.y - 0.07, hc2.z - 0.045), Vector3(0.05, 0.1, 0.085), silver, 8, 5)
	# 눈썹 바: 창 위 가장자리(돔 표면)를 그대로 따라가는 굵은 금 능선, 양 끝은 뺨 가리개 속으로 들어간다
	var bar: Array = []
	for j in 7:
		var lon := (float(j) / 6.0 - 0.5) * 2.0 * lon_bar
		var lat := lerpf(lat_b, lat_f, (1.0 + cos(lon)) * 0.5) - 0.02
		bar.append(_hp(hc2, hr2, lat, lon, 1.0))
	g.sweep(bar, 0.022, GOLD, 5)
	for side: float in [-1.0, 1.0]:
		g.torus(Vector3(hr2.x * 0.98 * side, hc2.y - 0.01, hc2.z), 0.04, 0.013, GOLD, 10, 4, Basis(Vector3.BACK, PI * 0.5))
	# ---- 크레스트(2차 움직임 뼈 Plume): 투구 이마에서 꼭대기를 넘어 목덜미까지 뒤로 휘어지는 두툼한 솔 모양 붉은 깃
	var plume_base := _hp(hc2, hr2, 0.9, 0.0, 1.0)
	g.add_bone("Plume", "Head", plume_base)
	g.use("Plume")
	g.measure = false
	var arc: Array = [Vector3(0, -0.015, 0.0), Vector3(0, 0.08, 0.02), Vector3(0, 0.17, 0.08), Vector3(0, 0.2, 0.17),
		Vector3(0, 0.16, 0.27), Vector3(0, 0.06, 0.36), Vector3(0, -0.13, 0.41)]
	var pts: Array = []
	for p: Vector3 in arc:
		pts.append(plume_base + p)
	g.spline_tube(pts, [0.04, 0.072, 0.085, 0.086, 0.08, 0.065, 0.028], CREST, 12, true, true, Vector3.RIGHT, 1.0, 1.2)
	g.measure = true
	# ---- 무기: 기사 검(0.46)의 1.3배쯤 되는 굵고 긴 대검(붉은 보석). 주먹에 쥐고 날을 앞·아래로 기울인다
	var hand_r := Vector3(sx, fist_y, -ar * 0.1)
	var tip := _sword(g, hand_r, 0.62, 0.058, RED, 0.19, 42.0, 16.0, 0.32, 0.1)
	return _finish(g, tip, es, P)


# ================================================================== 용사 루루

static func _hero() -> Dictionary:
	var P := {ankle = 0.08, knee = 0.27, hip = 0.47, hip_x = 0.075, pelvis = 0.49, spine = 0.57,
		shoulder = 0.84, shoulder_x = 0.2, elbow = 0.69, wrist = 0.55, neck = 0.88, head = 0.93,
		arm_r = 0.042, leg_r = 0.045, foot_len = 0.19}
	var skin := Color("f3dcc7")
	var hair := Color("f0c040")
	var hair_dk := Color("c48f22")     # 머리카락 안쪽·아랫면
	var blue := Color("3d6fd6")        # 상의·소매·치마 단(컨셉 README)
	var blue_dk := Color("2f55b0")
	var navy_dk := Color("1f2a5e")     # 베레모·리본
	var white := Color("dfe6ee")       # 치마·스타킹
	var silver := Color("c3ccd6")
	var cloak := Color("5a4a8a")       # 보라 망토(컨셉 README)
	var cloak_in := Color("7b6bb3")
	var cream := Color("e8d9b8")
	var sx: float = P.shoulder_x
	var g := CharGeo.new()
	CharGeo.skeleton(g, P)
	var hc := Vector3(0, 1.105, -0.005)
	var hr := Vector3(0.165, 0.16, 0.16)
	# ---- 몸통: 파란 상의, 흰 깃, 은 가슴판 + 금 별, 허리, 금 벨트, 깃의 금 브로치(파란 보석)
	g.use("Spine")
	var cc := Vector3(0, 0.72, 0)
	var cr := Vector3(0.16, 0.13, 0.12)
	g.ellipsoid(cc, cr, blue, 12, 6)
	g.ellipsoid(Vector3(0, 0.735, -0.035), Vector3(0.125, 0.1, 0.1), silver, 12, 6)
	g.polygon(CharGeo.star(4, 0.034, 0.013), Vector3(0, 0.79, -0.139), Basis.IDENTITY, 0.012, GOLD, GOLD_DARK)
	g.torus(Vector3(0, 0.845, 0), 0.07, 0.02, white, 12, 5)
	g.sphere(Vector3(0, 0.84, -0.092), 0.026, GOLD, 8, 4)
	g.sphere(Vector3(0, 0.84, -0.113), 0.012, Color("4fc3f7"), 6, 3)
	g.tube(Vector3(0, float(P.spine) - 0.03, 0), Vector3(0, cc.y - cr.y * 0.3, 0), 0.1, 0.14, blue, 10, false)
	var by := 0.585
	g.torus(Vector3(0, by, 0), 0.108, 0.015, GOLD, 12, 5)
	g.polygon(_diamond(0.03, 0.038), Vector3(0, by, -0.125), Basis.IDENTITY, 0.014, GOLD, GOLD_DARK)
	g.use("Neck")
	g.tube(Vector3(0, 0.85, 0), Vector3(0, 0.98, 0), 0.05, 0.048, skin, 8, false)
	# ---- 치마: 흰 긴 치마 + 파란 단(금 선) + 벨트에서 내려오는 짧은 파란 앞 자락(금 테)
	g.use("Pelvis")
	g.ellipsoid(Vector3(0, 0.5, 0), Vector3(0.13, 0.07, 0.1), blue, 10, 4)
	g.tube(Vector3(0, 0.56, 0), Vector3(0, 0.1, 0), 0.125, 0.27, white, 14, false, 1.0, 0.78)
	g.tube(Vector3(0, 0.16, 0), Vector3(0, 0.095, 0), 0.255, 0.276, blue, 14, true, 1.0, 0.78)
	g.tube(Vector3(0, 0.1, 0), Vector3(0, 0.08, 0), 0.272, 0.278, GOLD, 14, true, 1.0, 0.78)
	var panel := PackedVector2Array([Vector2(-0.05, 0.13), Vector2(0.05, 0.13), Vector2(0.085, -0.13), Vector2(-0.085, -0.13)])
	g.polygon(panel, Vector3(0, 0.44, -0.14), Basis(Vector3.RIGHT, 0.22), 0.016, blue_dk, GOLD)
	# ---- 팔다리: 파란 소매, 금 손목 띠, 피부색 맨손(작게), 흰 스타킹, 크림색 장화(금 발끝)
	var hand_s := 1.0
	_limbs(g, P, {upper = blue, elbow = blue, fore = blue, fore_flare = 1.15, cuff = GOLD, hand = skin, hand_s = hand_s,
		thigh = white, knee = white, shin = white, boot = cream, cuff_leg = GOLD, toe = GOLD, boot_s = 1.0})
	# ---- 작은 은 어깨 갑옷(금 테)
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.use("Arm" + sfx)
		var pc := Vector3(sx * side + 0.025 * side, float(P.shoulder) + 0.005, 0)
		var pr := Vector3(0.085, 0.065, 0.085)
		g.ellipsoid(pc, pr, silver, 10, 4, Basis.IDENTITY, PI * 0.6, PI * 0.6)
		g.ellipsoid(pc, pr * 1.04, GOLD, 10, 1, Basis.IDENTITY, PI * 0.61, PI * 0.61, PI * 0.52)
	# ---- 망토(보라, 밝은 보라 안감, 금 단): 어깨 밖 0.15 까지 넓게, 치맛단 바로 위까지. 옆은 몸을 감싸 3/4·옆에서도 보인다
	_cape(g, Vector3(0, 0.875, 0.05), 0.76, 0.7, 0.84, cloak, cloak_in, GOLD, 0.05, 0.12, 0.02, 0.01)
	# ---- 머리·얼굴: 크고 파란 눈, 가는 따뜻한 갈색 눈썹, 작은 입, 볼 홍조, 피부색 작은 코
	g.use("Head")
	g.ellipsoid(hc, hr, skin, 14, 9)
	var es := 0.044
	var ey := 1.1
	CharGeo.face(g, {hc = hc, hr = hr, es = es, eye_y = ey, eye_dx = 0.066, mouth_y = 1.025, mouth_w = 0.042,
		skin = skin, pupil = Color("3f7de0"), pupil_core = Color("1c2a5c"), iris = 1.1, eye_rim = Color("2a2338"),
		shine = 1.0, lash = Color("4a3520"), lid = skin.darkened(0.05), brow = Color("8a5a2a"), brow_w = 0.95, brow_t = 0.5,
		blush = Color("f4a9a0")})
	g.use("Head")
	var ny := ey - es * 1.3
	var keep_line := g.line
	g.line = 0.0
	g.ellipsoid(Vector3(0, ny, CharGeo.surf_z(hc, hr, 0, ny) - 0.004), Vector3(0.012, 0.011, 0.012), skin, 8, 4)
	g.line = keep_line
	# ---- 머리카락(한 덩어리): 베레모 아래 두개골 머리 덮개 + 이마 위 물결 앞머리 3갈래(가운데 짧고 굵게, 바깥은 관자놀이까지)
	g.ellipsoid(hc + Vector3(0, 0.01, 0.012), hr * 1.1, hair, 14, 8, Basis.IDENTITY, 0.95, 2.85)
	g.line = 0.7
	var lobe_lon: Array = [-0.8, 0.0, 0.8]
	var lobe_end: Array = [1.1, 0.95, 1.1]
	var lobe_r: Array = [[0.03, 0.05, 0.038], [0.034, 0.056, 0.042], [0.03, 0.05, 0.038]]
	for i in lobe_lon.size():
		var lon: float = lobe_lon[i]
		var le: float = lobe_end[i]
		var bang: Array = [_hp(hc, hr, 0.45, lon * 0.4, 1.08), _hp(hc, hr, lerpf(0.45, le, 0.55), lon * 0.8, 1.11), _hp(hc, hr, le, lon, 1.1)]
		g.spline_tube(bang, lobe_r[i], hair, 8, false, true)
	# 옆 가닥: 관자놀이에서 어깨 앞으로 내려오는 가는 가닥 하나씩(깊이가 얇아 옆에서 얼굴을 가리지 않는다)
	for side: float in [-1.0, 1.0]:
		var a: Array = [Vector3(0.15 * side, 1.09, -0.06), Vector3(0.2 * side, 0.96, -0.095), Vector3(0.195 * side, 0.82, -0.115),
			Vector3(0.205 * side, 0.7, -0.105), Vector3(0.225 * side, 0.6, -0.085)]
		g.spline_tube(a, [0.028, 0.038, 0.035, 0.028, 0.01], hair, 8, true, true, Vector3.RIGHT, 1.0, 0.75)
	# 뒷머리: 목덜미 묶음(둥근 덩어리)에서 허리까지 흘러내리는 넓은 머리 판(겉은 금발, 안쪽은 그늘색, 단은 물결).
	# 머리를 돌려도 몸에 남도록 Spine 뼈에 붙인다(쓰러질 때 땅에 묻히지 않게).
	g.use("Spine")
	g.ellipsoid(Vector3(0, 0.985, 0.095), Vector3(0.15, 0.1, 0.085), hair, 12, 5)
	var ht := Vector3(0, 1.06, 0.125)
	var hl := 0.6
	_cloth(g, ht, hl, 0.27, 0.38, hair, hair_dk, hair_dk, 0.03, 0.14, 0.06, 0.012, 8, 6)
	# 판 겉면 위의 물결 가닥 능선 3개(판과 같은 곡면 식을 따라가며 좌우로 살짝 흔들리고, 둥근 끝이 단 아래로 나와 물결 단을 만든다)
	for u: float in [-0.3, 0.0, 0.3]:
		var ridge: Array = []
		var rr: Array = []
		for i in 6:
			var t := float(i) / 5.0
			var w := lerpf(0.27, 0.38, t)
			var uu := u + 0.06 * sin(t * TAU + u * 4.0) * t
			var y := ht.y - hl * t - 0.025 * t * t
			var z := ht.z + 0.03 * t * t - 0.14 * (uu * uu * 4.0) * (0.3 + 0.7 * t) + 0.012
			ridge.append(Vector3(uu * w, y, z))
			rr.append(0.03 if i < 5 else 0.014)
		g.spline_tube(ridge, rr, hair, 7, false, true, Vector3.RIGHT, 1.3, 0.8)
	# 리본: 묶음 뒤의 남색 리본(두 고리 + 금 매듭 + 두 꼬리)
	var kn := Vector3(0, 0.995, 0.175)
	for side: float in [-1.0, 1.0]:
		g.ellipsoid(kn + Vector3(0.05 * side, 0.015, -0.005), Vector3(0.045, 0.028, 0.016), navy_dk, 8, 4, Basis(Vector3.BACK, 0.35 * side))
		g.spline_tube([kn + Vector3(0.015 * side, -0.01, 0), kn + Vector3(0.04 * side, -0.07, 0.01), kn + Vector3(0.055 * side, -0.13, 0.005)],
			[0.012, 0.016, 0.004], navy_dk, 6, false, true, Vector3.RIGHT, 1.6, 0.6)
	g.sphere(kn, 0.02, GOLD, 7, 4)
	g.line = keep_line
	g.use("Head")
	# ---- 베레모: 위로 살짝 솟은 남색 돔(살짝 뒤로 기울임), 금 띠, 앞 금 장식, 좁고 휘어진 작은 붉은 깃털 하나(2차 움직임 뼈 Plume)
	g.rounded_box(hc + Vector3(0, 0.15, 0.015), Vector3(0.19, 0.1, 0.19), navy_dk, 0.85, 14, 7, Basis(Vector3.RIGHT, 0.12))
	g.torus(hc + Vector3(0, 0.125, 0.015), 0.17, 0.014, GOLD, 14, 5)
	g.sphere(hc + Vector3(0, 0.13, -0.165), 0.02, GOLD, 7, 4)
	g.sphere(hc + Vector3(0, 0.13, -0.18), 0.011, Color("4fc3f7"), 6, 3)
	var plume_base := hc + Vector3(0, 0.225, 0.02)
	g.add_bone("Plume", "Head", plume_base)
	g.use("Plume")
	g.measure = false
	var feather: Array = []
	for p: Vector3 in [Vector3(0, -0.02, 0), Vector3(0.01, 0.05, 0.02), Vector3(0.02, 0.09, 0.06), Vector3(0.03, 0.1, 0.1)]:
		feather.append(plume_base + p)
	g.spline_tube(feather, [0.018, 0.028, 0.022, 0.0], CREST, 8, true, true, Vector3.RIGHT, 1.0, 0.6)
	g.measure = true
	# ---- 무기: 굵은 검(파란 보석), 주먹 바깥의 작은 별 버클러(파란 바탕, 은 테, 금 별)
	var hand_r := Vector3(sx, float(P.wrist) - float(P.arm_r) * 0.8 * hand_s, -float(P.arm_r) * 0.1)
	var tip := _sword(g, hand_r, 0.55, 0.05, Color("4fc3f7"), 0.13, 30.0, 0.0, 0.3, 0.07)
	_buckler(g, Vector3(-sx, hand_r.y, hand_r.z), float(P.arm_r) * 1.1 * hand_s, 0.075, blue_dk, silver, GOLD)
	return _finish(g, tip, es, P)
