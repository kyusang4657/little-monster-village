extends Node
## 실제 실행 화면 캡처용 자동 진행(개발·검수 전용, 일반 실행에서는 불리지 않음).
## 실행: godot --path . -- --shots=<출력폴더> --save-dir=user://shots/ --fresh --no-focus-pause

var main
var out_dir := ""
var log_lines: Array[String] = []


func run(p_main, p_out: String, scenario: String = "full") -> void:
	main = p_main
	out_dir = p_out
	DirAccess.make_dir_recursive_absolute(out_dir)
	match scenario:
		"construction":
			_construction()
		"decor":
			_decor()
		"tutorial":
			_tutorial()
		"closeup":
			_closeup()
		"art":
			_art()
		_:
			_sequence()


## 마을 시간을 빠르게 진행(규칙·일꾼 모두 같은 경로로 갱신)
func _advance_village(seconds: float) -> void:
	var step := 1.0 / 30.0
	var t := 0.0
	while t < seconds:
		main.state.tick(step)
		main.world.update_village(main.state.buildings, main.state.all_edges(), step, true)
		t += step
	await _wait(2)


func _finish_log() -> void:
	var f := FileAccess.open(out_dir.path_join("shot-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	get_tree().quit()


func _construction() -> void:
	await _wait(20)
	var s: GameState = main.state
	s.wood = 300
	main._begin_new("house")
	await _wait(2)
	main._move_ghost_to(Vector2i(10, 7))
	await _wait(2)
	main._confirm_edit()
	await _wait(2)
	main._begin_new("defense_tower")
	await _wait(2)
	main._move_ghost_to(Vector2i(7, 2))
	await _wait(2)
	main._confirm_edit()
	await _wait(4)
	_log("구매 직후: %s" % str(main.world.crew.summary()))
	await _shot("20-construction-start")
	await _advance_village(4.0)
	_log("4초 뒤: %s" % str(main.world.crew.summary()))
	await _shot("21-construction-walking")
	await _advance_village(3.0)
	_log("7초 뒤: 주택 남은 %.1f, 탑 남은 %.1f / %s" % [s.get_building("house_03").build_left, s.get_building("tower_03").build_left, str(main.world.crew.summary())])
	await _shot("22-construction-hammering")
	var t3: Dictionary = s.get_building("tower_03")
	main._tap(main.world.camera.unproject_position(WorldView.building_center("defense_tower", t3.x, t3.z)))
	await _wait(4)
	await _shot("23-construction-info")
	main._deselect()
	await _advance_village(4.0)
	await _shot("24-house-complete")
	await _advance_village(10.0)
	_log("완성 후: 주택 %.1f 탑 %.1f / %s" % [s.get_building("house_03").build_left, s.get_building("tower_03").build_left, str(main.world.crew.summary())])
	await _advance_village(5.0)
	await _shot("25-all-complete")
	_finish_log()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	_log("캡처 %s (%dx%d)" % [name, img.get_width(), img.get_height()])


func _log(s: String) -> void:
	print("[SHOT] ", s)
	log_lines.append(s)


func _screen_of(world_pos: Vector3) -> Vector2:
	return main.world.camera.unproject_position(world_pos)


func _fast_battle(seconds: float) -> void:
	var t := 0.0
	while t < seconds and main.sim != null and main.sim.outcome == "":
		main.sim.advance(0.1)
		t += 0.1
	await _wait(2)


func _sequence() -> void:
	await _wait(20)
	var s: GameState = main.state
	_log("시작: 목재 %d, 모드 %s, 건물 %d" % [s.wood, s.mode, s.buildings.size()])
	await _shot("01-village")

	# 기존 오른쪽 주택 선택 → 정보 패널
	var h2: Dictionary = s.get_building("house_02")
	main._tap(_screen_of(WorldView.building_center("house", h2.x, h2.z)))
	await _wait(6)
	await _shot("02-select-house")

	# 실제 드래그 입력으로 주택 이동 미리보기
	main._begin_move("house_02")
	await _wait(2)
	var from := _screen_of(WorldView.cell_center(Vector2i(9, 4)))
	var to := _screen_of(WorldView.cell_center(Vector2i(10, 7)))
	main._pointer_down(from)
	for i in 11:
		main._pointer_move(from.lerp(to, i / 10.0))
		await _wait(1)
	main._pointer_up(to)
	await _wait(6)
	_log("이동 미리보기: (%d,%d) 확정상태 house_02=(%d,%d)" % [main.edit.x, main.edit.z, s.get_building("house_02").x, s.get_building("house_02").z])
	await _shot("03-build-move-valid")
	main._rotate_edit()
	await _wait(4)
	await _shot("04-build-move-rotated")
	# 겹치는 자리로 끌기 → 불가 이유
	main._move_ghost_to(Vector2i(4, 4))
	await _wait(4)
	await _shot("05-build-move-invalid")
	main._cancel_edit()
	await _wait(4)
	_log("취소 후 house_02=(%d,%d) rot %d, 주택 수 %d" % [s.get_building("house_02").x, s.get_building("house_02").z, s.get_building("house_02").rot, s.count_type("house")])

	# 건설 메뉴 → 새 방어탑 미리보기
	main._open_build_menu()
	await _wait(6)
	await _shot("06-build-menu")
	main._begin_new("defense_tower")
	await _wait(2)
	main._move_ghost_to(Vector2i(7, 2))
	await _wait(6)
	await _shot("07-build-new-tower")
	main._cancel_edit()
	await _wait(2)
	_log("새 탑 취소 후 탑 수 %d, 목재 %d" % [s.count_type("defense_tower"), s.wood])

	# 울타리 편집
	main._begin_fence()
	await _wait(2)
	var a := _screen_of(WorldView.W(10, 0, 3))
	var b := _screen_of(WorldView.W(13, 0, 3))
	main._pointer_down(a)
	for i in 11:
		main._pointer_move(a.lerp(b, i / 10.0))
		await _wait(1)
	main._pointer_up(b)
	await _wait(6)
	await _shot("08-fence-plan")
	main._cancel_edit()
	await _wait(2)

	# 방어탑 정보
	var t1: Dictionary = s.get_building("tower_01")
	main._tap(_screen_of(WorldView.building_center("defense_tower", t1.x, t1.z)))
	await _wait(6)
	await _shot("09-tower-info")
	main._deselect()

	# 1단계 전투
	main._start_raid()
	await _wait(2)
	await _fast_battle(9.0)
	for i in 30:
		await _wait(1)
	await _shot("10-battle")
	main._pause_battle()
	await _wait(4)
	await _shot("11-pause")
	main._resume_battle()
	await _fast_battle(400.0)
	for i in 10:
		await _wait(1)
	_log("1단계 결과: 목재 %d, 단계 %d, 남은 대기 %.1f" % [s.wood, s.ready_stage, s.raid_timer])
	await _shot("12-result-win")
	main._on_result_closed("village")
	await _wait(10)
	await _shot("13-village-timer")

	# 패배 예시: 2단계를 강화 없이 시작
	s.raid_timer = 0.01
	await _wait(5)
	main._start_raid()
	await _fast_battle(400.0)
	for i in 10:
		await _wait(1)
	await _shot("14-result-defeat")
	main._on_result_closed("village")
	await _wait(5)
	_log("패배 후: 목재 %d, 단계 %d, 준비 %s" % [s.wood, s.ready_stage, s.raid_ready])

	main.hud._show_menu()
	await _wait(4)
	await _shot("15-menu")
	main.hud.hide_overlay()

	var f := FileAccess.open(out_dir.path_join("shot-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	get_tree().quit()


func _decor() -> void:
	await _wait(20)
	var s: GameState = main.state
	main._select("house_01")
	await _wait(4)
	await _shot("30-house-info-decor-button")
	main._begin_decor("house_01")
	await _wait(4)
	await _shot("31-decor-panel-default")
	for pair in [["roof_color", "teal"], ["roof_shape", "steep"], ["window", "round"], ["chimney", "back_left"], ["flag", "star"]]:
		main._on_decor_option(pair[0], pair[1])
		await _wait(2)
	await _shot("32-decor-preview")
	main._confirm_edit()
	await _wait(4)
	_log("저장된 꾸미기: %s" % str(s.get_building("house_01").deco))
	main._begin_decor("house_02")
	await _wait(2)
	for pair in [["roof_color", "red"], ["roof_shape", "hip"], ["window", "arch"], ["flag", "moon"]]:
		main._on_decor_option(pair[0], pair[1])
		await _wait(2)
	main._confirm_edit()
	main._begin_decor("tower_02")
	await _wait(2)
	main._on_decor_option("flag_color", "teal")
	main._on_decor_option("emblem", "moon")
	await _wait(3)
	await _shot("33-decor-tower")
	main._confirm_edit()
	main._begin_decor("lumber_01")
	main._on_decor_option("roof_color", "green")
	main._confirm_edit()
	await _wait(2)
	main.world.reset_camera()
	await _wait(4)
	await _shot("34-decorated-village")
	_finish_log()


func _tutorial() -> void:
	await _wait(20)
	var tut: Tutorial = main.tutorial
	if not tut.active():
		tut.start()
	await _wait(4)
	await _shot("40-tutorial-welcome")
	tut.advance()
	await _wait(4)
	await _shot("41-tutorial-wood")
	tut.advance()
	await _wait(4)
	await _shot("42-tutorial-build-button")
	main._open_build_menu()
	await _wait(4)
	await _shot("43-tutorial-pick-house")
	main._begin_new("house")
	await _wait(4)
	await _shot("44-tutorial-place")
	main._confirm_edit()
	await _wait(4)
	await _shot("45-tutorial-construction")
	await _advance_village(12.0)
	await _wait(4)
	await _shot("46-tutorial-select-tower")
	main._select("tower_01")
	await _wait(4)
	await _shot("47-tutorial-upgrade")
	main._upgrade_selected()
	await _wait(4)
	await _shot("48-tutorial-start")
	_log("안내 단계: %s" % tut.current_id())
	main._start_raid()
	await _wait(3)
	_log("전투 시작 후 안내 활성: %s" % tut.active())
	await _fast_battle(9.0)
	for i in 20:
		await _wait(1)
	await _shot("49-battle-spread")
	await _fast_battle(400.0)
	for i in 6:
		await _wait(1)
	await _shot("50-result-with-advice")
	main._on_result_closed("village")
	await _wait(4)
	main.hud._show_menu()
	await _wait(4)
	await _shot("51-menu-audio")
	_finish_log()


func _focus(logical: Vector2, size: float) -> void:
	main.world.cam_target = WorldView.W(logical.x, 0, logical.y)
	main.world.cam_size = size
	main.world._apply_camera()
	await _wait(3)


func _closeup() -> void:
	await _wait(20)
	await _focus(Vector2(6.5, 6.5), 6.0)
	await _shot("60-close-castle-houses")
	await _focus(Vector2(3.0, 6.5), 4.0)
	await _shot("61-close-lumber-workers")
	main._start_raid()
	await _fast_battle(13.0)
	await _focus(Vector2(6.5, 3.5), 3.5)
	for i in 6:
		await _wait(1)
	await _shot("62-close-knights")
	await _focus(Vector2(4.0, 2.0), 3.5)
	await _shot("63-close-tower")
	_finish_log()


## 스토어·아이콘용: UI 를 숨기고 장면만 찍는다
func _art() -> void:
	await _wait(20)
	main.hud.visible = false
	main.tutorial.visible = false
	var s: GameState = main.state
	s.commit_decor("house_02", {roof_color = "teal"})
	main._sync_world()
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= vp.y * 1.2:
		# 정사각형: 아이콘(성 확대)
		await _focus(Vector2(6.5, 6.6), 4.4)
		await _shot("icon-raw")
	else:
		# 가로 대표 이미지: 전투 장면
		main._start_raid()
		await _fast_battle(12.5)
		await _focus(Vector2(6.8, 4.6), 9.5)
		for i in 8:
			await _wait(1)
		await _shot("feature-raw")
	_finish_log()
