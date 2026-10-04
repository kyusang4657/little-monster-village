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
		"chapter":
			_chapter()
		"perf":
			_perf()
		"perf_base":
			_perf_base()
		"imp":
			_imp_scene()
		"units":
			_units_scene()
		"showcase":
			_showcase()
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


func _set_level(cleared: int) -> void:
	main.state.highest_cleared = cleared
	main.state.ready_stage = mini(cleared + 1, GameConfig.stage_count())
	main.state.sync_castle_level()
	main._sync_world()
	await _wait(3)


func _skip_story() -> void:
	while main.story_view.active():
		main.story_view.advance()
	await _wait(2)


func _story_shot(name: String) -> void:
	await _wait(3)
	if main.story_view.active():
		await _shot(name)
		_log("이야기 장면 %s" % main.story_view.current_id())
	else:
		_log("이야기 장면 없음: %s" % name)


## 전투를 빨리 끝내 승리시킨다(캡처 전용: 기사를 바로 쓰러뜨림)
func _force_win() -> void:
	var guard := 0
	while main.sim != null and main.sim.outcome == "" and guard < 4000:
		for k in main.sim.knights:
			if k.alive:
				k.alive = false
				k.hp = 0
				main.sim.killed += 1
		main.sim.advance(0.25)
		guard += 1
	await _wait(6)


func _ready_raid(stage_id: int) -> void:
	var s: GameState = main.state
	s.ready_stage = stage_id
	s.raid_ready = true
	s.raid_timer = 0.0
	s.mode = GameState.MODE_RAID_READY
	main._last_ui = ""
	await _wait(3)


## 3차: 성 레벨, 땅 넓히기 전후, 앞마당, 이야기 장면, 장 해금 결과, 보스 전투
func _chapter() -> void:
	await _wait(20)
	var s: GameState = main.state
	main._args.erase("no-story")
	await _story_shot("80-story-prologue")
	await _skip_story()
	main.tutorial.end(true)
	await _wait(2)
	for lv in [1, 2, 3, 4]:
		await _set_level([0, 3, 6, 9][lv - 1])
		await _focus(Vector2(6.5, 7.0), 6.0)
		main.world.cam_target.y = 2.8
		main.world._apply_camera()
		await _wait(3)
		await _shot("7%d-castle-lv%d" % [lv - 1, lv])
	# 땅 넓히기 전후(성 Lv.3: 네 방향 모두 열림)
	await _set_level(6)
	main.world.reset_camera()
	await _wait(3)
	await _shot("74-expand-before")
	s.wood = s.capacity()
	main._open_expand_menu()
	await _wait(3)
	await _shot("75-expand-menu")
	main.hud.hide_overlay()
	main._begin_expand("east")
	await _wait(3)
	await _shot("76-expand-zone")
	main._confirm_edit()
	await _story_shot("81-story-first-expansion")
	await _skip_story()
	for dir in ["west", "north", "south"]:
		s.wood = s.capacity()
		main._begin_expand(dir)
		await _wait(2)
		main._confirm_edit()
		await _wait(2)
	_log("넓힌 지도 %s" % str(s.bounds()))
	main.world.reset_camera()
	await _wait(3)
	await _shot("77-expand-after")
	# 앞마당
	s.wood = s.capacity()
	main._begin_new("outpost")
	await _wait(2)
	main._confirm_edit()
	await _wait(2)
	await _advance_village(float(GameConfig.building_def("outpost").build_seconds) + 1.0)
	await _story_shot("82-story-outpost")
	await _skip_story()
	await _focus(Vector2(17.0, 3.0), 4.5)
	await _shot("78-outpost")
	var op := ""
	for b in s.buildings:
		if b.type == "outpost":
			op = String(b.id)
	s.mark_outpost_lost(op)
	main._sync_world()
	await _wait(3)
	await _shot("79-outpost-captured")
	main._select(op)
	await _wait(4)
	await _shot("79b-outpost-repair-panel")
	main._upgrade_selected()
	await _advance_village(float(GameConfig.building_def("outpost").repair_seconds) + 1.0)
	main._deselect()
	# 9단계 승리 → 성 Lv.4·3장 끝 결과
	await _set_level(8)
	main.world.reset_camera()
	await _ready_raid(9)
	main._start_raid()
	await _wait(3)
	await _force_win()
	await _shot("83-levelup-result")
	main._on_result_closed("village")
	await _story_shot("84-story-chapter3-end")
	main.story_view.advance()
	for i in 6:
		if main.story_view.active() and main.story_view.current_id() == "ch3_end":
			main.story_view.advance()
	await _story_shot("85-story-final-start")
	await _skip_story()
	# 보스 단계
	await _ready_raid(10)
	main._start_raid()
	await _story_shot("86-story-boss-intro")
	await _skip_story()
	await _wait(3)
	if main.sim != null:
		# 캡처 전용: 용사가 나올 때까지 성이 버티게 한다(표시 수치도 같이 맞춤)
		main.sim.castle_hp = 100000
		main.sim.castle_max = 100000
		var t := 0.0
		var hero_in := false
		while t < 200.0 and main.sim.outcome == "" and not hero_in:
			main.sim.advance(0.1)
			t += 0.1
			for k in main.sim.knights:
				if k.alive and String(k.get("kind", "")) == "hero":
					hero_in = true
		main.sim.advance(3.0)
		await _wait(4)
		var hero_pos := Vector2(6.5, 2.0)
		for k in main.sim.knights:
			if k.alive and String(k.get("kind", "")) == "hero":
				hero_pos = k.pos
		await _focus(hero_pos, 3.2)
		for i in 4:
			await _wait(1)
		await _shot("87-boss-battle")
		main.world.reset_camera()
		await _wait(3)
		await _shot("88-boss-battle-wide")
		await _force_win()
		await _shot("89-ending-result")
		main._on_result_closed("village")
		await _story_shot("90-story-ending")
		await _skip_story()
	_finish_log()


## 가장 무거운 화면 측정: 최대 지도(24×18)·성 Lv.4·건물 한도·10단계 용사 파티(16명) + 일꾼 2 + 탑 조작수 6.
## 데스크톱 Xvfb + 소프트웨어 렌더러 수치이며 휴대폰 측정이 아니다.
func _build_max_village() -> void:
	var s: GameState = main.state
	await _set_level(9)
	for dir in ["east", "west", "north", "south"]:
		s.wood = s.capacity()
		s.commit_expand(dir)
	main._sync_world()
	var gate := GameConfig.entry_cell_for(s.bounds())
	for type in ["defense_tower", "defense_tower", "defense_tower", "defense_tower", "lumber_camp", "outpost"]:
		main.world.cam_target = WorldView.W(gate.x + 0.5, 0, gate.y + 4.0)
		s.wood = s.capacity()
		var c: Vector2i = main._find_spot(type)
		var r := s.commit_new_building(type, c.x, c.y, 0)
		_log("%s (%d,%d) %s" % [type, c.x, c.y, "ok" if r.ok else String(r.reason)])
	for type in ["house", "house", "house", "house", "house", "house", "flowerbed", "flowerbed", "flowerbed", "lantern", "lantern", "lantern"]:
		main.world.cam_target = WorldView.W(6.5, 0, 9.0)
		s.wood = s.capacity()
		var c: Vector2i = main._find_spot(type)
		s.commit_new_building(type, c.x, c.y, 0)
	for b in s.buildings:
		b.build_left = 0.0
		if b.type == "defense_tower":
			b.level = 3
	main._sync_world()
	_log("건물 %d동, 지도 %s" % [s.buildings.size(), str(s.bounds())])
	await _wait(5)


func _measure(label: String, seconds: float) -> void:
	var frames := 0
	var worst := 0.0
	var t := 0.0
	var max_calls := 0
	var max_tris := 0
	var max_chars := 0
	var last := Time.get_ticks_usec()
	while t < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		t += dt
		frames += 1
		worst = maxf(worst, dt)
		max_calls = maxi(max_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		max_tris = maxi(max_tris, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		if main.sim != null:
			max_chars = maxi(max_chars, main.sim.alive_knights().size())
	_log("[성능] %s: 평균 %.1f FPS, 최악 프레임 %.0fms, 그리기 호출 최대 %d, 삼각형 최대 %d, 동시 적 최대 %d (%.1f초, %d프레임)" % [label, frames / maxf(t, 0.001), worst * 1000.0, max_calls, max_tris, max_chars, t, frames])


func _perf() -> void:
	await _wait(20)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _skip_story()
	main.tutorial.end(true)
	await _build_max_village()
	main.world.reset_camera()
	await _wait(5)
	_tri_report(main.world)
	await _measure("마을(최대 지도, 일꾼 2)", 5.0)
	await _shot("95-perf-village")
	await _ready_raid(10)
	main._start_raid()
	await _skip_story()
	await _wait(2)
	if main.sim == null:
		_log("전투 시작 실패")
		_finish_log()
		return
	main.sim.castle_hp = 100000
	main.sim.castle_max = 100000
	# 16명이 모두 살아 있는 상태로 측정(탑 사격은 끄고 화면 부하만 잰다)
	var towers: Array = main.sim.towers
	main.sim.towers = []
	var guard := 0
	while main.sim.spawned < main.sim.total and guard < 3000:
		main.sim.advance(0.1)
		guard += 1
	main.sim.towers = towers
	for k in main.sim.knights:
		k.hp = k.max_hp * 50
		k.max_hp = k.max_hp * 50
	await _wait(3)
	await _measure("10단계 전투, 그림자 켬", 10.0)
	await _shot("96-perf-battle")
	main.world.set_shadows(false)
	await _measure("10단계 전투, 그림자 끔", 10.0)
	main.world.set_outlines(false)
	await _measure("10단계 전투, 그림자·외곽선 끔", 10.0)
	main.world.set_outlines(true)
	main.world.set_shadows(true)
	_finish_log()


func _tris_of(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		var m: Mesh = (n as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				t += (idx as PackedInt32Array).size() / 3
			else:
				t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		var per := 0
		for si in mm.mesh.get_surface_count():
			var arr := mm.mesh.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			per += ((idx as PackedInt32Array).size() if idx != null and (idx as PackedInt32Array).size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		t += per * mm.instance_count
	for c in n.get_children():
		t += _tris_of(c)
	return t


func _tri_report(root: Node) -> void:
	for c in root.get_children():
		var t := _tris_of(c)
		if t > 2000:
			_log("  삼각형 %s: %d" % [c.name, t])
			if t > 20000:
				for cc in c.get_children():
					var t2 := _tris_of(cc)
					if t2 > 3000:
						_log("    - %s: %d" % [cc.name, t2])


## 같은 조건 비교용(이전 버전과 동일 코드): 처음 배치 마을 5초 + 9단계 기사 16명 전투 10초
func _pbm(label: String, seconds: float) -> void:
	var frames := 0
	var worst := 0.0
	var t := 0.0
	var max_calls := 0
	var max_tris := 0
	var max_k := 0
	var last := Time.get_ticks_usec()
	while t < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		t += dt
		frames += 1
		worst = maxf(worst, dt)
		max_calls = maxi(max_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		max_tris = maxi(max_tris, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		if main.sim != null:
			max_k = maxi(max_k, main.sim.alive_knights().size())
	_log("[성능비교] %s: 평균 %.1f FPS, 최악 %.0fms, 그리기 호출 최대 %d, 삼각형 최대 %d, 동시 기사 %d" % [label, frames / maxf(t, 0.001), worst * 1000.0, max_calls, max_tris, max_k])


func _perf_base() -> void:
	await _wait(20)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if main.get("story_view") != null:
		while main.story_view.active():
			main.story_view.advance()
	main.tutorial.end(true)
	main.world.reset_camera()
	await _wait(10)
	await _pbm("처음 배치 마을", 5.0)
	var s = main.state
	s.ready_stage = 9
	s.raid_ready = true
	s.mode = GameState.MODE_RAID_READY
	main._start_raid()
	await _wait(2)
	main.sim.castle_hp = 100000
	main.sim.towers = []
	var guard := 0
	while main.sim.spawned < main.sim.total and guard < 3000:
		main.sim.advance(0.1)
		guard += 1
	await _wait(3)
	await _pbm("9단계 전투(그림자 켬)", 10.0)
	await _shot("97-perf-base-battle")
	main.world.set_shadows(false)
	await _pbm("9단계 전투(그림자 끔)", 10.0)
	main.world.set_outlines(false)
	await _pbm("9단계 전투(그림자·외곽선 끔)", 10.0)
	main.world.set_outlines(true)
	_finish_log()


## 뿔이 마을 상주: 산책, 누르면 한마디, 성 레벨업 연출, 이야기 얼굴
func _imp_scene() -> void:
	await _wait(20)
	var imp = main.world.imp
	await _advance_village(3.0)
	await _focus(imp.pos, 4.0)
	await _shot("100-imp-village")
	var tp: Vector2 = main.world.camera.unproject_position(imp.global_position + Vector3(0, 0.45, 0))
	_log("뿔이 화면 위치 %s, 판정 %s" % [str(tp), str(imp.hit(main.world.camera, tp))])
	main._tap(tp)
	_log("말풍선 %s '%s'" % [str(imp._bubble.visible), imp._bubble.text])
	await _focus(imp.pos, 3.2)
	await _shot("101-imp-tap")
	await _set_level(3)
	await _focus(Vector2(6.5, 7.5), 9.0)
	main.world.levelup_fx(main._castle_id, 3)
	_log("연출 %d개" % main.world._fx.size())
	imp.celebrate(Story.imp_levelup_line(3))
	await _wait(3)
	await _shot("102-levelup-fx")
	main._args.erase("no-story")
	main._replay_story("prologue")
	main.story_view.advance()
	await _wait(3)
	await _shot("103-story-imp-portrait")
	_finish_log()


## 4차 유닛: 막사·훈련장·유닛 줄·건설 메뉴·훈련 창·전투
func _units_scene() -> void:
	await _wait(20)
	var s: GameState = main.state
	await _set_level(3)
	# 막사·훈련장만 짓고(주택을 더 지으면 유닛이 집 사이에 가려진다) 유닛 수는 직접 넣는다
	for t in ["barracks", "training_ground"]:
		s.wood = s.capacity()
		main.world.cam_target = WorldView.W(10.0, 0, 6.0)
		var c: Vector2i = main._find_spot(t)
		s.commit_new_building(t, c.x, c.y, 0)
	for b in s.buildings:
		b.build_left = 0.0
	s.units = {archer = 3, orc = 3}
	s.commit_rally(GameConfig.entry_cell_for(s.bounds()) + Vector2i(0, 3))
	main._sync_world()
	await _wait(5)
	main.world.reset_camera()
	await _wait(3)
	await _shot("110-units-village")
	main._open_build_menu()
	await _wait(3)
	await _shot("111-build-menu-units")
	main.hud.hide_build_menu()
	var bk := ""
	for b in s.buildings:
		if b.type == "barracks":
			bk = String(b.id)
	main._select(bk)
	await _wait(3)
	await _focus(Vector2(float(s.get_building(bk).x) + 1.0, float(s.get_building(bk).z)), 5.0)
	await _shot("112-barracks-train")
	main._deselect()
	await _ready_raid(4)
	main._start_raid()
	await _wait(2)
	if main.sim != null:
		main.sim.castle_hp = 100000
		main.sim.castle_max = 100000
		var guard := 0
		var fighting := false
		while guard < 2000 and main.sim.outcome == "" and not fighting:
			main.sim.advance(0.1)
			guard += 1
			for d in main.sim.defenders:
				if d.kind == "orc" and not (d.blocking as Array).is_empty():
					fighting = true
		await _wait(4)
		var r := s.rally_cell()
		await _focus(Vector2(r.x + 0.5, r.y + 0.8), 4.2)
		await _wait(3)
		await _shot("113-units-battle")
	_finish_log()


## 5차: 새 캐릭터를 게임 화면에서 — 마을의 뿔이·일꾼, 유닛 집결, 기사 여러 종류의 전투, 보스 전투, 이야기 창 얼굴
func _showcase() -> void:
	await _wait(20)
	var s: GameState = main.state
	main.tutorial.end(true)
	await _advance_village(2.0)
	var imp = main.world.imp
	await _focus(imp.pos, 3.6)
	await _shot("120-village-imp")
	var tp: Vector2 = main.world.camera.unproject_position(imp.global_position + Vector3(0, 0.45, 0))
	main._tap(tp)
	await _wait(10)
	await _shot("121-village-imp-tap")
	# 일꾼 공사 현장
	s.wood = s.capacity()
	main.world.cam_target = WorldView.W(6.5, 0, 6.0)
	var hc: Vector2i = main._find_spot("house")
	s.commit_new_building("house", hc.x, hc.y, 0)
	await _advance_village(5.0)
	await _focus(Vector2(float(hc.x) + 0.5, float(hc.y) + 0.8), 4.0)
	await _shot("122-village-workers")
	# 유닛: 성 Lv.3, 막사·훈련장, 궁수 3·오크 3 집결
	await _set_level(6)
	# 막사·훈련장만 짓고(주택을 더 지으면 유닛이 집 사이에 가려진다) 유닛 수는 직접 넣는다
	for t in ["barracks", "training_ground"]:
		s.wood = s.capacity()
		main.world.cam_target = WorldView.W(10.0, 0, 6.0)
		var c: Vector2i = main._find_spot(t)
		s.commit_new_building(t, c.x, c.y, 0)
	for b in s.buildings:
		b.build_left = 0.0
	s.units = {archer = 3, orc = 3}
	s.commit_rally(GameConfig.entry_cell_for(s.bounds()) + Vector2i(0, 3))
	main._sync_world()
	await _wait(5)
	# 마을에서 유닛은 막사·훈련장 앞에 서 있다
	var bx := 6.5
	var bz := 6.0
	for b in s.buildings:
		if b.type == "barracks":
			bx = float(b.x) + 1.0
			bz = float(b.z) - 0.3
	await _focus(Vector2(bx, bz), 4.2)
	await _shot("123-units-barracks")
	# 7단계 전투: 기사 여러 변형이 정문을 지나 길 위에 있을 때
	await _ready_raid(7)
	main._start_raid()
	await _wait(2)
	if main.sim != null:
		main.sim.castle_hp = 100000
		main.sim.castle_max = 100000
		await _fast_battle(14.0)
		var cen := Vector2.ZERO
		var n := 0
		for k in main.sim.knights:
			if k.alive:
				cen += k.pos
				n += 1
		if n > 0:
			cen /= float(n)
		await _focus(cen, 3.4)
		for i in 4:
			await _wait(1)
		await _shot("124-battle-knights")
		await _force_win()
		main._on_result_closed("village")
		await _wait(3)
	# 보스 전투: 용사가 나올 때까지 버틴 뒤 용사·기사단장 근접
	await _set_level(9)
	main.world.reset_camera()
	await _ready_raid(10)
	main._start_raid()
	await _skip_story()
	await _wait(3)
	if main.sim != null:
		main.sim.castle_hp = 100000
		main.sim.castle_max = 100000
		var t := 0.0
		var hero_in := false
		while t < 200.0 and main.sim.outcome == "" and not hero_in:
			main.sim.advance(0.1)
			t += 0.1
			for k in main.sim.knights:
				if k.alive and String(k.get("kind", "")) == "hero":
					hero_in = true
		main.sim.advance(6.0)
		await _wait(4)
		var hero_pos := Vector2(6.5, 2.0)
		for k in main.sim.knights:
			if k.alive and String(k.get("kind", "")) == "hero":
				hero_pos = k.pos
		await _focus(hero_pos, 3.4)
		for i in 4:
			await _wait(1)
		await _shot("125-boss-battle")
		await _force_win()
		main._on_result_closed("village")
		await _wait(3)
	# 이야기 창: 뿔이·기사단장·용사가 말하는 줄에서 얼굴 캡처
	main._args.erase("no-story")
	main.world.reset_camera()
	if main.story_view.play(Story.scene_by_id("boss_intro")):
		var seen := {}
		for i in 12:
			if not main.story_view.active():
				break
			var ln: Dictionary = (main.story_view._scene.lines as Array)[main.story_view._line]
			var who := String(ln.get("who", ""))
			if who in ["imp", "commander", "hero"] and not seen.has(who):
				seen[who] = true
				await _wait(3)
				await _shot("126-story-" + who)
			main.story_view.advance()
		await _skip_story()
	_finish_log()
