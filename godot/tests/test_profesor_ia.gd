extends SceneTree
## Profesor IA (premium): qué detecta en directo, qué se le manda a la IA y cuándo se descarta su respuesta. Sin red:
## la llamada real a la API no se prueba aquí.
## Uso: godot --headless --path godot -s tests/test_profesor_ia.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	# Pieza a tiro: tras 1.e4 e5 2.Cf3, la dama a h4 queda a tiro del caballo.
	var fen := "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2"
	var m := GameReview.analyze_move(fen, "d8h4", 3)
	_ok(not m.is_empty() and str(m["kind"]) == "hang", "Dh4?? deja la dama a tiro del caballo (hang)")
	_ok(int(m.get("ply", -1)) == 3 and str(m.get("fen", "")) == fen and str(m.get("played", "")) == "d8h4", "el momento lleva jugada, posición y número")
	_ok(GameReview.analyze_move(fen, "b8c6", 3).is_empty(), "Cc6, jugada normal: el profesor no dice nada")
	_ok(GameReview.analyze_move(fen, "a1a1", 3).is_empty(), "jugada que no existe: nada")
	# Un peón suelto (la partida de Pablo, 21-11): 1.e4 Cf6 2.Ch3?, el peón de e4 sigue sin defensa.
	var pawn_fen := "rnbqkb1r/pppppppp/5n2/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 1 2"
	var pm := GameReview.analyze_move(pawn_fen, "g1h3", 2)
	_ok(not pm.is_empty() and str(pm["kind"]) == "hang" and str(pm["text"]).contains("e4"), "2.Ch3: el peón de e4 queda a tiro: %s" % str(pm.get("text", "")))
	_ok(GameReview.analyze_move(pawn_fen, "b1c3", 2).is_empty(), "2.Cc3, que lo defiende: nada")
	_ok(GameReview.analyze(["rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1", pawn_fen, "rnbqkb1r/pppppppp/5n2/8/4P3/7N/PPPP1PPP/RNBQKB1R b KQkq - 2 2"], ["e2e4", "g8f6", "g1h3"], 0).filter(func(x: Dictionary) -> bool: return str(x["kind"]) == "hang").is_empty(), "en el análisis de después, un peón sigue sin ser un momento")
	# Con el motor (lo que usa el profesor en vivo): 2.Ch3 no es «buena».
	var pe := GameDetail.entry(Bot.new(4), Chess.from_fen(pawn_fen), Chess.from_fen(pawn_fen).find_uci("g1h3"), 0, 2, 0.8)
	_ok([GameDetail.INACCURACY, GameDetail.MISTAKE, GameDetail.BLUNDER].has(str(pe.get("verdict", ""))), "2.Ch3 para el motor: %s (pierde %d) · %s" % [str(pe.get("verdict", "")), int(pe.get("loss", 0)), " ".join(pe.get("paras", []))])
	# Mate en una que se escapa: la dama blanca da mate en f7 y el jugador juega otra cosa.
	var mate_fen := "r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4"
	var mm := GameReview.analyze_move(mate_fen, "g1f3", 6)
	_ok(not mm.is_empty() and str(mm["kind"]) == "missed_mate" and str(mm["better"]) == "h5f7", "se escapa Dxf7#: missed_mate con la jugada buena")

	# Lo que sale hacia la IA.
	var facts := CoachAI.facts_for(m, "Dh4", "Cc6", 1180.0, "es")
	var body := CoachAI.build_body(facts, CoachAI.load_config())
	var user := str((body["messages"] as Array)[0]["content"])
	_ok(str(body["model"]) == "claude-haiku-5-5", "modelo: Claude Haiku 5.5")
	_ok(user.contains(fen) and user.contains("Dh4") and user.contains("aficionado"), "la petición lleva la posición, la jugada y el nivel")
	_ok(str(body["system"]).contains("SOLO los hechos"), "el sistema le prohíbe calcular por su cuenta")
	_ok(not user.contains("@") and not user.to_lower().contains("nombre"), "nada personal en la petición")
	_ok(CoachAI.level_words(0).contains("principiante"), "sin nivel: como principiante")

	# Comprobación de la respuesta.
	var ok_text := "Cuidado: con Dh4 tu dama quedó en h4, donde el caballo puede capturarla. Antes de mover, mira qué piezas tuyas quedan atacadas."
	_ok(CoachAI.answer_ok(ok_text, facts), "respuesta con casillas de los hechos: vale")
	_ok(not CoachAI.answer_ok("Mejor era Ag4 para clavar el caballo.", facts), "nombra una casilla que no está en los hechos (g4): se descarta")
	_ok(not CoachAI.answer_ok("", facts), "respuesta vacía: se descarta")
	_ok(CoachAI.allowed_squares({"verified": "capturar con Cxf5+ o exd5"}).has("f5") and CoachAI.allowed_squares({"verified": "exd5"}).has("d5"), "las casillas dentro de capturas cuentan")
	_ok(CoachAI.parse_answer('{"content":[{"type":"text","text":" Hola profe "}]}') == "Hola profe", "lee el texto de la API de mensajes")
	_ok(CoachAI.parse_answer("no es json") == "", "respuesta rota: vacía")

	# Cómo se llama.
	_ok(CoachAI.endpoint_mode({"endpoint": ""}, "", true) == "", "sin servidor ni clave: no se llama (texto comprobado)")
	_ok(CoachAI.endpoint_mode({"endpoint": ""}, "sk-ant-x", true) == "direct", "clave de prueba en depuración: directo")
	_ok(CoachAI.endpoint_mode({"endpoint": ""}, "sk-ant-x", false) == "", "en publicación, la clave de prueba no sirve")
	_ok(CoachAI.endpoint_mode({"endpoint": "https://ejemplo.test/profesor"}, "", false) == "server", "con servidor propio: servidor")

	# Premium y cuándo comenta.
	Premium.purchased = false
	Premium.test_on = false
	Premium.coach_on = true
	Premium._loaded = true
	_ok(not Premium.active(), "sin compra ni prueba: no es premium")
	Premium.test_on = true
	_ok(Premium.active() == OS.is_debug_build(), "premium de prueba: solo en depuración")
	Premium.purchased = true
	_ok(Premium.coach_applies(false, false, false, ""), "premium y partida normal: comenta")
	_ok(not Premium.coach_applies(true, false, false, ""), "nivel Kids: nunca")
	_ok(not Premium.coach_applies(false, true, false, ""), "online: no")
	_ok(not Premium.coach_applies(false, false, true, ""), "con reloj: no")
	_ok(not Premium.coach_applies(false, false, false, "war"), "War Chess y variantes: no")
	Premium.coach_on = false
	_ok(not Premium.coach_applies(false, false, false, ""), "apagado por el jugador: no")

	# Sin clave, `ask` contesta enseguida con el texto comprobado.
	Premium.coach_on = true
	Premium.test_key = ""
	var coach := CoachAI.new()
	coach.cfg = {"endpoint": ""}
	var got: Array = []
	coach.answered.connect(func(run: int, ply: int, text: String, from_ai: bool) -> void: got.append([run, ply, text, from_ai]))
	coach.ask(facts, 7, 3)
	_ok(got.size() == 1 and int(got[0][0]) == 7 and str(got[0][2]) == str(m["text"]) and not bool(got[0][3]), "sin clave: texto comprobado, sin IA")
	_ok(coach.calls == 0, "sin clave no se gasta ninguna petición")
	coach.free()

	print("profesor IA: %d de %d bien" % [hechos - fallos, hechos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + what)
