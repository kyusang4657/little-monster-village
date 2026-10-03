extends Node3D
## 게임 흐름·입력·저장 시점을 묶는 컨트롤러.

const DRAG_THRESHOLD := 14.0
const AUTOSAVE_SECONDS := 5.0

var state: GameState
var saver: SaveManager
var world: WorldView
var hud: Hud
var sim: BattleSim = null

var selected_id := ""
## 편집 중 정보. 비어 있으면 편집 아님.
## {kind: "move"|"new"|"fence", id, type, x, z, rot, ox, oz, orot, add, remove}
var edit: Dictionary = {}

var _pressing := false
var _dragging := false
var _drag_kind := ""
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _grab_offset := Vector2i.ZERO
var _fence_start := Vector2i.ZERO
var _fence_drag: Array[String] = []
var _touches: Dictionary = {}
var _gesture := false
var _alt_pan := false
var _autosave_t := 0.0
var _background := false
var _skip_frame := false
var _castle_id := "castle_01"
var _last_ui := ""
var _args: Dictionary = {}


func _ready() -> void:
	_args = _parse_args()
	state = GameState.new()
	saver = SaveManager.new(String(_args.get("save-dir", "user://")))
	if _args.has("save-dir"):
		DirAccess.make_dir_recursive_absolute(saver.dir)
		if _args.has("fresh"):
			saver.delete_all()
	world = WorldView.new()
	world.name = "World"
	add_child(world)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	_connect_hud()
	var res := saver.load_into(state)
	if res.status == "new":
		saver.save(state)
	_castle_id = String(GridLogic.castle_of(state.buildings).get("id", "castle_01"))
	state.changed.connect(_on_state_changed)
	state.construction_finished.connect(_on_construction_finished)
	_load_settings()
	_sync_world()
	_refresh_hud()
	if String(res.message) != "":
		hud.show_dialog("저장 데이터 안내", res.message)
	if _args.has("integration"):
		var it = load("res://tests/integration_driver.gd").new()
		add_child(it)
		it.run(self)
	if _args.has("shots"):
		var driver = load("res://scripts/debug/shot_driver.gd").new()
		add_child(driver)
		driver.run(self, String(_args.get("shots")), String(_args.get("scenario", "full")))


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var i := s.find("=")
		if i >= 0:
			out[s.substr(0, i)] = s.substr(i + 1)
		else:
			out[s] = true
	return out


func _connect_hud() -> void:
	hud.start_raid_pressed.connect(_start_raid)
	hud.build_pressed.connect(_open_build_menu)
	hud.build_menu_closed.connect(func(): hud.hide_build_menu())
	hud.buy_pressed.connect(_begin_new)
	hud.fence_pressed.connect(_begin_fence)
	hud.move_pressed.connect(func(): _begin_move(selected_id))
	hud.upgrade_pressed.connect(_upgrade_selected)
	hud.decor_pressed.connect(func(): _begin_decor(selected_id))
	hud.decor_option.connect(_on_decor_option)
	hud.decor_done.connect(_confirm_edit)
	hud.decor_cancel.connect(_cancel_edit)
	hud.info_closed.connect(_deselect)
	hud.edit_cancel.connect(_cancel_edit)
	hud.edit_rotate.connect(_rotate_edit)
	hud.edit_confirm.connect(_confirm_edit)
	hud.pause_pressed.connect(_pause_battle)
	hud.resume_pressed.connect(_resume_battle)
	hud.result_closed.connect(_on_result_closed)
	hud.menu_action.connect(_on_menu_action)


# ------------------------------------------------------------------ 프레임

func _process(delta: float) -> void:
	if _background:
		return
	if _skip_frame:
		_skip_frame = false
		return
	var dt := minf(delta, 0.25)
	if hud.fps_on or hud.fps_label != null:
		hud.set_fps_text("FPS %d · %.1fms" % [Engine.get_frames_per_second(), delta * 1000.0])
	match state.mode:
		GameState.MODE_VILLAGE, GameState.MODE_RAID_READY, GameState.MODE_BUILD:
			state.tick(dt)
			_autosave_t += dt
			if _autosave_t >= AUTOSAVE_SECONDS:
				_autosave_t = 0.0
				saver.save(state)
	var village_time: bool = state.mode in GameConfig.construction().progress_states
	world.update_village(state.buildings, state.all_edges(), dt, village_time)
	match state.mode:
		GameState.MODE_BATTLE:
			if sim != null:
				sim.advance(dt)
				world.update_battle(sim, dt, _castle_id)
				if sim.outcome != "":
					_finish_battle()
	_refresh_hud()


func _on_state_changed() -> void:
	if selected_id != "" and edit.is_empty() and hud.info_panel.visible:
		var b := state.get_building(selected_id)
		if not b.is_empty():
			hud.show_info(b, state)


func _on_construction_finished(id: String) -> void:
	var b := state.get_building(id)
	if b.is_empty():
		return
	hud.toast("%s 완성!" % GameConfig.type_label(b.type))
	saver.save(state)
	_on_state_changed()


func _sync_world() -> void:
	world.sync_buildings(state.buildings)
	world.rebuild_fences(state.all_edges())


func _refresh_hud() -> void:
	var m := state.mode
	var producing: bool = m in GameConfig.economy().income_states and state.count_type("lumber_camp") > 0
	hud.set_wood(state.wood, state.capacity(), producing)
	var battle_like := m == GameState.MODE_BATTLE or m == GameState.MODE_PAUSED or m == GameState.MODE_RESULT
	var stage_id := state.ready_stage
	var label := state.stage_label(stage_id)
	if state.highest_cleared >= stage_id and state.raid_ready:
		label += " 다시 도전"
	var knights := int(GameConfig.stage(stage_id).knight_count)
	var assist_pct := int(round((1.0 - state.assist_multiplier()) * 100.0))
	hud.assist_on = state.assist_enabled
	var key := "%s|%s|%s|%d|%s|%s|%d" % [m, state.raid_ready, label, int(ceil(state.raid_timer)), sim != null, hud.info_panel.visible, assist_pct]
	if key != _last_ui:
		_last_ui = key
		hud.set_raid(state.raid_ready, label, knights, state.raid_timer, not battle_like, assist_pct)
		# 선택 정보 패널이 열려 있으면 좁은 화면에서 겹치지 않게 건설 버튼을 숨긴다
		hud.set_village_controls((m == GameState.MODE_VILLAGE or m == GameState.MODE_RAID_READY) and not hud.info_panel.visible)
	if sim != null and (m == GameState.MODE_BATTLE or m == GameState.MODE_PAUSED):
		hud.set_battle(true, state.stage_label(sim.stage_id), sim.remaining(), sim.castle_hp, sim.castle_max)
	else:
		hud.set_battle(false)


# ------------------------------------------------------------------ 선택·건설

func _select(id: String) -> void:
	selected_id = id
	var b := state.get_building(id)
	world.show_selection(b)
	hud.hide_build_menu()
	hud.show_info(b, state)


func _deselect() -> void:
	selected_id = ""
	world.show_selection({})
	hud.hide_info()


func _can_edit() -> bool:
	return edit.is_empty() and (state.mode == GameState.MODE_VILLAGE or state.mode == GameState.MODE_RAID_READY)


func _open_build_menu() -> void:
	if not _can_edit():
		return
	_deselect()
	hud.show_build_menu(state)


func _begin_move(id: String) -> void:
	if not _can_edit():
		return
	var b := state.get_building(id)
	if b.is_empty() or not bool(GameConfig.building_def(b.type).get("movable", false)):
		hud.toast("성은 옮길 수 없어요")
		return
	_deselect()
	hud.hide_build_menu()
	edit = {kind = "move", id = id, type = b.type, x = int(b.x), z = int(b.z), rot = int(b.rot), ox = int(b.x), oz = int(b.z), orot = int(b.rot)}
	edit.was_ready = state.raid_ready
	state.mode = GameState.MODE_BUILD
	_update_edit()


func _begin_new(type: String) -> void:
	if not _can_edit():
		return
	hud.hide_build_menu()
	if state.count_type(type) >= state.max_count(type):
		hud.toast("최대 %d개까지 지을 수 있어요" % state.max_count(type))
		return
	var spot := _find_spot(type)
	edit = {kind = "new", type = type, x = spot.x, z = spot.y, rot = 0}
	edit.was_ready = state.raid_ready
	state.mode = GameState.MODE_BUILD
	_update_edit()


func _find_spot(type: String) -> Vector2i:
	var fp := GameConfig.footprint(type)
	var target := WorldView.to_logical(world.cam_target)
	var best := Vector2i(0, 0)
	var best_d := INF
	for x in range(0, GameConfig.grid_width() - fp.x + 1):
		for z in range(0, GameConfig.grid_depth() - fp.y + 1):
			var v := GridLogic.validate_building(state.buildings, state.interior_fences, {id = "__new__", type = type, x = x, z = z})
			if not v.ok:
				continue
			var d := Vector2(x + fp.x * 0.5, z + fp.y * 0.5).distance_to(target)
			if d < best_d:
				best_d = d
				best = Vector2i(x, z)
	return best


func _begin_fence() -> void:
	if not _can_edit():
		return
	hud.hide_build_menu()
	edit = {kind = "fence", add = {}, remove = {}}
	edit.was_ready = state.raid_ready
	state.mode = GameState.MODE_BUILD
	_update_edit()


## 꾸미기: 작업 사본을 미리보고 '완료'에서 한 번에 저장(무료). '취소'는 원래 외형으로.
func _begin_decor(id: String) -> void:
	if not _can_edit():
		return
	var b := state.get_building(id)
	if b.is_empty() or not Decor.has_parts(b.type):
		return
	_deselect()
	hud.hide_build_menu()
	edit = {kind = "deco", id = id, type = b.type, deco = Decor.sanitize(b.type, b.get("deco", {})), was_ready = state.raid_ready}
	state.mode = GameState.MODE_BUILD
	hud.set_village_controls(false)
	hud.show_decor(b.type, GameConfig.type_label(b.type), edit.deco)
	# 패널이 오른쪽을 가리므로 건물을 화면 왼쪽 가운데로 옮겨 보여 준다
	var vp := get_viewport().get_visible_rect().size
	var c := WorldView.building_center(b.type, b.x, b.z)
	world.pan_by_screen(world.camera.unproject_position(c), Vector2(vp.x * 0.3, vp.y * 0.52))
	world.show_selection(b)


func _on_decor_option(part_id: String, option_id: String) -> void:
	if edit.is_empty() or edit.kind != "deco":
		return
	edit.deco[part_id] = option_id
	edit.deco = Decor.sanitize(edit.type, edit.deco)
	hud.set_decor_selection(edit.deco)
	var preview := state.get_building(edit.id).duplicate()
	preview.deco = edit.deco
	var list: Array = []
	for b in state.buildings:
		list.append(preview if b.id == edit.id else b)
	world.sync_buildings(list)


func _rotate_edit() -> void:
	if edit.is_empty() or edit.kind == "fence":
		return
	edit.rot = (int(edit.rot) + 1) % 4
	_update_edit()


func _update_edit() -> void:
	if edit.is_empty():
		return
	world.set_grid_visible(true)
	var icon := {house = "house", defense_tower = "tower", lumber_camp = "lumber", castle = "castle"}
	match edit.kind:
		"move":
			var v := state.check_move(edit.id, edit.x, edit.z, edit.rot)
			var b := state.get_building(edit.id)
			world.place_node(world.building_node(edit.id), edit.type, edit.x, edit.z, edit.rot)
			world.show_footprint(edit.type, edit.x, edit.z, v.ok)
			var fp := GameConfig.footprint(edit.type)
			hud.show_edit(icon.get(edit.type, "house"), "%s · Lv.%d  (%d×%d칸 · 이동 중)" % [GameConfig.type_label(edit.type), int(b.level), fp.x, fp.y],
				v.ok, "배치 가능" if v.ok else String(v.reason), "배치", true, "건물을 끌어 원하는 곳에 놓으세요")
		"new":
			var v := state.check_new_building(edit.type, edit.x, edit.z, edit.rot)
			world.show_ghost(edit.type, edit.x, edit.z, edit.rot)
			world.show_footprint(edit.type, edit.x, edit.z, v.ok)
			var fp := GameConfig.footprint(edit.type)
			var cost := state.build_cost(edit.type)
			hud.show_edit(icon.get(edit.type, "house"), "새 %s  (%d×%d칸 · 목재 %d)" % [GameConfig.type_label(edit.type), fp.x, fp.y, cost],
				v.ok, "배치 가능" if v.ok else String(v.reason), "배치 · 목재 %d" % cost, true, "새 건물을 끌어 원하는 곳에 놓으세요")
		"fence":
			var add: Dictionary = edit.add.duplicate()
			for k in _fence_drag:
				if _fence_addable(k):
					add[k] = true
			var ok := false
			var status := "땅을 끌어 울타리 선을 그어 보세요"
			var cost := 0
			if not add.is_empty() or not edit.remove.is_empty():
				var v := state.check_fences(add, edit.remove)
				ok = v.ok
				cost = int(v.get("cost", 0))
				status = ("새 울타리 %d변 · 제거 %d변" % [add.size(), edit.remove.size()]) if ok else String(v.reason)
			world.show_fence_plan(add, edit.remove, ok or (add.is_empty() and edit.remove.is_empty()))
			hud.show_edit("fence", "울타리 편집 (한 변 목재 %d)" % int(GameConfig.defaults().fences.edge_build_cost), ok, status,
				"배치 · 목재 %d" % cost, false, "땅을 끌어 선을 긋고, 울타리를 누르면 제거 표시돼요 · 두 손가락으로 화면 이동")


func _fence_addable(k: String) -> bool:
	return GridLogic.is_interior_edge(k) and not state.interior_fences.has(k)


func _confirm_edit() -> void:
	if edit.is_empty():
		return
	var r: Dictionary
	match edit.kind:
		"move":
			r = state.commit_move(edit.id, edit.x, edit.z, edit.rot)
			if r.ok:
				hud.toast("%s을(를) 옮겼어요" % GameConfig.type_label(edit.type))
		"new":
			var cost := state.build_cost(edit.type)
			r = state.commit_new_building(edit.type, edit.x, edit.z, edit.rot)
			if r.ok:
				var secs := int(GameState.build_seconds(edit.type))
				hud.toast(("%s 공사 시작! 목재 -%d · %d초 뒤 완성" % [GameConfig.type_label(edit.type), cost, secs]) if secs > 0 else ("%s 완성! 목재 -%d" % [GameConfig.type_label(edit.type), cost]))
		"fence":
			r = state.commit_fences(edit.add, edit.remove)
			if r.ok:
				hud.toast("울타리를 바꿨어요" + (" · 목재 -%d" % int(r.cost) if int(r.cost) > 0 else ""))
		"deco":
			r = state.commit_decor(edit.id, edit.deco)
			if r.ok:
				hud.toast("새 모습으로 꾸몄어요")
	if not r.ok:
		hud.toast(String(r.reason))
		_update_edit()
		return
	saver.save(state)
	_end_edit()


func _cancel_edit() -> void:
	if edit.is_empty():
		return
	_end_edit()


## 편집 종료: 확정되지 않은 미리보기는 버리고 확정 상태를 다시 그린다.
func _end_edit() -> void:
	var was_ready := bool(edit.get("was_ready", true))
	edit = {}
	_fence_drag.clear()
	_pressing = false
	world.hide_ghost()
	world.hide_footprint()
	world.clear_fence_plan()
	world.set_grid_visible(false)
	world.show_selection({})
	hud.hide_edit()
	hud.hide_decor()
	state.mode = state.idle_mode()
	_sync_world()
	_last_ui = ""
	if state.raid_ready and not was_ready:
		hud.toast("습격 준비 완료! 방어 시작을 눌러 주세요")


func _upgrade_selected() -> void:
	if selected_id == "" or not _can_edit():
		return
	var r := state.commit_upgrade(selected_id)
	if r.ok:
		saver.save(state)
		world.sync_buildings(state.buildings)
		var b := state.get_building(selected_id)
		hud.toast("방어탑 Lv.%d! 공격력 %d" % [int(b.level), int(GameConfig.tower_level(int(b.level)).damage)])
		hud.show_info(b, state)
	else:
		hud.toast(String(r.reason))


# ------------------------------------------------------------------ 습격

func _start_raid() -> void:
	if state.mode == GameState.MODE_BUILD or not edit.is_empty():
		hud.toast("배치를 먼저 끝내세요")
		return
	if state.mode != GameState.MODE_RAID_READY:
		return
	_deselect()
	hud.hide_build_menu()
	var r := state.begin_battle()
	if not r.ok:
		hud.show_dialog("습격을 시작할 수 없어요", String(r.reason))
		return
	# 전투 시작 전 저장 = 준비 상태 스냅샷(전투 중 종료 시 여기로 돌아온다)
	saver.save(state)
	world.clear_battle()
	sim = BattleSim.new()
	sim.setup(state.buildings, state.all_edges(), int(r.stage), float(r.get("hp_multiplier", 1.0)))
	if not sim.constructing_towers.is_empty():
		hud.toast("공사 중인 방어탑 %d개는 이번 전투에 참여하지 않아요" % sim.constructing_towers.size(), 3.0)
	_last_ui = ""
	if sim.outcome == "abort":
		_finish_battle()


func _finish_battle() -> void:
	var outcome := sim.outcome
	if outcome == "abort":
		var reason := sim.abort_reason
		state.abort_battle()
		saver.save(state)
		sim = null
		world.clear_battle()
		print("전투 중단 기록: ", reason)
		hud.show_dialog("전투를 멈췄어요", "%s\n보상 없이 준비 상태로 돌아갔어요." % reason)
		_last_ui = ""
		return
	var stage_id := sim.stage_id
	var won := outcome == "win"
	var res := state.resolve_battle(state.current_battle_id, stage_id, won)
	saver.save(state)
	# 남은 화살은 바로 정리(기사는 결과 뒤에서 멈춘 채 보인다)
	sim.bolts.clear()
	world.update_battle(sim, 0.0, _castle_id)
	var wanted := int(GameConfig.stage(stage_id).win_wood)
	var final_stage := stage_id >= GameConfig.stage_count()
	var next_text := ""
	if won and not final_stage:
		next_text = "다음: %s · 마을에서 약 %d초 뒤 준비돼요" % [state.stage_label(stage_id + 1), int(ceil(state.raid_timer))]
	var tips := BattleAdvisor.advise(sim, state)
	print("조언: ", tips)
	hud.show_result(won, state.stage_label(stage_id), int(res.reward), wanted, final_stage, next_text, tips)
	_last_ui = ""


func _on_result_closed(action: String) -> void:
	hud.hide_overlay()
	sim = null
	world.clear_battle()
	state.leave_result()
	_last_ui = ""
	if action == "retry" or action == "replay":
		_start_raid()


func _pause_battle() -> void:
	if state.mode != GameState.MODE_BATTLE:
		return
	state.pause_return = GameState.MODE_BATTLE
	state.mode = GameState.MODE_PAUSED
	hud.show_pause()


func _resume_battle() -> void:
	if state.mode != GameState.MODE_PAUSED:
		return
	state.mode = state.pause_return
	hud.hide_overlay()
	_skip_frame = true


func _on_menu_action(action: String) -> void:
	match action:
		"recenter":
			world.reset_camera()
		"shadows":
			hud.shadows_on = not hud.shadows_on
			world.set_shadows(hud.shadows_on)
			_save_settings()
		"fps":
			hud.fps_on = not hud.fps_on
			_save_settings()
		"assist":
			state.assist_enabled = not state.assist_enabled
			saver.save(state)
			_last_ui = ""
			hud.toast("도움 모드를 켰어요: 같은 단계에서 %d번 이상 지면 기사 체력이 조금 줄어요" % int(GameConfig.raids().assist.after_losses) if state.assist_enabled else "도움 모드를 껐어요", 3.0)
		"reset":
			if not edit.is_empty():
				_end_edit()
			sim = null
			world.clear_battle()
			saver.delete_all()
			state.new_game()
			saver.save(state)
			_deselect()
			_sync_world()
			world.reset_camera()
			_last_ui = ""
			hud.toast("새 마을에서 시작해요")


# ------------------------------------------------------------------ 표시 설정(user://settings.cfg)

func _settings_path() -> String:
	return saver.dir + "settings.cfg"


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(_settings_path()) == OK:
		hud.shadows_on = bool(cf.get_value("display", "shadows", true))
		hud.fps_on = bool(cf.get_value("display", "show_fps", false))
	world.set_shadows(hud.shadows_on)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("display", "shadows", hud.shadows_on)
	cf.set_value("display", "show_fps", hud.fps_on)
	cf.save(_settings_path())


# ------------------------------------------------------------------ 앱 상태

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _args.has("no-focus-pause") and what == NOTIFICATION_APPLICATION_FOCUS_OUT:
				return
			_enter_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _background:
				_background = false
				_skip_frame = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			if state != null and state.mode != GameState.MODE_BATTLE and state.mode != GameState.MODE_PAUSED:
				saver.save(state)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()


func _enter_background() -> void:
	if _background or state == null:
		return
	_background = true
	_pressing = false
	_touches.clear()
	_gesture = false
	if state.mode == GameState.MODE_BATTLE:
		_pause_battle()
	elif state.mode != GameState.MODE_PAUSED:
		# 전투 중이 아니면 확정 상태만 저장(편집 미리보기는 저장하지 않음)
		saver.save(state)


func _on_back() -> void:
	if state.mode == GameState.MODE_BATTLE:
		_pause_battle()
	elif hud.overlay_visible() and state.mode != GameState.MODE_PAUSED and state.mode != GameState.MODE_RESULT:
		hud.hide_overlay()
	elif not edit.is_empty():
		_cancel_edit()
	elif hud.build_menu.visible:
		hud.hide_build_menu()
	elif selected_id != "":
		_deselect()


# ------------------------------------------------------------------ 입력

func _unhandled_input(event: InputEvent) -> void:
	if hud.overlay_visible() or _background:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not hud.is_over_ui(st.position):
				_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2 and not _gesture:
			_gesture = true
			_cancel_pointer()
		elif _touches.is_empty():
			_gesture = false
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return
		var old: Vector2 = _touches[sd.index]
		_touches[sd.index] = sd.position
		if _gesture and _touches.size() >= 2:
			var other_pos := Vector2.ZERO
			for i in _touches:
				if i != sd.index:
					other_pos = _touches[i]
					break
			var d_old := old.distance_to(other_pos)
			var d_new := sd.position.distance_to(other_pos)
			if d_old > 10.0 and d_new > 10.0:
				world.zoom_by(d_old / d_new)
			world.pan_by_screen((old + other_pos) * 0.5, (sd.position + other_pos) * 0.5)
		return
	if event is InputEventMagnifyGesture:
		world.zoom_by(1.0 / (event as InputEventMagnifyGesture).factor)
		return
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		var c := get_viewport().get_visible_rect().size * 0.5
		world.pan_by_screen(c, c - pg.delta * 8.0)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					world.zoom_by(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					world.zoom_by(1.1)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_alt_pan = mb.pressed
				_last_pos = mb.position
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pointer_down(mb.position)
				else:
					_pointer_up(mb.position)
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _alt_pan:
			world.pan_by_screen(_last_pos, mm.position)
			_last_pos = mm.position
		elif _pressing:
			_pointer_move(mm.position)


func _cancel_pointer() -> void:
	if _drag_kind == "fence":
		_fence_drag.clear()
		_update_edit()
	_pressing = false
	_dragging = false


## 화면 좌표 → 논리 지면 좌표(없으면 null)
func _logical_at(pos: Vector2):
	var p = world.ground_point(pos)
	if p == null:
		return null
	return WorldView.to_logical(p)


func _cell_at(pos: Vector2) -> Vector2i:
	var p = _logical_at(pos)
	if p == null:
		return Vector2i(-99, -99)
	return Vector2i(int(floor(p.x)), int(floor(p.y)))


func _lattice_at(pos: Vector2) -> Vector2i:
	var p = _logical_at(pos)
	if p == null:
		return Vector2i(-99, -99)
	return Vector2i(int(round(p.x)), int(round(p.y)))


func _pointer_down(pos: Vector2) -> void:
	if _gesture:
		return
	_pressing = true
	_dragging = false
	_press_pos = pos
	_last_pos = pos
	_drag_kind = "pan"
	if edit.is_empty() or edit.kind == "deco":
		return
	if edit.kind == "fence":
		_drag_kind = "fence"
		_fence_start = _lattice_at(pos)
		_fence_drag.clear()
	else:
		var cell := _cell_at(pos)
		var fp := GameConfig.footprint(edit.type)
		var rel := cell - Vector2i(edit.x, edit.z)
		if rel.x >= 0 and rel.y >= 0 and rel.x < fp.x and rel.y < fp.y:
			_drag_kind = "ghost"
			_grab_offset = rel


func _pointer_move(pos: Vector2) -> void:
	if _gesture:
		return
	if not _dragging and pos.distance_to(_press_pos) > DRAG_THRESHOLD:
		_dragging = true
	if not _dragging:
		return
	match _drag_kind:
		"pan":
			world.pan_by_screen(_last_pos, pos)
		"ghost":
			_move_ghost_to(_cell_at(pos) - _grab_offset)
		"fence":
			var end := _lattice_at(pos)
			if absi(end.x - _fence_start.x) >= absi(end.y - _fence_start.y):
				end.y = _fence_start.y
			else:
				end.x = _fence_start.x
			var edges := GridLogic.edges_between_points(_fence_start, end)
			if edges != _fence_drag:
				_fence_drag = edges
				_update_edit()
	_last_pos = pos


func _move_ghost_to(cell: Vector2i) -> void:
	var fp := GameConfig.footprint(edit.type)
	# 지도 밖 1칸까지는 끌 수 있게 두어 '지도 밖' 이유를 보여 준다
	var nx := clampi(cell.x, -1, GameConfig.grid_width() - fp.x + 1)
	var nz := clampi(cell.y, -1, GameConfig.grid_depth() - fp.y + 1)
	if nx != int(edit.x) or nz != int(edit.z):
		edit.x = nx
		edit.z = nz
		_update_edit()


func _pointer_up(pos: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	if _dragging:
		_dragging = false
		if _drag_kind == "fence":
			for k in _fence_drag:
				if edit.remove.has(k):
					edit.remove.erase(k)
				elif _fence_addable(k):
					edit.add[k] = true
			_fence_drag.clear()
			_update_edit()
		return
	_tap(pos)


func _tap(pos: Vector2) -> void:
	if not edit.is_empty() and edit.kind == "deco":
		return
	if not edit.is_empty():
		if edit.kind == "fence":
			_toggle_fence_at(pos)
		else:
			var fp := GameConfig.footprint(edit.type)
			_move_ghost_to(_cell_at(pos) - Vector2i(fp.x / 2, fp.y / 2))
		return
	if state.mode != GameState.MODE_VILLAGE and state.mode != GameState.MODE_RAID_READY:
		return
	hud.hide_build_menu()
	var b := state.building_at(_cell_at(pos))
	if b.is_empty():
		_deselect()
	else:
		_select(b.id)


func _toggle_fence_at(pos: Vector2) -> void:
	var p = _logical_at(pos)
	if p == null:
		return
	var hz := int(round(p.y))
	var hx := int(floor(p.x))
	var vx := int(round(p.x))
	var vz := int(floor(p.y))
	var dh := absf(p.y - hz)
	var dv := absf(p.x - vx)
	var k := ""
	if dh <= dv and dh < 0.35:
		k = "h:%d:%d" % [hx, hz]
	elif dv < 0.35:
		k = "v:%d:%d" % [vx, vz]
	if k == "":
		return
	if edit.add.has(k):
		edit.add.erase(k)
	elif state.interior_fences.has(k):
		if edit.remove.has(k):
			edit.remove.erase(k)
		else:
			edit.remove[k] = true
	elif GridLogic.is_interior_edge(k) and not GridLogic.gate_edges().has(k):
		edit.add[k] = true
	else:
		hud.toast(GridLogic.REASON_FIXED)
		return
	_update_edit()
