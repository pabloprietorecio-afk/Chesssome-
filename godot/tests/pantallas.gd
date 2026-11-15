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
	demo._leave_game()
	await _frames(4)
	await _detalle(demo)
	await _mis_partidas(demo)
	await _por_que(demo)
	print("PANTALLAS DONE")
	get_tree().quit()


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
	demo._detail_show(2)
	await _frames(6)
	await _shot("p17_detalle_error")
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
		GameLog.add(log, {"fecha": t, "tipo": "ordenador" if str(def[0]).begins_with("bot:") else "online", "rival_id": def[0], "rival_nombre": def[1], "color": def[3], "resultado": def[2], "motivo": "", "inicio": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "jugadas": ["e2e4", "e7e5", "g1f3", "b8c6"]}, {"nivel": def[4], "icono": "piece_rook" if def[0] == "u1" else "piece_knight"} if not str(def[0]).begins_with("bot:") else {})
	demo.game_log = log
	demo._open_my_games_from("online")
	await _frames(8)
	await _shot("p21_mis_partidas")
	demo.progress_scroll.scroll_vertical = 100000
	await _frames(3)
	await _shot("p22_mis_partidas_lista")
	demo._close_progress()


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
