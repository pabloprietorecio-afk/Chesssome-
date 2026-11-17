extends SceneTree
## El análisis de una partida en el tablero tiene «Volver» (Pablo, 17-11): lleva al final de la partida, desde donde
## se abrió el análisis; en una partida guardada, con «Mis partidas» a mano.
## Uso: godot --headless --path godot -s tests/test_volver_analisis.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	# Una partida guardada (como al abrirla desde «Mis partidas»): el mate del pastor con negras.
	demo._online_started(1)
	await _frames(4)
	var moves := ["e2e4", "e7e5", "f1c4", "b8c6", "d1h5", "g8f6", "h5f7"]
	var pos := Chess.from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	var fens: Array = [pos.fen()]
	for u: String in moves:
		pos.apply(pos.find_uci(u))
		fens.append(pos.fen())
	demo.mode = "game"
	demo.game = {"variant": "", "level": 0, "title": "Partida", "text": "", "kids": "", "unit": "", "clock": [], "online": false, "saved": true}
	demo.game_color = 1
	demo.game_history = fens
	demo.game_moves = moves
	demo.game_state = "over"
	demo.game_result = "Jaque mate: ha ganado el rival."
	demo.game_won = -1
	demo.view.set_fen(pos.fen())
	demo.review = [{"ply": 5, "fen": fens[5], "kind": "allowed_mate", "text": "Con 3… Cf6 el rival daba mate.", "arrows": [], "square": -1}]
	demo.review_done = true
	demo._actions_mode = ""
	demo._refresh()
	await _frames(4)
	_ok(_buttons(demo.actions, ["Análisis", "Mis partidas"]).size() == 2, "al final de la partida guardada: «Análisis» y «Mis partidas»")
	_buttons(demo.actions, ["Análisis"])[0].emit_signal("pressed")
	await _frames(4)
	_ok(demo.game_state == "review" and demo.review_at == 0, "«Análisis» enseña el momento en el tablero")
	var leave := _buttons(demo.actions, ["Volver"])
	_ok(leave.size() == 1, "con «Volver»")
	_ok(_buttons(demo.actions, ["Anterior", "Lista", "Siguiente"]).size() == 3, "sin perder «Anterior», «Lista» y «Siguiente»")
	leave[0].emit_signal("pressed")
	await _frames(4)
	_ok(demo.game_state == "over" and demo.review_at == -1, "«Volver» lleva al final de la partida")
	_ok(str(demo.view.board.chess.fen()) == str(fens[fens.size() - 1]), "con la posición final en el tablero")
	_ok(demo.progress == null or not is_instance_valid(demo.progress), "sin páginas encima")
	var mine := _buttons(demo.actions, ["Mis partidas"])
	_ok(mine.size() == 1, "y desde ahí, «Mis partidas»")
	mine[0].emit_signal("pressed")
	await _frames(4)
	_ok(demo.progress_kind == "my_games", "que lleva a «Mis partidas»")

	# «Jugada a jugada» desde el final ya tenía «Volver».
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
	if n is Button and (n as Button).visible:
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


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
