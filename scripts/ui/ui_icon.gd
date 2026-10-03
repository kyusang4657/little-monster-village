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


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var w := maxf(2.0, s * 0.11)
	match kind:
		"check":
			draw_circle(c, s * 0.48, Color("3fae4a"))
			draw_polyline(PackedVector2Array([c + Vector2(-0.24, 0.0) * s, c + Vector2(-0.06, 0.18) * s, c + Vector2(0.25, -0.17) * s]), Color.WHITE, w, true)
		"ban":
			draw_circle(c, s * 0.48, Color("d9383e"))
			draw_circle(c, s * 0.3, Color("fff7e6"))
			draw_line(c + Vector2(-0.22, 0.22) * s, c + Vector2(0.22, -0.22) * s, Color("d9383e"), w * 1.2, true)
		"wood":
			draw_rect(Rect2(c + Vector2(-0.42, -0.16) * s, Vector2(0.72, 0.32) * s), Color("b5712f"))
			draw_circle(c + Vector2(0.3, 0) * s, s * 0.17, Color("e9c48a"))
			draw_arc(c + Vector2(0.3, 0) * s, s * 0.09, 0, TAU, 12, Color("b5712f"), maxf(1.5, s * 0.04))
			draw_rect(Rect2(c + Vector2(-0.42, -0.42) * s, Vector2(0.6, 0.22) * s), Color("9a5d26"))
			draw_circle(c + Vector2(0.18, -0.31) * s, s * 0.11, Color("e9c48a"))
		"pause":
			draw_rect(Rect2(c + Vector2(-0.26, -0.3) * s, Vector2(0.18, 0.6) * s), color)
			draw_rect(Rect2(c + Vector2(0.08, -0.3) * s, Vector2(0.18, 0.6) * s), color)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, -0.3) * s, c + Vector2(0.3, 0) * s, c + Vector2(-0.22, 0.3) * s]), color)
		"menu":
			for i in 3:
				draw_rect(Rect2(c + Vector2(-0.3, -0.27 + i * 0.22) * s, Vector2(0.6, 0.11) * s), color)
		"x":
			draw_line(c + Vector2(-0.25, -0.25) * s, c + Vector2(0.25, 0.25) * s, color, w * 1.3, true)
			draw_line(c + Vector2(-0.25, 0.25) * s, c + Vector2(0.25, -0.25) * s, color, w * 1.3, true)
		"rotate":
			draw_arc(c, s * 0.3, -PI * 0.15, PI * 1.45, 20, color, w * 1.1, true)
			var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * s * 0.3
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.16, -0.08) * s, tip + Vector2(0.12, -0.04) * s, tip + Vector2(0.0, 0.2) * s]), color)
		"hammer":
			draw_line(c + Vector2(-0.3, 0.32) * s, c + Vector2(0.12, -0.1) * s, Color("e9c48a"), w * 1.4, true)
			draw_set_transform(c + Vector2(0.12, -0.14) * s, -PI * 0.25)
			draw_rect(Rect2(Vector2(-0.28, -0.12) * s, Vector2(0.56, 0.24) * s), Color("cfd6de"))
			draw_set_transform(Vector2.ZERO)
		"shield":
			var pts := PackedVector2Array([c + Vector2(0, -0.42) * s, c + Vector2(0.36, -0.28) * s, c + Vector2(0.3, 0.12) * s, c + Vector2(0, 0.42) * s, c + Vector2(-0.3, 0.12) * s, c + Vector2(-0.36, -0.28) * s])
			draw_colored_polygon(pts, color)
		"knight":
			draw_circle(c + Vector2(0, -0.05) * s, s * 0.3, Color("cfd6de"))
			draw_rect(Rect2(c + Vector2(-0.2, -0.08) * s, Vector2(0.4, 0.08) * s), Color("3a2443"))
			draw_circle(c + Vector2(0.05, -0.38) * s, s * 0.12, Color("c8343a"))
		"house":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, -0.02) * s, c + Vector2(0, -0.42) * s, c + Vector2(0.42, -0.02) * s]), Color("7a4bc4"))
			draw_rect(Rect2(c + Vector2(-0.3, -0.02) * s, Vector2(0.6, 0.4) * s), Color("f3e6c4"))
			draw_rect(Rect2(c + Vector2(-0.08, 0.12) * s, Vector2(0.16, 0.26) * s), Color("8f5a2b"))
		"tower":
			draw_rect(Rect2(c + Vector2(-0.36, -0.2) * s, Vector2(0.72, 0.1) * s), Color("c98a45"))
			for x in [-0.3, 0.22]:
				draw_rect(Rect2(c + Vector2(x, -0.36) * s, Vector2(0.08, 0.78) * s), Color("8f5a2b"))
			draw_rect(Rect2(c + Vector2(-0.14, -0.1) * s, Vector2(0.28, 0.3) * s), Color("7a4bc4"))
			draw_line(c + Vector2(-0.28, -0.32) * s, c + Vector2(0.28, -0.32) * s, Color("5b3a1f"), w, true)
		"fence":
			for x in [-0.34, 0.0, 0.34]:
				draw_rect(Rect2(c + Vector2(x - 0.06, -0.34) * s, Vector2(0.12, 0.7) * s), Color("8f5a2b"))
			draw_rect(Rect2(c + Vector2(-0.42, -0.16) * s, Vector2(0.84, 0.1) * s), Color("c98a45"))
			draw_rect(Rect2(c + Vector2(-0.42, 0.1) * s, Vector2(0.84, 0.1) * s), Color("c98a45"))
		"castle":
			draw_rect(Rect2(c + Vector2(-0.3, -0.1) * s, Vector2(0.6, 0.48) * s), Color("efe5cf"))
			for x in [-0.36, 0.22]:
				draw_rect(Rect2(c + Vector2(x, -0.24) * s, Vector2(0.14, 0.62) * s), Color("efe5cf"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(x - 0.04, -0.24) * s, c + Vector2(x + 0.07, -0.46) * s, c + Vector2(x + 0.18, -0.24) * s]), Color("7a4bc4"))
			draw_rect(Rect2(c + Vector2(-0.08, 0.12) * s, Vector2(0.16, 0.26) * s), Color("2fa4a0"))
		"heart":
			draw_circle(c + Vector2(-0.14, -0.08) * s, s * 0.2, color)
			draw_circle(c + Vector2(0.14, -0.08) * s, s * 0.2, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.33, 0.0) * s, c + Vector2(0.33, 0.0) * s, c + Vector2(0, 0.38) * s]), color)
		"clock":
			draw_circle(c, s * 0.42, color)
			draw_circle(c, s * 0.32, Color("fff7e6"))
			draw_line(c, c + Vector2(0, -0.22) * s, color, w, true)
			draw_line(c, c + Vector2(0.16, 0.0) * s, color, w, true)
		"chief":
			# 고블린 촌장: 큰 귀, 흰 콧수염, 외알 안경, 작은 모자
			_face_bg(c, s, Color("efe2ff"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.05) * s, c + Vector2(-0.62, -0.28) * s, c + Vector2(-0.3, 0.12) * s]), Color("6aa22c"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, -0.05) * s, c + Vector2(0.62, -0.28) * s, c + Vector2(0.3, 0.12) * s]), Color("6aa22c"))
			draw_circle(c + Vector2(0, 0.05) * s, s * 0.32, Color("8cc63f"))
			_eyes(c + Vector2(0, -0.02) * s, s, 0.11)
			draw_arc(c + Vector2(0.11, -0.02) * s, s * 0.08, 0, TAU, 16, Color("c9a24a"), maxf(1.5, s * 0.025))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, 0.15) * s, c + Vector2(0, 0.1) * s, c + Vector2(0.2, 0.15) * s, c + Vector2(0.12, 0.24) * s, c + Vector2(0, 0.18) * s, c + Vector2(-0.12, 0.24) * s]), Color("f4f1ea"))
			draw_rect(Rect2(c + Vector2(-0.18, -0.4) * s, Vector2(0.36, 0.1) * s), Color("7a4bc4"))
			draw_rect(Rect2(c + Vector2(-0.11, -0.55) * s, Vector2(0.22, 0.17) * s), Color("7a4bc4"))
		"imp":
			# 꼬마 마물: 보라 동그란 얼굴, 작은 뿔, 커다란 눈, 땀방울
			_face_bg(c, s, Color("fff3d8"))
			for sx in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0.12 * sx, -0.26) * s, c + Vector2(0.26 * sx, -0.5) * s, c + Vector2(0.26 * sx, -0.22) * s]), Color("f1e6cf"))
			draw_circle(c + Vector2(0, 0.04) * s, s * 0.32, Color("9b6fd6"))
			_eyes(c + Vector2(0, 0.0) * s, s, 0.13)
			draw_arc(c + Vector2(0, 0.17) * s, s * 0.06, PI * 0.1, PI * 0.9, 8, Color("3a2443"), maxf(1.5, s * 0.03))
			draw_circle(c + Vector2(0.3, -0.18) * s, s * 0.05, Color("8fd3ff"))
		"commander":
			# 기사단장: 은색 투구, 붉은 깃, 팔자 콧수염
			_face_bg(c, s, Color("ffe9e4"))
			draw_circle(c + Vector2(0, 0.08) * s, s * 0.3, Color("f2c9a0"))
			draw_circle(c + Vector2(0, -0.1) * s, s * 0.33, Color("b9c3cd"))
			draw_rect(Rect2(c + Vector2(-0.3, -0.06) * s, Vector2(0.6, 0.12) * s), Color("b9c3cd"))
			draw_rect(Rect2(c + Vector2(-0.26, -0.02) * s, Vector2(0.52, 0.05) * s), Color("2b2233"))
			draw_circle(c + Vector2(0.05, -0.5) * s, s * 0.13, Color("c8343a"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.24, 0.16) * s, c + Vector2(0, 0.12) * s, c + Vector2(0.24, 0.16) * s, c + Vector2(0.14, 0.2) * s, c + Vector2(0, 0.16) * s, c + Vector2(-0.14, 0.2) * s]), Color("6b3f1f"))
		"hero":
			# 용사: 금발, 이마띠, 반짝이는 눈
			_face_bg(c, s, Color("fff7d0"))
			draw_circle(c + Vector2(0, 0.06) * s, s * 0.3, Color("f2c9a0"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34, -0.02) * s, c + Vector2(-0.2, -0.36) * s, c + Vector2(0, -0.3) * s, c + Vector2(0.22, -0.38) * s, c + Vector2(0.34, -0.02) * s, c + Vector2(0, -0.14) * s]), Color("f0c53a"))
			draw_rect(Rect2(c + Vector2(-0.3, -0.16) * s, Vector2(0.6, 0.06) * s), Color("2e9c97"))
			_eyes(c + Vector2(0, 0.04) * s, s, 0.1)
			draw_arc(c + Vector2(0, 0.18) * s, s * 0.07, PI * 0.15, PI * 0.85, 8, Color("3a2443"), maxf(1.5, s * 0.03))
		"expand":
			draw_rect(Rect2(c + Vector2(-0.18, -0.18) * s, Vector2(0.36, 0.36) * s), Color("94cd5e"))
			draw_rect(Rect2(c + Vector2(-0.18, -0.18) * s, Vector2(0.36, 0.36) * s), Color("8f5a2b"), false, maxf(2.0, s * 0.06))
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var tip: Vector2 = c + d * 0.46 * s
				var side := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([tip, tip - d * 0.16 * s + side * 0.1 * s, tip - d * 0.16 * s - side * 0.1 * s]), Color("7a4bc4"))
		"outpost":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34, -0.02) * s, c + Vector2(-0.04, -0.3) * s, c + Vector2(0.26, -0.02) * s]), Color("7a4bc4"))
			draw_rect(Rect2(c + Vector2(-0.26, -0.02) * s, Vector2(0.44, 0.36) * s), Color("c98a45"))
			draw_line(c + Vector2(0.34, 0.34) * s, c + Vector2(0.34, -0.42) * s, Color("8f5a2b"), maxf(2.0, s * 0.06))
			draw_rect(Rect2(c + Vector2(0.34, -0.42) * s, Vector2(0.14, 0.12) * s), Color("7a4bc4"))
			draw_circle(c + Vector2(-0.38, 0.22) * s, s * 0.12, Color("2f7d45"))
		"flower":
			for i in 5:
				var a := i * TAU / 5.0
				draw_circle(c + Vector2(cos(a), sin(a)) * 0.2 * s, s * 0.14, Color("f29ac0"))
			draw_circle(c, s * 0.12, Color("f5d24a"))
		"lantern":
			draw_rect(Rect2(c + Vector2(-0.07, -0.02) * s, Vector2(0.14, 0.4) * s), Color("f3e6c4"))
			draw_circle(c + Vector2(0, -0.08) * s, s * 0.32, Color("b689ff"))
			draw_rect(Rect2(c + Vector2(-0.34, -0.06) * s, Vector2(0.68, 0.1) * s), Color("b689ff"))
			draw_circle(c + Vector2(-0.12, -0.2) * s, s * 0.05, Color.WHITE)
			draw_circle(c + Vector2(0.1, -0.16) * s, s * 0.04, Color.WHITE)
		"lumber":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, -0.1) * s, c + Vector2(0.42, -0.28) * s, c + Vector2(0.42, -0.18) * s, c + Vector2(-0.42, 0.0) * s]), Color("7a4bc4"))
			draw_rect(Rect2(c + Vector2(-0.36, -0.05) * s, Vector2(0.08, 0.42) * s), Color("8f5a2b"))
			draw_rect(Rect2(c + Vector2(0.28, -0.22) * s, Vector2(0.08, 0.6) * s), Color("8f5a2b"))
			draw_circle(c + Vector2(-0.05, 0.27) * s, s * 0.1, Color("e9c48a"))
			draw_circle(c + Vector2(0.15, 0.27) * s, s * 0.1, Color("e9c48a"))


func _face_bg(c: Vector2, s: float, bg: Color) -> void:
	draw_circle(c, s * 0.5, bg)
	draw_arc(c, s * 0.49, 0, TAU, 32, color, maxf(2.0, s * 0.04), true)


func _eyes(c: Vector2, s: float, spread: float) -> void:
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(spread * sx, 0) * s
		draw_circle(e, s * 0.07, Color.WHITE)
		draw_circle(e + Vector2(0, 0.01) * s, s * 0.035, Color("2b2233"))
