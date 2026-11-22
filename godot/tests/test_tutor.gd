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
	_ok(TutorVoice.fix_chess_words("mueve el al fin a c4", "es") == "mueve el alfil a c4" and TutorVoice.fix_chess_words("peor de rey dos pasos", "es") == "peón de rey dos pasos", "dictado: «al fin» → «alfil», «peor de rey» → «peón de rey»")
	_ok(TutorVoice.fix_chess_words("¿es peor esta jugada?", "es") == "¿es peor esta jugada?" and TutorVoice.fix_chess_words("al fin", "en") == "al fin", "sin tocar frases normales ni otros idiomas")
	var wav := TutorVoice.wav_bytes(PackedFloat32Array([0.0, 0.5, -0.5, 1.0]), 16000)
	_ok(wav.size() == 52 and wav.decode_u32(0) == 0x46464952 and wav.decode_u32(24) == 16000 and wav.decode_s16(46) == 16383, "WAV de 16 kHz para Whisper")
	var check_pos := Chess.from_fen("r1b1kbnr/pppp1ppp/2n1p3/8/1qBPP3/5N2/PPPN1PPP/R1BQK2R b KQkq - 5 5")
	_ok(CoachAI.threatened(check_pos, ["b4", "c4", "d2"]) == [Chess.sq_index("c4"), Chess.sq_index("d2")], "en rosa, las piezas amenazadas que se nombran (c4, d2), no la dama que ataca (b4)")
	_ok(CoachAI.squares_in("Con Cge2 sacas el caballo de g1, pero no proteges el peón de e5 (e5 queda solo). Dxe5.") == ["g1", "e5"], "casillas nombradas sueltas en un texto")
	_ok(CoachAI.tutor_url({"tutor": "https://x.test/tutor"}) == "https://x.test/tutor" and CoachAI.tutor_url({}) == "", "dirección del tutor")
	_ok(CoachAI.tutor_url(CoachAI.load_config()).ends_with("/tutor"), "la app trae la dirección del tutor")

	# Stockfish del móvil: lo que devuelve el complemento, a la forma del servidor (desde las blancas).
	var ea := LocalEngine.parse("move=f3f4;depth=20;cp=120;pv=f3f4,f8g7,g1f3", GIFT)
	_ok(ea["move"] == "f3f4" and ea["centipawns"] == 120 and ea["continuationArr"] == ["f3f4", "f8g7", "g1f3"], "análisis del móvil, juegan blancas")
	var eb := LocalEngine.parse("move=c7e5;depth=20;cp=150;pv=c7e5,d1d2", GIFT_AFTER)
	_ok(eb["centipawns"] == -150, "juegan negras: el valor se da la vuelta (desde las blancas)")
	_ok(LocalEngine.parse("move=e2e4;depth=9;mate=2;pv=e2e4", GIFT_AFTER)["mate"] == -2 and LocalEngine.parse("error=IOException", GIFT).is_empty(), "mate desde las blancas; un error, vacío")
	var lj := CoachAI.local_judge(GIFT, "g1e2", ea, eb)
	_ok(lj["verdict"] == "blunder" and lj["win_best"] == 61 and lj["local"] and CoachAI.remote_ok(lj), "valoración en el móvil (sin servidor): error grave, de 61 %%")
	_ok((lj["lines"]["played"] as Array).map(func(x: Dictionary) -> String: return x["uci"]) == ["g1e2", "c7e5", "d1d2"] and (lj["lines"]["best"] as Array).size() == 3, "con sus dos líneas")
	var miss := CoachAI.local_judge(GIFT, "g1e2", {"type": "bestmove", "move": "f3f4", "centipawns": 400, "mate": null, "continuationArr": ["f3f4"]}, {"type": "bestmove", "move": "c7e5", "centipawns": 40, "mate": null, "continuationArr": ["c7e5"]}, 52)
	_ok(miss["verdict"] == "miss" and CoachAI.remote_ok(miss), "oportunidad perdida (sin conexión): no empeora respecto a antes del rival")
	_ok(CoachAI.verdict_for(19.0, false, false, false) == "mistake" and CoachAI.verdict_for(20.0, false, false, false) == "blunder", "umbrales de chess.com, como el servidor")

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

	# 4a. Oportunidad perdida: su chapa, su nombre y el texto.
	demo._start_game(cfg, 0)
	await _frames(4)
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	var md := _fake("blunder")
	md["verdict"] = "miss"
	demo._coach_apply_remote(md)
	_ok(demo.coach_verdict == "miss" and demo._coach_label("miss") == Loc.t("Oportunidad perdida") and demo.BADGES.has(demo._coach_badge_for("miss")), "oportunidad perdida: chapa y nombre")
	_ok(demo.coach_note.contains("No pierdes nada") and demo.coach_note.contains("f4"), "y el texto: no pierdes nada, había algo mejor (%s)" % demo.coach_note)
	_ok(demo._coach_prev_win == 42, "se guarda cómo quedó para la jugada siguiente")
	await _until(func() -> bool: return demo.game_state == "play")

	# 4c. «Prueba otra vez»: deshace, pista en rosa sin decir la jugada, y celebra si ahora aciertas.
	demo._start_game(cfg, 0)
	await _frames(4)
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	demo._coach_apply_remote(_fake("blunder"))
	await _until(func() -> bool: return demo.game_state == "play")
	demo._refresh()
	await _frames(2)
	_ok(demo._retry_ready() and _has_text(demo.card_body, "Prueba otra vez"), "tras un error grave: botón «Prueba otra vez»")
	var used_before := Premium.trial_left()
	demo._coach_retry()
	await _frames(3)
	_ok(demo._same_position(demo.view.board.chess.fen(), GIFT) and demo.view.interactive, "se deshace tu jugada y la del rival")
	_ok(Array(demo.view.board.focus_squares()) == [Chess.sq_index("f3")] and demo.coach_hint.contains("f3") and not demo.coach_hint.contains("f4"), "pista: la pieza que conviene mover, en rosa, sin la jugada (%s)" % demo.coach_hint)
	_ok(demo.game_helped and demo.game_note.contains(Loc.t("Con ayudas, esta partida no cuenta para tu nivel.")), "con ayudas, la partida no cuenta para el nivel (y se avisa)")
	demo.view.show_move("f3f4")
	demo._game_move("f3f4")
	_ok(Array(demo.view.board.focus_squares()).is_empty(), "al jugar, deja de parpadear")
	var good := _fake("best")
	good["lines"]["played"][0]["uci"] = "f3f4"
	demo._coach_apply_remote(good)
	_ok(demo.coach_retry_line == Loc.t("¡Ahora sí! Era la mejor jugada.") and not demo._retry_ready(), "si ahora aciertas, el tutor lo celebra")
	_ok(Premium.active() or Premium.trial_left() == used_before, "deshacer no gasta otra partida gratis (%d → %d)" % [used_before, Premium.trial_left()])
	await _until(func() -> bool: return demo.game_state == "play")
	var helped_log := {"partidas": [{"rival_id": "bot:3", "resultado": 1, "ayudas": true}, {"rival_id": "bot:3", "resultado": 1}], "rivales": {}}
	_ok(int(GameLog.game_rating(helped_log, [{}, {}, {}, {"elo": 1500.0, "rd": 60.0}])["n"]) == 1, "las partidas con ayudas no cuentan para el nivel de juego")

	# 4b. Con Stockfish en el móvil y sin servidor: la valoración sale igual (Stockfish simulado).
	demo.local_engine.fake = func(fen: String, _ms: int) -> String:
		return "move=f3f4;depth=20;cp=120;pv=f3f4,f8g7,g1f3" if fen == GIFT else "move=c7e5;depth=20;cp=150;pv=c7e5,d1d2"
	demo.coach.cfg = {"endpoint": ""}
	demo._start_game(cfg, 0)
	await _frames(4)
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	await _until(func() -> bool: return demo.coach_verdict != "" and not demo._coach_remote_wait)
	_ok(demo.coach_verdict == "blunder" and not demo.coach_lesson.is_empty() and demo.coach_debug.contains("Stockfish del móvil"), "Stockfish del móvil sin conexión: error grave y lección en el tablero (%s)" % demo.coach_verdict)
	await _until(func() -> bool: return demo.game_state == "play")
	demo.local_engine.fake = Callable()

	# 5. Preguntas libres (servidor simulado: se llama a _on_tutor_answer a mano).
	demo.coach.cfg = {"endpoint": "", "tutor": "http://127.0.0.1:9/tutor", "tutor_timeout_s": 1, "ask_timeout_s": 1}
	demo.coach.hold_questions = true
	demo._refresh()
	demo._start_game(cfg, 0)
	await _frames(4)
	_ok(demo._tutor_can_ask() and _has_text(demo.card_body, "pregúntame lo que quieras"), "desde la primera jugada se puede preguntar")
	_ok(demo.tutor_toggle.visible and demo._tutor_switch.on, "el interruptor «Tutor IA» está en la barra, encendido")
	var payload := CoachAI.ask_payload(["a", "b", "c"], ["e2e4", "e7e5"], 1, "  ¿por qué?  ", 1200, "es")
	_ok(payload["start"] == "a" and payload["moves"] == ["e2e4", "e7e5"] and payload["player"] == "b" and payload["question"] == "¿por qué?", "lo que se manda al preguntar")
	var many: Array = []
	var hist: Array = ["p0"]
	for i in 20:
		many.append("m%d" % i)
		hist.append("p%d" % (i + 1))
	var cut := CoachAI.ask_payload(hist, many, 0, "x", 0, "es")
	_ok(cut["start"] == "p4" and (cut["moves"] as Array).size() == 16 and cut["moves"][0] == "m4", "como mucho las 16 últimas jugadas, desde la posición de antes")
	demo._open_ask()
	await _frames(2)
	_ok(demo.ask_state == "edit" and demo.ask_edit != null and _has_text(demo.confirm_node, "Qué planea el rival"), "ventana de preguntas, con ideas para empezar")
	_ok(not demo.tutor_voice.available() and _has_text(demo.confirm_node, "dictar con el micrófono del teclado"), "sin el complemento de voz, solo escribir (y el dictado del teclado)")
	demo._ask_idea("¿Qué planea el rival?")
	await _frames(2)
	_ok(demo.ask_state == "wait" and _has_text(demo.confirm_node, "El tutor está preparando tu respuesta") and _button_with(demo.confirm_node, "Cerrar") == null, "al preguntar: «el tutor está preparando tu respuesta», sin botones")
	var gen_q: int = demo._ask_gen
	demo._on_tutor_answer(demo.run_id, gen_q, {"answer": "Las negras quieren atacar tu peón de e5.", "show": {"from": 0, "steps": [{"uci": "c7e5", "fen": GIFT_AFTER, "arrows": [{"from": "c7", "to": "e5", "tone": "bad"}]}]}})
	await _frames(2)
	_ok(demo.ask_state == "answer" and _has_text(demo.confirm_node, "Las negras quieren atacar"), "llega la respuesta")
	_ok(_button_with(demo.confirm_node, "Enséñamelo en el tablero") != null, "con línea: «Enséñamelo en el tablero»")
	_ok(Array(demo.view.board.focus_squares()) == [Chess.sq_index("e5")], "la casilla de la respuesta parpadea en el tablero")
	var live2: String = demo.view.board.chess.fen()
	demo._open_answer_lesson()
	await _frames(3)
	_ok(demo.lesson_open and demo.lesson_line == "answer" and _has_text(demo.card_body, "Te lo enseño en el tablero") and _has_text(demo.card_body, "Las negras quieren atacar"), "la línea de la respuesta, en el tablero")
	_ok(_button_with(demo.actions, "Terminar") != null, "una sola jugada: «Terminar»")
	demo._lesson_next()
	await _frames(3)
	_ok(not demo.lesson_open and demo.view.board.chess.fen() == live2, "al terminar, vuelve la partida")
	_ok(demo.ask_history.size() == 1 and str(demo.ask_history[0]["a"]).contains("Las negras"), "la pregunta y su respuesta quedan para seguir el hilo")
	_ok(demo._ask_shown().is_empty(), "en la partida en directo no se manda «lo que se ve»")
	# Preguntar mirando la lección: el tutor sabe qué paso está en pantalla.
	demo._open_answer_lesson()
	await _frames(3)
	var shown: Dictionary = demo._ask_shown()
	_ok(str(shown.get("label", "")).contains("respuesta anterior, jugada 1 de 1") and shown["moves"] == ["c7e5"] and shown["start"] == GIFT_AFTER, "mirando una línea en el tablero: se manda el paso que se ve (%s)" % str(shown.get("label", "")))
	_ok(_has_round_ask(demo.card_body, demo), "en la lección también hay botón para preguntar")
	var p2 := CoachAI.ask_payload(demo.game_history, demo.game_moves, 0, "¿y si le como el peón?", 0, "es", shown, demo.ask_history)
	_ok(p2.has("shown") and (p2["previous"] as Array).size() == 1, "la pregunta lleva lo que se ve y el hilo")
	# Preguntar con la lección abierta: la respuesta tiene que salir en la ventana (se quedaba «preparando», 22 nov).
	demo._open_ask()
	await _frames(2)
	demo.ask_text = "¿Por qué ha movido la dama?"
	demo._send_question()
	await _frames(2)
	_ok(demo.lesson_open and demo.ask_state == "wait", "pregunta desde la lección: esperando")
	demo.ask_error = 503
	_ok(demo._ask_error_text() == Loc.t("El tutor no está disponible en este momento. Vuelve a intentarlo más tarde."), "sin IA en el servidor (503): «el tutor no está disponible», no «sin conexión»")
	demo.ask_error = 0
	demo._on_tutor_answer(demo.run_id, demo._ask_gen, {"answer": "Para defender el peón de h3.", "show": null})
	await _frames(2)
	_ok(demo.ask_state == "answer" and _has_text(demo.confirm_node, "Para defender el peón de h3"), "con la lección abierta, la respuesta sale en la ventana")
	demo._close_confirm()
	await _frames(2)
	# Apagar el tutor con la lección abierta: el tablero vuelve a la partida (antes se quedaba el ejemplo).
	demo._on_tutor_toggle()
	await _frames(3)
	_ok(not demo.lesson_open and demo.view.board.chess.fen() == live2 and demo.view.interactive, "apagar el tutor en plena lección devuelve el tablero a la partida")
	demo._on_tutor_toggle()
	await _frames(2)
	demo._ask_again()
	await _frames(2)
	demo.ask_text = "hola"
	demo._send_question()
	demo._on_tutor_answer(demo.run_id, demo._ask_gen, {"_error": 429})
	await _frames(2)
	_ok(demo.ask_state == "error" and _has_text(demo.confirm_node, "muchas preguntas seguidas"), "demasiadas preguntas: lo dice")
	demo._on_tutor_answer(demo.run_id, demo._ask_gen - 1, {"answer": "vieja"})
	_ok(demo.ask_state == "error", "una respuesta vieja no pisa la actual")
	demo._close_confirm()
	await _frames(2)
	_ok(Array(demo.view.board.focus_squares()).is_empty(), "al cerrar, nada parpadea")
	_ok(not CoachAI.question_ok({"answer": "ok bien", "show": {"steps": [{"uci": "e2e5", "fen": GIFT}]}}) and CoachAI.question_ok({"answer": "ok bien", "show": null}), "línea ilegal en la respuesta: se rechaza")

	# 5a. Dictado con Whisper (servidor simulado): lo grabado se transcribe y se corrige «al fin» → «alfil».
	var heard_text := [""]
	var on_heard := func(t: String) -> void: heard_text[0] = t
	demo.tutor_voice.heard.connect(on_heard)
	demo.tutor_voice.fake_server = func(audio: String) -> String: return "mueve el al fin a c4" if audio.length() > 100 else ""
	demo.tutor_voice._samples = PackedFloat32Array()
	demo.tutor_voice._samples.resize(16000)
	demo.tutor_voice._heard_voice = true
	demo.tutor_voice._lang = "es-ES"
	demo.tutor_voice._record_finish()
	await _frames(2)
	_ok(heard_text[0] == "mueve el alfil a c4", "Whisper: «%s»" % heard_text[0])
	demo.tutor_voice.heard.disconnect(on_heard)
	demo.tutor_voice.fake_server = Callable()

	# 5b. El asistente: órdenes con palabras (servidor simulado).
	demo._sync_assistant_button()
	_ok(demo.assistant_button != null and demo.assistant_button.visible, "botón flotante del asistente")
	# Se arrastra a otro sitio; el arrastre no abre el asistente.
	var fab: Button = demo.assistant_button
	var before: Vector2 = fab.position
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(50, 50)
	demo._on_assistant_fab_input(down)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = Vector2(-250, -450)
	demo._on_assistant_fab_input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(50, 50)
	demo._on_assistant_fab_input(up)
	demo._on_assistant_fab()
	await _frames(2)
	_ok(fab.position.distance_to(before) > 200.0 and demo.assistant_spot.x >= 0.0 and demo.ask_mode != "assistant", "el botón del asistente se arrastra a otro sitio (y arrastrarlo no lo abre)")
	demo._sync_assistant_button()
	_ok(fab.position.distance_to(before) > 200.0, "y se queda donde se dejó")
	demo.assistant_spot = Vector2(-1, -1)
	demo._sync_assistant_button()
	demo._open_assistant()
	await _frames(2)
	_ok(demo.ask_mode == "assistant" and _has_text(demo.confirm_node, "Asistente") and _has_text(demo.confirm_node, "Peón de rey dos pasos"), "ventana del asistente, con ideas para la partida")
	var st: Dictionary = demo._assistant_state()
	_ok(st["pantalla"] == "game" and (st["legal"] as Array).has("f4=f3f4") and st.has("partida"), "el asistente sabe dónde está y qué jugadas hay")
	_ok(st.has("perfil") and (st["perfil"] as Dictionary).has("juego") and (st["perfil"] as Dictionary).has("stockfish_en_el_movil"), "y el perfil del jugador (niveles, reto, racha): %s" % str(st.get("perfil", {})))
	demo.ask_text = "mármol y peón de rey dos pasos"
	demo._send_question()
	_ok(demo.ask_state == "wait" and demo.ask_mode == "assistant", "esperando al asistente")
	demo._on_assistant_reply(demo._ask_gen, {"say": "Hecho.", "actions": [{"name": "cambiar_material", "input": {"material": "mármol"}}, {"name": "mover", "input": {"uci": "f3f4"}}]})
	await _frames(4)
	_ok(demo.board_style == "marmol" and demo.game_moves.size() >= 1 and str(demo.game_moves[-1]) == "f3f4", "pone el mármol y juega f4")
	_ok(demo.ask_state == "" and demo.confirm_node == null, "hecho sin más: la ventana se cierra sola")
	await _until(func() -> bool: return demo.game_state == "play")
	demo._open_assistant()
	demo.ask_text = "inclina el tablero 20 grados"
	demo._send_question()
	demo._on_assistant_reply(demo._ask_gen, {"say": "Lo inclino.", "actions": [{"name": "inclinar_tablero", "input": {"grados": 20}}]})
	await _frames(2)
	_ok(demo.ask_state == "answer" and _has_text(demo.confirm_node, "Lo más inclinado"), "si no se puede del todo, lo explica")
	demo._close_confirm()
	demo._set_style_index(0)

	# 6. El interruptor: apagar y encender sin ir a Opciones; en partidas con reloj, apagado y explica por qué.
	demo._on_tutor_toggle()
	await _frames(2)
	_ok(not Premium.coach_on and not demo._tutor_switch.on and not demo._tutor_can_ask(), "apagar el tutor desde la barra")
	demo._on_tutor_toggle()
	await _frames(2)
	_ok(Premium.coach_on and demo._tutor_switch.on and demo.coach_note.contains("Tutor encendido"), "y volver a encenderlo")
	demo.game_clocked = true
	demo._refresh()
	await _frames(2)
	_ok(not demo._tutor_switch.on and demo.tutor_toggle.modulate.a < 1.0, "con reloj: apagado y atenuado")
	demo._on_tutor_toggle()
	await _frames(2)
	_ok(_has_text(demo.confirm_node, "Con reloj no hay tutor") and Premium.coach_on, "al tocarlo, explica por qué (sin cambiar el ajuste)")
	demo._close_confirm()
	demo.game_clocked = false
	await _until(func() -> bool: return demo.game_state == "play")
	await _frames(6)

	# 7. Sin premium: partidas gratis con profesor; al acabarse, un aviso (una vez) y nada más.
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
	demo._coach_apply_remote(_fake("blunder"))
	_ok(demo.coach_verdict == "blunder" and not bool(demo.coach_lesson["asked"]), "partida gratis: la lección no se pide sola, ni en un error grave")
	await _until(func() -> bool: return demo.coach_verdict != "")
	_ok(_has_text(demo.card_body, "Gratis 5/5"), "la tarjeta dice qué partida gratis es")
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

	# Licencias: el aviso de Stockfish y la GPL entera dentro de la app.
	demo._open_licences()
	await _frames(2)
	_ok(_has_text(demo.confirm_node, "Copyright (C) 2004-2026 The Stockfish developers") and _button_with(demo.confirm_node, "Código fuente de Stockfish 19") != null, "Licencias: aviso de Stockfish y enlace al código")
	demo._open_licence_text()
	await _frames(2)
	_ok(_has_text(demo.confirm_node, "GNU GENERAL PUBLIC LICENSE") and FileAccess.get_file_as_string(demo.LICENCE_FILE).length() > 30000, "el texto entero de la GPL v3")
	demo._close_confirm()

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


func _has_round_ask(node: Node, demo: Node) -> bool:
	if node is Button and (node as Button).pressed.is_connected(Callable(demo, "_open_ask")):
		return true
	for c in node.get_children():
		if _has_round_ask(c, demo):
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
