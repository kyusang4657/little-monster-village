class_name DemonGeo
extends CharGeo
## 악마형 마왕(6차) 전용 기하 도우미. CharGeo 를 상속해 공유 코드는 건드리지 않고
## "이어지는 곡면"을 만드는 도형을 더한다: 조각 구(머리), 회전체(몸통), 마디마다 뼈·색이 바뀌는 이어진 관(팔다리·뿔·꼬리).
## 정점 색에 미리 넣던 위·아래 명암(bake)은 끌 수 있다(실시간 조명만으로 명암을 낸다).

## 정점 색에 넣는 위·아래 명암 세기(CharGeo 기본 = 위 0.16 / 아래 0.2). 0 이면 넣지 않는다
var bake := 0.0


func _vert(p: Vector3, nn: Vector3, col: Color) -> void:
	v.append(p)
	var nm := nn.normalized()
	n.append(nm)
	var shaded := col.lightened(0.16 * bake * maxf(nm.y, 0.0)).darkened(0.2 * bake * maxf(-nm.y, 0.0))
	shaded.a = line
	c.append(shaded)
	vb.append(bone)
	if measure:
		top = maxf(top, p.y)
	if measure_all:
		all_top = maxf(all_top, p.y)


## 방향(단위 벡터, 머리 공간: 정면 -Z, 위 +Y)에 따라 반지름 배수를 돌려주는 함수로 구를 조각한다.
## shape.call(dir: Vector3) -> float (1.0 = 기본 구). 법선은 조각된 겉면의 접선으로 계산해 매끈하다.
## col_of 가 있으면 col_of.call(dir, p) -> Color 로 정점마다 색을 정한다(피부·볼 홍조 등). 극은 +Y(정수리).
func sculpt(ce: Vector3, r: Vector3, col: Color, segs: int, rings: int, shape: Callable, col_of: Callable = Callable()) -> void:
	var base := v.size()
	for i in rings + 1:
		var lat := PI * float(i) / float(rings)
		for j in segs + 1:
			var lon := TAU * float(j) / float(segs)
			var p := _sculpt_p(r, lat, lon, shape)
			var dlat := 0.012
			var dlon := 0.012
			var nn: Vector3
			if i == 0:
				nn = Vector3.UP
			elif i == rings:
				nn = Vector3.DOWN
			else:
				var pa := _sculpt_p(r, lat + dlat, lon, shape) - _sculpt_p(r, lat - dlat, lon, shape)
				var pb := _sculpt_p(r, lat, lon + dlon, shape) - _sculpt_p(r, lat, lon - dlon, shape)
				nn = pb.cross(pa).normalized()
				if nn.dot(p) < 0.0:
					nn = -nn
			var cc := col
			if col_of.is_valid():
				cc = col_of.call(p.normalized(), p)
			_vert(ce + p, nn, cc)
	for i in rings:
		for j in segs:
			var a := base + i * (segs + 1) + j
			var b := a + 1
			var d := a + segs + 1
			var e := d + 1
			if i > 0:
				tri(a, b, d)
			if i < rings - 1:
				tri(b, e, d)


static func _sculpt_p(r: Vector3, lat: float, lon: float, shape: Callable) -> Vector3:
	var dir := Vector3(sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
	var k: float = shape.call(dir)
	return Vector3(dir.x * r.x, dir.y * r.y, dir.z * r.z) * k


## 가우스 혹: 방향 dir 이 중심 방향 cdir 에서 벗어난 각도에 따라 0~1 (sigma = 라디안)
static func bump(dir: Vector3, cdir: Vector3, sigma: float) -> float:
	var a := dir.angle_to(cdir)
	return exp(-(a * a) / (2.0 * sigma * sigma))


## 회전체(몸통·옷): 프로파일 = [{y, rx, rz, bone, col}] 를 위에서 아래로. 고리끼리 정점을 공유해 한 장의 매끈한 면이 된다.
## 각 고리의 정점은 그 고리의 뼈에 묶인다(강체 스킨). 법선은 프로파일의 접선으로 계산한다. close_top/close_bottom 으로 끝을 막는다.
## 단면은 타원(rx, rz). line_of 가 있으면 고리마다 외곽선 세기(정점 알파)를 정한다(몸속에 숨은 고리는 0).
func lathe(prof: Array, segs: int, close_top: bool, close_bottom: bool, cx: float = 0.0, cz: float = 0.0, line_of: Callable = Callable()) -> void:
	var cnt := prof.size()
	if cnt < 2:
		return
	var base := v.size()
	var keep_line := line
	for i in cnt:
		var P: Dictionary = prof[i]
		var y: float = P.y
		var rx: float = P.rx
		var rz: float = P.rz
		use(String(P.bone))
		if line_of.is_valid():
			line = float(line_of.call(i))
		var Pp: Dictionary = prof[maxi(i - 1, 0)]
		var Pn: Dictionary = prof[mini(i + 1, cnt - 1)]
		# 접선(y 방향 변화량 대비 반지름 변화량)으로 법선 기울기
		var dy: float = float(Pn.y) - float(Pp.y)
		var drx: float = float(Pn.rx) - float(Pp.rx)
		var drz: float = float(Pn.rz) - float(Pp.rz)
		for j in segs + 1:
			var a := TAU * float(j) / float(segs)
			var ca := cos(a)
			var sa := sin(a)
			var p := Vector3(cx + ca * rx, y, cz + sa * rz)
			# 타원 단면의 바깥 법선 + 프로파일 기울기
			var nr := Vector3(ca / maxf(rx, 0.0001), 0.0, sa / maxf(rz, 0.0001)).normalized()
			var slope := 0.0
			if absf(dy) > 0.00001:
				slope = -(drx * absf(ca) + drz * absf(sa)) / dy
			var nn := (nr + Vector3(0, slope, 0)).normalized()
			_vert(p, nn, P.col)
	for i in cnt - 1:
		for j in segs:
			var i0 := base + i * (segs + 1) + j
			var i1 := i0 + segs + 1
			tri(i0, i0 + 1, i1)
			tri(i0 + 1, i1 + 1, i1)
	line = keep_line
	if close_top:
		var P0: Dictionary = prof[0]
		use(String(P0.bone))
		var cb := v.size()
		_vert(Vector3(cx, P0.y, cz), Vector3.UP, P0.col)
		for j in segs:
			var a := TAU * float(j) / float(segs)
			_vert(Vector3(cx + cos(a) * float(P0.rx), P0.y, cz + sin(a) * float(P0.rz)), Vector3.UP, P0.col)
		for j in segs:
			tri(cb, cb + 1 + j, cb + 1 + (j + 1) % segs)
	if close_bottom:
		var P1: Dictionary = prof[cnt - 1]
		use(String(P1.bone))
		var cb := v.size()
		_vert(Vector3(cx, P1.y, cz), Vector3.DOWN, P1.col)
		for j in segs:
			var a := TAU * float(j) / float(segs)
			_vert(Vector3(cx + cos(a) * float(P1.rx), P1.y, cz + sin(a) * float(P1.rz)), Vector3.DOWN, P1.col)
		for j in segs:
			tri(cb, cb + 1 + j, cb + 1 + (j + 1) % segs)


## 이어진 관(팔·다리·뿔·꼬리): 마디 = [{p, r, bone, col, [line], [fu], [fw]}]. 고리끼리 정점을 공유하고 프레임을 이어 받아 꼬이지 않는다.
## 마디마다 뼈가 바뀌어도 메시는 이어진다(관절에서 늘어날 뿐 끊기지 않는다). 끝은 둥근 반구(cap_r > 0)나 뾰족(r = 0)으로 막는다.
func limb(nodes: Array, segs: int, ref_axis: Vector3 = Vector3.RIGHT, cap_start: bool = false, cap_end: bool = true, round_end: int = 0) -> void:
	var cnt := nodes.size()
	if cnt < 2:
		return
	var pts: Array = []
	for N: Dictionary in nodes:
		pts.append(N.p)
	# 둥근 끝: 마지막 마디 뒤에 반구 모양 고리를 덧붙인다
	var work: Array = nodes.duplicate()
	if round_end > 0:
		var last: Dictionary = nodes[cnt - 1]
		var prev: Dictionary = nodes[cnt - 2]
		var d: Vector3 = ((last.p as Vector3) - (prev.p as Vector3)).normalized()
		var rr: float = last.r
		for k in range(1, round_end + 1):
			var t := float(k) / float(round_end)
			var ang := t * PI * 0.5
			var nd := last.duplicate()
			nd.p = (last.p as Vector3) + d * (rr * sin(ang))
			nd.r = rr * cos(ang)
			work.append(nd)
		cnt = work.size()
		pts = []
		for N: Dictionary in work:
			pts.append(N.p)
	var tan: Array[Vector3] = []
	for i in cnt:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, cnt - 1)]
		var t := b - a
		tan.append(t.normalized() if t.length() > 0.00001 else Vector3.UP)
	var u := ref_axis
	if absf(tan[0].dot(u)) > 0.95:
		u = Vector3.BACK if absf(tan[0].z) < 0.95 else Vector3.UP
	u = (u - tan[0] * u.dot(tan[0])).normalized()
	var us: Array[Vector3] = []
	var ws: Array[Vector3] = []
	var base := v.size()
	var keep_line := line
	for i in cnt:
		var N: Dictionary = work[i]
		var d: Vector3 = tan[i]
		u = (u - d * u.dot(d)).normalized()
		var w := d.cross(u)
		us.append(u)
		ws.append(w)
		use(String(N.bone))
		line = float(N.get("line", keep_line))
		var r: float = N.r
		var fu: float = N.get("fu", 1.0)
		var fw: float = N.get("fw", 1.0)
		var r_prev: float = (work[maxi(i - 1, 0)] as Dictionary).r
		var r_next: float = (work[mini(i + 1, cnt - 1)] as Dictionary).r
		var span: float = (pts[mini(i + 1, cnt - 1)] - pts[maxi(i - 1, 0)]).length()
		var slope := (r_prev - r_next) / maxf(span, 0.0001)
		for j in segs + 1:
			var ang := TAU * float(j) / float(segs)
			var off := u * (cos(ang) * r * fu) + w * (sin(ang) * r * fw)
			var nn := (u * (cos(ang) / fu) + w * (sin(ang) / fw)).normalized() + d * slope
			_vert((N.p as Vector3) + off, nn, N.col)
	for i in cnt - 1:
		for j in segs:
			var i0 := base + i * (segs + 1) + j
			var i2 := i0 + segs + 1
			tri(i0, i2, i0 + 1)
			tri(i0 + 1, i2, i2 + 1)
	line = keep_line
	for k in 2:
		if (k == 0 and not cap_start) or (k == 1 and not cap_end):
			continue
		var ii := 0 if k == 0 else cnt - 1
		var N: Dictionary = work[ii]
		var r: float = N.r
		if r <= 0.0001:
			continue
		use(String(N.bone))
		var nn: Vector3 = -tan[ii] if k == 0 else tan[ii]
		var cb := v.size()
		_vert(N.p, nn, N.col)
		var fu: float = N.get("fu", 1.0)
		var fw: float = N.get("fw", 1.0)
		for j in segs:
			var ang := TAU * float(j) / float(segs)
			_vert((N.p as Vector3) + us[ii] * (cos(ang) * r * fu) + ws[ii] * (sin(ang) * r * fw), nn, N.col)
		for j in segs:
			tri(cb, cb + 1 + j, cb + 1 + (j + 1) % segs)


## 3차 베지어 점
static func bez(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var s := 1.0 - t
	return p0 * (s * s * s) + p1 * (3.0 * s * s * t) + p2 * (3.0 * s * t * t) + p3 * (t * t * t)


## 망토 천(CharGeo.cape 와 같은 식)인데 격자 점들을 돌려준다(가장자리에 금 테를 두르거나 문양을 붙일 때). P[i][j] = i 행(위→아래), j 열(왼→오른).
func cape_grid(top: Vector3, length: float, w_top: float, w_bot: float, col_out: Color, col_in: Color,
		drape: float, wrap: float, hem_wave: float, cols: int, rows: int, thickness: float) -> Array:
	var P: Array = []
	for i in rows + 1:
		var t := float(i) / float(rows)
		var w := lerpf(w_top, w_bot, t)
		var row: Array = []
		for j in cols + 1:
			var u := float(j) / float(cols) - 0.5
			var y := top.y - length * t
			if hem_wave > 0.0:
				y -= hem_wave * t * t * (0.5 + 0.5 * cos(u * TAU * 1.5))
			var z := top.z + drape * t * t - wrap * (u * u * 4.0) * (0.3 + 0.7 * t)
			row.append(Vector3(top.x + u * w, y, z))
		P.append(row)
	var keep := line
	line = keep * 0.8
	for s: float in [1.0, -1.0]:
		var col := col_out if s > 0.0 else col_in
		var b0 := v.size()
		for i in rows + 1:
			for j in cols + 1:
				var p: Vector3 = P[i][j]
				var du: Vector3 = (P[i][mini(j + 1, cols)] as Vector3) - (P[i][maxi(j - 1, 0)] as Vector3)
				var dt: Vector3 = (P[mini(i + 1, rows)][j] as Vector3) - (P[maxi(i - 1, 0)][j] as Vector3)
				var nn := du.cross(dt).normalized()
				if nn.z < 0.0:
					nn = -nn
				nn *= s
				_vert(p + nn * thickness, nn, col)
		for i in rows:
			for j in cols:
				var a := b0 + i * (cols + 1) + j
				var d := a + cols + 1
				tri(a, a + 1, d)
				tri(a + 1, d + 1, d)
	line = keep
	return P


## 코트 같은 회전체 겉면을 따라가는 띠(x0~x1, y_top~y_bot). rz_of.call(y) 가 그 높이의 앞쪽 반지름, rx_of.call(y) 가 옆 반지름.
## 겉면에서 lift 만큼 띄워 그린다(겉면 색 띠·장식 띠). 법선은 바깥(-Z 쪽) 방향.
func front_strip(x0: float, x1: float, y_top: float, y_bot: float, rz_of: Callable, rx_of: Callable, lift: float, col: Color, steps: int = 6) -> void:
	var base := v.size()
	for i in steps + 1:
		var y := lerpf(y_top, y_bot, float(i) / float(steps))
		var rz: float = rz_of.call(y)
		var rx: float = rx_of.call(y)
		for x in [x0, x1]:
			var q := 1.0 - pow(clampf(x / maxf(rx, 0.0001), -0.999, 0.999), 2.0)
			var z := -rz * sqrt(q) - lift
			var nn := Vector3(x / (rx * rx), 0.0, z / (rz * rz)).normalized()
			_vert(Vector3(x, y, z), nn, col)
	for i in steps:
		var a := base + i * 2
		tri(a, a + 1, a + 2)
		tri(a + 1, a + 3, a + 2)
