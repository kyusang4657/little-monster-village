class_name GameConfig
extends RefCounted
## config/*.json 을 읽어 한 곳에서 제공한다. 수치의 단일 기준은 JSON 이다.

const DEFAULTS_PATH := "res://config/prototype-defaults.json"
const LAYOUT_PATH := "res://config/initial-layout.json"

static var _defaults: Dictionary = {}
static var _layout: Dictionary = {}


static func defaults() -> Dictionary:
	if _defaults.is_empty():
		_defaults = _load_json(DEFAULTS_PATH)
	return _defaults


static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = _load_json(LAYOUT_PATH)
	return _layout


static func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("설정 파일을 읽을 수 없습니다: %s" % path)
		return {}
	return data


static func grid_width() -> int:
	return int(defaults().grid.width)


static func grid_depth() -> int:
	return int(defaults().grid.depth)


static func building_def(type: String) -> Dictionary:
	return defaults().buildings.get(type, {})


static func footprint(type: String) -> Vector2i:
	var fp: Array = building_def(type).get("footprint", [1, 1])
	return Vector2i(int(fp[0]), int(fp[1]))


static func economy() -> Dictionary:
	return defaults().economy


static func combat() -> Dictionary:
	return defaults().combat


static func construction() -> Dictionary:
	return defaults().get("construction", {progress_states = [], move_while_constructing = true, upgrade_while_constructing = false})


static func raids() -> Dictionary:
	return defaults().raids


static func stage(stage_id: int) -> Dictionary:
	for s in raids().stages:
		if int(s.id) == stage_id:
			return s
	return {}


static func stage_count() -> int:
	return raids().stages.size()


static func tower_level(level: int) -> Dictionary:
	return building_def("defense_tower").levels.get(str(level), {})


static func camera() -> Dictionary:
	return defaults().camera


static func entry_cell() -> Vector2i:
	var e: Array = layout().raid_spawn.entry_cell
	return Vector2i(int(e[0]), int(e[1]))


static func spawn_world() -> Vector2:
	var p: Array = layout().raid_spawn.outside_world_position
	return Vector2(float(p[0]), float(p[1]))


static func type_label(type: String) -> String:
	match type:
		"castle":
			return "마물 성"
		"house":
			return "고블린 주택"
		"lumber_camp":
			return "벌목소"
		"defense_tower":
			return "방어탑"
	return type


# ---------------------------------------------------------------- 3차: 장·성 레벨·지도

static func chapters() -> Array:
	return defaults().get("chapters", [])


static func chapter_of_stage(stage_id: int) -> Dictionary:
	for c in chapters():
		if stage_id >= int(c.first_stage) and stage_id <= int(c.last_stage):
			return c
	return {}


static func castle_level_def(level: int) -> Dictionary:
	return defaults().get("castle_levels", {}).get(str(level), {})


static func max_castle_level() -> int:
	return int(building_def("castle").get("max_level", 1))


static func castle_hp(level: int) -> int:
	return int(castle_level_def(level).get("hp", 180))


static func map_config() -> Dictionary:
	return defaults().get("map", {})


static func initial_bounds() -> Rect2i:
	var m: Dictionary = map_config().get("initial", {min_x = 0, min_z = 0, max_x = grid_width() - 1, max_z = grid_depth() - 1})
	return Rect2i(int(m.min_x), int(m.min_z), int(m.max_x) - int(m.min_x) + 1, int(m.max_z) - int(m.min_z) + 1)


static func expansion_def(dir: String) -> Dictionary:
	return map_config().get("expansions", {}).get(dir, {})


## 확장 목록으로 경계를 계산한다(저장에는 확장 목록만 둔다 → 경계와 어긋날 수 없음).
static func bounds_for(expansions: Array) -> Rect2i:
	var b := initial_bounds()
	for dir in ["west", "east", "south", "north"]:
		if not expansions.has(dir):
			continue
		var e := expansion_def(dir)
		var n := int(e.get("cells", 0))
		match String(e.get("side", "")):
			"x+":
				b.size.x += n
			"x-":
				b.position.x -= n
				b.size.x += n
			"z+":
				b.size.y += n
			"z-":
				b.position.y -= n
				b.size.y += n
	return b


## 확장 방향 하나가 더하는 땅(논리 좌표)
static func expansion_rect(dir: String, current: Rect2i) -> Rect2i:
	var e := expansion_def(dir)
	var n := int(e.get("cells", 0))
	match String(e.get("side", "")):
		"x+":
			return Rect2i(current.end.x, current.position.y, n, current.size.y)
		"x-":
			return Rect2i(current.position.x - n, current.position.y, n, current.size.y)
		"z+":
			return Rect2i(current.position.x, current.end.y, current.size.x, n)
		"z-":
			return Rect2i(current.position.x, current.position.y - n, current.size.x, n)
	return Rect2i()


static func gate_x() -> Vector2i:
	var g: Array = map_config().get("gate_x", [6, 8])
	return Vector2i(int(g[0]), int(g[1]))


## 정문 안쪽 첫 칸: 앞쪽 경계(min_z)의 정문 왼쪽 칸
static func entry_cell_for(bounds: Rect2i) -> Vector2i:
	return Vector2i(gate_x().x, bounds.position.y)


static func spawn_world_for(bounds: Rect2i) -> Vector2:
	var dist := float(map_config().get("spawn_distance", 2.0))
	return Vector2(gate_x().x + 0.5, bounds.position.y - dist)


static func resource_sites() -> Array:
	return map_config().get("resource_sites", [])


## 습격에 나오는 적 목록(등장 순서). 보스 단계는 units 로 종류를 섞는다.
static func stage_units(stage_id: int) -> Array:
	var st := stage(stage_id)
	var base := {kind = "knight", hp = int(st.get("knight_hp", 90)),
		attack_damage = int(combat().knight_attack_damage), attack_interval_seconds = float(combat().knight_attack_interval_seconds),
		move_cells_per_second = float(combat().knight_move_cells_per_second)}
	if not st.has("units"):
		var out: Array = []
		for i in int(st.knight_count):
			out.append(base.duplicate())
		return out
	var list: Array = []
	var late: Array = []
	for u in st.units:
		var unit := base.duplicate()
		for k in u:
			if k != "count" and k != "spawn_after":
				unit[k] = u[k]
		for i in int(u.get("count", 1)):
			if u.has("spawn_after"):
				late.append({at = int(u.spawn_after), unit = unit.duplicate()})
			else:
				list.append(unit.duplicate())
	# spawn_after: 그 수만큼 앞 유닛이 나온 뒤 끼워 넣는다(결정적)
	late.sort_custom(func(a, b): return a.at > b.at)
	for l in late:
		list.insert(mini(int(l.at), list.size()), l.unit)
	return list
