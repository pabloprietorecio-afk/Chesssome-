class_name Progress
extends RefCounted
## Reto del día, racha, reto semanal e insignias. Lógica pura (sin interfaz ni reloj propio): el juego avisa de lo
## que ocurre (un problema, una lección, una partida) y esta clase actualiza el estado y devuelve los avisos que
## la interfaz puede enseñar. Los valores de equilibrio están en core/progress_config.gd.
##
## Estado (se guarda en PATH, como JSON):
##   dias     {«nº de día»: {p intentos, a resueltos, r repasos, l lecciones, g partidas, v ganadas}}
##   racha    {actual, mejor, ultimo (nº de día), gracia (semana en que se usó el día de gracia)}
##   reto     {dia, metas: [{tipo, meta, hecho}], completo}
##   semana   {idx, familia, meta, hecho, completo}
##   retos_dia, retos_semana: cuántos se han completado
##   insignias: [ids]
##   aviso    {activo, hora, min}: el aviso diario (core/reminder.gd), apagado hasta que el jugador lo activa
## «Nº de día»: días desde el 1-1-1970 en la hora local, para que el día cambie a medianoche del jugador.
##
## Qué se avisa (cada aviso es un Diccionario con «tipo»):
##   objetivo {meta: tipo de objetivo}, reto_dia {}, reto_semana {familia}, racha {dias}, insignia {id}.

const PATH := "user://chessome_progreso.json"
const VERSION := 1
## Cada tipo de objetivo diario y el contador del día en el que se cuenta.
const GOAL_KEY := {"problemas": "a", "repaso": "r", "partida": "g", "leccion": "l"}


# ---------------------------------------------------------------- tiempo

## Nº de día local: `bias_min` son los minutos de diferencia con UTC (Time.get_time_zone_from_system().bias).
static func day_number(unix: int, bias_min: int) -> int:
	return floori(float(unix + bias_min * 60) / 86400.0)


## Semana (de lunes a domingo) a la que pertenece un día. El 1-1-1970 fue jueves.
static func week_index(day: int) -> int:
	return floori(float(day + 3) / 7.0)


# ---------------------------------------------------------------- estado

static func new_state() -> Dictionary:
	return {
		"version": VERSION,
		"dias": {},
		"racha": {"actual": 0, "mejor": 0, "ultimo": -1, "gracia": -1},
		"reto": {"dia": -1, "metas": [], "completo": false},
		"semana": {"idx": -1, "familia": "", "meta": ProgressConfig.WEEKLY_PROBLEMS, "hecho": 0, "completo": false},
		"retos_dia": 0,
		"retos_semana": 0,
		"insignias": [],
		"aviso": {"activo": false, "hora": ReminderConfig.HOUR, "min": 0},
	}


## Lee el estado guardado. Si no existe o está roto, devuelve uno nuevo (nunca falla). Los números de un JSON
## llegan como decimales, así que se normalizan a enteros.
static func load_state(path: String = PATH) -> Dictionary:
	var state := new_state()
	if not FileAccess.file_exists(path):
		return state
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not (parser.data is Dictionary):
		return state
	var d: Dictionary = parser.data
	if d.get("dias") is Dictionary:
		for k: Variant in (d["dias"] as Dictionary):
			var counts: Variant = (d["dias"] as Dictionary)[k]
			if counts is Dictionary:
				var clean := {}
				for key: String in ["p", "a", "r", "l", "g", "v"]:
					clean[key] = int((counts as Dictionary).get(key, 0))
				(state["dias"] as Dictionary)[str(k)] = clean
	if d.get("racha") is Dictionary:
		var r: Dictionary = d["racha"]
		for key: String in ["actual", "mejor", "ultimo", "gracia"]:
			(state["racha"] as Dictionary)[key] = int(r.get(key, (state["racha"] as Dictionary)[key]))
	if d.get("reto") is Dictionary and (d["reto"] as Dictionary).get("metas") is Array:
		var goals: Array = []
		for m: Variant in (d["reto"] as Dictionary)["metas"]:
			if m is Dictionary and GOAL_KEY.has(str((m as Dictionary).get("tipo", ""))):
				goals.append({"tipo": str(m["tipo"]), "meta": maxi(1, int((m as Dictionary).get("meta", 1))), "hecho": bool((m as Dictionary).get("hecho", false))})
		state["reto"] = {"dia": int((d["reto"] as Dictionary).get("dia", -1)), "metas": goals, "completo": bool((d["reto"] as Dictionary).get("completo", false))}
	if d.get("semana") is Dictionary:
		var w: Dictionary = d["semana"]
		state["semana"] = {"idx": int(w.get("idx", -1)), "familia": str(w.get("familia", "")), "meta": maxi(1, int(w.get("meta", ProgressConfig.WEEKLY_PROBLEMS))), "hecho": int(w.get("hecho", 0)), "completo": bool(w.get("completo", false))}
	state["retos_dia"] = int(d.get("retos_dia", 0))
	state["retos_semana"] = int(d.get("retos_semana", 0))
	if d.get("aviso") is Dictionary:
		var a: Dictionary = d["aviso"]
		state["aviso"] = {"activo": bool(a.get("activo", false)), "hora": clampi(int(a.get("hora", ReminderConfig.HOUR)), 0, 23), "min": clampi(int(a.get("min", 0)), 0, 59)}
	if d.get("insignias") is Array:
		var ids: Array = []
		for id: Variant in (d["insignias"] as Array):
			if not ids.has(str(id)):
				ids.append(str(id))
		state["insignias"] = ids
	return state


## Guarda el estado: primero en un archivo temporal y luego se renombra, para que un corte a medias no deje el
## progreso roto. Devuelve si se pudo guardar.
static func save_state(state: Dictionary, path: String = PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK:
		return true
	# Si no se pudo renombrar, se escribe directamente.
	var direct := FileAccess.open(path, FileAccess.WRITE)
	if direct == null:
		return false
	direct.store_string(JSON.stringify(state))
	direct.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	return true


# ---------------------------------------------------------------- el día y la semana

## Contadores de un día (todo a cero si no se jugó).
static func counts(state: Dictionary, day: int) -> Dictionary:
	var c: Variant = (state["dias"] as Dictionary).get(str(day))
	if c is Dictionary:
		return c
	return {"p": 0, "a": 0, "r": 0, "l": 0, "g": 0, "v": 0}


## Prepara el reto del día y el de la semana si todavía no son los de hoy. `ctx`:
##   can_review    bool: hay fallos antiguos que repasar
##   lessons_left  bool: quedan lecciones del curso por hacer
##   focus         Array de familias flojas del jugador (de más a menos), para elegir la de la semana
##   families      Dictionary familia → problemas disponibles
static func ensure_today(state: Dictionary, day: int, ctx: Dictionary) -> void:
	var reto: Dictionary = state["reto"]
	if int(reto["dia"]) != day:
		var metas: Array = [{"tipo": "problemas", "meta": ProgressConfig.DAILY_PROBLEMS, "hecho": false}]
		if bool(ctx.get("can_review", false)):
			metas.append({"tipo": "repaso", "meta": ProgressConfig.DAILY_REVIEWS, "hecho": false})
		elif bool(ctx.get("lessons_left", false)):
			metas.append({"tipo": "leccion", "meta": ProgressConfig.DAILY_LESSONS, "hecho": false})
		if not bool(ctx.get("kids", false)):
			metas.append({"tipo": "partida", "meta": ProgressConfig.DAILY_GAMES, "hecho": false})
		state["reto"] = {"dia": day, "metas": metas, "completo": false}
	var week := week_index(day)
	var w: Dictionary = state["semana"]
	if int(w["idx"]) != week:
		state["semana"] = {"idx": week, "familia": _pick_family(week, str(w["familia"]), ctx), "meta": ProgressConfig.WEEKLY_PROBLEMS, "hecho": 0, "completo": false}


## Categoría de la semana: la más floja del jugador que tenga problemas de sobra; si no hay datos, se van
## turnando. No se repite la de la semana anterior si hay otra.
static func _pick_family(week: int, previous: String, ctx: Dictionary) -> String:
	var families: Dictionary = ctx.get("families", {})
	var options: Array = []
	for f: String in Assessment.FAMILIES:
		if f != "otros" and int(families.get(f, 0)) >= ProgressConfig.WEEKLY_MIN_POOL:
			options.append(f)
	if options.is_empty():
		return ""
	for f: Variant in ctx.get("focus", []):
		if options.has(str(f)) and (str(f) != previous or options.size() == 1):
			return str(f)
	var pick := str(options[week % options.size()])
	if pick == previous and options.size() > 1:
		pick = str(options[(week + 1) % options.size()])
	return pick


# ---------------------------------------------------------------- eventos

## Un problema terminado. `ev`: {correct, review (era un repaso), family}. Devuelve los avisos.
static func record_problem(state: Dictionary, ev: Dictionary, now: int, bias_min: int, ctx: Dictionary) -> Array:
	var day := day_number(now, bias_min)
	ensure_today(state, day, ctx)
	var avisos: Array = []
	_touch(state, day, avisos)
	var c := _today(state, day)
	c["p"] = int(c["p"]) + 1
	if bool(ev.get("correct", false)):
		c["a"] = int(c["a"]) + 1
		var w: Dictionary = state["semana"]
		if str(w["familia"]) != "" and str(ev.get("family", "")) == str(w["familia"]):
			w["hecho"] = int(w["hecho"]) + 1
	if bool(ev.get("review", false)):
		c["r"] = int(c["r"]) + 1
	_check(state, day, avisos)
	return avisos


## Una lección del curso terminada.
static func record_lesson(state: Dictionary, now: int, bias_min: int, ctx: Dictionary) -> Array:
	var day := day_number(now, bias_min)
	ensure_today(state, day, ctx)
	var avisos: Array = []
	_touch(state, day, avisos)
	var c := _today(state, day)
	c["l"] = int(c["l"]) + 1
	_check(state, day, avisos)
	return avisos


## Una partida terminada. `ev`: {own_moves (jugadas del jugador), result (1 gana, 0 tablas, −1 pierde)}. Las
## partidas con muy pocas jugadas no cuentan.
static func record_game(state: Dictionary, ev: Dictionary, now: int, bias_min: int, ctx: Dictionary) -> Array:
	if int(ev.get("own_moves", 0)) < ProgressConfig.MIN_OWN_MOVES_FOR_GAME:
		return []
	var day := day_number(now, bias_min)
	ensure_today(state, day, ctx)
	var avisos: Array = []
	_touch(state, day, avisos)
	var c := _today(state, day)
	c["g"] = int(c["g"]) + 1
	if int(ev.get("result", 0)) > 0:
		c["v"] = int(c["v"]) + 1
	_check(state, day, avisos)
	return avisos


static func _today(state: Dictionary, day: int) -> Dictionary:
	var days: Dictionary = state["dias"]
	if not days.has(str(day)):
		days[str(day)] = {"p": 0, "a": 0, "r": 0, "l": 0, "g": 0, "v": 0}
	return days[str(day)]


## Anota el día como jugado: actualiza la racha (con el día de gracia) y recorta el historial antiguo.
static func _touch(state: Dictionary, day: int, avisos: Array) -> void:
	var r: Dictionary = state["racha"]
	var last := int(r["ultimo"])
	var gap := day - last
	var grew := false
	if last < 0 or gap > 2 or gap < 0:
		r["actual"] = 1
		grew = true
	elif gap == 1:
		r["actual"] = int(r["actual"]) + 1
		grew = true
	elif gap == 2 and ProgressConfig.GRACE_PER_WEEK > 0 and int(r["gracia"]) != week_index(day):
		r["actual"] = int(r["actual"]) + 1
		r["gracia"] = week_index(day)
		grew = true
	elif gap == 2:
		r["actual"] = 1
		grew = true
	r["ultimo"] = day
	r["mejor"] = maxi(int(r["mejor"]), int(r["actual"]))
	if grew and gap != 0:
		avisos.append({"tipo": "racha", "dias": int(r["actual"])})
		if ProgressConfig.STREAK_BADGES.has(int(r["actual"])):
			_badge(state, "racha%d" % int(r["actual"]), avisos)
	var days: Dictionary = state["dias"]
	for k: String in days.keys():
		if int(k) < day - ProgressConfig.KEEP_DAYS:
			days.erase(k)


static func _badge(state: Dictionary, id: String, avisos: Array) -> void:
	var ids: Array = state["insignias"]
	if not ids.has(id):
		ids.append(id)
		avisos.append({"tipo": "insignia", "id": id})


## Comprueba los objetivos del día y el reto de la semana tras un evento.
static func _check(state: Dictionary, day: int, avisos: Array) -> void:
	var reto: Dictionary = state["reto"]
	var c := counts(state, day)
	var all := true
	for m: Dictionary in reto["metas"]:
		if not bool(m["hecho"]) and int(c[GOAL_KEY[str(m["tipo"])]]) >= int(m["meta"]):
			m["hecho"] = true
			avisos.append({"tipo": "objetivo", "meta": str(m["tipo"])})
		all = all and bool(m["hecho"])
	if all and not (reto["metas"] as Array).is_empty() and not bool(reto["completo"]):
		reto["completo"] = true
		state["retos_dia"] = int(state["retos_dia"]) + 1
		avisos.append({"tipo": "reto_dia"})
		if ProgressConfig.DAILY_CHALLENGE_BADGES.has(int(state["retos_dia"])):
			_badge(state, "dia%d" % int(state["retos_dia"]), avisos)
	var w: Dictionary = state["semana"]
	if str(w["familia"]) != "" and not bool(w["completo"]) and int(w["hecho"]) >= int(w["meta"]):
		w["completo"] = true
		state["retos_semana"] = int(state["retos_semana"]) + 1
		avisos.append({"tipo": "reto_semana", "familia": str(w["familia"])})
		if ProgressConfig.WEEKLY_CHALLENGE_BADGES.has(int(state["retos_semana"])):
			_badge(state, "semana%d" % int(state["retos_semana"]), avisos)


# ---------------------------------------------------------------- lo que se enseña

## Días de racha que se enseñan hoy: la racha sigue viva si se jugó ayer, y también si se jugó anteayer y queda
## el día de gracia de esta semana; si no, 0 (aunque «mejor» se conserva).
static func streak_now(state: Dictionary, day: int) -> int:
	var r: Dictionary = state["racha"]
	var gap := day - int(r["ultimo"])
	if int(r["ultimo"]) < 0 or gap < 0 or gap > 2:
		return 0
	if gap == 2 and (ProgressConfig.GRACE_PER_WEEK <= 0 or int(r["gracia"]) == week_index(day)):
		return 0
	return int(r["actual"])


## Los objetivos de hoy con su avance: [{tipo, meta, actual (tope: la meta), hecho}]. Vacío si todavía no se
## preparó el reto de hoy.
static func goals(state: Dictionary, day: int) -> Array:
	var out: Array = []
	var reto: Dictionary = state["reto"]
	if int(reto["dia"]) != day:
		return out
	var c := counts(state, day)
	for m: Dictionary in reto["metas"]:
		var now := mini(int(c[GOAL_KEY[str(m["tipo"])]]), int(m["meta"]))
		out.append({"tipo": str(m["tipo"]), "meta": int(m["meta"]), "actual": now, "hecho": bool(m["hecho"])})
	return out


## Lo que se ha hecho hoy, en frases cortas, para el resumen («3 problemas resueltos», «1 partida ganada»…).
static func summary_lines(state: Dictionary, day: int) -> Array:
	var c := counts(state, day)
	var out: Array = []
	var solved := int(c["a"])
	var tried := int(c["p"])
	if tried > 0:
		out.append(Loc.f("%d de %d problemas resueltos", [solved, tried]) if tried != 1 else Loc.t("1 problema resuelto" if solved == 1 else "1 problema intentado"))
	var lessons := int(c["l"])
	if lessons > 0:
		out.append(Loc.t("1 lección") if lessons == 1 else Loc.f("%d lecciones", lessons))
	var games := int(c["g"])
	if games > 0:
		var won := int(c["v"])
		var line := Loc.t("1 partida") if games == 1 else Loc.f("%d partidas", games)
		if won > 0:
			line += Loc.t(" (1 ganada)") if won == 1 else Loc.f(" (%d ganadas)", won)
		out.append(line)
	return out


## Nombre y descripción de una insignia, para la interfaz.
static func badge_info(id: String) -> Dictionary:
	# Textos en el idioma de la app (Loc), con el singular y el plural por separado para poder traducirlos.
	if id.begins_with("racha"):
		var days := id.substr(5).to_int()
		return {"nombre": Loc.f("%d días seguidos", days), "texto": Loc.f("Has jugado %d días seguidos.", days)}
	if id.begins_with("dia"):
		var done := id.substr(3).to_int()
		return {"nombre": Loc.f("%d retos del día", done), "texto": Loc.f("Has completado %d retos del día.", done)}
	if id.begins_with("semana"):
		var n := id.substr(6).to_int()
		if n == 1:
			return {"nombre": Loc.t("1 reto semanal"), "texto": Loc.t("Has completado 1 reto de la semana.")}
		return {"nombre": Loc.f("%d retos semanales", n), "texto": Loc.f("Has completado %d retos de la semana.", n)}
	return {"nombre": id, "texto": ""}
