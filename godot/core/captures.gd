class_name Captures
extends RefCounted
## Piezas comidas en una partida: las que le faltan a cada bando respecto a la posición de partida, y la ventaja
## de material. Sale solo de las dos posiciones, así que vale igual al mirar jugadas anteriores o al analizar.
## Un peón que coronó no cuenta como comido: la pieza nueva ocupa su lugar.

## Valor de cada pieza en peones (P, C, A, T, D); el rey no cuenta.
const VALUE := [0, 1, 3, 3, 5, 9, 0]


## Cuántas piezas de cada tipo tiene cada bando: [blancas, negras], cada una indexada por tipo (1 = peón … 6 = rey).
static func counts(pos: Chess) -> Array:
	var out := [[0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0]]
	for p in pos.b:
		if p != 0:
			out[Chess.color_of(p)][Chess.type_of(p)] += 1
	return out


## {"lost": [tipos blancos comidos, tipos negros comidos], de menor a mayor valor;
##  "lead": ventaja de material de las blancas en puntos (negativa si van por delante las negras)}.
static func of(start: Chess, now: Chess) -> Dictionary:
	var a := counts(start)
	var c := counts(now)
	var lost := [[], []]
	var points := [0, 0]
	for color in 2:
		# Piezas de más respecto al principio: vienen de peones que coronaron.
		var promoted := 0
		for t in [Chess.KNIGHT, Chess.BISHOP, Chess.ROOK, Chess.QUEEN]:
			promoted += maxi(0, int(c[color][t]) - int(a[color][t]))
		for i in maxi(0, int(a[color][Chess.PAWN]) - int(c[color][Chess.PAWN]) - promoted):
			lost[color].append(Chess.PAWN)
		for t in [Chess.KNIGHT, Chess.BISHOP, Chess.ROOK, Chess.QUEEN]:
			for i in maxi(0, int(a[color][t]) - int(c[color][t])):
				lost[color].append(t)
		for t in range(Chess.PAWN, Chess.KING):
			points[color] += int(c[color][t]) * int(VALUE[t])
	return {"lost": lost, "lead": int(points[0]) - int(points[1])}
