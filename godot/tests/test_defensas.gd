extends SceneTree
## Las otras jugadas del rival en el «paso a paso» (core/move_why.gd, alternatives_paras; datos de Stockfish en
## data/defensas.json, de tools/defensas/analizar.py). Pablo, 17-11: «un jugador inexperto no entenderá por qué se
## sacrifica la dama»; antes solo se decía «De todas sus jugadas, es la que más resiste».
## Uso: godot --headless --path godot -s tests/test_defensas.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	# Comparar valoraciones (desde el que se defiende).
	_ok(DefenseData.compare(-600, -900) == -1, "−9 es peor que −6")
	_ok(DefenseData.compare(-600, -700) == 0, "−7 y −6: más o menos igual")
	_ok(DefenseData.compare(-600, -300) == 1, "−3 aguanta más que −6")
	_ok(DefenseData.compare(-3000, -3400) == 0, "con valoraciones enormes, el margen crece (−34 y −30: igual)")
	_ok(DefenseData.compare(-600, "#-3") == -1 and DefenseData.compare("#-3", -600) == 1, "un mate en contra es peor que cualquier valoración")
	_ok(DefenseData.compare("#-2", "#-1") == -1 and DefenseData.compare("#-2", "#-2") == 0 and DefenseData.compare("#-2", "#-4") == 1, "entre dos mates, aguanta más el que llega más tarde")
	_ok(DefenseData.engine().begins_with("Stockfish") and DefenseData.depth() >= 18, "los datos dicen con qué motor y a qué profundidad (%s, %d)" % [DefenseData.engine(), DefenseData.depth()])

	# El problema de la queja (dekIo): 19… f5? 20. Cxh6+ y el rival entrega la dama con Dxh6.
	var start := Chess.from_fen("3r1rk1/1bp2pq1/p3p2p/1p4pQ/3P2N1/2PB4/PP3PPP/R5K1 b - - 4 19")
	var line := ["f7f5", "g4h6", "g7h6", "h5h6"]
	var pos := start.copy()
	pos.apply(pos.find_uci("f7f5"))
	pos.apply(pos.find_uci("g4h6"))
	var e := MoveWhy.explain(pos, pos.find_uci("g7h6"), 0, "reply", line.slice(3))
	print("== %s · %s" % [e["san"], e["label"]])
	for p: Dictionary in e["paras"]:
		print("   ", p["text"])
	var text := _text(e)
	_ok(e["verdict"] == MoveWhy.DEFENSE, "Dxh6 sigue siendo «su mejor defensa» (ninguna otra aguanta claramente más)")
	_ok(text.contains("Tenía tres salidas: Dxh6, Rh8 y Rh7"), "se dicen las tres salidas")
	_ok(text.contains("Si Rh7, Cxf5+ es jaque descubierto y además ataca la dama rival de g7, que cae sin remedio."), "Rh7: el jaque descubierto gana la dama")
	_ok(text.contains("Rh8 aguantaba más o menos igual: seguiría Cxf5+."), "Rh8: aguantaba parecido (no hay mate, como comprobó Stockfish)")
	_ok(text.contains("Con Dxh6, al menos se lleva tu caballo a cambio de la dama."), "y por qué Dxh6: se lleva el caballo a cambio")
	_ok(not text.contains("es la que más resiste") and not text.contains("mate"), "sin la frase genérica y sin hablar de un mate que no hay")
	# El párrafo de Rh7 se ve en el tablero: el rey en h7, el caballo ya en f5 y las flechas del jaque y del ataque.
	var rh7: Dictionary = {}
	for p: Dictionary in e["paras"]:
		if str(p["text"]).begins_with("Si Rh7"):
			rh7 = p
	var shown := Chess.from_fen(str(rh7.get("fen", Board3D.START_FEN)))
	_ok(shown.b[Chess.sq_index("h7")] != 0 and Chess.type_of(shown.b[Chess.sq_index("h7")]) == Chess.KING and Chess.type_of(shown.b[Chess.sq_index("f5")]) == Chess.KNIGHT, "tablero del párrafo: rey en h7 y caballo en f5")
	_ok(_has_arrow(rh7, "h5", "h7", "bad") and _has_arrow(rh7, "f5", "g7", "bad") and _has_arrow(rh7, "g8", "h7", "info"), "con las flechas del jaque (h5→h7), del ataque (f5→g7) y de la otra jugada")
	_ok(rh7.get("move", []) == [Chess.sq_index("h6"), Chess.sq_index("f5")], "y la jugada Cxf5+ resaltada")

	# «Cae haga lo que haga», comprobado en el tablero: tras Rh7 Cxf5+ la dama cae; tras Rh8 Cxf5+ no (Dh7 la cambia).
	var kh7 := pos.after(pos.find_uci("g8h7"))
	kh7.apply(kh7.find_uci("h6f5"))
	_ok(MoveWhy._falls(kh7) == [Chess.sq_index("g7"), Chess.sq_index("f5")], "tras Rh7 Cxf5+ la dama de g7 cae")
	var kh8 := pos.after(pos.find_uci("g8h8"))
	kh8.apply(kh8.find_uci("h6f5"))
	_ok(MoveWhy._falls(kh8).is_empty(), "tras Rh8 Cxf5+ no se afirma que caiga nada")

	# Todos los problemas: cada respuesta del rival analizada tiene sus párrafos y no afirma de más.
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_puzzles.json"))
	var seen := 0
	var with_better: Array = []
	var bad: Array = []
	var generic := 0
	var replies := 0
	for p: Dictionary in raw["puzzles"]:
		var q := Chess.from_fen(str(p["fen"]))
		var moves: Array = p["moves"]
		var me := 1 - q.turn
		for i in moves.size():
			var m := q.find_uci(str(moves[i]))
			var legal := q.legal_moves()
			if i >= 2 and i % 2 == 0 and legal.size() >= 2:
				replies += 1
				var entry := DefenseData.lookup(q)
				var w := MoveWhy.explain(q, m, me, "reply", moves.slice(i + 1))
				var t := _text(w)
				if entry.is_empty():
					if legal.size() <= 7:
						bad.append("%s/%d: sin análisis con %d jugadas" % [p["id"], i, legal.size()])
					if t.contains("es la que más resiste"):
						generic += 1
				else:
					seen += 1
					var problem := _check_entry(q, m, entry, w, moves.slice(i + 1))
					if problem != "":
						bad.append("%s/%d: %s" % [p["id"], i, problem])
					if MoveWhy.has_better_defense(q, m):
						with_better.append(str(p["id"]))
			q.apply(m)
	print("respuestas del rival con más de una jugada: %d; analizadas: %d; con la frase genérica: %d; con otra que aguantaba más: %s" % [replies, seen, generic, str(with_better)])
	for b: String in bad.slice(0, 12):
		print("   MAL: ", b)
	_ok(bad.is_empty(), "todas las respuestas analizadas cuadran con el tablero y no afirman de más (%d mal)" % bad.size())
	_ok(seen >= 150, "hay análisis de las respuestas con pocas jugadas (%d)" % seen)
	_ok(with_better.size() <= 3, "son raras las respuestas de la solución que no eran la mejor defensa (%d)" % with_better.size())

	# La continuación que coincide con la jugada siguiente de la solución no se dice (sería dar la respuesta).
	var fork := Chess.from_fen("Qbq3k1/5pp1/2p4p/2PpP3/3P1B2/5N1P/4nPP1/6K1 w - - 4 35")
	var fe := MoveWhy.explain(fork, fork.find_uci("g1f1"), 1, "reply", ["e2f4"])
	_ok(_text(fe).contains("Rh2 y Rh1 aguantaban más o menos igual.") and not _text(fe).contains("Cxf4"), "si lo que seguiría es la jugada de la solución, no se dice: %s" % _text(fe))

	# Mientras el problema no está resuelto (reveal = false) no se da lo que sigue en la solución.
	var hidden := MoveWhy.explain(pos, pos.find_uci("g7h6"), 0, "reply", line.slice(3), false)
	var ht := _text(hidden)
	_ok(ht.contains("Si Rh7, Cxf5+ es jaque descubierto") and ht.contains("Rh8 aguantaba más o menos igual.") and not ht.contains("seguiría"), "sin resolver: las otras jugadas, sin «seguiría»")
	_ok(not ht.contains("a cambio de la dama") and not ht.contains("Dxh6 come"), "sin resolver: no se cuenta que a la dama se la comen después")
	var first := start.copy()
	var blunder := MoveWhy.explain(first, first.find_uci("f7f5"), 0, "blunder", line.slice(1), false)
	_ok(_text(blunder).contains("Pero es un error. ¿Ves por qué?") and not _text(blunder).contains("Cxh6"), "sin resolver: el error del rival no viene con la solución: %s" % _text(blunder))
	_ok(_text(MoveWhy.explain(first, first.find_uci("f7f5"), 0, "blunder", line.slice(1))).contains("permite Cxh6+"), "resuelto: sí se cuenta qué permitía")
	var after_f5 := first.after(first.find_uci("f7f5"))
	var sol := MoveWhy.explain(after_f5, after_f5.find_uci("g4h6"), 0, "solution", line.slice(2), false)
	_ok(not _text(sol).contains("La idea"), "sin resolver: la jugada propia no anuncia la siguiente")
	_ok(_text(MoveWhy.explain(after_f5, after_f5.find_uci("g4h6"), 0, "solution", line.slice(2))).contains("La idea: tras Dxh6, llega Dxh6"), "resuelto: sí")
	# Y en todos los problemas: sin resolver, el castigo de otra jugada no es nunca la jugada que hay que encontrar.
	var leaks := 0
	for p: Dictionary in raw["puzzles"]:
		var q := Chess.from_fen(str(p["fen"]))
		var moves: Array = p["moves"]
		for i in moves.size():
			var m := q.find_uci(str(moves[i]))
			if i >= 2 and i % 2 == 0 and i + 1 < moves.size() and not DefenseData.lookup(q).is_empty():
				var w := MoveWhy.explain(q, m, 1 - q.turn if i % 2 == 0 else q.turn, "reply", moves.slice(i + 1), false)
				var t := _text(w)
				if t.contains("igual: seguiría") or t.contains("a cambio"):
					leaks += 1
				for o: Array in DefenseData.lookup(q)["o"]:
					if str(o[2][0]) != str(moves[i + 1]):
						continue
					var alt := q.find_uci(str(o[0]))
					var a := q.after(alt)
					var given := "Si %s, %s" % [SanEs.san(q, alt), SanEs.san(a, a.find_uci(str(o[2][0])))]
					if t.contains(given):
						leaks += 1
			q.apply(m)
	_ok(leaks == 0, "sin resolver, ninguna explicación da la jugada siguiente de la solución (%d)" % leaks)

	# Otra aguantaba claramente más: se dice, y la jugada deja de ser «su mejor defensa».
	var rook := Chess.from_fen("8/R3Krk1/7p/4p3/4P2p/7P/8/8 w - - 0 49")
	var re := MoveWhy.explain(rook, rook.find_uci("e7d6"), 1, "reply", [])
	_ok(re["verdict"] == MoveWhy.PLAIN and _text(re).contains("Re6 aguantaba más"), "Rd6 no era la mejor defensa: «Re6 aguantaba más» y la etiqueta es «La jugada»")
	_ok(not _text(re).contains("la que menos pierde") and not _text(re).contains("más resiste"), "y no se dice que sea la que menos pierde")

	# En otros idiomas: las frases nuevas están traducidas y no fallan al componerse.
	for code in ["en", "de", "ru", "ja", "hi", "fr", "it", "pt", "id"]:
		Loc.apply(code)
		var le := MoveWhy.explain(pos, pos.find_uci("g7h6"), 0, "reply", line.slice(3))
		var lt := _text(le)
		if code == "en":
			print("   [en] ", lt)
			_ok(lt.contains("If Kh7, Nxf5+ is discovered check and also attacks the opponent's queen on g7, which can't be saved."), "en inglés, con su notación")
		_ok(not lt.contains("que cae sin remedio") and not lt.contains("aguantaba") and not lt.contains("a cambio de") and not lt.contains("%"), "traducido al %s" % code)
	# Fallo antiguo, visto al probar los idiomas: con las letras inglesas (inglés, japonés, indonesio, hindi), una
	# jugada de torre metida en una frase se volvía a leer como española y salía como jugada de rey («Rb1+» → «Kb1+»).
	for code in ["en", "ja", "id", "hi"]:
		Loc.apply(code)
		_ok(Loc.t("Rb1+") == "Rb1+" and Loc.f("El rival ha jugado %s.", "Rb1+").contains("Rb1+"), "%s: una jugada de torre ya escrita no se cambia por una de rey" % code)
		_ok(Loc.explain("Tb1+") == "Rb1+" and Loc.san_text("Rf2 y Tb1+").contains("Kf2") and Loc.san_text("Rf2 y Tb1+").contains("Rb1+"), "%s: las jugadas de los datos (en español) sí se pasan a su notación" % code)
		var ib := Chess.from_fen("4Q3/8/7k/2p1p3/2PpPn2/5P2/Pr6/5K2 w - - 0 42")
		ib.apply(ib.find_uci("e8e5"))
		var tb := MoveWhy.explain(ib, ib.find_uci("b2b1"), 1, "solution", ["f1f2", "f4d3"])
		_ok(str(tb["paras"][0]["text"]).begins_with("Rb1+") or str(tb["paras"][0]["text"]).contains("Rb1+"), "%s: la explicación de Tb1+ habla de Rb1+, no de Kb1+ (%s)" % [code, str(tb["paras"][0]["text"]).substr(0, 40)])
		_ok(not _text(tb).contains("Kb1"), "%s: sin «Kb1» en ninguna frase" % code)
	Loc.apply("es")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Comprueba una respuesta analizada contra el tablero y contra lo que dice la explicación. "" si todo cuadra.
func _check_entry(q: Chess, m: int, entry: Dictionary, w: Dictionary, rest: Array) -> String:
	if str(entry["j"]) != Chess.uci(m):
		return "la jugada analizada (%s) no es la de la solución" % entry["j"]
	var legal := q.legal_moves()
	var others: Array = entry["o"]
	var complete := others.size() == legal.size() - 1
	if not complete and legal.size() <= 7:
		return "faltan jugadas por analizar"
	var worse := 0
	var better := 0
	for o: Array in others:
		var alt := q.find_uci(str(o[0]))
		if alt < 0 or alt == m:
			return "jugada ilegal o repetida: %s" % o[0]
		var a := q.after(alt)
		if (o[2] as Array).is_empty() or a.find_uci(str(o[2][0])) < 0:
			return "la continuación de %s no es legal" % o[0]
		# Un mate en 1 del análisis tiene que ser mate en el tablero.
		if o[1] is String and str(o[1]) == "#-1" and not a.after(a.find_uci(str(o[2][0]))).is_checkmate():
			return "el mate en 1 tras %s no es mate" % o[0]
		var c := DefenseData.compare(entry["v"], o[1])
		worse += 1 if c < 0 else 0
		better += 1 if c > 0 else 0
	var t := _text(w)
	var paras: Array = w["paras"]
	if t.contains("es la que más resiste"):
		return "sigue la frase genérica"
	for p: Dictionary in paras:
		if str(p["text"]).strip_edges() == "" or str(p["text"]).contains("%"):
			return "párrafo vacío o sin componer"
		if Chess.from_fen(str(p["fen"])) == null:
			return "posición de un párrafo sin leer"
		# Lo que se dice mate, lo es en la posición que se enseña.
		if str(p["text"]).contains("es jaque mate.") and str(p["text"]).begins_with("Si ") and not Chess.from_fen(str(p["fen"])).is_checkmate():
			return "«es jaque mate» y no lo es"
		if str(p["text"]).contains("llega el mate:") and not Chess.from_fen(str(p["fen"])).is_checkmate():
			return "«llega el mate» y la línea no acaba en mate"
	var all_worse := complete and worse == others.size()
	if (t.contains("la que menos pierde") or t.contains("lo que menos pierde") or t.contains("retrasa el mate")) and not all_worse:
		return "dice que es la que menos pierde sin que todas las demás sean peores"
	if better > 0 and (w["verdict"] != MoveWhy.PLAIN or not t.contains("aguantaba más:")):
		return "otra aguantaba más y no se dice"
	if better == 0 and w["verdict"] != MoveWhy.DEFENSE:
		return "debería ser «su mejor defensa»"
	# La continuación igual a la jugada siguiente de la solución no se da con las que aguantaban parecido.
	if not rest.is_empty():
		var nm := q.after(m).find_uci(str(rest[0]))
		if nm >= 0:
			var nsan := SanEs.san(q.after(m), nm)
			for p: Dictionary in paras:
				if str(p["text"]).contains("más o menos igual: seguiría " + nsan + "."):
					# Solo vale si en esa otra posición es otra jugada (otra casilla de salida).
					var same_move := false
					for o: Array in others:
						if str(o[2][0]) == str(rest[0]) and DefenseData.compare(entry["v"], o[1]) == 0:
							same_move = true
					if same_move:
						return "da la jugada siguiente de la solución"
	return ""


func _has_arrow(p: Dictionary, from: String, to: String, tone: String) -> bool:
	for a: Dictionary in p.get("arrows", []):
		if int(a["from"]) == Chess.sq_index(from) and int(a["to"]) == Chess.sq_index(to) and str(a["tone"]) == tone:
			return true
	return false


func _text(e: Dictionary) -> String:
	var out := ""
	for p: Dictionary in e["paras"]:
		out += str(p["text"]) + " "
	return out


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
