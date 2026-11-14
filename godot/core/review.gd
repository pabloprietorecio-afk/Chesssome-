class_name GameReview
extends RefCounted
## Análisis educativo de una partida: busca los momentos en los que el jugador podía aprender algo.
##
## Solo dice lo que se puede comprobar con las reglas, sin opiniones del rival (core/bot.gd no es un motor fuerte
## y sus números no se convierten en frases):
##   allowed_mate    tras tu jugada, el rival tenía mate en una (y había otra jugada que lo evitaba)
##   missed_mate     tenías mate en una y no lo diste
##   hang            tras tu jugada, el rival podía ganar material capturando (cuenta del cambio de piezas en esa
##                   casilla, «SEE»), y otra jugada no perdía nada (vista de una jugada y media: no ve más lejos)
##   missed_capture  podías ganar material capturando una pieza mal defendida y no lo hiciste
##   repeat          en la apertura, moviste la misma pieza por tercera vez con dos o más piezas menores sin sacar
##   king            moviste el rey (sin enrocar y sin estar en jaque) cuando aún podías enrocar
## Cada momento: {ply, kind, fen (antes de tu jugada), played (uci), better (uci o ""), square, text, lesson,
## themes}. Los textos de adultos nombran piezas y casillas; los del nivel Kids son frases fijas (llevan voz).

const VALUE := [0, 100, 310, 330, 500, 900, 0]
const NAME := ["", "peón", "caballo", "alfil", "torre", "dama", "rey"]
## Pronombre de cada pieza («lo» o «la»), para las frases.
const IT := ["", "lo", "lo", "lo", "la", "la", "lo"]
## Material mínimo que cuenta como pérdida o ganancia (centipeones): un peón suelto no es un «momento».
const MIN_GAIN := 200
const MAX_MOMENTS := 6
const PRIORITY := {"allowed_mate": 0, "missed_mate": 1, "hang": 2, "missed_capture": 3, "king": 4, "repeat": 5}
## Lección del curso y temas de problemas con los que practicar cada clase de momento.
const LESSON := {"allowed_mate": "mate", "missed_mate": "mate", "hang": "a-salvo", "missed_capture": "capturar", "king": "enroque", "repeat": ""}
const THEMES := {"allowed_mate": ["Mate en 1", "Mate del pasillo", "Jugada defensiva"], "missed_mate": ["Mate en 1", "Mate del pasillo"], "hang": ["Pieza colgada"], "missed_capture": ["Pieza colgada"], "king": [], "repeat": []}


## fens: posición inicial y la de después de cada jugada; moves: las jugadas en UCI (una menos que fens).
static func analyze(fens: Array, moves: Array, player: int, variant: String = "") -> Array:
	var out: Array = []
	if variant != "":
		return out
	var moved_count := {}
	var my_moves := 0
	for i in moves.size():
		var before := Chess.from_fen(str(fens[i]))
		if before.turn != player:
			continue
		my_moves += 1
		var m := before.find_uci(str(moves[i]))
		if m < 0:
			continue
		var after := before.after(m)
		var found := _tactics(before, m, after, i)
		if found.is_empty() and my_moves <= 12:
			found = _opening(before, m, i, moved_count, my_moves)
		# Seguimiento de piezas para «la misma pieza tres veces»: la pieza va con su casilla.
		var from := Chess.move_from(m)
		var to := Chess.move_to(m)
		var times := int(moved_count.get(from, 0)) + 1
		moved_count.erase(from)
		moved_count[to] = times
		if not found.is_empty():
			found["ply"] = i
			found["fen"] = str(fens[i])
			found["played"] = str(moves[i])
			found["lesson"] = LESSON[found["kind"]]
			found["themes"] = THEMES[found["kind"]]
			out.append(found)
	# Los más importantes primero (y, entre iguales, en el orden de la partida); después, en orden de partida.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return [int(PRIORITY[a["kind"]]), int(a["ply"])] < [int(PRIORITY[b["kind"]]), int(b["ply"])])
	out = out.slice(0, MAX_MOMENTS)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["ply"]) < int(b["ply"]))
	return out


static func _tactics(before: Chess, m: int, after: Chess, ply: int) -> Dictionary:
	var me := before.turn
	var san := SanEs.san(before, m)
	var n := ply / 2 + 1
	var at := "%d.%s %s" % [n, "" if me == 0 else "..", san]
	if after.is_checkmate():
		return {}
	# Mate en una que no se dio.
	var mate := mate_in_one(before)
	if mate >= 0:
		return {"kind": "missed_mate", "better": Chess.uci(mate), "square": Chess.move_to(mate),
			"text": "Con %s tenías jaque mate: %s. Antes de cada jugada, mira si tienes un jaque que el rival no pueda parar." % [at, SanEs.san(before, mate)]}
	# Mate en una que se permite.
	var their_mate := mate_in_one(after)
	if their_mate >= 0:
		var safe := _safe_from_mate(before)
		if safe >= 0:
			return {"kind": "allowed_mate", "better": Chess.uci(safe), "square": Chess.move_to(their_mate),
				"text": "Tras %s, el rival podía darte jaque mate con %s. Por ejemplo, %s lo evitaba. Antes de mover, pregúntate qué amenaza el rival." % [at, SanEs.san(after, their_mate), SanEs.san(before, safe)]}
	# Material: lo que gana la jugada contando la mejor captura que deja al rival (una jugada y media de vista).
	var played_net := net(before, m)
	if played_net <= -MIN_GAIN:
		var alt := _best_net_move(before, false)
		if alt >= 0 and net(before, alt) >= played_net + MIN_GAIN:
			var loss := best_capture(after)
			var sq := int(loss["square"])
			var piece := Chess.type_of(after.b[sq]) if sq >= 0 else Chess.PAWN
			var text := ""
			if sq == Chess.move_to(m):
				text = "Con %s, tu %s quedó en %s, donde el rival %s podía capturar sin perder lo mismo a cambio." % [at, NAME[piece], Chess.sq_name(sq), IT[piece]]
			else:
				text = "Tras %s, tu %s de %s quedó a tiro: el rival podía capturar%s y ganar material." % [at, NAME[piece], Chess.sq_name(sq), IT[piece]]
			text += " Con %s no perdías nada. Antes de mover, mira qué piezas tuyas quedan atacadas." % SanEs.san(before, alt)
			return {"kind": "hang", "better": Chess.uci(alt), "square": sq, "text": text}
	# Si la jugada daba jaque, puede que buscara algo más (no se sabe con esta vista tan corta): no se dice nada.
	var cm := -1 if after.in_check() else _best_net_move(before, true)
	if cm >= 0 and cm != m:
		var gain := net(before, cm)
		if gain >= MIN_GAIN and gain >= played_net + MIN_GAIN:
			var sq := Chess.move_to(cm)
			return {"kind": "missed_capture", "better": Chess.uci(cm), "square": sq,
				"text": "En la jugada %d, %s capturaba el %s de %s y ganaba material: no estaba bien defendido. Jugaste %s. Antes de mover, mira qué piezas del rival puedes capturar." % [n, SanEs.san(before, cm), NAME[Chess.type_of(before.b[sq])], Chess.sq_name(sq), san]}
	return {}


static func _opening(before: Chess, m: int, ply: int, moved_count: Dictionary, my_moves: int) -> Dictionary:
	var me := before.turn
	var from := Chess.move_from(m)
	var t := Chess.type_of(before.b[from])
	var n := ply / 2 + 1
	var san := SanEs.san(before, m)
	# El rey que se mueve sin enrocar (y sin estar en jaque) pierde el enroque.
	var rights := before.castle & (3 if me == 0 else 12)
	var flag := Chess.move_flag(m)
	if t == Chess.KING and rights != 0 and flag != Chess.F_CASTLE_K and flag != Chess.F_CASTLE_Q and not before.in_check():
		return {"kind": "king", "better": "", "square": from,
			"text": "En la jugada %d moviste el rey (%s) sin enrocar: ya no podrás enrocar. El enroque esconde al rey y saca la torre a la vez." % [n, san]}
	# La misma pieza por tercera vez con piezas menores sin sacar.
	if int(moved_count.get(from, 0)) >= 2 and t != Chess.PAWN and t != Chess.KING and Chess.move_flag(m) == Chess.F_NORMAL and before.b[Chess.move_to(m)] == 0:
		var home := [1, 6, 2, 5] if me == 0 else [57, 62, 58, 61]
		var undeveloped := 0
		for s: int in home:
			var p := before.b[s]
			if p != 0 and Chess.color_of(p) == me and (Chess.type_of(p) == Chess.KNIGHT or Chess.type_of(p) == Chess.BISHOP):
				undeveloped += 1
		if undeveloped >= 2:
			return {"kind": "repeat", "better": "", "square": from,
				"text": "En la jugada %d moviste tu %s por tercera vez (%s) mientras %d de tus caballos y alfiles seguían sin salir. En la apertura conviene sacar primero todas las piezas: cada jugada con la misma pieza es una que no usas para desarrollar otra." % [n, NAME[t], san, undeveloped]}
	return {}


## Jugada que da mate en una (−1 si no hay).
static func mate_in_one(pos: Chess) -> int:
	for m in pos.legal_moves():
		var c := pos.after(m)
		if c.in_check() and c.legal_moves().is_empty():
			return m
	return -1


static func _safe_from_mate(pos: Chess) -> int:
	for m in pos.legal_moves():
		if mate_in_one(pos.after(m)) < 0:
			return m
	return -1


static func _captured_value(pos: Chess, m: int) -> int:
	if Chess.move_flag(m) == Chess.F_EN_PASSANT:
		return VALUE[Chess.PAWN]
	var v: int = VALUE[Chess.type_of(pos.b[Chess.move_to(m)])] if pos.b[Chess.move_to(m)] != 0 else 0
	if Chess.move_promo(m) != 0:
		v += VALUE[Chess.move_promo(m)] - VALUE[Chess.PAWN]
	return v


## La mejor captura del bando que mueve, contando el cambio de piezas en esa casilla: {gain, move, square}.
static func best_capture(pos: Chess) -> Dictionary:
	var best := {"gain": 0, "move": -1, "square": -1}
	for m in pos.legal_moves():
		if pos.b[Chess.move_to(m)] == 0 or Chess.type_of(pos.b[Chess.move_to(m)]) == Chess.KING:
			continue
		var g := _captured_value(pos, m) - see(pos.after(m), Chess.move_to(m))
		if g > int(best["gain"]):
			best = {"gain": g, "move": m, "square": Chess.move_to(m)}
	return best


## Cambio de piezas en una casilla («static exchange evaluation»): lo que gana el bando que mueve capturando ahí
## siempre con su pieza más barata, pudiendo parar cuando quiera (0 si no le conviene empezar).
static func see(pos: Chess, sq: int) -> int:
	if pos.b[sq] == 0:
		return 0
	var cheapest := -1
	var cheapest_value := 100000
	for m in pos.legal_moves():
		if Chess.move_to(m) != sq:
			continue
		if Chess.move_promo(m) != 0 and Chess.move_promo(m) != Chess.QUEEN:
			continue
		var v: int = VALUE[Chess.type_of(pos.b[Chess.move_from(m)])]
		if Chess.type_of(pos.b[Chess.move_from(m)]) == Chess.KING:
			v = 10000
		if v < cheapest_value:
			cheapest_value = v
			cheapest = m
	if cheapest < 0:
		return 0
	return maxi(0, _captured_value(pos, cheapest) - see(pos.after(cheapest), sq))


## Lo que gana (o pierde, si es negativo) la jugada m: lo que captura menos la mejor captura que le deja al rival.
## Una jugada que permite mate en una cuenta como pérdida enorme.
static func net(pos: Chess, m: int) -> int:
	var after := pos.after(m)
	if mate_in_one(after) >= 0:
		return -100000
	return _captured_value(pos, m) - int(best_capture(after)["gain"])


## La jugada con más ganancia neta (solo capturas si only_captures): −1 si no hay jugadas.
static func _best_net_move(pos: Chess, only_captures: bool) -> int:
	var best := -1
	var best_net := -1000000
	for m in pos.legal_moves():
		if only_captures and pos.b[Chess.move_to(m)] == 0:
			continue
		var v := net(pos, m)
		if v > best_net:
			best_net = v
			best = m
	return best


## Título corto de cada clase de momento.
static func title_of(kind: String) -> String:
	return {"allowed_mate": "Mate del rival", "missed_mate": "Un mate que se escapó", "hang": "Pieza a tiro", "missed_capture": "Una captura gratis", "king": "El rey sin enrocar", "repeat": "La misma pieza otra vez"}.get(kind, "")


## Frase fija del nivel Kids para cada clase de momento (clave de kidsLines en curso.json).
static func kids_key(kind: String) -> String:
	return {"allowed_mate": "reviewAllowedMate", "missed_mate": "reviewMissedMate", "hang": "reviewHang", "missed_capture": "reviewMissedCapture", "king": "reviewKing", "repeat": "reviewRepeat"}.get(kind, "")
