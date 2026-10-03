class_name Models
extends RefCounted
## 아트 가이드의 고정 구조를 지킨 임시 입체 모델. 기준점 = 점유 영역 지면 중앙, 정면 = -Z.
## 캐릭터의 '오른손'은 캐릭터 자신의 오른쪽(+X, 정면 -Z 기준)이다.

const IVORY := Color("eadfc6")
const IVORY_DARK := Color("cfc0a0")
const STONE := Color("bdb6a8")
const STONE_DARK := Color("9a9387")
const PURPLE := Color("7a4bc4")
const PURPLE_DARK := Color("5b3497")
const TEAL := Color("2fa4a0")
const WOOD := Color("c98a45")
const WOOD_DARK := Color("8f5a2b")
const WOOD_LIGHT := Color("e9c48a")
const CREAM := Color("f3e6c4")
const GLASS := Color("ffd76a")
const GLASS_DARK := Color("4a3b6b")
const GOLD := Color("e1b23c")
const GOBLIN_SKIN := Color("8cc63f")
const GOBLIN_SKIN_DARK := Color("6aa22c")
const TUNIC := Color("7d4cc2")
const SHORTS := Color("e3cfa2")
const BOOT := Color("7a4a26")
const HAIR := Color("6b3f1f")
const BRASS := Color("c9a24a")
const SILVER := Color("cfd6de")
const SILVER_DARK := Color("98a3ae")
const RED := Color("c8343a")
const SKIN := Color("f2c9a0")
const BLACK := Color("2b2233")
const WHITE := Color("ffffff")


static func build(type: String) -> Node3D:
	match type:
		"castle":
			return castle()
		"house":
			return house()
		"lumber_camp":
			return lumber_camp()
		"defense_tower":
			return defense_tower()
	return Node3D.new()


static func _root(n: String) -> Node3D:
	var r := Node3D.new()
	r.name = n
	return r


static func _emblem(b: MeshBatch, pos: Vector3, facing_z: float, s: float = 1.0) -> void:
	# 깃발의 해골 문양을 단순화: 아이보리 머리 + 두 뿔 + 눈
	b.sphere(0.09 * s, pos, IVORY, Vector3(1, 0.9, 0.35))
	b.cyl(0.0, 0.035 * s, 0.1 * s, pos + Vector3(0.08 * s, 0.07 * s, 0), IVORY, Vector3(0, 0, -35))
	b.cyl(0.0, 0.035 * s, 0.1 * s, pos + Vector3(-0.08 * s, 0.07 * s, 0), IVORY, Vector3(0, 0, 35))
	b.sphere(0.022 * s, pos + Vector3(0.035 * s, 0.01, facing_z * 0.03), PURPLE_DARK)
	b.sphere(0.022 * s, pos + Vector3(-0.035 * s, 0.01, facing_z * 0.03), PURPLE_DARK)


# ------------------------------------------------------------------ 마물 성 (3×3)
static func castle() -> Node3D:
	var r := _root("Castle")
	var b := MeshBatch.new()
	b.box(Vector3(2.9, 0.12, 2.9), Vector3(0, 0.06, 0), STONE)
	# 낮고 넓은 본관 + 평평한 지붕 테라스
	b.box(Vector3(2.3, 1.05, 1.9), Vector3(0, 0.645, 0.2), IVORY)
	b.box(Vector3(2.42, 0.1, 2.02), Vector3(0, 1.2, 0.2), IVORY_DARK)
	for i in 6:
		var x := -1.05 + i * 0.42
		b.box(Vector3(0.22, 0.18, 0.14), Vector3(x, 1.34, 1.15), IVORY)
	for i in 4:
		var z := -0.55 + i * 0.5
		b.box(Vector3(0.14, 0.18, 0.22), Vector3(1.15, 1.34, z), IVORY)
		b.box(Vector3(0.14, 0.18, 0.22), Vector3(-1.15, 1.34, z), IVORY)
	b.box(Vector3(1.2, 0.18, 0.14), Vector3(0, 1.34, -0.75), IVORY)
	# 정면 양 모서리의 원형 탑 두 개만
	for sx in [-1.0, 1.0]:
		var p := Vector3(1.0 * sx, 0, -0.78)
		b.cyl(0.44, 0.48, 1.7, p + Vector3(0, 0.97, 0), IVORY)
		b.cyl(0.5, 0.5, 0.1, p + Vector3(0, 1.84, 0), IVORY_DARK)
		b.cyl(0.0, 0.56, 0.8, p + Vector3(0, 2.29, 0), PURPLE)
		b.sphere(0.07, p + Vector3(0, 2.72, 0), GOLD)
		# 탑 정면 보라 깃발과 문양
		b.box(Vector3(0.36, 0.55, 0.04), p + Vector3(0, 1.0, -0.47), PURPLE)
		b.prism(Vector3(0.36, 0.12, 0.04), p + Vector3(0, 0.67, -0.47), PURPLE, Vector3(0, 0, 180))
		_emblem(b, p + Vector3(0, 1.05, -0.5), -1.0, 1.1)
		b.box(Vector3(0.1, 0.18, 0.04), p + Vector3(0.48 * sx, 1.4, 0), GLASS_DARK, Vector3(0, 90 * sx, 0))
	# 청록 양문과 두 단 계단
	b.box(Vector3(0.74, 0.62, 0.08), Vector3(0, 0.5, -0.76), TEAL)
	b.cyl(0.37, 0.37, 0.08, Vector3(0, 0.81, -0.76), TEAL, Vector3(90, 0, 0), 16)
	b.box(Vector3(0.84, 0.08, 0.06), Vector3(0, 0.81, -0.77), IVORY_DARK)
	b.box(Vector3(0.03, 0.88, 0.1), Vector3(0, 0.6, -0.8), Color("1f7a77"))
	b.sphere(0.035, Vector3(0.09, 0.5, -0.82), GOLD)
	b.sphere(0.035, Vector3(-0.09, 0.5, -0.82), GOLD)
	b.box(Vector3(1.1, 0.08, 0.28), Vector3(0, 0.16, -0.92), STONE)
	b.box(Vector3(1.3, 0.08, 0.3), Vector3(0, 0.08, -1.08), STONE_DARK)
	# 옆면 창 하나씩, 후면 창 두 개
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.06, 0.32, 0.24), Vector3(1.16 * sx, 0.75, 0.35), GLASS_DARK)
	for x in [-0.5, 0.5]:
		b.box(Vector3(0.24, 0.32, 0.06), Vector3(x, 0.75, 1.16), GLASS_DARK)
	# 지붕 뒤 중앙 작은 깃대(중앙 탑 아님)
	b.cyl(0.025, 0.025, 0.8, Vector3(0, 1.65, 0.85), WOOD_DARK)
	b.box(Vector3(0.36, 0.22, 0.02), Vector3(0.19, 1.92, 0.85), PURPLE)
	r.add_child(b.instance("Body"))
	return r


# ------------------------------------------------------------------ 고블린 주택 (2×2)
static func house() -> Node3D:
	var r := _root("House")
	var b := MeshBatch.new()
	b.box(Vector3(1.72, 0.1, 1.6), Vector3(0, 0.05, 0), STONE)
	b.box(Vector3(1.4, 0.85, 1.25), Vector3(0, 0.525, 0.05), CREAM)
	# 목재 프레임
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0.11, 0.88, 0.11), Vector3(0.7 * sx, 0.54, 0.05 + 0.625 * sz), WOOD)
	b.box(Vector3(1.5, 0.09, 0.1), Vector3(0, 0.96, -0.58), WOOD)
	b.box(Vector3(1.5, 0.09, 0.1), Vector3(0, 0.96, 0.68), WOOD)
	b.box(Vector3(0.1, 0.09, 1.35), Vector3(0.71, 0.96, 0.05), WOOD)
	b.box(Vector3(0.1, 0.09, 1.35), Vector3(-0.71, 0.96, 0.05), WOOD)
	# 보라색 맞배지붕(용마루가 앞뒤 방향, 박공이 정면)
	b.prism(Vector3(1.38, 0.55, 1.25), Vector3(0, 1.27, 0.05), CREAM)
	b.prism(Vector3(1.8, 0.7, 1.55), Vector3(0, 1.33, 0.05), PURPLE)
	b.box(Vector3(0.08, 0.06, 1.6), Vector3(0, 1.69, 0.05), PURPLE_DARK)
	# 박공의 둥근 다락창
	b.cyl(0.11, 0.11, 0.04, Vector3(0, 1.2, -0.58), WOOD_DARK, Vector3(90, 0, 0), 14)
	b.cyl(0.08, 0.08, 0.05, Vector3(0, 1.2, -0.59), GLASS, Vector3(90, 0, 0), 14)
	# 정면 중앙 아치형 나무문과 낮은 계단
	b.box(Vector3(0.36, 0.42, 0.05), Vector3(0, 0.33, -0.58), WOOD_DARK)
	b.cyl(0.18, 0.18, 0.05, Vector3(0, 0.54, -0.58), WOOD_DARK, Vector3(90, 0, 0), 14)
	b.sphere(0.025, Vector3(0.1, 0.35, -0.62), GOLD)
	b.box(Vector3(0.6, 0.08, 0.22), Vector3(0, 0.12, -0.72), STONE_DARK)
	# 문 양옆 창문
	for x in [-0.45, 0.45]:
		b.box(Vector3(0.28, 0.28, 0.04), Vector3(x, 0.6, -0.58), WOOD)
		b.box(Vector3(0.2, 0.2, 0.05), Vector3(x, 0.6, -0.59), GLASS)
	# 오른쪽 면(정면을 바라보는 사람의 오른쪽 = -X) 창 두 개
	for z in [-0.25, 0.35]:
		b.box(Vector3(0.04, 0.26, 0.24), Vector3(-0.71, 0.6, z), WOOD)
		b.box(Vector3(0.05, 0.19, 0.17), Vector3(-0.72, 0.6, z), GLASS)
	# 후면 창 하나
	b.box(Vector3(0.26, 0.26, 0.04), Vector3(0, 0.6, 0.69), WOOD)
	b.box(Vector3(0.19, 0.19, 0.05), Vector3(0, 0.6, 0.7), GLASS)
	# 굴뚝: 뒤쪽 오른쪽 하나(정면에서 보면 오른쪽, 후면에서 보면 왼쪽)
	b.box(Vector3(0.24, 0.6, 0.24), Vector3(-0.42, 1.5, 0.42), STONE)
	b.box(Vector3(0.3, 0.08, 0.3), Vector3(-0.42, 1.82, 0.42), STONE_DARK)
	r.add_child(b.instance("Body"))
	return r


# ------------------------------------------------------------------ 벌목소 (2×2)
static func lumber_camp() -> Node3D:
	var r := _root("LumberCamp")
	var b := MeshBatch.new()
	# 네 목조 기둥과 돌 받침. 뒤가 높고 앞이 낮다.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var h := 1.3 if sz > 0 else 0.95
			var p := Vector3(0.74 * sx, 0, 0.6 * sz)
			b.box(Vector3(0.24, 0.14, 0.24), p + Vector3(0, 0.07, 0), STONE)
			b.box(Vector3(0.13, h, 0.13), p + Vector3(0, 0.14 + h * 0.5, 0), WOOD)
	var ang := rad_to_deg(atan2(1.3 - 0.95, 1.2))
	b.box(Vector3(1.9, 0.08, 1.62), Vector3(0, 0.14 + 1.125 + 0.06, 0), PURPLE, Vector3(-ang, 0, 0))
	b.box(Vector3(1.9, 0.05, 0.1), Vector3(0, 0.14 + 0.95 + 0.0, -0.8), PURPLE_DARK, Vector3(-ang, 0, 0))
	# 뒤쪽에만 낮은 판자 벽
	for i in 3:
		b.box(Vector3(1.48, 0.16, 0.05), Vector3(0, 0.25 + i * 0.18, 0.62), WOOD_DARK if i % 2 == 0 else WOOD)
	# 정면 기준 왼쪽(+X) 작업대
	b.box(Vector3(0.55, 0.08, 0.36), Vector3(0.38, 0.48, -0.05), WOOD)
	for lx in [0.15, 0.6]:
		for lz in [-0.18, 0.1]:
			b.box(Vector3(0.06, 0.42, 0.06), Vector3(lx, 0.23, lz), WOOD_DARK)
	b.box(Vector3(0.22, 0.04, 0.05), Vector3(0.4, 0.54, -0.1), SILVER_DARK, Vector3(0, 30, 0))
	b.box(Vector3(0.05, 0.05, 0.2), Vector3(0.3, 0.55, 0.05), WOOD_DARK)
	# 오른쪽(-X) 통나무 세 개: 아래 둘·위 하나, 길이 방향은 앞뒤, 밝은 단면이 정면
	var logs := [Vector3(-0.62, 0.14, -0.1), Vector3(-0.34, 0.14, -0.1), Vector3(-0.48, 0.38, -0.1)]
	for p in logs:
		b.cyl(0.13, 0.13, 0.75, p, WOOD_DARK, Vector3(90, 0, 0))
		b.cyl(0.11, 0.11, 0.02, p + Vector3(0, 0, -0.38), WOOD_LIGHT, Vector3(90, 0, 0))
	r.add_child(b.instance("Body"))
	return r


# ------------------------------------------------------------------ 방어탑 (2×2)
## 자식: Body(고정), Turret(석궁+조작자, -Z 가 조준 방향), Badge(레벨 표시)
static func defense_tower() -> Node3D:
	var r := _root("DefenseTower")
	var b := MeshBatch.new()
	var top := 1.45
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(0.6 * sx, 0, 0.6 * sz)
			b.box(Vector3(0.32, 0.18, 0.32), p + Vector3(0, 0.09, 0), STONE)
			b.box(Vector3(0.2, top + 0.45, 0.2), p + Vector3(0, 0.18 + (top + 0.45) * 0.5 - 0.1, 0), WOOD)
	# 측면 가새
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.07, 1.25, 0.08), Vector3(0.6 * sx, 0.8, 0), WOOD_DARK, Vector3(52, 0, 0))
	b.box(Vector3(1.0, 0.08, 0.07), Vector3(0, 0.8, -0.6), WOOD_DARK, Vector3(0, 0, 40))
	# 지붕 없는 사각 발판
	b.box(Vector3(1.5, 0.12, 1.5), Vector3(0, top, 0), WOOD)
	# 난간: 후면 중앙은 사다리 출입구로 비움
	b.box(Vector3(1.4, 0.1, 0.08), Vector3(0, top + 0.32, -0.66), WOOD)
	b.box(Vector3(0.08, 0.1, 1.4), Vector3(0.66, top + 0.32, 0), WOOD)
	b.box(Vector3(0.08, 0.1, 1.4), Vector3(-0.66, top + 0.32, 0), WOOD)
	b.box(Vector3(0.42, 0.1, 0.08), Vector3(0.45, top + 0.32, 0.66), WOOD)
	b.box(Vector3(0.42, 0.1, 0.08), Vector3(-0.45, top + 0.32, 0.66), WOOD)
	b.box(Vector3(1.4, 0.06, 0.06), Vector3(0, top + 0.15, -0.66), WOOD_DARK)
	# 정면 난간의 보라색 깃발
	b.box(Vector3(0.5, 0.62, 0.03), Vector3(0, top - 0.05, -0.72), PURPLE)
	b.prism(Vector3(0.5, 0.14, 0.03), Vector3(0, top - 0.43, -0.72), PURPLE, Vector3(0, 0, 180))
	b.box(Vector3(0.1, 0.06, 0.05), Vector3(0.2, top + 0.27, -0.72), SILVER_DARK)
	b.box(Vector3(0.1, 0.06, 0.05), Vector3(-0.2, top + 0.27, -0.72), SILVER_DARK)
	_emblem(b, Vector3(0, top, -0.745), -1.0, 1.3)
	# 후면 중앙 사다리(난간 개구부와 연결)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.06, top + 0.35, 0.06), Vector3(0.17 * sx, (top + 0.35) * 0.5, 0.86), WOOD, Vector3(-8, 0, 0))
	for i in 6:
		var y := 0.2 + i * 0.25
		b.box(Vector3(0.34, 0.05, 0.05), Vector3(0, y, 0.89 - y * 0.14), WOOD_DARK)
	r.add_child(b.instance("Body"))

	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, top + 0.06, 0)
	var t := MeshBatch.new()
	t.cyl(0.16, 0.2, 0.18, Vector3(0, 0.09, 0), STONE_DARK)
	t.box(Vector3(0.12, 0.12, 0.2), Vector3(0, 0.3, 0.0), WOOD_DARK)
	t.box(Vector3(0.13, 0.11, 0.78), Vector3(0, 0.42, -0.12), WOOD)
	t.box(Vector3(0.86, 0.07, 0.08), Vector3(0, 0.44, -0.44), WOOD_DARK)
	t.box(Vector3(0.06, 0.06, 0.06), Vector3(0.43, 0.44, -0.44), SILVER_DARK)
	t.box(Vector3(0.06, 0.06, 0.06), Vector3(-0.43, 0.44, -0.44), SILVER_DARK)
	t.box(Vector3(0.86, 0.015, 0.015), Vector3(0, 0.45, -0.32), BLACK)
	t.cyl(0.0, 0.06, 0.16, Vector3(0, 0.44, -0.6), SILVER, Vector3(-90, 0, 0))
	t.box(Vector3(0.22, 0.12, 0.14), Vector3(0, 0.43, -0.6), SILVER_DARK)
	turret.add_child(t.instance("Crossbow"))
	var op := goblin(false)
	op.name = "Operator"
	op.scale = Vector3.ONE * 0.8
	op.position = Vector3(0.0, 0.0, 0.42)
	turret.add_child(op)
	r.add_child(turret)

	var badge := Label3D.new()
	badge.name = "Badge"
	badge.text = "Lv.2"
	badge.font_size = 64
	badge.pixel_size = 0.006
	badge.outline_size = 18
	badge.modulate = GOLD
	badge.outline_modulate = PURPLE_DARK
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.no_depth_test = true
	badge.position = Vector3(0.55, top + 0.95, 0)
	badge.visible = false
	r.add_child(badge)
	return r


# ------------------------------------------------------------------ 고블린 (약 1.0)
## 관절 노드: LegL/LegR/ArmL/ArmR(어깨·엉덩이 피벗), Head
static func goblin(with_hammer: bool = true) -> Node3D:
	var r := _root("Goblin")
	var body := MeshBatch.new()
	body.sphere(0.2, Vector3(0, 0.44, 0), TUNIC, Vector3(1.0, 1.05, 0.85))
	body.box(Vector3(0.36, 0.06, 0.3), Vector3(0, 0.36, 0), WOOD_DARK)
	body.box(Vector3(0.07, 0.06, 0.02), Vector3(0, 0.36, -0.15), BRASS)
	body.box(Vector3(0.32, 0.1, 0.26), Vector3(0, 0.29, 0), SHORTS)
	r.add_child(body.instance("Body"))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.62, 0)
	var h := MeshBatch.new()
	h.sphere(0.23, Vector3(0, 0.16, 0), GOBLIN_SKIN, Vector3(1.05, 0.95, 0.95))
	# 큰 뾰족 귀
	h.cyl(0.0, 0.08, 0.32, Vector3(0.32, 0.2, 0.02), GOBLIN_SKIN_DARK, Vector3(0, 0, -100))
	h.cyl(0.0, 0.08, 0.32, Vector3(-0.32, 0.2, 0.02), GOBLIN_SKIN_DARK, Vector3(0, 0, 100))
	# 눈·송곳니·코
	h.sphere(0.04, Vector3(0.08, 0.17, -0.2), BLACK)
	h.sphere(0.04, Vector3(-0.08, 0.17, -0.2), BLACK)
	h.sphere(0.035, Vector3(0, 0.12, -0.23), GOBLIN_SKIN_DARK)
	h.cyl(0.0, 0.015, 0.04, Vector3(0.05, 0.04, -0.19), WHITE, Vector3(180, 0, 0))
	h.cyl(0.0, 0.015, 0.04, Vector3(-0.05, 0.04, -0.19), WHITE, Vector3(180, 0, 0))
	# 이마 위 황동 고글
	h.box(Vector3(0.42, 0.04, 0.4), Vector3(0, 0.27, 0.0), WOOD_DARK)
	h.cyl(0.06, 0.06, 0.05, Vector3(0.08, 0.29, -0.2), BRASS, Vector3(70, 0, 0))
	h.cyl(0.06, 0.06, 0.05, Vector3(-0.08, 0.29, -0.2), BRASS, Vector3(70, 0, 0))
	h.cyl(0.04, 0.04, 0.055, Vector3(0.08, 0.29, -0.205), Color("9fd8e8"), Vector3(70, 0, 0))
	h.cyl(0.04, 0.04, 0.055, Vector3(-0.08, 0.29, -0.205), Color("9fd8e8"), Vector3(70, 0, 0))
	# 갈색 머리 한 줌
	h.cyl(0.0, 0.07, 0.14, Vector3(0.0, 0.4, 0.02), HAIR, Vector3(-15, 0, 10))
	h.cyl(0.0, 0.05, 0.11, Vector3(0.06, 0.38, 0.0), HAIR, Vector3(0, 0, -25))
	head.add_child(h.instance("HeadMesh"))
	r.add_child(head)

	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegR" if side > 0 else "LegL"
		leg.position = Vector3(0.09 * side, 0.26, 0)
		var lb := MeshBatch.new()
		lb.box(Vector3(0.1, 0.16, 0.1), Vector3(0, -0.08, 0), GOBLIN_SKIN)
		lb.box(Vector3(0.13, 0.12, 0.17), Vector3(0, -0.2, -0.02), BOOT)
		leg.add_child(lb.instance("LegMesh"))
		r.add_child(leg)
		var arm := Node3D.new()
		arm.name = "ArmR" if side > 0 else "ArmL"
		arm.position = Vector3(0.21 * side, 0.52, 0)
		var ab := MeshBatch.new()
		ab.box(Vector3(0.08, 0.2, 0.08), Vector3(0.02 * side, -0.1, 0), GOBLIN_SKIN)
		ab.sphere(0.05, Vector3(0.02 * side, -0.21, 0), GOBLIN_SKIN)
		if with_hammer and side > 0:
			# 나무 망치는 본인의 오른손(+X)
			ab.box(Vector3(0.04, 0.04, 0.32), Vector3(0.02, -0.21, -0.12), WOOD)
			ab.box(Vector3(0.1, 0.1, 0.16), Vector3(0.02, -0.21, -0.28), WOOD_DARK, Vector3(0, 90, 0))
		arm.add_child(ab.instance("ArmMesh"))
		r.add_child(arm)
	return r


# ------------------------------------------------------------------ 인간 기사 (약 1.1)
static func knight() -> Node3D:
	var r := _root("Knight")
	var body := MeshBatch.new()
	body.box(Vector3(0.34, 0.3, 0.24), Vector3(0, 0.5, 0), SILVER)
	body.box(Vector3(0.26, 0.04, 0.02), Vector3(0, 0.6, -0.125), GOLD)
	body.box(Vector3(0.36, 0.06, 0.26), Vector3(0, 0.36, 0), WOOD_DARK)
	body.box(Vector3(0.06, 0.06, 0.02), Vector3(0, 0.36, -0.135), GOLD)
	body.box(Vector3(0.32, 0.12, 0.24), Vector3(0, 0.28, 0), RED)
	body.sphere(0.08, Vector3(0.2, 0.62, 0), SILVER_DARK)
	body.sphere(0.08, Vector3(-0.2, 0.62, 0), SILVER_DARK)
	# 붉은 짧은 망토(뒤 +Z)
	body.box(Vector3(0.36, 0.42, 0.03), Vector3(0, 0.44, 0.15), RED, Vector3(-8, 0, 0))
	r.add_child(body.instance("Body"))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.66, 0)
	var h := MeshBatch.new()
	h.sphere(0.2, Vector3(0, 0.18, 0), SKIN)
	h.sphere(0.03, Vector3(0.07, 0.17, -0.18), BLACK)
	h.sphere(0.03, Vector3(-0.07, 0.17, -0.18), BLACK)
	# 은색 투구 + 황동 테두리 + 붉은 깃
	h.sphere(0.23, Vector3(0, 0.25, 0.02), SILVER, Vector3(1, 0.85, 1))
	h.box(Vector3(0.36, 0.05, 0.05), Vector3(0, 0.27, -0.19), GOLD)
	h.box(Vector3(0.05, 0.12, 0.05), Vector3(0, 0.33, -0.2), SILVER_DARK)
	h.box(Vector3(0.04, 0.2, 0.3), Vector3(0.21, 0.13, 0.03), SILVER)
	h.box(Vector3(0.04, 0.2, 0.3), Vector3(-0.21, 0.13, 0.03), SILVER)
	h.sphere(0.1, Vector3(0.0, 0.5, 0.06), RED, Vector3(0.6, 1.0, 1.5), Vector3(-30, 0, 0))
	head.add_child(h.instance("HeadMesh"))
	r.add_child(head)

	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegR" if side > 0 else "LegL"
		leg.position = Vector3(0.09 * side, 0.24, 0)
		var lb := MeshBatch.new()
		lb.box(Vector3(0.12, 0.16, 0.12), Vector3(0, -0.07, 0), SILVER_DARK)
		lb.box(Vector3(0.14, 0.1, 0.18), Vector3(0, -0.18, -0.02), BOOT)
		leg.add_child(lb.instance("LegMesh"))
		r.add_child(leg)
		var arm := Node3D.new()
		arm.name = "ArmR" if side > 0 else "ArmL"
		arm.position = Vector3(0.23 * side, 0.58, 0)
		var ab := MeshBatch.new()
		ab.box(Vector3(0.09, 0.22, 0.09), Vector3(0.02 * side, -0.1, 0), SILVER)
		ab.sphere(0.055, Vector3(0.02 * side, -0.22, 0), BOOT)
		if side > 0:
			# 검은 본인의 오른손(+X)
			ab.box(Vector3(0.04, 0.04, 0.14), Vector3(0.02, -0.22, -0.04), GOLD)
			ab.box(Vector3(0.05, 0.03, 0.4), Vector3(0.02, -0.22, -0.3), SILVER)
			ab.cyl(0.0, 0.03, 0.07, Vector3(0.02, -0.22, -0.53), SILVER, Vector3(-90, 0, 0))
		else:
			# 둥근 붉은 방패는 왼손(-X)
			ab.cyl(0.2, 0.2, 0.04, Vector3(-0.07, -0.16, 0.0), RED, Vector3(0, 0, 90), 16)
			ab.cyl(0.21, 0.21, 0.03, Vector3(-0.065, -0.16, 0.0), GOLD, Vector3(0, 0, 90), 16)
			ab.sphere(0.05, Vector3(-0.1, -0.16, 0.0), GOLD)
		arm.add_child(ab.instance("ArmMesh"))
		r.add_child(arm)
	return r


# ------------------------------------------------------------------ 발사체
static func bolt() -> Node3D:
	var r := _root("Bolt")
	var b := MeshBatch.new()
	b.box(Vector3(0.035, 0.035, 0.42), Vector3(0, 0, 0), WOOD_DARK)
	b.cyl(0.0, 0.045, 0.1, Vector3(0, 0, -0.25), SILVER, Vector3(-90, 0, 0))
	b.box(Vector3(0.12, 0.01, 0.08), Vector3(0, 0, 0.18), RED)
	r.add_child(b.instance("BoltMesh"))
	return r
