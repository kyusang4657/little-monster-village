extends Node
## 실제 실행 화면 캡처용 자동 진행(개발·검수 전용, 일반 실행에서는 불리지 않음).
## 실행: godot --path . -- --shots=<출력폴더> --save-dir=user://shots/ --fresh --no-focus-pause

var main
var out_dir := ""
var log_lines: Array[String] = []


func run(p_main, p_out: String) -> void:
	main = p_main
	out_dir = p_out
	DirAccess.make_dir_recursive_absolute(out_dir)
	_sequence()


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
