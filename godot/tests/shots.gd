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
	view = BoardView3D.new()
	view.position = Vector2(0.0, (size.y - size.x) * 0.5)
	view.size = Vector2(size.x, size.x)
	add_child(view)
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
	board.set_theme("dark")
	bg.color = Color("0a0f1e")
	await _frames(3)
	await _shot("06_oscuro")
	board.set_theme("light")
	bg.color = Color("eaf1fb")

	# Con negras.
	view.set_orientation(1)
	await _frames(3)
	await _shot("07_negras")
	view.set_orientation(0)

	# Primer plano para juzgar formas y materiales.
	view.set_fen(Board3D.START_FEN)
	var eye := Vector3(2.9, 2.3, 6.9)
	board.camera.transform = Transform3D(Basis.looking_at(Vector3(0.2, 0.55, 2.7) - eye, Vector3.UP), eye)
	await _frames(3)
	await _shot("08_primer_plano")
	eye = Vector3(-2.4, 1.6, -0.6)
	board.camera.transform = Transform3D(Basis.looking_at(Vector3(0.6, 0.6, -3.3) - eye, Vector3.UP), eye)
	await _frames(3)
	await _shot("09_primer_plano_negras")
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
	await _frames(20)
	view.set_fen(MID_FEN)
	await _frames(2)
	if view.show_move("e1c1"):
		await _frames(11)
		await _shot("12_enroque")
		await _frames(20)
	view.set_fen(PROMO_FEN)
	await _frames(2)
	view.show_move("e7e8q")
	await _frames(13)
	await _shot("13_promocion")
	await _frames(20)
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
	var canvas := get_viewport().get_visible_rect().size
	board.drag_piece(_sq("g1"), Vector2(canvas.x * 0.62, canvas.x * 0.6))
	await _frames(3)
	await _shot("16_arrastre")
