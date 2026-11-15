extends SceneTree
## La partida online en la demo, sin red: pantalla de búsqueda, empezar con negras, jugada del rival que llega,
## jugada propia, abandono del rival. (La red se prueba aparte, contra Firebase.)
## Uso: godot --headless --path godot -s tests/test_online_ui.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(5)
	demo._open_online_home()
	await _frames(3)
	_ok(demo.progress_kind == "online", "la pantalla «Partida online» se abre")
	demo.online_busy = true
	demo._open_online()
	await _frames(3)
	_ok(demo.progress_kind == "online", "la pantalla de búsqueda se abre")
	# Entra un rival y nos tocan las negras: mueve primero él.
	demo._online_started(1)
	await _frames(3)
	_ok(demo.mode == "game" and bool(demo.game.get("online", false)), "empieza la partida online")
	_ok(demo.game_state == "think" and not demo.view.interactive, "con negras, espera al rival")
	demo._online_move("e2e4")
	await _frames(3)
	_ok(demo.game_state == "play" and demo.view.interactive, "llega la jugada del rival y nos toca")
	_ok(str(demo.view.board.chess.fen()).begins_with("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b"), "el tablero muestra e4")
	demo._online_move("a7a5")
	await _frames(2)
	_ok(demo.game_state == "play" and demo.game_moves.size() == 1, "una jugada ilegal del rival se ignora")
	# Jugada propia (sin red: Online.play devuelve false sin sesión, la partida sigue en local).
	demo.view.show_move("e7e5")
	demo._game_move("e7e5")
	await _frames(3)
	_ok(demo.game_state == "think" and not demo.view.interactive, "tras mover, espera al rival")
	demo._online_ended("abandoned", 1)
	await _frames(3)
	_ok(demo.game_state == "over" and demo.game_won == 1, "si el rival abandona, ganamos")
	demo._leave_game()
	await _frames(3)
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
