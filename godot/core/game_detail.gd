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


static func entry(bot: Bot, pos: Chess, m: int, color: int, ply: int, seconds: float) -> Dictionary:
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
	var a := bot.analyse(pos, m, 4, seconds)
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
	if best == m or loss <= 30:
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
			paras.append("También estaba %s." % SanEs.san(pos, best))
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
				paras.append("Permite jaque mate: %s." % SanEs.san(after, mate))
				arrows.append({"from": Chess.move_from(mate), "to": Chess.move_to(mate), "tone": "info"})
			else:
				paras.append("Deja al rival un mate forzado.")
		else:
			var r := bot.analyse(after, -1, 3, seconds * 0.5)
			if not r.is_empty():
				var reply := int(r["best"])
				var tag := MoveWhy.short_tag(after, reply)
				paras.append("Permite %s%s." % [SanEs.san(after, reply), (": " + tag) if tag != "" else ""])
				arrows.append({"from": Chess.move_from(reply), "to": Chess.move_to(reply), "tone": "info"})
		# La mejor y por qué.
		var best_why := MoveWhy.move_paras(pos, best, color)
		var best_text := "La mejor era %s" % SanEs.san(pos, best)
		var btag := MoveWhy.short_tag(pos, best)
		if missed_mate:
			best_text += ": llevaba a un mate forzado"
		elif btag != "":
			best_text += ": " + btag
		paras.append(best_text + ".")
		if best_why.size() > 1 and btag == "" and not missed_mate:
			paras.append(str((best_why[1] as Dictionary)["text"]))
		arrows.append({"from": Chess.move_from(best), "to": Chess.move_to(best), "tone": "good"})
	e["paras"] = paras
	e["arrows"] = arrows
	e["best_san"] = SanEs.san(pos, best)
	if best != m:
		# Para enseñar la mejor en el tablero, con cómo seguiría la partida.
		e["best_uci"] = Chess.uci(best)
	return _finish(e)


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
