class_name MoveWhy
extends RefCounted
## Por qué se juega una jugada, con hechos que se comprueban en el tablero: si era la única posible, la mejor o un
## error, y por qué. Nada sale de cifras de un motor: cada frase se deduce de la posición (qué piezas atacan qué
## casillas, qué jugadas son legales, qué pasa tras cada respuesta posible).
##
## Una explicación es una lista de párrafos, uno por idea. Cada párrafo trae sus flechas y la posición en la que hay
## que verlas: {"text", "arrows": [{"from", "to", "tone"}], "fen", "move": [desde, hasta] o []}.
## Tonos de flecha: "good" (la jugada), "bad" (lo que ataca o impide), "info" (casillas o ideas).
##
## `me` es el bando de quien aprende (0 blancas, 1 negras): sus piezas son «tu caballo»; las otras, «el caballo
## rival». Con −1 se dice el color («el caballo negro»).

const NOUN := {1: "peón", 2: "caballo", 3: "alfil", 4: "torre", 5: "dama", 6: "rey"}
const PLURAL := {1: "peones", 2: "caballos", 3: "alfiles", 4: "torres", 5: "damas", 6: "reyes"}
const VALUE := {1: 1, 2: 3, 3: 3, 4: 5, 5: 9, 6: 100}
const KNIGHT_D: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
const KING_D: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const DIAG: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]
const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

## Veredictos.
const ONLY := "only"
const BEST := "best"
const DEFENSE := "defense"
const ERROR := "error"
const PLAIN := "plain"
const LABELS := {"only": "Única jugada posible", "best": "La mejor jugada", "defense": "Su mejor defensa", "error": "Es un error", "plain": "La jugada"}


# ---------------------------------------------------------------- palabras

static func _fem(t: int) -> bool:
	return t == Chess.ROOK or t == Chess.QUEEN


static func _art(t: int) -> String:
	return "la" if _fem(t) else "el"


static func _pron(t: int) -> String:
	return "la" if _fem(t) else "lo"


## «tu caballo de f4», «la dama rival de e5», «el rey blanco de f1».
static func name_at(pos: Chess, s: int, me: int, with_square: bool = true) -> String:
	var p: int = pos.b[s]
	if p == 0:
		return Chess.sq_name(s)
	var t := Chess.type_of(p)
	var c := Chess.color_of(p)
	var base := ""
	if me < 0:
		var adj := ("blanca" if c == 0 else "negra") if _fem(t) else ("blanco" if c == 0 else "negro")
		base = "%s %s %s" % [_art(t), NOUN[t], adj]
	elif c == me:
		base = "tu %s" % NOUN[t]
	else:
		base = "%s %s rival" % [_art(t), NOUN[t]]
	return base + (" de " + Chess.sq_name(s) if with_square else "")


static func cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1) if text != "" else text


## «e2», «e2 y g2», «e2, f2 y g2».
static func join(items: Array) -> String:
	var parts: Array = []
	for x in items:
		parts.append(str(x))
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " y " + str(parts[parts.size() - 1])


static func squares(list: Array) -> String:
	var names: Array = []
	for s in list:
		names.append(Chess.sq_name(int(s)))
	return join(names)


# ---------------------------------------------------------------- geometría

## Casillas que ataca la pieza de `s` (sin mirar clavadas): las deslizantes, hasta la primera pieza, incluida.
static func attacks_from(pos: Chess, s: int) -> Array:
	var out: Array = []
	var p: int = pos.b[s]
	if p == 0:
		return out
	var t := Chess.type_of(p)
	var c := Chess.color_of(p)
	var f := s & 7
	var r := s >> 3
	if t == Chess.PAWN:
		var nr := r + (1 if c == 0 else -1)
		if nr >= 0 and nr < 8:
			if f > 0:
				out.append(f - 1 + 8 * nr)
			if f < 7:
				out.append(f + 1 + 8 * nr)
		return out
	if t == Chess.KNIGHT or t == Chess.KING:
		for d in (KNIGHT_D if t == Chess.KNIGHT else KING_D):
			var nf: int = f + d.x
			var nr2: int = r + d.y
			if nf >= 0 and nf < 8 and nr2 >= 0 and nr2 < 8:
				out.append(nf + 8 * nr2)
		return out
	var dirs: Array = []
	if t == Chess.BISHOP or t == Chess.QUEEN:
		dirs.append_array(DIAG)
	if t == Chess.ROOK or t == Chess.QUEEN:
		dirs.append_array(ORTHO)
	for d: Vector2i in dirs:
		var nf: int = f + d.x
		var nr3: int = r + d.y
		while nf >= 0 and nf < 8 and nr3 >= 0 and nr3 < 8:
			var q: int = nf + 8 * nr3
			out.append(q)
			if pos.b[q] != 0:
				break
			nf += d.x
			nr3 += d.y
	return out


## Casillas de las piezas del bando `color` que atacan `target`.
static func attackers(pos: Chess, target: int, color: int) -> Array:
	var out: Array = []
	for s in 64:
		var p: int = pos.b[s]
		if p != 0 and Chess.color_of(p) == color and attacks_from(pos, s).has(target):
			out.append(s)
	return out


## ¿Están `a`, `b` y `c` en la misma fila, columna o diagonal, con `b` entre medias o más allá de `a` desde `c`?
static func _same_line(from: int, through: int, to: int) -> bool:
	var d1 := Vector2i((through & 7) - (from & 7), (through >> 3) - (from >> 3))
	var d2 := Vector2i((to & 7) - (from & 7), (to >> 3) - (from >> 3))
	if d1 == Vector2i.ZERO or d2 == Vector2i.ZERO:
		return false
	var u1 := Vector2i(signi(d1.x), signi(d1.y))
	var u2 := Vector2i(signi(d2.x), signi(d2.y))
	if u1 != u2:
		return false
	# Misma dirección y alineadas (fila, columna o diagonal exacta).
	var aligned1 := d1.x == 0 or d1.y == 0 or absi(d1.x) == absi(d1.y)
	var aligned2 := d2.x == 0 or d2.y == 0 or absi(d2.x) == absi(d2.y)
	return aligned1 and aligned2


## «por la fila 1», «por la columna e», «en diagonal» o nada (caballo, peón).
static func line_word(from: int, to: int) -> String:
	var t := Vector2i((to & 7) - (from & 7), (to >> 3) - (from >> 3))
	if t.y == 0:
		return " por la fila %d" % ((from >> 3) + 1)
	if t.x == 0:
		return " por la columna %s" % "abcdefgh"[from & 7]
	if absi(t.x) == absi(t.y):
		return " en diagonal"
	return ""


static func _line_noun(from: int, to: int) -> String:
	var t := Vector2i((to & 7) - (from & 7), (to >> 3) - (from >> 3))
	if t.y == 0:
		return "la fila %d" % ((from >> 3) + 1)
	if t.x == 0:
		return "la columna %s" % "abcdefgh"[from & 7]
	return "esa diagonal"


static func _between(a: int, b: int) -> Array:
	var out: Array = []
	var d := Vector2i(signi((b & 7) - (a & 7)), signi((b >> 3) - (a >> 3)))
	var f := (a & 7) + d.x
	var r := (a >> 3) + d.y
	while f + 8 * r != b and f >= 0 and f < 8 and r >= 0 and r < 8:
		out.append(f + 8 * r)
		f += d.x
		r += d.y
	return out


static func _arrow(from: int, to: int, tone: String) -> Dictionary:
	return {"from": from, "to": to, "tone": tone}


static func _par(text: String, arrows: Array, pos: Chess, move: Array = []) -> Dictionary:
	return {"text": text, "arrows": arrows, "fen": pos.fen(), "move": move}


static func _san(pos: Chess, m: int) -> String:
	return SanEs.san(pos, m)


# ---------------------------------------------------------------- jaque: por qué solo quedan esas salidas

## Análisis de un jaque en `pos` (le toca al bando en jaque): quién da jaque, qué casillas tiene el rey y quién se
## las quita, si se puede comer o tapar. Devuelve los datos; los párrafos se escriben en escape_paras.
static func check_facts(pos: Chess) -> Dictionary:
	var side := pos.turn
	var k := pos.king_sq(side)
	var checkers := attackers(pos, k, 1 - side)
	var legal := pos.legal_moves()
	var king_ok: Array = []
	var own: Array = []
	var on_line: Array = []
	var covered := {}  # atacante → casillas
	var defended := {}  # casilla con pieza rival defendida → defensores
	var bare := pos.copy()
	bare.b[k] = 0
	for d in KING_D:
		var f: int = (k & 7) + d.x
		var r: int = (k >> 3) + d.y
		if f < 0 or f > 7 or r < 0 or r > 7:
			continue
		var n: int = f + 8 * r
		var occ: int = pos.b[n]
		if occ != 0 and Chess.color_of(occ) == side:
			own.append(n)
			continue
		var ok := false
		for m in legal:
			if Chess.move_from(m) == k and Chess.move_to(m) == n:
				ok = true
		if ok:
			king_ok.append(n)
			continue
		# Por qué no: sigue en la línea de una pieza que da jaque, o la ataca otra pieza.
		var by := attackers(bare, n, 1 - side)
		var lined := false
		for c in checkers:
			var ct := Chess.type_of(pos.b[c])
			if (ct == Chess.ROOK or ct == Chess.BISHOP or ct == Chess.QUEEN) and _same_line(c, k, n) and by.has(c):
				lined = true
		if lined:
			on_line.append(n)
			continue
		if occ != 0:
			defended[n] = by
			continue
		# Mejor nombrar una sola pieza por casilla: la que más casillas quita.
		for a in by:
			if not covered.has(a):
				covered[a] = []
			(covered[a] as Array).append(n)
	# Cada casilla, a un solo atacante (el que más casillas cubre primero).
	var assigned := {}
	var by_attacker := {}
	var order: Array = covered.keys()
	order.sort_custom(func(x: int, y: int) -> bool: return (covered[x] as Array).size() > (covered[y] as Array).size())
	for a: int in order:
		for n: int in covered[a]:
			if assigned.has(n):
				continue
			assigned[n] = a
			if not by_attacker.has(a):
				by_attacker[a] = []
			(by_attacker[a] as Array).append(n)
	var captures: Array = []
	var blocks: Array = []
	if checkers.size() == 1:
		var c: int = checkers[0]
		var between := _between(c, k)
		for m in legal:
			var to := Chess.move_to(m)
			if to == c:
				captures.append(m)
			elif between.has(to) and Chess.move_from(m) != k:
				blocks.append(m)
	return {"king": k, "checkers": checkers, "legal": legal, "king_ok": king_ok, "own": own, "on_line": on_line, "by_attacker": by_attacker, "defended": defended, "captures": captures, "blocks": blocks}


## Párrafos que explican un jaque en `pos`: por qué solo quedan las salidas que quedan. `played` es la jugada que se
## hizo (-1 si se explica un mate). Con `whose` = "su"/"tu" se nombra el rey.
static func escape_paras(pos: Chess, played: int, me: int) -> Array:
	var f := check_facts(pos)
	var out: Array = []
	var k: int = f["king"]
	var checkers: Array = f["checkers"]
	var legal: PackedInt32Array = f["legal"]
	var king := name_at(pos, k, me, false)
	if checkers.is_empty():
		return out
	var c: int = checkers[0]
	if checkers.size() == 1:
		out.append(_par("%s está en jaque: %s lo ataca%s." % [cap(king), name_at(pos, c, me), line_word(c, k)], [_arrow(c, k, "bad")], pos))
	else:
		var names: Array = []
		var arrows: Array = []
		for x: int in checkers:
			names.append(name_at(pos, x, me))
			arrows.append(_arrow(x, k, "bad"))
		out.append(_par("%s está en jaque doble: %s lo atacan a la vez. Contra dos jaques no vale comer ni tapar: solo puede mover el rey." % [cap(king), join(names)], arrows, pos))
	# Las casillas del rey.
	var on_line: Array = f["on_line"]
	on_line.sort()
	var king_ok: Array = f["king_ok"]
	var by_attacker: Dictionary = f["by_attacker"]
	var candidates: Array = king_ok.duplicate()
	for a: int in by_attacker:
		candidates.append_array(by_attacker[a])
	var defended: Dictionary = f["defended"]
	candidates.append_array(defended.keys())
	candidates.sort()
	var ct := Chess.type_of(pos.b[c])
	var slider := ct == Chess.ROOK or ct == Chess.BISHOP or ct == Chess.QUEEN
	var text := ""
	var arrows2: Array = []
	for n: int in candidates:
		arrows2.append(_arrow(k, n, "info"))
	if checkers.size() == 1 and slider and not on_line.is_empty():
		text = "Mover el rey dentro de %s no sirve: %s %s en la línea de %s." % [_line_noun(c, k), squares(on_line), "sigue" if on_line.size() == 1 else "siguen", name_at(pos, c, me, false)]
		if candidates.is_empty():
			text += " Y fuera de ella no tiene ninguna casilla libre."
		else:
			text += " Fuera de ella, %s %s." % ["tiene una casilla:" if candidates.size() == 1 else "tiene %s casillas:" % _count_word(candidates.size()), squares(candidates)]
		for n: int in on_line:
			arrows2.append(_arrow(k, n, "bad"))
	elif candidates.is_empty():
		text = "El rey no tiene ninguna casilla libre a su alrededor."
	else:
		text = "Para escapar, el rey podría ir a %s." % squares(candidates)
	var own: Array = f["own"]
	own.sort()
	if not own.is_empty() and own.size() <= 3:
		text += " En %s %s sus propias piezas." % [squares(own), "está una de" if own.size() == 1 else "están"]
	out.append(_par(text, arrows2, pos))
	# Quién quita cada casilla.
	if not by_attacker.is_empty() or not defended.is_empty():
		var phrases: Array = []
		var arrows3: Array = []
		for a: int in by_attacker:
			var list: Array = by_attacker[a]
			list.sort()
			phrases.append("%s controla %s" % [name_at(pos, a, me), squares(list)])
			for n: int in list:
				arrows3.append(_arrow(a, n, "bad"))
		for n: int in defended:
			var defs: Array = defended[n]
			if defs.is_empty():
				continue
			phrases.append("%s no se puede comer porque %s %s defiende" % [name_at(pos, n, me), name_at(pos, int(defs[0]), me), _pron(Chess.type_of(pos.b[n]))])
			arrows3.append(_arrow(int(defs[0]), n, "bad"))
		var lead := "Pero " if not king_ok.is_empty() or candidates.size() > 0 else ""
		var t3 := lead + join(phrases) + "."
		if king_ok.size() == 1 and candidates.size() > 1:
			t3 += " Solo le queda %s." % Chess.sq_name(int(king_ok[0]))
		elif king_ok.is_empty() and candidates.size() > 0:
			t3 += " El rey no puede moverse."
		out.append(_par(cap(t3), arrows3, pos))
	# Comer o tapar.
	if checkers.size() == 1:
		var captures: Array = f["captures"]
		var blocks: Array = f["blocks"]
		var can_block := slider and not _between(c, k).is_empty()
		var arrows4: Array = []
		var t4 := ""
		if captures.is_empty() and (blocks.is_empty() or not can_block):
			t4 = "Nada puede comer %s" % name_at(pos, c, me)
			t4 += " ni ponerse en medio." if can_block else "."
			if ct == Chess.KNIGHT:
				t4 += " Y al jaque de un caballo no se le puede poner nada delante."
		else:
			var parts: Array = []
			if not captures.is_empty():
				var sans: Array = []
				for m: int in captures:
					sans.append(_san(pos, m))
					arrows4.append(_arrow(Chess.move_from(m), Chess.move_to(m), "info"))
				parts.append("puede comer %s (%s)" % [name_at(pos, c, me), join(sans)])
			if not blocks.is_empty() and can_block:
				var sans2: Array = []
				for m: int in blocks:
					sans2.append(_san(pos, m))
					arrows4.append(_arrow(Chess.move_from(m), Chess.move_to(m), "info"))
				parts.append("puede taparse (%s)" % join(sans2))
			t4 = "También " + join(parts) + "."
		out.append(_par(cap(t4), arrows4, pos))
	# Conclusión.
	if played < 0:
		if legal.is_empty():
			out.append(_par("No le queda ninguna jugada: es jaque mate.", [], pos))
		return out
	var san := _san(pos, played)
	var mv := [Chess.move_from(played), Chess.move_to(played)]
	if legal.size() == 1:
		out.append(_par("Así que %s era la única jugada posible." % san, [_arrow(mv[0], mv[1], "good")], pos, mv))
	else:
		var sans3: Array = []
		for m in legal:
			sans3.append(_san(pos, m))
		out.append(_par("Tenía %s salidas: %s. Eligió %s." % [_count_word(legal.size()), join(sans3), san], [_arrow(mv[0], mv[1], "good")], pos, mv))
	return out


static func _count_word(n: int) -> String:
	var words := ["cero", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho"]
	return words[n] if n < words.size() else str(n)


## Frase corta de por qué la respuesta a un jaque es forzada: «e2 y g2 las controla tu caballo de f4».
static func forced_reason(pos: Chess, me: int) -> String:
	var f := check_facts(pos)
	var by_attacker: Dictionary = f["by_attacker"]
	var parts: Array = []
	for a: int in by_attacker:
		var list: Array = by_attacker[a]
		list.sort()
		parts.append("%s %s %s" % [squares(list), "la controla" if list.size() == 1 else "las controla", name_at(pos, a, me)])
	if parts.is_empty():
		return ""
	return join(parts)


# ---------------------------------------------------------------- qué consigue una jugada

## Hechos de una jugada: captura, jaque, ataque doble, amenazas, qué le queda al rival. Párrafos en la posición de
## antes (la jugada en verde) y, si conviene, en la de después.
static func move_paras(before: Chess, m: int, me: int) -> Array:
	var out: Array = []
	var from := Chess.move_from(m)
	var to := Chess.move_to(m)
	var side := before.turn
	var opp := 1 - side
	var after := before.after(m)
	var mover_t := Chess.type_of(before.b[from])
	var new_t := Chess.type_of(after.b[to])
	var mv := [from, to]
	var san := _san(before, m)
	var flag := Chess.move_flag(m)
	# 1. Qué hace.
	var does: Array = []
	var taken_sq := to
	if flag == Chess.F_EN_PASSANT:
		taken_sq = to + (-8 if side == 0 else 8)
	var taken: int = before.b[taken_sq]
	if flag == Chess.F_CASTLE_K or flag == Chess.F_CASTLE_Q:
		does.append("%s enroca: el rey se pone a salvo y la torre entra en juego" % san)
	elif taken != 0:
		var tt := Chess.type_of(taken)
		var desc := name_at(before, taken_sq, me)
		var defended := after.attacked(to, opp)
		if not defended:
			does.append("%s come %s (no tenía defensa)" % [san, desc])
		elif int(VALUE[tt]) > int(VALUE[mover_t]):
			does.append("%s come %s, que vale más que %s: aunque %s recuperen, sale ganando" % [san, desc, _art(mover_t) + " " + str(NOUN[mover_t]), "se " + _pron(mover_t)])
		else:
			does.append("%s come %s" % [san, desc])
	else:
		does.append("%s lleva %s a %s" % [san, name_at(before, from, me, false), Chess.sq_name(to)])
	if Chess.move_promo(m) > 0:
		does.append("el peón corona: ahora es %s %s" % ["una" if _fem(new_t) else "un", NOUN[new_t]])
	var checkers: Array = []
	if after.in_check():
		checkers = attackers(after, after.king_sq(opp), side)
		var direct := checkers.has(to)
		if direct and checkers.size() == 1:
			does.append("da jaque al rey%s" % line_word(to, after.king_sq(opp)))
		elif direct:
			does.append("da jaque doble")
		else:
			does.append("al apartarse, %s da jaque al rey (jaque descubierto)" % name_at(after, int(checkers[0]), me))
	var arrows1: Array = [_arrow(from, to, "good")]
	out.append(_par(join(does) + ".", arrows1, before, mv))
	# 2. Mate.
	if after.is_checkmate():
		var mate := escape_paras(after, -1, me)
		if mate.size() > 1:
			for i in range(1, mate.size()):
				out.append(mate[i])
		else:
			out.append(_par("Es jaque mate.", [], after, mv))
		return out
	# 3. Ataque doble o amenaza con la pieza que llega.
	var targets: Array = []
	for s: int in attacks_from(after, to):
		var p: int = after.b[s]
		if p == 0 or Chess.color_of(p) != opp or Chess.type_of(p) == Chess.KING:
			continue
		var t := Chess.type_of(p)
		if int(VALUE[t]) > int(VALUE[new_t]) or not after.attacked(s, opp):
			targets.append(s)
	targets.sort_custom(func(x: int, y: int) -> bool: return int(VALUE[Chess.type_of(after.b[x])]) > int(VALUE[Chess.type_of(after.b[y])]))
	var replies := after.legal_moves()
	if not checkers.is_empty() and checkers.has(to) and not targets.is_empty():
		var tgt: int = targets[0]
		var arrows: Array = [_arrow(to, after.king_sq(opp), "bad"), _arrow(to, tgt, "bad")]
		var text := "Es un ataque doble: %s da jaque y, a la vez, ataca %s." % [name_at(after, to, me, false), name_at(after, tgt, me)]
		if _wins_after_all(after, to, tgt, replies):
			text += " El rival tiene que sacar el rey del jaque y después %s se come %s." % [name_at(after, to, me, false), _art(Chess.type_of(after.b[tgt])) + " " + str(NOUN[Chess.type_of(after.b[tgt])])]
		out.append(_par(text, arrows, after, mv))
	elif checkers.is_empty() and targets.size() >= 2:
		var arrows5: Array = []
		var names: Array = []
		for s: int in targets.slice(0, 2):
			arrows5.append(_arrow(to, s, "bad"))
			names.append(name_at(after, s, me))
		var text2 := "Es un ataque doble: %s ataca a la vez %s." % [name_at(after, to, me, false), join(names)]
		if _one_falls(after, to, targets.slice(0, 2), replies):
			text2 += " El rival no puede salvar las dos."
		out.append(_par(text2, arrows5, after, mv))
	elif checkers.is_empty() and targets.size() == 1:
		var tgt2: int = targets[0]
		out.append(_par("Ahora %s amenaza comer %s." % [name_at(after, to, me, false), name_at(after, tgt2, me)], [_arrow(to, tgt2, "bad")], after, mv))
	# 4. Ataque descubierto (sin jaque): una pieza propia que ahora ve una pieza rival valiosa.
	if checkers.is_empty() and mover_t != Chess.KING:
		for s in 64:
			var p: int = after.b[s]
			if p == 0 or Chess.color_of(p) != side or s == to:
				continue
			var t2 := Chess.type_of(p)
			if t2 != Chess.ROOK and t2 != Chess.BISHOP and t2 != Chess.QUEEN:
				continue
			var now := attacks_from(after, s)
			var was := attacks_from(before, s)
			for q: int in now:
				var pq: int = after.b[q]
				if was.has(q) or pq == 0 or Chess.color_of(pq) != opp:
					continue
				var tq := Chess.type_of(pq)
				if tq != Chess.KING and (int(VALUE[tq]) > int(VALUE[t2]) or not after.attacked(q, opp)):
					out.append(_par("Al moverse, deja a %s atacando %s: un ataque descubierto." % [name_at(after, s, me), name_at(after, q, me)], [_arrow(s, q, "bad")], after, mv))
					break
	# 5. Qué le queda al rival.
	if replies.size() == 1:
		var only := replies[0]
		var reason := forced_reason(after, me) if after.in_check() else ""
		var t5 := "Al rival solo le queda una jugada: %s" % _san(after, only)
		t5 += (" (%s)." % reason) if reason != "" else "."
		out.append(_par(t5, [_arrow(Chess.move_from(only), Chess.move_to(only), "info")], after, mv))
	elif checkers.is_empty():
		var threat := mate_threat(after)
		if threat >= 0:
			var probe := after.copy()
			probe.turn = side
			probe.ep = -1
			out.append(_par("Y amenaza jaque mate con %s." % _san(probe, threat), [_arrow(Chess.move_from(threat), Chess.move_to(threat), "bad")], after, mv))
	return out


## ¿Tras cualquier respuesta, la pieza de `at` puede comer la de `target`?
static func _wins_after_all(pos: Chess, at: int, target: int, replies: PackedInt32Array) -> bool:
	if replies.is_empty():
		return false
	var piece: int = pos.b[target]
	for r in replies:
		var nxt := pos.after(r)
		if nxt.b[target] != piece or nxt.b[at] != pos.b[at]:
			return false
		var ok := false
		for m in nxt.legal_moves():
			if Chess.move_from(m) == at and Chess.move_to(m) == target:
				ok = true
				break
		if not ok:
			return false
	return true


## ¿Tras cualquier respuesta, la pieza de `at` puede comer alguna de `targets`?
static func _one_falls(pos: Chess, at: int, targets: Array, replies: PackedInt32Array) -> bool:
	if replies.is_empty():
		return false
	for r in replies:
		var nxt := pos.after(r)
		if nxt.b[at] != pos.b[at]:
			return false
		var ok := false
		for m in nxt.legal_moves():
			if Chess.move_from(m) == at and targets.has(Chess.move_to(m)) and nxt.b[Chess.move_to(m)] == pos.b[Chess.move_to(m)]:
				ok = true
				break
		if not ok:
			return false
	return true


## Si el bando que acaba de mover volviera a jugar, ¿daría mate? Devuelve esa jugada (en la posición con el turno
## cambiado) o −1.
static func mate_threat(after: Chess) -> int:
	if after.in_check():
		return -1
	var probe := after.copy()
	probe.turn = 1 - after.turn
	probe.ep = -1
	if probe.in_check():
		return -1
	for m in probe.legal_moves():
		if probe.after(m).is_checkmate():
			return m
	return -1


## Etiqueta corta de lo que consigue una jugada, para resumir una combinación: «jaque mate», «ataque doble al rey y
## la dama», «come la dama», «jaque».
static func short_tag(before: Chess, m: int) -> String:
	var after := before.after(m)
	var opp := 1 - before.turn
	var to := Chess.move_to(m)
	if after.is_checkmate():
		return "jaque mate"
	var new_t := Chess.type_of(after.b[to])
	var check := after.in_check()
	var best := -1
	for s: int in attacks_from(after, to):
		var p: int = after.b[s]
		if p == 0 or Chess.color_of(p) != opp or Chess.type_of(p) == Chess.KING:
			continue
		var t := Chess.type_of(p)
		if (int(VALUE[t]) > int(VALUE[new_t]) or not after.attacked(s, opp)) and (best < 0 or int(VALUE[t]) > int(VALUE[Chess.type_of(after.b[best])])):
			best = s
	if check and best >= 0 and attackers(after, after.king_sq(opp), before.turn).has(to):
		return "ataque doble al rey y %s" % (_art(Chess.type_of(after.b[best])) + " " + str(NOUN[Chess.type_of(after.b[best])]))
	var taken: int = before.b[to]
	if taken != 0 and Chess.type_of(taken) >= Chess.KNIGHT:
		return "come %s" % (_art(Chess.type_of(taken)) + " " + str(NOUN[Chess.type_of(taken)]))
	if check:
		return "jaque"
	if best >= 0:
		return "ataca %s" % (_art(Chess.type_of(after.b[best])) + " " + str(NOUN[Chess.type_of(after.b[best])]))
	return ""


# ---------------------------------------------------------------- explicaciones completas

## Explicación de una jugada con su veredicto. `role`: "solution" (jugada de la solución, de quien aprende),
## "reply" (respuesta del rival dentro de la solución), "blunder" (la jugada del rival que abre el problema) o
## "free" (sin contexto). `rest`: las jugadas (UCI) que siguen en la solución, para resumir la combinación.
static func explain(before: Chess, m: int, me: int, role: String, rest: Array = []) -> Dictionary:
	var legal := before.legal_moves()
	var verdict := PLAIN
	var paras: Array = []
	if legal.size() == 1:
		verdict = ONLY
		if before.in_check():
			paras = escape_paras(before, m, me)
		else:
			var san := _san(before, m)
			paras = [_par("No tenía otra jugada legal: %s era la única pieza que podía moverse." % san, [_arrow(Chess.move_from(m), Chess.move_to(m), "good")], before, [Chess.move_from(m), Chess.move_to(m)])]
	elif role == "solution":
		verdict = BEST
		paras = move_paras(before, m, me)
		var plan := _plan(before.after(m), rest, me)
		if plan != "":
			paras.append(_par(plan, [], before.after(m), [Chess.move_from(m), Chess.move_to(m)]))
	elif role == "blunder":
		verdict = ERROR
		paras = move_paras(before, m, me)
		var after := before.after(m)
		var story := _story(after, rest, me)
		if story != "":
			paras.append(_par("Pero es un error: permite %s." % story, [], after, [Chess.move_from(m), Chess.move_to(m)]))
	elif role == "reply":
		verdict = DEFENSE
		if before.in_check():
			paras = escape_paras(before, m, me)
		else:
			paras = move_paras(before, m, me)
		paras.append(_par("De todas sus jugadas, es la que más resiste.", [], before.after(m), [Chess.move_from(m), Chess.move_to(m)]))
	else:
		if before.in_check():
			paras = escape_paras(before, m, me)
		else:
			paras = move_paras(before, m, me)
	return {"verdict": verdict, "label": LABELS[verdict], "san": _san(before, m), "paras": paras}


## Resumen de la combinación que sigue: «Tb1+ y, tras Rf2 (su única jugada), Cd3+: ataque doble al rey y la dama».
static func _story(pos: Chess, ucis: Array, me: int) -> String:
	if ucis.is_empty():
		return ""
	var p := pos.copy()
	var parts: Array = []
	for i in ucis.size():
		var m := p.find_uci(str(ucis[i]))
		if m < 0:
			break
		var san := _san(p, m)
		var mine := p.turn == me or me < 0 and i % 2 == 0
		if mine:
			var tag := short_tag(p, m)
			parts.append(san + (" (%s)" % tag if tag != "" else ""))
		else:
			parts.append("y, tras %s%s," % [san, " (su única jugada)" if p.legal_moves().size() == 1 else ""])
		p.apply(m)
	return " ".join(parts).trim_suffix(",")


## Lo que viene después de una jugada de la solución: «Ahora al rival solo le queda Rf2, y entonces Cd3+ será un
## ataque doble al rey y la dama».
static func _plan(after: Chess, rest: Array, me: int) -> String:
	if rest.size() < 2:
		return ""
	var r := after.find_uci(str(rest[0]))
	if r < 0:
		return ""
	var next_pos := after.after(r)
	var n := next_pos.find_uci(str(rest[1]))
	if n < 0:
		return ""
	var tag := short_tag(next_pos, n)
	var text := "La idea: tras %s, llega %s" % [_san(after, r), _san(next_pos, n)]
	text += (": %s." % tag) if tag != "" else "."
	return text


## Por qué el rey del bando que mueve no tiene salida (jaque mate) o no tiene jugadas (ahogado), paso a paso y
## con animación: en cada paso, `tries` son las casillas a las que el rey «intenta» ir (y no puede). `kids`: frases
## muy cortas, sin coordenadas. Devuelve [] si la posición no es mate ni ahogado.
static func king_box(pos: Chess, me: int, kids: bool) -> Array:
	if not pos.legal_moves().is_empty():
		return []
	var out: Array = []
	var f := check_facts(pos)
	var k: int = f["king"]
	var checkers: Array = f["checkers"]
	var mate := not checkers.is_empty()
	var ws := not kids
	var king := _who(kids, pos, k, me, false)
	# 1. ¿Está en jaque?
	if mate:
		var c: int = checkers[0]
		var arrows: Array = []
		for x: int in checkers:
			arrows.append(_arrow(x, k, "bad"))
		if kids:
			out.append(_par(("¡Jaque! %s ataca a %s." % [cap(_who(kids, pos, c, me, false)), king]).replace(" a el ", " al "), arrows, pos))
		else:
			out.append(_par("%s está en jaque: %s lo ataca%s." % [cap(king), _who(kids, pos, c, me), line_word(c, k)], arrows, pos))
	else:
		if kids:
			out.append(_par("Mira: %s no está en jaque. Nadie le ataca." % king, [], pos))
		else:
			out.append(_par("%s no está en jaque: ninguna pieza lo ataca ahora mismo." % cap(king), [], pos))
	# 2. Cada casilla de alrededor: por qué no puede ir.
	var by_attacker: Dictionary = f["by_attacker"]
	for a: int in by_attacker:
		var squares: Array = by_attacker[a]
		var arrows2: Array = []
		var tries: Array = []
		for n: int in squares:
			arrows2.append(_arrow(a, n, "bad"))
			tries.append([k, n])
		var p: Dictionary
		if kids:
			p = _par("Si el rey se escapa por %s, %s le atacaría." % ["aquí" if squares.size() == 1 else "estas casillas", _who(kids, pos, a, me, false)], arrows2, pos)
		else:
			var names: Array = []
			for n: int in squares:
				names.append(Chess.sq_name(n))
			p = _par("Las casillas %s las controla %s." % [join(names), _who(kids, pos, a, me)] if squares.size() > 1 else "La casilla %s la controla %s." % [join(names), _who(kids, pos, a, me)], arrows2, pos)
		p["tries"] = tries
		out.append(p)
	var on_line: Array = f["on_line"]
	if not on_line.is_empty() and mate:
		var c2: int = checkers[0]
		var arrows3: Array = []
		var tries3: Array = []
		var names3: Array = []
		for n: int in on_line:
			arrows3.append(_arrow(c2, n, "bad"))
			tries3.append([k, n])
			names3.append(Chess.sq_name(n))
		var p3 := _par("Si se aparta por la misma línea, %s le sigue atacando." % _who(kids, pos, c2, me, false) if kids else "En %s seguiría en la línea de %s." % [join(names3), _who(kids, pos, c2, me)], arrows3, pos)
		p3["tries"] = tries3
		out.append(p3)
	var own: Array = f["own"]
	if not own.is_empty():
		var tries4: Array = []
		var names4: Array = []
		for n: int in own:
			tries4.append([k, n])
			names4.append(Chess.sq_name(n))
		var who := _who(kids, pos, own[0], me, false)
		var kid_own := ("Y por ahí no puede pasar: está %s, de su mismo color." % who) if own.size() == 1 else "Y por ahí no puede pasar: están sus propias piezas."
		var p4 := _par(kid_own if kids else ("Las casillas %s están ocupadas por sus propias piezas." % join(names4) if own.size() > 1 else "La casilla %s la ocupa %s." % [join(names4), _who(kids, pos, own[0], me, false)]), [], pos)
		p4["tries"] = tries4
		out.append(p4)
	var defended: Dictionary = f["defended"]
	for n: int in defended:
		var defs: Array = defended[n]
		var arrows5: Array = []
		for d: int in defs:
			arrows5.append(_arrow(d, n, "bad"))
		var p5 := _par(("No se puede comer %s: %s lo protege." % [_who(kids, pos, n, me, false), _who(kids, pos, defs[0], me, false)]) if kids else ("No puede comer %s: lo defiende %s." % [_who(kids, pos, n, me), _who(kids, pos, defs[0], me)]), arrows5, pos)
		p5["tries"] = [[k, n]]
		out.append(p5)
	# 3. Comer la pieza que da jaque o tapar (en el mate), u otras piezas que muevan (en el ahogado).
	if mate and checkers.size() == 1:
		var c3: int = checkers[0]
		var between := _between(c3, k)
		var t3 := Chess.type_of(pos.b[c3])
		var gap := not between.is_empty() and (t3 == Chess.ROOK or t3 == Chess.BISHOP or t3 == Chess.QUEEN)
		if kids:
			out.append(_par("Y nadie puede comerse %s%s." % [_who(kids, pos, c3, me, false), " ni ponerse en medio" if gap else ""], [_arrow(c3, k, "bad")], pos))
		else:
			out.append(_par("Ninguna pieza puede comer %s%s." % [_who(kids, pos, c3, me), " ni interponerse" if gap else ""], [_arrow(c3, k, "bad")], pos))
	elif not mate:
		var others := 0
		for s in 64:
			var q: int = pos.b[s]
			if q != 0 and Chess.color_of(q) == pos.turn and Chess.type_of(q) != Chess.KING:
				others += 1
		if others > 0:
			out.append(_par("Sus otras piezas tampoco se pueden mover." if kids else "Y ninguna otra pieza suya tiene jugada.", [], pos))
	# 4. Conclusión.
	if mate:
		out.append(_par("No tiene salida: ¡jaque mate!" if kids else "No hay forma de salir del jaque: jaque mate.", [], pos))
	else:
		out.append(_par("No está en jaque, pero no puede mover nada: es ahogado. ¡Y el ahogado es empate!" if kids else "Sin jaque y sin ninguna jugada legal: ahogado. La partida acaba en tablas.", [], pos))
	return out


## Nombre de una pieza: para niños, «tu torre» o «el rey negro» (sin casilla); si no, como name_at.
static func _who(kids: bool, pos: Chess, s: int, me: int, with_square: bool = true) -> String:
	if not kids:
		return name_at(pos, s, me, with_square)
	var p: int = pos.b[s]
	if p == 0:
		return Chess.sq_name(s)
	var t := Chess.type_of(p)
	var c := Chess.color_of(p)
	if c == me:
		return "tu %s" % NOUN[t]
	var adj := ("blanca" if c == 0 else "negra") if _fem(t) else ("blanco" if c == 0 else "negro")
	return "%s %s %s" % [_art(t), NOUN[t], adj]
