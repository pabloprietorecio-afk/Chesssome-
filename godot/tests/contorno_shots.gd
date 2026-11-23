extends SceneTree
## Tres contornos para las piezas negras: actual, más fino y brillo suave (para elegir).
## Uso: OUTLINE=actual|fino|brillo SHOTS_DIR=/tmp/o xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --resolution 1080x2400 -s tests/contorno_shots.gd

const FEN := "r1bq1rk1/pp2bppp/2n1pn2/3p4/2PP4/2N1PN2/PP1B1PPP/R2QKB1R w KQ - 2 8"
const GLOW := "shader_type spatial;\nrender_mode unshaded, cull_front, shadows_disabled, blend_mix, depth_draw_never;\nuniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);\nuniform float width = 0.05;\ninstance uniform float glow = 0.0;\nvoid vertex() { VERTEX += NORMAL * width; }\nvoid fragment() { ALBEDO = outline_color.rgb; ALPHA = 0.38; }\n"


func _initialize() -> void:
	var out := OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var mode := OS.get_environment("OUTLINE")
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	for i in 20:
		await process_frame
	demo._start_game({"variant": "", "level": 3, "title": "Partida", "text": "", "kids": "", "unit": "", "clock": []}, 0)
	for i in 10:
		await process_frame
	demo.view.set_fen(FEN)
	for i in 5:
		await process_frame
	var mats: Array = demo.view.board._outline_mats
	match mode:
		"fino":
			for m: ShaderMaterial in mats:
				m.set_shader_parameter("width", 0.011)
		"brillo":
			var sh := Shader.new()
			sh.code = GLOW
			mats[1].shader = sh
			mats[1].set_shader_parameter("outline_color", Color("ffcc33"))
			mats[1].set_shader_parameter("width", 0.06)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("contorno_" + mode + ".png"))
	print("captura ", mode)
	quit()
