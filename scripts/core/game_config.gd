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
