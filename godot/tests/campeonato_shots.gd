extends SceneTree
## Capturas del modo Campeonato (para revisarlas): lista de salas, cuadro, paseo y tarjeta del rival.
## Uso: xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --resolution 1080x2400 -s tests/campeonato_shots.gd

var out := ""


func _initialize() -> void:
	out = OS.get_environment("SHOTS_DIR")
	if out == "":
		out = OS.get_user_data_dir().path_join("campeonato_shots")
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(20)
	var p: Dictionary = Assessment.start_test("never")
	p["done"] = true
	p["rating"]["r"] = 1272.0
	demo.player = p
	demo.home_style = "rejilla"
	demo._open_home()
	await _frames(10)
	await _shot("c0_inicio_rejilla")
	demo.home_style = "lista"
	demo._open_home()
	await _frames(10)
	await _shot("c0_inicio_lista")
	demo._open_campeonato()
	await _frames(10)
	await _shot("c1_salas")
	demo._open_campeonato_room("escuela")
	await _frames(10)
	await _shot("c2_sala_antes")
	demo._campeonato_new("escuela")
	await _frames(40)
	await _shot("c3_paseo_entrada")
	await create_timer(3.6).timeout
	await _shot("c4_paseo_pasillo")
	await create_timer(5.0).timeout
	await _frames(10)
	await _shot("c5_rival")
	var walk: Node = demo.get_node_or_null("CampeonatoPaseo")
	if walk != null:
		walk.queue_free()
	var t: Dictionary = demo.campeonato_state()["torneos"]["escuela"]
	Campeonato.record(demo.campeonato_state(), "escuela", 1.0, RandomNumberGenerator.new())
	demo._open_campeonato_room("escuela", "¡Has ganado! Pasas a la semifinal.")
	await _frames(10)
	await _shot("c6_cuadro")
	demo._campeonato_start_game("escuela", 3)
	await _frames(30)
	await _shot("c7_partida")
	demo.game_state = "think"
	demo._refresh()
	await _frames(20)
	await _shot("c8_piensa")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	quit()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("captura ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
