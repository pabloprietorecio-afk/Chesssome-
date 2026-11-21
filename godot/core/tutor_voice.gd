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
		get_tree().on_request_permissions_result.connect(_on_permission)
	return _p


func available() -> bool:
	var p := _plugin()
	return p != null and bool(p.call("available"))


static func locale_for(language: String) -> String:
	return str(LOCALES.get(language, "en-US"))


func listen(language: String) -> void:
	var p := _plugin()
	if p == null:
		failed.emit(-1)
		return
	_lang = locale_for(language)
	_set_listening(true)
	# La primera vez Android pregunta por el permiso; al concederlo se empieza a escuchar.
	if not PERMISSION in OS.get_granted_permissions():
		_waiting_permission = true
		if not OS.request_permission(PERMISSION):
			return
		_waiting_permission = false
	p.call("start", _lang)


func stop() -> void:
	if _p != null and listening:
		_p.call("stop")


func cancel() -> void:
	_waiting_permission = false
	if _p != null and listening:
		_p.call("cancel")
	_set_listening(false)


func _on_permission(permission: String, granted: bool) -> void:
	if permission != PERMISSION or not _waiting_permission:
		return
	_waiting_permission = false
	if granted:
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
