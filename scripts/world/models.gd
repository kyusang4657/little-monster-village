class_name Models
extends RefCounted
## 통일된 로우폴리 모델(기본 도형 조합, 단색 정점 색). 기준점 = 점유 영역 지면 중앙, 정면 = -Z.
## 캐릭터의 '오른손'은 캐릭터 자신의 오른쪽(+X, 정면 -Z 기준)이다.
## 건물은 부품 함수(_house_roof, _window 등)로 조립하고, 꾸미기 값(deco)에 따라 부품을 고른다.
## 외형만 바뀌며 점유 칸·기준점·석궁/조작자 노드 이름(Turret/Crossbow/Operator)은 유지한다.

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
const SILVER := Color("b9c3cd")
const SILVER_DARK := Color("8a95a1")
const RED := Color("c8343a")
const SKIN := Color("f2c9a0")
const BLACK := Color("2b2233")
const WHITE := Color("ffffff")
## 테두리·몰딩 두께(모든 건물 공통 → 같은 손맛의 로우폴리)
const TRIM := 0.08


## level: 성 레벨(1~4), flags.damaged: 점령된 앞마당 표시
static func build(type: String, deco: Dictionary = {}, level: int = 1, flags: Dictionary = {}) -> Node3D:
	var d := Decor.sanitize(type, deco)
	match type:
		"castle":
			return castle(level)
		"house":
			return house(d)
		"lumber_camp":
			return lumber_camp(d)
		"defense_tower":
			return defense_tower(d)
		"outpost":
			return outpost(bool(flags.get("damaged", false)))
		"flowerbed":
			return flowerbed(d)
		"lantern":
			return lantern(d)
	return Node3D.new()


static func _root(n: String) -> Node3D:
	var r := Node3D.new()
	r.name = n
	return r


## 문양: skull·moon·star·none. pos 는 깃발 앞면 중앙, facing_z 는 깃발이 보는 방향(-1 = 정면).
static func _emblem(b: MeshBatch, kind: String, pos: Vector3, facing_z: float, s: float = 1.0) -> void:
	match kind:
		"skull":
			b.sphere(0.09 * s, pos, IVORY, Vector3(1, 0.9, 0.35))
			b.cyl(0.0, 0.035 * s, 0.1 * s, pos + Vector3(0.08 * s, 0.07 * s, 0), IVORY, Vector3(0, 0, -35))
			b.cyl(0.0, 0.035 * s, 0.1 * s, pos + Vector3(-0.08 * s, 0.07 * s, 0), IVORY, Vector3(0, 0, 35))
			b.sphere(0.022 * s, pos + Vector3(0.035 * s, 0.01, facing_z * 0.03), PURPLE_DARK)
			b.sphere(0.022 * s, pos + Vector3(-0.035 * s, 0.01, facing_z * 0.03), PURPLE_DARK)
		"moon":
			b.cyl(0.1 * s, 0.1 * s, 0.02, pos, GOLD, Vector3(90, 0, 0), 14)
			b.cyl(0.085 * s, 0.085 * s, 0.025, pos + Vector3(0.05 * s, 0.03 * s, facing_z * 0.004), PURPLE_DARK, Vector3(90, 0, 0), 14)
		"star":
			b.cyl(0.11 * s, 0.11 * s, 0.02, pos, GOLD, Vector3(90, 0, 0), 5)
			b.cyl(0.11 * s, 0.11 * s, 0.02, pos, GOLD, Vector3(90, 0, 36), 5)


## 창문 부품: square·round·arch. center 는 벽면 위 창 중심, yaw 는 벽이 바라보는 방향(0 = -Z 정면).
static func _window(b: MeshBatch, kind: String, center: Vector3, yaw: float, size: float = 0.22) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var out := basis * Vector3(0, 0, -1)
	var rot := Vector3(0, yaw, 0)
	var cyl_rot := Vector3(90, yaw, 0)
	match kind:
		"round":
			b.cyl(size * 0.62, size * 0.62, 0.04, center, WOOD, cyl_rot, 14)
			b.cyl(size * 0.46, size * 0.46, 0.05, center + out * 0.006, GLASS, cyl_rot, 14)
			b.box(Vector3(size * 0.9, 0.02, 0.02), center + out * 0.03, WOOD_DARK, rot)
		"arch":
			b.box(Vector3(size * 1.15, size * 1.0, 0.04), center + Vector3(0, -size * 0.12, 0), WOOD, rot)
			b.cyl(size * 0.58, size * 0.58, 0.04, center + Vector3(0, size * 0.38, 0), WOOD, cyl_rot, 12)
			b.box(Vector3(size * 0.82, size * 0.8, 0.05), center + Vector3(0, -size * 0.12, 0) + out * 0.006, GLASS, rot)
			b.cyl(size * 0.41, size * 0.41, 0.05, center + Vector3(0, size * 0.28, 0) + out * 0.006, GLASS, cyl_rot, 12)
		_:
			b.box(Vector3(size * 1.3, size * 1.3, 0.04), center, WOOD, rot)
			b.box(Vector3(size * 0.95, size * 0.95, 0.05), center + out * 0.006, GLASS, rot)
			b.box(Vector3(size * 1.0, 0.02, 0.02), center + out * 0.03, WOOD_DARK, rot)
			b.box(Vector3(0.02, size * 1.0, 0.02), center + out * 0.03, WOOD_DARK, rot)
			# 창 아래 꽃 상자
			b.box(Vector3(size * 1.4, 0.06, 0.08), center + Vector3(0, -size * 0.78, 0) + out * 0.05, WOOD_DARK, rot)
			b.sphere(0.035, center + Vector3(-size * 0.35, -size * 0.7, 0) + out * 0.06, Color("e46f8e"))
			b.sphere(0.035, center + Vector3(size * 0.35, -size * 0.7, 0) + out * 0.06, Color("f3d04f"))


## 작은 깃대 + 깃발(지붕 장식)
static func _pennant(b: MeshBatch, emblem: String, base: Vector3, cloth: Color) -> void:
	b.cyl(0.022, 0.022, 0.62, base + Vector3(0, 0.31, 0), WOOD_DARK, Vector3.ZERO, 6)
	b.sphere(0.035, base + Vector3(0, 0.64, 0), GOLD)
	b.box(Vector3(0.3, 0.2, 0.02), base + Vector3(0.16, 0.5, 0), cloth)
	_emblem(b, emblem, base + Vector3(0.16, 0.5, -0.012), -1.0, 0.75)


# ------------------------------------------------------------------ 마물 성 (3×3)
## 성은 레벨마다 커지고 화려해진다. 점유는 언제나 3×3, 기준점은 영역 중앙, 성문은 정면(-Z) 가운데.
static func castle(level: int = 1) -> Node3D:
	if level >= 2:
		return castle_upgraded(level)
	var r := _root("Castle")
	var b := MeshBatch.new()
	# 계단식 돌 기단
	b.box(Vector3(2.9, 0.1, 2.9), Vector3(0, 0.05, 0), STONE_DARK)
	b.box(Vector3(2.7, 0.06, 2.6), Vector3(0, 0.13, 0.05), STONE)
	# 낮고 넓은 본관 + 아래 돌띠 + 평평한 지붕 테라스
	b.box(Vector3(2.3, 1.05, 1.9), Vector3(0, 0.685, 0.2), IVORY)
	b.box(Vector3(2.36, 0.16, 1.96), Vector3(0, 0.24, 0.2), IVORY_DARK)
	b.box(Vector3(2.42, 0.1, 2.02), Vector3(0, 1.24, 0.2), IVORY_DARK)
	for i in 6:
		var x := -1.05 + i * 0.42
		b.box(Vector3(0.22, 0.18, 0.14), Vector3(x, 1.38, 1.15), IVORY)
	for i in 4:
		var z := -0.55 + i * 0.5
		b.box(Vector3(0.14, 0.18, 0.22), Vector3(1.15, 1.38, z), IVORY)
		b.box(Vector3(0.14, 0.18, 0.22), Vector3(-1.15, 1.38, z), IVORY)
	b.box(Vector3(1.2, 0.18, 0.14), Vector3(0, 1.38, -0.75), IVORY)
	# 정면 양 모서리의 원형 탑 두 개만(중앙 탑 없음)
	for sx in [-1.0, 1.0]:
		var p := Vector3(1.0 * sx, 0, -0.78)
		b.cyl(0.44, 0.5, 1.72, p + Vector3(0, 1.02, 0), IVORY, Vector3.ZERO, 14)
		b.cyl(0.52, 0.53, 0.16, p + Vector3(0, 0.24, 0), IVORY_DARK, Vector3.ZERO, 14)
		b.cyl(0.5, 0.5, 0.1, p + Vector3(0, 1.9, 0), IVORY_DARK, Vector3.ZERO, 14)
		b.cyl(0.0, 0.58, 0.85, p + Vector3(0, 2.37, 0), PURPLE, Vector3.ZERO, 14)
		b.cyl(0.6, 0.6, 0.05, p + Vector3(0, 1.97, 0), PURPLE_DARK, Vector3.ZERO, 14)
		b.sphere(0.07, p + Vector3(0, 2.83, 0), GOLD)
		# 탑 정면 보라 깃발과 문양
		b.box(Vector3(0.36, 0.55, 0.04), p + Vector3(0, 1.06, -0.47), PURPLE)
		b.prism(Vector3(0.36, 0.12, 0.04), p + Vector3(0, 0.73, -0.47), PURPLE, Vector3(0, 0, 180))
		b.box(Vector3(0.42, 0.05, 0.06), p + Vector3(0, 1.34, -0.48), GOLD)
		_emblem(b, "skull", p + Vector3(0, 1.1, -0.5), -1.0, 1.1)
		b.box(Vector3(0.1, 0.2, 0.04), p + Vector3(0.48 * sx, 1.46, 0), GLASS_DARK, Vector3(0, 90 * sx, 0))
	# 청록 양문(돌 아치 테두리)과 낮은 두 단 계단
	b.box(Vector3(0.9, 0.74, 0.06), Vector3(0, 0.56, -0.74), IVORY_DARK)
	b.cyl(0.45, 0.45, 0.06, Vector3(0, 0.93, -0.74), IVORY_DARK, Vector3(90, 0, 0), 16)
	b.box(Vector3(0.74, 0.62, 0.08), Vector3(0, 0.54, -0.76), TEAL)
	b.cyl(0.37, 0.37, 0.08, Vector3(0, 0.85, -0.76), TEAL, Vector3(90, 0, 0), 16)
	b.box(Vector3(0.03, 0.88, 0.1), Vector3(0, 0.64, -0.8), Color("1f7a77"))
	for y in [0.4, 0.7]:
		b.box(Vector3(0.7, 0.03, 0.02), Vector3(0, y, -0.81), Color("1f7a77"))
	b.sphere(0.035, Vector3(0.09, 0.54, -0.82), GOLD)
	b.sphere(0.035, Vector3(-0.09, 0.54, -0.82), GOLD)
	b.box(Vector3(1.1, 0.08, 0.28), Vector3(0, 0.2, -0.92), STONE)
	b.box(Vector3(1.3, 0.08, 0.3), Vector3(0, 0.12, -1.08), STONE_DARK)
	# 옆면 창 하나씩, 후면 창 두 개
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.06, 0.34, 0.26), Vector3(1.16 * sx, 0.8, 0.35), GLASS_DARK)
		b.box(Vector3(0.07, 0.05, 0.32), Vector3(1.17 * sx, 0.6, 0.35), IVORY_DARK)
	for x in [-0.5, 0.5]:
		b.box(Vector3(0.26, 0.34, 0.06), Vector3(x, 0.8, 1.16), GLASS_DARK)
		b.box(Vector3(0.32, 0.05, 0.07), Vector3(x, 0.6, 1.17), IVORY_DARK)
	# 지붕 뒤 중앙 작은 깃대(중앙 탑 아님)
	b.cyl(0.025, 0.025, 0.8, Vector3(0, 1.69, 0.85), WOOD_DARK)
	b.box(Vector3(0.36, 0.22, 0.02), Vector3(0.19, 1.96, 0.85), PURPLE)
	r.add_child(b.instance("Body"))
	return r


## Lv.2 고블린 요새 · Lv.3 어둠의 성채 · Lv.4 마왕성
static func castle_upgraded(level: int) -> Node3D:
	var r := _root("Castle")
	var b := MeshBatch.new()
	var dark := level >= 3
	var wall := IVORY if not dark else (Color("6b6080") if level == 3 else Color("4d4462"))
	var wall_trim := IVORY_DARK if not dark else wall.darkened(0.25)
	var roof := PURPLE if level < 4 else Color("5a2c8f")
	var glow := GLASS_DARK if not dark else Color("b689ff")
	var accent := GOLD if level < 4 else Color("e8a33a")
	var hall_h := 1.15 + 0.25 * (level - 1)
	var tower_h := 1.7 + 0.35 * (level - 1)
	# 기단
	b.box(Vector3(2.95, 0.12, 2.95), Vector3(0, 0.06, 0), STONE_DARK if not dark else Color("3d3650"))
	b.box(Vector3(2.75, 0.08, 2.65), Vector3(0, 0.16, 0.05), STONE if not dark else Color("514866"))
	# 본관과 테라스
	b.box(Vector3(2.3, hall_h, 1.9), Vector3(0, 0.2 + hall_h * 0.5, 0.2), wall)
	b.box(Vector3(2.36, 0.16, 1.96), Vector3(0, 0.28, 0.2), wall_trim)
	b.box(Vector3(2.42, 0.1, 2.02), Vector3(0, 0.25 + hall_h, 0.2), wall_trim)
	for i in 6:
		var x := -1.05 + i * 0.42
		b.box(Vector3(0.22, 0.2, 0.14), Vector3(x, 0.4 + hall_h, 1.15), wall)
	for i in 4:
		var z := -0.55 + i * 0.5
		b.box(Vector3(0.14, 0.2, 0.22), Vector3(1.15, 0.4 + hall_h, z), wall)
		b.box(Vector3(0.14, 0.2, 0.22), Vector3(-1.15, 0.4 + hall_h, z), wall)
	if level == 2:
		# 고블린 요새: 지붕 둘레의 뾰족한 통나무 울짱과 망루
		for i in 9:
			var x := -1.1 + i * 0.275
			b.cyl(0.0, 0.06, 0.32, Vector3(x, 0.52 + hall_h, -0.72), WOOD, Vector3.ZERO, 6)
		b.box(Vector3(0.8, 0.5, 0.7), Vector3(0, 0.55 + hall_h, 0.55), WOOD)
		b.prism(Vector3(0.95, 0.35, 0.85), Vector3(0, 0.98 + hall_h, 0.55), roof)
	else:
		# 뒤쪽 중앙 큰 탑(Lv.3 이상)
		var keep_h := hall_h + 1.0 + 0.6 * (level - 3)
		var kp := Vector3(0, 0, 0.55)
		b.cyl(0.5, 0.56, keep_h, kp + Vector3(0, 0.25 + keep_h * 0.5, 0), wall, Vector3.ZERO, 14)
		b.cyl(0.6, 0.6, 0.12, kp + Vector3(0, 0.3 + keep_h, 0), wall_trim, Vector3.ZERO, 14)
		b.cyl(0.0, 0.66, 1.1 + 0.3 * (level - 3), kp + Vector3(0, 0.9 + keep_h + 0.15 * (level - 3), 0), roof, Vector3.ZERO, 14)
		for i in 3:
			b.box(Vector3(0.12, 0.3, 0.04), kp + Vector3(0, 0.9 + i * 0.55, -0.55), glow)
		if level >= 4:
			# 마왕성: 지붕의 두 뿔과 금빛 장식
			for sx in [-1.0, 1.0]:
				b.cyl(0.0, 0.12, 0.7, kp + Vector3(0.42 * sx, 1.25 + keep_h, 0), Color("f1e6cf"), Vector3(0, 0, -35 * sx), 8)
			b.sphere(0.1, kp + Vector3(0, 1.55 + keep_h + 0.15, 0), accent)
	# 정면 양 모서리 원형 탑(레벨마다 높아짐)
	for sx in [-1.0, 1.0]:
		var p := Vector3(1.0 * sx, 0, -0.78)
		b.cyl(0.46, 0.52, tower_h, p + Vector3(0, 0.25 + tower_h * 0.5, 0), wall, Vector3.ZERO, 14)
		b.cyl(0.54, 0.55, 0.16, p + Vector3(0, 0.3, 0), wall_trim, Vector3.ZERO, 14)
		b.cyl(0.52, 0.52, 0.1, p + Vector3(0, 0.3 + tower_h, 0), wall_trim, Vector3.ZERO, 14)
		b.cyl(0.0, 0.6, 0.9 + 0.1 * level, p + Vector3(0, 0.8 + tower_h + 0.05 * level, 0), roof, Vector3.ZERO, 14)
		b.sphere(0.07, p + Vector3(0, 1.3 + tower_h + 0.1 * level, 0), accent)
		if dark:
			for i in 4:
				var a := i * PI * 0.5 + PI * 0.25
				b.cyl(0.0, 0.07, 0.3, p + Vector3(cos(a) * 0.5, 0.42 + tower_h, sin(a) * 0.5), wall_trim, Vector3.ZERO, 6)
		b.box(Vector3(0.38, 0.6, 0.04), p + Vector3(0, 0.95 + tower_h * 0.25, -0.5), PURPLE if level < 4 else Color("8e2a3a"))
		b.prism(Vector3(0.38, 0.12, 0.04), p + Vector3(0, 0.59 + tower_h * 0.25, -0.5), PURPLE if level < 4 else Color("8e2a3a"), Vector3(0, 0, 180))
		b.box(Vector3(0.44, 0.05, 0.06), p + Vector3(0, 1.27 + tower_h * 0.25, -0.51), accent)
		_emblem(b, "skull", p + Vector3(0, 1.0 + tower_h * 0.25, -0.53), -1.0, 1.15)
		b.box(Vector3(0.1, 0.2, 0.04), p + Vector3(0.5 * sx, 0.6 + tower_h * 0.6, 0), glow, Vector3(0, 90 * sx, 0))
	# 성문(정면 가운데)
	var gate_c := TEAL if not dark else Color("2b2440")
	b.box(Vector3(0.95, 0.8, 0.06), Vector3(0, 0.62, -0.74), wall_trim)
	b.cyl(0.48, 0.48, 0.06, Vector3(0, 1.02, -0.74), wall_trim, Vector3(90, 0, 0), 16)
	b.box(Vector3(0.76, 0.66, 0.08), Vector3(0, 0.6, -0.76), gate_c)
	b.cyl(0.38, 0.38, 0.08, Vector3(0, 0.93, -0.76), gate_c, Vector3(90, 0, 0), 16)
	b.box(Vector3(0.03, 0.9, 0.1), Vector3(0, 0.7, -0.8), gate_c.darkened(0.3))
	for y in [0.45, 0.78]:
		b.box(Vector3(0.72, 0.03, 0.02), Vector3(0, y, -0.81), accent if dark else gate_c.darkened(0.3))
	if dark:
		_emblem(b, "skull", Vector3(0, 1.12, -0.82), -1.0, 1.0)
	b.box(Vector3(1.1, 0.08, 0.28), Vector3(0, 0.24, -0.92), STONE)
	b.box(Vector3(1.3, 0.08, 0.3), Vector3(0, 0.16, -1.08), STONE_DARK)
	# 옆·뒤 창
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.06, 0.36, 0.26), Vector3(1.16 * sx, 0.3 + hall_h * 0.55, 0.35), glow)
	for x in [-0.6, 0.6]:
		b.box(Vector3(0.26, 0.36, 0.06), Vector3(x, 0.3 + hall_h * 0.55, 1.16), glow)
	# 양옆 큰 깃발 기둥
	for sx in [-1.0, 1.0]:
		var fp := Vector3(1.3 * sx, 0, 1.25)
		b.cyl(0.03, 0.03, 1.6 + 0.3 * level, fp + Vector3(0, (1.6 + 0.3 * level) * 0.5, 0), WOOD_DARK, Vector3.ZERO, 6)
		b.box(Vector3(0.04, 0.5, 0.4), fp + Vector3(0, 1.3 + 0.3 * level, -0.21), roof)
	r.add_child(b.instance("Body"))
	return r


# ------------------------------------------------------------------ 앞마당 (2×2, 숲 자원 지점)
## 작은 벌목 막사 + 높은 고블린 깃대. 점령되면 지붕이 내려앉고 인간 기사단 깃발이 꽂힌다.
static func outpost(damaged: bool = false) -> Node3D:
	var r := _root("Outpost")
	var b := MeshBatch.new()
	b.box(Vector3(1.8, 0.04, 1.6), Vector3(0, 0.02, 0), Color("8c6c42"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0.12, 0.9, 0.12), Vector3(0.55 * sx, 0.45, 0.45 * sz), WOOD)
	var roof_c := PURPLE if not damaged else PURPLE.darkened(0.45)
	if damaged:
		b.box(Vector3(1.4, 0.07, 1.2), Vector3(0.1, 0.55, 0.0), roof_c, Vector3(0, 0, 18))
	else:
		b.prism(Vector3(1.4, 0.45, 1.2), Vector3(0, 1.12, 0), roof_c)
	b.box(Vector3(1.1, 0.4, 0.05), Vector3(0, 0.3, 0.45), WOOD_DARK)
	# 통나무 더미
	for i in 3:
		b.cyl(0.11, 0.11, 0.6, Vector3(-0.15 + i * 0.22, 0.11, -0.55), WOOD_DARK, Vector3(0, 0, 90))
		b.cyl(0.09, 0.09, 0.02, Vector3(-0.15 + i * 0.22 - 0.3, 0.11, -0.55), WOOD_LIGHT, Vector3(0, 0, 90))
	# 남은 나무 두 그루(숲 자원 지점 느낌)
	for p in [Vector3(0.75, 0, 0.65), Vector3(-0.78, 0, 0.6)]:
		b.cyl(0.07, 0.09, 0.4, p + Vector3(0, 0.2, 0), WOOD_DARK, Vector3.ZERO, 8)
		b.cyl(0.0, 0.35, 0.7, p + Vector3(0, 0.75, 0), Color("2f7d45"), Vector3.ZERO, 10)
	# 깃대
	var flag_c := PURPLE if not damaged else Color("e8e2d6")
	b.cyl(0.03, 0.03, 1.9, Vector3(0.7, 0.95, -0.55), WOOD_DARK, Vector3.ZERO, 6)
	b.box(Vector3(0.45, 0.3, 0.02), Vector3(0.93, 1.7, -0.55), flag_c)
	if damaged:
		b.box(Vector3(0.3, 0.06, 0.03), Vector3(0.93, 1.7, -0.565), RED)
		b.box(Vector3(0.06, 0.24, 0.03), Vector3(0.93, 1.7, -0.565), RED)
	else:
		_emblem(b, "skull", Vector3(0.93, 1.7, -0.57), -1.0, 0.8)
	r.add_child(b.instance("Body"))
	return r


# ------------------------------------------------------------------ 꾸밈 소품 (1×1)
static func flowerbed(deco: Dictionary = {}) -> Node3D:
	var d := Decor.sanitize("flowerbed", deco)
	var c := Decor.color("flowerbed", d, "flower_color", Color("f29ac0"))
	var r := _root("Flowerbed")
	var b := MeshBatch.new()
	b.box(Vector3(0.86, 0.14, 0.86), Vector3(0, 0.07, 0), WOOD)
	b.box(Vector3(0.74, 0.04, 0.74), Vector3(0, 0.15, 0), Color("6b4a2b"))
	for i in 9:
		var x := -0.24 + (i % 3) * 0.24
		var z := -0.24 + (i / 3) * 0.24
		b.cyl(0.015, 0.015, 0.16, Vector3(x, 0.24, z), Color("4f9a3d"), Vector3.ZERO, 5)
		b.sphere(0.07, Vector3(x, 0.33, z), c if (i % 2 == 0) else c.lightened(0.25))
	r.add_child(b.instance("Body"))
	return r


static func lantern(deco: Dictionary = {}) -> Node3D:
	var d := Decor.sanitize("lantern", deco)
	var c := Decor.color("lantern", d, "glow", Color("b689ff"))
	var r := _root("Lantern")
	var b := MeshBatch.new()
	b.cyl(0.08, 0.12, 0.55, Vector3(0, 0.27, 0), CREAM, Vector3.ZERO, 10)
	b.sphere(0.3, Vector3(0, 0.6, 0), c, Vector3(1, 0.55, 1))
	for i in 5:
		var a := i * TAU / 5.0
		b.sphere(0.04, Vector3(cos(a) * 0.17, 0.72, sin(a) * 0.17), WHITE)
	b.sphere(0.13, Vector3(0.28, 0.12, 0.2), c.darkened(0.1), Vector3(1, 0.6, 1))
	b.cyl(0.03, 0.04, 0.12, Vector3(0.28, 0.05, 0.2), CREAM, Vector3.ZERO, 6)
	r.add_child(b.instance("Body"))
	return r


# ------------------------------------------------------------------ 고블린 주택 (2×2)
## 꾸미기: roof_color, roof_shape(gable/hip/steep), window(square/round/arch), chimney(back_right/back_left/none), flag
static func house(deco: Dictionary = {}) -> Node3D:
	var d := Decor.sanitize("house", deco)
	var roof_c := Decor.color("house", d, "roof_color", PURPLE)
	var r := _root("House")
	var b := MeshBatch.new()
	# 돌 기단과 벽
	b.box(Vector3(1.74, 0.12, 1.62), Vector3(0, 0.06, 0), STONE)
	b.box(Vector3(1.46, 0.14, 1.31), Vector3(0, 0.17, 0.05), STONE_DARK)
	b.box(Vector3(1.4, 0.78, 1.25), Vector3(0, 0.62, 0.05), CREAM)
	# 목재 프레임(모서리 기둥·윗보)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0.11, 0.84, 0.11), Vector3(0.7 * sx, 0.6, 0.05 + 0.625 * sz), WOOD)
	b.box(Vector3(1.5, TRIM, 0.1), Vector3(0, 0.98, -0.58), WOOD)
	b.box(Vector3(1.5, TRIM, 0.1), Vector3(0, 0.98, 0.68), WOOD)
	b.box(Vector3(0.1, TRIM, 1.35), Vector3(0.71, 0.98, 0.05), WOOD)
	b.box(Vector3(0.1, TRIM, 1.35), Vector3(-0.71, 0.98, 0.05), WOOD)
	var roof_top := _house_roof(b, String(d.roof_shape), roof_c)
	# 정면 중앙 아치형 나무문과 낮은 계단
	b.box(Vector3(0.44, 0.5, 0.04), Vector3(0, 0.45, -0.575), WOOD)
	b.box(Vector3(0.36, 0.42, 0.05), Vector3(0, 0.43, -0.58), WOOD_DARK)
	b.cyl(0.18, 0.18, 0.05, Vector3(0, 0.64, -0.58), WOOD_DARK, Vector3(90, 0, 0), 14)
	b.box(Vector3(0.02, 0.4, 0.06), Vector3(0, 0.45, -0.6), WOOD)
	b.sphere(0.025, Vector3(0.1, 0.43, -0.62), GOLD)
	b.box(Vector3(0.62, 0.08, 0.22), Vector3(0, 0.2, -0.72), STONE_DARK)
	b.box(Vector3(0.5, 0.06, 0.16), Vector3(0, 0.27, -0.66), STONE)
	# 창문: 문 양옆 2, 오른쪽 면(정면을 보는 사람의 오른쪽 = -X) 2, 후면 1
	var wk := String(d.window)
	for x in [-0.45, 0.45]:
		_window(b, wk, Vector3(x, 0.66, -0.58), 0.0)
	for z in [-0.25, 0.35]:
		_window(b, wk, Vector3(-0.71, 0.66, z), 90.0, 0.2)
	_window(b, wk, Vector3(0, 0.66, 0.69), 180.0, 0.2)
	# 굴뚝: 기본은 뒤쪽 오른쪽(정면에서 보면 오른쪽, 후면에서 보면 왼쪽)
	if d.chimney != "none":
		var cx := -0.42 if d.chimney == "back_right" else 0.42
		var h := roof_top - 0.95
		b.box(Vector3(0.24, h, 0.24), Vector3(cx, 1.0 + h * 0.5, 0.42), STONE)
		b.box(Vector3(0.3, 0.08, 0.3), Vector3(cx, 1.0 + h + 0.04, 0.42), STONE_DARK)
	if d.flag != "none":
		_pennant(b, String(d.flag), Vector3(0.0, roof_top - 0.04, -0.15), roof_c.darkened(0.15))
	r.add_child(b.instance("Body"))
	return r


## 지붕 부품. 반환값 = 지붕 꼭대기 높이(굴뚝·깃발 높이 맞춤)
static func _house_roof(b: MeshBatch, shape: String, c: Color) -> float:
	var base := 1.02
	match shape:
		"hip":
			b.quad_frustum(Vector2(0.92, 0.8), 0.18, 0.62, Vector3(0, base + 0.31, 0.05), c)
			b.box(Vector3(0.32, 0.05, 0.28), Vector3(0, base + 0.63, 0.05), c.darkened(0.2))
			b.box(Vector3(1.86, 0.05, 1.62), Vector3(0, base + 0.02, 0.05), c.darkened(0.25))
			return base + 0.64
		"steep":
			b.prism(Vector3(1.38, 0.95, 1.25), Vector3(0, base + 0.42, 0.05), CREAM)
			b.prism(Vector3(1.72, 1.08, 1.5), Vector3(0, base + 0.5, 0.05), c)
			b.box(Vector3(0.07, 0.07, 1.56), Vector3(0, base + 1.04, 0.05), c.darkened(0.25))
			b.cyl(0.09, 0.09, 0.04, Vector3(0, base + 0.36, -0.58), WOOD_DARK, Vector3(90, 0, 0), 14)
			b.cyl(0.065, 0.065, 0.05, Vector3(0, base + 0.36, -0.59), GLASS, Vector3(90, 0, 0), 14)
			return base + 1.05
		_:
			# 맞배(용마루가 앞뒤, 박공이 정면)
			b.prism(Vector3(1.38, 0.55, 1.25), Vector3(0, base + 0.25, 0.05), CREAM)
			b.prism(Vector3(1.8, 0.7, 1.55), Vector3(0, base + 0.31, 0.05), c)
			b.box(Vector3(0.08, 0.06, 1.6), Vector3(0, base + 0.67, 0.05), c.darkened(0.25))
			# 지붕 끝선(처마 그림자 띠)
			for sx in [-1.0, 1.0]:
				b.box(Vector3(0.05, 0.05, 1.58), Vector3(0.9 * sx, base - 0.02, 0.05), c.darkened(0.3))
			# 박공의 둥근 다락창
			b.cyl(0.11, 0.11, 0.04, Vector3(0, base + 0.18, -0.58), WOOD_DARK, Vector3(90, 0, 0), 14)
			b.cyl(0.08, 0.08, 0.05, Vector3(0, base + 0.18, -0.59), GLASS, Vector3(90, 0, 0), 14)
			return base + 0.68


# ------------------------------------------------------------------ 벌목소 (2×2)
static func lumber_camp(deco: Dictionary = {}) -> Node3D:
	var d := Decor.sanitize("lumber_camp", deco)
	var roof_c := Decor.color("lumber_camp", d, "roof_color", PURPLE)
	var r := _root("LumberCamp")
	var b := MeshBatch.new()
	b.box(Vector3(1.8, 0.04, 1.6), Vector3(0, 0.02, 0), Color("a8834f"))
	# 네 목조 기둥과 돌 받침. 뒤가 높고 앞이 낮다.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var h := 1.3 if sz > 0 else 0.95
			var p := Vector3(0.74 * sx, 0, 0.6 * sz)
			b.box(Vector3(0.24, 0.14, 0.24), p + Vector3(0, 0.07, 0), STONE)
			b.box(Vector3(0.13, h, 0.13), p + Vector3(0, 0.14 + h * 0.5, 0), WOOD)
	# 앞뒤 보
	b.box(Vector3(1.62, TRIM, 0.1), Vector3(0, 1.09, -0.6), WOOD_DARK)
	b.box(Vector3(1.62, TRIM, 0.1), Vector3(0, 1.44, 0.6), WOOD_DARK)
	var ang := rad_to_deg(atan2(1.3 - 0.95, 1.2))
	b.box(Vector3(1.9, 0.08, 1.62), Vector3(0, 0.14 + 1.125 + 0.06, 0), roof_c, Vector3(-ang, 0, 0))
	for i in 5:
		b.box(Vector3(0.04, 0.03, 1.6), Vector3(-0.76 + i * 0.38, 0.14 + 1.125 + 0.115, 0), roof_c.darkened(0.2), Vector3(-ang, 0, 0))
	b.box(Vector3(1.9, 0.05, 0.1), Vector3(0, 0.14 + 0.95, -0.8), roof_c.darkened(0.3), Vector3(-ang, 0, 0))
	# 뒤쪽에만 낮은 판자 벽
	for i in 3:
		b.box(Vector3(1.48, 0.16, 0.05), Vector3(0, 0.25 + i * 0.18, 0.62), WOOD_DARK if i % 2 == 0 else WOOD)
	# 정면 기준 왼쪽(+X) 작업대(톱·도끼)
	b.box(Vector3(0.55, 0.08, 0.36), Vector3(0.38, 0.48, -0.05), WOOD)
	for lx in [0.15, 0.6]:
		for lz in [-0.18, 0.1]:
			b.box(Vector3(0.06, 0.42, 0.06), Vector3(lx, 0.23, lz), WOOD_DARK)
	b.box(Vector3(0.22, 0.04, 0.05), Vector3(0.4, 0.54, -0.1), SILVER_DARK, Vector3(0, 30, 0))
	b.box(Vector3(0.05, 0.05, 0.2), Vector3(0.3, 0.55, 0.05), WOOD_DARK)
	b.box(Vector3(0.04, 0.3, 0.04), Vector3(0.62, 0.2, -0.32), WOOD_DARK, Vector3(0, 0, 12))
	b.box(Vector3(0.12, 0.08, 0.03), Vector3(0.66, 0.36, -0.32), SILVER_DARK, Vector3(0, 0, 12))
	# 오른쪽(-X) 통나무 세 개: 아래 둘·위 하나, 길이 방향은 앞뒤, 밝은 단면이 정면
	var logs := [Vector3(-0.62, 0.14, -0.1), Vector3(-0.34, 0.14, -0.1), Vector3(-0.48, 0.38, -0.1)]
	for p in logs:
		b.cyl(0.13, 0.13, 0.75, p, WOOD_DARK, Vector3(90, 0, 0))
		b.cyl(0.11, 0.11, 0.02, p + Vector3(0, 0, -0.38), WOOD_LIGHT, Vector3(90, 0, 0))
		b.cyl(0.05, 0.05, 0.025, p + Vector3(0, 0, -0.385), WOOD, Vector3(90, 0, 0), 8)
	r.add_child(b.instance("Body"))
	return r


# ------------------------------------------------------------------ 방어탑 (2×2)
## 자식: Body(고정), Turret(석궁+조작자, -Z 가 조준 방향), Badge(레벨 표시)
## 꾸미기: flag_color, emblem
static func defense_tower(deco: Dictionary = {}) -> Node3D:
	var d := Decor.sanitize("defense_tower", deco)
	var flag_c := Decor.color("defense_tower", d, "flag_color", PURPLE)
	var r := _root("DefenseTower")
	var b := MeshBatch.new()
	var top := 1.45
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(0.6 * sx, 0, 0.6 * sz)
			b.box(Vector3(0.32, 0.18, 0.32), p + Vector3(0, 0.09, 0), STONE)
			b.box(Vector3(0.2, top + 0.45, 0.2), p + Vector3(0, 0.18 + (top + 0.45) * 0.5 - 0.1, 0), WOOD)
			b.box(Vector3(0.24, 0.06, 0.24), p + Vector3(0, top + 0.53, 0), WOOD_DARK)
	# 측면·정면 가새
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.07, 1.25, 0.08), Vector3(0.6 * sx, 0.8, 0), WOOD_DARK, Vector3(52, 0, 0))
	b.box(Vector3(1.0, 0.08, 0.07), Vector3(0, 0.8, -0.6), WOOD_DARK, Vector3(0, 0, 40))
	# 지붕 없는 사각 발판(판자 줄)
	b.box(Vector3(1.5, 0.12, 1.5), Vector3(0, top, 0), WOOD)
	for i in 4:
		b.box(Vector3(1.48, 0.01, 0.02), Vector3(0, top + 0.065, -0.54 + i * 0.36), WOOD_DARK)
	# 난간: 후면 중앙은 사다리 출입구로 비움
	b.box(Vector3(1.4, 0.1, 0.08), Vector3(0, top + 0.32, -0.66), WOOD)
	b.box(Vector3(0.08, 0.1, 1.4), Vector3(0.66, top + 0.32, 0), WOOD)
	b.box(Vector3(0.08, 0.1, 1.4), Vector3(-0.66, top + 0.32, 0), WOOD)
	b.box(Vector3(0.42, 0.1, 0.08), Vector3(0.45, top + 0.32, 0.66), WOOD)
	b.box(Vector3(0.42, 0.1, 0.08), Vector3(-0.45, top + 0.32, 0.66), WOOD)
	b.box(Vector3(1.4, 0.06, 0.06), Vector3(0, top + 0.15, -0.66), WOOD_DARK)
	# 정면 난간의 깃발(색·문양은 꾸미기)
	b.box(Vector3(0.5, 0.62, 0.03), Vector3(0, top - 0.05, -0.72), flag_c)
	b.prism(Vector3(0.5, 0.14, 0.03), Vector3(0, top - 0.43, -0.72), flag_c, Vector3(0, 0, 180))
	b.box(Vector3(0.1, 0.06, 0.05), Vector3(0.2, top + 0.27, -0.72), SILVER_DARK)
	b.box(Vector3(0.1, 0.06, 0.05), Vector3(-0.2, top + 0.27, -0.72), SILVER_DARK)
	_emblem(b, String(d.emblem), Vector3(0, top, -0.745), -1.0, 1.3)
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
	op.pose_crossbow()
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


# ------------------------------------------------------------------ 공사 비계(점유 영역 크기)
## 모서리 기둥·가로 발판·대각 가새·바닥 자재. 건물 몸체가 진행률만큼 올라오는 동안 둘러싼다.
static func scaffold(fp: Vector2i) -> Node3D:
	var r := _root("Scaffold")
	var b := MeshBatch.new()
	var hx := fp.x * 0.5 - 0.12
	var hz := fp.y * 0.5 - 0.12
	var h := 1.5 if fp.x <= 2 else 2.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0.07, h, 0.07), Vector3(hx * sx, h * 0.5, hz * sz), WOOD_LIGHT)
	for y in [0.55, 1.1, h - 0.05]:
		b.box(Vector3(hx * 2 + 0.1, 0.05, 0.12), Vector3(0, y, -hz), WOOD)
		b.box(Vector3(hx * 2 + 0.1, 0.05, 0.12), Vector3(0, y, hz), WOOD)
		b.box(Vector3(0.12, 0.05, hz * 2 + 0.1), Vector3(-hx, y, 0), WOOD)
		b.box(Vector3(0.12, 0.05, hz * 2 + 0.1), Vector3(hx, y, 0), WOOD)
	var diag := rad_to_deg(atan2(0.55, hx * 2))
	b.box(Vector3(hx * 2.2, 0.035, 0.035), Vector3(0, 0.83, -hz - 0.02), WOOD_DARK, Vector3(0, 0, diag))
	b.box(Vector3(0.035, 0.035, hz * 2.2), Vector3(hx + 0.02, 0.83, 0), WOOD_DARK, Vector3(diag, 0, 0))
	# 바닥 자재: 판자 더미·돌
	b.box(Vector3(0.5, 0.08, 0.18), Vector3(hx - 0.1, 0.04, -hz - 0.25), WOOD_LIGHT)
	b.box(Vector3(0.5, 0.08, 0.18), Vector3(hx - 0.12, 0.12, -hz - 0.25), WOOD)
	b.box(Vector3(0.18, 0.14, 0.18), Vector3(-hx + 0.05, 0.07, -hz - 0.22), STONE)
	# 바닥 테두리(공사 표시)
	b.box(Vector3(fp.x - 0.05, 0.02, 0.06), Vector3(0, 0.01, -fp.y * 0.5 + 0.03), Color("e8b84a"))
	b.box(Vector3(fp.x - 0.05, 0.02, 0.06), Vector3(0, 0.01, fp.y * 0.5 - 0.03), Color("e8b84a"))
	b.box(Vector3(0.06, 0.02, fp.y - 0.05), Vector3(-fp.x * 0.5 + 0.03, 0.01, 0), Color("e8b84a"))
	b.box(Vector3(0.06, 0.02, fp.y - 0.05), Vector3(fp.x * 0.5 - 0.03, 0.01, 0), Color("e8b84a"))
	r.add_child(b.instance("ScaffoldMesh"))
	return r


# ------------------------------------------------------------------ 캐릭터(관절형 리그로 위임)
## 고블린(약 1.0, 3등신)·기사(약 1.15, 3.5등신)는 CharacterRig(하나의 스킨 메시 + 골격)로 만든다.
## 관절 뼈: Head, Neck, Spine, Pelvis, ArmL/R, ForearmL/R, HandL/R, LegL/R, ShinL/R, FootL/R.
## 자세는 pose_idle/pose_walk/pose_attack/pose_hammer 등 함수로 바꾼다(노드 회전이 아님).
static func goblin(with_hammer: bool = true, variant: int = 0) -> CharacterRig:
	return CharacterRig.goblin(variant, with_hammer)


static func knight(variant: int = 0) -> CharacterRig:
	return CharacterRig.knight(variant)


# ------------------------------------------------------------------ 발사체
static func bolt() -> Node3D:
	var r := _root("Bolt")
	var b := MeshBatch.new()
	b.box(Vector3(0.035, 0.035, 0.42), Vector3(0, 0, 0), WOOD_DARK)
	b.cyl(0.0, 0.045, 0.1, Vector3(0, 0, -0.25), SILVER, Vector3(-90, 0, 0))
	b.box(Vector3(0.12, 0.01, 0.08), Vector3(0, 0, 0.18), RED)
	r.add_child(b.instance("BoltMesh"))
	return r
