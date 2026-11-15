class_name Reminder
extends RefCounted
## Decide cuál es el próximo aviso al jugador y qué dice, a partir de su racha, su reto del día y su reto semanal
## (core/progress.gd). Lógica pura: quien lo envíe al sistema (un plugin de notificaciones locales) solo recibe
## «a esta hora, este título y este texto». Valores en core/reminder_config.gd.
##
## Reglas:
##  - Un aviso como máximo, el siguiente; se vuelve a calcular tras cada cosa que haga el jugador.
##  - Si hoy ya cumplió el reto, no hay aviso hoy.
##  - Tono sin culpa: nada de reproches. Si no entra en varios días, avisa cada vez menos y acaba callándose.
##  - Dice lo que de verdad le queda (la racha que se conserva, lo que falta del reto, la semana), no frases vacías.

## `settings`: {enabled: bool, hour: int, minute: int}. `now`: segundos Unix; `bias_min`: minutos de diferencia
## con UTC. Devuelve {at (segundos Unix), title, body} o un Diccionario vacío si no toca avisar.
static func plan(state: Dictionary, settings: Dictionary, now: int, bias_min: int) -> Dictionary:
	if not bool(settings.get("enabled", false)):
		return {}
	var today := Progress.day_number(now, bias_min)
	var minute_of_day := int(settings.get("hour", ReminderConfig.DEFAULT_HOUR)) * 60 + int(settings.get("minute", 0))
	var last := int((state["racha"] as Dictionary)["ultimo"])
	for d in range(today, today + ReminderConfig.LOOKAHEAD_DAYS):
		var at := d * 86400 + minute_of_day * 60 - bias_min * 60
		if at <= now + ReminderConfig.MIN_LEAD_SECONDS:
			continue
		if d == today and _done_today(state, today):
			continue
		if not _allowed(d, last):
			continue
		var text := _text(state, d, today, last)
		return {"at": at, "title": text[0], "body": text[1]}
	return {}


static func _done_today(state: Dictionary, today: int) -> bool:
	var reto: Dictionary = state["reto"]
	return int(reto["dia"]) == today and bool(reto["completo"])


## ¿Toca avisar el día `d`? Diario mientras entre a menudo; luego semanal; luego nada.
static func _allowed(d: int, last: int) -> bool:
	if last < 0:
		return true
	var gap := d - last
	if gap <= ReminderConfig.IGNORED_DAYS_LIMIT:
		return true
	if gap > ReminderConfig.STOP_AFTER_DAYS:
		return false
	return gap % 7 == 0


## [título, texto] del aviso del día `d`.
static func _text(state: Dictionary, d: int, today: int, last: int) -> Array:
	var gap := d - last if last >= 0 else 0
	if last >= 0 and gap >= 7:
		return ["Un rato de ajedrez", "Un problema de 2 minutos para volver cuando quieras."]
	var c := Progress.counts(state, d)
	var played_today := int(c["p"]) + int(c["l"]) + int(c["g"]) > 0
	# La racha que se conserva si juega hoy.
	var streak := Progress.streak_now(state, d)
	if streak >= 2 and not played_today:
		return ["¡Tu racha de %d días!" % streak, "Un problema o una partida y la mantienes."]
	# Lo que le falta del reto de hoy.
	if d == today:
		for g: Dictionary in Progress.goals(state, d):
			if not bool(g["hecho"]):
				return ["Tu reto de hoy", "Te falta %s." % _remaining(g)]
	# El reto de la semana.
	var w: Dictionary = state["semana"]
	if str(w["familia"]) != "" and int(w["idx"]) == Progress.week_index(d) and not bool(w["completo"]):
		var fam := str(Assessment.FAMILY_NAME.get(str(w["familia"]), str(w["familia"])))
		return ["Reto de la semana: %s" % fam.to_lower(), "Llevas %d de %d problemas." % [mini(int(w["hecho"]), int(w["meta"])), int(w["meta"])]]
	var fallbacks: Array = [
		["Un problema al día", "Dos minutos bastan para entrenar."],
		["Hoy toca ajedrez", "Resuelve un problema o juega una partida."],
		["Tu reto del día te espera", "%d problemas y listo." % ProgressConfig.DAILY_PROBLEMS],
	]
	return fallbacks[d % fallbacks.size()]


static func _remaining(g: Dictionary) -> String:
	var left := int(g["meta"]) - int(g["actual"])
	match str(g["tipo"]):
		"problemas":
			return "resolver %d problema%s más" % [left, "" if left == 1 else "s"] if int(g["actual"]) > 0 else "resolver %d problemas" % left
		"repaso":
			return "repasar un fallo"
		"leccion":
			return "hacer una lección"
		"partida":
			return "jugar una partida"
	return ""
