class_name CharacterRig
extends Node3D
## 관절형 캐릭터(고블린 일꾼·인간 기사·보스 용사/기사단장).
## 기준점 = 두 발 사이 지면, 정면 = -Z, 캐릭터 자신의 오른손 = +X.
## 몸 전체가 하나의 스킨 메시(정점 색 + MeshBatch 공용 재질)이고 Skeleton3D 뼈로 움직인다.
## 각 정점은 뼈 하나에 100% 묶인다(강체 스킨) → 캐릭터당 그리기 호출 1개(그림자 패스 제외).
## 표정·눈 깜빡임은 얼굴 전용 작은 뼈의 크기·회전으로 바꾼다(숨길 입 모양은 크기 0).
## 자세 함수는 위상/시간만으로 정해진다(난수 없음). 개체 차이는 seed_id(변형·id)로만 생긴다.
## 무기는 손 뼈에 묶인다: 검·망치 = HandR(+X), 방패 = HandL(-X).

const HAMMER_RATE := 1.34      ## 초당 망치질 횟수(내려치는 순간 = 위상 0)
const WALK_RATE := 1.25        ## 초당 걸음 주기(왼발·오른발 한 번씩)

const MAIN_BONES := ["Root", "Pelvis", "Spine", "Neck", "Head",
	"ArmL", "ForearmL", "HandL", "ArmR", "ForearmR", "HandR",
	"LegL", "ShinL", "FootL", "LegR", "ShinR", "FootR"]
const FACE_BONES := ["EyeL", "EyeR", "LidL", "LidR", "BrowL", "BrowR", "PupilL", "PupilR", "MouthN", "MouthA", "MouthH"]
const SECONDARY_BONES := ["Cape", "Plume", "EarL", "EarR"]
const REQUIRED_JOINTS := ["Head", "Neck", "Spine", "Pelvis", "ArmL", "ArmR", "ForearmL", "ForearmR",
	"HandL", "HandR", "LegL", "LegR", "ShinL", "ShinR", "FootL", "FootR"]

## 표정: lid = 윗눈꺼풀 내림(0~1), tilt = 눈꺼풀 기울기, brow = 눈썹 기울기(+ = 안쪽 내림), dy = 눈썹 높이(눈 크기 배수)
const EXPR := {
	"normal": {eye = 1.0, lid = 0.12, tilt = 0.0, brow = 0.0, dy = 0.0, pupil = 1.0, mouth = "MouthN"},
	"angry": {eye = 1.0, lid = 0.42, tilt = 0.35, brow = 0.5, dy = -0.35, pupil = 0.85, mouth = "MouthA"},
	"hurt": {eye = 1.0, lid = 0.55, tilt = -0.25, brow = -0.45, dy = 0.3, pupil = 0.65, mouth = "MouthH"},
	"ko": {eye = 0.0, lid = 0.0, tilt = 0.0, brow = -0.3, dy = 0.1, pupil = 1.0, mouth = "MouthH"},
	"fierce": {eye = 1.0, lid = 0.3, tilt = 0.25, brow = 0.38, dy = -0.25, pupil = 0.9, mouth = "MouthN"},
	"happy": {eye = 0.06, lid = 0.0, tilt = -0.15, brow = -0.25, dy = 0.25, pupil = 1.05, mouth = "MouthA"},   # 눈을 감은 웃음: 눈알을 눌러 감은 눈 선(아래로 볼록한 곡선)이 보인다
}


var HEIGHT := 1.0              ## 머리(투구) 꼭대기 높이(장식 깃털·머리카락 제외), 월드 단위
var kind := "goblin"
var variant := 0
var seed_id := 0
var expression := "normal"
var skeleton: Skeleton3D
var body: MeshInstance3D

var _def: Dictionary = {}
var _bi: Dictionary = {}       # 뼈 이름 -> 번호
var _rest: Array[Vector3] = []
var _rot: Array[Vector3] = []  # 기본 자세 회전(오일러 YXZ)
var _add: Array[Vector3] = []  # 덧씌우는 자세(맞음)
var _off: Array[Vector3] = []  # 위치 이동
var _main: Array[int] = []
var _blink := 0.0
var _sec_t := 0.0
var _spring: Dictionary = {}
var _prev_pelvis_y := 0.0
var _pelvis_vy := 0.0

static var _defs: Dictionary = {}
static var _outline_mat: ShaderMaterial = null

## 만화풍 외곽선 두께(월드 단위). 0 이면 외곽선 없음
const OUTLINE_WIDTH := 0.011


## 뒤집은 껍데기 외곽선: 법선 방향으로 부풀린 면의 뒷면만 짙은 갈색으로 그린다(스키닝 뒤 정점 기준)
static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
uniform vec4 line_color : source_color = vec4(0.17, 0.09, 0.05, 1.0);
uniform float width = 0.011;
void vertex() { VERTEX += NORMAL * width * COLOR.a; }
void fragment() { ALBEDO = line_color.rgb; }
"""
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = sh
		_outline_mat.set_shader_parameter("width", OUTLINE_WIDTH)
	return _outline_mat


static var _char_mat: StandardMaterial3D = null

## 캐릭터 공용 재질(정점 색 = 바탕색). 모든 빌더가 이 재질을 쓴다.
## 건물보다 부드럽고 살짝 윤이 나는 장난감 질감: 감싸는 확산광(그늘이 부드럽게), 약한 반사광, 가장자리 림 라이트.
static func character_material() -> Material:
	if _char_mat == null:
		_char_mat = StandardMaterial3D.new()
		_char_mat.vertex_color_use_as_albedo = true
		_char_mat.vertex_color_is_srgb = true
		_char_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		_char_mat.roughness = 0.62
		_char_mat.metallic = 0.0
		_char_mat.metallic_specular = 0.42
		_char_mat.rim_enabled = true
		_char_mat.rim = 0.3
		_char_mat.rim_tint = 0.55
	return _char_mat


# ================================================================== 만들기

## 모델 세트: "v5" = 5차 모델(기본, 게임이 쓰는 것), "v6" = 6차 교체 후보(조각 구·회전체·이어진 관, scripts/world/chars/*_v6_builder.gd).
## 테스트 씬·디버그 시나리오가 바꿔 끼워 비교한다. 본 게임 기본값은 승인 전까지 "v5".
static var model_set := "v5"


static func _v6() -> bool:
	return model_set == "v6"


static func goblin(v: int = 0, with_hammer: bool = true) -> CharacterRig:
	var vv := posmod(v, 3)
	var key := "%s:goblin:%d:%s" % [model_set, vv, with_hammer]
	if not _defs.has(key):
		_defs[key] = GoblinV6Builder.build(vv, with_hammer) if _v6() else GoblinBuilder.build(vv, with_hammer)
	return _instance(_defs[key], "goblin", vv, 1.0)


static func knight(v: int = 0) -> CharacterRig:
	var vv := posmod(v, 5)
	var key := "%s:knight:%d" % [model_set, vv]
	if not _defs.has(key):
		_defs[key] = KnightV6Builder.build(vv) if _v6() else KnightBuilder.build(vv)
	return _instance(_defs[key], "knight", vv, float(KnightBuilder.SCALE[vv]))


## kind: "hero"(용사) 또는 "commander"(기사단장)
static func boss(k: String) -> CharacterRig:
	var kk := "commander" if k == "commander" else "hero"
	var key := "%s:boss:%s" % [model_set, kk]
	if not _defs.has(key):
		_defs[key] = BossV6Builder.build(kk) if _v6() else BossBuilder.build(kk)
	return _instance(_defs[key], kk, 0, 1.0)


## 꼬마 오크(4차 유닛): 고블린 골격을 키우고 올리브색 피부·엄니·몽둥이
static func orc() -> CharacterRig:
	var key := model_set + ":orc"
	if not _defs.has(key):
		_defs[key] = OrcV6Builder.build() if _v6() else OrcBuilder.build()
	return _instance(_defs[key], "orc", 0, 1.3)


## 해골 궁수(4차 유닛): 뼈 색 몸, 검은 철모, 붉게 빛나는 눈, 활
static func skeleton_archer() -> CharacterRig:
	var key := model_set + ":skeleton"
	if not _defs.has(key):
		_defs[key] = SkeletonV6Builder.build() if _v6() else SkeletonBuilder.build()
	return _instance(_defs[key], "skeleton", 0, 0.95)


## 뿔이(어린 마왕, 주인공): level = 성 레벨 1~4. 뿔·망토·장식이 성과 함께 자란다.
static func imp(level: int = 1) -> CharacterRig:
	var lv := clampi(level, 1, 4)
	var key := "%s:imp:%d" % [model_set, lv]
	if not _defs.has(key):
		# v6 는 아직 Lv.1(악마형 마왕)만 있다. Lv.2~4 는 5차 모델을 그대로 쓴다
		_defs[key] = DemonLv1Builder.build() if (_v6() and lv == 1) else ImpBuilder.build(lv)
	return _instance(_defs[key], "imp", lv, 1.0)


static func _instance(def: Dictionary, p_kind: String, v: int, scl: float) -> CharacterRig:
	var r := CharacterRig.new()
	r.name = {"goblin": "Goblin", "knight": "Knight", "hero": "Hero", "commander": "Commander", "imp": "Imp",
		"orc": "Orc", "skeleton": "Skeleton"}.get(p_kind, "Character")
	r.kind = p_kind
	r.variant = v
	r.seed_id = v * 7 + 3
	r._setup(def, scl)
	return r


func _setup(def: Dictionary, scl: float) -> void:
	_def = def
	HEIGHT = float(def.top) * scl
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	skeleton.scale = Vector3.ONE * scl
	var names: PackedStringArray = def.names
	var parents: PackedInt32Array = def.parents
	var pos: PackedVector3Array = def.pos
	for i in names.size():
		skeleton.add_bone(names[i])
		_bi[names[i]] = i
	for i in names.size():
		var local := pos[i]
		if parents[i] >= 0:
			skeleton.set_bone_parent(i, parents[i])
			local = pos[i] - pos[parents[i]]
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
		_rest.append(local)
		_rot.append(Vector3.ZERO)
		_add.append(Vector3.ZERO)
		_off.append(Vector3.ZERO)
	skeleton.reset_bone_poses()
	for n in MAIN_BONES:
		_main.append(int(_bi[n]))
	add_child(skeleton)
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = def.mesh
	body.skin = def.skin
	var h: float = def.all_top
	# 자세(쓰러짐·팔 들기)로 원래 경계를 벗어나도 잘리지 않게 넉넉한 경계 상자
	body.custom_aabb = AABB(Vector3(-h, -0.3, -h), Vector3(h * 2.0, h * 1.6, h * 2.0))
	if OUTLINE_WIDTH > 0.0:
		body.set_meta("outline", outline_material())
		if MeshBatch.outlines_on:
			body.material_overlay = outline_material()
	skeleton.add_child(body)
	set_expression("normal")
	pose_idle(0.0)


# ================================================================== 공개 API

func hp_bar_y() -> float:
	return (float(_def.all_top) + 0.12) * skeleton.scale.y


func stats() -> Dictionary:
	return {triangles = int(_def.tris), draw_calls = body.mesh.get_surface_count(), bones = skeleton.get_bone_count()}


func has_joint(jname: String) -> bool:
	return _bi.has(jname)


## 관절 노드(BoneAttachment3D, 처음 요청할 때 만든다). 없는 이름이면 null.
func joint(jname: String) -> Node3D:
	if skeleton.has_node(jname):
		return skeleton.get_node(jname)
	if not _bi.has(jname):
		return null
	var ba := BoneAttachment3D.new()
	ba.name = jname
	ba.bone_name = jname
	skeleton.add_child(ba)
	return ba


## 뼈의 현재 자세 기준 월드 위치(렌더링 없이도 계산된다)
func joint_global_position(jname: String) -> Vector3:
	if not _bi.has(jname):
		return Vector3.ZERO
	return _skel_to_world() * skeleton.get_bone_global_pose(int(_bi[jname])).origin


## 검 끝 / 망치 머리(무기가 없으면 오른손)
func weapon_tip_global_position() -> Vector3:
	var hb := int(_bi["HandR"])
	var local: Vector3 = (def_vec("tip")) - (_def.pos as PackedVector3Array)[hb]
	return _skel_to_world() * (skeleton.get_bone_global_pose(hb) * local)


func def_vec(key: String) -> Vector3:
	return _def.get(key, Vector3.ZERO)


## CPU 로 계산한 현재 자세의 모든 정점(이 노드 기준 좌표). 검사용.
func posed_vertices() -> PackedVector3Array:
	var verts: PackedVector3Array = _def.verts
	var vb: PackedInt32Array = _def.vbones
	var pos: PackedVector3Array = _def.pos
	var poses: Array[Transform3D] = []
	for i in pos.size():
		poses.append(skeleton.get_bone_global_pose(i))
	var out := PackedVector3Array()
	out.resize(verts.size())
	var st := skeleton.transform
	for i in verts.size():
		var b := vb[i]
		out[i] = st * (poses[b] * (verts[i] - pos[b]))
	return out


func set_expression(e: String) -> void:
	expression = e if EXPR.has(e) else "normal"
	_apply_face()


## 눈 깜빡임(개체마다 다른 주기, 시간만으로 결정)
func update_blink(time: float) -> void:
	var period := 3.1 + float(seed_id % 5) * 0.37
	var ph := fposmod(time + float(seed_id) * 1.31, period)
	var b := 0.0
	if ph < 0.15:
		b = sin(ph / 0.15 * PI)
	elif seed_id % 2 == 0 and ph > 0.32 and ph < 0.44:
		b = sin((ph - 0.32) / 0.12 * PI)    # 가끔 두 번 깜빡
	if absf(b - _blink) > 0.001:
		_blink = b
		_apply_face()


## 걸음 위상 변화를 감지하는 도우미: 위상 p 가 0(내려치는 순간)을 지났는가
static func crossed_impact(prev_p: float, p: float) -> bool:
	return fposmod(p, 1.0) < fposmod(prev_p, 1.0)


## 시간 time 까지 내려친 횟수(망치 rate 기준). 이 값이 바뀌면 소리를 낸다.
static func impact_index(time: float, rate: float = HAMMER_RATE) -> int:
	return int(floor(time * rate))


# ================================================================== 자세

## 숨쉬기 + 가끔 고개 돌리기
func pose_idle(t: float) -> void:
	_begin()
	var br := sin(t * 2.2)
	var h := _h()
	_r("Spine", Vector3(-0.03 + br * 0.015, 0, 0))
	_o("Pelvis", Vector3(0, br * 0.004 * h, 0))
	var arm_x := 0.06 + br * 0.02
	_r("ArmL", Vector3(arm_x, 0, -0.1))
	_r("ArmR", Vector3(arm_x, 0, 0.1))
	if kind == "goblin":
		_r("ForearmL", Vector3(0.25, 0, 0))
		_r("ForearmR", Vector3(0.3, 0, 0))
	else:
		_r("ForearmL", Vector3(0.75, 0, 0))
		_r("ForearmR", Vector3(0.7, 0, 0))
	# 5초마다 정해진(seed) 방향으로 잠시 고개를 돌린다
	var win := 5.0
	var k := int(floor((t + float(seed_id) * 0.7) / win))
	var ph := fposmod(t + float(seed_id) * 0.7, win) / win
	var dir := float(absi(k * 7919 + seed_id * 104729) % 3 - 1)
	var bump := sin(clampf((ph - 0.45) / 0.5, 0.0, 1.0) * PI)
	_r("Head", Vector3(-br * 0.01, dir * 0.55 * bump, dir * 0.06 * bump))
	_legs(0.0, -0.04, 0.0, -0.04)
	_flush()


## 걷기: phase 1 = 한 주기(두 걸음). 무릎 굽힘·발 디딤·팔꿈치 굽힌 반대 팔 흔들기·몸 위아래·앞으로 기울기
func pose_walk(phase: float, lean: float = 1.0) -> void:
	_begin()
	var a := TAU * fposmod(phase, 1.0)
	var s := sin(a)
	var c := cos(a)
	var sw := 0.5
	var tl := s * sw
	var tr := -s * sw
	var kl := -(0.12 + 0.95 * maxf(0.0, c))
	var kr := -(0.12 + 0.95 * maxf(0.0, -c))
	_legs(tl, kl, tr, kr, 0.0, 0.3 * maxf(0.0, c), 0.3 * maxf(0.0, -c))
	_r("Pelvis", Vector3(0, -s * 0.08, 0))
	_r("Spine", Vector3(-0.12 * lean - 0.03 * absf(c), s * 0.14, 0))
	_r("Neck", Vector3(0.05 * lean, 0, 0))
	_r("Head", Vector3(0.03 * cos(2.0 * a), -s * 0.06, 0))
	if kind == "goblin":
		_r("ArmL", Vector3(-s * 0.55, 0, -0.12))
		_r("ArmR", Vector3(s * 0.45, 0, 0.12))
		_r("ForearmL", Vector3(0.55 + 0.35 * maxf(0.0, -s), 0, 0))
		_r("ForearmR", Vector3(1.0 + 0.3 * maxf(0.0, s), 0, 0))
	elif kind == "imp":
		# 뿔이: 빈손이라 두 팔을 번갈아 자연스럽게 흔든다(짧은 팔, 앞으로 나올 때 팔꿈치를 더 굽힘)
		_r("ArmL", Vector3(-s * 0.6, 0, -0.2))
		_r("ArmR", Vector3(s * 0.6, 0, 0.2))
		_r("ForearmL", Vector3(0.45 + 0.4 * maxf(0.0, -s), 0, 0))
		_r("ForearmR", Vector3(0.45 + 0.4 * maxf(0.0, s), 0, 0))
	else:
		# 방패 팔(왼쪽)은 작게, 검 팔(오른쪽)은 크게 흔든다
		_r("ArmL", Vector3(0.12 - s * 0.15, 0, -0.12))
		_r("ForearmL", Vector3(0.95, 0, 0))
		_r("ArmR", Vector3(0.1 + s * 0.45, 0, 0.12))
		_r("ForearmR", Vector3(0.9 + 0.3 * maxf(0.0, s), 0, 0))
	_flush()


## 기사 공격(주기 함수). p = 1 - attack_timer/interval. p = 0(≡1) 이 내려친 순간(검이 가장 낮음 = 성 피해).
## [0, 0.25) 회복, [0.25, 0.8) 들어 올리기, [0.8, 1) 빠르게 내려치기.
func pose_attack(p: float) -> void:
	# 순서: spine_x, spine_y, armR_x, armR_z, foreR, handR, armL_x, armL_z, foreL, legL, shinL, legR, shinR, head_x, pelvis_z
	var impact := [-0.32, 0.25, 1.35, 0.05, 0.08, -0.25, -0.15, -0.15, 0.95, 0.35, -0.3, -0.2, -0.12, 0.18, -0.03]
	var guard := [-0.05, 0.0, 0.35, 0.15, 1.0, 0.1, 0.1, -0.12, 1.0, 0.15, -0.15, -0.1, -0.1, 0.0, 0.0]
	var raised := [0.14, -0.22, 2.75, 0.25, 0.9, 0.35, 0.35, -0.2, 0.9, 0.22, -0.28, -0.14, -0.16, 0.12, 0.02]
	var k := _cycle(fposmod(p, 1.0), impact, guard, raised, 0.25, 0.8)
	_begin()
	_r("Spine", Vector3(k[0], k[1], 0))
	_r("ArmR", Vector3(k[2], 0, k[3]))
	_r("ForearmR", Vector3(k[4], 0, 0))
	_r("HandR", Vector3(k[5], 0, 0))
	_r("ArmL", Vector3(k[6], 0, k[7]))
	_r("ForearmL", Vector3(k[8], 0, 0))
	_r("Head", Vector3(k[13], -k[1] * 0.5, 0))
	_legs(k[9], k[10], k[11], k[12], k[14] * _h())
	_flush()


## 고블린 망치질(주기 함수). p = 0(≡1) 이 내려친 순간(망치 머리가 가장 낮음). 허리를 굽혀 온몸으로 친다.
func pose_hammer(p: float) -> void:
	var impact := [-0.55, 0.15, 1.0, 0.1, 0.35, -0.1, 0.7, -0.15, 0.6, 0.45, -0.6, -0.35, -0.35, 0.3, -0.02]
	var rec := [-0.35, 0.05, 0.9, 0.15, 1.2, 0.2, 0.6, -0.15, 0.7, 0.4, -0.5, -0.3, -0.3, 0.2, 0.0]
	var raised := [-0.05, -0.15, 2.6, 0.2, 1.3, 0.5, 0.5, -0.15, 0.8, 0.35, -0.45, -0.3, -0.3, 0.05, 0.01]
	var k := _cycle(fposmod(p, 1.0), impact, rec, raised, 0.3, 0.85)
	_begin()
	_r("Spine", Vector3(k[0], k[1], 0))
	_r("ArmR", Vector3(k[2], 0, k[3]))
	_r("ForearmR", Vector3(k[4], 0, 0))
	_r("HandR", Vector3(k[5], 0, 0))
	_r("ArmL", Vector3(k[6], 0, k[7]))
	_r("ForearmL", Vector3(k[8], 0, 0))
	_r("Head", Vector3(k[13], -k[1] * 0.4, 0))
	_legs(k[9], k[10], k[11], k[12], k[14] * _h())
	_flush()


## 맞음: 기본 자세 위에 덧씌운다(t 0..1, 살짝 밀렸다가 돌아옴). pose_walk/attack/idle 다음에 부른다.
func pose_hit(t: float) -> void:
	var tt := clampf(t, 0.0, 1.0)
	var amt := 0.0
	if tt < 0.2:
		var u := tt / 0.2
		amt = 1.0 - (1.0 - u) * (1.0 - u)
	else:
		amt = 1.0 - smoothstep(0.0, 1.0, (tt - 0.2) / 0.8)
	for i in _main:
		_add[i] = Vector3.ZERO
	_add[int(_bi["Spine"])] = Vector3(0.38 * amt, 0, 0)
	_add[int(_bi["Head"])] = Vector3(0.3 * amt, 0, 0.1 * amt)
	_add[int(_bi["ArmL"])] = Vector3(0.35 * amt, 0, -0.45 * amt)
	_add[int(_bi["ArmR"])] = Vector3(0.35 * amt, 0, 0.45 * amt)
	var pv := int(_bi["Pelvis"])
	var keep := _off[pv]
	_off[pv] = keep + Vector3(0, -0.02 * amt, 0.07 * amt) * _h()
	_flush()
	_off[pv] = keep


## 쓰러짐: 무릎이 꺾이고 뒤로 넘어진다(t 0..1)
func pose_die(t: float) -> void:
	var tt := clampf(t, 0.0, 1.0)
	var u1 := 1.0 - pow(1.0 - clampf(tt / 0.4, 0.0, 1.0), 2.0)
	var u2 := clampf((tt - 0.3) / 0.7, 0.0, 1.0)
	var fall := u2 * u2
	if u2 > 0.85:
		fall = 1.0 - sin((u2 - 0.85) / 0.15 * PI) * 0.06   # 바닥에 닿고 살짝 튐
	_begin()
	var straight := 1.0 - fall
	_legs(0.9 * u1 * straight + 0.25 * fall, -1.5 * u1 * straight - 0.25 * fall, 0.7 * u1 * straight + 0.1 * fall, -1.3 * u1 * straight - 0.15 * fall)
	_r("Spine", Vector3(-0.35 * u1 * straight + 0.1 * fall, 0, 0.05 * fall))
	_r("Head", Vector3(-0.2 * u1 * straight - 0.25 * fall, 0.9 * fall, 0))
	_r("ArmL", Vector3(0.3 * u1 * straight + 0.1 * fall, 0, -0.2 - 1.0 * fall))
	_r("ArmR", Vector3(0.3 * u1 * straight + 0.1 * fall, 0, 0.2 + 1.0 * fall))
	_r("ForearmL", Vector3(0.4 * straight + 0.2, 0, 0))
	_r("ForearmR", Vector3(0.4 * straight + 0.2, 0, 0))
	_r("HandR", Vector3(-0.9 * fall, 0, 0))
	# 엉덩이 뒤쪽 지면 점을 축으로 뒤로 눕는다. 등 두께만큼 들어 올려 땅에 묻히지 않게 한다.
	var ang := 1.45 * fall
	var rot := Basis.from_euler(Vector3(ang, 0, 0))
	var pivot := Vector3(0, 0, 0.12 * _h())
	_r("Root", Vector3(ang, 0, 0))
	_o("Root", pivot - rot * pivot + Vector3(0, 0.02 * _h() * sin(ang), 0))
	_flush()
	if tt > 0.55:
		set_expression("ko")
	elif expression != "hurt":
		set_expression("hurt")


## 뿔이: 무서운 자세 연습(t 0..1). 0~0.45 팔·망토를 크게 펼쳐 으르렁 → 0.45~1 균형을 잃고 휘청였다가 겨우 선다
func pose_scare(t: float) -> void:
	var tt := clampf(t, 0.0, 1.0)
	var up := smoothstep(0.0, 1.0, clampf(tt / 0.35, 0.0, 1.0))
	var w := clampf((tt - 0.45) / 0.55, 0.0, 1.0)
	var wob := sin(w * PI * 3.0) * (1.0 - w) * 0.28 if tt > 0.45 else 0.0
	var relax := smoothstep(0.0, 1.0, clampf((tt - 0.8) / 0.2, 0.0, 1.0))
	var a := up * (1.0 - relax * 0.6)
	_begin()
	# 두 팔을 양옆·위로 활짝 펼치고 발톱을 세운다(날개·망토는 Cape 뼈가 알아서 흔들린다). 몸은 뒤로 젖히고 다리는 벌린다
	_r("Spine", Vector3(0.18 * a, 0, wob * 0.6))
	_r("Head", Vector3(-0.14 * a, 0, -wob * 0.5))
	_r("ArmL", Vector3(0.7 * a, 0, -0.1 - 1.7 * a))
	_r("ArmR", Vector3(0.7 * a, 0, 0.1 + 1.7 * a))
	_r("ForearmL", Vector3(0.3 + 0.25 * a, 0, 0))
	_r("ForearmR", Vector3(0.3 + 0.25 * a, 0, 0))
	_r("HandL", Vector3(-0.7 * a, 0, 0))    # 손목을 젖혀 발톱이 앞·위를 향하게
	_r("HandR", Vector3(-0.7 * a, 0, 0))
	_legs(0.3 * a - wob * 0.3, -0.4 * a, -0.2 * a + wob * 0.3, -0.12 * a)
	_r("Root", Vector3(0, 0, wob))
	_flush()
	set_expression("angry" if tt < 0.5 else ("hurt" if relax < 0.5 else "happy"))


## 뿔이: 승리 환호(주기, p 0..1 = 점프 한 번). 지팡이를 높이 들고 깡충
func pose_cheer(p: float) -> void:
	var ph := fposmod(p, 1.0)
	var jump := maxf(0.0, sin(ph * TAU)) * 0.11 * _h()
	var crouch := maxf(0.0, -sin(ph * TAU))
	_begin()
	# 두 손을 머리 위로 번쩍 들고 깡충. 웅크릴 때는 팔이 조금 내려오고 뛸 때 쭉 뻗는다
	var lift := 1.0 - crouch * 0.25
	_r("Spine", Vector3(0.12 - crouch * 0.2, 0, 0))
	_r("Head", Vector3(-0.15, 0, 0))
	_r("ArmR", Vector3(2.8 * lift, 0, 0.45))
	_r("ForearmR", Vector3(0.25 + crouch * 0.3, 0, 0))
	_r("HandR", Vector3(-0.5, 0, 0))
	_r("ArmL", Vector3(2.8 * lift, 0, -0.45))
	_r("ForearmL", Vector3(0.25 + crouch * 0.3, 0, 0))
	_r("HandL", Vector3(-0.5, 0, 0))
	_legs(0.5 * crouch + 0.1, -1.0 * crouch - 0.05, 0.5 * crouch + 0.1, -1.0 * crouch - 0.05)
	_o("Root", Vector3(0, jump, 0))
	_flush()
	set_expression("happy")


## 방어탑 조작자: 석궁을 두 손으로 잡고 조준
func pose_crossbow(t: float = 0.0) -> void:
	_begin()
	var br := sin(t * 2.0)
	_r("Spine", Vector3(-0.12 + br * 0.01, 0, 0))
	_r("ArmL", Vector3(1.2, 0, 0.3))
	_r("ArmR", Vector3(1.2, 0, -0.3))
	_r("ForearmL", Vector3(0.35, 0, 0))
	_r("ForearmR", Vector3(0.35, 0, 0))
	_r("Head", Vector3(0.05, 0, 0))
	_legs(0.0, -0.05, 0.0, -0.05, 0.0)
	_flush()


## 2차 움직임: 망토·깃털(기사), 귀(고블린). speed = 이동 속도(0 = 정지, 1 = 보통 걸음)
func update_secondary(delta: float, speed: float) -> void:
	var dt := clampf(delta, 0.0, 0.1)
	_sec_t += dt
	var pv := int(_bi["Pelvis"])
	var py := _off[pv].y
	if dt > 0.0:
		_pelvis_vy = clampf((py - _prev_pelvis_y) / dt, -1.5, 1.5)
	_prev_pelvis_y = py
	var spd := clampf(speed, 0.0, 2.0)
	var sp := int(_bi["Spine"])
	var lean := _rot[sp].x + _add[sp].x
	var sd := float(seed_id)
	if _bi.has("Cape"):
		var tgt := -lean - 0.06 - 0.22 * spd + sin(_sec_t * 7.0 + sd) * 0.05 * (0.4 + spd) + _pelvis_vy * 0.4
		var cx := _spring_step("cape", tgt, dt, 70.0, 7.0)
		var cz := sin(_sec_t * 3.3 + sd) * 0.04 * (0.3 + spd)
		skeleton.set_bone_pose_rotation(int(_bi["Cape"]), Quaternion.from_euler(Vector3(cx, 0, cz)))
	if _bi.has("Plume"):
		var tgt := 0.25 * spd + sin(_sec_t * 5.3 + sd) * 0.06 * (0.5 + spd) - _pelvis_vy * 0.8
		var px := _spring_step("plume", tgt, dt, 110.0, 8.0)
		var pz := sin(_sec_t * 2.9 + sd * 0.5) * 0.05 * (0.4 + spd)
		skeleton.set_bone_pose_rotation(int(_bi["Plume"]), Quaternion.from_euler(Vector3(px, 0, pz)))
	if _bi.has("EarL"):
		var flap_t := 0.05 * sin(_sec_t * 1.7 + sd) - _pelvis_vy * 1.4 + sin(_sec_t * 9.0 + sd) * 0.08 * spd
		var flap := _spring_step("ear", flap_t, dt, 140.0, 6.0)
		var sweep := _spring_step("ear_back", 0.35 * spd, dt, 60.0, 9.0)
		skeleton.set_bone_pose_rotation(int(_bi["EarR"]), Quaternion.from_euler(Vector3(0, -sweep, flap)))
		skeleton.set_bone_pose_rotation(int(_bi["EarL"]), Quaternion.from_euler(Vector3(0, sweep, -flap)))


# ================================================================== 자세 내부

func _h() -> float:
	return float(_def.H)


func _begin() -> void:
	for i in _main:
		_rot[i] = Vector3.ZERO
		_add[i] = Vector3.ZERO
		_off[i] = Vector3.ZERO


func _r(n: String, e: Vector3) -> void:
	_rot[int(_bi[n])] = e


func _o(n: String, p: Vector3) -> void:
	_off[int(_bi[n])] = p


func _flush() -> void:
	for i in _main:
		skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(_rot[i] + _add[i]))
		skeleton.set_bone_pose_position(i, _rest[i] + _off[i])


## 다리 자세 + 발 디딤: 낮은 발이 지면에 닿도록 골반 높이를 계산하고 발바닥은 수평으로 둔다.
## thigh = 허벅지 앞으로(+), shin = 무릎 굽힘(-), pelvis_z = 골반 앞뒤 이동, toe = 발끝 들기
func _legs(tl: float, kl: float, tr: float, kr: float, pelvis_z: float = 0.0, toe_l: float = 0.0, toe_r: float = 0.0) -> void:
	var l1: float = _def.thigh
	var l2: float = _def.shin
	_r("LegL", Vector3(tl, 0, -0.03))
	_r("ShinL", Vector3(kl, 0, 0))
	_r("FootL", Vector3(-(tl + kl) + toe_l, 0, 0.03))
	_r("LegR", Vector3(tr, 0, 0.03))
	_r("ShinR", Vector3(kr, 0, 0))
	_r("FootR", Vector3(-(tr + kr) + toe_r, 0, -0.03))
	var yl := -cos(tl) * l1 - cos(tl + kl) * l2
	var yr := -cos(tr) * l1 - cos(tr + kr) * l2
	var low := minf(yl, yr)
	var pv := int(_bi["Pelvis"])
	_off[pv] = _off[pv] + Vector3(0, -(l1 + l2) - low, pelvis_z)


## 세 기준 자세 사이 주기 보간: [0,a) 충격→회복(감속), [a,b) 회복→들기(부드럽게), [b,1) 들기→충격(가속)
func _cycle(p: float, impact: Array, mid: Array, raised: Array, a: float, b: float) -> Array:
	var from: Array
	var to: Array
	var e := 0.0
	if p < a:
		var u := p / a
		e = 1.0 - (1.0 - u) * (1.0 - u)
		from = impact
		to = mid
	elif p < b:
		e = smoothstep(0.0, 1.0, (p - a) / (b - a))
		from = mid
		to = raised
	else:
		var u := (p - b) / (1.0 - b)
		e = u * u * u
		from = raised
		to = impact
	var out: Array = []
	for i in from.size():
		out.append(lerpf(float(from[i]), float(to[i]), e))
	return out


func _spring_step(key: String, target: float, dt: float, k: float, c: float) -> float:
	var s: Vector2 = _spring.get(key, Vector2(target, 0.0))
	var steps := maxi(1, int(ceil(dt / 0.02)))
	var h := dt / float(steps)
	for i in steps:
		var acc := k * (target - s.x) - c * s.y
		s.y += acc * h
		s.x += s.y * h
	_spring[key] = s
	return s.x


func _apply_face() -> void:
	if skeleton == null:
		return
	var e: Dictionary = EXPR[expression]
	var es: float = _def.es
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		# 감은 눈: 눈알 뼈를 납작하게 눌러 뒤쪽의 속눈썹 선(◡)이 드러나게 한다
		var sq := maxf(float(e.eye) * (1.0 - _blink * 0.95), 0.05)
		skeleton.set_bone_pose_scale(int(_bi["Eye" + sfx]), Vector3(1.0, sq, maxf(sq, 0.2)))
		var lid := float(e.lid) * (1.0 - _blink)
		var tilt := float(e.tilt) * side
		var li := int(_bi["Lid" + sfx])
		skeleton.set_bone_pose_rotation(li, Quaternion.from_euler(Vector3(0, 0, tilt)))
		skeleton.set_bone_pose_scale(li, Vector3(1.0, maxf(lid, 0.001), 1.0))
		var bi := int(_bi["Brow" + sfx])
		skeleton.set_bone_pose_rotation(bi, Quaternion.from_euler(Vector3(0, 0, float(e.brow) * side)))
		skeleton.set_bone_pose_position(bi, _rest[bi] + Vector3(0, float(e.dy) * es, 0))
		skeleton.set_bone_pose_scale(int(_bi["Pupil" + sfx]), Vector3.ONE * float(e.pupil))
	for m in ["MouthN", "MouthA", "MouthH"]:
		skeleton.set_bone_pose_scale(int(_bi[m]), Vector3.ONE if m == e.mouth else Vector3.ONE * 0.001)


func _skel_to_world() -> Transform3D:
	if skeleton.is_inside_tree():
		return skeleton.global_transform
	return transform * skeleton.transform
