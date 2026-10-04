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
	await _decor_checks(s)
	await _chapter_checks(s)
	await _review_ui_checks(s)
	await _tutorial_checks()

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


func _decor_checks(s: GameState) -> void:
	var before: Dictionary = s.get_building("house_01").deco.duplicate()
	main._begin_decor("house_01")
	await _wait(2)
	check(main.hud.decor_panel.visible and s.mode == GameState.MODE_BUILD, "꾸미기 패널 열림")
	main._on_decor_option("roof_color", "red")
	await _wait(2)
	check(s.get_building("house_01").deco == before, "미리보기는 확정 전 저장 안 됨")
	check(String(main.world.building_node("house_01").get_meta("deco_key")).contains("roof_color=red"), "미리보기 모델 교체")
	main._cancel_edit()
	await _wait(3)
	check(String(main.world.building_node("house_01").get_meta("deco_key")) == Decor.key(before), "취소 시 원래 외형")
	main._begin_decor("house_01")
	main._on_decor_option("window", "arch")
	main._confirm_edit()
	await _wait(2)
	var snap := GameState.new()
	SaveManager.new(main.saver.dir).load_into(snap)
	check(snap.get_building("house_01").deco.window == "arch", "완료 시 건물별 저장")
	main._begin_decor("castle_01")
	await _wait(1)
	check(main.edit.is_empty(), "성은 꾸미기 없음")


func _tutorial_checks() -> void:
	var tut: Tutorial = main.tutorial
	tut.start()
	await _wait(2)
	check(tut.active() and tut.current_id() == "welcome", "안내 시작")
	tut.advance()
	tut.advance()
	check(tut.current_id() == "open_build", "다음 버튼으로 진행")
	tut.notify("upgraded")
	check(tut.current_id() == "open_build", "기다리는 사건이 아니면 그대로")
	main._open_build_menu()
	await _wait(1)
	check(tut.current_id() == "pick", "건설 메뉴를 열면 다음 단계")
	main.hud.hide_build_menu()
	tut.end(true)
	await _wait(1)
	var cf := ConfigFile.new()
	cf.load(main.saver.dir + "settings.cfg")
	check(not tut.active() and bool(cf.get_value("progress", "tutorial_done", false)), "건너뛰기 후 완료 기록 저장")
	check(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0, "음악·효과음 버스")


## 3차: 성 레벨·땅 넓히기·앞마당·이야기 장면이 실제 화면 흐름에서 동작하는지
func _chapter_checks(s: GameState) -> void:
	s.highest_cleared = 6
	s.sync_castle_level()
	s.wood = int(GameConfig.economy().capacity)
	main._sync_world()
	await _wait(3)
	check(s.castle_level() == 3 and String(main.world.building_node(main._castle_id).get_meta("model_key")).contains("lv3"), "성 Lv.3 모델로 다시 조립")
	main._open_expand_menu()
	await _wait(2)
	check(main.hud.overlay_visible(), "땅 넓히기 방향 고르기 화면")
	main.hud.hide_overlay()
	main._begin_expand("east")
	await _wait(2)
	check(main.edit.get("kind", "") == "expand" and main.world._zone != null and main.world._zone.visible, "넓힐 땅 노란 표시")
	main._args.erase("no-story")
	main._confirm_edit()
	await _wait(3)
	check(s.expansions.has("east") and main.world.map_bounds == s.bounds() and s.bounds().size.x == 19, "동쪽 넓히기 후 지도 경계 %s" % str(s.bounds()))
	check(main.story_view.active() and main.story_view.current_id() == "first_expansion", "첫 넓히기 이야기 장면")
	var sel0: String = main.selected_id
	await _click(_scr(Vector2i(2, 2)))
	check(main.selected_id == sel0 and main.story_view.active(), "이야기 중 땅 입력 막음")
	for i in 8:
		if main.story_view.active():
			main.story_view.advance()
	await _wait(2)
	check(not main.story_view.active() and s.story_seen.has("first_expansion"), "장면 끝까지 넘기면 본 장면으로 저장")
	main._args["no-story"] = true
	# 넓힌 땅에 주택 짓기
	var houses := s.count_type("house")
	main._begin_new("house")
	main.edit.x = 15
	main.edit.z = 6
	main.edit.rot = 0
	main._update_edit()
	main._confirm_edit()
	await _wait(2)
	check(s.count_type("house") == houses + 1 and s.buildings.any(func(b): return b.type == "house" and int(b.x) == 15 and int(b.z) == 6), "넓힌 땅(15,6)에 주택 배치")
	var hid := ""
	for b in s.buildings:
		if b.type == "house" and int(b.x) == 15 and int(b.z) == 6:
			hid = String(b.id)
	await _advance_village(4.0)
	var going := false
	for w in main.world.crew.summary():
		if w.target == hid and w.state != WorkerCrew.STATE_IDLE:
			going = true
	check(going, "일꾼이 넓힌 땅 현장으로 감 %s" % str(main.world.crew.summary()))
	# 앞마당: 자원 지점으로 자동 이동
	main._begin_new("outpost")
	await _wait(1)
	check(int(main.edit.x) == 16 and int(main.edit.z) == 2, "앞마당은 숲 자원 지점에 놓임 (%d,%d)" % [int(main.edit.x), int(main.edit.z)])
	var rate0 := s.income_rate()
	main._confirm_edit()
	await _wait(2)
	var op := ""
	for b in s.buildings:
		if b.type == "outpost":
			op = String(b.id)
	check(op != "", "앞마당 공사 시작")
	await _advance_village(float(GameConfig.building_def("outpost").get("build_seconds", 25)) + 1.0)
	check(s.is_built(s.get_building(op)) and s.income_rate() > rate0, "앞마당 완성 후 생산 증가 (%.1f → %.1f)" % [rate0, s.income_rate()])
	# 점령 → 수리
	s.mark_outpost_lost(op)
	main._sync_world()
	await _wait(2)
	check(String(main.world.building_node(op).get_meta("model_key")).ends_with("|x") and s.income_rate() == rate0, "점령된 앞마당: 무너진 모습·생산만 멈춤")
	main._select(op)
	await _wait(1)
	main._upgrade_selected()
	await _wait(2)
	check(bool(s.get_building(op).get("repairing", false)), "수리 시작")
	await _advance_village(float(GameConfig.building_def("outpost").get("repair_seconds", 15)) + 1.0)
	main._sync_world()
	await _wait(2)
	check(not bool(s.get_building(op).get("damaged", false)) and not String(main.world.building_node(op).get_meta("model_key")).ends_with("|x"), "수리 완료 후 원래 모습")
	main._deselect()
	# 전투 중 점령 연출: 바로 무너진 모습, 저장 상태가 멀쩡하면 다음 동기화에서 원래 모습
	var toasted := [false]
	main.world.outpost_fell.connect(func(_id: String): toasted[0] = true, CONNECT_ONE_SHOT)
	main.world.update_battle(_fake_sim_with_event({type = "outpost_captured", outpost = op}, op), 0.016, main._castle_id)
	await _wait(2)
	check(String(main.world.building_node(op).get_meta("model_key")).ends_with("|x") and toasted[0], "전투 중 점령 즉시 무너진 모습·알림")
	main._sync_world()
	await _wait(2)
	check(not String(main.world.building_node(op).get_meta("model_key")).ends_with("|x"), "저장 상태 기준으로 다시 맞춤")
	# 이야기 다시 보기
	main._on_menu_action("story")
	await _wait(2)
	check(main.hud.overlay_visible(), "이야기 다시 보기 목록")
	main.hud.hide_overlay()
	main._replay_story("first_expansion")
	await _wait(1)
	check(main.story_view.active(), "본 장면 다시 재생")
	main.story_view._finish()
	await _wait(1)
	check(not main.story_view.active(), "건너뛰기로 닫힘")


func _fake_sim_with_event(e: Dictionary, outpost_id: String) -> BattleSim:
	var sim := BattleSim.new()
	sim.outpost = {id = outpost_id, hp = 0, max_hp = 150, captured = true}
	sim.events = [e]
	return sim


func _label_texts(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	for c in n.get_children():
		out += _label_texts(c)
	return out


## 3차 검토에서 나온 화면·흐름 문제 재발 방지
func _review_ui_checks(s: GameState) -> void:
	main._args.erase("no-story")
	main._deselect()
	await _wait(2)
	# 1) 장면이 이어지는 동안 다른 장면(앞마당 완성 등)이 와도 대기열을 덮지 않는다
	for id in ["ch1_end", "ch2_start", "outpost_built"]:
		s.story_seen.erase(id)
	var done := [false]
	main._queue_story(["chapter_end:1", "chapter_start:2"], func(): done[0] = true)
	await _wait(2)
	check(main.story_view.active() and main.story_view.current_id() == "ch1_end", "장 끝 장면 시작")
	main._queue_story(["outpost_built"])
	await _wait(1)
	check(main.story_view.current_id() == "ch1_end" and s.story_pending == ["chapter_end:1", "chapter_start:2", "outpost_built"], "비동기 장면은 뒤에 이어 붙음 %s" % str(s.story_pending))
	var snap := GameState.new()
	snap.from_dict(JSON.parse_string(FileAccess.get_file_as_string(main.saver.dir + "save.json")))
	check(snap.story_pending.has("chapter_start:2") and not snap.story_seen.has("ch1_end"), "대기 장면은 저장되고, 끝까지 보기 전에는 본 것으로 치지 않음")
	# 2) 뒤로 가기는 장면만 넘기고 아래 화면은 그대로
	main.selected_id = "house_01"
	var line0: int = main.story_view._line
	main._on_back()
	check(main.story_view._line == line0 + 1 and main.selected_id == "house_01", "뒤로 가기 = 장면 넘기기")
	main.selected_id = ""
	var guard := 0
	while main.story_view.active() and guard < 40:
		main.story_view.advance()
		guard += 1
		await _wait(1)
	check(done[0] and s.story_seen.has("ch1_end") and s.story_seen.has("ch2_start") and s.story_seen.has("outpost_built") and s.story_pending.is_empty(), "세 장면 모두 보고 이어서 콜백 실행")
	# 3) 창이 떠 있으면 장면은 기다렸다가 창이 닫히면 나온다
	s.story_seen.erase("outpost_lost")
	main.hud.show_dialog("시험", "창")
	main._queue_story(["outpost_lost"])
	await _wait(2)
	check(not main.story_view.active() and s.story_pending.has("outpost_lost"), "창이 떠 있으면 장면 대기")
	main.hud.hide_overlay()
	await _wait(3)
	check(main.story_view.active() and main.story_view.current_id() == "outpost_lost", "창을 닫으면 대기 장면 표시")
	# 4) 장면이 열리면 눌림 상태가 지워진다
	main.story_view._finish()
	await _wait(2)
	s.story_seen.erase("outpost_lost")
	main._pressing = true
	main._gesture = true
	main._queue_story(["outpost_lost"])
	await _wait(2)
	check(main.story_view.active() and not main._pressing and not main._gesture, "장면 시작 시 눌림·제스처 초기화")
	main.story_view._finish()
	await _wait(2)
	main._args["no-story"] = true
	# 5) 넓히기 미리보기 중 땅을 눌러도 편집이 그대로(오류 없음)
	s.wood = s.capacity()
	main._begin_expand("west")
	await _wait(2)
	var before_edit: Dictionary = main.edit.duplicate()
	main._tap(_scr(Vector2i(3, 3)))
	await _click(_scr(Vector2i(3, 3)))
	check(main.edit == before_edit, "넓히기 미리보기 중 땅 누르기 무시")
	main._cancel_edit()
	await _wait(2)
	# 6) 패배·마지막 단계 결과에도 덧붙인 줄이 보인다
	main.hud.show_result(false, "시험 습격", 0, 0, false, "", [], ["꼬블: 「힘내요!」"])
	await _wait(1)
	check(_label_texts(main.hud.overlay_box).contains("꼬블: 「힘내요!」"), "패배 결과에 촌장 격려")
	main.hud.show_result(true, "열 번째 습격", 160, 160, true, "", [], ["번쩍경: 「다음엔 꼭!」"])
	await _wait(1)
	check(_label_texts(main.hud.overlay_box).contains("번쩍경"), "최종 단계 결과에 기사단장 핑계")
	# 7) 긴 결과 창도 화면 안에 들어간다(넘치면 창 안에서 넘김)
	var many: Array = []
	for i in 12:
		many.append("긴 줄 %d: 성이 커지고 새로 여러 가지가 열렸어요" % i)
	main.hud.show_result(true, "세 번째 습격", 80, 80, false, "다음: 네 번째 습격", ["조언 하나", "조언 둘", "조언 셋"], many)
	await _wait(3)
	var vp := get_viewport().get_visible_rect().size
	check(main.hud.overlay_panel.get_global_rect().size.y <= vp.y and main.hud.overlay_panel.get_global_rect().position.y >= 0.0, "긴 결과 창 높이 %.0f ≤ 화면 %.0f" % [main.hud.overlay_panel.get_global_rect().size.y, vp.y])
	main.hud.hide_overlay()
	await _wait(1)
	# 8) 가장 긴 습격 안내도 목재 패널·메뉴 버튼과 겹치지 않는다
	var keep := [s.ready_stage, s.highest_cleared, s.assist_enabled, s.consecutive_losses]
	s.ready_stage = GameConfig.stage_count()
	s.highest_cleared = GameConfig.stage_count()
	s.assist_enabled = true
	s.consecutive_losses = 5
	s.raid_ready = true
	s.mode = GameState.MODE_RAID_READY
	main._last_ui = ""
	await _wait(3)
	var rp: Rect2 = main.hud.raid_panel.get_global_rect()
	var wpr: Rect2 = main.hud.wood_panel.get_global_rect()
	var mb: Rect2 = main.hud.menu_btn.get_global_rect()
	check(not rp.intersects(wpr) and not rp.intersects(mb), "긴 습격 안내가 목재·메뉴와 안 겹침 (%s / %s / %s)" % [str(rp), str(wpr), str(mb)])
	s.ready_stage = keep[0]
	s.highest_cleared = keep[1]
	s.assist_enabled = keep[2]
	s.consecutive_losses = keep[3]
	main._last_ui = ""
	# 10) 첫 실행 흐름: 프롤로그가 끝나야 안내가 시작된다
	main._args.erase("no-story")
	s.story_seen.erase("prologue")
	main._queue_story(["new_game"], func(): main.tutorial.start())
	await _wait(2)
	check(main.story_view.active() and main.story_view.current_id() == "prologue" and not main.tutorial.active(), "프롤로그 먼저, 안내는 아직")
	main.story_view._finish()
	await _wait(2)
	check(main.tutorial.active() and s.story_seen.has("prologue"), "프롤로그 뒤 안내 시작")
	main.tutorial.end(true)
	await _wait(1)
	main._args["no-story"] = true
	# 14) 외곽선 끄기·켜기(느린 기기용): 이미 있는 건물·캐릭터에도 바로 적용
	var cnode: Node3D = main.world.building_node(main._castle_id)
	var body := cnode.get_node("Body") as GeometryInstance3D
	check(body.material_overlay != null, "외곽선 기본 켬")
	main._on_menu_action("outlines")
	await _wait(1)
	check(body.material_overlay == null and not MeshBatch.outlines_on, "메뉴에서 외곽선 끄기")
	main._on_menu_action("outlines")
	await _wait(1)
	check(body.material_overlay != null, "다시 켜기")
	# 15) 뿔이: 성 레벨 모델, 누르면 한마디, 성이 자라면 결과·이야기 뒤 축하
	main._sync_world()
	await _wait(2)
	check(main.world.imp.level == s.castle_level() and main.world.imp.rig != null, "뿔이 모델 = 성 레벨 %d" % s.castle_level())
	await _advance_village(1.0)
	var ip: Vector2 = main.world.camera.unproject_position(main.world.imp.global_position + Vector3(0, 0.45, 0))
	main._tap(ip)
	check(main.world.imp._bubble.visible and main.world.imp._bubble.text != "", "뿔이를 누르면 한마디")
	main._celebrate_level = 4
	main._on_result_closed("village")
	await _wait(2)
	check(not main.world._fx.is_empty() and main.world.imp._cheer_t > 0.0, "성 레벨업 뒤 빛기둥·뿔이 환호")
	# 16) 유닛: 해골 막사 건설 → 훈련 버튼 → 시간 뒤 궁수, 집결 깃발 옮기기, 전투에 유닛 등장
	s.wood = s.capacity()
	main._begin_new("barracks")
	await _wait(1)
	main._confirm_edit()
	await _wait(1)
	var bk := ""
	for b in s.buildings:
		if b.type == "barracks":
			bk = String(b.id)
	check(bk != "", "해골 막사 건설")
	await _advance_village(float(GameConfig.building_def("barracks").build_seconds) + 1.0)
	main._select(bk)
	await _wait(1)
	check(main.hud.info_upgrade.visible and String((main.hud.info_upgrade.get_meta("label") as Label).text).contains("훈련"), "정보 창에 훈련 버튼")
	var a0 := int(s.units.archer)
	s.wood = s.capacity()
	main._upgrade_selected()
	await _advance_village(float(GameConfig.unit_def("archer").train_seconds) + 0.5)
	await _wait(2)
	check(int(s.units.archer) == a0 + 1, "훈련 버튼 → 궁수 1명 (%d → %d)" % [a0, int(s.units.archer)])
	check(main.world._unit_root.get_child_count() >= 1, "마을에 궁수가 보임")
	main._deselect()
	main._begin_rally()
	await _wait(1)
	var target := GameConfig.entry_cell_for(s.bounds()) + Vector2i(0, 2)
	main._tap(_scr(target))
	await _wait(1)
	main._confirm_edit()
	await _wait(2)
	check(s.rally == target and s.rally_cell() == target, "집결 깃발 옮기기 %s" % str(s.rally))
	# 9) 지도가 넓어지면 축소 한계도 넓어진다
	check(main.world.cam_max >= 20.0 * WorldView._map_grow(s.bounds()) - 0.01, "넓힌 지도 축소 한계 %.1f" % main.world.cam_max)
	# 11) 안내가 떠 있을 때 10단계 방어 시작: 안내를 끝내고 보스 장면 → 전투
	main._args.erase("no-story")
	s.story_seen.erase("boss_intro")
	var keep10 := [s.ready_stage, s.highest_cleared]
	s.ready_stage = GameConfig.stage_count()
	s.highest_cleared = GameConfig.stage_count() - 1
	s.raid_ready = true
	s.mode = GameState.MODE_RAID_READY
	main.tutorial.start()
	await _wait(1)
	main._start_raid()
	await _wait(2)
	check(not main.tutorial.active() and main.story_view.active() and main.story_view.current_id() == "boss_intro", "안내 중 방어 시작 → 안내 끝, 보스 장면")
	main.story_view._finish()
	await _wait(3)
	check(s.mode == GameState.MODE_BATTLE and main.sim != null, "보스 장면 뒤 바로 전투")
	main.sim.castle_hp = 0
	main.sim.advance(0.1)
	await _wait(4)
	main._on_result_closed("village")
	await _wait(3)
	s.ready_stage = keep10[0]
	s.highest_cleared = keep10[1]
	# 12) 새 게임: 옛 대기 장면은 버리고 안내 중이어도 프롤로그부터
	main.tutorial.start()
	s.story_pending.append("outpost_built")
	s.story_seen.erase("outpost_built")
	main._begin_new("house")
	await _wait(1)
	s.mode = GameState.MODE_BUILD
	main._on_menu_action("reset")
	await _wait(3)
	check(main.story_view.active() and main.story_view.current_id() == "prologue" and not main.tutorial.active(), "새 게임 → 옛 장면 없이 프롤로그")
	main.story_view._finish()
	await _wait(2)
	check(main.state.story_seen.keys() == ["prologue"] and main.state.story_pending.is_empty(), "새 게임 본 장면은 프롤로그뿐 %s" % str(main.state.story_seen.keys()))
	s = main.state
	# 13) --no-story 면 저장본에 남은 대기 장면도 띄우지 않음
	main._args["no-story"] = true
	s.story_pending.append("outpost_lost")
	await _wait(3)
	check(not main.story_view.active() and s.story_pending.is_empty(), "--no-story 는 대기 장면도 비움")
