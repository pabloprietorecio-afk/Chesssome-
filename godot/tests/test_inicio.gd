extends SceneTree
## Las dos pantallas de inicio (ui/home_screens.gd): qué enseña cada una, que todo lleva a algún sitio y que
## se cambia de una a otra desde Opciones.
## Uso: godot --headless --path godot -s tests/test_inicio.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(5)
	_ok(demo.home_style == "lista", "de serie, el inicio es la lista")

	# Con jugador (nivel 6).
	var p: Dictionary = Assessment.start_test("never")
	p["done"] = true
	p["rating"]["r"] = 1451.0
	demo.player = p
	demo._open_home()
	await _frames(3)
	var names := _labels(demo.progress)
	_ok(demo.progress_kind == "home", "la lista es la pantalla de inicio")
	for want: String in ["Mi nivel", "Reto del día", "Entrenar", "Jugar una partida", "Partida online", "Mi nivel y mi plan", "Modo Kids", "Aprende desde cero", "Opciones"]:
		_ok(names.has(want), "lista: está «%s»" % want)
	_ok(_all_wired(demo.progress), "lista: todo lo que se pulsa lleva a algún sitio")

	# A la rejilla, como lo hace Opciones.
	demo._set_home_style(1)
	await _frames(3)
	names = _labels(demo.progress)
	_ok(demo.home_style == "rejilla" and demo.progress_kind == "home", "al elegir «Rejilla» se ve la rejilla")
	for want: String in ["Mi nivel", "Racha", "Avisos", "Portada", "Reto del día", "Entrenar", "Jugar una partida", "Partida online", "Aprende desde cero", "Modo Kids", "Reto de la semana", "Progreso", "Mis partidas", "Opciones"]:
		_ok(names.has(want), "rejilla: está «%s»" % want)
	_ok(not names.has("Mi nivel y mi plan"), "rejilla: «Mi nivel y mi plan» deja su sitio a «Aprende desde cero»")
	var games := int(GameLog.game_rating(demo._log())["n"])
	_ok(names.has("Nivel de juego") == (games > 0), "rejilla: la pastilla del nivel de juego sale solo si hay partidas")
	_ok(_all_wired(demo.progress), "rejilla: todo lo que se pulsa lleva a algún sitio")

	# Lo que abre cada cosa.
	_press(demo.progress, "Mis partidas")
	await _frames(3)
	_ok(demo.progress_kind != "home", "rejilla: «Mis partidas» abre su pantalla (%s)" % demo.progress_kind)
	demo._open_home()
	await _frames(3)
	_press(demo.progress, "Reto del día")
	await _frames(3)
	_ok(demo.progress_kind == "day", "rejilla: «Reto del día» abre «Tu día» (%s)" % demo.progress_kind)
	demo._open_home()
	await _frames(3)
	_press(demo.progress, "Progreso")
	await _frames(3)
	_ok(demo.progress_kind == "progress", "rejilla: «Progreso» abre «Mi nivel y mi plan» (%s)" % demo.progress_kind)
	demo._open_home()
	await _frames(3)
	_press(demo.progress, "Opciones")
	await _frames(3)
	_ok(demo.options_open, "rejilla: «Opciones» abre las opciones")
	_ok(_has_text(demo, Loc.t("Pantalla de inicio").to_upper()), "opciones: está el selector «Pantalla de inicio»")
	# Con las opciones abiertas sobre el inicio, cambiar de pantalla la enseña al momento.
	demo._set_home_style(0)
	await _frames(3)
	_ok(demo.home_style == "lista" and demo.progress_kind == "home" and _labels(demo.progress).has("Mi nivel y mi plan"), "desde Opciones se vuelve a la lista")
	demo._set_home_style(7)
	await _frames(3)
	_ok(demo.home_style == "rejilla", "un índice fuera de rango se queda en la última pantalla")

	# Sin jugador: las dos invitan al test de nivel y no se rompe nada.
	demo.player = {}
	for style: String in HomeScreens.STYLES:
		demo.home_style = style
		demo._open_home()
		await _frames(3)
		names = _labels(demo.progress)
		_ok(names.has("Test de nivel"), "%s sin jugador: está «Test de nivel»" % style)
		_ok(not names.has("Reto del día"), "%s sin jugador: sin reto del día todavía" % style)
		_ok(_all_wired(demo.progress), "%s sin jugador: todo lleva a algún sitio" % style)

	# En oscuro y en otro idioma se montan igual.
	demo.player = p
	demo.dark = true
	Loc.apply("ja")
	for style: String in HomeScreens.STYLES:
		demo.home_style = style
		demo._open_home()
		await _frames(3)
		_ok(demo.progress_kind == "home" and _labels(demo.progress).has("Reto del día"), "%s en oscuro y en japonés" % style)
	Loc.apply("es")
	demo.dark = false

	# El modo Kids conserva su inicio de siempre, elija lo que elija el adulto.
	demo.home_style = "rejilla"
	demo.kids = true
	demo._open_home()
	await _frames(3)
	_ok(demo.progress_kind == "home" and not _labels(demo.progress).has("Reto de la semana"), "en modo Kids el inicio es el suyo")
	demo.kids = false

	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Nombres (meta «label») de todo lo que se puede pulsar en la pantalla.
func _labels(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	if node is BaseButton and node.has_meta("label"):
		out.append(str(node.get_meta("label")))
	for child: Node in node.get_children():
		out.append_array(_labels(child))
	return out


func _find(node: Node, label: String) -> BaseButton:
	if node == null:
		return null
	if node is BaseButton and node.has_meta("label") and str(node.get_meta("label")) == label:
		return node
	for child: Node in node.get_children():
		var hit := _find(child, label)
		if hit != null:
			return hit
	return null


func _press(node: Node, label: String) -> void:
	var b := _find(node, label)
	_ok(b != null, "existe el botón «%s»" % label)
	if b != null:
		b.pressed.emit()


## Ningún botón con nombre se queda sin acción (salvo la pestaña en la que ya estás).
func _all_wired(node: Node) -> bool:
	if node == null:
		return false
	if node is BaseButton and node.has_meta("label"):
		var b: BaseButton = node
		if b.pressed.get_connections().is_empty() and not b.disabled and str(b.get_meta("label")) != "Inicio":
			print("  sin acción: " + str(b.get_meta("label")))
			return false
	for child: Node in node.get_children():
		if not _all_wired(child):
			return false
	return true


func _has_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child: Node in node.get_children():
		if _has_text(child, text):
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
