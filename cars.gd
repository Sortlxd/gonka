extends RefCounted
# Каталог машин и их «мультяшные» 3D-модели из скруглённых фигур.
# mult — множитель скорости (а значит и заработка),
# price — цена в KM (для обычных машин),
# parts — сколько деталей нужно собрать (для эксклюзивных).

const ORDER = ["hatch", "sedan", "pickup", "sport", "super", "retro", "ghost", "rocket"]

const CARS = {
	"hatch":  {"mult": 1.0, "price": 0,       "color": "#ef476f", "exclusive": false},
	"sedan":  {"mult": 1.3, "price": 100,     "color": "#118ab2", "exclusive": false},
	"pickup": {"mult": 1.6, "price": 750,     "color": "#f4a261", "exclusive": false},
	"sport":  {"mult": 2.2, "price": 4200,    "color": "#ffd166", "exclusive": false},
	"super":  {"mult": 3.0, "price": 20000,   "color": "#8338ec", "exclusive": false},
	"retro":  {"mult": 2.6, "parts": 8,  "color": "#06d6a0", "exclusive": true},
	"ghost":  {"mult": 3.6, "parts": 12, "color": "#2b2d42", "exclusive": true},
	"rocket": {"mult": 5.0, "parts": 16, "color": "#ff006e", "exclusive": true},
}

# Поток машин: [модель, вес]. Чем больше вес, тем чаще встречается.
const TRAFFIC = [
	["van", 20], ["taxi", 14], ["truck", 12], ["bus", 8],  # без машин из гаража
	["police", 8], ["ambulance", 7], ["firetruck", 3],
]
const TRAFFIC_COLORS = ["#4d9de0", "#f4a261", "#2a9d8f", "#e9c46a", "#9aa5b1", "#8e7dbe", "#f1faee", "#3d5a80", "#e76f51", "#90be6d"]
const FIXED_COLORS = {"taxi": "#ffc93c", "police": "#f5f7fa", "ambulance": "#ffffff", "firetruck": "#e63946"}

const GLASS = Color("#2b3a55")
const DARK = Color("#2a2a33")
const CHROME = Color("#d7dde5")
const TRIM = Color("#2b2d33")

static var mesh_cache = {}


static func random_traffic(rng: RandomNumberGenerator) -> Array:
	var total = 0
	for t in TRAFFIC:
		total += t[1]
	var r = rng.randi_range(1, total)
	var shape = "van"
	for t in TRAFFIC:
		r -= t[1]
		if r <= 0:
			shape = t[0]
			break
	var col = FIXED_COLORS.get(shape, TRAFFIC_COLORS[rng.randi() % TRAFFIC_COLORS.size()])
	return [shape, Color(col)]


# w — главный скрипт игры (у него есть rbox / add_mesh / cylinder и т.д.)
# opts: "rim" — цвет дисков, "exhaust" — огонь из выхлопа (от тюнинга)
static func build(w, shape: String, color: Color, opts := {}) -> Node3D:
	var car = Node3D.new()
	match shape:
		"hatch":
			# короткий, почти вертикальная пятая дверь
			base_car(w, car, color, 3.4, 1.8, 0.66, 0.35, 1.95, 0.6, 0.32, opts, 1.3, 0.32)
		"sedan", "taxi", "police":
			var roof = base_car(w, car, color, 3.95, 1.84, 0.6, 0.35, 2.15, 0.55, 0.1, opts, 1.25, 0.05)
			if shape == "taxi":
				w.rbox(Vector3(0.7, 0.2, 0.32), Vector3(0, roof + 0.1, 0.15), Color("#fff3b0"), car, true, "matte", 0.15)
				for sx in [-1.0, 1.0]:
					w.rbox(Vector3(0.02, 0.1, 2.6), Vector3(sx * 0.93, 0.02, 0), Color("#222222"), car, false, "matte", 0.1)
			if shape == "police":
				var y0 = 0.35 - 0.53
				for sx in [-1.0, 1.0]:
					w.rbox(Vector3(0.03, 0.3, 2.1), Vector3(sx * 0.925, y0 + 0.3, -0.05), Color("#1f2a44"), car, false, "paint", 0.1)
				light_bar(w, car, roof, 0.15)
		"van", "ambulance":
			var r = 0.4
			var wy = r - 0.45
			var by = wy - 0.08 + 0.72
			w.rbox(Vector3(1.95, 1.45, 4.3), Vector3(0, by, 0), color, car, false, "paint", 0.12)
			var top = by + 0.72
			var ws = w.rbox(Vector3(1.75, 0.6, 0.08), Vector3(0, top - 0.42, -2.13), GLASS, car, false, "glass", 0.08)
			ws.rotation_degrees.x = 12
			for sx in [-1.0, 1.0]:
				w.rbox(Vector3(0.03, 0.45, 2.6), Vector3(sx * 0.98, top - 0.42, 0.2), GLASS, car, false, "glass", 0.08)
			wheels(w, car, 0.85, -1.4, 1.4, r, opts)
			lights(w, car, -2.15, 2.15, by - 0.3, 0.62)
			bumpers(w, car, 1.95, 2.15, wy + 0.05)
			if shape == "ambulance":
				w.rbox(Vector3(1.98, 0.16, 3.9), Vector3(0, by - 0.05, 0.1), Color("#e63946"), car, false, "paint", 0.08)
				light_bar(w, car, top, -1.2)
			car.set_meta("len", 4.3)
		"pickup":
			var roof = base_car(w, car, color, 4.3, 1.95, 0.74, 0.44, 1.75, 0.62, -0.8, opts, 1.35, 0.15)
			var bed_top = roof - 0.62 - 0.05
			w.rbox(Vector3(1.7, 0.05, 1.85), Vector3(0, bed_top - 0.01, 1.15), TRIM, car, false, "matte", 0.08)
			for sx in [-1.0, 1.0]:
				w.rbox(Vector3(0.1, 0.32, 1.95), Vector3(sx * 0.925, bed_top + 0.14, 1.12), color, car, false, "paint", 0.12)
			w.rbox(Vector3(1.95, 0.32, 0.1), Vector3(0, bed_top + 0.14, 2.1), color, car, false, "paint", 0.12)
		"bus":
			var r = 0.5
			var wy = r - 0.45
			var by = wy - 0.05 + 1.15
			w.rbox(Vector3(2.4, 2.3, 9.0), Vector3(0, by, 0), color, car, false, "paint", 0.1)
			var top = by + 1.15
			for sx in [-1.0, 1.0]:
				w.rbox(Vector3(0.03, 0.75, 7.4), Vector3(sx * 1.2, top - 0.7, 0.5), GLASS, car, false, "glass", 0.06)
			w.rbox(Vector3(2.1, 1.0, 0.06), Vector3(0, top - 0.8, -4.5), GLASS, car, false, "glass", 0.06)
			w.rbox(Vector3(2.42, 0.12, 9.02), Vector3(0, by - 0.45, 0), Color("#f4f4f0"), car, false, "paint", 0.08)
			wheels(w, car, 1.05, -3.0, 3.0, r, opts)
			lights(w, car, -4.5, 4.5, by - 0.7, 0.8)
			car.set_meta("len", 9.0)
		"truck", "firetruck":
			var r = 0.48
			var wy = r - 0.45
			var cab_y = wy - 0.05 + 0.85
			w.rbox(Vector3(2.2, 1.7, 1.9), Vector3(0, cab_y, -2.6), color, car, false, "paint", 0.12)
			w.rbox(Vector3(1.95, 0.6, 0.06), Vector3(0, cab_y + 0.35, -3.56), GLASS, car, false, "glass", 0.06)
			for sx in [-1.0, 1.0]:
				w.rbox(Vector3(0.03, 0.55, 0.9), Vector3(sx * 1.1, cab_y + 0.35, -2.9), GLASS, car, false, "glass", 0.06)
			w.rbox(Vector3(1.6, 0.35, 0.05), Vector3(0, cab_y - 0.4, -3.56), TRIM, car, false, "matte", 0.08)
			var box_col = color if shape == "firetruck" else Color("#eceff1")
			w.rbox(Vector3(2.35, 2.2, 4.6), Vector3(0, wy - 0.05 + 1.15, 0.9), box_col, car, false, "paint", 0.08)
			wheels(w, car, 0.95, -2.6, 2.0, r, opts)
			lights(w, car, -3.55, 3.2, cab_y - 0.4, 0.75)
			if shape == "firetruck":
				for sx in [-0.5, 0.5]:
					w.rbox(Vector3(0.1, 0.1, 4.4), Vector3(sx, wy + 2.35, 0.9), CHROME, car, false, "chrome", 0.3)
				light_bar(w, car, cab_y + 0.85, -2.6)
			car.set_meta("len", 7.2)
		"sport", "rocket":
			var roof = base_car(w, car, color, 4.1, 1.96, 0.46, 0.35, 2.1, 0.42, 0.3, opts, 0.9, 0.25)
			spoiler(w, car, 1.85, 1.8, roof - 0.25)
			for sx in [-1.0, 1.0]:
				w.rbox(Vector3(0.04, 0.15, 0.5), Vector3(sx * 0.99, 0.0, 0.7), TRIM, car, false, "matte", 0.15)
			if shape == "rocket":
				w.rbox(Vector3(0.1, 0.5, 0.9), Vector3(0, roof + 0.1, 1.2), color, car, false, "paint", 0.15)
				exhaust(w, car, 2.1, 0.05)
		"super", "ghost":
			var roof = base_car(w, car, color, 4.4, 2.06, 0.4, 0.36, 2.2, 0.38, 0.1, opts, 0.85, 0.2)
			for sx in [-1.0, 1.0]:
				w.rbox(Vector3(0.04, 0.2, 0.9), Vector3(sx * 1.035, -0.02, 0.6), TRIM, car, false, "matte", 0.15)
			w.rbox(Vector3(0.6, 0.04, 1.0), Vector3(0, roof - 0.42, -1.4), TRIM, car, false, "matte", 0.15)
			spoiler(w, car, 2.0, 2.0, roof - 0.15)
			if shape == "ghost":
				var neon = Color("#00f5d4")
				for sx in [-1.0, 1.0]:
					w.rbox(Vector3(0.03, 0.05, 3.6), Vector3(sx * 1.04, 0.1, 0), neon, car, true, "matte", 0.15)
				w.rbox(Vector3(1.8, 0.03, 3.8), Vector3(0, -0.4, 0), neon, car, true, "matte", 0.15)
		"retro":
			# классика 70-х: длинная, плоская крыша, хромированные бамперы
			var roof = base_car(w, car, color, 4.2, 1.82, 0.6, 0.36, 2.0, 0.55, 0.05, opts, 1.55, 0.05)
			for z in [-2.12, 2.12]:
				w.rbox(Vector3(1.9, 0.12, 0.1), Vector3(0, -0.05, z), CHROME, car, false, "chrome", 0.2)
			for sx in [-1.0, 1.0]:
				w.rbox(Vector3(0.03, 0.05, 3.9), Vector3(sx * 0.915, 0.25, 0), CHROME, car, false, "chrome", 0.2)
			w.rbox(Vector3(1.4, 0.04, 1.3), Vector3(0, roof + 0.0, 0.05), Color("#f1e3c8"), car, false, "paint", 0.15)
	if opts.get("exhaust", false) and shape not in ["rocket", "bus", "truck", "firetruck", "van", "ambulance"]:
		exhaust(w, car, car.get_meta("len", 4.0) / 2.0 + 0.05, -0.1)
	return car


# Легковая машина: угловатый кузов + кабина-трапеция (наклонные стёкла) + крыша.
# cab_top — длина верха кабины, cab_toz — сдвиг верха назад. Возвращает высоту крыши.
static func base_car(w, car, color: Color, L: float, W: float, H: float, r: float, cab_len: float, cab_h: float, cab_z: float, opts: Dictionary, cab_top := -1.0, cab_toz := -99.0) -> float:
	var wy = r - 0.45              # центр колеса (дорога на высоте -0.45)
	var y0 = wy - 0.08             # низ кузова
	var top = y0 + H
	w.rbox(Vector3(W, H, L), Vector3(0, y0 + H / 2.0, 0), color, car, false, "paint", 0.16)
	var roof = top
	if cab_len > 0:
		if cab_top < 0:
			cab_top = cab_len * 0.6
		if cab_toz < -50:
			cab_toz = cab_len * 0.08
		var cw = W * 0.9
		w.add_mesh(taper(cw, cab_len, cw * 0.86, cab_top, cab_toz, cab_h), Vector3(0, top - 0.02, cab_z), GLASS, car, false, "glass")
		w.add_mesh(taper(cw * 0.88, cab_top + 0.04, cw * 0.82, cab_top - 0.12, 0.0, 0.07), Vector3(0, top - 0.02 + cab_h, cab_z + cab_toz), color, car, false, "paint")
		roof = top - 0.02 + cab_h + 0.07
		for sx in [-1.0, 1.0]:
			# зеркала и ручки дверей
			w.rbox(Vector3(0.16, 0.1, 0.12), Vector3(sx * (W / 2.0 + 0.05), top + 0.1, cab_z - cab_len / 2.0 + 0.25), color, car, false, "paint", 0.3)
			w.rbox(Vector3(0.03, 0.04, 0.16), Vector3(sx * (W / 2.0 + 0.01), top - 0.12, cab_z - 0.1), Color("#c9ced6"), car, false, "chrome", 0.3)
	for sx in [-1.0, 1.0]:
		# пороги
		w.rbox(Vector3(0.05, 0.08, L * 0.6), Vector3(sx * (W / 2.0 + 0.005), y0 + 0.06, 0), TRIM, car, false, "matte", 0.2)
	var ly = top - minf(0.16, H * 0.3)
	# решётка радиатора
	w.rbox(Vector3(W * 0.36, 0.11, 0.05), Vector3(0, ly, -L / 2.0), Color("#1b1c20"), car, false, "matte", 0.15)
	wheels(w, car, W / 2.0 - 0.15, -(L / 2.0 - r - 0.32), L / 2.0 - r - 0.32, r, opts, W / 2.0)
	lights(w, car, -L / 2.0, L / 2.0, ly, W * 0.33)
	bumpers(w, car, W + 0.04, L / 2.0 - 0.06, y0 + minf(0.2, H * 0.32) / 2.0)
	car.set_meta("len", L)
	return roof


# «трапеция»: низ bw x bl, верх tw x tl (сдвинут на toz), высота h
static func taper(bw: float, bl: float, tw: float, tl: float, toz: float, h: float) -> ArrayMesh:
	var key = "%s_%s_%s_%s_%s_%s" % [bw, bl, tw, tl, toz, h]
	if mesh_cache.has(key):
		return mesh_cache[key]
	var b = [Vector3(-bw / 2, 0, -bl / 2), Vector3(bw / 2, 0, -bl / 2), Vector3(bw / 2, 0, bl / 2), Vector3(-bw / 2, 0, bl / 2)]
	var t = [Vector3(-tw / 2, h, toz - tl / 2), Vector3(tw / 2, h, toz - tl / 2), Vector3(tw / 2, h, toz + tl / 2), Vector3(-tw / 2, h, toz + tl / 2)]
	var quads = [[b[0], b[1], b[2], b[3]], [t[0], t[1], t[2], t[3]], [b[0], b[1], t[1], t[0]], [b[1], b[2], t[2], t[1]], [b[2], b[3], t[3], t[2]], [b[3], b[0], t[0], t[3]]]
	var center = Vector3(0, h / 2, toz / 2)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			var n = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			var mid = (tri[0] + tri[1] + tri[2]) / 3.0
			if n.dot(mid - center) < 0:
				n = -n
			for order in [[0, 1, 2], [0, 2, 1]]:
				for k in order:
					st.set_normal(n)
					st.add_vertex(tri[k])
	var m = st.commit()
	mesh_cache[key] = m
	return m


static func bumpers(w, car, width: float, z: float, y: float):
	for sz in [-z, z]:
		w.rbox(Vector3(width, 0.2, 0.22), Vector3(0, y, sz), TRIM, car, false, "matte", 0.25)
		# номер
		w.rbox(Vector3(0.42, 0.13, 0.03), Vector3(0, y, sz + signf(sz) * 0.12), Color("#f4f4f0"), car, false, "matte", 0.15)


static func spoiler(w, car, width: float, z: float, y: float):
	for sx in [-width * 0.3, width * 0.3]:
		w.rbox(Vector3(0.08, 0.3, 0.12), Vector3(sx, y - 0.1, z), TRIM, car, false, "matte", 0.2)
	w.rbox(Vector3(width, 0.06, 0.4), Vector3(0, y + 0.06, z + 0.05), TRIM, car, false, "matte", 0.2)


static func light_bar(w, car, roof_y: float, z: float):
	# мигалка: красный и синий огоньки, которые мигают по очереди
	w.rbox(Vector3(0.9, 0.08, 0.3), Vector3(0, roof_y + 0.04, z), DARK, car, false, "matte", 0.2)
	var red = w.rbox(Vector3(0.38, 0.14, 0.26), Vector3(-0.22, roof_y + 0.13, z), Color("#ff2d55"), car, true, "matte", 0.25)
	var blue = w.rbox(Vector3(0.38, 0.14, 0.26), Vector3(0.22, roof_y + 0.13, z), Color("#2d7dff"), car, true, "matte", 0.25)
	w.register_flasher(red, 0)
	w.register_flasher(blue, 1)


static func exhaust(w, car, z: float, y: float):
	for sx in [-0.4, 0.4]:
		var f = w.add_mesh(w.sphere(0.13), Vector3(sx, y, z), Color("#ff8c1a"), car, true)
		f.scale = Vector3(1, 1, 1.6)


# колёса: плоская шина, диск, колпачок и тёмная арка на боку кузова (well_x — где бок)
static func wheels(w, car, x: float, zf: float, zr: float, r: float, opts: Dictionary, well_x := -1.0):
	var rim: Color = opts.get("rim", CHROME)
	if well_x < 0:
		well_x = x + 0.12
	for sx in [-1.0, 1.0]:
		for z in [zf, zr]:
			var y = r - 0.45
			var well = w.add_mesh(w.cylinder(r * 1.14, r * 1.14, 0.04), Vector3(sx * well_x, y + 0.02, z), Color("#15161a"), car)
			well.rotation_degrees.z = 90
			var tire = w.add_mesh(w.cylinder(r, r, 0.3), Vector3(sx * x, y, z), Color("#232328"), car, false, "rubber")
			tire.rotation_degrees.z = 90
			var disc = w.add_mesh(w.cylinder(r * 0.62, r * 0.62, 0.32), Vector3(sx * x, y, z), rim, car, false, "chrome")
			disc.rotation_degrees.z = 90
			var cap = w.add_mesh(w.cylinder(r * 0.18, r * 0.18, 0.34), Vector3(sx * x, y, z), Color("#3a3d44"), car)
			cap.rotation_degrees.z = 90


static func lights(w, car, zf: float, zr: float, y: float, half: float):
	for sx in [-half, half]:
		w.rbox(Vector3(0.42, 0.12, 0.06), Vector3(sx, y, zf), Color("#fff4cf"), car, true, "matte", 0.15)
		w.rbox(Vector3(0.4, 0.11, 0.06), Vector3(sx, y, zr), Color("#ff2a3a"), car, true, "matte", 0.15)
	w.add_car_light(car, zf, y)
