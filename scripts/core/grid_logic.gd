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
const REASON_SITE := "숲 자원 지점은 앞마당 자리예요"
const REASON_OUTPOST_SITE := "앞마당은 숲 자원 지점에만 지을 수 있어요"

## 지도 경계(논리 칸). size 가 0 이면 처음 지도(14×10)를 쓴다.
## 3차부터 지도가 넓어질 수 있으므로 모든 격자 함수가 경계를 인자로 받는다.
static func bnd(b: Rect2i) -> Rect2i:
	return GameConfig.initial_bounds() if b.size == Vector2i.ZERO else b


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


static func in_grid(c: Vector2i, bounds: Rect2i = Rect2i()) -> bool:
	return bnd(bounds).has_point(c)


## 바깥 경계가 아닌, 지도 안쪽의 변인지.
static func is_interior_edge(key: String, bounds: Rect2i = Rect2i()) -> bool:
	var p := key.split(":")
	if p.size() != 3:
		return false
	var x := int(p[1])
	var z := int(p[2])
	var b := bnd(bounds)
	var x0 := b.position.x
	var z0 := b.position.y
	var x1 := b.end.x - 1
	var z1 := b.end.y - 1
	if p[0] == "h":
		return x >= x0 and x <= x1 and z >= z0 + 1 and z <= z1
	if p[0] == "v":
		return z >= z0 and z <= z1 and x >= x0 + 1 and x <= x1
	return false


## 정문: 앞쪽 경계(min_z)의 x = gate_x[0] .. gate_x[1] 구간. 항상 열려 있다.
static func gate_edges(bounds: Rect2i = Rect2i()) -> Array[String]:
	var out: Array[String] = []
	var b := bnd(bounds)
	var g := GameConfig.gate_x()
	for x in range(g.x, g.y):
		out.append("h:%d:%d" % [x, b.position.y])
	return out


## 바깥 울타리 = 현재 경계의 둘레 - 정문. 지도가 넓어지면 새 경계로 옮겨진다.
static func fixed_edges(bounds: Rect2i = Rect2i()) -> Dictionary:
	var out := {}
	var b := bnd(bounds)
	for x in range(b.position.x, b.end.x):
		out["h:%d:%d" % [x, b.position.y]] = true
		out["h:%d:%d" % [x, b.end.y]] = true
	for z in range(b.position.y, b.end.y):
		out["v:%d:%d" % [b.position.x, z]] = true
		out["v:%d:%d" % [b.end.x, z]] = true
	for k in gate_edges(b):
		out.erase(k)
	return out


## 경계 안에 들어온 자원 지점(앞마당 자리)
static func open_sites(bounds: Rect2i = Rect2i()) -> Array:
	var out: Array = []
	var b := bnd(bounds)
	for s in GameConfig.resource_sites():
		var r := Rect2i(int(s.x), int(s.z), int(s.w), int(s.d))
		if b.encloses(r):
			out.append(s)
	return out


static func site_rect(s: Dictionary) -> Rect2i:
	return Rect2i(int(s.x), int(s.z), int(s.w), int(s.d))


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
static func attack_cells(buildings: Array, edges: Dictionary, bounds: Rect2i = Rect2i()) -> Dictionary:
	return attack_cells_for(castle_of(buildings), buildings, edges, bounds)


## 임의 건물(성·앞마당)을 공격할 수 있는 칸
static func attack_cells_for(target: Dictionary, buildings: Array, edges: Dictionary, bounds: Rect2i = Rect2i()) -> Dictionary:
	var out := {}
	if target.is_empty():
		return out
	var occ := occupancy(buildings)
	for c in footprint_cells(target):
		for d in DIRS:
			var n: Vector2i = c + d
			if not in_grid(n, bounds) or occ.has(n):
				continue
			if blocks(edges, n, c):
				continue
			out[n] = true
	return out


## 입구 칸에서 공격 가능 칸까지 4방향 최단 경로. 없으면 빈 배열.
static func find_route(buildings: Array, edges: Dictionary, bounds: Rect2i = Rect2i()) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var b := bnd(bounds)
	var start := GameConfig.entry_cell_for(b)
	var occ := occupancy(buildings)
	if not in_grid(start, b) or occ.has(start):
		return empty
	var goals := attack_cells(buildings, edges, b)
	if goals.is_empty():
		return empty
	return find_path(buildings, edges, start, goals, b)


## 4방향 BFS 최단 경로(건물 점유 칸·울타리 변을 피함). 시작 칸은 점유되어 있어도 출발할 수 있다.
## 이웃 순서가 고정이라 결과가 항상 같다(결정적).
static func find_path(buildings: Array, edges: Dictionary, start: Vector2i, goals: Dictionary, bounds: Rect2i = Rect2i()) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var bb := bnd(bounds)
	if goals.is_empty() or not in_grid(start, bb):
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
			if not in_grid(n, bb) or occ.has(n) or prev.has(n):
				continue
			if blocks(edges, cur, n):
				continue
			prev[n] = cur
			queue.append(n)
	return empty


static func all_edges(interior: Dictionary, bounds: Rect2i = Rect2i()) -> Dictionary:
	var e := fixed_edges(bounds)
	for k in interior:
		e[k] = true
	return e


## 건물 배치 후보 검증. candidate = {id, type, x, z}. exclude_id 는 옮기는 중인 자신.
static func validate_building(buildings: Array, interior: Dictionary, candidate: Dictionary, exclude_id: String = "", bounds: Rect2i = Rect2i()) -> Dictionary:
	var b0 := bnd(bounds)
	var fp := GameConfig.footprint(candidate.type)
	var x := int(candidate.x)
	var z := int(candidate.z)
	var rect := Rect2i(x, z, fp.x, fp.y)
	if not b0.encloses(rect):
		return {ok = false, reason = REASON_OUT}
	var occ := occupancy(buildings, exclude_id)
	for c in footprint_cells(candidate):
		if occ.has(c):
			return {ok = false, reason = REASON_OVERLAP}
	# 숲 자원 지점은 앞마당만 쓸 수 있고, 앞마당은 자원 지점 위에만 지을 수 있다
	var on_site := false
	for s in open_sites(b0):
		var sr := site_rect(s)
		if sr == rect:
			on_site = true
		elif sr.intersects(rect) and candidate.type != "outpost":
			return {ok = false, reason = REASON_SITE}
		elif sr.intersects(rect):
			return {ok = false, reason = REASON_OUTPOST_SITE}
	if candidate.type == "outpost" and not on_site:
		return {ok = false, reason = REASON_OUTPOST_SITE}
	if candidate.type != "outpost" and on_site:
		return {ok = false, reason = REASON_SITE}
	var edges := all_edges(interior, b0)
	for k in edges:
		if edge_inside_building(k, candidate):
			return {ok = false, reason = REASON_FENCE_CROSS}
	var trial: Array = []
	for b in buildings:
		if b.id != exclude_id:
			trial.append(b)
	trial.append(candidate)
	if find_route(trial, edges, b0).is_empty():
		return {ok = false, reason = REASON_NO_ROUTE}
	return {ok = true, reason = ""}


## 울타리 편집 검증. add/remove 는 키 집합. cost 는 새로 추가되는 변 수 × 단가.
static func validate_fences(buildings: Array, interior: Dictionary, add: Dictionary, remove: Dictionary, bounds: Rect2i = Rect2i()) -> Dictionary:
	var b0 := bnd(bounds)
	var unit := int(GameConfig.defaults().fences.edge_build_cost)
	var fixed := fixed_edges(b0)
	var gates := gate_edges(b0)
	var new_count := 0
	for k in add:
		if fixed.has(k) or gates.has(k) or not is_interior_edge(k, b0):
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
	if find_route(buildings, all_edges(result, b0), b0).is_empty():
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
