extends Node
## Vídeo de muestra de las animaciones con carácter: cada pieza se mueve y come una vez.
## Uso: xvfb-run godot --path godot --rendering-driver opengl3 --fixed-fps 30 --resolution 540x960 \
##        --write-movie /tmp/anim/f.png res://tests/anim_demo.tscn
## Variables de entorno: ANIM_SET = juego de piezas ("clasico" por defecto, "fichas", "piratas"…); ANIM_PITCH = inclinación.

# Posición preparada para que las seis piezas blancas tengan una jugada tranquila y una captura.
const FEN := "4k3/6p1/2p1p3/3p1p2/1n5r/2NpP3/P1PBQPPP/R3K3 w - - 0 1"
# Negras solo mueven el rey de un lado a otro para devolver el turno.
const LINE := ["a2a3", "e8d8", "a3b4", "d8e8", "c3d5", "e8d8", "d5e7", "d8e8", "d2c3", "e8d8", "c3g7", "d8e8", "e2f3", "e8d8", "f3f5", "d8e8", "a1a6", "e8d8", "a6c6", "d8e8", "e1d2", "e8d8", "d2d3", "d8e8"]

var view: BoardView3D


func _ready() -> void:
	var size := get_viewport().get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color("eaf1fb")
	bg.size = size
	add_child(bg)
	view = BoardView3D.new()
	var h := minf(size.y, size.x * 1.25)
	view.position = Vector2(0.0, (size.y - h) * 0.5)
	view.size = Vector2(size.x, h)
	view.set_board_theme("light", bg.color)
	add_child(view)
	var wanted := OS.get_environment("ANIM_SET")
	view.set_piece_set(wanted if wanted != "" else "clasico")
	view.set_board_style("madera", true)
	view.board.anim_mode = Board3D.Anim.FULL
	view.set_fen(FEN)
	view.board.set_view(float(OS.get_environment("ANIM_PITCH")) if OS.get_environment("ANIM_PITCH") != "" else 48.0, 0.0)
	await _frames(20)
	for text: String in LINE:
		var m := view.board.chess.find_uci(text.trim_suffix("x"))
		if m < 0:
			print("ANIM jugada ilegal: ", text)
			continue
		view.board.play_move(m)
		# Las jugadas de relleno de las negras, deprisa; las blancas, con pausa para verlas.
		await _frames(8 if text.begins_with("e8") or text.begins_with("d8") else int(OS.get_environment("ANIM_WAIT")) if OS.get_environment("ANIM_WAIT") != "" else 44)
	await _frames(15)
	print("ANIM DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
