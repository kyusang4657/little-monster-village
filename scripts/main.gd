extends Node3D
## 게임 흐름·입력·저장 시점을 묶는 컨트롤러.

const DRAG_THRESHOLD := 14.0
const AUTOSAVE_SECONDS := 5.0

var state: GameState
var saver: SaveManager
var world: WorldView
var hud: Hud
var tutorial: Tutorial
var story_view: StoryView
var _story_then: Callable
var _imp_taps := 0
## 성이 자란 전투 뒤, 결과·이야기가 끝나면 뿔이 축하 연출
var _celebrate_level := 0
var _story_current := ""
## 결과 화면을 닫은 뒤 이어서 보여 줄 장면(장 완료·앞마당 점령 등)
var _tutorial_done := false
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
	tutorial = Tutorial.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	tutorial.setup(hud)
	tutorial.finished.connect(_on_tutorial_finished)
	story_view = StoryView.new()
	story_view.name = "Story"
	add_child(story_view)
	story_view.setup(hud)
	story_view.finished.connect(_on_story_finished)
	_connect_hud()
	var res := saver.load_into(state)
	if res.status == "new":
		saver.save(state)
	_castle_id = String(GridLogic.castle_of(state.buildings).get("id", "castle_01"))
	state.changed.connect(_on_state_changed)
	state.construction_finished.connect(_on_construction_finished)
	world.outpost_fell.connect(func(_id: String): hud.toast("앞마당이 점령당했어요! 생산만 멈추고, 전투 뒤 수리할 수 있어요", 3.0))
	_load_settings()
	_sync_world()
	_refresh_hud()
	Sound.play_music("village")
	if String(res.message) != "":
		hud.show_dialog("저장 데이터 안내", res.message)
	var start_tutorial := not _tutorial_done and not _args.has("no-tutorial") and String(res.message) == ""
	# 첫 실행이면 프롤로그 → 안내. 지난 실행에서 못 보여 준 장면(story_pending)도 이어서 보여 준다
	var first: Array = ["new_game"] if state.highest_cleared == 0 and String(res.message) == "" else []
	_queue_story(first, func(): if start_tutorial: tutorial.start())
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
	hud.expand_pressed.connect(_open_expand_menu)
	hud.expand_selected.connect(_begin_expand)
	hud.story_replay.connect(_replay_story)
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
	_check_low_fps(delta)
	match state.mode:
		GameState.MODE_VILLAGE, GameState.MODE_RAID_READY, GameState.MODE_BUILD:
			state.tick(dt)
			_autosave_t += dt
			if _autosave_t >= AUTOSAVE_SECONDS:
				_autosave_t = 0.0
				saver.save(state)
	# 미뤄 둔 장면(결과·편집·창이 닫히면)
	if (not state.story_pending.is_empty() or _story_then.is_valid()) and _can_show_story():
		_story_next()
	var village_time: bool = state.mode in GameConfig.construction().progress_states
	world.update_village(state.buildings, state.all_edges(), dt, village_time)
	match state.mode:
		GameState.MODE_BATTLE:
			if sim != null:
				sim.advance(dt)
				world.update_battle(sim, dt, _castle_id)
				if sim.outcome != "":
					_finish_battle()
	if tutorial.current_id() == "select_tower" and selected_id == "" and edit.is_empty():
		for b in state.buildings:
			if b.type == "defense_tower":
				world.show_selection(b)
				break
	_refresh_hud()


## 그림자가 켜진 채 FPS 가 계속 낮으면 한 번만 그림자 끄기를 안내한다(설정은 사용자가 직접 바꾼다)
var _low_fps_t := 0.0
var _low_fps_hinted := false


func _check_low_fps(delta: float) -> void:
	if _low_fps_hinted or not (hud.shadows_on or hud.outlines_on) or _args.has("integration") or _args.has("shots"):
		return
	# 이야기·창이 떠 있을 때는 안내를 겹쳐 띄우지 않는다(시간도 세지 않음)
	if story_view.active() or hud.overlay_visible():
		return
	if not state.mode in [GameState.MODE_VILLAGE, GameState.MODE_RAID_READY, GameState.MODE_BATTLE]:
		return
	var cfg: Dictionary = GameConfig.defaults().get("performance_targets", {}).get("low_fps_hint", {})
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < float(cfg.get("below_fps", 24)):
		_low_fps_t += delta
	else:
		_low_fps_t = maxf(0.0, _low_fps_t - delta)
	if _low_fps_t >= float(cfg.get("window_seconds", 8)):
		_low_fps_hinted = true
		hud.toast("화면이 조금 느려요. 메뉴(≡)에서 그림자·외곽선을 끄면 빨라져요", 4.0)


func _on_state_changed() -> void:
	if selected_id != "" and edit.is_empty() and hud.info_panel.visible:
		var b := state.get_building(selected_id)
		if not b.is_empty():
			hud.show_info(b, state)


func _on_construction_finished(id: String) -> void:
	var b := state.get_building(id)
	if b.is_empty():
		return
	if state.last_finished_repair:
		hud.toast("%s 수리 완료! 생산이 다시 시작돼요" % GameConfig.type_label(b.type))
	else:
		hud.toast("%s 완성!" % GameConfig.type_label(b.type))
		if b.type == "outpost":
			_queue_story(["outpost_built"])
	tutorial.notify("construction_finished")
	Sound.play("build_done")
	saver.save(state)
	_on_state_changed()


func _sync_world() -> void:
	world.set_map(state.bounds())
	world.imp.set_level(state.castle_level())
	world.sync_buildings(state.buildings)
	world.rebuild_fences(state.all_edges())


func _refresh_hud() -> void:
	var m := state.mode
	var producing: bool = m in GameConfig.economy().income_states and state.income_rate() > 0.0
	hud.set_wood(state.wood, state.capacity(), producing, state.income_rate())
	var battle_like := m == GameState.MODE_BATTLE or m == GameState.MODE_PAUSED or m == GameState.MODE_RESULT
	var stage_id := state.ready_stage
	var ch := GameConfig.chapter_of_stage(stage_id)
	var label := state.stage_label(stage_id)
	if not ch.is_empty():
		label = "%s · %s" % [String(ch.label), label]
	var units := GameConfig.stage_units(stage_id)
	var bosses := 0
	for u in units:
		if String(u.get("kind", "knight")) != "knight":
			bosses += 1
	var detail := ("기사 %d명 + 보스 %d명 접근" % [units.size() - bosses, bosses]) if bosses > 0 else ("기사 %d명 접근" % units.size())
	if state.highest_cleared >= stage_id and state.raid_ready:
		detail = "다시 도전 · " + detail
	var assist_pct := int(round((1.0 - state.assist_multiplier()) * 100.0))
	hud.assist_on = state.assist_enabled
	var key := "%s|%s|%s|%s|%d|%s|%s|%d" % [m, state.raid_ready, label, detail, int(ceil(state.raid_timer)), sim != null, hud.info_panel.visible, assist_pct]
	if key != _last_ui:
		_last_ui = key
		hud.set_raid(state.raid_ready, label, detail, state.raid_timer, not battle_like, assist_pct)
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
	if b.get("type", "") == "defense_tower":
		tutorial.notify("selected_tower")
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
	tutorial.notify("build_menu_opened")


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
	if state.max_count(type) <= 0:
		hud.toast("성 Lv.%d에서 열려요" % GameState.unlock_level_for(type))
		return
	if state.count_type(type) >= state.max_count(type):
		hud.toast("최대 %d개까지 지을 수 있어요" % state.max_count(type))
		return
	if type == "outpost" and GridLogic.open_sites(state.bounds()).is_empty():
		hud.toast("숲 자원 지점이 있는 땅을 먼저 넓혀 주세요")
		return
	var spot := _find_spot(type)
	edit = {kind = "new", type = type, x = spot.x, z = spot.y, rot = 0}
	edit.was_ready = state.raid_ready
	state.mode = GameState.MODE_BUILD
	_update_edit()
	tutorial.notify("build_preview")


func _find_spot(type: String) -> Vector2i:
	var fp := GameConfig.footprint(type)
	var target := WorldView.to_logical(world.cam_target)
	var bb := state.bounds()
	if type == "outpost":
		for site in GridLogic.open_sites(bb):
			return Vector2i(int(site.x), int(site.z))
	# 화면 가운데에서 가까운 칸부터 검사해 처음 놓을 수 있는 칸을 고른다(넓은 지도에서도 길 검사를 몇 번만 함)
	var cands: Array = []
	for x in range(bb.position.x, bb.end.x - fp.x + 1):
		for z in range(bb.position.y, bb.end.y - fp.y + 1):
			cands.append(Vector3(x, z, Vector2(x + fp.x * 0.5, z + fp.y * 0.5).distance_squared_to(target)))
	cands.sort_custom(func(a: Vector3, b: Vector3): return a.z < b.z or (a.z == b.z and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	for c in cands:
		var v := GridLogic.validate_building(state.buildings, state.interior_fences, {id = "__new__", type = type, x = int(c.x), z = int(c.y)}, "", bb)
		if v.ok:
			return Vector2i(int(c.x), int(c.y))
	return Vector2i(bb.position.x, bb.position.y)


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


# ------------------------------------------------------------------ 땅 넓히기

func _open_expand_menu() -> void:
	if not _can_edit():
		return
	hud.hide_build_menu()
	hud.show_expand_menu(state)


func _begin_expand(dir: String) -> void:
	if not _can_edit():
		return
	_deselect()
	edit = {kind = "expand", dir = dir, was_ready = state.raid_ready}
	state.mode = GameState.MODE_BUILD
	var r := GameConfig.expansion_rect(dir, state.bounds())
	var vp := get_viewport().get_visible_rect().size
	world.pan_by_screen(world.camera.unproject_position(WorldView.W(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)), vp * 0.5)
	_update_edit()


# ------------------------------------------------------------------ 이야기



## 장면 대기열은 state.story_pending(저장됨)에 쌓는다. 화면이 비면 차례로 보여 주고, 다 보여 주면 then 을 부른다.
## 이미 대기 중인 장면·콜백은 지우지 않고 뒤에 잇는다(공사 완료 같은 비동기 장면이 장 이야기를 덮지 않게).
func _queue_story(triggers: Array, then: Callable = Callable()) -> void:
	if not _args.has("no-story"):
		var added := false
		for t in triggers:
			var sc := Story.scene_for(String(t))
			if sc.is_empty() or state.story_seen.has(String(sc.id)) or state.story_pending.has(String(t)):
				continue
			state.story_pending.append(String(t))
			added = true
		if added:
			saver.save(state)
	if then.is_valid():
		if _story_then.is_valid():
			var prev := _story_then
			_story_then = func(): prev.call(); then.call()
		else:
			_story_then = then
	_story_next()


## 장면을 띄워도 되는 때: 다른 창·편집·안내·전투가 없을 때
func _can_show_story() -> bool:
	return not story_view.active() and edit.is_empty() and not hud.overlay_visible() and not tutorial.active() \
		and not _background and state.mode in [GameState.MODE_VILLAGE, GameState.MODE_RAID_READY]


func _story_next() -> void:
	if not _can_show_story():
		return
	# 검사·캡처용 --no-story: 저장본에 남은 대기 장면도 보여 주지 않는다(콜백은 그대로 실행)
	if _args.has("no-story"):
		state.story_pending.clear()
	while not state.story_pending.is_empty():
		var t := String(state.story_pending[0])
		var sc := Story.scene_for(t)
		if sc.is_empty() or state.story_seen.has(String(sc.id)):
			state.story_pending.pop_front()
			continue
		_story_current = t
		_reset_pointer_state()
		if story_view.play(sc):
			return
		# 대사가 없는 장면은 건너뛴다(대기열에서 빼고 다음으로)
		state.story_pending.pop_front()
		_story_current = ""
	var then := _story_then
	_story_then = Callable()
	if then.is_valid():
		then.call()


## 장면을 끝까지 보거나 건너뛰면 그때 본 것으로 저장한다(도중에 앱이 꺼지면 다음 실행에서 다시 보여 줌)
func _on_story_finished(id: String) -> void:
	if _story_current != "" and state.story_pending.has(_story_current):
		state.story_seen[id] = true
		state.story_pending.erase(_story_current)
		saver.save(state)
	_story_current = ""
	_story_next()


func _replay_story(id: String) -> void:
	_story_current = ""
	_reset_pointer_state()
	story_view.play(Story.scene_by_id(id))


## 장면이 열리면 눌림·끌기·두 손가락 상태를 비운다(놓는 입력이 장면에 막혀 남지 않게)
func _reset_pointer_state() -> void:
	_cancel_pointer()
	_touches.clear()
	_gesture = false
	_alt_pan = false


func _rotate_edit() -> void:
	if edit.is_empty() or edit.kind == "fence":
		return
	edit.rot = (int(edit.rot) + 1) % 4
	_update_edit()


func _update_edit() -> void:
	if edit.is_empty():
		return
	world.set_grid_visible(true)
	var icon := {house = "house", defense_tower = "tower", lumber_camp = "lumber", castle = "castle", outpost = "outpost", flowerbed = "flower", lantern = "lantern"}
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
		"expand":
			var e := GameConfig.expansion_def(edit.dir)
			var v := state.check_expand(edit.dir)
			world.show_zone(GameConfig.expansion_rect(edit.dir, state.bounds()), v.ok)
			hud.show_edit("expand", "%s 넓히기 (+%d칸 · 목재 %d)" % [String(e.label), int(e.cells), int(e.cost)], v.ok,
				"넓힐 수 있어요" if v.ok else String(v.reason), "넓히기 · 목재 %d" % int(e.cost), false,
				"노란 땅이 마을이 돼요. 바깥 울타리와 정문은 새 경계로 옮겨져요")


func _fence_addable(k: String) -> bool:
	return GridLogic.is_interior_edge(k, state.bounds()) and not state.interior_fences.has(k)


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
				tutorial.notify("building_placed")
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
		"expand":
			var first := state.expansions.is_empty()
			r = state.commit_expand(edit.dir)
			if r.ok:
				hud.toast("%s을(를) 넓혔어요! 목재 -%d" % [String(GameConfig.expansion_def(edit.dir).label), int(r.cost)])
				if first:
					_queue_story(["first_expansion"])
	if not r.ok:
		hud.toast(String(r.reason))
		_update_edit()
		return
	saver.save(state)
	Sound.play("place")
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
	world.hide_zone()
	hud.hide_edit()
	hud.hide_decor()
	state.mode = state.idle_mode()
	_sync_world()
	_last_ui = ""
	if state.raid_ready and not was_ready:
		hud.toast("습격 준비 완료! 방어 시작을 눌러 주세요")
	# 편집 중 미뤄 둔 장면(첫 넓히기·앞마당 완성 등)
	_story_next()


func _upgrade_selected() -> void:
	if selected_id == "" or not _can_edit():
		return
	var sel := state.get_building(selected_id)
	if sel.get("type", "") == "outpost":
		var rp := state.commit_repair(selected_id)
		if rp.ok:
			saver.save(state)
			_sync_world()
			hud.toast("수리 시작! 목재 -%d · 일꾼이 고치러 가요" % int(rp.cost))
			Sound.play("place")
			hud.show_info(state.get_building(selected_id), state)
		else:
			hud.toast(String(rp.reason))
		return
	var r := state.commit_upgrade(selected_id)
	if r.ok:
		saver.save(state)
		world.sync_buildings(state.buildings)
		var b := state.get_building(selected_id)
		hud.toast("방어탑 Lv.%d! 공격력 %d" % [int(b.level), int(GameConfig.tower_level(int(b.level)).damage)])
		tutorial.notify("upgraded")
		Sound.play("upgrade")
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
	if story_view.active():
		return
	_deselect()
	hud.hide_build_menu()
	# 보스 단계는 처음 한 번 대화 장면 뒤에 시작
	var pre := "before_stage:%d" % state.ready_stage
	var sc := Story.scene_for(pre)
	if not sc.is_empty() and not state.story_seen.has(String(sc.id)) and not _args.has("no-story"):
		# 방어 시작을 눌렀으니 안내는 여기서 끝낸다(안내가 떠 있으면 장면이 기다리기만 하므로)
		tutorial.notify("battle_started")
		_queue_story([pre], _start_raid)
		return
	var r := state.begin_battle()
	if not r.ok:
		hud.show_dialog("습격을 시작할 수 없어요", String(r.reason))
		return
	# 전투 시작 전 저장 = 준비 상태 스냅샷(전투 중 종료 시 여기로 돌아온다)
	saver.save(state)
	world.clear_battle()
	sim = BattleSim.new()
	sim.setup(state.buildings, state.all_edges(), int(r.stage), float(r.get("hp_multiplier", 1.0)),
		{castle_hp = int(r.castle_hp), bounds = r.bounds, units = r.units, rally = r.rally})
	tutorial.notify("battle_started")
	Sound.play("raid_start")
	Sound.play_music("battle")
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
		# 전투 중 무너진 모습으로 바꾼 앞마당 등은 저장 상태대로 되돌린다
		_sync_world()
		print("전투 중단 기록: ", reason)
		hud.show_dialog("전투를 멈췄어요", "%s\n보상 없이 준비 상태로 돌아갔어요." % reason)
		Sound.play_music("village")
		_last_ui = ""
		return
	var stage_id := sim.stage_id
	var won := outcome == "win"
	var replay := state.highest_cleared >= stage_id
	# 앞마당이 점령되었으면 생산만 멈춘다(결과와 함께 한 번에 저장)
	var outpost_lost := false
	if not sim.outpost.is_empty() and bool(sim.outpost.captured):
		state.mark_outpost_lost(String(sim.outpost.id))
		outpost_lost = true
	var res := state.resolve_battle(state.current_battle_id, stage_id, won)
	# 결과 뒤에 볼 장면은 결과와 같은 저장본에 대기열로 남긴다(결과 화면에서 앱이 꺼져도 잃지 않음)
	var story_triggers: Array = []
	var extra: Array = []
	if int(res.get("castle_level", 1)) > int(res.get("castle_level_before", 1)):
		var lv := int(res.castle_level)
		var ld := GameConfig.castle_level_def(lv)
		extra.append("성이 Lv.%d %s(으)로 커졌어요! 체력 %d" % [lv, String(ld.get("label", "")), int(ld.get("hp", 0))])
		_celebrate_level = lv
		var unlocks: Array = ld.get("unlock_text", [])
		if not unlocks.is_empty():
			extra.append("새로 열림: %s" % " · ".join(PackedStringArray(unlocks)))
		_sync_world()
	var cc := int(res.get("chapter_cleared", 0))
	if cc > 0:
		if cc >= GameConfig.chapters().size():
			story_triggers.append("stage_clear:%d" % stage_id)
		else:
			story_triggers.append("chapter_end:%d" % cc)
			story_triggers.append("chapter_start:%d" % (cc + 1))
	if outpost_lost:
		extra.append("앞마당이 점령당했어요. 생산이 멈췄지만 수리하면 다시 돌아가요.")
		story_triggers.append("outpost_lost")
	_queue_story(story_triggers)
	saver.save(state)
	if won:
		var ex := Story.commander_excuse(stage_id, replay)
		if ex != "":
			extra.append("%s: 「%s」" % [Story.name_of("commander"), ex])
	else:
		var cheer := Story.chief_after_defeat(state.consecutive_losses - 1)
		if cheer != "":
			extra.append("%s: 「%s」" % [Story.name_of("chief"), cheer])
	# 남은 화살은 바로 정리(기사는 결과 뒤에서 멈춘 채 보인다)
	sim.bolts.clear()
	world.update_battle(sim, 0.0, _castle_id)
	var wanted := int(GameConfig.stage(stage_id).win_wood)
	var final_stage := stage_id >= GameConfig.stage_count()
	var next_text := ""
	if won and not final_stage:
		next_text = "다음: %s · 마을에서 약 %d초 뒤 준비돼요" % [state.stage_label(stage_id + 1), int(ceil(state.raid_timer))]
	Sound.play_music("")
	Sound.play("victory" if won else "defeat")
	var tips := BattleAdvisor.advise(sim, state)
	print("조언: ", tips)
	hud.show_result(won, state.stage_label(stage_id), int(res.reward), wanted, final_stage, next_text, tips, extra)
	_last_ui = ""


func _on_result_closed(action: String) -> void:
	hud.hide_overlay()
	sim = null
	world.clear_battle()
	state.leave_result()
	_last_ui = ""
	Sound.play_music("village")
	var then := Callable()
	if action == "retry" or action == "replay":
		then = _start_raid
	elif _celebrate_level > 0:
		var lv := _celebrate_level
		then = func():
			world.levelup_fx(_castle_id, lv)
			world.imp.celebrate(Story.imp_levelup_line(lv))
	_celebrate_level = 0
	_queue_story([], then)


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
		"outlines":
			hud.outlines_on = not hud.outlines_on
			world.set_outlines(hud.outlines_on)
			_save_settings()
		"fps":
			hud.fps_on = not hud.fps_on
			_save_settings()
		"story":
			hud.show_story_list(Story.seen_scenes(state.story_seen))
		"tutorial":
			if not edit.is_empty():
				_cancel_edit()
			if state.mode == GameState.MODE_VILLAGE or state.mode == GameState.MODE_RAID_READY:
				_deselect()
				tutorial.start()
		"music_down", "music_up", "sfx_down", "sfx_up":
			var step := 0.1 if action.ends_with("up") else -0.1
			if action.begins_with("music"):
				Sound.music_volume = clampf(snappedf(Sound.music_volume + step, 0.1), 0.0, 1.0)
			else:
				Sound.sfx_volume = clampf(snappedf(Sound.sfx_volume + step, 0.1), 0.0, 1.0)
			Sound.apply_volumes()
			Sound.play("click")
			_save_settings()
			hud._show_menu()
		"assist":
			state.assist_enabled = not state.assist_enabled
			saver.save(state)
			_last_ui = ""
			hud.toast("도움 모드를 켰어요: 같은 단계에서 %d번 이상 지면 기사 체력이 조금 줄어요" % int(GameConfig.raids().assist.after_losses) if state.assist_enabled else "도움 모드를 껐어요", 3.0)
		"reset":
			# 이전 게임의 대기 장면·콜백·안내는 버린다(편집을 닫으며 옛 장면이 뜨지 않게 먼저 비움)
			state.story_pending.clear()
			_story_then = Callable()
			_story_current = ""
			if tutorial.active():
				tutorial.end(true)
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
			_queue_story(["new_game"])


# ------------------------------------------------------------------ 표시 설정(user://settings.cfg)

func _settings_path() -> String:
	return saver.dir + "settings.cfg"


func _on_tutorial_finished(skipped: bool) -> void:
	_tutorial_done = true
	_save_settings()
	world.show_selection(state.get_building(selected_id) if selected_id != "" else {})
	if skipped:
		hud.toast("안내는 메뉴(≡)에서 다시 볼 수 있어요")


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(_settings_path()) == OK:
		hud.shadows_on = bool(cf.get_value("display", "shadows", true))
		hud.fps_on = bool(cf.get_value("display", "show_fps", false))
		hud.outlines_on = bool(cf.get_value("display", "outlines", true))
		_tutorial_done = bool(cf.get_value("progress", "tutorial_done", false))
		Sound.music_volume = float(cf.get_value("audio", "music", 0.7))
		Sound.sfx_volume = float(cf.get_value("audio", "sfx", 0.8))
	Sound.apply_volumes()
	world.set_shadows(hud.shadows_on)
	world.set_outlines(hud.outlines_on)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("display", "shadows", hud.shadows_on)
	cf.set_value("display", "show_fps", hud.fps_on)
	cf.set_value("display", "outlines", hud.outlines_on)
	cf.set_value("progress", "tutorial_done", _tutorial_done)
	cf.set_value("audio", "music", Sound.music_volume)
	cf.set_value("audio", "sfx", Sound.sfx_volume)
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
				Sound.set_background(false)
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
	Sound.set_background(true)
	_pressing = false
	_touches.clear()
	_gesture = false
	if state.mode == GameState.MODE_BATTLE:
		_pause_battle()
	elif state.mode != GameState.MODE_PAUSED:
		# 전투 중이 아니면 확정 상태만 저장(편집 미리보기는 저장하지 않음)
		saver.save(state)


func _on_back() -> void:
	# 이야기 장면이 열려 있으면 뒤로 가기는 장면만 넘긴다(아래 가려진 화면은 건드리지 않음)
	if story_view.active():
		story_view.advance()
	elif state.mode == GameState.MODE_BATTLE:
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
	if hud.overlay_visible() or _background or story_view.active():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not hud.is_over_ui(st.position) and not tutorial.is_over(st.position):
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
	if edit.is_empty() or edit.kind in ["deco", "expand"]:
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
	var bb := state.bounds()
	# 앞마당은 가까운 숲 자원 지점에 딱 맞춰 붙는다
	if edit.type == "outpost":
		for site in GridLogic.open_sites(bb):
			if Vector2(cell).distance_to(Vector2(int(site.x), int(site.z))) <= 2.5:
				cell = Vector2i(int(site.x), int(site.z))
				break
	# 지도 밖 1칸까지는 끌 수 있게 두어 '지도 밖' 이유를 보여 준다
	var nx := clampi(cell.x, bb.position.x - 1, bb.end.x - fp.x + 1)
	var nz := clampi(cell.y, bb.position.y - 1, bb.end.y - fp.y + 1)
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
	if not edit.is_empty() and edit.kind in ["deco", "expand"]:
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
	# 뿔이를 누르면 한마디(건물보다 먼저)
	if world.imp.hit(world.camera, pos):
		world.imp.react(Story.imp_tap_line(_imp_taps))
		_imp_taps += 1
		Sound.play("click")
		return
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
	elif GridLogic.is_interior_edge(k, state.bounds()) and not GridLogic.gate_edges(state.bounds()).has(k):
		edit.add[k] = true
	else:
		hud.toast(GridLogic.REASON_FIXED)
		return
	_update_edit()
