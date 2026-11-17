extends SceneTree
## Al tocar una pieza: su contorno en grande sobre el tablero, como un neón naranja (ui/neon_piece.gd), y la pieza
## se levanta y se agranda un poco, como si la cogieran con los dedos (board_3d.gd, _lift). Las pistas, que también
## seleccionan piezas, no encienden el neón.
## Uso: godot --headless --path godot -s tests/test_neon.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(6)
	demo._start_game({"variant": "", "level": 1, "title": "Partida", "text": "", "kids": "", "unit": "", "clock": []}, 0)
	await create_timer(0.8).timeout
	var view: BoardView3D = demo.view
	var board: Board3D = view.board
	board.anim_mode = Board3D.Anim.FULL
	_ok(NeonPiece.texture() != null, "el atlas del neón se carga")
	_ok(view.neon != null and not view.neon.shown(), "al empezar no hay neón")

	# Toque del jugador en el caballo de g1.
	var g1 := Chess.sq_index("g1")
	_pick(view, g1)
	await create_timer(0.3).timeout
	_ok(view.neon.shown() and view.neon.piece == Chess.KNIGHT, "tocar el caballo enciende su contorno")
	var node: Node3D = board._pieces[g1]
	_ok(is_equal_approx(float(node.get_meta("lift", 0.0)), 1.0), "y el caballo se levanta")
	_ok(absf(node.position.y - (Board3D.sq_pos(g1).y + Board3D.LIFT_UP)) < 0.02, "a la altura de LIFT_UP (%.2f)" % node.position.y)
	_ok(node.transform.basis.get_scale().y > Board3D.PIECE_SCALE * 1.1, "y se agranda (×%.2f)" % node.transform.basis.get_scale().y)

	# Otra pieza: cambia el contorno, la anterior se posa.
	var e2 := Chess.sq_index("e2")
	_pick(view, e2)
	await create_timer(0.3).timeout
	_ok(view.neon.piece == Chess.PAWN, "tocar el peón cambia el contorno al del peón")
	_ok(float(node.get_meta("lift", 1.0)) < 0.01 and absf(node.position.y - Board3D.sq_pos(g1).y) < 0.02, "el caballo vuelve a posarse")

	# Soltar la selección: se apaga.
	board.deselect()
	await create_timer(0.3).timeout
	_ok(not view.neon.shown() and not view.neon.visible, "al soltar la pieza se apaga el neón")
	_ok(float((board._pieces[e2] as Node3D).get_meta("lift", 1.0)) < 0.01, "y el peón se posa")

	# Una pista selecciona una pieza sin encender el neón (la pieza sí se levanta).
	board.select(g1)
	await create_timer(0.3).timeout
	_ok(not view.neon.shown(), "una selección de la app (pista) no enciende el neón")
	board.deselect()
	await create_timer(0.2).timeout

	# Jugar: el neón se apaga y la pieza llega a su casilla, posada y a su tamaño.
	_pick(view, e2)
	await create_timer(0.2).timeout
	var pawn: Node3D = board._pieces[e2]
	view._try_move(Chess.sq_index("e4"), false)
	await create_timer(0.15).timeout
	_ok(not view.neon.shown(), "al mover se apaga el neón")
	await create_timer(1.6).timeout
	var e4 := Chess.sq_index("e4")
	if board._pieces.get(e4) == pawn:
		_ok(absf(pawn.position.y - Board3D.sq_pos(e4).y) < 0.02 and absf(pawn.transform.basis.get_scale().y - Board3D.PIECE_SCALE) < 0.02, "el peón queda en e4, posado y a su tamaño")
	else:
		_ok(false, "el peón no está en e4")

	# Sin animaciones: aparece y desaparece de golpe.
	board.anim_mode = Board3D.Anim.NONE
	await create_timer(2.0).timeout
	var d2 := Chess.sq_index("d2")
	if board.is_own(d2):
		_pick(view, d2)
		_ok(view.neon.shown() and view.neon.modulate.a > 0.99, "sin animaciones, el neón sale de golpe")
		_ok(is_equal_approx(float((board._pieces[d2] as Node3D).get_meta("lift", 0.0)), 1.0), "y la pieza se levanta de golpe")
		board.deselect()
		_ok(not view.neon.visible, "y se apaga de golpe")
	demo._stop_game_thread()
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Como un toque del jugador sobre una pieza propia.
func _pick(view: BoardView3D, sq: int) -> void:
	view._user_pick = true
	view.board.select(sq)
	view._user_pick = false


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
