extends SceneTree
## 캐릭터 캡처(개발·검수용, 디스플레이 필요). 게임과 같은 조명에서 근접 렌더링해 PNG 로 저장한다.
## 실행: xvfb-run -a -s "-screen 0 1700x1100x24" godot --path . --rendering-driver opengl3 --resolution 360x480 \
##        --script res://tests/character_capture.gd -- --out=<폴더> --mode=views --tag=before
## 모드: views(정면·옆·뒤), lineup(변형·보스 한 줄), strips(동작 프레임), ingame(게임 시점 소형)
## CharacterRig 는 load() 로 불러와 새 모델이 없을 때(이전 모델 캡처)도 이 스크립트가 해석된다.

var out := ""
var mode := "views"
var tag := "after"
var _world: Node3D
var _cam: Camera3D
var _rig: Script = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--tag="):
			tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	if ResourceLoader.exists("res://scripts/world/character_rig.gd"):
		_rig = load("res://scripts/world/character_rig.gd")
	_run.call_deferred()


func _run() -> void:
	_setup_scene()
	match mode:
		"views":
			await _views()
		"lineup":
			await _lineup()
		"strips":
			await _strips()
		"faces":
			await _faces()
	quit(0)


func _setup_scene() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("8fc45a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff3dc")
	e.ambient_light_energy = 0.2
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 25, 0)
	sun.light_energy = 0.5
	sun.light_color = Color("fff6e5")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_opacity = 0.55
	sun.shadow_blur = 1.5
	_world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("8fc45a")
	ground.material_override = gm
	_world.add_child(ground)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.1
	_cam.far = 100.0
	_world.add_child(_cam)
	_cam.make_current()


## 카메라: target 을 바라보며 yaw(0 = 캐릭터 정면 쪽 -Z 에서 봄), 고도 elev 도
func _aim(target: Vector3, yaw_deg: float, elev_deg: float, size: float) -> void:
	var y := deg_to_rad(yaw_deg)
	var el := deg_to_rad(elev_deg)
	var dir := Vector3(-sin(y) * cos(el), sin(el), -cos(y) * cos(el))
	_cam.size = size
	_cam.look_at_from_position(target + dir * 20.0, target, Vector3.UP)


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _clear() -> void:
	for c in _world.get_children():
		if c.has_meta("subject"):
			_world.remove_child(c)
			c.free()


func _add(n: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
	n.set_meta("subject", true)
	n.position = pos
	_world.add_child(n)
	return n


func _goblin(v: int) -> Node3D:
	if _rig:
		return _rig.call("goblin", v, true)
	return Models.goblin(true)


func _knight(v: int) -> Node3D:
	if _rig:
		return _rig.call("knight", v)
	return Models.knight()


func _views() -> void:
	var subjects := {"goblin": _goblin(0), "knight": _knight(0)}
	for key in subjects:
		_clear()
		var n: Node3D = _add(subjects[key])
		if n.has_method("pose_idle"):
			n.call("pose_idle", 0.0)
		for view in [["front", 0.0], ["side", 90.0], ["back", 180.0]]:
			_aim(Vector3(0, 0.66, 0), view[1], 8.0, 1.62)
			await _shot("%s-%s-%s" % [tag, key, view[0]])


## 변형 5종·고블린 3종·용사·기사단장 한 줄(정면 약간 위, 3/4 시점)
func _lineup() -> void:
	_clear()
	var nodes: Array = []
	for v in 5:
		nodes.append(_knight(v))
	for v in 3:
		nodes.append(_goblin(v))
	if _rig:
		nodes.append(_rig.call("boss", "hero"))
		nodes.append(_rig.call("boss", "commander"))
	# 정면(-Z)에서 보면 +X 가 화면 왼쪽이므로 첫 캐릭터를 +X 끝에 둔다
	var x := float(nodes.size() - 1) * 0.5 * 0.78
	for n in nodes:
		_add(n, Vector3(x, 0, 0))
		if n.has_method("pose_idle"):
			n.call("pose_idle", 0.0)
		x -= 0.78
	_aim(Vector3(0, 0.7, 0), 12.0, 12.0, 1.95)
	await _shot("lineup")


## 동작 프레임: 각 동작마다 frames 장(옆에서 약간 앞쪽 3/4 시점)
func _strips() -> void:
	if _rig == null:
		return
	var specs := [
		["walk", "knight", 8], ["walkg", "goblin", 8], ["attack", "knight", 8], ["hit", "knight", 6],
		["die", "knight", 7], ["hammer", "goblin", 8],
	]
	for s in specs:
		_clear()
		var n: Node3D = _add(_rig.call("knight", 0) if s[1] == "knight" else _rig.call("goblin", 0, true))
		var frames: int = s[2]
		for f in frames:
			var p := float(f) / float(frames)
			match String(s[0]):
				"walk", "walkg":
					n.call("set_expression", "normal")
					n.call("pose_walk", p)
					n.call("update_secondary", 1.0 / 30.0, 1.0)
				"attack":
					# 0.0 = 내려친 순간(성 피해와 같은 프레임)
					n.call("set_expression", "angry")
					n.call("pose_attack", p)
				"hit":
					n.call("set_expression", "hurt")
					n.call("pose_hit", float(f) / float(frames - 1))
				"die":
					n.call("set_expression", "hurt")
					n.call("pose_die", float(f) / float(frames - 1))
				"hammer":
					n.call("set_expression", "normal")
					n.call("pose_hammer", p)
			n.call("update_blink", 0.5)
			_aim(Vector3(0, 0.55, 0.42 if s[0] == "die" else 0.0), -60.0, 12.0, 1.7 if s[0] != "die" else 2.1)
			await _shot("frame-%s-%d" % [s[0], f])


## 표정 근접(보통·화남·아픔·눈 감음)
func _faces() -> void:
	if _rig == null:
		return
	var subjects := [["goblin", _rig.call("goblin", 0, true), 0.8], ["knight", _rig.call("knight", 0), 0.95], ["hero", _rig.call("boss", "hero"), 1.1]]
	for sj in subjects:
		_clear()
		var n: Node3D = _add(sj[1])
		n.call("pose_idle", 0.0)
		for e in ["normal", "angry", "hurt", "ko"]:
			n.call("set_expression", e)
			n.call("update_blink", 1.0)
			_aim(Vector3(0, float(sj[2]), 0), 0.0, 6.0, 0.5)
			await _shot("face-%s-%s" % [sj[0], e])
