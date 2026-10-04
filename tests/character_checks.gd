extends SceneTree
## 캐릭터 리그 검사(헤드리스): godot --headless --path . --script res://tests/character_checks.gd
## 관절 이름, 무기 손, 발 높이, 키, 공격·망치 충격 위상, 표정, 삼각형·그리기 호출 예산을 확인한다.
## 렌더링 없이 Skeleton3D 의 전역 뼈 자세(get_bone_global_pose)와 CPU 스키닝으로 계산한다.

var _pass := 0
var _fail := 0


func _initialize() -> void:
	# --model-set=v6 이면 6차 교체 후보를 같은 기준으로 검사한다(기본 v5)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model-set="):
			CharacterRig.model_set = a.substr(12)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("  실패: " + what)


func _run() -> void:
	var budgets: Dictionary = GameConfig.defaults().get("performance_targets", {}).get("budgets", {})
	var b_char := int(budgets.get("character_triangles_max", 4000))
	var b_boss := int(budgets.get("boss_triangles_max", 6000))
	var cases: Array = []
	for v in 3:
		cases.append({rig = CharacterRig.goblin(v, true), label = "goblin%d" % v, kind = "goblin", h = 1.0, budget = b_char})
	cases.append({rig = CharacterRig.goblin(0, false), label = "goblin-nohammer", kind = "goblin_nh", h = 1.0, budget = b_char})
	for v in 5:
		cases.append({rig = CharacterRig.knight(v), label = "knight%d" % v, kind = "knight", h = 1.15, budget = b_char})
	cases.append({rig = CharacterRig.boss("hero"), label = "hero", kind = "boss", h = 1.3, budget = b_boss})
	cases.append({rig = CharacterRig.boss("commander"), label = "commander", kind = "boss", h = 1.3, budget = b_boss})
	cases.append({rig = CharacterRig.orc(), label = "orc", kind = "unit", h = 1.0, budget = b_char})
	cases.append({rig = CharacterRig.skeleton_archer(), label = "skeleton", kind = "unit_bow", h = 1.15, budget = b_char})
	var x := 0.0
	for c in cases:
		var r: CharacterRig = c.rig
		r.position = Vector3(x, 0, 0)
		x += 3.0
		root.add_child(r)
	for c in cases:
		_check_rig(c)
	_check_misc()
	print("RESULT: %d passed, %d failed (model set %s)" % [_pass, _fail, CharacterRig.model_set])
	quit(1 if _fail > 0 else 0)


func _local(r: CharacterRig, p: Vector3) -> Vector3:
	return r.global_transform.affine_inverse() * p


func _bone_centroid_x(r: CharacterRig, bone: String) -> float:
	var verts := r.posed_vertices()
	var vb: PackedInt32Array = r._def.vbones
	var bi: int = r._bi[bone]
	var sum := 0.0
	var cnt := 0
	for i in verts.size():
		if vb[i] == bi:
			sum += verts[i].x
			cnt += 1
	return sum / maxf(1.0, float(cnt))


func _min_y(r: CharacterRig) -> float:
	var m := 99.0
	for p in r.posed_vertices():
		m = minf(m, p.y)
	return m


func _max_y(r: CharacterRig) -> float:
	var m := -99.0
	for p in r.posed_vertices():
		m = maxf(m, p.y)
	return m


func _check_rig(c: Dictionary) -> void:
	var r: CharacterRig = c.rig
	var label: String = c.label
	# 1. 관절
	for j in CharacterRig.REQUIRED_JOINTS:
		check(r.has_joint(j) and r.joint(j) != null, "%s: 관절 %s" % [label, j])
	var jn := r.joint("HandR")
	check(jn != null and jn.name == "HandR", "%s: joint() 노드 이름" % label)
	# 2. 쉬는 자세: 발 높이, 키
	r.pose_idle(0.0)
	var low := _min_y(r)
	check(absf(low) <= 0.03, "%s: 가장 낮은 정점 y=%.3f (±0.03)" % [label, low])
	var scale_y: float = r.skeleton.scale.y
	var base_h: float = r.HEIGHT / scale_y
	check(absf(base_h / float(c.h) - 1.0) <= 0.06, "%s: 기본 키 %.3f (표 %.2f ±6%%)" % [label, base_h, c.h])
	if c.kind == "knight":
		check(scale_y >= 0.95 - 0.0001 and scale_y <= 1.05 + 0.0001, "%s: 변형 키 배율 %.2f (±5%%)" % [label, scale_y])
		check(absf(r.HEIGHT / 1.15 - 1.0) <= 0.06 + 0.05, "%s: 변형 키 %.3f" % [label, r.HEIGHT])
	check(_max_y(r) >= r.HEIGHT - 0.001, "%s: 정점 최고점이 HEIGHT 이상" % label)
	check(r.hp_bar_y() > _max_y(r) - 0.05 or r.hp_bar_y() > r.HEIGHT + 0.1, "%s: 체력 막대 높이 %.2f" % [label, r.hp_bar_y()])
	# 3. 정면 -Z: 눈동자가 머리 중심보다 앞(-Z)
	var head_z := _local(r, r.joint_global_position("Head")).z
	var pupil_z := _local(r, r.joint_global_position("PupilL")).z
	check(pupil_z < head_z - 0.05, "%s: 얼굴이 -Z 를 봄" % label)
	# 4. 무기 손: 검·망치 = HandR(+X), 방패 = HandL(-X)
	var hand_r := _local(r, r.joint_global_position("HandR"))
	var hand_l := _local(r, r.joint_global_position("HandL"))
	check(hand_r.x > 0.05 and hand_l.x < -0.05, "%s: HandR +X, HandL -X" % label)
	if c.kind != "goblin_nh" and c.kind != "unit_bow":
		var tip := _local(r, r.weapon_tip_global_position())
		check(tip.x > 0.05, "%s: 무기(검/망치)가 +X 쪽 HandR 에 있음 (x=%.2f)" % [label, tip.x])
		check(tip.distance_to(hand_r) > 0.2, "%s: 무기 끝이 손에서 떨어져 있음" % label)
		check(_bone_centroid_x(r, "HandR") > 0.05, "%s: HandR 정점 +X" % label)
	if c.kind == "knight" or c.kind == "boss":
		check(_bone_centroid_x(r, "HandL") < -0.1, "%s: 방패(HandL 정점) -X" % label)
	# 5. 걷기: 발 디딤(가장 낮은 정점이 늘 지면 근처), 몸 위아래 움직임
	var lows: Array = []
	var pel: Array = []
	for i in 16:
		r.pose_walk(i / 16.0)
		lows.append(_min_y(r))
		pel.append(_local(r, r.joint_global_position("Pelvis")).y)
	var lmin: float = lows.min()
	var lmax: float = lows.max()
	check(lmin >= -0.03 and lmax <= 0.035, "%s: 걷기 발 디딤 %.3f~%.3f" % [label, lmin, lmax])
	check(float(pel.max()) - float(pel.min()) > 0.005, "%s: 걷기 몸 위아래" % label)
	var bend := 0.0
	for i in 8:
		r.pose_walk(i / 8.0)
		var knee_l := _local(r, r.joint_global_position("ShinL"))
		var hip_l := _local(r, r.joint_global_position("LegL"))
		var ankle_l := _local(r, r.joint_global_position("FootL"))
		bend = maxf(bend, (knee_l - hip_l).normalized().angle_to((ankle_l - knee_l).normalized()))
	check(bend > 0.6, "%s: 걷기 중 무릎 굽힘 최대 %.2f rad" % [label, bend])
	r.pose_walk(0.0)
	var lean := r.skeleton.get_bone_pose_rotation(int(r._bi["Spine"])).get_euler().x
	check(lean < -0.05, "%s: 걷기에서 앞으로 기울임" % label)
	# 6. 공격/망치 충격 위상: 무기 끝 최저점이 p≈0
	if c.kind == "knight" or c.kind == "boss":
		var am := _argmin_tip(r, "attack")
		check(am <= 0.03 or am >= 0.97, "%s: 공격 최저점 p=%.2f (0 근처)" % [label, am])
	if c.kind == "goblin":
		var hm := _argmin_tip(r, "hammer")
		check(hm <= 0.03 or hm >= 0.97, "%s: 망치 최저점 p=%.2f (0 근처)" % [label, hm])
		r.pose_hammer(0.0)
		var sp := r.skeleton.get_bone_pose_rotation(int(r._bi["Spine"])).get_euler()
		check(sp.x < -0.3, "%s: 망치질에서 허리를 굽힘" % label)
	# 7. 표정과 깜빡임
	r.pose_idle(0.0)
	r.update_blink(1.0)
	r.set_expression("normal")
	var a := r.posed_vertices()
	r.set_expression("angry")
	var b := r.posed_vertices()
	r.set_expression("hurt")
	var h := r.posed_vertices()
	check(_diff(a, b) > 0.05 and _diff(a, h) > 0.05 and _diff(b, h) > 0.05, "%s: 표정 변화 측정됨" % label)
	r.set_expression("normal")
	var blink_t := _blink_time(r)
	check(blink_t >= 0.0, "%s: 6초 안에 깜빡임" % label)
	r.update_blink(blink_t)
	var eye_s := r.skeleton.get_bone_pose_scale(int(r._bi["EyeL"])).y
	r.update_blink(blink_t + 1.0)
	var eye_o := r.skeleton.get_bone_pose_scale(int(r._bi["EyeL"])).y
	check(eye_s < 0.2 and eye_o > 0.9, "%s: 눈 깜빡임(눈알 높이 %.2f/%.2f)" % [label, eye_s, eye_o])
	# 8. 맞음·쓰러짐
	if c.kind != "goblin" and c.kind != "goblin_nh":
		r.pose_idle(0.0)
		var p0 := _local(r, r.joint_global_position("Head"))
		r.pose_hit(0.2)
		var p1 := _local(r, r.joint_global_position("Head"))
		r.pose_hit(1.0)
		var p2 := _local(r, r.joint_global_position("Head"))
		check(p1.z > p0.z + 0.03 and p2.distance_to(p0) < 0.01, "%s: 맞으면 뒤로 밀렸다 돌아옴" % label)
		r.pose_die(1.0)
		var top := _max_y(r)
		check(top < r.HEIGHT * 0.6 and _min_y(r) > -0.06, "%s: 쓰러짐(최고점 %.2f)" % [label, top])
		r.set_expression("normal")
	# 9. 예산
	var st := r.stats()
	check(int(st.triangles) <= int(c.budget), "%s: 삼각형 %d ≤ %d" % [label, st.triangles, c.budget])
	check(int(st.draw_calls) <= 16, "%s: 그리기 호출 %d" % [label, st.draw_calls])
	print("  %s: 삼각형 %d, 그리기 호출 %d, 뼈 %d, HEIGHT %.3f, hp_bar_y %.2f" % [label, st.triangles, st.draw_calls, st.bones, r.HEIGHT, r.hp_bar_y()])
	# 10. 2차 움직임(망토·깃털·귀)이 속도에 반응
	var sec := ""
	for n in ["Cape", "Plume", "EarR"]:
		if r.has_joint(n):
			sec = n
			break
	if sec != "":
		for i in 30:
			r.update_secondary(1.0 / 30.0, 0.0)
		var q0 := r.skeleton.get_bone_pose_rotation(int(r._bi[sec]))
		for i in 30:
			r.update_secondary(1.0 / 30.0, 1.0)
		var q1 := r.skeleton.get_bone_pose_rotation(int(r._bi[sec]))
		check(q0.angle_to(q1) > 0.05, "%s: %s 2차 움직임" % [label, sec])


func _argmin_tip(r: CharacterRig, what: String) -> float:
	var best := 99.0
	var arg := -1.0
	for i in 100:
		var p := i / 100.0
		if what == "attack":
			r.pose_attack(p)
		else:
			r.pose_hammer(p)
		var y := r.weapon_tip_global_position().y
		if y < best:
			best = y
			arg = p
	return arg


func _blink_time(r: CharacterRig) -> float:
	for i in 600:
		var t := i * 0.01
		r.update_blink(t)
		if r.skeleton.get_bone_pose_scale(int(r._bi["EyeL"])).y < 0.1:
			return t
	return -1.0


func _diff(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var s := 0.0
	for i in a.size():
		s += a[i].distance_to(b[i])
	return s


func _check_misc() -> void:
	# 기존 호출 이름 유지: Models.goblin()/knight() 는 CharacterRig 를 돌려준다
	var g := Models.goblin(true)
	check(g is CharacterRig, "Models.goblin() → CharacterRig")
	var k := Models.knight()
	check(k is CharacterRig, "Models.knight() → CharacterRig")
	var tower := Models.defense_tower()
	check(tower.has_node("Turret/Operator") and tower.get_node("Turret/Operator") is CharacterRig, "방어탑 Turret/Operator 는 CharacterRig")
	check(tower.has_node("Turret/Crossbow"), "방어탑 Turret/Crossbow 유지")
	g.free()
	k.free()
	tower.free()
	# 결정적: 같은 변형·같은 위상이면 같은 자세
	var a := CharacterRig.knight(2)
	var b := CharacterRig.knight(2)
	root.add_child(a)
	root.add_child(b)
	a.pose_walk(0.37)
	b.pose_walk(0.37)
	check(a.joint_global_position("HandR").is_equal_approx(b.joint_global_position("HandR")), "자세는 결정적")
	# 변형마다 모양이 다름
	var tris := {}
	for v in 5:
		var kv := CharacterRig.knight(v)
		tris[kv.stats().triangles] = true
		kv.free()
	check(tris.size() >= 3, "기사 변형 5종의 메시가 서로 다름")
	var gt := {}
	for v in 3:
		var gv := CharacterRig.goblin(v, true)
		gt[gv.stats().triangles] = true
		gv.free()
	check(gt.size() == 3, "고블린 변형 3종의 메시가 서로 다름")
	# 충격 감지 도우미
	check(CharacterRig.crossed_impact(0.95, 0.02) and not CharacterRig.crossed_impact(0.2, 0.4), "crossed_impact")
	check(CharacterRig.impact_index(1.0 / CharacterRig.HAMMER_RATE + 0.001) == 1, "impact_index")
	# 보스가 기사보다 크다
	var hero := CharacterRig.boss("hero")
	var cmd := CharacterRig.boss("commander")
	var kn := CharacterRig.knight(1)
	check(hero.HEIGHT > kn.HEIGHT + 0.05 and cmd.HEIGHT > kn.HEIGHT + 0.05, "보스가 기사보다 큼")
	hero.free()
	cmd.free()
	kn.free()
