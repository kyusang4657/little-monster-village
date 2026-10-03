class_name GameState
extends RefCounted
## 확정된 마을 상태와 규칙. 화면·입력과 분리되어 있어 자동 테스트로 검증한다.

signal changed
signal raid_became_ready
signal construction_finished(id: String)
signal castle_leveled(level: int)

const MODE_VILLAGE := "VILLAGE"
const MODE_BUILD := "BUILD"
const MODE_RAID_READY := "RAID_READY"
const MODE_BATTLE := "BATTLE"
const MODE_PAUSED := "PAUSED"
const MODE_RESULT := "RESULT"

const SAVE_VERSION := 3

var buildings: Array = []
var interior_fences: Dictionary = {}
var wood: int = 0
var wood_frac: float = 0.0
var ready_stage: int = 1
var highest_cleared: int = 0
var raid_ready: bool = true
var raid_timer: float = -1.0
var last_resolved_battle_id: int = 0
var battle_seq: int = 0
var rng_seed: int = 0
## 같은 단계 연속 패배 수(도움 모드 판단용, 승리하면 0)
var consecutive_losses: int = 0
## 도움 모드(연패 시 기사 체력 소폭 감소). 기본 꺼짐.
var assist_enabled: bool = false
## 3차: 산 땅 넓히기 방향(경계는 이 목록으로 계산)
var expansions: Array = []
## 3차: 이미 본 스토리 장면 ID
var story_seen: Dictionary = {}

## 실행 중 상태(저장하지 않음)
var mode: String = MODE_RAID_READY
var pause_return: String = MODE_BATTLE
var current_battle_id: int = 0
var current_battle_stage: int = 0

var _rng := RandomNumberGenerator.new()


func new_game() -> void:
	var lay := GameConfig.layout()
	buildings = []
	for b in lay.buildings:
		buildings.append({
			id = String(b.id), type = String(b.type), x = int(b.x), z = int(b.z),
			rot = int(b.rotation_quarters), level = int(b.level),
			build_left = 0.0, deco = Decor.defaults(String(b.type)),
		})
	interior_fences = {}
	for e in lay.interior_fence_edges:
		interior_fences[GridLogic.edge_key(Vector2i(int(e.from[0]), int(e.from[1])), Vector2i(int(e.to[0]), int(e.to[1])))] = true
	var init: Dictionary = lay.initial_state
	wood = int(init.wood)
	wood_frac = 0.0
	ready_stage = int(init.ready_stage)
	highest_cleared = int(init.highest_stage_cleared)
	raid_ready = String(init.mode) == MODE_RAID_READY
	raid_timer = -1.0 if init.raid_timer_seconds == null else float(init.raid_timer_seconds)
	last_resolved_battle_id = 0 if init.last_resolved_battle_id == null else int(init.last_resolved_battle_id)
	battle_seq = last_resolved_battle_id
	rng_seed = randi()
	_rng.seed = rng_seed
	consecutive_losses = 0
	assist_enabled = bool(GameConfig.raids().get("assist", {}).get("enabled_default", false))
	expansions = []
	story_seen = {}
	sync_castle_level()
	mode = idle_mode()
	changed.emit()


func idle_mode() -> String:
	return MODE_RAID_READY if raid_ready else MODE_VILLAGE


# ---------------------------------------------------------------- 시간 흐름

## 전면 실행 중 매 프레임 호출. delta 는 호출 측에서 상한을 둔다.
func tick(delta: float) -> void:
	var econ := GameConfig.economy()
	if mode in econ.income_states:
		var rate := income_rate()
		if wood >= capacity():
			wood_frac = 0.0
		else:
			wood_frac += rate * delta
			if wood_frac >= 1.0:
				var whole := int(floor(wood_frac))
				wood_frac -= whole
				wood = mini(wood + whole, capacity())
				changed.emit()
	if mode in GameConfig.construction().progress_states:
		for b in buildings:
			if float(b.build_left) > 0.0:
				b.build_left = maxf(0.0, float(b.build_left) - delta)
				if b.build_left <= 0.0:
					b.erase("repairing")
					construction_finished.emit(b.id)
					changed.emit()
	if not raid_ready and raid_timer >= 0.0 and mode in GameConfig.raids().timer_states:
		raid_timer -= delta
		if raid_timer <= 0.0:
			raid_timer = -1.0
			raid_ready = true
			if mode == MODE_VILLAGE:
				mode = MODE_RAID_READY
			raid_became_ready.emit()
			changed.emit()


## 초당 목재: 완성된 벌목소 + 멀쩡한 앞마당
func income_rate() -> float:
	var rate := 0.0
	for b in buildings:
		if not is_built(b):
			continue
		if b.type == "lumber_camp":
			rate += float(GameConfig.economy().income_per_second)
		elif b.type == "outpost" and not bool(b.get("damaged", false)):
			rate += float(GameConfig.building_def("outpost").get("income_per_second", 0))
	return rate


func capacity() -> int:
	return int(GameConfig.economy().capacity)


## 상한을 지켜 목재를 더하고 실제 더한 양을 돌려준다.
func add_wood(amount: int) -> int:
	var before := wood
	wood = clampi(wood + amount, 0, capacity())
	changed.emit()
	return wood - before


# ---------------------------------------------------------------- 조회

func count_type(type: String) -> int:
	var n := 0
	for b in buildings:
		if b.type == type:
			n += 1
	return n


func get_building(id: String) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}


func building_at(cell: Vector2i) -> Dictionary:
	for b in buildings:
		if cell in GridLogic.footprint_cells(b):
			return b
	return {}


func is_built(b: Dictionary) -> bool:
	return float(b.get("build_left", 0.0)) <= 0.0


static func build_seconds(type: String) -> float:
	return float(GameConfig.building_def(type).get("build_seconds", 0.0))


## 0~1 공사 진행률(완성 = 1)
func build_progress(b: Dictionary) -> float:
	var total := build_seconds(b.type)
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - float(b.get("build_left", 0.0)) / total, 0.0, 1.0)


func constructing() -> Array:
	var out: Array = []
	for b in buildings:
		if not is_built(b):
			out.append(b)
	return out


func bounds() -> Rect2i:
	return GameConfig.bounds_for(expansions)


func all_edges() -> Dictionary:
	return GridLogic.all_edges(interior_fences, bounds())


## 성 레벨 = 1 + 끝낸 장 수(최종장 제외, 최대 성 레벨). 클리어 단계에서 파생하므로 저장값과 어긋나지 않는다.
static func castle_level_for(cleared: int) -> int:
	var lv := 1
	for c in GameConfig.chapters():
		if int(c.id) < GameConfig.chapters().size() and cleared >= int(c.last_stage):
			lv += 1
	return mini(lv, GameConfig.max_castle_level())


func castle_level() -> int:
	return castle_level_for(highest_cleared)


func sync_castle_level() -> void:
	var c := GridLogic.castle_of(buildings)
	if not c.is_empty():
		c.level = castle_level()


func castle_hp() -> int:
	return GameConfig.castle_hp(castle_level())


## 지금 성 레벨에서 허용되는 수량(레벨별 max_counts 를 누적, 없으면 건물 기본 한도)
static func limit_for(type: String, level: int) -> int:
	var lim := int(GameConfig.building_def(type).get("max_count", 0))
	var found := -1
	for lv in range(1, level + 1):
		var mc: Dictionary = GameConfig.castle_level_def(lv).get("max_counts", {})
		if mc.has(type):
			found = int(mc[type])
	return lim if found < 0 else mini(found, lim)


func max_count(type: String) -> int:
	return limit_for(type, castle_level())


## 이 수량을 처음 허용하는 성 레벨(잠긴 안내용). 없으면 -1
static func unlock_level_for(type: String) -> int:
	for lv in range(1, GameConfig.max_castle_level() + 1):
		if limit_for(type, lv) > 0:
			return lv
	return -1


## 지금 열려 있는 땅 넓히기 방향
func unlocked_expansions() -> Array:
	var out: Array = []
	for lv in range(1, castle_level() + 1):
		for d in GameConfig.castle_level_def(lv).get("expansions", []):
			out.append(String(d))
	return out


func build_cost(type: String) -> int:
	return int(GameConfig.building_def(type).get("build_cost", 0))


func upgrade_cost(b: Dictionary) -> int:
	if b.type != "defense_tower":
		return -1
	var next := GameConfig.tower_level(int(b.level) + 1)
	if next.is_empty():
		return -1
	return int(next.get("upgrade_cost", -1))


func next_id(type: String) -> String:
	var prefix: String = {house = "house", defense_tower = "tower", lumber_camp = "lumber", castle = "castle", outpost = "outpost", flowerbed = "flower", lantern = "lantern"}.get(type, type)
	var n := 1
	while true:
		var id := "%s_%02d" % [prefix, n]
		if get_building(id).is_empty():
			return id
		n += 1
	return ""


# ---------------------------------------------------------------- 확정 동작(원자적)

## 새 건물 구매. 검증이 모두 통과할 때만 추가와 차감을 한 번에 적용한다.
func check_new_building(type: String, x: int, z: int, rot: int) -> Dictionary:
	var def := GameConfig.building_def(type)
	if def.is_empty() or not def.has("build_cost"):
		return {ok = false, reason = "지을 수 없는 건물이에요"}
	if max_count(type) <= 0:
		return {ok = false, reason = "성 Lv.%d에서 열려요" % unlock_level_for(type)}
	if count_type(type) >= max_count(type):
		return {ok = false, reason = "최대 %d개까지 지을 수 있어요" % max_count(type)}
	var v := GridLogic.validate_building(buildings, interior_fences, {id = "__new__", type = type, x = x, z = z, rot = rot}, "", bounds())
	if not v.ok:
		return v
	if wood < build_cost(type):
		return {ok = false, reason = "목재가 부족해요"}
	return {ok = true, reason = ""}


func commit_new_building(type: String, x: int, z: int, rot: int) -> Dictionary:
	var v := check_new_building(type, x, z, rot)
	if not v.ok:
		return v
	var b := {id = next_id(type), type = type, x = x, z = z, rot = posmod(rot, 4), level = 1,
		build_left = build_seconds(type), deco = Decor.defaults(type)}
	wood -= build_cost(type)
	buildings.append(b)
	changed.emit()
	return {ok = true, reason = "", id = b.id}


func check_move(id: String, x: int, z: int, rot: int) -> Dictionary:
	var b := get_building(id)
	if b.is_empty():
		return {ok = false, reason = "건물을 찾을 수 없어요"}
	if not bool(GameConfig.building_def(b.type).get("movable", false)):
		return {ok = false, reason = "성은 옮길 수 없어요"}
	if not is_built(b) and not bool(GameConfig.construction().move_while_constructing):
		return {ok = false, reason = "공사 중에는 옮길 수 없어요"}
	return GridLogic.validate_building(buildings, interior_fences, {id = id, type = b.type, x = x, z = z, rot = rot}, id, bounds())


func commit_move(id: String, x: int, z: int, rot: int) -> Dictionary:
	var v := check_move(id, x, z, rot)
	if not v.ok:
		return v
	var b := get_building(id)
	b.x = x
	b.z = z
	b.rot = posmod(rot, 4)
	changed.emit()
	return {ok = true, reason = ""}


func check_upgrade(id: String) -> Dictionary:
	var b := get_building(id)
	if b.is_empty():
		return {ok = false, reason = "건물을 찾을 수 없어요"}
	var cost := upgrade_cost(b)
	if cost < 0:
		return {ok = false, reason = "최대 레벨이에요"}
	if not is_built(b) and not bool(GameConfig.construction().upgrade_while_constructing):
		return {ok = false, reason = "공사가 끝나면 강화할 수 있어요"}
	if wood < cost:
		return {ok = false, reason = "목재가 부족해요"}
	return {ok = true, reason = "", cost = cost}


func commit_upgrade(id: String) -> Dictionary:
	var v := check_upgrade(id)
	if not v.ok:
		return v
	var b := get_building(id)
	wood -= int(v.cost)
	b.level = int(b.level) + 1
	changed.emit()
	return v


## 꾸미기 적용(무료, 외형 전용). 알 수 없는 값은 기본값으로 정리된다.
func commit_decor(id: String, deco: Dictionary) -> Dictionary:
	var b := get_building(id)
	if b.is_empty():
		return {ok = false, reason = "건물을 찾을 수 없어요"}
	if not Decor.has_parts(b.type):
		return {ok = false, reason = "꾸밀 수 없는 건물이에요"}
	b.deco = Decor.sanitize(b.type, deco)
	changed.emit()
	return {ok = true, reason = ""}


func check_fences(add: Dictionary, remove: Dictionary) -> Dictionary:
	var v := GridLogic.validate_fences(buildings, interior_fences, add, remove, bounds())
	if v.ok and wood < int(v.cost):
		return {ok = false, reason = "목재가 부족해요", cost = v.cost}
	return v


func commit_fences(add: Dictionary, remove: Dictionary) -> Dictionary:
	var v := check_fences(add, remove)
	if not v.ok:
		return v
	wood -= int(v.cost)
	interior_fences = v.result
	changed.emit()
	return v


# ---------------------------------------------------------------- 습격

# ---------------------------------------------------------------- 땅 넓히기(3차)

func check_expand(dir: String) -> Dictionary:
	var e := GameConfig.expansion_def(dir)
	if e.is_empty():
		return {ok = false, reason = "알 수 없는 방향이에요"}
	if expansions.has(dir):
		return {ok = false, reason = "이미 넓힌 땅이에요"}
	if not unlocked_expansions().has(dir):
		for lv in range(1, GameConfig.max_castle_level() + 1):
			if (GameConfig.castle_level_def(lv).get("expansions", []) as Array).has(dir):
				return {ok = false, reason = "성 Lv.%d에서 열려요" % lv}
		return {ok = false, reason = "아직 열리지 않았어요"}
	var next := GameConfig.bounds_for(expansions + [dir])
	var mx: Array = GameConfig.map_config().get("max_size", [99, 99])
	if next.size.x > int(mx[0]) or next.size.y > int(mx[1]):
		return {ok = false, reason = "지도 최대 크기예요"}
	if GridLogic.find_route(buildings, GridLogic.all_edges(interior_fences, next), next).is_empty():
		return {ok = false, reason = GridLogic.REASON_NO_ROUTE}
	if wood < int(e.cost):
		return {ok = false, reason = "목재가 부족해요"}
	return {ok = true, reason = "", cost = int(e.cost)}


func commit_expand(dir: String) -> Dictionary:
	var v := check_expand(dir)
	if not v.ok:
		return v
	wood -= int(v.cost)
	expansions.append(dir)
	changed.emit()
	return v


# ---------------------------------------------------------------- 앞마당(3차)

func outposts() -> Array:
	var out: Array = []
	for b in buildings:
		if b.type == "outpost":
			out.append(b)
	return out


## 전투에서 점령당한 앞마당: 생산만 멈춘다(영구 손실 없음)
func mark_outpost_lost(id: String) -> void:
	var b := get_building(id)
	if b.is_empty():
		return
	b.damaged = true
	changed.emit()


func check_repair(id: String) -> Dictionary:
	var b := get_building(id)
	if b.is_empty() or not bool(b.get("damaged", false)):
		return {ok = false, reason = "고칠 곳이 없어요"}
	var cost := int(GameConfig.building_def(b.type).get("repair_cost", 0))
	if wood < cost:
		return {ok = false, reason = "목재가 부족해요"}
	return {ok = true, reason = "", cost = cost}


## 수리: 공사 시스템을 그대로 써서 일꾼이 와서 고친다
func commit_repair(id: String) -> Dictionary:
	var v := check_repair(id)
	if not v.ok:
		return v
	var b := get_building(id)
	wood -= int(v.cost)
	b.damaged = false
	b.repairing = true
	b.build_left = float(GameConfig.building_def(b.type).get("repair_seconds", 10))
	changed.emit()
	return v


func stage_label(stage_id: int) -> String:
	return String(GameConfig.stage(stage_id).get("label", "%d단계 습격" % stage_id))


## 준비된 습격을 시작한다. 호출 측은 직전에 저장해 준비 상태 스냅샷을 남긴다.
func begin_battle() -> Dictionary:
	if mode != MODE_RAID_READY or not raid_ready:
		return {ok = false, reason = "습격이 준비되지 않았어요"}
	if GridLogic.find_route(buildings, all_edges(), bounds()).is_empty():
		return {ok = false, reason = GridLogic.REASON_NO_ROUTE}
	battle_seq += 1
	current_battle_id = battle_seq
	current_battle_stage = ready_stage
	mode = MODE_BATTLE
	changed.emit()
	return {ok = true, battle_id = current_battle_id, stage = ready_stage, hp_multiplier = assist_multiplier(),
		castle_hp = castle_hp(), bounds = bounds()}


## 도움 모드가 켜져 있고 같은 단계에서 연속으로 졌을 때만 1보다 작아진다.
func assist_multiplier() -> float:
	var a: Dictionary = GameConfig.raids().get("assist", {})
	if not assist_enabled or a.is_empty():
		return 1.0
	var after := int(a.after_losses)
	if consecutive_losses < after:
		return 1.0
	return maxf(float(a.min_multiplier), pow(float(a.hp_multiplier_step), consecutive_losses - after + 1))


## 전투 결과를 한 번만 반영한다. 같은 battle_id 를 다시 넣으면 아무것도 바뀌지 않는다.
func resolve_battle(battle_id: int, stage_id: int, won: bool) -> Dictionary:
	if battle_id <= last_resolved_battle_id:
		return {applied = false, reward = 0, won = won, stage = stage_id}
	last_resolved_battle_id = battle_id
	var reward := 0
	var level_before := castle_level()
	consecutive_losses = 0 if won else consecutive_losses + 1
	if won:
		reward = add_wood(int(GameConfig.stage(stage_id).win_wood))
		highest_cleared = maxi(highest_cleared, stage_id)
		if stage_id < GameConfig.stage_count():
			ready_stage = stage_id + 1
			raid_ready = false
			var r: Array = GameConfig.raids().next_ready_delay_seconds
			raid_timer = _rng.randf_range(float(r[0]), float(r[1]))
		else:
			ready_stage = stage_id
			raid_ready = true
			raid_timer = -1.0
	else:
		ready_stage = stage_id
		raid_ready = true
		raid_timer = -1.0
	mode = MODE_RESULT
	sync_castle_level()
	var level_after := castle_level()
	var ch := GameConfig.chapter_of_stage(stage_id)
	var chapter_cleared := 0
	if won and not ch.is_empty() and stage_id == int(ch.last_stage):
		if level_after > level_before or (int(ch.id) == GameConfig.chapters().size() and not story_seen.has("ending")):
			chapter_cleared = int(ch.id)
	if level_after > level_before:
		castle_leveled.emit(level_after)
	changed.emit()
	return {applied = true, reward = reward, won = won, stage = stage_id, chapter_cleared = chapter_cleared,
		castle_level_before = level_before, castle_level = level_after}


## 경로 상실·진행 정지 등으로 전투를 취소. 보상 없이 준비 상태로.
func abort_battle() -> void:
	if current_battle_id > last_resolved_battle_id:
		last_resolved_battle_id = current_battle_id
	raid_ready = true
	ready_stage = current_battle_stage if current_battle_stage > 0 else ready_stage
	mode = MODE_RAID_READY
	changed.emit()


func leave_result() -> void:
	mode = idle_mode()
	changed.emit()


# ---------------------------------------------------------------- 저장 형식

func to_dict() -> Dictionary:
	var bl: Array = []
	for b in buildings:
		var e := {id = b.id, type = b.type, x = int(b.x), z = int(b.z), rot = int(b.rot), level = int(b.level),
			build_left = snappedf(float(b.get("build_left", 0.0)), 0.001), deco = Decor.sanitize(b.type, b.get("deco", {}))}
		if bool(b.get("damaged", false)):
			e.damaged = true
		if bool(b.get("repairing", false)):
			e.repairing = true
		bl.append(e)
	var fences: Array = interior_fences.keys()
	fences.sort()
	return {
		version = SAVE_VERSION,
		buildings = bl,
		interior_fences = fences,
		wood = wood,
		wood_frac = wood_frac,
		ready_stage = ready_stage,
		highest_cleared = highest_cleared,
		raid_ready = raid_ready,
		raid_timer = raid_timer,
		last_resolved_battle_id = last_resolved_battle_id,
		battle_seq = battle_seq,
		rng_seed = rng_seed,
		rng_state = str(_rng.state),
		consecutive_losses = consecutive_losses,
		assist_enabled = assist_enabled,
		expansions = expansions.duplicate(),
		story_seen = _sorted_keys(story_seen),
	}


static func _sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k


## 저장 데이터 검사. 문제가 있으면 사유 문자열, 정상이면 "".
static func validate_dict(d) -> String:
	if typeof(d) != TYPE_DICTIONARY:
		return "형식 오류"
	for key in ["version", "buildings", "interior_fences", "wood", "ready_stage", "highest_cleared", "raid_ready", "raid_timer", "last_resolved_battle_id", "battle_seq"]:
		if not d.has(key):
			return "누락: %s" % key
	if int(d.version) < 1 or int(d.version) > SAVE_VERSION:
		return "버전 불일치"
	if typeof(d.buildings) != TYPE_ARRAY or typeof(d.interior_fences) != TYPE_ARRAY:
		return "형식 오류"
	var ids := {}
	var counts := {}
	var bl: Array = []
	for b in d.buildings:
		if typeof(b) != TYPE_DICTIONARY:
			return "건물 형식 오류"
		for key in ["id", "type", "x", "z", "rot", "level"]:
			if not b.has(key):
				return "건물 누락: %s" % key
		var def := GameConfig.building_def(String(b.type))
		if def.is_empty():
			return "알 수 없는 건물"
		if ids.has(b.id):
			return "중복 ID"
		ids[b.id] = true
		counts[b.type] = int(counts.get(b.type, 0)) + 1
		if int(b.level) < 1 or int(b.level) > int(def.max_level):
			return "레벨 범위 오류"
		if int(b.rot) < 0 or int(b.rot) > 3:
			return "회전 범위 오류"
		var left := float(b.get("build_left", 0.0))
		var max_left := maxf(build_seconds(String(b.type)), float(def.get("repair_seconds", 0.0)))
		if left < 0.0 or left > max_left + 0.001:
			return "공사 시간 범위 오류"
		bl.append({id = String(b.id), type = String(b.type), x = int(b.x), z = int(b.z), rot = int(b.rot), level = int(b.level)})
	var exps: Array = d.get("expansions", [])
	if typeof(exps) != TYPE_ARRAY:
		return "확장 형식 오류"
	var seen_dirs := {}
	for e in exps:
		if GameConfig.expansion_def(String(e)).is_empty() or seen_dirs.has(String(e)):
			return "확장 오류"
		seen_dirs[String(e)] = true
	var bnds := GameConfig.bounds_for(exps)
	var mx: Array = GameConfig.map_config().get("max_size", [99, 99])
	if bnds.size.x > int(mx[0]) or bnds.size.y > int(mx[1]):
		return "지도 크기 오류"
	for type in counts:
		if counts[type] > int(GameConfig.building_def(type).max_count):
			return "수량 한도 초과"
	if int(counts.get("castle", 0)) != 1 or int(counts.get("lumber_camp", 0)) < 1:
		return "성·벌목소 수 오류"
	var castle := GridLogic.castle_of(bl)
	for lb in GameConfig.layout().buildings:
		if lb.type == "castle" and (int(lb.x) != castle.x or int(lb.z) != castle.z):
			return "성 위치 오류"
	var placed: Array = []
	var fences := {}
	for k in d.interior_fences:
		if typeof(k) != TYPE_STRING or not GridLogic.is_interior_edge(k, bnds) or fences.has(k):
			return "울타리 오류"
		fences[k] = true
	for b in bl:
		var v := GridLogic.validate_building(placed, fences, b, "", bnds)
		# 경로 검사는 전체가 놓인 뒤 한 번만 한다.
		if not v.ok and v.reason != GridLogic.REASON_NO_ROUTE:
			return "배치 오류: %s" % v.reason
		placed.append(b)
	if GridLogic.find_route(bl, GridLogic.all_edges(fences, bnds), bnds).is_empty():
		return "경로 없음"
	var cap := int(GameConfig.economy().capacity)
	if int(d.wood) < 0 or int(d.wood) > cap:
		return "목재 범위 오류"
	if int(d.ready_stage) < 1 or int(d.ready_stage) > GameConfig.stage_count():
		return "단계 범위 오류"
	if int(d.highest_cleared) < 0 or int(d.highest_cleared) > GameConfig.stage_count():
		return "단계 범위 오류"
	if int(d.last_resolved_battle_id) > int(d.battle_seq):
		return "전투 ID 오류"
	return ""


func from_dict(d: Dictionary) -> void:
	buildings = []
	# 버전 1 저장본: 공사 없음·꾸미기 기본값으로 이어받는다
	for b in d.buildings:
		var nb := {id = String(b.id), type = String(b.type), x = int(b.x), z = int(b.z), rot = int(b.rot), level = int(b.level),
			build_left = float(b.get("build_left", 0.0)), deco = Decor.sanitize(String(b.type), b.get("deco", {}))}
		if bool(b.get("damaged", false)):
			nb.damaged = true
		if bool(b.get("repairing", false)) and nb.build_left > 0.0:
			nb.repairing = true
		buildings.append(nb)
	interior_fences = {}
	for k in d.interior_fences:
		interior_fences[String(k)] = true
	wood = int(d.wood)
	wood_frac = clampf(float(d.get("wood_frac", 0.0)), 0.0, 0.999)
	ready_stage = int(d.ready_stage)
	highest_cleared = int(d.highest_cleared)
	raid_ready = bool(d.raid_ready)
	raid_timer = float(d.raid_timer)
	if not raid_ready and raid_timer < 0.0:
		raid_ready = true
	last_resolved_battle_id = int(d.last_resolved_battle_id)
	battle_seq = int(d.battle_seq)
	rng_seed = int(d.get("rng_seed", 0))
	_rng.seed = rng_seed
	if d.has("rng_state"):
		_rng.state = int(String(d.rng_state))
	consecutive_losses = maxi(0, int(d.get("consecutive_losses", 0)))
	assist_enabled = bool(d.get("assist_enabled", false))
	# 버전 2 이하: 확장 없음. 이미 지나간 장의 장면은 본 것으로 처리(되돌아가 보여 주지 않음)
	expansions = []
	for e in d.get("expansions", []):
		expansions.append(String(e))
	story_seen = {}
	for sid in d.get("story_seen", []):
		story_seen[String(sid)] = true
	if int(d.version) < 3:
		_mark_past_story_seen()
	sync_castle_level()
	mode = idle_mode()
	current_battle_id = 0
	current_battle_stage = 0
	changed.emit()


## 이전 버전 저장본을 이어받을 때, 이미 지나온 장의 장면은 다시 띄우지 않는다
func _mark_past_story_seen() -> void:
	if highest_cleared > 0 or battle_seq > 0:
		story_seen["prologue"] = true
	for c in GameConfig.chapters():
		if highest_cleared >= int(c.last_stage):
			story_seen["ch%d_end" % int(c.id)] = true
			story_seen["ch%d_start" % (int(c.id) + 1)] = true
