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
