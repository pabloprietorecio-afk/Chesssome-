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
	# Durante la partida, el rival va encima del tablero: su cara, su nombre y que es un bot (si hay sitio: en
	# pantallas 16:9 no lo hay y el reloj ya lleva su nombre).
	demo._place_tip()
	var rv := Campeonato.rival("escuela", str(m["rival"]))
	var built := CampeonatoUI.game_tag(demo, "escuela", str(m["rival"]), false, 116.0)
	_ok(_has_text(built, str(rv.get("name", ""))) and _has_text(built, Loc.f("Bot · Elo %d", int(rv.get("elo", 0)))), "el rival de encima del tablero: nombre y «Bot · Elo»")
	built.free()
	var thinking := CampeonatoUI.game_tag(demo, "escuela", str(m["rival"]), true, 84.0)
	_ok(_has_text(thinking, Loc.t("Bot · pensando…")), "mientras piensa: «Bot · pensando…»")
	thinking.free()
	var sky: float = demo.view.get_global_rect().position.y + demo.view.board_top() - demo._coach_legend_floor()
	var tag: Control = demo.camp_tag
	var shown := tag != null and is_instance_valid(tag) and tag.visible
	_ok(shown == (sky >= 144.0), "se ve si cabe entre la barra y el tablero (%d px)" % int(sky))
	_ok(not shown or tag.get_global_rect().end.y <= demo.view.get_global_rect().position.y + demo.view.board_top() + 1.0, "sin tapar el tablero")
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

	await _formatos(demo)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campeonato.PATH))
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Elegir formato y ritmo, y jugar en una liga y en un mini-match.
func _formatos(demo: Node) -> void:
	demo._open_campeonato_room("club")
	await _frames(2)
	_ok(_has_text(demo.progress, "FORMATO") and _has_text(demo.progress, "RITMO"), "la sala ofrece elegir formato y ritmo")
	for f: Dictionary in Campeonato.FORMATS:
		_ok(_find_button(demo.progress, str(f["name"])) != null, "formato: %s" % f["name"])
	_ok(_find_button(demo.progress, "90+30") != null and _find_button(demo.progress, "Otro") != null and _find_button(demo.progress, "3+2") != null, "ritmos de la app, también «Otro»")
	_ok(_find_button(demo.progress, "Sin reloj") == null, "pero siempre con reloj")
	var liga := _find_button(demo.progress, "Liga")
	liga.pressed.emit()
	await _frames(2)
	_ok(demo.camp_fmt == "liga" and _has_text(demo.progress, "siete partidas"), "elegir liga se nota (y se vuelve a dibujar)")
	var fast := _find_button(demo.progress, "3+2")
	fast.pressed.emit()
	await _frames(2)
	_ok(demo.camp_tc == 1 and (demo._camp_clock("club") as Array) == [3, 2], "ritmo 3+2")
	_find_button(demo.progress, "Otro").pressed.emit()
	await _frames(2)
	_ok(_has_text(demo.progress, "Minutos por jugador") and (demo._camp_clock("club") as Array) == [10, 5], "«Otro»: minutos e incremento a mano")
	demo._camp_step_minutes(1, "club")
	await _frames(2)
	_ok((demo._camp_clock("club") as Array) == [15, 5], "con los botones de más y menos")
	_find_button(demo.progress, "3+2").pressed.emit()
	await _frames(2)
	_ok(Campeonato.load_state()["ultimo"]["formato"] == "liga" and int(Campeonato.load_state()["ultimo"]["ritmo"]) == 1, "se guarda la última elección")
	demo._campeonato_new("club")
	await _frames(3)
	var tl: Dictionary = demo.campeonato_state()["torneos"]["club"]
	_ok(Campeonato.format_of(tl) == "liga" and (tl["ritmo"] as Array) == [3, 2], "el torneo empieza con el formato y el ritmo elegidos")
	var w: Node = demo.get_node_or_null("CampeonatoPaseo")
	if w != null:
		w.queue_free()
	var ml := Campeonato.current_match(tl, "club")
	demo._campeonato_start_game("club", int(ml["level"]))
	await _frames(3)
	_ok(demo.game_clocked and (demo.game["clock"] as Array) == [3, 2] and str(demo.game["title"]).contains(Loc.f("Ronda %d", 1)), "la partida, a 3+2 y como «Ronda 1»")
	demo.game_state = "over"
	demo.game_won = 0
	demo.game_result = "Tablas"
	demo.game_moves = ["e2e4", "e7e5"]
	demo._refresh()
	await _frames(2)
	_ok(int(tl["ronda"]) == 1 and (tl["res"] as Array).size() == 4, "tablas: se apunta y las demás partidas de la ronda se juegan")
	demo._campeonato_after_game()
	await _frames(2)
	_ok(_has_text(demo.progress, "CLASIFICACIÓN") and _has_text(demo.progress, "TUS PARTIDAS") and _has_text(demo.progress, "Ronda 2"), "la sala enseña la clasificación y tus partidas")
	_ok(_find_button(demo.progress, "Jugar: Ronda 2") != null, "y «Jugar: Ronda 2»")
	# Mini-match: la barra y el marcador tras la primera partida.
	demo.camp_fmt = "copa_match"
	demo.camp_tc = 0
	demo._campeonato_new("escuela")
	await _frames(3)
	var w3: Node = demo.get_node_or_null("CampeonatoPaseo")
	if w3 != null:
		w3.queue_free()
	var tm: Dictionary = demo.campeonato_state()["torneos"]["escuela"]
	var mm := Campeonato.current_match(tm, "escuela")
	demo._campeonato_start_game("escuela", int(mm["level"]))
	await _frames(3)
	_ok(str(demo.game["title"]).contains("1/2") and (demo.game["clock"] as Array) == [10, 5], "mini-match: partida 1/2, con el reloj de la sala")
	demo.game_state = "over"
	demo.game_won = 1
	demo.game_result = "¡Has ganado!"
	demo.game_moves = ["e2e4", "e7e5"]
	demo._refresh()
	await _frames(2)
	demo._campeonato_after_game()
	await _frames(2)
	_ok(_has_text(demo.progress, "Marcador del mini-match") and _find_button(demo.progress, "Jugar: Cuartos de final · 2/2") != null, "marcador del mini-match y «Jugar» la segunda")


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
