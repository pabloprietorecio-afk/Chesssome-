class_name CuadroSonidos
extends RefCounted
## Efectos del cuadro del campeonato, sintetizados al vuelo (sin ficheros): «whoosh» del vuelo de una ficha,
## golpe de la derrota, campanita al formarse la ficha nueva y fanfarria de la corona.

const RATE := 22050
static var _cache := {}
static var _player: Array[AudioStreamPlayer] = []


static func play(d: Node, kind: String, volume_db: float = -8.0) -> void:
	if not bool(d.get("sound_on")):
		return
	var s := _stream(kind)
	if s == null or not is_instance_valid(d) or not d.is_inside_tree():
		return
	var p: AudioStreamPlayer = null
	for q in _player:
		if is_instance_valid(q) and not q.playing:
			p = q
			break
	if p == null:
		p = AudioStreamPlayer.new()
		d.add_child(p)
		_player.append(p)
	p.stream = s
	p.volume_db = volume_db
	p.play()


static func _stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var data := PackedFloat32Array()
	match kind:
		"whoosh":
			data = _whoosh()
		"thud":
			data = _thud()
		"chime":
			data = _chime([784.0, 1175.0], 0.7)
		"fanfare":
			data = _fanfare()
		_:
			return null
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	_cache[kind] = w
	return w


static func _whoosh() -> PackedFloat32Array:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var env := sin(PI * t) * sin(PI * t)
		var k := 0.04 + 0.5 * t * t
		lp += k * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * env * 1.6
	return out


static func _thud() -> PackedFloat32Array:
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var f := 140.0 * exp(-t * 9.0) + 50.0
		out[i] = sin(TAU * f * t) * exp(-t * 11.0) * 0.9
	return out


static func _chime(freqs: Array, length: float) -> PackedFloat32Array:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var v := 0.0
		for f: float in freqs:
			v += sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)
		out[i] = v / float(freqs.size()) * exp(-t * 5.0) * 0.5
	return out


static func _fanfare() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var starts := [0.0, 0.14, 0.28, 0.45]
	var n := int(RATE * 1.6)
	var out := PackedFloat32Array()
	out.resize(n)
	for j in notes.size():
		var f: float = notes[j]
		var i0 := int(RATE * float(starts[j]))
		for i in range(i0, n):
			var t := float(i - i0) / float(RATE)
			var env := minf(t * 60.0, 1.0) * exp(-t * (2.2 if j == 3 else 5.0))
			out[i] += (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t) + 0.2 * sin(TAU * f * 3.0 * t)) * env * 0.28
	return out
