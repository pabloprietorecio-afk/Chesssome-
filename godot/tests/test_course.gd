extends SceneTree
## Prueba del curso «Aprende a jugar» (data/curso.json) con las reglas de la app (core/chess.gd):
##   collect  la solución de scripts/export-course.ts se juega con las reglas de Godot, con el turno de vuelta a
##            blancas tras cada jugada y moviendo solo la pieza de la lección: cada jugada es legal, ninguna acaba
##            en una casilla atacada si el ejercicio lo prohíbe, y al final no quedan estrellas ni piezas negras
##   move     las jugadas que juzga el curso son exactamente las legales de Godot, y al menos una vale
##   Kids     cada lección y cada ejercicio tienen su texto sencillo, y cada frase que se lee en voz alta está en
##            data/voz.json (el índice de los audios)
## Uso: godot --headless --path godot -s tests/test_course.gd

var fallos := 0
var hechos := 0
var voz := {}


func _init() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/curso.json"))
	if typeof(data) != TYPE_DICTIONARY:
		print("FALLA no se puede leer data/curso.json")
		quit(1)
		return
	var lecciones := 0
	var ejercicios := 0
	var indice: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/voz.json"))
	voz = indice if typeof(indice) == TYPE_DICTIONARY else {}
	_comprueba(not voz.is_empty(), "data/voz.json")
	for linea: Variant in (data.get("kidsLines", {}) as Dictionary).values():
		_con_voz(str(linea), "frase Kids")
	for unit: Dictionary in data["units"]:
		for lesson: Dictionary in unit["lessons"]:
			lecciones += 1
			var kids: Dictionary = lesson.get("kids", {})
			_comprueba(str(kids.get("title", "")) != "" and (kids.get("intro", []) as Array).size() > 0 and str(kids.get("takeaway", "")) != "", "%s: textos Kids" % lesson["id"])
			_con_voz(str(kids.get("title", "")), lesson["id"])
			_con_voz(str(kids.get("takeaway", "")), lesson["id"])
			for t: Variant in kids.get("intro", []):
				_con_voz(str(t), lesson["id"])
			var i := 0
			for ex: Dictionary in lesson["exercises"]:
				i += 1
				ejercicios += 1
				var donde := "%s #%d" % [lesson["id"], i]
				_comprueba(str(ex.get("kids", "")) != "", "%s: sin texto Kids" % donde)
				_con_voz(str(ex.get("kids", "")), donde)
				match str(ex["kind"]):
					"collect":
						_collect(ex, donde)
					"move":
						_move(ex, donde)
					"info":
						_comprueba(Chess.from_fen(str(ex["fen"])).b.size() == 64, "%s: posición" % donde)
	_comprueba(lecciones == int(data["lessons"]) and ejercicios == int(data["exercises"]), "recuento del curso")
	print("Curso: %d lecciones, %d ejercicios, %d comprobaciones, %d fallos" % [lecciones, ejercicios, hechos, fallos])
	print("TODO OK" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	quit(0 if fallos == 0 else 1)


func _collect(ex: Dictionary, donde: String) -> void:
	var chess := Chess.from_fen(str(ex["fen"]))
	var hero := Chess.sq_index(str(ex["hero"]))
	var stars := {}
	for s: Variant in ex.get("stars", []):
		stars[Chess.sq_index(str(s))] = true
	var solution: Array = ex["solution"]
	_comprueba(solution.size() == int(ex["par"]), "%s: el mínimo no cuadra con la solución" % donde)
	for uci: Variant in solution:
		var text := str(uci)
		_comprueba(Chess.sq_index(text.substr(0, 2)) == hero, "%s: %s no mueve la pieza de la lección" % [donde, text])
		var m := chess.find_uci(text)
		_comprueba(m >= 0, "%s: %s no es legal en Godot" % [donde, text])
		if m < 0:
			return
		chess.apply(m)
		chess.turn = 0
		chess.ep = -1
		hero = Chess.move_to(m)
		if bool(ex.get("safe", false)):
			_comprueba(not chess.attacked(hero, 1), "%s: %s acaba en una casilla atacada" % [donde, text])
		stars.erase(hero)
	var negras := 0
	for p in chess.b:
		if p != 0 and Chess.color_of(p) == 1:
			negras += 1
	_comprueba(stars.is_empty() and negras == 0, "%s: al final quedan %d estrellas y %d piezas negras" % [donde, stars.size(), negras])


func _move(ex: Dictionary, donde: String) -> void:
	var chess := Chess.from_fen(str(ex["fen"]))
	var juzgadas: Dictionary = ex["moves"]
	var legales := {}
	for m in chess.legal_moves():
		legales[Chess.uci(m)] = true
	_comprueba(legales.size() == juzgadas.size(), "%s: Godot ve %d jugadas legales y el curso juzga %d" % [donde, legales.size(), juzgadas.size()])
	var valen := 0
	for uci: String in juzgadas:
		_comprueba(legales.has(uci), "%s: %s no es legal en Godot" % [donde, uci])
		var j: Dictionary = juzgadas[uci]
		_comprueba(str(j.get("t", "")) != "", "%s: %s sin texto" % [donde, uci])
		_comprueba(str(j.get("k", "")) != "", "%s: %s sin texto Kids" % [donde, uci])
		_con_voz(str(j.get("k", "")), donde)
		if bool(j.get("ok", false)):
			valen += 1
	_comprueba(valen > 0, "%s: ninguna jugada vale" % donde)


func _con_voz(texto: String, donde: String) -> void:
	_comprueba(voz.has(texto), "%s: «%s» no está en data/voz.json" % [donde, texto])


func _comprueba(cierto: bool, mensaje: String) -> void:
	hechos += 1
	if not cierto:
		fallos += 1
		if fallos <= 20:
			print("FALLA " + mensaje)
