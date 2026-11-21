extends SceneTree
## Profesor IA dentro de la app: con premium de prueba, un error en la partida saca la tarjeta del profesor (sin
## clave, con el texto comprobado); una jugada normal no; sin premium, nunca. Opciones enseña la sección Premium.
## Uso: godot --headless --path godot -s tests/test_profesor_app.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	Premium._loaded = true
	Premium.purchased = false
	Premium.test_on = true
	Premium.coach_on = true
	Premium.test_key = ""
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	Premium._loaded = true
	Premium.test_on = true
	Premium.test_key = ""
	demo.view.board.anim_mode = Board3D.Anim.NONE
	var fen := "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2"
	var cfg := {"variant": "", "level": 0, "title": "Partida", "text": "", "kids": "", "unit": "", "fen": fen}

	# Error: Dh4, la dama a tiro del caballo.
	demo._start_game(cfg, 1)
	await _frames(4)
	demo.view.show_move("d8h4")
	demo._game_move("d8h4")
	await _frames(4)
	if OS.is_debug_build():
		_ok(str(demo.coach_note).contains("h4") and not demo.coach_from_ai, "error: el profesor lo explica (texto comprobado, sin clave): %s" % demo.coach_note)
		_ok(_has_text(demo, "Profesor"), "la tarjeta del profesor está en pantalla")
	await _wait_bot(demo)
	_ok(str(demo.coach_note) != "", "la corrección sigue tras la jugada del rival")

	# Jugada normal: nada.
	demo._start_game(cfg, 1)
	await _frames(4)
	_ok(demo.coach_note == "", "partida nueva: sin corrección")
	demo.view.show_move("b8c6")
	demo._game_move("b8c6")
	await _frames(4)
	_ok(demo.coach_note == "" and not demo.coach_waiting, "Cc6: el profesor no dice nada")
	await _wait_bot(demo)

	# Sin premium: nunca.
	Premium.test_on = false
	demo._start_game(cfg, 1)
	await _frames(4)
	demo.view.show_move("d8h4")
	demo._game_move("d8h4")
	await _frames(4)
	_ok(demo.coach_note == "", "sin premium: sin profesor")
	await _wait_bot(demo)

	# Opciones: sección Premium (con el interruptor de prueba en depuración).
	demo._close_progress()
	demo._open_options()
	await _frames(4)
	_ok(_has_text(demo, "Premium"), "Opciones tiene la sección Premium")
	if OS.is_debug_build():
		_ok(_has_text(demo, "Premium de prueba"), "con «Premium de prueba» en depuración")
	print("profesor en la app: %d de %d bien" % [hechos - fallos, hechos])
	quit(1 if fallos > 0 else 0)


func _wait_bot(demo: Control) -> void:
	for i in 400:
		if demo.game_state != "think":
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _has_text(node: Node, text: String) -> bool:
	var want := Loc.t(text)
	if (node is Label and (node as Label).text.contains(want)) or (node is Button and (node as Button).text.contains(want)):
		return true
	for c in node.get_children():
		if _has_text(c, text):
			return true
	return false


func _ok(cond: bool, what: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + what)
