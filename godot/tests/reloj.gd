extends Control
## Capturas del reloj de ajedrez en varios estados (para revisar el dibujo).
## Uso: SHOTS_DIR=… godot --path godot --resolution 1080x1600 res://tests/reloj.tscn

func _ready() -> void:
	var dir := OS.get_environment("SHOTS_DIR")
	var bold: Font = load("res://fonts/InterDisplay-Bold.woff2")
	var tab := FontVariation.new()
	tab.base_font = bold
	tab.opentype_features = {"tnum": 1}
	var semi: Font = load("res://fonts/Inter-SemiBold.woff2")
	var states := [[1080000.0, 1195000.0, 0, 1.0, false], [1080000.0, 1195000.0, 0, 1.0, true], [1083000.0, 1190000.0, 1, 0.0, false], [7400.0, 64000.0, 0, 1.0, false]]
	for dark_i in 2:
		var bg := ColorRect.new()
		bg.color = Color("161e38") if dark_i == 1 else Color("ffffff")
		bg.size = Vector2(1080, 1600)
		add_child(bg)
		for i in states.size():
			var st: Array = states[i]
			var c := ChessClock.new()
			c.digits_font = tab
			c.label_font = semi
			c.dark = dark_i == 1
			c.times = [st[0], st[1]]
			c.running = st[2]
			c.up_mine = st[3]
			c.call_press = st[4]
			c.position = Vector2(60, 40 + i * 390)
			c.size = Vector2(960, 360)
			add_child(c)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/reloj_%d.png" % dark_i)
		for ch in get_children():
			ch.queue_free()
		await get_tree().process_frame
	get_tree().quit()
