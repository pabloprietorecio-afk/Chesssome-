extends Node
## Capturas del tablero 3D para revisar el aspecto, los estados y las animaciones.
## Se ejecuta en la CI con Vulkan por software y a pasos de tiempo fijos (--fixed-fps 30), para que los
## fotogramas de las animaciones salgan siempre en el mismo instante.
## Uso: xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --fixed-fps 30 res://tests/shots.tscn
## La carpeta de salida se indica con la variable de entorno SHOTS_DIR.

const MID_FEN := "r1q1k2r/1b2bp1p/pp3n2/1N2Q3/3p4/3P3P/PPP2PP1/R3KB1R w KQkq - 1 16"
const MATE_FEN := "6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1"
const PROMO_FEN := "8/4P1k1/8/8/8/8/6K1/8 w - - 0 1"

var out_dir := ""
var view: BoardView3D
var bg: ColorRect


func _ready() -> void:
	out_dir = OS.get_environment("SHOTS_DIR")
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var size := get_viewport().get_visible_rect().size
	bg = ColorRect.new()
	bg.color = Color("eaf1fb")
	bg.size = size
	add_child(bg)
	# La vista 3D pinta su fondo con el color de la pantalla: no debe notarse dónde acaba.
	view = BoardView3D.new()
	var h := minf(size.y, size.x * 1.25)
	view.position = Vector2(0.0, (size.y - h) * 0.5)
	view.size = Vector2(size.x, h)
	view.edge_fade = 40.0
	view.set_board_theme("light", bg.color)
	add_child(view)
	view.board.fit_pad = Vector4(0.012, 0.09, 0.012, 0.09)
	view.board.apply_camera()
	print("SHOTS driver=%s pantalla=%s lienzo=%s" % [DisplayServer.get_name(), str(DisplayServer.window_get_size()), str(size)])
	await _run()
	print("SHOTS DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT (sin pantalla) ", shot_name)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)


func _sq(square: String) -> int:
	return Chess.sq_index(square)


func _run() -> void:
	var board := view.board
	board.anim_mode = Board3D.Anim.NONE
	await _frames(8)
	await _shot("01_inicio")
	var maple := load("res://textures/arce.jpg") as Texture2D
	if maple != null:
		var img := maple.get_image()
		print("TEXTURA arce %s formato=%d mipmaps=%s" % [str(maple.get_size()), img.get_format(), str(img.has_mipmaps())])
	# Los otros acabados: mármol, metal e ilustrado (con su contorno de tinta); y la madera con contorno.
	for other: String in ["marmol", "metal", "ilustrado"]:
		view.set_board_style(other)
		await _frames(4)
		await _shot("01_" + other)
	view.set_board_style("madera", true)
	await _frames(3)
	await _shot("01_madera_con_contorno")
	view.set_board_style("madera")

	# Medio juego: última jugada, jaque y pieza seleccionada con sus destinos.
	view.set_fen(MID_FEN)
	view.show_move("b5d6")
	board.select(_sq("e8"))
	await _frames(3)
	await _shot("02_jaque_y_seleccion")

	# Flechas de una explicación: la jugada mala y la buena.
	view.set_fen(MID_FEN)
	board.set_arrows([{"from": _sq("b5"), "to": _sq("d4"), "tone": "bad"}, {"from": _sq("b5"), "to": _sq("d6"), "tone": "good"}])
	await _frames(3)
	await _shot("03_flechas")
	board.set_arrows([])

	# Vista en picado («Centrar»).
	board.set_view(90.0, 0.0)
	await _frames(3)
	await _shot("04_cenital")

	# Vista girada con los dedos.
	board.set_view(44.0, -32.0)
	await _frames(3)
	await _shot("05_girada")
	board.set_view(Board3D.DEFAULT_PITCH, 0.0)

	# Tema oscuro.
	bg.color = Color("0a0f1e")
	view.set_board_theme("dark", bg.color)
	await _frames(3)
	await _shot("06_oscuro")
	bg.color = Color("eaf1fb")
	view.set_board_theme("light", bg.color)

	# Con negras.
	view.set_orientation(1)
	await _frames(3)
	await _shot("07_negras")
	view.set_orientation(0)

	# Primer plano para juzgar formas y materiales.
	view.set_fen(Board3D.START_FEN)
	board.camera.fov = 26.0
	board.camera.near = 0.2
	var eye := Vector3(2.9, 2.3, 6.9)
	board.camera.transform = Transform3D(Basis.looking_at(Vector3(0.2, 0.55, 2.7) - eye, Vector3.UP), eye)
	await _frames(3)
	await _shot("08_primer_plano")
	eye = Vector3(-2.4, 1.6, -0.6)
	board.camera.transform = Transform3D(Basis.looking_at(Vector3(0.6, 0.6, -3.3) - eye, Vector3.UP), eye)
	await _frames(3)
	await _shot("09_primer_plano_negras")
	for other: String in ["marmol", "metal"]:
		view.set_board_style(other)
		await _frames(4)
		await _shot("09_primer_plano_" + other)
	view.set_board_style("madera")
	board.apply_camera()

	# Animaciones completas, a mitad de recorrido.
	board.anim_mode = Board3D.Anim.FULL
	view.set_fen(MID_FEN)
	await _frames(2)
	view.show_move("b5d4")
	await _frames(6)
	await _shot("10_salto_del_caballo")
	await _frames(6)
	await _shot("11_captura")
	await _frames(2)
	view.set_fen(MID_FEN)
	await _frames(2)
	if view.show_move("e1c1"):
		await _frames(11)
		await _shot("12_enroque")
		await _frames(2)
	view.set_fen(PROMO_FEN)
	await _frames(2)
	view.show_move("e7e8q")
	await _frames(13)
	await _shot("13_promocion")
	await _frames(2)
	view.set_fen(MATE_FEN)
	await _frames(2)
	view.show_move("a1a8")
	await _frames(24)
	await _shot("14_mate")
	await _frames(20)
	await _shot("15_mate_final")

	# Arrastre: la pieza levantada sigue al dedo.
	board.anim_mode = Board3D.Anim.FAST
	view.set_fen(Board3D.START_FEN)
	board.select(_sq("g1"))
	await _frames(2)
	board.drag_piece(_sq("g1"), board.camera.unproject_position(Board3D.sq_pos(_sq("f3")) + Vector3(0.0, 0.3, 0.0)))
	await _frames(3)
	await _shot("16_arrastre")
	board.cancel_drag()
	board.deselect()

	await _token_shots()
	await _demo_shots()


## Fichas planas con el icono de la pieza en relieve, en los cuatro acabados; de cerca, en picado, con negras y en el mate.
func _token_shots() -> void:
	var board := view.board
	board.anim_mode = Board3D.Anim.NONE
	view.set_fen(Board3D.START_FEN)
	view.set_piece_set("fichas")
	for finish: String in ["madera", "marmol", "metal", "ilustrado"]:
		view.set_board_style(finish)
		await _frames(4)
		await _shot("17_fichas_" + finish)
	view.set_board_style("madera")
	view.set_fen(MID_FEN)
	view.show_move("b5d6")
	board.select(_sq("e8"))
	await _frames(3)
	await _shot("17_fichas_jaque_y_seleccion")
	board.deselect()
	board.set_view(90.0, 0.0)
	await _frames(3)
	await _shot("17_fichas_cenital")
	board.set_view(Board3D.DEFAULT_PITCH, 0.0)
	view.set_orientation(1)
	await _frames(3)
	await _shot("17_fichas_negras")
	view.set_orientation(0)
	# De cerca, para juzgar el relieve de los iconos.
	view.set_fen(Board3D.START_FEN)
	board.camera.fov = 26.0
	board.camera.near = 0.2
	var eye := Vector3(1.6, 2.6, 5.6)
	board.camera.transform = Transform3D(Basis.looking_at(Vector3(0.3, 0.0, 2.9) - eye, Vector3.UP), eye)
	for finish: String in ["madera", "marmol", "metal", "ilustrado"]:
		view.set_board_style(finish)
		await _frames(4)
		await _shot("18_fichas_de_cerca_" + finish)
	view.set_board_style("madera")
	eye = Vector3(-1.2, 2.4, -1.4)
	board.camera.transform = Transform3D(Basis.looking_at(Vector3(0.4, 0.0, -3.1) - eye, Vector3.UP), eye)
	await _frames(3)
	await _shot("18_fichas_de_cerca_oscuras")
	board.apply_camera()
	# Mate: la ficha del rey se da la vuelta. Y los avisos de sonido de una jugada con captura y de un mate.
	var heard: Array[String] = []
	var listen := func(kind: String, _amount: float) -> void: heard.append(kind)
	board.sound.connect(listen)
	board.anim_mode = Board3D.Anim.FULL
	view.set_fen(MID_FEN)
	await _frames(2)
	view.show_move("b5d4")
	await _frames(24)
	view.set_fen(MATE_FEN)
	await _frames(2)
	view.show_move("a1a8")
	await _frames(14)
	await _shot("19_fichas_mate")
	await _frames(24)
	await _shot("19_fichas_mate_final")
	board.sound.disconnect(listen)
	print("SONIDOS avisos=%s grabaciones: arrastre=%s posar=%s captura=%s jaque=%s caida=%s" % [str(heard), str(view.sounds.has_sound("slide")), str(view.sounds.has_sound("place")), str(view.sounds.has_sound("capture")), str(view.sounds.has_sound("check")), str(view.sounds.has_sound("fall"))])
	board.anim_mode = Board3D.Anim.FAST
	view.set_piece_set("clasico")
	view.set_fen(Board3D.START_FEN)
	await _frames(2)


## Primera jugada legal que no es la de la solución (para fallar a propósito).
func _wrong_move(chess: Chess, solution: String) -> String:
	for m in chess.legal_moves():
		var uci := Chess.uci(m)
		if uci != solution and not chess.after(m).is_checkmate() and uci.length() == 4:
			return uci
	return ""


## La demo de verdad (escena principal del APK), jugada con toques simulados por el mismo camino que un dedo.
## El tiempo corre al doble para no alargar la CI: aquí no se juzgan animaciones, sino la pantalla.
func _demo_shots() -> void:
	view.visible = false
	bg.visible = false
	Engine.time_scale = 2.0
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	# Sin ajustes guardados ni bienvenida automática: las capturas salen siempre del mismo estado.
	demo.use_settings = false
	add_child(demo)
	await _frames(30)
	await _shot("20_demo")
	var missing: Array[String] = []
	for icon_name: String in ["bulb", "step", "eye", "skip", "retry", "next", "why", "line", "chart", "tap", "sliders", "pin", "pin_on", "view", "search", "spark", "copy", "open", "close", "sound", "phone", "sun", "moon", "outline", "info", "whatif", "book", "back", "zoom", "play", "first", "piece_knight", "token_pawn", "cap", "clock", "flag", "target", "wrong", "piece_pawn", "piece_queen", "check"]:
		if UiIcons.texture(icon_name) == null:
			missing.append(icon_name)
	print("ICONOS %d en el atlas, faltan=%s emblema=%s" % [UiIcons.names().size(), str(missing), str(UiIcons.emblem() != null)])
	print("DEMO pista de gestos visible=%s botones=«%s» «%s» «%s» «%s»" % [str(demo.gesture_tip.visible), demo.button_label(demo.hint_button), demo.button_label(demo.step_button), demo.button_label(demo.left_button), demo.button_label(demo.right_button)])
	var dview: BoardView3D = demo.view
	var moves: Array = demo.puzzle["moves"]
	var solution := str(moves[1])
	print("DEMO explicaciones=%s puntos=%d" % [str(demo.explain.ok), demo.explain.point_count()])
	# Un fallo a propósito: la tarjeta cuenta qué hace la jugada y qué permite, sin decir cuál era la mejor.
	var wrong := _wrong_move(dview.board.chess, solution)
	if wrong != "":
		_tap(dview, _sq(wrong.substr(0, 2)))
		await _frames(3)
		_tap(dview, _sq(wrong.substr(2, 2)))
		await _frames(22)
		await _shot("20b_demo_fallo")
		print("DEMO fallo=%s titulo=«%s» fase=%d parcial=%s interactivo=%s" % [wrong, demo.title.text, demo.phase, str(demo.exp_partial), str(dview.interactive)])
		var levels: Array = demo.expl.get("levels", [])
		if levels.size() == 4:
			print("DEMO fallo dice: %s" % " | ".join(PackedStringArray(levels[0]["paragraphs"])))
			for line: Dictionary in levels[2]["lines"]:
				if str(line["tone"]) == "bad":
					demo._step_line(line, 0)
					await _frames(10)
					demo._step_line(line, 1)
					await _frames(12)
					await _shot("20c_demo_fallo_variante")
					demo._leave_line()
					await _frames(4)
					break
		print("DEMO tras la variante: fase=%d interactivo=%s" % [demo.phase, str(dview.interactive)])
	_tap(dview, _sq(solution.substr(0, 2)))
	await _frames(3)
	await _shot("21_demo_pieza_tocada")
	print("DEMO seleccionada=%d (esperada %d)" % [dview.board.selected, _sq(solution.substr(0, 2))])
	_tap(dview, _sq(solution.substr(2, 2)))
	await _frames(3)
	await _shot("22_demo_bien")
	print("DEMO titulo=«%s» paso=%d" % [demo.title.text, demo.step])
	await _frames(24)
	await _shot("23_demo_sigue")
	print("DEMO titulo=«%s» paso=%d" % [demo.title.text, demo.step])
	# «Ver solución» y, al acabar, «Repetir» y «Siguiente».
	demo._on_left()
	await _frames(50)
	await _shot("24_demo_solucion")
	print("DEMO titulo=«%s» izquierda=«%s» derecha=«%s»" % [demo.title.text, demo.button_label(demo.left_button), demo.button_label(demo.right_button)])
	# La explicación, nivel a nivel: el concepto, la variante (jugada en el tablero) y las cifras del motor.
	for deeper in 3:
		demo._on_why()
		await _frames(8)
		await _shot("24%s_demo_nivel_%d" % ["bcd"[deeper], deeper + 2])
	print("DEMO nivel=%d flechas=%d alto de la tarjeta=%d" % [demo.exp_level, dview.board._arrows_root.get_child_count(), int(demo.card.size.y)])
	demo.card_scroll.scroll_vertical = 100000
	await _frames(3)
	await _shot("24e_demo_nivel_4_final")
	demo.card_scroll.scroll_vertical = 0
	var shown_levels: Array = demo.expl.get("levels", [])
	if shown_levels.size() == 4 and not (shown_levels[2]["lines"] as Array).is_empty():
		demo._step_line(shown_levels[2]["lines"][0], 0)
		await _frames(12)
		await _shot("24f_demo_variante")
		demo._leave_line()
		await _frames(3)
	# «¿Y si juego…?»: se prueba otra jugada en la posición de la decisión.
	demo._toggle_whatif()
	await _frames(6)
	await _shot("24g_demo_y_si_juego")
	var other := _wrong_move(dview.board.chess, demo.explain.point_solution(demo.exp_point))
	if other != "":
		_tap(dview, _sq(other.substr(0, 2)))
		await _frames(3)
		_tap(dview, _sq(other.substr(2, 2)))
		await _frames(22)
		await _shot("24h_demo_y_si_juego_jugada")
		print("DEMO y si juego %s: titulo=«%s» interactivo=%s" % [other, demo.title.text, str(dview.interactive)])
	# «Pregunta a una IA»: el texto que se lleva, con la posición y el análisis.
	demo._open_ai()
	await _frames(8)
	await _shot("24i_demo_pregunta_a_una_ia")
	print("DEMO texto para la IA: %d caracteres, empieza «%s»" % [demo._ai_text().length(), demo._ai_text().substr(0, 60)])
	demo._close_options()
	demo._toggle_whatif()
	await _frames(4)
	print("DEMO lichess=%s" % demo._lichess_url(demo._decision_fen()))
	# Opciones en hoja inferior, en claro y en oscuro.
	demo._open_options()
	await _frames(6)
	await _shot("25_demo_opciones")
	demo._set_dark(true)
	await _frames(5)
	await _shot("26_demo_opciones_oscuro")
	demo._close_options()
	await _frames(3)
	await _shot("27_demo_oscuro")
	demo._on_toggle_view()
	await _frames(12)
	await _shot("28_demo_oscuro_picado")
	# «Repetir»: el mismo problema desde el principio.
	demo._on_left()
	await _frames(30)
	await _shot("29_demo_repetido")
	print("DEMO titulo=«%s» paso=%d problema=%d" % [demo.title.text, demo.step, demo.index])

	# Pellizco con dos dedos: el tablero se amplía y puede ser más ancho que la pantalla.
	# (Antes, de vuelta al tema claro y a la vista inclinada.)
	demo._set_dark(false)
	demo._on_toggle_view()
	await _frames(20)
	dview.board.deselect()
	var c := dview.get_global_rect().get_center()
	_touch(0, c + Vector2(-90.0, 0.0), true)
	_touch(1, c + Vector2(90.0, 0.0), true)
	for i in 8:
		var off := 90.0 + 13.0 * float(i + 1)
		_drag(0, c + Vector2(-off, 0.0), Vector2(-13.0, 0.0))
		_drag(1, c + Vector2(off, 0.0), Vector2(13.0, 0.0))
		await _frames(1)
	_touch(0, c + Vector2(-194.0, 0.0), false)
	_touch(1, c + Vector2(194.0, 0.0), false)
	await _frames(3)
	await _shot("30_demo_ampliado")
	print("DEMO ampliado zoom=%.2f desplazamiento=%s" % [dview.board.zoom, str(dview.board.pan)])
	# Con el tablero ampliado, un dedo que arrastra desde una casilla sin pieza propia lo desplaza.
	var empty := -1
	for s in 64:
		if dview.board.chess.b[s] == 0 and (s & 7) >= 2 and (s & 7) <= 5 and (s >> 3) >= 2 and (s >> 3) <= 5:
			empty = s
			break
	dview.board.deselect()
	var from: Vector2 = dview.get_global_transform() * dview.view_to_local(dview.board.camera.unproject_position(Board3D.sq_pos(empty)))
	_touch(0, from, true)
	for i in 10:
		_drag(0, from + Vector2(26.0 * float(i + 1), 12.0 * float(i + 1)), Vector2(26.0, 12.0))
		await _frames(1)
	_touch(0, from + Vector2(260.0, 120.0), false)
	await _frames(3)
	await _shot("31_demo_desplazado")
	print("DEMO desplazado zoom=%.2f desplazamiento=%s seleccionada=%d" % [dview.board.zoom, str(dview.board.pan), dview.board.selected])
	# El botón de vista devuelve el tablero a su tamaño.
	demo._on_toggle_view()
	await _frames(16)
	await _shot("32_demo_entero_otra_vez")
	print("DEMO entero zoom=%.2f desplazamiento=%s picado=%s" % [dview.board.zoom, str(dview.board.pan), str(demo.top_view)])
	# Problema resuelto: la explicación de la solución. Se resuelve entero con toques.
	demo._on_right()
	await _frames(34)
	var guard := 0
	while demo.phase != 4 and guard < 8:
		guard += 1
		if demo.phase == 1 and dview.interactive and demo.step < demo.puzzle["moves"].size():
			var next_move := str(demo.puzzle["moves"][demo.step])
			_tap(dview, _sq(next_move.substr(0, 2)))
			await _frames(3)
			_tap(dview, _sq(next_move.substr(2, 2)))
		await _frames(34)
	await _frames(20)
	await _shot("33_demo_resuelto")
	print("DEMO resuelto: fase=%d titulo=«%s» problema=%d" % [demo.phase, demo.title.text, demo.index])
	demo._on_why()
	await _frames(10)
	await _shot("34_demo_resuelto_por_que")
	# Con fichas, y la bienvenida.
	demo._set_pieces_index(1)
	await _frames(6)
	await _shot("35_demo_fichas")
	demo._on_right()
	await _frames(40)
	await _shot("36_demo_fichas_problema")
	demo._open_options()
	await _frames(8)
	await _shot("37_demo_opciones_fichas")
	demo.sheet_scroll.scroll_vertical = 100000
	await _frames(3)
	await _shot("37b_demo_opciones_final")
	demo._close_options()
	await _help_shots(demo)
	await _level_shots(demo)
	demo._open_welcome()
	await _frames(6)
	await _shot("38_demo_bienvenida")
	demo._set_dark(true)
	await _frames(6)
	demo._open_welcome()
	await _frames(6)
	await _shot("39_demo_bienvenida_oscuro")
	demo._close_welcome()
	Engine.time_scale = 1.0


## Pista, «Un paso», la chincheta del giro y el giro con dos dedos.
func _help_shots(demo: Control) -> void:
	var dview: BoardView3D = demo.view
	demo._set_pieces_index(0)
	demo._on_right()
	await _frames(40)
	# Pista: primero el tema; después, además, la pieza (queda elegida en el tablero).
	demo._on_hint()
	await _frames(10)
	await _shot("40_demo_pista")
	demo._on_hint()
	await _frames(10)
	await _shot("41_demo_pista_pieza")
	var expected := str(demo.puzzle["moves"][demo.ask_step]).substr(0, 2)
	print("AYUDA pista nivel=%d pieza elegida=%d (esperada %d) fase=%d" % [demo.hint_level, dview.board.selected, _sq(expected), demo.phase])
	# Un paso: se juega solo esa jugada, con su explicación; «Seguir» devuelve el turno al jugador.
	var before_step: int = demo.step
	demo._on_step()
	await _frames(26)
	await _shot("42_demo_un_paso")
	print("AYUDA un paso: fase=%d titulo=«%s» paso %d→%d botones=«%s» «%s»" % [demo.phase, demo.title.text, before_step, demo.step, demo.button_label(demo.left_button), demo.button_label(demo.right_button)])
	if demo.phase == 7:
		demo._on_why()
		await _frames(10)
		await _shot("43_demo_un_paso_por_que")
		demo._on_right()
		await _frames(40)
		await _shot("44_demo_tras_el_paso")
		print("AYUDA tras seguir: fase=%d titulo=«%s» paso=%d interactivo=%s" % [demo.phase, demo.title.text, demo.step, str(dview.interactive)])
	# Chincheta: con el giro fijado, girar dos dedos no mueve el tablero; al soltarla, sí (y hacia el mismo lado).
	demo._set_gesture_hint(true)
	await _frames(4)
	demo._on_toggle_pin()
	await _frames(6)
	await _shot("45_demo_giro_fijado")
	var c := dview.get_global_rect().get_center()
	await _twist(c, 150.0, 0.0, 30.0)
	print("AYUDA giro fijado=%s: tras girar dos dedos 30°, giro=%.1f pista de gestos=%s" % [str(dview.view_locked), dview.board.cam_yaw, str(demo.gesture_hint)])
	demo._on_toggle_pin()
	await _frames(4)
	await _twist(c, 150.0, 0.0, 30.0)
	await _frames(4)
	await _shot("46_demo_girado_con_dos_dedos")
	print("AYUDA giro libre: tras girar dos dedos 30° a la derecha, giro=%.1f inclinación=%.1f pista de gestos=%s" % [dview.board.cam_yaw, dview.board.cam_pitch, str(demo.gesture_hint)])
	# Casi derecho al soltar: se endereza solo.
	await _twist(c, 150.0, 30.0, 5.0)
	await _frames(12)
	print("AYUDA casi derecho al soltar: giro=%.1f" % dview.board.cam_yaw)
	await _shot("47_demo_enderezado")


## El test de nivel, de principio a fin: experiencia, problemas con un solo intento, resultado con perfil y
## plan, y el entrenamiento adaptado. Dos problemas se contestan con toques de verdad (uno mal y otro bien);
## el resto del test se completa con respuestas fijas por el mismo camino de anotación.
func _level_shots(demo: Control) -> void:
	var dview: BoardView3D = demo.view
	demo._open_experience()
	await _frames(8)
	await _shot("50_experiencia")
	demo._start_test("casual")
	await _frames(40)
	await _shot("51_test_problema")
	print("NIVEL test: modo=%s fase=%d contador=«%s» botón=«%s» problema=%s dificultad=%d" % [demo.mode, demo.phase, demo.counter.text, demo.button_label(demo.left_button), str(demo.puzzle["id"]), int(demo.puzzle["rating"])])
	# Primer problema: una jugada equivocada. Un solo intento: se explica y se pasa al siguiente.
	var wrong := _wrong_move(dview.board.chess, str(demo.puzzle["moves"][1]))
	_tap(dview, _sq(wrong.substr(0, 2)))
	await _frames(3)
	_tap(dview, _sq(wrong.substr(2, 2)))
	await _frames(30)
	await _shot("52_test_fallo")
	var first: Dictionary = (demo.player["tries"] as Array).back()
	print("NIVEL fallo %s: fase=%d anotados=%d error=«%s» paso=%d tiempo=%d ms nivel=%.0f±%.0f botón=«%s»" % [wrong, demo.phase, (demo.player["tries"] as Array).size(), str(first["error"]), int(first["failStep"]), int(first["msFirst"]), float(demo.player["rating"]["r"]), float(demo.player["rating"]["rd"]), demo.button_label(demo.right_button)])
	# Segundo problema: resuelto entero con toques.
	demo._on_right()
	await _frames(40)
	var guard := 0
	while demo.phase != 4 and guard < 8:
		guard += 1
		if demo.phase == 1 and dview.interactive and demo.step < demo.puzzle["moves"].size():
			var next_move := str(demo.puzzle["moves"][demo.step])
			_tap(dview, _sq(next_move.substr(0, 2)))
			await _frames(3)
			_tap(dview, _sq(next_move.substr(2, 2)))
		await _frames(34)
	await _frames(10)
	await _shot("53_test_acierto")
	var second: Dictionary = (demo.player["tries"] as Array).back()
	print("NIVEL acierto: fase=%d anotados=%d correcto=%s nivel=%.0f±%.0f" % [demo.phase, (demo.player["tries"] as Array).size(), str(second["correct"]), float(demo.player["rating"]["r"]), float(demo.player["rating"]["rd"])])
	# Tercero: «No lo sé».
	demo._on_right()
	await _frames(40)
	demo._on_left()
	await _frames(60)
	await _shot("54_test_no_lo_se")
	var third: Dictionary = (demo.player["tries"] as Array).back()
	print("NIVEL no lo sé: fase=%d anotados=%d ayuda=«%s» titulo=«%s»" % [demo.phase, (demo.player["tries"] as Array).size(), str(third["help"]), demo.title.text])
	# El resto del test, con respuestas fijas: falla los mates y los problemas largos, y acierta lo demás.
	var kinds := ["mate", "hangMoved", "hangOther", "missed"]
	var i := 0
	while not bool(demo.player["done"]):
		var item: Dictionary = Assessment.next_test_item(demo.player, demo.pool, 0.5)
		if item.is_empty():
			break
		var fails: bool = bool(item["mate"]) or int(item["steps"]) >= 3
		var outcome := {"correct": not fails, "failStep": (1 if int(item["steps"]) >= 3 else 0) if fails else -1, "error": kinds[i % kinds.size()] if fails else "", "help": "", "msFirst": 4000.0 if fails else 21000.0, "ms": 30000.0}
		demo.player = Assessment.record_try(demo.player, item, outcome, "test")
		i += 1
	demo._finish_test()
	await _frames(10)
	await _shot("55_resultado")
	var pr: Dictionary = Assessment.profile(demo.player["tries"])
	var todo: Dictionary = Assessment.plan(demo.player["rating"], pr)
	print("NIVEL resultado: problemas=%d nivel=%.0f±%.0f mates=%d/%d largos=%d/%d fallos=%d respuesta=%d precipitados=%d plan=%s hábitos=%s modo=%s página=%s" % [(demo.player["tries"] as Array).size(), float(demo.player["rating"]["r"]), float(demo.player["rating"]["rd"]), int(pr["mate"]["correct"]), int(pr["mate"]["n"]), int(pr["long"]["correct"]), int(pr["long"]["n"]), int(pr["fails"]), int(pr["replyBlind"]), int(pr["time"]["rushed"]), str(todo["focus"]), str(todo["habits"]), demo.mode, demo.progress_kind])
	demo.progress_scroll.scroll_vertical = 700
	await _frames(3)
	await _shot("55b_resultado_perfil")
	demo.progress_scroll.scroll_vertical = 100000
	await _frames(3)
	await _shot("55c_resultado_plan")
	# Entrenamiento: el problema lo elige el nivel y el perfil; al terminar se ve cómo cambia el nivel.
	demo._start_training()
	await _frames(40)
	await _shot("56_entrenamiento")
	print("NIVEL entrenamiento: modo=%s problema=%s dificultad=%d (objetivo %.0f) píldora=«%s» visible=%s" % [demo.mode, str(demo.puzzle["id"]), int(demo.puzzle["rating"]), float(todo["target"]), (demo.level_pill.get_meta("label_node") as Label).text, str(demo.level_pill.visible)])
	guard = 0
	while demo.phase != 4 and guard < 8:
		guard += 1
		if demo.phase == 1 and dview.interactive and demo.step < demo.puzzle["moves"].size():
			var move := str(demo.puzzle["moves"][demo.step])
			_tap(dview, _sq(move.substr(0, 2)))
			await _frames(3)
			_tap(dview, _sq(move.substr(2, 2)))
		await _frames(34)
	await _frames(10)
	await _shot("57_entrenamiento_resuelto")
	print("NIVEL tras resolver: fase=%d anotados=%d cambio=%s" % [demo.phase, (demo.player["tries"] as Array).size(), str(demo._rating_shown)])
	demo._open_progress("progress")
	await _frames(8)
	await _shot("58_progreso")
	demo._close_progress()
	demo._set_dark(true)
	await _frames(6)
	demo._open_progress("progress")
	await _frames(8)
	await _shot("59_progreso_oscuro")
	demo._open_experience()
	await _frames(8)
	await _shot("59b_experiencia_oscuro")
	demo._close_progress()
	demo._set_dark(false)
	await _frames(6)


## Dos dedos que giran alrededor de un punto, de un ángulo a otro (grados; positivo = a la derecha, como las agujas del reloj).
func _twist(c: Vector2, radius: float, from_deg: float, to_deg: float) -> void:
	var at := func(deg: float, side: float) -> Vector2:
		return c + Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * radius * side
	_touch(0, at.call(from_deg, -1.0), true)
	_touch(1, at.call(from_deg, 1.0), true)
	var steps := 10
	var prev := from_deg
	for i in steps:
		var deg := lerpf(from_deg, to_deg, float(i + 1) / float(steps))
		_drag(0, at.call(deg, -1.0), at.call(deg, -1.0) - at.call(prev, -1.0))
		_drag(1, at.call(deg, 1.0), at.call(deg, 1.0) - at.call(prev, 1.0))
		prev = deg
		await _frames(1)
	_touch(0, at.call(to_deg, -1.0), false)
	_touch(1, at.call(to_deg, 1.0), false)


func _touch(index: int, canvas_pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = canvas_pos
	e.pressed = pressed
	get_viewport().push_input(e, true)


func _drag(index: int, canvas_pos: Vector2, relative: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = canvas_pos
	e.relative = relative
	get_viewport().push_input(e, true)


func _tap(v: BoardView3D, square: int) -> void:
	var in_view := v.board.camera.unproject_position(Board3D.sq_pos(square) + Vector3(0.0, 0.3, 0.0))
	var canvas_pos: Vector2 = v.get_global_transform() * v.view_to_local(in_view)
	for pressed: bool in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = canvas_pos
		e.pressed = pressed
		get_viewport().push_input(e, true)

