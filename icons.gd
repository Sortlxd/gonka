extends Control
# Векторные иконки, нарисованные кодом (вместо смайликов).
# Использование: Icons.new().setup("gear", Color.WHITE, 40)
# Координаты внутри иконки — от 0 до 100.

var icon = ""
var color = Color.WHITE
var hole = Color(0, 0, 0, 0.35)   # цвет «дырок» (центр шестерни, гайки и т.п.)


func setup(icon_name: String, col: Color, sz: float) -> Control:
	icon = icon_name
	color = col
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func set_icon(icon_name: String):
	icon = icon_name
	queue_redraw()


var _o = Vector2.ZERO
var _u = 1.0

func P(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _u


func circ(x: float, y: float, r: float, col: Color):
	draw_circle(P(x, y), r * _u, col)


func line(pts: Array, w: float, col = null):
	col = color if col == null else col
	var arr = PackedVector2Array()
	for p in pts:
		arr.append(P(p[0], p[1]))
	draw_polyline(arr, col, w * _u, true)


func poly(pts: Array, col = null):
	col = color if col == null else col
	var arr = PackedVector2Array()
	for p in pts:
		arr.append(P(p[0], p[1]))
	draw_colored_polygon(arr, col)


func arc(x: float, y: float, r: float, a0: float, a1: float, w: float, col = null):
	col = color if col == null else col
	draw_arc(P(x, y), r * _u, deg_to_rad(a0), deg_to_rad(a1), 32, col, w * _u, true)


func rect(x: float, y: float, w: float, h: float, col = null):
	col = color if col == null else col
	draw_rect(Rect2(P(x, y), Vector2(w, h) * _u), col)


func _draw():
	var s = minf(size.x, size.y)
	_o = (size - Vector2(s, s)) / 2.0
	_u = s / 100.0
	match icon:
		"speed":
			arc(50, 60, 36, 150, 390, 10)
			line([[50, 60], [72, 36]], 9)
			circ(50, 60, 9, color)
		"bolt":
			poly([[60, 4], [20, 56], [46, 56], [38, 96], [80, 40], [54, 40], [64, 4]])
		"overtake":
			line([[20, 56], [50, 28], [80, 56]], 11)
			line([[20, 82], [50, 54], [80, 82]], 11, Color(color, 0.6))
		"clock":
			arc(50, 50, 38, 0, 360, 9)
			line([[50, 50], [50, 26]], 8)
			line([[50, 50], [68, 60]], 8)
			circ(50, 50, 6, color)
		"gear":
			var pts = []
			for i in 32:
				var a = i / 32.0 * TAU
				var r = 46.0 if (i % 4) < 2 else 33.0
				pts.append([50 + cos(a) * r, 50 + sin(a) * r])
			poly(pts)
			circ(50, 50, 14, hole)
		"trophy":
			poly([[26, 14], [74, 14], [70, 44], [58, 58], [42, 58], [30, 44]])
			arc(28, 30, 13, 90, 270, 7)
			arc(72, 30, 13, -90, 90, 7)
			rect(45, 56, 10, 18)
			rect(30, 74, 40, 12)
		"podium":
			rect(10, 54, 26, 36)
			rect(37, 30, 26, 60)
			rect(64, 64, 26, 26)
			poly(star_pts(50, 14, 11, 5))
		"flame":
			poly([[50, 4], [70, 30], [80, 56], [74, 80], [50, 96], [26, 80], [20, 58], [30, 38], [40, 48]])
			poly([[50, 46], [62, 64], [60, 82], [50, 88], [40, 82], [38, 66]], Color(1, 1, 1, 0.45))
		"wheel":
			arc(50, 50, 34, 0, 360, 14)
			circ(50, 50, 10, color)
			for k in 5:
				var a = k * TAU / 5.0
				line([[50 + cos(a) * 10, 50 + sin(a) * 10], [50 + cos(a) * 28, 50 + sin(a) * 28]], 6)
		"turbo":
			arc(50, 50, 40, 0, 360, 7)
			for k in 3:
				var a = k * TAU / 3.0
				poly([[50, 50], [50 + cos(a) * 32, 50 + sin(a) * 32], [50 + cos(a + 0.9) * 20, 50 + sin(a + 0.9) * 20]])
			circ(50, 50, 7, color)
		"drop":
			var pts = [[50, 6]]
			for i in 17:
				var a = deg_to_rad(-35.0 + i * 250.0 / 16.0)
				pts.append([50 + cos(a) * 28, 62 + sin(a) * 28])
			poly(pts)
			circ(40, 64, 7, Color(1, 1, 1, 0.45))
		"box":
			rect(14, 42, 72, 44)
			rect(10, 24, 80, 20)
			rect(44, 36, 12, 16, hole)
		"wrench":
			line([[28, 74], [64, 38]], 14)
			circ(70, 30, 19, color)
			circ(79, 21, 9, hole)
			circ(27, 75, 9, color)
		"star":
			poly(star_pts(50, 52, 46, 20))
		"car":
			poly([[26, 50], [36, 28], [64, 28], [76, 50]])
			rect(8, 48, 84, 24)
			circ(28, 74, 12, color)
			circ(72, 74, 12, color)
			circ(28, 74, 5, hole)
			circ(72, 74, 5, hole)
		"sun":
			circ(50, 50, 20, color)
			for k in 8:
				var a = k * TAU / 8.0
				line([[50 + cos(a) * 30, 50 + sin(a) * 30], [50 + cos(a) * 44, 50 + sin(a) * 44]], 8)
		"moon":
			var pts = []
			for i in 17:   # внешняя дуга (левая половина большого круга)
				var a = deg_to_rad(270.0 - i * 180.0 / 16.0)
				pts.append([50 + cos(a) * 38, 50 + sin(a) * 38])
			for i in 17:   # внутренняя дуга обратно
				var a = deg_to_rad(90.0 + i * 180.0 / 16.0)
				pts.append([64 + cos(a) * 30, 50 + sin(a) * 30])
			poly(pts)
		"cloud":
			cloud_shape(0)
		"rain":
			cloud_shape(-14)
			for x in [34, 50, 66]:
				line([[x, 70], [x - 6, 88]], 6)
		"fog":
			line([[14, 34], [86, 34]], 9)
			line([[22, 52], [78, 52]], 9)
			line([[14, 70], [72, 70]], 9)
		"nut":
			var pts = []
			for i in 6:
				var a = i * TAU / 6.0 + PI / 6.0
				pts.append([50 + cos(a) * 44, 50 + sin(a) * 44])
			poly(pts)
			circ(50, 50, 17, hole)
		"check":
			line([[20, 52], [42, 74], [82, 30]], 13)
		"lock":
			arc(50, 42, 18, 180, 360, 9)
			rect(26, 42, 48, 42)
		"note":
			circ(36, 74, 14, color)
			rect(44, 18, 8, 58)
			poly([[52, 18], [80, 30], [80, 44], [52, 34]])
		"speaker":
			poly([[12, 38], [32, 38], [54, 18], [54, 82], [32, 62], [12, 62]])
			arc(54, 50, 18, -45, 45, 7)
			arc(54, 50, 32, -45, 45, 7)
		"phone":
			draw_rect(Rect2(P(32, 10), Vector2(36, 80) * _u), color, false, 8 * _u)
			rect(44, 76, 12, 5)
			arc(32, 50, 20, 150, 210, 6)
			arc(68, 50, 20, -30, 30, 6)
		"globe":
			arc(50, 50, 38, 0, 360, 7)
			var pts = []
			for i in 33:
				var a = i / 32.0 * TAU
				pts.append([50 + cos(a) * 16, 50 + sin(a) * 38])
			line(pts, 6)
			line([[12, 50], [88, 50]], 6)
		"bird":
			circ(46, 58, 24, color)
			circ(70, 40, 14, color)
			poly([[82, 38], [96, 44], [82, 48]], Color("#ff922b"))
			poly([[22, 52], [44, 30], [52, 56]], Color(1, 1, 1, 0.5))
		"user":
			circ(50, 34, 18, color)
			poly([[18, 90], [22, 66], [36, 56], [64, 56], [78, 66], [82, 90]])


func star_pts(cx: float, cy: float, r_out: float, r_in: float) -> Array:
	var pts = []
	for i in 10:
		var r = r_out if i % 2 == 0 else r_in
		var a = -PI / 2.0 + i * PI / 5.0
		pts.append([cx + cos(a) * r, cy + sin(a) * r])
	return pts


func cloud_shape(dy: float):
	circ(34, 60 + dy, 18, color)
	circ(54, 48 + dy, 23, color)
	circ(72, 62 + dy, 16, color)
	rect(34, 60 + dy, 38, 18)
