extends SceneTree
## El vídeo de un final dentro de la app, de principio a fin, con un reproductor simulado en lugar del nativo
## (core/cine_player.gd → CinePlayer.fake): mismo recorrido que en el móvil, sin YouTube.
##   - Al abrir el final: el reproductor se crea parado en el inicio del clip, en su hueco, arriba y a todo el ancho.
##   - Al pulsar ▶ (en el reproductor): el tablero sigue las jugadas del vídeo y nunca enseña la de la pregunta.
##   - En cada marca: el vídeo se para y sale la pregunta, en la misma posición.
##   - «Seguir el vídeo» tras responder: el vídeo sigue; al final, la explicación de la partida, sin vídeo.
##   - Con algo encima (Opciones), el reproductor se oculta; fuera de la lección, se cierra.
## Uso: godot --headless --path godot -s tests/test_cine_video.gd

var fallos := 0
var hechos := 0


## Reproductor simulado: los mismos métodos que android_cine/YouTubeCine.java. El tiempo avanza con el reloj solo
## mientras «reproduce»; listo al abrirlo.
class FakePlayer extends RefCounted:
	var calls: Array = []
	var opened := false
	var rect := Rect2i()
	var visible := true
	var time := 0.0
	var playing := false
	var duration := 0.0
	var error := 0

	func open(_id: String, start: float, x: int, y: int, w: int, h: int, _lang: String) -> void:
		calls.append("open")
		opened = true
		time = start
		playing = false
		rect = Rect2i(x, y, w, h)

	func place(x: int, y: int, w: int, h: int) -> void:
		rect = Rect2i(x, y, w, h)

	func show(v: bool) -> void:
		visible = v

	func cue(at: float) -> void:
		calls.append("cue")
		time = at
		playing = false

	func play() -> void:
		calls.append("play")
		playing = true

	func pause() -> void:
		calls.append("pause")
		playing = false

	func seek(at: float) -> void:
		calls.append("seek")
		time = at

	func snapshot() -> Dictionary:
		return {"open": opened, "ready": opened, "time": time, "duration": duration, "state": 1 if playing else 2, "error": error, "blocked": false}

	func close() -> void:
		calls.append("close")
		opened = false
		playing = false

	## Avanza el vídeo: deprisa (1 s por fotograma) lejos de las marcas y de 0,1 en 0,1 cerca de ellas.
	func advance(_dt: float) -> void:
		if not playing:
			return
		var step := 1.0
		for m: float in marks:
			if time < m and m - time < 3.0:
				step = 0.1
		time += step

	var marks: Array = []


var fake := FakePlayer.new()


func _initialize() -> void:
	CinePlayer.fake = fake
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	var clip := Cine.clip_of("cine-ding-gukesh-2024-g14")
	var film: Dictionary = clip["film"]
	fake.duration = float(film["duration"])
	for st: Dictionary in film["stops"]:
		fake.marks.append(float(st["at"]))
	fake.marks.append(float(film["end"]))
	for m: Dictionary in film["sync"]["marks"]:
		fake.marks.append(float(m["at"]))

	demo._start_lesson("cine-ding-gukesh-2024-g14")
	await _frames(4)
	_ok(not demo.film.is_empty(), "el final se abre con vídeo")
	_ok(fake.opened and is_equal_approx(fake.time, float(film["start"])) and not fake.playing, "reproductor creado parado en el inicio del clip")
	var slot: Control = demo.video_slot
	_ok(slot.visible and absf(slot.size.x - demo.size.x) < 1.0, "el hueco del vídeo va a todo el ancho")
	_ok(fake.rect.size.x > 0 and absf(float(fake.rect.size.x) / float(fake.rect.size.y) - 16.0 / 9.0) < 0.02, "el reproductor mide 16:9 (%s)" % str(fake.rect))
	# YouTube pide al menos 200 × 200 px CSS: a todo el ancho en 16:9, en un móvil (≈400 px CSS de ancho) son ≈225 de alto.
	_ok(absf((slot.size.y - 18.0) - slot.size.x * 9.0 / 16.0) < 1.5, "el hueco es 16:9 a todo el ancho")
	var board_top: float = demo.board_slot.get_global_rect().position.y
	_ok(slot.get_global_rect().end.y <= board_top + 1.0, "el vídeo queda encima del tablero, sin taparlo")
	_ok(demo.ex_state == "intro" and _actions(demo).has("Ir a la pregunta"), "presentación con «Ir a la pregunta»")
	var start_ply := int(film["sync"]["startPly"])
	_ok(str(film["frames"][str(start_ply)]["fen"]).split(" ")[0] == demo.view.board.chess.fen().split(" ")[0], "antes de ▶, el tablero enseña la posición del vídeo al empezar")

	# El jugador pulsa ▶ y el vídeo corre: el tablero sigue las jugadas sin pasar de la pregunta.
	fake.play()
	var stops: Array = film["stops"]
	var q_ply := int((demo.lesson["exercises"] as Array)[0]["ply"])
	var spoiled := false
	var moved := false
	var guard := 0
	while demo.film["st"]["phase"] != "asking" and guard < 4000:
		fake.advance(0.1)
		await process_frame
		guard += 1
		if int(demo.film["ply"]) >= q_ply:
			spoiled = true
		if int(demo.film["ply"]) > start_ply:
			moved = true
	_ok(demo.film["st"]["phase"] == "asking" and int(demo.film["st"]["stop"]) == 0, "el vídeo se para en la primera marca")
	_ok(absf(fake.time - float(stops[0]["at"])) <= 0.25 and not fake.playing, "pausa justo antes de la jugada (%.2f, marca %.2f)" % [fake.time, float(stops[0]["at"])])
	_ok(moved, "el tablero siguió las jugadas del vídeo")
	_ok(not spoiled, "el tablero no enseñó la jugada de la pregunta")
	_ok(demo.ex_state == "play" and int(demo.ex.get("ply", 0)) == q_ply, "sale la pregunta de esa pausa")
	_ok(demo.view.board.chess.fen().split(" ")[0] == str(demo.ex["fen"]).split(" ")[0], "en la posición de la pregunta")
	_ok(_actions(demo).has("Seguir el vídeo") and _actions(demo).has("Pista"), "pregunta con «Pista» y «Seguir el vídeo» (responder es opcional)")

	# Con Opciones abiertas, el reproductor se oculta.
	demo._open_options()
	await _frames(3)
	_ok(not fake.visible, "con Opciones encima, el reproductor se oculta")
	demo._close_options()
	await _frames(3)
	_ok(fake.visible, "al cerrarlas, vuelve")

	# Responde bien (la jugada de la partida) y sigue el vídeo.
	var played := str(demo.ex["cine"]["played"])
	demo.view.show_move(played)
	demo._on_move_played(played)
	await create_timer(1.0).timeout
	_ok(demo.ex_state == "done", "respuesta correcta")
	demo._next_lesson_step()
	await _frames(3)
	_ok(demo.film["st"]["phase"] == "reveal" and fake.playing and demo.ex_state == "film", "«Seguir el vídeo»: el vídeo sigue")
	_ok(_actions(demo).has("Ir a la pregunta"), "mientras sigue, «Ir a la pregunta»")

	# Segunda pausa sin esperar: «Ir a la pregunta» salta a la marca y pregunta.
	demo._film_ask()
	await _frames(3)
	_ok(demo.film["st"]["phase"] == "asking" and int(demo.film["st"]["stop"]) == 1 and is_equal_approx(fake.time, float(stops[1]["at"])), "«Ir a la pregunta» salta a la siguiente pausa")
	_ok(int(demo.ex.get("ply", 0)) == int((demo.lesson["exercises"] as Array)[1]["ply"]), "y sale la segunda pregunta")

	# Ahora, pasado el margen de la pausa (1,5 s), pulsa ▶ en el reproductor sin responder: sigue viendo y puede volver.
	await create_timer(1.6).timeout
	fake.play()
	for i in 12:
		fake.advance(0.1)
		await process_frame
	_ok(demo.film["st"]["phase"] == "reveal" and demo.film["st"]["missed"] == "resumed", "▶ sin responder: sigue viendo")
	_ok(_actions(demo).has("Volver a la pregunta"), "con «Volver a la pregunta»")
	demo._film_back()
	await _frames(3)
	_ok(demo.film["st"]["phase"] == "asking" and not fake.playing and demo.ex_state == "play", "vuelve a la pregunta y el vídeo se para")

	# Responde, sigue, y deja que el vídeo llegue a la tercera pausa y al final.
	played = str(demo.ex["cine"]["played"])
	demo.view.show_move(played)
	demo._on_move_played(played)
	await create_timer(1.0).timeout
	demo._next_lesson_step()
	guard = 0
	while demo.film["st"]["phase"] != "asking" or int(demo.film["st"]["stop"]) != 2:
		fake.advance(0.1)
		await process_frame
		guard += 1
		if guard > 4000:
			break
	_ok(int(demo.film["st"]["stop"]) == 2 and demo.film["st"]["phase"] == "asking", "tercera pausa")
	demo._next_lesson_step() # sin responder: «Seguir el vídeo»
	guard = 0
	while not demo.film.is_empty() and guard < 4000:
		fake.advance(0.1)
		await process_frame
		guard += 1
	_ok(demo.film.is_empty() and fake.calls.has("close"), "al acabar el clip, el reproductor se cierra")
	_ok(not demo.video_slot.visible, "y el hueco del vídeo desaparece")
	_ok(demo.ex_state == "info" and str(demo.ex.get("kind", "")) == "info", "sigue la explicación de la partida")

	# Fuera de la lección, nada queda abierto.
	demo._start_lesson("cine-ding-gukesh-2024-g14")
	await _frames(3)
	_ok(not demo.film.is_empty() and fake.opened, "otra vez con vídeo")
	demo._open_home()
	await _frames(3)
	_ok(demo.film.is_empty() and not fake.opened, "al ir al inicio, el vídeo se cierra")

	# Sin reproductor (escritorio, APK sin el complemento): la lección de siempre.
	CinePlayer.fake = null
	demo._start_lesson("cine-ding-gukesh-2024-g14")
	await _frames(3)
	_ok(demo.film.is_empty() and not demo.video_slot.visible and _actions(demo).has("Empezar"), "sin reproductor: la lección de la fase 1")
	demo.queue_free()
	await _frames(2)
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _actions(demo: Control) -> Array:
	var out: Array = []
	var rows: Array = demo.actions.get_children() + (demo._popup_row as Array)
	for b: Variant in rows:
		if b is Button and is_instance_valid(b):
			out.append(_label_of(b))
	return out


func _label_of(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	for c in n.get_children():
		var t := _label_of(c)
		if t != "":
			return t
	return ""


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
