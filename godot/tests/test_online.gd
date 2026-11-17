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

	# Espacios (ritmos)
	for r in ["0+0", "5+3", "10+5", "15+10", "20+0", "30+0", "1+0", "180+60", "7+2"]:
		_ok(Online.rhythm_ok(r), "ritmo válido " + r)
	for r in ["", "5", "0+3", "181+0", "5+61", "05+3", "-1+0", "5+3+1", "a+b", "5 +3"]:
		_ok(not Online.rhythm_ok(r), "ritmo no válido «%s»" % r)
	_ok(Online.rhythm_parts("15+10") == [15, 10] and Online.rhythm_parts("basura") == [0, 0], "partes del ritmo")
	_ok(Online.SPACES.all(func(r: String) -> bool: return Online.rhythm_ok(r)), "los espacios fijos son válidos")
	# War Chess: los mismos ritmos con una «w» delante, en espacios aparte.
	for r in ["w0+0", "w5+3", "w180+60"]:
		_ok(Online.rhythm_ok(r) and Online.is_war(r), "espacio de War Chess " + r)
	for r in ["ww5+3", "W5+3", "x5+3", "w", "w0+3", "5+3w"]:
		_ok(not Online.rhythm_ok(r), "espacio no válido «%s»" % r)
	_ok(Online.rhythm_parts("w15+10") == [15, 10] and Online.rhythm_label("w20+0") == Online.rhythm_label("20+0"), "un espacio de War Chess tiene el reloj de su ritmo")
	_ok(Online.space_of("5+3", true) == "w5+3" and Online.space_of("w5+3", false) == "5+3" and Online.space_of("w5+3", true) == "w5+3", "espacio de un ritmo en cada modalidad")
	_ok(not Online.is_war("5+3") and Online.space_label("5+3") == "5+3" and Online.space_label("w5+3") == "War Chess · 5+3", "nombre del espacio")

	# Reloj por las pulsaciones (5+3: 300 000 ms y 3 000 por jugada); el rival entra en t = 1 000 000
	var base := 300000.0
	var inc := 3000.0
	var c0 := Online.clock_state({"unidoEn": 1000000}, base, inc)
	_ok(c0["left"] == [base, base] and int(c0["side"]) == 0 and float(c0["since"]) == 1000000.0 and int(c0["presses"]) == 0, "reloj al empezar: corre el de blancas")
	var c1 := Online.clock_state({"unidoEn": 1000000, "pulsos": {"0": 1010000, "1": 1030000}}, base, inc)
	_ok(c1["left"] == [base - 10000.0 + inc, base - 20000.0 + inc] and int(c1["side"]) == 0 and float(c1["since"]) == 1030000.0 and int(c1["flag"]) == -1, "dos pulsaciones: cada uno gasta lo suyo y suma el incremento")
	var c2 := Online.clock_state({"unidoEn": 1000000, "pulsos": [1010000, 1030000, 1040000]}, base, inc)
	_ok(int(c2["side"]) == 1 and int(c2["presses"]) == 3, "pulsaciones como array")
	var c3 := Online.clock_state({"unidoEn": 0, "pulsos": {"0": 310000}}, base, inc)
	_ok(int(c3["flag"]) == 0, "pulsar después de agotar el tiempo: pierde por tiempo")
	var c4 := Online.clock_state({"unidoEn": 0, "pulsos": {"0": 10000, "2": 20000}}, base, inc)
	_ok(int(c4["presses"]) == 1, "pulsaciones sin huecos")

	# Quién espera en cada espacio
	var rows := {
		"20261116-100000-aaaaaa": {"creador": "u1", "latido": 990000, "ritmo": "5+3"},
		"20261116-100001-bbbbbb": {"creador": "u2", "latido": 995000, "ritmo": "5+3"},
		"20261116-100002-cccccc": {"creador": "u3", "latido": 995000, "ritmo": "7+2"},
		"20261116-100003-dddddd": {"creador": "yo", "latido": 995000, "ritmo": "5+3"},
		"20261116-100004-eeeeee": {"creador": "u4", "latido": 900000, "ritmo": "5+3"},
		"20261116-100005-ffffff": {"creador": "malo", "latido": 995000, "ritmo": "0+0"},
		"20261116-100006-gggggg": {"creador": "u5", "latido": 995000, "ritmo": "0+0", "no": {"yo": true}},
		"20261116-100007-hhhhhh": {"creador": "u6", "latido": 995000, "ritmo": "99999+0"},
		"20261116-100008-iiiiii": {"creador": "u7", "latido": 995000},
		"20261116-100009-jjjjjj": {"creador": "u8", "latido": 995000, "ritmo": "w5+3"},
	}
	var sp := Online.spaces_of(rows, "yo", 1000000.0, {"malo": "Malo"})
	_ok(sp.get("5+3", []) == ["20261116-100000-aaaaaa", "20261116-100001-bbbbbb"], "5+3: dos esperando, la más antigua primero")
	_ok(sp.get("7+2", []) == ["20261116-100002-cccccc"], "espacio personalizado")
	_ok(not sp.has("0+0"), "sin las de bloqueados ni las de quien me ha bloqueado")
	_ok(sp.get("w5+3", []) == ["20261116-100009-jjjjjj"], "las de War Chess, en su propio espacio (no en 5+3)")
	_ok(sp.size() == 3, "sin la mía, las viejas ni las de ritmo raro (%s)" % str(sp))
	_ok(Online.spaces_of(null, "yo", 0.0, {}).is_empty(), "sin partidas en espera")
	# «¿Sigues ahí?»: el límite depende del ritmo
	_ok(Online.idle_limit_ms(0.0) == 180000.0, "sin reloj: 3 minutos")
	_ok(Online.idle_limit_ms(300000.0) == 60000.0 and Online.idle_limit_ms(600000.0) == 120000.0, "5+3 → 1 min, 10+5 → 2 min")
	_ok(Online.idle_limit_ms(1800000.0) == 300000.0 and Online.idle_limit_ms(10800000.0) == 300000.0, "30 min o más → 5 min")
	_ok(Online.idle_limit_ms(60000.0) == 60000.0, "1 minuto → al menos 1 min")
	var o: Online = Online.new()
	o.phase = "playing"
	o.uid = "a"
	o.rival_uid = "b"
	o.my_color = 0
	o.base_ms = 0.0
	o._applied = 1
	o._track_turn()
	_ok(o.on_move() == 1 and o.idle_ms(0) == 0.0, "sin reloj, tras mi jugada le toca al rival")
	o._turn_at = Time.get_ticks_msec() - 200000
	_ok(o.idle_ms(1) >= 200000.0, "lleva más de 3 minutos sin jugar")
	o._check_extras({"creador": "a", "rival": "b", "sigo": {"b": 123456}})
	_ok(o.idle_ms(1) < 1000.0, "«Sigo aquí» del rival: vuelve a contar desde cero")
	var got := []
	o.ended.connect(func(reason: String, winner: int) -> void: got.append([reason, winner]))
	o._check_fin({"fin": {"tipo": "abandono", "pierde": 1, "de": "a", "t": 1}})
	_ok(got == [["ausencia", 0]] and o.phase == "ended", "fin por abandono: gana el que lo reclama")
	o.free()
	# Bloqueados al abrir: por rutas («no/<uid>»), que es lo que dejan las reglas; los 50 últimos.
	var bl := {}
	for i in 60:
		bl["u%d" % i] = "Jugador %d" % i
	var row := Online.blocked_row(bl)
	_ok(row.size() == 50 and row.has("no/u59") and not row.has("no/u9") and row["no/u10"] == true, "bloqueados: 50 últimos, como rutas no/<uid>")
	_ok(not row.has("no") and Online.blocked_row({}).is_empty(), "nunca la lista entera «no» (daba 401)")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
