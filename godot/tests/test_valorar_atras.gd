extends SceneTree
## Informe de testers (27 nov): el botón «atrás» y valorar la app.
## - «Atrás» en el inicio: la primera vez avisa («Pulsa otra vez para salir»); la segunda, en menos de 2 s, cierra.
## - «Atrás» en Entrenar, la lista de un nivel, «Mis partidas» y las páginas online hace lo de su botón «Volver».
## - La ventanita de valoración de Google Play solo al cerrar la enhorabuena de subir de nivel, cuando toca
##   (core/review_ask.gd), y «Valorar la app» en Opciones (abre la ficha de Play, no la ventanita).
## Uso: godot --headless --path godot -s tests/test_valorar_atras.gd

var fallos := 0
var hechos := 0


class FakePlay extends RefCounted:
	var asks := 0

	func valorar() -> void:
		asks += 1

	func conectar() -> void:
		pass


func _initialize() -> void:
	_rules()
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	var p: Dictionary = Assessment.start_test("never")
	p["done"] = true
	p["rating"]["r"] = 1272.0
	demo.player = p
	var quits := [0]
	demo.quit_hook = func() -> void: quits[0] += 1

	# «Atrás» en el inicio.
	demo._open_home()
	await _frames(3)
	_ok(demo.progress_kind == "home", "el inicio está abierto")
	demo._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_ok(quits[0] == 0 and demo._exit_toast_node != null and is_instance_valid(demo._exit_toast_node), "primera vez: avisa y no cierra")
	_ok(_has_text(demo._exit_toast_node, Loc.t("Pulsa otra vez para salir")), "el aviso dice «Pulsa otra vez para salir»")
	demo._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(quits[0] == 1, "segunda vez seguida: cierra")
	# Pasado el plazo, vuelve a avisar.
	demo._exit_armed_ms = Time.get_ticks_msec() - demo.EXIT_WINDOW_MS - 10
	demo._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(quits[0] == 1, "pasados 2 s, vuelve a avisar sin cerrar")
	await create_timer(2.3).timeout
	await _frames(2)
	_ok(demo._exit_toast_node == null or not is_instance_valid(demo._exit_toast_node), "el aviso se va solo")

	# «Atrás» en otras páginas: lo de su botón «Volver».
	demo._open_train_hub()
	await _frames(3)
	demo._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_ok(demo.progress_kind == "home", "Entrenar → inicio")
	demo._open_level_list(4)
	await _frames(3)
	demo._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_ok(demo.progress_kind == "train_hub", "lista de un nivel → Entrenar")
	demo._open_my_games()
	await _frames(3)
	_ok(demo.progress_kind == "my_games", "«Mis partidas» abierta")
	demo._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_ok(demo.progress_kind != "my_games", "«Mis partidas» se cierra (ahora: «%s»)" % demo.progress_kind)
	_ok(quits[0] == 1, "nada de esto cierra la app")

	# Valoración al subir de nivel, solo cuando toca.
	var play := FakePlay.new()
	demo.pagos.fake = play
	demo.review_state = ReviewAsk.new_state()
	(demo._prog()["dias"] as Dictionary).clear()
	_ok(not demo._maybe_ask_review(), "sin días de uso ni problemas resueltos: no se pide")
	for d in 4:
		(demo._prog()["dias"] as Dictionary)[str(20000 + d)] = {"p": 1, "a": 1, "r": 0, "l": 0, "g": 0, "v": 0}
	var tries: Array = []
	for i in 25:
		tries.append({"id": "x%d" % i, "correct": true})
	demo.player["tries"] = tries
	demo.kids = true
	_ok(not demo._maybe_ask_review() and play.asks == 0, "en Kids, nunca")
	demo.kids = false
	demo._level_up(5, 1180.0, 1210.0)
	await _frames(3)
	_ok(play.asks == 0, "la enhorabuena sola no la pide")
	var go := _buttons(demo._celebration, ["¡Seguir jugando!"])
	_ok(go.size() == 1, "la enhorabuena tiene «¡Seguir jugando!»")
	if go.size() == 1:
		go[0].emit_signal("pressed")
	await _frames(3)
	_ok(play.asks == 1 and int(demo.review_state["veces"]) == 1, "al cerrar la enhorabuena, se pide una vez")
	_ok(not demo._maybe_ask_review() and play.asks == 1, "la siguiente subida, al poco, ya no")
	demo.pagos.fake = null

	# Opciones: «Valorar la app».
	demo._open_options()
	await _frames(4)
	_ok(_buttons(demo, ["Valorar la app"]).size() == 1, "Opciones tiene «Valorar la app»")
	demo._close_options()
	await _frames(2)
	_finish()


func _rules() -> void:
	var s := ReviewAsk.new_state()
	var now := 1_800_000_000
	_ok(not ReviewAsk.should_ask(s, 2, 50, now, false), "reglas: con 2 días, no")
	_ok(not ReviewAsk.should_ask(s, 5, 19, now, false), "reglas: con 19 resueltos, no")
	_ok(ReviewAsk.should_ask(s, 3, 20, now, false), "reglas: 3 días y 20 resueltos, sí")
	_ok(not ReviewAsk.should_ask(s, 3, 20, now, true), "reglas: en Kids, no")
	ReviewAsk.asked(s, now)
	_ok(not ReviewAsk.should_ask(s, 9, 90, now + 89 * 86400, false), "reglas: antes de 90 días, no")
	_ok(ReviewAsk.should_ask(s, 9, 90, now + 90 * 86400, false), "reglas: a los 90 días, sí")
	ReviewAsk.asked(s, now + 90 * 86400)
	ReviewAsk.asked(s, now + 180 * 86400)
	_ok(not ReviewAsk.should_ask(s, 99, 999, now + 999 * 86400, false), "reglas: como mucho 3 veces")
	var c := ReviewAsk.clean({"veces": -2, "ultima": "x"})
	_ok(int(c["veces"]) == 0 and int(c["ultima"]) == 0, "reglas: datos guardados raros, a cero")


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _has_text(n: Node, text: String) -> bool:
	if n == null:
		return false
	if n is Label and (n as Label).text == text:
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


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


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await process_frame
