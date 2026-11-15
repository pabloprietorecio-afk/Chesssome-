extends SceneTree
## Explicaciones de jugadas sacadas del tablero (core/move_why.gd), con un problema real de Lichess (IBanZ):
## 42. Dxe5? Tb1+ 43. Rf2 (única: e2 y g2 las controla el caballo) Cd3+ (ataque doble al rey y la dama).
## Uso: godot --headless --path godot -s tests/test_move_why.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	var start := Chess.from_fen("4Q3/8/7k/2p1p3/2PpPn2/5P2/Pr6/5K2 w - - 0 42")
	var line := ["e8e5", "b2b1", "f1f2", "f4d3"]
	var pos := start.copy()
	var me := 1
	var roles := ["blunder", "solution", "reply", "solution"]
	var all := {}
	for i in line.size():
		var m := pos.find_uci(line[i])
		var e := MoveWhy.explain(pos, m, me, roles[i], line.slice(i + 1))
		all[line[i]] = e
		print("== %s · %s" % [e["san"], e["label"]])
		for p: Dictionary in e["paras"]:
			print("   ", p["text"], "   ", _arrows(p["arrows"]))
		pos.apply(m)
	var kf2: Dictionary = all["f1f2"]
	_ok(kf2["verdict"] == MoveWhy.ONLY, "Rf2 es la única jugada")
	var text := _text(kf2)
	_ok(text.contains("torre de b1") and text.contains("fila 1"), "dice quién da jaque y por dónde")
	_ok(text.contains("e2") and text.contains("g2") and text.contains("caballo de f4"), "dice que el caballo controla e2 y g2")
	_ok(text.contains("única jugada posible"), "concluye que era la única")
	var nd3: Dictionary = all["f4d3"]
	_ok(nd3["verdict"] == MoveWhy.BEST, "Cd3+ es la mejor jugada")
	_ok(_text(nd3).contains("ataque doble") and _text(nd3).contains("se come la dama"), "Cd3+: ataque doble y gana la dama")
	var qxe5: Dictionary = all["e8e5"]
	_ok(qxe5["verdict"] == MoveWhy.ERROR and _text(qxe5).contains("Cd3+"), "Dxe5 es un error y se dice qué permite")
	var tb1: Dictionary = all["b2b1"]
	_ok(_text(tb1).contains("solo le queda una jugada: Rf2"), "Tb1+ deja al rival una sola jugada")
	# Un mate: se explica por qué el rey no escapa.
	var mate_pos := Chess.from_fen("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
	var mm := mate_pos.find_uci("a1a8")
	var me2 := MoveWhy.explain(mate_pos, mm, 0, "solution")
	print("== Ta8# · ", me2["label"])
	for p: Dictionary in me2["paras"]:
		print("   ", p["text"], "   ", _arrows(p["arrows"]))
	_ok(_text(me2).contains("jaque mate"), "mate del pasillo explicado")
	_ok(_text(me2).contains("f7, g7 y h7") or _text(me2).contains("sus propias piezas"), "dice que sus peones le quitan las casillas")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _text(e: Dictionary) -> String:
	var out := ""
	for p: Dictionary in e["paras"]:
		out += str(p["text"]) + " "
	return out


func _arrows(list: Array) -> String:
	var out: Array = []
	for a: Dictionary in list:
		out.append("%s-%s:%s" % [Chess.sq_name(int(a["from"])), Chess.sq_name(int(a["to"])), a["tone"]])
	return "[" + ", ".join(out) + "]"


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
