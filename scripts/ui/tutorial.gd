class_name Tutorial
extends CanvasLayer
## 처음 하는 사람을 위한 안내 말풍선: 건설 → 배치 → 강화 → 방어 시작.
## 대상 UI 를 빛나는 테두리로 짚고, 행동하면 다음 단계로 넘어간다. 언제든 건너뛸 수 있다.

signal finished(skipped: bool)

## 단계: id, 문구, 대상(hud 노드 이름 또는 ""), 기다릴 사건(없으면 '다음' 버튼)
const STEPS := [
	{id = "welcome", text = "마물 마을에 온 걸 환영해요!\n인간 기사들이 성을 노리고 있어요. 마을을 키워 막아 볼까요?", target = "", wait = ""},
	{id = "wood", text = "목재는 벌목소가 저절로 모아요.\n건물을 짓고 방어탑을 강화하는 데 써요.", target = "wood", wait = ""},
	{id = "open_build", text = "'건설'을 눌러 보세요.", target = "build_btn", wait = "build_menu_opened"},
	{id = "pick", text = "고블린 주택(목재 30)을 골라 보세요.", target = "card_house", wait = "build_preview"},
	{id = "place", text = "건물을 끌거나 땅을 눌러 자리를 고르고 '배치'를 누르세요.\n바닥이 초록색이면 놓을 수 있어요.", target = "edit_confirm", wait = "building_placed"},
	{id = "construct", text = "고블린 일꾼이 공사하러 갔어요!\n다 지어질 때까지 잠깐 기다려요.", target = "", wait = "construction_finished"},
	{id = "select_tower", text = "노란 테두리의 방어탑을 눌러 보세요.\n방어탑은 다가오는 기사를 자동으로 쏴요.", target = "", wait = "selected_tower"},
	{id = "upgrade", text = "'강화'를 누르면 공격력이 올라가요.\n목재가 모자라면 '다음'을 눌러도 돼요.", target = "info_upgrade", wait = "upgraded", allow_next = true},
	{id = "start", text = "준비가 되면 '방어 시작'!\n기사들이 정문으로 들어와요. 행운을 빌어요!", target = "raid_btn", wait = "battle_started"},
]

var hud: Hud
var step := -1
var _root: Control
var _bubble: PanelContainer
var _text: Label
var _count: Label
var _next_btn: Button
var _ring: Control
var _arrow: Control
var _t := 0.0


func setup(p_hud: Hud) -> void:
	hud = p_hud
	layer = 11
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = hud.root.theme
	add_child(_root)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_root.add_child(_ring)
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.custom_minimum_size = Vector2(36, 24)
	_arrow.draw.connect(_draw_arrow)
	_root.add_child(_arrow)
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := hud._style(Hud.C_IVORY, Hud.C_PURPLE, 20, 4)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	_bubble.add_theme_stylebox_override("panel", st)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiIcon.new("chief", 48, Color(String(Story.character("chief").get("color", "4c9a3d")))))
	_count = hud._label("", 18, Hud.C_TEXT_SOFT, true)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	vb.add_child(head)
	_text = hud._label("", 24, Hud.C_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(430, 0)
	vb.add_child(_text)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 12)
	var skip := hud._button("건너뛰기", "ivory", "x")
	skip.custom_minimum_size.y = 64
	skip.pressed.connect(func(): end(true))
	hb.add_child(skip)
	_next_btn = hud._button("다음", "green", "play")
	_next_btn.custom_minimum_size.y = 64
	_next_btn.pressed.connect(advance)
	hb.add_child(_next_btn)
	vb.add_child(hb)
	_bubble.add_child(vb)
	_root.add_child(_bubble)
	visible = false


func active() -> bool:
	return step >= 0


func start() -> void:
	step = 0
	visible = true
	_show_step()


func end(skipped: bool) -> void:
	if step < 0:
		return
	step = -1
	visible = false
	finished.emit(skipped)


func advance() -> void:
	if step < 0:
		return
	step += 1
	if step >= STEPS.size():
		end(false)
		return
	_show_step()


## main 이 게임 사건을 알려 준다. 지금 단계가 기다리는 사건이면 다음으로.
func notify(event: String) -> void:
	if step < 0:
		return
	if event == "battle_started":
		# 전투를 시작하면 안내는 끝(어느 단계였든)
		end(step < STEPS.size() - 1)
		return
	if String(STEPS[step].wait) == event:
		advance()


func current_id() -> String:
	return "" if step < 0 else String(STEPS[step].id)


func _show_step() -> void:
	var s: Dictionary = STEPS[step]
	_text.text = Story.tutorial_text(String(s.id), String(s.text))
	_count.text = "%s · 안내 %d / %d" % [Story.name_of("chief"), step + 1, STEPS.size()]
	_next_btn.visible = String(s.wait) == "" or bool(s.get("allow_next", false)) or String(s.id) == "construct"
	_bubble.reset_size()


func _target_rect() -> Rect2:
	var t := String(STEPS[step].target)
	var c: Control = null
	match t:
		"wood":
			c = hud.frame.get_child(0)
		"build_btn":
			c = hud.build_btn
		"card_house":
			c = hud.buy_cards.get("house", {}).get("button")
		"edit_confirm":
			c = hud.edit_confirm_btn
		"info_upgrade":
			c = hud.info_upgrade
		"raid_btn":
			c = hud.raid_btn
	if c == null or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()


func _process(delta: float) -> void:
	if step < 0:
		return
	_t += delta
	# 결과·일시정지 등 덮개가 열려 있으면 잠시 숨긴다
	_root.visible = not hud.overlay_visible()
	var vp := _root.get_viewport_rect().size
	var r := _target_rect()
	var bs := _bubble.get_combined_minimum_size()
	var pos: Vector2
	if r.size == Vector2.ZERO:
		pos = Vector2((vp.x - bs.x) * 0.5, vp.y * 0.2)
		_arrow.visible = false
	else:
		var below := r.get_center().y < vp.y * 0.5
		pos.x = clampf(r.get_center().x - bs.x * 0.5, 16, vp.x - bs.x - 16)
		pos.y = r.end.y + 26 if below else r.position.y - bs.y - 26
		pos.y = clampf(pos.y, 12, vp.y - bs.y - 12)
		_arrow.visible = true
		_arrow.set_meta("down", not below)
		_arrow.position = Vector2(r.get_center().x - 18, r.end.y + 2 if below else r.position.y - 26)
		_arrow.size = Vector2(36, 24)
		_arrow.queue_redraw()
	_bubble.position = pos
	_bubble.size = bs
	_ring.position = r.position - Vector2(8, 8)
	_ring.size = r.size + Vector2(16, 16)
	_ring.visible = r.size != Vector2.ZERO
	_ring.queue_redraw()


func _draw_ring() -> void:
	var a := 0.55 + 0.45 * sin(_t * 5.0)
	var rect := Rect2(Vector2.ZERO, _ring.size)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(1.0, 0.85, 0.25, a)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(22)
	_ring.draw_style_box(sb, rect)


func _draw_arrow() -> void:
	var down := bool(_arrow.get_meta("down", false))
	var w := _arrow.size
	var pts := PackedVector2Array([Vector2(0, w.y), Vector2(w.x, w.y), Vector2(w.x * 0.5, 0)]) if not down else PackedVector2Array([Vector2(0, 0), Vector2(w.x, 0), Vector2(w.x * 0.5, w.y)])
	_arrow.draw_colored_polygon(pts, Hud.C_PURPLE)


## UI 위 터치 판단용
func is_over(pos: Vector2) -> bool:
	return step >= 0 and _root.visible and _bubble.get_global_rect().has_point(pos)
