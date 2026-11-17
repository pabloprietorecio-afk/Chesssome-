extends "res://tests/shots.gd"
## Capturas de War Chess: escudos, casilla roja, el botón «Blindar» y los fotogramas del golpe al blindaje.
## Uso: xvfb-run godot --path godot --fixed-fps 30 res://tests/war_shots.tscn  (SHOTS_DIR = carpeta de salida)


func _run() -> void:
	var board := view.board
	board.anim_mode = Board3D.Anim.NONE
	board.set_fen("r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4 war:e4.c6.f6:e4.c6.f6")
	await _frames(8)
	await _shot("war_01_blindadas")
	# El botón «Blindar» sobre la pieza seleccionada.
	board.select(_sq("c4"))
	await _frames(4)
	await _shot("war_02_boton")
	board.deselect()
	# Golpe: Cxe5? No: Cf3 ataca e5 (sin blindaje); Ac4 ataca f7. Se prepara un golpe del alfil al caballo de f6.
	board.set_fen("r1bqkb1r/pppp1ppp/2n2n2/4p1B1/4P3/2N5/PPPP1PPP/R2QKBNR w KQkq - 4 4 war:f6:f6")
	await _frames(6)
	board.select(_sq("g5"))
	await _frames(3)
	await _shot("war_03_marca_golpe")
	board.deselect()
	board.anim_mode = Board3D.Anim.FULL
	view.show_move("g5f6")
	for i in 14:
		await _shot("war_04_golpe_%02d" % i)
	await _frames(10)
	await _shot("war_05_despues")
	# Blindarse.
	view.show_move("d7d7")
	for i in 10:
		await _shot("war_06_blindarse_%02d" % i)
	await _frames(10)
	await _shot("war_07_blindado")
	# Peón atrincherado: escudo reforzado; el golpe de la torre lo agrieta y aguanta.
	board.anim_mode = Board3D.Anim.NONE
	board.set_fen("4k3/8/4n3/3p4/8/8/3R4/4K3 w - - 0 1 war:d5.e6:d5.e6:-:-")
	await _frames(6)
	await _shot("war_09_peon_reforzado")
	board.anim_mode = Board3D.Anim.FULL
	view.show_move("d2d5")
	for i in 8:
		await _shot("war_10_agrieta_%02d" % i)
	await _frames(10)
	await _shot("war_11_agrietado")
	# Tema oscuro.
	view.set_board_theme("dark", Color("0f1529"))
	bg.color = Color("0f1529")
	await _frames(4)
	await _shot("war_08_oscuro")
