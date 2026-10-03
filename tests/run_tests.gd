extends SceneTree
## 헤드리스 자동 검사:  godot --headless --path . --script res://tests/run_tests.gd
## 결과가 중요한 규칙(배치 원자성·경로·비용/보상 중복·저장 복원·전투 수치)을 확인한다.

var _pass := 0
var _fail := 0
var _report: Array[String] = []


func _init() -> void:
	var tests := [
		"test_initial_layout", "test_move_and_cancel_atomic", "test_invalid_placements",
		"test_purchase_limits_and_cost", "test_upgrade", "test_fences", "test_route_blocking_examples",
		"test_production_states", "test_raid_timer_and_build", "test_reward_once",
		"test_save_roundtrip_and_recovery", "test_unsaved_preview_not_persisted",
		"test_battle_stage1_default_win", "test_battle_loss_layout", "test_battle_upgrade_effect",
		"test_battle_bolts_and_counts", "test_battle_stages_2_3_reachable", "test_watchdog_and_long_route",
		"test_battle_pause_no_catchup",
		"test_construction_basic", "test_construction_battle_and_rules", "test_save_v2_and_migration",
		"test_decor", "test_assist_mode", "test_knight_spread", "test_advisor", "test_stage_curve",
		"test_castle_levels", "test_boss_units", "test_expansion", "test_resource_sites_and_props",
		"test_outpost_battle", "test_outpost_repair", "test_save_v3_migration", "test_story_data",
	]
	for t in tests:
		var before := _fail
		var checks := _pass + _fail
		call(t)
		if _pass + _fail == checks:
			_fail += 1
			printerr("  실패: %s 가 끝까지 실행되지 않음(스크립트 오류)" % t)
		_report.append("%s %s" % ["PASS" if _fail == before else "FAIL", t])
	print("\n".join(_report))
	print("RESULT: %d checks passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("  실패: " + what)


func fresh() -> GameState:
	var s := GameState.new()
	s.new_game()
	return s


func test_initial_layout() -> void:
	var s := fresh()
	check(s.buildings.size() == 6, "건물 6동")
	check(s.count_type("castle") == 1 and s.count_type("house") == 2 and s.count_type("lumber_camp") == 1 and s.count_type("defense_tower") == 2, "종류별 수")
	check(s.wood == 100, "시작 목재 100")
	check(s.mode == GameState.MODE_RAID_READY and s.ready_stage == 1, "최초 습격 준비")
	check(GridLogic.fixed_edges().size() == 46, "외곽 울타리 46변")
	var gates := GridLogic.gate_edges()
	check(gates.size() == 2 and not GridLogic.fixed_edges().has(gates[0]) and not GridLogic.fixed_edges().has(gates[1]), "정문 2변 열림")
	var occ := GridLogic.occupancy(s.buildings)
	check(occ.size() == 29, "점유 29칸 겹침 없음")
	check(not GridLogic.find_route(s.buildings, s.all_edges()).is_empty(), "초기 경로 존재")
	check(s.get_building("castle_01").x == 5 and s.get_building("castle_01").z == 6, "성 좌표")


func test_move_and_cancel_atomic() -> void:
	var s := fresh()
	var before := JSON.stringify(s.to_dict())
	# 미리보기 검증만으로는 상태가 바뀌지 않는다
	var v := s.check_move("house_02", 10, 7, 1)
	check(v.ok, "주택 (10,7) 이동 가능: %s" % v.reason)
	check(JSON.stringify(s.to_dict()) == before, "검증은 상태 불변")
	var r := s.commit_move("house_02", 10, 7, 1)
	check(r.ok, "이동 확정")
	var h := s.get_building("house_02")
	check(h.x == 10 and h.z == 7 and h.rot == 1, "좌표·회전 반영")
	check(s.count_type("house") == 2 and s.wood == 100, "복사본 없음·이동 무료")
	check(s.building_at(Vector2i(9, 4)).is_empty(), "원래 자리 비움")
	# 성 이동 불가
	check(not s.check_move("castle_01", 1, 1, 0).ok, "성 고정")


func test_invalid_placements() -> void:
	var s := fresh()
	check(s.check_move("house_02", 4, 5, 0).reason == GridLogic.REASON_OVERLAP, "겹침 거부")
	check(s.check_move("house_02", 13, 9, 0).reason == GridLogic.REASON_OUT, "지도 밖 거부")
	check(s.check_move("house_02", -1, 3, 0).reason == GridLogic.REASON_OUT, "음수 좌표 거부")
	# 입구 칸 막기
	check(s.check_move("house_02", 6, 0, 0).reason == GridLogic.REASON_NO_ROUTE, "입구 봉쇄 거부")
	# 기존 내부 울타리가 가로지르는 자리
	var add := {"h:10:8": true}
	check(s.commit_fences(add, {}).ok, "울타리 설치")
	check(s.check_move("house_02", 10, 7, 0).reason == GridLogic.REASON_FENCE_CROSS, "울타리 가로지름 거부")
	# 둘레에 접한 울타리는 허용
	check(s.check_move("house_02", 10, 8, 0).ok, "둘레 접한 울타리 허용")
	# 길 그림 유무는 조건 아님: 길 위 (6,2)에도 경로가 남으면 허용
	check(s.check_move("house_02", 7, 2, 0).ok or s.check_move("house_02", 7, 2, 0).reason == GridLogic.REASON_NO_ROUTE, "길 위 배치 판정은 경로만")


func test_purchase_limits_and_cost() -> void:
	var s := fresh()
	var v := s.check_new_building("house", 10, 7, 0)
	check(v.ok, "새 주택 (10,7)")
	check(s.wood == 100 and s.count_type("house") == 2, "미리보기 시 미차감")
	var r := s.commit_new_building("house", 10, 7, 0)
	check(r.ok and s.wood == 70 and s.count_type("house") == 3, "주택 30 차감 1회")
	check(r.id == "house_03", "새 ID")
	# 실패한 구매는 아무것도 바꾸지 않는다
	s.wood = 20
	var bad := s.commit_new_building("house", 12, 7, 0)
	check(not bad.ok and s.wood == 20 and s.count_type("house") == 3, "목재 부족 시 불변")
	s.wood = 500
	check(s.commit_new_building("house", 12, 7, 0).ok, "4번째 주택")
	check(s.count_type("house") == 4, "주택 4")
	var over := s.commit_new_building("house", 11, 2, 0)
	check(not over.ok and s.count_type("house") == 4 and s.wood == 470, "주택 한도 4")
	check(s.commit_new_building("defense_tower", 1, 4, 0).ok and s.wood == 390, "탑 80")
	check(s.commit_new_building("defense_tower", 11, 4, 0).ok, "탑 4번째")
	s.wood = 500
	check(s.commit_new_building("defense_tower", 11, 0, 0).ok and s.commit_new_building("defense_tower", 1, 0, 0).ok, "탑 5·6번째")
	check(s.count_type("defense_tower") == 6 and not s.commit_new_building("defense_tower", 12, 5, 0).ok, "탑 한도 6")
	check(not s.check_new_building("lumber_camp", 11, 0, 0).ok, "벌목소 구매 불가")
	check(not s.check_new_building("castle", 11, 0, 0).ok, "성 구매 불가")
	check(s.wood >= 0, "음수 없음")


func test_upgrade() -> void:
	var s := fresh()
	check(s.check_upgrade("tower_01").ok, "강화 가능")
	var r := s.commit_upgrade("tower_01")
	check(r.ok and s.wood == 40 and s.get_building("tower_01").level == 2, "60 차감·Lv.2")
	check(GameConfig.tower_level(2).damage == 15 and GameConfig.tower_level(1).damage == 10, "피해 10→15")
	s.wood = 500
	var r3 := s.commit_upgrade("tower_01")
	check(r3.ok and s.wood == 380 and s.get_building("tower_01").level == 3 and GameConfig.tower_level(3).damage == 22, "Lv.3 강화 120·피해 22")
	check(not s.commit_upgrade("tower_01").ok and s.wood == 380, "Lv.4 없음")
	check(not s.commit_upgrade("house_01").ok, "주택 강화 없음")
	s.wood = 59
	check(not s.commit_upgrade("tower_02").ok and s.wood == 59, "목재 부족 강화 불가")


func test_fences() -> void:
	var s := fresh()
	var add := {"v:11:6": true, "v:11:7": true}
	var r := s.commit_fences(add, {})
	check(r.ok and r.cost == 4 and s.wood == 96, "2변 = 목재 4")
	check(s.interior_fences.size() == 2, "변 2개")
	var dup := s.commit_fences({"v:11:6": true}, {})
	check(not dup.ok and s.wood == 96, "중복 변 거부·미과금")
	var rm := s.commit_fences({}, {"v:11:6": true})
	check(rm.ok and rm.cost == 0 and s.wood == 96 and s.interior_fences.size() == 1, "제거 무료·환급 없음")
	check(not s.commit_fences({}, {"h:0:0": true}).ok, "외곽 제거 불가")
	check(not s.commit_fences({"h:6:0": true}, {}).ok, "정문 막기 불가")
	check(not s.commit_fences({"h:5:7": true}, {}).ok, "성 내부 가르기 불가")
	check(not s.commit_fences({"v:4:4": true}, {}).ok, "주택 내부 가르기 불가")
	# 건물 둘레 변은 허용
	check(s.commit_fences({"h:3:6": true}, {}).ok, "건물 둘레 변 허용")
	# 원자성: 여러 변 중 하나라도 잘못되면 전체 거부
	var w := s.wood
	var cnt := s.interior_fences.size()
	check(not s.commit_fences({"v:12:2": true, "h:5:7": true}, {}).ok and s.wood == w and s.interior_fences.size() == cnt, "부분 적용 없음")
	check(GridLogic.edges_between_points(Vector2i(10, 2), Vector2i(10, 5)).size() == 3, "드래그 3변")


func test_route_blocking_examples() -> void:
	var s := fresh()
	var add := {}
	for e in GameConfig.layout().qa_examples.route_blocking_edges:
		add[GridLogic.edge_key(Vector2i(int(e.from[0]), int(e.from[1])), Vector2i(int(e.to[0]), int(e.to[1])))] = true
	var r := s.check_fences(add, {})
	check(not r.ok and r.reason == GridLogic.REASON_NO_ROUTE, "입구 U자 봉쇄 거부")
	# 성 둘레(x=5..8, z=6..9) 전체 감싸기: 마지막 변이 거부되어야 함
	var ring: Array[String] = []
	for x in range(5, 8):
		ring.append("h:%d:6" % x)
	for z in range(6, 9):
		ring.append("v:5:%d" % z)
		ring.append("v:8:%d" % z)
	# 뒤쪽 z=9 는 지도 안쪽이라 설치 가능
	for x in range(5, 8):
		ring.append("h:%d:9" % x)
	s.wood = 500
	var accepted := 0
	var rejected_last := false
	for i in ring.size():
		var res := s.commit_fences({ring[i]: true}, {})
		if res.ok:
			accepted += 1
		elif i == ring.size() - 1:
			rejected_last = res.reason == GridLogic.REASON_NO_ROUTE
	check(rejected_last and accepted == ring.size() - 1, "성 둘레 마지막 변 거부 (%d/%d)" % [accepted, ring.size()])
	check(not GridLogic.find_route(s.buildings, s.all_edges()).is_empty(), "거부 후 기존 경로 유지")
	# 주변 칸에 도달해도 성과 공격 변이 막히면 목표가 아니다
	var goals := GridLogic.attack_cells(s.buildings, s.all_edges())
	for c in goals:
		var blocked_side := true
		for d in GridLogic.DIRS:
			var n: Vector2i = c + d
			if s.building_at(n).get("type", "") == "castle" and not GridLogic.blocks(s.all_edges(), c, n):
				blocked_side = false
		check(not blocked_side, "공격 칸 %s 은 열린 변으로 성과 접함" % c)


func test_production_states() -> void:
	var s := fresh()
	s.mode = GameState.MODE_RAID_READY
	for i in 600:
		s.tick(1.0 / 60.0)
	check(s.wood == 110, "RAID_READY 10초 = +10 (실제 %d)" % s.wood)
	s.mode = GameState.MODE_BUILD
	for i in 180:
		s.tick(1.0 / 30.0)
	check(s.wood == 116, "BUILD 6초 = +6, 프레임률 무관 (실제 %d)" % s.wood)
	for m in [GameState.MODE_BATTLE, GameState.MODE_PAUSED, GameState.MODE_RESULT]:
		s.mode = m
		var w := s.wood
		for i in 300:
			s.tick(1.0 / 60.0)
		check(s.wood == w, "%s 생산 없음" % m)
	s.mode = GameState.MODE_VILLAGE
	s.wood = 499
	s.wood_frac = 0.0
	for i in 600:
		s.tick(1.0 / 60.0)
	check(s.wood == 500, "상한 500")
	var got := s.add_wood(80)
	check(got == 0 and s.wood == 500, "보상도 상한 적용")


func test_raid_timer_and_build() -> void:
	var s := fresh()
	var b := s.begin_battle()
	check(b.ok, "1단계 시작")
	s.resolve_battle(b.battle_id, b.stage, true)
	check(s.ready_stage == 2 and not s.raid_ready, "승리 후 대기")
	check(s.raid_timer >= 30.0 and s.raid_timer <= 60.0, "대기 30~60초 (%.1f)" % s.raid_timer)
	s.leave_result()
	check(s.mode == GameState.MODE_VILLAGE, "마을로")
	# 결과·전투 중에는 타이머 정지
	var t := s.raid_timer
	s.mode = GameState.MODE_RESULT
	s.tick(5.0)
	check(is_equal_approx(s.raid_timer, t), "RESULT 타이머 정지")
	s.mode = GameState.MODE_RAID_READY
	s.tick(5.0)
	check(is_equal_approx(s.raid_timer, t), "준비 전 RAID_READY 상태에서 타이머 미진행")
	# BUILD 중 타이머 종료: 편집 유지, 준비 플래그만
	s.mode = GameState.MODE_BUILD
	for i in int(ceil(t)) + 1:
		s.tick(1.0)
	check(s.raid_ready and s.mode == GameState.MODE_BUILD, "BUILD 유지·준비 플래그")
	check(s.idle_mode() == GameState.MODE_RAID_READY, "편집 종료 후 RAID_READY")
	# 시작하기 전 자동 시작 없음
	s.mode = s.idle_mode()
	s.tick(100.0)
	check(s.mode == GameState.MODE_RAID_READY, "자동 시작 없음")


func test_reward_once() -> void:
	var s := fresh()
	var b := s.begin_battle()
	var r1 := s.resolve_battle(b.battle_id, 1, true)
	var w := s.wood
	var r2 := s.resolve_battle(b.battle_id, 1, true)
	check(r1.applied and r1.reward == 40, "보상 40")
	check(not r2.applied and s.wood == w, "같은 전투 재지급 없음")
	# 패배 보상 0, 같은 단계 재도전
	s.leave_result()
	s.raid_ready = true
	s.raid_timer = -1
	s.mode = GameState.MODE_RAID_READY
	var b2 := s.begin_battle()
	check(b2.stage == 2, "2단계")
	var w2 := s.wood
	var r3 := s.resolve_battle(b2.battle_id, 2, false)
	check(r3.reward == 0 and s.wood == w2 and s.ready_stage == 2 and s.raid_ready, "패배 보상 0·같은 단계 준비")
	# 3단계 승리 후 4단계 없음
	s.leave_result()
	var last := GameConfig.stage_count()
	check(last == 10, "습격 10단계")
	s.ready_stage = last
	var b3 := s.begin_battle()
	var r4 := s.resolve_battle(b3.battle_id, last, true)
	check(r4.applied and s.ready_stage == last and s.raid_ready and s.highest_cleared == last, "마지막 단계 후 수동 반복(가상의 다음 단계 없음)")
	s.leave_result()
	var b4 := s.begin_battle()
	check(b4.ok and b4.battle_id != b3.battle_id, "다시 도전은 새 전투 ID")


func _tmp_dir(name: String) -> String:
	var path := "user://test_%s/" % name
	DirAccess.make_dir_recursive_absolute(path)
	var sm := SaveManager.new(path)
	sm.delete_all()
	var da := DirAccess.open(path)
	if da and FileAccess.file_exists(path + "save.broken.json"):
		da.remove("save.broken.json")
	return path


func test_save_roundtrip_and_recovery() -> void:
	var dir := _tmp_dir("save")
	var sm := SaveManager.new(dir)
	var s := fresh()
	s.commit_move("house_02", 10, 7, 3)
	s.commit_upgrade("tower_01")
	s.commit_fences({"v:12:2": true}, {})
	s.wood_frac = 0.4
	check(sm.save(s), "저장")
	var t := GameState.new()
	var res := sm.load_into(t)
	check(res.status == "loaded", "불러오기")
	check(JSON.stringify(t.to_dict()) == JSON.stringify(s.to_dict()), "완전 복원")
	# 두 번째 저장으로 백업 생성 후 본 파일 손상
	s.wood = 77
	sm.save(s)
	check(FileAccess.file_exists(sm.backup_path()), "백업 존재")
	var f := FileAccess.open(sm.save_path(), FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	var u := GameState.new()
	var res2 := sm.load_into(u)
	check(res2.status == "backup" and u.get_building("tower_01").level == 2, "손상 시 백업 복구")
	check(FileAccess.file_exists(dir + "save.broken.json"), "손상본 보존")
	# 비정상 값(겹치는 건물)은 거부
	var d := s.to_dict()
	d.buildings[1].x = 5
	d.buildings[1].z = 6
	check(GameState.validate_dict(d) != "", "겹침 저장값 거부")
	var d2 := s.to_dict()
	d2.buildings.append(d2.buildings[1].duplicate())
	check(GameState.validate_dict(d2) != "", "중복 ID 거부")
	var d3 := s.to_dict()
	d3.wood = 9999
	check(GameState.validate_dict(d3) != "", "목재 범위 거부")
	# 둘 다 손상 → 새 마을 + 보존
	var f2 := FileAccess.open(sm.backup_path(), FileAccess.WRITE)
	f2.store_string("x")
	f2.close()
	var f3 := FileAccess.open(sm.save_path(), FileAccess.WRITE)
	f3.store_string("y")
	f3.close()
	var v := GameState.new()
	var res3 := sm.load_into(v)
	check(res3.status == "reset" and v.buildings.size() == 6 and res3.message != "", "복구 불가 시 안내 후 새 마을")


func test_unsaved_preview_not_persisted() -> void:
	var dir := _tmp_dir("preview")
	var sm := SaveManager.new(dir)
	var s := fresh()
	sm.save(s)
	# 미리보기 검증(이동·구매)만 하고 종료 → 저장본은 그대로
	s.check_move("house_01", 10, 7, 1)
	s.check_new_building("defense_tower", 11, 4, 0)
	var t := GameState.new()
	sm.load_into(t)
	check(t.get_building("house_01").x == 3 and t.wood == 100 and t.count_type("defense_tower") == 2, "미확정 변경 미저장")
	# 전투 시작 전 저장 → 전투 중 종료 → 준비 상태 복원, 보상 없음
	var b := s.begin_battle()
	sm.save(s)
	var u := GameState.new()
	sm.load_into(u)
	check(u.mode == GameState.MODE_RAID_READY and u.ready_stage == 1 and u.wood == 100, "전투 중 종료 시 준비 상태")
	check(u.battle_seq == b.battle_id and u.last_resolved_battle_id < b.battle_id, "미완료 전투 보상 없음")
	# 승리 직후 저장 → 재실행 시 재지급 없음
	s.resolve_battle(b.battle_id, 1, true)
	sm.save(s)
	var v := GameState.new()
	sm.load_into(v)
	check(v.wood == 140 and v.ready_stage == 2, "보상·진행 함께 저장")
	check(not v.resolve_battle(b.battle_id, 1, true).applied and v.wood == 140, "재실행 후 재지급 없음")


## 마을 시간으로 공사를 끝낸다(실제 규칙 경로 사용)
func finish_construction(s: GameState) -> void:
	var m := s.mode
	s.mode = GameState.MODE_VILLAGE
	for i in 60 * 30:
		if s.constructing().is_empty():
			break
		s.tick(1.0 / 60.0)
	s.mode = m


func sim(s: GameState, stage: int) -> BattleSim:
	var b := BattleSim.new()
	b.setup(s.buildings, s.all_edges(), stage, 1.0, {castle_hp = s.castle_hp(), bounds = s.bounds()})
	b.run_to_end()
	return b


func test_battle_stage1_default_win() -> void:
	var s := fresh()
	var b := sim(s, 1)
	print("  [P01] 기본 배치 1단계: %s, 성 HP %d/%d, %.1f초" % [b.outcome, b.castle_hp, b.castle_max, b.time])
	check(b.outcome == "win", "기본 배치 1단계 승리")


func test_battle_loss_layout() -> void:
	var s := fresh()
	for p in GameConfig.layout().qa_examples.loss_layout_tower_positions:
		var r := s.commit_move(String(p.id), int(p.x), int(p.z), 0)
		check(r.ok, "패배 검수 배치 이동 %s" % p.id)
	var b := sim(s, 1)
	print("  [P02] 탑 (0,0)/(12,8) 1단계: %s, 성 HP %d, %.1f초" % [b.outcome, b.castle_hp, b.time])
	check(b.outcome == "lose", "먼 배치 패배")
	# 원래 배치로 복구하면 다시 이길 수 있다
	s.commit_move("tower_01", 3, 1, 0)
	s.commit_move("tower_02", 9, 1, 0)
	check(sim(s, 1).outcome == "win", "복구 후 승리")


func test_battle_upgrade_effect() -> void:
	var s := fresh()
	var b1 := sim(s, 2)
	var s2 := fresh()
	s2.wood = 500
	s2.commit_upgrade("tower_01")
	s2.commit_upgrade("tower_02")
	var b2 := sim(s2, 2)
	var dmg1 := 0
	var dmg2 := 0
	for k in b1.knights:
		dmg1 += k.max_hp - maxi(k.hp, 0)
	for k in b2.knights:
		dmg2 += k.max_hp - maxi(k.hp, 0)
	print("  [P03] 2단계 Lv1: %s HP%d 처치%d %.1f초 / Lv2: %s HP%d 처치%d %.1f초" % [b1.outcome, b1.castle_hp, b1.killed, b1.time, b2.outcome, b2.castle_hp, b2.killed, b2.time])
	check(b2.castle_hp >= b1.castle_hp, "강화 후 성 피해 감소 또는 동일")
	check(b2.towers[0].damage == 15 and b1.towers[0].damage == 10, "탑 피해 반영")
	check(b2.killed >= b1.killed, "강화 후 처치 수 이상")


func test_battle_bolts_and_counts() -> void:
	var s := fresh()
	var b := BattleSim.new()
	b.setup(s.buildings, s.all_edges(), 1)
	var kills := 0
	var hits := {}
	var dup_hit := false
	var early_win := false
	while b.outcome == "" and b.time < 300:
		b.step(BattleSim.STEP)
		for e in b.events:
			if e.type == "kill":
				kills += 1
			if e.type == "hit":
				if hits.has(e.bolt):
					dup_hit = true
				hits[e.bolt] = true
		b.events.clear()
		if b.spawned < b.total and b.outcome == "win":
			early_win = true
		if b.remaining() != b.total - kills:
			check(false, "남은 적 = 전체 - 처치")
	check(not dup_hit, "화살 1회 피해")
	check(kills == b.killed and kills <= b.total, "처치 중복 없음 (%d)" % kills)
	check(not early_win, "미등장 적 남으면 승리 아님")
	# 등장 간격·위치
	var c := BattleSim.new()
	c.setup(s.buildings, s.all_edges(), 1)
	c.step(BattleSim.STEP)
	check(c.spawned == 1 and c.knights[0].pos.distance_to(Vector2(6.5, -2)) < 0.05, "첫 기사 즉시 (6.5,-2)")
	while c.time < 2.9:
		c.step(BattleSim.STEP)
	check(c.spawned == 1, "3초 전 추가 등장 없음")
	while c.time < 3.05:
		c.step(BattleSim.STEP)
	check(c.spawned == 2, "3초 간격")
	check(c.remaining() == 4, "미등장 포함 남은 적 4")
	# 사거리 판정
	for t in c.towers:
		if t.target_id > 0:
			check(t.center.distance_to(c.knights[t.target_id - 1].pos) <= t.range, "사거리 내 표적")
	# 사라진 표적을 향한 화살은 피해 없이 종료
	var d := BattleSim.new()
	d.setup(s.buildings, s.all_edges(), 1)
	d.knights = []
	d.spawned = d.total
	d.killed = d.total - 1
	d.knights.append({id = 1, kind = "knight", hp = 5, max_hp = 90, pos = Vector2(6.5, 3), waypoints = [Vector2(6.5, 3)], wp = 0, state = "walk", attack_timer = 0.0, alive = true, facing = Vector2(0, 1), remaining_dist = 1.0,
		target = "castle", speed = 0.6, attack_damage = 6, attack_interval = 1.0, castle_cell = Vector2i(6, 6)})
	d.bolts.append({id = 90, tower_id = "tower_01", target_id = 1, pos = Vector2(4, 2), start = Vector2(4, 2), damage = 10, alive = true})
	d.bolts.append({id = 91, tower_id = "tower_02", target_id = 1, pos = Vector2(10, 2), start = Vector2(10, 2), damage = 10, alive = true})
	for i in 120:
		d.step(BattleSim.STEP)
	check(d.killed == d.total and d.outcome == "win", "동시 화살에도 1회 처치")


func test_battle_stages_2_3_reachable() -> void:
	# 구매·배치·강화 범위 안의 한 가지 계획으로 2·3단계를 이길 수 있는지 확인
	var s := fresh()
	s.wood = 500
	s.commit_upgrade("tower_01")
	s.commit_upgrade("tower_02")
	var r1 := s.commit_new_building("defense_tower", 7, 1, 0)
	check(r1.ok, "3번째 탑 (7,1): %s" % r1.reason)
	finish_construction(s)
	var b2 := sim(s, 2)
	print("  [P03] 2단계 탑 3(Lv2,Lv2,Lv1): %s HP%d %.1f초" % [b2.outcome, b2.castle_hp, b2.time])
	check(b2.outcome == "win", "2단계 클리어 가능")
	s.wood = 500
	s.commit_upgrade(r1.id)
	var r2 := s.commit_new_building("defense_tower", 7, 3, 0)
	check(r2.ok, "4번째 탑 (7,3): %s" % r2.reason)
	finish_construction(s)
	s.wood = 500
	s.commit_upgrade(r2.id)
	var b3 := sim(s, 3)
	print("  [P03] 3단계 탑 4(Lv2×4): %s HP%d %.1f초" % [b3.outcome, b3.castle_hp, b3.time])
	check(b3.outcome == "win", "3단계 클리어 가능")
	var plain := fresh()
	var b3p := sim(plain, 3)
	print("  [참고] 3단계 기본 배치: %s HP%d %.1f초" % [b3p.outcome, b3p.castle_hp, b3p.time])


func test_watchdog_and_long_route() -> void:
	# 긴 우회로: 울타리로 지그재그를 만들어도 이동 중이면 중단하지 않는다
	var s := fresh()
	s.wood = 500
	var add := {}
	for x in range(5, 14):
		add["h:%d:3" % x] = true
	var r := s.commit_fences(add, {})
	check(r.ok, "우회 울타리: %s" % r.reason)
	var b := sim(s, 1)
	print("  [A22] 우회로 길이 %d칸, 결과 %s, %.1f초" % [b.route.size(), b.outcome, b.time])
	check(b.route.size() > 10, "우회로가 실제로 길어짐")
	check(b.outcome != "abort", "긴 우회로는 중단하지 않음")
	# 인위적 정지: 기사를 멈추게 만들면 15초 후 중단
	var c := BattleSim.new()
	c.setup(fresh().buildings, fresh().all_edges(), 1)
	c.towers = []
	c.step(BattleSim.STEP)
	c.spawned = c.total
	c.knights[0].waypoints = [c.knights[0].pos]
	c.knights[0].wp = 1
	c.knights[0].state = "stuck"
	c.run_to_end(40.0)
	check(c.outcome == "abort" and c.time >= 15.0 and c.time < 15.2, "15초 무진행 중단 (%.2f초)" % c.time)


func test_battle_pause_no_catchup() -> void:
	var s := fresh()
	var b := BattleSim.new()
	b.setup(s.buildings, s.all_edges(), 1)
	b.advance(0.5)
	var t := b.time
	# 복귀 직후 큰 delta 가 와도 몰아서 진행하지 않는다
	b.advance(30.0)
	check(b.time - t <= BattleSim.STEP * BattleSim.MAX_STEPS_PER_FRAME + 0.0001, "큰 delta 몰아치기 없음")


func test_construction_basic() -> void:
	var s := fresh()
	s.mode = GameState.MODE_VILLAGE
	var r := s.commit_new_building("house", 10, 7, 0)
	var h := s.get_building(r.id)
	check(is_equal_approx(float(h.build_left), 10.0) and not s.is_built(h), "주택 공사 10초로 시작")
	check(s.count_type("house") == 3 and s.wood == 70, "공사 중에도 수량·비용은 확정 시 반영")
	var done := []
	s.construction_finished.connect(func(id): done.append(id))
	for m in [GameState.MODE_BATTLE, GameState.MODE_PAUSED, GameState.MODE_RESULT]:
		s.mode = m
		s.tick(5.0)
		check(is_equal_approx(float(h.build_left), 10.0), "%s 에서 공사 정지" % m)
	s.mode = GameState.MODE_BUILD
	for i in 300:
		s.tick(1.0 / 60.0)
	check(absf(float(h.build_left) - 5.0) < 0.01, "BUILD 상태에서 공사 진행")
	s.mode = GameState.MODE_RAID_READY
	for i in 400:
		s.tick(1.0 / 60.0)
	check(s.is_built(h) and done == [r.id], "완성 신호 1회 (%s)" % str(done))
	check(is_equal_approx(s.build_progress(h), 1.0), "진행률 1")
	var t := s.commit_new_building("defense_tower", 1, 4, 0)
	check(is_equal_approx(float(s.get_building(t.id).build_left), 20.0), "방어탑 공사 20초")
	check(is_equal_approx(GameState.build_seconds("castle"), 0.0), "초기 건물은 공사 없음")


func test_construction_battle_and_rules() -> void:
	var s := fresh()
	s.wood = 500
	var r := s.commit_new_building("defense_tower", 7, 1, 0)
	check(not s.check_upgrade(r.id).ok, "공사 중 강화 불가")
	var mv := s.commit_move(r.id, 7, 3, 1)
	check(mv.ok and float(s.get_building(r.id).build_left) == 20.0, "공사 중 이동 허용·진행 유지")
	var b := BattleSim.new()
	b.setup(s.buildings, s.all_edges(), 1)
	check(b.towers.size() == 2 and b.constructing_towers == [r.id], "공사 중 방어탑은 전투 불참")
	finish_construction(s)
	var c := BattleSim.new()
	c.setup(s.buildings, s.all_edges(), 1)
	check(c.towers.size() == 3 and c.constructing_towers.is_empty(), "완성 후 전투 참여")
	check(s.check_upgrade(r.id).ok, "완성 후 강화 가능")


func test_save_v2_and_migration() -> void:
	var dir := _tmp_dir("v2")
	var sm := SaveManager.new(dir)
	var s := fresh()
	s.mode = GameState.MODE_VILLAGE
	var r := s.commit_new_building("house", 10, 7, 2)
	s.tick(3.25)
	s.commit_decor("house_01", {roof_color = "red", window = "round"})
	s.consecutive_losses = 2
	s.assist_enabled = true
	sm.save(s)
	var t := GameState.new()
	check(sm.load_into(t).status == "loaded", "v2 불러오기")
	check(absf(float(t.get_building(r.id).build_left) - 6.75) < 0.01, "공사 남은 시간 복원")
	check(t.get_building("house_01").deco.roof_color == "red" and t.get_building("house_01").deco.chimney == "back_right", "꾸미기 복원")
	check(t.consecutive_losses == 2 and t.assist_enabled, "연패·도움 모드 복원")
	# 버전 1 저장본(공사·꾸미기 필드 없음)
	var v1 := {version = 1, buildings = [], interior_fences = [], wood = 120, wood_frac = 0.0, ready_stage = 2,
		highest_cleared = 1, raid_ready = true, raid_timer = -1.0, last_resolved_battle_id = 1, battle_seq = 1}
	for b in fresh().buildings:
		v1.buildings.append({id = b.id, type = b.type, x = b.x, z = b.z, rot = b.rot, level = b.level})
	check(GameState.validate_dict(v1) == "", "v1 저장본 허용")
	var u := GameState.new()
	u.from_dict(v1)
	check(u.wood == 120 and u.ready_stage == 2 and s.is_built(u.get_building("tower_01")) and u.get_building("house_02").deco.roof_color == "purple", "v1 → v2 이전(완성 상태·기본 꾸미기)")
	var bad := s.to_dict()
	bad.buildings[0].build_left = 999.0
	check(GameState.validate_dict(bad) != "", "공사 시간 범위 밖 거부")


func test_decor() -> void:
	var s := fresh()
	check(s.get_building("house_01").deco == Decor.defaults("house"), "기본 꾸미기")
	check(Decor.defaults("house").roof_color == "purple" and Decor.defaults("house").chimney == "back_right", "기본값은 기준 시트(보라 맞배·뒤 오른쪽 굴뚝)")
	var w := s.wood
	check(s.commit_decor("house_01", {roof_color = "teal", roof_shape = "steep", window = "arch", chimney = "none", flag = "star", junk = "x"}).ok, "꾸미기 적용")
	var d: Dictionary = s.get_building("house_01").deco
	check(d.roof_shape == "steep" and d.flag == "star" and not d.has("junk") and s.wood == w, "무료·알 수 없는 부품 제거")
	s.commit_decor("house_01", {roof_color = "gold"})
	check(s.get_building("house_01").deco.roof_color == "purple", "없는 값은 기본값")
	check(not s.commit_decor("castle_01", {}).ok, "성은 꾸미기 없음")
	check(s.commit_decor("tower_01", {emblem = "moon"}).ok and s.get_building("tower_01").deco.emblem == "moon", "방어탑 꾸미기")
	var a := sim(fresh(), 1)
	var b := sim(s, 1)
	check(a.outcome == b.outcome and a.castle_hp == b.castle_hp and is_equal_approx(a.time, b.time), "꾸미기는 전투 결과에 영향 없음")
	for type in ["house", "defense_tower", "lumber_camp"]:
		for p in Decor.parts(type):
			check(p.options.size() >= 2 and not Decor.option(type, p.id, p.default).is_empty(), "%s.%s 선택지·기본값" % [type, p.id])


func test_assist_mode() -> void:
	var s := fresh()
	check(not s.assist_enabled and is_equal_approx(s.assist_multiplier(), 1.0), "기본 꺼짐")
	s.consecutive_losses = 3
	check(is_equal_approx(s.assist_multiplier(), 1.0), "꺼져 있으면 연패해도 그대로")
	s.assist_enabled = true
	s.consecutive_losses = 1
	check(is_equal_approx(s.assist_multiplier(), 1.0), "1패는 적용 안 함")
	s.consecutive_losses = 2
	check(is_equal_approx(s.assist_multiplier(), 0.9), "2연패 0.9")
	s.consecutive_losses = 3
	check(is_equal_approx(s.assist_multiplier(), 0.81), "3연패 0.81")
	s.consecutive_losses = 9
	check(is_equal_approx(s.assist_multiplier(), 0.7), "하한 0.7")
	var b := BattleSim.new()
	b.setup(s.buildings, s.all_edges(), 1, s.assist_multiplier())
	check(b.knight_hp == 63, "기사 체력 90×0.7=63")
	s.consecutive_losses = 0
	var bb := s.begin_battle()
	s.resolve_battle(bb.battle_id, 1, false)
	s.leave_result()
	check(s.consecutive_losses == 1, "패배 시 증가")
	var bc := s.begin_battle()
	s.resolve_battle(bc.battle_id, 1, true)
	check(s.consecutive_losses == 0, "승리 시 초기화")


func test_knight_spread() -> void:
	var s := fresh()
	var b := sim(s, 2)
	check(b.lanes.size() >= 2, "공격 칸 여러 갈래 (%d)" % b.lanes.size())
	var lanes := {}
	for k in b.knights:
		lanes[k.lane] = true
	check(lanes.size() >= 2, "기사들이 여러 공격 칸으로 나뉨 (%d칸)" % lanes.size())
	var finals := {}
	var dup := false
	for k in b.knights:
		var last: Vector2 = k.waypoints[k.waypoints.size() - 1]
		var key := "%.2f,%.2f" % [last.x, last.y]
		if finals.has(key):
			dup = true
		finals[key] = true
	check(not dup, "같은 지점에 겹쳐 서지 않음")
	for k in b.knights:
		var last: Vector2 = k.waypoints[k.waypoints.size() - 1]
		var cell := Vector2i(int(floor(last.x)), int(floor(last.y)))
		check(GridLogic.attack_cells(s.buildings, s.all_edges()).has(cell), "최종 자리는 공격 칸 안 %s" % cell)
		check(k.waypoints.size() <= b.route.size() + 4, "우회는 최단+4칸 이내")
	var c := sim(fresh(), 2)
	var same := c.outcome == b.outcome and c.castle_hp == b.castle_hp and is_equal_approx(c.time, b.time)
	for i in b.knights.size():
		same = same and (b.knights[i].pos as Vector2).is_equal_approx(c.knights[i].pos)
	check(same, "결정적(같은 입력 → 같은 결과)")


func test_advisor() -> void:
	var lose := fresh()
	for p in GameConfig.layout().qa_examples.loss_layout_tower_positions:
		lose.commit_move(String(p.id), int(p.x), int(p.z), 0)
	var b := sim(lose, 1)
	var tips := BattleAdvisor.advise(b, lose)
	print("  [조언·패배 배치] ", tips)
	check(tips.size() >= 1 and tips.size() <= 3, "조언 1~3개")
	var joined := " ".join(tips)
	check(joined.contains("방어탑이 닿지 않아요") or joined.contains("쏘지 못했어요"), "사거리 밖 길·놀고 있는 탑 지적")
	check(BattleAdvisor.advise(b, lose) == tips, "같은 기록 → 같은 조언")
	var win := fresh()
	var w := sim(win, 1)
	var wt := BattleAdvisor.advise(w, win)
	print("  [조언·기본 승리] ", wt)
	check(" ".join(wt).contains("다음 습격은 기사 6명"), "승리 시 다음 습격 안내")
	var c := fresh()
	c.wood = 500
	c.commit_new_building("defense_tower", 7, 1, 0)
	var cs := sim(c, 1)
	check(BattleAdvisor.advise(cs, c)[0].contains("공사 중이던 방어탑 1개"), "공사 중 탑 조언 우선")
	check(BattleAdvisor.place_words(Vector2(1, 1)) == "정문 쪽 왼쪽" and BattleAdvisor.place_words(Vector2(11, 7)) == "성 앞 오른쪽", "위치 말")


## 기준 배치(탑 수·레벨·울타리 미로)를 만들어 둔다. 공사는 끝난 상태.
func reference_layout(towers: int, level: int, maze: bool) -> GameState:
	var s := fresh()
	var extra := [Vector2i(7, 1), Vector2i(7, 3), Vector2i(11, 3), Vector2i(1, 2)]
	for i in towers - 2:
		s.wood = 500
		check(s.commit_new_building("defense_tower", extra[i].x, extra[i].y, 0).ok, "기준 배치 탑 %s" % extra[i])
	if maze:
		var add := {}
		for x in range(5, 13):
			add["h:%d:3" % x] = true
		s.wood = 500
		check(s.commit_fences(add, {}).ok, "기준 미로 울타리")
	finish_construction(s)
	for b in s.buildings:
		if b.type == "defense_tower":
			while int(b.level) < level:
				s.wood = 500
				s.commit_upgrade(b.id)
	return s


## 단계 곡선: 각 단계는 '그 단계까지 모을 수 있는 범위'의 기준 배치로 이길 수 있고,
## 처음 배치(Lv.1 탑 2개)로는 2단계부터 어렵다(성장이 필요).
func test_stage_curve() -> void:
	var plans := {
		4: [3, 2, false], 5: [4, 2, false], 6: [4, 2, false],
		7: [4, 3, true], 8: [4, 3, true], 9: [6, 3, true], 10: [6, 3, true],
	}
	var line := "  [단계 곡선]"
	for st in range(1, GameConfig.stage_count() + 1):
		# 그 단계에 도달했을 때의 성 레벨(체력)로 시험한다
		var fs := fresh()
		fs.highest_cleared = st - 1
		fs.sync_castle_level()
		var base := sim(fs, st)
		var res := "기본 %s" % ("승" if base.outcome == "win" else "패")
		if plans.has(st):
			var p: Array = plans[st]
			var rl := reference_layout(p[0], p[1], p[2])
			rl.highest_cleared = st - 1
			rl.sync_castle_level()
			var b := sim(rl, st)
			res += " / 탑%d Lv%d%s %s HP%d" % [p[0], p[1], " 미로" if p[2] else "", "승" if b.outcome == "win" else "패", b.castle_hp]
			check(b.outcome == "win", "%d단계: 기준 배치(탑 %d·Lv.%d%s)로 클리어 가능" % [st, p[0], p[1], "·미로" if p[2] else ""])
		if st >= 2:
			check(base.outcome == "lose", "%d단계: 처음 배치로는 패배(성장 필요)" % st)
		line += "  %d:%s" % [st, res]
		if st > 1:
			check(total_stage_hp(st) > total_stage_hp(st - 1), "%d단계 총 체력 증가" % st)
	print(line)


func total_stage_hp(st: int) -> int:
	var n := 0
	for u in GameConfig.stage_units(st):
		n += int(u.hp)
	return n


## 장 진행에 따라 성 레벨을 맞춘 상태
func at_level(cleared: int) -> GameState:
	var s := fresh()
	s.highest_cleared = cleared
	s.ready_stage = mini(cleared + 1, GameConfig.stage_count())
	s.sync_castle_level()
	return s


func test_castle_levels() -> void:
	check(GameState.castle_level_for(0) == 1 and GameState.castle_level_for(2) == 1, "1장 진행 중 Lv.1")
	check(GameState.castle_level_for(3) == 2 and GameState.castle_level_for(6) == 3 and GameState.castle_level_for(9) == 4, "장을 끝낼 때마다 Lv.2·3·4")
	check(GameState.castle_level_for(10) == 4, "최종장 클리어 후에도 Lv.4(최대)")
	check(GameConfig.castle_hp(1) == 180 and GameConfig.castle_hp(4) > GameConfig.castle_hp(3), "성 체력 Lv.1 180, 레벨마다 증가")
	var s := at_level(2)
	s.ready_stage = 3
	s.raid_ready = true
	s.mode = GameState.MODE_RAID_READY
	var leveled := []
	s.castle_leveled.connect(func(lv): leveled.append(lv))
	var b := s.begin_battle()
	check(int(b.castle_hp) == 180, "3단계 전투는 Lv.1 체력")
	var r := s.resolve_battle(b.battle_id, 3, true)
	check(int(r.chapter_cleared) == 1 and int(r.castle_level) == 2 and leveled == [2], "3단계 승리 → 1장 완료·성 Lv.2")
	check(s.get_building("castle_01").level == 2 and s.castle_hp() == 220, "성 건물 레벨·체력 반영")
	s.leave_result()
	s.ready_stage = 3
	s.raid_ready = true
	s.mode = GameState.MODE_RAID_READY
	var b2 := s.begin_battle()
	var r2 := s.resolve_battle(b2.battle_id, 3, true)
	check(int(r2.chapter_cleared) == 0 and leveled == [2], "같은 장 다시 클리어해도 레벨업 반복 없음")
	# 레벨별 한도
	var l1 := fresh()
	check(l1.max_count("house") == 4 and l1.max_count("lumber_camp") == 1 and l1.max_count("outpost") == 0 and l1.max_count("flowerbed") == 0, "Lv.1 한도")
	check(l1.check_new_building("flowerbed", 12, 8, 0).reason == "성 Lv.2에서 열려요", "잠긴 건물 안내")
	var l2 := at_level(3)
	check(l2.max_count("house") == 6 and l2.max_count("lumber_camp") == 2 and l2.max_count("flowerbed") == 12, "Lv.2 한도")
	var l4 := at_level(9)
	check(l4.max_count("house") == 10 and l4.max_count("outpost") == 1 and l4.max_count("defense_tower") == 6, "Lv.4 한도(방어탑은 그대로 6)")
	l2.wood = 500
	var lc := l2.commit_new_building("lumber_camp", 12, 7, 0)
	check(lc.ok and l2.wood == 380, "Lv.2 벌목소 추가(목재 120)")
	check(is_equal_approx(l2.income_rate(), 1.0), "공사 중 벌목소는 생산 안 함")
	finish_construction(l2)
	check(is_equal_approx(l2.income_rate(), 2.0), "완성 후 초당 2")


func test_boss_units() -> void:
	var u := GameConfig.stage_units(10)
	check(u.size() == 16, "10단계 16명(기사 14 + 기사단장 + 용사)")
	check(u[7].kind == "commander" and u[u.size() - 1].kind == "hero", "기사단장은 8번째, 용사는 마지막")
	var kn := 0
	for x in u:
		if x.kind == "knight":
			kn += 1
	check(kn == 14, "일반 기사 14")
	check(GameConfig.stage_units(3).size() == 8 and GameConfig.stage_units(3)[0].kind == "knight", "보통 단계는 기사만")
	var s := at_level(9)
	# 성이 먼저 무너지지 않게 체력을 크게 주고 등장만 확인한다
	var b := BattleSim.new()
	b.setup(s.buildings, s.all_edges(), 10, 1.0, {castle_hp = 100000, bounds = s.bounds()})
	b.run_to_end()
	var kinds := {}
	for k in b.knights:
		kinds[k.kind] = int(kinds.get(k.kind, 0)) + 1
	check(int(kinds.get("hero", 0)) == 1 and int(kinds.get("commander", 0)) == 1, "보스 등장")
	var hero: Dictionary = {}
	for k in b.knights:
		if k.kind == "hero":
			hero = k
	check(int(hero.max_hp) == int(GameConfig.stage(10).units[2].hp) and is_equal_approx(float(hero.speed), 0.5), "용사 체력·속도")
	s.assist_enabled = true
	s.consecutive_losses = 2
	var c := BattleSim.new()
	c.setup(s.buildings, s.all_edges(), 10, s.assist_multiplier(), {castle_hp = s.castle_hp(), bounds = s.bounds()})
	c.run_to_end(5.0)
	check(c.knights.size() >= 1 and int(c.knight_hp) == int(round(220 * 0.9)), "도움 모드는 보스 단계에도 적용")


func test_expansion() -> void:
	var s := fresh()
	check(GridLogic.fixed_edges(s.bounds()).size() == 46, "처음 바깥 울타리 46변")
	var listed := {}
	for e in GameConfig.layout().fixed_fence_edges:
		listed[GridLogic.edge_key(Vector2i(int(e.from[0]), int(e.from[1])), Vector2i(int(e.to[0]), int(e.to[1])))] = true
	check(listed == GridLogic.fixed_edges(s.bounds()), "계산한 외곽 = initial-layout 목록")
	check(s.check_expand("east").reason == "성 Lv.2에서 열려요", "Lv.1 확장 잠김")
	var t := at_level(3)
	t.wood = 500
	check(t.check_expand("north").reason == "성 Lv.3에서 열려요", "북쪽은 Lv.3")
	var w := t.wood
	var r := t.commit_expand("east")
	check(r.ok and t.wood == w - 60 and t.bounds() == Rect2i(0, 0, 19, 10), "동쪽 5칸 확장(목재 60)")
	check(not t.commit_expand("east").ok, "같은 방향 두 번 불가")
	var fx := GridLogic.fixed_edges(t.bounds())
	check(fx.size() == 2 * 19 + 2 * 10 - 2 and not fx.has("v:14:3") and fx.has("v:19:3"), "외곽 울타리가 새 경계로 이동")
	check(GridLogic.is_interior_edge("v:14:3", t.bounds()), "옛 경계 자리는 안쪽 변")
	check(t.commit_new_building("house", 15, 7, 0).ok, "넓힌 땅에 주택")
	check(t.commit_fences({"v:14:6": true}, {}).ok, "넓힌 땅 울타리")
	var u := at_level(6)
	u.wood = 500
	check(u.commit_expand("south").ok, "남쪽 확장")
	check(GameConfig.entry_cell_for(u.bounds()) == Vector2i(6, -4) and GameConfig.spawn_world_for(u.bounds()).is_equal_approx(Vector2(6.5, -6)), "정문·진입 지점이 앞으로 이동")
	check(GridLogic.gate_edges(u.bounds()) == ["h:6:-4", "h:7:-4"], "정문 변 이동")
	var route := GridLogic.find_route(u.buildings, u.all_edges(), u.bounds())
	check(not route.is_empty() and route[0] == Vector2i(6, -4), "새 정문에서 성까지 길")
	var b := BattleSim.new()
	b.setup(u.buildings, u.all_edges(), 7, 1.0, {castle_hp = u.castle_hp(), bounds = u.bounds()})
	b.step(BattleSim.STEP)
	check(b.knights.size() == 1 and (b.knights[0].pos as Vector2).distance_to(Vector2(6.5, -6)) < 0.05, "기사가 새 진입 지점 (6.5,-6)에서 등장")
	u.wood = 500
	for d in ["west", "east", "north"]:
		u.commit_expand(d)
		u.wood = 500
	var mx: Array = GameConfig.map_config().max_size
	check(u.bounds().size == Vector2i(int(mx[0]), int(mx[1])), "네 방향 모두 넓히면 최대 크기 %s" % str(u.bounds().size))
	# 확장 후 입구 봉쇄 금지 규칙 그대로
	check(u.check_move("house_01", 6, -4, 0).reason == GridLogic.REASON_NO_ROUTE, "새 입구 막기 거부")
	check(u.check_move("house_01", -5, 2, 0).ok, "서쪽 땅에 옮기기")
	check(u.check_move("house_01", -6, 2, 0).reason == GridLogic.REASON_OUT, "새 경계 밖 거부")
	# 저장·검증
	var d := u.to_dict()
	check(GameState.validate_dict(d) == "", "확장 저장본 검증 통과")
	var v := GameState.new()
	v.from_dict(d)
	check(v.bounds() == u.bounds() and v.expansions.size() == 4, "확장 복원")
	var bad := u.to_dict()
	bad.expansions = ["east", "east"]
	check(GameState.validate_dict(bad) != "", "중복 확장 거부")


func test_resource_sites_and_props() -> void:
	var s := at_level(6)
	s.wood = 500
	check(s.commit_new_building("outpost", 16, 2, 0).reason == GridLogic.REASON_OUT, "확장 전에는 앞마당 자리 없음")
	s.commit_expand("east")
	s.wood = 500
	check(GridLogic.open_sites(s.bounds()).size() == 1, "동쪽 숲 자원 지점 열림")
	check(s.check_new_building("house", 16, 2, 0).reason == GridLogic.REASON_SITE, "자원 지점에 다른 건물 불가")
	check(s.check_new_building("house", 15, 1, 0).reason == GridLogic.REASON_SITE, "자원 지점에 겹쳐도 불가")
	check(s.check_new_building("outpost", 15, 5, 0).reason == GridLogic.REASON_OUTPOST_SITE, "앞마당은 자원 지점에만")
	var r := s.commit_new_building("outpost", 16, 2, 0)
	check(r.ok and s.wood == 400, "앞마당 건설(목재 100)")
	check(not s.check_new_building("outpost", 16, 2, 0).ok, "앞마당 한도 1")
	var f := s.commit_new_building("flowerbed", 12, 8, 0)
	check(f.ok and GameConfig.footprint("flowerbed") == Vector2i(1, 1), "1칸 꾸밈 소품")
	check(s.check_move("house_01", 12, 8, 0).reason == GridLogic.REASON_OVERLAP, "소품도 칸을 차지")
	check(s.commit_decor(f.id, {flower_color = "yellow"}).ok, "소품 꾸미기")


func outpost_state(protected_outpost: bool) -> GameState:
	var s := at_level(6)
	s.wood = 500
	s.commit_expand("east")
	s.wood = 500
	s.commit_new_building("outpost", 16, 2, 0)
	if protected_outpost:
		s.wood = 500
		s.commit_new_building("defense_tower", 14, 1, 0)
		s.wood = 500
		s.commit_new_building("defense_tower", 14, 4, 0)
	finish_construction(s)
	if protected_outpost:
		for b in s.buildings:
			if b.type == "defense_tower":
				while int(b.level) < 3:
					s.wood = 500
					s.commit_upgrade(b.id)
	return s


func test_outpost_battle() -> void:
	var s := outpost_state(false)
	var b := BattleSim.new()
	# 앞마당 쟁탈만 보려고 성 체력은 크게
	b.setup(s.buildings, s.all_edges(), 7, 1.0, {castle_hp = 100000, bounds = s.bounds()})
	check(not b.outpost.is_empty() and not b.outpost_lanes.is_empty(), "앞마당 공격 갈래")
	var captured_at := -1.0
	var retargeted := false
	while b.outcome == "" and b.time < 120:
		b.step(BattleSim.STEP)
		for e in b.events:
			if e.type == "outpost_captured" and captured_at < 0:
				captured_at = b.time
		b.events.clear()
	var raiders := 0
	for k in b.knights:
		if String(k.lane).begins_with("o"):
			raiders += 1
			if k.target == "castle":
				retargeted = true
	check(raiders == int(GameConfig.stage(7).knight_count) / 4, "4번째마다 앞마당 소대 (%d명)" % raiders)
	print("  [앞마당·무방비 7단계] %s, 점령 %.1f초, 성 HP %d" % [b.outcome, captured_at, b.castle_hp])
	check(captured_at > 0.0 and bool(b.outpost.captured), "무방비 앞마당은 점령됨")
	check(retargeted, "점령 뒤 소대는 성으로 방향 전환")
	var c := BattleSim.new()
	c.setup(s.buildings, s.all_edges(), 7, 1.0, {castle_hp = 100000, bounds = s.bounds()})
	c.run_to_end(120.0)
	var same := c.outcome == b.outcome and c.castle_hp == b.castle_hp and int(c.outpost.hp) == int(b.outpost.hp)
	for i in b.knights.size():
		same = same and (b.knights[i].pos as Vector2).is_equal_approx(c.knights[i].pos)
	check(same, "앞마당 전투도 결정적")
	var p := outpost_state(true)
	var d := BattleSim.new()
	d.setup(p.buildings, p.all_edges(), 7, 1.0, {castle_hp = 100000, bounds = p.bounds()})
	d.run_to_end()
	print("  [앞마당·탑 2개 엄호 7단계] %s, 앞마당 HP %d/%d" % [d.outcome, int(d.outpost.hp), int(d.outpost.max_hp)])
	check(not bool(d.outpost.captured), "방어탑으로 지킨 앞마당은 버팀")
	var none := at_level(6)
	var e := sim(none, 7)
	for k in e.knights:
		if k.target != "castle":
			check(false, "앞마당이 없으면 모두 성으로")
			break
	check(e.outpost.is_empty(), "앞마당 없음")


func test_outpost_repair() -> void:
	var s := outpost_state(false)
	var id: String = s.outposts()[0].id
	check(is_equal_approx(s.income_rate(), 2.0), "앞마당 생산 +1/초")
	s.mark_outpost_lost(id)
	check(is_equal_approx(s.income_rate(), 1.0) and s.buildings.size() > 0 and not s.get_building(id).is_empty(), "점령되면 생산만 멈춤(건물 유지)")
	var nb := BattleSim.new()
	nb.setup(s.buildings, s.all_edges(), 7, 1.0, {castle_hp = s.castle_hp(), bounds = s.bounds()})
	check(nb.outpost.is_empty(), "점령된 앞마당은 다음 전투에서 표적 아님")
	s.wood = 10
	check(not s.commit_repair(id).ok and s.wood == 10, "수리 목재 부족")
	s.wood = 100
	var r := s.commit_repair(id)
	check(r.ok and s.wood == 80 and bool(s.get_building(id).repairing), "수리 시작(목재 20)")
	check(is_equal_approx(s.income_rate(), 1.0), "수리 중 생산 없음")
	var d := s.to_dict()
	var t := GameState.new()
	t.from_dict(d)
	check(bool(t.get_building(id).get("repairing", false)) and float(t.get_building(id).build_left) > 0.0, "수리 상태 저장")
	finish_construction(s)
	check(is_equal_approx(s.income_rate(), 2.0) and not s.get_building(id).has("repairing"), "수리 완료 후 생산 재개")


func test_save_v3_migration() -> void:
	var s := at_level(5)
	var d := s.to_dict()
	d.version = 2
	d.erase("expansions")
	d.erase("story_seen")
	for b in d.buildings:
		if b.type == "castle":
			b.level = 1
	check(GameState.validate_dict(d) == "", "v2 저장본 허용")
	var t := GameState.new()
	t.from_dict(d)
	check(t.castle_level() == 2 and t.get_building("castle_01").level == 2, "v2 → 성 레벨 자동 맞춤")
	check(t.expansions.is_empty() and t.bounds() == GameConfig.initial_bounds(), "확장 없음으로 이전")
	check(t.story_seen.has("prologue") and t.story_seen.has("ch1_end") and not t.story_seen.has("ch2_end"), "지나온 장면만 본 것으로 표시")
	var u := at_level(0)
	var e := u.to_dict()
	e.version = 2
	e.erase("story_seen")
	var w := GameState.new()
	w.from_dict(e)
	check(not w.story_seen.has("prologue"), "새로 시작한 저장본은 프롤로그 미시청")


## 이야기 데이터: 게임이 부르는 장면이 모두 있고, 3~6줄, 말하는 인물이 정의돼 있고, 대화 상자에 들어가는 길이
func test_story_data() -> void:
	Story.reload()
	var d := Story.data()
	var chars: Dictionary = d.get("characters", {})
	for key in ["chief", "imp", "commander", "hero"]:
		check(chars.has(key) and String(chars[key].get("name", "")) != "", "인물 %s 정의" % key)
	var triggers := ["new_game", "before_stage:%d" % GameConfig.stage_count(), "stage_clear:%d" % GameConfig.stage_count(),
		"first_expansion", "outpost_built", "outpost_lost"]
	var nch := GameConfig.chapters().size()
	for c in range(1, nch):
		triggers.append("chapter_end:%d" % c)
		triggers.append("chapter_start:%d" % (c + 1))
	for t in triggers:
		check(not Story.scene_for(t).is_empty(), "장면 있음: %s" % t)
	var ids := {}
	for sc in d.get("scenes", []):
		var id := String(sc.get("id", ""))
		check(id != "" and not ids.has(id), "장면 id 고유: %s" % id)
		ids[id] = true
		var lines: Array = sc.get("lines", [])
		check(lines.size() >= 3 and lines.size() <= 6, "%s 3~6줄 (%d)" % [id, lines.size()])
		for ln in lines:
			check(chars.has(String(ln.get("who", ""))), "%s 말하는 인물 정의됨" % id)
			var n := String(ln.get("text", "")).length()
			check(n > 0 and n <= 60, "%s 대사 길이 1~60자 (%d)" % [id, n])
	# 기사단장 핑계: 단계마다 첫 승리·다시 이김 두 가지가 서로 다르게
	for st in range(1, GameConfig.stage_count() + 1):
		var a := Story.commander_excuse(st, false)
		var b := Story.commander_excuse(st, true)
		check(a != "" and b != "" and a != b, "단계 %d 핑계 2종" % st)
	var all_ex := {}
	for st in range(1, GameConfig.stage_count() + 1):
		all_ex[Story.commander_excuse(st, false)] = true
	check(all_ex.size() == GameConfig.stage_count(), "단계마다 다른 핑계")
	check(Story.chief_after_defeat(0) != "" and Story.chief_after_defeat(7) != "", "패배 격려 대사 순환")
	# 안내 단계 id 는 tutorial.gd 의 STEPS 에서 읽는다(헤드리스 검사에서는 UI 스크립트를 불러오지 않음)
	var re := RegEx.create_from_string('\\{id = "([a-z_]+)"')
	var steps := re.search_all(FileAccess.get_file_as_string("res://scripts/ui/tutorial.gd"))
	check(steps.size() >= 5, "안내 단계 읽기 (%d)" % steps.size())
	for m in steps:
		check(Story.tutorial_text(m.get_string(1), "") != "", "안내 대사 데이터: %s" % m.get_string(1))
	# 다시 보기: 본 장면만, 데이터 순서대로
	var seen := {"ending": true, "prologue": true}
	var list := Story.seen_scenes(seen)
	check(list.size() == 2 and String(list[0].id) == "prologue", "다시 보기 목록은 본 장면만")
