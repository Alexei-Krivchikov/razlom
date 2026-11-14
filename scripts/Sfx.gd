extends Node

# No audio packs yet, so every sound is synthesized at startup.

const RATE := 22050
const VOICES := 8

var _streams := {}
var _volumes := {"swing": -10.0, "hit": -4.0, "death": -6.0, "hurt": -4.0, "upgrade": -6.0}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams["swing"] = _to_wav(_swing())
	_streams["hit"] = _to_wav(_hit())
	_streams["death"] = _to_wav(_death())
	_streams["hurt"] = _to_wav(_hurt())
	_streams["upgrade"] = _to_wav(_upgrade())
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = _to_wav(_music_loop(), true)
	_music.volume_db = -14.0
	add_child(_music)


func play(id: String) -> void:
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[id]
	p.volume_db = _volumes[id]
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


func start_music() -> void:
	if not _music.playing:
		_music.play()


func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _swing() -> PackedFloat32Array:
	var b := _buf(0.11)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var k := lerpf(0.05, 0.5, t)
		lp += (randf_range(-1, 1) - lp) * k
		b[i] = lp * sin(t * PI) * 0.9
	return b


func _hit() -> PackedFloat32Array:
	var b := _buf(0.14)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += lerpf(190.0, 50.0, t) / RATE
		var env := pow(1.0 - t, 2.0)
		b[i] = (sin(TAU * phase) * 0.9 + randf_range(-1, 1) * 0.5 * (1.0 - t * 3.0 if t < 0.33 else 0.0)) * env
	return b


func _death() -> PackedFloat32Array:
	var b := _buf(0.32)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += lerpf(420.0, 70.0, t) / RATE
		var sq := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var crushed := floorf((sq * 0.4 + randf_range(-1, 1) * 0.4) * 6.0) / 6.0
		b[i] = crushed * (1.0 - t)
	return b


func _hurt() -> PackedFloat32Array:
	var b := _buf(0.26)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += (140.0 + sin(t * 60.0) * 25.0) / RATE
		var sq := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		b[i] = sq * 0.5 * (1.0 - t)
	return b


func _upgrade() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var b := _buf(0.5)
	var step := b.size() / notes.size()
	for i in b.size():
		var n: int = mini(i / step, notes.size() - 1)
		var local := float(i - n * step) / step
		var t := float(i) / RATE
		var env := (1.0 - local) * (1.0 - float(i) / b.size() * 0.5)
		b[i] = (sin(TAU * notes[n] * t) + 0.3 * sin(TAU * notes[n] * 2.0 * t)) * env * 0.5
	return b


func _music_loop() -> PackedFloat32Array:
	# 120 bpm, 4 bars of A-minor bass, kick on beats, hat on off-beats.
	var bass := [55.0, 55.0, 110.0, 55.0, 65.41, 65.41, 130.81, 65.41,
		49.0, 49.0, 98.0, 49.0, 41.2, 41.2, 82.41, 61.74]
	var eighth := RATE / 4
	var b := _buf(8.0)
	var phase := 0.0
	var lp := 0.0
	for i in b.size():
		var step := i / eighth
		var in_step := float(i % eighth) / eighth
		var note: float = bass[(step / 2) % bass.size()] if step % 2 == 0 else bass[(step / 2) % bass.size()] * 2.0
		phase += note / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		lp += (saw - lp) * 0.12
		var s := lp * 0.35 * (1.0 - in_step * 0.6)
		if step % 2 == 0:
			var kt := in_step * eighth / RATE
			s += sin(TAU * (50.0 + 90.0 * exp(-kt * 30.0)) * kt) * exp(-kt * 12.0) * 0.6
		else:
			s += randf_range(-1, 1) * 0.12 * exp(-in_step * 18.0)
		b[i] = s * 0.8
	return b
