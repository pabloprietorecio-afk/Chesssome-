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
		return [Loc.t("Un rato de ajedrez"), Loc.t("Un problema de 2 minutos para volver cuando quieras.")]
	var c := Progress.counts(state, d)
	var played_today := int(c["p"]) + int(c["l"]) + int(c["g"]) > 0
	# La racha que se conserva si juega hoy.
	var streak := Progress.streak_now(state, d)
	if streak >= 2 and not played_today:
		return [Loc.f("¡Tu racha de %d días!", streak), Loc.t("Un problema o una partida y la mantienes.")]
	# Lo que le falta del reto de hoy.
	if d == today:
		for g: Dictionary in Progress.goals(state, d):
			if not bool(g["hecho"]):
				return [Loc.t("Tu reto de hoy"), _remaining(g)]
	# El reto de la semana.
	var w: Dictionary = state["semana"]
	if str(w["familia"]) != "" and int(w["idx"]) == Progress.week_index(d) and not bool(w["completo"]):
		var fam := str(Assessment.FAMILY_NAME.get(str(w["familia"]), str(w["familia"])))
		# En español va en minúscula («Reto de la semana: mates»); en otros idiomas, como se traduce.
		var fam_text := fam.to_lower() if Loc.language == "es" else Loc.t(fam)
		return [Loc.f("Reto de la semana: %s", fam_text), Loc.f("Llevas %d de %d problemas.", [mini(int(w["hecho"]), int(w["meta"])), int(w["meta"])])]
	var fallbacks: Array = [
		[Loc.t("Un problema al día"), Loc.t("Dos minutos bastan para entrenar.")],
		[Loc.t("Hoy toca ajedrez"), Loc.t("Resuelve un problema o juega una partida.")],
		[Loc.t("Tu reto del día te espera"), Loc.f("%d problemas y listo.", ProgressConfig.DAILY_PROBLEMS)],
	]
	return fallbacks[d % fallbacks.size()]


## Lo que falta del objetivo `g`, como frase entera («Te falta resolver 2 problemas más.»), para poder traducirla.
static func _remaining(g: Dictionary) -> String:
	var left := int(g["meta"]) - int(g["actual"])
	match str(g["tipo"]):
		"problemas":
			if int(g["actual"]) == 0:
				return Loc.f("Te falta resolver %d problemas.", left)
			return Loc.t("Te falta resolver 1 problema más.") if left == 1 else Loc.f("Te falta resolver %d problemas más.", left)
		"repaso":
			return Loc.t("Te falta repasar un fallo.")
		"leccion":
			return Loc.t("Te falta hacer una lección.")
		"partida":
			return Loc.t("Te falta jugar una partida.")
	return ""
