extends Node3D

const Texts = preload("res://texts.gd")
const Cars = preload("res://cars.gd")
const Sound = preload("res://sound.gd")
const Icons = preload("res://icons.gd")
const Biomes = preload("res://biomes.gd")
const Race = preload("res://race.gd")
const Showroom = preload("res://showroom.gd")

# ================= НАСТРОЙКИ ИГРЫ =================
# Километры считаются как в жизни: время в игре идёт как настоящее.
# При 60 KM/H вы проезжаете 1 KM в минуту.
const SAVE_PATH = "user://save_v2.cfg"
const BASE_OFFLINE_SECONDS = 2 * 60 * 60  # базовый лимит офлайна — 2 часа
const VIS = 0.3              # скорость «полёта» мира: метров в секунду на 1 KM/H
const LANE_X = 1.75          # наша полоса справа, встречка слева
const ROAD_WIDTH = 7.0
const LOOP_LEN = 320.0       # длина «бесконечного» участка дороги
const NEAR_Z = 15.0          # объект уехал за камеру -> переносим вперёд
const FAR_Z = NEAR_Z - LOOP_LEN
const FOLLOW_GAP = 3.6       # зазор до машины впереди (плюс половина её длины)
const DAY_LENGTH = 420.0     # длина полных суток в секундах
const MINI_STAGES = 3        # сколько раз нужно попасть в зелёную зону
const MISS_PENALTY = 0.22    # промах «съедает» такую долю времени — встречка резко ближе
const CRASH_PENALTY = 0.10   # сколько баланса теряем при аварии (10%)
const THREAT_START_Z = -110.0

# ---- ИВЕНТ «ПТИЦА» ----
const BIRD_MIN_DELAY = 25.0      # через сколько секунд может появиться птица (от и до)
const BIRD_MAX_DELAY = 60.0
const BIRD_BONUS_SECONDS = 30.0  # награда: доход за столько секунд езды (поменяем позже)

# ---- СУНДУКИ: шансы можно менять здесь ----
const CHEST_BASE_CHANCE = 0.25   # базовый шанс сундука после успешного обгона
const CHEST_ORDER = ["parts", "tools", "carparts", "car"]
var chest_types = {
	"parts":    {"chance": 60, "icon": "box",    "color": Color("#c08552")},  # ящик с деталями
	"tools":    {"chance": 25, "icon": "wrench", "color": Color("#e5484d")},  # ящик с инструментами
	"carparts": {"chance": 12, "icon": "gear",   "color": Color("#3e8bff")},  # ящик с деталями машин
	"car":      {"chance": 3,  "icon": "car",    "color": Color("#f5b301")},  # ящик с гарантированной машиной
}

# ---- ПОГОДА: шанс и как она выглядит (снег выключен: chance = 0) ----
var weathers = {
	"clear":  {"chance": 50, "cloud": 0.0,  "rain": 0.0, "fog": 0.0015, "icon": "sun"},
	"cloudy": {"chance": 25, "cloud": 0.7,  "rain": 0.0, "fog": 0.0028, "icon": "cloud"},
	"rain":   {"chance": 15, "cloud": 0.9,  "rain": 1.0, "fog": 0.008,  "icon": "rain"},
	"fog":    {"chance": 10, "cloud": 0.5,  "rain": 0.0, "fog": 0.028,  "icon": "fog"},
	"snow":   {"chance": 0,  "cloud": 0.85, "rain": 0.0, "fog": 0.014,  "icon": "cloud"},
}

# ---- небо по времени суток: [время, верх неба, горизонт, цвет солнца, сила солнца, общий свет] ----
var sky_keys = [
	[0.0,  Color("#101a3a"), Color("#26305a"), Color("#8fa0e0"), 0.12, 0.3],
	[0.22, Color("#22336a"), Color("#5a5288"), Color("#8fa0e0"), 0.15, 0.35],
	[0.28, Color("#5b7fc4"), Color("#ffb79a"), Color("#ffbb80"), 0.6, 0.65],
	[0.4,  Color("#4a90e8"), Color("#bfe3ff"), Color("#fff4dc"), 1.0, 0.85],
	[0.62, Color("#4a90e8"), Color("#bfe3ff"), Color("#fff4dc"), 1.0, 0.85],
	[0.74, Color("#5a5b8c"), Color("#ff9f7a"), Color("#ffa36c"), 0.6, 0.65],
	[0.8,  Color("#22336a"), Color("#5a5288"), Color("#8fa0e0"), 0.15, 0.35],
	[1.0,  Color("#101a3a"), Color("#26305a"), Color("#8fa0e0"), 0.12, 0.3],
]

# ================= ПРОГРЕСС =================
var total_km: float = 0.0   # весь пройденный путь (для лидерборда)
var km: float = 0.0         # баланс, который можно тратить
var nuts: int = 0           # вторая валюта — гайки
var current_speed: float = 0.0   # KM/H
var save_timer: float = 0.0
var anim_time: float = 0.0
var rng = RandomNumberGenerator.new()
var nick = ""

# общие улучшения за KM (действуют на любую машину)
var upgrades = {
	"speed":    {"level": 0, "base_cost": 0.5, "growth": 1.6,  "icon": "speed",    "color": Color("#ff7a45")},
	"accel":    {"level": 0, "base_cost": 0.6, "growth": 1.6,  "icon": "bolt",     "color": Color("#22b8cf")},
	"overtake": {"level": 0, "base_cost": 1.2, "growth": 1.7,  "icon": "overtake", "color": Color("#9b6dff")},
	"offline":  {"level": 0, "base_cost": 2.4, "growth": 1.75, "icon": "clock",    "color": Color("#38c172")},
}
# универсальные улучшения за гайки (Мастерская)
const WS_ORDER = ["income", "luck", "offline", "discount", "bird"]
var workshop = {
	"income":   {"level": 0, "base": 3, "growth": 1.5, "max": 20, "icon": "car",    "color": Color("#ffa94d")},
	"luck":     {"level": 0, "base": 4, "growth": 1.6, "max": 10, "icon": "star",   "color": Color("#ffd43b")},
	"offline":  {"level": 0, "base": 5, "growth": 1.7, "max": 6,  "icon": "moon",   "color": Color("#748ffc")},
	"discount": {"level": 0, "base": 4, "growth": 1.6, "max": 10, "icon": "wrench", "color": Color("#63e6be")},
	"bird":     {"level": 0, "base": 3, "growth": 1.5, "max": 8,  "icon": "bird",   "color": Color("#ff8fab")},
}
# тюнинг: детали конкретной машины (нужны KM + запчасти из сундуков)
const PART_ORDER = ["engine", "gearbox", "wheels", "turbo"]
const PART_MAX = 10
var part_info = {
	"engine":  {"base_cost": 80,  "growth": 1.7, "icon": "flame", "color": Color("#ff6b6b")},
	"gearbox": {"base_cost": 60,  "growth": 1.7, "icon": "gear",  "color": Color("#4dabf7")},
	"wheels":  {"base_cost": 50,  "growth": 1.7, "icon": "wheel", "color": Color("#ffd43b")},
	"turbo":   {"base_cost": 150, "growth": 1.8, "icon": "turbo", "color": Color("#b197fc")},
}
var spare = {"engine": 0, "gearbox": 0, "wheels": 0, "turbo": 0}   # запчасти на складе
var tune = {}    # {машина: {деталь: уровень}}
# покраска
const PAINTS = ["#ef476f", "#118ab2", "#06d6a0", "#ffd166", "#8338ec", "#ff7f11", "#2b2d42", "#f8f9fa", "#e63946", "#00b4d8"]
var paint = {}          # {машина: цвет}
var owned_paints = {}   # {машина: [цвета]}
var owned_cars = ["hatch"]
var selected_car = "hatch"
var parts = {"retro": 0, "ghost": 0, "rocket": 0}
var chests = {"parts": 0, "tools": 0, "carparts": 0, "car": 0}

# настройки
var lang = "ru"
var music_on = true
var sound_on = true
var vibro_on = true

# ================= 3D-МИР =================
var sound: Node
var cam: Camera3D
var cam_base = Vector3(0.8, 6.2, 10.0)
var shake: float = 0.0
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var road_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var shoulder_mat: StandardMaterial3D
var rain_fx: CPUParticles3D
var wind_fx: CPUParticles3D
var headlight: SpotLight3D
var player_car: Node3D
var scrolling = []      # разметка и окружение, которые едут навстречу по кругу
var clouds = []
var landmarks = []      # заправки, кафе, дома, билборды
var landmark_timer: float = 12.0
var backdrop: Node3D
var biome = "meadow"
var biome_timer: float = 70.0
var oncoming = []       # встречные машины
var lead_car: Node3D = null   # машина впереди в нашей полосе
var lead_speed: float = 0.0
var lead_passing = false
var lead_timer: float = 6.0
var oncoming_timer: float = 1.0
var overtaking = false
var back_in_lane = true
var overtake_cooldown: float = 0.0
var mat_cache = {}
var mesh_cache = {}
var glow_mats = []
var car_lights = []     # фары всех машин (конусы света)
var lamp_lights = []    # свет фонарей
var flashers = []       # мигалки полиции и скорой
var last_light: SpotLight3D

# погода и время суток
var day_time: float = 0.33
var weather = "clear"
var weather_timer: float = 60.0
var cloud: float = 0.0
var rain_amt: float = 0.0
var fog_d: float = 0.003
var night: float = 0.0
var dark: float = 0.0

# птица
var bird: Node3D = null
var bird_hint: Label3D = null
var bird_t: float = 0.0
var bird_dir: float = 1.0
var bird_timer: float = 30.0
var bird_gold = false
var bird_ring: MeshInstance3D = null
var bird_outline: StandardMaterial3D
var stars: Node3D
var shop_btn: Button
var admin_btn: Button
var overtake_glow: Panel
var shop_nuts_label: Label

# ================= МИНИ-ИГРА =================
var mini_active = false
var mini_stage = 0
var mini_time_total: float = 5.0
var mini_time_left: float = 5.0
var marker_pos: float = 0.0
var marker_dir: float = 1.0
var marker_speed: float = 1.0
var zone_start: float = 0.0
var zone_size: float = 0.2
var threat_car: Node3D = null    # встречная машина, которая едет на нас во время мини-игры
var threat_state = ""
var threat_v: float = 20.0
var threat_base_z: float = 0.0   # где встречка была бы без промахов
var threat_push: float = 0.0     # насколько ближе её сделали промахи

# ================= ИНТЕРФЕЙС =================
var ui_root: Control
var km_label: Label
var speed_label: Label
var nuts_label: Label
var weather_label: Label
var weather_icon: Control
var toast: Label
var banner: Label
var bottom_panel: PanelContainer
var tab_buttons = {}
var pages = {}
var current_tab = "upgrades"
var cards = {}
var part_cards = {}
var ws_cards = {}
var ws_nuts_label: Label
var paint_buttons = {}
var paint_price_label: Label
var tune_title: Label
var car_rows = {}
var chest_cards = {}
var overtake_btn: Button
var settings_btn: Button
var lb_btn: Button
var mini_panel: PanelContainer
var mini_bar: Control
var mini_bar_bg: ColorRect
var mini_zone: ColorRect
var mini_marker: ColorRect
var mini_timer_fill: ColorRect
var stage_label: Label
var popup_dim: ColorRect = null
var ui_font: Font
var race: Node3D
var race_pending = false
var showroom: Node3D


func _ready():
	rng.randomize()
	sound = Sound.new()
	add_child(sound)
	var offline_earned = load_game()
	if not FileAccess.file_exists(SAVE_PATH):
		var loc = OS.get_locale_language()
		lang = loc if Texts.LANGS.has(loc) else "en"
	if nick == "":
		nick = t("default_nick") + str(rng.randi_range(100, 999))
	sound.set_music(music_on)
	sound.set_sound(sound_on)
	setup_world()
	setup_ui()
	current_speed = get_speed()
	bird_timer = bird_delay()
	update_ui()
	if offline_earned > 0:
		show_toast(t("offline") + fmt(offline_earned) + " " + t("km"))


func t(key: String) -> String:
	return Texts.TEXT[lang].get(key, key)


# ---------- формулы ----------
func car_mult() -> float:
	return Cars.CARS[selected_car]["mult"]

func part_level(p: String) -> int:
	return tune.get(selected_car, {}).get(p, 0)

func ws_level(id: String) -> int:
	return workshop[id]["level"]

func get_speed() -> float:      # максимальная скорость, KM/H
	var parts_bonus = 1.0 + 0.06 * part_level("engine") + 0.04 * part_level("turbo")
	return (60.0 + upgrades["speed"]["level"] * 6.0) * car_mult() * parts_bonus

func get_accel() -> float:      # разгон, KM/H в секунду
	var parts_bonus = 1.0 + 0.10 * part_level("gearbox") + 0.04 * part_level("turbo")
	return (12.0 + upgrades["accel"]["level"] * 5.0) * car_mult() * parts_bonus

func income_mult() -> float:    # бонус Мастерской к заработку
	return 1.0 + 0.1 * ws_level("income")

func income_per_sec() -> float: # сколько KM даёт секунда езды на полной скорости
	return get_speed() / 3600.0 * income_mult()

func discount() -> float:
	return 1.0 - 0.03 * ws_level("discount")

func get_offline_rate() -> float:
	return minf(0.1 + upgrades["offline"]["level"] * 0.05, 1.0)

func max_offline() -> float:
	return BASE_OFFLINE_SECONDS + 3600.0 * ws_level("offline")

func get_zone_size() -> float:
	return clampf(0.10 + upgrades["overtake"]["level"] * 0.012 + part_level("wheels") * 0.006, 0.10, 0.3)

func get_mini_time() -> float:
	return minf(5.0 + upgrades["overtake"]["level"] * 0.2 + part_level("wheels") * 0.15, 9.0)

func get_chest_chance() -> float:
	return CHEST_BASE_CHANCE + minf(upgrades["overtake"]["level"] * 0.008, 0.12) + 0.02 * ws_level("luck")

func bird_delay() -> float:
	var k = 1.0 - 0.1 * ws_level("bird")
	return rng.randf_range(BIRD_MIN_DELAY, BIRD_MAX_DELAY) * k

func get_cost(id: String) -> float:
	var u = upgrades[id]
	return snappedf(u["base_cost"] * pow(u["growth"], u["level"]) * discount(), 0.01)

func get_part_cost(p: String) -> int:
	var info = part_info[p]
	return int(info["base_cost"] * pow(car_mult(), 1.5) * pow(info["growth"], part_level(p)) * discount())

func part_need(p: String) -> int:   # сколько запчастей нужно на следующий уровень
	return part_level(p) + 1

func get_ws_cost(id: String) -> int:
	var w = workshop[id]
	return int(w["base"] * pow(w["growth"], w["level"]))

func paint_price() -> float:
	return snappedf(25.0 * pow(car_mult(), 1.5) * discount(), 0.1)

func car_color() -> String:
	return paint.get(selected_car, Cars.CARS[selected_car]["color"])

func car_opts() -> Dictionary:
	# внешний вид от тюнинга: диски меняют цвет, турбо даёт огонь из выхлопа
	var w = part_level("wheels")
	var rim = Cars.CHROME
	if w >= 8:
		rim = Color("#ffcc33")
	elif w >= 4:
		rim = Color("#3a3f4b")
	return {"rim": rim, "exhaust": part_level("turbo") >= 5}

func follow_dist() -> float:
	return lead_car.get_meta("len", 4.0) / 2.0 + FOLLOW_GAP if lead_car else 7.0


# ================= ГЛАВНЫЙ ЦИКЛ =================
func _process(delta):
	anim_time += delta
	if race.active or showroom.active:
		if not showroom.active: race.step(delta)
		update_environment(delta)
		update_flashers()
		return
	update_speed(delta)
	var dz = current_speed * VIS * delta
	move_scenery(dz, delta)
	update_landmarks(dz, delta)
	update_biome(delta)
	update_oncoming(delta, dz)
	update_lead(delta)
	update_threat(delta)
	update_minigame(delta)
	update_bird(delta)
	update_environment(delta)
	update_flashers()
	update_camera(delta)
	sound.set_engine(0.75 + 0.5 * clampf(current_speed / maxf(get_speed(), 1.0), 0.0, 1.0) + 0.3 * minf(get_speed() / 300.0, 1.0), -15.0)
	var distance = current_speed / 3600.0 * delta
	total_km += distance
	km += distance * income_mult()
	if overtake_cooldown > 0:
		overtake_cooldown -= delta
	update_ui()
	save_timer += delta
	if save_timer >= 5.0:
		save_timer = 0.0
		save_game()


func update_speed(delta):
	var target = get_speed()
	# медленная машина впереди -> подъезжаем и едем с её скоростью
	if lead_car and not lead_passing:
		target = minf(target, lead_speed + maxf(-lead_car.position.z - follow_dist(), 0.0) * 3.0)
	if current_speed > target:
		current_speed = move_toward(current_speed, target, maxf(get_speed() * 0.8, 40.0) * delta)
	else:
		current_speed = move_toward(current_speed, target, get_accel() * delta)


func is_blocked() -> bool:
	return lead_car != null and not lead_passing and -lead_car.position.z <= follow_dist() + 0.5


func update_camera(delta):
	shake = move_toward(shake, 0.0, delta * 1.5)
	var off = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * shake * 0.35
	cam.position = cam_base + Vector3(player_car.position.x * 0.25, 0, 0) + off
	# чем быстрее едем, тем шире обзор — так скорость чувствуется сильнее
	var sp = clampf((current_speed - 60.0) / 240.0, 0.0, 1.0)
	cam.fov = lerpf(cam.fov, 60.0 + sp * 16.0, delta * 2.0)
	wind_fx.emitting = current_speed > 110.0
	wind_fx.gravity = Vector3(0, 0, current_speed * VIS * 3.0)


func update_flashers():
	var phase = int(anim_time * 4.0) % 2
	for f in flashers.duplicate():
		if not is_instance_valid(f[0]):
			flashers.erase(f)
			continue
		f[0].visible = f[1] == phase


# ================= ТРАФИК =================
func random_traffic_car() -> Node3D:
	var pick = Cars.random_traffic(rng)
	return Cars.build(self, pick[0], pick[1])


func update_lead(delta):
	if lead_car == null:
		lead_timer -= delta
		if lead_timer <= 0 and not overtaking:
			lead_speed = maxf(get_speed() * rng.randf_range(0.45, 0.6), 30.0)
			lead_car = random_traffic_car()
			lead_car.position = Vector3(LANE_X, 0, FAR_Z)
			add_child(lead_car)
		return
	lead_car.position.z += (current_speed - lead_speed) * VIS * delta
	if not lead_passing:
		lead_car.position.z = minf(lead_car.position.z, -follow_dist())
	if lead_passing and lead_car.position.z > -2.0 and not lead_car.has_meta("whoosh"):
		lead_car.set_meta("whoosh", true)
		sound.play("passby", -7.0, 0.85)
	var clear_z = lead_car.get_meta("len", 4.0) / 2.0 + 3.0
	if overtaking and not back_in_lane and lead_car.position.z > clear_z:
		return_to_lane()
	if lead_car.position.z > NEAR_Z + 5.0:
		lead_car.queue_free()
		lead_car = null
		lead_passing = false
		lead_timer = rng.randf_range(8.0, 16.0)


func update_oncoming(delta, dz):
	oncoming_timer -= delta
	var lead_close = lead_car != null and not lead_passing and -lead_car.position.z < follow_dist() + 60.0
	if oncoming_timer <= 0 and not lead_close and not overtaking and not mini_active:
		oncoming_timer = rng.randf_range(1.8, 4.0)
		var c = random_traffic_car()
		c.rotation.y = PI  # смотрит на нас
		c.position = Vector3(-LANE_X, 0, FAR_Z)
		c.set_meta("speed", rng.randf_range(50.0, 90.0))
		add_child(c)
		oncoming.append(c)
	for c in oncoming.duplicate():
		c.position.z += dz + c.get_meta("speed") * VIS * delta
		if c.position.z > -3.0 and not c.has_meta("whoosh"):
			c.set_meta("whoosh", true)
			sound.play("passby", -9.0, rng.randf_range(0.9, 1.1))
		if c.position.z > NEAR_Z + 5.0:
			oncoming.erase(c)
			c.queue_free()


func threat_hit_z() -> float:
	return -threat_car.get_meta("len", 4.0) / 2.0 - 2.1


func update_threat(delta):
	if threat_car == null:
		return
	match threat_state:
		"coming":
			# встречка всегда приближается вместе с таймером; промахи резко «съедают» время
			threat_base_z += threat_v * delta   # едет с постоянной обычной скоростью
			var target_z = minf(threat_base_z + threat_push, threat_hit_z())
			threat_car.position.z = target_z
		"slow":   # притормозил и прижался к своему краю дороги
			threat_car.position.z += (current_speed + 40.0) * VIS * delta   # спокойно едет дальше по своей полосе
		"pass":   # проехал дальше после аварии
			threat_car.position.z += (current_speed + 40.0) * VIS * delta
	if threat_car.position.z > NEAR_Z + 5.0:
		threat_car.queue_free()
		threat_car = null


# ================= ОБГОН И МИНИ-ИГРА =================
func _on_overtake_pressed():
	if not is_blocked() or mini_active:
		return
	sound.play("click", -6.0)
	mini_active = true
	mini_stage = 0
	mini_time_total = get_mini_time()
	mini_time_left = mini_time_total
	marker_pos = 0.0
	marker_dir = 1.0
	new_stage()
	mini_panel.visible = true
	bottom_panel.visible = false
	# убираем встречку, которая уже рядом, и выпускаем ту, что едет прямо на нас
	for c in oncoming.duplicate():
		if c.position.z > -125.0 and c.position.z < -2.0:
			oncoming.erase(c)
			c.queue_free()
	if threat_car:
		threat_car.queue_free()
	threat_car = random_traffic_car()
	threat_car.rotation.y = PI
	threat_car.position = Vector3(-LANE_X + 0.35, 0, THREAT_START_Z)
	threat_v = (-THREAT_START_Z + threat_hit_z()) / mini_time_total
	threat_state = "coming"; threat_base_z = THREAT_START_Z; threat_push = 0.0
	add_child(threat_car)
	# выглядываем из-за машины впереди
	create_tween().tween_property(player_car, "position:x", 0.6, 0.4).set_trans(Tween.TRANS_SINE)


func new_stage():
	var shrink = [1.5, 1.0, 0.65]  # зона уменьшается с каждым этапом
	zone_size = get_zone_size() * shrink[mini_stage]
	zone_start = rng.randf_range(0.05, 0.95 - zone_size)
	marker_speed = 1.0 + mini_stage * 0.3
	stage_label.text = t("stage") + " " + str(mini_stage + 1) + " / " + str(MINI_STAGES)


func update_minigame(delta):
	if not mini_active:
		return
	mini_time_left = (threat_hit_z() - threat_car.position.z) / threat_v if threat_car else mini_time_left - delta
	marker_pos += marker_dir * marker_speed * delta
	if marker_pos >= 1.0:
		marker_pos = 1.0
		marker_dir = -1.0
	elif marker_pos <= 0.0:
		marker_pos = 0.0
		marker_dir = 1.0
	var w = mini_bar.size.x
	var h = mini_bar.size.y
	mini_zone.position = Vector2(zone_start * w, 0)
	mini_zone.size = Vector2(zone_size * w, h)
	mini_marker.position = Vector2(marker_pos * w - 5, -8)
	mini_marker.size = Vector2(10, h + 16)
	var ratio = clampf(mini_time_left / mini_time_total, 0.0, 1.0)
	mini_timer_fill.size = Vector2(mini_timer_fill.get_parent().size.x * ratio, 12)
	mini_timer_fill.color = Color("#38c172").lerp(Color("#e5484d"), 1.0 - ratio)
	if mini_time_left <= 0.02 or (threat_car and threat_car.position.z >= threat_hit_z() - 0.05):   # время вышло / машины встретились
		finish_minigame(false)


func _on_mini_tap():
	if not mini_active:
		return
	if absf(marker_pos - (zone_start + zone_size / 2.0)) <= zone_size / 2.0 + 0.02:  # небольшой запас по краям
		mini_stage += 1
		sound.play("click", -4.0, 1.0 + mini_stage * 0.25)
		if mini_stage >= MINI_STAGES:
			finish_minigame(true)
		else:
			new_stage()
			flash(mini_bar_bg, Color("#38c172"))
	else:
		# промах: встречная машина резко приближается
		create_tween().tween_property(self, "threat_push", threat_push + -THREAT_START_Z * MISS_PENALTY * 0.5, 0.6).set_trans(Tween.TRANS_SINE)
		sound.play("fail", -8.0)
		flash(mini_bar_bg, Color("#e5484d"))
		shake = 0.25
		if vibro_on:
			Input.vibrate_handheld(60)


func flash(rect: ColorRect, col: Color):
	rect.color = col
	create_tween().tween_property(rect, "color", Color("#2b3245"), 0.35)


func finish_minigame(success: bool):
	mini_active = false
	mini_panel.visible = false
	bottom_panel.visible = true
	if success:
		start_overtake()
	else:
		crash()


func start_overtake():
	overtaking = true
	back_in_lane = false
	lead_passing = true
	lead_speed *= 0.6; create_tween().tween_property(lead_car, "position:x", LANE_X + 0.4, 0.5).set_trans(Tween.TRANS_SINE)
	current_speed = maxf(current_speed, get_speed())
	# встречная машина немного тормозит и прижимается к краю своей полосы (не съезжая с дороги)
	if threat_car:
		threat_state = "slow"
		create_tween().tween_property(threat_car, "position:x", -2.75, 0.5).set_trans(Tween.TRANS_SINE)
	var bonus = income_per_sec() * 5.0
	km += bonus
	var msg = t("overtake_ok") + fmt(bonus) + " " + t("km")
	if rng.randf() < get_chest_chance():
		var ct = roll_chest()
		chests[ct] += 1
		msg += "\n" + t("chest_got") + t("chest_" + ct)
		sound.chime([0, 4, 7, 12, 16], -8.0)
	else:
		sound.chime([7, 12], -10.0)
	if rng.randf() < 0.0:   # гайки теперь только из ящиков и за донат
		nuts += 1
		msg += "\n" + t("nuts_got") + "1"
	show_toast(msg)
	if rng.randf() < Race.RACE_CHANCE:
		race_pending = true
	# проезжаем по разделительной полосе между машинами
	create_tween().tween_property(player_car, "position:x", -0.3, 0.35).set_trans(Tween.TRANS_SINE)


func return_to_lane():
	back_in_lane = true
	var tw = create_tween()
	tw.tween_property(player_car, "position:x", LANE_X, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		overtaking = false
		if race_pending:
			race_pending = false
			start_race_event())


func start_race_event():
	# надпись «ГОНКА!» и через секунду переносимся на трассу
	if race.active or mini_active:
		return
	show_banner(t("race_event"))
	sound.chime([0, 7, 12, 19], -5.0)
	if vibro_on:
		Input.vibrate_handheld(120)
	get_tree().create_timer(1.4).timeout.connect(race.begin)


# Для проверки на компьютере: R — гонка, B — птица (только в отладке)
func _unhandled_input(event):
	if not OS.is_debug_build() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_R and not race.active:
		start_race_event()
	elif event.keycode == KEY_B and bird == null and not race.active:
		spawn_bird()


func crash():
	# встречка подъезжает вплотную и машины бьются передними углами
	threat_state = "impact"
	if threat_car == null:
		crash_impact()
		return
	var plen = player_car.get_meta("len", 4.0)
	var tlen = threat_car.get_meta("len", 4.0)
	var contact_z = -(plen / 2.0 + tlen / 2.0) + 0.3
	var tw = create_tween().set_parallel(true)
	tw.tween_property(threat_car, "position", Vector3(-0.5, 0, contact_z), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(player_car, "position:x", 0.4, 0.18)
	tw.chain().tween_callback(crash_impact)


func crash_impact():
	var penalty = km * CRASH_PENALTY
	km -= penalty
	show_toast(t("crash") + fmt(penalty) + " " + t("km"))
	sound.play("crash", -2.0)
	if vibro_on:
		Input.vibrate_handheld(400)
	shake = 0.9
	current_speed *= 0.4
	overtake_cooldown = 2.5
	var hit = Vector3(0.0, 0.2, -player_car.get_meta("len", 4.0) / 2.0)
	burst(hit, Color("#ffd166"), 30, 7.0, 0.07, 0.5, true)      # искры
	burst(hit, Color("#c9ced6"), 14, 2.5, 0.45, 1.1, false)     # дым
	# нашу машину отбрасывает и заносит, потом она возвращается в полосу
	var tw = create_tween()
	tw.tween_property(player_car, "rotation:y", deg_to_rad(28), 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(player_car, "position:x", LANE_X + 0.4, 0.3)
	tw.tween_property(player_car, "rotation:y", deg_to_rad(-14), 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player_car, "rotation:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(player_car, "position:x", LANE_X, 0.45).set_trans(Tween.TRANS_SINE)
	if threat_car:
		# встречку отбрасывает назад, разворачивает и уводит на её край дороги
		var tc = threat_car
		var tt = create_tween()
		tt.tween_property(tc, "position:z", tc.position.z - 1.6, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tt.parallel().tween_property(tc, "rotation:y", PI - 0.55, 0.25)
		tt.tween_property(tc, "position:x", -LANE_X - 0.35, 0.5).set_trans(Tween.TRANS_SINE)
		tt.parallel().tween_property(tc, "rotation:y", PI, 0.5)
		tt.tween_callback(func(): threat_state = "pass")


# вспышка частиц: искры, дым, перья, звёздочки
func burst(pos: Vector3, col: Color, amount: int, speed: float, sz: float, life: float, glow: bool):
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.position = pos
	p.direction = Vector3(0, 1, 0)
	p.spread = 85.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0 if glow else 0.5, 0)
	p.damping_min = 0.5
	p.damping_max = 2.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if not glow:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(col, 0.7)
	var mesh = SphereMesh.new()
	mesh.radius = sz
	mesh.height = sz * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = m
	p.mesh = mesh
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)


# всплывающая надпись в 3D (например «+120 KM» над птицей)
func float_text(pos: Vector3, text: String, col: Color):
	var l = Label3D.new()
	l.text = text
	if ui_font:
		l.font = ui_font
	l.font_size = 96
	l.outline_size = 22
	l.pixel_size = 0.012
	l.modulate = col
	l.outline_modulate = Color(0.08, 0.08, 0.12, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "position:y", pos.y + 2.5, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.tween_callback(l.queue_free)


# ================= ИВЕНТ: ПТИЦА =================
func update_bird(delta):
	if bird == null:
		if mini_active or popup_dim != null:
			return
		bird_timer -= delta
		if bird_timer <= 0:
			spawn_bird()
		return
	bird_t += delta / 7.0
	# плавный полёт дугой с покачиванием
	var x = lerpf(-11.0, 11.0, bird_t) * bird_dir
	var y = 2.5 + sin(bird_t * PI) * 0.8 + sin(anim_time * 3.0) * 0.25
	bird.position = Vector3(x, y, -9.5 + sin(bird_t * PI) * 1.5)
	var flap = sin(anim_time * 16.0)
	bird.get_node("WingL").rotation.x = flap * 0.9
	bird.get_node("WingR").rotation.x = -flap * 0.9
	bird.get_node("Body").position.y = -flap * 0.06
	bird.rotation.z = sin(anim_time * 3.0) * 0.12 * bird_dir
	var pulse = 0.5 + 0.5 * sin(anim_time * 7.0)
	bird_hint.scale = Vector3.ONE * (1.0 + 0.12 * pulse)
	bird_outline.albedo_color = Color("#fff3a0").lerp(Color("#ffb703"), pulse); bird_outline.grow_amount = 0.05 + 0.05 * pulse
	bird_ring.material_override.albedo_color.a = 0.35 + 0.45 * (1.0 - pulse)
	if bird_t >= 1.0:
		bird.queue_free()
		bird = null
		bird_timer = bird_delay()


func spawn_bird():
	bird_t = 0.0
	bird_dir = 1.0 if rng.randf() < 0.5 else -1.0
	bird_gold = rng.randf() < 0.12    # редкая золотая птица — награда втрое больше
	bird = Node3D.new()
	var col = Color("#ffcc33") if bird_gold else [Color("#ff8fab"), Color("#74c0fc"), Color("#8ce99a"), Color("#ffa94d")][rng.randi() % 4]
	var body = Node3D.new()
	body.name = "Body"
	bird.add_child(body)
	var torso = add_mesh(sphere(0.55), Vector3.ZERO, col, body, bird_gold, "paint")
	torso.scale = Vector3(1.15, 0.95, 0.95)
	var belly = add_mesh(sphere(0.42), Vector3(0.05 * bird_dir, -0.14, 0.18), Color("#fff4e6"), body)
	belly.scale = Vector3(1.0, 0.85, 0.8)
	add_mesh(sphere(0.4), Vector3(0.5 * bird_dir, 0.38, 0), col, body, bird_gold, "paint")     # голова
	add_mesh(sphere(0.1), Vector3(0.62 * bird_dir, 0.5, 0.3), Color.WHITE, body)               # глаз
	add_mesh(sphere(0.065), Vector3(0.66 * bird_dir, 0.5, 0.37), Color("#1b1b1b"), body)
	add_mesh(sphere(0.025), Vector3(0.68 * bird_dir, 0.53, 0.42), Color.WHITE, body, true)
	var cheek = add_mesh(sphere(0.08), Vector3(0.68 * bird_dir, 0.34, 0.28), Color("#ff6b9a"), body)
	cheek.scale = Vector3(1, 0.6, 0.4)
	var beak = add_mesh(cylinder(0.0, 0.1, 0.26), Vector3(0.94 * bird_dir, 0.34, 0), Color("#ff922b"), body)
	beak.rotation_degrees.z = -90 * bird_dir
	var crest = add_mesh(sphere(0.12), Vector3(0.45 * bird_dir, 0.8, 0), col.darkened(0.15), body)
	crest.scale = Vector3(0.6, 1.4, 0.5)
	for i in 3:   # хвост веером
		var f = add_mesh(sphere(0.22), Vector3(-0.7 * bird_dir, 0.1 + i * 0.05, (i - 1) * 0.16), col.darkened(0.12), body)
		f.scale = Vector3(1.6, 0.25, 0.6)
		f.rotation_degrees = Vector3((i - 1) * 20, 0, 15 * bird_dir)
	for side in [["WingL", 0.42], ["WingR", -0.42]]:
		var pivot = Node3D.new()
		pivot.name = side[0]
		pivot.position = Vector3(0, 0.18, side[1])
		bird.add_child(pivot)
		var wing = add_mesh(sphere(0.42), Vector3(0, 0, side[1] * 1.3), col.darkened(0.08), pivot, bird_gold, "paint")
		wing.scale = Vector3(0.95, 0.16, 1.4)
	# подсказка: надпись и пульсирующее кольцо
	bird_hint = Label3D.new()
	bird_hint.text = t("bird_hint")
	if ui_font:
		bird_hint.font = ui_font
	bird_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bird_hint.no_depth_test = true
	bird_hint.font_size = 80
	bird_hint.outline_size = 20
	bird_hint.pixel_size = 0.011
	bird_hint.modulate = Color("#ffd43b")
	bird_hint.outline_modulate = Color(0.1, 0.1, 0.15, 0.9)
	bird_hint.position = Vector3(0, 1.6, 0)
	bird.add_child(bird_hint)
	bird_ring = MeshInstance3D.new()
	bird_ring.mesh = torus(1.25, 1.42)
	var rm = StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.no_depth_test = true
	rm.albedo_color = Color(1.0, 0.85, 0.25, 0.6)
	bird_ring.material_override = rm
	bird_ring.rotation_degrees.x = 64   # повернуто к камере
	bird_ring.visible = false; bird.add_child(bird_ring)
	if bird_gold:
		# золотая птица оставляет блестящий след
		var trail = CPUParticles3D.new()
		trail.amount = 30
		trail.lifetime = 0.8
		trail.local_coords = false
		trail.gravity = Vector3(0, -1.0, 0)
		trail.spread = 180.0
		trail.initial_velocity_max = 0.6
		trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		trail.emission_sphere_radius = 0.4
		var tm = StandardMaterial3D.new()
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.albedo_color = Color("#fff3a0")
		var sm = SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		sm.material = tm
		trail.mesh = sm
		bird.add_child(trail)
	# невидимая «зона нажатия» вокруг птицы — по ней можно тапнуть
	var area = Area3D.new()
	area.name = "Tap"
	area.input_ray_pickable = true
	var shape = CollisionShape3D.new()
	var s = SphereShape3D.new()
	s.radius = 2.3
	shape.shape = s
	area.add_child(shape)
	area.input_event.connect(_on_bird_input)
	bird.add_child(area)
	bird.scale = Vector3.ONE * 1.15; outline_bird(bird)
	add_child(bird)
	update_bird(0.0)
	sound.play_later(0.0, "bird", -9.0, 1.0)
	sound.play_later(0.35, "bird", -11.0, 1.15)


func outline_bird(node: Node3D):
	# птица подсвечивается светящимся контуром (вместо кольца)
	bird_outline = StandardMaterial3D.new()
	bird_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bird_outline.cull_mode = BaseMaterial3D.CULL_FRONT
	bird_outline.grow = true
	bird_outline.grow_amount = 0.06
	bird_outline.albedo_color = Color("#fff3a0")
	for m in node.find_children("*", "MeshInstance3D", true, false):
		if m != bird_ring:
			m.material_overlay = bird_outline


func _on_bird_input(_camera, event, _pos, _normal, _idx):
	var pressed = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or bird == null:
		return
	var mult = 3.0 if bird_gold else 1.0
	var bonus = income_per_sec() * BIRD_BONUS_SECONDS * (1.0 + 0.25 * ws_level("bird")) * mult
	var nut_gain = 0   # гайки теперь только из ящиков и за донат
	km += bonus
	nuts += nut_gain
	show_toast(t("bird_gold" if bird_gold else "bird") + fmt(bonus) + " " + t("km"))
	sound.chime([12, 16, 19, 24, 28] if bird_gold else [12, 16, 19, 24], -6.0)
	if vibro_on:
		Input.vibrate_handheld(50)
	var b = bird
	var col = Color("#ffcc33") if bird_gold else Color("#ffffff")
	burst(b.position, col, 22, 5.0, 0.12, 0.9, false)               # перья
	burst(b.position, Color("#ffe066"), 18, 6.0, 0.07, 0.6, true)  # звёздочки
	float_text(b.position + Vector3(0, 1.0, 0), "+" + fmt(bonus) + " " + t("km"), Color("#ffd43b"))
	bird = null
	bird_timer = bird_delay()
	if b.has_node("Tap"):
		b.get_node("Tap").queue_free()
	bird_hint.visible = false
	bird_ring.visible = false
	# птица радостно кувыркается и улетает вверх
	var tw = create_tween().set_parallel(true)
	tw.tween_property(b, "position", b.position + Vector3(2.5 * bird_dir, 6.0, -3.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "rotation:z", TAU * bird_dir, 0.7)
	tw.tween_property(b, "scale", Vector3.ONE * 0.4, 0.7)
	tw.chain().tween_callback(b.queue_free)


# ================= СУНДУКИ, ГАРАЖ, ТЮНИНГ, МАСТЕРСКАЯ =================
func roll_chest() -> String:
	var total = 0
	for ct in CHEST_ORDER:
		total += chest_types[ct]["chance"]
	var r = rng.randi_range(1, total)
	for ct in CHEST_ORDER:
		r -= chest_types[ct]["chance"]
		if r <= 0:
			return ct
	return "parts"


func unfinished_exclusives() -> Array:
	var list = []
	for id in Cars.ORDER:
		if Cars.CARS[id]["exclusive"] and not owned_cars.has(id):
			list.append(id)
	return list


func car_name(id: String) -> String:
	return t("car_" + id)


func open_chest(ct: String):
	if chests[ct] <= 0:
		return
	chests[ct] -= 1
	var lines = []
	match ct:
		"parts":
			add_km_reward(income_per_sec() * 30.0, lines)
			add_spare(2, lines)
		"tools":
			add_km_reward(income_per_sec() * 60.0, lines)
			add_spare(3, lines)
			add_nuts(1, lines)
		"carparts":
			var list = unfinished_exclusives()
			add_parts(4, list[rng.randi() % list.size()] if list.size() > 0 else "", lines)
			add_spare(1, lines)
			add_nuts(2, lines)
		"car":
			var list = unfinished_exclusives()
			if list.size() > 0:
				var id = list[rng.randi() % list.size()]
				add_parts(Cars.CARS[id]["parts"] - parts[id], id, lines)
			else:
				add_km_reward(income_per_sec() * 750.0, lines)
			add_nuts(5, lines)
	sound.chime([0, 4, 7, 11, 14, 19], -6.0)
	save_game()
	show_chest_popup(ct, lines)


func add_km_reward(amount: float, lines: Array):
	km += amount
	lines.append("+" + fmt(amount) + " " + t("km"))


func add_nuts(n: int, lines: Array):
	nuts += n
	lines.append(t("nuts_got") + str(n))


func add_spare(count: int, lines: Array):
	var got = {}
	for i in count:
		var p = PART_ORDER[rng.randi() % PART_ORDER.size()]
		spare[p] += 1
		got[p] = got.get(p, 0) + 1
	var parts_text = []
	for p in got:
		parts_text.append(t("part_" + p) + " x" + str(got[p]))
	lines.append(t("spare_got") + ", ".join(PackedStringArray(parts_text)))


func add_parts(count: int, car_id: String, lines: Array):
	var got = {}
	for i in count:
		var id = car_id
		if id == "" or owned_cars.has(id):
			var list = unfinished_exclusives()
			if list.is_empty():
				add_km_reward(income_per_sec() * 45.0, lines)
				continue
			id = list[rng.randi() % list.size()]
		parts[id] += 1
		got[id] = got.get(id, 0) + 1
		if parts[id] >= Cars.CARS[id]["parts"]:
			owned_cars.append(id)
			lines.append(t("new_car") + car_name(id))
	for id in got:
		lines.append(t("part") + ": " + car_name(id) + " x" + str(got[id]) + "  (" + str(parts[id]) + "/" + str(Cars.CARS[id]["parts"]) + ")")


func _on_car_pressed(id: String):
	var c = Cars.CARS[id]
	if owned_cars.has(id):
		if selected_car != id:
			selected_car = id
			replace_player_car()
			sound.play("click", -6.0)
	elif not c["exclusive"] and km >= c["price"]:
		km -= c["price"]
		owned_cars.append(id)
		selected_car = id
		replace_player_car()
		sound.chime([0, 4, 7, 12], -6.0)
		show_toast(t("bought") + car_name(id))
	else:
		sound.play("fail", -10.0)
		return
	tune_title.text = t("tuning_for") + car_name(selected_car)
	refresh_paint()
	save_game()


func _on_part_pressed(p: String):
	if part_level(p) >= PART_MAX:
		return
	var cost = 0   # детали больше не стоят KM
	if spare[p] < part_need(p):   # тюнинг только за запчасти из ящиков
		sound.play("fail", -10.0)
		return
	km -= cost
	spare[p] -= part_need(p)
	if not tune.has(selected_car):
		tune[selected_car] = {}
	var before = car_opts()
	tune[selected_car][p] = part_level(p) + 1
	if car_opts() != before:
		replace_player_car()   # поменялись диски или появился огонь турбо
	sound.chime([0, 4, 7], -8.0)
	save_game()


func _on_ws_pressed(id: String):
	var w = workshop[id]
	if w["level"] >= w["max"]:
		return
	var cost = get_ws_cost(id)
	if nuts < cost:
		sound.play("fail", -10.0)
		return
	nuts -= cost
	w["level"] += 1
	sound.chime([0, 4, 7, 12], -8.0)
	save_game()


func _on_paint_pressed(col: String):
	var owned = owned_paints.get(selected_car, [])
	if col != Cars.CARS[selected_car]["color"] and not owned.has(col):
		var price = paint_price()
		if km < price:
			sound.play("fail", -10.0)
			return
		km -= price
		owned.append(col)
		owned_paints[selected_car] = owned
		sound.chime([0, 4, 7, 12], -8.0)
	else:
		sound.play("click", -8.0)
	paint[selected_car] = col
	replace_player_car()
	refresh_paint()
	save_game()


func replace_player_car():
	var x = LANE_X
	if player_car:
		x = player_car.position.x
		player_car.queue_free()
	player_car = Cars.build(self, selected_car, Color(car_color()), car_opts())
	player_car.position = Vector3(x, 0, 0)
	add_child(player_car)
	# фара нашей машины — с тенями
	headlight = last_light
	headlight.shadow_enabled = true
	headlight.spot_range = 45.0
	headlight.spot_angle = 30.0


# ================= ПОСТРОЕНИЕ МИРА =================
func setup_world():
	for n in ["Road", "Car"]:
		if has_node(n):
			get_node(n).visible = false

	sun = get_node("DirectionalLight3D")
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.directional_shadow_max_distance = 70.0

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.04; env.tonemap_exposure = 0.92
	env.adjustment_contrast = 1.04
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.15; env.fog_mode = Environment.FOG_MODE_DEPTH; env.fog_depth_curve = 1.6   # дымка вдали скрывает появление объектов
	# сглаживание: убирает «лесенку» и мерцание
	get_viewport().msaa_3d = Viewport.MSAA_4X
	# чтобы можно было тапнуть по птице
	get_viewport().physics_object_picking = true
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	cam = get_node("Camera3D")
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 60; cam.near = 0.25; cam.far = 1500.0
	cam.rotation_degrees = Vector3(-26, 0, 0)

	var info = Biomes.BIOMES[biome]
	# --- земля и дорога ---
	var mid_z = (NEAR_Z + FAR_Z) / 2.0 - 20.0
	var long = LOOP_LEN + 60.0
	grass_mat = toon(Color(info["ground"]))
	grass_mat.albedo_texture = noise_tex(Color("#e9f5e4"), Color("#ffffff"), 0.02)
	grass_mat.uv1_scale = Vector3(70, 70, 1)
	grass_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	add_plane(Vector2(1400, 1400), Vector3(0, -0.5, -500), grass_mat)

	road_mat = toon(Color("#5a6273"))
	road_mat.albedo_texture = noise_tex(Color("#eef0f4"), Color("#ffffff"), 0.08)
	road_mat.uv1_scale = Vector3(1, long / 7.0, 1)
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	add_plane(Vector2(ROAD_WIDTH, long), Vector3(0, -0.45, mid_z), road_mat)

	shoulder_mat = toon(Color(info["shoulder"]))
	for s in [-1, 1]:
		# бордюр и полоска обочины вдоль дороги
		rbox(Vector3(0.35, 0.16, long), Vector3(s * (ROAD_WIDTH / 2 + 0.1), -0.42, mid_z), Color("#f1ede4"), null, false, "matte", 0.6)
		add_plane(Vector2(1.4, long), Vector3(s * (ROAD_WIDTH / 2 + 0.95), -0.47, mid_z), shoulder_mat)
		rbox(Vector3(0.15, 0.03, long), Vector3(s * (ROAD_WIDTH / 2 - 0.35), -0.44, mid_z), Color("#fbfaf5"), null, false, "matte", 0.5)

	for i in int(LOOP_LEN / 8.0):
		scrolling.append(rbox(Vector3(0.2, 0.03, 3.0), Vector3(0, -0.44, NEAR_Z - i * 8.0), Color("#fbfaf5"), null, false, "matte", 0.5))

	# столбики вдоль обочины (бело-красные «леденцы»)
	for i in int(LOOP_LEN / 8.0):
		for s in [-1, 1]:
			var post = Node3D.new()
			add_mesh(capsule(0.1, 0.9), Vector3(0, 0.0, 0), Color("#ffffff"), post)
			add_mesh(capsule(0.11, 0.25), Vector3(0, 0.25, 0), Color("#ef476f"), post)
			post.position = Vector3(s * (ROAD_WIDTH / 2 + 1.7), -0.1, NEAR_Z - i * 8.0 - s * 4.0)
			add_child(post)
			scrolling.append(post)

	for i in int(LOOP_LEN / 40.0):
		var side = 1 if i % 2 == 0 else -1
		var lamp = make_lamp()
		lamp.position = Vector3(side * (ROAD_WIDTH / 2 + 2.2), -0.5, NEAR_Z - i * 40.0)
		if side < 0:
			lamp.rotation.y = PI
		add_child(lamp)
		scrolling.append(lamp)

	# декор вдоль дороги — меняется вместе с биомом
	for i in 140:
		var side = 1 if i % 2 == 0 else -1
		scrolling.append(make_deco(side, NEAR_Z - rng.randf() * LOOP_LEN))

	backdrop = Biomes.backdrop(self, biome, rng)
	add_child(backdrop)

	# пушистые облака
	for i in 9:
		var c = make_cloud()
		c.position = Vector3(rng.randf_range(-90, 90), rng.randf_range(28, 45), rng.randf_range(-220, -140))
		add_child(c)
		clouds.append(c)

	add_sky_extras(); rain_fx = make_rain()
	wind_fx = make_wind()

	replace_player_car()
	race = Race.new()
	add_child(race)
	race.setup(self); showroom = Showroom.new(); add_child(showroom); showroom.setup(self)
	update_environment(0.0)


func make_deco(side: int, z: float) -> Node3D:
	var d = Biomes.deco(self, biome, rng)
	d.set_meta("deco", true)
	d.set_meta("side", side)
	d.position = Vector3(side * rng.randf_range(d.get_meta("min_x"), d.get_meta("max_x")), -0.5, z)
	d.rotation.y = rng.randf() * TAU
	add_child(d)
	return d


func add_sky_extras():
	# воздушные шары плывут по небу вместе с облаками
	for i in 4:
		var b = make_balloon()
		b.position = Vector3(rng.randf_range(-80, 80), rng.randf_range(18, 32), rng.randf_range(-170, -110))
		add_child(b)
		clouds.append(b)
	# звёзды — видны только ночью
	stars = Node3D.new()
	for i in 160:
		var a = rng.randf() * TAU
		var e = rng.randf_range(0.12, 1.2)
		var d = 900.0
		var pos = Vector3(cos(a) * cos(e) * d, sin(e) * d, -absf(sin(a)) * cos(e) * d - 100.0)
		add_mesh(sphere(snappedf(rng.randf_range(1.2, 2.8), 0.4)), pos, Color("#fff8e1"), stars, true); make_mat(Color("#fff8e1"), true).disable_fog = true
	stars.visible = false
	add_child(stars)


func make_balloon() -> Node3D:
	# мультяшный воздушный шар в полоску с корзинкой
	var b = Node3D.new()
	var pairs = [[Color("#ef476f"), Color("#ffd166")], [Color("#06d6a0"), Color("#ffffff")], [Color("#118ab2"), Color("#ffd166")], [Color("#8338ec"), Color("#ff7f11")]]
	var c = pairs[rng.randi() % pairs.size()]
	add_mesh(sphere(2.9), Vector3.ZERO, c[0], b, false, "paint")
	for i in 6:
		var band = add_mesh(sphere(3.0), Vector3.ZERO, c[1], b, false, "paint")
		band.scale = Vector3(0.28, 1.0, 1.0)
		band.rotation_degrees.y = i * 30.0
	add_mesh(cylinder(1.3, 0.5, 1.6), Vector3(0, -3.3, 0), c[0].darkened(0.15), b)
	for sx in [-0.45, 0.45]:
		for sz in [-0.45, 0.45]:
			add_mesh(cylinder(0.03, 0.03, 1.4), Vector3(sx, -4.6, sz), Color("#5c4033"), b)
	rbox(Vector3(1.1, 0.8, 1.1), Vector3(0, -5.6, 0), Color("#a0522d"), b, false, "matte", 0.3)
	b.scale = Vector3.ONE * rng.randf_range(0.9, 1.3)
	return b


func make_rain() -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = 800
	p.lifetime = 0.7
	p.emitting = false
	p.position = Vector3(0, 12, -22)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 0.5, 30)
	p.direction = Vector3(0, -1, 0)
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.9, 1.0, 0.4)
	var b = BoxMesh.new()
	b.size = Vector3(0.03, 0.6, 0.03)
	b.material = m
	p.mesh = b
	p.particle_flag_align_y = true
	p.spread = 3.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 24.0
	add_child(p)
	return p


func make_wind() -> CPUParticles3D:
	# полосы ветра по бокам на большой скорости
	var p = CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.5
	p.emitting = false
	p.position = Vector3(0, 1.5, -20)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7, 2.5, 18)
	p.direction = Vector3(0, 0, 1)
	p.spread = 0.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.particle_flag_align_y = true
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.35)
	var b = BoxMesh.new()
	b.size = Vector3(0.03, 2.2, 0.03)
	b.material = m
	p.mesh = b
	add_child(p)
	return p


func make_cloud() -> Node3D:
	var c = Node3D.new()
	var white = Color("#ffffff")
	add_mesh(sphere(4.0), Vector3(0, 0, 0), white, c)
	add_mesh(sphere(3.0), Vector3(4.0, -0.8, 0.5), white, c)
	add_mesh(sphere(3.2), Vector3(-4.0, -0.6, -0.3), white, c)
	add_mesh(sphere(2.6), Vector3(1.5, 2.2, 0), white, c)
	c.scale = Vector3(1, 0.75, 0.8) * rng.randf_range(0.8, 1.4)
	return c


# конус света фар (вызывается из cars.gd для каждой машины)
func add_car_light(car: Node3D, zf: float, y: float):
	var l = SpotLight3D.new()
	l.position = Vector3(0, y + 0.1, zf - 0.1)
	l.rotation_degrees.x = -7
	l.spot_range = 28.0
	l.spot_angle = 32.0
	l.spot_attenuation = 0.9
	l.light_color = Color("#fff1c9")
	l.light_energy = 0.0
	l.visible = false
	car.add_child(l)
	car_lights.append(l)
	last_light = l


func register_flasher(node: Node3D, phase: int):
	flashers.append([node, phase])


func noise_tex(c1: Color, c2: Color, freq: float) -> NoiseTexture2D:
	var n = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = freq
	n.fractal_octaves = 3
	var g = Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	tex.color_ramp = g
	return tex


func move_scenery(dz, delta):
	for i in scrolling.size():
		var o = scrolling[i]
		o.position.z += dz
		if o.position.z > NEAR_Z:
			if o.has_meta("deco"):
				# декор за спиной заменяем новым — из текущего биома
				var side = o.get_meta("side")
				var nz = o.position.z - LOOP_LEN
				o.queue_free()
				scrolling[i] = make_deco(side, nz)
			else:
				o.position.z -= LOOP_LEN
	# текстуры дороги и травы «едут» вместе с миром
	road_mat.uv1_offset.y = fposmod(road_mat.uv1_offset.y - dz / 7.0, 1.0)
	grass_mat.uv1_offset.y = fposmod(grass_mat.uv1_offset.y - dz / 20.0, 1.0)
	# облака медленно плывут
	for c in clouds:
		c.position.x += delta * 1.5
		if c.position.x > 110:
			c.position.x = -110


# ================= БИОМЫ И ПРИДОРОЖНЫЕ ЗДАНИЯ =================
func update_biome(delta):
	biome_timer -= delta
	if biome_timer > 0:
		return
	biome_timer = rng.randf_range(50.0, 100.0)
	if rng.randf() < 0.6:
		change_biome(Biomes.pick(rng, biome))


func change_biome(new_biome: String):
	biome = new_biome
	var info = Biomes.BIOMES[biome]
	var tw = create_tween().set_parallel(true)
	tw.tween_property(grass_mat, "albedo_color", Color(info["ground"]), 4.0)
	tw.tween_property(shoulder_mat, "albedo_color", Color(info["shoulder"]), 4.0)
	if backdrop:
		backdrop.queue_free()
	backdrop = Biomes.backdrop(self, biome, rng)
	add_child(backdrop)
	show_banner(t("biome_" + biome))


func update_landmarks(dz, delta):
	landmark_timer -= delta
	if landmark_timer <= 0:
		landmark_timer = rng.randf_range(18.0, 35.0)
		var kinds = Biomes.LANDMARKS
		var lm = Biomes.landmark(self, kinds[rng.randi() % kinds.size()], rng)
		var side = 1 if rng.randf() < 0.5 else -1
		lm.position = Vector3(side * (ROAD_WIDTH / 2 + 4.6), -0.5, FAR_Z - 10.0)
		if side < 0:
			lm.rotation.y = PI
		add_child(lm)
		landmarks.append(lm)
	for lm in landmarks.duplicate():
		lm.position.z += dz
		if lm.position.z > NEAR_Z + 20.0:
			landmarks.erase(lm)
			lm.queue_free()


func show_banner(text: String):
	banner.text = text
	banner.modulate.a = 0.0
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.7, 0.7)
	var tw = create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)


# ================= ПОГОДА И ВРЕМЯ СУТОК =================
func pick_weather():
	var total = 0
	for w in weathers:
		total += weathers[w]["chance"]
	var r = rng.randi_range(1, total)
	for w in weathers:
		r -= weathers[w]["chance"]
		if r <= 0:
			weather = w
			break
	weather_timer = rng.randf_range(70.0, 140.0)


func sample_sky(tt: float) -> Array:
	for i in sky_keys.size() - 1:
		var a = sky_keys[i]
		var b = sky_keys[i + 1]
		if tt >= a[0] and tt <= b[0]:
			var f = (tt - a[0]) / (b[0] - a[0])
			return [a[1].lerp(b[1], f), a[2].lerp(b[2], f), a[3].lerp(b[3], f), lerpf(a[4], b[4], f), lerpf(a[5], b[5], f)]
	var l = sky_keys[0]
	return [l[1], l[2], l[3], l[4], l[5]]


func update_environment(delta):
	day_time = fposmod(day_time + delta / DAY_LENGTH, 1.0)
	weather_timer -= delta
	if weather_timer <= 0:
		pick_weather()
	var wt = weathers[weather]
	if wt["chance"] == 0:
		weather = "clear"
		wt = weathers[weather]
	var k = clampf(delta * 0.2, 0.0, 1.0)
	if delta == 0.0:
		k = 1.0
	cloud = lerpf(cloud, wt["cloud"], k)
	rain_amt = lerpf(rain_amt, wt["rain"], k)
	fog_d = lerpf(fog_d, wt["fog"], k)

	var s = sample_sky(day_time)
	var light = s[4]
	night = clampf((0.6 - light) / 0.35, 0.0, 1.0)
	var grey_top = Color("#7d8a9a").darkened(1.0 - light)
	var grey_hor = Color("#b6c0cb").darkened(1.0 - light)
	var top: Color = s[0].lerp(grey_top, cloud * 0.8)
	var hor: Color = s[1].lerp(grey_hor, cloud * 0.8)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = hor.darkened(0.4)
	env.fog_light_color = hor
	env.fog_density = 1.0; env.fog_depth_end = lerpf(360.0, 130.0, clampf((fog_d - 0.0015) / 0.0265, 0.0, 1.0)); env.fog_depth_begin = env.fog_depth_end * 0.22
	env.ambient_light_energy = light * (1.0 - 0.3 * cloud)

	sun.light_color = s[2]
	sun.light_energy = s[3] * (1.0 - 0.6 * cloud)
	var elev = sin((day_time - 0.25) * TAU)
	sun.rotation_degrees = Vector3(-lerpf(20.0, 70.0, clampf(elev, 0.0, 1.0)), -35.0, 0.0)

	for m in glow_mats:
		m.emission_energy_multiplier = 1.0 + 3.0 * night
	env.glow_intensity = 0.15 + 0.75 * night
	# фары и фонари: конусы света включаются в темноте, тумане и дожде
	dark = clampf(night * 1.3 + cloud * 0.25 + (fog_d - 0.003) * 8.0, 0.0, 1.0)
	var on = dark > 0.15
	for l in car_lights.duplicate():
		if not is_instance_valid(l):
			car_lights.erase(l)
			continue
		l.visible = on
		l.light_energy = (5.0 if l == headlight else 2.5) * dark
	for l in lamp_lights:
		l.visible = night > 0.2
		l.light_energy = 4.0 * night

	road_mat.roughness = lerpf(0.9, 0.25, rain_amt)
	road_mat.metallic = 0.25 * rain_amt
	road_mat.albedo_color = Color("#5a6273").darkened(0.2 * rain_amt)

	rain_fx.position.x = race.position.x if race and race.active else 0.0
	rain_fx.emitting = rain_amt > 0.35
	rain_fx.gravity = Vector3(0, -20, current_speed * VIS * 1.5)

	sound.set_rain(rain_amt)
	sound.set_wind(0.4 + 0.6 * cloud)
	sound.birds_enabled = night < 0.3 and rain_amt < 0.2; stars.visible = night > 0.45 and cloud < 0.6


func time_name() -> String:
	if night > 0.6:
		return "night"
	if day_time < 0.45:
		return "morning"
	if day_time < 0.68:
		return "day"
	return "evening"


func weather_icon_name() -> String:
	if weather == "clear":
		return "moon" if night > 0.6 else "sun"
	return weathers[weather]["icon"]


func make_lamp() -> Node3D:
	var lamp = Node3D.new()
	add_mesh(capsule(0.1, 4.4), Vector3(0, 2.0, 0), Color("#6c7a91"), lamp)
	var arm = add_mesh(capsule(0.07, 1.4), Vector3(-0.55, 4.1, 0), Color("#6c7a91"), lamp)
	arm.rotation_degrees.z = 90
	var head = add_mesh(sphere(0.32), Vector3(-1.15, 4.0, 0), Color("#fff1b8"), lamp, true)
	head.scale = Vector3(1.2, 0.6, 1.0)
	# конус света вниз
	var l = SpotLight3D.new()
	l.position = Vector3(-1.15, 3.9, 0)
	l.rotation_degrees.x = -90
	l.spot_range = 7.0
	l.spot_angle = 45.0
	l.light_color = Color("#ffd9a0")
	l.visible = false
	lamp.add_child(l)
	lamp_lights.append(l)
	return lamp


# ---------- помощники для 3D ----------
func toon(color: Color) -> StandardMaterial3D:
	# «мультяшный» материал: мягкие ступенчатые тени и лёгкая подсветка краёв
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.9
	return m


func make_mat(color: Color, glow := false, kind := "matte") -> StandardMaterial3D:
	var key = color.to_html() + str(glow) + kind
	if mat_cache.has(key):
		return mat_cache[key]
	var m = toon(color)
	match kind:
		"paint":
			m.roughness = 0.45
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.6
		"glass":
			m.roughness = 0.25
			m.metallic = 0.3
			m.rim_enabled = true
			m.rim = 0.4
		"chrome":
			m.roughness = 0.35
			m.metallic = 0.6
		"rubber":
			m.roughness = 1.0
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
		glow_mats.append(m)
	mat_cache[key] = m
	return m

func add_mesh(mesh: Mesh, pos: Vector3, color: Color, parent: Node = null, glow := false, kind := "matte") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = make_mat(color, glow, kind)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi

# скруглённая коробка (как кубик из пластилина): roundness 0 — острые углы, 1 — шар
func rbox(size: Vector3, pos: Vector3, color: Color, parent: Node = null, glow := false, kind := "matte", roundness := 0.35) -> MeshInstance3D:
	return add_mesh(rounded_box_mesh(size, roundness), pos, color, parent, glow, kind)

func rounded_box_mesh(size: Vector3, roundness: float) -> ArrayMesh:
	var key = str(size) + "_" + str(roundness)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	var arr = sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var h = size / 2.0
	var e = clampf(roundness, 0.05, 1.0)
	for i in verts.size():
		var v = verts[i]
		verts[i] = Vector3(spow(v.x, e) * h.x, spow(v.y, e) * h.y, spow(v.z, e) * h.z)
		norms[i] = Vector3(spow(v.x, 2.0 - e) / h.x, spow(v.y, 2.0 - e) / h.y, spow(v.z, 2.0 - e) / h.z).normalized()
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = null
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh_cache[key] = m
	return m

func spow(x: float, p: float) -> float:
	return signf(x) * pow(absf(x), p)

func add_plane(size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var pm = PlaneMesh.new()
	pm.size = size
	var mi = MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 20
	return c

func sphere(r: float) -> SphereMesh:
	var key = "s" + str(r)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 24
	s.rings = 12
	mesh_cache[key] = s
	return s

func capsule(r: float, h: float) -> CapsuleMesh:
	var key = "c" + str(r) + "_" + str(h)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var c = CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 16
	c.rings = 6
	mesh_cache[key] = c
	return c

func torus(inner: float, outer: float) -> TorusMesh:
	var key = "t" + str(inner) + "_" + str(outer)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var tm = TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 24
	tm.ring_segments = 12
	mesh_cache[key] = tm
	return tm


# ================= СТИЛЬ ИНТЕРФЕЙСА =================
const UI_BG = Color("#141925")        # фон панелей
const UI_CARD = Color("#212a3c")      # фон карточек
const UI_TEXT2 = Color("#9aa6bf")     # второстепенный текст
const ACCENT = Color("#ffc43d")       # главный акцент (жёлтый)
const DARK_TEXT = Color("#22180a")

var chip_styles = {}


func make_theme() -> Theme:
	# Жирный округлый шрифт для всей игры: res://fonts/main.ttf (Nunito).
	# Если файла нет, берём системный.
	var th = Theme.new()
	var f: Font
	if ResourceLoader.exists("res://fonts/main.ttf"):
		var ff: FontFile = load("res://fonts/main.ttf")
		ff.multichannel_signed_distance_field = false; ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY; ff.hinting = TextServer.HINTING_LIGHT   # гладкие буквы без «резаных» краёв
		var fv = FontVariation.new()
		fv.base_font = ff
		# у Nunito толщина настраивается: 800 = ExtraBold
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		f = fv
	else:
		var sf = SystemFont.new()
		sf.font_names = PackedStringArray(["Nunito", "Montserrat", "Segoe UI", "Roboto", "Arial"])
		sf.font_weight = 800
		sf.multichannel_signed_distance_field = true
		f = sf
	ui_font = f
	th.default_font = f
	th.default_font_size = 22
	return th


func icon(icon_name: String, col: Color, sz: float) -> Control:
	return Icons.new().setup(icon_name, col, sz)


func box(bg: Color, radius := 24, margin := 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	s.anti_aliasing_size = 0.6
	return s


func outlined(bg: Color, border: Color, radius := 24, width := 3) -> StyleBoxFlat:
	var s = box(bg, radius)
	s.set_border_width_all(width)
	s.border_color = border
	return s


func solid(col: Color, lip: int, radius := 24) -> StyleBoxFlat:
	# яркая кнопка с чёткой «объёмной» нижней гранью (без размытых теней)
	var s = box(col, radius)
	s.border_width_bottom = lip
	s.border_color = col.darkened(0.32)
	return s


func style_card(b: Button, accent: Color):
	# тёмная карточка с цветной рамкой
	var a = Color(accent.r, accent.g, accent.b, 0.55)
	b.add_theme_stylebox_override("normal", outlined(UI_CARD, a))
	b.add_theme_stylebox_override("hover", outlined(UI_CARD.lightened(0.04), Color(a, 0.8)))
	b.add_theme_stylebox_override("pressed", outlined(UI_CARD.darkened(0.15), accent))
	b.add_theme_stylebox_override("disabled", outlined(UI_CARD, Color(1, 1, 1, 0.08)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE


func style_solid(b: Button, col: Color, text_col := Color.WHITE):
	b.add_theme_stylebox_override("normal", solid(col, 6))
	b.add_theme_stylebox_override("hover", solid(col.lightened(0.06), 6))
	b.add_theme_stylebox_override("pressed", solid(col.darkened(0.08), 2))
	b.add_theme_stylebox_override("disabled", solid(Color("#3a4256"), 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, text_col)


func make_button(text: String, col: Color, font_size: int, height: int, text_col := Color.WHITE) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", font_size)
	style_solid(b, col, text_col)
	b.pressed.connect(func(): sound.play("click", -10.0))
	return b


# кнопка с иконкой слева и текстом
func make_icon_button(icon_name: String, text: String, col: Color, height: int, text_col := Color.WHITE) -> Array:
	var b = make_button("", col, 24, height, text_col)
	var h = HBoxContainer.new()
	fill_rect(h, 22, 8, 22, 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	ignore_mouse(h)
	b.add_child(h)
	h.add_child(icon(icon_name, text_col, 34))
	var l = make_label(text, 24, text_col)
	h.add_child(l)
	return [b, l]


func make_label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	return l


func make_chip(text_size: int, icon_name := "") -> Dictionary:
	# цветная плашка с надписью (цена, статус), иногда с иконкой
	var p = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	ignore_mouse(h)
	p.add_child(h)
	var ic: Control = null
	if icon_name != "":
		ic = icon(icon_name, DARK_TEXT, text_size)
		h.add_child(ic)
	var l = make_label("", text_size, DARK_TEXT)
	h.add_child(l)
	return {"panel": p, "label": l, "icon": ic}


func icon_circle(icon_name: String, col: Color, size: int) -> PanelContainer:
	var p = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", box(col, int(size / 2.0), int(size * 0.2)))
	if icon_name != "":
		p.add_child(icon(icon_name, Color.WHITE, size * 0.6))
	return p


func ignore_mouse(c: Control):
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func fill_rect(c: Control, left := 0.0, top := 0.0, right := 0.0, bottom := 0.0):
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = left
	c.offset_top = top
	c.offset_right = -right
	c.offset_bottom = -bottom


func make_scroll(content: Control) -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


func square_hud_button(icon_name: String, on_press: Callable) -> Button:
	var b = Button.new()
	var sb = box(Color(0.07, 0.09, 0.14, 0.85), 26, 0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", box(Color(0.15, 0.18, 0.26, 0.95), 26, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	var ic = icon(icon_name, Color.WHITE, 44)
	fill_rect(ic, 20, 20, 20, 20)
	b.add_child(ic)
	b.pressed.connect(on_press)
	b.pressed.connect(func(): sound.play("click", -10.0))
	return b


# ================= ИНТЕРФЕЙС =================
func setup_ui():
	var canvas = $CanvasLayer
	for c in canvas.get_children():
		c.queue_free()
	cards.clear()
	part_cards.clear()
	ws_cards.clear()
	paint_buttons.clear()
	car_rows.clear()
	chest_cards.clear()
	tab_buttons.clear()
	pages.clear()
	popup_dim = null
	chip_styles = {
		"accent": box(ACCENT, 14, 6),
		"green": box(Color("#3ddc97"), 14, 6),
		"grey": box(Color("#3a4256"), 14, 6),
		"gold": box(Color("#2c2a20"), 14, 6),
	}
	chip_styles["gold"].set_border_width_all(2)
	chip_styles["gold"].border_color = ACCENT

	ui_root = Control.new()
	ui_root.theme = make_theme()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)

	# --- верх: слева лидерборд, по центру счётчик, справа настройки ---
	lb_btn = square_hud_button("podium", show_leaderboard)
	lb_btn.offset_left = 24
	lb_btn.offset_right = 112
	lb_btn.offset_top = 24
	lb_btn.offset_bottom = 112
	ui_root.add_child(lb_btn)

	settings_btn = square_hud_button("gear", show_settings)
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.offset_left = -112
	settings_btn.offset_right = -24
	settings_btn.offset_top = 24
	settings_btn.offset_bottom = 112
	ui_root.add_child(settings_btn); add_hud_buttons()

	var top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", box(Color(0.07, 0.09, 0.14, 0.85), 26, 10))
	top.anchor_right = 1.0
	top.offset_left = 124
	top.offset_right = -124
	top.offset_top = 24
	ui_root.add_child(top)
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	top.add_child(tv)
	km_label = make_label("", 46, Color.WHITE)
	speed_label = make_label("", 17, UI_TEXT2)
	tv.add_child(km_label)
	tv.add_child(speed_label)
	var nut_row = HBoxContainer.new()
	nut_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nut_row.add_theme_constant_override("separation", 6)
	tv.add_child(nut_row)
	nut_row.add_child(icon("nut", ACCENT, 20))
	nuts_label = make_label("", 18, ACCENT)
	nut_row.add_child(nuts_label)

	var pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", box(Color(0.07, 0.09, 0.14, 0.65), 18, 8))
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.offset_top = 172
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ignore_mouse(pill)
	ui_root.add_child(pill)
	var wrow = HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 8)
	pill.add_child(wrow)
	weather_icon = icon("sun", Color.WHITE, 22)
	wrow.add_child(weather_icon)
	weather_label = make_label("", 18, Color.WHITE)
	wrow.add_child(weather_label)

	toast = make_label("", 28, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 10)
	toast.anchor_right = 1.0
	toast.offset_top = 335
	toast.modulate.a = 0.0
	ui_root.add_child(toast)

	# название биома посередине экрана
	banner = make_label("", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 18)
	banner.anchor_right = 1.0
	banner.anchor_top = 0.36
	banner.anchor_bottom = 0.36
	banner.offset_bottom = 90
	banner.modulate.a = 0.0
	ui_root.add_child(banner)

	# --- кнопка обгона ---
	var ob = make_icon_button("overtake", t("overtake"), Color("#ffb703"), 104, DARK_TEXT); overtake_btn = ob[0]; ob[1].add_theme_font_size_override("font_size", 40)
	overtake_btn.anchor_left = 0.5
	overtake_btn.anchor_right = 0.5
	overtake_btn.offset_left = -190
	overtake_btn.offset_right = 190
	overtake_btn.offset_top = 222
	overtake_btn.offset_bottom = 322
	overtake_btn.visible = false
	overtake_btn.pressed.connect(_on_overtake_pressed)
	ui_root.add_child(overtake_btn); style_overtake(overtake_btn)

	# --- нижняя панель с вкладками ---
	bottom_panel = PanelContainer.new()
	var bs = box(UI_BG, 0, 18)
	bs.corner_radius_top_left = 34
	bs.corner_radius_top_right = 34
	bs.content_margin_bottom = 30
	bottom_panel.add_theme_stylebox_override("panel", bs)
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui_root.add_child(bottom_panel)
	var bv = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 14)
	bottom_panel.add_child(bv)

	# переключатель вкладок
	var seg = PanelContainer.new()
	seg.add_theme_stylebox_override("panel", box(Color("#0c1018"), 22, 5))
	bv.add_child(seg)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	seg.add_child(tabs)
	for id in ["upgrades", "tuning", "workshop", "garage", "chests"]:
		var tb = Button.new()
		tb.text = t("tab_" + id)
		tb.custom_minimum_size = Vector2(0, 54)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 16)
		tb.clip_text = true
		tb.focus_mode = Control.FOCUS_NONE
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tb.pressed.connect(switch_tab.bind(id))
		tb.pressed.connect(func(): sound.play("click", -12.0))
		tabs.add_child(tb)
		tab_buttons[id] = tb

	var holder = Control.new()
	holder.custom_minimum_size = Vector2(0, 360)
	bv.add_child(holder)
	pages["upgrades"] = build_upgrades_page()
	pages["tuning"] = build_tuning_page()
	pages["workshop"] = build_workshop_page()
	pages["garage"] = build_garage_page()
	pages["chests"] = build_chests_page()
	for id in pages:
		fill_rect(pages[id])
		holder.add_child(pages[id])
	switch_tab(current_tab)
	refresh_paint()

	build_mini_panel()


func switch_tab(id: String):
	current_tab = id
	for tid in tab_buttons:
		var active = tid == id
		var b: Button = tab_buttons[tid]
		var st = box(ACCENT if active else Color(0, 0, 0, 0), 18, 2)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st if active else box(Color(1, 1, 1, 0.05), 18, 2))
		b.add_theme_stylebox_override("pressed", st)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, DARK_TEXT if active else UI_TEXT2)
		pages[tid].visible = active


# карточка улучшения (общая для всех вкладок с улучшениями)
func make_upgrade_card(icon_name: String, title_text: String, desc_text: String, col: Color, on_press: Callable, chip_icon := "") -> Dictionary:
	var b = Button.new()
	b.custom_minimum_size = Vector2(0, 166)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_card(b, col)
	b.pressed.connect(on_press)
	var v = VBoxContainer.new()
	fill_rect(v, 14, 12, 14, 14)
	v.add_theme_constant_override("separation", 4)
	ignore_mouse(v)
	b.add_child(v)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	ignore_mouse(head)
	v.add_child(head)
	head.add_child(icon_circle(icon_name, col, 46))
	var title = make_label(title_text, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	var lvl = make_label("", 16, UI_TEXT2, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(lvl)
	var desc = make_label(desc_text, 14, UI_TEXT2.darkened(0.12), HORIZONTAL_ALIGNMENT_LEFT)
	desc.clip_text = true
	v.add_child(desc)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ignore_mouse(spacer)
	v.add_child(spacer)
	var chip = make_chip(21, chip_icon)
	v.add_child(chip["panel"])
	return {"button": b, "level": lvl, "chip": chip["panel"], "cost": chip["label"], "chip_icon": chip["icon"]}


func make_grid(cols: int) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	return grid


func build_upgrades_page() -> Control:
	var grid = make_grid(2)
	for id in upgrades:
		var u = upgrades[id]
		var c = make_upgrade_card(u["icon"], t("up_" + id), t("up_" + id + "_d"), u["color"], _on_upgrade_pressed.bind(id))
		cards[id] = c
		grid.add_child(c["button"])
	return grid


func build_tuning_page() -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	tune_title = make_label(t("tuning_for") + car_name(selected_car), 18, UI_TEXT2)
	v.add_child(tune_title)
	var grid = make_grid(2)
	v.add_child(grid)
	for p in PART_ORDER:
		var info = part_info[p]
		var c = make_upgrade_card(info["icon"], t("part_" + p), t("part_" + p + "_d"), info["color"], _on_part_pressed.bind(p))
		part_cards[p] = c
		grid.add_child(c["button"])
	# покраска
	var ph = HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	v.add_child(ph)
	ph.add_child(icon("drop", ACCENT, 24))
	ph.add_child(make_label(t("paint"), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	var pspace = Control.new(); pspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(pspace)
	var pchip = make_chip(22, "drop"); pchip["panel"].add_theme_stylebox_override("panel", box(ACCENT, 16, 10)); paint_price_label = pchip["label"]
	ph.add_child(pchip["panel"])   # цена покраски — яркая плашка
	var pg = make_grid(5)
	pg.add_theme_constant_override("h_separation", 10)
	pg.add_theme_constant_override("v_separation", 10)
	v.add_child(pg)
	for col in PAINTS:
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_paint_pressed.bind(col))
		var ic = icon("lock", Color(1, 1, 1, 0.85), 28)
		fill_rect(ic, 20, 18, 20, 18)
		b.add_child(ic)
		paint_buttons[col] = {"button": b, "icon": ic}
		pg.add_child(b)
	return make_scroll(v)


func refresh_paint():
	if paint_buttons.is_empty():
		return
	var owned = owned_paints.get(selected_car, [])
	var base = Cars.CARS[selected_car]["color"]
	var current = car_color()
	for col in paint_buttons:
		var pb = paint_buttons[col]
		var is_owned = col == base or owned.has(col)
		var st = box(Color(col), 18, 0)
		if col == current:
			st.set_border_width_all(5)
			st.border_color = Color.WHITE
		pb["button"].add_theme_stylebox_override("normal", st)
		pb["button"].add_theme_stylebox_override("hover", st)
		pb["button"].add_theme_stylebox_override("pressed", st)
		var ic = pb["icon"]
		ic.visible = col == current or not is_owned
		var dark_col = Color(col).get_luminance() > 0.6
		ic.color = Color(0.1, 0.1, 0.15, 0.85) if dark_col else Color(1, 1, 1, 0.9)
		ic.set_icon("check" if col == current else "lock")
	paint_price_label.text = t("paint_price") + fmt(paint_price()) + " " + t("km")


func build_workshop_page() -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var head = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(icon("nut", ACCENT, 28))
	ws_nuts_label = make_label("", 24, ACCENT)
	head.add_child(ws_nuts_label)
	v.add_child(make_label(t("nuts_hint"), 15, UI_TEXT2)); var shop_b = make_icon_button("nut", t("shop"), Color("#9b6dff"), 70); shop_b[0].pressed.connect(show_shop); v.add_child(shop_b[0])
	var grid = make_grid(2)
	v.add_child(grid)
	for id in WS_ORDER:
		var w = workshop[id]
		var c = make_upgrade_card(w["icon"], t("ws_" + id), t("ws_" + id + "_d"), w["color"], _on_ws_pressed.bind(id), "nut")
		ws_cards[id] = c
		grid.add_child(c["button"])
	return make_scroll(v)


func build_garage_page() -> Control:
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	for id in Cars.ORDER:
		var c = Cars.CARS[id]
		var col = Color(c["color"])
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 96)
		style_card(b, ACCENT if c["exclusive"] else col)
		b.pressed.connect(_on_car_pressed.bind(id))
		var h = HBoxContainer.new()
		fill_rect(h, 16, 12, 16, 12)
		h.add_theme_constant_override("separation", 14)
		ignore_mouse(h)
		b.add_child(h)
		h.add_child(icon_circle("star" if c["exclusive"] else "car", col, 58))
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		ignore_mouse(v)
		h.add_child(v)
		v.add_child(make_label(car_name(id), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		var info = t("speed_x") + str(c["mult"])
		if c["exclusive"]:
			info += "  •  " + t("exclusive")
		v.add_child(make_label(info, 15, UI_TEXT2, HORIZONTAL_ALIGNMENT_LEFT))
		var chip = make_chip(19)
		chip["panel"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip["panel"].custom_minimum_size = Vector2(140, 0)
		h.add_child(chip["panel"])
		car_rows[id] = {"button": b, "chip": chip["panel"], "state": chip["label"]}
		list.add_child(b)
	return make_scroll(list)


func build_chests_page() -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(make_label(t("chest_hint"), 16, UI_TEXT2))
	var grid = make_grid(2)
	v.add_child(grid)
	for ct in CHEST_ORDER:
		var info = chest_types[ct]
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		style_card(b, info["color"])
		b.pressed.connect(open_chest.bind(ct))
		var cv = VBoxContainer.new()
		fill_rect(cv, 10, 10, 10, 10)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 2)
		ignore_mouse(cv)
		b.add_child(cv)
		var ic = icon_circle(info["icon"], info["color"], 56)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var name_l = make_label(t("chest_" + ct), 16, Color.WHITE)
		name_l.clip_text = true
		cv.add_child(name_l)
		var count = make_label("", 24, ACCENT)
		cv.add_child(count)
		var chance_l = make_label("", 13, UI_TEXT2)
		cv.add_child(chance_l)
		chest_cards[ct] = {"button": b, "count": count, "chance": chance_l}
		grid.add_child(b)
	return v


func build_mini_panel():
	mini_panel = PanelContainer.new()
	var ms = box(UI_BG, 0, 26)
	ms.corner_radius_top_left = 34
	ms.corner_radius_top_right = 34
	ms.border_width_top = 4
	ms.border_color = ACCENT
	ms.content_margin_bottom = 40
	mini_panel.add_theme_stylebox_override("panel", ms)
	mini_panel.anchor_top = 1.0
	mini_panel.anchor_bottom = 1.0
	mini_panel.anchor_right = 1.0
	mini_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mini_panel.visible = false
	ui_root.add_child(mini_panel)
	var mv = VBoxContainer.new()
	mv.add_theme_constant_override("separation", 18)
	mini_panel.add_child(mv)
	stage_label = make_label("", 30, ACCENT)
	mv.add_child(stage_label)
	mv.add_child(make_label(t("mini_title"), 20, UI_TEXT2))
	var timer_bg = ColorRect.new()
	timer_bg.color = Color("#2b3245")
	timer_bg.custom_minimum_size = Vector2(0, 12)
	mv.add_child(timer_bg)
	mini_timer_fill = ColorRect.new()
	mini_timer_fill.color = Color("#38c172")
	timer_bg.add_child(mini_timer_fill)
	mini_bar = Control.new()
	mini_bar.custom_minimum_size = Vector2(0, 60)
	mv.add_child(mini_bar)
	mini_bar_bg = ColorRect.new()
	mini_bar_bg.color = Color("#2b3245")
	mini_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	mini_bar.add_child(mini_bar_bg)
	mini_zone = ColorRect.new()
	mini_zone.color = Color("#3ddc97")
	mini_bar.add_child(mini_zone)
	mini_marker = ColorRect.new()
	mini_marker.color = Color.WHITE
	mini_bar.add_child(mini_marker)
	var tap = make_button(t("tap"), Color("#38c172"), 44, 130)
	tap.button_down.connect(_on_mini_tap)  # срабатывает в момент нажатия
	mv.add_child(tap)


# ---------- всплывающие окна ----------
func open_popup() -> VBoxContainer:
	close_popup()
	popup_dim = ColorRect.new()
	popup_dim.color = Color(0, 0, 0, 0.6)
	popup_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(popup_dim)
	var panel = PanelContainer.new()
	var ps = outlined(Color("#1b2132"), Color(ACCENT, 0.6), 30, 3)
	ps.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", ps)
	panel.anchor_right = 1.0
	panel.anchor_top = 0.16
	panel.anchor_bottom = 0.16
	panel.offset_left = 44
	panel.offset_right = -44
	popup_dim.add_child(panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	return v


func close_popup():
	if popup_dim:
		popup_dim.queue_free()
		popup_dim = null


func show_chest_popup(ct: String, lines: Array):
	var v = open_popup()
	var ic = icon_circle(chest_types[ct]["icon"], chest_types[ct]["color"], 130)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(make_label(t("chest_" + ct), 30, ACCENT))
	v.add_child(make_label(t("opened"), 20, UI_TEXT2))
	var r = make_label("\n".join(PackedStringArray(lines)), 22, Color.WHITE)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(r)
	var ok = make_button(t("great"), Color("#38c172"), 28, 86)
	ok.pressed.connect(close_popup)
	v.add_child(ok)
	# сундук «подпрыгивает»
	ic.pivot_offset = Vector2(65, 65)
	ic.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(ic, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func add_hud_buttons():
	# магазин — отдельная иконка справа под настройками
	shop_btn = square_hud_button("nut", show_shop)
	shop_btn.anchor_left = 1.0
	shop_btn.anchor_right = 1.0
	shop_btn.offset_left = -112
	shop_btn.offset_right = -24
	shop_btn.offset_top = 124
	shop_btn.offset_bottom = 212
	ui_root.add_child(shop_btn)
	# админ-панель для тестов — видна только при запуске из Godot
	admin_btn = square_hud_button("wrench", show_admin)
	admin_btn.offset_left = 24
	admin_btn.offset_right = 112
	admin_btn.offset_top = 124
	admin_btn.offset_bottom = 212
	admin_btn.visible = OS.is_debug_build()
	ui_root.add_child(admin_btn)


# ================= АДМИН-ПАНЕЛЬ (только для тестов) =================
func show_admin():
	var v = open_popup()
	v.add_child(make_label("ADMIN — тест", 30, ACCENT))
	var grid = make_grid(2)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var items = [
		["Гонка: обычный", admin_race.bind("common"), "#adb5bd"],
		["Гонка: редкий", admin_race.bind("rare"), "#4dabf7"],
		["Гонка: эпик", admin_race.bind("epic"), "#b197fc"],
		["Гонка: легенда", admin_race.bind("legendary"), "#ffd43b"],
		["+100 KM", admin_km.bind(100.0), "#38c172"],
		["+10K KM", admin_km.bind(10000.0), "#38c172"],
		["+100 гаек", admin_nuts, "#9b6dff"],
		["+10 запчастей", admin_spare, "#ff6b6b"],
		["+5 всех ящиков", admin_boxes, "#e0a96d"],
		["Все машины", admin_cars, "#4dabf7"],
		["Птица", admin_bird, "#ff8fab"],
		["Сменить биом", admin_biome, "#63e6be"],
		["День / ночь", admin_time, "#748ffc"],
		["Дождь вкл/выкл", admin_rain, "#74c0fc"],
		["Сброс прогресса", admin_reset, "#e5484d"],
		["Витрина машин", showroom.open, "#ffd166"], ["Закрыть", close_popup, "#3a4256"],
	]
	for it in items:
		var col = Color(it[2])
		var b = make_button(it[0], col, 19, 64, DARK_TEXT if col.get_luminance() > 0.45 else Color.WHITE)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[1])
		grid.add_child(b)


func admin_done(msg: String):
	save_game()
	show_toast("ADMIN: " + msg)


func admin_race(rar: String):
	close_popup()
	show_banner(t("race_event"))
	get_tree().create_timer(1.0).timeout.connect(race.begin.bind(rar))


func admin_km(amount: float):
	km += amount
	admin_done("+" + fmt(amount) + " KM")


func admin_nuts():
	nuts += 100
	admin_done("+100 " + t("nuts"))


func admin_spare():
	for p in spare:
		spare[p] += 10
	admin_done("+10 " + t("spare"))


func admin_boxes():
	for ct in chests:
		chests[ct] += 5
	admin_done("+5")


func admin_cars():
	for id in Cars.ORDER:
		if not owned_cars.has(id):
			owned_cars.append(id)
		if parts.has(id):
			parts[id] = Cars.CARS[id]["parts"]
	admin_done("all cars")


func admin_bird():
	close_popup()
	if bird == null:
		spawn_bird()


func admin_biome():
	close_popup()
	change_biome(Biomes.pick(rng, biome))


func admin_time():
	day_time = 0.92 if night < 0.5 else 0.45
	admin_done("time")


func admin_rain():
	weather = "clear" if weather == "rain" else "rain"
	weather_timer = 120.0
	admin_done(weather)


func admin_reset():
	# удаляем сохранение и запускаем игру с нуля
	set_process(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()


func shop_card(icon_name: String, col: Color, title: String, sub: String, price: String, price_icon: String, on_press: Callable) -> Button:
	# одинаковая карточка товара: значок, название, подпись, цена
	var b = Button.new()
	b.custom_minimum_size = Vector2(0, 176)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_card(b, col)
	b.pressed.connect(on_press)
	var cv = VBoxContainer.new()
	fill_rect(cv, 10, 12, 10, 12)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 6)
	ignore_mouse(cv)
	b.add_child(cv)
	var ic = icon_circle(icon_name, col, 52)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cv.add_child(ic)
	var tl = make_label(title, 21, Color.WHITE)
	tl.clip_text = true
	cv.add_child(tl)
	cv.add_child(make_label(sub if sub != "" else " ", 14, Color("#3ddc97")))
	var chip = make_chip(19, price_icon)
	chip["panel"].add_theme_stylebox_override("panel", box(ACCENT, 14, 6))
	chip["label"].text = price
	chip["panel"].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip["panel"].custom_minimum_size = Vector2(130, 0)
	cv.add_child(chip["panel"])
	return b


func shop_section(parent: Control, title: String) -> GridContainer:
	parent.add_child(make_label(title, 20, ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	var grid = make_grid(2)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	return grid


func show_shop():
	# Магазин. Оплата пока НЕ подключена: в отладке покупка гаек бесплатная (для проверки),
	# в готовой игре показывается «скоро». Позже подключим App Store / Google Play.
	var v = open_popup()
	var head = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(icon("nut", ACCENT, 34))
	head.add_child(make_label(t("shop"), 32, ACCENT))
	shop_nuts_label = make_label("", 20, Color.WHITE)
	v.add_child(shop_nuts_label)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 700)
	v.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	# 1) гайки за деньги: [сколько, цена, бонус]
	var g1 = shop_section(list, t("shop_nuts"))
	for pk in [[10, "0.99 EUR", ""], [55, "4.99 EUR", "+10%"], [120, "9.99 EUR", "+20%"], [300, "19.99 EUR", "+50%"]]:
		g1.add_child(shop_card("nut", Color("#9b6dff"), "x" + str(pk[0]), (t("bonus") + " " + pk[2]) if pk[2] != "" else "", pk[1], "", buy_pack.bind(pk[0])))
	# 2) километры за гайки: [цена в гайках, сколько секунд дохода, подпись]
	var g2 = shop_section(list, t("shop_km"))
	for off in [[5, 600.0, "10 min"], [15, 3600.0, "1 h"], [40, 3 * 3600.0, "3 h"], [100, 10 * 3600.0, "10 h"]]:
		var amount = income_per_sec() * off[1]
		g2.add_child(shop_card("speed", Color("#38c172"), "+" + fmt(amount) + " " + t("km"), off[2], str(off[0]), "nut", buy_km.bind(off[0], off[1])))
	# 3) ящики за гайки
	var g3 = shop_section(list, t("shop_boxes"))
	var box_prices = {"parts": 5, "tools": 12, "carparts": 30, "car": 90}
	for ct in CHEST_ORDER:
		g3.add_child(shop_card(chest_types[ct]["icon"], chest_types[ct]["color"], t("chest_" + ct), "", str(box_prices[ct]), "nut", buy_box.bind(ct, box_prices[ct])))
	var note = make_label(t("shop_note"), 14, UI_TEXT2)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var close_b = make_button(t("close"), ACCENT, 26, 76, DARK_TEXT)
	close_b.pressed.connect(close_popup)
	v.add_child(close_b)
	refresh_shop()


func refresh_shop():
	if shop_nuts_label and is_instance_valid(shop_nuts_label):
		shop_nuts_label.text = t("nuts") + ": " + str(nuts)


func buy_pack(amount: int):
	# ЗДЕСЬ позже будет настоящая оплата через магазин приложений
	if not OS.is_debug_build():
		show_toast(t("shop_soon"))
		return
	nuts += amount
	save_game()
	sound.chime([0, 4, 7, 12, 16], -6.0)
	show_toast(t("shop_test") + str(amount))
	refresh_shop()


func buy_km(price: int, secs: float):
	if nuts < price:
		sound.play("fail", -10.0)
		show_toast(t("no_nuts"))
		return
	nuts -= price
	var amount = income_per_sec() * secs
	km += amount
	save_game()
	sound.chime([0, 4, 7, 12], -6.0)
	show_toast("+" + fmt(amount) + " " + t("km"))
	refresh_shop()


func buy_box(ct: String, price: int):
	if nuts < price:
		sound.play("fail", -10.0)
		show_toast(t("no_nuts"))
		return
	nuts -= price
	chests[ct] += 1
	save_game()
	sound.chime([0, 4, 7, 12], -6.0)
	show_toast(t("chest_got") + t("chest_" + ct))
	refresh_shop()


func style_overtake(b: Button):
	# кнопка-«таблетка» с объёмной нижней гранью и мягко пульсирующим ореолом
	for state in ["normal", "hover", "pressed"]:
		var base = Color("#ffc43d")
		if state == "hover":
			base = base.lightened(0.06)
		elif state == "pressed":
			base = base.darkened(0.08)
		var s = box(base, 50, 0)
		s.border_width_bottom = 4 if state == "pressed" else 10
		s.border_color = Color("#d98a00")
		b.add_theme_stylebox_override(state, s)
	overtake_glow = Panel.new()
	overtake_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overtake_glow.add_theme_stylebox_override("panel", box(Color(1.0, 0.85, 0.3, 0.35), 64, 0))
	overtake_glow.anchor_left = b.anchor_left
	overtake_glow.anchor_right = b.anchor_right
	overtake_glow.offset_left = b.offset_left - 14
	overtake_glow.offset_right = b.offset_right + 14
	overtake_glow.offset_top = b.offset_top - 12
	overtake_glow.offset_bottom = b.offset_bottom + 14
	overtake_glow.visible = false
	ui_root.add_child(overtake_glow)
	ui_root.move_child(overtake_glow, b.get_index())


func show_settings():
	var v = open_popup()
	v.add_child(make_label(t("settings"), 32, ACCENT))
	var lang_b = make_icon_button("globe", t("language"), Color("#4d7cff"), 80)
	lang_b[0].pressed.connect(func():
		var li = Texts.LANGS.find(lang)
		lang = Texts.LANGS[(li + 1) % Texts.LANGS.size()]
		save_game()
		setup_ui()
		update_ui()
		show_settings())
	v.add_child(lang_b[0])
	var icons = {"music": "note", "sounds": "speaker", "vibration": "phone"}
	for opt in ["music", "sounds", "vibration"]:
		var ib = make_icon_button(icons[opt], "", Color("#3a4256"), 80)
		v.add_child(ib[0])
		refresh_toggle(ib[0], ib[1], opt)
		ib[0].pressed.connect(func():
			match opt:
				"music":
					music_on = not music_on
					sound.set_music(music_on)
				"sounds":
					sound_on = not sound_on
					sound.set_sound(sound_on)
				"vibration":
					vibro_on = not vibro_on
					if vibro_on:
						Input.vibrate_handheld(80)
			refresh_toggle(ib[0], ib[1], opt)
			save_game())
	var close_b = make_button(t("close"), ACCENT, 26, 80, DARK_TEXT)
	close_b.pressed.connect(close_popup)
	v.add_child(close_b)


func refresh_toggle(b: Button, l: Label, opt: String):
	var on = {"music": music_on, "sounds": sound_on, "vibration": vibro_on}[opt]
	l.text = t(opt) + ": " + (t("on") if on else t("off"))
	style_solid(b, Color("#38c172") if on else Color("#3a4256"))


func show_leaderboard():
	# Пока без сервера: ваш результат среди тестовых соперников.
	# Когда подключим онлайн (например, Firebase), здесь будут реальные игроки.
	var v = open_popup()
	var head = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(icon("trophy", ACCENT, 36))
	head.add_child(make_label(t("leaderboard"), 32, ACCENT))
	var nick_row = HBoxContainer.new()
	nick_row.add_theme_constant_override("separation", 10)
	v.add_child(nick_row)
	nick_row.add_child(icon("user", UI_TEXT2, 28))
	var edit = LineEdit.new()
	edit.text = nick
	edit.placeholder_text = t("nick")
	edit.max_length = 16
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 54)
	edit.add_theme_font_size_override("font_size", 22)
	edit.add_theme_stylebox_override("normal", outlined(UI_CARD, Color(1, 1, 1, 0.15), 14, 2))
	edit.add_theme_stylebox_override("focus", outlined(UI_CARD, ACCENT, 14, 2))
	edit.text_changed.connect(func(txt):
		nick = txt
		save_game())
	nick_row.add_child(edit)
	var bots = [["RoadKing", 40000.0], ["Turbo_Max", 15800.0], ["NightRider", 7000.0], ["Drifter77", 3000.0],
		["Lisa_GT", 1250.0], ["Pilot42", 530.0], ["Kolyaska", 200.0], ["Bullet", 75.0], ["Sonya", 25.0]]
	var rows = []
	for b in bots:
		rows.append([b[0], b[1], false])
	rows.append([nick if nick != "" else t("default_nick"), total_km, true])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	v.add_child(list)
	for i in rows.size():
		var r = rows[i]
		var row = PanelContainer.new()
		row.add_theme_stylebox_override("panel", box(Color("#3a3220") if r[2] else UI_CARD, 14, 10))
		list.add_child(row)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var place_col = [Color("#ffd43b"), Color("#dee2e6"), Color("#e8a76b")][i] if i < 3 else UI_TEXT2
		var place = make_label(str(i + 1), 22, place_col)
		place.custom_minimum_size = Vector2(36, 0)
		h.add_child(place)
		var nm = make_label(r[0], 20, ACCENT if r[2] else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(make_label(fmt(r[1]) + " " + t("km"), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT))
	var note = make_label(t("lb_note"), 14, UI_TEXT2)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var close_b = make_button(t("close"), ACCENT, 26, 76, DARK_TEXT)
	close_b.pressed.connect(close_popup)
	v.add_child(close_b)


func show_toast(text: String):
	toast.text = text; toast.move_to_front()
	toast.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)


func fmt(v: float) -> String:
	if v < 1000:
		return String.num(v, 2) if v < 10 else (String.num(v, 1) if v < 100 else str(int(v)))
	if v < 1000000:
		return String.num(v / 1000.0, 1 if v < 100000 else 0) + "K"
	return String.num(v / 1000000.0, 1) + "M"


func _on_upgrade_pressed(id: String):
	var cost = get_cost(id)
	if km >= cost:
		km -= cost
		upgrades[id]["level"] += 1
		sound.chime([0, 7], -10.0)
		save_game()


func set_chip(c: Dictionary, text: String, style: String, text_col := DARK_TEXT):
	c["cost"].text = text
	c["chip"].add_theme_stylebox_override("panel", chip_styles[style])
	c["cost"].add_theme_color_override("font_color", text_col)
	if c.get("chip_icon") != null:
		c["chip_icon"].color = text_col
		c["chip_icon"].queue_redraw()


func set_card_state(c: Dictionary, can: bool):
	c["button"].disabled = not can
	c["button"].modulate = Color(1, 1, 1, 1.0 if can else 0.75)


func update_ui():
	km_label.text = fmt(km) + " " + t("km")
	speed_label.text = str(int(current_speed)) + " " + t("kmh") + "   •   " + t("total") + " " + fmt(total_km) + " " + t("km")
	nuts_label.text = str(nuts)
	weather_label.text = t(time_name()) + "  •  " + t(weather)
	if weather_icon.icon != weather_icon_name():
		weather_icon.set_icon(weather_icon_name())
	for id in upgrades:
		var c = cards[id]
		var cost = get_cost(id)
		var can = km >= cost
		c["level"].text = t("level") + " " + str(upgrades[id]["level"])
		set_chip(c, fmt(cost) + " " + t("km"), "accent" if can else "grey", DARK_TEXT if can else UI_TEXT2)
		set_card_state(c, can)
	for p in part_cards:
		var c = part_cards[p]
		var lvl = part_level(p)
		var need = part_need(p)
		c["level"].text = t("lvl") + " " + str(lvl) + "/" + str(PART_MAX)
		if lvl >= PART_MAX:
			set_chip(c, t("max"), "green")
			c["button"].disabled = true
			c["button"].modulate = Color.WHITE
		else:
			# тюнинг покупается только за запчасти из ящиков
			var can = spare[p] >= need
			set_chip(c, t("spare") + " " + str(spare[p]) + " / " + str(need), "accent" if can else "grey", DARK_TEXT if can else UI_TEXT2)
			set_card_state(c, can)
	ws_nuts_label.text = t("nuts") + ": " + str(nuts)
	for id in ws_cards:
		var c = ws_cards[id]
		var w = workshop[id]
		c["level"].text = t("lvl") + " " + str(w["level"]) + "/" + str(w["max"])
		if w["level"] >= w["max"]:
			set_chip(c, t("max"), "green")
			c["button"].disabled = true
			c["button"].modulate = Color.WHITE
		else:
			var cost = get_ws_cost(id)
			var can = nuts >= cost
			set_chip(c, str(cost), "accent" if can else "grey", DARK_TEXT if can else UI_TEXT2)
			set_card_state(c, can)
	for id in car_rows:
		var r = car_rows[id]
		var c = Cars.CARS[id]
		var rc = {"cost": r["state"], "chip": r["chip"]}
		if id == selected_car:
			set_chip(rc, t("selected"), "green")
		elif owned_cars.has(id):
			set_chip(rc, t("select"), "grey", Color.WHITE)
		elif c["exclusive"]:
			set_chip(rc, t("part") + " " + str(parts[id]) + "/" + str(c["parts"]), "gold", ACCENT)
		elif km >= c["price"]:
			set_chip(rc, fmt(c["price"]) + " " + t("km"), "accent")
		else:
			set_chip(rc, fmt(c["price"]) + " " + t("km"), "grey", Color("#ff9b9b"))
	var total = 0
	for ct in CHEST_ORDER:
		total += chest_types[ct]["chance"]
	for ct in chest_cards:
		var has = chests[ct] > 0
		chest_cards[ct]["count"].text = "x " + str(chests[ct])
		chest_cards[ct]["chance"].text = t("chance") + " " + String.num(100.0 * chest_types[ct]["chance"] / total * get_chest_chance(), 1) + "%"
		chest_cards[ct]["button"].disabled = not has
		chest_cards[ct]["button"].modulate = Color(1, 1, 1, 1.0 if has else 0.6)
	overtake_btn.visible = is_blocked() and not mini_active and not overtaking and overtake_cooldown <= 0 and popup_dim == null; overtake_glow.visible = overtake_btn.visible
	if overtake_btn.visible:
		overtake_btn.pivot_offset = overtake_btn.size / 2
		overtake_btn.scale = Vector2.ONE * (1.0 + 0.04 * sin(anim_time * 6.0)); overtake_glow.pivot_offset = overtake_glow.size / 2; overtake_glow.scale = Vector2.ONE * (1.0 + 0.05 * (0.5 + 0.5 * sin(anim_time * 6.0))); overtake_glow.modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(anim_time * 6.0))
	settings_btn.visible = not mini_active
	lb_btn.visible = not mini_active; shop_btn.visible = not mini_active; admin_btn.visible = not mini_active and OS.is_debug_build()


# ================= СОХРАНЕНИЕ =================
func save_game():
	var cfg = ConfigFile.new()
	cfg.set_value("game", "km", km)
	cfg.set_value("game", "total_km", total_km); cfg.set_value("game", "real_km", true)
	cfg.set_value("game", "nuts", nuts)
	cfg.set_value("game", "nick", nick)
	cfg.set_value("game", "time", Time.get_unix_time_from_system())
	for id in upgrades:
		cfg.set_value("upgrades", id, upgrades[id]["level"])
	for id in workshop:
		cfg.set_value("workshop", id, workshop[id]["level"])
	cfg.set_value("garage", "owned", owned_cars)
	cfg.set_value("garage", "selected", selected_car)
	cfg.set_value("garage", "tune", tune)
	cfg.set_value("garage", "spare", spare)
	cfg.set_value("garage", "paint", paint)
	cfg.set_value("garage", "owned_paints", owned_paints)
	for id in parts:
		cfg.set_value("parts", id, parts[id])
	for ct in chests:
		cfg.set_value("chests", ct, chests[ct])
	cfg.set_value("settings", "lang", lang)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sound", sound_on)
	cfg.set_value("settings", "vibro", vibro_on)
	cfg.set_value("world", "day_time", day_time)
	cfg.set_value("world", "biome", biome)
	cfg.save(SAVE_PATH)


func load_game() -> float:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0.0
	km = cfg.get_value("game", "km", 0.0)
	total_km = cfg.get_value("game", "total_km", 0.0); var conv = 1.0 if cfg.get_value("game", "real_km", false) else 1.0 / 60.0; km *= conv; total_km *= conv   # старые сохранения переводим в настоящие километры
	nuts = cfg.get_value("game", "nuts", 0)
	nick = cfg.get_value("game", "nick", "")
	for id in upgrades:
		upgrades[id]["level"] = cfg.get_value("upgrades", id, 0)
	for id in workshop:
		workshop[id]["level"] = cfg.get_value("workshop", id, 0)
	owned_cars = cfg.get_value("garage", "owned", ["hatch"])
	selected_car = cfg.get_value("garage", "selected", "hatch")
	if not Cars.CARS.has(selected_car):
		selected_car = "hatch"
	tune = cfg.get_value("garage", "tune", {})
	var sp = cfg.get_value("garage", "spare", {})
	for p in spare:
		spare[p] = sp.get(p, 0)
	paint = cfg.get_value("garage", "paint", {})
	owned_paints = cfg.get_value("garage", "owned_paints", {})
	for id in parts:
		parts[id] = cfg.get_value("parts", id, 0)
	for ct in chests:
		chests[ct] = cfg.get_value("chests", ct, 0)
	lang = cfg.get_value("settings", "lang", "ru")
	if not Texts.LANGS.has(lang):
		lang = "en"
	music_on = cfg.get_value("settings", "music", true)
	sound_on = cfg.get_value("settings", "sound", true)
	vibro_on = cfg.get_value("settings", "vibro", true)
	day_time = cfg.get_value("world", "day_time", 0.33)
	biome = cfg.get_value("world", "biome", "meadow")
	if not Biomes.BIOMES.has(biome):
		biome = "meadow"
	var last_time = cfg.get_value("game", "time", 0.0)
	if last_time > 0:
		var away = clampf(Time.get_unix_time_from_system() - last_time, 0, max_offline())
		if away > 10:
			var earned = away * income_per_sec() * get_offline_rate()
			km += earned
			total_km += earned
			return earned
	return 0.0


func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
