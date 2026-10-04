class_name BattleSim
extends RefCounted
## 고정 간격으로 진행하는 결정적 전투 시뮬레이션. 화면은 이 상태를 읽어 그리기만 한다.
## 3차: 넓어진 지도(경계), 성 레벨별 체력, 보스 유닛(용사·기사단장), 앞마당을 노리는 소대.

const STEP := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 6

var stage_id: int = 1
var total: int = 0
var spawned: int = 0
var killed: int = 0
## 일반 기사 체력(도움 모드 적용 후). 보스는 유닛별 체력을 쓴다.
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
## 기사들이 나눠 갈 성 공격 칸별 경로 [{cell, path, castle_cell}] (짧은 순)
var lanes: Array = []
## 앞마당 공격 칸별 경로(앞마당이 있을 때만)
var outpost_lanes: Array = []
var _lane_counts: Dictionary = {}
## 도움 모드 적용 배율(1.0 = 정상)
var hp_multiplier: float = 1.0
## 공사 중이라 전투에 참여하지 않은 방어탑 ID
var constructing_towers: Array[String] = []
var castle_center := Vector2.ZERO
var bounds := Rect2i()
## 앞마당: {} 이면 없음. {id, hp, max_hp, captured, center}
var outpost: Dictionary = {}

var _units: Array = []
var _castle_spawns := 0
var _outpost_spawns := 0
var _buildings: Array = []
var _edges: Dictionary = {}
var _castle: Dictionary = {}
var _spawn_timer: float = 0.0
var _watchdog: float = 0.0
var _accum: float = 0.0
var _next_bolt_id: int = 1
var _c: Dictionary


## opts: castle_hp(성 레벨 체력, 기본 Lv.1), bounds(지도 경계, 기본 처음 지도)
func setup(buildings: Array, edges: Dictionary, p_stage: int, p_hp_multiplier: float = 1.0, opts: Dictionary = {}) -> void:
	_c = GameConfig.combat()
	stage_id = p_stage
	bounds = GridLogic.bnd(opts.get("bounds", Rect2i()))
	_buildings = buildings
	_edges = edges
	hp_multiplier = clampf(p_hp_multiplier, 0.1, 1.0)
	_units = GameConfig.stage_units(p_stage)
	total = _units.size()
	knight_hp = maxi(1, int(round(int(GameConfig.stage(p_stage).get("knight_hp", 90)) * hp_multiplier)))
	castle_max = int(opts.get("castle_hp", GameConfig.castle_hp(1)))
	castle_hp = castle_max
	route = GridLogic.find_route(buildings, edges, bounds)
	_castle = GridLogic.castle_of(buildings)
	var cfp := GameConfig.footprint("castle")
	castle_center = Vector2(_castle.x + cfp.x * 0.5, _castle.z + cfp.y * 0.5)
	lanes = _build_lanes_for(_castle, route)
	_setup_outpost()
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


## 멀쩡하고 완성된 앞마당이 있고 길이 닿으면 그곳을 노리는 소대를 만든다
func _setup_outpost() -> void:
	outpost = {}
	outpost_lanes = []
	for b in _buildings:
		if b.type != "outpost" or float(b.get("build_left", 0.0)) > 0.0 or bool(b.get("damaged", false)):
			continue
		var start := GameConfig.entry_cell_for(bounds)
		var p := GridLogic.find_path(_buildings, _edges, start, GridLogic.attack_cells_for(b, _buildings, _edges, bounds), bounds)
		if p.is_empty():
			continue
		var fp := GameConfig.footprint(b.type)
		var hp := int(GameConfig.building_def("outpost").get("battle_hp", 150))
		outpost = {id = String(b.id), hp = hp, max_hp = hp, captured = false, center = Vector2(b.x + fp.x * 0.5, b.z + fp.y * 0.5), building = b}
		outpost_lanes = _build_lanes_for(b, p)
		break


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
	# 2. 이동과 공격(성 또는 앞마당)
	for k in knights:
		if not k.alive:
			continue
		for t in towers:
			if (t.center as Vector2).distance_to(k.pos) <= float(t.range):
				k.time_in_range = float(k.get("time_in_range", 0.0)) + dt
				break
		if k.state == "attack" and k.target == "castle":
			k.reached = true
		if k.state == "walk":
			var before: float = k.remaining_dist
			var move := float(k.speed) * dt
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
				var cc: Vector2i = k.castle_cell
				k.facing = (Vector2(cc.x + 0.5, cc.y + 0.5) - k.pos).normalized()
				events.append({type = "arrive", knight = k.id})
		elif k.state == "attack":
			k.attack_timer -= dt
			if k.attack_timer <= 0.0:
				k.attack_timer += float(k.attack_interval)
				progress = true
				if k.target == "outpost":
					_hit_outpost(k)
				else:
					castle_hp -= int(k.attack_damage)
					events.append({type = "castle_hit", knight = k.id, damage = int(k.attack_damage)})
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


func _hit_outpost(k: Dictionary) -> void:
	if outpost.is_empty() or bool(outpost.captured):
		_retarget_to_castle(k)
		return
	outpost.hp = int(outpost.hp) - int(k.attack_damage)
	events.append({type = "outpost_hit", knight = k.id, damage = int(k.attack_damage)})
	if int(outpost.hp) <= 0:
		outpost.hp = 0
		outpost.captured = true
		events.append({type = "outpost_captured", outpost = outpost.id})
		# 앞마당을 노리던 기사들은 성으로 방향을 바꾼다
		for other in knights:
			if other.alive and other.target == "outpost":
				_retarget_to_castle(other)


## 지금 있는 칸에서 성 공격 칸까지 새 길을 잡는다(결정적: 같은 BFS)
func _retarget_to_castle(k: Dictionary) -> void:
	var cell := Vector2i(int(floor(k.pos.x)), int(floor(k.pos.y)))
	# 아직 정문 밖(등장 길)에 있으면 진입 칸에서 길을 잡는다. 등장 길은 진입 칸과 일직선이라 그대로 걸어 들어온다
	if not GridLogic.in_grid(cell, bounds):
		cell = GameConfig.entry_cell_for(bounds)
	var path := GridLogic.find_path(_buildings, _edges, cell, GridLogic.attack_cells(_buildings, _edges, bounds), bounds)
	k.target = "castle"
	if path.is_empty():
		# 길이 없을 리 없지만(경로 규칙), 만약을 위해 가장 가까운 성 칸을 바라보고 멈춘다 → 감시가 처리
		k.state = "stuck"
		return
	var wps: Array = []
	for c in path:
		wps.append(Vector2(c.x + 0.5, c.y + 0.5))
	var goal: Vector2i = path[path.size() - 1]
	k.castle_cell = _target_neighbor(goal, _castle)
	k.waypoints = wps
	k.wp = 0
	k.state = "walk"
	k.remaining_dist = _remaining_dist(k)


func _abort(reason: String) -> void:
	outcome = "abort"
	abort_reason = reason
	push_warning("전투 중단: %s" % reason)


## 목표 건물의 공격 칸마다 최단 경로를 구해, 가장 짧은 길보다 max_detour 칸 이내인 칸들을 '갈래'로 쓴다.
func _build_lanes_for(target: Dictionary, shortest: Array) -> Array:
	var out: Array = []
	if shortest.is_empty() or target.is_empty():
		return out
	var sp: Dictionary = _c.get("spread", {})
	var start := GameConfig.entry_cell_for(bounds)
	if not bool(sp.get("enabled", false)):
		out.append({cell = shortest[shortest.size() - 1], path = shortest, castle_cell = _target_neighbor(shortest[shortest.size() - 1], target)})
		return out
	var goals := GridLogic.attack_cells_for(target, _buildings, _edges, bounds)
	var cand: Array = []
	for g in goals:
		var p := GridLogic.find_path(_buildings, _edges, start, {g: true}, bounds)
		if not p.is_empty():
			cand.append({cell = g, path = p, castle_cell = _target_neighbor(g, target)})
	cand.sort_custom(func(a, b):
		if a.path.size() != b.path.size():
			return a.path.size() < b.path.size()
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y
		return a.cell.x < b.cell.x)
	var limit: int = shortest.size() + int(sp.get("max_detour_cells", 0))
	for c in cand:
		if c.path.size() <= limit:
			out.append(c)
	if out.is_empty():
		out.append({cell = shortest[shortest.size() - 1], path = shortest, castle_cell = _target_neighbor(shortest[shortest.size() - 1], target)})
	return out


## 공격 칸에서 울타리로 막히지 않은 쪽의 목표 건물 칸
func _target_neighbor(cell: Vector2i, target: Dictionary) -> Vector2i:
	var cells := GridLogic.footprint_cells(target)
	for d in GridLogic.DIRS:
		var n: Vector2i = cell + d
		if n in cells and not GridLogic.blocks(_edges, cell, n):
			return n
	return cells[0] if not cells.is_empty() else Vector2i(int(castle_center.x), int(castle_center.y))


func _spawn_knight() -> void:
	var spawn := GameConfig.spawn_world_for(bounds)
	var unit: Dictionary = _units[spawned]
	var kind := String(unit.get("kind", "knight"))
	var hp := knight_hp
	if kind != "knight":
		hp = maxi(1, int(round(int(unit.get("hp", knight_hp)) * hp_multiplier)))
	# 앞마당이 있으면 일반 기사 가운데 every_nth 번째마다 앞마당을 노린다(보스 제외)
	var nth := int(_c.get("outpost_raid", {}).get("every_nth", 0))
	var to_outpost: bool = kind == "knight" and nth > 0 and not outpost.is_empty() and not bool(outpost.captured) \
		and not outpost_lanes.is_empty() and spawned % nth == nth - 1
	var lane: Dictionary
	if to_outpost:
		lane = outpost_lanes[_outpost_spawns % outpost_lanes.size()]
		_outpost_spawns += 1
	elif not lanes.is_empty():
		lane = lanes[_castle_spawns % lanes.size()]
		_castle_spawns += 1
	else:
		lane = {path = route, castle_cell = Vector2i.ZERO, cell = Vector2i.ZERO}
	var wps: Array = []
	for c in lane.path:
		wps.append(Vector2(c.x + 0.5, c.y + 0.5))
	# 같은 칸에 몰리지 않도록 칸 안의 자리(slot)를 나눈다
	var key := ("o" if to_outpost else "") + str(lane.get("cell", Vector2i.ZERO))
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
		id = spawned + 1, kind = kind, hp = hp, max_hp = hp, pos = spawn,
		waypoints = wps, wp = 0, state = "walk", attack_timer = 0.0, alive = true,
		facing = Vector2(0, 1), remaining_dist = 0.0, castle_cell = lane.castle_cell, lane = key,
		target = "outpost" if to_outpost else "castle",
		speed = float(unit.get("move_cells_per_second", _c.knight_move_cells_per_second)),
		attack_damage = int(unit.get("attack_damage", _c.knight_attack_damage)),
		attack_interval = float(unit.get("attack_interval_seconds", _c.knight_attack_interval_seconds)),
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
