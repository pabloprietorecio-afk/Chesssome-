extends SceneTree
## Capturas de la animación al volver al torneo tras una partida (para revisarla).
## Uso: SHOTS_DIR=/tmp/a xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --resolution 1080x2400 -s tests/animacion_shots.gd

var out := ""


func _initialize() -> void:
	out = OS.get_environment("SHOTS_DIR")
	if out == "":
		out = OS.get_user_data_dir().path_join("animacion_shots")
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
	var st: Dictionary = demo.campeonato_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Copa: ganas los cuartos y vuelves al cuadro.
	Campeonato.start(st, "centro_civico", 1400.0, rng, "copa")
	Campeonato.record(st, "centro_civico", 1.0, rng)
	demo._open_campeonato_room("centro_civico", "¡Has ganado! Siguiente ronda: Semifinal.", true)
	for t: float in [0.4, 1.6, 4.5, 7.0]:
		await create_timer(t if t == 0.4 else 0.0).timeout
	await _shot_at("a1_copa_inicio", 0.4)
	await _shot_at("a2_copa_derrotas", 1.8)
	await _shot_at("a3_copa_nuevos", 4.0)
	await _shot_at("a4_copa_final", 3.0)
	# Liga: tablas en la ronda 3 y vuelta.
	Campeonato.start(st, "club", 1400.0, rng, "liga")
	Campeonato.record(st, "club", 1.0, rng)
	Campeonato.record(st, "club", 0.5, rng)
	demo._open_campeonato_room("club", "Partida apuntada. Siguiente: Ronda 3.", true)
	await _shot_at("a5_liga_inicio", 0.3)
	await _shot_at("a6_liga_resultados", 2.0)
	await _shot_at("a7_liga_clasif", 3.0)
	await _shot_at("a8_liga_nuevos", 4.5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	quit()


func _shot_at(name: String, wait: float) -> void:
	await create_timer(wait).timeout
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("captura ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
