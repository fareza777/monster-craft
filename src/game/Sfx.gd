extends Node
## All audio is synthesized at runtime: original crisp SFX and an ambient
## day/night score. No external audio files, no network.

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_day: AudioStreamWAV
var _music_night: AudioStreamWAV
var _music_player: AudioStreamPlayer
var _music_night_player: AudioStreamPlayer
var _night := false
var _music_started := false
var master_volume := 0.8
var music_volume := 0.75
var sfx_volume := 0.9

const RATE := 22050
const MRATE := 11025

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sfx()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -80.0
	add_child(_music_player)
	_music_night_player = AudioStreamPlayer.new()
	_music_night_player.bus = "Master"
	_music_night_player.volume_db = -80.0
	add_child(_music_night_player)
	apply_volumes()

func _process(_delta: float) -> void:
	if _music_started and Game.in_game:
		var want_night := Game.is_night()
		if want_night != _night:
			_night = want_night
			_crossfade_music()

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_music_volume()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)

func apply_volumes() -> void:
	set_master_volume(Game.master_volume)
	music_volume = clampf(Game.music_volume, 0.0, 1.0)
	sfx_volume = clampf(Game.sfx_volume, 0.0, 1.0)
	_apply_music_volume()

func _apply_music_volume() -> void:
	if _music_player == null:
		return
	var db := -18.0 + linear_to_db(maxf(music_volume, 0.001))
	_music_player.volume_db = db if not _night else -80.0
	_music_night_player.volume_db = db if _night else -80.0

func play(sound: String, pitch_variation: float = 0.08) -> void:
	if not _sfx.has(sound):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	if p.playing:
		for q in _players:
			if not q.playing:
				p = q
				break
	p.stream = _sfx[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.volume_db = linear_to_db(clampf(sfx_volume, 0.001, 1.0)) - 2.0
	p.play()

func start_music() -> void:
	if _music_started:
		return
	_music_started = true
	if _music_day == null:
		_music_day = _make_music(false)
		_music_night = _make_music(true)
	_music_player.stream = _music_day
	_music_night_player.stream = _music_night
	_night = Game.in_game and Game.is_night()
	_music_player.play()
	_music_night_player.play()
	_crossfade_music()

func stop_music() -> void:
	_music_started = false
	var tw := create_tween()
	tw.tween_property(_music_player, "volume_db", -80.0, 0.4)
	tw.parallel().tween_property(_music_night_player, "volume_db", -80.0, 0.4)
	tw.tween_callback(func():
		_music_player.stop()
		_music_night_player.stop())

func _crossfade_music() -> void:
	if _music_day == null:
		return
	var tw := create_tween()
	var base := -18.0 + linear_to_db(maxf(music_volume, 0.001))
	var day_db := base if not _night else -80.0
	var night_db := base if _night else -80.0
	tw.tween_property(_music_player, "volume_db", day_db, 2.0)
	tw.parallel().tween_property(_music_night_player, "volume_db", night_db, 2.0)

# ------------------------------------------------------------------ synthesis

func _wav(samples: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s

func _tone(freq: float, dur: float, vol: float = 0.5, wave: String = "sine",
		attack: float = 0.005, decay_pow: float = 2.0, rate: int = RATE) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		phase += TAU * freq / rate
		var v := 0.0
		match wave:
			"sine": v = sin(phase)
			"triangle": v = asin(sin(phase)) * 0.63
			"saw": v = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"square": v = 1.0 if sin(phase) >= 0.0 else -1.0
		var env := 1.0
		if t < attack:
			env = t / attack
		else:
			env = pow(maxf(0.0, 1.0 - (t - attack) / maxf(dur - attack, 0.001)), decay_pow)
		out[i] = v * vol * env
	return out

func _noise(dur: float, vol: float, low: float = 0.4, rate: int = RATE) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / rate
		var white := randf_range(-1.0, 1.0)
		last = lerpf(last, white, low)
		var env := pow(maxf(0.0, 1.0 - t / dur), 2.2)
		out[i] = last * vol * env
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: float = 0.0) -> PackedFloat32Array:
	var off := int(offset * RATE)
	var size := maxi(a.size(), b.size() + off)
	var out := PackedFloat32Array()
	out.resize(size)
	for i in a.size():
		out[i] += a[i]
	for i in b.size():
		if i + off < size:
			out[i + off] += b[i]
	return out

func _concat(arrays: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for a in arrays:
		out.append_array(a)
	return out

func _build_sfx() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	seed(4242)
	_sfx["dig"] = _wav(_mix(_noise(0.09, 0.5, 0.25), _tone(120, 0.07, 0.3, "square", 0.002, 3.0)))
	_sfx["break"] = _wav(_mix(_noise(0.2, 0.55, 0.18), _tone(90, 0.14, 0.35, "triangle", 0.003, 2.0)))
	_sfx["place"] = _wav(_tone(150, 0.09, 0.4, "triangle", 0.002, 2.5))
	_sfx["pickup"] = _wav(_concat([_tone(880, 0.05, 0.25, "sine"), _tone(1320, 0.08, 0.2, "sine")]))
	_sfx["hurt"] = _wav(_mix(_noise(0.16, 0.3), _tone(180, 0.18, 0.35, "saw", 0.002, 2.0)))
	_sfx["jump"] = _wav(_tone(420, 0.1, 0.25, "sine", 0.003, 1.4))
	_sfx["swing"] = _wav(_noise(0.12, 0.3, 0.6))
	_sfx["hit"] = _wav(_mix(_noise(0.08, 0.4, 0.3), _tone(220, 0.1, 0.3, "square", 0.001, 3.0)))
	_sfx["level"] = _wav(_concat([
		_tone(523.25, 0.09, 0.3, "triangle", 0.004, 1.0),
		_tone(659.25, 0.09, 0.3, "triangle", 0.004, 1.0),
		_tone(783.99, 0.09, 0.3, "triangle", 0.004, 1.0),
		_tone(1046.5, 0.24, 0.32, "sine", 0.004, 1.5)]))
	_sfx["capture"] = _wav(_concat([
		_tone(660, 0.07, 0.22, "sine"), _tone(990, 0.07, 0.22, "sine"),
		_tone(1320, 0.07, 0.22, "sine"), _tone(1760, 0.18, 0.25, "sine")]))
	_sfx["feed"] = _wav(_mix(_noise(0.12, 0.25, 0.1), _tone(300, 0.08, 0.2, "triangle")))
	_sfx["quest"] = _wav(_concat([_tone(1046.5, 0.12, 0.25, "triangle"), _tone(1318.5, 0.28, 0.25, "sine")]))
	_sfx["victory"] = _wav(_concat([
		_tone(523.25, 0.12, 0.28, "triangle"), _tone(659.25, 0.12, 0.28, "triangle"),
		_tone(783.99, 0.12, 0.3, "triangle"), _tone(1046.5, 0.42, 0.32, "sine", 0.005, 1.2)]))
	_sfx["evolve"] = _wav(_mix(_tone(330, 0.6, 0.25, "triangle", 0.02, 1.2), _noise(0.5, 0.12, 0.05), 0.05))
	_sfx["ui"] = _wav(_tone(660, 0.04, 0.15, "sine", 0.001, 3.0))
	_sfx["splash"] = _wav(_noise(0.2, 0.35, 0.05))
	_sfx["thunder"] = _wav(_mix(_noise(0.8, 0.5, 0.02), _tone(60, 0.7, 0.3, "triangle", 0.01, 1.2)))
	_sfx["craft"] = _wav(_mix(_noise(0.07, 0.3, 0.2), _tone(700, 0.06, 0.2, "square", 0.001, 2.0)))
	_sfx["roar"] = _wav(_mix(_tone(110, 0.5, 0.35, "saw", 0.02, 1.5), _tone(165, 0.5, 0.2, "square", 0.02, 2.0)))
	_sfx["rift"] = _wav(_mix(_tone(220, 1.0, 0.2, "sine", 0.05, 0.7), _tone(333, 1.0, 0.13, "triangle", 0.06, 0.8)))
	seed(0)

func _make_music(night: bool) -> AudioStreamWAV:
	var dur := 12.0
	var n := int(dur * MRATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99117 if night else 77113
	var root := 110.0 if not night else 82.41
	var scale := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0, 2.245] if not night else [1.0, 1.189, 1.335, 1.498, 1.782, 2.0]
	var pad_freqs := [root, root * 1.5, root * 2.0, root * 2.5]
	if night:
		pad_freqs = [root, root * 1.189, root * 2.0, root * 2.378]
	var plucks: Array = []
	var t := 0.6
	while t < dur - 1.0:
		var f: float = root * 2.0 * scale[rng.randi_range(0, scale.size() - 1)]
		plucks.append({"t": t, "f": f, "a": rng.randf_range(0.06, 0.14)})
		t += rng.randf_range(1.1, 2.4)
	for i in n:
		var time := float(i) / MRATE
		var env := 0.6 + 0.4 * sin(time * 0.35 + (1.4 if night else 0.0))
		var v := 0.0
		for k in pad_freqs.size():
			v += sin(TAU * pad_freqs[k] * time + k * 0.7) * (0.12 / (k + 1))
		v *= env
		v += sin(TAU * root * 0.5 * time) * 0.045
		out[i] = v
	for p in plucks:
		var start := int(float(p.t) * MRATE)
		var freq: float = p.f
		var length := int(1.6 * MRATE)
		for j in length:
			var idx := start + j
			if idx >= n:
				break
			var tt := float(j) / MRATE
			var amp := pow(maxf(0.0, 1.0 - tt / 1.6), 3.0) * float(p.a)
			out[idx] += sin(TAU * freq * tt) * amp
			out[idx] += sin(TAU * freq * 2.0 * tt) * amp * 0.2
	var fade := int(0.15 * MRATE)
	for i in fade:
		out[i] *= float(i) / fade
		out[n - 1 - i] *= float(i) / fade
	return _wav(out, MRATE, true)
