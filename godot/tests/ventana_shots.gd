extends SceneTree
## Capturas de las ventanas de formato y ritmo del Campeonato y de la explicación de un formato.
## Uso: SHOTS_DIR=/tmp/v xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --resolution 1080x2400 -s tests/ventana_shots.gd

func _initialize() -> void:
	var out := OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	for i in 20:
		await process_frame
	demo._open_campeonato_room("club")
	for i in 10:
		await process_frame
	demo._campeonato_options("club")
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("v1_ventana.png"))
	demo._camp_format_info("club", "copa_match")
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("v2_info.png"))
	demo._camp_set_format("club", "liga")
	demo._campeonato_options("club")
	demo._camp_set_tc(7, "club")
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("v3_otro.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	quit()
