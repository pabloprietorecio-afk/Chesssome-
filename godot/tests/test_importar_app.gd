extends SceneTree
## «Importar partidas» en la app: el botón en «Mis partidas», la página (Lichess o Chess.com, el nombre, «Traer mis
## partidas»), la lista de lo traído, abrir una para analizarla y volver con «Importadas». Sin red: las partidas se
## ponen a mano como si hubieran llegado de Lichess (las mismas de tests/test_importar.gd).
## Uso: godot --headless --path godot -s tests/test_importar_app.gd

var fallos := 0
var hechos := 0

const PGN := """[Site "https://lichess.org/AbCd1234"]
[White "PabloTest"]
[Black "rival_uno"]
[Result "1-0"]
[UTCDate "2026.11.20"]
[UTCTime "18:03:12"]
[Variant "Standard"]
[Termination "Normal"]

1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0

[Site "https://lichess.org/EfGh5678"]
[White "OtroJugador"]
[Black "pablotest"]
[Result "1-0"]
[UTCDate "2026.11.21"]
[UTCTime "09:00:00"]
[Variant "Standard"]
[Termination "Time forfeit"]

1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qxf7# 1-0
"""


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	var games_before := (demo._log()["partidas"] as Array).size()
	demo.import_store = {"ultima": "lichess"}
	demo.import_source = "lichess"
	demo._open_my_games()
	await _frames(3)
	var entry := _buttons(demo.progress, ["Importar partidas"])
	_ok(entry.size() == 1, "«Mis partidas» tiene «Importar partidas»")
	if entry.is_empty():
		_finish()
		return
	entry[0].emit_signal("pressed")
	await _frames(3)
	_ok(demo.progress_kind == "import_games", "abre la página de importar")
	_ok(_buttons(demo.progress, ["Lichess", "Chess.com", "Traer mis partidas", "Volver"]).size() == 4, "con Lichess, Chess.com, «Traer mis partidas» y «Volver»")
	_ok(demo._import_edit != null and demo._import_edit.placeholder_text.contains("Lichess"), "el campo pide el nombre de Lichess")
	# Sin nombre: no se pregunta a nadie; se dice qué pasa.
	_buttons(demo.progress, ["Traer mis partidas"])[0].emit_signal("pressed")
	await _frames(3)
	_ok(not demo._import_busy and demo._import_error != "", "sin nombre no se pide nada y sale el motivo")
	# Tras un «429», se espera un minuto sin volver a preguntar.
	demo._import_edit.text = "PabloTest"
	demo._import_wait["lichess"] = Time.get_unix_time_from_system() + 60.0
	demo._import_fetch()
	await _frames(3)
	_ok(not demo._import_busy and demo._import_error.contains("minuto"), "tras un «429», esperar un minuto")
	demo._import_wait.clear()
	demo._import_error = ""
	# Lo que habría llegado de Lichess.
	var games := GameImport.from_lichess(PGN, "PabloTest")
	GameImport.put(demo.import_store, "lichess", "PabloTest", JSON.parse_string(JSON.stringify(games)), 1794300000)
	demo._open_import()
	await _frames(3)
	var won := _buttons(demo.progress, ["Ganada"])
	var lost := _buttons(demo.progress, ["Perdida"])
	_ok(won.size() == 1 and lost.size() == 1, "la lista enseña las dos partidas traídas")
	_ok(demo._import_edit.text == "PabloTest", "con el nombre de la última vez")
	# Chess.com, sin nada traído: su campo y ninguna partida.
	demo._import_pick("chesscom")
	await _frames(3)
	_ok(demo._import_edit.placeholder_text.contains("Chess.com") and _buttons(demo.progress, ["Ganada"]).is_empty(), "Chess.com, todavía vacío")
	demo._import_pick("lichess")
	await _frames(3)
	# Abrir la ganada: el análisis, con nuestras piezas (blancas) abajo.
	_buttons(demo.progress, ["Ganada"])[0].emit_signal("pressed")
	var t0 := Time.get_ticks_msec()
	while not demo.review_done and Time.get_ticks_msec() - t0 < 60000:
		await create_timer(0.1).timeout
	await _frames(4)
	_ok(demo.mode == "game" and bool(demo.game.get("imported", false)) and demo.game_color == 0, "abre la partida importada, con blancas")
	_ok(demo.game_moves == ["e2e4", "e7e5", "f1c4", "b8c6", "d1h5", "g8f6", "h5f7"] and demo.review_done, "con sus jugadas y su análisis")
	_ok(demo.game_result == "Jaque mate: has ganado.", "y cómo terminó")
	if demo.game_state == "review":
		var leave := _buttons(demo.actions, ["Volver"])
		if not leave.is_empty():
			leave[0].emit_signal("pressed")
			await _frames(4)
	if demo.progress != null and is_instance_valid(demo.progress) and demo.progress_kind == "review":
		demo._close_progress()
		await _frames(2)
	_ok(demo.game_state == "over", "al final de la partida")
	var back := _buttons(demo.actions, ["Importadas"])
	_ok(back.size() == 1 and _buttons(demo.actions, ["Mis partidas"]).is_empty(), "la barra vuelve a «Importadas» (no a «Mis partidas»)")
	if not back.is_empty():
		back[0].emit_signal("pressed")
		await _frames(4)
	_ok(demo.progress_kind == "import_games", "«Importadas» lleva a la página de importar")
	_ok((demo._log()["partidas"] as Array).size() == games_before, "las importadas no se suman a «Mis partidas»")
	# El botón «atrás» de Android, desde la página de importar, vuelve a «Mis partidas».
	demo._leave_progress()
	await _frames(3)
	_ok(demo.progress_kind == "my_games", "«atrás» vuelve a «Mis partidas»")
	_finish()


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Botones cuyo texto principal es uno de `labels`, en ese orden.
func _buttons(n: Node, labels: Array) -> Array:
	var found := {}
	if n != null:
		_collect(n, labels, found)
	var out: Array = []
	for l: String in labels:
		if found.has(Loc.t(l)):
			out.append(found[Loc.t(l)])
	return out


func _collect(n: Node, labels: Array, found: Dictionary) -> void:
	if n is Button and (n as Button).visible:
		var label := _first_label(n)
		if label == "":
			label = (n as Button).text
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


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)


func _frames(k: int) -> void:
	for i in k:
		await process_frame
