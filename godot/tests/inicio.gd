extends Node
## Capturas de las dos pantallas de inicio (lista y rejilla), en claro y en oscuro, con jugador y sin él.
## Salida: SHOTS_DIR. También comprueba que nada necesita desplazamiento a este tamaño (líneas «CABE»).
## Uso: xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile --resolution 1080x2400 res://tests/inicio.tscn

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_environment("SHOTS_DIR")
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("inicio")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	add_child(demo)
	await _frames(20)
	var lang := OS.get_environment("IDIOMA")
	if lang != "":
		demo.language = lang
		Loc.apply(lang)
	var only := OS.get_environment("SOLO")
	for with_player: bool in [true, false]:
		if with_player:
			# Un jugador de nivel 6 a media subida, con racha y partidas, como el del diseño.
			var p: Dictionary = Assessment.start_test("never")
			p["done"] = true
			p["rating"]["r"] = 1451.0
			demo.player = p
		else:
			demo.player = {}
		for style: String in HomeScreens.STYLES:
			for dark: bool in [false, true]:
				var shot_name := "inicio_%s_%s%s" % [style, "oscuro" if dark else "claro", "" if with_player else "_nuevo"]
				if only != "" and not shot_name.contains(only):
					continue
				demo.home_style = style
				demo.dark = dark
				demo._open_home()
				await _frames(6)
				var scroll: ScrollContainer = demo.progress_scroll
				var inner: Control = scroll.get_child(0) if scroll != null and scroll.get_child_count() > 0 else null
				var need := inner.get_combined_minimum_size().y if inner != null else 0.0
				var have := scroll.size.y if scroll != null else 0.0
				print("CABE %s: necesita %d, hay %d -> %s" % [shot_name, int(need), int(have), "sí" if need <= have + 0.5 else "NO"])
				await _shot(shot_name)
	# Opciones, con el selector «Pantalla de inicio» a la vista.
	if only == "" or "inicio_opciones".contains(only):
		var p2: Dictionary = Assessment.start_test("never")
		p2["done"] = true
		p2["rating"]["r"] = 1451.0
		demo.player = p2
		demo.dark = false
		demo.home_style = "rejilla"
		demo._open_home()
		await _frames(4)
		demo._open_options()
		await _frames(30)
		var caption := _find_text(demo, Loc.t("Pantalla de inicio").to_upper())
		if caption != null and demo.sheet_scroll != null:
			demo.sheet_scroll.scroll_vertical = int(maxf(0.0, caption.get_global_rect().position.y - demo.sheet_scroll.get_global_rect().position.y - 700.0))
			await _frames(4)
		print("SELECTOR ", "sí" if caption != null else "NO")
		await _shot("inicio_opciones")
	print("HECHO")
	get_tree().quit()


func _find_text(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node
	for child: Node in node.get_children():
		var hit := _find_text(child, text)
		if hit != null:
			return hit
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)
