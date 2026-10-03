class_name Hud
extends CanvasLayer
## 한국어 UI. 아이보리 패널·짙은 보라 글자·보라/초록 버튼. 모든 문구는 실제 텍스트.

signal start_raid_pressed
signal build_pressed
signal buy_pressed(type: String)
signal fence_pressed
signal build_menu_closed
signal move_pressed
signal upgrade_pressed
signal decor_pressed
signal decor_option(part_id: String, option_id: String)
signal decor_done
signal decor_cancel
signal info_closed
signal edit_cancel
signal edit_rotate
signal edit_confirm
signal pause_pressed
signal resume_pressed
signal result_closed(action: String)
signal menu_action(action: String)

const C_IVORY := Color("fff7e6")
const C_IVORY_EDGE := Color("dcc79c")
const C_TEXT := Color("4a2b5e")
const C_TEXT_SOFT := Color("7a6488")
const C_PURPLE := Color("7a4fc0")
const C_PURPLE_EDGE := Color("55308f")
const C_GREEN := Color("3fae4a")
const C_GREEN_EDGE := Color("2a7d33")
const C_RED := Color("d9383e")
const C_DISABLED := Color("c9c2b6")
const BTN_H := 78.0

var root: Control
var frame: Control
var _font_bold: Font
var _font_regular: Font

var wood_label: Label
var wood_sub: Label
var raid_panel: PanelContainer
var raid_icon: UiIcon
var raid_label: Label
var raid_btn: Button
var battle_panel: PanelContainer
var battle_label: Label
var castle_bar: ProgressBar
var castle_label: Label
var pause_btn: Button
var menu_btn: Button
var build_btn: Button
var build_menu: PanelContainer
var buy_cards: Dictionary = {}
var info_panel: PanelContainer
var info_icon: UiIcon
var info_title: Label
var info_desc: Label
var info_move: Button
var info_upgrade: Button
var info_decor: Button
var decor_panel: PanelContainer
var _decor_box: VBoxContainer
var _decor_chips: Dictionary = {}     # part_id -> {option_id: Button}
var edit_bar: PanelContainer
var edit_icon: UiIcon
var edit_title: Label
var edit_status_icon: UiIcon
var edit_status: Label
var edit_rotate_btn: Button
var edit_confirm_btn: Button
var hint_panel: PanelContainer
var hint_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var _toast_t := 0.0
var overlay: ColorRect
var overlay_box: VBoxContainer
var overlay_panel: PanelContainer


func _ready() -> void:
	layer = 10
	_font_bold = load("res://assets/fonts/NanumGothic-Bold.ttf")
	_font_regular = load("res://assets/fonts/NanumGothic-Regular.ttf")
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	frame = Control.new()
	frame.name = "SafeFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	_build_top()
	_build_bottom()
	_build_decor_panel()
	_build_overlay()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_panel.modulate.a = clampf(_toast_t / 0.3, 0.0, 1.0)
		if _toast_t <= 0.0:
			toast_panel.visible = false


## 노치·둥근 모서리 안전 영역 + 기본 여백 16
func _apply_safe_area() -> void:
	var vp := root.get_viewport_rect().size
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var m := Vector4(16, 12, 16, 12)   # left, top, right, bottom
	if screen.x > 0 and screen.y > 0 and safe.size.x > 0 and OS.has_feature("mobile"):
		var sx := vp.x / screen.x
		var sy := vp.y / screen.y
		m.x += safe.position.x * sx
		m.y += safe.position.y * sy
		m.z += (screen.x - safe.end.x) * sx
		m.w += (screen.y - safe.end.y) * sy
	frame.position = Vector2(m.x, m.y)
	frame.size = vp - Vector2(m.x + m.z, m.y + m.w)


# ------------------------------------------------------------------ 테마

func _style(bg: Color, edge: Color, radius: int = 18, border: int = 3, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if shadow:
		s.shadow_color = Color(0.2, 0.1, 0.25, 0.25)
		s.shadow_size = 4
		s.shadow_offset = Vector2(0, 3)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font_bold
	t.default_font_size = 26
	t.set_color("font_color", "Label", C_TEXT)
	t.set_stylebox("panel", "PanelContainer", _style(C_IVORY, C_IVORY_EDGE))
	var pb_bg := _style(Color("3a2443"), Color("3a2443"), 10, 0, false)
	pb_bg.content_margin_top = 0
	pb_bg.content_margin_bottom = 0
	var pb_fill := _style(Color("e0443c"), Color("e0443c"), 10, 0, false)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_font_size("font_size", "ProgressBar", 1)
	return t


func _button(text: String, variant: String, icon: String = "", min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, BTN_H)
	b.add_theme_font_size_override("font_size", 28)
	_apply_variant(b, variant)
	if icon != "":
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.add_theme_constant_override("separation", 10)
		var ic := UiIcon.new(icon, 34, b.get_theme_color("font_color"))
		ic.name = "Icon"
		hb.add_child(ic)
		var l := Label.new()
		l.name = "Text"
		l.text = text
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", b.get_theme_color("font_color"))
		hb.add_child(l)
		b.add_child(hb)
		var w := 0.0
		w = _font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 34 + 10 + 44
		b.custom_minimum_size.x = maxf(min_w, w)
		b.set_meta("label", l)
		b.set_meta("icon", ic)
	else:
		b.text = text
	return b


func _apply_variant(b: Button, variant: String) -> void:
	var bg := C_IVORY
	var edge := C_IVORY_EDGE
	var fc := C_TEXT
	match variant:
		"purple":
			bg = C_PURPLE
			edge = C_PURPLE_EDGE
			fc = Color.WHITE
		"green":
			bg = C_GREEN
			edge = C_GREEN_EDGE
			fc = Color.WHITE
	b.add_theme_stylebox_override("normal", _style(bg, edge))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.08), edge))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.12), edge, 18, 3, false))
	b.add_theme_stylebox_override("disabled", _style(C_DISABLED, C_DISABLED.darkened(0.15), 18, 3, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", Color("8a8275"))


func set_button_text(b: Button, text: String) -> void:
	if b.has_meta("label"):
		var l: Label = b.get_meta("label")
		l.text = text
		b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, _font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 34 + 10 + 44)
	else:
		b.text = text


func set_button_enabled(b: Button, on: bool) -> void:
	b.disabled = not on
	if b.has_meta("label"):
		var col := b.get_theme_color("font_disabled_color") if not on else b.get_theme_color("font_color")
		(b.get_meta("label") as Label).add_theme_color_override("font_color", col)
		(b.get_meta("icon") as UiIcon).color = col
		(b.get_meta("icon") as UiIcon).queue_redraw()


func _label(text: String, size: int = 26, color: Color = C_TEXT, regular: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if regular:
		l.add_theme_font_override("font", _font_regular)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _anchor(c: Control, preset: int, grow_h: int, grow_v: int) -> void:
	frame.add_child(c)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v


# ------------------------------------------------------------------ 상단

func _build_top() -> void:
	# 목재
	var wp := _panel()
	var whb := HBoxContainer.new()
	whb.add_theme_constant_override("separation", 10)
	whb.add_child(UiIcon.new("wood", 44))
	var wvb := VBoxContainer.new()
	wvb.add_theme_constant_override("separation", 0)
	wood_label = _label("목재 100 / 500", 28)
	wood_sub = _label("+1/초", 18, C_TEXT_SOFT, true)
	wvb.add_child(wood_label)
	wvb.add_child(wood_sub)
	whb.add_child(wvb)
	wp.add_child(whb)
	_anchor(wp, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)

	# 습격 준비
	raid_panel = _panel()
	var rhb := HBoxContainer.new()
	rhb.add_theme_constant_override("separation", 12)
	raid_icon = UiIcon.new("shield", 36, C_PURPLE)
	rhb.add_child(raid_icon)
	raid_label = _label("첫 번째 습격 · 기사 4명 접근", 26)
	raid_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rhb.add_child(raid_label)
	raid_btn = _button("방어 시작", "green", "shield")
	raid_btn.custom_minimum_size.y = 64
	raid_btn.pressed.connect(func(): start_raid_pressed.emit())
	rhb.add_child(raid_btn)
	raid_panel.add_child(rhb)
	_anchor(raid_panel, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)

	# 전투 정보
	battle_panel = _panel()
	var bvb := VBoxContainer.new()
	var bhb := HBoxContainer.new()
	bhb.alignment = BoxContainer.ALIGNMENT_CENTER
	bhb.add_theme_constant_override("separation", 10)
	bhb.add_child(UiIcon.new("knight", 34))
	battle_label = _label("첫 번째 습격 · 남은 적 4", 28)
	bhb.add_child(battle_label)
	bvb.add_child(bhb)
	var chb := HBoxContainer.new()
	chb.add_theme_constant_override("separation", 8)
	chb.add_child(UiIcon.new("castle", 30))
	castle_bar = ProgressBar.new()
	castle_bar.custom_minimum_size = Vector2(220, 18)
	castle_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	castle_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	castle_bar.show_percentage = false
	castle_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chb.add_child(castle_bar)
	castle_label = _label("성 180/180", 20, C_TEXT, true)
	chb.add_child(castle_label)
	bvb.add_child(chb)
	battle_panel.add_child(bvb)
	_anchor(battle_panel, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	battle_panel.visible = false

	# 우상단
	pause_btn = _button("", "ivory", "pause", BTN_H)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	_anchor(pause_btn, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	pause_btn.visible = false
	menu_btn = _button("", "ivory", "menu", BTN_H)
	menu_btn.pressed.connect(_show_menu)
	_anchor(menu_btn, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)

	# 안내 띠
	hint_panel = _panel()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = _label("건물을 끌어 원하는 곳에 놓으세요", 24)
	hint_panel.add_child(hint_label)
	_anchor(hint_panel, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	hint_panel.position.y += 96
	hint_panel.visible = false

	# 짧은 알림
	toast_panel = _panel()
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", _style(Color("4a2b5e"), Color("2f1a3d")))
	toast_label = _label("", 26, Color.WHITE)
	toast_panel.add_child(toast_label)
	_anchor(toast_panel, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	toast_panel.visible = false


# ------------------------------------------------------------------ 하단

func _build_bottom() -> void:
	build_btn = _button("건설", "purple", "hammer", 170)
	build_btn.pressed.connect(func(): build_pressed.emit())
	_anchor(build_btn, Control.PRESET_BOTTOM_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)

	# 건설 메뉴
	build_menu = _panel()
	var mhb := HBoxContainer.new()
	mhb.add_theme_constant_override("separation", 12)
	for item in [["house", "고블린 주택", "house"], ["defense_tower", "방어탑", "tower"], ["fence", "울타리", "fence"]]:
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(196, 128)
		_apply_variant(card, "ivory")
		card.add_theme_stylebox_override("normal", _style(Color("fffaf0"), C_IVORY_EDGE, 16))
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		var ic := UiIcon.new(item[2], 44)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(ic)
		var name_l := _label(item[1], 24)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(name_l)
		var cost_l := _label("", 19, C_TEXT_SOFT, true)
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(cost_l)
		card.add_child(vb)
		var type: String = item[0]
		if type == "fence":
			card.pressed.connect(func(): fence_pressed.emit())
		else:
			card.pressed.connect(func(): buy_pressed.emit(type))
		buy_cards[type] = {button = card, cost = cost_l}
		mhb.add_child(card)
	var close := _button("", "ivory", "x", BTN_H)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): build_menu_closed.emit())
	mhb.add_child(close)
	build_menu.add_child(mhb)
	_anchor(build_menu, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	build_menu.visible = false

	# 선택 정보
	info_panel = _panel()
	var ihb := HBoxContainer.new()
	ihb.add_theme_constant_override("separation", 14)
	info_icon = UiIcon.new("house", 56)
	info_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ihb.add_child(info_icon)
	var ivb := VBoxContainer.new()
	ivb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_title = _label("", 28)
	info_desc = _label("", 20, C_TEXT_SOFT, true)
	ivb.add_child(info_title)
	ivb.add_child(info_desc)
	ihb.add_child(ivb)
	info_move = _button("옮기기", "purple", "rotate")
	(info_move.get_meta("icon") as UiIcon).set_kind("hammer", Color.WHITE)
	info_move.pressed.connect(func(): move_pressed.emit())
	ihb.add_child(info_move)
	info_upgrade = _button("강화 · 목재 60", "green", "tower")
	info_upgrade.pressed.connect(func(): upgrade_pressed.emit())
	ihb.add_child(info_upgrade)
	info_decor = _button("꾸미기", "ivory", "house")
	info_decor.pressed.connect(func(): decor_pressed.emit())
	ihb.add_child(info_decor)
	var iclose := _button("", "ivory", "x", BTN_H)
	iclose.pressed.connect(func(): info_closed.emit())
	ihb.add_child(iclose)
	info_panel.add_child(ihb)
	_anchor(info_panel, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	info_panel.visible = false

	# 배치 편집 막대
	edit_bar = _panel()
	var ehb := HBoxContainer.new()
	ehb.add_theme_constant_override("separation", 14)
	edit_icon = UiIcon.new("house", 56)
	edit_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ehb.add_child(edit_icon)
	var evb := VBoxContainer.new()
	evb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	evb.custom_minimum_size.x = 250
	edit_title = _label("", 26)
	evb.add_child(edit_title)
	var shb := HBoxContainer.new()
	shb.add_theme_constant_override("separation", 6)
	edit_status_icon = UiIcon.new("check", 26)
	edit_status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shb.add_child(edit_status_icon)
	edit_status = _label("배치 가능", 21, C_GREEN_EDGE)
	shb.add_child(edit_status)
	evb.add_child(shb)
	ehb.add_child(evb)
	var cancel := _button("취소", "ivory", "x")
	cancel.pressed.connect(func(): edit_cancel.emit())
	ehb.add_child(cancel)
	edit_rotate_btn = _button("회전", "purple", "rotate")
	edit_rotate_btn.pressed.connect(func(): edit_rotate.emit())
	ehb.add_child(edit_rotate_btn)
	edit_confirm_btn = _button("배치", "green", "check")
	edit_confirm_btn.pressed.connect(func(): edit_confirm.emit())
	ehb.add_child(edit_confirm_btn)
	edit_bar.add_child(ehb)
	_anchor(edit_bar, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	edit_bar.visible = false


# ------------------------------------------------------------------ 꾸미기 패널(오른쪽)

func _build_decor_panel() -> void:
	decor_panel = _panel()
	_decor_box = VBoxContainer.new()
	_decor_box.add_theme_constant_override("separation", 8)
	decor_panel.add_child(_decor_box)
	_anchor(decor_panel, Control.PRESET_CENTER_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BOTH)
	decor_panel.visible = false


func show_decor(type: String, title: String, deco: Dictionary) -> void:
	for c in _decor_box.get_children():
		_decor_box.remove_child(c)
		c.queue_free()
	_decor_chips.clear()
	var head := _label("%s 꾸미기" % title, 28)
	_decor_box.add_child(head)
	var sub := _label("외형만 바뀌어요 · 무료", 19, C_TEXT_SOFT, true)
	_decor_box.add_child(sub)
	for p in Decor.parts(type):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := _label(String(p.label), 22)
		l.custom_minimum_size = Vector2(104, 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var chips := {}
		for o in p.options:
			var chip := _chip(String(o.label), Color(String(o.color)) if o.has("color") else Color(0, 0, 0, 0))
			var pid := String(p.id)
			var oid := String(o.id)
			chip.pressed.connect(func(): decor_option.emit(pid, oid))
			row.add_child(chip)
			chips[oid] = chip
		_decor_chips[String(p.id)] = chips
		_decor_box.add_child(row)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 12)
	var cancel := _button("취소", "ivory", "x")
	cancel.pressed.connect(func(): decor_cancel.emit())
	hb.add_child(cancel)
	var done := _button("완료", "green", "check")
	done.pressed.connect(func(): decor_done.emit())
	hb.add_child(done)
	_decor_box.add_child(hb)
	set_decor_selection(deco)
	decor_panel.visible = true
	decor_panel.reset_size()
	decor_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)


## 선택한 부품은 초록 테두리·굵은 표시
func set_decor_selection(deco: Dictionary) -> void:
	for pid in _decor_chips:
		for oid in _decor_chips[pid]:
			var chip: Button = _decor_chips[pid][oid]
			var on: bool = String(deco.get(pid, "")) == oid
			var st := _style(Color("e6f6e2") if on else Color("fffaf0"), C_GREEN if on else C_IVORY_EDGE, 14, 4 if on else 2, false)
			st.content_margin_left = 10
			st.content_margin_right = 10
			chip.add_theme_stylebox_override("normal", st)
			chip.add_theme_stylebox_override("hover", st)
			chip.add_theme_stylebox_override("pressed", st)


func hide_decor() -> void:
	decor_panel.visible = false


func _chip(text: String, swatch: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(84, 64)
	_apply_variant(b, "ivory")
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 6)
	if swatch.a > 0.0:
		var sw := ColorRect.new()
		sw.color = swatch
		sw.custom_minimum_size = Vector2(20, 20)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(sw)
	var l := _label(text, 21)
	hb.add_child(l)
	b.add_child(hb)
	var w := _font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + (26 if swatch.a > 0.0 else 0) + 26
	b.custom_minimum_size.x = maxf(84, w)
	return b


# ------------------------------------------------------------------ 가운데 덮개(일시정지·결과·안내)

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.16, 0.08, 0.2, 0.45)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	overlay_panel = _panel()
	overlay_panel.custom_minimum_size = Vector2(520, 0)
	var st := _style(C_IVORY, C_IVORY_EDGE, 24, 4)
	st.content_margin_left = 36
	st.content_margin_right = 36
	st.content_margin_top = 26
	st.content_margin_bottom = 26
	overlay_panel.add_theme_stylebox_override("panel", st)
	center.add_child(overlay_panel)
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 14)
	overlay_panel.add_child(overlay_box)
	overlay.visible = false


func _clear_overlay() -> void:
	for c in overlay_box.get_children():
		overlay_box.remove_child(c)
		c.queue_free()


func _overlay(title: String, lines: Array, buttons: Array, icon: String = "", icon_color: Color = C_PURPLE, extra_rows: Array = [], tips: Array = []) -> void:
	_clear_overlay()
	if icon != "":
		var ic := UiIcon.new(icon, 72, icon_color)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		overlay_box.add_child(ic)
	var t := _label(title, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(t)
	for line in lines:
		var l := _label(line, 24, C_TEXT, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 460
		overlay_box.add_child(l)
	if not tips.is_empty():
		var tp := PanelContainer.new()
		var tst := _style(Color("f3ecff"), Color("c9b4ef"), 14, 2, false)
		tp.add_theme_stylebox_override("panel", tst)
		var tvb := VBoxContainer.new()
		tvb.add_theme_constant_override("separation", 4)
		var th := HBoxContainer.new()
		th.add_theme_constant_override("separation", 8)
		th.add_child(UiIcon.new("shield", 26, C_PURPLE))
		th.add_child(_label("다음 판 조언", 22, C_PURPLE_EDGE))
		tvb.add_child(th)
		for tip in tips:
			var l := _label("· " + String(tip), 20, C_TEXT, true)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 520
			tvb.add_child(l)
		tp.add_child(tvb)
		overlay_box.add_child(tp)
	for row in extra_rows + [buttons]:
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 14)
		for spec in row:
			var b := _button(spec[0], spec[1], spec[2] if spec.size() > 2 else "", 180)
			b.pressed.connect(spec[3] if spec.size() > 3 else func(): pass)
			hb.add_child(b)
		overlay_box.add_child(hb)
	overlay.visible = true


func hide_overlay() -> void:
	overlay.visible = false
	_clear_overlay()


func overlay_visible() -> bool:
	return overlay.visible


func show_pause() -> void:
	_overlay("일시정지", ["전투가 멈춰 있어요.", "준비되면 계속하기를 눌러 주세요."], [["계속하기", "green", "play", func(): resume_pressed.emit()]], "pause", C_PURPLE)


func show_result(won: bool, stage_label: String, reward: int, wanted: int, final_stage: bool, next_text: String, tips: Array = []) -> void:
	var n := GameConfig.stage_count()
	if won and final_stage:
		_overlay("모든 습격 완료!", [
			"%s을 막아냈어요." % stage_label,
			"목재 +%d%s" % [reward, "" if reward == wanted else " (창고 한도)"],
			"%d번의 습격을 모두 이겼어요. 마지막 단계에 다시 도전할 수 있어요." % n,
		], [["%d단계 다시 도전" % n, "purple", "shield", func(): result_closed.emit("replay")], ["마을로", "green", "check", func(): result_closed.emit("village")]], "check", C_PURPLE, [], tips)
	elif won:
		_overlay("승리!", [
			"%s을 막아냈어요. 목재 +%d%s" % [stage_label, reward, "" if reward == wanted else " (창고 한도)"],
			next_text,
		], [["확인", "green", "check", func(): result_closed.emit("village")]], "check", C_PURPLE, [], tips)
	else:
		_overlay("성이 함락됐어요", [
			"마을은 그대로예요. 건물·울타리·목재는 잃지 않았어요.",
			"배치를 바꾸거나 방어탑을 강화한 뒤 무료로 다시 도전해 보세요.",
		], [["마을로", "ivory", "x", func(): result_closed.emit("village")], ["다시 도전", "green", "shield", func(): result_closed.emit("retry")]], "ban", C_PURPLE, [], tips)


func show_dialog(title: String, message: String) -> void:
	_overlay(title, [message], [["확인", "green", "check", func(): hide_overlay()]], "clock", C_PURPLE)


## 메뉴의 현재 설정 표시용(main 이 갱신)
var shadows_on := true
var assist_on := false
var fps_on := false
var fps_label: Label


func _show_menu() -> void:
	_overlay("메뉴", ["진행은 자동으로 기기에 저장돼요."], [
		["카메라 초기화", "ivory", "rotate", func(): hide_overlay(); menu_action.emit("recenter")],
		["새 게임", "purple", "x", func(): _confirm_reset()],
		["닫기", "green", "check", func(): hide_overlay()],
	], "menu", C_PURPLE, [[
		["그림자 끄기" if shadows_on else "그림자 켜기", "ivory", "menu", func(): hide_overlay(); menu_action.emit("shadows")],
		["FPS 숨기기" if fps_on else "FPS 표시", "ivory", "clock", func(): hide_overlay(); menu_action.emit("fps")],
		["도움 모드 끄기" if assist_on else "도움 모드 켜기", "ivory", "heart", func(): hide_overlay(); menu_action.emit("assist")],
	]])


func set_fps_text(t: String) -> void:
	if fps_label == null:
		fps_label = _label("", 20, C_TEXT, true)
		_anchor(fps_label, Control.PRESET_BOTTOM_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	fps_label.visible = fps_on
	fps_label.text = t


func _confirm_reset() -> void:
	_overlay("새 게임으로 시작할까요?", ["지금 마을과 진행 상황이 지워지고 처음 상태로 돌아가요.", "이 동작은 되돌릴 수 없어요."], [
		["취소", "ivory", "x", func(): hide_overlay()],
		["새 게임", "purple", "check", func(): hide_overlay(); menu_action.emit("reset")],
	], "ban")


# ------------------------------------------------------------------ 갱신

func toast(msg: String, seconds: float = 2.2) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	toast_panel.reset_size()
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	toast_panel.position.y -= 120
	_toast_t = seconds


func set_wood(wood: int, cap: int, producing: bool) -> void:
	wood_label.text = "목재 %d / %d" % [wood, cap]
	if wood >= cap:
		wood_sub.text = "창고가 가득 찼어요"
	elif producing:
		wood_sub.text = "벌목소 생산 중 · +1/초"
	else:
		wood_sub.text = "생산 멈춤"


func set_raid(ready: bool, label: String, knights: int, timer: float, visible_flag: bool, assist_pct: int = 0) -> void:
	raid_panel.visible = visible_flag
	if ready:
		raid_icon.set_kind("shield", C_PURPLE)
		raid_label.text = "%s · 기사 %d명 접근" % [label, knights]
		if assist_pct > 0:
			raid_label.text += " · 도움 모드 체력 -%d%%" % assist_pct
		raid_btn.visible = true
	else:
		raid_icon.set_kind("clock", C_PURPLE)
		raid_label.text = "다음 습격 준비 중 · %d초 남음" % int(ceil(maxf(timer, 0.0)))
		raid_btn.visible = false
	raid_panel.reset_size()
	raid_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)


func set_battle(visible_flag: bool, label: String = "", remaining: int = 0, hp: int = 0, hp_max: int = 1) -> void:
	battle_panel.visible = visible_flag
	pause_btn.visible = visible_flag
	menu_btn.visible = not visible_flag
	if visible_flag:
		battle_label.text = "%s · 남은 적 %d" % [label, remaining]
		castle_bar.max_value = hp_max
		castle_bar.value = hp
		castle_label.text = "성 %d/%d" % [hp, hp_max]


func set_village_controls(build_visible: bool) -> void:
	build_btn.visible = build_visible


func show_build_menu(state: GameState) -> void:
	for type in buy_cards:
		var card: Dictionary = buy_cards[type]
		var b: Button = card.button
		if type == "fence":
			card.cost.text = "한 변 목재 %d" % int(GameConfig.defaults().fences.edge_build_cost)
			b.disabled = false
		else:
			var cnt := state.count_type(type)
			var mx := state.max_count(type)
			var cost := state.build_cost(type)
			card.cost.text = "목재 %d · %d/%d" % [cost, cnt, mx]
			b.disabled = cnt >= mx or state.wood < cost
			if cnt >= mx:
				card.cost.text = "최대 %d/%d" % [cnt, mx]
	build_menu.visible = true
	build_menu.reset_size()
	build_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)


func hide_build_menu() -> void:
	build_menu.visible = false


func show_info(b: Dictionary, state: GameState) -> void:
	var def := GameConfig.building_def(b.type)
	info_icon.set_kind({castle = "castle", house = "house", lumber_camp = "lumber", defense_tower = "tower"}.get(b.type, "house"))
	var fp := GameConfig.footprint(b.type)
	info_title.text = "%s · Lv.%d" % [GameConfig.type_label(b.type), int(b.level)]
	var desc := "%d×%d칸" % [fp.x, fp.y]
	match b.type:
		"castle":
			desc += " · 체력 %d · 옮길 수 없어요" % int(def.hp)
		"house":
			desc += " · 꾸미기용 건물"
		"lumber_camp":
			desc += " · 목재 초당 %d" % int(GameConfig.economy().income_per_second)
		"defense_tower":
			var lv := GameConfig.tower_level(int(b.level))
			desc += " · 공격력 %d · 사거리 %.1f칸" % [int(lv.damage), float(lv.range_cells)]
	if not state.is_built(b):
		desc += " · 공사 중 %d초 남음" % int(ceil(float(b.build_left)))
	info_desc.text = desc
	info_move.visible = bool(def.get("movable", false))
	info_upgrade.visible = b.type == "defense_tower"
	info_decor.visible = Decor.has_parts(b.type)
	if b.type == "defense_tower":
		var up := state.check_upgrade(b.id)
		var cost := state.upgrade_cost(b)
		if cost < 0:
			set_button_text(info_upgrade, "최대 레벨")
			set_button_enabled(info_upgrade, false)
		elif not state.is_built(b):
			set_button_text(info_upgrade, "공사가 끝나면 강화")
			set_button_enabled(info_upgrade, false)
		else:
			var nxt := GameConfig.tower_level(int(b.level) + 1)
			set_button_text(info_upgrade, "강화 · 목재 %d (공격력 %d)" % [cost, int(nxt.damage)])
			set_button_enabled(info_upgrade, up.ok)
	info_panel.visible = true
	info_panel.reset_size()
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)


func hide_info() -> void:
	info_panel.visible = false


func show_edit(icon: String, title: String, ok: bool, status: String, confirm_text: String, rotate_visible: bool, hint: String) -> void:
	edit_icon.set_kind(icon)
	edit_title.text = title
	edit_status_icon.set_kind("check" if ok else "ban")
	edit_status.text = status
	edit_status.add_theme_color_override("font_color", C_GREEN_EDGE if ok else C_RED)
	set_button_text(edit_confirm_btn, confirm_text)
	set_button_enabled(edit_confirm_btn, ok)
	edit_rotate_btn.visible = rotate_visible
	edit_bar.visible = true
	edit_bar.reset_size()
	edit_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	hint_label.text = hint
	hint_panel.visible = hint != ""
	hint_panel.reset_size()
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	hint_panel.position.y += 96


func hide_edit() -> void:
	edit_bar.visible = false
	hint_panel.visible = false


## UI 위의 터치는 마을로 전달하지 않는다(다중 터치 판단용).
func is_over_ui(pos: Vector2) -> bool:
	if overlay.visible:
		return true
	for c in [raid_panel, battle_panel, pause_btn, menu_btn, build_btn, build_menu, info_panel, edit_bar, decor_panel]:
		var ctl: Control = c
		if ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(pos):
			return true
	var wp := frame.get_child(0) as Control
	return wp.get_global_rect().has_point(pos)
