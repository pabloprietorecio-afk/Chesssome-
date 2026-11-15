extends SceneTree
## Detalle de una partida jugada a jugada (core/game_detail.gd): el mate del pastor visto desde las negras
## (Cf6?? permite Dxf7#) y una pieza regalada visto desde las blancas.
## Uso: godot --headless --path godot -s tests/test_game_detail.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var d1 := _run(["e2e4", "e7e5", "f1c4", "b8c6", "d1h5", "g8f6", "h5f7"], 1)
	var nf6: Dictionary = d1[2]
	_ok(nf6["san"] == "Cf6" and nf6["verdict"] == GameDetail.BLUNDER, "Cf6 es un error grave")
	_ok(" ".join(nf6["paras"]).contains("Dxf7#"), "dice que permite Dxf7#")
	# Blancas regalan el alfil: 1. e4 e5 2. Ac4 Cf6 3. Ab5?? (sin nada) … y 3… c6 lo ataca; mejor: el alfil a2 en d5
	var d2 := _run(["e2e4", "d7d5", "f1b5", "c7c6", "b5a4", "b7b5", "a4b3", "d5e4", "d1h5", "g7g6"], 0)
	var bad := 0
	for e: Dictionary in d2:
		if e["verdict"] in [GameDetail.MISTAKE, GameDetail.BLUNDER, GameDetail.INACCURACY]:
			bad += 1
	_ok(d2.size() == 5, "una entrada por cada jugada propia")
	_ok(bad >= 1, "encuentra algún fallo")
	print("ms total: %d" % (Time.get_ticks_msec() - t0))
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _run(moves: Array, color: int) -> Array:
	var pos := Chess.from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	var fens: Array = []
	for u in moves:
		fens.append(pos.fen())
		pos.apply(pos.find_uci(str(u)))
	var d := GameDetail.analyze(fens, moves, color, 0.4)
	for e: Dictionary in d:
		print("%d. %s · %s (pierde %s)" % [e["n"], e["san"], e["label"], str(e.get("loss", "-"))])
		for p in e["paras"]:
			print("      ", p)
	return d


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
