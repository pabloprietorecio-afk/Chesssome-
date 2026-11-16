extends Node
## Capturas de la app en varios idiomas: inicio con el tablerito-bandera, la hoja de idiomas y Opciones.
## Uso: SHOTS_DIR=… LANGS=en,ja xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile res://tests/idiomas.tscn

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_environment("SHOTS_DIR")
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("idiomas")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var langs := OS.get_environment("LANGS")
	var list: Array = Array(langs.split(",")) if langs != "" else Loc.LANGUAGES.duplicate()
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	add_child(demo)
	await _frames(20)
	var p: Dictionary = Assessment.start_test("never")
	p["done"] = true
	p["rating"]["r"] = 1272.0
	demo.player = p
	for code: String in list:
		demo._set_language(code)
		await _frames(6)
		demo._open_home()
		await _frames(8)
		await _shot("%s_1_inicio" % code)
		demo._open_language(false)
		await _frames(6)
		await _shot("%s_2_idiomas" % code)
		demo._close_options()
		demo._open_options()
		await _frames(6)
		await _shot("%s_3_opciones" % code)
		demo._close_options()
		if OS.get_environment("MAS") != "":
			demo._open_course()
			await _frames(8)
			await _shot("%s_4_curso" % code)
			demo._open_game_setup()
			await _frames(8)
			await _shot("%s_5_partida" % code)
			demo._go_home_now()
			demo._open_train_hub()
			await _frames(4)
			var idx := 0
			for i in demo.puzzles.size():
				if str(demo.puzzles[i]["id"]) == "IBanZ":
					idx = i
			demo.view.board.anim_mode = Board3D.Anim.NONE
			demo._start(idx)
			await _frames(12)
			await _shot("%s_6_problema" % code)
			demo._show_solution()
			await get_tree().create_timer(1.5).timeout
			await _frames(6)
			await _shot("%s_7_solucion" % code)
			demo._go_home_now()
			await _frames(4)
	print("HECHO")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)
