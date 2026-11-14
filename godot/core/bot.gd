class_name Bot
extends RefCounted
## Rival de las partidas de práctica: búsqueda alfa-beta propia sobre las reglas de core/chess.gd.
##
## No es un motor fuerte (GDScript, sin tablas de transposición): sirve para principiantes y jugadores de club
## flojos. La evaluación es propia y sencilla: material, casillas centrales, avance de peones, desarrollo y
## refugio del rey; nada copiado de otros motores. La fuerza de cada nivel no está medida contra jugadores reales.
##
## Niveles (LEVELS): profundidad de la búsqueda, ruido en la evaluación (para que se equivoque como una persona)
## y probabilidad de jugar al azar. Con `variant == "peones"` se juegan las partidas sin reyes del curso (la
## guerra de peones, también con caballos): gana quien corona primero, quien captura todo o quien deja al otro
## sin jugadas.

const VALUE := [0, 100, 310, 330, 500, 900, 0]
const MATE := 100000
const INF_SCORE := 1000000

## name, depth, noise (centipeones), random (probabilidad de una jugada al azar), think (segundos como mucho)
const LEVELS := [
	{"name": "Muy fácil", "depth": 1, "noise": 220, "random": 0.45, "think": 0.6},
	{"name": "Fácil", "depth": 2, "noise": 120, "random": 0.15, "think": 1.0},
	{"name": "Medio", "depth": 2, "noise": 40, "random": 0.0, "think": 1.5},
	{"name": "Difícil", "depth": 3, "noise": 12, "random": 0.0, "think": 2.5},
	{"name": "Muy difícil", "depth": 5, "noise": 0, "random": 0.0, "think": 4.0},
]

var level := 0
var variant := ""
## Sin ruido ni jugadas al azar: para las pistas, que deben ser la mejor jugada que encuentra, no un error humano.
var exact := false
var rng := RandomNumberGenerator.new()
var nodes := 0
var _deadline := 0
var _stopped := false
## Ruido fijo por jugada de la raíz (se sortea una vez por decisión): un error humano, no temblor.
var _noise := {}


func _init(lvl: int = 0, var_name: String = "", seed_value: int = -1) -> void:
	level = clampi(lvl, 0, LEVELS.size() - 1)
	variant = var_name
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## Jugada elegida (formato de Chess) o -1 si no hay ninguna.
func choose(pos: Chess) -> int:
	var moves := legal(pos)
	if moves.is_empty():
		return -1
	var cfg: Dictionary = LEVELS[level]
	nodes = 0
	_stopped = false
	_deadline = Time.get_ticks_msec() + int(float(cfg["think"]) * 1000.0)
	_noise = {}
	var noise := 0 if exact else int(cfg["noise"])
	for m in moves:
		_noise[m] = rng.randi_range(-noise, noise)
	# Un mate en una (o coronar, en la guerra de peones) no se escapa nunca, tampoco al nivel más fácil: si no,
	# el rival parece tonto adrede.
	for m in moves:
		var c := pos.after(m)
		if variant == "peones":
			if peones_result(c, m) == pos.turn:
				return m
		elif c.is_checkmate():
			return m
	if not exact and rng.randf() < float(cfg["random"]):
		return moves[rng.randi() % moves.size()]
	var best := moves[0]
	var ordered := _order(pos, moves)
	for depth in range(1, int(cfg["depth"]) + 1):
		var alpha := -INF_SCORE
		var found := -1
		for m in ordered:
			# Ventana rebajada en el ruido: así las jugadas que el ruido puede subir por encima de la mejor tienen su
			# valor exacto, no una cota (con una cota, el ruido elegiría casi al azar).
			var floor_score := alpha - 2 * noise - 1 if found >= 0 else -INF_SCORE
			var score := -_search(pos.after(m), depth - 1, -INF_SCORE, -floor_score, 1) + int(_noise[m])
			if _stopped:
				break
			if score > alpha or found < 0:
				alpha = score
				found = m
		if _stopped:
			break
		best = found
		# La mejor primero en la siguiente vuelta.
		ordered.erase(best)
		ordered.insert(0, best)
	return best


## Jugadas legales en la variante.
func legal(pos: Chess) -> PackedInt32Array:
	if variant != "peones":
		return pos.legal_moves()
	# Sin reyes no hay jaques: todas las jugadas valen, y un peón solo corona en dama (gana igual).
	var out := PackedInt32Array()
	for m in pos.pseudo_moves():
		var promo := Chess.move_promo(m)
		if promo == 0 or promo == Chess.QUEEN:
			out.append(m)
	return out


## Partidas sin reyes: quién gana con la jugada `m`, que dejó la posición `after` (0 blancas, 1 negras, −1 nadie
## todavía). Gana quien corona, quien deja al rival sin piezas o quien lo deja sin jugadas.
static func peones_result(after: Chess, m: int) -> int:
	var mover := 1 - after.turn
	if Chess.move_promo(m) != 0:
		return mover
	var left := 0
	for p in after.b:
		if p != 0 and Chess.color_of(p) == after.turn:
			left += 1
	if left == 0 or after.pseudo_moves().is_empty():
		return mover
	return -1


func _search(pos: Chess, depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 255) == 0 and Time.get_ticks_msec() > _deadline:
		_stopped = true
	if _stopped:
		return 0
	if depth <= 0:
		return _quiesce(pos, alpha, beta, ply, 4)
	var me := pos.turn
	var moves := legal(pos) if variant == "peones" else pos.pseudo_moves()
	var best := -INF_SCORE
	var any := false
	for m in _order(pos, moves):
		var c := pos.after(m)
		# Las jugadas se comprueban al hacerlas (más barato que pedir antes la lista de legales).
		if variant != "peones" and c.attacked(c.king_sq(me), 1 - me):
			continue
		any = true
		var score := 0
		if variant == "peones" and peones_result(c, m) == me:
			score = MATE - ply
		else:
			score = -_search(c, depth - 1, -beta, -alpha, ply + 1)
		if score > best:
			best = score
		if score > alpha:
			alpha = score
		if alpha >= beta or _stopped:
			break
	if not any:
		if variant == "peones":
			return -MATE + ply
		return -MATE + ply if pos.in_check() else 0
	return best


## Solo capturas (y coronaciones), para no cortar la cuenta a mitad de un cambio de piezas.
func _quiesce(pos: Chess, alpha: int, beta: int, ply: int, left: int) -> int:
	nodes += 1
	var stand := evaluate(pos)
	if stand >= beta or left <= 0:
		return stand
	if stand > alpha:
		alpha = stand
	var me := pos.turn
	var caps := PackedInt32Array()
	for m in pos.pseudo_moves():
		if pos.b[Chess.move_to(m)] != 0 or Chess.move_promo(m) == Chess.QUEEN or Chess.move_flag(m) == Chess.F_EN_PASSANT:
			caps.append(m)
	for m in _order(pos, caps):
		var c := pos.after(m)
		if variant != "peones" and c.attacked(c.king_sq(me), 1 - me):
			continue
		if variant == "peones" and peones_result(c, m) == me:
			return MATE - ply
		var score := -_quiesce(c, -beta, -alpha, ply + 1, left - 1)
		if score >= beta:
			return score
		if score > alpha:
			alpha = score
	return alpha


## Capturas primero (la pieza más valiosa con la atacante más barata), después coronaciones y el resto.
func _order(pos: Chess, moves: PackedInt32Array) -> Array:
	var scored: Array = []
	for m in moves:
		var victim := pos.b[Chess.move_to(m)]
		var k := 0
		if victim != 0:
			k = 10000 + VALUE[victim & 7] * 10 - VALUE[pos.b[Chess.move_from(m)] & 7] / 10
		if Chess.move_promo(m) == Chess.QUEEN:
			k += 9000
		scored.append([k, m])
	scored.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var out: Array = []
	for e: Array in scored:
		out.append(e[1])
	return out


## Evaluación desde el bando que mueve (centipeones).
func evaluate(pos: Chess) -> int:
	var score := 0
	var material := 0
	for s in 64:
		var p := pos.b[s]
		if p != 0 and (p & 7) != Chess.KING and (p & 7) != Chess.PAWN:
			material += VALUE[p & 7]
	# 0 = apertura y medio juego con mucho material; 1 = final.
	var endgame := clampf(1.0 - float(material - 1300) / 3000.0, 0.0, 1.0)
	for s in 64:
		var p := pos.b[s]
		if p == 0:
			continue
		var c := Chess.color_of(p)
		var t := p & 7
		var f := s & 7
		var r := s >> 3
		var rel := r if c == 0 else 7 - r
		# Distancia al centro: 0 en d4/e4/d5/e5, 6 en las esquinas.
		var center := absi(2 * f - 7) / 2 + absi(2 * r - 7) / 2
		var v: int = VALUE[t]
		match t:
			Chess.PAWN:
				v += rel * rel * (3 if variant == "peones" else 1) * (1 + int(endgame * 2.0))
				if f >= 2 and f <= 5:
					v += rel * 3
			Chess.KNIGHT:
				v += 24 - 8 * center
			Chess.BISHOP:
				v += 12 - 4 * center
			Chess.ROOK:
				v += 12 if rel == 6 else 0
			Chess.QUEEN:
				v += 6 - 2 * center
				# La dama que sale demasiado pronto suele perder tiempo.
				if endgame < 0.3 and rel > 1:
					v -= 10
			Chess.KING:
				if endgame < 0.6:
					# En el medio juego, el rey resguardado en su primera fila y en un lado.
					v += (20 if rel == 0 and (f <= 2 or f >= 6) else 0) - rel * 18
				else:
					v += int((20 - 6 * center) * endgame)
		# Piezas menores sin desarrollar al principio.
		if (t == Chess.KNIGHT or t == Chess.BISHOP) and rel == 0 and endgame < 0.4:
			v -= 15
		score += v if c == pos.turn else -v
	return score
