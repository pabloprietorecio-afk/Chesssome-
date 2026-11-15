extends SceneTree
## Aviso diario: cuándo y qué dice (core/reminder.gd).
## Uso: godot --headless --path godot -s tests/test_reminder.gd

var fallos := 0
var hechos := 0

const CTX := {"can_review": false, "lessons_left": false, "kids": false, "focus": ["doble"], "families": {"doble": 48, "mate": 90, "linea": 22, "defensor": 30, "peon": 14, "caza": 15}}
const ON := {"enabled": true, "hour": 19, "minute": 0}


func _init() -> void:
	_apagado()
	_hora()
	_reto_cumplido()
	_textos()
	_ritmo()
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Segundo Unix del día `d` a la hora `h` (hora local con bias 0).
func _at(d: int, h: int, m: int = 0) -> int:
	return d * 86400 + h * 3600 + m * 60


func _problem(s: Dictionary, d: int, correct: bool = true, family: String = "mate") -> void:
	Progress.record_problem(s, {"correct": correct, "family": family}, _at(d, 12), 0, CTX)


func _apagado() -> void:
	var s := Progress.new_state()
	_problem(s, 100)
	_ok(Reminder.plan(s, {"enabled": false}, _at(100, 9), 0).is_empty(), "apagado: ningún aviso")
	_ok(Reminder.plan(s, {}, _at(100, 9), 0).is_empty(), "sin ajustes: ningún aviso")


func _hora() -> void:
	var s := Progress.new_state()
	_problem(s, 100)
	var p := Reminder.plan(s, ON, _at(100, 9), 0)
	_ok(int(p["at"]) == _at(100, 19), "antes de la hora, hoy a su hora")
	var q := Reminder.plan(s, ON, _at(100, 20), 0)
	_ok(int(q["at"]) == _at(101, 19), "pasada la hora, mañana")
	var r := Reminder.plan(s, {"enabled": true, "hour": 8, "minute": 30}, _at(100, 7), 0)
	_ok(int(r["at"]) == _at(100, 8, 30), "hora y minuto elegidos")
	# Con hora local distinta de UTC (+60 min): las 19:00 locales son las 18:00 UTC.
	var local := Reminder.plan(s, ON, _at(100, 9), 60)
	_ok(int(local["at"]) == _at(100, 18), "respeta la zona horaria")
	var near := Reminder.plan(s, ON, _at(100, 19) - 30, 0)
	_ok(int(near["at"]) == _at(101, 19), "un aviso a punto de sonar ya no se programa")


func _reto_cumplido() -> void:
	var s := Progress.new_state()
	for i in 3:
		_problem(s, 100)
	Progress.record_game(s, {"own_moves": 12, "result": 1}, _at(100, 12), 0, CTX)
	_ok(bool(s["reto"]["completo"]), "(el reto de hoy está cumplido)")
	var p := Reminder.plan(s, ON, _at(100, 15), 0)
	_ok(int(p["at"]) == _at(101, 19), "con el reto cumplido, nada hoy: el siguiente es mañana")


func _textos() -> void:
	# Jugó ayer y hoy aún no: la racha manda.
	var s := Progress.new_state()
	_problem(s, 98)
	_problem(s, 99)
	var p := Reminder.plan(s, ON, _at(100, 9), 0)
	_ok(str(p["title"]) == "¡Tu racha de 2 días!", "racha viva: título con los días: %s" % str(p["title"]))
	# Una racha de un día no se enseña como racha.
	var one := Progress.new_state()
	_problem(one, 99)
	var o := Reminder.plan(one, ON, _at(100, 9), 0)
	_ok(not str(o["title"]).begins_with("¡Tu racha"), "con un solo día no se habla de racha")
	# Ya jugó algo hoy: dice lo que falta.
	var t := Progress.new_state()
	_problem(t, 99)
	_problem(t, 100)
	var q := Reminder.plan(t, ON, _at(100, 15), 0)
	_ok(str(q["title"]) == "Tu reto de hoy" and str(q["body"]) == "Te falta resolver 2 problemas más.", "falta del reto: %s" % str(q["body"]))
	# Reto de la semana (hoy no hay reto pendiente porque es otro día sin empezar y sin racha).
	var w := Progress.new_state()
	for i in 2:
		_problem(w, 100, true, "doble")
	var weekly := Reminder.plan(w, ON, _at(101, 9), 0)
	_ok(str(weekly["title"]).begins_with("Reto de la semana") or str(weekly["title"]).begins_with("¡Tu racha"), "mañana: semana o racha")
	var only_week := Progress.new_state()
	Progress.ensure_today(only_week, 105, CTX)
	only_week["semana"]["hecho"] = 3
	only_week["racha"]["ultimo"] = 104
	only_week["racha"]["actual"] = 1
	var wk := Reminder.plan(only_week, ON, _at(105, 20), 0)
	_ok(str(wk["title"]).begins_with("Reto de la semana") and str(wk["body"]) == "Llevas 3 de 5 problemas.", "reto de la semana: %s / %s" % [str(wk["title"]), str(wk["body"])])
	# Semana ya cumplida y sin nada pendiente: una frase general.
	var done_week := Progress.new_state()
	Progress.ensure_today(done_week, 105, CTX)
	done_week["semana"]["completo"] = true
	done_week["racha"]["ultimo"] = 104
	done_week["racha"]["actual"] = 1
	var g := Reminder.plan(done_week, ON, _at(105, 20), 0)
	_ok(str(g["title"]) != "" and str(g["body"]) != "", "frase general cuando no hay nada concreto")


func _ritmo() -> void:
	var s := Progress.new_state()
	_problem(s, 100)
	# Entra cada día: aviso diario.
	_ok(int(Reminder.plan(s, ON, _at(101, 20), 0)["at"]) == _at(102, 19), "al día siguiente, aviso")
	# Ha pasado 3 días: todavía diario; 4 días: pasa a semanal.
	_ok(int(Reminder.plan(s, ON, _at(102, 20), 0)["at"]) == _at(103, 19), "a los 3 días sin entrar, aviso (diario)")
	var p4 := Reminder.plan(s, ON, _at(103, 20), 0)
	_ok(int(p4["at"]) == _at(107, 19), "pasados 3 días, el siguiente es a la semana: %d" % (int(p4["at"]) / 86400 - 100))
	_ok(str(p4["title"]) == "Un rato de ajedrez", "y es un aviso de vuelta, sin reproches")
	var p7 := Reminder.plan(s, ON, _at(107, 20), 0)
	_ok(int(p7["at"]) == _at(114, 19), "luego, a las dos semanas")
	_ok(Reminder.plan(s, ON, _at(114, 20), 0).is_empty(), "pasadas dos semanas, se calla")
	# Si vuelve, se retoma el aviso diario.
	_problem(s, 120)
	_ok(not Reminder.plan(s, ON, _at(120, 13), 0).is_empty(), "al volver a jugar, vuelve el aviso")
	# Sin historial no falla.
	_ok(not Reminder.plan(Progress.new_state(), ON, _at(100, 9), 0).is_empty(), "sin historial: aviso normal")


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
