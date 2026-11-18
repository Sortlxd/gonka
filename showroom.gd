extends Node3D
# Витрина (только для тестов): варианты стиля машин по одной,
# чтобы выбрать, какой нравится. Открывается из админ-панели.

const Cars = preload("res://cars.gd")

var w
var active = false
var cars = []
var hint: Label
var groups = []
var idx = 0


func setup(main):
	w = main
	position = Vector3(8000, 0, 0)
	visible = false


func open():
	w.close_popup()
	if cars.is_empty():
		build()
	active = true
	visible = true
	w.ui_root.visible = false
	w.day_time = 0.45
	w.cam.fov = 60
	w.cam.position = position + Vector3(0, 3.4, 6.2)
	w.cam.rotation_degrees = Vector3(-24, 0, 0)
	hint = w.make_label("Нажми, чтобы закрыть витрину", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 12)
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -120
	hint.offset_bottom = -60
	hint.theme = w.ui_root.theme
	w.get_node("CanvasLayer").add_child(hint)
	idx = 0
	show_idx()


func show_idx():
	for i in groups.size():
		groups[i].visible = i == idx
	if hint:
		hint.text = "%d / %d · нажми — следующая" % [idx + 1, groups.size()]


func close():
	active = false
	visible = false
	w.ui_root.visible = true
	w.cam.rotation_degrees = Vector3(-26, 0, 0)
	if hint:
		hint.queue_free()
		hint = null


func _process(delta):
	if not active:
		return
	for c in cars:
		c.rotation.y += delta * 0.5


func _unhandled_input(event):
	if not active:
		return
	if event is InputEventMouseButton and event.pressed:
		idx += 1
		if idx >= groups.size():
			close()
		else:
			show_idx()


func build():
	var floor_mat = w.toon(Color("#9fb0c4"))
	var pm = PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var fl = MeshInstance3D.new()
	fl.mesh = pm
	fl.material_override = floor_mat
	fl.position = Vector3(0, -0.66, -10)
	add_child(fl)
	var shapes = Cars.ORDER + ["taxi", "police", "van", "ambulance", "truck", "firetruck", "bus"]
	var names = shapes
	var made = shapes.map(func(s): return Cars.build(w, s, Color(Cars.CARS[s].color if Cars.CARS.has(s) else Cars.FIXED_COLORS.get(s, "#4d9de0"))))
	for i in shapes.size():
		var p = Vector3(0, 0, -1.0)
		var g = Node3D.new()
		add_child(g)
		groups.append(g)
		w.add_mesh(w.cylinder(2.6, 2.6, 0.2), p + Vector3(0, -0.56, 0), Color.WHITE, g)
		var ring = w.add_mesh(w.torus(2.5, 2.7), p + Vector3(0, -0.45, 0), Color("#ffc43d"), g)
		ring.scale = Vector3(1, 0.3, 1)
		var car = made[i]
		car.position = p
		car.rotation.y = 0.6
		g.add_child(car)
		cars.append(car)
		var l = Label3D.new()
		l.text = names[i]
		if w.ui_font:
			l.font = w.ui_font
		l.font_size = 72
		l.outline_size = 18
		l.pixel_size = 0.012
		l.modulate = Color.WHITE
		l.outline_modulate = Color(0.1, 0.1, 0.15, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = p + Vector3(0, 2.3, 0)
		g.add_child(l)

var mesh_cache = {}


# «трапеция»: низ bw x bl, верх tw x tl (сдвинут на toz), высота h — для кабины
# с наклонным лобовым и задним стеклом
func taper(bw: float, bl: float, tw: float, tl: float, toz: float, h: float) -> ArrayMesh:
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
			# обе стороны с наружной нормалью — видимой останется правильная
			for order in [[0, 1, 2], [0, 2, 1]]:
				for k in order:
					st.set_normal(n)
					st.add_vertex(tri[k])
	var m = st.commit()
	mesh_cache[key] = m
	return m


func tmesh(car: Node3D, mesh: Mesh, pos: Vector3, col: Color, kind := "paint", glow := false) -> MeshInstance3D:
	return w.add_mesh(mesh, pos, col, car, glow, kind)


# колесо: шина-цилиндр, диск, тёмная арка на кузове
func wheel(car: Node3D, x: float, z: float, r: float, rim: Color, wide := 1.0):
	var y = r - 0.45
	var sx = signf(x)
	var well = w.add_mesh(w.cylinder(r * 1.14, r * 1.14, 0.04), Vector3(x + sx * 0.15, y + 0.02, z), Color("#15161a"), car)
	well.rotation_degrees.z = 90
	var tire = w.add_mesh(w.cylinder(r, r, 0.3 * wide), Vector3(x, y, z), Color("#232328"), car, false, "rubber")
	tire.rotation_degrees.z = 90
	var disc = w.add_mesh(w.cylinder(r * 0.62, r * 0.62, 0.3 * wide + 0.02), Vector3(x, y, z), rim, car, false, "chrome")
	disc.rotation_degrees.z = 90
	var cap = w.add_mesh(w.cylinder(r * 0.18, r * 0.18, 0.3 * wide + 0.04), Vector3(x, y, z), Color("#3a3d44"), car)
	cap.rotation_degrees.z = 90


# общий «реалистичный» кузов. p — словарь размеров
func real_car(col: Color, p: Dictionary) -> Node3D:
	var car = Node3D.new()
	var L = p.L
	var W = p.W
	var H = p.H
	var y0 = -0.45 + p.clr
	var top = y0 + H
	var rnd = p.get("rnd", 0.16)
	# нижняя часть кузова
	w.rbox(Vector3(W, H, L), Vector3(0, y0 + H / 2, 0), col, car, false, "paint", rnd)
	# кабина-стекло с наклонными стойками и крыша цвета кузова
	var cw = W * 0.9
	tmesh(car, taper(cw, p.cab_bl, cw * 0.86, p.cab_tl, p.cab_toz, p.cab_h), Vector3(0, top - 0.02, p.cab_z), Cars.GLASS, "glass")
	tmesh(car, taper(cw * 0.88, p.cab_tl + 0.04, cw * 0.82, p.cab_tl - 0.12, 0.0, 0.07), Vector3(0, top - 0.02 + p.cab_h, p.cab_z + p.cab_toz), col, "paint")
	# средняя стойка
	for sx in [-1.0, 1.0]:
		var bp = w.rbox(Vector3(0.05, p.cab_h * 0.9, 0.12), Vector3(sx * cw * 0.45, top + p.cab_h * 0.45, p.cab_z + p.cab_toz * 0.5 + p.get("bpil", 0.0)), col, car, false, "paint", 0.2)
		bp.rotation_degrees.z = -sx * 4.0
	# бамперы, решётка, фары
	var bh = minf(0.2, H * 0.32)
	for zs in [-1.0, 1.0]:
		w.rbox(Vector3(W + 0.04, bh, 0.22), Vector3(0, y0 + bh / 2, zs * (L / 2 - 0.06)), Color("#2b2d33"), car, false, "matte", 0.25)
		w.rbox(Vector3(0.42, 0.13, 0.03), Vector3(0, y0 + bh / 2, zs * (L / 2 + 0.06)), Color("#f4f4f0"), car, false, "matte", 0.15)
	var ly = top - minf(0.16, H * 0.3)
	for sx in [-1.0, 1.0]:
		w.rbox(Vector3(W * 0.24, 0.12, 0.06), Vector3(sx * W * 0.33, ly, -L / 2), Color("#fff4cf"), car, true, "matte", 0.15)
		w.rbox(Vector3(W * 0.22, 0.11, 0.06), Vector3(sx * W * 0.34, ly, L / 2), Color("#ff2a3a"), car, true, "matte", 0.15)
		# зеркала
		w.rbox(Vector3(0.16, 0.1, 0.12), Vector3(sx * (W / 2 + 0.05), top + 0.12, p.cab_z - p.cab_bl / 2 + 0.25), col, car, false, "paint", 0.3)
		# порог
		w.rbox(Vector3(0.05, 0.08, L * 0.62), Vector3(sx * (W / 2 + 0.005), y0 + 0.06, 0), Color("#2b2d33"), car, false, "matte", 0.2)
		# ручки дверей
		w.rbox(Vector3(0.03, 0.04, 0.16), Vector3(sx * (W / 2 + 0.01), top - 0.12, p.cab_z - 0.1), Color("#c9ced6"), car, false, "chrome", 0.3)
	w.rbox(Vector3(W * 0.36, 0.11, 0.05), Vector3(0, ly, -L / 2), Color("#1b1c20"), car, false, "matte", 0.15)
	# колёса
	for sx in [-1.0, 1.0]:
		for z in [p.zf, p.zr]:
			wheel(car, sx * (W / 2 - 0.15), z, p.r, p.get("rim", Color("#c9ced6")), p.get("wide", 1.0))
	return car


# A — хэтчбек: короткий, почти вертикальная пятая дверь
func concept_toy(col: Color) -> Node3D:
	var car = real_car(col, {"L": 3.8, "W": 1.76, "H": 0.62, "clr": 0.24, "r": 0.33, "zf": -1.22, "zr": 1.2,
		"cab_bl": 2.3, "cab_tl": 1.5, "cab_z": 0.4, "cab_toz": 0.36, "cab_h": 0.6})
	w.rbox(Vector3(1.3, 0.05, 0.12), Vector3(0, 0.82, 1.56), col, car, false, "paint", 0.3)
	return car


# B — седан: три объёма, длинный капот и багажник
func concept_bubble(col: Color) -> Node3D:
	return real_car(col, {"L": 4.5, "W": 1.82, "H": 0.6, "clr": 0.24, "r": 0.34, "zf": -1.42, "zr": 1.38,
		"cab_bl": 2.5, "cab_tl": 1.45, "cab_z": 0.15, "cab_toz": 0.08, "cab_h": 0.56, "rim": Color("#8f96a3")})


# C — пикап: высокий, короткая кабина и открытый кузов сзади
func concept_retro(col: Color) -> Node3D:
	var car = real_car(col, {"L": 4.9, "W": 1.95, "H": 0.78, "clr": 0.42, "r": 0.44, "zf": -1.5, "zr": 1.45, "rnd": 0.12,
		"cab_bl": 1.9, "cab_tl": 1.5, "cab_z": -0.55, "cab_toz": 0.18, "cab_h": 0.68, "rim": Color("#3a3d44"), "wide": 1.15})
	var top = -0.45 + 0.42 + 0.78
	# борта кузова-платформы
	var bed = Color("#2b2d33")
	w.rbox(Vector3(1.7, 0.05, 2.0), Vector3(0, top - 0.01, 1.32), bed, car, false, "matte", 0.1)
	for sx in [-1.0, 1.0]:
		w.rbox(Vector3(0.1, 0.32, 2.1), Vector3(sx * 0.925, top + 0.14, 1.3), col, car, false, "paint", 0.15)
	w.rbox(Vector3(1.95, 0.32, 0.1), Vector3(0, top + 0.14, 2.38), col, car, false, "paint", 0.15)
	# дуга безопасности
	w.rbox(Vector3(1.75, 0.08, 0.08), Vector3(0, top + 0.6, 0.32), Color("#2b2d33"), car, false, "matte", 0.3)
	for sx in [-1.0, 1.0]:
		w.rbox(Vector3(0.08, 0.6, 0.08), Vector3(sx * 0.86, top + 0.3, 0.32), Color("#2b2d33"), car, false, "matte", 0.3)
	return car


# D — спорткар: низкий, широкий, заваленное стекло, антикрыло
func concept_sport(col: Color) -> Node3D:
	var car = real_car(col, {"L": 4.4, "W": 1.98, "H": 0.46, "clr": 0.15, "r": 0.35, "zf": -1.38, "zr": 1.36, "rnd": 0.2,
		"cab_bl": 2.3, "cab_tl": 0.95, "cab_z": 0.3, "cab_toz": 0.25, "cab_h": 0.45, "rim": Color("#2a2a33"), "wide": 1.25})
	var top = -0.45 + 0.15 + 0.46
	# воздухозаборники и антикрыло
	for sx in [-1.0, 1.0]:
		w.rbox(Vector3(0.05, 0.16, 0.5), Vector3(sx * 1.0, top - 0.2, 0.75), Color("#1b1c20"), car, false, "matte", 0.2)
		w.rbox(Vector3(0.06, 0.24, 0.12), Vector3(sx * 0.75, top + 0.12, 1.98), Color("#1b1c20"), car, false, "matte", 0.2)
	w.rbox(Vector3(1.95, 0.06, 0.38), Vector3(0, top + 0.26, 2.0), Color("#1b1c20"), car, false, "matte", 0.2)
	w.rbox(Vector3(0.5, 0.04, 0.9), Vector3(0, top + 0.01, -1.4), Color("#1b1c20"), car, false, "matte", 0.2)
	return car
