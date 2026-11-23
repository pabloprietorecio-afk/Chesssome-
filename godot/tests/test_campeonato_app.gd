extends SceneTree
## Modo Campeonato en la app entera: salas, paseo hasta la mesa, partida con reloj y sin tutor, abandono que
## cuenta como derrota, «Seguir el torneo» y la final de Premium.
## Uso: godot --headless --path godot -s tests/test_campeonato_app.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	Premium._loaded = true
	Premium.purchased = false
	Premium.test_on = false
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)

	for f: String in ["murmullo_a.ogg", "murmullo_b.ogg", "aplausos_pequeno.ogg", "aplausos_grande.ogg", "exclamacion_1.ogg", "lamento.ogg"]:
		_ok(CampeonatoUI._stream(f) != null, "sonido %s" % f)
	_ok((CampeonatoUI._stream("murmullo_a.ogg") as AudioStreamOggVorbis).loop, "el murmullo va en bucle")
	_ok(CampeonatoUI.depth_of(Campeonato.portrait_path("escuela", "lucia")) != null and CampeonatoUI.depth_of(Campeonato.room_path("hotel", "pasillo")) != null, "fotos vivas: hay mapas de profundidad")
	var probe := TextureRect.new()
	_ok(CampeonatoUI.alive(probe, Campeonato.portrait_path("escuela", "lucia"), 0.5) != null and probe.material is ShaderMaterial, "la foto viva se monta con su shader")
	probe.free()
	demo._open_campeonato()
	await _frames(2)
	_ok(demo.progress_kind == "campeonato", "se abre la lista de salas")
	_ok(_has_text(demo.progress, "Torneo de la escuela") and _has_text(demo.progress, "Torneo del barrio"), "con la escuela y el barrio")
	_ok(not _has_text(demo.progress, "Gran Torneo Internacional"), "sin Stockfish en el escritorio, el hotel no sale")

	demo._open_campeonato_room("escuela")
	await _frames(2)
	_ok(demo.progress_kind == "campeonato_sala" and _has_text(demo.progress, "Empezar el torneo"), "la sala, con «Empezar el torneo»")

	demo._campeonato_new("escuela")
	await _frames(3)
	var walk: Node = demo.get_node_or_null("CampeonatoPaseo")
	_ok(walk != null, "el paseo por la sala")
	# Un toque salta el paseo: sale la tarjeta del rival.
	for b in walk.find_children("*", "Button", true, false):
		if (b as Button).flat:
			(b as Button).pressed.emit()
			break
	await _until(func() -> bool: return _find_button(walk, "Sentarse a jugar") != null)
	var sit := _find_button(walk, "Sentarse a jugar")
	_ok(sit != null, "tarjeta del rival con «Sentarse a jugar»")
	_ok(_has_text(walk, "Bot · Elo"), "el rival se presenta como bot")
	sit.pressed.emit()
	await _frames(4)
	_ok(demo.mode == "game" and str(demo.game.get("campeonato", "")) == "escuela", "empieza la partida del torneo")
	_ok(demo.game_clocked and (demo.game["clock"] as Array) == [10, 5], "con el reloj de la escuela")
	_ok(not Premium.coach_applies(demo.kids, false, demo.game_clocked, ""), "y sin tutor (con reloj no hay)")
	_ok(str(demo.game["title"]).contains("(bot)"), "el título dice que el rival es un bot")

	# Abandonar cuenta como derrota: quedas fuera.
	demo._ask_leave()
	await _frames(2)
	var leave := _find_button(demo, "Abandonar")
	_ok(leave != null, "aviso: abandonar te deja fuera")
	if leave != null:
		leave.pressed.emit()
	await _frames(4)
	var tour: Dictionary = demo.campeonato_state()["torneos"]["escuela"]
	_ok(str(tour["estado"]) == "eliminado", "abandonar cuenta como derrota")
	_ok(Campeonato.champion(tour) != "", "el resto del cuadro se juega")

	# Otro torneo: ganas los cuartos; la barra dice «Seguir el torneo» y no hay «Otra».
	demo._campeonato_new("escuela")
	await _frames(2)
	var w2: Node = demo.get_node_or_null("CampeonatoPaseo")
	if w2 != null:
		w2.queue_free()
	var t2: Dictionary = demo.campeonato_state()["torneos"]["escuela"]
	var m := Campeonato.current_match(t2, "escuela")
	demo._campeonato_start_game("escuela", int(m["level"]))
	await _frames(3)
	demo.game_state = "over"
	demo.game_won = 1
	demo.game_result = "¡Has ganado!"
	demo.game_moves = ["e2e4", "e7e5"]
	demo._refresh()
	await _frames(2)
	_ok(_find_button(demo, "Seguir el torneo") != null and _find_button(demo, "Otra") == null, "al acabar: «Seguir el torneo», sin «Otra»")
	_ok(int(t2["ronda"]) == 1, "la victoria se apunta al acabar (semifinal)")
	demo._refresh()
	_ok(int(t2["ronda"]) == 1, "y solo una vez")
	demo._campeonato_after_game()
	await _frames(2)
	_ok(demo.progress_kind == "campeonato_sala" and _has_text(demo.progress, "SEMIFINAL"), "vuelta al cuadro, con la semifinal")

	# La final es de Premium.
	t2["ronda"] = 2
	t2["ganadores"] = [["tu", "a", "b", "c"], ["tu", "b"], []]
	demo._campeonato_play("escuela")
	await _frames(2)
	_ok(demo._premium_offer_reason == "campeonato", "la final pide Premium")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	for b in node.find_children("*", "Button", true, false):
		if not (b as Button).is_visible_in_tree():
			continue
		if (b as Button).text == text:
			return b
		for l in b.find_children("*", "Label", true, false):
			if (l as Label).text == text:
				return b
	return null


func _has_text(node: Node, text: String) -> bool:
	if node == null:
		return false
	for l in node.find_children("*", "Label", true, false):
		if (l as Label).text.contains(text):
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, limit: int = 600) -> void:
	for i in limit:
		if cond.call():
			return
		await process_frame


func _ok(cond: bool, msg: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: ", msg)
