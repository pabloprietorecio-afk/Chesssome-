extends SceneTree
## Prueba del rival de las partidas (core/bot.gd):
##   - nunca propone una jugada ilegal y, sin jugadas, devuelve −1
##   - en todos los niveles da el mate en una cuando lo hay y, desde «Medio», no deja una dama a tiro gratis
##   - piensa dentro de su tiempo
##   - la guerra de peones: quién gana y que el rival corona cuando puede
##   - partidas enteras entre niveles: el más fuerte gana casi siempre al más flojo
## Uso: godot --headless --path godot -s tests/test_bot.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	# Mate en una: Ta8#.
	var mate := Chess.from_fen("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1")
	for lvl in Bot.LEVELS.size():
		var bot := Bot.new(lvl, "", 7)
		_comprueba(Chess.uci(bot.choose(mate)) == "a1a8", "nivel %d: da el mate en una" % lvl)
	# Dama negra a tiro gratis en d5 (Cxd5).
	var free := Chess.from_fen("4k3/8/8/3q4/8/2N5/8/4K3 w - - 0 1")
	for lvl in range(2, Bot.LEVELS.size()):
		_comprueba(Chess.uci(Bot.new(lvl, "", 3).choose(free)) == "c3d5", "nivel %d: captura la dama gratis" % lvl)
	# Con la dama atacada por un peón, desde «Medio» la aparta.
	var hang := Chess.from_fen("4k3/8/8/2p5/3Q4/8/8/4K3 w - - 0 1")
	for lvl in range(2, Bot.LEVELS.size()):
		var m := Bot.new(lvl, "", 5).choose(hang)
		var after := hang.after(m)
		_comprueba(not after.attacked(Chess.move_to(m), 1) or Chess.move_to(m) == Chess.sq_index("c5"), "nivel %d: no deja la dama a tiro (%s)" % [lvl, Chess.uci(m)])
	# Sin jugadas.
	_comprueba(Bot.new(2).choose(Chess.from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")) == -1, "ahogado: sin jugada")
	# Tiempo: el nivel más alto en la posición inicial.
	var t0 := Time.get_ticks_msec()
	var top := Bot.new(Bot.LEVELS.size() - 1, "", 1)
	var first := top.choose(Chess.from_fen(Board3D.START_FEN))
	var ms := Time.get_ticks_msec() - t0
	print("Muy difícil, posición inicial: %s en %d ms, %d nodos" % [Chess.uci(first), ms, top.nodes])
	_comprueba(ms < int(float(Bot.LEVELS[-1]["think"]) * 1000.0) + 1500, "piensa dentro de su tiempo (%d ms)" % ms)
	# Guerra de peones.
	var peones := Chess.from_fen("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
	var e4 := peones.find_uci("e2e4")
	_comprueba(Bot.peones_result(peones.after(e4), e4) == -1, "peones: al empezar no gana nadie")
	var promo_pos := Chess.from_fen("8/P7/8/8/8/8/p7/8 w - - 0 1")
	var a8 := promo_pos.find_uci("a7a8q")
	_comprueba(Bot.peones_result(promo_pos.after(a8), a8) == 0, "peones: corona blancas")
	var last := Chess.from_fen("8/8/8/8/8/1p6/2P5/8 w - - 0 1")
	var take := last.find_uci("c2b3")
	_comprueba(Bot.peones_result(last.after(take), take) == 0, "peones: negras sin piezas")
	var stuck := Chess.from_fen("8/8/8/8/8/p7/P7/8 w - - 0 1")
	_comprueba(Bot.new(2, "peones").choose(stuck) == -1, "peones: blancas sin jugadas")
	# El caballo puede capturar el peón que va a coronar: lo hace.
	var defend := Chess.from_fen("8/8/8/8/8/1p6/8/2N5 w - - 0 1")
	_comprueba(Chess.uci(Bot.new(2, "peones", 4).choose(defend)) == "c1b3", "peones: el caballo captura el peón que iba a coronar")
	var race := Chess.from_fen("8/1P6/8/8/8/8/6p1/8 w - - 0 1")
	_comprueba(Chess.uci(Bot.new(0, "peones", 2).choose(race)) == "b7b8q", "peones: corona cuando puede")
	# Guerra de peones entera: «Medio» contra «Muy fácil».
	var won := 0
	for g in 2:
		var r := _play_peones(2, 0, g == 0, 50 + g)
		print("Guerra de peones nivel 2 contra nivel 0: %s" % r)
		if r == "fuerte":
			won += 1
	_comprueba(won >= 1, "peones: el nivel 2 gana al 0")
	# Partidas: cada nivel contra el más flojo.
	for lvl in [2, 4]:
		var wins := 0
		# El nivel más alto piensa segundos por jugada: una sola partida, para que la prueba no tarde demasiado.
		var games := 2 if lvl < 4 else 1
		for g in games:
			var r := _play(lvl, 0, g % 2 == 0, 100 + g)
			if r == "fuerte":
				wins += 1
			print("Partida nivel %d contra nivel 0 (%s): %s" % [lvl, "blancas" if g % 2 == 0 else "negras", r])
		_comprueba(wins >= games - (1 if games > 1 else 0), "nivel %d gana al nivel 0 (%d de %d)" % [lvl, wins, games])
	# Notación en español.
	var start := Chess.from_fen(Board3D.START_FEN)
	_comprueba(SanEs.san(start, start.find_uci("g1f3")) == "Cf3", "notación: Cf3")
	_comprueba(SanEs.san(mate, mate.find_uci("a1a8")) == "Ta8#", "notación: Ta8#")
	var two := Chess.from_fen("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
	_comprueba(SanEs.san(two, two.find_uci("a1d1")) == "Tad1", "notación: Tad1 (%s)" % SanEs.san(two, two.find_uci("a1d1")))
	var castle_pos := Chess.from_fen("4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
	_comprueba(SanEs.san(castle_pos, castle_pos.find_uci("e1g1")) == "O-O", "notación: O-O")
	var ep_pos := Chess.from_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	_comprueba(SanEs.san(ep_pos, ep_pos.find_uci("e5d6")) == "exd6", "notación: exd6")
	print("Rival: %d comprobaciones, %d fallos" % [hechos, fallos])
	print("TODO OK" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	quit(0 if fallos == 0 else 1)


## Juega una partida entera; devuelve "fuerte", "flojo" o "tablas".
func _play(strong: int, weak: int, strong_white: bool, seed_value: int) -> String:
	var pos := Chess.from_fen(Board3D.START_FEN)
	var bots := [Bot.new(strong if strong_white else weak, "", seed_value), Bot.new(weak if strong_white else strong, "", seed_value + 1)]
	for ply in 240:
		var m: int = bots[pos.turn].choose(pos)
		if m < 0:
			if not pos.in_check():
				return "tablas"
			var loser_white := pos.turn == 0
			return "flojo" if loser_white == strong_white else "fuerte"
		_comprueba(pos.legal_moves().has(m), "jugada legal en la partida (%s)" % Chess.uci(m))
		pos.apply(m)
		if pos.half >= 100:
			return "tablas"
	return "tablas"


func _play_peones(strong: int, weak: int, strong_white: bool, seed_value: int) -> String:
	var pos := Chess.from_fen("8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1")
	var bots := [Bot.new(strong if strong_white else weak, "peones", seed_value), Bot.new(weak if strong_white else strong, "peones", seed_value + 1)]
	for ply in 200:
		var me := pos.turn
		var m: int = bots[me].choose(pos)
		if m < 0:
			return "flojo" if (me == 0) == strong_white else "fuerte"
		pos.apply(m)
		var w := Bot.peones_result(pos, m)
		if w >= 0:
			return "fuerte" if (w == 0) == strong_white else "flojo"
	return "tablas"


func _comprueba(cierto: bool, mensaje: String) -> void:
	hechos += 1
	if not cierto:
		fallos += 1
		if fallos <= 20:
			print("FALLA " + mensaje)
