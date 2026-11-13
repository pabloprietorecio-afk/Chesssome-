extends SceneTree
## Comprueba las explicaciones que viajan con la app (data/explain/*.json) contra las reglas en GDScript:
## cada jugada legal de cada punto de decisión tiene su explicación (ni una más, ni una menos), con sus cuatro
## niveles; las variantes se pueden jugar entera y legalmente; y las flechas señalan casillas del tablero.
## Uso: godot --headless --path godot -s tests/test_explain.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	var lista: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_puzzles.json"))
	if typeof(lista) != TYPE_DICTIONARY:
		print("FALLA no se puede leer data/demo_puzzles.json")
		quit(1)
		return
	var explicaciones := 0
	var variantes := 0
	for p: Dictionary in lista["puzzles"]:
		var id := str(p["id"])
		var datos := ExplainData.load_for(id)
		_comprueba(datos.ok, "%s: no hay ficha de explicaciones" % id)
		if not datos.ok:
			continue
		var moves: Array = p["moves"]
		# Hay un punto de decisión por cada jugada de quien resuelve.
		_comprueba(datos.point_count() == moves.size() >> 1, "%s: %d puntos para %d jugadas" % [id, datos.point_count(), moves.size()])
		# Las posiciones de los puntos de decisión son las que salen de jugar la línea del problema.
		var chess := Chess.from_fen(str(p["fen"]))
		for k in datos.point_count():
			var rival := chess.find_uci(str(moves[2 * k]))
			_comprueba(rival >= 0, "%s: la jugada %s del rival no es legal" % [id, str(moves[2 * k])])
			if rival < 0:
				break
			chess.apply(rival)
			var here := Chess.from_fen(datos.point_fen(k))
			_comprueba(here.fen_core() == chess.fen_core(), "%s punto %d: la posición no coincide" % [id, k])
			_comprueba(datos.point_solution(k) == str(moves[2 * k + 1]), "%s punto %d: la solución no coincide" % [id, k])
			for m in here.legal_moves():
				var uci := Chess.uci(m)
				var expl := datos.for_move(k, uci)
				_comprueba(not expl.is_empty(), "%s punto %d: falta la explicación de %s" % [id, k, uci])
				if expl.is_empty():
					continue
				explicaciones += 1
				variantes += _revisa(expl, "%s punto %d %s" % [id, k, uci])
				_comprueba(bool(expl["correct"]) == (uci == datos.point_solution(k) or here.after(m).is_checkmate()), "%s punto %d %s: «correct» no cuadra con el problema" % [id, k, uci])
			var sol := chess.find_uci(str(moves[2 * k + 1]))
			if sol < 0:
				break
			chess.apply(sol)
		var resuelto := datos.solved()
		_comprueba(not resuelto.is_empty() and bool(resuelto.get("correct", false)), "%s: falta la explicación del problema resuelto" % id)
		if not resuelto.is_empty():
			explicaciones += 1
			variantes += _revisa(resuelto, "%s resuelto" % id)
	print("Explicaciones: %d revisadas, %d variantes jugadas, %d comprobaciones, %d fallos" % [explicaciones, variantes, hechos, fallos])
	print("TODO OK" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	quit(0 if fallos == 0 else 1)


## Forma de una explicación. Devuelve cuántas variantes ha jugado.
func _revisa(expl: Dictionary, donde: String) -> int:
	var levels: Array = expl["levels"]
	_comprueba(levels.size() == 4, "%s: %d niveles" % [donde, levels.size()])
	_comprueba(str(expl["headline"]) != "" and str(expl["san"]) != "" and str(expl["best"]) != "", "%s: falta el titular o una jugada" % donde)
	if levels.size() != 4:
		return 0
	_comprueba(not (levels[0]["paragraphs"] as Array).is_empty(), "%s: el primer nivel no dice nada" % donde)
	var jugadas := 0
	for level: Dictionary in levels:
		for a: Dictionary in level["arrows"]:
			_comprueba(int(a["from"]) >= 0 and int(a["from"]) < 64 and int(a["to"]) >= 0 and int(a["to"]) < 64, "%s: flecha fuera del tablero" % donde)
		for line: Dictionary in level["lines"]:
			var ucis: Array = line["ucis"]
			_comprueba(not ucis.is_empty() and ExplainData.line_fen(line, ucis.size()) != "", "%s: la variante «%s» no se puede jugar" % [donde, str(line["text"])])
			jugadas += 1
		for row: PackedStringArray in level["rows"]:
			_comprueba(row.size() == 5, "%s: fila de la tabla con %d columnas" % [donde, row.size()])
	return jugadas


func _comprueba(cierto: bool, mensaje: String) -> void:
	hechos += 1
	if not cierto:
		fallos += 1
		if fallos <= 20:
			print("FALLA ", mensaje)
