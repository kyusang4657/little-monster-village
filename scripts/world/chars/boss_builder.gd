class_name BossBuilder
extends RefCounted
## 보스 2종(용사 "hero", 기사단장 "commander")의 외형 명세. 몸은 HumanBuilder.build() 로 만든다


static func build(k: String) -> Dictionary:
	return HumanBuilder.build(spec(k))


static func spec(k: String) -> Dictionary:
	var s := {
		H = 1.3,
		P = {
			ankle = 0.09, knee = 0.27, hip = 0.49, hip_x = 0.095, pelvis = 0.505, spine = 0.57,
			shoulder = 0.84, shoulder_x = 0.235, elbow = 0.67, wrist = 0.515, neck = 0.87, head = 0.92,
			arm_r = 0.052, leg_r = 0.057, foot_len = 0.22,
		},
		hc = Vector3(0, 1.112, -0.005), hr = Vector3(0.165, 0.158, 0.16),
		hand_s = 1.4, boot_s = 1.22,
		es = 0.032, eye_dx = 0.06, eye_y = 1.092, mouth_y = 1.03, mouth_w = 0.072,
		skin = Color("f2c9a0"),
		chest_c = Vector3(0, 0.755, 0), chest_r = Vector3(0.24, 0.155, 0.15),
		waist_r = Vector2(0.11, 0.15), belt_y = 0.6,
		skirt_y = Vector2(0.6, 0.42), skirt_r = Vector2(0.13, 0.175),
		boot = Color("5a3418"), glove = Color("6b3f1f"),
		cape_len = 0.56, cape_w = Vector2(0.14, 0.21),
		sword_len = 0.58, sword_w = 0.042, mustache = false,
	}
	if k == "hero":
		s.merge({
			chest = Color("dfe6ee"), waist = Color("3d6fd6"), skirt = Color("3d6fd6"), trouser = Color("2f3f6a"),
			armor = Color("dfe6ee"), armor_dark = Color("9fb0c2"), trim = Models.GOLD,
			pauldron = Vector3(0.14, 0.105, 0.14), cape = Color("2f55b0"), cape_hem = Models.GOLD,
			helmet = "", hair = Color("f0c040"), circlet = true, plumes = [],
			shield = "star", shield_r = 0.27, shield_c = Color("3a5fb8"), shield_rim = Color("dfe6ee"), shield_mark = Models.GOLD,
			gem = Color("4fc3f7"),
		}, true)
	else:
		s.merge({
			chest = Color("8e99a6"), waist = Color("5c6570"), skirt = Color("8f1f27"), trouser = Color("4a4552"),
			armor = Color("8e99a6"), armor_dark = Color("5c6570"), trim = Models.GOLD,
			pauldron = Vector3(0.16, 0.12, 0.16), spikes = true, cape = Color("a3242c"), cape_hem = Models.GOLD,
			helmet = "crest", plumes = [Color("d8333a"), Color("f4efe4")], plume_size = 1.2,
			shield = "crown", shield_r = 0.3, shield_c = Color("b52a33"), shield_rim = Models.GOLD, shield_mark = Models.GOLD,
			mustache = true, gem = Color("e04848"),
		}, true)
	return s
