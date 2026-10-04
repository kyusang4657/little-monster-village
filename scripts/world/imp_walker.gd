class_name ImpWalker
extends Node3D
## 뿔이(주인공, 어린 마왕): 마을을 산책하고, 누르면 반응하고, 성이 자라면 함께 자란다. 외형·연출 전용(규칙 없음).
## 산책 목적지는 성 앞·주택 앞·벌목소 앞을 차례로 돈다(난수 없음). 전투 중에는 성 뒤에 숨어서 지켜본다.

const SPEED := 1.1
var _bounds := Rect2i()

var rig: CharacterRig
var level := 0
var pos := Vector2(-99, -99)
var face := Vector2(0, -1)
var path: Array = []
var _time := 0.0
var _wait := 2.0
var _goal_i := 0
var _cheer_t := 0.0
var _scare_t := -1.0
var _bubble: Label3D
var _bubble_t := 0.0
var _font: Font


func setup(font: Font) -> void:
	_font = font
	_bubble = Label3D.new()
	_bubble.font = font
	_bubble.font_size = 56
	_bubble.pixel_size = 0.0065
	_bubble.outline_size = 14
	_bubble.modulate = Color("fff6d8")
	_bubble.outline_modulate = Color("2e1a0e")
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.width = 640.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.visible = false
	add_child(_bubble)


func set_level(lv: int) -> void:
	if lv == level and rig != null:
		return
	level = lv
	if rig != null:
		rig.queue_free()
	rig = CharacterRig.imp(lv)
	rig.name = "Imp"
	rig.seed_id = 77
	add_child(rig)


## 누르면: 깡충 환호 + 한마디
func react(line: String) -> void:
	_cheer_t = 1.6
	_say(line, 2.6)


## 성이 자랄 때: 오래 환호 + 레벨 대사
func celebrate(line: String) -> void:
	_cheer_t = 3.2
	_say(line, 3.4)


func _say(line: String, secs: float) -> void:
	if line == "":
		return
	_bubble.text = line
	_bubble.visible = true
	_bubble_t = secs


## 화면 좌표 근처에 뿔이가 있는가(누르기 판정)
func hit(cam: Camera3D, screen: Vector2) -> bool:
	if rig == null or not visible:
		return false
	var p := cam.unproject_position(global_position + Vector3(0, 0.45, 0))
	# 확대 정도에 맞춘 판정 반경(약 0.45칸)
	var edge := cam.unproject_position(global_position + Vector3(0.45, 0.45, 0))
	return p.distance_to(screen) < maxf(24.0, p.distance_to(edge))


func update_imp(buildings: Array, edges: Dictionary, bounds: Rect2i, delta: float, battle: bool) -> void:
	if rig == null:
		return
	_bounds = GridLogic.bnd(bounds)
	_time += delta
	var castle := GridLogic.castle_of(buildings)
	var goals := _goals(buildings, castle, battle)
	var here := Vector2i(int(floor(pos.x)), int(floor(pos.y)))
	if (pos.x < -50.0 or (path.is_empty() and GridLogic.occupancy(buildings).has(here))) and not goals.is_empty():
		# 처음이거나, 서 있던 칸에 건물이 들어서면 빈 목적지로 옮긴다
		pos = Vector2(goals[0].x + 0.5, goals[0].y + 0.5)
		path = []
	if path.is_empty():
		_wait -= delta
		if _wait <= 0.0 and not goals.is_empty():
			_goal_i = (_goal_i + 1) % goals.size()
			var g: Vector2i = goals[_goal_i]
			var cells := GridLogic.find_path(buildings, edges, Vector2i(int(floor(pos.x)), int(floor(pos.y))), {g: true}, bounds)
			path = []
			for c in cells:
				path.append(Vector2(c.x + 0.5, c.y + 0.5))
			# 길이 없으면(울타리로 막힘 등) 순간이동하지 않고 다음 목적지를 잠시 뒤에 고른다
			_wait = 3.5 + float(_goal_i % 3) if not path.is_empty() else 0.5
			# 가끔(목적지 세 번에 한 번) 무서운 자세 연습
			if _goal_i % 3 == 1:
				_scare_t = 0.0
	var speed := 0.0
	if not path.is_empty() and _cheer_t <= 0.0:
		var move := SPEED * delta
		while move > 0.0 and not path.is_empty():
			var t: Vector2 = path[0]
			var to := t - pos
			var d := to.length()
			if d <= move:
				pos = t
				move -= d
				path.pop_front()
			else:
				pos += to / d * move
				face = to / d
				move = 0.0
		speed = 1.0
	position = WorldView.W(pos.x, 0, pos.y)
	if _cheer_t > 0.0:
		_cheer_t -= delta
		rig.pose_cheer(_time * 1.6)
	elif speed > 0.0:
		rig.pose_walk(_time * CharacterRig.WALK_RATE * 1.2)
		rig.set_expression("normal")
		rig.rotation.y = WorldView.yaw_for_dir(face)
	elif _scare_t >= 0.0:
		_scare_t += delta / 2.4
		rig.pose_scare(_scare_t)
		if _scare_t >= 1.0:
			_scare_t = -1.0
	else:
		rig.pose_idle(_time)
		rig.set_expression("hurt" if battle else "normal")
		if battle and not castle.is_empty():
			# 전투 중: 성을 바라보며 걱정
			var fp := GameConfig.footprint("castle")
			rig.rotation.y = WorldView.yaw_for_dir(Vector2(castle.x + fp.x * 0.5, castle.z + fp.y * 0.5) - pos)
	rig.update_secondary(delta, speed)
	rig.update_blink(_time)
	if _bubble_t > 0.0:
		_bubble_t -= delta
		_bubble.position = Vector3(0, 1.25, 0)
		_bubble.modulate.a = clampf(_bubble_t / 0.3, 0.0, 1.0)
		if _bubble_t <= 0.0:
			_bubble.visible = false


## 산책 목적지: 성 앞(정문 쪽) → 주택 앞 → 벌목소 앞… 전투 중에는 성 뒤 한 칸
func _goals(buildings: Array, castle: Dictionary, battle: bool) -> Array:
	var out: Array = []
	if castle.is_empty():
		return out
	var cfp := GameConfig.footprint("castle")
	var occ := GridLogic.occupancy(buildings)
	if battle:
		for c in [Vector2i(castle.x + 1, castle.z + cfp.y), Vector2i(castle.x + cfp.x, castle.z + 1), Vector2i(castle.x - 1, castle.z + 1)]:
			if not occ.has(c):
				return [c]
		return out
	var cands: Array = [Vector2i(castle.x + 1, castle.z - 1)]
	for b in buildings:
		if b.type in ["house", "lumber_camp"] and float(b.get("build_left", 0.0)) <= 0.0:
			var fp := GameConfig.footprint(b.type)
			cands.append(Vector2i(int(b.x) + fp.x / 2, int(b.z) - 1))
	# 경계 안 빈칸만
	for c in cands:
		if GridLogic.in_grid(c, _bounds) and not occ.has(c):
			out.append(c)
	return out
