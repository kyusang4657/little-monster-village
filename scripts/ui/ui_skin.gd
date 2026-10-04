class_name UiSkin
extends RefCounted
## 두툼한 만화풍 UI 질감(젤리 버튼·양피지 패널·어두운 자원 막대)을 코드로 그려 만든다.
## 외부 그림 파일 없이 Image 에 픽셀을 칠해 StyleBoxTexture(9칸 늘이기)로 쓴다. 색마다 한 번만 만들고 재사용한다.

static var _cache: Dictionary = {}

const OUTLINE := Color("2e1a0e")


## 둥근 사각형까지의 부호 거리(안쪽 음수)
static func _sd(px: float, py: float, r: Rect2, rad: float) -> float:
	var c := r.get_center()
	var hx := r.size.x * 0.5 - rad
	var hy := r.size.y * 0.5 - rad
	var qx := absf(px - c.x) - hx
	var qy := absf(py - c.y) - hy
	var ox := maxf(qx, 0.0)
	var oy := maxf(qy, 0.0)
	return sqrt(ox * ox + oy * oy) + minf(maxf(qx, qy), 0.0) - rad


static func _over(dst: Color, src: Color, a: float) -> Color:
	var sa := src.a * a
	var oa := sa + dst.a * (1.0 - sa)
	if oa <= 0.0001:
		return Color(0, 0, 0, 0)
	var rgb := (Color(src.r, src.g, src.b) * sa + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - sa)) / oa
	return Color(rgb.r, rgb.g, rgb.b, oa)


## layers: [{rect, rad, color 또는 grad=[위색, 아래색], stroke(선 두께, 0 = 채움)}] 를 차례로 덮어 칠한다
static func _paint(w: int, h: int, layers: Array) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var col := Color(0, 0, 0, 0)
			for L in layers:
				var r: Rect2 = L.rect
				var d := _sd(px, py, r, float(L.rad))
				var a := 0.0
				var st := float(L.get("stroke", 0.0))
				if st > 0.0:
					a = clampf(0.5 - absf(d + st * 0.5) + st * 0.5, 0.0, 1.0)
				else:
					a = clampf(0.5 - d, 0.0, 1.0)
				if a <= 0.0:
					continue
				var c: Color
				if L.has("grad"):
					var t := clampf((py - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)
					c = (L.grad[0] as Color).lerp(L.grad[1] as Color, t)
				else:
					c = L.color
				col = _over(col, c, a)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _box(tex: Texture2D, ml: float, mt: float, mr: float, mb: float, pad: Vector4) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = ml
	s.texture_margin_top = mt
	s.texture_margin_right = mr
	s.texture_margin_bottom = mb
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


## 젤리 버튼: 짙은 외곽선, 위가 밝은 그라데이션, 윗부분 광택, 아래 두께(입술). pressed 는 눌려 들어간 모양.
static func button(base: Color, state: String = "normal") -> StyleBoxTexture:
	var key := "btn:%s:%s" % [base.to_html(), state]
	if _cache.has(key):
		return _cache[key]
	var W := 112
	var H := 108
	var o := 5.0
	var R := 24.0
	var lip := 9.0 if state != "pressed" else 3.0
	var down := 0.0 if state != "pressed" else 6.0
	var col := base
	if state == "hover":
		col = base.lightened(0.07)
	elif state == "pressed":
		col = base.darkened(0.08)
	var inner := Rect2(o, o + down, W - o * 2.0, H - o * 2.0 - down)
	var body := Rect2(inner.position, Vector2(inner.size.x, inner.size.y - lip))
	var gloss := Rect2(body.position + Vector2(7, 4), Vector2(body.size.x - 14, body.size.y * 0.4))
	var layers := [
		{rect = Rect2(0, down, W, H - down), rad = R, color = OUTLINE.lerp(base.darkened(0.7), 0.35)},
		{rect = inner, rad = R - o, color = col.darkened(0.38)},
		{rect = body, rad = R - o, grad = [col.lightened(0.28), col.darkened(0.06)]},
		{rect = gloss, rad = (R - o) * 0.7, grad = [Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.08)]},
		{rect = body.grow(-1.5), rad = R - o - 1.5, color = Color(1, 1, 1, 0.22), stroke = 2.0},
	]
	var s := _box(_paint(W, H, layers), R + 2, R + 2 + down, R + 2, R + lip + 2, Vector4(20, 8 + down, 20, 8 + lip))
	_cache[key] = s
	return s


## 양피지 패널: 짙은 갈색 외곽선, 크림색 그라데이션, 안쪽 밝은 선, 아래 두께
static func panel(kind: String = "parchment") -> StyleBoxTexture:
	var key := "panel:" + kind
	if _cache.has(key):
		return _cache[key]
	var W := 96
	var H := 96
	var s: StyleBoxTexture
	match kind:
		"dark":
			var layers := [
				{rect = Rect2(0, 0, W, H), rad = 18.0, color = Color(0.07, 0.04, 0.03, 0.9)},
				{rect = Rect2(3, 3, W - 6, H - 6), rad = 15.0, grad = [Color(0.25, 0.17, 0.12, 0.92), Color(0.13, 0.08, 0.06, 0.92)]},
				{rect = Rect2(4, 4, W - 8, H - 8), rad = 14.0, color = Color(1, 1, 1, 0.12), stroke = 1.5},
			]
			s = _box(_paint(W, H, layers), 20, 20, 20, 20, Vector4(16, 8, 16, 8))
		"card":
			var layers := [
				{rect = Rect2(0, 0, W, H), rad = 16.0, color = OUTLINE},
				{rect = Rect2(4, 4, W - 8, H - 8), rad = 12.0, color = Color("c9a46a")},
				{rect = Rect2(4, 4, W - 8, H - 14), rad = 12.0, grad = [Color("fffaf0"), Color("f1e2bf")]},
			]
			s = _box(_paint(W, H, layers), 18, 18, 18, 22, Vector4(12, 8, 12, 12))
		_:
			var layers := [
				{rect = Rect2(0, 0, W, H), rad = 22.0, color = Color("4a2a12")},
				{rect = Rect2(5, 5, W - 10, H - 10), rad = 17.0, color = Color("b8874e")},
				{rect = Rect2(5, 5, W - 10, H - 17), rad = 17.0, grad = [Color("fdf3dc"), Color("eed6a2")]},
				{rect = Rect2(8, 8, W - 16, H - 23), rad = 14.0, color = Color(1, 1, 1, 0.55), stroke = 2.0},
			]
			s = _box(_paint(W, H, layers), 24, 24, 24, 30, Vector4(22, 14, 22, 18))
	_cache[key] = s
	return s


## 자원 막대 채움(위 밝고 아래 진한 그라데이션 + 광택)
static func bar_fill(base: Color) -> StyleBoxTexture:
	var key := "bar:" + base.to_html()
	if _cache.has(key):
		return _cache[key]
	var W := 48
	var H := 32
	var layers := [
		{rect = Rect2(0, 0, W, H), rad = 10.0, grad = [base.lightened(0.3), base.darkened(0.15)]},
		{rect = Rect2(4, 3, W - 8, H * 0.38), rad = 6.0, color = Color(1, 1, 1, 0.35)},
	]
	var s := _box(_paint(W, H, layers), 12, 12, 12, 12, Vector4(0, 0, 0, 0))
	_cache[key] = s
	return s
