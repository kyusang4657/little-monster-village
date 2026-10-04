extends SceneTree
## 캐릭터 캡처(개발·검수용, 디스플레이 필요). 게임과 같은 조명에서 근접 렌더링해 PNG 로 저장한다.
## 실행: xvfb-run -a -s "-screen 0 1700x1100x24" godot --path . --rendering-driver opengl3 --resolution 360x480 \
##        --script res://tests/character_capture.gd -- --out=<폴더> --mode=views --tag=before
## 모드: views(정면·옆·뒤), lineup(변형·보스 한 줄), strips(동작 프레임), ingame(게임 시점 소형), imp(뿔이 Lv.1~4 + 동작·표정, --lv= 로 프레임 레벨)
## CharacterRig 는 load() 로 불러와 새 모델이 없을 때(이전 모델 캡처)도 이 스크립트가 해석된다.

var out := ""
var mode := "views"
var tag := "after"
var who := "imp:4"
var frame_lv := 1   # imp 모드의 동작·표정 프레임에 쓰는 뿔이 레벨(--lv=)
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
		elif a.begins_with("--who="):
			who = a.substr(6)
		elif a.begins_with("--model-set="):
			CharacterRig.model_set = a.substr(12)
		elif a.begins_with("--lv="):
			frame_lv = int(a.substr(5))
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
		"imp":
			await _imp()
		"units":
			await _units()
		"solo":
			await _solo()
		"cast":
			await _cast()
		"geo":
			await _geo()
	quit(0)


## --who 문자열 하나를 리그로. 예: imp:4, knight:2, boss:hero, goblin:1, goblin:0:nohammer, orc, skeleton
func _make(spec: String) -> Node3D:
	var parts := spec.split(":")
	var k := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	match k:
		"imp":
			return _rig.call("imp", int(arg) if arg != "" else 4)
		"knight":
			return _rig.call("knight", int(arg) if arg != "" else 0)
		"boss":
			return _rig.call("boss", arg if arg != "" else "hero")
		"goblin":
			return _rig.call("goblin", int(arg) if arg != "" else 0, not (parts.size() > 2 and parts[2] == "nohammer"))
		"orc":
			return _rig.call("orc")
		"skeleton":
			return _rig.call("skeleton_archer")
	return _rig.call("knight", 0)


## 한 캐릭터를 모든 각도·동작·표정으로(빌더 작업용). --who=imp:4,knight:2 처럼 여러 개 가능.
## 파일: solo-<who>-front/three/side/back, solo-<who>-pose-idle/walk/action/hit, solo-<who>-face-<표정>
func _solo() -> void:
	if _rig == null:
		return
	for spec in who.split(","):
		var tagn := spec.replace(":", "")
		_clear()
		var n: Node3D = _add(_make(spec))
		n.call("pose_idle", 0.0)
		n.call("update_blink", 2.0)
		var h: float = n.get("HEIGHT")
		var top: float = n.call("hp_bar_y")
		var cy := top * 0.5
		var size := maxf(top * 1.35, 0.9)
		for view in [["front", 0.0], ["three", 35.0], ["side", 90.0], ["back", 180.0]]:
			_aim(Vector3(0, cy, 0), view[1], 8.0, size)
			await _shot("solo-%s-%s" % [tagn, view[0]])
		var kind: String = n.get("kind")
		for pose in ["idle", "walk", "action", "hit"]:
			n.call("set_expression", "normal")
			match pose:
				"idle":
					n.call("pose_idle", 1.3)
					n.call("update_secondary", 1.0 / 30.0, 0.0)
				"walk":
					n.call("pose_walk", 0.3)
					for i in 20:
						n.call("update_secondary", 1.0 / 30.0, 1.0)
				"action":
					if kind == "goblin":
						n.call("pose_hammer", 0.05)
					elif kind == "imp":
						n.call("pose_cheer", 0.25)
						n.call("set_expression", "happy")
					elif kind == "skeleton":
						n.call("pose_crossbow", 0.0)
						n.call("set_expression", "angry")
					else:
						n.call("pose_attack", 0.9)
						n.call("set_expression", "angry")
				"hit":
					n.call("pose_idle", 0.0)
					n.call("pose_hit", 0.2)
					n.call("set_expression", "hurt")
			n.call("update_blink", 2.0)
			_aim(Vector3(0, cy, 0), -40.0, 12.0, size)
			await _shot("solo-%s-pose-%s" % [tagn, pose])
		n.call("pose_idle", 0.0)
		var head_y: float = n.call("joint_global_position", "Head").y
		for e in ["normal", "happy", "angry", "hurt", "ko"]:
			n.call("set_expression", e)
			n.call("update_blink", 2.0)
			_aim(Vector3(0, head_y + h * 0.04, 0), 0.0, 6.0, h * 0.5)
			await _shot("solo-%s-face-%s" % [tagn, e])
		# 게임 시점 크기(화면에서 실제로 보이는 크기, 약 60px 높이)
		n.call("set_expression", "normal")
		n.call("pose_walk", 0.3)
		_aim(Vector3(0, cy, 0), 20.0, 52.0, size * 4.0)
		await _shot("solo-%s-ingame" % tagn)


## 전체 출연진 한 줄(기사 5·기사단장·용사·고블린 3·오크·해골·뿔이 Lv.1·Lv.4)
func _cast() -> void:
	if _rig == null:
		return
	_clear()
	var specs := ["knight:0", "knight:1", "knight:2", "knight:3", "knight:4", "boss:commander", "boss:hero",
		"goblin:0", "goblin:1", "goblin:2:nohammer", "orc", "skeleton", "imp:1", "imp:4"]
	var x := float(specs.size() - 1) * 0.5 * 0.72
	for s in specs:
		var n: Node3D = _add(_make(s), Vector3(x, 0, 0))
		n.call("pose_idle", 0.0)
		n.call("update_blink", 2.0)
		x -= 0.72
	var vp := root.get_visible_rect().size
	_aim(Vector3(0, 0.7, 0), 12.0, 10.0, maxf(2.0, 11.0 * vp.y / vp.x))
	await _shot("cast")


## 새 기본 도형 견본(rounded_box·spline_tube·horn·torus·polygon·star·wing·cape·눈 옵션)
func _geo() -> void:
	_clear()
	var g := CharGeo.new()
	g.add_bone("Root", "", Vector3.ZERO)
	g.add_bone("Head", "Root", Vector3(0, 0.5, 0))
	g.use("Root")
	# 얼굴은 x = 0 기준이므로 머리를 가운데 두고 나머지 견본을 양옆에 놓는다
	g.rounded_box(Vector3(-2.0, 0.3, 0), Vector3(0.25, 0.3, 0.2), Color("4a3a5c"), 0.45)
	g.spline_tube([Vector3(-1.4, 0.0, 0), Vector3(-1.4, 0.25, 0.05), Vector3(-1.3, 0.45, 0.15), Vector3(-1.1, 0.55, 0.3)], [0.08, 0.07, 0.045, 0.0], Color("c9c2c6"), 10)
	g.horn(Vector3(-0.8, 0.0, 0), Vector3(0.3, 1.0, 0), Vector3(0.5, -0.2, 0.3), 0.55, 0.09, Color("c9c2c6"), 7, 10, Color("8d8489"))
	g.torus(Vector3(0.7, 0.1, 0), 0.22, 0.07, Color("f3ece4"), 14, 8)
	g.polygon(CharGeo.star(5, 0.2, 0.09), Vector3(0.7, 0.55, 0), Basis.IDENTITY, 0.04, Color("e0b04c"), Color("a87c2a"))
	g.wing(Vector3(1.3, 0.3, 0), [Vector3(1.85, 0.75, 0.1), Vector3(2.0, 0.4, 0.1), Vector3(1.9, 0.05, 0.1)], 0.018, Color("3a2a3f"), Color("7a2634"), 0.3)
	g.cape(Vector3(2.6, 0.75, 0.0), 0.7, 0.3, 0.5, Color("b3202c"), Color("5a1018"), 0.12, 0.08, 0.03)
	g.use("Head")
	var hc := Vector3(0.0, 0.45, 0)
	var hr := Vector3(0.2, 0.19, 0.19)
	g.ellipsoid(hc, hr, Color("3a2a3f"), 16, 10)
	CharGeo.face(g, {hc = hc, hr = hr, es = 0.05, eye_y = 0.47, eye_dx = 0.085, mouth_y = 0.38, mouth_w = 0.08,
		skin = Color("3a2a3f"), pupil = Color("151015"), brow = Color("251a28"), sclera = Color("f5c43a"), pupil_shape = "slit",
		eye_rim = Color("1a1018"), lid = Color("3a2a3f"), brow_t = 1.3})
	var def := g.build(_rig.call("character_material"))
	var mi := MeshInstance3D.new()
	mi.mesh = def.mesh
	mi.material_overlay = _rig.call("outline_material")
	_add(mi)
	_aim(Vector3(0.3, 0.35, 0), 20.0, 14.0, 2.6)
	await _shot("geo")
	print("geo tris ", def.tris)


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
		if _rig.has_method("orc"):
			nodes.append(_rig.call("skeleton_archer"))
			nodes.append(_rig.call("orc"))
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


## 뿔이 시안: 성 레벨 1~4 정면·옆·뒤, 레벨 줄 세우기(고블린·기사와 키 비교), 동작 프레임, 표정
func _imp() -> void:
	if _rig == null:
		return
	for lv in range(1, 5):
		_clear()
		var n: Node3D = _add(_rig.call("imp", lv))
		n.call("pose_idle", 0.0)
		n.call("update_blink", 2.0)
		for view in [["front", 0.0], ["three", 35.0], ["side", 90.0], ["back", 180.0]]:
			_aim(Vector3(0, 0.5, 0), view[1], 8.0, 1.25)
			await _shot("imp-lv%d-%s" % [lv, view[0]])
	# 줄 세우기: 고블린 · 뿔이 Lv.1~4 · 기사
	_clear()
	var nodes: Array = [_rig.call("goblin", 0, true)]
	for lv in range(1, 5):
		nodes.append(_rig.call("imp", lv))
	nodes.append(_rig.call("knight", 0))
	var x := float(nodes.size() - 1) * 0.5 * 0.62
	for n in nodes:
		_add(n, Vector3(x, 0, 0))
		n.call("pose_idle", 0.0)
		n.call("update_blink", 2.0)
		x -= 0.62
	# 줄 세우기는 가로가 넓으므로 화면 비율에 맞춰 크기를 정한다
	var vp := root.get_visible_rect().size
	_aim(Vector3(0, 0.6, 0), 15.0, 10.0, maxf(1.6, 4.2 * vp.y / vp.x))
	await _shot("imp-lineup")
	# 동작: 대기 숨쉬기, 걷기, 무서운 척 → 휘청, 환호 점프
	var specs := [["idle", 6], ["walk", 8], ["scare", 8], ["cheer", 6]]
	for sp in specs:
		_clear()
		var n: Node3D = _add(_rig.call("imp", frame_lv))
		var frames: int = sp[1]
		for f in frames:
			var p := float(f) / float(frames)
			n.call("set_expression", "normal")
			match String(sp[0]):
				"idle":
					n.call("pose_idle", p * 3.0)
					n.call("update_secondary", 1.0 / 30.0, 0.0)
				"walk":
					n.call("pose_walk", p)
					n.call("update_secondary", 1.0 / 30.0, 1.0)
				"scare":
					n.call("pose_scare", float(f) / float(frames - 1))
					n.call("update_secondary", 1.0 / 30.0, 0.6)
				"cheer":
					n.call("pose_cheer", p)
					n.call("update_secondary", 1.0 / 30.0, 0.8)
			n.call("update_blink", 2.0)
			_aim(Vector3(0, 0.48, 0), -40.0, 10.0, 1.35)
			await _shot("imp-frame-%s-%d" % [sp[0], f])
	# 표정
	_clear()
	var fn: Node3D = _add(_rig.call("imp", frame_lv))
	fn.call("pose_idle", 0.0)
	for e in ["normal", "happy", "angry", "hurt", "ko"]:
		fn.call("set_expression", e)
		fn.call("update_blink", 2.0)
		_aim(Vector3(0, 0.62, 0), 0.0, 6.0, 0.55)
		await _shot("imp-face-%s" % e)


## 4차 유닛: 해골 궁수·꼬마 오크(고블린 일꾼과 키 비교), 3/4 시점과 동작
func _units() -> void:
	_clear()
	var nodes: Array = [_rig.call("goblin", 0, true), _rig.call("skeleton_archer"), _rig.call("orc")]
	var x := 0.75
	for n in nodes:
		_add(n, Vector3(x, 0, 0))
		n.call("pose_idle", 0.0)
		n.call("update_blink", 2.0)
		x -= 0.75
	_aim(Vector3(0, 0.55, 0), 20.0, 10.0, 1.5)
	await _shot("units-lineup")
	_clear()
	var sk: Node3D = _add(_rig.call("skeleton_archer"), Vector3(0.45, 0, 0))
	sk.call("pose_crossbow", 0.0)
	sk.call("set_expression", "angry")
	var oc: Node3D = _add(_rig.call("orc"), Vector3(-0.45, 0, 0))
	oc.call("pose_attack", 0.9)
	oc.call("set_expression", "angry")
	_aim(Vector3(0, 0.55, 0), -35.0, 10.0, 1.5)
	await _shot("units-action")
