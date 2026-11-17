extends SceneTree
## Prueba de War Chess, regla 1 (blindaje): core/war_chess.gd, el rival (core/bot.gd), la notación (core/san.gd)
## y el tablero 3D (escudos, casilla roja, botón «Blindar»).
## Uso: godot --headless --path godot -s tests/test_war.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	_reglas()
	_peones()
	_repeticion()
	_jaques()
	_notacion()
	_rival()
	await _tablero()
	print("War Chess: %d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _comprueba(ok: bool, que: String) -> void:
	hechos += 1
	if not ok:
		fallos += 1
		print("FALLO: " + que)


func _pos(fen: String) -> WarChess:
	return WarChess.from_war_fen(WarChess.start_fen(fen))


func _juega(c: Chess, uci: String) -> bool:
	var m := c.find_uci(uci)
	if m < 0:
		return false
	c.apply(m)
	return true


func _reglas() -> void:
	var c := _pos(Board3D.START_FEN)
	_comprueba(WarChess.is_war_fen(c.fen()), "el FEN lleva el campo de War Chess")
	_comprueba(c.fen().ends_with(" war:-:-:-:-"), "al empezar no hay blindajes (%s)" % c.fen())
	_comprueba(WarChess.from_war_fen(Board3D.START_FEN + " war:e2:e2").is_armored(Chess.sq_index("e2")), "se leen los FEN antiguos de tres campos")
	# 20 jugadas normales y 15 blindajes (todas las piezas menos el rey).
	_comprueba(c.legal_moves().size() == 35, "35 jugadas al empezar (%d)" % c.legal_moves().size())
	_comprueba(c.find_uci("e1e1") < 0, "el rey no puede blindarse")
	_comprueba(WarChess.parse(Board3D.START_FEN) is not WarChess, "un FEN normal sigue siendo ajedrez normal")
	# Blindarse gasta el turno.
	_comprueba(_juega(c, "b1b1"), "blindar el caballo de b1")
	_comprueba(c.turn == 1 and c.is_armored(1) and c.spent[1] == 1, "caballo blindado y turno del rival")
	_comprueba(c.armors_left(0) == 14 and c.armors_left(1) == 15, "blindajes que quedan: 14 y 15")
	var again := WarChess.from_war_fen(c.fen())
	_comprueba(again.is_armored(1) and again.spent[1] == 1 and again.fen() == c.fen(), "el FEN guarda y recupera los blindajes")
	_comprueba(_juega(c, "e7e5"), "negras e5")
	_comprueba(c.find_uci("b1b1") < 0, "una pieza blindada no se vuelve a blindar")
	_comprueba(c.armor_rested() and c.find_uci("g1g1") < 0 and c.find_uci("e2e2") < 0, "no se puede blindar dos turnos seguidos")
	# Al mover, pierde el blindaje y no puede volver a blindarse.
	_comprueba(_juega(c, "b1c3"), "Cc3")
	_comprueba(not c.is_armored(18) and c.spent[18] == 1 and not c.is_armored(1), "el caballo se mueve sin blindaje y con el blindaje gastado")
	_comprueba(_juega(c, "a7a6"), "a6")
	_comprueba(not c.armor_rested() and c.find_uci("g1g1") >= 0, "tras una jugada normal se vuelve a poder blindar")
	_comprueba(c.find_uci("c3c3") < 0, "el caballo ya no puede blindarse")
	# Romper un blindaje: la atacante no se mueve.
	var d := _pos("4k3/8/8/3p4/4P3/8/8/4K3 b - - 0 1")
	_comprueba(_juega(d, "d5d5"), "negras blindan el peón de d5")
	var brk := d.find_uci("e4d5")
	_comprueba(brk >= 0 and WarChess.is_break_move(brk), "exd5 es un golpe al blindaje, no una captura")
	d.apply(brk)
	var d5 := Chess.sq_index("d5")
	var e4 := Chess.sq_index("e4")
	_comprueba(d.b[d5] == Chess.PAWN + Chess.BLACK_BIT and d.b[e4] == Chess.PAWN, "las dos piezas siguen en su casilla")
	_comprueba(not d.is_armored(d5) and d.spent[d5] == 1, "el peón de d5 ya no está blindado y no puede volver a blindarse")
	_comprueba(d.turn == 1 and d.half == 0, "golpear gasta el turno y reinicia la cuenta de 50")
	# Ahora sí se puede capturar.
	_comprueba(_juega(d, "e8e7") and d.find_uci("e4d5") >= 0 and not WarChess.is_break_move(d.find_uci("e4d5")), "sin blindaje, exd5 vuelve a ser captura")
	# Un peón que golpea en la última fila no corona: una sola jugada.
	var p := _pos("1r2k3/P7/8/8/8/8/8/4K3 b - - 0 1")
	_comprueba(_juega(p, "b8b8"), "torre de b8 blindada")
	var golpes := 0
	for m in p.legal_moves():
		if Chess.move_from(m) == Chess.sq_index("a7") and Chess.move_to(m) == Chess.sq_index("b8"):
			golpes += 1
			_comprueba(WarChess.is_break_move(m) and Chess.move_promo(m) == 0, "axb8 contra torre blindada: golpe sin coronar")
	_comprueba(golpes == 1, "una sola jugada a b8 (%d)" % golpes)
	# Enroque: la torre conserva que ya gastó su blindaje.
	var e := _pos("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	_comprueba(_juega(e, "h1h1") and _juega(e, "a8a8"), "torres blindadas")
	_comprueba(_juega(e, "e1g1"), "O-O con la torre blindada")
	var f1 := Chess.sq_index("f1")
	_comprueba(e.b[f1] == Chess.ROOK and not e.is_armored(f1) and e.spent[f1] == 1, "la torre enrocada pierde el blindaje y lo tiene gastado")
	# Capturar una pieza borra su estado.
	var g := _pos("4k3/8/8/3n4/8/4N3/8/4K3 w - - 0 1")
	_comprueba(_juega(g, "e3d5"), "Cxd5")
	_comprueba(g.spent[Chess.sq_index("d5")] == 0 and g.find_uci("e8e8") < 0, "la pieza que captura conserva su blindaje sin gastar")
	# Al paso: no se puede contra un peón blindado (solo con blindajes que viajan); sin blindaje, normal.
	var h := _pos("4k3/3p4/8/4P3/8/8/8/4K3 b - - 0 1")
	_comprueba(_juega(h, "d7d5") and h.find_uci("e5d6") >= 0, "al paso normal")


func _peones() -> void:
	# Peón atrincherado: una pieza necesita dos golpes; el rey también.
	var c := _pos("4k3/8/8/3p4/8/8/3R4/4K3 b - - 0 1")
	var d5 := Chess.sq_index("d5")
	_comprueba(_juega(c, "d5d5") and c.hits_left(d5) == 2, "peón blindado: aguanta dos golpes de pieza")
	_comprueba(c.hits_left(d5, Chess.sq_index("d2")) == 2, "la torre necesita dos golpes")
	c.half = 30
	_comprueba(_juega(c, "d2d5"), "primer golpe de la torre")
	_comprueba(c.is_armored(d5) and c.cracked[d5] == 1 and c.hits_left(d5) == 1, "el blindaje se agrieta pero sigue")
	_comprueba(c.half == 0, "el golpe que agrieta reinicia la cuenta de 50")
	_comprueba(c.b[Chess.sq_index("d2")] == Chess.ROOK, "la torre sigue en d2")
	var again := WarChess.from_war_fen(c.fen())
	_comprueba(again.cracked[d5] == 1 and again.is_armored(d5), "el FEN guarda la grieta (%s)" % c.fen())
	_comprueba(_juega(c, "e8e7") and _juega(c, "d2d5"), "segundo golpe")
	_comprueba(not c.is_armored(d5) and c.cracked[d5] == 0 and c.b[d5] == Chess.PAWN + Chess.BLACK_BIT, "el segundo golpe rompe el blindaje")
	# Un peón lo rompe a la primera.
	var p := _pos("4k3/8/8/3p4/4P3/8/8/4K3 b - - 0 1")
	_comprueba(_juega(p, "d5d5") and p.hits_left(d5, Chess.sq_index("e4")) == 1, "contra un peón, un solo golpe")
	_comprueba(_juega(p, "e4d5") and not p.is_armored(d5), "exd5 rompe el blindaje del peón a la primera")
	# Grieta de una pieza y golpe final de otra.
	var q := _pos("4k3/8/8/3p4/4P3/8/3R4/4K3 b - - 0 1")
	_comprueba(_juega(q, "d5d5") and _juega(q, "d2d5") and q.cracked[d5] == 1, "la torre agrieta")
	_comprueba(_juega(q, "e8d8") and _juega(q, "e4d5") and not q.is_armored(d5), "el peón remata la grieta")
	# Las piezas que no son peones siguen con un solo golpe.
	var n := _pos("4k3/8/8/3n4/8/8/3R4/4K3 b - - 0 1")
	_comprueba(_juega(n, "d5d5") and _juega(n, "d2d5") and not n.is_armored(d5), "un caballo blindado cae de un golpe")
	# El rey golpeando un peón blindado: dos golpes.
	var k := _pos("8/8/8/3pK3/8/8/8/k7 b - - 0 1")
	_comprueba(_juega(k, "d5d5") and k.hits_left(d5, Chess.sq_index("e5")) == 2, "el rey también necesita dos golpes")


func _repeticion() -> void:
	# Tercera repetición ilegal: Rg1-h1-g1-h1… con el rey negro igual. La jugada que dejaría por tercera vez una
	# posición ya vista dos veces desaparece de las legales.
	var c := _pos("7k/8/8/8/8/8/8/6K1 w - - 0 1")
	var fens: Array = [c.fen()]
	for u in ["g1h1", "h8g8", "h1g1", "g8h8", "g1h1", "h8g8", "h1g1"]:
		c.seen = WarChess.count_positions(fens)
		_comprueba(_juega(c, u), "%s todavía se puede" % u)
		fens.append(c.fen())
	c.seen = WarChess.count_positions(fens)
	_comprueba(c.find_uci("g8h8") < 0, "g8h8 repetiría la posición por tercera vez: ilegal")
	_comprueba(c.repetition_filters() and not c.repetition_locked(), "quedan otras jugadas")
	_comprueba(c.find_uci("g8g7") >= 0, "otra jugada sí vale")
	var plain := WarChess.from_war_fen(c.fen())
	_comprueba(plain.find_uci("g8h8") >= 0, "sin historial no se filtra nada")
	_comprueba(WarChess.key_of(c.fen()) == WarChess.key_of(c.fen().replace(" 0 ", " 7 ")), "la clave no depende de los contadores")


func _jaques() -> void:
	# Blindarse no saca del jaque.
	var c := _pos("4k3/8/8/8/8/8/3r4/R3K3 w Q - 0 1")
	_comprueba(_juega(c, "a1a1") and _juega(c, "d2e2"), "jaque de la torre")
	for m in c.legal_moves():
		_comprueba(not WarChess.is_armor_move(m), "en jaque no se puede blindar (%s)" % Chess.uci(m))
	# Golpear a la pieza blindada que da jaque no lo resuelve: el rey tiene que apartarse o taparse.
	var d := _pos("4k3/8/8/8/8/4r3/8/R3K3 b Q - 0 1")
	_comprueba(_juega(d, "e3e3"), "torre de e3 blindada (da jaque)")
	_comprueba(d.in_check(), "el rey blanco está en jaque")
	for m in d.legal_moves():
		_comprueba(not WarChess.is_break_move(m), "golpear a la que da jaque no vale (%s)" % Chess.uci(m))
	# Mate con una pieza blindada pegada al rey: el rey no puede capturarla.
	var mate := _pos("6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1")
	_comprueba(_juega(mate, "d1d8"), "Td8#")
	_comprueba(mate.is_checkmate(), "mate normal sigue siendo mate")


func _notacion() -> void:
	var c := _pos(Board3D.START_FEN)
	_comprueba(SanEs.san(c, c.find_uci("g1g1")) == "[Cg1]", "notación de blindarse: [Cg1] (%s)" % SanEs.san(c, c.find_uci("g1g1")))
	_comprueba(SanEs.san(c, c.find_uci("e2e2")) == "[e2]", "notación de blindar un peón: [e2]")
	var d := _pos("4k3/8/8/3p4/4P3/8/8/4K3 b - - 0 1")
	_juega(d, "d5d5")
	_comprueba(SanEs.san(d, d.find_uci("e4d5")) == "ex[d5]", "notación del golpe: ex[d5] (%s)" % SanEs.san(d, d.find_uci("e4d5")))


func _rival() -> void:
	# El rival juega War Chess: siempre jugadas legales, y la partida acaba (el blindaje no la atasca).
	for level in [0, 1, 2]:
		var bot := Bot.new(level, "war", 11 + level)
		bot.time_cap = 0.25
		var c := _pos(Board3D.START_FEN)
		var plies := 0
		var armors := 0
		var breaks := 0
		while plies < 160:
			var moves := c.legal_moves()
			if moves.is_empty():
				break
			var m := bot.choose(c)
			if not moves.has(m):
				_comprueba(false, "nivel %d: jugada ilegal %s" % [level, Chess.uci(m)])
				break
			if WarChess.is_armor_move(m):
				armors += 1
			if WarChess.is_break_move(m):
				breaks += 1
			c.apply(m)
			plies += 1
		_comprueba(plies > 10, "nivel %d: juega una partida (%d jugadas, %d blindajes, %d golpes)" % [level, plies, armors, breaks])
		_comprueba(armors <= 30, "nivel %d: como mucho 30 blindajes en la partida" % level)
		print("  nivel %d: %d medias jugadas, %d blindajes, %d golpes, %s" % [level, plies, armors, breaks, c.fen()])
	# Con una pieza atacada y sin defensa, el rival «Medio» la salva (moviéndola o blindándola).
	var hang := _pos("4k3/8/8/2p5/3Q4/8/8/4K3 w - - 0 1")
	var m := Bot.new(2, "war", 5).choose(hang)
	var after := hang.after(m) as WarChess
	var q := Chess.move_to(m) if not WarChess.is_armor_move(m) else Chess.move_from(m)
	_comprueba(after.is_armored(q) or not after.attacked(q, 1) or q == Chess.sq_index("c5"), "el rival no deja la dama a tiro (%s)" % Chess.uci(m))
	# Da el mate en una también en War Chess.
	var mate := _pos("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1")
	_comprueba(Chess.uci(Bot.new(0, "war", 3).choose(mate)) == "a1a8", "da el mate en una")


func _tablero() -> void:
	var view := BoardView3D.new()
	view.size = Vector2(1080, 1080)
	root.add_child(view)
	await process_frame
	var board := view.board
	board.anim_mode = Board3D.Anim.FULL
	board.set_fen(WarChess.start_fen(Board3D.START_FEN))
	_comprueba(board.chess is WarChess, "el tablero entiende el FEN de War Chess")
	board.select(Chess.sq_index("g1"))
	_comprueba(board.armor_option >= 0 and WarChess.is_armor_move(board.armor_option), "al seleccionar el caballo se ofrece blindarlo")
	_comprueba(not board.is_target(Chess.sq_index("g1")), "tocar otra vez la pieza no la blinda")
	board.select(Chess.sq_index("e1"))
	_comprueba(board.armor_option < 0, "al rey no se le ofrece blindaje")
	board.deselect()
	_comprueba(view.show_move("g1g1"), "blindar con show_move")
	_comprueba(board._shields.has(Chess.sq_index("g1")), "aparece el escudo")
	var a := board._state_img.get_pixel(6, 0).a
	_comprueba(a < 0.75, "la casilla del caballo blindado se tiñe (A=%.2f)" % a)
	for i in 30:
		await process_frame
	_comprueba(view.show_move("e7e5"), "e5")
	_comprueba(view.show_move("g1f3"), "Cf3: el caballo se mueve")
	_comprueba(not board._shields.has(Chess.sq_index("g1")) and not board._shields.has(Chess.sq_index("f3")), "el escudo se queda atrás y se va")
	_comprueba(view.show_move("b8b8") and view.show_move("e2e4") and view.show_move("d7d5"), "más jugadas")
	_comprueba(view.show_move("b1b1"), "blinda el caballo de b1")
	# Golpe: negras no pueden, pero la posición sirve con un FEN preparado.
	board.set_fen(WarChess.start_fen("4k3/8/8/3p4/4P3/8/8/4K3 b - - 0 1"))
	_comprueba(view.show_move("d5d5"), "negras blindan d5")
	board.select(Chess.sq_index("e4"))
	var mk := 0
	for m in board._targets:
		if Chess.move_to(m) == Chess.sq_index("d5"):
			mk = 1 if WarChess.is_break_move(m) else 2
	_comprueba(mk == 1, "el golpe se marca como golpe al blindaje")
	board.deselect()
	_comprueba(view.show_move("e4d5"), "exd5 rompe el blindaje")
	var d5 := Chess.sq_index("d5")
	var e4 := Chess.sq_index("e4")
	_comprueba(not board._shields.has(d5), "el escudo se va")
	_comprueba(board._pieces.has(d5) and board._pieces.has(e4), "las dos piezas siguen en el tablero")
	var t0 := Time.get_ticks_msec()
	while board.is_animating() and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	var took := Time.get_ticks_msec() - t0
	_comprueba(took < 1500, "la animación del golpe es corta (%d ms)" % took)
	_comprueba((board._pieces[e4] as Node3D).position.distance_to(Board3D.sq_pos(e4)) < 0.01, "la atacante vuelve a su casilla")
	_comprueba((board._pieces[d5] as Node3D).position.distance_to(Board3D.sq_pos(d5)) < 0.01, "la golpeada queda en su casilla")
	# Peón atrincherado en el tablero: escudo reforzado; el golpe de una pieza lo agrieta y el escudo se queda.
	board.set_fen(WarChess.start_fen("4k3/8/8/3p4/8/8/3R4/4K3 b - - 0 1"))
	_comprueba(view.show_move("d5d5"), "peón blindado")
	_comprueba(str((board._shields[d5] as Sprite3D).get_meta("kind")) == "pawn" and (board._shields[d5] as Node).get_node_or_null("Detras") != null, "con dos escudos (dos golpes)")
	_comprueba(view.show_move("d2d5"), "Td5 golpea")
	_comprueba(board._shields.has(d5), "el escudo aguanta")
	for i in 40:
		await process_frame
	_comprueba(str((board._shields[d5] as Sprite3D).get_meta("kind")) == "normal" and (board._shields[d5] as Node).get_node_or_null("Detras") == null, "y queda uno solo")
	_comprueba(view.show_move("e8e7") and view.show_move("d2d5"), "segundo golpe")
	_comprueba(not board._shields.has(d5), "el escudo se va")
	view.queue_free()
