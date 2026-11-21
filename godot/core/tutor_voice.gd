class_name TutorVoice
extends Node
## Preguntar al tutor hablando: puente con el complemento de Android «TutorVoz» (android_voz/TutorVoz.java), copiado
## del de A Tank Story (que funciona en el móvil de Pablo), con el reconocimiento de voz del sistema. El permiso del
## micrófono se pide aquí, con OS.request_permission, como allí. Sin el complemento (escritorio, pruebas, APK sin
## Gradle) `available()` es false y la app solo ofrece escribir. La app no graba audio: solo recibe el texto.

signal heard_partial(text: String)
signal heard(text: String)
signal failed(code: int)
signal listening_changed(on: bool)

const SINGLETON := "TutorVoz"
const PERMISSION := "android.permission.RECORD_AUDIO"
## Errores de SpeechRecognizer que significan «no he oído nada» (no es un fallo: se vuelve a intentar).
const NO_MATCH := [6, 7]
const PERMISSION_DENIED := 9
const LOCALES := {"es": "es-ES", "en": "en-US", "pt": "pt-PT", "fr": "fr-FR", "de": "de-DE", "it": "it-IT", "ru": "ru-RU", "hi": "hi-IN", "id": "id-ID", "ja": "ja-JP"}

var listening := false
## Dictado con Whisper en el servidor (/voz): la app graba y el servidor transcribe con el vocabulario de ajedrez.
## Si está vacío o falla, el reconocedor de Android (complemento TutorVoz), como antes.
var server_url := ""
## Pruebas: Callable(audio_wav_base64) -> String con lo «oído», en lugar del servidor.
var fake_server: Callable
var _p: Object
var _lang := "es-ES"
var _wired := false
var _waiting_permission := false


func _plugin() -> Object:
	if _p == null and OS.has_feature("android") and Engine.has_singleton(SINGLETON):
		_p = Engine.get_singleton(SINGLETON)
	if _p != null and not _wired:
		_wired = true
		_p.connect("voz_parcial", func(t: String) -> void: heard_partial.emit(fix_chess_words(t, _lang.left(2))), CONNECT_DEFERRED)
		_p.connect("voz_texto", _on_text, CONNECT_DEFERRED)
		_p.connect("voz_error", _on_error, CONNECT_DEFERRED)
		_wire_permission()
	return _p


func _wire_permission() -> void:
	if not get_tree().on_request_permissions_result.is_connected(_on_permission):
		get_tree().on_request_permissions_result.connect(_on_permission)


func available() -> bool:
	if _recording_possible():
		return true
	var p := _plugin()
	return p != null and bool(p.call("available"))


func _recording_possible() -> bool:
	return server_url != "" and OS.has_feature("android")


static func locale_for(language: String) -> String:
	return str(LOCALES.get(language, "en-US"))


func listen(language: String) -> void:
	_lang = locale_for(language)
	if _recording_possible():
		_set_listening(true)
		if not PERMISSION in OS.get_granted_permissions():
			_waiting_permission = true
			if not OS.request_permission(PERMISSION):
				return
			_waiting_permission = false
		_record_start()
		return
	var p := _plugin()
	if p == null:
		failed.emit(-1)
		return
	_set_listening(true)
	# La primera vez Android pregunta por el permiso; al concederlo se empieza a escuchar.
	if not PERMISSION in OS.get_granted_permissions():
		_waiting_permission = true
		if not OS.request_permission(PERMISSION):
			return
		_waiting_permission = false
	p.call("start", _lang)


func stop() -> void:
	if _recording:
		_record_finish()
		return
	if _p != null and listening:
		_p.call("stop")


func cancel() -> void:
	_waiting_permission = false
	if _recording:
		_record_stop()
	_rec_gen += 1
	if _p != null and listening:
		_p.call("cancel")
	_set_listening(false)


func _on_permission(permission: String, granted: bool) -> void:
	if permission != PERMISSION or not _waiting_permission:
		return
	_waiting_permission = false
	if granted and _recording_possible():
		_record_start()
	elif granted:
		_p.call("start", _lang)
	else:
		_set_listening(false)
		failed.emit(PERMISSION_DENIED)


func _on_text(t: String) -> void:
	_set_listening(false)
	heard.emit(fix_chess_words(t.strip_edges(), _lang.left(2)))


## Lo que el reconocedor de voz suele entender mal en una app de ajedrez (no sabe de qué hablamos): «al fin» por
## «alfil» (Pablo, 22 nov), «peor de rey» por «peón de rey»… Solo en español, con cuidado de no tocar frases normales.
const FIXES_ES := [
	["(?i)\\bal fin\\b", "alfil"],
	["(?i)\\bal fil\\b", "alfil"],
	["(?i)\\bpeor de (rey|dama|reina|torre|alfil|caballo)\\b", "peón de $1"],
	["(?i)\\bpeores de (rey|dama|reina|torre|alfil|caballo)\\b", "peones de $1"],
	["(?i)\\ben roque\\b", "enroque"],
]


static func fix_chess_words(text: String, language: String) -> String:
	if language != "es":
		return text
	var out := text
	for f: Array in FIXES_ES:
		var re := RegEx.create_from_string(str(f[0]))
		out = re.sub(out, str(f[1]), true)
	return out


func _on_error(code: int) -> void:
	_set_listening(false)
	failed.emit(code)


func _set_listening(on: bool) -> void:
	if listening != on:
		listening = on
		listening_changed.emit(on)



# ---------------------------------------------------------------- grabar y transcribir con Whisper (servidor)

const RATE := 16000
## Corta sola: 1,3 s de silencio después de hablar; como mucho 12 s; si en 7 s no se oye nada, se rinde.
const SILENCE_S := 1.3
const MAX_S := 12.0
const NOTHING_S := 7.0
## Nivel (RMS) a partir del cual hay voz.
const VOICE_RMS := 0.02

signal transcribing

var _recording := false
var _rec_gen := 0
var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _samples := PackedFloat32Array()
var _rec_t := 0.0
var _heard_voice := false
var _quiet_t := 0.0
var _carry := 0.0


func _record_setup() -> void:
	if _player != null:
		return
	var bus := AudioServer.get_bus_index("Dictado")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Dictado")
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus, _capture)
		# Que no se oiga por el altavoz lo que entra por el micrófono.
		AudioServer.set_bus_mute(bus, true)
	else:
		_capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Dictado"
	add_child(_player)


func _record_start() -> void:
	_wire_permission()
	_record_setup()
	_capture.clear_buffer()
	_samples = PackedFloat32Array()
	_rec_t = 0.0
	_quiet_t = 0.0
	_carry = 0.0
	_heard_voice = false
	_recording = true
	_player.play()
	set_process(true)


func _record_stop() -> void:
	_recording = false
	if _player != null:
		_player.stop()
	set_process(false)


func _process(delta: float) -> void:
	if not _recording:
		return
	_rec_t += delta
	var frames := _capture.get_frames_available()
	if frames > 0:
		var buf := _capture.get_buffer(frames)
		var step := AudioServer.get_mix_rate() / float(RATE)
		var energy := 0.0
		for i in buf.size():
			var v := (buf[i].x + buf[i].y) * 0.5
			energy += v * v
			# Pasa a 16 kHz tomando una muestra cada `step` (el habla cabe de sobra en 8 kHz).
			_carry += 1.0
			if _carry >= step:
				_carry -= step
				_samples.append(v)
		var rms := sqrt(energy / float(maxi(1, buf.size())))
		if rms >= VOICE_RMS:
			_heard_voice = true
			_quiet_t = 0.0
		else:
			_quiet_t += delta
	if (_heard_voice and _quiet_t >= SILENCE_S) or _rec_t >= MAX_S:
		_record_finish()
	elif not _heard_voice and _rec_t >= NOTHING_S:
		_record_stop()
		_set_listening(false)
		failed.emit(NO_MATCH[0])


func _record_finish() -> void:
	_record_stop()
	if not _heard_voice or _samples.size() < RATE / 4:
		_set_listening(false)
		failed.emit(NO_MATCH[0])
		return
	transcribing.emit()
	_rec_gen += 1
	var gen := _rec_gen
	var audio := Marshalls.raw_to_base64(wav_bytes(_samples, RATE))
	var text := ""
	if fake_server.is_valid():
		text = str(fake_server.call(audio))
	else:
		var req := HTTPRequest.new()
		req.timeout = 25.0
		add_child(req)
		var err := req.request(server_url, PackedStringArray(["content-type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"audio": audio, "language": _lang.left(2)}))
		if err == OK:
			var r: Array = await req.request_completed
			if int(r[0]) == HTTPRequest.RESULT_SUCCESS and int(r[1]) == 200:
				var data: Variant = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
				if data is Dictionary:
					text = str((data as Dictionary).get("text", ""))
		req.queue_free()
	if gen != _rec_gen:
		return
	_set_listening(false)
	text = fix_chess_words(text.strip_edges(), _lang.left(2))
	if text == "":
		failed.emit(NO_MATCH[0])
	else:
		heard.emit(text)


## WAV de 16 bits, mono, a partir de muestras entre −1 y 1.
static func wav_bytes(samples: PackedFloat32Array, rate: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)  # «RIFF»
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)  # «WAVE»
	h.encode_u32(12, 0x20746d66)  # «fmt »
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)
	h.encode_u16(22, 1)
	h.encode_u32(24, rate)
	h.encode_u32(28, rate * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)  # «data»
	h.encode_u32(40, data.size())
	return h + data
