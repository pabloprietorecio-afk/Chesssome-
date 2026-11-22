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
	_ok(float(won["drop"]) < 10.0 and (e_won["verdict"] == GameDetail.GOOD or e_won["verdict"] == GameDetail.INACCURACY), "ganando de sobra, perder 3 peones de ventaja es como mucho una imprecisión (%s, baja %.1f)" % [e_won["verdict"], float(won["drop"])])
	var even := GameDetail.pre_from_engine(pos, m, {"move": "f3f4", "centipawns": 40, "mate": null, "depth": 20}, {"move": "c7e5", "centipawns": -300, "mate": null, "depth": 20})
	var e_even := GameDetail.entry(null, pos, m, 0, 22, 0.6, even)
	_ok(e_even["verdict"] == GameDetail.BLUNDER and e_even["best_san"] == "f4" and str(e_even["paras"]).contains("Dxe5"), "igualado y pierdes una pieza: error grave, la mejor era f4 y permite Dxe5 (%s)" % str(e_even["paras"]))

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

	print("TODO OK" if fallos == 0 else "FALLOS: %d de %d" % [fallos, hechos])
	quit(1 if fallos > 0 else 0)


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
