extends RefCounted
# Биомы (местности), декор вдоль дороги, дальний фон и придорожные здания.
# w — главный скрипт игры (у него есть add_mesh / rbox / sphere / capsule / cylinder).

const ORDER = ["meadow", "forest", "desert", "jungle", "mountains", "city"]

# chance — как часто выпадает биом при смене местности
const BIOMES = {
	"meadow":    {"ground": "#7cc96b", "shoulder": "#e8d8a8", "chance": 30},
	"forest":    {"ground": "#4f9b4d", "shoulder": "#b39566", "chance": 20},
	"desert":    {"ground": "#ecc98a", "shoulder": "#dcb377", "chance": 15},
	"jungle":    {"ground": "#3dac58", "shoulder": "#8d6b46", "chance": 12},
	"mountains": {"ground": "#94b27c", "shoulder": "#bdb6a8", "chance": 13},
	"city":      {"ground": "#aab1bb", "shoulder": "#cfd2d8", "chance": 10},
}

const LANDMARKS = ["gas", "gas", "cafe", "house", "billboard"]


static func pick(rng: RandomNumberGenerator, current: String) -> String:
	var total = 0
	for b in ORDER:
		if b != current:
			total += BIOMES[b]["chance"]
	var r = rng.randi_range(1, total)
	for b in ORDER:
		if b == current:
			continue
		r -= BIOMES[b]["chance"]
		if r <= 0:
			return b
	return "meadow"


# ---------- декор вдоль дороги ----------
static func deco(w, biome: String, rng: RandomNumberGenerator) -> Node3D:
	var n: Node3D
	var r = rng.randf()
	var near = false   # мелкие объекты ставим ближе к дороге
	match biome:
		"meadow":
			if r < 0.35:
				n = tree_round(w, rng, Color("#66bb6a"))
			elif r < 0.6:
				n = tree_pine(w, rng, Color("#4caf50"), 1.0)
			else:
				n = bush(w, rng, Color("#5fb04f"), true)
				near = true
		"forest":
			if r < 0.65:
				n = tree_pine(w, rng, Color("#2e7d32"), rng.randf_range(1.2, 1.8))
			elif r < 0.8:
				n = tree_round(w, rng, Color("#388e3c"))
			else:
				n = mushroom(w, rng)
				near = true
		"desert":
			if r < 0.45:
				n = cactus(w, rng)
			elif r < 0.8:
				n = rock(w, rng, Color("#d9965b"))
			else:
				n = bush(w, rng, Color("#b5a46a"), false)
				near = true
		"jungle":
			if r < 0.5:
				n = palm(w, rng)
			elif r < 0.8:
				n = fern(w, rng)
				near = true
			else:
				n = bush(w, rng, Color("#2f9e44"), true)
				near = true
		"mountains":
			if r < 0.45:
				n = tree_pine(w, rng, Color("#2f7d4f"), rng.randf_range(1.0, 1.5))
			elif r < 0.9:
				n = rock(w, rng, Color("#9aa1ab"))
			else:
				n = bush(w, rng, Color("#6a9f58"), false)
				near = true
		"city":
			if r < 0.55:
				n = building(w, rng)
				n.set_meta("min_x", 10.0)
				n.set_meta("max_x", 22.0)
				return n
			elif r < 0.8:
				n = tree_round(w, rng, Color("#66bb6a"))
				n.scale *= 0.6
				near = true
			else:
				n = bench(w)
				near = true
	n.set_meta("min_x", 6.2 if near else 7.5)
	n.set_meta("max_x", 11.0 if near else 28.0)
	return n


static func tree_round(w, rng, green: Color) -> Node3D:
	var t = Node3D.new()
	w.add_mesh(w.capsule(0.18, 2.0), Vector3(0, 0.9, 0), Color("#8d5a3b"), t)
	var g = green.darkened(rng.randf() * 0.12)
	w.add_mesh(w.sphere(1.4), Vector3(0, 2.7, 0), g, t)
	w.add_mesh(w.sphere(0.9), Vector3(0.7, 2.4, 0.4), g.lightened(0.08), t)
	w.add_mesh(w.sphere(0.8), Vector3(-0.6, 2.5, -0.3), g.lightened(0.04), t)
	t.scale = Vector3.ONE * rng.randf_range(0.8, 1.4)
	return t


static func tree_pine(w, rng, green: Color, tall: float) -> Node3D:
	var t = Node3D.new()
	w.add_mesh(w.capsule(0.16, 1.6), Vector3(0, 0.6, 0), Color("#7a4e32"), t)
	var g = green.darkened(rng.randf() * 0.1)
	for j in 3:
		var tier = w.add_mesh(w.sphere(1.25 - j * 0.3), Vector3(0, 1.7 + j * 0.85, 0), g.lightened(j * 0.05), t)
		tier.scale = Vector3(1, 0.75, 1)
	t.scale = Vector3(1, tall, 1) * rng.randf_range(0.85, 1.3)
	return t


static func bush(w, rng, green: Color, flowers: bool) -> Node3D:
	var b = Node3D.new()
	var g = green.darkened(rng.randf() * 0.15)
	w.add_mesh(w.sphere(0.6), Vector3(0, 0.15, 0), g, b)
	w.add_mesh(w.sphere(0.45), Vector3(0.55, 0.05, 0.1), g.lightened(0.06), b)
	w.add_mesh(w.sphere(0.4), Vector3(-0.5, 0.03, -0.1), g.lightened(0.1), b)
	if flowers and rng.randf() < 0.5:
		var fc = [Color("#ff8fab"), Color("#ffd43b"), Color("#ffffff"), Color("#b197fc")][rng.randi() % 4]
		w.add_mesh(w.sphere(0.12), Vector3(0.2, 0.7, 0.3), fc, b)
		w.add_mesh(w.sphere(0.1), Vector3(-0.3, 0.55, 0.2), fc, b)
	b.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
	return b


static func mushroom(w, rng) -> Node3D:
	var m = Node3D.new()
	w.add_mesh(w.capsule(0.15, 0.7), Vector3(0, 0.3, 0), Color("#f8f1e5"), m)
	var cap = w.add_mesh(w.sphere(0.45), Vector3(0, 0.7, 0), Color("#e5484d"), m)
	cap.scale = Vector3(1, 0.6, 1)
	for p in [Vector3(0.2, 0.9, 0.2), Vector3(-0.22, 0.85, 0.05), Vector3(0.05, 0.92, -0.25)]:
		w.add_mesh(w.sphere(0.07), p, Color.WHITE, m)
	m.scale = Vector3.ONE * rng.randf_range(0.8, 1.6)
	return m


static func cactus(w, rng) -> Node3D:
	var c = Node3D.new()
	var g = Color("#4caf50").darkened(rng.randf() * 0.15)
	var h = rng.randf_range(2.0, 3.4)
	w.add_mesh(w.capsule(0.35, h), Vector3(0, h / 2.0, 0), g, c)
	for side in [-1, 1]:
		if rng.randf() < 0.75:
			var y = rng.randf_range(0.9, h - 0.6)
			var arm = w.add_mesh(w.capsule(0.22, 0.8), Vector3(side * 0.55, y, 0), g, c)
			arm.rotation_degrees.z = 90
			w.add_mesh(w.capsule(0.22, 1.0), Vector3(side * 0.85, y + 0.45, 0), g, c)
	if rng.randf() < 0.4:
		w.add_mesh(w.sphere(0.14), Vector3(0, h + 0.05, 0), Color("#ff8fab"), c)
	return c


static func rock(w, rng, col: Color) -> Node3D:
	var r = Node3D.new()
	var s = rng.randf_range(0.8, 2.0)
	w.rbox(Vector3(1.6, 1.1, 1.3) * s, Vector3(0, 0.45 * s, 0), col.darkened(rng.randf() * 0.15), r, false, "matte", 0.6)
	w.rbox(Vector3(0.9, 0.7, 0.8) * s, Vector3(0.8 * s, 0.25 * s, 0.3 * s), col.lightened(0.05), r, false, "matte", 0.6)
	r.rotation.y = rng.randf() * TAU
	return r


static func palm(w, rng) -> Node3D:
	var p = Node3D.new()
	var lean = rng.randf_range(-0.25, 0.25)
	var top = Vector3.ZERO
	for i in 5:   # изогнутый ствол из сегментов
		var seg = w.add_mesh(w.capsule(0.2 - i * 0.015, 1.0), Vector3(lean * i * i * 0.12, 0.45 + i * 0.85, 0), Color("#a47148"), p)
		seg.rotation.z = -lean * i * 0.25
		top = seg.position
	for k in 6:   # листья
		var a = k * TAU / 6.0 + rng.randf() * 0.3
		var leaf = w.add_mesh(w.sphere(0.9), top + Vector3(cos(a) * 1.0, 0.45, sin(a) * 1.0), Color("#2f9e44"), p)
		leaf.scale = Vector3(1.4, 0.18, 0.5)
		leaf.rotation.y = -a
		leaf.rotation.z = -0.3
	w.add_mesh(w.sphere(0.2), top + Vector3(0.15, 0.3, 0), Color("#8d5a3b"), p)
	p.scale = Vector3.ONE * rng.randf_range(0.9, 1.3)
	return p


static func fern(w, rng) -> Node3D:
	var f = Node3D.new()
	for k in 7:
		var a = k * TAU / 7.0
		var leaf = w.add_mesh(w.sphere(0.6), Vector3(cos(a) * 0.5, 0.35, sin(a) * 0.5), Color("#37b24d").darkened(rng.randf() * 0.2), f)
		leaf.scale = Vector3(1.3, 0.2, 0.45)
		leaf.rotation.y = -a
		leaf.rotation.z = 0.5
	f.scale = Vector3.ONE * rng.randf_range(0.9, 1.6)
	return f


static func building(w, rng) -> Node3D:
	var b = Node3D.new()
	var cols = ["#f4a261", "#e9c46a", "#8ecae6", "#b5838d", "#a8dadc", "#ffb4a2", "#cdb4db", "#90be6d"]
	var col = Color(cols[rng.randi() % cols.size()])
	var h = rng.randf_range(6.0, 18.0)
	var wd = rng.randf_range(5.0, 8.0)
	var dp = rng.randf_range(5.0, 7.0)
	w.rbox(Vector3(wd, h, dp), Vector3(0, h / 2.0, 0), col, b, false, "matte", 0.12)
	var y = 1.6
	while y < h - 1.0:   # ряды окон
		w.rbox(Vector3(wd + 0.06, 0.8, dp * 0.86), Vector3(0, y, 0), Color("#3d5a80"), b, false, "glass", 0.2)
		y += 2.2
	w.rbox(Vector3(wd * 0.5, 0.8, dp * 0.5), Vector3(0, h + 0.3, 0), col.darkened(0.15), b, false, "matte", 0.3)
	return b


static func bench(w) -> Node3D:
	var b = Node3D.new()
	w.rbox(Vector3(0.6, 0.12, 1.8), Vector3(0, 0.45, 0), Color("#a47148"), b, false, "matte", 0.4)
	w.rbox(Vector3(0.12, 0.6, 1.8), Vector3(0.28, 0.75, 0), Color("#a47148"), b, false, "matte", 0.4)
	for z in [-0.7, 0.7]:
		w.add_mesh(w.capsule(0.06, 0.5), Vector3(0, 0.2, z), Color("#495057"), b)
	return b


# ---------- дальний фон (холмы, горы, барханы, небоскрёбы) ----------
static func backdrop(w, biome: String, rng: RandomNumberGenerator) -> Node3D:
	var root = Node3D.new()
	var ground = Color(BIOMES[biome]["ground"])
	match biome:
		"mountains":
			for i in 8:
				var h = rng.randf_range(40.0, 75.0)
				var r = rng.randf_range(25.0, 40.0)
				var x = rng.randf_range(-150, 150)
				var z = rng.randf_range(-270, -220)
				w.add_mesh(w.cylinder(0.0, r, h), Vector3(x, h / 2.0 - 4.0, z), Color("#8d939e").darkened(rng.randf() * 0.15), root)
				w.add_mesh(w.cylinder(0.0, r * 0.36, h * 0.34), Vector3(x, h - 3.7 - h * 0.16, z), Color("#f8f9fa"), root)
		"city":
			for i in 28:
				var h = rng.randf_range(15.0, 55.0)
				w.rbox(Vector3(rng.randf_range(8, 16), h, 10), Vector3(rng.randf_range(-160, 160), h / 2.0 - 2.0, rng.randf_range(-265, -215)), Color("#9aa7bd").darkened(rng.randf() * 0.2), root, false, "matte", 0.1)
		"desert":
			for i in 7:
				var dune = w.add_mesh(w.sphere(1.0), Vector3(rng.randf_range(-150, 150), -5, rng.randf_range(-265, -215)), Color("#e3b877"), root)
				dune.scale = Vector3(rng.randf_range(30, 50), rng.randf_range(10, 18), 22)
			for i in 4:
				var mh = rng.randf_range(12, 22)
				w.rbox(Vector3(rng.randf_range(20, 35), mh, 16), Vector3(rng.randf_range(-140, 140), mh / 2.0 - 2.0, rng.randf_range(-270, -240)), Color("#c97b4a"), root, false, "matte", 0.2)
		_:
			var hill_col = ground.darkened(0.12)
			var hh = 26.0 if biome == "jungle" else 20.0
			for i in 9:
				var hill = w.add_mesh(w.sphere(1.0), Vector3(rng.randf_range(-150, 150), -6, rng.randf_range(-270, -215)), hill_col.darkened(rng.randf() * 0.15), root)
				hill.scale = Vector3(rng.randf_range(28, 48), rng.randf_range(12, hh), 22)
	return root


# ---------- придорожные здания (заправка, кафе, дом, билборд) ----------
# Строятся так, что +X направлен от дороги.
static func landmark(w, kind: String, rng: RandomNumberGenerator) -> Node3D:
	var n = Node3D.new()
	match kind:
		"gas":
			w.rbox(Vector3(7.0, 0.5, 6.0), Vector3(3.5, 4.4, 0), Color("#f8f9fa"), n, false, "matte", 0.3)
			w.rbox(Vector3(7.05, 0.2, 6.05), Vector3(3.5, 4.2, 0), Color("#e5484d"), n, false, "matte", 0.3)
			for x in [1.0, 6.0]:
				for z in [-2.4, 2.4]:
					w.add_mesh(w.capsule(0.18, 4.2), Vector3(x, 2.0, z), Color("#dee2e6"), n)
			for z in [-1.2, 1.2]:
				w.rbox(Vector3(0.7, 1.5, 0.6), Vector3(3.5, 0.3, z), Color("#e5484d"), n, false, "paint", 0.4)
				w.rbox(Vector3(0.5, 0.4, 0.62), Vector3(3.5, 0.75, z), Color("#212529"), n, false, "glass", 0.4)
			w.rbox(Vector3(4.0, 3.0, 5.0), Vector3(10.0, 1.0, 0), Color("#fff3bf"), n, false, "matte", 0.2)
			w.rbox(Vector3(4.05, 0.5, 5.05), Vector3(10.0, 2.3, 0), Color("#e5484d"), n, false, "matte", 0.2)
			w.rbox(Vector3(0.1, 1.2, 3.0), Vector3(7.95, 0.6, 0), Color("#4dabf7"), n, false, "glass", 0.3)
			w.add_mesh(w.capsule(0.15, 7.0), Vector3(0.5, 3.0, -4.0), Color("#adb5bd"), n)
			w.rbox(Vector3(0.4, 1.8, 1.8), Vector3(0.5, 6.4, -4.0), Color("#ffd43b"), n, true, "matte", 0.4)
		"cafe":
			var col = Color(["#ffb4a2", "#a8dadc", "#cdb4db", "#ffe066"][rng.randi() % 4])
			w.rbox(Vector3(5.0, 3.4, 6.0), Vector3(5.0, 1.2, 0), col, n, false, "matte", 0.25)
			for i in 6:   # полосатый навес
				w.rbox(Vector3(1.4, 0.15, 1.0), Vector3(2.0, 2.5, -2.5 + i * 1.0), Color("#e5484d") if i % 2 == 0 else Color.WHITE, n, false, "matte", 0.3)
			w.rbox(Vector3(0.1, 1.4, 3.0), Vector3(2.45, 0.7, 0), Color("#4dabf7"), n, false, "glass", 0.3)
			var disc = w.add_mesh(w.cylinder(1.0, 1.0, 0.2), Vector3(5.0, 3.6, 0), Color("#ffd43b"), n, true)
			disc.rotation_degrees.z = 90
		"house":
			var col = Color(["#f8f9fa", "#ffe8cc", "#e3fafc", "#fff0f6"][rng.randi() % 4])
			w.rbox(Vector3(5.0, 3.0, 5.0), Vector3(6.0, 1.0, 0), col, n, false, "matte", 0.2)
			for side in [-1, 1]:
				var roof = w.rbox(Vector3(3.4, 0.35, 5.6), Vector3(6.0 + side * 1.2, 3.1, 0), Color("#c92a2a"), n, false, "matte", 0.3)
				roof.rotation_degrees.z = -side * 35
			w.rbox(Vector3(0.1, 1.6, 1.0), Vector3(3.45, 0.3, 0), Color("#8d5a3b"), n, false, "matte", 0.3)
			for z in [-1.6, 1.6]:
				w.rbox(Vector3(0.1, 0.9, 0.9), Vector3(3.45, 1.4, z), Color("#4dabf7"), n, false, "glass", 0.3)
			w.rbox(Vector3(0.6, 1.2, 0.6), Vector3(7.0, 3.8, 1.5), Color("#868e96"), n, false, "matte", 0.3)
		"billboard":
			for z in [-1.8, 1.8]:
				w.add_mesh(w.capsule(0.15, 5.0), Vector3(1.0, 2.0, z), Color("#868e96"), n)
			var col = Color(["#4dabf7", "#ff6b6b", "#51cf66", "#ffd43b", "#cc5de8"][rng.randi() % 5])
			var board = w.rbox(Vector3(0.3, 2.6, 6.0), Vector3(1.0, 4.5, 0), col, n, false, "paint", 0.2)
			board.rotation_degrees.y = 15
			w.rbox(Vector3(0.35, 0.6, 4.0), Vector3(0.9, 4.5, 0), Color.WHITE, n, false, "matte", 0.4)
	return n
