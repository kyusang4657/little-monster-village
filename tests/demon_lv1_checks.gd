extends SceneTree
## 악마형 마왕 교체 후보(Lv.1~4) 리그 검사(헤드리스): godot --headless --path . --script res://tests/demon_lv1_checks.gd
## character_checks.gd 와 같은 기준(관절, 발 높이, 정면, 무기 손, 걷기 접지·무릎, 표정·깜빡임, 2차 움직임, 예산)을 후보 네 레벨과 기존 뿔이 Lv.1에 같이 적용한다.
## 기존 뿔이는 모델 세트 기본값과 무관하게 ImpBuilder.build(1) 로 직접 만든다.
## 뿔이는 쓰러지지 않지만(게임에서 pose_die 를 쓰지 않음) 환호·무서운 척 자세에서도 발이 땅 아래로 내려가지 않는지 본다.

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("  실패: " + what)


func _run() -> void:
	var budget := int(GameConfig.defaults().get("performance_targets", {}).get("budgets", {}).get("imp_triangles_max", 6000))
	var cases: Array = [
		{rig = CharacterRig._instance(ImpBuilder.build(1), "imp", 1, 1.0), label = "old-imp1"},
	]
	for lv in range(1, 5):
		cases.append({rig = CharacterRig._instance(DemonBuilder.build(lv), "imp", lv, 1.0), label = "demon-lv%d" % lv})
	for c in cases:
		root.add_child(c.rig)
	for c in cases:
		_check_rig(c.rig, c.label, budget)
	# 결정적: 같은 입력이면 같은 메시·같은 자세
	var a := CharacterRig._instance(DemonBuilder.build(1), "imp", 1, 1.0)
	var b := CharacterRig._instance(DemonBuilder.build(1), "imp", 1, 1.0)
	root.add_child(a)
	root.add_child(b)
	a.pose_walk(0.37)
	b.pose_walk(0.37)
	check(a.stats().triangles == b.stats().triangles and a.joint_global_position("HandR").is_equal_approx(b.joint_global_position("HandR")), "후보: 결정적 메시·자세")
	print("RESULT: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _local(r: CharacterRig, p: Vector3) -> Vector3:
	return r.global_transform.affine_inverse() * p


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


func _diff(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var s := 0.0
	for i in a.size():
		s += a[i].distance_to(b[i])
	return s


func _check_rig(r: CharacterRig, label: String, budget: int) -> void:
	for j in CharacterRig.REQUIRED_JOINTS:
		check(r.has_joint(j), "%s: 관절 %s" % [label, j])
	for j in CharacterRig.FACE_BONES:
		check(r.has_joint(j), "%s: 얼굴 뼈 %s" % [label, j])
	check(r.has_joint("Cape"), "%s: 망토 뼈(2차 움직임)" % label)
	r.pose_idle(0.0)
	var low := _min_y(r)
	check(absf(low) <= 0.03, "%s: 가장 낮은 정점 y=%.3f (±0.03)" % [label, low])
	check(r.HEIGHT >= 0.85 and r.HEIGHT <= 1.0, "%s: HEIGHT %.3f (0.85~1.0)" % [label, r.HEIGHT])
	check(_max_y(r) >= r.HEIGHT - 0.001, "%s: 정점 최고점이 HEIGHT 이상" % label)
	var head_z := _local(r, r.joint_global_position("Head")).z
	var pupil_z := _local(r, r.joint_global_position("PupilL")).z
	check(pupil_z < head_z - 0.05, "%s: 얼굴이 -Z 를 봄 (동공 z %.3f, 머리 z %.3f)" % [label, pupil_z, head_z])
	var hand_r := _local(r, r.joint_global_position("HandR"))
	var hand_l := _local(r, r.joint_global_position("HandL"))
	check(hand_r.x > 0.05 and hand_l.x < -0.05, "%s: HandR +X, HandL -X" % label)
	var tip := _local(r, r.weapon_tip_global_position())
	check(tip.x > 0.05, "%s: 가리키는 손(tip) +X (x=%.2f)" % [label, tip.x])
	# 걷기: 접지·몸 위아래·무릎
	var lows: Array = []
	var pel: Array = []
	for i in 16:
		r.pose_walk(i / 16.0)
		lows.append(_min_y(r))
		pel.append(_local(r, r.joint_global_position("Pelvis")).y)
	check(float(lows.min()) >= -0.03 and float(lows.max()) <= 0.035, "%s: 걷기 발 디딤 %.3f~%.3f" % [label, lows.min(), lows.max()])
	check(float(pel.max()) - float(pel.min()) > 0.005, "%s: 걷기 몸 위아래" % label)
	var bend := 0.0
	for i in 8:
		r.pose_walk(i / 8.0)
		var knee := _local(r, r.joint_global_position("ShinL"))
		var hip := _local(r, r.joint_global_position("LegL"))
		var ankle := _local(r, r.joint_global_position("FootL"))
		bend = maxf(bend, (knee - hip).normalized().angle_to((ankle - knee).normalized()))
	check(bend > 0.6, "%s: 걷기 무릎 굽힘 %.2f" % [label, bend])
	# 환호·무서운 척: 발이 땅 아래로 내려가지 않음
	var cheer_low := 99.0
	for i in 8:
		r.pose_cheer(i / 8.0)
		cheer_low = minf(cheer_low, _min_y(r))
	check(cheer_low >= -0.03, "%s: 환호 중 최저점 %.3f" % [label, cheer_low])
	var scare_low := 99.0
	for i in 8:
		r.pose_scare(i / 7.0)
		scare_low = minf(scare_low, _min_y(r))
	# 무서운 척은 공통 자세가 몸 전체를 좌우로 기울여(Root 회전) 바깥 장화 모서리가 조금 내려간다(후보 약 4cm)
	check(scare_low >= -0.05, "%s: 무서운 척 중 최저점 %.3f" % [label, scare_low])
	# 표정·깜빡임
	r.pose_idle(0.0)
	r.update_blink(1.0)
	r.set_expression("normal")
	var a := r.posed_vertices()
	r.set_expression("angry")
	var b := r.posed_vertices()
	r.set_expression("hurt")
	var h := r.posed_vertices()
	r.set_expression("happy")
	var hp := r.posed_vertices()
	check(_diff(a, b) > 0.05 and _diff(a, h) > 0.05 and _diff(b, h) > 0.05 and _diff(a, hp) > 0.05, "%s: 표정 변화 측정됨" % label)
	r.set_expression("normal")
	var blink_t := -1.0
	for i in 600:
		r.update_blink(i * 0.01)
		if r.skeleton.get_bone_pose_scale(int(r._bi["EyeL"])).y < 0.1:
			blink_t = i * 0.01
			break
	check(blink_t >= 0.0, "%s: 6초 안에 깜빡임" % label)
	# 2차 움직임(망토)
	for i in 30:
		r.update_secondary(1.0 / 30.0, 0.0)
	var q0 := r.skeleton.get_bone_pose_rotation(int(r._bi["Cape"]))
	for i in 30:
		r.update_secondary(1.0 / 30.0, 1.0)
	var q1 := r.skeleton.get_bone_pose_rotation(int(r._bi["Cape"]))
	check(q0.angle_to(q1) > 0.05, "%s: 망토 2차 움직임" % label)
	# 예산
	var st := r.stats()
	check(int(st.triangles) <= budget, "%s: 삼각형 %d ≤ %d" % [label, st.triangles, budget])
	check(int(st.draw_calls) == 1, "%s: 그리기 호출 %d" % [label, st.draw_calls])
	print("  %s: 삼각형 %d, 그리기 호출 %d, 뼈 %d, HEIGHT %.3f, hp_bar_y %.2f, 정점 %d" % [label, st.triangles, st.draw_calls, st.bones, r.HEIGHT, r.hp_bar_y(), (r._def.verts as PackedVector3Array).size()])
