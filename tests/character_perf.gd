extends SceneTree
## 캐릭터 성능 측정(개발용, 디스플레이 필요). 기사 20 + 고블린 2 를 걷기·공격 자세로 매 프레임 갱신한다.
## 실행: xvfb-run -a -s "-screen 0 1700x1100x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tests/character_perf.gd
## 결과는 데스크톱 Xvfb + Mesa llvmpipe(소프트웨어 렌더링) 기준이며 휴대폰 측정이 아니다.
## CharacterRig 가 있으면 새 리그(자세 함수)를, 없으면 예전 Models 관절 노드 회전을 쓴다.

const RUN_SECONDS := 10.0
const BASELINE_SECONDS := 1.5

var _world: Node3D
var _chars: Array = []
var _t := 0.0
var _phase := 0           # 0 = 빈 장면 기준선, 1 = 캐릭터 측정
var _frames := 0
var _worst := 0.0
var _last_us := 0
var _base_info := {}
var _max_tris := 0
var _max_calls := 0
var _rig_script: Script = null
var _pose_us := 0


func _initialize() -> void:
	_setup.call_deferred()


func _setup() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if ResourceLoader.exists("res://scripts/world/character_rig.gd"):
		_rig_script = load("res://scripts/world/character_rig.gd")
	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("8fc45a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff3dc")
	e.ambient_light_energy = 0.2
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 25, 0)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	_world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	_world.add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.0
	var az := deg_to_rad(30.0)
	var el := deg_to_rad(50.0)
	cam.position = Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) * 40.0
	_world.add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.make_current()
	_last_us = Time.get_ticks_usec()


func _spawn() -> void:
	for i in 20:
		var n: Node3D
		if _rig_script:
			n = _rig_script.call("knight", (i * 7) % 5)
		else:
			n = Models.knight()
		n.position = Vector3(float(i % 5) * 1.0 - 2.0, 0, floorf(i / 5.0) - 1.5)
		_world.add_child(n)
		_chars.append({node = n, kind = "knight", attack = i % 2 == 1, id = i})
	for i in 2:
		var g: Node3D
		if _rig_script:
			g = _rig_script.call("goblin", i, true)
		else:
			g = Models.goblin(true)
		g.position = Vector3(-3.0 + i * 6.0, 0, 2.0)
		_world.add_child(g)
		_chars.append({node = g, kind = "goblin", attack = i == 1, id = 20 + i})


func _pose(c: Dictionary, delta: float) -> void:
	var n: Node3D = c.node
	var t: float = _t + float(c.id) * 0.37
	if n.has_method("pose_walk"):
		if c.attack:
			if c.kind == "knight":
				n.call("pose_attack", fposmod(t, 1.0))
				n.call("set_expression", "angry")
			else:
				n.call("pose_hammer", fposmod(t * 1.3, 1.0))
		else:
			n.call("pose_walk", t * 1.6)
		n.call("update_secondary", delta, 0.0 if c.attack else 0.6)
		n.call("update_blink", t)
		return
	var s := sin(t * 9.0)
	if c.attack:
		(n.get_node("ArmR") as Node3D).rotation.x = 0.3 + fposmod(t, 1.0) * 2.3
	else:
		(n.get_node("LegL") as Node3D).rotation.x = s * 0.6
		(n.get_node("LegR") as Node3D).rotation.x = -s * 0.6
		(n.get_node("ArmL") as Node3D).rotation.x = -s * 0.35
		(n.get_node("ArmR") as Node3D).rotation.x = s * 0.35
		n.position.y = absf(s) * 0.04


func _process(delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var dt_ms := float(now - _last_us) / 1000.0
	_last_us = now
	_t += delta
	if _world == null:
		return false
	if _phase == 0:
		if _t > BASELINE_SECONDS:
			_base_info = _info()
			_spawn()
			_phase = 1
			_t = 0.0
			_frames = -10
		return false
	var p0 := Time.get_ticks_usec()
	for c in _chars:
		_pose(c, delta)
	if _frames >= 0:
		_pose_us += Time.get_ticks_usec() - p0
	_frames += 1
	if _frames > 0:
		_worst = maxf(_worst, dt_ms)
		var inf := _info()
		_max_tris = maxi(_max_tris, int(inf.tris))
		_max_calls = maxi(_max_calls, int(inf.calls))
	if _frames == 0:
		_t = 0.0
	if _frames > 0 and _t >= RUN_SECONDS:
		var inf := _info()
		print("PERF models=%s frames=%d seconds=%.2f avg_fps=%.1f worst_frame_ms=%.1f" % ["CharacterRig" if _rig_script else "old Models", _frames, _t, _frames / _t, _worst])
		print("PERF pose_update_avg_ms=%.2f (22 characters, GDScript)" % [float(_pose_us) / 1000.0 / maxf(1.0, float(_frames))])
		print("PERF scene_only %s" % [_base_info])
		print("PERF with_characters_all %s" % [inf])
		print("PERF with_characters tris=%d draw_calls=%d (max tris=%d calls=%d)" % [inf.tris, inf.calls, _max_tris, _max_calls])
		print("PERF characters_only tris=%d draw_calls=%d" % [int(inf.tris) - int(_base_info.tris), int(inf.calls) - int(_base_info.calls)])
		quit(0)
	return false


func _info() -> Dictionary:
	return {
		tris = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		calls = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		shadow_tris = root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		shadow_calls = root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		rs_tris = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		rs_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
	}
