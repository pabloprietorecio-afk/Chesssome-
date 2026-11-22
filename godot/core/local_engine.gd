class_name LocalEngine
extends Node
## Stockfish 19 dentro del móvil: puente con el complemento de Android «MotorStockfish» (android_motor/). Devuelve
## los análisis con la misma forma que el servicio del servidor (chess-api.com), con los valores desde las blancas:
## {move, depth, centipawns, mate, continuationArr, type: "bestmove"}. Sin el complemento (escritorio, pruebas, APK
## sin Gradle) `available()` es false y el tutor usa el Stockfish del servidor.

const SINGLETON := "MotorStockfish"
## Tiempo por posición: en un móvil actual, profundidad 18–22.
const THINK_MS := 800

## Pruebas: un Callable(fen, millis) -> String con la respuesta en bruto del complemento («move=…;cp=…;pv=…»).
var fake: Callable
## Pruebas: el Elo de la última jugada pedida con play().
var last_play_elo := -1
var _p: Object
var _wired := false
var _next := 0
var _results := {}

signal _arrived(id: int)


func _plugin() -> Object:
	if _p == null and OS.has_feature("android") and Engine.has_singleton(SINGLETON):
		_p = Engine.get_singleton(SINGLETON)
	if _p != null and not _wired:
		_wired = true
		_p.connect("analisis", _on_result, CONNECT_DEFERRED)
	return _p


func available() -> bool:
	if fake.is_valid():
		return true
	var p := _plugin()
	return p != null and bool(p.call("available"))


## Analiza `fen` durante `millis` ms. {} si no hay motor o falla.
func analyze(fen: String, millis: int = THINK_MS) -> Dictionary:
	if fake.is_valid():
		await get_tree().process_frame
		return parse(str(fake.call(fen, millis)), fen)
	var p := _plugin()
	if p == null:
		return {}
	_next += 1
	var id := _next
	p.call("analyze", id, fen, millis)
	while not _results.has(id):
		await _arrived
	var raw: String = _results[id]
	_results.erase(id)
	return parse(raw, fen)


## Jugada del rival (UCI) pensada `millis` ms con la fuerza limitada a `elo` (0: sin límite). "" si no hay motor o
## falla (entonces juega el rival de la app).
func play(fen: String, millis: int, elo: int) -> String:
	last_play_elo = elo
	var raw := ""
	if fake.is_valid():
		await get_tree().process_frame
		raw = str(fake.call(fen, millis))
	else:
		var p := _plugin()
		if p == null:
			return ""
		_next += 1
		var id := _next
		p.call("play", id, fen, millis, elo)
		while not _results.has(id):
			await _arrived
		raw = _results[id]
		_results.erase(id)
	# Del rival solo hace falta la jugada (sin puntuación, que con poca reflexión puede no venir).
	for part in raw.split(";", false):
		if part.begins_with("move="):
			var mv := part.substr(5)
			return mv if mv.length() >= 4 and mv != "(none)" else ""
	return ""


func _on_result(id: int, raw: String) -> void:
	_results[id] = raw
	_arrived.emit(id)


## «move=e2e4;depth=20;cp=35;pv=e2e4,e7e5» (valores desde el bando que mueve) → forma del servidor, desde las blancas.
static func parse(raw: String, fen: String) -> Dictionary:
	var kv := {}
	for part in raw.split(";", false):
		var i := part.find("=")
		if i > 0:
			kv[part.left(i)] = part.substr(i + 1)
	var move := str(kv.get("move", ""))
	if kv.has("error") or move.length() < 4 or move == "(none)":
		return {}
	var sign := -1 if fen.get_slice(" ", 1) == "b" else 1
	var out := {"type": "bestmove", "move": move, "depth": int(kv.get("depth", "0")), "mate": null, "centipawns": null}
	if kv.has("mate"):
		out["mate"] = int(kv["mate"]) * sign
	elif kv.has("cp"):
		out["centipawns"] = int(kv["cp"]) * sign
	else:
		return {}
	out["continuationArr"] = Array(str(kv.get("pv", move)).split(",", false))
	return out
