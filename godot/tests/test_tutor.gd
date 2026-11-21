extends SceneTree
## Tutor con Stockfish (worker/src/tutor.js) en la app: la valoración que llega del servidor manda y trae la lección
## sobre el tablero; sin respuesta, vale el motor local. Sin red: las respuestas del servidor se simulan.
## Uso: godot --headless --path godot -s tests/test_tutor.gd

const GIFT := "r3kbnr/1bqppp1p/p5p1/p1pPP3/2B5/2N2P2/PPP3PP/R2QK1NR w KQkq - 0 12"
const GIFT_AFTER := "r3kbnr/1bqppp1p/p5p1/p1pPP3/2B5/2N2P2/PPP1N1PP/R2QK2R b KQkq - 1 12"

var fallos := 0
var hechos := 0


func _fake(verdict: String) -> Dictionary:
	return {
		"verdict": verdict, "drop": 19.8, "win_best": 62, "win_played": 42, "best": "f3f4", "player": "w",
		"lines": {
			"played": [
				{"uci": "g1e2", "fen": GIFT, "arrows": [{"from": "g1", "to": "e2", "tone": "bad"}]},
				{"uci": "c7e5", "fen": GIFT_AFTER, "arrows": [{"from": "c7", "to": "e5", "tone": "bad"}, {"from": "e5", "to": "e2", "tone": "bad"}]},
			],
			"best": [{"uci": "f3f4", "fen": GIFT, "arrows": [{"from": "f3", "to": "f4", "tone": "good"}]}],
		},
	}


func _initialize() -> void:
	# Forma de la respuesta.
	_ok(CoachAI.remote_ok(_fake("blunder")), "respuesta del tutor con la forma esperada")
	_ok(not CoachAI.remote_ok({"verdict": "genial", "lines": {"played": [], "best": []}}), "valoración desconocida: no vale")
	var broken := _fake("blunder")
	broken["lines"]["played"][1]["uci"] = "c7c1"
	_ok(not CoachAI.remote_ok(broken), "una jugada ilegal en la línea: no vale")
	_ok(not CoachAI.remote_ok({"verdict": "best"}), "sin líneas: no vale")
	var arrows := CoachAI.board_arrows(_fake("blunder")["lines"]["played"][1])
	_ok(arrows.size() == 2 and int(arrows[0]["from"]) == Chess.sq_index("c7") and int(arrows[0]["to"]) == Chess.sq_index("e5") and str(arrows[0]["tone"]) == "bad", "flechas del tutor, por índice de casilla")
	_ok(CoachAI.squares_in("Con Cge2 sacas el caballo de g1, pero no proteges el peón de e5 (e5 queda solo). Dxe5.") == ["g1", "e5"], "casillas nombradas sueltas en un texto")
	_ok(CoachAI.tutor_url({"tutor": "https://x.test/tutor"}) == "https://x.test/tutor" and CoachAI.tutor_url({}) == "", "dirección del tutor")
	_ok(CoachAI.tutor_url(CoachAI.load_config()).ends_with("/tutor"), "la app trae la dirección del tutor")

	Premium._loaded = true
	Premium.purchased = false
	Premium.test_on = true
	Premium.coach_on = true
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	Premium._loaded = true
	Premium.test_on = true
	demo.view.board.anim_mode = Board3D.Anim.NONE
	demo.gesture_hint = false
	var cfg := {"variant": "", "level": 0, "title": "Partida", "text": "", "kids": "", "unit": "", "fen": GIFT}
	if not OS.is_debug_build():
		print("TODO OK")
		quit(0)
		return

	# 1. El servidor no contesta (dirección que falla): vale el motor local, sin lección sobre el tablero.
	demo.coach.cfg = {"endpoint": "", "tutor": "http://127.0.0.1:9/tutor", "tutor_timeout_s": 2}
	demo._start_game(cfg, 0)
	await _frames(4)
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	_ok(demo.coach_waiting and demo._coach_remote_wait, "tras la jugada: el profesor la está mirando (se espera a Stockfish)")
	await _until(func() -> bool: return demo.coach_verdict != "" and not demo._coach_remote_wait)
	_ok(demo.coach_lesson.is_empty() and str(demo.coach_note).contains("e5"), "sin servidor: motor local, con su explicación (%s)" % demo.coach_verdict)
	await _until(func() -> bool: return demo.game_state == "play")

	# 2. Contesta Stockfish: su valoración manda y trae la lección.
	demo._start_game(cfg, 0)
	await _frames(4)
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	demo._on_coach_judged(demo.run_id, demo._coach_gen, _fake("blunder"))
	_ok(demo.coach_verdict == "blunder" and not demo.coach_waiting and not demo._coach_pending, "valoración de Stockfish: error grave")
	_ok(not demo.coach_lesson.is_empty() and bool(demo.coach_lesson["asked"]), "con lección, y pedida ya al profesor")
	_ok(str(demo.coach_note).contains("f4"), "mientras llega: «La mejor era f4» (%s)" % demo.coach_note)
	_ok(demo._coach_badge_sq == Chess.sq_index("e2"), "chapa en la casilla de la jugada")
	var gen: int = demo._coach_gen
	demo._on_coach_lesson(demo.run_id, gen, {"summary": "Dejaste e5 sin defensa.", "advice": "Mira qué queda atacado.", "played": ["Sale el caballo.", "La dama captura en e5."], "best": ["Si hubieras jugado f4, defendías e5."]})
	_ok(demo.coach_note == "Dejaste e5 sin defensa." and demo.coach_from_ai, "llega la lección: el resumen del profesor en la tarjeta")
	_ok(_button_with(demo.card_body, "Explícamelo") != null, "botón «Explícamelo» en el bloque del profesor")
	await _until(func() -> bool: return demo.game_state == "play")
	await _frames(4)
	var live: String = demo.view.board.chess.fen()

	# 3. La lección sobre el tablero.
	demo._open_lesson()
	await _frames(3)
	_ok(demo.lesson_open and demo.lesson_line == "played" and demo.lesson_step == 0, "se abre en tu jugada")
	_ok(str(demo.view.board.chess.fen()).begins_with(GIFT_AFTER.get_slice(" ", 0)), "el tablero vuelve atrás y repite tu jugada")
	_ok(not demo.view.interactive, "durante la lección no se mueven piezas a mano")
	_ok(_has_text(demo.card_body, "Sale el caballo.") and _has_text(demo.card_body, "Lo que jugaste"), "la tarjeta dice lo del profesor para esa jugada")
	_ok(_button_with(demo.actions, "Siguiente") != null and _button_with(demo.actions, "Cerrar") != null, "botones: Cerrar, Anterior, Siguiente")
	_ok(Array(demo.view.board.focus_squares()).is_empty(), "sin casillas nombradas (aparte de la jugada), nada parpadea")
	demo._lesson_next()
	await _frames(3)
	_ok(demo.lesson_step == 1 and _has_text(demo.card_body, "La dama captura en e5."), "siguiente: el castigo del rival")
	_ok(Array(demo.view.board.focus_squares()).is_empty(), "la casilla de la propia jugada (e5) no parpadea: ya va marcada")
	_ok(_button_with(demo.actions, "Ver la mejor") != null, "al final de tu línea: «Ver la mejor»")
	demo._lesson_next()
	await _frames(3)
	_ok(demo.lesson_line == "best" and demo.lesson_step == 0 and _has_text(demo.card_body, "Si hubieras jugado f4"), "después, la mejor jugada")
	_ok(Array(demo.view.board.focus_squares()) == [Chess.sq_index("e5")], "parpadea en rosa la pieza de la que habla el profesor (e5)")
	_ok(_has_text(demo.card_body, "Mira qué queda atacado.") and _button_with(demo.actions, "Terminar") != null, "al final, el consejo y «Terminar»")
	demo._lesson_prev()
	await _frames(3)
	_ok(demo.lesson_line == "played" and demo.lesson_step == 1, "anterior: vuelve a tu línea")
	demo._lesson_next()
	demo._lesson_next()
	await _frames(3)
	_ok(not demo.lesson_open and demo.view.board.chess.fen() == live and demo.view.interactive, "al terminar, el tablero vuelve a la partida")
	_ok(Array(demo.view.board.focus_squares()).is_empty(), "y deja de parpadear")

	# 4. Sin textos del profesor, cada paso lleva lo que la app sabe decir.
	demo._start_game(cfg, 0)
	await _frames(4)
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	demo._on_coach_judged(demo.run_id, demo._coach_gen, _fake("brilliant"))
	_ok(demo.coach_verdict == "brilliant" and demo._coach_label("brilliant") == Loc.t("Brillante") and demo.BADGES.has(demo._coach_badge_for("brilliant")), "«brillante» tiene chapa y nombre")
	_ok(not bool(demo.coach_lesson["asked"]), "en una jugada buena la lección se pide solo si se toca «Explícamelo»")
	await _until(func() -> bool: return demo.game_state == "play")
	demo._open_lesson()
	await _frames(3)
	_ok(demo.lesson_open and bool(demo.coach_lesson["asked"]) and _has_text(demo.card_body, "Tu jugada"), "«Explícamelo» también en las jugadas buenas")
	_ok(demo._tutor_text(demo.coach_lesson["lines"]["played"][0]) != "", "sin texto del profesor: el de la app")
	demo._close_lesson()
	await _frames(2)

	# 5. Sin premium: partidas gratis con profesor; al acabarse, un aviso (una vez) y nada más.
	Premium.test_on = false
	Premium.trial_used = 4
	Premium.trial_run = -1
	Premium.trial_told = false
	demo.coach.cfg = {"endpoint": ""}
	demo._start_game(cfg, 0)
	await _frames(4)
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	_ok(demo.coach_trial_game == 5 and Premium.trial_left() == 0, "quinta partida gratis: con profesor")
	await _until(func() -> bool: return demo.coach_verdict != "")
	_ok(_has_text(demo.card_body, "gratis 5 de 5"), "la tarjeta dice qué partida gratis es")
	await _until(func() -> bool: return demo.game_state == "play")
	demo._start_game(cfg, 0)
	await _frames(4)
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	_ok(demo.coach_note.contains("premium") and demo.coach_verdict == "" and Premium.trial_told, "sexta: aviso de que hace falta premium, sin valoración")
	await _until(func() -> bool: return demo.game_state == "play")
	demo.view.show_move("h2h3")
	demo._game_move("h2h3")
	_ok(demo.coach_note == "", "el aviso sale una sola vez")
	await _until(func() -> bool: return demo.game_state == "play")
	await _frames(10)
	Premium.trial_used = 0
	Premium.trial_told = false
	Premium.save_state()

	print("tutor: %d de %d bien" % [hechos - fallos, hechos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _until(cond: Callable) -> void:
	for i in 1500:
		if cond.call():
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _button_with(node: Node, text: String) -> Button:
	if node is Button and ((node as Button).text.contains(Loc.t(text)) or _label_below(node, Loc.t(text))):
		return node
	for c in node.get_children():
		var f := _button_with(c, text)
		if f != null:
			return f
	return null


func _label_below(node: Node, text: String) -> bool:
	for c in node.get_children():
		if (c is Label and (c as Label).text.contains(text)) or _label_below(c, text):
			return true
	return false


func _has_text(node: Node, text: String) -> bool:
	var want := Loc.t(text)
	if (node is Label and (node as Label).text.contains(want)) or (node is Button and (node as Button).text.contains(want)):
		return true
	for c in node.get_children():
		if _has_text(c, text):
			return true
	return false


func _ok(cond: bool, what: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + what)
