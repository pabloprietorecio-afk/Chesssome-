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
	var th := Campeonato.start({"torneos": {}, "titulos": {}}, "hotel", 2300.0, rng)
	_ok(Campeonato.needs_premium(th, false, "hotel") and not Campeonato.needs_premium(th, true, "hotel"), "en el hotel (Stockfish, «Experto») es Premium desde los cuartos")
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
	_formatos(rng)
	_end()


## Los cinco formatos y el ritmo elegido.
func _formatos(rng: RandomNumberGenerator) -> void:
	_ok(Campeonato.FORMATS.size() == 5, "cinco formatos")
	# Ritmo elegido: manda sobre el de la sala; sin elegir, el de la sala.
	var st := {"torneos": {}, "titulos": {}}
	var c := Campeonato.start(st, "escuela", 300.0, rng, "copa", [3, 2])
	_ok((Campeonato.current_match(c, "escuela")["clock"] as Array) == [3, 2], "el ritmo elegido (3+2) es el de la partida")
	Campeonato.record(st, "escuela", 0.5, rng)
	_ok((Campeonato.current_match(c, "escuela")["clock"] as Array) == [3, 2], "con un ritmo rápido, el desempate no es más lento")
	var c0 := Campeonato.start(st, "escuela", 300.0, rng)
	_ok((Campeonato.current_match(c0, "escuela")["clock"] as Array) == [10, 5] and Campeonato.format_of(c0) == "copa", "sin elegir: copa y reloj de la sala")
	var old := {"cuadro": c0["cuadro"], "ronda": 0, "ganadores": [[], [], []], "estado": "en_curso", "desempate": 0, "color": 0, "partidas": []}
	_ok(Campeonato.format_of(old) == "copa" and (Campeonato.current_match(old, "escuela")["clock"] as Array) == [10, 5], "un torneo guardado antes de los formatos sigue siendo una copa")
	var c90 := Campeonato.start(st, "club", 1200.0, rng, "copa", [90, 30])
	Campeonato.record(st, "club", 0.5, rng)
	_ok((Campeonato.current_match(c90, "club")["clock"] as Array) == Campeonato.TIEBREAK_CLOCK, "con 90+30, el desempate es 5+3")

	# Copa con mini-match: dos partidas por cruce, una con cada color.
	var sm := {"torneos": {}, "titulos": {}}
	var m := Campeonato.start(sm, "escuela", 300.0, rng, "copa_match")
	var m0 := Campeonato.current_match(m, "escuela")
	_ok(int(m0["juegos"]) == 2 and int(m0["juego"]) == 0 and str(m0["titulo"]).ends_with("1/2"), "mini-match: primera de dos partidas")
	var r1 := Campeonato.record(sm, "escuela", 1.0, rng)
	var m1 := Campeonato.current_match(m, "escuela")
	_ok(not bool(r1["decided"]) and int(r1["mini"]) == 1 and int(m1["juego"]) == 1 and int(m1["color"]) == 1 - int(m0["color"]) and int(m1["ronda"]) == 0, "tras la primera, la segunda con los colores cambiados y el mismo rival")
	_ok(str(m1["rival"]) == str(m0["rival"]) and str(m1["titulo"]).ends_with("2/2"), "contra el mismo rival (2/2)")
	var r2 := Campeonato.record(sm, "escuela", 0.5, rng)
	_ok(bool(r2["decided"]) and bool(r2["won"]) and int(m["ronda"]) == 1 and int(Campeonato.current_match(m, "escuela")["juego"]) == 0, "1,5 a 0,5: pasas y la siguiente ronda empieza de nuevo")
	# 1-1: desempate y armagedón.
	var s2 := {"torneos": {}, "titulos": {}}
	var m2 := Campeonato.start(s2, "escuela", 300.0, rng, "copa_match", [5, 0])
	Campeonato.record(s2, "escuela", 1.0, rng)
	var rt := Campeonato.record(s2, "escuela", 0.0, rng)
	var mt := Campeonato.current_match(m2, "escuela")
	_ok(not bool(rt["decided"]) and int(rt["tiebreak"]) == 1 and int(mt["desempate"]) == 1 and int(mt["juegos"]) == 1, "1-1: desempate de una partida")
	Campeonato.record(s2, "escuela", 0.5, rng)
	_ok(int(Campeonato.current_match(m2, "escuela")["desempate"]) == 2, "tablas en el desempate: armagedón")
	Campeonato.record(s2, "escuela", 1.0, rng)
	_ok(int(m2["ronda"]) == 1 and int(m2["desempate"]) == 0, "y ganas el cruce")
	# Perder 0-2: eliminado, y el cuadro se acaba.
	var s3 := {"torneos": {}, "titulos": {}}
	var m3 := Campeonato.start(s3, "escuela", 300.0, rng, "copa_match")
	Campeonato.record(s3, "escuela", 0.0, rng)
	var rl := Campeonato.record(s3, "escuela", 0.5, rng)
	_ok(bool(rl["decided"]) and str(rl["estado"]) == "eliminado" and Campeonato.champion(m3) != "", "0,5 a 1,5: eliminado")

	# Cuadrangular: tú y tres rivales, tres rondas, todos contra todos.
	var sq := {"torneos": {}, "titulos": {}}
	var q := Campeonato.start(sq, "club", 1400.0, rng, "cuadrangular")
	_ok((q["cuadro"] as Array).size() == 4 and (q["cuadro"] as Array).has(Campeonato.YOU) and Campeonato.round_count(q) == 3, "cuadrangular: cuatro jugadores y tres rondas")
	var opp := {}
	for i in 3:
		var mm := Campeonato.current_match(q, "club")
		opp[str(mm["rival"])] = true
		_ok(Campeonato.pairs(q, i).size() == 2 and str(mm["titulo"]) == Loc.f("Ronda %d", i + 1), "ronda %d: dos cruces" % (i + 1))
		var rr := Campeonato.record(sq, "club", 1.0, rng)
		_ok(bool(rr["decided"]), "la partida de la ronda %d queda decidida (sin desempate)" % (i + 1))
	_ok(opp.size() == 3, "juegas contra los tres rivales, una vez cada uno")
	_ok((q["res"] as Array).size() == 6, "seis partidas en total (tú y las simuladas)")
	_ok(str(q["estado"]) == "campeon" and Campeonato.champion(q) == Campeonato.YOU and int(sq["titulos"]["club"]) == 1 and int(q["puesto"]) == 1, "con tres victorias eres campeón")
	var sq2 := {"torneos": {}, "titulos": {}}
	var q2 := Campeonato.start(sq2, "club", 1400.0, rng, "cuadrangular")
	for i in 3:
		Campeonato.record(sq2, "club", 0.0, rng)
	_ok(str(q2["estado"]) == "terminado" and int(q2["puesto"]) == 4 and Campeonato.champion(q2) != Campeonato.YOU and not sq2["titulos"].has("club"), "con tres derrotas acabas cuarto, sin título")
	_ok(Campeonato.current_match(q2, "club").is_empty(), "y no hay más partidas")
	var sq3 := {"torneos": {}, "titulos": {}}
	var q3 := Campeonato.start(sq3, "club", 1400.0, rng, "cuadrangular")
	Campeonato.record(sq3, "club", 0.5, rng)
	_ok(int(q3["ronda"]) == 1 and int(q3["desempate"]) == 0, "tablas en un torneo con tabla: son tablas, sin desempate")

	# Liga: siete rondas, un rival distinto en cada una.
	var sl := {"torneos": {}, "titulos": {}}
	var l := Campeonato.start(sl, "casino", 1700.0, rng, "liga", [15, 10])
	_ok(Campeonato.round_count(l) == 7 and (l["rondas"] as Array).size() == 7 and (l["cuadro"] as Array).size() == 8, "liga: ocho jugadores y siete rondas")
	var seen := {}
	var pairing := {}
	for i in 7:
		for pr: Array in Campeonato.pairs(l, i):
			_ok(not pairing.has(Campeonato._pair_key(str(pr[0]), str(pr[1]))), "nadie se repite")
			pairing[Campeonato._pair_key(str(pr[0]), str(pr[1]))] = true
		_ok(Campeonato.pairs(l, i).size() == 4, "cuatro cruces por ronda")
		seen[str(Campeonato.current_match(l, "casino")["rival"])] = true
		Campeonato.record(sl, "casino", 0.5, rng)
	_ok(seen.size() == 7 and pairing.size() == 28, "juegas con los siete y se juegan las 28 partidas")
	_ok(str(l["estado"]) in ["campeon", "terminado"] and (l["clasificacion"] as Array).size() == 8 and (l["res"] as Array).size() == 28, "liga acabada con clasificación de ocho")
	var tab := Campeonato.standings(l, "casino")
	var total := 0.0
	for row: Dictionary in tab:
		total += float(row["pts"])
	_ok(is_equal_approx(total, 28.0), "reparto de 28 puntos entre los ocho")

	# Suizo: cinco rondas sin repetir rival.
	var ss := {"torneos": {}, "titulos": {}}
	var w := Campeonato.start(ss, "escuela", 300.0, rng, "suizo", [10, 0])
	var met := {}
	var ok_pairs := true
	for i in 5:
		var prs := Campeonato.pairs(w, i)
		ok_pairs = ok_pairs and prs.size() == 4
		var flat := {}
		for pr: Array in prs:
			flat[str(pr[0])] = true
			flat[str(pr[1])] = true
			var k := Campeonato._pair_key(str(pr[0]), str(pr[1]))
			if met.has(k):
				ok_pairs = false
			met[k] = true
		ok_pairs = ok_pairs and flat.size() == 8
		Campeonato.record(ss, "escuela", [1.0, 0.5, 0.0, 1.0, 0.5][i], rng)
	_ok(ok_pairs, "suizo: cuatro cruces por ronda, todos juegan y nadie repite rival")
	_ok(met.size() == 20 and str(w["estado"]) in ["campeon", "terminado"] and (w["rondas"] as Array).size() == 5, "cinco rondas, veinte partidas")
	# El suizo empareja por puntos: tras ganar la primera, no te toca el último de la tabla.
	var s4 := {"torneos": {}, "titulos": {}}
	var w4 := Campeonato.start(s4, "escuela", 300.0, rng, "suizo")
	Campeonato.record(s4, "escuela", 1.0, rng)
	var scs := Campeonato.scores(w4)
	var mine_rival := str(Campeonato.current_match(w4, "escuela")["rival"])
	_ok(float(scs[mine_rival]) >= 0.5 or float(scs[Campeonato.YOU]) == 1.0, "suizo: tras ganar, juegas contra alguien de arriba")
	# Premium: desde la tercera ronda.
	_ok(not Campeonato.needs_premium(w4, false, "escuela"), "las dos primeras rondas son gratis")
	w4["ronda"] = 2
	_ok(Campeonato.needs_premium(w4, false, "escuela") and not Campeonato.needs_premium(w4, true, "escuela"), "y la tercera, Premium")
	# Guardar y leer un torneo con tabla.
	var path2 := "user://campeonato_prueba2.json"
	Campeonato.save_state(ss, path2)
	var back2 := Campeonato.load_state(path2)
	_ok(Campeonato.is_table(back2["torneos"]["escuela"]) and (back2["torneos"]["escuela"]["clasificacion"] as Array).size() == 8, "se guarda y se lee un suizo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path2))


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
