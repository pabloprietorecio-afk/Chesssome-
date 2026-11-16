extends SceneTree
## Reto del día, racha, reto semanal, insignias y guardado (core/progress.gd).
## Uso: godot --headless --path godot -s tests/test_progress.gd

var fallos := 0
var hechos := 0

const CTX := {"can_review": false, "lessons_left": false, "kids": false, "focus": [], "families": {"doble": 48, "linea": 22, "defensor": 30, "mate": 90, "peon": 14, "caza": 15, "otros": 80}}


func _init() -> void:
	_tiempo()
	_reto_del_dia()
	_partidas_cortas()
	_racha()
	_insignias_de_racha()
	_reto_semanal()
	_guardado()
	_resumen()
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _at(day: int) -> int:
	return day * 86400 + 12 * 3600


var _ids := 0


## Como en la app: un problema nuevo anota su primer intento (record_problem) y, al terminar, el final
## (record_finish); un repaso es un problema ya intentado, así que solo anota el final.
func _problem(s: Dictionary, day: int, correct: bool = true, family: String = "mate", review: bool = false, ctx: Dictionary = CTX) -> Array:
	_ids += 1
	var avisos: Array = []
	if not review:
		avisos.append_array(Progress.record_problem(s, {"correct": correct}, _at(day), 0, ctx))
	avisos.append_array(_finish(s, day, "p%d" % _ids, family, correct, review, ctx))
	return avisos


func _finish(s: Dictionary, day: int, id: String, family: String, solved: bool, review: bool = false, ctx: Dictionary = CTX) -> Array:
	return Progress.record_finish(s, {"id": id, "family": family, "solved": solved, "review": review}, _at(day), 0, ctx)


func _kinds(avisos: Array) -> Array:
	var out: Array = []
	for a: Dictionary in avisos:
		out.append(str(a["tipo"]))
	return out


func _tiempo() -> void:
	_ok(Progress.day_number(0, 0) == 0, "el 1-1-1970 es el día 0")
	_ok(Progress.day_number(23 * 3600 + 1800, 0) == 0 and Progress.day_number(23 * 3600 + 1800, 60) == 1, "la hora local cambia el día")
	_ok(Progress.week_index(3) == 0 and Progress.week_index(4) == 1 and Progress.week_index(10) == 1 and Progress.week_index(11) == 2, "las semanas van de lunes a domingo")


func _reto_del_dia() -> void:
	var s := Progress.new_state()
	Progress.ensure_today(s, 100, CTX)
	var g := Progress.goals(s, 100)
	_ok(g.size() == 2 and g[0]["tipo"] == "problemas" and g[1]["tipo"] == "partida", "sin repaso ni lecciones: problemas y partida")
	var s2 := Progress.new_state()
	Progress.ensure_today(s2, 100, {"can_review": true, "lessons_left": true, "kids": false, "families": {}})
	var t: Array = []
	for x: Dictionary in Progress.goals(s2, 100):
		t.append(x["tipo"])
	_ok(t == ["problemas", "repaso", "partida"], "con fallos por repasar se pide el repaso (y no la lección)")
	var s3 := Progress.new_state()
	Progress.ensure_today(s3, 100, {"can_review": false, "lessons_left": true, "kids": false, "families": {}})
	_ok(Progress.goals(s3, 100).size() == 3 and Progress.goals(s3, 100)[1]["tipo"] == "leccion", "sin fallos, una lección")
	var s4 := Progress.new_state()
	Progress.ensure_today(s4, 100, {"kids": true, "families": {}})
	_ok(Progress.goals(s4, 100).size() == 1, "en Kids no se pide partida")
	_ok(Progress.goals(s, 101).is_empty(), "los objetivos de ayer no valen hoy")
	# Se completa.
	var all: Array = []
	for i in 3:
		all.append_array(_problem(s, 100))
	_ok(_kinds(all).count("objetivo") == 1 and not _kinds(all).has("reto_dia"), "tres problemas cumplen un objetivo, no el reto")
	var fin := Progress.record_game(s, {"own_moves": 20, "result": 1}, _at(100), 0, CTX)
	_ok(_kinds(fin).has("reto_dia") and int(s["retos_dia"]) == 1, "con la partida se completa el reto del día")
	var again := _problem(s, 100)
	_ok(not _kinds(again).has("reto_dia") and int(s["retos_dia"]) == 1, "no se premia dos veces el mismo día")
	var g2 := Progress.goals(s, 100)
	_ok(g2[0]["actual"] == 3 and g2[0]["hecho"] and g2[1]["hecho"], "el avance se enseña con tope en la meta")
	# Un problema fallado no cuenta como resuelto.
	var s5 := Progress.new_state()
	for i in 5:
		_problem(s5, 100, false)
	_ok(int(Progress.goals(s5, 100)[0]["actual"]) == 0, "fallar no avanza el objetivo")
	# El repaso cuenta aunque se falle.
	var s6 := Progress.new_state()
	Progress.ensure_today(s6, 100, {"can_review": true, "families": {}})
	_problem(s6, 100, false, "mate", true, {"can_review": true, "families": {}})
	_ok(Progress.goals(s6, 100)[1]["hecho"], "intentar un repaso cumple el objetivo")
	# El repaso es un problema ya intentado: no pasa por el primer intento, solo por el final (antes no contaba).
	var s7 := Progress.new_state()
	var rctx := {"can_review": true, "families": {}}
	Progress.ensure_today(s7, 100, rctx)
	var got := _finish(s7, 100, "viejo", "mate", true, true, rctx)
	_ok(Progress.goals(s7, 100)[1]["hecho"] and _kinds(got).has("objetivo"), "resolver un repaso (solo el final) cumple el objetivo y avisa")
	_ok(int(Progress.counts(s7, 100)["p"]) == 0 and int(Progress.counts(s7, 100)["a"]) == 0, "el repaso no cuenta como problema nuevo")
	_ok(int(s7["racha"]["actual"]) == 1, "repasar también cuenta como día jugado")
	var s8 := Progress.new_state()
	Progress.ensure_today(s8, 100, rctx)
	_ok(_finish(s8, 100, "x", "mate", true, false, rctx).is_empty() and int(s8["racha"]["actual"]) == 0, "terminar un problema repetido fuera del reto no cambia nada")


func _partidas_cortas() -> void:
	var s := Progress.new_state()
	var a := Progress.record_game(s, {"own_moves": 3, "result": 1}, _at(50), 0, CTX)
	_ok(a.is_empty() and Progress.counts(s, 50)["g"] == 0 and int(s["racha"]["actual"]) == 0, "una partida de pocas jugadas no cuenta ni da racha")
	Progress.record_game(s, {"own_moves": 8, "result": 0}, _at(50), 0, CTX)
	_ok(Progress.counts(s, 50)["g"] == 1 and Progress.counts(s, 50)["v"] == 0, "con 8 jugadas sí; unas tablas no son victoria")


func _racha() -> void:
	# Día 4 = lunes, 6 = miércoles, 8 = viernes de la misma semana.
	var s := Progress.new_state()
	_problem(s, 4)
	_ok(int(s["racha"]["actual"]) == 1, "primer día: racha 1")
	_problem(s, 4)
	_ok(int(s["racha"]["actual"]) == 1, "el mismo día no suma")
	_problem(s, 6)
	_ok(int(s["racha"]["actual"]) == 2 and int(s["racha"]["gracia"]) == Progress.week_index(6), "un día sin jugar se perdona con el día de gracia")
	_problem(s, 8)
	_ok(int(s["racha"]["actual"]) == 1, "pero solo uno por semana")
	_ok(int(s["racha"]["mejor"]) == 2, "la mejor racha se conserva")
	# Lo que se enseña.
	var t := Progress.new_state()
	_problem(t, 4)
	_ok(Progress.streak_now(t, 4) == 1 and Progress.streak_now(t, 5) == 1, "viva el mismo día y al siguiente")
	_ok(Progress.streak_now(t, 6) == 1, "viva con el día de gracia disponible")
	_ok(Progress.streak_now(t, 7) == 0, "a los tres días, cortada")
	var u := Progress.new_state()
	_problem(u, 4)
	_problem(u, 6)
	_ok(Progress.streak_now(u, 8) == 0, "con la gracia ya gastada esta semana, a los dos días se corta")
	var v := Progress.new_state()
	_problem(v, 20)
	_problem(v, 30)
	_ok(int(v["racha"]["actual"]) == 1, "tras una pausa larga se empieza de nuevo")
	# Sin gracia configurada no habría perdón: se comprueba con la constante.
	_ok(ProgressConfig.GRACE_PER_WEEK >= 0, "la gracia es un número")


func _insignias_de_racha() -> void:
	var s := Progress.new_state()
	var got: Array = []
	for d in [10, 11, 12]:
		for a: Dictionary in _problem(s, d):
			if a["tipo"] == "insignia":
				got.append(a["id"])
	_ok(got == ["racha3"] and (s["insignias"] as Array).has("racha3"), "tres días seguidos dan la insignia")
	var more := _problem(s, 13)
	_ok(not _kinds(more).has("insignia"), "la insignia se da una sola vez")
	var info := Progress.badge_info("racha7")
	_ok(str(info["nombre"]) == "7 días seguidos", "nombre de insignia")


func _reto_semanal() -> void:
	var s := Progress.new_state()
	var ctx := CTX.duplicate()
	ctx["focus"] = ["peon", "doble"]
	Progress.ensure_today(s, 100, ctx)
	_ok(str(s["semana"]["familia"]) == "peon", "la semana toma la categoría más floja")
	var ctx2 := CTX.duplicate()
	ctx2["focus"] = ["otros", "peon"]
	var s2 := Progress.new_state()
	Progress.ensure_today(s2, 100, ctx2)
	_ok(str(s2["semana"]["familia"]) == "peon", "«otros» no se elige")
	var ctx3 := CTX.duplicate()
	ctx3["families"] = {"peon": 3, "mate": 90}
	ctx3["focus"] = ["peon"]
	var s3 := Progress.new_state()
	Progress.ensure_today(s3, 100, ctx3)
	_ok(str(s3["semana"]["familia"]) == "mate", "una categoría con pocos problemas no se elige")
	# Contar.
	var got: Array = []
	for i in 4:
		got.append_array(_problem(s, 100, true, "peon", false, ctx))
	_problem(s, 100, true, "mate", false, ctx)
	_problem(s, 100, false, "peon", false, ctx)
	_ok(int(s["semana"]["hecho"]) == 4 and not bool(s["semana"]["completo"]), "solo cuentan los aciertos de la categoría")
	var fin := _problem(s, 101, true, "peon", false, ctx)
	_ok(_kinds(fin).has("reto_semana") and _kinds(fin).has("insignia") and (s["insignias"] as Array).has("semana1"), "el quinto acierto completa la semana y da insignia")
	_ok(not _kinds(_problem(s, 102, true, "peon", false, ctx)).has("reto_semana"), "no se repite")
	# Lo que pasaba en el móvil: problemas resueltos tras un fallo, o ya vistos antes, no contaban.
	var w := Progress.new_state()
	Progress.ensure_today(w, 100, ctx)
	Progress.record_problem(w, {"correct": false}, _at(100), 0, ctx)
	_finish(w, 100, "a", "peon", true, false, ctx)
	_ok(int(w["semana"]["hecho"]) == 1, "resolverlo después de fallar cuenta para la semana")
	_finish(w, 100, "b", "peon", true, false, ctx)
	_ok(int(w["semana"]["hecho"]) == 2, "un problema ya visto (solo el final) cuenta para la semana")
	_finish(w, 101, "b", "peon", true, false, ctx)
	_ok(int(w["semana"]["hecho"]) == 2, "el mismo problema solo cuenta una vez por semana")
	_finish(w, 101, "c", "peon", false, false, ctx)
	_ok(int(w["semana"]["hecho"]) == 2, "con la solución a la vista no cuenta")
	_finish(w, 101, "d", "mate", true, false, ctx)
	_ok(int(w["semana"]["hecho"]) == 2, "otra categoría no cuenta")
	Progress.save_state(w, "user://test_progreso_semana.json")
	var back := Progress.load_state("user://test_progreso_semana.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_progreso_semana.json"))
	_ok((back["semana"]["ids"] as Array) == ["a", "b"], "los problemas contados se guardan")
	_finish(back, 101, "a", "peon", true, false, ctx)
	_ok(int(back["semana"]["hecho"]) == 2, "y al volver a abrir la app no se cuentan otra vez")
	_finish(back, 107, "a", "peon", true, false, ctx)
	_ok(int(back["semana"]["idx"]) == Progress.week_index(107) and (back["semana"]["ids"] as Array).size() <= 1, "la semana siguiente empieza de cero")
	# Otra semana: nueva categoría, que no repite la anterior.
	var next := Progress.new_state()
	next["semana"]["idx"] = Progress.week_index(100) - 1
	next["semana"]["familia"] = "mate"
	Progress.ensure_today(next, 100, CTX)
	_ok(str(next["semana"]["familia"]) != "" and str(next["semana"]["familia"]) != "mate", "no repite la categoría de la semana anterior")
	# Sin datos de la muestra no hay reto semanal, pero nada falla.
	var empty := Progress.new_state()
	Progress.ensure_today(empty, 100, {"families": {}})
	var a := Progress.record_problem(empty, {"correct": true, "family": "mate"}, _at(100), 0, {"families": {}})
	_ok(str(empty["semana"]["familia"]) == "" and not _kinds(a).has("reto_semana"), "sin categoría disponible no hay reto semanal")


func _guardado() -> void:
	var s := Progress.new_state()
	for i in 3:
		_problem(s, 100)
	Progress.record_game(s, {"own_moves": 12, "result": 1}, _at(100), 0, CTX)
	var path := "user://_test_progreso.json"
	_ok(Progress.save_state(s, path), "se guarda")
	_ok(not FileAccess.file_exists(path + ".tmp"), "no queda el archivo temporal")
	var back := Progress.load_state(path)
	_ok(back["dias"]["100"]["a"] == 3 and typeof(back["dias"]["100"]["a"]) == TYPE_INT, "se lee con enteros")
	_ok(int(back["racha"]["actual"]) == 1 and int(back["retos_dia"]) == 1 and (back["reto"]["metas"] as Array).size() == 2, "se conserva todo")
	_ok(typeof(back["racha"]["ultimo"]) == TYPE_INT and int(back["racha"]["ultimo"]) == 100, "la racha vuelve como entero")
	# Seguir donde se dejó.
	var more := Progress.record_problem(back, {"correct": true, "family": "mate"}, _at(101), 0, CTX)
	_ok(int(back["racha"]["actual"]) == 2 and _kinds(more).has("racha"), "la racha continúa tras recargar")
	# El aviso diario se conserva y se normaliza.
	back["aviso"] = {"activo": true, "hora": 8, "min": 30}
	Progress.save_state(back, path)
	var again := Progress.load_state(path)
	_ok(bool(again["aviso"]["activo"]) and again["aviso"]["hora"] == 8 and typeof(again["aviso"]["hora"]) == TYPE_INT and again["aviso"]["min"] == 30, "el aviso diario se guarda y se lee")
	_ok(not bool(Progress.new_state()["aviso"]["activo"]), "el aviso empieza apagado")
	var g2 := FileAccess.open(path, FileAccess.WRITE)
	g2.store_string(JSON.stringify({"aviso": {"activo": true, "hora": 99, "min": -5}}))
	g2.close()
	var odd2 := Progress.load_state(path)
	_ok(odd2["aviso"]["hora"] == 23 and odd2["aviso"]["min"] == 0, "la hora del aviso se limita a valores posibles")
	# Un archivo estropeado no rompe nada.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{esto no es json")
	f.close()
	var bad := Progress.load_state(path)
	_ok(int(bad["racha"]["actual"]) == 0 and (bad["dias"] as Dictionary).is_empty(), "archivo roto: estado nuevo")
	var g := FileAccess.open(path, FileAccess.WRITE)
	g.store_string(JSON.stringify({"dias": 5, "racha": "x", "reto": {"metas": [{"tipo": "raro"}]}, "insignias": 3}))
	g.close()
	var odd := Progress.load_state(path)
	_ok((odd["reto"]["metas"] as Array).is_empty() and (odd["insignias"] as Array).is_empty(), "datos con forma rara: se ignoran")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_ok(Progress.load_state("user://_no_existe.json")["version"] == Progress.VERSION, "sin archivo: estado nuevo")
	# Se recorta el historial antiguo.
	var old := Progress.new_state()
	_problem(old, 10)
	_problem(old, 10 + ProgressConfig.KEEP_DAYS + 5)
	_ok(not (old["dias"] as Dictionary).has("10"), "se olvidan los días muy antiguos")


func _resumen() -> void:
	var s := Progress.new_state()
	_ok(Progress.summary_lines(s, 100).is_empty(), "sin actividad no hay resumen")
	_problem(s, 100)
	_problem(s, 100, false)
	_problem(s, 100)
	Progress.record_game(s, {"own_moves": 10, "result": 1}, _at(100), 0, CTX)
	Progress.record_lesson(s, _at(100), 0, CTX)
	var lines := Progress.summary_lines(s, 100)
	_ok(lines == ["2 de 3 problemas resueltos", "1 lección", "1 partida (1 ganada)"], "frases del resumen: %s" % str(lines))


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
