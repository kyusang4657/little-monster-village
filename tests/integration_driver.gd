extends Node
## 실제 게임 장면(main.tscn)을 띄워 입력·미리보기·일시정지·UI 터치 분리를 확인한다.
## 실행: godot --headless --path . -- --integration --save-dir=user://itest/ --fresh --no-focus-pause

var main
var _pass := 0
var _fail := 0
var _lines: Array[String] = []


func run(p_main) -> void:
	main = p_main
	_sequence()


func check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		_lines.append("  ok   " + what)
	else:
		_fail += 1
		_lines.append("  FAIL " + what)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _scr(c: Vector2i) -> Vector2:
	return main.world.camera.unproject_position(WorldView.cell_center(c))


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e)
		await _wait(1)


func _drag(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = from
	get_viewport().push_input(e)
	for i in 13:
		var m := InputEventMouseMotion.new()
		m.position = from.lerp(to, i / 12.0)
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(m)
		await _wait(1)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = to
	get_viewport().push_input(u)
	await _wait(2)


func _buildings_named(id: String) -> int:
	var n := 0
	for c in main.world.get_node("Buildings").get_children():
		if String(c.name) == id and not c.is_queued_for_deletion():
			n += 1
	return n


func _sequence() -> void:
	await _wait(10)
	var s: GameState = main.state
	_lines.append("[통합 검사] 화면 %s" % str(get_viewport().get_visible_rect().size))

	# A01 화면 구성: 독립 노드
	check(main.world.get_node("Buildings").get_child_count() == 6, "A01 건물 6동이 개별 노드")
	check(s.mode == GameState.MODE_RAID_READY and s.wood >= 100, "A01 습격 준비·목재")

	# A02 실제 드래그 입력으로 이동 → 확정
	await _click(_scr(Vector2i(9, 4)))
	check(main.selected_id == "house_02", "탭으로 오른쪽 주택 선택")
	main._begin_move("house_02")
	await _wait(2)
	await _drag(_scr(Vector2i(9, 4)), _scr(Vector2i(10, 7)))
	check(main.edit.x == 10 and main.edit.z == 7, "A02 드래그로 미리보기 (10,7) (실제 %d,%d)" % [main.edit.x, main.edit.z])
	check(s.get_building("house_02").x == 9, "A02 확정 전 논리 좌표 불변")
	check(_buildings_named("house_02") == 1, "A02 같은 건물 한 개만 존재(복사본 없음)")
	main._rotate_edit()
	await _wait(2)
	var node: Node3D = main.world.building_node("house_02")
	check(node.position.is_equal_approx(WorldView.building_center("house", 10, 7)), "A02 미리보기 표시 위치 = 격자")
	main._confirm_edit()
	await _wait(2)
	var h: Dictionary = s.get_building("house_02")
	check(h.x == 10 and h.z == 7 and h.rot == 1, "A02 확정 후 좌표·방향")
	check(node.position.is_equal_approx(WorldView.building_center("house", 10, 7)) and is_equal_approx(node.rotation.y, WorldView.yaw_for_rot(1)), "A02 표시 = 논리")
	check(s.mode == GameState.MODE_RAID_READY, "편집 종료 후 RAID_READY 복귀")

	# A03 이동 취소 / 새 건설 취소
	main._begin_move("house_02")
	await _wait(1)
	main._move_ghost_to(Vector2i(11, 4))
	await _wait(1)
	main._cancel_edit()
	await _wait(2)
	h = s.get_building("house_02")
	check(h.x == 10 and h.z == 7 and h.rot == 1 and node.position.is_equal_approx(WorldView.building_center("house", 10, 7)), "A03 이동 취소 시 원래 위치·방향")
	var wood_before: int = s.wood
	main._begin_new("defense_tower")
	await _wait(2)
	check(main.world.get_node_or_null("Ghost") != null, "새 건설 미리보기 표시")
	main._cancel_edit()
	await _wait(2)
	check(s.count_type("defense_tower") == 2 and s.wood >= wood_before and main.world.get_node_or_null("Ghost") == null, "A03 새 건설 취소: 생성·차감 없음")

	# A12 편집 중 습격 시작 차단
	main._begin_move("house_01")
	await _wait(1)
	main._start_raid()
	await _wait(1)
	check(s.mode == GameState.MODE_BUILD and main.sim == null, "A12 편집 중 습격 시작 차단")
	check(main.hud.toast_panel.visible and main.hud.toast_label.text == "배치를 먼저 끝내세요", "A12 '배치를 먼저 끝내세요' 표시")
	main._cancel_edit()
	await _wait(1)

	# UI 위 입력은 마을로 전달되지 않음: 건설 버튼 아래에 건물이 있어도 선택되지 않음
	main._deselect()
	var btn: Button = main.hud.build_btn
	await _click(btn.get_global_rect().get_center())
	await _wait(2)
	check(main.hud.build_menu.visible and main.selected_id == "", "P05(에디터) UI 터치가 마을 선택으로 전달되지 않음")
	main.hud.hide_build_menu()

	# A20 전투 시작 직전 저장 = 준비 스냅샷
	main._start_raid()
	await _wait(2)
	check(s.mode == GameState.MODE_BATTLE and main.sim != null, "전투 시작")
	var snap := GameState.new()
	SaveManager.new(main.saver.dir).load_into(snap)
	check(snap.mode == GameState.MODE_RAID_READY and snap.ready_stage == 1 and snap.raid_ready and snap.last_resolved_battle_id < s.current_battle_id, "A20 전투 중 강제 종료 시 준비 상태로 복원")

	# A17 일시정지·백그라운드
	await _wait(30)
	main._pause_battle()
	var t0: float = main.sim.time
	var wood_p: int = s.wood
	await _wait(60)
	check(is_equal_approx(main.sim.time, t0) and s.wood == wood_p, "A17 일시정지 중 전투 시간·생산 정지")
	check(main.hud.overlay_visible(), "일시정지 화면")
	main._resume_battle()
	await _wait(10)
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _wait(2)
	var t1: float = main.sim.time
	check(s.mode == GameState.MODE_PAUSED, "A17 백그라운드 전환 시 일시정지")
	await _wait(60)
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _wait(20)
	check(is_equal_approx(main.sim.time, t1) and s.mode == GameState.MODE_PAUSED, "A17 복귀해도 자동 재개 안 함")
	main._resume_battle()
	await _wait(3)
	check(main.sim.time - t1 < 0.2, "A17 계속하기 후 경과 시간 몰아치기 없음 (%.3f초)" % (main.sim.time - t1))

	# 결과 1회 처리
	while main.sim != null and main.sim.outcome == "":
		main.sim.advance(0.1)
		await _wait(1)
	await _wait(3)
	check(s.mode == GameState.MODE_RESULT and main.hud.overlay_visible(), "결과 화면")
	var w_after: int = s.wood
	check(s.resolve_battle(s.last_resolved_battle_id, 1, true).applied == false and s.wood == w_after, "A21 같은 전투 결과 재처리 시 재지급 없음")
	main._on_result_closed("village")
	await _wait(3)
	await _wait(2)
	check(main.world.get_node("Battle").get_child_count() == 0, "결과 후 적·화살 정리")
	check(s.mode == GameState.MODE_VILLAGE and not s.raid_ready and s.ready_stage == 2, "승리 후 다음 예고 대기")

	await _construction_checks(s)

	_lines.append("RESULT: %d passed, %d failed" % [_pass, _fail])
	print("\n".join(_lines))
	get_tree().quit(1 if _fail > 0 else 0)


func _advance_village(seconds: float) -> void:
	var step := 1.0 / 30.0
	var t := 0.0
	while t < seconds:
		main.state.tick(step)
		main.world.update_village(main.state.buildings, main.state.all_edges(), step, true)
		t += step
	await _wait(2)


func _construction_checks(s: GameState) -> void:
	s.wood = 300
	main._begin_new("house")
	await _wait(1)
	main._move_ghost_to(Vector2i(12, 4))
	await _wait(1)
	main._confirm_edit()
	await _wait(2)
	var id := ""
	for b in s.buildings:
		if b.type == "house" and not s.is_built(b):
			id = b.id
	check(id != "", "공사 중 주택 생성")
	var node: Node3D = main.world.building_node(id)
	check(node != null and node.has_node("Scaffold") and node.get_node("Body").scale.y < 0.3, "비계 표시·몸체 낮음")
	var snap := GameState.new()
	SaveManager.new(main.saver.dir).load_into(snap)
	check(not snap.get_building(id).is_empty() and float(snap.get_building(id).build_left) > 9.0, "확정 직후 공사 상태 저장")
	await _advance_village(6.0)
	var at_site := false
	for w in main.world.crew.summary():
		if w.target == id and w.state == WorkerCrew.STATE_WORK:
			at_site = true
	check(at_site, "일꾼이 현장에 도착해 작업 중 %s" % str(main.world.crew.summary()))
	check(node.get_node("Body").scale.y > 0.4, "진행률만큼 몸체 상승")
	await _advance_village(5.0)
	check(s.is_built(s.get_building(id)), "10초 뒤 완성")
	await _wait(3)
	check(not node.has_node("Scaffold"), "완성 후 비계 제거")
	await _advance_village(8.0)
	var home := true
	for w in main.world.crew.summary():
		if w.target != "" or w.state == WorkerCrew.STATE_WORK:
			home = false
	check(home, "완성 후 일꾼 복귀")
