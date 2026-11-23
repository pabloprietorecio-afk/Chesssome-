extends SceneTree
## Copia de seguridad en la app (Opciones → «Copia de seguridad»): el botón sale (no en Kids), la ventana se abre,
## un archivo malo da un aviso y no una ventana de confirmar, y una copia buena pide confirmación con su resumen.
## Uso: godot --headless --path godot -s tests/test_backup_app.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo._open_options()
	await _frames(4)
	_ok(_buttons(demo, ["Copia de seguridad"]).size() == 1, "Opciones tiene el botón «Copia de seguridad»")
	_buttons(demo, ["Copia de seguridad"])[0].emit_signal("pressed")
	await _frames(4)
	_ok(_buttons(demo.confirm_node, ["Importar una copia", "Enviar (correo, Drive…)"]).size() == 2, "la ventana ofrece enviar e importar")
	_ok(_buttons(demo.confirm_node, ["Guardar en el móvil"]).is_empty(), "sin el complemento de Android no ofrece «Guardar en el móvil»")

	# Un archivo que no es una copia: aviso, sin ventana de confirmar.
	demo._close_confirm()
	demo._backup_read("esto no es una copia")
	await _frames(4)
	_ok(demo.confirm_node == null or not is_instance_valid(demo.confirm_node), "un archivo malo no abre «¿Importar?»")
	demo._backup_read("cancel")
	demo._backup_read("error: sin permiso")
	await _frames(2)

	# Una copia buena: pide confirmar.
	var text := JSON.stringify({"app": Backup.APP, "version": Backup.VERSION, "creado": 0, "archivos": {
		"chessome_partidas.json": JSON.stringify({"partidas": [{"a": 1}, {"a": 2}], "rivales": {}}),
		"chessome_jugador.json": JSON.stringify({"tries": [{}, {}, {}], "rating": {"r": 1.0, "rd": 1.0, "vol": 0.06}}),
	}})
	demo._backup_read(text)
	await _frames(4)
	_ok(demo.confirm_node != null and is_instance_valid(demo.confirm_node), "una copia buena pide confirmar")
	_ok(_buttons(demo.confirm_node, ["Importar", "Cancelar"]).size() == 2, "con «Importar» y «Cancelar»")
	_ok(_has_text(demo.confirm_node, "2 partidas, 3 problemas"), "y dice qué trae (2 partidas, 3 problemas)")
	_buttons(demo.confirm_node, ["Cancelar"])[0].emit_signal("pressed")
	await _frames(2)

	# En Kids no sale.
	demo.kids = true
	demo._build_sheet()
	await _frames(3)
	_ok(_buttons(demo, ["Copia de seguridad"]).is_empty(), "en Kids no hay «Copia de seguridad»")

	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(c: bool, what: String) -> void:
	hechos += 1
	if not c:
		fallos += 1
		printerr("FALLO: ", what)
	else:
		print("ok: ", what)


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _buttons(n: Node, labels: Array) -> Array:
	var found := {}
	if n != null and is_instance_valid(n):
		_collect(n, labels, found)
	var out: Array = []
	for l: String in labels:
		if found.has(Loc.t(l)):
			out.append(found[Loc.t(l)])
	return out


func _collect(n: Node, labels: Array, found: Dictionary) -> void:
	if n is Button and (n as Button).visible:
		var label := _first_label(n)
		for l: String in labels:
			if label == Loc.t(l) and not found.has(label):
				found[label] = n
	for c in n.get_children():
		_collect(c, labels, found)


func _first_label(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	for c in n.get_children():
		var t := _first_label(c)
		if t != "":
			return t
	return ""


func _has_text(n: Node, part: String) -> bool:
	if n is Label and (n as Label).text.contains(part):
		return true
	for c in n.get_children():
		if _has_text(c, part):
			return true
	return false
