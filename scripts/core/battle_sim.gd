class_name BattleSim
extends RefCounted
## 고정 간격으로 진행하는 결정적 전투 시뮬레이션. 화면은 이 상태를 읽어 그리기만 한다.

const STEP := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 6

var stage_id: int = 1
var total: int = 0
var spawned: int = 0
var killed: int = 0
var knight_hp: int = 0
var castle_hp: int = 0
var castle_max: int = 0
var time: float = 0.0
var outcome: String = ""          # "", "win", "lose", "abort"
var abort_reason: String = ""

var knights: Array = []
var towers: Array = []
var bolts: Array = []
## 화면 연출용 이벤트(소비 측이 비운다)
var events: Array = []

var route: Array[Vector2i] = []
## 기사들이 나눠 갈 공격 칸별 경로 [{cell, path, castle_cell}] (짧은 순)
var lanes: Array = []
var _lane_counts: Dictionary = {}
## 도움 모드 적용 배율(1.0 = 정상)
var hp_multiplier: float = 1.0
## 공사 중이라 전투에 참여하지 않은 방어탑 ID
var constructing_towers: Array[String] = []
var castle_center := Vector2.ZERO

var _spawn_timer: float = 0.0
var _watchdog: float = 0.0
var _accum: float = 0.0
var _next_bolt_id: int = 1
var _c: Dictionary


func setup(buildings: Array, edges: Dictionary, p_stage: int, p_hp_multiplier: float = 1.0) -> void:
	_c = GameConfig.combat()
	stage_id = p_stage
	var st := GameConfig.stage(p_stage)
	total = int(st.knight_count)
	hp_multiplier = clampf(p_hp_multiplier, 0.1, 1.0)
	knight_hp = maxi(1, int(round(int(st.knight_hp) * hp_multiplier)))
	castle_max = int(GameConfig.building_def("castle").hp)
	castle_hp = castle_max
	route = GridLogic.find_route(buildings, edges)
	var castle := GridLogic.castle_of(buildings)
	var cfp := GameConfig.footprint("castle")
	castle_center = Vector2(castle.x + cfp.x * 0.5, castle.z + cfp.y * 0.5)
	_build_lanes(buildings, edges, castle)
	towers = []
	for b in buildings:
		if b.type != "defense_tower":
			continue
		if float(b.get("build_left", 0.0)) > 0.0 and not bool(GameConfig.construction().get("towers_fight_while_constructing", false)):
			constructing_towers.append(String(b.id))
			continue
		var fp := GameConfig.footprint(b.type)
		var lv := GameConfig.tower_level(int(b.level))
		towers.append({
			id = b.id, level = int(b.level),
			center = Vector2(b.x + fp.x * 0.5, b.z + fp.y * 0.5),
			damage = int(lv.damage), range = float(lv.range_cells), cooldown = float(lv.cooldown_seconds),
			cooldown_left = 0.0, target_id = -1, aim = Vector2(0, -1), shots = 0,
		})
	if route.is_empty():
		_abort(GridLogic.REASON_NO_ROUTE)


func remaining() -> int:
	return total - killed


func alive_knights() -> Array:
	var out: Array = []
	for k in knights:
		if k.alive:
			out.append(k)
	return out


## 화면 프레임 시간으로 진행. 큰 delta 는 잘라서 복귀 시 몰아서 진행하지 않는다.
func advance(delta: float) -> void:
	_accum += minf(delta, STEP * MAX_STEPS_PER_FRAME)
	while _accum >= STEP and outcome == "":
		_accum -= STEP
		step(STEP)


func step(dt: float) -> void:
	if outcome != "":
		return
	time += dt
	var progress := false
	# 1. 등장
	_spawn_timer -= dt
	while spawned < total and _spawn_timer <= 0.0:
		_spawn_knight()
		_spawn_timer += float(_c.spawn_interval_seconds)
		progress = true
	# 2. 이동과 성 공격
	var speed := float(_c.knight_move_cells_per_second)
	for k in knights:
		if not k.alive:
			continue
		for t in towers:
			if (t.center as Vector2).distance_to(k.pos) <= float(t.range):
				k.time_in_range = float(k.get("time_in_range", 0.0)) + dt
				break
		if k.state == "attack":
			k.reached = true
		if k.state == "walk":
			var before: float = k.remaining_dist
			var move := speed * dt
			while move > 0.0 and k.wp < k.waypoints.size():
				var target: Vector2 = k.waypoints[k.wp]
				var to: Vector2 = target - k.pos
				var d := to.length()
				if d <= move:
					k.pos = target
					move -= d
					k.wp += 1
				else:
					k.pos += to / d * move
					k.facing = to / d
					move = 0.0
			k.remaining_dist = _remaining_dist(k)
			if k.remaining_dist < before - 0.0001:
				progress = true
			if k.wp >= k.waypoints.size():
				k.state = "attack"
				k.attack_timer = float(_c.knight_first_attack_after_seconds)
				var cc: Vector2i = k.get("castle_cell", Vector2i(int(castle_center.x), int(castle_center.y)))
				k.facing = (Vector2(cc.x + 0.5, cc.y + 0.5) - k.pos).normalized()
				events.append({type = "arrive", knight = k.id})
		elif k.state == "attack":
			k.attack_timer -= dt
			if k.attack_timer <= 0.0:
				k.attack_timer += float(_c.knight_attack_interval_seconds)
				castle_hp -= int(_c.knight_attack_damage)
				progress = true
				events.append({type = "castle_hit", knight = k.id, damage = int(_c.knight_attack_damage)})
	# 3. 방어탑 조준·발사
	for t in towers:
		t.cooldown_left = maxf(0.0, t.cooldown_left - dt)
		var target := _pick_target(t)
		t.target_id = -1 if target.is_empty() else int(target.id)
		if target.is_empty():
			continue
		t.engaged_time = float(t.get("engaged_time", 0.0)) + dt
		t.aim = (target.pos - t.center).normalized()
		if t.cooldown_left <= 0.0:
			t.cooldown_left = t.cooldown
			t.shots += 1
			bolts.append({id = _next_bolt_id, tower_id = t.id, target_id = target.id, pos = t.center, start = t.center, damage = t.damage, alive = true})
			events.append({type = "fire", tower = t.id, bolt = _next_bolt_id, target = target.id})
			_next_bolt_id += 1
	# 4. 발사체
	var bolt_speed := float(_c.bolt_speed_cells_per_second)
	for bolt in bolts:
		if not bolt.alive:
			continue
		var tk := _knight_by_id(bolt.target_id)
		if tk.is_empty() or not tk.alive:
			bolt.alive = false
			events.append({type = "bolt_fizzle", bolt = bolt.id})
			continue
		var to: Vector2 = tk.pos - bolt.pos
		var d := to.length()
		var move := bolt_speed * dt
		if d <= move:
			bolt.pos = tk.pos
			bolt.alive = false
			tk.hp -= int(bolt.damage)
			tk.damage_taken = int(tk.get("damage_taken", 0)) + int(bolt.damage)
			progress = true
			events.append({type = "hit", bolt = bolt.id, knight = tk.id, damage = bolt.damage})
			if tk.hp <= 0 and tk.alive:
				tk.alive = false
				killed += 1
				events.append({type = "kill", knight = tk.id})
		else:
			bolt.pos += to / d * move
	bolts = bolts.filter(func(b): return b.alive)
	# 5. 종료(같은 갱신에서 둘 다 성립하면 패배 우선)
	if castle_hp <= 0:
		castle_hp = 0
		outcome = "lose"
	elif spawned >= total and remaining() == 0:
		outcome = "win"
	if outcome != "":
		return
	# 6. 진행 감시
	if progress:
		_watchdog = 0.0
	else:
		_watchdog += dt
		if _watchdog >= float(_c.progress_watchdog_seconds):
			_abort("전투가 진행되지 않아 준비 상태로 돌아갔어요")


func _abort(reason: String) -> void:
	outcome = "abort"
	abort_reason = reason
	push_warning("전투 중단: %s" % reason)


## 성의 공격 칸마다 최단 경로를 구해, 가장 짧은 길보다 max_detour 칸 이내인 칸들을 '갈래'로 쓴다.
func _build_lanes(buildings: Array, edges: Dictionary, castle: Dictionary) -> void:
	lanes = []
	if route.is_empty():
		return
	var sp: Dictionary = _c.get("spread", {})
	if not bool(sp.get("enabled", false)):
		lanes.append({cell = route[route.size() - 1], path = route, castle_cell = _castle_neighbor(route[route.size() - 1], castle, edges)})
		return
	var goals := GridLogic.attack_cells(buildings, edges)
	var cand: Array = []
	for g in goals:
		var p := GridLogic.find_path(buildings, edges, GameConfig.entry_cell(), {g: true})
		if not p.is_empty():
			cand.append({cell = g, path = p, castle_cell = _castle_neighbor(g, castle, edges)})
	cand.sort_custom(func(a, b):
		if a.path.size() != b.path.size():
			return a.path.size() < b.path.size()
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y
		return a.cell.x < b.cell.x)
	var limit: int = route.size() + int(sp.get("max_detour_cells", 0))
	for c in cand:
		if c.path.size() <= limit:
			lanes.append(c)
	if lanes.is_empty():
		lanes.append({cell = route[route.size() - 1], path = route, castle_cell = _castle_neighbor(route[route.size() - 1], castle, edges)})


func _castle_neighbor(cell: Vector2i, castle: Dictionary, edges: Dictionary) -> Vector2i:
	var cells := GridLogic.footprint_cells(castle)
	for d in GridLogic.DIRS:
		var n: Vector2i = cell + d
		if n in cells and not GridLogic.blocks(edges, cell, n):
			return n
	return Vector2i(int(castle_center.x), int(castle_center.y))


func _spawn_knight() -> void:
	var spawn := GameConfig.spawn_world()
	var wps: Array = []
	var lane: Dictionary = lanes[spawned % lanes.size()] if not lanes.is_empty() else {path = route, castle_cell = Vector2i.ZERO}
	for c in lane.path:
		wps.append(Vector2(c.x + 0.5, c.y + 0.5))
	# 같은 칸에 몰리지 않도록 칸 안의 자리(slot)를 나눈다
	var key := str(lane.get("cell", Vector2i.ZERO))
	var slot := int(_lane_counts.get(key, 0))
	_lane_counts[key] = slot + 1
	var offsets: Array = _c.get("spread", {}).get("slot_offsets", [[0, 0]])
	var off: Array = offsets[slot % offsets.size()]
	if not wps.is_empty():
		var last: Vector2 = wps[wps.size() - 1]
		var toward := (Vector2(lane.castle_cell.x + 0.5, lane.castle_cell.y + 0.5) - last).normalized()
		var side := Vector2(-toward.y, toward.x)
		wps[wps.size() - 1] = last + side * float(off[0]) + toward * -float(off[1])
	var k := {
		id = spawned + 1, hp = knight_hp, max_hp = knight_hp, pos = spawn,
		waypoints = wps, wp = 0, state = "walk", attack_timer = 0.0, alive = true,
		facing = Vector2(0, 1), remaining_dist = 0.0, castle_cell = lane.castle_cell, lane = key,
		damage_taken = 0, time_in_range = 0.0,
	}
	k.remaining_dist = _remaining_dist(k)
	knights.append(k)
	spawned += 1
	events.append({type = "spawn", knight = k.id})


func _remaining_dist(k: Dictionary) -> float:
	if k.wp >= k.waypoints.size():
		return 0.0
	var d: float = k.pos.distance_to(k.waypoints[k.wp])
	for i in range(k.wp, k.waypoints.size() - 1):
		d += (k.waypoints[i] as Vector2).distance_to(k.waypoints[i + 1])
	return d


func _pick_target(t: Dictionary) -> Dictionary:
	var best := {}
	var best_d := INF
	for k in knights:
		if not k.alive:
			continue
		var d: float = t.center.distance_to(k.pos)
		if d > t.range:
			continue
		if d < best_d - 0.000001 or (absf(d - best_d) <= 0.000001 and int(k.id) < int(best.id)):
			best = k
			best_d = d
	return best


func _knight_by_id(id: int) -> Dictionary:
	if id >= 1 and id <= knights.size():
		return knights[id - 1]
	return {}


## 테스트·밸런스 점검용: 끝날 때까지 돌린다.
func run_to_end(max_seconds: float = 600.0) -> String:
	while outcome == "" and time < max_seconds:
		step(STEP)
	return outcome
