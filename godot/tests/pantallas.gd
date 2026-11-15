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
	demo._open_online_home()
	await _frames(8)
	await _shot("p4_online")
	demo.online_busy = true
	demo._open_online()
	await _frames(8)
	await _shot("p5_online_buscando")
	demo.online_busy = false
	demo._close_progress()
	print("PANTALLAS DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)
