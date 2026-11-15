extends SceneTree
## Prueba de la parte pura del cliente online (core/online.gd): identificadores, colores, latido, fecha HTTP,
## lector de eventos SSE, copia local de los datos y jugadas. La red se prueba aparte, contra Firebase.
## Uso: godot --headless --path godot -s tests/test_online.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var id := Online.new_game_id(1794715205, rng)
	_ok(id.begins_with("20261115-040005-") and id.length() == 22, "id con hora al segundo (%s)" % id)
	_ok(Online.new_game_id(1794715205, rng) < Online.new_game_id(1794715206, rng), "los ids ordenan cronológicamente")
	_ok(Online.color_of(1000, "creador") == 0 and Online.color_of(1000, "rival") == 1, "par: creador blancas")
	_ok(Online.color_of(1001, "creador") == 1 and Online.color_of(1001, "rival") == 0, "impar: creador negras")
	_ok(Online.is_fresh(100000.0, 110000.0), "latido reciente")
	_ok(not Online.is_fresh(100000, 200000.0), "latido viejo")
	_ok(not Online.is_fresh(null, 1.0), "sin latido")
	_ok(Online.parse_http_date("Sun, 15 Nov 2026 04:00:00 GMT") == 1794715200000.0, "fecha HTTP")
	_ok(Online.parse_http_date("basura") < 0.0, "fecha HTTP rota")

	# SSE en trozos
	var a := Online.sse_push("", "event: put\ndata: {\"path\":\"/\",\"da")
	_ok((a["events"] as Array).is_empty(), "SSE: trozo incompleto")
	var b := Online.sse_push(str(a["buffer"]), "ta\":{\"a\":1}}\n\nevent: keep-alive\ndata: null\n\nevent: patch\r\ndata: {\"path\":\"/x\",\"data\":{\"b\":2}}\r\n\r\n")
	var evs: Array = b["events"]
	_ok(evs.size() == 3 and str(evs[0]["event"]) == "put" and str(evs[1]["event"]) == "keep-alive" and str(evs[2]["event"]) == "patch", "SSE: tres eventos")
	_ok(int((evs[0]["data"] as Dictionary)["data"]["a"]) == 1, "SSE: datos del put")

	# Copia local
	var t: Variant = null
	t = Online.apply_event(t, {"event": "put", "data": {"path": "/", "data": {"creador": "a"}}})
	t = Online.apply_event(t, {"event": "patch", "data": {"path": "/", "data": {"rival": "b", "unidoEn": 7}}})
	t = Online.apply_event(t, {"event": "put", "data": {"path": "/jugadas/0", "data": "e2e4"}})
	t = Online.apply_event(t, {"event": "put", "data": {"path": "/jugadas/1", "data": "e7e5"}})
	var d: Dictionary = t
	_ok(str(d["creador"]) == "a" and str(d["rival"]) == "b" and int(d["unidoEn"]) == 7, "put y patch")
	_ok(Online.moves_of(t) == ["e2e4", "e7e5"], "jugadas en orden")
	t = Online.apply_event(t, {"event": "put", "data": {"path": "/jugadas/1", "data": null}})
	_ok(Online.moves_of(t) == ["e2e4"], "borrar una jugada")
	_ok(Online.moves_of({"jugadas": ["e2e4", "e7e5"]}) == ["e2e4", "e7e5"], "jugadas como array")
	_ok(Online.moves_of({"jugadas": {"0": "e2e4", "2": "g1f3"}}) == ["e2e4"], "sin huecos")
	t = Online.apply_event(t, {"event": "put", "data": {"path": "/", "data": null}})
	_ok(t == null, "put nulo en la raíz vacía todo")

	# Quién juega con qué
	var doc := {"creador": "a", "rival": "b", "unidoEn": 1001}
	_ok(Online.color_for(doc, "a") == 1 and Online.color_for(doc, "b") == 0, "color de cada jugador")
	_ok(Online.color_for(doc, "x") == -1, "un tercero no juega")
	_ok(Online.color_for({"creador": "a"}, "a") == -1, "sin rival no hay color")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
