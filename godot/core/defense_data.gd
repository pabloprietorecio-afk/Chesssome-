class_name DefenseData
extends RefCounted
## Las otras salidas del rival en la solución de cada problema, analizadas con Stockfish
## (tools/defensas/analizar.py → data/defensas.json).
##
## En la solución de un problema de Lichess, la respuesta del rival es la que eligió su motor. La app la llamaba «su
## mejor defensa» sin comprobarlo ni contar qué pasaba con las demás. Aquí están, para cada respuesta del rival con
## pocas jugadas legales (2 a 7), todas las demás con su valoración y la continuación del motor; y, para las que
## tienen más jugadas, solo las raras en que otra jugada aguantaba claramente más.
##
## Aquí no se redacta nada: MoveWhy.alternatives_paras escribe las frases y comprueba en el tablero lo que afirma.
##
## Una entrada: {"j": jugada de la solución (UCI), "v": su valoración, "o": [[jugada, valoración, [continuación]]]}.
## Valoraciones desde el bando que mueve (el que se defiende): centipeones (número) o mate ("#-2": le dan mate en 2).

const PATH := "res://data/defensas.json"
## Margen, en centipeones, dentro del cual dos defensas «aguantan más o menos igual». Con valoraciones muy grandes
## el margen crece (un cuarto de la valoración): entre −15 y −17 no hay diferencia que contar.
const SAME_CP := 150

static var _engine := ""
static var _depth := 0
static var _loaded := false
static var _positions: Dictionary = {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_engine = str((parsed as Dictionary).get("motor", ""))
	_depth = int((parsed as Dictionary).get("profundidad", 0))
	_positions = (parsed as Dictionary).get("posiciones", {})


## El motor con el que se hizo el análisis («Stockfish 16») y a qué profundidad.
static func engine() -> String:
	_load()
	return _engine


static func depth() -> int:
	_load()
	return _depth


## Clave de una posición: piezas y turno (los dos primeros campos del FEN).
static func key_of(pos: Chess) -> String:
	var parts := pos.fen_core().split(" ")
	return parts[0] + " " + parts[1]


## La entrada de `pos` (mueve el que se defiende) o {}.
static func lookup(pos: Chess) -> Dictionary:
	_load()
	var e: Variant = _positions.get(key_of(pos), {})
	return e if e is Dictionary else {}


## Todas las posiciones analizadas (clave → entrada), para las pruebas.
static func all() -> Dictionary:
	_load()
	return _positions


static func is_mate(v: Variant) -> bool:
	return v is String


## Jugadas hasta el mate: negativo si se lo dan al bando que mueve (−2: le dan mate en 2); 0 si no es un mate.
static func mate_of(v: Variant) -> int:
	return int(str(v).substr(1)) if v is String else 0


## Número para ordenar valoraciones: cuanto mayor, mejor para el que se defiende. Un mate en contra es peor que
## cualquier valoración en peones y, entre dos mates, aguanta más el que llega más tarde.
static func rank(v: Variant) -> float:
	if v is String:
		var n := mate_of(v)
		return -1000000.0 - float(n) if n < 0 else 1000000.0 - float(n)
	return float(v)


## Compara otra jugada con la de la solución: −1 si es peor, 0 si aguanta más o menos igual, 1 si aguanta más.
static func compare(played: Variant, other: Variant) -> int:
	var d := rank(played) - rank(other)
	if not is_mate(played) and not is_mate(other):
		var margin := maxf(float(SAME_CP), absf(float(played)) * 0.25)
		return -1 if d >= margin else (1 if d <= -margin else 0)
	if is_mate(played) and is_mate(other) and (mate_of(played) < 0) == (mate_of(other) < 0):
		return 0 if is_zero_approx(d) else (-1 if d > 0.0 else 1)
	return -1 if d > 0.0 else 1
