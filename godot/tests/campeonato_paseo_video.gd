extends SceneTree
## Graba el paseo del Campeonato (entrada → pasillo → rival con su tarjeta), para revisarlo.
## Uso: xvfb-run godot --path godot --write-movie /tmp/paseo.avi --fixed-fps 30 --resolution 720x1600 -s tests/campeonato_paseo_video.gd

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	for i in 20:
		await process_frame
	demo._campeonato_new(OS.get_environment("SALA") if OS.get_environment("SALA") != "" else "escuela")
	await create_timer(float(OS.get_environment("SEGUNDOS")) if OS.get_environment("SEGUNDOS") != "" else 16.0).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	quit()
