class_name ExplainData
extends RefCounted
## Explicaciones ya redactadas de un problema (godot/data/explain/<id>.json).
##
## Las genera scripts/export-godot-demo.ts con la misma capa explicativa del prototipo web: cada frase sale
## del análisis del motor, de las reglas o de la etiqueta de Lichess. Aquí no se redacta ni se calcula nada:
## solo se leen y se entregan en una forma cómoda para la interfaz.
##
## Una explicación es un diccionario:
##   san, best     la jugada y la mejor jugada, en notación española
##   correct       el problema acepta la jugada
##   verdict       "best", "alsoWins", "slower", "missed" o "loses"
##   headline      titular
##   levels        cuatro niveles (qué ha pasado, el concepto, la variante, el motor), cada uno con:
##                   title, paragraphs, arrows [{from, to, tone}], lines [{label, tone, fen, ucis, text}],
##                   rows [[etiqueta, jugada, evaluación, profundidad, continuación]]
##   facts         [[fuente, texto]]: de dónde sale cada dato ("motor", "reglas" o "lichess")

var ok := false
var id := ""
var engine := ""
var depth_all := 0
var depth_top := 0

var _points: Array = []
var _solved: Dictionary = {}
var _lines: Array = []
var _strings: Array = []


static func load_for(puzzle_id: String) -> ExplainData:
	var data := ExplainData.new()
	data.id = puzzle_id
	var path := "res://data/explain/%s.json" % puzzle_id
	if not FileAccess.file_exists(path):
		return data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return data
	var d: Dictionary = parsed
	data.engine = str(d.get("engine", ""))
	data.depth_all = int(d.get("depthAll", 0))
	data.depth_top = int(d.get("depthTop", 0))
	data._points = d.get("points", [])
	data._solved = d.get("solved", {})
	data._lines = d.get("lines", [])
	data._strings = d.get("S", [])
	data.ok = not data._points.is_empty()
	data._attach_notes()
	return data


## Notas por jugada de «Qué pasaría» (godot/data/notas/<id>.json, tools/notas/generar.py): se cuelgan de cada
## variante como "notes" (una por jugada; la 0, la del jugador, vacía). Si el archivo no casa, no se usa.
func _attach_notes() -> void:
	var path := "res://data/notas/%s.json" % id
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var by_line: Dictionary = (parsed as Dictionary).get("lines", {})
	for key: String in by_line:
		var li := int(key)
		var entry: Dictionary = by_line[key]
		if li < 0 or li >= _lines.size():
			continue
		var line: Dictionary = _lines[li]
		var ucis: Array = line.get("ucis", [])
		var notes: Array = entry.get("n", [])
		if ucis.is_empty() or str(ucis[0]) != str(entry.get("u", "")) or notes.size() != ucis.size():
			continue
		line["notes"] = notes


func point_count() -> int:
	return _points.size()


## Posición del punto de decisión k (mueve quien resuelve).
func point_fen(k: int) -> String:
	if k < 0 or k >= _points.size():
		return ""
	return str((_points[k] as Dictionary).get("fen", ""))


func point_solution(k: int) -> String:
	if k < 0 or k >= _points.size():
		return ""
	return str((_points[k] as Dictionary).get("solution", ""))


## Explicación del problema entero, una vez resuelto.
func solved() -> Dictionary:
	return _unpack(_solved)


## Explicación de la jugada «uci» en el punto de decisión k ({} si no está).
func for_move(k: int, uci: String) -> Dictionary:
	if k < 0 or k >= _points.size():
		return {}
	var moves: Dictionary = (_points[k] as Dictionary).get("moves", {})
	if not moves.has(uci):
		return {}
	return _unpack(moves[uci])


func _text(index: Variant) -> String:
	var i := int(index)
	return Loc.explain(str(_strings[i])) if i >= 0 and i < _strings.size() else ""


## Fila del análisis del motor (etiqueta, jugada, evaluación, profundidad, continuación), en el idioma de la app.
func _row(index: Variant) -> PackedStringArray:
	var i := int(index)
	if i < 0 or i >= _strings.size():
		return PackedStringArray()
	var cells := str(_strings[i]).split("\t")
	if Loc.language == "es":
		return cells
	if cells.size() > 0:
		cells[0] = Loc.t(cells[0])
	if cells.size() > 1:
		cells[1] = Loc.san_text(cells[1])
	if cells.size() > 2:
		cells[2] = Loc.explain(cells[2])
	if cells.size() > 4:
		cells[4] = Loc.san_text(cells[4])
	return cells


## Variante (etiqueta y jugadas) en el idioma de la app.
static func _line(line: Dictionary) -> Dictionary:
	if Loc.language == "es":
		return line
	var out := line.duplicate()
	out["label"] = Loc.t(str(line.get("label", "")))
	out["text"] = Loc.san_text(str(line.get("text", "")))
	return out


func _unpack(e: Dictionary) -> Dictionary:
	if e.is_empty():
		return {}
	var levels: Array = []
	for packed: Dictionary in e.get("l", []):
		var paragraphs: Array = []
		for i: Variant in packed.get("p", []):
			paragraphs.append(_text(i))
		var arrows: Array = []
		for a: Array in packed.get("a", []):
			if a.size() >= 3:
				arrows.append({"from": Chess.sq_index(str(a[0])), "to": Chess.sq_index(str(a[1])), "tone": str(a[2])})
		var lines: Array = []
		for i: Variant in packed.get("n", []):
			var li := int(i)
			if li >= 0 and li < _lines.size():
				lines.append(_line(_lines[li]))
		var rows: Array = []
		for i: Variant in packed.get("r", []):
			rows.append(_row(i))
		levels.append({"title": _text(packed.get("t", -1)), "paragraphs": paragraphs, "arrows": arrows, "lines": lines, "rows": rows})
	var facts: Array = []
	for f: Array in e.get("f", []):
		if f.size() >= 2:
			facts.append([str(f[0]), _text(f[1])])
	return {
		"san": Loc.san_text(str(e.get("s", ""))),
		"best": Loc.san_text(str(e.get("b", ""))),
		"correct": int(e.get("ok", 0)) == 1,
		"verdict": str(e.get("v", "")),
		# Clase de error de la jugada ("" si es la del problema): ver Assessment.ERROR_KINDS.
		"error": str(e.get("e", "")),
		"headline": _text(e.get("h", -1)),
		"levels": levels,
		"facts": facts,
	}


## Posición a la que se llega tras jugar las primeras «plies» jugadas de una variante ("" si alguna no es legal).
static func line_fen(line: Dictionary, plies: int) -> String:
	var chess := Chess.from_fen(str(line.get("fen", "")))
	var ucis: Array = line.get("ucis", [])
	for i in mini(plies, ucis.size()):
		var m := chess.find_uci(str(ucis[i]))
		if m < 0:
			return ""
		chess.apply(m)
	return chess.fen()
