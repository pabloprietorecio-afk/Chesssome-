extends SceneTree
## Animación de las esperas del análisis (ui/knight_wait.gd): un vídeo del caballo por espera, que se repite con un
## fundido; el siguiente la próxima vez, en ciclo; quieta sin animaciones; y su uso en «Analizando jugada a jugada…»
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

	# En ciclo: 0, 1, 2, 0…
	_ok(KnightWait.next_clip(0) == 1 and KnightWait.next_clip(1) == 2 and KnightWait.next_clip(2) == 0, "los vídeos van en ciclo")

	# En una misma espera se ve uno solo: al acabar, vuelve a empezar el mismo, con un fundido.
	var w := KnightWait.new()
	w.clip = 1
	w.set_side(400.0, true)
	root.add_child(w)
	await _frames(3)
	_ok(w._players.size() == 2 and w._players[w._front].is_playing(), "empieza el vídeo")
	_ok(w._players[w._front].stream.resource_path == KnightWait.CLIPS[1], "el que toca (el 2.º)")
	var length := w._players[w._front].get_stream_length()
	_ok(length > 3.0 and length < 6.0, "sabe cuánto dura (%.2f s) para fundir antes del final" % length)
	w._play_next()
	_ok(w._fading, "al acabar entra otra vez fundiéndose")
	await create_timer(KnightWait.XFADE + 0.2).timeout
	var now := w._players[w._front]
	_ok(not w._fading and now.is_playing() and now.modulate.a > 0.99 and now.stream_position < 1.0, "tras el fundido, el vídeo vuelve a empezar")
	_ok(now.stream.resource_path == KnightWait.CLIPS[1], "y es el mismo: no cambia dentro de una espera")
	_ok(not w._players[1 - w._front].is_playing(), "el reproductor anterior se para")
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
	# Cada espera, el siguiente vídeo.
	var clips: Array = [demo._wait_anim.clip]
	for i in 3:
		var other: KnightWait = demo._wait_animation(false)
		clips.append(other.clip)
		other.free()
	_ok(clips == [0, 1, 2, 0], "cada vez que se entra, el siguiente vídeo, en ciclo (%s)" % str(clips))
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
