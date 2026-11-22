class_name GameDetail
extends RefCounted
## Detalle de una partida, jugada a jugada: para cada jugada de quien aprende, qué tal era (la mejor, buena,
## imprecisión, error, error grave, única), qué hace, qué permite y cuál era la mejor, con flechas.
##
## Las cifras salen del rival de la app (core/bot.gd, sin ruido): no es un motor fuerte, así que los umbrales son
## anchos (un error es perder 2 peones o más; una imprecisión, alrededor de uno) y las frases dicen lo que se ve
## en el tablero (core/move_why.gd), no números.

const ONLY := "only"
const BEST := "best"
const GOOD := "good"
const INACCURACY := "inaccuracy"
const MISTAKE := "mistake"
const BLUNDER := "blunder"
const LABELS := {"only": "Única jugada", "best": "La mejor", "good": "Buena", "inaccuracy": "Imprecisión", "mistake": "Error", "blunder": "Error grave"}
## Chapa de anotación en el tablero (las de demo.gd: best «!», good e only con icono, dubious «?!», wrong «?»,
## blunder «??»).
const BADGE := {"only": "only", "best": "best", "good": "good", "inaccuracy": "dubious", "mistake": "wrong", "blunder": "blunder"}
const NEAR_MATE := Bot.MATE - 300


## fens[i]: posición antes de la jugada i; moves[i]: la jugada (UCI). color: el bando de quien aprende.
## `progress` (opcional) recibe (hechas, total).
static func analyze(fens: Array, moves: Array, color: int, seconds: float = 0.6, progress: Callable = Callable()) -> Array:
	var out: Array = []
	var bot := Bot.new(4)
	var mine: Array = []
	for i in moves.size():
		if i < fens.size() and Chess.from_fen(str(fens[i])).turn == color:
			mine.append(i)
	var done := 0
	for i: int in mine:
		var pos := Chess.from_fen(str(fens[i]))
		var m := pos.find_uci(str(moves[i]))
		done += 1
		if progress.is_valid():
			progress.call(done, mine.size())
		if m < 0:
			continue
		out.append(entry(bot, pos, m, color, i, seconds))
	return out


## `pre`: la valoración ya hecha con Stockfish (pre_from_engine); sin ella, la calcula `bot`. Con Stockfish la
## nota sale de cuánto baja la probabilidad de ganar (umbrales de chess.com, como el tutor: CoachAI.verdict_for),
## no de los centipeones: así un error en una posición ya ganada no sale como «error grave».
static func entry(bot: Bot, pos: Chess, m: int, color: int, ply: int, seconds: float, pre: Dictionary = {}) -> Dictionary:
	var san := SanEs.san(pos, m)
	var legal := pos.legal_moves()
	var e := {"ply": ply, "n": ply / 2 + 1, "san": san, "fen": pos.fen(), "uci": Chess.uci(m), "paras": [], "arrows": []}
	var from := Chess.move_from(m)
	var to := Chess.move_to(m)
	if legal.size() == 1:
		e["verdict"] = ONLY
		var w := MoveWhy.explain(pos, m, color, "free")
		e["paras"] = _texts(w["paras"], 3)
		e["arrows"] = [{"from": from, "to": to, "tone": "good"}]
		return _finish(e)
	var a := pre if not pre.is_empty() else (bot.analyse(pos, m, 4, seconds) if bot != null else {})
	if a.is_empty() or int(a.get("depth", 0)) == 0:
		e["verdict"] = GOOD
		e["paras"] = _texts(MoveWhy.move_paras(pos, m, color), 2)
		e["arrows"] = [{"from": from, "to": to, "tone": "good"}]
		return _finish(e)
	var best := int(a["best"])
	var bs := int(a["best_score"])
	var ps := int(a["played_score"])
	var loss := _clip(bs) - _clip(ps)
	var verdict := GOOD
	var missed_mate := bs >= NEAR_MATE and ps < NEAR_MATE
	var allows_mate := ps <= -NEAR_MATE and bs > -NEAR_MATE
	if a.has("drop"):
		var v := CoachAI.verdict_for(float(a["drop"]), best == m, allows_mate, missed_mate)
		if best != m and not allows_mate:
			v = CoachAI.at_least(v, str(a.get("floor", "")))
		verdict = {"best": BEST, "inaccuracy": INACCURACY, "mistake": MISTAKE, "blunder": BLUNDER}.get(v, GOOD)
	elif best == m or loss <= 30:
		verdict = BEST if best == m else GOOD
	elif allows_mate:
		verdict = BLUNDER
	elif missed_mate:
		verdict = MISTAKE
	elif loss < 90:
		verdict = GOOD
	elif loss < 200:
		verdict = INACCURACY
	elif loss < 400:
		verdict = MISTAKE
	else:
		verdict = BLUNDER
	e["verdict"] = verdict
	e["loss"] = loss
	var paras: Array = []
	var arrows: Array = []
	var played_why := MoveWhy.move_paras(pos, m, color)
	if verdict == BEST or verdict == GOOD:
		paras.append_array(_texts(played_why, 2))
		var idea := principle(pos, m, ply)
		if idea != "":
			paras.append(idea)
		arrows.append({"from": from, "to": to, "tone": "good"})
		if verdict == GOOD and best != m and loss >= 60:
			paras.append(Loc.f("También estaba %s.", SanEs.san(pos, best)))
		elif verdict == BEST and bs >= NEAR_MATE:
			paras.append("Lleva a un mate forzado.")
	else:
		paras.append(_texts(played_why, 1)[0] if not played_why.is_empty() else "%s." % san)
		arrows.append({"from": from, "to": to, "tone": "bad"})
		# Qué permite: la mejor respuesta del rival.
		var after := pos.after(m)
		if allows_mate:
			var mate := GameReview.mate_in_one(after)
			if mate >= 0:
				paras.append(Loc.f("Permite jaque mate: %s.", SanEs.san(after, mate)))
				arrows.append({"from": Chess.move_from(mate), "to": Chess.move_to(mate), "tone": "info"})
			else:
				paras.append("Deja al rival un mate forzado.")
		else:
			var r := {"best": int(a["reply"])} if a.has("reply") and int(a["reply"]) >= 0 else ({} if a.has("reply") or bot == null else bot.analyse(after, -1, 3, seconds * 0.5))
			if not r.is_empty():
				var reply := int(r["best"])
				var tag := MoveWhy.short_tag(after, reply)
				paras.append(Loc.f("Permite %s%s.", [SanEs.san(after, reply), (": " + tag) if tag != "" else ""]))
				arrows.append({"from": Chess.move_from(reply), "to": Chess.move_to(reply), "tone": "info"})
		# La mejor y por qué.
		var best_why := MoveWhy.move_paras(pos, best, color)
		var best_text := Loc.f("La mejor era %s", SanEs.san(pos, best))
		var btag := MoveWhy.short_tag(pos, best)
		if missed_mate:
			best_text += ": llevaba a un mate forzado"
		elif btag != "":
			best_text += ": " + btag
		paras.append(best_text + ".")
		if best_why.size() > 1 and btag == "" and not missed_mate:
			# Esta frase cuenta cómo quedaría la posición con la mejor jugada, que no se jugó: hay que decirlo, o
			# parece que habla de piezas que no están ahí («El peón de h4…» con el peón aún en h3; Pablo, 21-11).
			paras.append(after_best(str((best_why[1] as Dictionary)["text"])))
		arrows.append({"from": Chess.move_from(best), "to": Chess.move_to(best), "tone": "good"})
	e["paras"] = paras
	e["arrows"] = arrows
	e["best_san"] = SanEs.san(pos, best)
	if best != m:
		# Para enseñar la mejor en el tablero, con cómo seguiría la partida.
		e["best_uci"] = Chess.uci(best)
	return _finish(e)


## La valoración de Stockfish (LocalEngine: valores desde las blancas) en la forma de Bot.analyse, para `entry`:
## `a` es el análisis de la posición y `b` el de después de la jugada ({} si allí ya no hay jugadas). Además, «drop»
## (lo que baja la probabilidad de ganar, en puntos) y «reply» (la mejor respuesta del rival, o −1).
static func pre_from_engine(pos: Chess, m: int, a: Dictionary, b: Dictionary, elo: float = CoachAI.DEFAULT_ELO) -> Dictionary:
	var best := pos.find_uci(str(a.get("move", "")))
	if best < 0:
		return {}
	var sign := 1 if pos.turn == 0 else -1
	var after := pos.after(m)
	var bs := _engine_score(a) * sign
	var ps := 0
	var reply := -1
	# Puntos esperados del jugador según su nivel (como chess.com; CoachAI.expected).
	var player := pos.turn
	var w_after := CoachAI.expected(0.0, 0, elo)
	var cp_played := 0.0
	if b.is_empty():
		if not after.legal_moves().is_empty():
			return {}
		# Mate o ahogado con tu jugada.
		ps = Bot.MATE if after.in_check() else 0
		if after.in_check():
			w_after = 100.0
			cp_played = 10000.0
	else:
		ps = _engine_score(b) * sign
		reply = after.find_uci(str(b.get("move", "")))
		w_after = CoachAI.expected_for(b, player, elo)
		cp_played = CoachAI.cp_for(b, player)
	if best == m:
		ps = bs
	var w_before := CoachAI.expected_for(a, player, elo)
	var drop := w_before - w_after
	# Red de seguridad del material (como el tutor): la línea jugada acaba con menos material que la mejor.
	var floor := ""
	var cp_best := CoachAI.cp_for(a, player)
	if best != m and absf(cp_best) < 10000.0 and absf(cp_played) < 10000.0:
		var line: Array = [Chess.uci(m)]
		if not b.is_empty():
			line.append_array(CoachAI._chain(str(b["move"]), b.get("continuationArr", [])))
		var mb := CoachAI.material_after(pos.fen(), CoachAI._chain(str(a["move"]), a.get("continuationArr", [])), player)
		var mp := CoachAI.material_after(pos.fen(), line, player)
		if not mb.is_empty() and not mp.is_empty():
			floor = CoachAI.material_min_verdict(int(mb["bal"]) - int(mp["bal"]), cp_best - cp_played)
	return {"best": best, "best_score": bs, "played_score": ps, "depth": maxi(1, int(a.get("depth", 1))), "reply": reply, "drop": maxf(0.0, drop) if best != m else 0.0, "floor": floor}


## Puntuación de un análisis de Stockfish desde las blancas, en la escala de Bot (mate = ±(MATE − jugadas)).
static func _engine_score(e: Dictionary) -> int:
	if e.get("mate") != null:
		var n := int(e["mate"])
		return (Bot.MATE - absi(n)) * (1 if n > 0 else -1)
	return int(e.get("centipawns", 0))


## Lo que se dice de la posición a la que llevaba la mejor jugada (que no se jugó).
static func after_best(text: String) -> String:
	return Loc.f("Si la hubieras jugado: %s", text)


## Principios de la apertura que cumple una jugada (en las primeras jugadas): centro, desarrollo, enroque.
static func principle(pos: Chess, m: int, ply: int) -> String:
	if ply > 24:
		return ""
	var from := Chess.move_from(m)
	var to := Chess.move_to(m)
	var t := Chess.type_of(pos.b[from])
	var flag := Chess.move_flag(m)
	if flag == Chess.F_CASTLE_K or flag == Chess.F_CASTLE_Q:
		return "Enrocar pronto pone el rey a salvo y conecta las torres."
	var back := 0 if pos.turn == 0 else 7
	if (t == Chess.KNIGHT or t == Chess.BISHOP) and (from >> 3) == back:
		return "Desarrolla una pieza: sale de su casilla inicial y entra en juego."
	if t == Chess.PAWN and Chess.sq_name(to) in ["e4", "d4", "e5", "d5"]:
		return "Ocupa el centro, donde las piezas tienen más casillas."
	return ""


static func _finish(e: Dictionary) -> Dictionary:
	e["label"] = LABELS[str(e["verdict"])]
	e["badge"] = BADGE[str(e["verdict"])]
	return e


static func _texts(paras: Array, limit: int) -> Array:
	var out: Array = []
	for p: Dictionary in paras.slice(0, limit):
		out.append(str(p["text"]))
	return out


## Valores de mate recortados, para restar sin desbordar: un mate cuenta como 20 peones.
static func _clip(score: int) -> int:
	return clampi(score, -2000, 2000)


## Recuento por veredicto, para el resumen: {"best": n, "good": n, …}.
static func counts(detail: Array) -> Dictionary:
	var out := {}
	for e: Dictionary in detail:
		var v := str(e["verdict"])
		out[v] = int(out.get(v, 0)) + 1
	return out
