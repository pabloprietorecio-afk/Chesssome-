extends SceneTree
## Mini tablero de las pantallas de espera del análisis (ui/analysis_board.gd) y su uso en «Analizando jugada a
## jugada…»: enseña la jugada que se analiza y la barra avanza con el progreso.
## Uso: godot --headless --path godot -s tests/test_espera.gd

var fallos := 0
var hechos := 0
const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"


func _initialize() -> void:
	var b := AnalysisBoard.new()
	root.add_child(b)
	b.set_side(400.0, true)
	b.show_position(START)
	_ok(str(b._board[0]) == "r" and str(b._board[60]) == "K" and str(b._board[36]) == "", "lee la posición del FEN (a8 = 0, e1 = 60)")
	_ok(b._cell_of(60) == Vector2(4, 7), "blancas abajo: e1 en la fila de abajo")
	b.flipped = true
	_ok(b._cell_of(60) == Vector2(3, 0), "negras abajo: e1 arriba y la columna al revés")
	b.flipped = false
	# Una jugada: al principio la pieza sigue en su casilla y se desliza; al acabar, la posición de después.
	b.show_move(START, "e2e4")
	_ok(b._from == AnalysisBoard._square("e2") and b._to == AnalysisBoard._square("e4") and b._glide < 1.0, "la jugada marca sus casillas y empieza a deslizarse")
	await create_timer(0.5).timeout
	_ok(str(b._board[AnalysisBoard._square("e4")]) == "P" and str(b._board[AnalysisBoard._square("e2")]) == "", "al acabar, el peón está en e4")
	# El enroque mueve también la torre.
	var castle := "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
	b.show_move(castle, "e1g1")
	await create_timer(0.5).timeout
	_ok(str(b._board[AnalysisBoard._square("g1")]) == "K" and str(b._board[AnalysisBoard._square("f1")]) == "R", "enroque: rey en g1 y torre en f1")
	# Sin animaciones: de golpe.
	b.still = true
	b.show_move(START, "g1f3")
	_ok(str(b._board[AnalysisBoard._square("f3")]) == "N" and b._glide >= 1.0, "sin animaciones, la posición cambia de golpe")
	b.still = false
	# Una jugada imposible no rompe nada: queda la posición.
	b.show_move(START, "e2e5")
	_ok(b._from == -1 and str(b._board[AnalysisBoard._square("e2")]) == "P", "una jugada imposible deja la posición tal cual")
	# Barra.
	b.progress = 0.0
	b.progress = 0.5
	await create_timer(0.3).timeout
	_ok(b._bar > 0.0 and b._bar <= 0.5, "la barra avanza poco a poco hacia el progreso")
	b.queue_free()

	# En la app: «Analizando jugada a jugada…» enseña cada jugada propia que se analiza.
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	var moves := ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"]
	var pos := Chess.from_fen(START)
	var fens: Array = [pos.fen()]
	for u: String in moves:
		pos.apply(pos.find_uci(u))
		fens.append(pos.fen())
	demo.game_history = fens
	demo.game_moves = moves
	demo.game_color = 1
	demo.mode = "game"
	demo.detail_done = false
	demo._open_detail()
	_ok(demo._wait_board != null and is_instance_valid(demo._wait_board) and demo._wait_board.flipped, "hay mini tablero, desde el lado del jugador (negras)")
	_ok(demo._detail_plies == [1, 3, 5], "las jugadas propias, en el orden del análisis")
	demo._detail_tick(2, 3)
	_ok(demo._wait_board._from == AnalysisBoard._square("b8") and demo._wait_board._to == AnalysisBoard._square("c6"), "el aviso de progreso enseña la jugada que se analiza (…Cc6)")
	_ok(is_equal_approx(demo._wait_board.progress, 2.0 / 3.0), "y la barra va por 2 de 3")
	# Que el análisis acabe antes de salir (si no, el hilo sigue con todo ya liberado).
	for i in 300:
		if demo._review_thread == null:
			break
		await create_timer(0.1).timeout
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
