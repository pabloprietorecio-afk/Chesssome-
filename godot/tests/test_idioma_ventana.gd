extends SceneTree
## La bandera de la bienvenida abre la ventana de idiomas, y elegir uno cambia el idioma y la cierra.
## Uso: godot --headless --path godot -s tests/test_idioma_ventana.gd

var fails := 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("ok   ", msg)
	else:
		fails += 1
		print("FALLA ", msg)


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	for i in 20:
		await process_frame
	demo._open_welcome()
	for i in 4:
		await process_frame
	# La bandera es el último hijo de la bienvenida: nada queda por encima que le quite el toque.
	var w: Control = demo.welcome
	_ok(w != null, "la bienvenida está abierta")
	var flag: Button = null
	for c in w.get_children():
		if c is Button:
			flag = c
	_ok(flag != null, "la bandera es un botón hijo directo de la bienvenida")
	_ok(w.get_child(w.get_child_count() - 1) == flag, "la bandera está por encima del resto")
	flag.pressed.emit()
	for i in 4:
		await process_frame
	_ok(demo.lang_dialog != null and is_instance_valid(demo.lang_dialog), "al pulsar la bandera se abre la ventana de idiomas")
	var marks: Array = demo.lang_dialog.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n is LangBoard)
	_ok(marks.size() == Loc.LANGUAGES.size(), "la ventana ofrece los %d idiomas" % Loc.LANGUAGES.size())
	demo._pick_language_dialog("en")
	for i in 6:
		await process_frame
	_ok(demo.language == "en", "elegir English cambia el idioma")
	_ok(demo.lang_dialog == null, "la ventana se cierra al elegir")
	_ok(demo.welcome != null and is_instance_valid(demo.welcome), "la bienvenida se rehace en el nuevo idioma")
	print("TODO OK" if fails == 0 else "FALLOS: %d" % fails)
	quit(fails)
