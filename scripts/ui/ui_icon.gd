class_name UiIcon
extends Control
## 이미지 없이 그리는 단순 아이콘(체크·금지·목재·일시정지 등).

var kind: String = "check"
var color: Color = Color.WHITE


func _init(p_kind: String = "check", p_size: float = 32.0, p_color: Color = Color.WHITE) -> void:
	kind = p_kind
	color = p_color
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_kind(k: String, c: Color = color) -> void:
	kind = k
	color = c
	queue_redraw()


## 만화풍 두꺼운 외곽선: 같은 모양을 짙은 색으로 8방향 살짝 밀어 먼저 그린 뒤 본 그림을 그린다
var outlined := true
var _dark := false
var _off := Vector2.ZERO
const OUTLINE := Color("2e1a0e")


func _k(col: Color) -> Color:
	return Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, col.a) if _dark else col


func _draw() -> void:
	var s := minf(size.x, size.y)
	if outlined and s >= 22.0:
		var o := maxf(1.5, s * 0.045)
		_dark = true
		for i in 8:
			var a := TAU * float(i) / 8.0
			_off = Vector2(cos(a), sin(a)) * o
			draw_set_transform(_off)
			_shapes()
		_dark = false
	_off = Vector2.ZERO
	draw_set_transform(Vector2.ZERO)
	_shapes()


func _shapes() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var w := maxf(2.0, s * 0.11)
	match kind:
		"check":
			draw_circle(c, s * 0.48, _k(Color("3fae4a")))
			draw_polyline(PackedVector2Array([c + Vector2(-0.24, 0.0) * s, c + Vector2(-0.06, 0.18) * s, c + Vector2(0.25, -0.17) * s]), _k(Color.WHITE), w, true)
		"ban":
			draw_circle(c, s * 0.48, _k(Color("d9383e")))
			draw_circle(c, s * 0.3, _k(Color("fff7e6")))
			draw_line(c + Vector2(-0.22, 0.22) * s, c + Vector2(0.22, -0.22) * s, _k(Color("d9383e")), w * 1.2, true)
		"wood":
			draw_rect(Rect2(c + Vector2(-0.42, -0.16) * s, Vector2(0.72, 0.32) * s), _k(Color("b5712f")))
			draw_circle(c + Vector2(0.3, 0) * s, s * 0.17, _k(Color("e9c48a")))
			draw_arc(c + Vector2(0.3, 0) * s, s * 0.09, 0, TAU, 12, _k(Color("b5712f")), maxf(1.5, s * 0.04))
			draw_rect(Rect2(c + Vector2(-0.42, -0.42) * s, Vector2(0.6, 0.22) * s), _k(Color("9a5d26")))
			draw_circle(c + Vector2(0.18, -0.31) * s, s * 0.11, _k(Color("e9c48a")))
		"pause":
			draw_rect(Rect2(c + Vector2(-0.26, -0.3) * s, Vector2(0.18, 0.6) * s), _k(color))
			draw_rect(Rect2(c + Vector2(0.08, -0.3) * s, Vector2(0.18, 0.6) * s), _k(color))
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, -0.3) * s, c + Vector2(0.3, 0) * s, c + Vector2(-0.22, 0.3) * s]), _k(color))
		"menu":
			for i in 3:
				draw_rect(Rect2(c + Vector2(-0.3, -0.27 + i * 0.22) * s, Vector2(0.6, 0.11) * s), _k(color))
		"x":
			draw_line(c + Vector2(-0.25, -0.25) * s, c + Vector2(0.25, 0.25) * s, _k(color), w * 1.3, true)
			draw_line(c + Vector2(-0.25, 0.25) * s, c + Vector2(0.25, -0.25) * s, _k(color), w * 1.3, true)
		"rotate":
			draw_arc(c, s * 0.3, -PI * 0.15, PI * 1.45, 20, _k(color), w * 1.1, true)
			var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * s * 0.3
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.16, -0.08) * s, tip + Vector2(0.12, -0.04) * s, tip + Vector2(0.0, 0.2) * s]), _k(color))
		"hammer":
			draw_line(c + Vector2(-0.3, 0.32) * s, c + Vector2(0.12, -0.1) * s, _k(Color("e9c48a")), w * 1.4, true)
			draw_set_transform(_off + c + Vector2(0.12, -0.14) * s, -PI * 0.25)
			draw_rect(Rect2(Vector2(-0.28, -0.12) * s, Vector2(0.56, 0.24) * s), _k(Color("cfd6de")))
			draw_set_transform(_off)
		"shield":
			var pts := PackedVector2Array([c + Vector2(0, -0.42) * s, c + Vector2(0.36, -0.28) * s, c + Vector2(0.3, 0.12) * s, c + Vector2(0, 0.42) * s, c + Vector2(-0.3, 0.12) * s, c + Vector2(-0.36, -0.28) * s])
			draw_colored_polygon(pts, _k(color))
		"knight":
			draw_circle(c + Vector2(0, -0.05) * s, s * 0.3, _k(Color("cfd6de")))
			draw_rect(Rect2(c + Vector2(-0.2, -0.08) * s, Vector2(0.4, 0.08) * s), _k(Color("3a2443")))
			draw_circle(c + Vector2(0.05, -0.38) * s, s * 0.12, _k(Color("c8343a")))
		"house":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, -0.02) * s, c + Vector2(0, -0.42) * s, c + Vector2(0.42, -0.02) * s]), _k(Color("7a4bc4")))
			draw_rect(Rect2(c + Vector2(-0.3, -0.02) * s, Vector2(0.6, 0.4) * s), _k(Color("f3e6c4")))
			draw_rect(Rect2(c + Vector2(-0.08, 0.12) * s, Vector2(0.16, 0.26) * s), _k(Color("8f5a2b")))
		"tower":
			draw_rect(Rect2(c + Vector2(-0.36, -0.2) * s, Vector2(0.72, 0.1) * s), _k(Color("c98a45")))
			for x in [-0.3, 0.22]:
				draw_rect(Rect2(c + Vector2(x, -0.36) * s, Vector2(0.08, 0.78) * s), _k(Color("8f5a2b")))
			draw_rect(Rect2(c + Vector2(-0.14, -0.1) * s, Vector2(0.28, 0.3) * s), _k(Color("7a4bc4")))
			draw_line(c + Vector2(-0.28, -0.32) * s, c + Vector2(0.28, -0.32) * s, _k(Color("5b3a1f")), w, true)
		"fence":
			for x in [-0.34, 0.0, 0.34]:
				draw_rect(Rect2(c + Vector2(x - 0.06, -0.34) * s, Vector2(0.12, 0.7) * s), _k(Color("8f5a2b")))
			draw_rect(Rect2(c + Vector2(-0.42, -0.16) * s, Vector2(0.84, 0.1) * s), _k(Color("c98a45")))
			draw_rect(Rect2(c + Vector2(-0.42, 0.1) * s, Vector2(0.84, 0.1) * s), _k(Color("c98a45")))
		"castle":
			draw_rect(Rect2(c + Vector2(-0.3, -0.1) * s, Vector2(0.6, 0.48) * s), _k(Color("efe5cf")))
			for x in [-0.36, 0.22]:
				draw_rect(Rect2(c + Vector2(x, -0.24) * s, Vector2(0.14, 0.62) * s), _k(Color("efe5cf")))
				draw_colored_polygon(PackedVector2Array([c + Vector2(x - 0.04, -0.24) * s, c + Vector2(x + 0.07, -0.46) * s, c + Vector2(x + 0.18, -0.24) * s]), _k(Color("7a4bc4")))
			draw_rect(Rect2(c + Vector2(-0.08, 0.12) * s, Vector2(0.16, 0.26) * s), _k(Color("2fa4a0")))
		"heart":
			draw_circle(c + Vector2(-0.14, -0.08) * s, s * 0.2, _k(color))
			draw_circle(c + Vector2(0.14, -0.08) * s, s * 0.2, _k(color))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.33, 0.0) * s, c + Vector2(0.33, 0.0) * s, c + Vector2(0, 0.38) * s]), _k(color))
		"clock":
			draw_circle(c, s * 0.42, _k(color))
			draw_circle(c, s * 0.32, _k(Color("fff7e6")))
			draw_line(c, c + Vector2(0, -0.22) * s, _k(color), w, true)
			draw_line(c, c + Vector2(0.16, 0.0) * s, _k(color), w, true)
		"chief":
			# 고블린 촌장: 큰 귀, 흰 콧수염, 외알 안경, 작은 모자
			_face_bg(c, s, _k(Color("efe2ff")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.05) * s, c + Vector2(-0.62, -0.28) * s, c + Vector2(-0.3, 0.12) * s]), _k(Color("6aa22c")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, -0.05) * s, c + Vector2(0.62, -0.28) * s, c + Vector2(0.3, 0.12) * s]), _k(Color("6aa22c")))
			draw_circle(c + Vector2(0, 0.05) * s, s * 0.32, _k(Color("8cc63f")))
			_eyes(c + Vector2(0, -0.02) * s, s, 0.11)
			draw_arc(c + Vector2(0.11, -0.02) * s, s * 0.08, 0, TAU, 16, _k(Color("c9a24a")), maxf(1.5, s * 0.025))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, 0.15) * s, c + Vector2(0, 0.1) * s, c + Vector2(0.2, 0.15) * s, c + Vector2(0.12, 0.24) * s, c + Vector2(0, 0.18) * s, c + Vector2(-0.12, 0.24) * s]), _k(Color("f4f1ea")))
			draw_rect(Rect2(c + Vector2(-0.18, -0.4) * s, Vector2(0.36, 0.1) * s), _k(Color("7a4bc4")))
			draw_rect(Rect2(c + Vector2(-0.11, -0.55) * s, Vector2(0.22, 0.17) * s), _k(Color("7a4bc4")))
		"imp":
			# 뿔이: 라벤더 얼굴, 짝짝이 뿔(캐릭터의 오른쪽 = 화면 왼쪽이 큼), 연두 눈, 말린 머리카락, 송곳니 하나
			_face_bg(c, s, _k(Color("fff3d8")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.12, -0.24) * s, c + Vector2(-0.36, -0.52) * s, c + Vector2(-0.26, -0.18) * s]), _k(Color("f3e6c8")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.14, -0.24) * s, c + Vector2(0.27, -0.4) * s, c + Vector2(0.25, -0.18) * s]), _k(Color("f3e6c8")))
			draw_circle(c + Vector2(0, 0.05) * s, s * 0.33, _k(Color("c9b3ea")))
			draw_arc(c + Vector2(0, -0.33) * s, s * 0.06, PI * 0.2, PI * 1.9, 10, _k(Color("4a2d6a")), maxf(1.5, s * 0.035))
			for ex in [-0.13, 0.13]:
				draw_circle(c + Vector2(ex, 0.07) * s, s * 0.095, _k(Color("fbfbf7")))
				draw_circle(c + Vector2(ex - 0.01, 0.08) * s, s * 0.07, _k(Color("2f9a3c")))
				draw_circle(c + Vector2(ex - 0.01, 0.09) * s, s * 0.035, _k(Color("173d1c")))
				draw_circle(c + Vector2(ex + 0.02, 0.05) * s, s * 0.022, _k(Color.WHITE))
			draw_arc(c + Vector2(0, 0.2) * s, s * 0.07, PI * 0.15, PI * 0.85, 8, _k(Color("4a1f28")), maxf(1.5, s * 0.03))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.03, 0.24) * s, c + Vector2(0.07, 0.24) * s, c + Vector2(0.05, 0.3) * s]), _k(Color.WHITE))
			for ex in [-0.24, 0.24]:
				draw_circle(c + Vector2(ex, 0.19) * s, s * 0.05, _k(Color(0.95, 0.63, 0.78, 0.8)))
		"commander":
			# 기사단장: 은색 투구, 붉은 깃, 팔자 콧수염
			_face_bg(c, s, _k(Color("ffe9e4")))
			draw_circle(c + Vector2(0, 0.08) * s, s * 0.3, _k(Color("f2c9a0")))
			draw_circle(c + Vector2(0, -0.1) * s, s * 0.33, _k(Color("b9c3cd")))
			draw_rect(Rect2(c + Vector2(-0.3, -0.06) * s, Vector2(0.6, 0.12) * s), _k(Color("b9c3cd")))
			draw_rect(Rect2(c + Vector2(-0.26, -0.02) * s, Vector2(0.52, 0.05) * s), _k(Color("2b2233")))
			draw_circle(c + Vector2(0.05, -0.5) * s, s * 0.13, _k(Color("c8343a")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.24, 0.16) * s, c + Vector2(0, 0.12) * s, c + Vector2(0.24, 0.16) * s, c + Vector2(0.14, 0.2) * s, c + Vector2(0, 0.16) * s, c + Vector2(-0.14, 0.2) * s]), _k(Color("6b3f1f")))
		"hero":
			# 용사: 금발, 이마띠, 반짝이는 눈
			_face_bg(c, s, _k(Color("fff7d0")))
			draw_circle(c + Vector2(0, 0.06) * s, s * 0.3, _k(Color("f2c9a0")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34, -0.02) * s, c + Vector2(-0.2, -0.36) * s, c + Vector2(0, -0.3) * s, c + Vector2(0.22, -0.38) * s, c + Vector2(0.34, -0.02) * s, c + Vector2(0, -0.14) * s]), _k(Color("f0c53a")))
			draw_rect(Rect2(c + Vector2(-0.3, -0.16) * s, Vector2(0.6, 0.06) * s), _k(Color("2e9c97")))
			_eyes(c + Vector2(0, 0.04) * s, s, 0.1)
			draw_arc(c + Vector2(0, 0.18) * s, s * 0.07, PI * 0.15, PI * 0.85, 8, _k(Color("3a2443")), maxf(1.5, s * 0.03))
		"expand":
			draw_rect(Rect2(c + Vector2(-0.18, -0.18) * s, Vector2(0.36, 0.36) * s), _k(Color("94cd5e")))
			draw_rect(Rect2(c + Vector2(-0.18, -0.18) * s, Vector2(0.36, 0.36) * s), _k(Color("8f5a2b")), false, maxf(2.0, s * 0.06))
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var tip: Vector2 = c + d * 0.46 * s
				var side := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([tip, tip - d * 0.16 * s + side * 0.1 * s, tip - d * 0.16 * s - side * 0.1 * s]), _k(Color("7a4bc4")))
		"outpost":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34, -0.02) * s, c + Vector2(-0.04, -0.3) * s, c + Vector2(0.26, -0.02) * s]), _k(Color("7a4bc4")))
			draw_rect(Rect2(c + Vector2(-0.26, -0.02) * s, Vector2(0.44, 0.36) * s), _k(Color("c98a45")))
			draw_line(c + Vector2(0.34, 0.34) * s, c + Vector2(0.34, -0.42) * s, _k(Color("8f5a2b")), maxf(2.0, s * 0.06))
			draw_rect(Rect2(c + Vector2(0.34, -0.42) * s, Vector2(0.14, 0.12) * s), _k(Color("7a4bc4")))
			draw_circle(c + Vector2(-0.38, 0.22) * s, s * 0.12, _k(Color("2f7d45")))
		"flower":
			for i in 5:
				var a := i * TAU / 5.0
				draw_circle(c + Vector2(cos(a), sin(a)) * 0.2 * s, s * 0.14, _k(Color("f29ac0")))
			draw_circle(c, s * 0.12, _k(Color("f5d24a")))
		"lantern":
			draw_rect(Rect2(c + Vector2(-0.07, -0.02) * s, Vector2(0.14, 0.4) * s), _k(Color("f3e6c4")))
			draw_circle(c + Vector2(0, -0.08) * s, s * 0.32, _k(Color("b689ff")))
			draw_rect(Rect2(c + Vector2(-0.34, -0.06) * s, Vector2(0.68, 0.1) * s), _k(Color("b689ff")))
			draw_circle(c + Vector2(-0.12, -0.2) * s, s * 0.05, _k(Color.WHITE))
			draw_circle(c + Vector2(0.1, -0.16) * s, s * 0.04, _k(Color.WHITE))
		"lumber":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, -0.1) * s, c + Vector2(0.42, -0.28) * s, c + Vector2(0.42, -0.18) * s, c + Vector2(-0.42, 0.0) * s]), _k(Color("7a4bc4")))
			draw_rect(Rect2(c + Vector2(-0.36, -0.05) * s, Vector2(0.08, 0.42) * s), _k(Color("8f5a2b")))
			draw_rect(Rect2(c + Vector2(0.28, -0.22) * s, Vector2(0.08, 0.6) * s), _k(Color("8f5a2b")))
			draw_circle(c + Vector2(-0.05, 0.27) * s, s * 0.1, _k(Color("e9c48a")))
			draw_circle(c + Vector2(0.15, 0.27) * s, s * 0.1, _k(Color("e9c48a")))


func _face_bg(c: Vector2, s: float, bg: Color) -> void:
	draw_circle(c, s * 0.5, bg)
	draw_arc(c, s * 0.49, 0, TAU, 32, _k(color), maxf(2.0, s * 0.04), true)


func _eyes(c: Vector2, s: float, spread: float) -> void:
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(spread * sx, 0) * s
		draw_circle(e, s * 0.07, _k(Color.WHITE))
		draw_circle(e + Vector2(0, 0.01) * s, s * 0.035, _k(Color("2b2233")))
