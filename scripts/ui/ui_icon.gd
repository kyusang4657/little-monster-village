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
		"lumber":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, -0.1) * s, c + Vector2(0.42, -0.28) * s, c + Vector2(0.42, -0.18) * s, c + Vector2(-0.42, 0.0) * s]), Color("7a4bc4"))
			draw_rect(Rect2(c + Vector2(-0.36, -0.05) * s, Vector2(0.08, 0.42) * s), Color("8f5a2b"))
			draw_rect(Rect2(c + Vector2(0.28, -0.22) * s, Vector2(0.08, 0.6) * s), Color("8f5a2b"))
			draw_circle(c + Vector2(-0.05, 0.27) * s, s * 0.1, Color("e9c48a"))
			draw_circle(c + Vector2(0.15, 0.27) * s, s * 0.1, Color("e9c48a"))
