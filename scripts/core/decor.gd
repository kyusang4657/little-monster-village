class_name Decor
extends RefCounted
## 꾸미기 부품(config/decorations.json). 외형 전용이며 규칙·전투에는 쓰지 않는다.

const PATH := "res://config/decorations.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if typeof(d) == TYPE_DICTIONARY else {types = {}}
	return _data


static func parts(type: String) -> Array:
	return data().types.get(type, {}).get("parts", [])


static func has_parts(type: String) -> bool:
	return not parts(type).is_empty()


static func defaults(type: String) -> Dictionary:
	var out := {}
	for p in parts(type):
		out[String(p.id)] = String(p.default)
	return out


static func option(type: String, part_id: String, option_id: String) -> Dictionary:
	for p in parts(type):
		if p.id == part_id:
			for o in p.options:
				if o.id == option_id:
					return o
	return {}


## 알 수 없는 부품·값은 기본값으로 바꾸고, 빠진 부품은 채운다(저장 호환).
static func sanitize(type: String, deco) -> Dictionary:
	var out := defaults(type)
	if typeof(deco) != TYPE_DICTIONARY:
		return out
	for k in out:
		if deco.has(k) and not option(type, k, String(deco[k])).is_empty():
			out[k] = String(deco[k])
	return out


static func color(type: String, deco: Dictionary, part_id: String, fallback: Color) -> Color:
	var o := option(type, part_id, String(deco.get(part_id, "")))
	return Color(String(o.color)) if o.has("color") else fallback


static func key(deco: Dictionary) -> String:
	var ks := deco.keys()
	ks.sort()
	var parts_s: Array[String] = []
	for k in ks:
		parts_s.append("%s=%s" % [k, deco[k]])
	return ",".join(parts_s)
