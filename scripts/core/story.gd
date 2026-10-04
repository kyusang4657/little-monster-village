class_name Story
extends RefCounted
## 미리 써 둔 대사 데이터(config/story.json). 런타임 생성 없음.
## 장면은 trigger 로 찾는다: new_game, chapter_end:N, chapter_start:N, before_stage:N, stage_clear:N,
## first_expansion, outpost_built, outpost_lost

const PATH := "res://config/story.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = null
		if FileAccess.file_exists(PATH):
			d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if typeof(d) == TYPE_DICTIONARY else {characters = {}, scenes = []}
	return _data


static func reload() -> void:
	_data = {}


static func scene_for(trigger: String) -> Dictionary:
	for sc in data().get("scenes", []):
		if String(sc.get("trigger", "")) == trigger:
			return sc
	return {}


static func scene_by_id(id: String) -> Dictionary:
	for sc in data().get("scenes", []):
		if String(sc.get("id", "")) == id:
			return sc
	return {}


static func character(key: String) -> Dictionary:
	return data().get("characters", {}).get(key, {name = key, role = ""})


static func name_of(key: String) -> String:
	return String(character(key).get("name", key))


## 기사단장의 패배 핑계: 처음 이긴 단계는 첫 대사, 다시 이기면 두 번째 대사
static func commander_excuse(stage_id: int, replay: bool) -> String:
	var arr: Array = data().get("commander_excuses", {}).get(str(stage_id), [])
	if arr.is_empty():
		return ""
	return String(arr[mini(1 if replay else 0, arr.size() - 1)])


## 패배 뒤 촌장의 격려(연패 수로 돌려 가며)
static func chief_after_defeat(n: int) -> String:
	var arr: Array = data().get("chief_after_defeat", [])
	if arr.is_empty():
		return ""
	return String(arr[posmod(n, arr.size())])


static func tutorial_text(step_id: String, fallback: String) -> String:
	return String(data().get("tutorial", {}).get(step_id, fallback))


## 다시 보기 목록(본 장면만, 데이터 순서대로)
static func seen_scenes(seen: Dictionary) -> Array:
	var out: Array = []
	for sc in data().get("scenes", []):
		if seen.has(String(sc.get("id", ""))):
			out.append(sc)
	return out


## 마을에서 뿔이를 눌렀을 때 한마디(누른 횟수로 돌려 가며)
static func imp_tap_line(n: int) -> String:
	var arr: Array = data().get("imp_taps", [])
	return "" if arr.is_empty() else String(arr[posmod(n, arr.size())])


## 성이 자랐을 때 뿔이 한마디
static func imp_levelup_line(level: int) -> String:
	return String(data().get("imp_levelup", {}).get(str(level), ""))
