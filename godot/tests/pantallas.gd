extends Node
## Capturas rápidas de las pantallas 2D de la demo (inicio, Entrenar, partida online), para revisarlas en unos
## minutos sin esperar a las capturas largas del 3D. Salida: SHOTS_DIR.
## Uso: xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile res://tests/pantallas.tscn

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_environment("SHOTS_DIR")
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("pantallas")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	add_child(demo)
	await _frames(20)
	# Un jugador de nivel 5 a media subida, como el de las capturas del móvil.
	var p: Dictionary = Assessment.start_test("never")
	p["done"] = true
	p["rating"]["r"] = 1272.0
	demo.player = p
	demo._open_home()
	await _frames(10)
	await _shot("p1_inicio")
	# Cambiar a oscuro desde Opciones, con el inicio abierto: el inicio sigue encima de la tarjeta del problema.
	demo._open_options()
	await _frames(4)
	demo._set_dark(true)
	await _frames(8)
	await _shot("p1b_oscuro_opciones")
	print("OSCURO chrome=%d inicio=%d hoja=%s" % [demo.chrome.get_index(), demo.progress.get_index(), demo.sheet_kind])
	demo._close_options()
	await _frames(4)
	await _shot("p1c_inicio_oscuro")
	demo._set_dark(false)
	await _frames(8)
	await _reto_del_dia(demo)
	demo._open_train_hub()
	await _frames(10)
	await _shot("p2_entrenar")
	# Pulsar un nivel bloqueado: el aviso cambia.
	demo._on_level_pressed(8, 5)
	await _frames(4)
	await _shot("p3_entrenar_bloqueado")
	# Lista numerada de un nivel, con resueltos (verde) e intentados (amarillo).
	var lists: Dictionary = demo._level_lists()
	var four: Array = lists.get(4, [])
	for k in mini(5, four.size()):
		demo.player = Assessment.record_try(demo.player, four[k], {"correct": k != 3}, "train")
	demo._open_level_list(4)
	await _frames(8)
	await _shot("p3b_nivel_4")
	demo._open_online_home()
	await _frames(8)
	await _shot("p4_online")
	demo.online_busy = true
	# 1:23 de espera, a punto de pasar a 1:24: una captura quieta y otra con la lámina cayendo.
	demo.online_wait_ms = Time.get_ticks_msec() - 83000 + 600
	demo._open_online()
	await _frames(8)
	await _shot("p5_online_buscando")
	var clock := _find_clock(demo)
	clock.set_process(false)
	var last: FlipClock.FlipCard = clock._cards[3]
	last.set_digit(str((int(last.digit) + 1) % 10), true)
	last.t = 0.24
	last._pose()
	await _frames(2)
	await _shot("p6_online_lamina_cae")
	last.t = 0.72
	last._pose()
	await _frames(2)
	await _shot("p7_online_lamina_asienta")
	demo.online_busy = false
	demo._close_progress()
	# Partida online: el rival (nivel e icono), un gesto y mirar una jugada atrás.
	demo.view.board.anim_mode = Board3D.Anim.NONE
	demo._online_started(0)
	await _frames(6)
	demo._online_rival_profile({"nivel": 4, "icono": "piece_bishop"})
	demo.view.show_move("e2e4")
	demo._game_move("e2e4")
	await _frames(4)
	demo._online_move("e7e5")
	await _frames(4)
	demo._online_gesture(false, "aplauso")
	await get_tree().create_timer(0.5).timeout
	await _shot("p14_online_partida")
	demo._game_browse(1)
	await _frames(4)
	demo._online_move("g1f3")
	await _frames(4)
	await _shot("p15_online_atras")
	print("ONLINE atrás=%d pendientes=%d" % [demo.game_back, demo._online_pending.size()])
	# Online con reloj: el reloj ocupa la tarjeta y debajo van la insignia, los gestos, «¡Tu tiempo!» y «…».
	demo.online.rhythm = "5+3"
	demo.online.base_ms = 300000.0
	demo.online.inc_ms = 3000.0
	demo.online.rival_uid = "rival-de-prueba"
	demo.online_rival = {"nivel": 4, "icono": "piece_bishop", "nombre": "Lucía"}
	demo._online_started(0)
	await get_tree().create_timer(0.6).timeout
	await _shot("p15b_online_reloj")
	demo._online_gesture(false, "tiempo")
	demo._board_bubble("clock", "¡Pulsa el reloj! Tu tiempo sigue corriendo.", "peach", false, 3.0)
	await get_tree().create_timer(0.5).timeout
	await _shot("p15c_online_avisos")
	demo._ask_still_here()
	await _frames(6)
	await _shot("p15d_sigues_ahi")
	demo._close_idle_ask()
	demo._offer_idle_win(215000.0)
	await _frames(6)
	await _shot("p15e_rival_no_contesta")
	demo._close_idle_offer()
	demo.online.rival_uid = ""
	demo.online.rhythm = ""
	demo.online.base_ms = 0.0
	demo.online.inc_ms = 0.0
	# Piezas comidas: arriba, las que ha comido el rival; abajo, las tuyas y la ventaja.
	var cpos := Chess.from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	var cfens: Array = [cpos.fen()]
	for u: String in ["e2e4", "d7d5", "e4d5", "d8d5", "b1c3", "d5a2", "a1a2"]:
		cpos.apply(cpos.find_uci(u))
		cfens.append(cpos.fen())
	demo.game_history = cfens
	demo.game_moves = ["e2e4", "d7d5", "e4d5", "d8d5", "b1c3", "d5a2", "a1a2"]
	demo.game_back = 0
	demo.view.set_fen(cpos.fen())
	demo._refresh()
	await _frames(8)
	await _shot("p23_comidas")
	demo._leave_game()
	await _frames(4)
	demo._open_game_setup()
	await _frames(6)
	await _shot("p32_configurar_partida")
	demo._close_progress()
	await _frames(2)
	await _reloj(demo)
	await _detalle(demo)
	await _mis_partidas(demo)
	await _por_que(demo)
	print("PROG FINAL ", demo.prog.get("dias", {}))
	# Ahogado: un ejemplo del curso y su «¿Por qué?» (el rey intenta escapar).
	demo._start_lesson("ahogado")
	await _frames(4)
	demo._next_lesson_step()
	await get_tree().create_timer(0.8).timeout
	await _shot("p30_ahogado_ejemplo")
	print("AHOGADO estado=%s porque=%s" % [demo.ex_state, str(demo._learn_why_ok())])
	demo._learn_why_toggle()
	await _frames(4)
	demo._why_go(1)
	await get_tree().create_timer(0.75).timeout
	await _shot("p31_ahogado_porque")
	for wp: Dictionary in demo.why_paras:
		print("PORQUE ", wp["text"])
	demo._learn_why_toggle()
	await _frames(2)
	await _cine(demo)
	# Flechas cortas (a la casilla de al lado) por encima de las piezas: Txf2 en verde, Cxd1 en violeta.
	demo.view.set_fen("r1b1k2r/ppppn1pp/2n5/2p1N3/2P5/8/P4nPP/2RQ1RK1 b - - 0 16")
	demo.view.board.set_arrows([{"from": 5, "to": 13, "tone": "good"}, {"from": 13, "to": 3, "tone": "info"}, {"from": 53, "to": 36, "tone": "bad"}])
	await _frames(6)
	await _shot("p33_flechas_cortas")
	demo.view.board.set_arrows([])
	# Personajes con la chapita de su pieza sobre la cabeza.
	demo.view.board.set_piece_set("aventura")
	demo.view.set_fen("r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4")
	await get_tree().create_timer(1.5).timeout
	await _shot("p29_aventura_chapas")
	demo.view.board.set_piece_set("clasico")
	print("PANTALLAS DONE")
	get_tree().quit()


## Reto del día: una racha de cuatro días, un objetivo cumplido, el reto de la semana a medias, una insignia y el aviso.
func _reto_del_dia(demo: Control) -> void:
	var now: Array = demo._prog_now()
	var bias: int = int(now[1])
	var today: int = demo._prog_day()
	var st := Progress.new_state()
	var ctx: Dictionary = demo._prog_ctx()
	var week_family := ""
	for d in range(today - 3, today + 1):
		var at := d * 86400 + 43200 - bias * 60
		Progress.ensure_today(st, d, ctx)
		week_family = str(st["semana"]["familia"])
		var n := 3 if d == today else 1
		for i in n:
			Progress.record_problem(st, {"correct": true}, at, bias, ctx)
			Progress.record_finish(st, {"id": "s%d_%d" % [d, i], "family": week_family if d == today else "otros", "solved": true}, at, bias, ctx)
	st["aviso"]["activo"] = true
	demo.prog = st
	demo._open_home()
	await _frames(10)
	await _shot("p1d_inicio_reto")
	demo._open_day()
	await _frames(10)
	await _shot("p1e_tu_dia")
	demo._prog_toast("¡Reto del día cumplido!", "Racha de 4 días", true)
	await get_tree().create_timer(0.7).timeout
	await _shot("p1f_aviso_reto")
	print("RETO racha=%d objetivos=%s semana=%s insignias=%s" % [Progress.streak_now(st, today), str(Progress.goals(st, today).map(func(g): return str(g["tipo"]) + ":" + str(g["actual"]) + "/" + str(g["meta"]))), str(st["semana"]), str(st["insignias"])])
	# Los enganches del juego llegan al núcleo: un problema, una lección y una partida (de 20 jugadas, con blancas).
	demo.prog = {}
	demo._try = {"item": demo.pool[0]}
	demo._prog_problem(true)
	demo._prog_lesson()
	demo.game_moves = ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "d2d3", "f8c5", "c2c3", "d7d6", "b2b4", "c5b6", "a2a4", "a7a6", "a4a5", "b6a7", "c1g5", "h7h6", "g5h4", "g7g5"]
	demo.game_color = 0
	demo.game_won = 1
	demo._prog_game()
	var c: Dictionary = Progress.counts(demo.prog, demo._prog_day())
	print("ENGANCHES problema=%d/%d lecciones=%d partidas=%d ganadas=%d" % [int(c["a"]), int(c["p"]), int(c["l"]), int(c["g"]), int(c["v"])])
	# Y por los caminos reales: _record (problema resuelto) y _record_game (partida terminada y anotada).
	demo.prog = {}
	demo.mode = "train"
	demo._try = {"item": demo.pool[0], "t0": 0, "fail_step": -1, "error": "", "help": "", "ms_first": 0.0, "recorded": false}
	demo._record(true)
	demo.game = {}
	demo.game_recorded = false
	demo.game_history = [Board3D.START_FEN]
	demo.game_state = "over"
	demo._record_game()
	var c2: Dictionary = Progress.counts(demo.prog, demo._prog_day())
	print("CAMINOS REALES problemas=%d partidas=%d ganadas=%d" % [int(c2["a"]), int(c2["g"]), int(c2["v"])])
	# Abandonar una partida online no cuenta como partida jugada.
	demo.game = {"online": true}
	demo.game_recorded = false
	demo.game_won = -1
	demo.game_result = "Has abandonado la partida."
	demo._record_game()
	print("ABANDONO partidas=%d (antes %d)" % [int(Progress.counts(demo.prog, demo._prog_day())["g"]), int(c2["g"])])
	demo.game = {}
	demo.prog = {}
	demo._try = {}
	demo._close_progress()


## «¿Por qué?» de un problema real (IBanZ): Tb1+, Rf2 (la única: el caballo controla e2 y g2) y Cd3+ (ataque
## doble). Las explicaciones van párrafo a párrafo, con flechas en el tablero.
func _por_que(demo: Control) -> void:
	var idx := -1
	for i in demo.puzzles.size():
		if str(demo.puzzles[i]["id"]) == "IBanZ":
			idx = i
	if idx < 0:
		print("POR QUE: no está IBanZ")
		return
	demo.view.board.anim_mode = Board3D.Anim.NONE
	demo._start(idx)
	await get_tree().create_timer(0.8).timeout
	await _frames(4)
	await _shot("p7b_comenzar")
	demo._begin()
	await get_tree().create_timer(2.0).timeout
	demo._on_step()
	await get_tree().create_timer(1.0).timeout
	demo._on_right()
	await get_tree().create_timer(2.0).timeout
	print("POR QUE fase=%d paso=%d" % [demo.phase, demo.ask_step])
	demo._toggle_move_why()
	await _frames(6)
	await _shot("p8_rival_1")
	demo._why_go(1)
	await _frames(4)
	await _shot("p9_rival_2")
	demo._why_go(1)
	await _frames(4)
	await _shot("p10_rival_3")
	demo._why_go(2)
	await _frames(4)
	await _shot("p11_rival_5")
	for p: Dictionary in demo.why_paras:
		print("POR QUE · ", p["text"])
	demo._toggle_move_why()
	await _frames(4)
	# La última jugada la hace «el jugador»: sale la ventana «¡Resuelto!» y, tras «OK», la tarjeta pequeña.
	demo.view.show_move("f4d3")
	demo._on_move_played("f4d3")
	await get_tree().create_timer(1.2).timeout
	await _frames(4)
	await _shot("p12a_resuelto_ventana")
	print("RESUELTO fase=%d ventana=%s" % [demo.phase, str(demo.result_popup)])
	demo._close_result_popup()
	await _frames(6)
	await _shot("p12_resuelto")
	demo._toggle_summary()
	await _frames(6)
	await _shot("p12b_resumen")
	demo._toggle_summary()
	await _frames(2)
	demo._toggle_story()
	var k := 0
	for i in demo.why_paras.size():
		if str(demo.why_paras[i]["text"]).contains("ataque doble") and str(demo.why_paras[i].get("san", "")) == "Cd3+":
			k = i
	demo._why_go(k)
	await _frames(4)
	await _shot("p13_jugada_a_jugada")


## «Ver el detalle» de una partida: el mate del pastor jugado con negras (3… Cf6?? permite Dxf7#).
func _detalle(demo: Control) -> void:
	demo._online_started(1)
	await _frames(4)
	var moves := ["e2e4", "e7e5", "f1c4", "b8c6", "d1h5", "g8f6", "h5f7"]
	var pos := Chess.from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	var fens: Array = [pos.fen()]
	for u: String in moves:
		pos.apply(pos.find_uci(u))
		fens.append(pos.fen())
	demo.game_history = fens
	demo.game_moves = moves
	demo.game_state = "over"
	demo.game_result = "Jaque mate: ha ganado el rival."
	demo.game_won = -1
	demo.view.set_fen(pos.fen())
	demo.review = []
	demo.review_done = true
	demo.game["online"] = false
	demo._actions_mode = ""
	demo._refresh()
	await _frames(6)
	await _shot("p16a_final_partida")
	demo._open_detail_from_over()
	var g0 := 0
	while not demo.detail_done and g0 < 600:
		g0 += 1
		await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	await _shot("p16b_jugada_a_jugada_desde_final")
	demo._detail_back()
	await _frames(4)
	print("VUELTA estado=%s" % demo.game_state)
	demo.game["online"] = true
	demo._show_review_page()
	await _frames(6)
	await _shot("p16_analisis_resumen")
	demo._open_detail()
	var guard := 0
	while not demo.detail_done and guard < 600:
		guard += 1
		await get_tree().process_frame
	await _frames(4)
	for e: Dictionary in demo.detail:
		print("DETALLE %s · %s · %s" % [e["san"], e["label"], " / ".join(e["paras"])])
	demo._detail_show(1)
	await get_tree().create_timer(1.4).timeout
	await _shot("p17a_detalle_buena")
	demo._detail_show(2)
	await get_tree().create_timer(0.55).timeout
	await _shot("p17b_detalle_respuesta")
	await get_tree().create_timer(1.6).timeout
	await _shot("p17_detalle_error")
	demo._detail_line_open()
	await get_tree().create_timer(1.0).timeout
	await _shot("p17c_la_mejor_era")
	demo._detail_line_step(2)
	await get_tree().create_timer(1.0).timeout
	await _shot("p17d_la_mejor_sigue")
	print("LINEA %s" % " ".join(PackedStringArray(demo.detail_line_san)))
	demo._detail_line_close()
	await get_tree().create_timer(1.2).timeout
	demo._detail_back()
	await _frames(4)
	await _shot("p18_analisis_con_recuento")
	demo._close_progress()
	demo._leave_game()
	await _frames(4)


## El nombre para jugar online y «Mis partidas» con unas partidas de ejemplo.
func _mis_partidas(demo: Control) -> void:
	demo.online_name = ""
	demo._open_online_home()
	await _frames(6)
	await _shot("p19_online_nombre")
	demo.online_name = "Pablo"
	demo._open_online_home()
	await _frames(6)
	await _shot("p20_online_con_nombre")
	var log := {"partidas": [], "rivales": {}}
	var t := int(Time.get_unix_time_from_system()) - 4000
	for def: Array in [["u1", "Ana", 1, 0, 5], ["bot:2", "Ordenador · Medio", -1, 1, -1], ["u1", "Ana", 0, 1, 5], ["u2", "Luis", 1, 0, 2], ["u3", "Marta", -1, 1, 7]]:
		t += 600
		var why := "Se te ha acabado el tiempo." if int(def[2]) < 0 else ("¡Jaque mate! Has ganado." if int(def[2]) > 0 else "La misma posición tres veces: tablas.")
		GameLog.add(log, {"fecha": t, "tipo": "ordenador" if str(def[0]).begins_with("bot:") else "online", "rival_id": def[0], "rival_nombre": def[1], "color": def[3], "resultado": def[2], "motivo": why, "inicio": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "jugadas": ["e2e4", "e7e5", "g1f3", "b8c6"]}, {"nivel": def[4], "icono": "piece_rook" if def[0] == "u1" else "piece_knight"} if not str(def[0]).begins_with("bot:") else {})
	demo.game_log = log
	# Una evolución de prueba: intentos con su dificultad (la gráfica recalcula la puntuación).
	demo.experience = "casual"
	var tries: Array = []
	for k in 24:
		tries.append({"id": "t%d" % k, "rating": 1050.0 + 18.0 * k, "rd": 60.0, "correct": k % 4 != 1, "phase": "train"})
	demo.player = {"rating": {"r": 1300.0, "rd": 80.0, "vol": 0.06}, "tries": tries, "done": true}
	demo._open_my_games_from("online")
	await _frames(8)
	await _shot("p21_mis_partidas")
	demo._filter_my_games("perdidas", "tiempo")
	await _frames(8)
	await _shot("p21b_mis_partidas_filtro")
	demo.progress_scroll.scroll_vertical = 100000
	await _frames(3)
	await _shot("p22_mis_partidas_lista")
	demo._filter_my_games("", "")
	demo._close_progress()


## Finales de campeones: la entrada en Entrenar, la lista, la presentación, una pregunta (fallo y acierto), un paso
## de la explicación con flechas y el final con el vídeo.
func _cine(demo: Control) -> void:
	# Los intentos de prueba de arriba son de una lista de nivel, sin todos los campos de un problema: al acabar la
	# lección, el resumen del día los leería. Fuera mientras tanto.
	var tries_before: Array = demo.player["tries"]
	demo.player["tries"] = []
	demo._open_train_hub()
	await _frames(6)
	demo.progress_scroll.scroll_vertical = 1100
	await _frames(4)
	await _shot("p34_entrenar_finales")
	demo._open_cine()
	await _frames(6)
	await _shot("p35_finales_lista")
	demo._start_lesson("cine-ding-gukesh-2024-g14")
	await get_tree().create_timer(0.6).timeout
	await _shot("p36_final_presentacion")
	demo._next_lesson_step()
	await get_tree().create_timer(0.6).timeout
	await _shot("p37_final_pregunta")
	demo.view.show_move("b2b1")
	demo._on_move_played("b2b1")
	await get_tree().create_timer(0.8).timeout
	await _shot("p38_final_fallo")
	print("CINE fallo: ", demo.ex_text)
	demo._show_lesson_step()
	await _frames(4)
	demo.view.show_move("b2f2")
	demo._on_move_played("b2f2")
	await get_tree().create_timer(0.8).timeout
	await _shot("p39_final_acierto")
	demo.lesson_ex = 4
	demo._show_lesson_step()
	await get_tree().create_timer(0.6).timeout
	await _shot("p40_final_explicacion")
	demo.lesson_ex = (demo.lesson["exercises"] as Array).size()
	demo._show_lesson_step()
	await get_tree().create_timer(0.8).timeout
	await _shot("p41_final_fin")
	print("CINE fin: ", demo.course_done.get("cine-ding-gukesh-2024-g14", -1))
	demo._open_home()
	await _frames(4)
	demo.player["tries"] = tries_before


func _find_clock(n: Node) -> FlipClock:
	if n is FlipClock:
		return n
	for c in n.get_children():
		var f := _find_clock(c)
		if f != null:
			return f
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)


## Partida con reloj contra el ordenador: el reloj de verdad (pulsadores y pantallas) y la confirmación de rendirse.
func _reloj(demo: Control) -> void:
	demo.press_clock = true
	demo._start_game({"variant": "", "level": 1, "title": "Partida · Medio", "text": "", "kids": "", "unit": "", "clock": [20, 0]}, 0)
	await get_tree().create_timer(0.6).timeout
	await _shot("p24_reloj_te_toca")
	demo.view.show_move("e2e4")
	demo._game_move("e2e4")
	await get_tree().create_timer(0.5).timeout
	await _shot("p25_reloj_pulsa")
	print("RELOJ estado=%s" % demo.game_state)
	demo._on_clock_pressed()
	await get_tree().create_timer(0.05).timeout
	await _shot("p26_reloj_bajando")
	var guard := 0
	while demo.game_state != "play" and guard < 400:
		guard += 1
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _shot("p27_reloj_rival_pulso")
	demo._game_browse(1)
	await _frames(6)
	await _shot("p27b_reloj_atras")
	print("ATRAS back=%d" % demo.game_back)
	demo._on_view_tapped("locked")
	await _frames(4)
	print("DIRECTO back=%d" % demo.game_back)
	demo._ask_resign()
	await get_tree().create_timer(0.4).timeout
	await _shot("p28_confirmar_rendirse")
	print("CONFIRMAR abierta=%s" % str(demo.confirm_node != null))
	demo._close_confirm()
	await _frames(2)
	demo._leave_game()
	await _frames(4)
