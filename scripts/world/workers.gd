class_name WorkerCrew
extends Node3D
## 고블린 일꾼(외형 전용). 공사 현장으로 격자 경로를 따라 걸어가 망치질하고, 끝나면 벌목소 옆으로 돌아온다.
## 공사 진행은 시간 기준 규칙(GameState)이 정하며 일꾼 도착 여부와 무관하다. 전투에는 참여하지 않는다.

const STATE_IDLE := "idle"
const STATE_WALK := "walk"
const STATE_WORK := "work"

var workers: Array = []
var _speed := 1.6
var _time := 0.0


func setup(count: int, speed: float) -> void:
	_speed = speed
	for i in count:
		var g := CharacterRig.goblin(i % 3, true)
		g.seed_id = 11 + i * 5
		g.name = "Worker%d" % i
		add_child(g)
		workers.append({node = g, state = STATE_IDLE, target = "", site_key = "", path = [], pos = Vector2(-99, -99), face = Vector2(0, -1), idx = i})


## 현재 상태 요약(테스트·캡처 기록용)
func summary() -> Array:
	var out: Array = []
	for w in workers:
		out.append({state = w.state, target = w.target, pos = w.pos})
	return out


## 지금 지도 경계(넓힌 땅의 현장까지 걸어가도록). 비어 있으면 처음 지도
var _bounds := Rect2i()


func update_crew(buildings: Array, edges: Dictionary, delta: float, active: bool, bounds: Rect2i = Rect2i()) -> void:
	_time += delta
	_bounds = GridLogic.bnd(bounds)
	var sites: Array = []
	for b in buildings:
		if float(b.get("build_left", 0.0)) > 0.0:
			sites.append(b)
	var home_cells := _home_cells(buildings)
	for w in workers:
		var g: Node3D = w.node
		if w.pos.x < -50.0:
			var hc: Vector2i = home_cells[w.idx % maxi(home_cells.size(), 1)] if not home_cells.is_empty() else Vector2i(1, 5)
			w.pos = Vector2(hc.x + 0.5, hc.y + 0.5)
		var target := ""
		var site := {}
		if not sites.is_empty():
			site = sites[w.idx % sites.size()]
			target = String(site.id)
		var site_key := "home" if site.is_empty() else "%s@%d,%d" % [site.id, int(site.x), int(site.z)]
		if site_key != w.site_key:
			w.site_key = site_key
			w.target = target
			_plan(w, buildings, edges, site, home_cells)
		if active and w.state == STATE_WALK:
			_walk(w, delta)
		_animate(w, site, active, delta)
		g.position = WorldView.W(w.pos.x, 0, w.pos.y)


func _home_cells(buildings: Array) -> Array:
	var occ := GridLogic.occupancy(buildings)
	var anchor := {}
	for b in buildings:
		if b.type == "lumber_camp":
			anchor = b
			break
	if anchor.is_empty():
		return []
	var fp := GameConfig.footprint(anchor.type)
	var center := Vector2(anchor.x + fp.x * 0.5, anchor.z + fp.y * 0.5)
	var cells: Array = []
	for x in range(anchor.x - 1, anchor.x + fp.x + 1):
		for z in range(anchor.z - 1, anchor.z + fp.y + 1):
			var c := Vector2i(x, z)
			if GridLogic.in_grid(c, _bounds) and not occ.has(c):
				cells.append(c)
	cells.sort_custom(func(a, b): return Vector2(a.x + 0.5, a.y + 0.5).distance_to(center + Vector2(0.4, -1.2)) < Vector2(b.x + 0.5, b.y + 0.5).distance_to(center + Vector2(0.4, -1.2)))
	return cells


## 목적지 칸까지 경로를 세운다. 현장 둘레의 빈 칸 중 일꾼마다 다른 칸을 고른다.
func _plan(w: Dictionary, buildings: Array, edges: Dictionary, site: Dictionary, home_cells: Array) -> void:
	var goals := {}
	var ordered: Array = []
	if site.is_empty():
		ordered = home_cells
	else:
		var occ := GridLogic.occupancy(buildings)
		var fp := GameConfig.footprint(site.type)
		for x in range(int(site.x) - 1, int(site.x) + fp.x + 1):
			for z in range(int(site.z) - 1, int(site.z) + fp.y + 1):
				var c := Vector2i(x, z)
				var inside: bool = x >= site.x and x < site.x + fp.x and z >= site.z and z < site.z + fp.y
				var corner: bool = (x == site.x - 1 or x == site.x + fp.x) and (z == site.z - 1 or z == site.z + fp.y)
				if inside or corner or not GridLogic.in_grid(c, _bounds) or occ.has(c):
					continue
				ordered.append(c)
		var front := Vector2(site.x + fp.x * 0.5, site.z - 1.0)
		ordered.sort_custom(func(a, b): return Vector2(a.x + 0.5, a.y + 0.5).distance_to(front) < Vector2(b.x + 0.5, b.y + 0.5).distance_to(front))
	if ordered.is_empty():
		w.state = STATE_IDLE
		w.path = []
		return
	var pick: Vector2i = ordered[mini(w.idx, ordered.size() - 1)]
	goals[pick] = true
	var start := Vector2i(int(floor(w.pos.x)), int(floor(w.pos.y)))
	var cells := GridLogic.find_path(buildings, edges, start, goals, _bounds)
	var pts: Array = []
	if cells.is_empty():
		# 길이 없으면(예: 건물에 둘러싸임) 목적지로 바로 옮긴다
		w.pos = Vector2(pick.x + 0.5, pick.y + 0.5)
	else:
		for c in cells:
			pts.append(Vector2(c.x + 0.5, c.y + 0.5))
	w.path = pts
	w.state = STATE_WALK if not pts.is_empty() else (STATE_IDLE if site.is_empty() else STATE_WORK)


func _walk(w: Dictionary, delta: float) -> void:
	var move := _speed * delta
	while move > 0.0 and not w.path.is_empty():
		var t: Vector2 = w.path[0]
		var to: Vector2 = t - w.pos
		var d := to.length()
		if d <= move:
			w.pos = t
			move -= d
			w.path.pop_front()
		else:
			w.pos += to / d * move
			w.face = to / d
			move = 0.0
	if w.path.is_empty():
		w.state = STATE_WORK if w.target != "" else STATE_IDLE


## 자세: 걷기(pose_walk)·망치질(pose_hammer, 온몸)·쉬기(pose_idle). 내려치는 순간(위상 0)에 '똑' 소리.
func _animate(w: Dictionary, site: Dictionary, active: bool, delta: float) -> void:
	var g: CharacterRig = w.node
	var t: float = _time + w.idx * 0.37
	var speed := 0.0
	match w.state:
		STATE_WALK:
			if active:
				g.pose_walk(t * CharacterRig.WALK_RATE * 1.3)
				speed = 1.0
			else:
				g.pose_idle(t)
			g.rotation.y = WorldView.yaw_for_dir(w.face)
		STATE_WORK:
			if active:
				g.pose_hammer(fposmod(t * CharacterRig.HAMMER_RATE, 1.0))
				var strike := CharacterRig.impact_index(t)
				if strike != int(w.get("strike", -1)):
					w.strike = strike
					Sound.play("hammer", -10.0, randf_range(0.9, 1.15))
			else:
				g.pose_hammer(0.3)
			if not site.is_empty():
				var fp := GameConfig.footprint(site.type)
				var c := Vector2(site.x + fp.x * 0.5, site.z + fp.y * 0.5)
				g.rotation.y = WorldView.yaw_for_dir(c - w.pos)
		_:
			g.pose_idle(t)
	g.update_secondary(delta if active else 0.0, speed)
	g.update_blink(t)
