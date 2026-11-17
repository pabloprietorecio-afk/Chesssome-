extends SceneTree
## Hora del aviso diario con el reloj de WakeAgenda (ui/clock_picker.gd): su geometría (las mismas pruebas que
## ClockMathTest.kt de WakeAgenda) y elegir la hora en «Tu día».
## Uso: godot --headless --path godot -s tests/test_reloj.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	# --- Geometría (ClockMathTest.kt) ---
	_ok(ClockPicker.hour_at(0.0, 0.8) == 12 and ClockPicker.hour_at(90.0, 0.8) == 3 and ClockPicker.hour_at(180.0, 0.8) == 6 and ClockPicker.hour_at(330.0, 0.8) == 11, "anillo exterior: 12 y 1…11")
	_ok(ClockPicker.hour_at(0.0, 0.5) == 0 and ClockPicker.hour_at(90.0, 0.5) == 15 and ClockPicker.hour_at(180.0, 0.5) == 18 and ClockPicker.hour_at(330.0, 0.5) == 23, "anillo interior: 00 y 13…23")
	_ok(ClockPicker.hour_at(359.0, 0.8) == 12 and ClockPicker.hour_at(352.0, 0.5) == 0 and ClockPicker.minute_at(359.0) == 0, "justo antes de las 12 cuenta como arriba")
	_ok(ClockPicker.hour_at(44.0, 0.8) == 1 and ClockPicker.hour_at(46.0, 0.8) == 2, "la hora más cercana")
	_ok(ClockPicker.minute_at(90.0) == 15 and ClockPicker.minute_at(180.0) == 30 and ClockPicker.minute_at(270.0) == 45 and ClockPicker.minute_at(222.5) == 37, "minutos de 6 en 6 grados")
	_ok(ClockPicker.angle_of_hour(0) == 0.0 and ClockPicker.angle_of_hour(12) == 0.0 and ClockPicker.angle_of_hour(13) == 30.0 and ClockPicker.angle_of_hour(23) == 330.0, "ángulo de cada hora")
	var round_trip := true
	for h in 24:
		round_trip = round_trip and ClockPicker.hour_at(ClockPicker.angle_of_hour(h), 0.5 if ClockPicker.is_inner_ring(h) else 0.8) == h
	for m in 60:
		round_trip = round_trip and ClockPicker.minute_at(ClockPicker.angle_of_minute(m)) == m
	_ok(round_trip, "todas las horas y minutos vuelven a sí mismos")
	_ok(is_equal_approx(ClockPicker.angle_of(1.0, 0.0), 90.0) and is_equal_approx(ClockPicker.angle_of(0.0, -1.0), 0.0) and is_equal_approx(ClockPicker.angle_of(0.0, 1.0), 180.0), "ángulo de un toque (la y crece hacia abajo)")

	# --- En la app ---
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	var a: Dictionary = demo._prog()["aviso"]
	a["activo"] = true
	# Una hora guardada con el selector antiguo (sin «elegida») no cuenta: 21:00.
	a["hora"] = 13
	a["min"] = 0
	_ok(int(demo._aviso_settings()["hour"]) == 21 and demo._aviso_hour_text() == "21:00", "sin elegir, a las 21:00 (aunque quedara guardada otra)")
	demo._open_day()
	await _frames(3)
	var row := _button_with(demo.progress, "Hora del aviso")
	_ok(row != null, "«Tu día» tiene «Hora del aviso»")
	row.emit_signal("pressed")
	await _frames(3)
	var picker: ClockPicker = demo._aviso_picker
	_ok(picker != null and is_instance_valid(picker) and picker.hour == 21 and picker.minute == 0 and picker.mode == ClockPicker.Mode.HOUR, "abre el reloj en las 21:00, eligiendo la hora")
	# Tocar el 7 (anillo exterior) pasa a los minutos; arrastrar al 30.
	var r := picker.diameter * 0.5
	picker.pick(picker._polar(r * ClockPicker.OUTER_RING, ClockPicker.angle_of_hour(7)), true)
	_ok(picker.hour == 7 and picker.mode == ClockPicker.Mode.MINUTE, "tocar el 7 elige las 7 y pasa a los minutos")
	picker.pick(picker._polar(r * ClockPicker.OUTER_RING, 170.0), false)
	picker.pick(picker._polar(r * ClockPicker.OUTER_RING, ClockPicker.angle_of_minute(30)), true)
	_ok(picker.minute == 30, "arrastrar hasta el 30")
	# Volver a la hora con su ficha y elegir el anillo interior (las 19).
	picker.set_mode(ClockPicker.Mode.HOUR)
	picker.pick(picker._polar(r * ClockPicker.INNER_RING, ClockPicker.angle_of_hour(19)), true)
	_ok(picker.hour == 19 and picker.mode == ClockPicker.Mode.MINUTE, "anillo interior: las 19")
	# Cancelar no cambia nada.
	_button_with(demo.confirm_node, "Cancelar").emit_signal("pressed")
	await _frames(2)
	_ok(int(demo._aviso_settings()["hour"]) == 21, "«Cancelar» no cambia la hora")
	# Ahora sí: 7:30 y «Aceptar».
	_button_with(demo.progress, "Hora del aviso").emit_signal("pressed")
	await _frames(3)
	picker = demo._aviso_picker
	picker.pick(picker._polar(picker.diameter * 0.5 * ClockPicker.OUTER_RING, ClockPicker.angle_of_hour(7)), true)
	picker.pick(picker._polar(picker.diameter * 0.5 * ClockPicker.OUTER_RING, ClockPicker.angle_of_minute(30)), true)
	_button_with(demo.confirm_node, "Aceptar").emit_signal("pressed")
	await _frames(3)
	var s: Dictionary = demo._aviso_settings()
	_ok(int(s["hour"]) == 7 and int(s["minute"]) == 30 and demo._aviso_hour_text() == "7:30", "«Aceptar» guarda las 7:30")
	_ok(_has_text(demo.progress, Loc.f("A las %s, solo si aún no has cumplido tu reto.", "7:30")), "y «Tu día» lo dice")
	# El aviso se programa a esa hora (Reminder.plan).
	var now := int(Time.get_unix_time_from_system())
	var plan := Reminder.plan(demo._prog(), s, now, 0)
	if not plan.is_empty():
		var at := int(plan["at"])
		_ok(posmod(at, 86400) == 7 * 3600 + 30 * 60, "el aviso se programa a las 7:30")
	# Se guarda.
	var back := Progress.load_state("user://no_existe.json")
	back["aviso"] = (demo._prog()["aviso"] as Dictionary).duplicate()
	Progress.save_state(back, "user://test_reloj.json")
	var again := Progress.load_state("user://test_reloj.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_reloj.json"))
	_ok(bool(again["aviso"]["elegida"]) and int(again["aviso"]["hora"]) == 7 and int(again["aviso"]["min"]) == 30, "la hora elegida se guarda")
	# En inglés, a la manera inglesa.
	var lang: String = Loc.language
	Loc.apply("en")
	_ok(demo._aviso_hour_text() == "7:30 AM", "en inglés: 7:30 AM (%s)" % demo._aviso_hour_text())
	demo._aviso_set_time(21, 0)
	_ok(demo._aviso_hour_text() == "9 PM", "y 9 PM")
	Loc.apply(lang)
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _button_with(n: Node, label: String) -> Button:
	if n == null:
		return null
	if n is Button and _first_label(n) == Loc.t(label):
		return n
	for c in n.get_children():
		var b := _button_with(c, label)
		if b != null:
			return b
	return null


func _first_label(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	for c in n.get_children():
		var t := _first_label(c)
		if t != "":
			return t
	return ""


func _has_text(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text.contains(text):
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
