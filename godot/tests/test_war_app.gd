extends SceneTree
## War Chess en la app entera: elegir la modalidad en «Jugar una partida», blindar con el botón que flota sobre la
## pieza, que el rival conteste, deshacer, y que la partida no cuente para el nivel de juego.
## Uso: godot --headless --path godot -s tests/test_war_app.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo._open_game_setup()
	await _frames(3)
	var modes := _buttons(demo.progress, ["Clásica", "War Chess"])
	_ok(modes.size() == 2, "«Clásica» y «War Chess» en la página de partida (%d)" % modes.size())
	modes[1].emit_signal("pressed")
	await _frames(3)
	_ok(demo.game_war, "War Chess elegido")
	_ok(_has_text(demo.progress, "Blindar"), "con las reglas en corto")
	# Rival «Muy difícil» (un solo escalón: empieza directamente), con blancas.
	demo.game_pick_color = 0
	_buttons(demo.progress, Bot.GROUPS)[4].emit_signal("pressed")
	await _frames(4)
	_ok(demo.mode == "game" and str(demo.game.get("variant", "")) == "war", "empieza una partida de War Chess")
	_ok(demo.view.board.chess is WarChess, "el tablero juega con las reglas de War Chess")
	_ok(str(demo.game.get("title", "")).begins_with("War Chess"), "título «War Chess · …»")
	_ok(_has_text(demo.card, Loc.f("Blindajes: tú %d · rival %d", [15, 15])), "etiqueta con los blindajes que quedan")
	var view: BoardView3D = demo.view
	view.board.select(Chess.sq_index("g1"))
	view._sync_armor_button()
	_ok(view._armor_button.visible, "al seleccionar el caballo aparece «Blindar»")
	_ok(view._armor_button.text == Loc.t("Blindar"), "con su texto")
	view._armor_button.emit_signal("pressed")
	await _frames(2)
	_ok((view.board.chess as WarChess).spent[Chess.sq_index("g1")] == 1, "el caballo queda blindado")
	_ok(demo.game_moves.size() >= 1 and str(demo.game_moves[0]) == "g1g1", "la jugada se apunta como g1g1")
	# Espera la respuesta del rival.
	var t0 := Time.get_ticks_msec()
	while demo.game_state != "play" and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	_ok(demo.game_state == "play" and demo.game_moves.size() == 2, "el rival contesta (%s)" % str(demo.game_moves))
	_ok(not view._armor_button.visible, "sin pieza seleccionada no hay botón")
	# Deshacer vuelve al principio con los blindajes también deshechos.
	demo._game_undo()
	await _frames(2)
	_ok((view.board.chess as WarChess).spent[Chess.sq_index("g1")] == 0 and view.board._shields.is_empty(), "deshacer quita el blindaje")
	_ok(demo.game_history.size() == 1, "y vuelve a la posición inicial")
	# Pista de blindaje (si la da) sin flecha: con la chapa del escudo.
	demo._stop_game_thread()
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Botones cuyo texto principal es uno de `labels`, en ese orden.
func _buttons(n: Node, labels: Array) -> Array:
	var found := {}
	_collect(n, labels, found)
	var out: Array = []
	for l: String in labels:
		if found.has(Loc.t(l)):
			out.append(found[Loc.t(l)])
	return out


func _collect(n: Node, labels: Array, found: Dictionary) -> void:
	if n is Button:
		var label := _first_label(n)
		for l: String in labels:
			if label == Loc.t(l) and not found.has(label):
				found[label] = n
	for c in n.get_children():
		_collect(c, labels, found)


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
