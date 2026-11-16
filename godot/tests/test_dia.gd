extends SceneTree
## «Tu día»: cada reto sin cumplir lleva un botón «Ir» que lleva directo a ese reto; los cumplidos, no.
## Uso: godot --headless --path godot -s tests/test_dia.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	# Un jugador con un fallo antiguo sin repasar (el problema 3 del banco).
	var p: Dictionary = Assessment.start_test("never")
	p["done"] = true
	var failed_id := str(demo.puzzles[3]["id"])
	p = Assessment.record_try(p, demo.puzzles[3], {"correct": false, "failStep": 0, "error": "otra"}, "train")
	p["done"] = true
	demo.player = p
	var s: Dictionary = demo._prog()
	var day: int = demo._prog_day()
	Progress.ensure_today(s, day, demo._prog_ctx())
	# Los cuatro tipos de reto, sin cumplir, y uno cumplido.
	s["reto"]["metas"] = [
		{"tipo": "problemas", "meta": 3, "hecho": false},
		{"tipo": "repaso", "meta": 1, "hecho": false},
		{"tipo": "leccion", "meta": 1, "hecho": false},
		{"tipo": "partida", "meta": 1, "hecho": false},
	]
	s["semana"]["familia"] = "doble"
	s["semana"]["completo"] = false

	var gos := await _open(demo)
	_ok(gos.size() == 5, "«Ir» en los cuatro retos de hoy y en el de la semana (%d)" % gos.size())

	# Problemas: el entrenamiento recomendado.
	(await _open(demo))[0].emit_signal("pressed")
	await _frames(3)
	_ok(demo.mode == "train" and demo.train_family == "" and not demo.puzzle.is_empty() and _no_page(demo), "problemas: al entrenamiento recomendado")

	# Repaso: directo al fallo antiguo, como repaso.
	(await _open(demo))[1].emit_signal("pressed")
	await _frames(3)
	_ok(demo.mode == "train" and demo.is_review and str(demo.puzzle.get("id", "")) == failed_id, "repaso: directo al fallo antiguo")

	# Lección: la primera que falta.
	var first := ""
	for l: Dictionary in demo._course_lessons():
		if not demo.course_done.has(str(l["id"])):
			first = str(l["id"])
			break
	(await _open(demo))[2].emit_signal("pressed")
	await _frames(3)
	_ok(demo.mode == "learn" and str(demo.lesson.get("id", "")) == first, "lección: la siguiente que falta (%s)" % first)

	# Partida: a elegir rival.
	(await _open(demo))[3].emit_signal("pressed")
	await _frames(3)
	_ok(demo.progress_kind == "game_setup", "partida: a elegir rival")

	# Semana: problemas de su categoría.
	(await _open(demo))[4].emit_signal("pressed")
	await _frames(3)
	_ok(demo.mode == "train" and demo.train_family == "doble", "semana: problemas de esa categoría")

	# Un reto cumplido no lleva «Ir».
	s["reto"]["metas"][0]["hecho"] = true
	s["reto"]["metas"][0]["actual"] = 3
	_ok((await _open(demo)).size() == 4, "un reto cumplido no lleva «Ir»")
	# Aviso diario: a las 21:00 siempre, aunque se hubiera guardado otra hora; sin selector de hora.
	s["aviso"] = {"activo": true, "hora": 13, "min": 30}
	var st: Dictionary = demo._aviso_settings()
	_ok(int(st["hour"]) == 21 and int(st["minute"]) == 0 and bool(st["enabled"]), "el aviso va a las 21:00, sin importar la hora guardada")
	demo._open_day()
	await _frames(3)
	_ok(not _has_text(demo.progress, Loc.t("Hora del aviso")), "sin selector de hora")
	_ok(_has_text(demo.progress, Loc.f("A las %s, solo si aún no has cumplido tu reto.", "21:00")) or not (demo._aviso_available() or not demo.use_settings), "dice cuándo llega: a las 21:00")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Abre «Tu día» y devuelve sus botones «Ir», en orden.
func _open(demo: Control) -> Array:
	demo._open_day()
	await _frames(3)
	var out: Array = []
	_collect(demo.progress, out)
	return out


func _collect(n: Node, out: Array) -> void:
	if n is Button and _label_of(n) == Loc.t("Ir"):
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _label_of(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	for c in n.get_children():
		var t := _label_of(c)
		if t != "":
			return t
	return ""


func _has_text(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text == text:
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


func _no_page(demo: Control) -> bool:
	return demo.progress == null or not is_instance_valid(demo.progress)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
