extends Node
## Procedurally synthesised sound effects and a looping A-minor arpeggio. No audio files needed.

const RATE := 22050
const MODE_LABELS := ["♪ 소리: 켬", "♪ 음악: 끔", "♪ 소리: 끔"]

var streams: Dictionary = {}
var players: Array = []
var next_player: int = 0
var last_played: Dictionary = {}
var music: AudioStreamPlayer
var mode: int = 0   # 0 all on, 1 music off, 2 all off


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sfx()
	for i in 16:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		players.append(pl)
	music = AudioStreamPlayer.new()
	music.stream = _build_music()
	music.volume_db = -9.0
	add_child(music)
	music.play()


func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if mode == 2 or not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(name, -1000)) < 45:
		return
	last_played[name] = now
	var pl: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	pl.stream = streams[name]
	pl.pitch_scale = pitch * randf_range(0.97, 1.03)
	pl.volume_db = vol_db
	pl.play()


func cycle_mode() -> void:
	mode = (mode + 1) % 3
	music.stream_paused = mode != 0


# ---------- synthesis ----------

func _synth(dur: float, f0: float, f1: float, wave: String = "sine", vol: float = 0.4, decay: float = 8.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += lerpf(f0, f1, float(i) / n) / RATE
		var fr := ph - floorf(ph)
		var x := 0.0
		match wave:
			"sine":
				x = sin(TAU * ph)
			"tri":
				x = 4.0 * absf(fr - 0.5) - 1.0
			"square":
				x = (1.0 if fr < 0.5 else -1.0) * 0.45
			"noise":
				x = randf() * 2.0 - 1.0
			"bell":
				x = (sin(TAU * ph) + 0.5 * sin(TAU * ph * 2.0) + 0.25 * sin(TAU * ph * 3.01)) * 0.6
		var env := minf(1.0, t / 0.004) * exp(-decay * t)
		var tail := minf(1.0, float(n - i) / (0.006 * RATE))
		out[i] = x * vol * env * tail
	return out


func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for prt in parts:
		out.append_array(prt)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _build_sfx() -> void:
	streams["sub"] = _wav(_synth(0.07, 880, 780, "sine", 0.3, 30))
	streams["diff"] = _wav(_synth(0.13, 940, 430, "tri", 0.35, 16))
	streams["pulse"] = _wav(_mix(_synth(0.4, 220, 170, "sine", 0.45, 7), _synth(0.3, 440, 360, "tri", 0.12, 10)))
	streams["mod"] = _wav(_cat([_synth(0.06, 392, 392, "square", 0.25, 25), _synth(0.07, 523, 523, "square", 0.25, 25)]))
	streams["eval"] = _wav(_synth(0.7, 523, 523, "bell", 0.45, 5))
	streams["int"] = _wav(_synth(0.2, 300, 720, "tri", 0.3, 9))
	streams["coin"] = _wav(_cat([_synth(0.07, 988, 988, "sine", 0.28, 20), _synth(0.16, 1319, 1319, "sine", 0.28, 12)]))
	var notes := [523.3, 587.3, 659.3, 784.0, 880.0]
	for i in notes.size():
		streams["kill%d" % i] = _wav(_mix(_synth(0.45, notes[i], notes[i], "bell", 0.38, 8), _synth(0.25, notes[i] * 2.0, notes[i] * 2.0, "sine", 0.08, 14)))
	streams["leak"] = _wav(_mix(_synth(0.4, 120, 60, "square", 0.5, 6), _synth(0.12, 0, 0, "noise", 0.3, 30)))
	streams["build"] = _wav(_cat([_synth(0.07, 523, 523, "tri", 0.3, 18), _synth(0.12, 784, 784, "tri", 0.3, 14)]))
	streams["ui"] = _wav(_synth(0.035, 1200, 1100, "sine", 0.18, 50))
	streams["wave"] = _wav(_cat([_synth(0.12, 392, 392, "tri", 0.3, 10), _synth(0.12, 523, 523, "tri", 0.3, 10), _synth(0.3, 659, 659, "tri", 0.3, 6)]))
	streams["clear"] = _wav(_cat([_synth(0.1, 523, 523, "bell", 0.3, 9), _synth(0.1, 659, 659, "bell", 0.3, 9), _synth(0.1, 784, 784, "bell", 0.3, 9), _synth(0.45, 1046, 1046, "bell", 0.3, 5)]))
	streams["lose"] = _wav(_synth(1.1, 392, 130, "tri", 0.4, 2))
	var win: Array = []
	for f in [523.3, 659.3, 784.0, 1046.5, 1318.5]:
		win.append(_synth(0.13, f, f, "bell", 0.32, 6))
	win.append(_synth(0.6, 1568.0, 1568.0, "bell", 0.3, 3))
	streams["win"] = _wav(_cat(win))


func _build_music() -> AudioStreamWAV:
	# Am – F – C – G, eighth-note arpeggio at 100 bpm, 9.6 s loop.
	var eighth := 0.3
	var chords := [[440.0, 523.3, 659.3], [349.2, 440.0, 523.3], [392.0, 523.3, 659.3], [392.0, 493.9, 587.3]]
	var bass := [110.0, 87.3, 130.8, 98.0]
	var pattern := [0, 1, 2, 1, 0, 2, 1, 2]
	var total := int(eighth * 32 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for ci in 4:
		var ch: Array = chords[ci]
		var bstart := int(ci * 8 * eighth * RATE)
		var bf: float = bass[ci]
		var blen := int(8 * eighth * RATE)
		for i in blen:
			var t := float(i) / RATE
			var env := minf(1.0, t / 0.05) * exp(-0.9 * t) * minf(1.0, float(blen - i) / 600.0)
			buf[bstart + i] += (sin(TAU * bf * t) + 0.3 * sin(TAU * bf * 2.0 * t)) * 0.16 * env
		for k in 8:
			var f: float = ch[pattern[k]]
			var start := bstart + int(k * eighth * RATE)
			var nlen := mini(int(0.55 * RATE), total - start)
			for i in nlen:
				var t2 := float(i) / RATE
				var env2 := minf(1.0, t2 / 0.006) * exp(-5.5 * t2)
				buf[start + i] += (sin(TAU * f * t2) + 0.25 * sin(TAU * f * 2.0 * t2)) * 0.09 * env2
	return _wav(buf, true)
