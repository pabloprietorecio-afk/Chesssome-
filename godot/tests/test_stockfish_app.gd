extends SceneTree
## Stockfish del móvil fuera del tutor (22 nov): rival «Experto» con su Elo, «Pista» y el análisis de la partida.
## Stockfish simulado (LocalEngine.fake): contesta con la primera jugada legal, o con la que se le diga.
## Uso: godot --headless --path godot -s tests/test_stockfish_app.gd

const GIFT := "r3kbnr/1bqppp1p/p5p1/p1pPP3/2B5/2N2P2/PPP3PP/R2QK1NR w KQkq - 0 12"

var fallos := 0
var hechos := 0
## Jugada que el Stockfish simulado da en una posición (FEN sin contadores), si no, la primera legal.
var answers := {}


func _fake(fen: String, _ms: int) -> String:
	var key := " ".join(Array(fen.split(" ")).slice(0, 4))
	var pos := Chess.from_fen(fen)
	var mv := str(answers.get(key, ""))
	if mv == "":
		mv = Chess.uci(pos.legal_moves()[0])
	return "move=%s;depth=20;cp=30;pv=%s" % [mv, mv]


func _initialize() -> void:
	_ok(GameDetail._engine_score({"mate": 3, "centipawns": null}) == Bot.MATE - 3 and GameDetail._engine_score({"mate": null, "centipawns": -80}) == -80, "puntuación de Stockfish en la escala de la app")
	# Análisis: la misma valoración con un error en una posición ya ganada (+9) no es «error grave».
	var pos := Chess.from_fen(GIFT)
	var m := pos.find_uci("g1e2")
	var won := GameDetail.pre_from_engine(pos, m, {"move": "f3f4", "centipawns": 900, "mate": null, "depth": 20}, {"move": "c7e5", "centipawns": 600, "mate": null, "depth": 20})
	var e_won := GameDetail.entry(null, pos, m, 0, 22, 0.6, won)
	# Con la curva medida (22 nov), un 1500 convierte +6 bastante peor que +9 (un 80 % frente a un 91 %): puede ser
	# «error», pero nunca «error grave». Un 2200 convierte casi igual: como mucho, imprecisión.
	_ok(float(won["drop"]) < 20.0 and e_won["verdict"] != GameDetail.BLUNDER, "ganando de sobra, perder 3 peones de ventaja no es error grave (%s, baja %.1f)" % [e_won["verdict"], float(won["drop"])])
	var won_2200 := GameDetail.pre_from_engine(pos, m, {"move": "f3f4", "centipawns": 900, "mate": null, "depth": 20}, {"move": "c7e5", "centipawns": 600, "mate": null, "depth": 20}, 2200.0)
	var e_won_2200 := GameDetail.entry(null, pos, m, 0, 22, 0.6, won_2200)
	_ok(e_won_2200["verdict"] == GameDetail.GOOD or e_won_2200["verdict"] == GameDetail.INACCURACY, "y para un 2200, como mucho imprecisión (%s, baja %.1f)" % [e_won_2200["verdict"], float(won_2200["drop"])])
	var even := GameDetail.pre_from_engine(pos, m, {"move": "f3f4", "centipawns": 40, "mate": null, "depth": 20}, {"move": "c7e5", "centipawns": -300, "mate": null, "depth": 20})
	var e_even := GameDetail.entry(null, pos, m, 0, 22, 0.6, even)
	_ok(e_even["verdict"] == GameDetail.BLUNDER and e_even["best_san"] == "f4" and str(e_even["paras"]).contains("Dxe5"), "igualado y pierdes una pieza: error grave, la mejor era f4 y permite Dxe5 (%s)" % str(e_even["paras"]))

	# Banco de casos de las chapas (22 nov), igual que en el servidor (worker/test.mjs): regalar un caballo con la
	# partida perdida nunca es «buena», y la curva de puntos esperados es la misma tabla.
	var ce4 := "r4rk1/pp3ppp/5n2/5q2/8/1PN5/P1P1QPPP/6K1 w - - 0 16"
	var ce4_a := {"move": "e2e3", "centipawns": -650, "mate": null, "depth": 16, "continuationArr": ["e2e3", "f5c2", "e3e7", "c2b2"]}
	var ce4_b := {"move": "f5e4", "centipawns": -900, "mate": null, "depth": 16, "continuationArr": ["f5e4", "e2e4", "f6e4", "a2a3"]}
	for elo: float in [800.0, 1500.0, 2200.0]:
		var j := CoachAI.local_judge(ce4, "c3e4", ce4_a, ce4_b, -1, elo)
		_ok(j["verdict"] == "mistake" or j["verdict"] == "blunder", "Ce4 regalando el caballo (Elo %d): %s, pierde %d" % [elo, j["verdict"], int(j.get("material", 0))])
		# Ya perdida antes de la jugada del rival: no le había regalado nada, así que no es «oportunidad perdida».
		var jp := CoachAI.local_judge(ce4, "c3e4", ce4_a, ce4_b, roundi(CoachAI.expected(-650.0, 0, elo)), elo)
		_ok(jp["verdict"] == "mistake" or jp["verdict"] == "blunder", "Ce4 con la partida ya perdida antes (Elo %d): %s" % [elo, jp["verdict"]])
	var pos_ce4 := Chess.from_fen(ce4)
	var pre_ce4 := GameDetail.pre_from_engine(pos_ce4, pos_ce4.find_uci("c3e4"), ce4_a, ce4_b, 1500.0)
	var e_ce4 := GameDetail.entry(null, pos_ce4, pos_ce4.find_uci("c3e4"), 0, 30, 0.6, pre_ce4)
	_ok(e_ce4["verdict"] == GameDetail.MISTAKE or e_ce4["verdict"] == GameDetail.BLUNDER, "y en el análisis de la partida: %s" % e_ce4["verdict"])
	_ok(absf(CoachAI.expected(0.0, 0, 1500.0) - 50.0) < 1.5 and CoachAI.expected(300.0, 0, 1500.0) > CoachAI.expected(100.0, 0, 1500.0), "curva de puntos esperados cargada")
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo.view.board.anim_mode = Board3D.Anim.NONE
	demo.gesture_hint = false
	Premium.coach_on = false

	# Sin Stockfish: los cinco niveles de siempre.
	_ok(demo._level_groups() == [0, 1, 2, 3, 4], "sin Stockfish en el móvil, sin «Experto»")
	demo.local_engine.fake = _fake
	_ok(demo._level_groups() == [0, 1, 2, 3, 4, 5], "con Stockfish: «Experto»")
	demo.game_war = true
	_ok(not demo._level_groups().has(5), "en War Chess, no")
	demo.game_war = false

	# Rival «Experto 1»: juega Stockfish con UCI_Elo 2100.
	var cfg := {"variant": "", "level": 13, "title": "Partida", "text": "", "kids": "", "unit": "", "fen": GIFT}
	demo._start_game(cfg, 0)
	await _frames(4)
	answers["r3kbnr/1bqppp1p/p5p1/p1pPP3/2B5/2N2P2/PPP1N1PP/R2QK2R b KQkq -"] = "c7e5"
	demo.view.show_move("g1e2")
	demo._game_move("g1e2")
	await _until(func() -> bool: return demo.game_state == "play" and demo.game_moves.size() == 2)
	_ok(demo.game_moves.size() == 2 and str(demo.game_moves[1]) == "c7e5" and demo.local_engine.last_play_elo == 2100, "«Experto 1»: contesta Stockfish con Elo 2100 (%s, %d)" % [str(demo.game_moves), demo.local_engine.last_play_elo])

	# Pista: la de Stockfish.
	answers[" ".join(Array(demo.view.board.chess.fen().split(" ")).slice(0, 4))] = "d1d4"
	demo._game_hint()
	await _until(func() -> bool: return not demo._hint_busy)
	await _frames(2)
	_ok(demo.game_note.contains("Dd4"), "pista de Stockfish: %s" % demo.game_note)

	# Análisis de la partida: con Stockfish, una entrada por jugada tuya.
	demo._open_detail()
	await _until(func() -> bool: return demo.detail_done)
	_ok(demo.detail_done and demo.detail.size() == 1 and str(demo.detail[0]["uci"]) == "g1e2" and str(demo.detail[0]["verdict"]) != "", "análisis con Stockfish: %s" % str(demo.detail.map(func(x: Dictionary) -> String: return "%s %s" % [x["san"], x["verdict"]])))

	# Pantalla encendida: en la partida sin reloj mientras se toca; a los 5 minutos sin tocar, ya no; en un menú, no.
	var t0 := Time.get_ticks_msec()
	demo._close_progress()
	demo.mode = "game"
	demo.game_state = "play"
	demo._last_touch_ms = t0
	_ok(demo._screen_wanted(t0 + 1000), "partida sin reloj, tocando: encendida")
	_ok(not demo._screen_wanted(t0 + demo.SCREEN_IDLE_MS + 1000), "5 minutos sin tocar: se deja apagar")
	demo.game_clocked = true
	_ok(demo._screen_wanted(t0 + demo.SCREEN_IDLE_MS + 1000), "con reloj: siempre encendida")
	demo.game_state = "over"
	_ok(not demo._screen_wanted(t0 + 61000), "online o con reloj, partida terminada y sin tocar: se deja apagar")
	demo.game_state = "play"
	demo.game_clocked = false
	demo._open_home()
	await _frames(2)
	_ok(not demo._screen_wanted(t0 + 1000), "en el inicio, como cualquier app")

	# Gesto «?» (22 nov): sin respuesta del rival en 20 s, aviso; si contesta, se acaba.
	var row: Control = demo._gesture_row(true)
	var grid: GridContainer = row.get_child(0)
	var inline: Control = demo._gesture_row()
	_ok(grid.get_child_count() == 7 and grid.columns == 4 and (grid.get_child(0) as Button).custom_minimum_size.x >= 160.0 and (inline.get_child(0) as GridContainer).columns == 4, "gestos: siete (con «?»), grandes, en dos filas (también en la tarjeta)")
	inline.free()
	row.free()
	demo.online.phase = "playing"
	var now := Time.get_ticks_msec()
	demo._ping_at = now - 25000
	demo._ping_told = false
	demo.online.rival_alive_at = -1000000
	demo._ping_tick()
	_ok(demo._ping_told and demo._ping_at != -1 and demo._idle_offer_node != null and demo.confirm_node == demo._idle_offer_node and _has_button(demo.confirm_node, "Ganar por abandono"), "«?» sin respuesta en 20 s: sale la ventana de abandono (ganar o seguir esperando)")
	demo._online_idle_tick()
	_ok(demo.confirm_node == demo._idle_offer_node and demo._ping_offer, "y la lógica del turno no la cierra")
	demo._close_confirm()
	demo.online.rival_alive_at = Time.get_ticks_msec() + 1
	demo._ping_tick()
	_ok(demo._ping_at == -1, "si su app contesta, el aviso se acaba")
	_ok(demo._thinking_node != null and demo.confirm_node == demo._thinking_node and demo._recheck_button.disabled and (demo._recheck_button.get_meta("label_node") as Label).text.contains("(2"), "y sale «Tu rival está pensando» con «Volver a comprobar (20)» desactivado")
	demo._recheck_at = Time.get_ticks_msec() - 1
	demo._recheck_tick()
	_ok(not demo._recheck_button.disabled and (demo._recheck_button.get_meta("label_node") as Label).text == Loc.t("Volver a comprobar"), "a los 20 s se puede volver a comprobar")
	demo._close_thinking()
	_ok(demo.confirm_node == null or not is_instance_valid(demo.confirm_node), "y se quita")
	demo.online.phase = ""

	print("TODO OK" if fallos == 0 else "FALLOS: %d de %d" % [fallos, hechos])
	quit(1 if fallos > 0 else 0)


func _has_button(node: Node, text: String) -> bool:
	if node is Button and str(node.get_meta("label", "")) == text:
		return true
	for c in node.get_children():
		if _has_button(c, text):
			return true
	return false


func _until(cond: Callable) -> void:
	for i in 1500:
		if cond.call():
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(cond: bool, what: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + what)
