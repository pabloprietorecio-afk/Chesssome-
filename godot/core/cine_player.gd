class_name CinePlayer
extends RefCounted
## Puente con el reproductor nativo de YouTube (android_cine/YouTubeCine.java): ejecuta las órdenes del director
## (core/cine_film.gd) y le pasa las lecturas del vídeo. Solo existe en Android con el complemento (APK de Gradle);
## sin él, available() es false y la app abre el vídeo fuera, en YouTube.

const SINGLETON := "YouTubeCine"
## Solo para las pruebas (tests/test_cine_video.gd): un reproductor simulado con los mismos métodos que el nativo.
static var fake: Object = null

var _p: Object = null
var _id := ""
var _lang := "es"
var opened := false
var _rect := Rect2i()
var _shown := true


static func available() -> bool:
	return fake != null or (OS.has_feature("android") and Engine.has_singleton(SINGLETON))


func _init(video_id: String, lang: String) -> void:
	_id = video_id
	_lang = lang
	if fake != null:
		_p = fake
	elif available():
		_p = Engine.get_singleton(SINGLETON)


## Órdenes del director: cue (crea el reproductor parado en ese segundo la primera vez), play, pause, seek.
func run(commands: Array, rect: Rect2i) -> void:
	if _p == null:
		return
	for c: Dictionary in commands:
		match str(c["type"]):
			"cue":
				if not opened:
					_rect = rect
					_p.call("open", _id, float(c["at"]), rect.position.x, rect.position.y, rect.size.x, rect.size.y, _lang)
					opened = true
				else:
					_p.call("cue", float(c["at"]))
			"play":
				_p.call("play")
			"pause":
				_p.call("pause")
			"seek":
				_p.call("seek", float(c["at"]))


## Lo coloca sobre su hueco (píxeles de la ventana) si se ha movido.
func place(rect: Rect2i) -> void:
	if _p == null or not opened or rect == _rect:
		return
	_rect = rect
	_p.call("place", rect.position.x, rect.position.y, rect.size.x, rect.size.y)


## Oculto mientras hay algo de la app encima de su hueco (una hoja, un aviso): YouTube no deja tapar el reproductor.
func show(visible: bool) -> void:
	if _p == null or not opened or visible == _shown:
		return
	_shown = visible
	_p.call("show", visible)


## {ready, time, duration, state (el de YouTube: 1 = reproduciendo), error, blocked}. {} sin reproductor.
func snapshot() -> Dictionary:
	if _p == null or not opened:
		return {}
	var d: Variant = _p.call("snapshot")
	return d if d is Dictionary else {}


func close() -> void:
	if _p != null and opened:
		_p.call("close")
	opened = false
