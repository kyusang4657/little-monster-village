class_name GameState
extends RefCounted
## 확정된 마을 상태와 규칙. 화면·입력과 분리되어 있어 자동 테스트로 검증한다.

signal changed
signal raid_became_ready
signal construction_finished(id: String)

const MODE_VILLAGE := "VILLAGE"
const MODE_BUILD := "BUILD"
const MODE_RAID_READY := "RAID_READY"
const MODE_BATTLE := "BATTLE"
const MODE_PAUSED := "PAUSED"
const MODE_RESULT := "RESULT"

const SAVE_VERSION := 2

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
	mode = idle_mode()
	changed.emit()


func idle_mode() -> String:
	return MODE_RAID_READY if raid_ready else MODE_VILLAGE


# ---------------------------------------------------------------- 시간 흐름

## 전면 실행 중 매 프레임 호출. delta 는 호출 측에서 상한을 둔다.
func tick(delta: float) -> void:
	var econ := GameConfig.economy()
	if mode in econ.income_states:
		var rate := float(econ.income_per_second) * count_type("lumber_camp")
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


func all_edges() -> Dictionary:
	return GridLogic.all_edges(interior_fences)


func max_count(type: String) -> int:
	return int(GameConfig.building_def(type).get("max_count", 0))


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
	var prefix: String = {house = "house", defense_tower = "tower", lumber_camp = "lumber", castle = "castle"}.get(type, type)
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
	if count_type(type) >= max_count(type):
		return {ok = false, reason = "최대 %d개까지 지을 수 있어요" % max_count(type)}
	var v := GridLogic.validate_building(buildings, interior_fences, {id = "__new__", type = type, x = x, z = z, rot = rot})
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
	return GridLogic.validate_building(buildings, interior_fences, {id = id, type = b.type, x = x, z = z, rot = rot}, id)


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
	var v := GridLogic.validate_fences(buildings, interior_fences, add, remove)
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

func stage_label(stage_id: int) -> String:
	return String(GameConfig.stage(stage_id).get("label", "%d단계 습격" % stage_id))


## 준비된 습격을 시작한다. 호출 측은 직전에 저장해 준비 상태 스냅샷을 남긴다.
func begin_battle() -> Dictionary:
	if mode != MODE_RAID_READY or not raid_ready:
		return {ok = false, reason = "습격이 준비되지 않았어요"}
	if GridLogic.find_route(buildings, all_edges()).is_empty():
		return {ok = false, reason = GridLogic.REASON_NO_ROUTE}
	battle_seq += 1
	current_battle_id = battle_seq
	current_battle_stage = ready_stage
	mode = MODE_BATTLE
	changed.emit()
	return {ok = true, battle_id = current_battle_id, stage = ready_stage, hp_multiplier = assist_multiplier()}


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
	changed.emit()
	return {applied = true, reward = reward, won = won, stage = stage_id}


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
		bl.append({id = b.id, type = b.type, x = int(b.x), z = int(b.z), rot = int(b.rot), level = int(b.level),
			build_left = snappedf(float(b.get("build_left", 0.0)), 0.001), deco = Decor.sanitize(b.type, b.get("deco", {}))})
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
	}


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
		if left < 0.0 or left > build_seconds(String(b.type)) + 0.001:
			return "공사 시간 범위 오류"
		bl.append({id = String(b.id), type = String(b.type), x = int(b.x), z = int(b.z), rot = int(b.rot), level = int(b.level)})
	for type in counts:
		if counts[type] > int(GameConfig.building_def(type).max_count):
			return "수량 한도 초과"
	if int(counts.get("castle", 0)) != 1 or int(counts.get("lumber_camp", 0)) != 1:
		return "성·벌목소 수 오류"
	var castle := GridLogic.castle_of(bl)
	for lb in GameConfig.layout().buildings:
		if lb.type == "castle" and (int(lb.x) != castle.x or int(lb.z) != castle.z):
			return "성 위치 오류"
	var placed: Array = []
	var fences := {}
	for k in d.interior_fences:
		if typeof(k) != TYPE_STRING or not GridLogic.is_interior_edge(k) or fences.has(k):
			return "울타리 오류"
		fences[k] = true
	for b in bl:
		var v := GridLogic.validate_building(placed, fences, b)
		# 경로 검사는 전체가 놓인 뒤 한 번만 한다.
		if not v.ok and v.reason != GridLogic.REASON_NO_ROUTE:
			return "배치 오류: %s" % v.reason
		placed.append(b)
	if GridLogic.find_route(bl, GridLogic.all_edges(fences)).is_empty():
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
		buildings.append({id = String(b.id), type = String(b.type), x = int(b.x), z = int(b.z), rot = int(b.rot), level = int(b.level),
			build_left = float(b.get("build_left", 0.0)), deco = Decor.sanitize(String(b.type), b.get("deco", {}))})
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
	mode = idle_mode()
	current_battle_id = 0
	current_battle_stage = 0
	changed.emit()
