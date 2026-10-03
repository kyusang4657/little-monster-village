class_name GridLogic
extends RefCounted
## 격자 점유·울타리 변·경로 검사. 순수 함수만 둔다(테스트·저장 검증·화면이 함께 사용).
##
## 울타리 변 키
##   "h:x:z"  격자점 (x,z)-(x+1,z) 를 잇는 가로 변. 칸 (x,z-1) 과 (x,z) 사이.
##   "v:x:z"  격자점 (x,z)-(x,z+1) 를 잇는 세로 변. 칸 (x-1,z) 와 (x,z) 사이.

const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]

const REASON_OUT := "지도 밖이에요"
const REASON_OVERLAP := "다른 건물과 겹쳐요"
const REASON_FENCE_CROSS := "울타리가 건물 자리를 가로질러요"
const REASON_NO_ROUTE := "성으로 가는 길을 남겨 주세요"
const REASON_FIXED := "바깥 울타리와 정문은 바꿀 수 없어요"
const REASON_EDGE_IN_BUILDING := "건물 안을 가르는 울타리예요"
const REASON_DUP := "이미 있는 울타리예요"


static func edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.y == b.y and absi(a.x - b.x) == 1:
		return "h:%d:%d" % [mini(a.x, b.x), a.y]
	if a.x == b.x and absi(a.y - b.y) == 1:
		return "v:%d:%d" % [a.x, mini(a.y, b.y)]
	return ""


static func edge_points(key: String) -> Array[Vector2i]:
	var p := key.split(":")
	var x := int(p[1])
	var z := int(p[2])
	if p[0] == "h":
		return [Vector2i(x, z), Vector2i(x + 1, z)]
	return [Vector2i(x, z), Vector2i(x, z + 1)]


## 칸 a 에서 이웃 칸 b 로 갈 때 지나는 변.
static func crossing_edge(a: Vector2i, b: Vector2i) -> String:
	var d := b - a
	if d == Vector2i(1, 0):
		return "v:%d:%d" % [b.x, a.y]
	if d == Vector2i(-1, 0):
		return "v:%d:%d" % [a.x, a.y]
	if d == Vector2i(0, 1):
		return "h:%d:%d" % [a.x, b.y]
	if d == Vector2i(0, -1):
		return "h:%d:%d" % [a.x, a.y]
	return ""


static func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GameConfig.grid_width() and c.y < GameConfig.grid_depth()


## 바깥 경계가 아닌, 지도 안쪽의 변인지.
static func is_interior_edge(key: String) -> bool:
	var p := key.split(":")
	if p.size() != 3:
		return false
	var x := int(p[1])
	var z := int(p[2])
	var w := GameConfig.grid_width()
	var d := GameConfig.grid_depth()
	if p[0] == "h":
		return x >= 0 and x < w and z >= 1 and z <= d - 1
	if p[0] == "v":
		return z >= 0 and z < d and x >= 1 and x <= w - 1
	return false


static func gate_edges() -> Array[String]:
	var out: Array[String] = []
	for g in GameConfig.layout().gates:
		var a := Vector2i(int(g.from[0]), int(g.from[1]))
		var b := Vector2i(int(g.to[0]), int(g.to[1]))
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var c := a
		while c != b:
			out.append(edge_key(c, c + step))
			c += step
	return out


static func fixed_edges() -> Dictionary:
	var out := {}
	for e in GameConfig.layout().fixed_fence_edges:
		var k := edge_key(Vector2i(int(e.from[0]), int(e.from[1])), Vector2i(int(e.to[0]), int(e.to[1])))
		if k != "":
			out[k] = true
	return out


static func footprint_cells(b: Dictionary) -> Array[Vector2i]:
	var fp := GameConfig.footprint(b.type)
	var out: Array[Vector2i] = []
	for dx in fp.x:
		for dz in fp.y:
			out.append(Vector2i(int(b.x) + dx, int(b.z) + dz))
	return out


## 건물 영역 내부를 가로지르는 변인지(둘레에 접한 변은 제외).
static func edge_inside_building(key: String, b: Dictionary) -> bool:
	var fp := GameConfig.footprint(b.type)
	var p := key.split(":")
	var x := int(p[1])
	var z := int(p[2])
	var bx := int(b.x)
	var bz := int(b.z)
	if p[0] == "h":
		return x >= bx and x <= bx + fp.x - 1 and z >= bz + 1 and z <= bz + fp.y - 1
	return x >= bx + 1 and x <= bx + fp.x - 1 and z >= bz and z <= bz + fp.y - 1


static func occupancy(buildings: Array, exclude_id: String = "") -> Dictionary:
	var occ := {}
	for b in buildings:
		if b.id == exclude_id:
			continue
		for c in footprint_cells(b):
			occ[c] = b.id
	return occ


static func castle_of(buildings: Array) -> Dictionary:
	for b in buildings:
		if b.type == "castle":
			return b
	return {}


static func blocks(edges: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	return edges.has(crossing_edge(a, b))


## 성에 변으로 인접하고, 그 변이 울타리로 막히지 않은 통과 가능 칸 목록.
static func attack_cells(buildings: Array, edges: Dictionary) -> Dictionary:
	var castle := castle_of(buildings)
	var out := {}
	if castle.is_empty():
		return out
	var occ := occupancy(buildings)
	for c in footprint_cells(castle):
		for d in DIRS:
			var n: Vector2i = c + d
			if not in_grid(n) or occ.has(n):
				continue
			if blocks(edges, n, c):
				continue
			out[n] = true
	return out


## 입구 칸에서 공격 가능 칸까지 4방향 최단 경로. 없으면 빈 배열.
static func find_route(buildings: Array, edges: Dictionary) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var start := GameConfig.entry_cell()
	var occ := occupancy(buildings)
	if not in_grid(start) or occ.has(start):
		return empty
	var goals := attack_cells(buildings, edges)
	if goals.is_empty():
		return empty
	return find_path(buildings, edges, start, goals)


## 4방향 BFS 최단 경로(건물 점유 칸·울타리 변을 피함). 시작 칸은 점유되어 있어도 출발할 수 있다.
## 이웃 순서가 고정이라 결과가 항상 같다(결정적).
static func find_path(buildings: Array, edges: Dictionary, start: Vector2i, goals: Dictionary) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if goals.is_empty() or not in_grid(start):
		return empty
	var occ := occupancy(buildings)
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if goals.has(cur):
			var path: Array[Vector2i] = [cur]
			while path[0] != start:
				path.push_front(prev[path[0]])
			return path
		for d in DIRS:
			var n: Vector2i = cur + d
			if not in_grid(n) or occ.has(n) or prev.has(n):
				continue
			if blocks(edges, cur, n):
				continue
			prev[n] = cur
			queue.append(n)
	return empty


static func all_edges(interior: Dictionary) -> Dictionary:
	var e := fixed_edges()
	for k in interior:
		e[k] = true
	return e


## 건물 배치 후보 검증. candidate = {id, type, x, z}. exclude_id 는 옮기는 중인 자신.
static func validate_building(buildings: Array, interior: Dictionary, candidate: Dictionary, exclude_id: String = "") -> Dictionary:
	var fp := GameConfig.footprint(candidate.type)
	var x := int(candidate.x)
	var z := int(candidate.z)
	if x < 0 or z < 0 or x + fp.x > GameConfig.grid_width() or z + fp.y > GameConfig.grid_depth():
		return {ok = false, reason = REASON_OUT}
	var occ := occupancy(buildings, exclude_id)
	for c in footprint_cells(candidate):
		if occ.has(c):
			return {ok = false, reason = REASON_OVERLAP}
	var edges := all_edges(interior)
	for k in edges:
		if edge_inside_building(k, candidate):
			return {ok = false, reason = REASON_FENCE_CROSS}
	var trial: Array = []
	for b in buildings:
		if b.id != exclude_id:
			trial.append(b)
	trial.append(candidate)
	if find_route(trial, edges).is_empty():
		return {ok = false, reason = REASON_NO_ROUTE}
	return {ok = true, reason = ""}


## 울타리 편집 검증. add/remove 는 키 집합. cost 는 새로 추가되는 변 수 × 단가.
static func validate_fences(buildings: Array, interior: Dictionary, add: Dictionary, remove: Dictionary) -> Dictionary:
	var unit := int(GameConfig.defaults().fences.edge_build_cost)
	var fixed := fixed_edges()
	var gates := gate_edges()
	var new_count := 0
	for k in add:
		if fixed.has(k) or gates.has(k) or not is_interior_edge(k):
			return {ok = false, reason = REASON_FIXED, cost = 0}
		if interior.has(k):
			return {ok = false, reason = REASON_DUP, cost = 0}
		for b in buildings:
			if edge_inside_building(k, b):
				return {ok = false, reason = REASON_EDGE_IN_BUILDING, cost = 0}
		new_count += 1
	for k in remove:
		if not interior.has(k):
			return {ok = false, reason = REASON_FIXED, cost = 0}
	var result := interior.duplicate()
	for k in remove:
		result.erase(k)
	for k in add:
		result[k] = true
	if find_route(buildings, all_edges(result)).is_empty():
		return {ok = false, reason = REASON_NO_ROUTE, cost = new_count * unit}
	return {ok = true, reason = "", cost = new_count * unit, result = result}


## 격자점 a 에서 b 까지(같은 행 또는 열) 이어지는 변 목록.
static func edges_between_points(a: Vector2i, b: Vector2i) -> Array[String]:
	var out: Array[String] = []
	if a == b:
		return out
	if a.x != b.x and a.y != b.y:
		return out
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var c := a
	while c != b:
		out.append(edge_key(c, c + step))
		c += step
	return out
