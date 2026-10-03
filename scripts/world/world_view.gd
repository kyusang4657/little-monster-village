class_name WorldView
extends Node3D
## 3D 장면: 지면·장식·울타리·건물·캐릭터·전투 연출·카메라. 게임 규칙은 갖지 않는다.

const KNIGHT_HP_BAR_W := 0.7

var camera: Camera3D
var cam_target := Vector3(7.0, 0, -5.0)
var cam_size := 13.0
var cam_min := 6.0
var cam_max := 20.0

var _buildings_root: Node3D
var _building_nodes: Dictionary = {}     # id -> Node3D
var _fence_node: MeshInstance3D
var _fence_plan_node: MeshInstance3D
var _grid_node: MeshInstance3D
var _footprint: MeshInstance3D
var _footprint_mat: StandardMaterial3D
var _selection: MeshInstance3D
var _ghost: Node3D
var _ghost_type := ""
var crew: WorkerCrew
## 3차: 현재 지도 경계(논리 칸). 바뀌면 지면·장식·격자·카메라 범위를 다시 만든다.
var map_bounds := Rect2i()
var _ground_node: MeshInstance3D
var _trees_node: MeshInstance3D
var _flowers_node: MeshInstance3D
var _sites_node: MeshInstance3D
var _zone: MeshInstance3D
var _zone_mat: StandardMaterial3D
var _sites_key := ""
var _complete_pop: Dictionary = {}      # id -> 남은 완성 연출 시간

var _battle_root: Node3D
var _knight_nodes: Dictionary = {}       # knight id -> {node, bar, fg, dying}
var _bolt_nodes: Dictionary = {}         # bolt id -> {node, start, total}
var _dying: Array = []
var _floaters: Array = []
var _castle_shake := 0.0
var _flash_mat: StandardMaterial3D
var _bar_bg_mat: StandardMaterial3D
var _bar_fg_mat: StandardMaterial3D
var _font: Font


func _ready() -> void:
	_font = load("res://assets/fonts/NanumGothic-Bold.ttf")
	_setup_environment()
	map_bounds = GameConfig.initial_bounds()
	_setup_camera()
	_build_ground()
	_build_decor()
	_sites_node = MeshInstance3D.new()
	_sites_node.name = "ResourceSites"
	add_child(_sites_node)
	_zone = MeshInstance3D.new()
	_zone.name = "ZonePreview"
	var zpm := PlaneMesh.new()
	zpm.size = Vector2(1, 1)
	_zone.mesh = zpm
	_zone_mat = _unshaded(Color(1.0, 0.85, 0.3, 0.38))
	_zone.material_override = _zone_mat
	_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_zone.visible = false
	add_child(_zone)
	_buildings_root = Node3D.new()
	_buildings_root.name = "Buildings"
	add_child(_buildings_root)
	_fence_node = MeshInstance3D.new()
	_fence_node.name = "Fences"
	add_child(_fence_node)
	_fence_plan_node = MeshInstance3D.new()
	_fence_plan_node.name = "FencePlan"
	add_child(_fence_plan_node)
	_build_grid_overlay()
	_build_footprint()
	_battle_root = Node3D.new()
	_battle_root.name = "Battle"
	add_child(_battle_root)
	_flash_mat = _unshaded(Color(1, 1, 1, 0.55))
	_bar_bg_mat = _unshaded(Color("3a2443"), true)
	_bar_fg_mat = _unshaded(Color("e0443c"), true)
	crew = WorkerCrew.new()
	crew.name = "Workers"
	add_child(crew)
	var cc := GameConfig.construction()
	crew.setup(int(cc.get("worker_count", 2)), float(cc.get("worker_walk_cells_per_second", 1.6)))


static func _unshaded(c: Color, billboard: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = true
		m.render_priority = 10
	return m


# ------------------------------------------------------------------ 환경·카메라

func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("8fc45a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff3dc")
	e.ambient_light_energy = 0.2
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58, 25, 0)
	sun.light_energy = 0.5
	sun.light_color = Color("fff6e5")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_opacity = 0.55
	sun.shadow_blur = 1.5
	add_child(sun)
	_sun = sun


var _sun: DirectionalLight3D


## 성능이 낮은 기기에서 먼저 줄일 항목
func set_shadows(on: bool) -> void:
	_sun.shadow_enabled = on


func _setup_camera() -> void:
	var c := GameConfig.camera()
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.5
	camera.far = 120.0
	add_child(camera)
	camera.make_current()
	_azimuth = deg_to_rad(float(c.initial_azimuth_degrees))
	_elevation = deg_to_rad(float(c.initial_elevation_degrees))
	reset_camera()


var _azimuth := 0.0
var _elevation := 0.0


func reset_camera() -> void:
	var b := map_bounds if map_bounds.size != Vector2i.ZERO else GameConfig.initial_bounds()
	cam_target = W(b.position.x + b.size.x * 0.5, 0, b.position.y + b.size.y * 0.5 - 0.4)
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var aspect := vp.x / maxf(vp.y, 1.0)
	# 좁은 화면에서도 마을 전체가 들어오도록 기본 확대 정도를 고른다(지도가 넓어지면 비례해 넓게).
	var grow := clampf(maxf(b.size.x / 14.0, b.size.y / 10.0), 1.0, 1.8)
	cam_max = 20.0 * grow
	cam_size = clampf(maxf(14.6, 22.0 / aspect) * grow, 12.0, cam_max)
	_apply_camera()


func _apply_camera() -> void:
	cam_size = clampf(cam_size, cam_min, cam_max)
	var b := map_bounds if map_bounds.size != Vector2i.ZERO else GameConfig.initial_bounds()
	cam_target.x = clampf(cam_target.x, b.position.x - 3.0, b.end.x + 3.0)
	cam_target.z = clampf(cam_target.z, -(b.end.y + 3.0), -(b.position.y - 4.0))
	camera.size = cam_size
	# 논리 정면(z가 작은 쪽, 정문)이 화면 아래에 오도록 앞쪽 오른편 위에서 내려다본다.
	var off := Vector3(sin(_azimuth) * cos(_elevation), sin(_elevation), cos(_azimuth) * cos(_elevation))
	camera.position = cam_target + off * 40.0
	camera.look_at(cam_target, Vector3.UP)


func pan_by_screen(from: Vector2, to: Vector2) -> void:
	var a = ground_point(from)
	var b = ground_point(to)
	if a == null or b == null:
		return
	cam_target += a - b
	_apply_camera()


func zoom_by(factor: float) -> void:
	cam_size *= factor
	_apply_camera()


func ground_point(screen: Vector2):
	var o := camera.project_ray_origin(screen)
	var d := camera.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return null
	var t := -o.y / d.y
	return o + d * t


## 논리 좌표(x 오른쪽, z 뒤쪽) → 월드 좌표. 화면에서 x가 오른쪽·z가 위로 보이도록 z를 뒤집는다.
## 모델은 뒤집지 않고 회전만 바꾸므로(PI 보정) 좌우 손·창 위치가 거울상이 되지 않는다.
static func W(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, -z)


## 월드 지면 점 → 논리 좌표
static func to_logical(p: Vector3) -> Vector2:
	return Vector2(p.x, -p.z)


## 논리 방향(정면 -z 기준 회전 사분면) → 월드 Y 회전
static func yaw_for_rot(rot: int) -> float:
	return PI - rot * PI * 0.5


## 논리 방향 벡터 → 모델(정면 -Z) 월드 Y 회전
static func yaw_for_dir(d: Vector2) -> float:
	return atan2(-d.x, d.y)


static func cell_center(c: Vector2i) -> Vector3:
	return W(c.x + 0.5, 0, c.y + 0.5)


static func building_center(type: String, x: int, z: int) -> Vector3:
	var fp := GameConfig.footprint(type)
	return W(x + fp.x * 0.5, 0, z + fp.y * 0.5)


# ------------------------------------------------------------------ 지면·장식

## 지도 경계가 바뀌면 지면·장식·격자를 다시 만들고 카메라 범위를 맞춘다
func set_map(bounds: Rect2i) -> void:
	if bounds == map_bounds:
		return
	map_bounds = bounds
	_build_ground()
	_build_decor()
	_build_grid_overlay()
	_apply_camera()


## 경계 바깥 넓힐 땅 미리보기(노란 반투명 바닥)
func show_zone(r: Rect2i, ok: bool = true) -> void:
	_zone.visible = true
	_zone.position = W(r.position.x + r.size.x * 0.5, 0.05, r.position.y + r.size.y * 0.5)
	_zone.scale = Vector3(r.size.x, 1, r.size.y)
	_zone_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.42) if ok else Color(0.9, 0.4, 0.3, 0.38)


func hide_zone() -> void:
	_zone.visible = false


func _build_ground() -> void:
	if _ground_node != null:
		_ground_node.queue_free()
	var bb := map_bounds
	var w := float(bb.size.x)
	var d := float(bb.size.y)
	var x0 := float(bb.position.x)
	var z0 := float(bb.position.y)
	var g := MeshBatch.new()
	g.box(Vector3(110, 0.2, 110), W(x0 + w * 0.5, -0.1, z0 + d * 0.5), Color("86c053"))
	g.box(Vector3(w, 0.02, d), W(x0 + w * 0.5, 0.0, z0 + d * 0.5), Color("94cd5e"))
	# 바깥 접근로(정문 앞). 앞쪽으로 넓히면 정문과 함께 앞으로 나간다.
	var gx := GameConfig.gate_x()
	g.box(Vector3(2.0, 0.02, 7.0), W(gx.x + 1.0, 0.012, z0 - 3.5), Color("d9b77a"))
	var init := GameConfig.initial_bounds()
	if z0 < init.position.y:
		var ext := float(init.position.y) - z0
		g.box(Vector3(2.0, 0.02, ext), W(gx.x + 1.0, 0.014, z0 + ext * 0.5), Color("dcbb7f"))
	for r in GameConfig.layout().cosmetic_path_rects:
		var rw := float(r.w)
		var rd := float(r.d)
		g.box(Vector3(rw, 0.02, rd), W(float(r.x) + rw * 0.5, 0.014, float(r.z) + rd * 0.5), Color("dcbb7f"))
	# 잔디 결: 조금 짙거나 옅은 납작한 풀밭 조각(장식, 비충돌)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		var p := Vector2(rng.randf_range(x0 - 8.0, x0 + w + 8.0), rng.randf_range(z0 - 8.0, z0 + d + 7.0))
		var r := rng.randf_range(0.35, 1.1)
		var c := Color("89bf56") if i % 2 == 0 else Color("93ca5e")
		g.cyl(r, r, 0.012, W(p.x, 0.006, p.y), c, Vector3.ZERO, 10)
	# 길 가장자리 자갈
	for rr in GameConfig.layout().cosmetic_path_rects:
		for i in int(rr.w) * int(rr.d):
			var px := float(rr.x) + rng.randf_range(0.0, float(rr.w))
			var pz := float(rr.z) + rng.randf_range(0.0, float(rr.d))
			if rng.randf() < 0.5:
				g.sphere(rng.randf_range(0.04, 0.07), W(px, 0.02, pz), Color("c9a46a"), Vector3(1.2, 0.5, 1.0))
	var mi := g.instance("Ground")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	move_child(mi, 0)
	_ground_node = mi


## 나무·바위·꽃: 가장 넓은 지도 둘레까지 후보 위치를 고정 씨앗으로 만든 뒤, 현재 경계 밖 것만 그린다.
## 그래서 땅을 넓혀도 남은 나무는 그 자리에 있고, 넓힌 땅의 나무만 사라진다. 개수 상한은 config map.decor_limits.
func _build_decor() -> void:
	for n in [_trees_node, _flowers_node]:
		if n != null:
			n.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260927
	var lim: Dictionary = GameConfig.map_config().get("decor_limits", {})
	var max_trees := int(lim.get("trees", 64))
	var max_rocks := int(lim.get("rocks", 14))
	var max_flowers := int(lim.get("flowers", 160))
	var all_dirs: Array = GameConfig.map_config().get("expansions", {}).keys()
	var big := GameConfig.bounds_for(all_dirs)
	var cur := map_bounds
	var gx := GameConfig.gate_x()
	var trees := MeshBatch.new()
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < max_trees and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(big.position.x - 9.0, big.end.x + 9.0), rng.randf_range(big.position.y - 9.0, big.end.y + 8.0))
		# 마을 안쪽과 울타리 주변·정문 접근로는 비운다(비충돌 장식)
		if p.x > cur.position.x - 1.6 and p.x < cur.end.x + 1.6 and p.y > cur.position.y - 1.6 and p.y < cur.end.y + 1.6:
			continue
		if p.x > gx.x - 1.5 and p.x < gx.y + 1.5 and p.y < cur.position.y:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < 1.5:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var s := rng.randf_range(0.8, 1.25)
		var base := W(p.x, 0, p.y)
		if rng.randf() < 0.6:
			trees.cyl(0.12 * s, 0.15 * s, 0.5 * s, base + Vector3(0, 0.25 * s, 0), Models.WOOD_DARK, Vector3.ZERO, 8)
			trees.cyl(0.0, 0.75 * s, 1.0 * s, base + Vector3(0, 0.9 * s, 0), Color("2f7d45"), Vector3.ZERO, 10)
			trees.cyl(0.0, 0.6 * s, 0.85 * s, base + Vector3(0, 1.45 * s, 0), Color("3a9150"), Vector3.ZERO, 10)
			trees.cyl(0.0, 0.42 * s, 0.7 * s, base + Vector3(0, 1.95 * s, 0), Color("44a35b"), Vector3.ZERO, 10)
		else:
			trees.cyl(0.12 * s, 0.16 * s, 0.7 * s, base + Vector3(0, 0.35 * s, 0), Models.WOOD_DARK, Vector3.ZERO, 8)
			trees.sphere(0.62 * s, base + Vector3(0, 1.1 * s, 0), Color("4fa54a"))
			trees.sphere(0.42 * s, base + Vector3(0.3 * s, 1.45 * s, 0.1 * s), Color("62b956"))
	for i in max_rocks:
		var p := Vector2(rng.randf_range(big.position.x - 7.0, big.end.x + 7.0), rng.randf_range(big.position.y - 7.0, big.end.y + 6.0))
		if p.x > cur.position.x - 0.8 and p.x < cur.end.x + 0.8 and p.y > cur.position.y - 0.8 and p.y < cur.end.y + 0.8:
			continue
		if p.x > gx.x - 1.0 and p.x < gx.y + 1.0 and p.y < cur.position.y:
			continue
		var s := rng.randf_range(0.25, 0.5)
		trees.sphere(s, W(p.x, s * 0.4, p.y), Color("aeb0ad"), Vector3(1.3, 0.8, 1.0))
	var tm := trees.instance("Trees")
	add_child(tm)
	_trees_node = tm
	# 꽃·풀 점(그림자 없음)
	var fl := MeshBatch.new()
	for i in max_flowers:
		var p := Vector2(rng.randf_range(big.position.x - 8.0, big.end.x + 8.0), rng.randf_range(big.position.y - 8.0, big.end.y + 7.0))
		var col: Color = [Color("fff3a0"), Color("ffffff"), Color("f7c8e0"), Color("6fb84a")][i % 4]
		if i % 4 == 3:
			fl.cyl(0.0, 0.07, 0.16, W(p.x, 0.08, p.y), col, Vector3.ZERO, 5)
		else:
			fl.sphere(0.05, W(p.x, 0.04, p.y), col)
	var fm := fl.instance("Flowers")
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fm)
	_flowers_node = fm


## 숲 자원 지점: 앞마당이 없으면 빽빽한 나무와 노란 테두리(지도 안이면)로 표시
func _build_sites(buildings: Array) -> void:
	var taken := {}
	for b in buildings:
		if b.type == "outpost":
			taken["%d,%d" % [int(b.x), int(b.z)]] = true
	var key := "%s|%s" % [str(map_bounds), str(taken.keys())]
	if key == _sites_key:
		return
	_sites_key = key
	var m := MeshBatch.new()
	for s in GameConfig.resource_sites():
		if taken.has("%d,%d" % [int(s.x), int(s.z)]):
			continue
		var r := GridLogic.site_rect(s)
		for i in 4:
			var p := Vector2(r.position.x + 0.45 + (i % 2) * (r.size.x - 0.9), r.position.y + 0.45 + (i / 2) * (r.size.y - 0.9))
			var base := W(p.x, 0, p.y)
			m.cyl(0.08, 0.1, 0.35, base + Vector3(0, 0.17, 0), Models.WOOD_DARK, Vector3.ZERO, 8)
			m.cyl(0.0, 0.42, 0.8, base + Vector3(0, 0.75, 0), Color("27693b"), Vector3.ZERO, 10)
			m.cyl(0.0, 0.32, 0.6, base + Vector3(0, 1.15, 0), Color("2f7d45"), Vector3.ZERO, 10)
		if map_bounds.encloses(r):
			var c := Color("ffd84a")
			var t := 0.07
			var cx := r.position.x + r.size.x * 0.5
			var cz := r.position.y + r.size.y * 0.5
			m.box(Vector3(r.size.x, 0.02, t), W(cx, 0.03, r.position.y + t * 0.5), c)
			m.box(Vector3(r.size.x, 0.02, t), W(cx, 0.03, r.end.y - t * 0.5), c)
			m.box(Vector3(t, 0.02, r.size.y), W(r.position.x + t * 0.5, 0.03, cz), c)
			m.box(Vector3(t, 0.02, r.size.y), W(r.end.x - t * 0.5, 0.03, cz), c)
	_sites_node.mesh = m.mesh() if not m.is_empty() else null


# ------------------------------------------------------------------ 울타리

func rebuild_fences(edges: Dictionary) -> void:
	var b := MeshBatch.new()
	_add_fence_edges(b, edges.keys(), Models.WOOD, true)
	_add_gate(b)
	_fence_node.mesh = b.mesh()


## 편집 중 계획: 추가(초록/불가 시 주황)·제거 표시(빨강)
func show_fence_plan(add: Dictionary, remove: Dictionary, valid: bool) -> void:
	if add.is_empty() and remove.is_empty():
		_fence_plan_node.mesh = null
		return
	var b := MeshBatch.new()
	_add_fence_edges(b, add.keys(), Color("7fd65c") if valid else Color("f0a040"), true, 0.03)
	for k in remove:
		var p := GridLogic.edge_points(k)
		var a := W(p[0].x, 0, p[0].y)
		var c := W(p[1].x, 0, p[1].y)
		var mid := (a + c) * 0.5
		var along_x: bool = p[0].y == p[1].y
		b.box(Vector3(1.04 if along_x else 0.2, 0.06, 0.2 if along_x else 1.04), mid + Vector3(0, 0.78, 0), Color("e5484d"))
		b.box(Vector3(0.36, 0.08, 0.08), mid + Vector3(0, 0.95, 0), Color("e5484d"), Vector3(0, 45, 0))
		b.box(Vector3(0.36, 0.08, 0.08), mid + Vector3(0, 0.95, 0), Color("e5484d"), Vector3(0, -45, 0))
	_fence_plan_node.mesh = b.mesh()


func clear_fence_plan() -> void:
	_fence_plan_node.mesh = null


func _add_fence_edges(b: MeshBatch, keys: Array, color: Color, posts: bool, lift: float = 0.0) -> void:
	var post_set := {}
	for k in keys:
		var p := GridLogic.edge_points(k)
		var a := W(p[0].x, lift, p[0].y)
		var c := W(p[1].x, lift, p[1].y)
		var mid := (a + c) * 0.5
		var along_x: bool = p[0].y == p[1].y
		var size_rail := Vector3(1.0, 0.09, 0.07) if along_x else Vector3(0.07, 0.09, 1.0)
		b.box(size_rail, mid + Vector3(0, 0.26, 0), color.darkened(0.08))
		b.box(size_rail, mid + Vector3(0, 0.5, 0), color)
		post_set[p[0]] = true
		post_set[p[1]] = true
	if posts:
		# 기둥은 꼭짓점에서 한 번만(공유)
		for q in post_set:
			var pos := W(q.x, lift, q.y)
			b.box(Vector3(0.15, 0.7, 0.15), pos + Vector3(0, 0.35, 0), color.darkened(0.15))
			b.box(Vector3(0.18, 0.06, 0.18), pos + Vector3(0, 0.72, 0), color.darkened(0.25))


func _add_gate(b: MeshBatch) -> void:
	var gx := GameConfig.gate_x()
	for g in [{from = [gx.x, map_bounds.position.y], to = [gx.y, map_bounds.position.y]}]:
		var a := W(float(g.from[0]), 0, float(g.from[1]))
		var c := W(float(g.to[0]), 0, float(g.to[1]))
		# 바깥 두 기둥만(문 중앙 기둥 없음). 양문은 바깥쪽으로 열려 통로를 비운다.
		for side in [-1.0, 1.0]:
			var hinge := a if side < 0 else c
			b.box(Vector3(0.2, 0.95, 0.2), hinge + Vector3(0, 0.475, 0), Models.WOOD_DARK)
			b.box(Vector3(0.24, 0.06, 0.24), hinge + Vector3(0, 0.97, 0), Models.WOOD_DARK.darkened(0.2))
			var leaf_mid := hinge + Vector3(-side * 0.12, 0, 0.5)
			for i in 4:
				b.box(Vector3(0.05, 0.62, 0.2), leaf_mid + Vector3(0, 0.38, 0.36 - i * 0.24), Models.WOOD)
			b.box(Vector3(0.07, 0.08, 0.95), leaf_mid + Vector3(0, 0.6, 0), Models.WOOD_DARK)
			b.box(Vector3(0.07, 0.08, 0.95), leaf_mid + Vector3(0, 0.18, 0), Models.WOOD_DARK)
			b.box(Vector3(0.09, 0.06, 0.14), hinge + Vector3(-side * 0.1, 0.6, 0.08), Models.BLACK)
			b.box(Vector3(0.09, 0.06, 0.14), hinge + Vector3(-side * 0.1, 0.2, 0.08), Models.BLACK)


# ------------------------------------------------------------------ 건물

func sync_buildings(buildings: Array) -> void:
	var seen := {}
	for b in buildings:
		seen[b.id] = true
		var n: Node3D = _building_nodes.get(b.id)
		var dk := Decor.key(b.get("deco", {}))
		# 꾸미기·성 레벨·앞마당 파손이 바뀌면 다시 조립
		var mk := "%s|lv%d|%s" % [dk, int(b.level) if b.type == "castle" else 1, "x" if bool(b.get("damaged", false)) else ""]
		if n != null and String(n.get_meta("model_key", "")) != mk:
			# 꾸미기가 바뀌면 모델을 다시 조립한다(외형만, 위치·ID 유지)
			_building_nodes.erase(b.id)
			n.name = "%s_old" % b.id
			n.queue_free()
			n = null
		if n == null:
			n = Models.build(b.type, b.get("deco", {}), int(b.level), {damaged = bool(b.get("damaged", false))})
			n.name = b.id
			n.set_meta("deco_key", dk)
			n.set_meta("model_key", mk)
			_buildings_root.add_child(n)
			_building_nodes[b.id] = n
		place_node(n, b.type, int(b.x), int(b.z), int(b.rot))
		if b.type == "defense_tower":
			(n.get_node("Badge") as Label3D).visible = int(b.level) >= 2
			(n.get_node("Badge") as Label3D).text = "Lv.%d" % int(b.level)
	for id in _building_nodes.keys():
		if not seen.has(id):
			_building_nodes[id].queue_free()
			_building_nodes.erase(id)
	update_construction(buildings, 0.0)
	_build_sites(buildings)


func place_node(n: Node3D, type: String, x: int, z: int, rot: int) -> void:
	n.position = building_center(type, x, z)
	n.rotation = Vector3(0, yaw_for_rot(rot), 0)


func building_node(id: String) -> Node3D:
	return _building_nodes.get(id)


func show_ghost(type: String, x: int, z: int, rot: int) -> void:
	if _ghost == null or _ghost_type != type:
		hide_ghost()
		_ghost = Models.build(type, Decor.defaults(type))
		_ghost.name = "Ghost"
		_ghost_type = type
		add_child(_ghost)
	place_node(_ghost, type, x, z, rot)


func hide_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
		_ghost_type = ""


## 공사 중 표시: 몸체가 진행률만큼 올라오고 비계·남은 시간 표시. 완성 순간 살짝 튀어 오른다.
func update_construction(buildings: Array, delta: float) -> void:
	for b in buildings:
		var n: Node3D = _building_nodes.get(b.id)
		if n == null:
			continue
		var body: Node3D = n.get_node("Body")
		var left := float(b.get("build_left", 0.0))
		var sc: Node3D = n.get_node_or_null("Scaffold")
		if left > 0.0:
			var total := maxf(GameState.build_seconds(b.type), 0.001)
			var p := clampf(1.0 - left / total, 0.0, 1.0)
			if sc == null:
				sc = Models.scaffold(GameConfig.footprint(b.type))
				n.add_child(sc)
				var lbl := Label3D.new()
				lbl.name = "BuildTimer"
				lbl.font = _font
				lbl.font_size = 64
				lbl.pixel_size = 0.0075
				lbl.outline_size = 14
				lbl.modulate = Color("fff6d8")
				lbl.outline_modulate = Color("4a2b5e")
				lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lbl.no_depth_test = true
				lbl.position = Vector3(0, 2.0, 0)
				sc.add_child(lbl)
			body.scale = Vector3(1, 0.08 + 0.92 * p, 1)
			(sc.get_node("BuildTimer") as Label3D).text = "공사 중 %d초" % int(ceil(left))
			if n.has_node("Turret"):
				(n.get_node("Turret") as Node3D).visible = false
		else:
			if sc != null:
				sc.name = "ScaffoldDone"
				sc.queue_free()
				_complete_pop[b.id] = 0.45
			if n.has_node("Turret"):
				(n.get_node("Turret") as Node3D).visible = true
			var pop := float(_complete_pop.get(b.id, 0.0))
			if pop > 0.0:
				pop -= delta
				_complete_pop[b.id] = pop
				var k := sin(clampf(1.0 - pop / 0.45, 0.0, 1.0) * PI)
				body.scale = Vector3(1.0 + 0.08 * k, 1.0 + 0.14 * k, 1.0 + 0.08 * k)
			else:
				_complete_pop.erase(b.id)
				body.scale = Vector3.ONE


## 매 프레임: 공사 표시와 일꾼. active=false(전투·일시정지)면 일꾼은 제자리에서 멈춘다.
func update_village(buildings: Array, edges: Dictionary, delta: float, active: bool) -> void:
	update_construction(buildings, delta)
	crew.update_crew(buildings, edges, delta, active)


# ------------------------------------------------------------------ 편집 표시

func _build_grid_overlay() -> void:
	var was_visible := false
	if _grid_node != null:
		was_visible = _grid_node.visible
		_grid_node.queue_free()
	var b := MeshBatch.new()
	var bb := map_bounds if map_bounds.size != Vector2i.ZERO else GameConfig.initial_bounds()
	var w := float(bb.size.x)
	var d := float(bb.size.y)
	for x in range(bb.position.x, bb.end.x + 1):
		b.box(Vector3(0.03, 0.01, d), W(x, 0.03, bb.position.y + d * 0.5), Color(1, 1, 1))
	for z in range(bb.position.y, bb.end.y + 1):
		b.box(Vector3(w, 0.01, 0.03), W(bb.position.x + w * 0.5, 0.03, z), Color(1, 1, 1))
	_grid_node = b.instance("GridOverlay")
	var m := _unshaded(Color(1, 1, 1, 0.45))
	_grid_node.material_override = m
	_grid_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_node.visible = was_visible
	add_child(_grid_node)


func set_grid_visible(v: bool) -> void:
	_grid_node.visible = v


func _build_footprint() -> void:
	_footprint = MeshInstance3D.new()
	_footprint.name = "Footprint"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_footprint.mesh = pm
	_footprint_mat = _unshaded(Color(0.3, 0.9, 0.3, 0.45))
	_footprint.material_override = _footprint_mat
	_footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_footprint.visible = false
	add_child(_footprint)
	_selection = MeshInstance3D.new()
	_selection.name = "Selection"
	_selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection.visible = false
	add_child(_selection)


func show_footprint(type: String, x: int, z: int, ok: bool) -> void:
	var fp := GameConfig.footprint(type)
	_footprint.visible = true
	_footprint.position = W(x + fp.x * 0.5, 0.04, z + fp.y * 0.5)
	_footprint.scale = Vector3(fp.x, 1, fp.y)
	_footprint_mat.albedo_color = Color(0.3, 0.92, 0.35, 0.5) if ok else Color(0.95, 0.25, 0.25, 0.5)


func hide_footprint() -> void:
	_footprint.visible = false


func show_selection(b: Dictionary) -> void:
	if b.is_empty():
		_selection.visible = false
		return
	var fp := GameConfig.footprint(b.type)
	var mb := MeshBatch.new()
	var c := Color("ffd84a")
	var t := 0.08
	mb.box(Vector3(fp.x, 0.02, t), W(fp.x * 0.5, 0, t * 0.5), c)
	mb.box(Vector3(fp.x, 0.02, t), W(fp.x * 0.5, 0, fp.y - t * 0.5), c)
	mb.box(Vector3(t, 0.02, fp.y), W(t * 0.5, 0, fp.y * 0.5), c)
	mb.box(Vector3(t, 0.02, fp.y), W(fp.x - t * 0.5, 0, fp.y * 0.5), c)
	_selection.mesh = mb.mesh()
	_selection.material_override = _unshaded(c)
	_selection.position = W(b.x, 0.05, b.z)
	_selection.visible = true


# ------------------------------------------------------------------ 전투 연출

func clear_battle() -> void:
	for c in _battle_root.get_children():
		c.queue_free()
	_knight_nodes.clear()
	_bolt_nodes.clear()
	_dying.clear()
	_floaters.clear()
	_castle_shake = 0.0
	for id in _building_nodes:
		var n: Node3D = _building_nodes[id]
		if n.has_node("Turret"):
			(n.get_node("Turret") as Node3D).rotation = Vector3.ZERO


func _make_knight(k: Dictionary) -> void:
	var n := Models.knight()
	n.name = "Knight%d" % k.id
	n.position = W(k.pos.x, 0, k.pos.y) + _knight_offset(k.id)
	n.rotation.y = yaw_for_dir(k.facing)
	_battle_root.add_child(n)
	var bar := Node3D.new()
	bar.position = Vector3(0, 1.4, 0)
	n.add_child(bar)
	var bg := MeshInstance3D.new()
	var bgq := QuadMesh.new()
	bgq.size = Vector2(KNIGHT_HP_BAR_W + 0.06, 0.13)
	bg.mesh = bgq
	bg.material_override = _bar_bg_mat
	bar.add_child(bg)
	var fg := MeshInstance3D.new()
	var fgq := QuadMesh.new()
	fgq.size = Vector2(KNIGHT_HP_BAR_W, 0.08)
	fg.mesh = fgq
	var fgm := _bar_fg_mat.duplicate()
	fgm.render_priority = 11
	fg.material_override = fgm
	bar.add_child(fg)
	_knight_nodes[k.id] = {node = n, fg = fgq, flash = 0.0, swing = 0.0}


func _knight_offset(id: int) -> Vector3:
	return Vector3(float((id * 37) % 7 - 3) * 0.06, 0, float((id * 53) % 5 - 2) * 0.05)


func update_battle(sim: BattleSim, delta: float, castle_id: String) -> void:
	for e in sim.events:
		match e.type:
			"spawn":
				_make_knight(sim.knights[e.knight - 1])
			"fire":
				Sound.play("bow", -6.0, randf_range(0.92, 1.08))
				var t := _tower_node(e.tower)
				if t:
					var cb: Node3D = t.get_node("Turret/Crossbow")
					cb.position.z = 0.12
				var bn := Models.bolt()
				_battle_root.add_child(bn)
				_bolt_nodes[e.bolt] = {node = bn}
			"hit":
				Sound.play("hit", -4.0, randf_range(0.9, 1.1))
				if _knight_nodes.has(e.knight):
					_knight_nodes[e.knight].flash = 0.12
				_floater("-%d" % int(e.damage), _knight_pos(sim, e.knight) + Vector3(0.25, 1.65, 0), Color("fff1a8"))
			"kill":
				Sound.play("knight_down", -2.0)
				if _knight_nodes.has(e.knight):
					var kn: Dictionary = _knight_nodes[e.knight]
					var dead: Dictionary = sim.knights[e.knight - 1]
					(kn.node as Node3D).position = W(dead.pos.x, 0, dead.pos.y) + _knight_offset(e.knight)
					_set_overlay(kn.node, null)
					_dying.append({node = kn.node, t = 0.0})
					_knight_nodes.erase(e.knight)
			"castle_hit":
				Sound.play("castle_hit", -3.0)
				_castle_shake = 0.18
				if _knight_nodes.has(e.knight):
					_knight_nodes[e.knight].swing = 0.3
				var cn: Node3D = _building_nodes.get(castle_id)
				if cn:
					_floater("-%d" % int(e.damage), cn.position + Vector3(randf_range(-0.6, 0.6), 2.0, 0.6), Color("ff7a6e"))
	sim.events.clear()
	var t_now := sim.time
	# 기사
	for id in _knight_nodes:
		var kn: Dictionary = _knight_nodes[id]
		var k: Dictionary = sim.knights[id - 1]
		var n: Node3D = kn.node
		n.position = W(k.pos.x, 0, k.pos.y) + _knight_offset(id)
		var f: Vector2 = k.facing
		n.rotation.y = lerp_angle(n.rotation.y, yaw_for_dir(f), minf(1.0, delta * 12.0))
		var leg_l: Node3D = n.get_node("LegL")
		var leg_r: Node3D = n.get_node("LegR")
		var arm_r: Node3D = n.get_node("ArmR")
		var arm_l: Node3D = n.get_node("ArmL")
		if k.state == "walk":
			var s := sin(t_now * 9.0 + id)
			leg_l.rotation.x = s * 0.6
			leg_r.rotation.x = -s * 0.6
			arm_l.rotation.x = -s * 0.35
			arm_r.rotation.x = s * 0.35
			n.position.y = absf(s) * 0.04
		else:
			leg_l.rotation.x = 0.0
			leg_r.rotation.x = 0.0
			# 준비: 공격 시점이 다가오면 검을 들어 올리고, 피해 순간 내려친다
			var interval := float(GameConfig.combat().knight_attack_interval_seconds)
			var wind := clampf(1.0 - k.attack_timer / interval, 0.0, 1.0)
			kn.swing = maxf(0.0, kn.swing - delta)
			arm_r.rotation.x = 0.5 if kn.swing > 0.0 else 0.3 + wind * 2.3
			arm_l.rotation.x = -0.3
		kn.fg.size = Vector2(KNIGHT_HP_BAR_W * clampf(float(k.hp) / float(k.max_hp), 0.0, 1.0), 0.08)
		kn.fg.center_offset = Vector3(-(KNIGHT_HP_BAR_W - kn.fg.size.x) * 0.5, 0, 0)
		kn.flash = maxf(0.0, kn.flash - delta)
		_set_overlay(n, _flash_mat if kn.flash > 0.0 else null)
	# 쓰러지는 기사
	for dk in _dying:
		dk.t += delta
		var n: Node3D = dk.node
		n.rotation.x = -minf(dk.t / 0.35, 1.0) * PI * 0.5
		n.position.y = -maxf(0.0, dk.t - 0.6) * 0.8
		if dk.t > 1.2:
			n.queue_free()
	_dying = _dying.filter(func(d): return d.t <= 1.2)
	# 방어탑 조준
	for t in sim.towers:
		var tn := _tower_node(t.id)
		if tn == null:
			continue
		var turret: Node3D = tn.get_node("Turret")
		var desired := yaw_for_dir(t.aim)
		var g := turret.global_rotation
		g.y = lerp_angle(g.y, desired, minf(1.0, delta * 10.0))
		turret.global_rotation = Vector3(0, g.y, 0)
		var cb: Node3D = tn.get_node("Turret/Crossbow")
		cb.position.z = move_toward(cb.position.z, 0.0, delta * 0.6)
		var op: Node3D = tn.get_node("Turret/Operator")
		op.get_node("ArmL").rotation.x = 1.25
		op.get_node("ArmR").rotation.x = 1.25
	# 발사체: 지면 위치는 시뮬레이션, 높이는 탑 위에서 표적 가슴까지의 낮은 곡선
	for bolt in sim.bolts:
		if not _bolt_nodes.has(bolt.id):
			continue
		var bn: Dictionary = _bolt_nodes[bolt.id]
		var node: Node3D = bn.node
		var tk: Dictionary = sim.knights[bolt.target_id - 1]
		var total: float = (bolt.start as Vector2).distance_to(tk.pos) + 0.0001
		var left: float = (bolt.pos as Vector2).distance_to(tk.pos)
		var p := clampf(1.0 - left / total, 0.0, 1.0)
		var y := lerpf(2.0, 0.65, p) + sin(p * PI) * 0.35
		var pos := W(bolt.pos.x, y, bolt.pos.y)
		var dir := W(tk.pos.x, 0.65, tk.pos.y) - pos
		node.position = pos
		if dir.length() > 0.01:
			node.look_at(pos + dir, Vector3.UP)
	var live := {}
	for bolt in sim.bolts:
		live[bolt.id] = true
	for id in _bolt_nodes.keys():
		if not live.has(id):
			_bolt_nodes[id].node.queue_free()
			_bolt_nodes.erase(id)
	# 성 흔들림
	var castle: Node3D = _building_nodes.get(castle_id)
	if castle:
		var body: Node3D = castle.get_node("Body")
		if _castle_shake > 0.0:
			_castle_shake -= delta
			body.position = Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03))
		else:
			body.position = Vector3.ZERO
	_update_floaters(delta)


func _knight_pos(sim: BattleSim, id: int) -> Vector3:
	var k: Dictionary = sim.knights[id - 1]
	return W(k.pos.x, 0, k.pos.y)


func _tower_node(id: String) -> Node3D:
	var n: Node3D = _building_nodes.get(id)
	if n and n.has_node("Turret"):
		return n
	return null


func _set_overlay(n: Node, mat: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and c.material_override == null:
			(c as MeshInstance3D).material_overlay = mat
		if c.get_child_count() > 0 and not (c is MeshInstance3D):
			_set_overlay(c, mat)


func _floater(text: String, pos: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 56
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = col
	l.outline_modulate = Color("3a2443")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	_battle_root.add_child(l)
	_floaters.append({node = l, t = 0.0})


func _update_floaters(delta: float) -> void:
	for f in _floaters:
		f.t += delta
		var l: Label3D = f.node
		l.position.y += delta * 0.8
		l.modulate.a = clampf(1.0 - (f.t - 0.4) / 0.4, 0.0, 1.0)
		if f.t > 0.8:
			l.queue_free()
	_floaters = _floaters.filter(func(f): return f.t <= 0.8)

