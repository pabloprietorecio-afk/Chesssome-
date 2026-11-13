class_name Chess
## Reglas del ajedrez: posición (FEN), jugadas legales, jaque, mate y ahogado.
## La referencia es chess.js (lo que usa el núcleo TypeScript); se comprueba con tests/test_chess.gd
## contra tests/golden/chess.json (npm run golden).
##
## Casillas: 0 = a1 … 7 = h1, 8 = a2 … 63 = h8.  Piezas: 0 vacío; blancas 1–6 (P N B R Q K); negras +8.
## Jugada (int): origen | destino << 6 | promoción << 12 | marca << 15.

const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const BLACK_BIT := 8

const F_NORMAL := 0
const F_DOUBLE := 1
const F_EN_PASSANT := 2
const F_CASTLE_K := 3
const F_CASTLE_Q := 4

const _KNIGHT_D: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
const _KING_D: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const _DIAG: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]
const _ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const _LETTERS := "pnbrqk"

var b := PackedInt32Array()
## 0 = juegan blancas, 1 = juegan negras.
var turn := 0
## Derechos de enroque: 1 = K, 2 = Q, 4 = k, 8 = q.
var castle := 0
## Casilla de captura al paso, o -1.
var ep := -1
var half := 0
var full := 1


static func from_fen(text: String) -> Chess:
	var c := Chess.new()
	c.b.resize(64)
	c.b.fill(0)
	var parts := text.strip_edges().split(" ", false)
	var rank := 7
	var file := 0
	for ch in parts[0]:
		if ch == "/":
			rank -= 1
			file = 0
		elif ch.is_valid_int():
			file += int(ch)
		else:
			var t := _LETTERS.find(ch.to_lower()) + 1
			c.b[file + 8 * rank] = t if ch == ch.to_upper() else t + BLACK_BIT
			file += 1
	c.turn = 1 if parts.size() > 1 and parts[1] == "b" else 0
	c.castle = 0
	if parts.size() > 2:
		if parts[2].contains("K"): c.castle |= 1
		if parts[2].contains("Q"): c.castle |= 2
		if parts[2].contains("k"): c.castle |= 4
		if parts[2].contains("q"): c.castle |= 8
	c.ep = sq_index(parts[3]) if parts.size() > 3 and parts[3] != "-" else -1
	c.half = int(parts[4]) if parts.size() > 4 else 0
	c.full = int(parts[5]) if parts.size() > 5 else 1
	return c


func copy() -> Chess:
	var c := Chess.new()
	c.b = b.duplicate()
	c.turn = turn
	c.castle = castle
	c.ep = ep
	c.half = half
	c.full = full
	return c


## Colocación de piezas, turno y enroques (los tres primeros campos del FEN).
func fen_core() -> String:
	var out := ""
	for rank in range(7, -1, -1):
		var empty := 0
		for file in 8:
			var p := b[file + 8 * rank]
			if p == 0:
				empty += 1
				continue
			if empty > 0:
				out += str(empty)
				empty = 0
			var ch := _LETTERS[(p & 7) - 1]
			out += ch if p >= BLACK_BIT else ch.to_upper()
		if empty > 0:
			out += str(empty)
		if rank > 0:
			out += "/"
	var rights := ""
	if castle & 1: rights += "K"
	if castle & 2: rights += "Q"
	if castle & 4: rights += "k"
	if castle & 8: rights += "q"
	return "%s %s %s" % [out, "b" if turn == 1 else "w", rights if rights != "" else "-"]


func fen() -> String:
	return "%s %s %d %d" % [fen_core(), sq_name(ep) if ep >= 0 else "-", half, full]


static func sq_name(s: int) -> String:
	return "abcdefgh"[s & 7] + str((s >> 3) + 1)


static func sq_index(name: String) -> int:
	return (name.unicode_at(0) - 97) + 8 * (name.unicode_at(1) - 49)


## 0 = blanca, 1 = negra, -1 = casilla vacía.
static func color_of(p: int) -> int:
	if p == 0:
		return -1
	return 1 if p >= BLACK_BIT else 0


static func type_of(p: int) -> int:
	return p & 7


static func move_from(m: int) -> int:
	return m & 63


static func move_to(m: int) -> int:
	return (m >> 6) & 63


static func move_promo(m: int) -> int:
	return (m >> 12) & 7


static func move_flag(m: int) -> int:
	return (m >> 15) & 7


static func uci(m: int) -> String:
	var s := sq_name(m & 63) + sq_name((m >> 6) & 63)
	var pr := (m >> 12) & 7
	if pr > 0:
		s += _LETTERS[pr - 1]
	return s


func king_sq(color: int) -> int:
	var k := KING + (BLACK_BIT if color == 1 else 0)
	return b.find(k)


## ¿Ataca el bando `by` la casilla `s`?
func attacked(s: int, by: int) -> bool:
	# Sin esa casilla (por ejemplo, el rey de una posición de lección que no lo tiene), nada la ataca.
	if s < 0 or s > 63:
		return false
	var f := s & 7
	var r := s >> 3
	var off := BLACK_BIT if by == 1 else 0
	# Peones: un peón blanco ataca hacia arriba, así que está una fila por debajo de la casilla atacada.
	var pr := r - 1 if by == 0 else r + 1
	if pr >= 0 and pr < 8:
		if f > 0 and b[(f - 1) + 8 * pr] == PAWN + off: return true
		if f < 7 and b[(f + 1) + 8 * pr] == PAWN + off: return true
	for d in _KNIGHT_D:
		var nf: int = f + d.x
		var nr: int = r + d.y
		if nf >= 0 and nf < 8 and nr >= 0 and nr < 8 and b[nf + 8 * nr] == KNIGHT + off: return true
	for d in _KING_D:
		var nf: int = f + d.x
		var nr: int = r + d.y
		if nf >= 0 and nf < 8 and nr >= 0 and nr < 8 and b[nf + 8 * nr] == KING + off: return true
	for d in _DIAG:
		var nf: int = f + d.x
		var nr: int = r + d.y
		while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
			var p: int = b[nf + 8 * nr]
			if p != 0:
				if p == BISHOP + off or p == QUEEN + off: return true
				break
			nf += d.x
			nr += d.y
	for d in _ORTHO:
		var nf: int = f + d.x
		var nr: int = r + d.y
		while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
			var p: int = b[nf + 8 * nr]
			if p != 0:
				if p == ROOK + off or p == QUEEN + off: return true
				break
			nf += d.x
			nr += d.y
	return false


## ¿Está en jaque el bando que mueve?
func in_check() -> bool:
	return attacked(king_sq(turn), 1 - turn)


## Avance o captura de peón: si llega a la última fila, una jugada por cada pieza de promoción.
func _pawn_moves(from: int, to: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r := to >> 3
	if r == 7 or r == 0:
		out.append(from | (to << 6) | (QUEEN << 12))
		out.append(from | (to << 6) | (ROOK << 12))
		out.append(from | (to << 6) | (BISHOP << 12))
		out.append(from | (to << 6) | (KNIGHT << 12))
	else:
		out.append(from | (to << 6))
	return out


## Jugadas sin comprobar si dejan al rey propio en jaque.
func pseudo_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	var me := turn
	for s in 64:
		var p := b[s]
		if p == 0 or (1 if p >= BLACK_BIT else 0) != me:
			continue
		var t := p & 7
		var f := s & 7
		var r := s >> 3
		if t == PAWN:
			var dir := 1 if me == 0 else -1
			var start := 1 if me == 0 else 6
			var nr: int = r + dir
			if nr >= 0 and nr < 8:
				if b[f + 8 * nr] == 0:
					out.append_array(_pawn_moves(s, f + 8 * nr))
					if r == start and b[f + 8 * (r + 2 * dir)] == 0:
						out.append(s | ((f + 8 * (r + 2 * dir)) << 6) | (F_DOUBLE << 15))
				for df in [-1, 1]:
					var nf: int = f + df
					if nf < 0 or nf > 7:
						continue
					var to: int = nf + 8 * nr
					var q: int = b[to]
					if q != 0 and (1 if q >= BLACK_BIT else 0) != me:
						out.append_array(_pawn_moves(s, to))
					elif to == ep and q == 0:
						out.append(s | (to << 6) | (F_EN_PASSANT << 15))
		elif t == KNIGHT or t == KING:
			var steps: Array[Vector2i] = _KNIGHT_D if t == KNIGHT else _KING_D
			for d in steps:
				var nf: int = f + d.x
				var nr: int = r + d.y
				if nf < 0 or nf > 7 or nr < 0 or nr > 7:
					continue
				var q: int = b[nf + 8 * nr]
				if q == 0 or (1 if q >= BLACK_BIT else 0) != me:
					out.append(s | ((nf + 8 * nr) << 6))
			if t == KING:
				var home := 4 if me == 0 else 60
				if s == home and not attacked(home, 1 - me):
					var k_right := 1 if me == 0 else 4
					var q_right := 2 if me == 0 else 8
					var rook := ROOK + (BLACK_BIT if me == 1 else 0)
					if castle & k_right and b[home + 1] == 0 and b[home + 2] == 0 and b[home + 3] == rook \
							and not attacked(home + 1, 1 - me) and not attacked(home + 2, 1 - me):
						out.append(s | ((home + 2) << 6) | (F_CASTLE_K << 15))
					if castle & q_right and b[home - 1] == 0 and b[home - 2] == 0 and b[home - 3] == 0 and b[home - 4] == rook \
							and not attacked(home - 1, 1 - me) and not attacked(home - 2, 1 - me):
						out.append(s | ((home - 2) << 6) | (F_CASTLE_Q << 15))
		else:
			var dirs: Array[Vector2i] = []
			if t == BISHOP or t == QUEEN: dirs.append_array(_DIAG)
			if t == ROOK or t == QUEEN: dirs.append_array(_ORTHO)
			for d in dirs:
				var nf: int = f + d.x
				var nr: int = r + d.y
				while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
					var q: int = b[nf + 8 * nr]
					if q == 0:
						out.append(s | ((nf + 8 * nr) << 6))
					else:
						if (1 if q >= BLACK_BIT else 0) != me:
							out.append(s | ((nf + 8 * nr) << 6))
						break
					nf += d.x
					nr += d.y
	return out


## Aplica la jugada sobre esta misma posición.
func apply(m: int) -> void:
	var from := m & 63
	var to := (m >> 6) & 63
	var promo := (m >> 12) & 7
	var flag := (m >> 15) & 7
	var p := b[from]
	var captured := b[to]
	var me := turn
	b[from] = 0
	b[to] = p if promo == 0 else promo + (BLACK_BIT if me == 1 else 0)
	if flag == F_EN_PASSANT:
		b[(to & 7) + 8 * (from >> 3)] = 0
	elif flag == F_CASTLE_K:
		b[to + 1] = 0
		b[to - 1] = ROOK + (BLACK_BIT if me == 1 else 0)
	elif flag == F_CASTLE_Q:
		b[to - 2] = 0
		b[to + 1] = ROOK + (BLACK_BIT if me == 1 else 0)
	ep = (from + to) / 2 if flag == F_DOUBLE else -1
	if (p & 7) == KING:
		castle &= ~(3 if me == 0 else 12)
	for s in [from, to]:
		if s == 0: castle &= ~2
		elif s == 7: castle &= ~1
		elif s == 56: castle &= ~8
		elif s == 63: castle &= ~4
	half = 0 if (p & 7) == PAWN or captured != 0 or flag == F_EN_PASSANT else half + 1
	if me == 1:
		full += 1
	turn = 1 - me


func after(m: int) -> Chess:
	var c := copy()
	c.apply(m)
	return c


func legal_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	var me := turn
	for m in pseudo_moves():
		var c := after(m)
		if not c.attacked(c.king_sq(me), 1 - me):
			out.append(m)
	return out


## Devuelve la jugada legal que corresponde a un texto UCI («e2e4», «e7e8q»), o -1 si no es legal.
func find_uci(text: String) -> int:
	for m in legal_moves():
		if uci(m) == text:
			return m
	return -1


func is_checkmate() -> bool:
	return in_check() and legal_moves().is_empty()


func is_stalemate() -> bool:
	return not in_check() and legal_moves().is_empty()


func perft(depth: int) -> int:
	var moves := legal_moves()
	if depth <= 1:
		return moves.size()
	var n := 0
	for m in moves:
		n += after(m).perft(depth - 1)
	return n
