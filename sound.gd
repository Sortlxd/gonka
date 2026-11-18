extends Node
# Музыка и звуки, которые генерируются кодом при запуске (аудиофайлы не нужны).
# Короткие «семплы» создаются один раз, а музыка собирается из них на лету,
# как в маленьком синтезаторе: пианино, мягкий пэд и бас по кругу из 4 аккордов.

const RATE = 22050      # частота дискретизации генерируемых звуков
const STEP = 0.37       # длительность одной восьмой ноты в музыке, сек

var samples = {}
var sfx_pool = []
var music_pool = []
var engine_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var rng = RandomNumberGenerator.new()
var music_clock = 0.0
var step_index = 0
var clock = 0.0
var queue = []           # отложенные звуки: [время, семпл, высота, громкость]
var birds_enabled = true
var bird_timer = 3.0

# Аккорды в полутонах от ноты «до»: Cmaj7 – Am7 – Fmaj7 – G6
var chords = [[0, 4, 7, 11], [-3, 0, 4, 7], [-7, -3, 0, 4], [-5, -1, 2, 4]]
var arp = [0, 2, 1, 3, 2, 1, 3, 2]


func _ready():
	rng.randomize()
	setup_buses()
	build_samples()
	for i in 10:
		music_pool.append(make_player("Music"))
	for i in 10:
		sfx_pool.append(make_player("SFX"))
	engine_player = make_loop("engine", -15.0)
	wind_player = make_loop("wind", -20.0)
	rain_player = make_loop("rain", -80.0)


# ---------- шины: отдельно музыка и звуки, чтобы выключать их в настройках ----------
func setup_buses():
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var mi = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(mi, -9.0)
	if AudioServer.get_bus_effect_count(mi) == 0:
		var rev = AudioEffectReverb.new()
		rev.room_size = 0.75
		rev.damping = 0.6
		rev.wet = 0.3
		rev.dry = 0.85
		AudioServer.add_bus_effect(mi, rev)

func set_music(on: bool):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)

func set_sound(on: bool):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not on)


func make_player(bus_name: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p

func make_loop(id: String, vol: float) -> AudioStreamPlayer:
	var p = make_player("SFX")
	p.stream = samples[id]
	p.volume_db = vol
	p.play()
	return p


# ---------- управление из игры ----------
func play(id: String, vol_db := 0.0, pitch := 1.0):
	var p = sfx_pool[0]
	for q in sfx_pool:
		if not q.playing:
			p = q
			break
	p.stream = samples[id]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()

func play_later(delay: float, id: String, vol_db := 0.0, pitch := 1.0):
	queue.append([clock + delay, id, pitch, vol_db])

func chime(notes: Array, vol_db := -6.0):
	# короткая мелодия из нот (полутона от «до» второй октавы)
	for i in notes.size():
		play_later(i * 0.1, "piano", vol_db, pow(2.0, (notes[i] + 12) / 12.0))

func set_engine(pitch: float, vol_db: float):
	engine_player.pitch_scale = clampf(pitch, 0.5, 2.5)
	engine_player.volume_db = vol_db

func set_rain(amount: float):
	rain_player.volume_db = -80.0 if amount < 0.02 else linear_to_db(amount * 0.16)

func set_wind(amount: float):
	wind_player.volume_db = linear_to_db(clampf(amount, 0.01, 1.0) * 0.08)


func _process(delta):
	music_clock += delta
	while music_clock >= STEP:
		music_clock -= STEP
		music_step()
	clock += delta
	for q in queue.duplicate():
		if clock >= q[0]:
			play(q[1], q[3], q[2])
			queue.erase(q)
	if birds_enabled:
		bird_timer -= delta
		if bird_timer <= 0:
			bird_timer = rng.randf_range(2.5, 7.0)
			for i in rng.randi_range(1, 3):
				play_later(i * 0.17, "bird", -22.0, rng.randf_range(0.85, 1.25))


func music_step():
	var bar_step = step_index % 16
	var chord = chords[int(step_index / 16.0) % chords.size()]
	if bar_step == 0:
		for s in [chord[0], chord[1], chord[2]]:
			music_note("pad", s, -9.0)
		music_note("bass", chord[0], -5.0)
	elif bar_step == 8:
		music_note("bass", chord[0] + 7, -8.0)
	if rng.randf() < 0.75:
		var semi = chord[arp[bar_step % 8] % chord.size()]
		if bar_step % 8 >= 5:
			semi += 12
		music_note("piano", semi, -11.0 + rng.randf_range(-3.0, 0.0))
	step_index += 1

func music_note(id: String, semi: float, vol_db: float):
	var p = music_pool[0]
	for q in music_pool:
		if not q.playing:
			p = q
			break
	p.stream = samples[id]
	p.volume_db = vol_db
	p.pitch_scale = pow(2.0, semi / 12.0)
	p.play()


# ================= генерация семплов =================
func build_samples():
	samples["piano"] = make_wav(gen_piano(261.63, 1.8), false)
	samples["pad"] = make_wav(gen_pad(130.81, 3.2), false)
	samples["bass"] = make_wav(gen_bass(65.41, 1.4), false)
	samples["engine"] = make_wav(gen_engine(), true)
	samples["wind"] = make_wav(gen_wind(4.0), true)
	samples["rain"] = make_wav(gen_rain_soft(3.0), true)
	samples["whoosh"] = make_wav(gen_whoosh(0.8), false); samples["passby"] = make_wav(gen_passby(1.3), false)
	samples["crash"] = make_wav(gen_crash(0.8), false)
	samples["click"] = make_wav(gen_tone(1100.0, 0.06, 55.0, 0.35), false)
	samples["fail"] = make_wav(gen_buzz(0.3), false)
	samples["bird"] = make_wav(gen_bird(0.2), false)


func make_wav(d: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(d.size() * 2)
	for i in d.size():
		bytes.encode_s16(i * 2, int(clampf(d[i], -1.0, 1.0) * 32767.0))
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = d.size()
	return w


func new_buf(dur: float) -> PackedFloat32Array:
	var d = PackedFloat32Array()
	d.resize(int(dur * RATE))
	return d


func gen_piano(f: float, dur: float) -> PackedFloat32Array:
	var d = new_buf(dur)
	for i in d.size():
		var t = float(i) / RATE
		var ph = TAU * f * t
		var env = minf(t / 0.006, 1.0) * exp(-t * 2.6)
		d[i] = (sin(ph) + 0.35 * sin(2.0 * ph) * exp(-t * 3.0) + 0.1 * sin(3.0 * ph) * exp(-t * 5.0)) * env * 0.35
	return d


func gen_pad(f: float, dur: float) -> PackedFloat32Array:
	var d = new_buf(dur)
	for i in d.size():
		var t = float(i) / RATE
		var a = TAU * f * 1.003 * t
		var b = TAU * f * 0.997 * t
		var env = minf(t / 0.8, 1.0) * clampf((dur - t) / 1.2, 0.0, 1.0)
		d[i] = (sin(a) + sin(b) + (sin(2.0 * a) + sin(2.0 * b)) * 0.25 + (sin(3.0 * a) + sin(3.0 * b)) * 0.11) * env * 0.12
	return d


func gen_bass(f: float, dur: float) -> PackedFloat32Array:
	var d = new_buf(dur)
	for i in d.size():
		var t = float(i) / RATE
		var ph = TAU * f * t
		d[i] = (sin(ph) + 0.3 * sin(2.0 * ph)) * minf(t / 0.01, 1.0) * exp(-t * 1.8) * 0.4
	return d


func gen_engine() -> PackedFloat32Array:
	# 1 секунда с целым числом периодов, чтобы петля шла без щелчков
	var d = new_buf(1.0)
	for i in d.size():
		var t = float(i) / RATE
		var ph = TAU * 50.0 * t
		var s = sin(ph) + 0.6 * sin(2.0 * ph) + 0.45 * sin(3.0 * ph) + 0.3 * sin(4.0 * ph) + 0.15 * sin(6.0 * ph)
		d[i] = s * (0.8 + 0.2 * sin(TAU * 25.0 * t)) * 0.17
	return d


func seamless(raw: PackedFloat32Array, n: int) -> PackedFloat32Array:
	# конец звука плавно перетекает в начало — петля без щелчка
	var fade = raw.size() - n
	var d = PackedFloat32Array()
	d.resize(n)
	for i in n:
		d[i] = raw[i]
	for i in fade:
		var k = float(i) / fade
		d[i] = raw[i] * k + raw[n + i] * (1.0 - k)
	return d


func normalize(d: PackedFloat32Array, amp: float):
	var m = 0.0001
	for v in d:
		m = maxf(m, absf(v))
	for i in d.size():
		d[i] = d[i] / m * amp


func gen_wind(dur: float) -> PackedFloat32Array:
	var n = int(dur * RATE)
	var raw = PackedFloat32Array()
	raw.resize(n + int(0.5 * RATE))
	var y1 = 0.0
	var y2 = 0.0
	for i in raw.size():
		y1 += 0.02 * (rng.randf_range(-1.0, 1.0) - y1)
		y2 += 0.02 * (y1 - y2)
		raw[i] = y2
	var d = seamless(raw, n)
	for i in n:
		d[i] *= 0.6 + 0.4 * sin(TAU * float(i) / n)
	normalize(d, 0.6)
	return d


func gen_rain(dur: float) -> PackedFloat32Array:
	var n = int(dur * RATE)
	var raw = PackedFloat32Array()
	raw.resize(n + int(0.4 * RATE))
	var lp = 0.0
	var drop = 0.0
	for i in raw.size():
		var x = rng.randf_range(-1.0, 1.0)
		lp += 0.35 * (x - lp)
		if rng.randf() < 0.0015:
			drop = rng.randf_range(0.4, 1.0)
		drop *= 0.992
		raw[i] = (x - lp) * 0.5 + rng.randf_range(-1.0, 1.0) * drop * 0.6
	var d = seamless(raw, n)
	normalize(d, 0.5)
	return d


func gen_whoosh(dur: float) -> PackedFloat32Array:
	var d = new_buf(dur)
	var y = 0.0
	for i in d.size():
		var t = float(i) / d.size()
		var k = 0.02 + 0.2 * sin(PI * t)
		y += k * (rng.randf_range(-1.0, 1.0) - y)
		d[i] = y * pow(sin(PI * t), 2.0)
	normalize(d, 0.6)
	return d


func gen_crash(dur: float) -> PackedFloat32Array:
	var d = new_buf(dur)
	var y = 0.0
	for i in d.size():
		var t = float(i) / RATE
		y += 0.3 * (rng.randf_range(-1.0, 1.0) - y)
		var metal = (sin(TAU * 820.0 * t) + sin(TAU * 1270.0 * t)) * 0.2 * exp(-t * 10.0)
		d[i] = y * exp(-t * 6.0) * 0.8 + sin(TAU * 55.0 * t) * exp(-t * 8.0) * 0.8 + metal
	normalize(d, 0.9)
	return d


func gen_tone(f: float, dur: float, decay: float, amp: float) -> PackedFloat32Array:
	var d = new_buf(dur)
	for i in d.size():
		var t = float(i) / RATE
		d[i] = sin(TAU * f * t) * exp(-t * decay) * minf(t / 0.003, 1.0) * amp
	return d


func gen_buzz(dur: float) -> PackedFloat32Array:
	var d = new_buf(dur)
	for i in d.size():
		var t = float(i) / RATE
		var s = sin(TAU * 140.0 * t)
		d[i] = (signf(s) * 0.15 + s * 0.2) * exp(-t * 7.0)
	return d


func gen_bird(dur: float) -> PackedFloat32Array:
	var d = new_buf(dur)
	var ph = 0.0
	for i in d.size():
		var t = float(i) / RATE
		var f = 2600.0 + 1400.0 * (t / dur) + 300.0 * sin(TAU * 30.0 * t)
		ph += TAU * f / RATE
		d[i] = sin(ph) * sin(PI * t / dur) * 0.25
	return d



func gen_passby(dur: float) -> PackedFloat32Array:
	# машина проезжает мимо: гул мотора, высота которого падает (эффект Доплера),
	# плюс мягкий поток воздуха. Громче всего — в середине.
	var d = new_buf(dur)
	var ph = 0.0
	var air = 0.0
	for i in d.size():
		var t = float(i) / RATE
		var x = (t / dur - 0.5) * 6.0
		var f = 120.0 * (1.0 - 0.18 * tanh(x))
		ph += TAU * f / RATE
		var env = 1.0 / (1.0 + x * x)
		air += 0.05 * (rng.randf_range(-1.0, 1.0) - air)
		var motor = sin(ph) + 0.55 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph) + 0.15 * sin(5.0 * ph)
		d[i] = (motor * 0.35 + air * 2.2) * env * minf(t / 0.05, 1.0) * clampf((dur - t) / 0.1, 0.0, 1.0)
	normalize(d, 0.55)
	return d



func gen_rain_soft(dur: float) -> PackedFloat32Array:
	# мягкий дождь: приглушённый шелест + редкие тихие «кап»
	var n = int(dur * RATE)
	var raw = PackedFloat32Array()
	raw.resize(n + int(0.4 * RATE))
	var lp1 = 0.0
	var lp2 = 0.0
	var hp = 0.0
	var drop = 0.0
	var drop_f = 2000.0
	var drop_ph = 0.0
	for i in raw.size():
		var x = rng.randf_range(-1.0, 1.0)
		lp1 += 0.12 * (x - lp1)
		lp2 += 0.12 * (lp1 - lp2)
		hp += 0.01 * (lp2 - hp)
		var hiss = (lp2 - hp) * 1.6
		if rng.randf() < 0.0006:
			drop = rng.randf_range(0.15, 0.4)
			drop_f = rng.randf_range(1400.0, 3200.0)
		drop *= 0.9985
		drop_ph += TAU * drop_f / RATE
		raw[i] = hiss  # без «пиликанья» капель
	var d = seamless(raw, n)
	normalize(d, 0.45)
	return d
