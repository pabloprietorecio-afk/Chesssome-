class_name SanEs
extends RefCounted
## Notación algebraica en español (C caballo, A alfil, T torre, D dama, R rey), como la de las explicaciones.

const LETTER := ["", "", "C", "A", "T", "D", "R"]


## La jugada `m` (legal en `pos`) escrita: «Cf3», «exd5», «O-O», «e8=D+», «Dh7#».
static func san(pos: Chess, m: int) -> String:
	var from := Chess.move_from(m)
	var to := Chess.move_to(m)
	var flag := Chess.move_flag(m)
	var t := Chess.type_of(pos.b[from])
	var out := ""
	if flag == Chess.F_CASTLE_K:
		out = "O-O"
	elif flag == Chess.F_CASTLE_Q:
		out = "O-O-O"
	else:
		var capture := pos.b[to] != 0 or flag == Chess.F_EN_PASSANT
		if t == Chess.PAWN:
			if capture:
				out = Chess.sq_name(from).substr(0, 1) + "x"
			out += Chess.sq_name(to)
			if Chess.move_promo(m) != 0:
				out += "=" + LETTER[Chess.move_promo(m)]
		else:
			out = LETTER[t]
			# Otra pieza igual que también puede ir a esa casilla: se dice de cuál se trata.
			var same_file := false
			var same_rank := false
			var other := false
			for o in pos.legal_moves():
				var of := Chess.move_from(o)
				if of != from and Chess.move_to(o) == to and Chess.type_of(pos.b[of]) == t:
					other = true
					same_file = same_file or (of & 7) == (from & 7)
					same_rank = same_rank or (of >> 3) == (from >> 3)
			if other:
				if not same_file:
					out += Chess.sq_name(from).substr(0, 1)
				elif not same_rank:
					out += Chess.sq_name(from).substr(1, 1)
				else:
					out += Chess.sq_name(from)
			if capture:
				out += "x"
			out += Chess.sq_name(to)
	var after := pos.after(m)
	if after.in_check():
		out += "#" if after.legal_moves().is_empty() else "+"
	return out
