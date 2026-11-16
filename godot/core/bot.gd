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

## name (el grupo: los cinco niveles de siempre), sub (escalón dentro del grupo, del más fácil al más difícil),
## depth, noise (centipeones), random (probabilidad de una jugada al azar), think (segundos como mucho);
## elo y rd: fuerza medida (.github/workflows/calibrar-bot.yml + tools/calibrar/ajustar.py) en partidas contra
## Stockfish 16 con UCI_Elo 1320, 1600 y 2000 (ritmo 60 s + 0,6 s) y entre niveles vecinos, en un servidor de
## GitHub: escala de Stockfish, anclada a CCRL 40/4 (motores, no personas). rd = la mitad del margen (±2 errores
## típicos). Por debajo de 1320 (el Elo más bajo de Stockfish) la escala sale solo de las partidas entre niveles: es
## menos precisa. En un móvil, los niveles con tope de tiempo pueden jugar algo peor. Un nivel sin «elo» no cuenta
## para el nivel de juego del jugador (core/game_log.gd).
##
## Los índices no se reordenan nunca: van guardados en el historial («bot:2»), en las partidas del curso y en las
## tandas de calibración. Los cinco primeros son los niveles de siempre (15-16 nov 2026); los escalones nuevos
## (17 nov, decisión de Pablo: 13 en total, Medio 1 hacia 1200) van detrás. El orden para el jugador lo dan
## «name» y «sub» (GROUPS, group_levels).
const LEVELS := [
	{"name": "Muy fácil", "sub": 3, "depth": 1, "noise": 200, "random": 0.35, "think": 0.6, "elo": 457.0, "rd": 248.0},
	{"name": "Fácil", "sub": 4, "depth": 2, "noise": 60, "random": 0.06, "think": 1.0, "elo": 1133.0, "rd": 76.0},
	{"name": "Medio", "sub": 3, "depth": 4, "noise": 12, "random": 0.0, "think": 2.0, "elo": 1589.0, "rd": 57.0},
	{"name": "Difícil", "sub": 2, "depth": 6, "noise": 0, "random": 0.0, "think": 3.0, "elo": 1807.0, "rd": 44.0},
	{"name": "Muy difícil", "sub": 1, "depth": 12, "noise": 0, "random": 0.0, "think": 5.0, "elo": 1912.0, "rd": 46.0},
	# Escalones nuevos (objetivo entre paréntesis; el Elo, cuando esté medido).
	{"name": "Muy fácil", "sub": 1, "depth": 1, "noise": 300, "random": 0.6, "think": 0.6},  # (≈250)
	{"name": "Muy fácil", "sub": 2, "depth": 1, "noise": 250, "random": 0.47, "think": 0.6},  # (≈360)
	{"name": "Fácil", "sub": 1, "depth": 1, "noise": 130, "random": 0.22, "think": 0.8},  # (≈630)
	{"name": "Fácil", "sub": 2, "depth": 2, "noise": 100, "random": 0.15, "think": 1.0},  # (≈800)
	{"name": "Fácil", "sub": 3, "depth": 2, "noise": 75, "random": 0.1, "think": 1.0},  # (≈965)
	{"name": "Medio", "sub": 1, "depth": 2, "noise": 40, "random": 0.035, "think": 1.2},  # (≈1200)
	{"name": "Medio", "sub": 2, "depth": 3, "noise": 25, "random": 0.0, "think": 1.5},  # (≈1395)
	{"name": "Difícil", "sub": 1, "depth": 5, "noise": 6, "random": 0.0, "think": 2.5},  # (≈1700)
]
## Los cinco grupos, de más fácil a más difícil.
const GROUPS := ["Muy fácil", "Fácil", "Medio", "Difícil", "Muy difícil"]


## Índices de los niveles de un grupo, del escalón más fácil al más difícil.
static func group_levels(group: int) -> Array:
	var out: Array = []
	for i in LEVELS.size():
		if str(LEVELS[i]["name"]) == str(GROUPS[clampi(group, 0, GROUPS.size() - 1)]):
			out.append(i)
	out.sort_custom(func(a: int, b: int) -> bool: return int(LEVELS[a]["sub"]) < int(LEVELS[b]["sub"]))
	return out


## Grupo (0–4) de un nivel.
static func group_of(lvl: int) -> int:
	return maxi(0, GROUPS.find(str(LEVELS[clampi(lvl, 0, LEVELS.size() - 1)]["name"])))


## Nombre para el jugador, en su idioma: «Medio 2»; el grupo solo si no tiene escalones («Muy difícil»).
static func level_name(lvl: int) -> String:
	var cfg: Dictionary = LEVELS[clampi(lvl, 0, LEVELS.size() - 1)]
	var group := Loc.t(str(cfg["name"]))
	if group_levels(group_of(lvl)).size() <= 1:
		return group
	return "%s %d" % [group, int(cfg["sub"])]


## Elo medido (redondeado a la decena) o -1 si aún no se ha medido.
static func level_elo(lvl: int) -> int:
	var cfg: Dictionary = LEVELS[clampi(lvl, 0, LEVELS.size() - 1)]
	if not cfg.has("elo"):
		return -1
	return int(roundf(float(cfg["elo"]) / 10.0) * 10.0)


var level := 0
var variant := ""
## Tope de tiempo para pensar (segundos; 0 = el del nivel): lo pone el reloj de la partida.
var time_cap := 0.0
## Sin ruido ni jugadas al azar: para las pistas, que deben ser la mejor jugada que encuentra, no un error humano.
var exact := false
var rng := RandomNumberGenerator.new()
var nodes := 0
## Tabla de transposiciones (clave → [profundidad, valor, tipo, jugada]), jugadas «asesinas» por altura y
## historial de cortes: hacen que la búsqueda llegue más lejos en el mismo tiempo.
var _tt := {}
var _killers := {}
var _history := {}
const TT_EXACT := 0
const TT_LOWER := 1
const TT_UPPER := 2
const TT_MAX := 200000
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
	_killers = {}
	_history = {}
	var think := float(cfg["think"])
	if time_cap > 0.0:
		think = minf(think, time_cap)
	_deadline = Time.get_ticks_msec() + int(think * 1000.0)
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
	var ordered := _order(pos, moves, int((_tt.get(_key(pos), [0, 0, 0, -1]) as Array)[3]))
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


## Para el detalle de una partida: la mejor jugada (sin ruido) y el valor de la jugada hecha, a la misma
## profundidad. Valores en centipeones para el bando que mueve (±MATE cerca del mate). Con `played` = −1 solo se
## busca la mejor. Profundidad creciente hasta `max_depth` o hasta agotar `seconds`.
func analyse(pos: Chess, played: int, max_depth: int, seconds: float) -> Dictionary:
	exact = true
	var moves := pos.legal_moves()
	if moves.is_empty():
		return {}
	nodes = 0
	_stopped = false
	_killers = {}
	_history = {}
	_deadline = Time.get_ticks_msec() + int(seconds * 1000.0)
	var out := {"best": moves[0], "best_score": 0, "played_score": 0, "depth": 0}
	var ordered := _order(pos, moves, -1)
	for depth in range(1, max_depth + 1):
		var alpha := -INF_SCORE
		var found := -1
		for m in ordered:
			var score := -_search(pos.after(m), depth - 1, -INF_SCORE, -alpha, 1)
			if _stopped:
				break
			if score > alpha or found < 0:
				alpha = score
				found = m
		if _stopped:
			break
		var ps := alpha
		if played >= 0 and played != found:
			ps = -_search(pos.after(played), depth - 1, -INF_SCORE, INF_SCORE, 1)
			if _stopped:
				break
		out = {"best": found, "best_score": alpha, "played_score": ps, "depth": depth}
		ordered.erase(found)
		ordered.insert(0, found)
	return out


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
	var me := pos.turn
	var in_check := variant == "" and pos.in_check()
	# Extensión por jaque: una posición con el rey atacado no se corta aquí (si no, los mates se ven tarde).
	if in_check and ply < 24:
		depth += 1
	if depth <= 0:
		return _quiesce(pos, alpha, beta, ply, 6)
	# Tabla de transposiciones: misma posición por otro camino, mismo resultado (y su mejor jugada primero).
	var key := _key(pos)
	var hit: Array = _tt.get(key, [])
	var tt_move := -1
	if not hit.is_empty():
		tt_move = int(hit[3])
		if int(hit[0]) >= depth and ply > 0:
			var v := int(hit[1])
			match int(hit[2]):
				TT_EXACT:
					return v
				TT_LOWER:
					if v >= beta:
						return v
				TT_UPPER:
					if v <= alpha:
						return v
	var start_alpha := alpha
	var moves := legal(pos) if variant == "peones" else pos.pseudo_moves()
	var best := -INF_SCORE
	var best_move := -1
	var any := false
	for m in _order(pos, moves, tt_move, ply):
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
		if _stopped:
			return 0
		if score > best:
			best = score
			best_move = m
		if score > alpha:
			alpha = score
		if alpha >= beta:
			# Jugada tranquila que corta: se recuerda para probarla pronto en posiciones hermanas.
			if pos.b[Chess.move_to(m)] == 0:
				var k: Array = _killers.get(ply, [])
				if not k.has(m):
					k.push_front(m)
					_killers[ply] = k.slice(0, 2)
				_history[m] = int(_history.get(m, 0)) + depth * depth
			break
	if not any:
		if variant == "peones":
			return -MATE + ply
		return -MATE + ply if in_check else 0
	var flag := TT_EXACT
	if best <= start_alpha:
		flag = TT_UPPER
	elif best >= beta:
		flag = TT_LOWER
	if _tt.size() > TT_MAX:
		_tt.clear()
	_tt[key] = [depth, best, flag, best_move]
	return best


## Solo capturas (y coronaciones), para no cortar la cuenta a mitad de un cambio de piezas. Con el rey en jaque,
## todas las jugadas que lo salvan (y si no hay ninguna, es mate): si no, un mate al final de la búsqueda no se ve.
func _quiesce(pos: Chess, alpha: int, beta: int, ply: int, left: int) -> int:
	nodes += 1
	if (nodes & 255) == 0 and Time.get_ticks_msec() > _deadline:
		_stopped = true
	var me := pos.turn
	if variant == "" and left > 0 and pos.in_check():
		var any := false
		var best := -INF_SCORE
		for m in _order(pos, pos.pseudo_moves(), -1, ply):
			var c := pos.after(m)
			if c.attacked(c.king_sq(me), 1 - me):
				continue
			any = true
			var score := -_quiesce(c, -beta, -alpha, ply + 1, left - 1)
			if score > best:
				best = score
			if score > alpha:
				alpha = score
			if alpha >= beta:
				break
		return best if any else -MATE + ply
	var stand := evaluate(pos)
	if stand >= beta or left <= 0:
		return stand
	if stand > alpha:
		alpha = stand
	var caps := PackedInt32Array()
	for m in pos.pseudo_moves():
		if pos.b[Chess.move_to(m)] != 0 or Chess.move_promo(m) == Chess.QUEEN or Chess.move_flag(m) == Chess.F_EN_PASSANT:
			caps.append(m)
	for m in _order(pos, caps, -1, ply):
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


## Clave de la posición para la tabla de transposiciones (casillas, turno, enroques y al paso).
func _key(pos: Chess) -> int:
	return hash([pos.b, pos.turn, pos.castle, pos.ep])


## Orden de prueba: la de la tabla, capturas (la pieza más valiosa con la atacante más barata), coronaciones,
## las dos jugadas que cortaron en esta profundidad y, entre el resto, las que más han cortado.
func _order(pos: Chess, moves: PackedInt32Array, first: int = -1, ply: int = 0) -> Array:
	var scored: Array = []
	var killers: Array = _killers.get(ply, [])
	for m in moves:
		var victim := pos.b[Chess.move_to(m)]
		var k := 0
		if m == first:
			k = 1000000
		elif victim != 0:
			k = 100000 + VALUE[victim & 7] * 10 - VALUE[pos.b[Chess.move_from(m)] & 7] / 10
		elif Chess.move_promo(m) == Chess.QUEEN:
			k = 90000
		elif killers.has(m):
			k = 80000 - killers.find(m)
		else:
			k = mini(int(_history.get(m, 0)), 70000)
		scored.append([k, m])
	scored.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var out: Array = []
	for e: Array in scored:
		out.append(e[1])
	return out


## Evaluación desde el bando que mueve (centipeones): material, casillas, estructura de peones (doblados, aislados,
## pasados), torres en columnas abiertas, pareja de alfiles, desarrollo y refugio del rey. Todo propio y sencillo.
func evaluate(pos: Chess) -> int:
	var score := [0, 0]
	var material := 0
	var pawns := [PackedInt32Array(), PackedInt32Array()]
	pawns[0].resize(8)
	pawns[1].resize(8)
	# Fila más adelantada y más atrasada de los peones de cada bando por columna (para los pasados).
	var front := [PackedInt32Array([-1, -1, -1, -1, -1, -1, -1, -1]), PackedInt32Array([8, 8, 8, 8, 8, 8, 8, 8])]
	var bishops := [0, 0]
	for s in 64:
		var p := pos.b[s]
		if p == 0:
			continue
		var t := p & 7
		var c := Chess.color_of(p)
		if t != Chess.KING and t != Chess.PAWN:
			material += VALUE[t]
		if t == Chess.PAWN:
			var f := s & 7
			var r := s >> 3
			pawns[c][f] += 1
			if c == 0:
				front[0][f] = maxi(front[0][f], r)
			else:
				front[1][f] = mini(front[1][f], r)
		elif t == Chess.BISHOP:
			bishops[c] += 1
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
				if pawns[c][f] > 1:
					v -= 12
				var left_mates: int = pawns[c][f - 1] if f > 0 else 0
				var right_mates: int = pawns[c][f + 1] if f < 7 else 0
				if left_mates + right_mates == 0:
					v -= 12
				# Pasado: ningún peón rival delante en su columna ni en las de al lado.
				var passed := true
				for df in [-1, 0, 1]:
					var ff: int = f + df
					if ff < 0 or ff > 7:
						continue
					if c == 0 and front[1][ff] < 8 and front[1][ff] > r:
						passed = false
					if c == 1 and front[0][ff] >= 0 and front[0][ff] < r:
						passed = false
				if passed:
					v += int((10 + rel * rel * 4) * (0.5 + endgame))
			Chess.KNIGHT:
				v += 24 - 8 * center
			Chess.BISHOP:
				v += 12 - 4 * center
			Chess.ROOK:
				v += 12 if rel == 6 else 0
				if pawns[c][f] == 0:
					v += 18 if pawns[1 - c][f] == 0 else 9
			Chess.QUEEN:
				v += 6 - 2 * center
				# La dama que sale demasiado pronto suele perder tiempo.
				if endgame < 0.3 and rel > 1:
					v -= 10
			Chess.KING:
				if endgame < 0.6:
					# En el medio juego, el rey resguardado en su primera fila, en un lado y con peones delante.
					v += (20 if rel == 0 and (f <= 2 or f >= 6) else 0) - rel * 18
					var shelter := 0
					for df in [-1, 0, 1]:
						var ff: int = f + df
						if ff < 0 or ff > 7:
							continue
						var ahead: int = s + (8 if c == 0 else -8) + df
						if ahead >= 0 and ahead < 64 and pos.b[ahead] == (Chess.PAWN | (0 if c == 0 else 8)):
							shelter += 1
					v += int(shelter * 12 * (1.0 - endgame))
				else:
					v += int((20 - 6 * center) * endgame)
		# Piezas menores sin desarrollar al principio.
		if (t == Chess.KNIGHT or t == Chess.BISHOP) and rel == 0 and endgame < 0.4:
			v -= 15
		score[c] += v
	for c in 2:
		if bishops[c] >= 2:
			score[c] += 30
	return score[pos.turn] - score[1 - pos.turn]
