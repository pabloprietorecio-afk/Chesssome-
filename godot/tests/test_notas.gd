extends SceneTree
## «Qué pasaría» con notas por jugada (data/notas, tools/notas/generar.py): hechos de las reglas y lo que dice el
## motor (casi obligada / da casi igual, con sus valoraciones), sin ningún «porque».
## Uso: godot --headless --path godot -s tests/test_notas.gd

var fallos := 0
var hechos := 0
var demo: Control


func _initialize() -> void:
	demo = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(6)
	demo.player = Assessment.start_test("casual")
	demo.player["done"] = true
	demo.mode = "train"
	demo._close_progress()
	demo._start(int(demo._index_of["En2NL"]))
	await create_timer(0.5).timeout
	demo._begin()
	await _until(func() -> bool: return demo.phase == demo.Phase.SOLVING)
	demo.view.show_move("e5f7")
	demo._on_move_played("e5f7")
	await _until(func() -> bool: return demo.phase == demo.Phase.WRONG)
	_ok(demo.phase == demo.Phase.WRONG, "6.Cxf7 no es la solución")
	var line: Dictionary = {}
	for l: Dictionary in (demo._shown_exp()["levels"][2] as Dictionary)["lines"]:
		if str(l.get("tone", "")) == "bad":
			line = l
	_ok(not line.is_empty() and (line.get("notes", []) as Array).size() == (line.get("ucis", []) as Array).size(), "la variante «Qué pasaría» lleva una nota por jugada")
	demo._step_line(line, 0)
	await _frames(4)
	var t := _card_text()
	_ok(t.contains("ataca a la vez a la dama de d8 y a la torre de h8"), "al empezar: qué hace tu jugada")
	_ok(not t.contains("Axf7+"), "sin decir cuál era la buena")
	demo._step_line(line, 1)
	await _frames(4)
	t = _card_text()
	_ok(t.contains("Dh4: La dama estaba atacada por el caballo de f7."), "Dh4: la dama estaba atacada (hecho de las reglas)")
	_ok(t.contains("da casi igual") and t.contains("Dd7 (+3,3)") and t.contains("Dc8 (+3,0)"), "Dh4: el motor dice que da casi igual, con las otras")
	demo._step_line(line, 2)
	await _frames(4)
	t = _card_text()
	_ok(t.contains("d3: Según el motor, da casi igual") and t.contains("Cxd1"), "7.d3: da casi igual (también Cxd1)")
	demo._step_line(line, 7)
	await _frames(4)
	t = _card_text()
	_ok(t.contains("estaba atacada por el alfil de g5") and t.contains("casi obligada"), "Dg4: atacada por el alfil y casi obligada")
	_ok(not t.contains("porque"), "nunca un «porque»")
	Loc.apply("en")
	demo._step_line(line, 1)
	await _frames(4)
	t = _card_text()
	_ok(t.contains("was attacked by the knight on f7") and t.contains("hardly matters"), "en inglés: %s" % t.substr(0, 160))
	Loc.apply("es")
	print("TODO OK" if fallos == 0 else "FALLOS: %d" % fallos)
	quit(fallos)


func _card_text() -> String:
	var out := ""
	for l in demo.card_body.find_children("*", "Label", true, false):
		out += (l as Label).text + "\n"
	return out


func _ok(cond: bool, what: String) -> void:
	hechos += 1
	if cond:
		print("ok   ", what)
	else:
		fallos += 1
		print("FALLO ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, limit := 10.0) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await create_timer(0.1).timeout
		t += 0.1
