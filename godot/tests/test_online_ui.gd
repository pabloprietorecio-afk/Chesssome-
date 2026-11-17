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

	# War Chess online (Pablo, 17-11): modalidad en la lista de espacios; sus espacios llevan una «w» delante.
	demo.online_busy = false
	demo.online_name = "Prueba"
	demo.online_war = false
	demo._open_online()
	await _frames(3)
	var modes := _buttons_named(demo.progress, ["Clásica", "War Chess"])
	_ok(modes.size() == 2, "«Clásica» y «War Chess» en «Partida online»")
	_ok(_space_labels(demo.progress).has("5+3") and not _space_labels(demo.progress).has("w5+3"), "en Clásica, los espacios de siempre")
	modes[1].emit_signal("pressed")
	await _frames(3)
	_ok(demo.online_war, "War Chess elegido")
	var wl := _space_labels(demo.progress)
	_ok(wl.has("w5+3") and wl.has("w0+0") and not wl.has("5+3"), "en War Chess, sus espacios (%s)" % str(wl))
	demo.online_spaces = {"w7+2": 1, "9+0": 1}
	demo._open_online()
	await _frames(3)
	wl = _space_labels(demo.progress)
	_ok(wl.has("w7+2") and not wl.has("9+0"), "los personalizados, solo los de su modalidad")
	demo.online_spaces = {}
	demo.online_busy = true
	demo.online_space = "w5+3"
	demo._open_online()
	await _frames(2)
	_ok(_has_text(demo.progress, "War Chess · 5+3"), "buscando rival: «Espacio War Chess · 5+3»")
	demo.online.rhythm = "w0+0"
	demo.online.base_ms = 0.0
	demo.online.inc_ms = 0.0
	demo._online_started(1)
	await _frames(3)
	_ok(demo.mode == "game" and str(demo.game.get("variant", "")) == "war" and demo.view.board.chess is WarChess, "empieza una partida online de War Chess")
	_ok(str(demo.game.get("title", "")) == "War Chess online", "titulada «War Chess online»")
	demo._online_move("g1g1")
	await _frames(3)
	_ok(demo.game_moves.size() == 1 and (demo.view.board.chess as WarChess).spent[Chess.sq_index("g1")] == 1, "llega un blindaje del rival (g1g1) y se aplica")
	_ok(str(demo.game_note).contains("blindado"), "con su nota: %s" % demo.game_note)
	_ok(demo.game_state == "play" and demo.view.interactive, "y me toca")
	demo.view.board.select(Chess.sq_index("g8"))
	demo.view._sync_armor_button()
	_ok(demo.view._armor_button.visible, "puedo blindar en la partida online")
	demo._online_ended("abandoned", 1)
	await _frames(3)
	_ok(demo.game_state == "over", "la partida de War Chess online termina")
	demo._leave_game()
	demo.online_busy = false
	demo.online_war = false
	await _frames(3)

	# Partida con reloj (5+3), sin red: lo que diría la base de datos se pone a mano.
	var on: Online = demo.online
	on.rhythm = "5+3"
	on.base_ms = 300000.0
	on.inc_ms = 3000.0
	on.phase = "playing"
	on.my_color = 1
	on._applied = 0
	var t0: float = on._server_now() - 5000.0
	on._clock = Online.clock_state({"unidoEn": t0}, 300000.0, 3000.0)
	demo.press_clock = true
	demo._online_started(1)
	await _frames(3)
	_ok(demo.game_clocked and demo.game_state == "think", "con reloj y negras, espera al rival")
	_ok(absf(float(demo.game_clock[0]) - 295000.0) < 2000.0 and absf(float(demo.game_clock[1]) - 300000.0) < 1.0, "corre el reloj de blancas desde que entró el rival (%s)" % str(demo.game_clock))
	on._applied = 1
	demo._online_move("e2e4")
	await _frames(2)
	_ok(demo.game_state == "think" and not demo.view.interactive, "se ve su jugada, pero hasta que pulse su reloj no me toca")
	on._clock = Online.clock_state({"unidoEn": t0, "pulsos": {"0": t0 + 4000.0}}, 300000.0, 3000.0)
	demo._online_clock_changed()
	await _frames(2)
	_ok(demo.game_state == "play" and demo.view.interactive, "pulsa su reloj y me toca")
	demo.view.show_move("e7e5")
	demo._game_move("e7e5")
	await _frames(2)
	_ok(demo.game_state == "press", "con pulsado a mano, tras mover toca pulsar el reloj")
	on.phase = "ended" # que no intente escribir en la red
	on._clock = Online.clock_state({"unidoEn": t0 - 400000.0, "pulsos": {"0": t0 - 399000.0}}, 300000.0, 3000.0)
	await _frames(3)
	_ok(demo.game_state == "over" and demo.game_won == -1, "si se me acaba el tiempo, pierdo (%s, %d)" % [demo.game_state, demo.game_won])
	demo._leave_game()
	await _frames(2)

	# Espacios: el rival que espera en 5+3 se ve en verde; el personalizado aparece en la lista.
	demo.online_name = "Prueba"
	demo.online_spaces = {"5+3": 2, "7+2": 1}
	demo.online_spaces_ok = true
	demo._open_online()
	await _frames(3)
	var labels: Array = []
	for b: Node in demo.progress.find_children("*", "Button", true, false):
		if b.has_meta("label"):
			labels.append(str(b.get_meta("label")))
	_ok(labels.has("5+3") and labels.has("7+2") and labels.has("0+0") and labels.has("otro"), "los espacios en la lista (%s)" % str(labels))
	_ok(demo._rhythm_kind("5+3")[0] == "Blitz" and demo._rhythm_kind("10+5")[0] == "Rápida" and demo._rhythm_kind("30+0")[0] == "Clásica", "tipo de partida por su duración")
	demo._close_online()
	await _frames(2)
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


func _buttons_named(n: Node, labels: Array) -> Array:
	var out: Array = []
	for l: String in labels:
		var b := _find_button(n, Loc.t(l))
		if b != null:
			out.append(b)
	return out


func _find_button(n: Node, text: String) -> Button:
	if n is Button and _first_label(n) == text:
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _first_label(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	for c in n.get_children():
		var t := _first_label(c)
		if t != "":
			return t
	return ""


## Espacios a la vista (meta «label» de cada tesela).
func _space_labels(n: Node) -> Array:
	var out: Array = []
	if n is Button and n.has_meta("label"):
		out.append(str(n.get_meta("label")))
	for c in n.get_children():
		out.append_array(_space_labels(c))
	return out


func _has_text(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text.contains(text):
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false
