extends SceneTree
## Animación de las esperas del análisis (ui/knight_wait.gd): los vídeos del caballo, al azar y sin repetir el mismo
## dos veces seguidas, encadenados con un fundido; quieta sin animaciones; y su uso en «Analizando jugada a jugada…»
## con la barra de progreso.
## Uso: godot --headless --path godot -s tests/test_espera.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	# Los vídeos existen y se cargan (Godot no los importa: tienen que estar tal cual y en el filtro de exportación).
	var loaded := 0
	for path: String in KnightWait.CLIPS:
		if FileAccess.file_exists(path) and load(path) is VideoStream:
			loaded += 1
	_ok(loaded == KnightWait.CLIPS.size() and loaded == 3, "los tres vídeos del caballo se cargan (%d)" % loaded)
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_ok(presets.count("espera/*.ogv") == 2, "los vídeos van en el filtro de exportación de los dos perfiles")

	# Al azar, sin repetir el mismo seguido, y salen todos.
	var k := KnightWait.new()
	var seen := {}
	var repeated := false
	for i in 60:
		var n := k.pick()
		if n == k._last:
			repeated = true
		k._last = n
		seen[n] = true
	_ok(not repeated and seen.size() == 3, "al azar, todos salen y nunca el mismo dos veces seguidas")
	k.free()

	# Se reproduce y, al acabar uno, empieza otro distinto con un fundido.
	var w := KnightWait.new()
	w.set_side(400.0, true)
	root.add_child(w)
	await _frames(3)
	var first := w.current()
	_ok(w._players.size() == 2 and w._players[w._front].is_playing(), "empieza un vídeo")
	var length := w._players[w._front].get_stream_length()
	_ok(length > 3.0 and length < 6.0, "sabe cuánto dura (%.2f s) para fundir antes del final" % length)
	w._play_next()
	_ok(w.current() != first and w._fading, "el siguiente es otro y entra fundiéndose")
	await create_timer(KnightWait.XFADE + 0.2).timeout
	_ok(not w._fading and w._players[w._front].is_playing() and w._players[w._front].modulate.a > 0.99, "tras el fundido queda el nuevo")
	_ok(not w._players[1 - w._front].is_playing(), "y el anterior se para")
	w.progress = 0.0
	w.progress = 0.6
	await create_timer(0.3).timeout
	_ok(w._bar > 0.0 and w._bar <= 0.6, "la barra avanza poco a poco")
	w.queue_free()

	# Sin animaciones: el logo quieto, sin vídeo.
	var s := KnightWait.new()
	s.still = true
	s.set_side(400.0, false)
	root.add_child(s)
	await _frames(2)
	_ok(s._players.is_empty() and s._logo != null and s._logo.texture != null, "sin animaciones, el logo quieto")
	s.queue_free()

	# En la app: «Analizando jugada a jugada…» con el caballo y la barra.
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	var moves := ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"]
	var pos := Chess.from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	var fens: Array = [pos.fen()]
	for u: String in moves:
		pos.apply(pos.find_uci(u))
		fens.append(pos.fen())
	demo.game_history = fens
	demo.game_moves = moves
	demo.game_color = 1
	demo.mode = "game"
	demo.detail_done = false
	demo._open_detail()
	await _frames(2)
	_ok(demo._wait_anim != null and is_instance_valid(demo._wait_anim) and demo._wait_anim.is_inside_tree(), "«Analizando jugada a jugada…» lleva el caballo")
	demo._detail_tick(2, 3)
	_ok(is_equal_approx(demo._wait_anim.progress, 2.0 / 3.0), "y la barra va por 2 de 3")
	# Que el análisis acabe antes de salir (si no, el hilo sigue con todo ya liberado).
	for i in 300:
		if demo._review_thread == null:
			break
		await create_timer(0.1).timeout
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
