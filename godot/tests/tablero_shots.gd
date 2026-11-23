extends SceneTree
## Capturas del tablero (acabado y piezas) en una partida a mitad de juego, para comparar aspectos.
## Uso: SHOTS_DIR=/tmp/t SHOT_NAME=madera xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --resolution 1080x2400 -s tests/tablero_shots.gd
## SHOT_STYLE: madera, marmol, metal o ilustrado (madera si no se dice).

const FEN := "r1bq1rk1/pp2bppp/2n1pn2/3p4/2PP4/2N1PN2/PP1B1PPP/R2QKB1R w KQ - 2 8"


func _initialize() -> void:
	var out := OS.get_environment("SHOTS_DIR")
	if out == "":
		out = OS.get_user_data_dir().path_join("tablero_shots")
	DirAccess.make_dir_recursive_absolute(out)
	var name := OS.get_environment("SHOT_NAME")
	if name == "":
		name = "tablero"
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	for i in 20:
		await process_frame
	var style := OS.get_environment("SHOT_STYLE")
	if style != "":
		demo.board_style = style
		demo.view.board.set_style(style)
	demo._start_game({"variant": "", "level": 3, "title": "Partida", "text": "", "kids": "", "unit": "", "clock": []}, 0)
	for i in 10:
		await process_frame
	demo.view.set_fen(FEN)
	for i in 30:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("captura ", name)
	quit()
