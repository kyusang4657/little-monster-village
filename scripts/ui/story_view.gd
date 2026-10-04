class_name StoryView
extends CanvasLayer
## 짧은 대화 장면(3~6줄): 화면 아래 대화 상자 + 말하는 인물 얼굴 + 이름. 탭/다음으로 넘기고 건너뛰기 가능.

signal finished(scene_id: String)

var hud: Hud
var _root: Control
var _dim: ColorRect
var _box: PanelContainer
var _portrait: UiIcon
var _name: Label
var _text: Label
var _title: Label
var _next_btn: Button
var _scene: Dictionary = {}
var _line := 0


func setup(p_hud: Hud) -> void:
	hud = p_hud
	layer = 12
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = hud.root.theme
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.06, 0.16, 0.35)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			advance())
	_root.add_child(_dim)
	_box = PanelContainer.new()
	var st := hud._style(Hud.C_IVORY, Hud.C_PURPLE, 22, 4)
	st.content_margin_left = 20
	st.content_margin_right = 22
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	_box.add_theme_stylebox_override("panel", st)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_portrait = UiIcon.new("chief", 112)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	_title = hud._label("", 18, Hud.C_TEXT_SOFT, true)
	vb.add_child(_title)
	_name = hud._label("", 24, Hud.C_PURPLE_EDGE)
	vb.add_child(_name)
	_text = hud._label("", 26, Hud.C_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(620, 70)
	vb.add_child(_text)
	hb.add_child(vb)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_END
	bv.add_theme_constant_override("separation", 10)
	var skip := hud._button("건너뛰기", "ivory", "x")
	skip.custom_minimum_size.y = 64
	skip.pressed.connect(func(): _finish())
	bv.add_child(skip)
	_next_btn = hud._button("다음", "green", "play")
	_next_btn.custom_minimum_size.y = 64
	_next_btn.pressed.connect(advance)
	bv.add_child(_next_btn)
	hb.add_child(bv)
	_box.add_child(hb)
	_root.add_child(_box)
	visible = false


func active() -> bool:
	return not _scene.is_empty()


func current_id() -> String:
	return String(_scene.get("id", ""))


## 장면을 보여 준다. 대사가 없으면 false(바로 다음 진행)
func play(scene: Dictionary) -> bool:
	if scene.is_empty() or (scene.get("lines", []) as Array).is_empty():
		return false
	_scene = scene
	_line = 0
	visible = true
	_show_line()
	return true


func advance() -> void:
	if _scene.is_empty():
		return
	Sound.play("click")
	_line += 1
	if _line >= (_scene.lines as Array).size():
		_finish()
	else:
		_show_line()


func _finish() -> void:
	if _scene.is_empty():
		return
	var id := String(_scene.get("id", ""))
	_scene = {}
	visible = false
	finished.emit(id)


func _show_line() -> void:
	var ln: Dictionary = _scene.lines[_line]
	var who := String(ln.get("who", "chief"))
	var ch := Story.character(who)
	_portrait.set_kind(who if who in ["chief", "imp", "commander", "hero"] else "chief", Color(String(ch.get("color", "7a4bc4"))))
	_name.text = "%s · %s" % [String(ch.get("name", who)), String(ch.get("role", ""))]
	_name.add_theme_color_override("font_color", Color(String(ch.get("color", "55308f"))).darkened(0.2))
	_text.text = String(ln.get("text", ""))
	_title.text = "%s  (%d/%d)" % [String(_scene.get("title", "")), _line + 1, (_scene.lines as Array).size()]
	hud.set_button_text(_next_btn, "닫기" if _line == (_scene.lines as Array).size() - 1 else "다음")
	_box.reset_size()


func _process(_delta: float) -> void:
	if _scene.is_empty():
		return
	var vp := _root.get_viewport_rect().size
	var bs := _box.get_combined_minimum_size()
	_box.size = Vector2(minf(vp.x - 32, maxf(bs.x, 900)), bs.y)
	_box.position = Vector2((vp.x - _box.size.x) * 0.5, vp.y - _box.size.y - 18)


func is_over(pos: Vector2) -> bool:
	return active()
