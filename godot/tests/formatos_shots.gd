extends SceneTree
## Capturas de la elección de formato y ritmo del Campeonato y de la clasificación (para revisarlas).
## Uso: SHOTS_DIR=/tmp/f xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --resolution 1080x2400 -s tests/formatos_shots.gd

var out := ""


func _initialize() -> void:
	out = OS.get_environment("SHOTS_DIR")
	if out == "":
		out = OS.get_user_data_dir().path_join("formatos_shots")
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
	demo._open_campeonato()
	await _frames(10)
	await _shot("f1_salas")
	demo._open_campeonato_room("club")
	await _frames(10)
	await _shot("f2_elegir_arriba")
	demo.progress_scroll.scroll_vertical = 100000
	await _frames(5)
	await _shot("f3_elegir_abajo")
	demo._camp_set_format("club", "liga")
	demo._camp_set_tc(7, "club")
	await _frames(10)
	demo.progress_scroll.scroll_vertical = 100000
	await _frames(5)
	await _shot("f4_liga_otro")
	demo._campeonato_new("club")
	await _frames(5)
	var w: Node = demo.get_node_or_null("CampeonatoPaseo")
	if w != null:
		w.queue_free()
	var st: Dictionary = demo.campeonato_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for s: float in [1.0, 0.5, 0.0]:
		Campeonato.record(st, "club", s, rng)
	demo._open_campeonato_room("club", "Partida apuntada. Siguiente: Ronda 4.")
	await _frames(10)
	await _shot("f5_liga_en_juego")
	demo.progress_scroll.scroll_vertical = 100000
	await _frames(5)
	await _shot("f6_liga_en_juego_abajo")
	demo.camp_fmt = "copa_match"
	demo.camp_tc = 0
	demo._campeonato_new("club")
	await _frames(5)
	w = demo.get_node_or_null("CampeonatoPaseo")
	if w != null:
		w.queue_free()
	Campeonato.record(st, "club", 1.0, rng)
	demo._open_campeonato_room("club", "Primera partida del mini-match jugada. Ahora, la segunda, con los colores cambiados.")
	await _frames(10)
	await _shot("f7_mini_match")
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
