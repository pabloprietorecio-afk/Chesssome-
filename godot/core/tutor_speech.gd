class_name TutorSpeech
extends Node
## La voz del tutor: lee en voz alta lo que contesta (Pablo, 22 nov: «la voz generada para A Tank Story me gusta para
## el tutor»). Es Kokoro con la voz del tutorial de A Tank Story (em_santa en español), sin el efecto de radio; la
## genera el servidor (/voz/decir, worker/src/speech.js), que además pasa las jugadas a palabras («Cxf5+» →
## «caballo toma en efe cinco, jaque»). docs/voz-tutor.md.
## - El texto se parte en trozos de unas pocas frases (el primero, corto, para que empiece antes); el siguiente se
##   pide mientras suena el anterior.
## - Lo ya dicho se guarda en el móvil (user://voz_tutor): repetirlo no vuelve a pedirse ni cuesta nada.
## - Sin servidor, sin red o en un idioma sin voz de Kokoro (alemán, ruso, indonesio): la voz del sistema del móvil,
##   con el texto ya preparado que devuelve el servidor si ha contestado.

signal speaking_changed(on: bool)

const CACHE_DIR := "user://voz_tutor"
## Lo que se guarda como mucho (archivos); al pasarse, se borran los más antiguos.
const CACHE_MAX := 300
## Largo de cada trozo (caracteres): un par de frases. El servidor admite 1500.
const CHUNK := 320
## El primero, más corto: empieza a sonar antes.
const CHUNK_FIRST := 140
const TIMEOUT := 20.0

## Dirección de /voz/decir ("" sin servidor: solo la voz del sistema).
var url := ""
var enabled := true
var speaking := false
## Pruebas: Callable(text, language) -> Dictionary con {"audio": base64} o {"_error": código, "texto": ...}.
var fake_server: Callable
## Pruebas: lo que se ha dicho con la voz del sistema.
var system_said: Array = []
## Pruebas: no reproducir (no hay dispositivo de audio).
var mute_output := false

var _player: AudioStreamPlayer
var _gen := 0
var _lang := "es"
## Trozos que faltan por decir y el audio ya pedido de cada uno (Dictionary del servidor), por posición.
var _chunks: Array = []
var _pending: Dictionary = {}
var _index := 0
var _system_utterance := -1
## Trozo que ya se está diciendo (para no empezarlo dos veces).
var _started := -1


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_finished)
	if system_voice_possible():
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_system_end)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_system_end)


## La voz del sistema se puede usar (la plataforma la tiene y está activada en project.godot).
static func system_voice_possible() -> bool:
	return bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)) and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)


## Lee el texto (corta lo que estuviera sonando).
func say(text: String, language: String) -> void:
	stop()
	if not enabled:
		return
	var clean := text.strip_edges()
	if clean == "":
		return
	_gen += 1
	_lang = language
	_chunks = split(clean, CHUNK, CHUNK_FIRST)
	_pending = {}
	_index = 0
	_started = -1
	_set_speaking(true)
	_fetch(0)
	_fetch(1)
	_play_current()


func stop() -> void:
	_gen += 1
	_chunks = []
	_pending = {}
	_started = -1
	if _player != null and _player.playing:
		_player.stop()
	if _system_utterance >= 0:
		_system_utterance = -1
		if system_voice_possible():
			DisplayServer.tts_stop()
	_set_speaking(false)


func _set_speaking(on: bool) -> void:
	if speaking != on:
		speaking = on
		speaking_changed.emit(on)


## Trozos de unas frases, sin cortar ninguna (una frase más larga que `size` va sola). El primero, de `first`.
static func split(text: String, size: int, first: int = -1) -> Array:
	var re := RegEx.create_from_string("[^.!?…\\n]+(?:[.!?…]+[»”\"')]*|\\n|$)")
	var out: Array = []
	var cur := ""
	for m: RegExMatch in re.search_all(text):
		var s := m.get_string().strip_edges()
		if s == "":
			continue
		var limit := first if out.is_empty() and first > 0 else size
		if cur != "" and cur.length() + 1 + s.length() > limit:
			out.append(cur)
			cur = s
		else:
			cur = s if cur == "" else cur + " " + s
	if cur != "":
		out.append(cur)
	return out


# ---------------------------------------------------------------- pedir el audio

func _fetch(i: int) -> void:
	if i >= _chunks.size() or _pending.has(i):
		return
	var gen := _gen
	_pending[i] = null
	var data: Dictionary = await _get_audio(str(_chunks[i]), _lang)
	if gen != _gen:
		return
	_pending[i] = data
	if i == _index:
		_play_current()


func _get_audio(text: String, language: String) -> Dictionary:
	var key := _cache_key(text, language)
	var path := CACHE_DIR.path_join(key + ".mp3")
	if FileAccess.file_exists(path):
		return {"bytes": FileAccess.get_file_as_bytes(path)}
	var data := {}
	if fake_server.is_valid():
		data = await fake_server.call(text, language)
	elif url != "":
		data = await _post(text, language)
	else:
		data = {"_error": -1}
	if data.has("audio"):
		var bytes := Marshalls.base64_to_raw(str(data["audio"]))
		if bytes.size() > 0:
			_cache_put(path, bytes)
			return {"bytes": bytes}
		return {"_error": 502}
	return data


func _post(text: String, language: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	var err := req.request(url, PackedStringArray(["content-type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"text": text, "language": language}))
	if err != OK:
		req.queue_free()
		return {"_error": 0}
	var r: Array = await req.request_completed
	req.queue_free()
	var body: Variant = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8()) if int(r[0]) == HTTPRequest.RESULT_SUCCESS else null
	if int(r[1]) == 200 and body is Dictionary:
		return body
	var out := {"_error": int(r[1])}
	if body is Dictionary and (body as Dictionary).get("detail") is Dictionary:
		out["texto"] = str((body["detail"] as Dictionary).get("texto", ""))
	return out


static func _cache_key(text: String, language: String) -> String:
	return (language + "|" + text).sha256_text().left(24)


func _cache_put(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(bytes)
	f.close()
	var files := DirAccess.get_files_at(CACHE_DIR)
	if files.size() <= CACHE_MAX:
		return
	var aged: Array = []
	for name in files:
		var p := CACHE_DIR.path_join(name)
		aged.append([FileAccess.get_modified_time(p), p])
	aged.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for k in files.size() - CACHE_MAX:
		DirAccess.remove_absolute(str(aged[k][1]))


# ---------------------------------------------------------------- reproducir

func _play_current() -> void:
	if _index >= _chunks.size():
		_chunks = []
		_set_speaking(false)
		return
	if not _pending.has(_index):
		_fetch(_index)
		return
	var data: Variant = _pending[_index]
	if data == null or _started == _index:
		return  # todavía llegando (_fetch lo reproduce al llegar) o ya sonando
	_started = _index
	_fetch(_index + 1)
	var d: Dictionary = data
	if d.has("bytes"):
		if mute_output:
			_advance.call_deferred()
			return
		var stream := AudioStreamMP3.new()
		stream.data = d["bytes"]
		if stream.get_length() <= 0.0:
			_advance.call_deferred()
			return
		_player.stream = stream
		_player.play()
		return
	_say_system(str(d.get("texto", "")) if str(d.get("texto", "")) != "" else str(_chunks[_index]))


func _on_finished() -> void:
	_advance()


func _advance() -> void:
	if _chunks.is_empty():
		return
	_pending.erase(_index)
	_index += 1
	_play_current()


## Voz del sistema del móvil (Godot: DisplayServer.tts_*). Si no hay, se calla y sigue.
func _say_system(text: String) -> void:
	system_said.append(text)
	if mute_output or not system_voice_possible():
		_advance.call_deferred()
		return
	var voices := DisplayServer.tts_get_voices_for_language(_lang)
	if voices.is_empty():
		_advance.call_deferred()
		return
	_system_utterance = _index + 1000 * (_gen % 1000)
	DisplayServer.tts_speak(text, voices[0], 100, 1.0, 1.0, _system_utterance)


func _on_system_end(id: int) -> void:
	if id != _system_utterance:
		return
	_system_utterance = -1
	_advance.call_deferred()
