extends Node
## Fully procedural audio engine. A layered score (pads, bells, bass, strings,
## taiko/percussion) is rendered per game state — explore, night, combat, boss —
## plus an ambience bed and material-aware SFX. No external files, fully offline.

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

var _tracks: Dictionary = {}
var _music_players: Dictionary = {}
var _current_track := ""
var _track_pending: Dictionary = {}
var _track_mutex := Mutex.new()
var _track_tasks: Array[int] = []

var _amb_day: AudioStreamWAV
var _amb_night: AudioStreamWAV
var _amb_players: Array[AudioStreamPlayer] = []
var _amb_night_on := false
var _music_started := false
var _combat_timer := 0.0
var _boss_timer := 0.0

var master_volume := 0.8
var music_volume := 0.75
var sfx_volume := 0.9

const RATE := 22050
const MRATE := 16000
const MUSIC_DB := -15.0
const AMB_DB := -27.0

const TRACK_KEYS := ["explore", "night", "combat", "boss"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sfx()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	for key in TRACK_KEYS:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Master"
		mp.volume_db = -80.0
		add_child(mp)
		_music_players[key] = mp
	for i in 2:
		var ap := AudioStreamPlayer.new()
		ap.bus = "Master"
		ap.volume_db = -80.0
		add_child(ap)
		_amb_players.append(ap)
	apply_volumes()

func _process(delta: float) -> void:
	if _combat_timer > 0.0:
		_combat_timer = maxf(0.0, _combat_timer - delta)
	if _boss_timer > 0.0:
		_boss_timer = maxf(0.0, _boss_timer - delta)
	_collect_pending()
	if not _music_started:
		return
	_update_state()
	_update_ambience()

func _update_state() -> void:
	var state := "explore"
	if Game.in_game and Game.is_night():
		state = "night"
	if _combat_timer > 0.0:
		state = "combat"
	if _boss_timer > 0.0:
		state = "boss"
	if state == _current_track:
		return
	if not _music_players.has(state):
		return
	if not _tracks.has(state):
		return
	_current_track = state
	var tw := create_tween()
	var base := MUSIC_DB + linear_to_db(maxf(music_volume, 0.001))
	for key in _music_players:
		var mp: AudioStreamPlayer = _music_players[key]
		if key == state:
			mp.stream = _tracks[key]
			if not mp.playing:
				mp.play()
			tw.parallel().tween_property(mp, "volume_db", base, 1.8)
		elif mp.playing:
			tw.parallel().tween_property(mp, "volume_db", -80.0, 1.8)

func pulse_combat(seconds: float = 9.0) -> void:
	_combat_timer = maxf(_combat_timer, seconds)

func pulse_boss(seconds: float = 40.0) -> void:
	_boss_timer = maxf(_boss_timer, seconds)

func end_combat() -> void:
	_combat_timer = 0.0

# ------------------------------------------------------------------ volumes

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
	for key in _music_players:
		var mp: AudioStreamPlayer = _music_players[key]
		var db := -80.0
		if key == _current_track:
			db = MUSIC_DB + linear_to_db(maxf(music_volume, 0.001))
		mp.volume_db = db
	var amb_db := AMB_DB + linear_to_db(maxf(music_volume, 0.001))
	for ap in _amb_players:
		if ap.playing:
			ap.volume_db = amb_db

# ------------------------------------------------------------------ sfx

func play(sound: String, pitch_variation: float = 0.08) -> void:
	if not _sfx.has(sound):
		if sound.ends_with("_stone") or sound.ends_with("_wood") or sound.ends_with("_dirt"):
			play("dig", pitch_variation)
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
	p.volume_db = linear_to_db(clampf(sfx_volume, 0.001, 1.0)) - 3.0
	p.play()

func play_pitched(sound: String, pitch: float) -> void:
	if not _sfx.has(sound):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sfx[sound]
	p.pitch_scale = clampf(pitch, 0.4, 2.2)
	p.volume_db = linear_to_db(clampf(sfx_volume, 0.001, 1.0)) - 3.0
	p.play()

# ------------------------------------------------------------------ music

func start_music() -> void:
	if _music_started:
		return
	_music_started = true
	if not _tracks.has("explore"):
		_tracks["explore"] = _render_track("explore")
	_render_later(["night", "combat", "boss"])
	_amb_day = _render_ambience(false)
	_amb_night = _render_ambience(true)
	_current_track = ""
	if "--audio-log" in OS.get_cmdline_user_args():
		_report_tracks()
	if _amb_players.size() > 0:
		_amb_players[0].stream = _amb_day
		_amb_players[1].stream = _amb_night
		_amb_players[0].play()
		_amb_players[1].play()
		_amb_players[0].volume_db = AMB_DB + linear_to_db(maxf(music_volume, 0.001))
		_amb_players[1].volume_db = -80.0
	_update_state()

func stop_music() -> void:
	_music_started = false
	var tw := create_tween()
	for key in _music_players:
		var mp: AudioStreamPlayer = _music_players[key]
		tw.parallel().tween_property(mp, "volume_db", -80.0, 0.5)
	for ap in _amb_players:
		tw.parallel().tween_property(ap, "volume_db", -80.0, 0.5)
	tw.tween_callback(func():
		for key in _music_players:
			(_music_players[key] as AudioStreamPlayer).stop()
		for ap in _amb_players:
			ap.stop())

func _report_tracks() -> void:
	for key in _tracks:
		var w: AudioStreamWAV = _tracks[key]
		var frames := w.data.size() / (4 if w.stereo else 2)
		var peak := 0
		var step := maxi(1, w.data.size() / 3000)
		for i in range(0, w.data.size() - 1, step):
			peak = maxi(peak, absi(w.data.decode_s16(i)))
		print("MUSIC %s dur=%.2fs rate=%d peak=%d" % [key, float(frames) / float(w.mix_rate), w.mix_rate, peak])

func _render_later(states: Array) -> void:
	for state in states:
		if _tracks.has(state) or _track_pending.has(state):
			continue
		_track_pending[state] = true
		var callable := _render_job.bind(str(state))
		_track_tasks.append(WorkerThreadPool.add_task(callable, false, "music_" + str(state)))

func _render_job(state: String) -> void:
	var stream := _render_track(state)
	_track_mutex.lock()
	_tracks[state] = stream
	_track_mutex.unlock()

func _exit_tree() -> void:
	for id in _track_tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	_track_tasks.clear()

func _collect_pending() -> void:
	for state in _track_pending.keys():
		if _tracks.has(state):
			_track_pending.erase(state)

func _update_ambience() -> void:
	if _amb_players.size() < 2 or not Game.in_game:
		return
	var want_night := Game.is_night()
	if want_night == _amb_night_on:
		return
	_amb_night_on = want_night
	var tw := create_tween()
	var base := AMB_DB + linear_to_db(maxf(music_volume, 0.001))
	tw.parallel().tween_property(_amb_players[0], "volume_db", -80.0 if want_night else base, 3.5)
	tw.parallel().tween_property(_amb_players[1], "volume_db", base if want_night else -80.0, 3.5)

# ------------------------------------------------------------------ synthesis core

func _freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)

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

func _wav_stereo(left: PackedFloat32Array, right: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var frames := mini(left.size(), right.size())
	var data := PackedByteArray()
	data.resize(frames * 4)
	for i in frames:
		data.encode_s16(i * 4, int(clampf(left[i], -1.0, 1.0) * 32000.0))
		data.encode_s16(i * 4 + 2, int(clampf(right[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = true
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = frames
	return s

func _normalize(buf: PackedFloat32Array, peak: float = 0.9) -> void:
	var top := 0.001
	for i in buf.size():
		var v := absf(buf[i])
		if v > top:
			top = v
	var gain := peak / top
	if gain > 4.0:
		gain = 4.0
	for i in buf.size():
		buf[i] *= gain

func _note(buf: PackedFloat32Array, t0: float, dur: float, freq: float, amp: float, instr: String) -> void:
	var rate := MRATE
	var start := int(t0 * rate)
	var n := int(dur * rate)
	if start >= buf.size() or n <= 0:
		return
	var ph := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var lp := 0.0
	var attack := 0.01
	var release := 0.12
	match instr:
		"pad": attack = 0.55; release = 0.9
		"bell": attack = 0.004; release = 0.06
		"pluck": attack = 0.006; release = 0.1
		"bass": attack = 0.02; release = 0.18
		"strings": attack = 0.12; release = 0.28
		"brass": attack = 0.05; release = 0.2
	var body := dur - release
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / rate
		ph += TAU * freq / rate
		ph2 += TAU * freq * 2.01 / rate
		ph3 += TAU * freq * 1.5 / rate
		var v := 0.0
		match instr:
			"pad":
				v = sin(ph) * 0.45 + sin(ph3) * 0.3 + fmod(ph / TAU, 1.0) * 0.12
				lp = lerpf(lp, v, 0.045)
				v = lp
			"bell":
				v = sin(ph) * 0.7 + sin(ph2) * 0.22 + sin(ph * 4.2) * 0.08
			"pluck":
				v = asin(sin(ph)) * 0.4 + sin(ph) * 0.35 + sin(ph2) * 0.12
			"bass":
				v = sin(ph) * 0.8 + asin(sin(ph)) * 0.22
			"strings":
				v = fmod(ph / TAU, 1.0) * 0.28 + sin(ph * 1.004) * 0.3 + sin(ph * 0.996) * 0.2
				lp = lerpf(lp, v, 0.22)
				v = lp
			"brass":
				v = sin(ph) * 0.42 + fmod(ph / TAU, 1.0) * 0.32 + sin(ph2) * 0.12
				lp = lerpf(lp, v, 0.35)
				v = lp
		var env := 1.0
		if t < attack:
			env = t / maxf(attack, 0.001)
		elif t > body:
			env = maxf(0.0, 1.0 - (t - body) / maxf(release, 0.001))
		var decay := 1.0
		match instr:
			"bell": decay = pow(maxf(0.0, 1.0 - t / dur), 3.2)
			"pluck": decay = pow(maxf(0.0, 1.0 - t / dur), 2.4)
			"pad": decay = 1.0 - 0.25 * (t / dur)
		buf[idx] += v * amp * env * decay

func _kick(buf: PackedFloat32Array, t0: float, amp: float) -> void:
	var start := int(t0 * MRATE)
	var n := int(0.3 * MRATE)
	var ph := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / MRATE
		var f := lerpf(150.0, 42.0, clampf(t / 0.09, 0.0, 1.0))
		ph += TAU * f / MRATE
		var env := pow(maxf(0.0, 1.0 - t / 0.3), 3.0)
		buf[idx] += sin(ph) * amp * env
		if t < 0.012:
			buf[idx] += randf_range(-1.0, 1.0) * amp * 0.25

func _snare(buf: PackedFloat32Array, t0: float, amp: float) -> void:
	var start := int(t0 * MRATE)
	var n := int(0.2 * MRATE)
	var ph := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / MRATE
		ph += TAU * 190.0 / MRATE
		var env := pow(maxf(0.0, 1.0 - t / 0.2), 3.4)
		buf[idx] += randf_range(-1.0, 1.0) * amp * env * 0.8 + sin(ph) * amp * env * 0.3

func _hat(buf: PackedFloat32Array, t0: float, amp: float) -> void:
	var start := int(t0 * MRATE)
	var n := int(0.06 * MRATE)
	var lp := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / MRATE
		var w := randf_range(-1.0, 1.0)
		lp = lerpf(lp, w, 0.85)
		var env := pow(maxf(0.0, 1.0 - t / 0.06), 4.0)
		buf[idx] += (w - lp) * amp * env

func _taiko(buf: PackedFloat32Array, t0: float, amp: float) -> void:
	_kick(buf, t0, amp * 0.9)
	var start := int(t0 * MRATE)
	var n := int(0.4 * MRATE)
	var lp := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / MRATE
		var w := randf_range(-1.0, 1.0)
		lp = lerpf(lp, w, 0.06)
		var env := pow(maxf(0.0, 1.0 - t / 0.4), 3.0)
		buf[idx] += lp * amp * env * 0.5

func _reverb(buf: PackedFloat32Array, wet: float = 0.26) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(buf.size())
	var d1 := int(0.031 * MRATE)
	var d2 := int(0.037 * MRATE)
	var d3 := int(0.011 * MRATE)
	for i in buf.size():
		var v := buf[i]
		if i >= d1:
			v += out[i - d1] * 0.42
		if i >= d2:
			v += out[i - d2] * 0.36
		out[i] = v * 0.62 + (out[i - d3] * 0.3 if i >= d3 else 0.0)
	for i in buf.size():
		buf[i] = buf[i] * (1.0 - wet) + out[i] * wet
	return buf

func _render_track(state: String) -> AudioStreamWAV:
	var bpm := 74.0
	var bars := 4
	var chords: Array = []
	var drums := "shaker"
	var pad_amp := 0.12
	var arp := "bell"
	var arp_amp := 0.1
	var bass_amp := 0.2
	var lead_amp := 0.0
	match state:
		"explore":
			bpm = 74.0
			chords = [[50, 57, 62, 66], [47, 54, 62, 69], [43, 59, 62, 66], [45, 57, 61, 67]]
			drums = "shaker"
			pad_amp = 0.13
			arp = "bell"
			arp_amp = 0.1
			bass_amp = 0.2
			lead_amp = 0.1
		"night":
			bpm = 56.0
			chords = [[45, 52, 60, 67], [41, 48, 57, 64], [48, 55, 64, 67], [43, 50, 59, 64]]
			drums = "none"
			pad_amp = 0.15
			arp = "bell"
			arp_amp = 0.075
			bass_amp = 0.16
			lead_amp = 0.06
		"combat":
			bpm = 138.0
			chords = [[50, 53, 57], [46, 50, 53, 58], [48, 52, 55, 60], [45, 49, 52, 57]]
			drums = "war"
			pad_amp = 0.1
			arp = "strings"
			arp_amp = 0.13
			bass_amp = 0.24
			lead_amp = 0.11
		"boss":
			bpm = 150.0
			chords = [[37, 43, 49, 55], [38, 44, 50, 56], [37, 42, 49, 54], [36, 42, 48, 53]]
			drums = "boss"
			pad_amp = 0.16
			arp = "brass"
			arp_amp = 0.15
			bass_amp = 0.26
			lead_amp = 0.12
	var beat := 60.0 / bpm
	var bar_len := beat * 4.0
	var total := bar_len * bars
	var buf := PackedFloat32Array()
	buf.resize(int(total * MRATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + state.length() * 97
	for bar in bars:
		var t := bar * bar_len
		var chord: Array = chords[bar % chords.size()]
		# pad chord
		for k in chord.size():
			var f := _freq(float(chord[k]) + (12.0 if k == chord.size() - 1 else 0.0))
			_note(buf, t, bar_len * 1.04, f, pad_amp / (1.0 + k * 0.25), "pad")
		# bass
		var root: float = _freq(float(chord[0]) - 12.0)
		if drums == "war" or drums == "boss":
			var steps := 8
			for s in steps:
				var st := t + float(s) * beat * 0.5
				if state == "boss" and s % 2 == 1:
					_note(buf, st, beat * 0.4, root * 2.0, bass_amp * 0.75, "bass")
				else:
					_note(buf, st, beat * 0.42, root, bass_amp, "bass")
		else:
			_note(buf, t, bar_len * 0.95, root, bass_amp, "bass")
			_note(buf, t + bar_len * 0.5, bar_len * 0.4, root, bass_amp * 0.5, "bass")
		# arpeggio / comping
		var tones: Array = []
		for c in chord:
			tones.append(float(c) + 12.0)
		var arp_steps := 8 if drums != "none" else 4
		for s in arp_steps:
			if state == "night" and s % 2 == 1:
				continue
			if rng.randf() > (0.72 if drums == "none" else 0.62):
				continue
			var tone: float = tones[s % tones.size()]
			if rng.randf() < 0.3:
				tone += 12.0
			var st2 := t + float(s) * (bar_len / arp_steps)
			_note(buf, st2, (beat * 1.5) if drums == "none" else (beat * 0.6), _freq(tone), arp_amp, arp)
		# percussion
		match drums:
			"shaker":
				for s in 8:
					if s % 2 == 0:
						_hat(buf, t + float(s) * beat * 0.5, 0.05)
				if bar % 2 == 1:
					_taiko(buf, t, 0.14)
			"war":
				for b in 4:
					_kick(buf, t + float(b) * beat, 0.3 if b % 2 == 0 else 0.18)
				_snare(buf, t + beat, 0.2)
				_snare(buf, t + beat * 3.0, 0.22)
				for s in 8:
					_hat(buf, t + float(s) * beat * 0.5, 0.07)
			"boss":
				_kick(buf, t, 0.38)
				_kick(buf, t + beat * 2.0, 0.3)
				_snare(buf, t + beat, 0.24)
				_snare(buf, t + beat * 3.0, 0.26)
				_taiko(buf, t + beat * 3.5, 0.2)
				for s in 8:
					_hat(buf, t + float(s) * beat * 0.5, 0.08)
		# sparse lead
		if lead_amp > 0.0 and rng.randf() < 0.6:
			var lead_tone: float = tones[1 % tones.size()] + (12.0 if rng.randf() < 0.4 else 0.0)
			_note(buf, t + beat * rng.randf_range(0.0, 1.6), beat * 2.0, _freq(lead_tone), lead_amp, arp if arp != "strings" else "pluck")
	# gentle loop seam
	var fade := int(0.08 * MRATE)
	for i in fade:
		var g := float(i) / fade
		buf[i] *= g
		buf[buf.size() - 1 - i] *= g
	_normalize(buf, 0.82)
	_reverb(buf, 0.3)
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(buf.size())
	right.resize(buf.size())
	var lofs := int(0.008 * MRATE)
	var rofs := int(0.014 * MRATE)
	for i in buf.size():
		left[i] = buf[i] * 0.92
		right[i] = buf[i] * 0.88
		if i >= lofs:
			left[i] += buf[i - lofs] * 0.14
		if i >= rofs:
			right[i] += buf[i - rofs] * 0.14
	return _wav_stereo(left, right, MRATE, true)

# ------------------------------------------------------------------ ambience

func _render_ambience(night: bool) -> AudioStreamWAV:
	var dur := 14.0
	var n := int(dur * MRATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717 if night else 9917
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / MRATE
		var w := randf_range(-1.0, 1.0)
		lp = lerpf(lp, w, 0.02)
		lp2 = lerpf(lp2, w, 0.004)
		var swell := 0.55 + 0.45 * sin(t * 0.22 + (2.1 if night else 0.0))
		var wind := (lp - lp2) * (0.30 if not night else 0.38) * swell
		buf[i] = wind
	# birds by day, crickets by night
	var t2 := 0.4
	while t2 < dur - 0.5:
		var start := int(t2 * MRATE)
		if night:
			var pulses := 5
			for p in pulses:
				var st := start + p * int(0.09 * MRATE)
				for j in int(0.045 * MRATE):
					var idx := st + j
					if idx >= n:
						break
					var tt := float(j) / MRATE
					buf[idx] += sin(TAU * 4300.0 * tt) * 0.02 * (1.0 - tt / 0.045)
		else:
			var notes := rng.randi_range(2, 4)
			for p in notes:
				var f0 := rng.randf_range(1900.0, 3100.0)
				var st := start + p * int(0.12 * MRATE)
				var length := int(0.09 * MRATE)
				for j in length:
					var idx := st + j
					if idx >= n:
						break
					var tt := float(j) / MRATE
					var f := f0 * (1.0 + 0.25 * tt / 0.09)
					buf[idx] += sin(TAU * f * tt) * 0.024 * pow(maxf(0.0, 1.0 - tt / 0.09), 1.6)
		t2 += rng.randf_range(2.4, 4.6)
	var fade := int(0.5 * MRATE)
	for i in fade:
		var g := float(i) / fade
		buf[i] *= g
		buf[n - 1 - i] *= g
	_normalize(buf, 0.5)
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(n)
	right.resize(n)
	for i in n:
		left[i] = buf[i] * 0.95
		right[i] = buf[i] * 0.9
	return _wav_stereo(left, right, MRATE, true)

# ------------------------------------------------------------------ sfx library

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
			env = t / maxf(attack, 0.0001)
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
	seed(4242)
	var stone_dig := _mix(_noise(0.08, 0.45, 0.32), _tone(150, 0.06, 0.24, "square", 0.001, 3.4))
	_sfx["dig"] = _wav(stone_dig)
	_sfx["dig_stone"] = _wav(stone_dig)
	_sfx["dig_wood"] = _wav(_mix(_noise(0.09, 0.34, 0.5), _tone(210, 0.07, 0.24, "triangle", 0.001, 2.6)))
	_sfx["dig_dirt"] = _wav(_mix(_noise(0.1, 0.4, 0.14), _tone(110, 0.07, 0.16, "triangle", 0.001, 2.2)))
	_sfx["dig_metal"] = _wav(_mix(_noise(0.06, 0.3, 0.7), _tone(880, 0.09, 0.16, "sine", 0.001, 3.0)))
	_sfx["break"] = _wav(_mix(_noise(0.22, 0.5, 0.16), _tone(88, 0.16, 0.32, "triangle", 0.002, 2.0)))
	_sfx["place"] = _wav(_mix(_tone(150, 0.09, 0.36, "triangle", 0.002, 2.6), _noise(0.05, 0.16, 0.4)))
	_sfx["pickup"] = _wav(_concat([_tone(880, 0.05, 0.22, "sine"), _tone(1320, 0.09, 0.18, "sine")]))
	_sfx["hurt"] = _wav(_mix(_noise(0.18, 0.28), _tone(180, 0.2, 0.34, "saw", 0.002, 2.0)))
	_sfx["jump"] = _wav(_tone(430, 0.1, 0.22, "sine", 0.003, 1.5))
	_sfx["dodge"] = _wav(_mix(_noise(0.22, 0.3, 0.55), _tone(300, 0.14, 0.14, "triangle", 0.01, 1.6)))
	_sfx["swing"] = _wav(_noise(0.13, 0.26, 0.62))
	_sfx["hit"] = _wav(_mix(_noise(0.07, 0.38, 0.3), _tone(230, 0.1, 0.3, "square", 0.001, 3.2)))
	_sfx["step_grass"] = _wav(_noise(0.07, 0.16, 0.12))
	_sfx["step_stone"] = _wav(_mix(_noise(0.06, 0.14, 0.42), _tone(180, 0.04, 0.07, "square", 0.001, 3.0)))
	_sfx["step_wood"] = _wav(_mix(_noise(0.06, 0.13, 0.3), _tone(240, 0.05, 0.08, "triangle", 0.001, 3.2)))
	_sfx["level"] = _wav(_concat([
		_tone(523.25, 0.1, 0.26, "triangle", 0.004, 1.0),
		_tone(659.25, 0.1, 0.26, "triangle", 0.004, 1.0),
		_tone(783.99, 0.1, 0.28, "triangle", 0.004, 1.0),
		_tone(1046.5, 0.3, 0.3, "sine", 0.004, 1.5)]))
	_sfx["capture"] = _wav(_concat([
		_tone(660, 0.07, 0.2, "sine"), _tone(990, 0.07, 0.2, "sine"),
		_tone(1320, 0.07, 0.2, "sine"), _tone(1760, 0.2, 0.22, "sine")]))
	_sfx["feed"] = _wav(_mix(_noise(0.13, 0.22, 0.1), _tone(310, 0.09, 0.18, "triangle")))
	_sfx["cook"] = _wav(_mix(_noise(0.5, 0.18, 0.06), _tone(190, 0.4, 0.1, "triangle", 0.02, 1.4)))
	_sfx["eat"] = _wav(_mix(_noise(0.18, 0.2, 0.2), _tone(140, 0.14, 0.14, "triangle", 0.01, 2.0)))
	_sfx["quest"] = _wav(_concat([_tone(1046.5, 0.12, 0.22, "triangle"), _tone(1318.5, 0.3, 0.22, "sine")]))
	_sfx["unlock"] = _wav(_concat([
		_tone(392, 0.14, 0.2, "triangle"), _tone(587.33, 0.14, 0.2, "triangle"),
		_tone(783.99, 0.34, 0.24, "sine", 0.005, 1.4)]))
	_sfx["victory"] = _wav(_concat([
		_tone(523.25, 0.12, 0.26, "triangle"), _tone(659.25, 0.12, 0.26, "triangle"),
		_tone(783.99, 0.12, 0.28, "triangle"), _tone(1046.5, 0.45, 0.3, "sine", 0.005, 1.2)]))
	_sfx["evolve"] = _wav(_mix(_tone(330, 0.7, 0.22, "triangle", 0.02, 1.2), _noise(0.6, 0.1, 0.05), 0.05))
	_sfx["ui"] = _wav(_tone(660, 0.04, 0.13, "sine", 0.001, 3.0))
	_sfx["sell"] = _wav(_concat([_tone(1180, 0.05, 0.16, "sine"), _tone(1560, 0.1, 0.14, "sine")]))
	_sfx["buy"] = _wav(_concat([_tone(720, 0.05, 0.16, "sine"), _tone(540, 0.09, 0.14, "sine")]))
	_sfx["splash"] = _wav(_noise(0.22, 0.32, 0.05))
	_sfx["thunder"] = _wav(_mix(_noise(0.9, 0.46, 0.02), _tone(58, 0.8, 0.28, "triangle", 0.01, 1.2)))
	_sfx["craft"] = _wav(_mix(_noise(0.07, 0.26, 0.24), _tone(720, 0.06, 0.18, "square", 0.001, 2.2)))
	_sfx["roar"] = _wav(_mix(_tone(108, 0.55, 0.32, "saw", 0.02, 1.5), _tone(162, 0.55, 0.18, "square", 0.02, 2.0)))
	_sfx["boss_warn"] = _wav(_mix(_tone(72, 1.6, 0.3, "saw", 0.2, 0.9), _tone(108, 1.6, 0.16, "triangle", 0.25, 1.1)))
	_sfx["rift"] = _wav(_mix(_tone(220, 1.1, 0.18, "sine", 0.05, 0.7), _tone(333, 1.1, 0.12, "triangle", 0.06, 0.8)))
	seed(0)
