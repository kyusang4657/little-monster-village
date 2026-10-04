extends SceneTree
## 악마형 마왕 Lv.1 교체 후보 테스트 씬(디스플레이 필요). 게임과 같은 조명·카메라 규칙으로 기존 모델과 후보를 캡처한다.
## 실행: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 420x480 --script res://tests/demon_lv1_scene.gd -- \
##        --out=<폴더> --variant=<이름>[,<이름>...] [--views=front,three,side,back,face,ingame,poses,faces]
## variant: old(기존 뿔이 Lv.1 그대로) old_nooutline old_thin(외곽선 0.005) old_gray(회색 재질, 정점 명암 없음) old_weld(겹치는 위치 법선 평균)
##          old_soft(림·반사 줄인 재질) new_gray(새 모델 회색) new(새 모델 최종) new_nooutline new_thin
## 캡처 이름: <variant>-<view>.png. 카메라·조명·해상도는 variant 와 무관하게 같다.

var out := "/tmp/demon"
var variants := "old"
var views := "front,three,side,back,face,ingame,poses,faces"
var _world: Node3D
var _cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--variant="):
			variants = a.substr(10)
		elif a.begins_with("--views="):
			views = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	_setup_scene()
	for vname in variants.split(","):
		var rig := make_variant(vname)
		if rig == null:
			print("모르는 variant: ", vname)
			continue
		await _capture(rig, vname)
		rig.free()
	quit(0)


## 게임(world_view._setup_environment)과 같은 조명·환경, 캐릭터 캡처(character_capture)와 같은 바닥·직교 카메라
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
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.08
	e.adjustment_contrast = 1.06
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


## variant 이름 → 리그. 기존 모델의 변형은 메시 배열을 복제해 한 요소만 바꾼다(원본 빌더·공유 재질은 건드리지 않는다)
static func make_variant(vname: String) -> CharacterRig:
	var rig: CharacterRig
	if vname.begins_with("old"):
		rig = CharacterRig.imp(1)
	elif vname.begins_with("new"):
		var def := DemonLv1Builder.build(vname == "new_gray")
		rig = CharacterRig._instance(def, "imp", 1, 1.0)
	else:
		return null
	rig.seed_id = 77
	match vname:
		"old_nooutline", "new_nooutline":
			rig.body.material_overlay = null
		"old_thin", "new_thin":
			rig.body.material_overlay = thin_outline(0.005)
		"old_gray":
			_rebuild(rig, "gray")
		"old_weld":
			_rebuild(rig, "weld")
		"old_soft":
			_rebuild(rig, "soft")
	return rig


static func thin_outline(width: float) -> ShaderMaterial:
	var m: ShaderMaterial = CharacterRig.outline_material().duplicate()
	m.set_shader_parameter("width", width)
	return m


## 형태 확인용 회색 재질(정점 색 무시, 림 없음)
static func gray_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.62, 0.62)
	m.roughness = 0.7
	m.metallic_specular = 0.3
	return m


## 림·반사광을 줄인 부드러운 재질(공유 재질의 복제)
static func soft_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = CharacterRig.character_material().duplicate()
	m.rim = 0.12
	m.rim_tint = 0.4
	m.metallic_specular = 0.25
	m.roughness = 0.72
	return m


static func _rebuild(rig: CharacterRig, how: String) -> void:
	var mesh: ArrayMesh = rig.body.mesh
	var arr := mesh.surface_get_arrays(0)
	var mat: Material = mesh.surface_get_material(0)
	match how:
		"gray":
			mat = gray_material()
		"soft":
			mat = soft_material()
		"weld":
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var acc := {}
			for i in verts.size():
				var k := Vector3i((verts[i] * 1000.0).round())
				acc[k] = acc.get(k, Vector3.ZERO) + norms[i]
			var out_n := PackedVector3Array()
			out_n.resize(verts.size())
			var welded := 0
			for i in verts.size():
				var sn: Vector3 = acc[Vector3i((verts[i] * 1000.0).round())]
				if sn.length() > 0.0001 and not sn.normalized().is_equal_approx(norms[i]):
					welded += 1
				out_n[i] = sn.normalized() if sn.length() > 0.0001 else norms[i]
			arr[Mesh.ARRAY_NORMAL] = out_n
			print("weld: 법선이 바뀐 정점 %d / %d" % [welded, verts.size()])
	var m2 := ArrayMesh.new()
	m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m2.surface_set_material(0, mat)
	rig.body.mesh = m2


## 카메라: target 을 바라보며 yaw(0 = 정면 -Z 에서 봄), 고도 elev 도, 직교 크기 size
func _aim(target: Vector3, yaw_deg: float, elev_deg: float, size: float) -> void:
	var y := deg_to_rad(yaw_deg)
	var el := deg_to_rad(elev_deg)
	var dir := Vector3(-sin(y) * cos(el), sin(el), -cos(y) * cos(el))
	_cam.size = size
	_cam.look_at_from_position(target + dir * 20.0, target, Vector3.UP)


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _capture(rig: CharacterRig, vname: String) -> void:
	rig.position = Vector3.ZERO
	_world.add_child(rig)
	rig.pose_idle(0.0)
	rig.update_blink(2.0)
	rig.set_expression("normal")
	var top: float = rig.hp_bar_y()
	var cy := top * 0.5
	var size := maxf(top * 1.35, 0.9)
	var st := rig.stats()
	print("%s: 삼각형 %d, 그리기 호출 %d, 뼈 %d, HEIGHT %.3f" % [vname, st.triangles, st.draw_calls, st.bones, rig.HEIGHT])
	var vl := views.split(",")
	for view in [["front", 0.0], ["three", 35.0], ["side", 90.0], ["back", 180.0]]:
		if not vl.has(view[0]):
			continue
		_aim(Vector3(0, cy, 0), view[1], 8.0, size)
		await _shot("%s-%s" % [vname, view[0]])
	if vl.has("face"):
		var head_y: float = rig.joint_global_position("Head").y
		_aim(Vector3(0, head_y + 0.03, 0), 0.0, 6.0, 0.5)
		await _shot("%s-face" % vname)
		_aim(Vector3(0, head_y + 0.03, 0), 35.0, 6.0, 0.5)
		await _shot("%s-face-three" % vname)
	if vl.has("ingame"):
		# 실제 게임 카메라 규칙: 직교, 방위 30°·고도 50°, 1280×720 에서 size 14.6 → 1 단위 ≈ 49px. 이 뷰포트에서 같은 픽셀 크기가 되도록 size 를 맞춘다
		var vp := root.get_visible_rect().size
		rig.pose_walk(0.3)
		_aim(Vector3(0, 0.3, 0), 30.0, 50.0, 14.6 * vp.y / 720.0)
		await _shot("%s-ingame" % vname)
		rig.pose_idle(0.0)
	if vl.has("poses"):
		for pose in ["idle", "walk", "cheer", "scare"]:
			rig.set_expression("normal")
			match pose:
				"idle":
					rig.pose_idle(1.3)
					rig.update_secondary(1.0 / 30.0, 0.0)
				"walk":
					rig.pose_walk(0.3)
					for i in 20:
						rig.update_secondary(1.0 / 30.0, 1.0)
				"cheer":
					rig.pose_cheer(0.25)
				"scare":
					rig.pose_scare(0.3)
			rig.update_blink(2.0)
			_aim(Vector3(0, cy, 0), -40.0, 12.0, size)
			await _shot("%s-pose-%s" % [vname, pose])
		rig.pose_idle(0.0)
	if vl.has("faces"):
		var head_y: float = rig.joint_global_position("Head").y
		for e in ["normal", "happy", "angry", "hurt", "ko"]:
			rig.set_expression(e)
			rig.update_blink(2.0)
			_aim(Vector3(0, head_y + 0.03, 0), 0.0, 6.0, 0.5)
			await _shot("%s-expr-%s" % [vname, e])
		rig.set_expression("normal")
	_world.remove_child(rig)
