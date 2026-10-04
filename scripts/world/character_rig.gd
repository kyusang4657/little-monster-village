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
	"happy": {eye = 0.85, lid = 0.3, tilt = -0.15, brow = -0.25, dy = 0.25, pupil = 1.05, mouth = "MouthA"},
}

## 기사 변형 5종: 키 배율(±5%), 깃털 색, 방패 무늬, 투구 모양, 피부색
const KNIGHT_SCALE := [1.0, 1.05, 0.95, 1.03, 0.97]
const KNIGHT_PLUME := ["d8333a", "f4efe4", "e8742e", "3b6fd4", "c8343a"]
const KNIGHT_SHIELD := ["plain", "cross", "band", "ring", "stripes"]
const KNIGHT_HELMET := ["round", "pointed", "crest", "visor", "brim"]
const KNIGHT_SKIN := ["f2c9a0", "e6b088", "f6d6b8", "d9a27a", "efc29a"]

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


# ================================================================== 만들기

static func goblin(v: int = 0, with_hammer: bool = true) -> CharacterRig:
	var vv := posmod(v, 3)
	var key := "goblin:%d:%s" % [vv, with_hammer]
	if not _defs.has(key):
		_defs[key] = _build_goblin(vv, with_hammer)
	return _instance(_defs[key], "goblin", vv, 1.0)


static func knight(v: int = 0) -> CharacterRig:
	var vv := posmod(v, 5)
	var key := "knight:%d" % vv
	if not _defs.has(key):
		_defs[key] = _build_human(_knight_spec(vv))
	return _instance(_defs[key], "knight", vv, float(KNIGHT_SCALE[vv]))


## kind: "hero"(용사) 또는 "commander"(기사단장)
static func boss(k: String) -> CharacterRig:
	var kk := "commander" if k == "commander" else "hero"
	var key := "boss:" + kk
	if not _defs.has(key):
		_defs[key] = _build_human(_boss_spec(kk))
	return _instance(_defs[key], kk, 0, 1.0)


## 뿔이(어린 마왕, 주인공): level = 성 레벨 1~4. 뿔·망토·장식이 성과 함께 자란다.
static func imp(level: int = 1) -> CharacterRig:
	var lv := clampi(level, 1, 4)
	var key := "imp:%d" % lv
	if not _defs.has(key):
		_defs[key] = _build_imp(lv)
	return _instance(_defs[key], "imp", lv, 1.0)


static func _instance(def: Dictionary, p_kind: String, v: int, scl: float) -> CharacterRig:
	var r := CharacterRig.new()
	r.name = {"goblin": "Goblin", "knight": "Knight", "hero": "Hero", "commander": "Commander", "imp": "Imp"}.get(p_kind, "Character")
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
		# 지팡이 팔은 거의 고정(지팡이를 짚듯 곧게), 빈 팔만 크게 흔든다
		_r("ArmL", Vector3(-s * 0.6, 0, -0.15))
		_r("ForearmL", Vector3(0.45 + 0.35 * maxf(0.0, -s), 0, 0))
		_r("ArmR", Vector3(0.05 + s * 0.12, 0, 0.12))
		_r("ForearmR", Vector3(0.75, 0, 0))
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
	_r("Spine", Vector3(0.16 * a, 0, wob * 0.6))
	_r("Head", Vector3(-0.12 * a, 0, -wob * 0.5))
	_r("ArmL", Vector3(1.6 * a, 0, -0.1 - 1.0 * a))
	_r("ArmR", Vector3(2.4 * a, 0, 0.1 + 0.45 * a))
	_r("ForearmL", Vector3(0.3 + 0.5 * a, 0, 0))
	_r("ForearmR", Vector3(0.75 - 0.35 * a, 0, 0))
	_r("HandR", Vector3(-2.1 * a, 0, 0))    # 팔을 들어도 지팡이 보석이 위를 향하게
	_r("HandL", Vector3(-0.6 * a, 0, 0))
	_legs(0.25 * a - wob * 0.3, -0.35 * a, -0.15 * a + wob * 0.3, -0.1 * a)
	_r("Root", Vector3(0, 0, wob))
	_flush()
	set_expression("angry" if tt < 0.5 else ("hurt" if relax < 0.5 else "happy"))


## 뿔이: 승리 환호(주기, p 0..1 = 점프 한 번). 지팡이를 높이 들고 깡충
func pose_cheer(p: float) -> void:
	var ph := fposmod(p, 1.0)
	var jump := maxf(0.0, sin(ph * TAU)) * 0.11 * _h()
	var crouch := maxf(0.0, -sin(ph * TAU))
	_begin()
	_r("Spine", Vector3(0.12 - crouch * 0.2, 0, 0))
	_r("Head", Vector3(-0.15, 0, 0))
	_r("ArmR", Vector3(2.9, 0, 0.25))
	_r("ForearmR", Vector3(0.2, 0, 0))
	_r("HandR", Vector3(-2.35, 0, 0))
	_r("ArmL", Vector3(2.5 - crouch * 0.6, 0, -0.35))
	_r("ForearmL", Vector3(0.9, 0, 0))
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


# ================================================================== 기하 도우미

## 기본 도형을 뼈 번호와 함께 모은다. 모든 좌표는 골격 공간(쉬는 자세)이다.
class Geo:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var vb := PackedInt32Array()
	var idx := PackedInt32Array()
	var names := PackedStringArray()
	var parents := PackedInt32Array()
	var pos := PackedVector3Array()
	var bone := 0
	var measure := true        # HEIGHT(머리 꼭대기)에 넣는가
	var measure_all := true    # 체력 막대 높이에 넣는가(무기 제외)
	var line := 1.0            # 외곽선 두께 배율(정점 색 알파에 저장, 얼굴 부품은 0)
	var top := 0.0
	var all_top := 0.0

	func add_bone(bname: String, parent: String, p: Vector3) -> void:
		names.append(bname)
		parents.append(names.find(parent) if parent != "" else -1)
		pos.append(p)

	func use(bname: String) -> void:
		bone = names.find(bname)
		assert(bone >= 0, "뼈 없음: " + bname)

	func _vert(p: Vector3, nn: Vector3, col: Color) -> void:
		v.append(p)
		var nm := nn.normalized()
		n.append(nm)
		# 칠한 듯한 입체감: 위를 보는 면은 밝게, 아래를 보는 면은 어둡게 정점 색에 미리 넣는다
		var shaded := col.lightened(0.16 * maxf(nm.y, 0.0)).darkened(0.2 * maxf(-nm.y, 0.0))
		shaded.a = line
		c.append(shaded)
		vb.append(bone)
		if measure:
			top = maxf(top, p.y)
		if measure_all:
			all_top = maxf(all_top, p.y)

	## 삼각형(바깥 법선 기준으로 앞면 방향을 자동으로 맞춘다)
	func tri(a: int, b: int, d: int) -> void:
		var cr := (v[b] - v[a]).cross(v[d] - v[a])
		var nn := n[a] + n[b] + n[d]
		idx.append(a)
		if cr.dot(nn) > 0.0:
			idx.append(d)
			idx.append(b)
		else:
			idx.append(b)
			idx.append(d)

	## 타원체(위 극 = basis 의 +Y). lat_front/lat_back 으로 앞·뒤를 다른 깊이까지 자른 덮개도 만든다.
	func ellipsoid(ce: Vector3, r: Vector3, col: Color, segs: int = 10, rings: int = 6, basis: Basis = Basis.IDENTITY,
			lat_front: float = PI, lat_back: float = PI, lat_min: float = 0.0) -> void:
		var base := v.size()
		for i in rings + 1:
			for j in segs + 1:
				var lon := TAU * float(j) / float(segs)
				var fw := (1.0 + cos(lon)) * 0.5
				var lat := lerpf(lat_min, lerpf(lat_back, lat_front, fw), float(i) / float(rings))
				var dir := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
				var nn := Vector3(dir.x / r.x, dir.y / r.y, dir.z / r.z)
				_vert(ce + basis * (dir * r), basis * nn, col)
		var closed_bottom := lat_front >= PI - 0.001 and lat_back >= PI - 0.001
		for i in rings:
			for j in segs:
				var a := base + i * (segs + 1) + j
				var b := a + 1
				var d := a + segs + 1
				var e := d + 1
				if not (i == 0 and lat_min <= 0.0):
					tri(a, b, d)
				if not (i == rings - 1 and closed_bottom):
					tri(b, e, d)

	func sphere(ce: Vector3, r: float, col: Color, segs: int = 8, rings: int = 5) -> void:
		ellipsoid(ce, Vector3(r, r, r), col, segs, rings)

	## 원뿔대(a→b, 반지름 ra→rb). fu/fw = 단면 납작 비율(u 는 ref 쪽 축).
	func tube(a: Vector3, b: Vector3, ra: float, rb: float, col: Color, segs: int = 8, caps: bool = true,
			fu: float = 1.0, fw: float = 1.0, ref_axis: Vector3 = Vector3.RIGHT) -> void:
		var axis := b - a
		var l := axis.length()
		if l < 0.00001:
			return
		var d := axis / l
		var ref := ref_axis
		if absf(d.dot(ref)) > 0.95:
			ref = Vector3.BACK if absf(d.z) < 0.95 else Vector3.UP
		var u := (ref - d * ref.dot(d)).normalized()
		var w := d.cross(u)
		var slope := (ra - rb) / l
		var base := v.size()
		for k in 2:
			var p0 := a if k == 0 else b
			var r := ra if k == 0 else rb
			for j in segs + 1:
				var ang := TAU * float(j) / float(segs)
				var off := u * (cos(ang) * r * fu) + w * (sin(ang) * r * fw)
				var nn := (u * (cos(ang) / fu) + w * (sin(ang) / fw)).normalized() + d * slope
				_vert(p0 + off, nn, col)
		for j in segs:
			var i0 := base + j
			var i2 := base + segs + 1 + j
			tri(i0, i2, i0 + 1)
			tri(i0 + 1, i2, i2 + 1)
		if caps:
			for k in 2:
				var p0 := a if k == 0 else b
				var r := ra if k == 0 else rb
				if r <= 0.0001:
					continue
				var nn := -d if k == 0 else d
				var cb := v.size()
				_vert(p0, nn, col)
				for j in segs:
					var ang := TAU * float(j) / float(segs)
					_vert(p0 + u * (cos(ang) * r * fu) + w * (sin(ang) * r * fw), nn, col)
				for j in segs:
					tri(cb, cb + 1 + j, cb + 1 + (j + 1) % segs)

	## 점들을 잇는 가는 관(눈썹·입·테두리)
	func sweep(pts: Array, r: float, col: Color, segs: int = 5, closed: bool = false) -> void:
		var cnt := pts.size() if closed else pts.size() - 1
		for i in cnt:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % pts.size()]
			var ext := (b - a).normalized() * r * 0.5
			tube(a - ext, b + ext, r, r, col, segs, not closed and (i == 0 or i == cnt - 1))

	## 상자(basis 의 열 = 축 방향)
	func box(ce: Vector3, size: Vector3, col: Color, basis: Basis = Basis.IDENTITY) -> void:
		var axes := [basis.x.normalized(), basis.y.normalized(), basis.z.normalized()]
		for f in 6:
			var ax: int = f >> 1
			var sgn := 1.0 if f % 2 == 0 else -1.0
			var nn: Vector3 = axes[ax] * sgn
			var ua: Vector3 = axes[(ax + 1) % 3]
			var wa: Vector3 = axes[(ax + 2) % 3]
			var hn := size[ax] * 0.5
			var hu := size[(ax + 1) % 3] * 0.5
			var hw := size[(ax + 2) % 3] * 0.5
			var b0 := v.size()
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				_vert(ce + nn * hn + ua * (hu * q.x) + wa * (hw * q.y), nn, col)
			tri(b0, b0 + 1, b0 + 2)
			tri(b0, b0 + 2, b0 + 3)

	func build(material: Material) -> Dictionary:
		var m := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(v.size() * 4)
		weights.resize(v.size() * 4)
		for i in v.size():
			bones[i * 4] = vb[i]
			weights[i * 4] = 1.0
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = weights
		arr[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, material)
		var skin := Skin.new()
		for i in names.size():
			skin.add_bind(i, Transform3D(Basis.IDENTITY, -pos[i]))
		return {mesh = m, skin = skin, names = names, parents = parents, pos = pos, verts = v, vbones = vb,
			top = top, all_top = all_top, tris = int(idx.size() / 3.0)}


# ================================================================== 공통 부품

## 표준 골격(쉬는 자세: 팔은 어깨 아래로 곧게, 다리는 엉덩이 아래로 곧게)
static func _skeleton(g: Geo, P: Dictionary) -> void:
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	g.add_bone("Root", "", Vector3.ZERO)
	g.add_bone("Pelvis", "Root", Vector3(0, P.pelvis, 0))
	g.add_bone("Spine", "Pelvis", Vector3(0, P.spine, 0))
	g.add_bone("Neck", "Spine", Vector3(0, P.neck, 0))
	g.add_bone("Head", "Neck", Vector3(0, P.head, 0))
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.add_bone("Arm" + sfx, "Spine", Vector3(sx * side, P.shoulder, 0))
		g.add_bone("Forearm" + sfx, "Arm" + sfx, Vector3(sx * side, P.elbow, 0))
		g.add_bone("Hand" + sfx, "Forearm" + sfx, Vector3(sx * side, P.wrist, 0))
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.add_bone("Leg" + sfx, "Pelvis", Vector3(hx * side, P.hip, 0))
		g.add_bone("Shin" + sfx, "Leg" + sfx, Vector3(hx * side, P.knee, 0))
		g.add_bone("Foot" + sfx, "Shin" + sfx, Vector3(hx * side, P.ankle, 0))


static func _surf_z(hc: Vector3, hr: Vector3, x: float, y: float) -> float:
	var q := 1.0 - pow((x - hc.x) / hr.x, 2.0) - pow((y - hc.y) / hr.y, 2.0)
	return hc.z - hr.z * sqrt(maxf(0.04, q))


## 얼굴: 흰자+눈동자+반사광, 눈꺼풀(깜빡임/표정), 눈썹, 입 세 가지(보통·화남·아픔), 코, 볼
static func _face(g: Geo, F: Dictionary) -> void:
	# 눈·입 같은 작은 얼굴 부품에는 외곽선을 두르지 않는다(얼굴이 지저분해 보이지 않게)
	var keep_line := g.line
	g.line = 0.0
	_face_parts(g, F)
	g.line = keep_line


static func _face_parts(g: Geo, F: Dictionary) -> void:
	var hc: Vector3 = F.hc
	var hr: Vector3 = F.hr
	var es: float = F.es
	var ey: float = F.eye_y
	var skin: Color = F.skin
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var ex: float = float(F.eye_dx) * side
		var ez := _surf_z(hc, hr, ex, ey)
		# 감은 눈 선(눈알 뒤에 숨어 있다가 눈알을 누르면 보인다)
		g.use("Head")
		var lash: Array = []
		for i in 5:
			var u := float(i) / 2.0 - 1.0
			var lx := ex + u * es * 0.85
			var ly := ey - es * (0.32 - 0.27 * u * u)
			lash.append(Vector3(lx, ly, _surf_z(hc, hr, lx, ly) - es * 0.05))
		g.sweep(lash, es * 0.15, F.pupil, 4)
		g.add_bone("Eye" + sfx, "Head", Vector3(ex, ey - es * 0.2, ez + es * 0.3))
		g.use("Eye" + sfx)
		g.ellipsoid(Vector3(ex, ey, ez + es * 0.3), Vector3(es, es * 1.25, es * 0.6), Color("fbfbf7"), 8, 4)
		g.add_bone("Pupil" + sfx, "Eye" + sfx, Vector3(ex - side * es * 0.12, ey - es * 0.12, ez - es * 0.25))
		g.use("Pupil" + sfx)
		var ir: float = F.get("iris", 1.0)
		g.ellipsoid(Vector3(ex - side * es * 0.12, ey - es * 0.12, ez - es * 0.25), Vector3(es * 0.62 * ir, es * 0.8 * ir, es * 0.3), F.pupil, 8 if ir > 1.0 else 6, 4)
		if F.has("pupil_core"):
			g.ellipsoid(Vector3(ex - side * es * 0.12, ey - es * 0.18, ez - es * 0.38), Vector3(es * 0.24, es * 0.32, es * 0.16), F.pupil_core, 6, 3)
		g.sphere(Vector3(ex - side * es * 0.12 + es * 0.22, ey + es * 0.22, ez - es * 0.52), es * 0.2 * ir, Color.WHITE, 4, 3)
		# 윗눈꺼풀: 아래 반구 덮개. 뼈(눈 위쪽)에서 Y 크기를 키우면 내려와 눈을 덮는다.
		var lid_p := Vector3(ex, ey + es * 1.3, ez + es * 0.1)
		g.add_bone("Lid" + sfx, "Head", lid_p)
		g.use("Lid" + sfx)
		g.ellipsoid(lid_p, Vector3(es * 1.22, es * 2.7, es * 0.88), F.get("lid", skin.darkened(0.06)), 6, 3, Basis(Vector3.BACK, PI), PI * 0.5, PI * 0.5)
		# 눈썹
		var by := ey + es * 2.05
		var bz := _surf_z(hc, hr, ex, by)
		g.add_bone("Brow" + sfx, "Head", Vector3(ex, by, bz))
		g.use("Brow" + sfx)
		var bw := es * 1.05
		g.sweep([Vector3(ex - bw, by - es * 0.12, _surf_z(hc, hr, ex - bw, by) - es * 0.1),
			Vector3(ex, by + es * 0.12, bz - es * 0.12),
			Vector3(ex + bw, by - es * 0.12, _surf_z(hc, hr, ex + bw, by) - es * 0.1)], es * 0.24, F.brow, 4)
	# 입
	var my: float = F.mouth_y
	var mw: float = F.mouth_w
	var mz := _surf_z(hc, hr, 0.0, my)
	var dark := Color("4a1f28")
	g.add_bone("MouthN", "Head", Vector3(0, my, mz))
	g.use("MouthN")
	var pts: Array = []
	for i in 5:
		var u := float(i) / 2.0 - 1.0
		var x := u * mw * 0.5
		var y := my + u * u * mw * 0.28
		pts.append(Vector3(x, y, _surf_z(hc, hr, x, y) - mw * 0.03))
	g.sweep(pts, mw * 0.09, dark, 4)
	g.add_bone("MouthA", "Head", Vector3(0, my, mz))
	g.use("MouthA")
	g.ellipsoid(Vector3(0, my - mw * 0.05, mz + mw * 0.08), Vector3(mw * 0.45, mw * 0.26, mw * 0.2), dark, 8, 4)
	g.ellipsoid(Vector3(0, my + mw * 0.1, mz - mw * 0.03), Vector3(mw * 0.36, mw * 0.07, mw * 0.12), Color.WHITE, 6, 3)
	g.add_bone("MouthH", "Head", Vector3(0, my, mz))
	g.use("MouthH")
	g.ellipsoid(Vector3(0, my - mw * 0.05, mz + mw * 0.05), Vector3(mw * 0.2, mw * 0.24, mw * 0.14), dark, 6, 4)
	g.use("Head")
	# 볼 홍조
	if F.has("blush"):
		for side: float in [-1.0, 1.0]:
			var x: float = float(F.eye_dx) * side * 1.35
			var y := ey - es * 1.6
			g.ellipsoid(Vector3(x, y, _surf_z(hc, hr, x, y) + es * 0.15), Vector3(es * 0.7, es * 0.4, es * 0.3), F.blush, 6, 3)


## 팔(어깨 공·위팔·팔꿈치 공·아래팔·주먹)과 다리(허벅지·무릎 공·정강이·신발 앞코)
static func _limbs(g: Geo, P: Dictionary, C: Dictionary) -> void:
	var sx: float = P.shoulder_x
	var hx: float = P.hip_x
	var ar: float = P.arm_r
	var lr: float = P.leg_r
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var x := sx * side
		g.use("Arm" + sfx)
		if C.has("shoulder"):
			g.sphere(Vector3(x, P.shoulder, 0), ar * 1.3, C.shoulder, 8, 5)
		g.tube(Vector3(x, P.shoulder, 0), Vector3(x, P.elbow, 0), ar * 1.1, ar * 0.95, C.upper, 7, false)
		g.use("Forearm" + sfx)
		g.sphere(Vector3(x, P.elbow, 0), ar * 1.02, C.elbow, 7, 4)
		g.tube(Vector3(x, P.elbow, 0), Vector3(x, P.wrist, 0), ar * 0.98, ar * 0.82, C.fore, 7, false)
		g.use("Hand" + sfx)
		if C.has("cuff"):
			g.tube(Vector3(x, P.wrist + ar * 0.9, 0), Vector3(x, P.wrist - ar * 0.2, 0), ar * 1.05, ar * 1.12, C.cuff, 7, true)
		var hs: float = C.get("hand_s", 1.0)
		g.ellipsoid(Vector3(x, P.wrist - ar * 0.75, -ar * 0.1), Vector3(ar * 1.12, ar * 1.2, ar * 1.15) * hs, C.hand, 8, 5)
		var lx := hx * side
		g.use("Leg" + sfx)
		g.tube(Vector3(lx, P.hip + lr * 0.4, 0), Vector3(lx, P.knee, 0), lr * 1.15, lr * 0.95, C.thigh, 7, false)
		g.use("Shin" + sfx)
		g.sphere(Vector3(lx, P.knee, 0), lr * 1.0, C.knee, 7, 4)
		g.tube(Vector3(lx, P.knee, 0), Vector3(lx, P.ankle, 0), lr * 0.95, lr * 0.78, C.shin, 7, false)
		g.use("Foot" + sfx)
		var fl: float = P.foot_len
		var fh: float = P.ankle
		g.tube(Vector3(lx, P.ankle + lr * 0.6, 0), Vector3(lx, P.ankle - lr * 0.3, 0), lr * 0.95, lr * 1.0, C.cuff_leg, 7, true)
		var bs: float = C.get("boot_s", 1.0)
		g.ellipsoid(Vector3(lx, fh * 0.55 * bs, -fl * 0.22 * bs), Vector3(lr * 1.3 * bs, fh * 0.56 * bs, fl * 0.5 * bs), C.boot, 8, 5)
		if C.has("toe"):
			g.tube(Vector3(lx, fh * 0.55, -fl * 0.55), Vector3(lx, fh * 1.2, -fl * 0.95), lr * 0.75, 0.0, C.toe, 6, true)


# ================================================================== 고블린

static func _build_goblin(v: int, with_hammer: bool) -> Dictionary:
	var P := {
		ankle = 0.075, knee = 0.18, hip = 0.3, hip_x = 0.075, pelvis = 0.31, spine = 0.36,
		shoulder = 0.54, shoulder_x = 0.15, elbow = 0.41, wrist = 0.285, neck = 0.57, head = 0.62,
		arm_r = 0.035, leg_r = 0.038, foot_len = 0.17,
	}
	var tunic: Color = [Models.TUNIC, Color("2f8f8a"), Color("c0602f")][v]
	var skin := Models.GOBLIN_SKIN
	var g := Geo.new()
	_skeleton(g, P)
	# 몸통: 넓은 가슴, 잘록한 허리, 반바지
	g.use("Spine")
	g.ellipsoid(Vector3(0, 0.465, 0.005), Vector3(0.155, 0.12, 0.12), tunic, 12, 7)
	g.tube(Vector3(0, 0.335, 0), Vector3(0, 0.44, 0), 0.105, 0.125, tunic, 10, false)
	g.tube(Vector3(0, 0.345, 0), Vector3(0, 0.382, 0), 0.118, 0.12, Models.WOOD_DARK, 10, true)
	g.box(Vector3(0, 0.363, -0.12), Vector3(0.05, 0.04, 0.015), Models.BRASS)
	g.use("Pelvis")
	g.ellipsoid(Vector3(0, 0.3, 0), Vector3(0.125, 0.075, 0.1), Models.SHORTS, 10, 5)
	g.use("Neck")
	g.tube(Vector3(0, 0.54, 0), Vector3(0, 0.66, 0), 0.045, 0.045, skin, 7, false)
	_limbs(g, P, {shoulder = tunic, upper = skin, elbow = skin, fore = skin, hand = skin,
		thigh = skin, knee = skin, shin = skin, boot = Models.BOOT, cuff_leg = Color("5e3a1e"), toe = Models.BOOT})
	for side: float in [-1.0, 1.0]:
		g.use("LegL" if side < 0.0 else "LegR")
		g.tube(Vector3(0.075 * side, 0.32, 0), Vector3(0.075 * side, 0.235, 0), 0.062, 0.058, Models.SHORTS, 8, true)
	# 머리(3등신: 큰 머리)
	var hc := Vector3(0, 0.79, -0.005)
	var hr := Vector3(0.2, 0.18, 0.18)
	g.use("Head")
	g.ellipsoid(hc, hr, skin, 14, 9)
	_face(g, {hc = hc, hr = hr, es = 0.046, eye_y = 0.8, eye_dx = 0.082, mouth_y = 0.705, mouth_w = 0.12,
		skin = skin, pupil = Color("2b2233"), brow = Color("3f6b1a"), blush = Color("6aa22c")})
	g.use("Head")
	# 긴 코와 아랫니 송곳니
	g.ellipsoid(Vector3(0, 0.755, _surf_z(hc, hr, 0, 0.755) - 0.03), Vector3(0.034, 0.03, 0.055), Models.GOBLIN_SKIN_DARK, 7, 4)
	for side: float in [-1.0, 1.0]:
		var fx := 0.04 * side
		var fz := _surf_z(hc, hr, fx, 0.69) - 0.004
		g.tube(Vector3(fx, 0.682, fz), Vector3(fx, 0.718, fz - 0.004), 0.012, 0.0, Color.WHITE, 5, true)
	# 과장된 큰 뾰족 귀(2차 움직임용 뼈)
	g.measure = false
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		var base := Vector3(0.17 * side, 0.81, 0.01)
		g.add_bone("Ear" + sfx, "Head", base)
		g.use("Ear" + sfx)
		g.tube(base, Vector3(0.47 * side, 0.92, 0.06), 0.08, 0.0, skin, 8, true, 0.45, 1.0, Vector3.BACK)
		g.tube(base + Vector3(0.02 * side, 0, -0.03), Vector3(0.4 * side, 0.9, 0.03), 0.045, 0.0, Color("c97b7b"), 6, true, 0.35, 1.0, Vector3.BACK)
	# 머리 모양: 0 = 뾰족 머리털, 1 = 닭벼슬 머리, 2 = 상투
	g.use("Head")
	match v:
		0:
			for t in [[0.0, 0.0, 0.0, 0.13], [0.07, 0.03, -25.0, 0.1], [-0.07, 0.03, 25.0, 0.1]]:
				var b := Vector3(t[0], 0.95, t[1])
				var tip := b + Vector3(sin(deg_to_rad(-t[2])) * t[3], cos(deg_to_rad(t[2])) * t[3], 0.03)
				g.tube(b, tip, 0.05, 0.0, Models.HAIR, 6, true)
		1:
			for i in 5:
				var z := -0.12 + i * 0.06
				var y := hc.y + hr.y * sqrt(maxf(0.0, 1.0 - pow(z / hr.z, 2.0))) - 0.02
				g.tube(Vector3(0, y, z), Vector3(0, y + 0.11 - absf(z) * 0.3, z + 0.03), 0.04, 0.0, Color("d0532a"), 5, true, 0.5, 1.0)
		_:
			g.sphere(Vector3(0, 0.985, 0.03), 0.055, Color("3b2a1a"), 8, 5)
			g.tube(Vector3(0, 1.02, 0.04), Vector3(0, 1.07, 0.07), 0.025, 0.0, Color("3b2a1a"), 5, true)
	# 고글: 0, 2 번 변형
	g.measure = true
	if v != 1:
		g.ellipsoid(hc, hr * 1.04, Models.WOOD_DARK, 14, 1, Basis.IDENTITY, 0.98, 1.12, 0.84)
		for side: float in [-1.0, 1.0]:
			var gx := 0.075 * side
			var gy := 0.905
			var gz := _surf_z(hc, hr, gx, gy)
			var nn := Vector3(gx / (hr.x * hr.x), (gy - hc.y) / (hr.y * hr.y), (gz - hc.z) / (hr.z * hr.z)).normalized()
			var p := Vector3(gx, gy, gz)
			g.tube(p - nn * 0.01, p + nn * 0.035, 0.05, 0.05, Models.BRASS, 10, true)
			g.ellipsoid(p + nn * 0.035, Vector3(0.038, 0.038, 0.012), Color("9fd8e8"), 8, 3, Basis(Quaternion(Vector3.FORWARD, nn)))
	# 망치(오른손 +X). 손잡이는 손 아래로 35° 앞으로 기울어 쥔다.
	var hand := Vector3(P.shoulder_x, float(P.wrist) - float(P.arm_r) * 0.75, -0.004)
	var tip := hand
	if with_hammer:
		g.use("HandR")
		g.measure = false
		g.measure_all = false
		var gr := deg_to_rad(35.0)
		var d := Vector3(0, -cos(gr), -sin(gr))
		var perp := Vector3(0, -sin(gr), cos(gr))
		var end := hand + d * 0.3
		g.tube(hand - d * 0.04, end, 0.017, 0.017, Models.WOOD, 6, true)
		g.tube(end - perp * 0.075, end + perp * 0.075, 0.048, 0.048, Models.WOOD_DARK, 8, true)
		g.tube(end - perp * 0.08, end - perp * 0.05, 0.052, 0.052, Models.SILVER_DARK, 8, true)
		g.tube(end + perp * 0.05, end + perp * 0.08, 0.052, 0.052, Models.SILVER_DARK, 8, true)
		tip = end
	var def := g.build(MeshBatch.shared_material())
	def.tip = tip
	def.H = 1.0
	def.es = 0.046
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


# ================================================================== 뿔이(어린 마왕)

## 2.3등신. 짝짝이 뿔(왼쪽이 덜 자람), 물려받은 큰 망토(Lv.1 은 바닥에 끌림), 사탕 보석 지팡이, 연두 눈, 라벤더 피부.
## 성 레벨: Lv.2 뿔이 자라고 망토 끝을 묶음, Lv.3 금 어깨 장식·빛나는 보석, Lv.4 왕관·몸에 맞는 망토(왼뿔은 여전히 작음).
static func _build_imp(lv: int) -> Dictionary:
	var P := {
		ankle = 0.06, knee = 0.135, hip = 0.225, hip_x = 0.065, pelvis = 0.235, spine = 0.275,
		shoulder = 0.405, shoulder_x = 0.118, elbow = 0.315, wrist = 0.232, neck = 0.43, head = 0.47,
		arm_r = 0.031, leg_r = 0.034, foot_len = 0.15,
	}
	var skin := Color("c9b3ea")
	var skin_dark := Color("a68ccf")
	var robe := Color("553292")
	var cape_c := Color("6a3fb0")
	var cape_in := Color("2c1450")
	var gold := Models.GOLD
	var horn := Color("f3e6c8")
	var horn_tip := Color("8a6a9e")
	var eye_green := Color("2f9a3c")
	var gem := Color("b86bff") if lv < 3 else Color("d9a6ff")
	var g := Geo.new()
	_skeleton(g, P)
	# 몸통: 동그란 배의 짙은 보라 옷, 금단추
	g.use("Spine")
	g.ellipsoid(Vector3(0, 0.33, 0.0), Vector3(0.118, 0.105, 0.105), robe, 12, 7)
	g.tube(Vector3(0, 0.27, 0), Vector3(0, 0.37, 0), 0.1, 0.09, robe, 10, false)
	for i in 2:
		var by := 0.355 - i * 0.05
		g.sphere(Vector3(0, by, _surf_z(Vector3(0, 0.33, 0), Vector3(0.118, 0.105, 0.105), 0, by) - 0.004), 0.011, gold, 5, 3)
	g.use("Pelvis")
	g.tube(Vector3(0, 0.29, 0), Vector3(0, 0.17, 0), 0.1, 0.122, robe, 10, false)
	g.tube(Vector3(0, 0.185, 0), Vector3(0, 0.168, 0), 0.124, 0.126, gold if lv >= 3 else Color("5b3a8f"), 10, false)
	# 꼬리(뒤 +Z, 끝은 스페이드)
	var tail := [Vector3(0, 0.22, 0.09), Vector3(0, 0.17, 0.17), Vector3(0, 0.15, 0.25), Vector3(0, 0.2, 0.31)]
	g.sweep(tail, 0.014, skin_dark, 5)
	g.tube(Vector3(0, 0.2, 0.3), Vector3(0, 0.27, 0.33), 0.035, 0.0, skin_dark, 6, true, 1.0, 0.35, Vector3.BACK)
	g.use("Neck")
	g.tube(Vector3(0, 0.41, 0), Vector3(0, 0.5, 0), 0.04, 0.04, skin, 7, false)
	_limbs(g, P, {shoulder = robe, upper = robe, elbow = skin, fore = skin, hand = skin, cuff = Color("5b3a8f"),
		thigh = skin, knee = skin, shin = skin, boot = Color("2a1a3a"), cuff_leg = Color("4a2d6a"), toe = Color("2a1a3a")})
	# Lv.3+: 금 어깨 장식
	if lv >= 3:
		for side: float in [-1.0, 1.0]:
			g.use("ArmL" if side < 0.0 else "ArmR")
			var pc := Vector3(float(P.shoulder_x) * side, float(P.shoulder) + 0.005, 0)
			g.ellipsoid(pc, Vector3(0.05, 0.035, 0.05), gold, 8, 3, Basis.IDENTITY, PI * 0.55, PI * 0.55)
	# 망토(2차 움직임 뼈): Lv.1 은 몸보다 커서 바닥에 끌리고 깃이 크다
	var cape_len: float = [0.0, 0.44, 0.37, 0.35, 0.34][lv]
	var cape_w: Vector2 = [Vector2.ZERO, Vector2(0.12, 0.22), Vector2(0.11, 0.19), Vector2(0.11, 0.18), Vector2(0.11, 0.18)][lv]
	var cape_top := Vector3(0, float(P.shoulder) + 0.012, 0.085)
	g.add_bone("Cape", "Spine", cape_top)
	g.use("Cape")
	var cape_bot := cape_top + Vector3(0, -cape_len, 0.1 if lv == 1 else 0.07)
	g.tube(cape_top, cape_bot, cape_w.x, cape_w.y, cape_c, 9, true, 1.0, 0.12)
	g.tube(cape_top + Vector3(0, -0.01, -0.012), cape_bot + Vector3(0, 0.01, -0.012), cape_w.x * 0.96, cape_w.y * 0.96, cape_in, 9, false, 1.0, 0.1)
	if lv == 1:
		# 바닥에 끌리는 끝단(접힌 천)
		g.ellipsoid(cape_bot + Vector3(0, 0.012, 0.02), Vector3(cape_w.y * 1.05, 0.02, 0.06), cape_c, 9, 3)
	elif lv == 2:
		g.sphere(cape_bot + Vector3(cape_w.y * 0.55, 0.05, 0.005), 0.03, cape_c.darkened(0.15), 6, 4)
	else:
		g.tube(cape_bot + Vector3(0, 0.022, -0.003), cape_bot - Vector3(0, 0.002, 0), cape_w.y + 0.003, cape_w.y + 0.004, gold, 9, true, 1.0, 0.16)
	# 깃(Lv.1 은 크고 펄럭, Lv.4 는 높이 선 깃)
	var collar_r := 0.12 if lv == 1 else (0.1 if lv < 4 else 0.105)
	g.use("Spine")
	g.ellipsoid(Vector3(0, float(P.shoulder) + 0.02, 0.01), Vector3(collar_r, 0.035 if lv < 4 else 0.06, collar_r * 0.85), cape_c, 10, 3,
		Basis.IDENTITY, PI * 0.55, PI * 0.55, 0.0)
	if lv == 4:
		g.ellipsoid(Vector3(0, 0.335, _surf_z(Vector3(0, 0.33, 0), Vector3(0.118, 0.105, 0.105), 0, 0.335) - 0.005), Vector3(0.03, 0.03, 0.012), gold, 8, 3)
		g.sphere(Vector3(0, 0.335, _surf_z(Vector3(0, 0.33, 0), Vector3(0.118, 0.105, 0.105), 0, 0.335) - 0.016), 0.014, Color("7ee06a"), 5, 3)
	# 머리: 아주 큰 머리(2.3등신)
	var hc := Vector3(0, 0.625, -0.005)
	var hr := Vector3(0.19, 0.172, 0.172)
	g.use("Head")
	g.ellipsoid(hc, hr, skin, 14, 9)
	# 눈은 머리 가운데보다 아래(아기 같은 비율), 눈썹은 연한 색으로 부드럽게
	_face(g, {hc = hc, hr = hr, es = 0.052, eye_y = 0.6, eye_dx = 0.08, mouth_y = 0.517, mouth_w = 0.07,
		skin = skin, pupil = eye_green, brow = skin_dark.darkened(0.1), blush = Color("f2a0c8"), iris = 1.12, pupil_core = Color("173d1c"),
		lid = skin})
	g.use("Head")
	# 작은 코, 오른쪽 송곳니 하나(빼꼼)
	g.sphere(Vector3(0, 0.553, _surf_z(hc, hr, 0, 0.553) - 0.006), 0.013, skin_dark, 5, 3)
	var fz := _surf_z(hc, hr, 0.022, 0.515) - 0.006
	g.tube(Vector3(0.022, 0.521, fz), Vector3(0.024, 0.5, fz - 0.002), 0.009, 0.0, Color.WHITE, 5, true)
	# 정수리 위 동그랗게 말린 머리카락 한 가닥
	var curl: Array = []
	for j in 8:
		var a := float(j) / 7.0 * PI * 1.6
		curl.append(Vector3(sin(a) * 0.03, hc.y + hr.y * 0.97 + 0.03 - cos(a) * 0.03, hc.z - 0.03))
	g.sweep(curl, 0.012, Color("4a2d6a"), 5)
	# 짝짝이 뿔: 바깥·위·뒤로 휘어지는 원뿔 마디. 오른쪽(+X)이 더 크고, 왼쪽은 Lv.4 에서도 작다.
	g.measure = false
	var horn_len: Vector2 = {1: Vector2(0.06, 0.12), 2: Vector2(0.08, 0.16), 3: Vector2(0.095, 0.19), 4: Vector2(0.11, 0.23)}[lv]
	for side: float in [-1.0, 1.0]:
		var L: float = horn_len.x if side < 0.0 else horn_len.y
		var base := hc + Vector3(0.105 * side, hr.y * 0.78, 0.01)
		var r0 := 0.032 + L * 0.12
		var pts: Array = []
		for i in 5:
			var u := float(i) / 4.0
			pts.append(base + Vector3(side * (L * 0.55 * u + L * 0.25 * u * u), L * (0.95 * u - 0.15 * u * u), L * 0.35 * u * u))
		for i in 4:
			var ra := r0 * (1.0 - float(i) / 4.0)
			var rb := r0 * (1.0 - float(i + 1) / 4.0)
			g.tube(pts[i], pts[i + 1], ra, maxf(rb, 0.0), horn if i < 3 else horn_tip, 7, i == 3)
	g.measure = true
	# Lv.4 왕관(금테 + 뾰족 다섯 + 연두 보석)
	if lv == 4:
		var ring: Array = []
		for j in 14:
			var lon := TAU * float(j) / 14.0
			var lat := 0.62
			ring.append(hc + Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon)) * hr * 1.02)
		g.sweep(ring, 0.016, gold, 4, true)
		g.measure = false
		for k in 5:
			var lon := TAU * float(k) / 5.0
			var b := hc + Vector3(sin(0.62) * sin(lon), cos(0.62), -sin(0.62) * cos(lon)) * hr * 1.02
			g.tube(b, b + Vector3(0, 0.055, 0), 0.022, 0.0, gold, 5, true)
		g.measure = true
		g.sphere(ring[0] + Vector3(0, 0.01, -0.012), 0.018, Color("7ee06a"), 6, 4)
	# 사탕 보석 지팡이(오른손 +X). 쉬는 자세에서 앞으로 기울어 있어 팔을 굽히면(대기) 곧게 선다.
	var hand := Vector3(float(P.shoulder_x), float(P.wrist) - float(P.arm_r) * 0.75, -0.004)
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var sa := 0.75
	# 머리(큰 공) 옆을 지나 보석이 머리 위 바깥쪽에 오도록 살짝 바깥(+X)으로 기울인 긴 지팡이
	var d := Vector3(0.2, cos(sa), -sin(sa)).normalized()
	var top := hand + d * 0.52
	g.tube(hand - d * 0.1, top, 0.012, 0.013, Models.WOOD, 6, true)
	g.tube(top - d * 0.02, top + d * 0.012, 0.022, 0.022, gold, 6, true)
	var gc := top + d * 0.05
	g.sphere(gc, 0.05 if lv < 3 else 0.058, gem, 8, 6)
	# 사탕 소용돌이 띠
	var swirl: Array = []
	for j in 9:
		var a := TAU * float(j) / 8.0
		swirl.append(gc + Basis(Vector3.RIGHT, -sa) * (Vector3(cos(a), 0.35 * sin(a * 2.0) * 0.0 + (float(j) / 8.0 - 0.5) * 0.06, sin(a)) * (0.051 if lv < 3 else 0.059)))
	g.sweep(swirl, 0.008, Color("fdf3ff"), 4)
	if lv >= 3:
		# 빛나는 보석: 바깥 후광 고리
		g.sweep([gc + Vector3(-0.075, 0, 0), gc + Vector3(0, 0.075, 0), gc + Vector3(0.075, 0, 0), gc + Vector3(0, -0.075, 0)], 0.006, Color("f2dcff"), 4, true)
	var def := g.build(MeshBatch.shared_material())
	def.tip = gc
	def.H = 0.8
	def.es = 0.054
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def


# ================================================================== 인간(기사·보스)

static func _knight_spec(v: int) -> Dictionary:
	return {
		H = 1.15,
		P = {
			ankle = 0.08, knee = 0.245, hip = 0.425, hip_x = 0.085, pelvis = 0.44, spine = 0.5,
			shoulder = 0.72, shoulder_x = 0.2, elbow = 0.575, wrist = 0.44, neck = 0.75, head = 0.8,
			arm_r = 0.047, leg_r = 0.052, foot_len = 0.2,
		},
		hc = Vector3(0, 0.955, -0.005), hr = Vector3(0.17, 0.165, 0.165),
		hand_s = 1.4, boot_s = 1.22,
		es = 0.034, eye_dx = 0.062, eye_y = 0.935, mouth_y = 0.868, mouth_w = 0.075,
		skin = Color(KNIGHT_SKIN[v]),
		chest = Models.SILVER, chest_c = Vector3(0, 0.65, 0), chest_r = Vector3(0.205, 0.135, 0.135),
		waist = Color("7d8792"), waist_r = Vector2(0.092, 0.13), belt_y = 0.515,
		skirt = Models.RED, skirt_y = Vector2(0.52, 0.37), skirt_r = Vector2(0.115, 0.15),
		trouser = Color("6d6a78"), armor = Models.SILVER, armor_dark = Models.SILVER_DARK, trim = Models.GOLD,
		boot = Models.BOOT, glove = Color("8a5530"),
		pauldron = Vector3(0.13, 0.1, 0.13),
		cape = Color("b02a32"), cape_len = 0.36, cape_w = Vector2(0.12, 0.16),
		helmet = KNIGHT_HELMET[v], plumes = [Color(KNIGHT_PLUME[v])], plume_size = 1.0,
		shield = KNIGHT_SHIELD[v], shield_r = 0.255, shield_c = Models.RED, shield_rim = Models.GOLD, shield_mark = Models.GOLD,
		sword_len = 0.46, sword_w = 0.038, mustache = (v == 3),
	}


static func _boss_spec(k: String) -> Dictionary:
	var s := {
		H = 1.3,
		P = {
			ankle = 0.09, knee = 0.27, hip = 0.49, hip_x = 0.095, pelvis = 0.505, spine = 0.57,
			shoulder = 0.84, shoulder_x = 0.235, elbow = 0.67, wrist = 0.515, neck = 0.87, head = 0.92,
			arm_r = 0.045, leg_r = 0.052, foot_len = 0.22,
		},
		hc = Vector3(0, 1.112, -0.005), hr = Vector3(0.165, 0.158, 0.16),
		es = 0.032, eye_dx = 0.06, eye_y = 1.092, mouth_y = 1.03, mouth_w = 0.072,
		skin = Color("f2c9a0"),
		chest_c = Vector3(0, 0.75, 0), chest_r = Vector3(0.215, 0.145, 0.14),
		waist_r = Vector2(0.11, 0.15), belt_y = 0.6,
		skirt_y = Vector2(0.6, 0.42), skirt_r = Vector2(0.13, 0.175),
		boot = Color("5a3418"), glove = Color("6b3f1f"),
		cape_len = 0.56, cape_w = Vector2(0.14, 0.21),
		sword_len = 0.52, sword_w = 0.036, mustache = false,
	}
	if k == "hero":
		s.merge({
			chest = Color("dfe6ee"), waist = Color("3d6fd6"), skirt = Color("3d6fd6"), trouser = Color("2f3f6a"),
			armor = Color("dfe6ee"), armor_dark = Color("9fb0c2"), trim = Models.GOLD,
			pauldron = Vector3(0.11, 0.085, 0.115), cape = Color("2f55b0"), cape_hem = Models.GOLD,
			helmet = "", hair = Color("f0c040"), circlet = true, plumes = [],
			shield = "star", shield_r = 0.22, shield_c = Color("3a5fb8"), shield_rim = Color("dfe6ee"), shield_mark = Models.GOLD,
			gem = Color("4fc3f7"),
		}, true)
	else:
		s.merge({
			chest = Color("8e99a6"), waist = Color("5c6570"), skirt = Color("8f1f27"), trouser = Color("4a4552"),
			armor = Color("8e99a6"), armor_dark = Color("5c6570"), trim = Models.GOLD,
			pauldron = Vector3(0.135, 0.1, 0.135), spikes = true, cape = Color("a3242c"), cape_hem = Models.GOLD,
			helmet = "crest", plumes = [Color("d8333a"), Color("f4efe4")], plume_size = 1.2,
			shield = "crown", shield_r = 0.25, shield_c = Color("b52a33"), shield_rim = Models.GOLD, shield_mark = Models.GOLD,
			mustache = true, gem = Color("e04848"),
		}, true)
	return s


static func _build_human(S: Dictionary) -> Dictionary:
	var P: Dictionary = S.P
	var g := Geo.new()
	_skeleton(g, P)
	var hcen: Vector3 = S.hc
	var hr: Vector3 = S.hr
	var skin: Color = S.skin
	var trim: Color = S.trim
	var armor: Color = S.armor
	var cc: Vector3 = S.chest_c
	var cr: Vector3 = S.chest_r
	var spine_y: float = P.spine
	var pel: float = P.pelvis
	# 몸통: 넓은 가슴판, 잘록한 허리, 벨트, 치마(튜닉)
	g.use("Spine")
	g.ellipsoid(cc, cr, S.chest, 10, 6)
	g.ellipsoid(cc + Vector3(0, cr.y * 0.55, -cr.z * 0.05), Vector3(cr.x * 0.55, cr.y * 0.35, cr.z * 1.0), trim, 8, 3, Basis.IDENTITY, 0.9, 0.9, 0.5)
	var wr: Vector2 = S.waist_r
	g.tube(Vector3(0, spine_y - 0.04, 0), Vector3(0, cc.y - cr.y * 0.3, 0), wr.x, wr.y, S.waist, 10, false)
	if S.has("gem"):
		# 보스 가슴 문장(금 원판 + 보석)
		var ez := cc.z - cr.z * 0.93
		var ey := cc.y + cr.y * 0.05
		g.ellipsoid(Vector3(0, ey, ez), Vector3(0.05, 0.05, 0.02), trim, 10, 4)
		g.ellipsoid(Vector3(0, ey, ez - 0.015), Vector3(0.025, 0.03, 0.015), S.gem, 6, 4)
	var by: float = S.belt_y
	g.tube(Vector3(0, by - 0.02, 0), Vector3(0, by + 0.02, 0), wr.x + 0.012, wr.x + 0.016, Models.WOOD_DARK, 10, true)
	g.box(Vector3(0, by, -wr.x - 0.016), Vector3(0.05, 0.045, 0.015), trim)
	g.use("Pelvis")
	g.ellipsoid(Vector3(0, pel, 0), Vector3(wr.x * 1.15, 0.07, wr.x * 0.95), S.trouser, 8, 4)
	var sy: Vector2 = S.skirt_y
	var sr: Vector2 = S.skirt_r
	g.tube(Vector3(0, sy.x, 0), Vector3(0, sy.y, 0), sr.x, sr.y, S.skirt, 10, false)
	g.tube(Vector3(0, sy.y + 0.022, 0), Vector3(0, sy.y - 0.002, 0), sr.y + 0.004, sr.y + 0.008, trim, 10, false)
	g.use("Neck")
	g.tube(Vector3(0, float(P.neck) - 0.03, 0), Vector3(0, float(P.head) + 0.04, 0), 0.05, 0.048, skin, 7, false)
	g.use("Spine")
	g.tube(Vector3(0, float(P.neck) - 0.04, 0), Vector3(0, float(P.neck) + 0.005, 0), 0.085, 0.07, S.armor_dark, 10, true)
	# 팔다리
	_limbs(g, P, {upper = S.trouser, elbow = armor, fore = armor, hand = S.glove, cuff = S.armor_dark,
		thigh = S.trouser, knee = armor, shin = armor, boot = S.boot, cuff_leg = S.boot.darkened(0.2),
		hand_s = S.get("hand_s", 1.0), boot_s = S.get("boot_s", 1.0)})
	# 어깨 갑옷(넓은 어깨 실루엣)
	var pd: Vector3 = S.pauldron
	for side: float in [-1.0, 1.0]:
		var sfx := "L" if side < 0.0 else "R"
		g.use("Arm" + sfx)
		var pc := Vector3(float(P.shoulder_x) * side + pd.x * 0.15 * side, float(P.shoulder) - pd.y * 0.2, 0)
		g.ellipsoid(pc, pd, armor, 10, 4, Basis.IDENTITY, PI * 0.55, PI * 0.55)
		g.ellipsoid(pc, pd * 1.04, trim, 10, 1, Basis.IDENTITY, PI * 0.56, PI * 0.56, PI * 0.5)
		if S.get("spikes", false):
			g.measure = false
			g.tube(pc + Vector3(0, pd.y * 0.6, 0), pc + Vector3(pd.x * 0.7 * side, pd.y * 1.9, 0), 0.025, 0.0, trim, 5, true)
			g.measure = true
	# 망토(2차 움직임 뼈)
	var cape_top := Vector3(0, float(P.shoulder) + 0.01, cr.z * 0.85)
	g.add_bone("Cape", "Spine", cape_top)
	g.use("Cape")
	var cw: Vector2 = S.cape_w
	var cl: float = S.cape_len
	var cape_bot := cape_top + Vector3(0, -cl, 0.08)
	g.tube(cape_top, cape_bot, cw.x, cw.y, S.cape, 8, true, 1.0, 0.12)
	if S.has("cape_hem"):
		g.tube(cape_bot + Vector3(0, 0.025, -0.003), cape_bot - Vector3(0, 0.002, 0), cw.y + 0.003, cw.y + 0.004, S.cape_hem, 8, true, 1.0, 0.16)
	# 머리·얼굴
	g.use("Head")
	g.ellipsoid(hcen, hr, skin, 12, 8)
	var es: float = S.es
	var ey: float = S.eye_y
	_face(g, {hc = hcen, hr = hr, es = es, eye_y = ey, eye_dx = S.eye_dx, mouth_y = S.mouth_y, mouth_w = S.mouth_w,
		skin = skin, pupil = Color("2b2233"), brow = Color("5a3a22") if S.get("hair", null) == null else Color(S.hair).darkened(0.35),
		blush = Color("f19a8f")})
	g.use("Head")
	var ny := ey - es * 1.55
	g.sphere(Vector3(0, ny, _surf_z(hcen, hr, 0, ny) - 0.008), 0.022, skin.darkened(0.1), 6, 4)
	# 귀(사람, 투구가 없을 때만 보인다)
	for side: float in ([] if String(S.helmet) != "" else [-1.0, 1.0]):
		g.ellipsoid(hcen + Vector3(hr.x * 0.97 * side, -0.02, 0.01), Vector3(0.025, 0.04, 0.03), skin.darkened(0.06), 6, 3)
	if S.get("mustache", false):
		for side: float in [-1.0, 1.0]:
			var mx := 0.032 * side
			var my2: float = float(S.mouth_y) + float(S.mouth_w) * 0.42
			g.ellipsoid(Vector3(mx, my2, _surf_z(hcen, hr, mx, my2) - 0.006), Vector3(0.036, 0.014, 0.014), Color("7a5a3a"), 6, 3, Basis(Vector3.BACK, -0.35 * side))
	# 투구 또는 머리카락
	var helmet: String = S.helmet
	var plume_base := Vector3(0, hcen.y + hr.y + 0.03, 0.02)
	if helmet != "":
		var hc2 := hcen + Vector3(0, 0.012, 0.012)
		var hr2 := hr * Vector3(1.11, 1.15, 1.13)
		# 앞은 눈썹 위까지만 덮어 얼굴(표정)이 보이게, 옆·뒤는 깊게
		var lat_f := 1.2
		var lat_b := 2.15
		g.ellipsoid(hc2, hr2, armor, 12, 5, Basis.IDENTITY, lat_f, lat_b)
		var rim: Array = []
		for j in 10:
			var lon := TAU * float(j) / 10.0
			var lat := lerpf(lat_b, lat_f, (1.0 + cos(lon)) * 0.5)
			rim.append(hc2 + Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon)) * hr2 * 1.01)
		g.sweep(rim, 0.016, trim, 4, true)
		for side: float in [-1.0, 1.0]:
			g.ellipsoid(hcen + Vector3(hr.x * 0.95 * side, -0.055, -0.03), Vector3(0.035, 0.08, 0.075), S.armor_dark, 6, 4)
		var top_y := hc2.y + hr2.y
		g.measure = false
		match helmet:
			"round":
				g.sphere(Vector3(0, top_y + 0.01, hc2.z), 0.03, trim, 6, 4)
			"pointed":
				g.tube(Vector3(0, top_y - 0.04, hc2.z), Vector3(0, top_y + 0.13, hc2.z + 0.02), 0.08, 0.0, armor, 10, false)
				plume_base = Vector3(0, top_y + 0.1, hc2.z + 0.03)
			"crest":
				g.ellipsoid(Vector3(0, top_y - 0.005, hc2.z), Vector3(0.022, 0.06, hr2.z * 0.95), trim, 8, 5)
			"visor":
				g.ellipsoid(Vector3(0, hc2.y + hr2.y * 0.58, hc2.z - hr2.z * 0.72), Vector3(hr2.x * 0.9, 0.04, 0.06), S.armor_dark, 10, 4, Basis(Vector3.RIGHT, -0.5))
			"brim":
				g.tube(Vector3(0, hc2.y + hr2.y * 0.36, hc2.z), Vector3(0, hc2.y + hr2.y * 0.36 + 0.018, hc2.z), hr2.x * 1.35, hr2.x * 1.3, armor, 14, true)
		g.measure = true
	else:
		# 용사: 금빛 뾰족 머리 + 금관(이마띠)
		var hair: Color = S.hair
		g.ellipsoid(hcen + Vector3(0, 0.012, 0.008), hr * 1.07, hair, 14, 6, Basis.IDENTITY, 1.05, 2.0)
		g.measure = false
		for t in [[0.0, 0.0, 0.14], [0.35, 0.6, 0.12], [-0.35, 0.6, 0.12], [0.7, 1.4, 0.1], [-0.7, 1.4, 0.1], [0.2, 2.3, 0.11], [-0.2, 2.3, 0.11], [0.0, 2.8, 0.1]]:
			var lat: float = t[1] * 0.45
			var lon: float = PI + t[0] * 1.6 if t[1] > 1.0 else t[0] * 1.6
			var dir := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
			var b := hcen + dir * hr * 0.98
			g.tube(b, b + (dir + Vector3(0, 0.6, 0.25)).normalized() * float(t[2]), 0.05, 0.0, hair, 6, true)
		for side: float in [-1.0, 0.0, 1.0]:
			var b := hcen + Vector3(0.06 * side, hr.y * 0.72, -hr.z * 0.7)
			g.tube(b, b + Vector3(0.025 * side, -0.06, -0.035), 0.035, 0.0, hair, 5, true)
		g.measure = true
		if S.get("circlet", false):
			var ring: Array = []
			for j in 14:
				var lon := TAU * float(j) / 14.0
				var lat := 1.05 + 0.05 * cos(lon)
				ring.append(hcen + Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon)) * hr * 1.09)
			g.sweep(ring, 0.014, trim, 4, true)
			g.sphere(ring[0] + Vector3(0, 0.0, -0.012), 0.022, S.gem, 6, 4)
		plume_base = Vector3(0, hcen.y + hr.y, 0.0)
	# 깃털(2차 움직임 뼈) — 기사의 붉은 깃은 멀리서도 보이게 크게
	var plumes: Array = S.plumes
	if not plumes.is_empty():
		g.add_bone("Plume", "Head", plume_base)
		g.use("Plume")
		g.measure = false
		var ps: float = S.get("plume_size", 1.0)
		for pi_ in plumes.size():
			var pc: Color = plumes[pi_]
			var ox := 0.0 if plumes.size() == 1 else (float(pi_) - 0.5) * 0.06
			var arc := [Vector3(ox, 0.04, 0.0), Vector3(ox, 0.11, 0.03), Vector3(ox, 0.15, 0.1), Vector3(ox, 0.14, 0.18), Vector3(ox * 1.2, 0.09, 0.24)]
			var rad := [0.045, 0.055, 0.055, 0.045, 0.032]
			for i in arc.size():
				var p: Vector3 = plume_base + (arc[i] as Vector3) * ps
				var rr: float = float(rad[i]) * ps
				g.ellipsoid(p, Vector3(rr * 0.8, rr * 1.15, rr * 1.2), pc if i % 2 == 0 else pc.darkened(0.12), 6, 4, Basis(Vector3.RIGHT, -0.4 - 0.25 * i))
		g.measure = true
	# 검(오른손 +X): 손 아래로 30° 앞으로 기울어 쥔다. 날은 앞뒤에서 넓게 보이도록 X 로 넓다.
	var hand_r := Vector3(float(P.shoulder_x), float(P.wrist) - float(P.arm_r) * 0.75, -float(P.arm_r) * 0.1)
	g.use("HandR")
	g.measure = false
	g.measure_all = false
	var gr := deg_to_rad(30.0)
	var d := Vector3(0, -cos(gr), -sin(gr))
	var sl: float = S.sword_len
	var sw: float = S.sword_w
	g.tube(hand_r - d * 0.065, hand_r + d * 0.05, 0.015, 0.015, Models.WOOD_DARK, 6, false)
	g.sphere(hand_r - d * 0.075, 0.024, trim, 6, 4)
	var guard_c := hand_r + d * 0.058
	g.box(guard_c, Vector3(sw * 5.0, 0.026, 0.026), trim, Basis(Vector3.RIGHT, d, Vector3.RIGHT.cross(d)))
	if S.has("gem"):
		g.sphere(guard_c + d.cross(Vector3.RIGHT) * 0.016, 0.018, S.gem, 6, 4)
	var blade_end := hand_r + d * (0.07 + sl)
	g.tube(hand_r + d * 0.07, blade_end, sw, sw * 0.9, Color("dfe6ee"), 6, false, 1.0, 0.28)
	var tip := blade_end + d * sw * 2.6
	g.tube(blade_end, tip, sw * 0.9, 0.0, Color("dfe6ee"), 6, true, 1.0, 0.28)
	# 둥근 방패(왼손 -X): 바깥·앞을 본다. 무늬는 변형마다 다르다.
	g.use("HandL")
	var hand_l := Vector3(-float(P.shoulder_x), hand_r.y, hand_r.z)
	var nrm := Vector3(-0.55, -0.5, -0.67).normalized()
	var sc := hand_l + nrm * 0.055
	var r_sh: float = S.shield_r
	g.measure_all = true
	g.tube(sc - nrm * 0.022, sc + nrm * 0.012, r_sh * 1.07, r_sh * 1.07, S.shield_rim, 14, true)
	g.tube(sc - nrm * 0.01, sc + nrm * 0.022, r_sh, r_sh, S.shield_c, 14, true)
	var t1 := nrm.cross(Vector3.UP).normalized()
	var t2 := t1.cross(nrm).normalized()
	if t2.y < 0.0:
		t2 = -t2
	var face := sc + nrm * 0.026
	var sb := Basis(t1, t2, nrm)
	var mark: Color = S.shield_mark
	match String(S.shield):
		"cross":
			g.box(face, Vector3(r_sh * 1.7, 0.045, 0.012), mark, sb)
			g.box(face, Vector3(0.045, r_sh * 1.7, 0.012), mark, sb)
		"band":
			g.box(face, Vector3(r_sh * 1.85, 0.075, 0.012), Color("f4efe4"), Basis(nrm, PI * 0.25) * sb)
		"ring":
			g.tube(face - nrm * 0.006, face + nrm * 0.004, r_sh * 0.62, r_sh * 0.62, mark, 14, true)
			g.tube(face - nrm * 0.004, face + nrm * 0.008, r_sh * 0.48, r_sh * 0.48, S.shield_c, 14, true)
		"stripes":
			# 흰 가로 띠 두 줄
			for sgn: float in [-1.0, 1.0]:
				g.box(face + t2 * (r_sh * 0.32 * sgn), Vector3(r_sh * 1.6, 0.055, 0.012), Color("f4efe4"), sb)
		"star":
			for k in 4:
				g.box(face, Vector3(r_sh * 1.5, 0.05, 0.012), mark, Basis(nrm, PI * 0.25 * k) * sb)
		"crown":
			g.box(face - t2 * r_sh * 0.15, Vector3(r_sh * 0.95, r_sh * 0.28, 0.012), mark, sb)
			for k in 3:
				var off := t1 * (float(k - 1) * r_sh * 0.36) + t2 * r_sh * 0.02
				g.tube(face + off - nrm * 0.004, face + off + t2 * r_sh * 0.35, 0.05, 0.0, mark, 5, true, 1.0, 0.25, nrm)
	g.sphere(face + nrm * 0.012, 0.045 * r_sh / 0.21, trim, 8, 5)
	var def := g.build(MeshBatch.shared_material())
	def.tip = tip
	def.H = float(S.H)
	def.es = es
	def.thigh = float(P.hip) - float(P.knee)
	def.shin = float(P.knee) - float(P.ankle)
	return def
