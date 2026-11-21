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
	# Sin red en la prueba: ni servidor ni clave, así contesta con el texto comprobado.
	demo.coach.cfg = {"endpoint": ""}
	var fen := "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2"
	var cfg := {"variant": "", "level": 0, "title": "Partida", "text": "", "kids": "", "unit": "", "fen": fen}

	# Error: Dh4, la dama a tiro del caballo. El motor la valora en otro hilo.
	demo._start_game(cfg, 1)
	await _frames(4)
	demo.view.show_move("d8h4")
	demo._game_move("d8h4")
	await _until(func() -> bool: return demo.coach_verdict != "" and not demo.coach_waiting)
	if OS.is_debug_build():
		_ok(demo.coach_verdict == GameDetail.BLUNDER or demo.coach_verdict == GameDetail.MISTAKE, "Dh4: error para el motor (%s)" % demo.coach_verdict)
		_ok(str(demo.coach_note) != "" and not demo.coach_from_ai, "el profesor lo explica (texto comprobado, sin red): %s" % demo.coach_note)
		_ok(demo._coach_badge_sq == Chess.sq_index("h4") and demo.view.board._badge != null and is_instance_valid(demo.view.board._badge), "la chapa está puesta en el tablero, en h4")
		_ok(_has_text(demo, "Profesor") and _has_text(demo, "?"), "en la tarjeta: la valoración y el profesor")
	if OS.is_debug_build():
		# En la tarjeta, la versión corta (sin la frase que cuenta tu jugada) y un botón «Ver completa» a la vista.
		_ok(demo.coach_full.length() > demo.coach_note.length() and demo.coach_full.ends_with(demo.coach_note), "tarjeta: versión corta; completa: %s" % demo.coach_full)
		_ok(_button_with(demo.card_body, "Ver completa") != null, "botón «Ver completa» en el bloque del profesor")
		demo._open_coach_full()
		await _frames(3)
		_ok(demo.confirm_node != null and is_instance_valid(demo.confirm_node) and _has_text(demo.confirm_node, demo.coach_full), "«Ver completa» abre la ventana con la explicación entera")
		_ok(_button_with(demo.confirm_node, "Entendido") != null, "con un botón para cerrarla")
		# La ventana se arrastra y se acuerda de dónde se dejó.
		var win := _window(demo.confirm_node)
		_ok(win != null and (win.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a < 0.7, "la ventana es bastante transparente")
		await _frames(3)
		var at := win.position
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		demo._coach_window_input(press, win)
		var drag := InputEventMouseMotion.new()
		drag.relative = Vector2(30.0, 250.0)
		demo._coach_window_input(drag, win)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		demo._coach_window_input(release, win)
		_ok(win.position.distance_to(at + Vector2(30.0, 250.0)) < 1.0, "arrastrar mueve la ventana: de %s a %s" % [at, win.position])
		demo._coach_window_input(drag, win)
		_ok(win.position.distance_to(at + Vector2(30.0, 250.0)) < 1.0, "sin el dedo puesto, no se mueve")
		var left: Vector2 = win.position
		demo._close_confirm()
		await _frames(2)
		demo._open_coach_full()
		await _frames(4)
		win = _window(demo.confirm_node)
		_ok(win != null and win.position.distance_to(left) < 2.0, "al abrirla otra vez, sale donde se dejó: %s" % (win.position if win != null else Vector2.ZERO))
		demo._close_confirm()
		await _frames(2)
	await _wait_bot(demo)
	await _frames(4)
	_ok(str(demo.coach_note) != "", "la corrección sigue tras la jugada del rival")
	var taken: bool = Chess.color_of(demo.view.board.chess.b[Chess.sq_index("h4")]) != 1
	_ok(taken or (demo.view.board._badge != null and is_instance_valid(demo.view.board._badge)), "y la chapa sigue en el tablero tras la jugada del rival (salvo que capture la dama)")

	# Jugada buena: chapa como mucho, sin explicación.
	demo._start_game(cfg, 1)
	await _frames(4)
	_ok(demo.coach_note == "" and demo.coach_verdict == "", "partida nueva: sin corrección")
	demo.view.show_move("b8c6")
	demo._game_move("b8c6")
	await _until(func() -> bool: return demo.coach_verdict != "")
	_ok(demo.coach_verdict == GameDetail.BEST or demo.coach_verdict == GameDetail.GOOD, "Cc6: buena (%s)" % demo.coach_verdict)
	_ok(demo.coach_note == "" and not demo.coach_waiting, "Cc6: el profesor no dice nada")
	_ok(demo.view.board._badge != null and is_instance_valid(demo.view.board._badge), "Cc6: también lleva chapa (todas las jugadas)")
	_ok(_has_text(demo, str(GameDetail.LABELS[demo.coach_verdict])), "y la valoración sale en pantalla")
	# La leyenda de encima del tablero: las cinco valoraciones, con la de la última jugada resaltada.
	demo.gesture_hint = false
	demo._place_tip()
	await _frames(3)
	print("hueco sobre el tablero: %d (hacen falta %d)" % [int(demo._coach_legend_top() - demo._coach_legend_floor()), int(demo.COACH_LEGEND_H + 28.0)])
	if demo._coach_legend_shown():
		var legend: Control = demo.coach_legend
		_ok(legend != null and legend.visible and legend.get_child_count() == 5, "leyenda: cinco valoraciones encima del tablero")
		for v: String in demo.COACH_LEGEND:
			_ok(_has_text(legend, str(GameDetail.LABELS[v])), "leyenda: %s" % v)
		var at: int = demo.COACH_LEGEND.find(demo.coach_verdict)
		var lit := 0
		for i in legend.get_child_count():
			if (legend.get_child(i) as Control).modulate.a > 0.9:
				lit += 1
		_ok(lit == 1 and (legend.get_child(at) as Control).modulate.a > 0.9, "leyenda: solo la de tu jugada va resaltada")
		_ok(legend.get_global_rect().end.y <= demo._coach_legend_top() and legend.get_global_rect().position.y >= demo._coach_legend_floor(), "leyenda: entre la barra y el tablero, sin taparlos")
		_ok(not _has_text(demo.card_body, str(GameDetail.LABELS[demo.coach_verdict])), "con leyenda, la tarjeta no repite la valoración")
		demo.view.board.anim_mode = Board3D.Anim.NONE
	else:
		_ok(_has_text(demo.card_body, str(GameDetail.LABELS[demo.coach_verdict])), "sin sitio para la leyenda: la valoración va en la tarjeta")
	await _wait_bot(demo)
	await _frames(4)
	_ok(demo.view.board._badge != null and is_instance_valid(demo.view.board._badge), "Cc6: la chapa sigue tras la jugada del rival")
	# Mirar una jugada atrás y volver: la chapa vuelve.
	demo._game_browse(1)
	await _frames(2)
	demo._game_browse(-99)
	await _frames(2)
	_ok(demo.view.board._badge != null and is_instance_valid(demo.view.board._badge), "al volver al directo, la chapa vuelve")

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
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _until(cond: Callable) -> void:
	for i in 900:
		if cond.call():
			return
		await process_frame


func _wait_bot(demo: Control) -> void:
	for i in 400:
		if demo.game_state != "think":
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _window(node: Node) -> PanelContainer:
	if node == null:
		return null
	for c in node.get_children():
		if c is PanelContainer:
			return c
	return null


func _button_with(node: Node, text: String) -> Button:
	if node is Button and ((node as Button).text.contains(Loc.t(text)) or _label_below(node, Loc.t(text))):
		return node
	for c in node.get_children():
		var f := _button_with(c, text)
		if f != null:
			return f
	return null


func _label_below(node: Node, text: String) -> bool:
	for c in node.get_children():
		if (c is Label and (c as Label).text.contains(text)) or _label_below(c, text):
			return true
	return false


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
