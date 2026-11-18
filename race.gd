extends Node3D
# ================= ИВЕНТ «ГОНКА» =================
# Иногда после успешного обгона начинается гонка с боссом на гоночной трассе.
# Важны максимальная скорость и разгон. Чем реже босс, тем он сильнее и тем лучше награда.

const Cars = preload("res://cars.gd")

const RACE_CHANCE = 0.08       # шанс гонки после успешного обгона (8%)
const RACE_TIME = 12.0         # примерная длина гонки в секундах
const LANE = 1.9               # мы справа, босс слева
const TRACK_W = 9.0
const LOOP = 320.0
const NEAR = 15.0

# ---- редкость боссов: шанс, цвет, сила, награды ----
# power — во сколько раз босс сильнее «базовой» машины с вашими улучшениями
# reward_secs — сколько секунд дохода дают в KM за победу
const RARITY_ORDER = ["common", "rare", "epic", "legendary"]
const RARITY = {
	"common":    {"chance": 55, "color": "#adb5bd", "power": 1.0,  "reward_secs": 120,  "parts": 1, "nuts": 1, "box_chance": 0.15, "box": "parts"},
	"rare":      {"chance": 28, "color": "#4dabf7", "power": 1.35, "reward_secs": 240, "parts": 2, "nuts": 2, "box_chance": 0.30, "box": "tools"},
	"epic":      {"chance": 13, "color": "#b197fc", "power": 1.8,  "reward_secs": 480, "parts": 3, "nuts": 3, "box_chance": 0.50, "box": "carparts"},
	"legendary": {"chance": 4,  "color": "#ffd43b", "power": 2.5,  "reward_secs": 900, "parts": 5, "nuts": 5, "box_chance": 0.80, "box": "car"},
}

# ---- боссы (имена, внешний вид, номер) — позже пропишем подробнее ----
const BOSSES = {
	"rusty":   {"name": "Rusty Max",  "rarity": "common",    "style": "boss_muscle", "color": "#e76f51", "accent": "#f4f1de", "number": 7},
	"dusty":   {"name": "Dusty Joe",  "rarity": "common",    "style": "boss_gt",     "color": "#5c7aea", "accent": "#ffffff", "number": 12},
	"blaze":   {"name": "Blaze",      "rarity": "rare",      "style": "boss_gt",     "color": "#ff7f11", "accent": "#1b1b1b", "number": 21},
	"storm":   {"name": "Storm",      "rarity": "rare",      "style": "boss_muscle", "color": "#3a86ff", "accent": "#ffbe0b", "number": 33},
	"viper":   {"name": "Viper",      "rarity": "epic",      "style": "boss_hyper",  "color": "#06d6a0", "accent": "#111111", "number": 45},
	"nova":    {"name": "Nova",       "rarity": "epic",      "style": "boss_proto",  "color": "#ff006e", "accent": "#ffffff", "number": 58},
	"phantom": {"name": "Phantom",    "rarity": "legendary", "style": "boss_proto",  "color": "#1d1d2c", "accent": "#ffd166", "number": 1},
	"king":    {"name": "Road King",  "rarity": "legendary", "style": "boss_hyper",  "color": "#ffd166", "accent": "#8338ec", "number": 99},
}

var w   # главный скрипт игры
var active = false
var phase = ""
var timer: float = 0.0
var boss_id = ""
var p_pos: float = 0.0
var b_pos: float = 0.0
var p_v: float = 0.0
var b_v: float = 0.0
var p_max: float = 60.0
var p_acc: float = 12.0
var b_max: float = 60.0
var b_acc: float = 12.0
var length: float = 1000.0
var p_started = false
var false_start = false
var b_start_delay: float = 0.25
var go_time: float = 0.0
var winner = ""
var p_finish: float = -1.0
var b_finish: float = -1.0
var track_built = false
var scroll = []
var finish_arch: Node3D
var start_arch: Node3D
var p_car: Node3D
var b_car: Node3D
var track_mat: StandardMaterial3D
var start_lights = []

# интерфейс гонки
var hud: Control
var fade: ColorRect
var big_label: Label
var info_label: Label
var bar: Control
var p_mark: Control
var b_mark: Control
var start_btn: Button
var gap_label: Label


func setup(main):
	w = main
	position = Vector3(4000, 0, 0)   # трасса далеко от обычной дороги


func mileage_factor() -> float:
	# сила боссов растёт с общим пробегом (total_km), а не с улучшениями
	return 1.0 + 0.4 * log(1.0 + w.total_km / 5.0) / log(10.0)


func rarity_of(id: String) -> Dictionary:
	return RARITY[BOSSES[id]["rarity"]]


func pick_boss(force := "") -> String:
	var total = 0
	for r in RARITY_ORDER:
		total += RARITY[r]["chance"]
	var roll = w.rng.randi_range(1, total)
	var rar = "common"
	for r in RARITY_ORDER:
		roll -= RARITY[r]["chance"]
		if roll <= 0:
			rar = r
			break
	var list = []; rar = force if force != "" else rar
	for id in BOSSES:
		if BOSSES[id]["rarity"] == rar:
			list.append(id)
	return list[w.rng.randi() % list.size()]


# ================= ЗАПУСК =================
func begin(force_rarity := ""):
	if active:
		return
	active = true
	boss_id = pick_boss(force_rarity)
	var r = rarity_of(boss_id)
	# босс: «базовая» машина с вашими улучшениями, умноженная на силу редкости
	var k = w.rng.randf_range(0.95, 1.05)
	b_max = 60.0 * mileage_factor() * r["power"] * k   # сила босса растёт с общим пробегом
	b_acc = b_max * 0.4
	p_max = w.get_speed()
	p_acc = w.get_accel()
	length = maxf(p_max, b_max) * RACE_TIME
	p_pos = 0.0
	b_pos = 0.0
	p_v = 0.0
	b_v = 0.0
	p_started = false
	false_start = false
	b_start_delay = w.rng.randf_range(0.18, 0.35)
	winner = ""
	p_finish = -1.0
	b_finish = -1.0
	build_hud()
	# затемнение -> переносимся на трассу
	var tw = create_tween()
	bar.get_parent().get_parent().visible = false; tw.tween_property(fade, "color:a", 1.0, 0.45)
	tw.tween_callback(enter_track)
	tw.tween_property(fade, "color:a", 0.0, 0.45)
	tw.tween_callback(start_countdown)


func enter_track():
	if not track_built:
		build_track()
	visible = true
	for o in scroll:
		o.position.z = o.get_meta("base_z")
	start_arch.position.z = -2.0
	for l in start_lights:
		l.visible = false
		l.material_override = w.make_mat(Color("#ff3b3b"), true)
	finish_arch.position.z = -1000.0
	if p_car:
		p_car.queue_free()
	if b_car:
		b_car.queue_free()
	p_car = Cars.build(w, w.selected_car, Color(w.car_color()), w.car_opts())
	p_car.position = Vector3(LANE, 0, 0)
	add_child(p_car)
	var b = BOSSES[boss_id]
	b_car = build_boss(b["style"], Color(b["color"]), {"accent": Color(b["accent"]), "number": b["number"]})
	b_car.position = Vector3(-LANE, 0, 0)
	add_child(b_car)
	# прячем обычный интерфейс дороги
	w.bottom_panel.visible = false
	w.overtake_btn.visible = false; w.overtake_glow.visible = false
	w.lb_btn.visible = false
	w.settings_btn.visible = false; w.shop_btn.visible = false; w.admin_btn.visible = false; w.km_label.get_parent().get_parent().visible = false; w.weather_label.get_parent().get_parent().visible = false
	w.cam.fov = 64; bar.get_parent().get_parent().visible = true
	update_camera(1.0)
	var rar_name = w.t("rarity_" + b["rarity"])
	info_label.text = w.t("race_vs") + " " + b["name"] + "  •  " + rar_name
	info_label.add_theme_color_override("font_color", Color(rarity_of(boss_id)["color"]))
	w.show_banner(w.t("race_track"))
	w.sound.play("click", -6.0)


func start_countdown():
	phase = "countdown"
	timer = 0.0
	start_btn.visible = true
	start_btn.disabled = false


# ================= КАЖДЫЙ КАДР =================
func step(delta):
	if not visible:
		return
	match phase:
		"countdown":
			timer += delta
			var n = 3 - int(timer)
			var lit = clampi(int(timer), 0, 3)
			for i in start_lights.size():
				start_lights[i].visible = i < lit
			if timer < 3.0:
				set_big(str(n), Color.WHITE)
			else:
				phase = "run"
				go_time = 0.0
				set_big(w.t("race_go"), Color("#3ddc97"))
				w.sound.chime([12, 19, 24], -6.0)
				for l in start_lights:
					l.visible = true
					l.material_override = w.make_mat(Color("#3ddc97"), true)
		"run", "finish":
			go_time += delta
			if phase == "run" and go_time > 1.0 and big_label.modulate.a > 0.0:
				big_label.modulate.a = move_toward(big_label.modulate.a, 0.0, delta * 2.0)
			if not p_started and (go_time > 1.2 or (false_start and go_time > 0.6)):
				launch(99.0)   # не нажал (или фальстарт) — машина стартует сама, но поздно
			if p_started:
				p_v = move_toward(p_v, p_max, p_acc * delta)
			if go_time > b_start_delay:
				b_v = move_toward(b_v, b_max, b_acc * delta)
			if phase == "finish":
				p_v = move_toward(p_v, 0.0, p_max * 0.5 * delta)
				b_v = move_toward(b_v, 0.0, b_max * 0.5 * delta)
			p_pos += p_v * delta
			b_pos += b_v * delta
			if p_finish < 0 and p_pos >= length:
				p_finish = go_time
			if b_finish < 0 and b_pos >= length:
				b_finish = go_time
			if phase == "run" and (p_finish >= 0 or b_finish >= 0):
				winner = "player" if p_finish >= 0 and (b_finish < 0 or p_finish <= b_finish) else "boss"
				phase = "finish"
				timer = 0.0
				if winner == "player":
					set_big(w.t("race_win"), Color("#ffd43b"))
					w.sound.chime([0, 4, 7, 12, 16, 19], -4.0)
				else:
					set_big(w.t("race_lose"), Color("#ff6b6b"))
					w.sound.play("fail", -6.0)
			if phase == "finish":
				timer += delta
				if timer > 2.0 and timer - delta <= 2.0:
					show_results()
			move_world(delta)
	update_hud()
	update_camera(delta)


func launch(reaction: float):
	p_started = true
	start_btn.visible = false
	if reaction <= 0.3:
		p_v = p_max * 0.25   # идеальный старт — сразу набираем скорость
		w.show_toast(w.t("perfect_start"))
		w.sound.chime([7, 12, 16], -6.0)


func _on_start_pressed():
	if phase == "countdown":
		# фальстарт: штраф — машина стартует позже
		start_btn.disabled = true
		false_start = true
		w.show_toast(w.t("false_start"))
		w.sound.play("fail", -8.0)
		return
	if phase == "run" and not p_started:
		launch(go_time)


func move_world(delta):
	var dz = p_v * w.VIS * delta
	for o in scroll:
		o.position.z += dz
		if o.position.z > NEAR:
			o.position.z -= LOOP
	track_mat.uv1_offset.y = fposmod(track_mat.uv1_offset.y - dz / 8.0, 1.0)
	start_arch.position.z += dz
	finish_arch.position.z = -(length - p_pos) * w.VIS
	var bz = -(b_pos - p_pos) * w.VIS
	b_car.position.z = bz; b_car.visible = bz > -350.0 and bz < 30.0   # босс может уехать далеко вперёд или отстать
	w.sound.set_engine(0.8 + 0.9 * clampf(p_v / maxf(p_max, 1.0), 0.0, 1.0), -12.0)


func update_camera(delta):
	var off = Vector3(0.0, 5.6, 10.5)
	var target = position + Vector3(0.4, 0, 0) + off
	w.cam.position = w.cam.position.lerp(target, clampf(delta * 4.0, 0.0, 1.0)) if delta < 1.0 else target
	w.cam.rotation_degrees = Vector3(-24, 0, 0)
	var sp = clampf(p_v / maxf(p_max, 1.0), 0.0, 1.0)
	w.cam.fov = lerpf(w.cam.fov, 62.0 + sp * 14.0, clampf(delta * 2.0, 0.0, 1.0))


# ================= ИТОГИ =================
func show_results():
	var r = rarity_of(boss_id)
	var b = BOSSES[boss_id]
	var lines = []
	var win = winner == "player"
	if win:
		w.add_km_reward(w.income_per_sec() * r["reward_secs"], lines)
		w.add_parts(r["parts"], "", lines)
		pass   # гайки теперь только из ящиков и за донат
		if w.rng.randf() < r["box_chance"]:
			w.chests[r["box"]] += 1
			lines.append(w.t("chest_got") + w.t("chest_" + r["box"]))
	else:
		w.add_km_reward(w.income_per_sec() * r["reward_secs"] * 0.1, lines)
	w.save_game()
	var v = w.open_popup()
	var ic = w.icon_circle("trophy" if win else "flame", Color(r["color"]), 120)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(w.make_label(w.t("race_win") if win else w.t("race_lose"), 34, w.ACCENT if win else Color("#ff6b6b")))
	var who = w.make_label(b["name"] + "  •  " + w.t("rarity_" + b["rarity"]), 20, Color(r["color"]))
	v.add_child(who)
	var times = w.t("race_you") + ": " + fmt_time(p_finish) + "     " + b["name"] + ": " + fmt_time(b_finish)
	v.add_child(w.make_label(times, 17, w.UI_TEXT2))
	v.add_child(w.make_label(w.t("race_reward"), 20, w.UI_TEXT2))
	var rl = w.make_label("\n".join(PackedStringArray(lines)), 22, Color.WHITE)
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rl)
	var ok = w.make_button(w.t("race_back"), Color("#38c172"), 28, 86)
	ok.pressed.connect(finish_race)
	v.add_child(ok)
	ic.pivot_offset = Vector2(60, 60)
	ic.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(ic, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func fmt_time(tt: float) -> String:
	if tt < 0:
		return "—"
	return String.num(tt, 2) + " s"


func finish_race():
	w.close_popup()
	phase = "leave"
	var tw = create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.4)
	tw.tween_callback(leave_track)
	tw.tween_property(fade, "color:a", 0.0, 0.4)
	tw.tween_callback(func():
		if hud:
			hud.queue_free()
			hud = null
		phase = "")


func leave_track():
	visible = false
	active = false
	if p_car:
		p_car.queue_free()
		p_car = null
	if b_car:
		b_car.queue_free()
		b_car = null
	w.bottom_panel.visible = true; w.km_label.get_parent().get_parent().visible = true; w.weather_label.get_parent().get_parent().visible = true
	w.cam.fov = 60
	w.cam.rotation_degrees = Vector3(-26, 0, 0)
	w.current_speed = w.get_speed() * 0.7
	if big_label:
		big_label.modulate.a = 0.0


# ================= ИНТЕРФЕЙС ГОНКИ =================
func build_hud():
	if hud:
		hud.queue_free()
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.ui_root.add_child(hud)

	# верхняя плашка: против кого гонка и полоса прогресса
	var top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", w.box(Color(0.07, 0.09, 0.14, 0.88), 26, 16))
	top.anchor_right = 1.0
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 24
	hud.add_child(top)
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 10)
	top.add_child(tv)
	var title = w.make_label(w.t("race_event"), 34, w.ACCENT)
	tv.add_child(title)
	info_label = w.make_label("", 20, Color.WHITE)
	tv.add_child(info_label); gap_label = w.make_label("", 22, Color.WHITE); tv.add_child(gap_label)
	bar = Control.new()
	bar.custom_minimum_size = Vector2(0, 34)
	tv.add_child(bar)
	var track = ColorRect.new()
	track.color = Color("#2b3245")
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.offset_top = 13
	track.offset_bottom = -13
	bar.add_child(track)
	var flag = w.icon("trophy", Color.WHITE, 30)
	flag.anchor_left = 1.0
	flag.anchor_right = 1.0
	flag.offset_left = -30
	bar.add_child(flag)
	b_mark = w.icon_circle("", Color(rarity_of(boss_id)["color"]), 26)
	bar.add_child(b_mark)
	p_mark = w.icon_circle("car", Color(w.car_color()), 34)
	bar.add_child(p_mark)

	big_label = w.make_label("", 120, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 24)
	big_label.anchor_right = 1.0
	big_label.anchor_top = 0.3
	big_label.anchor_bottom = 0.3
	big_label.offset_bottom = 160
	big_label.modulate.a = 0.0
	hud.add_child(big_label)

	start_btn = w.make_button(w.t("race_start"), Color("#38c172"), 48, 150)
	start_btn.anchor_top = 1.0
	start_btn.anchor_bottom = 1.0
	start_btn.anchor_right = 1.0
	start_btn.offset_left = 40
	start_btn.offset_right = -40
	start_btn.offset_top = -230
	start_btn.offset_bottom = -60
	start_btn.visible = false
	start_btn.button_down.connect(_on_start_pressed)
	hud.add_child(start_btn)
	var hint = w.make_label(w.t("race_hint"), 18, w.UI_TEXT2)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_top = -280
	hint.offset_bottom = -240
	start_btn.visibility_changed.connect(func(): hint.visible = start_btn.visible)
	hint.visible = false
	hud.add_child(hint)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)


func set_big(text: String, col: Color):
	if big_label.text == text:
		return
	big_label.text = text
	big_label.add_theme_color_override("font_color", col)
	big_label.modulate.a = 1.0
	big_label.pivot_offset = Vector2(big_label.size.x / 2.0, 80)
	big_label.scale = Vector2(1.5, 1.5)
	create_tween().tween_property(big_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_gap():
	# отрыв от босса в метрах: зелёный — мы впереди, красный — отстаём
	if gap_label == null or phase == "countdown":
		return
	var gap = (p_pos - b_pos) * w.VIS
	var ahead = gap >= 0.0
	gap_label.text = w.t("race_ahead" if ahead else "race_behind") + " " + str(int(absf(gap))) + " " + w.t("race_m")
	gap_label.add_theme_color_override("font_color", Color("#3ddc97") if ahead else Color("#ff6b6b"))


func update_hud():
	if hud == null or bar == null:
		return
	var bw = bar.size.x - 40
	p_mark.position = Vector2(clampf(p_pos / length, 0.0, 1.0) * bw, 2)
	b_mark.position = Vector2(clampf(b_pos / length, 0.0, 1.0) * bw, 4); show_gap()


# ================= ГОНОЧНАЯ ТРАССА =================
func build_track():
	track_built = true
	var mid_z = (NEAR - LOOP) / 2.0 - 20.0
	var long = LOOP + 60.0
	# трава вокруг и тёмный гоночный асфальт
	var grass = w.toon(Color("#5fb04a"))
	grass.albedo_texture = w.noise_tex(Color("#e9f5e4"), Color("#ffffff"), 0.02)
	grass.uv1_scale = Vector3(70, 70, 1)
	add_plane(Vector2(1400, 1400), Vector3(0, -0.5, -500), grass)
	track_mat = w.toon(Color("#3d4250"))
	track_mat.albedo_texture = w.noise_tex(Color("#e8eaef"), Color("#ffffff"), 0.1)
	track_mat.uv1_scale = Vector3(1, long / 8.0, 1)
	add_plane(Vector2(TRACK_W, long), Vector3(0, -0.45, mid_z), track_mat)
	# белые края и пунктир посередине
	for s in [-1, 1]:
		w.rbox(Vector3(0.18, 0.03, long), Vector3(s * (TRACK_W / 2 - 0.3), -0.44, mid_z), Color("#ffffff"), self, false, "matte", 0.5)
		# отбойник
		w.rbox(Vector3(0.35, 0.8, long), Vector3(s * (TRACK_W / 2 + 3.2), -0.1, mid_z), Color("#dfe4ea"), self, false, "matte", 0.4)
		w.rbox(Vector3(0.37, 0.18, long), Vector3(s * (TRACK_W / 2 + 3.2), 0.1, mid_z), Color("#3a86ff"), self, false, "paint", 0.4)
	for i in int(LOOP / 8.0):
		add_scroll(w.rbox(Vector3(0.2, 0.03, 3.5), Vector3(0, -0.44, NEAR - i * 8.0), Color("#ffffff"), self, false, "matte", 0.5))
	# поребрики «зебра»: красный-белый
	for i in int(LOOP / 2.0):
		for s in [-1, 1]:
			var col = Color("#e63946") if i % 2 == 0 else Color("#ffffff")
			add_scroll(w.rbox(Vector3(1.0, 0.12, 2.0), Vector3(s * (TRACK_W / 2 + 0.5), -0.42, NEAR - i * 2.0), col, self, false, "matte", 0.5))
	# трибуны, шины, флаги, фонари
	for i in int(LOOP / 32.0):
		for s in [-1, 1]:
			add_scroll(make_stand(s, NEAR - i * 32.0 - (16.0 if s < 0 else 0.0)))
	for i in int(LOOP / 20.0):
		for s in [-1, 1]:
			add_scroll(make_tires(s, NEAR - i * 20.0 - 10.0))
			add_scroll(make_flag(s, NEAR - i * 20.0 - 4.0))
	for i in int(LOOP / 80.0):
		for s in [-1, 1]:
			var lamp = w.make_lamp()
			lamp.position = Vector3(s * (TRACK_W / 2 + 2.4), -0.5, NEAR - i * 80.0)
			if s < 0:
				lamp.rotation.y = PI
			add_child(lamp)
			add_scroll(lamp)
	# ворота старта и финиша
	start_arch = make_arch(false)
	add_child(start_arch)
	finish_arch = make_arch(true)
	add_child(finish_arch)
	visible = false


func add_plane(size: Vector2, pos: Vector3, mat: Material):
	var pm = PlaneMesh.new()
	pm.size = size
	var mi = MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func add_scroll(o: Node3D):
	o.set_meta("base_z", o.position.z)
	scroll.append(o)


func make_stand(side: int, z: float) -> Node3D:
	# трибуна со зрителями
	var st = Node3D.new()
	var x = side * (TRACK_W / 2 + 8.0)
	for row in 4:
		w.rbox(Vector3(4.0, 0.5, 14.0), Vector3(side * row * 1.2, row * 0.7, 0), Color("#8d99ae").lightened(row * 0.06), st, false, "matte", 0.3)
		for k in 9:
			var col = [Color("#ef476f"), Color("#ffd166"), Color("#06d6a0"), Color("#118ab2"), Color("#ffffff")][w.rng.randi() % 5]
			w.add_mesh(w.sphere(0.32), Vector3(side * row * 1.2 + w.rng.randf_range(-1.2, 1.2), row * 0.7 + 0.55, -6.0 + k * 1.5), col, st)
	var roof = w.rbox(Vector3(6.5, 0.25, 14.5), Vector3(side * 2.2, 4.2, 0), Color("#e63946"), st, false, "paint", 0.4)
	roof.rotation_degrees.z = -6 * side
	for zz in [-6.5, 6.5]:
		w.add_mesh(w.capsule(0.12, 4.2), Vector3(side * 4.8, 2.0, zz), Color("#6c7a91"), st)
	st.position = Vector3(x, -0.4, z)
	add_child(st)
	return st


func make_tires(side: int, z: float) -> Node3D:
	var t = Node3D.new()
	for k in 3:
		for h in 2:
			var tire = w.add_mesh(w.torus(0.22, 0.45), Vector3(0, h * 0.32, k * 0.95), Color("#2a2a2e") if (k + h) % 2 == 0 else Color("#e63946"), t, false, "rubber")
			tire.scale = Vector3(1, 1.4, 1)
	t.position = Vector3(side * (TRACK_W / 2 + 2.3), -0.3, z)
	add_child(t)
	return t


func make_flag(side: int, z: float) -> Node3D:
	var f = Node3D.new()
	w.add_mesh(w.capsule(0.05, 3.2), Vector3(0, 1.1, 0), Color("#dee2e6"), f)
	var col = [Color("#ef476f"), Color("#ffd166"), Color("#3a86ff"), Color("#06d6a0")][w.rng.randi() % 4]
	var cloth = w.rbox(Vector3(0.05, 0.6, 0.95), Vector3(0, 2.35, 0.5), col, f, false, "matte", 0.4)
	cloth.rotation_degrees.x = 5
	f.position = Vector3(side * (TRACK_W / 2 + 1.6), -0.5, z)
	add_child(f)
	return f


func make_arch(finish: bool) -> Node3D:
	var a = Node3D.new()
	var half = TRACK_W / 2 + 1.0
	for s in [-1, 1]:
		w.rbox(Vector3(0.5, 5.0, 0.5), Vector3(s * half, 2.0, 0), Color("#2b2d42"), a, false, "matte", 0.4)
	w.rbox(Vector3(half * 2 + 0.6, 1.1, 0.5), Vector3(0, 4.6, 0), Color("#2b2d42"), a, false, "matte", 0.3)
	if finish:
		# шахматная клетка на арке и на асфальте
		for i in 16:
			for j in 2:
				var c = Color.WHITE if (i + j) % 2 == 0 else Color("#111111")
				w.rbox(Vector3(0.62, 0.45, 0.06), Vector3(-4.65 + i * 0.62, 4.37 + j * 0.45, 0.27), c, a, false, "matte", 0.1)
				w.rbox(Vector3(TRACK_W / 16.0, 0.02, 0.6), Vector3(-TRACK_W / 2 + (i + 0.5) * TRACK_W / 16.0, -0.43, -0.3 + j * 0.6), c, a, false, "matte", 0.1)
	else:
		# огни светофора старта
		start_lights.clear()
		for i in 3:
			w.add_mesh(w.sphere(0.32), Vector3(-0.9 + i * 0.9, 4.6, 0.3), Color("#2a2a2e"), a)
			var l = w.add_mesh(w.sphere(0.3), Vector3(-0.9 + i * 0.9, 4.6, 0.36), Color("#ff3b3b"), a, true)
			l.visible = false
			start_lights.append(l)
		for i in 10:
			w.rbox(Vector3(TRACK_W / 10.0 - 0.05, 0.02, 0.4), Vector3(-TRACK_W / 2 + (i + 0.5) * TRACK_W / 10.0, -0.43, 0), Color.WHITE, a, false, "matte", 0.1)
	return a


# ================= БОССЫ ГОНОК: спортивные машины =================
# opts: "accent" — цвет полос и деталей, "number" — номер на крыше
func build_boss(style: String, color: Color, opts: Dictionary) -> Node3D:
	var car = Node3D.new()
	var accent: Color = opts.get("accent", Color.WHITE)
	var o = opts.duplicate()
	o["rim"] = accent
	var roof = 0.0
	var L = 4.3
	match style:
		"boss_muscle":
			# широкий «маслкар»: воздухозаборник на капоте, две полосы, большое крыло
			L = 4.4
			roof = Cars.base_car(w, car, color, L, 2.05, 0.62, 0.42, 1.5, 0.5, 0.45, o)
			w.rbox(Vector3(0.7, 0.18, 1.0), Vector3(0, 0.42, -1.25), Cars.DARK, car, false, "matte", 0.5)
			for sx in [-0.28, 0.28]:
				w.rbox(Vector3(0.22, 0.03, L * 0.98), Vector3(sx, 0.36, 0), accent, car, false, "paint", 0.5)
				w.rbox(Vector3(0.22, 0.03, 1.2), Vector3(sx, roof + 0.01, 0.45), accent, car, false, "paint", 0.5)
			Cars.spoiler(w, car, 2.0, 2.0, roof - 0.2)
		"boss_gt":
			# GT-болид: низкий, боковые воздухозаборники, крыло на высоких стойках
			L = 4.5
			roof = Cars.base_car(w, car, color, L, 2.1, 0.48, 0.38, 1.55, 0.42, 0.2, o)
			for sx in [-1.06, 1.06]:
				w.rbox(Vector3(0.08, 0.24, 1.0), Vector3(sx, 0.05, 0.55), Cars.DARK, car, false, "matte", 0.5)
				w.rbox(Vector3(0.05, 0.12, L * 0.9), Vector3(sx, -0.12, 0), accent, car, false, "paint", 0.5)
			w.rbox(Vector3(0.5, 0.03, L * 0.98), Vector3(0, 0.27, 0), accent, car, false, "paint", 0.5)
			for sx in [-0.6, 0.6]:
				w.rbox(Vector3(0.08, 0.55, 0.12), Vector3(sx, roof + 0.05, 2.0), Cars.DARK, car, false, "matte", 0.5)
			w.rbox(Vector3(2.15, 0.09, 0.55), Vector3(0, roof + 0.35, 2.05), accent, car, false, "paint", 0.6)
		"boss_hyper":
			# гиперкар: очень низкий, плавники, светящаяся полоса, диффузор
			L = 4.6
			roof = Cars.base_car(w, car, color, L, 2.15, 0.4, 0.37, 1.35, 0.36, -0.05, o)
			for sx in [-0.75, 0.75]:
				var fin = w.rbox(Vector3(0.08, 0.32, 1.3), Vector3(sx, 0.3, 1.5), color.darkened(0.15), car, false, "paint", 0.5)
				fin.rotation_degrees.x = -8
			for sx in [-1.09, 1.09]:
				w.rbox(Vector3(0.04, 0.05, L * 0.85), Vector3(sx, 0.02, 0), accent, car, true, "matte", 0.5)
			w.rbox(Vector3(1.9, 0.16, 0.3), Vector3(0, -0.22, L / 2.0 - 0.05), Cars.DARK, car, false, "matte", 0.4)
			w.rbox(Vector3(2.1, 0.07, 0.5), Vector3(0, roof + 0.12, 2.05), Cars.DARK, car, false, "matte", 0.6)
		"boss_proto":
			# прототип с Ле-Мана: длинный, узкая кабина-пузырь, «акулий» плавник
			L = 4.9
			var wy = 0.38 - 0.45
			var by = wy - 0.08 + 0.2
			w.rbox(Vector3(2.15, 0.42, L), Vector3(0, by, 0), color, car, false, "paint", 0.45)
			for sx in [-0.85, 0.85]:
				var arch = w.add_mesh(w.sphere(0.5), Vector3(sx, by + 0.15, -1.45), color, car, false, "paint")
				arch.scale = Vector3(0.8, 0.55, 1.4)
				var arch2 = w.add_mesh(w.sphere(0.5), Vector3(sx, by + 0.15, 1.45), color, car, false, "paint")
				arch2.scale = Vector3(0.8, 0.55, 1.4)
			var canopy = w.add_mesh(w.sphere(0.5), Vector3(0, by + 0.38, -0.1), Cars.GLASS, car, false, "glass")
			canopy.scale = Vector3(1.5, 0.75, 3.2)
			w.rbox(Vector3(0.08, 0.6, 1.7), Vector3(0, by + 0.5, 1.4), accent, car, false, "paint", 0.5)
			w.rbox(Vector3(2.2, 0.08, 0.5), Vector3(0, by + 0.75, 2.2), Cars.DARK, car, false, "matte", 0.6)
			for sx in [-1.0, 1.0]:
				w.rbox(Vector3(0.06, 0.55, 0.6), Vector3(sx, by + 0.45, 2.2), Cars.DARK, car, false, "matte", 0.5)
				w.rbox(Vector3(0.04, 0.05, L * 0.8), Vector3(sx * 1.08, by - 0.02, 0), accent, car, true, "matte", 0.5)
			Cars.wheels(w, car, 0.98, -1.45, 1.45, 0.38, o)
			Cars.lights(w, car, -L / 2.0, L / 2.0, by + 0.05, 0.7)
			car.set_meta("len", L)
			roof = by + 0.75
	# номер на крыше (круг + цифра)
	var num = str(opts.get("number", 1))
	w.add_mesh(w.cylinder(0.32, 0.32, 0.02), Vector3(0, roof + 0.02, 0.1), Color.WHITE, car)
	var lbl = Label3D.new()
	lbl.text = num
	lbl.font_size = 64
	lbl.pixel_size = 0.006
	lbl.modulate = Color("#111111")
	lbl.outline_size = 0
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.position = Vector3(0, roof + 0.04, 0.1)
	car.add_child(lbl)
	Cars.exhaust(w, car, car.get_meta("len", 4.4) / 2.0 + 0.05, -0.15)
	return car
