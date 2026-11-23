extends SceneTree
## Graba la animación del cuadro de la copa (3 rondas ganadas seguidas).
## Uso: xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --resolution 540x1200 --write-movie /tmp/cuadro.avi --fixed-fps 30 -s tests/cuadro_video.gd


func _initialize() -> void:
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
	Campeonato.start(st, "centro_civico", 1400.0, rng, "copa")
	Campeonato.record(st, "centro_civico", 1.0, rng)
	demo._open_campeonato_room("centro_civico", "¡Has ganado! Siguiente ronda: Semifinal.", true)
	await create_timer(9.0).timeout
	Campeonato.record(st, "centro_civico", 1.0, rng)
	demo._open_campeonato_room("centro_civico", "¡Has ganado! Siguiente ronda: Final.", true)
	await create_timer(8.0).timeout
	Campeonato.record(st, "centro_civico", 1.0, rng)
	demo._open_campeonato_room("centro_civico", "¡Campeón!", true)
	await create_timer(8.0).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
