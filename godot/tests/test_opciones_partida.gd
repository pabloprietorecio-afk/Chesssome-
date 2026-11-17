extends SceneTree
## «Jugar una partida» (Pablo, 17-11): las opciones (modalidad, piezas, ritmo) salen en una ventana semitransparente
## con «OK»; después se elige el nivel. En la página queda una ficha con lo elegido que vuelve a abrir la ventana.
## Uso: godot --headless --path godot -s tests/test_opciones_partida.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo.game_war = false
	demo.game_pick_color = 0
	demo.game_tc_pick = 0
	demo._open_game_setup(true)
	await _frames(4)
	_ok(demo.progress_kind == "game_setup", "se abre la página de partida")
	_ok(demo.confirm_node != null and is_instance_valid(demo.confirm_node), "y encima, la ventana de opciones")
	_ok(_buttons(demo.confirm_node, ["Clásica", "War Chess"]).size() == 2, "con la modalidad: Clásica y War Chess")
	_ok(_buttons(demo.confirm_node, ["Blancas", "Negras", "Al azar"]).size() == 3, "con tus piezas")
	_ok(_has_text(demo.confirm_node, Loc.t("RITMO")), "y con el ritmo")
	_ok(_buttons(demo.confirm_node, ["OK"]).size() == 1, "y un botón «OK»")
	_ok(_buttons(demo.progress, ["Blancas", "Negras", "Al azar"]).is_empty(), "las opciones ya no están en la página")
	_ok(_buttons(demo.progress, Bot.GROUPS).size() == 5, "en la página quedan los cinco niveles")
	var panel := _panel(demo.confirm_node)
	_ok(panel != null and (panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a < 0.95, "la ventana es semitransparente")

	# Cambiar opciones dentro de la ventana: la ventana sigue abierta y se rehace.
	_buttons(demo.confirm_node, ["Negras"])[0].emit_signal("pressed")
	await _frames(3)
	_ok(demo.game_pick_color == 1 and demo.confirm_node != null and is_instance_valid(demo.confirm_node), "elegir «Negras» no cierra la ventana")
	_buttons(demo.confirm_node, ["War Chess"])[0].emit_signal("pressed")
	await _frames(3)
	_ok(demo.game_war and _has_text(demo.confirm_node, "Blindar"), "War Chess, con sus reglas en corto")
	_ok(panel != null and panel.get_global_rect().end.y <= demo.size.y + 1.0, "la ventana cabe en la pantalla")

	_buttons(demo.confirm_node, ["OK"])[0].emit_signal("pressed")
	await _frames(4)
	_ok(demo.confirm_node == null, "«OK» cierra la ventana")
	_ok(demo.progress_kind == "game_setup" and demo.mode != "game", "y deja elegir el nivel")
	var summary: String = demo._game_options_summary()
	_ok(summary.contains(Loc.t("War Chess")) and summary.contains(Loc.t("Negras")), "la ficha resume lo elegido: %s" % summary)
	_ok(_has_text(demo.progress, summary), "y está en la página")

	# La ficha vuelve a abrir la ventana; tocar fuera también la cierra.
	var chip := _buttons(demo.progress, [summary])
	_ok(chip.size() == 1, "la ficha es un botón")
	chip[0].emit_signal("pressed")
	await _frames(3)
	_ok(demo.confirm_node != null and is_instance_valid(demo.confirm_node), "que vuelve a abrir la ventana")
	demo._close_confirm()
	await _frames(3)
	_ok(demo.confirm_node == null and demo.progress_kind == "game_setup", "cerrarla sin «OK» también vuelve a la página")

	# Desde el menú (sin `ask`) no sale la ventana: se ve directamente la página.
	demo._open_game_setup()
	await _frames(3)
	_ok(demo.confirm_node == null, "volver a la página (p. ej. desde «Mis partidas») no abre la ventana")

	# Elegir nivel: la partida respeta lo elegido en la ventana.
	_buttons(demo.progress, Bot.GROUPS)[4].emit_signal("pressed")
	await _frames(4)
	_ok(demo.mode == "game" and str(demo.game.get("variant", "")) == "war", "la partida es de War Chess")
	demo._stop_game_thread()

	# Kids: sin modalidad ni ritmo; con piezas y mundo.
	demo._leave_game()
	await _frames(3)
	demo.kids = true
	demo._open_game_setup(true)
	await _frames(3)
	_ok(_buttons(demo.confirm_node, ["Clásica", "War Chess"]).is_empty(), "Kids: sin War Chess")
	_ok(_has_text(demo.confirm_node, Loc.t("MUNDO")), "Kids: con el mundo")
	_ok(not _has_text(demo.confirm_node, Loc.t("RITMO")), "Kids: sin ritmo")
	demo._close_confirm()
	demo.kids = false
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _panel(n: Node) -> PanelContainer:
	if n is PanelContainer:
		return n
	for c in n.get_children():
		var p := _panel(c)
		if p != null:
			return p
	return null


## Botones cuyo texto principal es uno de `labels`, en ese orden.
func _buttons(n: Node, labels: Array) -> Array:
	var found := {}
	_collect(n, labels, found)
	var out: Array = []
	for l: String in labels:
		if found.has(Loc.t(l)):
			out.append(found[Loc.t(l)])
	return out


func _collect(n: Node, labels: Array, found: Dictionary) -> void:
	if n is Button:
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


func _has_text(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text.contains(text):
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
