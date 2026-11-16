extends SceneTree
## El vídeo dentro de la app (el cine, fase 2): el director (core/cine_film.gd) y el tablero sincronizado. Las mismas
## pruebas que tenía la rama `cine-video` (tests/videoCine.test.ts, «director» y «tablero sincronizado»), con los
## mismos números, más las de los datos reales de data/cine.json.
## Uso: godot --headless --path godot -s tests/test_cine_film.gd

var fallos := 0
var hechos := 0
const EPS := CineFilm.EPS


func _init() -> void:
	_director()
	_sincronia()
	_datos()
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _mini(over: Dictionary = {}) -> Dictionary:
	var f := {"start": 10.0, "end": 60.0, "duration": 100.0, "stops": [{"at": 20.0, "resume": null}, {"at": 40.0, "resume": null}]}
	f.merge(over, true)
	return f


func _tick(time: float, now: float, playing := true, duration := 100.0) -> Dictionary:
	return {"type": "tick", "time": time, "duration": duration, "playing": playing, "now": now}


## Lanza los eventos y devuelve {state, commands: [órdenes de cada evento]}.
func _drive(film: Dictionary, events: Array, from: Dictionary = {}) -> Dictionary:
	var state: Dictionary = from if not from.is_empty() else CineFilm.initial()
	var cmds: Array = []
	for e: Dictionary in events:
		var r := CineFilm.direct(film, state, e)
		state = r["state"]
		cmds.append(r["commands"])
	return {"state": state, "commands": cmds}


func _director() -> void:
	var m := _mini()
	# Modo película: carga en el inicio y pausa justo antes de la marca.
	var r := _drive(m, [{"type": "start", "mode": "film"}, _tick(10.2, 0), _tick(19.5, 100), _tick(20 - EPS + 0.01, 200)])
	_ok(r["commands"] == [[{"type": "cue", "at": 10.0}], [], [], [{"type": "pause"}]], "película: cue al inicio y pausa antes de la marca")
	_ok(r["state"]["phase"] == "asking" and int(r["state"]["stop"]) == 0, "película: pregunta de la primera pausa")

	# Parado (aún sin ▶): nada.
	r = _drive(m, [{"type": "start", "mode": "film"}, _tick(20, 0, false), _tick(20, 100, false)])
	_ok(r["state"]["phase"] == "watching" and r["commands"].slice(1) == [[], []], "con el vídeo parado no hace nada")

	# Margen tras la pausa, un reintento y después se respeta al jugador.
	var start := _drive(m, [{"type": "start", "mode": "film"}, _tick(19.95, 1000)])
	var grace := _drive(m, [_tick(20.1, 1300)], start["state"])
	_ok(grace["commands"] == [[]] and grace["state"]["phase"] == "asking", "dentro del margen no pasa nada")
	var retry := _drive(m, [_tick(20.3, 1700)], grace["state"])
	_ok(retry["commands"] == [[{"type": "pause"}]], "un único reintento de pausa")
	var resumed := _drive(m, [_tick(20.6, 2000), _tick(21.2, 2400)], retry["state"])
	_ok(resumed["commands"] == [[], []] and resumed["state"]["phase"] == "reveal" and resumed["state"]["missed"] == "resumed", "si sigue, el jugador quiere ver: no se le para")

	# ▶ durante la pregunta: sigue viendo y puede volver.
	var asking := _drive(m, [{"type": "start", "mode": "film"}, _tick(19.95, 0), _tick(19.97, 300, false)])
	var res2 := _drive(m, [_tick(20.4, 9000)], asking["state"])
	_ok(res2["state"]["phase"] == "reveal" and res2["state"]["missed"] == "resumed" and res2["commands"] == [[]], "▶ en la pregunta: sigue viendo")
	var back := _drive(m, [{"type": "back", "now": 9500}], res2["state"])
	_ok(back["state"]["phase"] == "asking" and back["commands"] == [[{"type": "pause"}]], "y puede volver a la pregunta")

	# Revelar: reproduce sin saltar si está donde se paró; salta si se movió.
	var ask_st: Dictionary = _drive(m, [{"type": "start", "mode": "film"}, _tick(19.95, 0)])["state"]
	_ok(_drive(m, [{"type": "reveal", "time": 19.97}], ask_st)["commands"] == [[{"type": "play"}]], "revelar en el sitio: solo play")
	_ok(_drive(m, [{"type": "reveal", "time": 55.0}], ask_st)["commands"] == [[{"type": "seek", "at": 20.0}, {"type": "play"}]], "revelar lejos: seek y play")
	_ok(_drive(m, [{"type": "reveal", "time": null}], ask_st)["commands"] == [[{"type": "seek", "at": 20.0}, {"type": "play"}]], "revelar sin lectura: seek y play")

	# Segunda parada y final.
	r = _drive(m, [{"type": "start", "mode": "film"}, _tick(19.95, 0), _tick(19.97, 400, false), {"type": "reveal", "time": 19.97}, _tick(30, 5000), _tick(39.9, 15000)])
	_ok(r["state"]["phase"] == "asking" and int(r["state"]["stop"]) == 1 and r["commands"][-1] == [{"type": "pause"}], "segunda parada")
	var end := _drive(m, [_tick(39.95, 15400, false), {"type": "reveal", "time": 39.95}, _tick(50, 20000), _tick(59.9, 30000), _tick(61, 31000)], r["state"])
	_ok(end["state"]["phase"] == "ended" and end["commands"] == [[], [{"type": "play"}], [], [{"type": "pause"}], []], "final del clip")

	# Saltar por delante: no se le para; puede volver.
	r = _drive(m, [{"type": "start", "mode": "film"}, _tick(25, 0)])
	_ok(r["state"]["phase"] == "reveal" and r["state"]["missed"] == "skipped" and r["commands"][1] == [], "saltó la marca: no se le para")
	back = _drive(m, [{"type": "back", "now": 100}], r["state"])
	_ok(back["state"]["phase"] == "asking" and int(back["state"]["stop"]) == 0, "puede volver a la pregunta saltada")

	# Anuncio (duración distinta): no actúa; al volver el vídeo, sí.
	r = _drive(m, [{"type": "start", "mode": "film"}, _tick(20, 0, true, 30), _tick(25, 100, true, 30)])
	_ok(r["state"]["phase"] == "watching" and bool(r["state"]["ad"]) and r["commands"].slice(1) == [[], []], "anuncio: no actúa")
	var after := _drive(m, [_tick(10.1, 31000), _tick(19.9, 41000)], r["state"])
	_ok(not bool(after["state"]["ad"]) and after["state"]["phase"] == "asking", "tras el anuncio, pausa normal")

	# Modo directo: pregunta sin vídeo; al revelar, carga parado en la marca.
	r = _drive(m, [{"type": "start", "mode": "direct"}, _tick(50, 0)])
	_ok(r["state"]["phase"] == "asking" and not bool(r["state"]["video_on"]) and r["commands"] == [[], []], "directo: sin vídeo")
	var rev := _drive(m, [{"type": "reveal", "time": null}, _tick(20.1, 1000, false), _tick(30, 9000), _tick(39.9, 19000)], r["state"])
	_ok(rev["commands"][0] == [{"type": "cue", "at": 20.0}] and rev["state"]["phase"] == "asking" and int(rev["state"]["stop"]) == 1, "directo: al revelar, cue en la marca")

	# Sin marcas: directo, y la revelación empieza donde pueda.
	var no_marks := _mini({"start": null, "end": null, "stops": [{"at": null, "resume": null}]})
	r = _drive(no_marks, [{"type": "start", "mode": "film"}])
	_ok(r["state"]["phase"] == "asking" and r["state"]["mode"] == "direct", "sin marcas: directo")
	_ok(_drive(no_marks, [{"type": "reveal", "time": null}], r["state"])["commands"] == [[{"type": "cue", "at": 0.0}]], "sin marcas: revelar desde el principio")

	# Pedir la pregunta sin esperar.
	r = _drive(m, [{"type": "start", "mode": "film"}, _tick(12, 0), {"type": "ask", "now": 100}])
	_ok(r["state"]["phase"] == "asking" and r["commands"][-1] == [{"type": "pause"}], "pedir la pregunta: pausa")
	_ok(_drive(m, [{"type": "reveal", "time": 12.1}], r["state"])["commands"] == [[{"type": "seek", "at": 20.0}, {"type": "play"}]], "al revelar salta a la marca")
	_ok(_drive(m, [{"type": "finish"}], r["state"])["state"]["phase"] == "ended", "terminar")

	# Vídeo sin marcas, entero.
	r = _drive(no_marks, [{"type": "start", "mode": "free"}, _tick(30, 0), _tick(90, 5000)])
	_ok(r["commands"] == [[{"type": "cue", "at": 0.0}], [], []] and r["state"]["phase"] == "reveal" and r["state"]["mode"] == "free" and r["state"]["missed"] == "skipped", "libre: vídeo entero")
	back = _drive(no_marks, [{"type": "back", "now": 6000}], r["state"])
	_ok(back["state"]["phase"] == "asking" and back["commands"] == [[{"type": "pause"}]], "libre: la pregunta a un toque")
	_ok(_drive(m, [{"type": "start", "mode": "free"}])["state"]["phase"] == "watching", "con marcas, «ver el vídeo» es el modo película")

	# Si el vídeo falla, la pregunta sigue.
	var watching: Dictionary = _drive(m, [{"type": "start", "mode": "film"}])["state"]
	var err := _drive(m, [{"type": "error", "code": 150}], watching)
	_ok(err["state"]["phase"] == "asking" and not bool(err["state"]["video_on"]) and int(err["state"]["error"]) == 150, "error: sigue la pregunta")
	var asking2: Dictionary = _drive(m, [{"type": "start", "mode": "direct"}, {"type": "reveal", "time": null}])["state"]
	_ok(_drive(m, [{"type": "error", "code": 153}], asking2)["state"]["phase"] == "ended", "error al revelar: fin")

	# «Ir a la pregunta» hacia la siguiente pausa, y «siguiente pregunta» desde una pregunta.
	var st := CineFilm.initial()
	st.merge({"phase": "reveal", "stop": 0, "video_on": true}, true)
	var ra := CineFilm.direct(m, st, {"type": "ask", "now": 1000})
	_ok(ra["state"]["phase"] == "asking" and int(ra["state"]["stop"]) == 1 and ra["commands"] == [{"type": "seek", "at": 40.0}, {"type": "pause"}], "ir a la siguiente pausa")
	st["stop"] = 1
	_ok(CineFilm.direct(m, st, {"type": "ask", "now": 1000})["state"]["phase"] == "reveal", "en la última pausa no hace nada")
	var sj := CineFilm.initial()
	sj.merge({"phase": "asking", "stop": 0, "video_on": true}, true)
	var rj := CineFilm.direct(m, sj, {"type": "jump", "now": 5})
	_ok(rj["state"]["phase"] == "asking" and int(rj["state"]["stop"]) == 1 and rj["commands"] == [{"type": "seek", "at": 40.0}, {"type": "pause"}], "siguiente pregunta: salta parado")

	# Ya respondida, ▶ en el reproductor: sigue viendo con normalidad y para en la siguiente pausa.
	var ans := _drive(m, [{"type": "start", "mode": "film"}, _tick(19.95, 0), _tick(19.97, 300, false), _tick(20.5, 9000)])
	_ok(ans["state"]["missed"] == "resumed", "▶ tras la pausa: «resumed»")
	var ans2 := _drive(m, [{"type": "answered"}, {"type": "ask", "now": 9100}], ans["state"])
	_ok(ans2["state"]["phase"] == "asking" and int(ans2["state"]["stop"]) == 1 and ans2["commands"][1] == [{"type": "seek", "at": 40.0}, {"type": "pause"}], "respondida: «Ir a la pregunta» lleva a la siguiente")
	_ok(_drive(m, [{"type": "answered"}], ask_st)["state"] == ask_st, "«answered» fuera de su caso no cambia nada")

	# Simulación: lecturas cada 100 ms; la pausa cae entre 0,12 s antes y 0,1 s después de la marca, una sola vez.
	for at: float in [3.07, 12.34, 20.0, 41.99]:
		var film := _mini({"start": 0.0, "end": null, "stops": [{"at": at, "resume": null}]})
		var time := 0.0
		var playing := false
		var pauses := 0
		var state := CineFilm.initial()
		var paused_at := -1.0
		var rr := CineFilm.direct(film, state, {"type": "start", "mode": "film"})
		state = rr["state"]
		playing = true # el jugador pulsa ▶
		var now := 0
		while now < 60000 and paused_at < 0.0:
			if playing:
				time += 0.1
			rr = CineFilm.direct(film, state, {"type": "tick", "time": time, "duration": 100.0, "playing": playing, "now": float(now)})
			state = rr["state"]
			for c: Dictionary in rr["commands"]:
				if c["type"] == "pause":
					playing = false
					pauses += 1
			if state["phase"] == "asking":
				paused_at = time
			now += 100
		_ok(paused_at >= at - EPS - 1e-6 and paused_at <= at + 0.1 + 1e-6 and pauses == 1, "simulación: pausa en %.2f para la marca %.2f" % [paused_at, at])


func _sincronia() -> void:
	var film := {"sync": {"startPly": 109, "marks": [{"ply": 110, "at": 216.0}, {"ply": 111, "at": 218.5}]}}
	_ok(CineFilm.ply_at(film, 200) == 109 and CineFilm.ply_at(film, 215.99) == 109, "antes de su segundo, la posición de partida")
	_ok(CineFilm.ply_at(film, 216) == 110 and CineFilm.ply_at(film, 230) == 111 and CineFilm.ply_at(film, INF) == 111, "cada jugada en su segundo")
	var plies := [110, 112, 116]
	_ok(CineFilm.sync_cap(plies, {"phase": "watching", "stop": 0, "mode": "film"}) == 109, "viendo: tope en la primera pregunta")
	_ok(CineFilm.sync_cap(plies, {"phase": "reveal", "stop": 0, "mode": "film"}) == 111, "tras la primera pausa: tope en la segunda")
	_ok(CineFilm.sync_cap(plies, {"phase": "reveal", "stop": 2, "mode": "film"}) == -1, "tras la última: sin tope")
	_ok(CineFilm.sync_cap(plies, {"phase": "watching", "stop": 0, "mode": "free"}) == -1, "libre: sin tope")
	_ok(CineFilm.sync_cap([20, 40], {"phase": "ended", "stop": 1, "mode": "film"}) == -1, "al acabar: sin tope")


## Los seis clips de data/cine.json: se pueden parar solos, las pausas van en orden y el tablero nunca enseña la jugada
## de una pregunta antes de su pausa, ni con el vídeo corriendo.
func _datos() -> void:
	var clips := Cine.clips()
	_ok(clips.size() == 6, "seis clips")
	for c: Dictionary in clips:
		var f: Variant = c.get("film")
		var id := str(c["id"])
		_ok(CineFilm.can_auto_pause(f), id + ": se para solo")
		if not CineFilm.can_auto_pause(f):
			continue
		var film: Dictionary = f
		var qs: Array = []
		for e: Dictionary in (c["lesson"] as Dictionary)["exercises"]:
			if str(e["kind"]) == "move":
				qs.append(int(e["ply"]))
		var stops: Array = film["stops"]
		_ok(qs.size() == stops.size(), id + ": una pregunta por pausa")
		var prev := float(film["start"])
		var in_order := true
		for s: Dictionary in stops:
			in_order = in_order and float(s["at"]) > prev
			prev = float(s["at"])
		in_order = in_order and (film["end"] == null or float(film["end"]) > prev)
		_ok(in_order, id + ": inicio, pausas y fin en orden")
		# Recorre el vídeo segundo a segundo como lo haría el tablero, con el tope de cada momento.
		var spoil := false
		var missing := false
		var t := float(film["start"])
		var end_t := float(film["end"]) if film["end"] != null else t + 600.0
		while t <= end_t:
			var stop_i := 0
			while stop_i < stops.size() and float(stops[stop_i]["at"]) <= t:
				stop_i += 1
			var st := {"phase": "watching" if stop_i == 0 else "reveal", "stop": maxi(stop_i - 1, 0) if stop_i > 0 else 0, "mode": "film"}
			var cap := CineFilm.sync_cap(qs, st)
			var fr := CineFilm.frame_at(film, t, cap)
			if str(fr["fen"]) == "":
				missing = true
			if stop_i < qs.size() and int(fr["ply"]) >= int(qs[stop_i]):
				spoil = true
			if stop_i < qs.size() and CineFilm.ply_at(film, t) >= int(qs[stop_i]):
				spoil = true # ni siquiera sin tope
			t += 0.25
		_ok(not missing, id + ": hay posición en cada segundo")
		_ok(not spoil, id + ": ninguna pregunta se destripa en el tablero")
		# En cada pausa, la posición del tablero es la de la pregunta.
		var same := true
		for i in qs.size():
			var fen_q := ""
			for e: Dictionary in (c["lesson"] as Dictionary)["exercises"]:
				if str(e["kind"]) == "move" and int(e["ply"]) == int(qs[i]):
					fen_q = str(e["fen"])
			var at_pause := CineFilm.frame_at(film, float(stops[i]["at"]), int(qs[i]) - 1)
			same = same and _board(str(at_pause["fen"])) == _board(fen_q)
		_ok(same, id + ": en cada pausa el tablero ya está en la posición de la pregunta")
	var ding := Cine.clip_of("cine-ding-gukesh-2024-g14")
	_ok(not ding.is_empty() and is_equal_approx(float(ding["film"]["end"]), 219.0), "Ding: el clip acaba a los 219 s (2,5 s tras 58…Re5)")


func _board(fen: String) -> String:
	return fen.split(" ")[0] + " " + (fen.split(" ")[1] if fen.split(" ").size() > 1 else "")


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
