extends SceneTree
## Espera online con Robi (core/wait_bot.gd, docs/espera-bot.md): cuándo se ofrece, que siempre se dice que es un
## bot, y su trato de rival humano (saluda, felicita alguna captura, piensa un poco, se despide).
## Uso: godot --headless --path godot -s tests/test_espera_bot.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	# Cuándo se ofrece.
	_ok(Online.bot_offer_s(0) == 15, "nadie esperando en otros espacios: 15 s")
	_ok(Online.bot_offer_s(1) == 30 and Online.bot_offer_s(3) == 60, "más gente esperando: se espera más")
	_ok(Online.bot_offer_s(50) == 120, "como mucho, 2 minutos")
	_ok(Online.bot_offer_s(-2) == 15, "recuento raro: 15 s")

	# Nivel a la medida.
	_ok(Bot.closest_level(0.0) == Bot.group_levels(1)[0], "sin rating: el primer «Fácil»")
	_ok(absf(float(Bot.LEVELS[Bot.closest_level(1600.0)]["elo"]) - 1600.0) < 200.0, "con 1600: un nivel cercano")
	_ok(float(Bot.LEVELS[Bot.closest_level(400.0)]["elo"]) < float(Bot.LEVELS[Bot.closest_level(1800.0)]["elo"]), "más rating, nivel más fuerte")

	# Trato humano.
	var start := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
	var no_knight := "rnbqkb1r/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"
	_ok(WaitBot.captured_value(start, no_knight, 0) == 3, "las blancas capturan un caballo: 3")
	_ok(WaitBot.captured_value(start, no_knight, 1) == 0, "visto por las negras: no han capturado nada")
	_ok(WaitBot.cheer_for(9, false, 10, 0.9) == "genial", "captura la dama: «¡Genial!»")
	_ok(WaitBot.cheer_for(3, false, 10, 0.1) == "arriba", "captura una pieza: «Bien»")
	_ok(WaitBot.cheer_for(3, false, 10, 0.9) == "", "no siempre felicita")
	_ok(WaitBot.cheer_for(5, true, 10, 0.1) == "", "si la captura es un error, no felicita")
	_ok(WaitBot.cheer_for(5, false, 1, 0.1) == "", "no felicita dos veces seguidas")
	_ok(WaitBot.cheer_for(1, false, 10, 0.1) == "", "un peón no se celebra")
	_ok(WaitBot.farewell(1) == ["aplauso", "buena"] and WaitBot.farewell(-1) == ["buena"] and WaitBot.farewell(0) == ["buena"], "se despide con «Buena partida» (y «¡Bravo!» si ganas)")
	var t := WaitBot.think_ms(0.5, 20, 0.0)
	_ok(t >= 1200.0 and t <= 4000.0, "piensa como una persona: %d ms" % int(t))
	_ok(WaitBot.think_ms(1.0, 20, 20000.0) <= 550.0 + 0.1, "con poco reloj, va rápido")
	_ok(WaitBot.think_ms(1.0, 2, 0.0) <= 1500.0, "las primeras jugadas, rápidas")

	# En la app.
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo.view.board.anim_mode = Board3D.Anim.NONE
	demo.online_name = "Pablo"
	demo.online_space = "5+3"
	demo.online_busy = true
	demo.online_bot_offer = false
	demo._wait_gen += 1
	demo._open_online()
	await _frames(3)
	_ok(not _has_text(demo.progress, "un bot de la app"), "al principio no se ofrece el bot")
	demo._offer_bot_later(demo._wait_gen, 0)
	await _frames(3)
	await create_timer(0.1).timeout
	await _frames(3)
	_ok(demo.online_bot_offer, "pasado el tiempo, se ofrece")
	var b := _button_with(demo.progress, "un bot de la app")
	_ok(b != null, "botón «Jugar contra Robi, un bot de la app»")
	_ok(_has_text(demo.progress, "Es un bot, no una persona"), "y se dice claramente que es un bot")
	# Un ofrecimiento viejo (otra búsqueda) no cuenta.
	var old_gen: int = demo._wait_gen
	demo._wait_gen += 1
	demo.online_bot_offer = false
	demo._offer_bot_later(old_gen, 0)
	await create_timer(0.1).timeout
	_ok(not demo.online_bot_offer, "el temporizador de una búsqueda anterior no ofrece nada")
	demo.online_bot_offer = true
	demo._open_online()
	await _frames(3)
	b = _button_with(demo.progress, "un bot de la app")
	b.emit_signal("pressed")
	await _frames(6)
	_ok(demo.mode == "game" and bool(demo.game.get("wait_bot", false)), "empieza la partida contra Robi")
	_ok(str(demo.game["title"]).contains("Robi") and str(demo.game["title"]).contains("bot"), "el título dice que es un bot: %s" % demo.game["title"])
	_ok(demo.game_clocked and absf(demo.game_inc_ms - 3000.0) < 1.0 and absf(demo.game_clock[0] - 300000.0) < 10000.0 and absf(demo.game_clock[1] - 300000.0) < 10000.0, "con el ritmo del espacio (5+3): %s" % str(demo.game_clock))
	_ok(not demo.online_busy and not bool(demo.game.get("online", false)), "ya no busca rival y no es una partida online")
	print("espera con bot: %d de %d bien" % [hechos - fallos, hechos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _button_with(node: Node, text: String) -> Button:
	if node is Button and ((node as Button).text.contains(text) or _has_text_below(node, text)):
		return node
	for c in node.get_children():
		var f := _button_with(c, text)
		if f != null:
			return f
	return null


func _has_text_below(node: Node, text: String) -> bool:
	for c in node.get_children():
		if _has_text(c, text):
			return true
	return false


func _has_text(node: Node, text: String) -> bool:
	if node == null:
		return false
	if (node is Label and (node as Label).text.contains(text)) or (node is Button and (node as Button).text.contains(text)):
		return true
	for c in node.get_children():
		if _has_text(c, text):
			return true
	return false


func _ok(cond: bool, what: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + what)
