extends SceneTree
## Piezas comidas y ventaja de material (core/captures.gd).
## Uso: godot --headless --path godot -s tests/test_captures.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	var start := Chess.from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	var r := Captures.of(start, start)
	_ok((r["lost"] as Array) == [[], []] and int(r["lead"]) == 0, "al empezar no falta nada")
	var pos := start.copy()
	for u: String in ["e2e4", "d7d5", "e4d5", "d8d5", "b1c3", "d5a2", "a1a2"]:
		pos.apply(pos.find_uci(u))
	r = Captures.of(start, pos)
	_ok((r["lost"] as Array)[0] == [Chess.PAWN, Chess.PAWN], "las blancas han perdido dos peones")
	_ok((r["lost"] as Array)[1] == [Chess.PAWN, Chess.QUEEN], "las negras, un peón y la dama")
	_ok(int(r["lead"]) == 8, "ventaja de las blancas: 9 + 1 − 2")
	# Coronación: el peón que corona no está comido.
	var p0 := Chess.from_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	var p1 := p0.copy()
	p1.apply(p1.find_uci("a7a8q"))
	r = Captures.of(p0, p1)
	_ok((r["lost"] as Array) == [[], []] and int(r["lead"]) == 9, "coronar no es perder el peón")
	# Una posición de partida con menos piezas (las partidas de las unidades del curso).
	var u0 := Chess.from_fen("4k3/8/8/3r4/8/8/8/R3K3 w - - 0 1")
	var u1 := u0.copy()
	u1.apply(u1.find_uci("a1a5"))
	u1.apply(u1.find_uci("d5a5"))
	r = Captures.of(u0, u1)
	_ok((r["lost"] as Array)[0] == [Chess.ROOK] and (r["lost"] as Array)[1] == [] and int(r["lead"]) == -5, "desde una posición propia")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
