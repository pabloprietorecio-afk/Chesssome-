extends SceneTree
## Rival en 13 niveles agrupados en los cinco de siempre: al tocar un nivel sale una ventana con sus subniveles (y su
## Elo) y «Cancelar»; «Muy difícil», de un solo escalón, empieza directamente.
## Uso: godot --headless --path godot -s tests/test_niveles.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo._open_game_setup()
	await _frames(3)
	var groups := _buttons(demo.progress, Bot.GROUPS)
	_ok(groups.size() == 5, "cinco niveles en «Jugar una partida» (%d)" % groups.size())

	# Medio: ventana con Medio 1, 2 y 3, su Elo y «Cancelar».
	groups[2].emit_signal("pressed")
	await _frames(3)
	_ok(demo.confirm_node != null and is_instance_valid(demo.confirm_node), "tocar «Medio» abre la ventana de subniveles")
	var subs := _buttons(demo.confirm_node, ["Medio 1", "Medio 2", "Medio 3"])
	_ok(subs.size() == 3, "con Medio 1, 2 y 3 (%d)" % subs.size())
	_ok(_has_text(demo.confirm_node, Loc.f("Elo %d", Bot.level_elo(2))), "cada uno con su Elo (Medio 3: %d)" % Bot.level_elo(2))
	var cancel := _buttons(demo.confirm_node, ["Cancelar"])
	_ok(cancel.size() == 1, "y «Cancelar»")
	cancel[0].emit_signal("pressed")
	await _frames(3)
	_ok(demo.confirm_node == null and demo.progress_kind == "game_setup" and demo.mode != "game", "«Cancelar» cierra la ventana y sigue en la misma página")

	# Elegir Medio 1: partida contra ese nivel.
	_buttons(demo.progress, Bot.GROUPS)[2].emit_signal("pressed")
	await _frames(3)
	_buttons(demo.confirm_node, ["Medio 1"])[0].emit_signal("pressed")
	await _frames(4)
	_ok(demo.mode == "game" and int(demo.game.get("level", -1)) == 10, "Medio 1 empieza la partida contra el nivel 10")
	_ok(str(demo.game.get("title", "")) == Loc.f("Partida · %s", "Medio 1"), "con su nombre: «Partida · Medio 1»")
	_ok(int(demo.game_sublevels.get("2", -1)) == 10, "y se recuerda el subnivel elegido")
	demo._stop_game_thread()

	# Muy difícil (un solo escalón): directo.
	demo._open_game_setup()
	await _frames(3)
	_buttons(demo.progress, Bot.GROUPS)[4].emit_signal("pressed")
	await _frames(4)
	_ok(demo.confirm_node == null and demo.mode == "game" and int(demo.game.get("level", -1)) == 4, "«Muy difícil» empieza directamente")
	demo._stop_game_thread()

	# Las partidas ya guardadas siguen contando con su rival: «bot:2» es el Medio de siempre (hoy, Medio 3).
	var log := {"partidas": [{"rival_id": "bot:2", "resultado": 1, "jugadas": 30}]}
	var r := GameLog.game_rating(log)
	_ok(int(r.get("n", 0)) <= 1, "una partida antigua contra «Medio» se sigue leyendo")
	_ok(Bot.level_name(2) == "Medio 3" and Bot.LEVELS[2].has("elo"), "el Medio de antes es Medio 3, con su Elo medido")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


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
