extends SceneTree
## Prueba del análisis de partidas (core/review.gd): cada clase de momento con una posición hecha a propósito, y
## que una partida sin errores no saca ninguno.
## Uso: godot --headless --path godot -s tests/test_review.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	# Mate en una que no se da (Ta8#) y mate que se permite (el rey sin salida en la primera fila).
	_caso("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1", ["a1a2"], 0, "missed_mate", "a1a8")
	_caso("r5k1/5ppp/8/8/7N/8/5PPP/6K1 w - - 0 1", ["h4f5"], 0, "allowed_mate", "")
	# Dama a tiro de un peón; caballo negro sin defensa que no se captura.
	_caso("4k3/8/8/2p5/8/8/8/3QK3 w - - 0 1", ["d1d4"], 0, "hang", "")
	_caso("4k3/8/8/3n4/8/8/8/3QK3 w - - 0 1", ["e1f2"], 0, "missed_capture", "d1d5")
	# Un cambio de piezas igualado no es un error: alfil por caballo.
	_caso("4k3/8/2p5/3n4/8/8/6B1/4K3 w - - 0 1", ["g2d5", "c6d5"], 0, "", "")
	# Apertura: el rey sin enrocar; el mismo caballo tres veces con las demás piezas en casa.
	_partida(["e2e4", "e7e5", "e1e2"], 0, "king")
	_partida(["b1c3", "h7h6", "c3e4", "h6h5", "e4g3"], 0, "repeat")
	# Una apertura normal: nada que señalar.
	_partida(["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1"], 0, "")
	# Negras también.
	_partida(["e2e4", "e7e5", "g1f3", "d8h4"], 1, "hang")
	print("Análisis: %d comprobaciones, %d fallos" % [hechos, fallos])
	print("TODO OK" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	quit(0 if fallos == 0 else 1)


func _caso(fen: String, moves: Array, player: int, kind: String, better: String) -> void:
	var fens := [fen]
	var pos := Chess.from_fen(fen)
	for u: String in moves:
		var m := pos.find_uci(u)
		_comprueba(m >= 0, "%s: %s ilegal" % [fen, u])
		if m < 0:
			return
		pos.apply(m)
		fens.append(pos.fen())
	var found := GameReview.analyze(fens, moves, player)
	_mira(found, kind, better, fen)


func _partida(moves: Array, player: int, kind: String) -> void:
	_caso(Board3D.START_FEN, moves, player, kind, "")


func _mira(found: Array, kind: String, better: String, donde: String) -> void:
	if kind == "":
		_comprueba(found.is_empty(), "%s: no debería haber momentos y hay %s" % [donde, str(found.map(func(x: Dictionary) -> String: return str(x["kind"]) + " " + str(x["text"])))])
		return
	_comprueba(found.size() >= 1 and str(found[0]["kind"]) == kind, "%s: esperaba %s y sale %s" % [donde, kind, str(found.map(func(x: Dictionary) -> String: return str(x["kind"])))])
	if found.size() >= 1:
		print("  %s: %s" % [kind, found[0]["text"]])
		if better != "":
			_comprueba(str(found[0]["better"]) == better, "%s: mejor jugada %s, sale %s" % [donde, better, found[0]["better"]])


func _comprueba(cierto: bool, mensaje: String) -> void:
	hechos += 1
	if not cierto:
		fallos += 1
		print("FALLA " + mensaje)
