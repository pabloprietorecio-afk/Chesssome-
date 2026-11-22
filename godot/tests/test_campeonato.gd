extends SceneTree
## Modo Campeonato (core/campeonato.gd): cuadro de 8, rondas, desempate, final Premium y salas que se abren.
## Uso: godot --headless --path godot -s tests/test_campeonato.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	# Datos: seis salas, siete rivales adultos por sala, cada uno con un nivel de su grupo.
	_ok(Campeonato.TOURNAMENTS.size() == 6 and str(Campeonato.TOURNAMENTS[0]["key"]) == "escuela" and str(Campeonato.TOURNAMENTS[5]["key"]) == "hotel", "seis salas, de la escuela al hotel")
	var ids := {}
	for t: Dictionary in Campeonato.TOURNAMENTS:
		var key := str(t["key"])
		var rs: Array = Campeonato.RIVALS[key]
		_ok(rs.size() == 7, "%s: siete rivales" % key)
		for r: Dictionary in rs:
			_ok(int(r["age"]) >= 18, "%s es adulto" % r["name"])
			_ok(not ids.has(str(r["id"])), "id único: %s" % r["id"])
			ids[str(r["id"])] = true
			var lv := Campeonato.level_for(key, str(r["id"]))
			_ok(Bot.group_of(lv) == int(t["group"]), "%s juega con un nivel de su grupo (%s)" % [r["name"], Bot.level_name(lv)])
	_ok(Bot.LEVELS[Campeonato.level_for("escuela", "lucia")]["sub"] == 3 and Bot.LEVELS[Campeonato.level_for("escuela", "priya")]["sub"] == 1, "el más fuerte de la escuela juega con Muy fácil 3; el más flojo, con Muy fácil 1")
	_ok(Bot.sf_elo(Campeonato.level_for("hotel", "viktor")) == 2700 and Bot.sf_elo(Campeonato.level_for("hotel", "lin")) == 2100, "en el hotel juega Stockfish con su Elo")

	# Cuadro.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := {"torneos": {}, "titulos": {}}
	var t := Campeonato.start(st, "escuela", 300.0, rng)
	var cuadro: Array = t["cuadro"]
	_ok(cuadro.size() == 8 and cuadro.has(Campeonato.YOU), "cuadro de 8 contigo dentro")
	_ok(Campeonato.pairs(t, 0).size() == 4, "cuatro cuartos de final")
	# El 1 y el 2 de la clasificación por Elo, en mitades distintas.
	var top := "lucia"
	var second := "tomas"
	_ok(cuadro.find(top) < 4 and cuadro.find(second) >= 4, "las dos primeras cabezas de serie, en mitades distintas")
	var m := Campeonato.current_match(t, "escuela")
	_ok(not m.is_empty() and int(m["ronda"]) == 0 and (m["clock"] as Array) == [10, 5], "tu partida de cuartos, con el reloj de la escuela")

	# Tablas: desempate con los colores cambiados; otra vez tablas: armagedón (las negras pasan con tablas).
	var c0 := int(m["color"])
	var r1 := Campeonato.record(st, "escuela", 0.5, rng)
	_ok(not bool(r1["decided"]) and int(r1["tiebreak"]) == 1, "tablas: desempate")
	var m1 := Campeonato.current_match(t, "escuela")
	_ok(int(m1["color"]) == 1 - c0 and (m1["clock"] as Array) == Campeonato.TIEBREAK_CLOCK, "desempate más rápido y con los colores cambiados")
	Campeonato.record(st, "escuela", 0.5, rng)
	var m2 := Campeonato.current_match(t, "escuela")
	_ok(int(m2["desempate"]) == 2 and (m2["clock"] as Array) == Campeonato.ARMAGEDDON_CLOCK, "armagedón")
	var r3 := Campeonato.record(st, "escuela", 0.5, rng)
	_ok(bool(r3["decided"]) and bool(r3["won"]) == (int(m2["color"]) == 1), "en el armagedón, las tablas valen para las negras")

	# Ganar los cuartos y la semifinal; la final pide Premium.
	var st2 := {"torneos": {}, "titulos": {}}
	var t2 := Campeonato.start(st2, "escuela", 300.0, rng)
	var w1 := Campeonato.record(st2, "escuela", 1.0, rng)
	_ok(bool(w1["decided"]) and bool(w1["won"]) and int(t2["ronda"]) == 1 and (t2["ganadores"][0] as Array).size() == 4, "ganas los cuartos: semifinal, con los otros tres cuartos jugados")
	_ok((t2["ganadores"][0] as Array).has(Campeonato.YOU), "y tú entre los cuatro")
	var color_sf := int(Campeonato.current_match(t2, "escuela")["color"])
	_ok(color_sf == 1 - int((t2["partidas"] as Array)[-1]["color"]), "en la ronda siguiente, el otro color")
	_ok(not Campeonato.needs_premium(t2, false), "la semifinal es gratis")
	Campeonato.record(st2, "escuela", 1.0, rng)
	_ok(int(t2["ronda"]) == 2 and Campeonato.needs_premium(t2, false) and not Campeonato.needs_premium(t2, true), "la final es Premium")
	var wf := Campeonato.record(st2, "escuela", 1.0, rng)
	_ok(str(wf["estado"]) == "campeon" and Campeonato.champion(t2) == Campeonato.YOU and int(st2["titulos"]["escuela"]) == 1, "campeón: se apunta el título")
	_ok(Campeonato.current_match(t2, "escuela").is_empty(), "y ya no hay partida")

	# Perder: eliminado, y el resto del cuadro se juega hasta el final.
	var st3 := {"torneos": {}, "titulos": {}}
	var t3 := Campeonato.start(st3, "escuela", 300.0, rng)
	var lost := Campeonato.record(st3, "escuela", 0.0, rng)
	_ok(str(lost["estado"]) == "eliminado" and not (t3["ganadores"][0] as Array).has(Campeonato.YOU), "pierdes: eliminado")
	_ok(Campeonato.champion(t3) != "" and Campeonato.champion(t3) != Campeonato.YOU, "el torneo sigue y alguien lo gana")

	# Simulación entre bots: el más fuerte gana casi siempre con 400 de diferencia.
	var wins := 0
	for i in 400:
		if Campeonato.simulate(1800.0, 1400.0, rng) == 0:
			wins += 1
	_ok(wins > 330 and wins < 390, "con 400 de diferencia gana el favorito unas 9 de cada 10 (%d de 400)" % wins)

	# Salas que se abren.
	var st4 := {"torneos": {}, "titulos": {}}
	_ok(Campeonato.unlocked(st4, "escuela", 0.0) and not Campeonato.unlocked(st4, "centro_civico", 300.0), "la escuela, abierta; el barrio, no")
	_ok(Campeonato.unlocked(st4, "centro_civico", 700.0), "el barrio se abre con nivel de juego suficiente")
	st4["titulos"]["escuela"] = 1
	_ok(Campeonato.unlocked(st4, "centro_civico", 100.0), "o ganando la escuela")
	_ok(not Campeonato.unlocked(st4, "club", 100.0), "pero no se salta salas")

	# Guardar y leer.
	var path := "user://campeonato_prueba.json"
	Campeonato.save_state(st2, path)
	var back := Campeonato.load_state(path)
	_ok(int(back["titulos"]["escuela"]) == 1 and str(back["torneos"]["escuela"]["estado"]) == "campeon", "se guarda y se lee")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_end()


func _ok(cond: bool, msg: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: ", msg)


func _end() -> void:
	if fallos == 0:
		print("TODO OK (%d comprobaciones)" % hechos)
	else:
		print("FALLOS: %d de %d" % [fallos, hechos])
	quit(1 if fallos > 0 else 0)
