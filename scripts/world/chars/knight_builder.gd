class_name KnightBuilder
extends RefCounted
## 인간 기사 5종의 외형 명세. 몸은 HumanBuilder.build() 로 만든다


## 기사 변형 5종: 키 배율(±5%), 깃털 색, 방패 무늬, 투구 모양, 피부색
const SCALE := [1.0, 1.05, 0.95, 1.03, 0.97]
const PLUME := ["d8333a", "f4efe4", "e8742e", "3b6fd4", "c8343a"]
const SHIELD := ["plain", "cross", "band", "ring", "stripes"]
const HELMET := ["round", "pointed", "crest", "visor", "brim"]
const SKIN := ["f2c9a0", "e6b088", "f6d6b8", "d9a27a", "efc29a"]


static func build(v: int) -> Dictionary:
	return HumanBuilder.build(spec(v))


static func spec(v: int) -> Dictionary:
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
		skin = Color(SKIN[v]),
		chest = Models.SILVER, chest_c = Vector3(0, 0.65, 0), chest_r = Vector3(0.205, 0.135, 0.135),
		waist = Color("7d8792"), waist_r = Vector2(0.092, 0.13), belt_y = 0.515,
		skirt = Models.RED, skirt_y = Vector2(0.52, 0.37), skirt_r = Vector2(0.115, 0.15),
		trouser = Color("6d6a78"), armor = Models.SILVER, armor_dark = Models.SILVER_DARK, trim = Models.GOLD,
		boot = Models.BOOT, glove = Color("8a5530"),
		pauldron = Vector3(0.13, 0.1, 0.13),
		cape = Color("b02a32"), cape_len = 0.36, cape_w = Vector2(0.12, 0.16),
		helmet = HELMET[v], plumes = [Color(PLUME[v])], plume_size = 1.0,
		shield = SHIELD[v], shield_r = 0.255, shield_c = Models.RED, shield_rim = Models.GOLD, shield_mark = Models.GOLD,
		sword_len = 0.46, sword_w = 0.038, mustache = (v == 3),
	}
