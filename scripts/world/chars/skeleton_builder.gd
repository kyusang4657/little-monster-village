class_name SkeletonBuilder
extends RefCounted
## 해골 궁수(4차 유닛)의 외형 명세. 몸은 HumanBuilder.build() 로 만든다


static func build() -> Dictionary:
	return HumanBuilder.build(spec())


static func spec() -> Dictionary:
	var s := KnightBuilder.spec(0)
	s.merge({
		skin = Color("ece6d6"), chest = Color("5b5662"), waist = Color("ece6d6"), trouser = Color("4a4552"),
		skirt = Color("3f3a48"), armor = Color("ece6d6"), armor_dark = Color("cfc6b2"), trim = Color("8a6a9e"),
		glove = Color("ece6d6"), boot = Color("4a4552"), pauldron = Vector3(0.09, 0.07, 0.09),
		cape = Color("3f3a48"), cape_len = 0.22, helmet = "round", plumes = [], mustache = false,
		weapon = "bow", pupil = Color("e04848"), no_blush = true, ribs = true, hand_s = 1.0, boot_s = 1.0,
	}, true)
	return s
