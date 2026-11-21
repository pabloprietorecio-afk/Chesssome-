class_name TutorVoice
extends Node
## Preguntar al tutor hablando: puente con el complemento de Android «TutorVoz» (android_voz/TutorVoz.java), que usa
## el reconocimiento de voz del sistema. Sin el complemento (escritorio, pruebas, APK sin Gradle) `available()` es
## false y la app solo ofrece escribir. La app no graba audio: solo recibe el texto.

signal heard_partial(text: String)
signal heard(text: String)
signal failed(code: int)
signal listening_changed(on: bool)

const SINGLETON := "TutorVoz"
## Errores de SpeechRecognizer que significan «no he oído nada» (no es un fallo: se vuelve a intentar).
const NO_MATCH := [6, 7]
const PERMISSION_DENIED := 9
## Se cerró la ventana de dictado sin decir nada: no es un fallo, no se avisa.
const CANCELLED := -2
const LOCALES := {"es": "es-ES", "en": "en-US", "pt": "pt-PT", "fr": "fr-FR", "de": "de-DE", "it": "it-IT", "ru": "ru-RU", "hi": "hi-IN", "id": "id-ID", "ja": "ja-JP"}

var listening := false
var _p: Object
var _lang := "es-ES"
var _wired := false


func _plugin() -> Object:
	if _p == null and OS.has_feature("android") and Engine.has_singleton(SINGLETON):
		_p = Engine.get_singleton(SINGLETON)
	if _p != null and not _wired:
		_wired = true
		_p.connect("voz_parcial", func(t: String) -> void: heard_partial.emit(t))
		_p.connect("voz_texto", _on_text)
		_p.connect("voz_error", _on_error)
		_p.connect("voz_permiso", _on_permission)
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
	# El complemento decide: ventana de dictado del sistema o, si no la hay, el reconocedor (y pide el permiso).
	_start()


func stop() -> void:
	if _p != null and listening:
		_p.call("stop")


func cancel() -> void:
	if _p != null and listening:
		_p.call("cancel")
	_set_listening(false)


func _start() -> void:
	_set_listening(true)
	_p.call("start", _lang)


func _on_permission(ok: bool) -> void:
	if not ok:
		_set_listening(false)
		failed.emit(PERMISSION_DENIED)


func _on_text(t: String) -> void:
	_set_listening(false)
	heard.emit(t.strip_edges())


func _on_error(code: int) -> void:
	_set_listening(false)
	failed.emit(code)


func _set_listening(on: bool) -> void:
	if listening != on:
		listening = on
		listening_changed.emit(on)
