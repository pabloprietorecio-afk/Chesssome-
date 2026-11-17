extends SceneTree
## Simulación de War Chess (no va en la CI): el rival contra sí mismo, en War Chess y en ajedrez clásico, para ver
## si el blindaje cambia algo o solo alarga la partida un turno.
## Uso: godot --headless --path godot -s tests/sim_war.gd -- <war|classic> <partidas> <nivel> <semilla> [segundos por jugada]
## Escribe una línea JSON por partida (SIM {...}).

const MAX_PLIES := 240


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "war"
	var games := int(args[1]) if args.size() > 1 else 4
	var level := int(args[2]) if args.size() > 2 else 11
	var seed_value := int(args[3]) if args.size() > 3 else 1
	var think := float(args[4]) if args.size() > 4 else 0.15
	for g in games:
		_play(mode, level, seed_value * 1000 + g, think)
	quit(0)


func _material(c: Chess) -> int:
	var v := 0
	for p in c.b:
		if p != 0:
			v += (1 if Chess.color_of(p) == 0 else -1) * int(Bot.VALUE[p & 7])
	return v


func _play(mode: String, level: int, seed_value: int, think: float) -> void:
	var war := mode == "war"
	var bots := [Bot.new(level, "war" if war else "", seed_value), Bot.new(level, "war" if war else "", seed_value + 7)]
	for b: Bot in bots:
		b.time_cap = think
	# Apertura variada: dos jugadas al azar por bando (siempre normales), para no repetir la misma partida.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Chess = WarChess.from_war_fen(WarChess.start_fen(Board3D.START_FEN)) if war else Chess.from_fen(Board3D.START_FEN)
	var history := {}
	var plies := 0
	var result := "limite"
	var stats := {"armor": 0, "armor_threat": 0, "armor_calm": 0, "breaks": 0, "break_then_captured": 0,
		"break_then_saved": 0, "armored_never_hit": 0, "armor_in_mate": 0, "cracks": 0, "pawn_armor": 0}
	# Para cada golpe: casilla de la pieza que perdió el blindaje y la jugada en la que ocurrió.
	var pending: Array = []
	while plies < MAX_PLIES:
		var moves := c.legal_moves()
		if moves.is_empty():
			result = "mate" if c.in_check() else "ahogado"
			break
		if c.half >= 100:
			result = "50"
			break
		var key := c.fen().split(" ")
		var k := " ".join(key.slice(0, 4)) + (" " + key[6] if key.size() > 6 else "")
		history[k] = int(history.get(k, 0)) + 1
		if int(history[k]) >= 3:
			result = "repeticion"
			break
		var m := -1
		if plies < 4:
			var normal: Array = []
			for x in moves:
				if not WarChess.is_armor_move(x):
					normal.append(x)
			m = normal[rng.randi() % normal.size()]
		else:
			m = (bots[c.turn] as Bot).choose(c)
		if war:
			var w := c as WarChess
			if WarChess.is_armor_move(m):
				stats["armor"] += 1
				if Chess.type_of(c.b[Chess.move_from(m)]) == Chess.PAWN:
					stats["pawn_armor"] += 1
				if c.attacked(Chess.move_from(m), 1 - c.turn):
					stats["armor_threat"] += 1
				else:
					stats["armor_calm"] += 1
			elif WarChess.is_break_move(m):
				if w.hits_left(Chess.move_to(m), Chess.move_from(m)) >= 2:
					stats["cracks"] += 1
				else:
					stats["breaks"] += 1
					pending.append([Chess.move_to(m), plies, w.b[Chess.move_to(m)]])
		# ¿La pieza que perdió el blindaje cae justo después? Golpe en la media jugada p; el dueño contesta en p+1
		# (puede apartarla, defenderla o volver a… no: ya no puede blindarla); el rival captura o no en p+2.
		var still: Array = []
		for pnd: Array in pending:
			var sq := int(pnd[0])
			var age := plies - int(pnd[1])
			if age == 1:
				if Chess.move_from(m) == sq and not WarChess.is_armor_move(m):
					pnd[0] = Chess.move_to(m)
				still.append(pnd)
			elif age == 2:
				if Chess.move_to(m) == sq and not WarChess.is_break_move(m) and not WarChess.is_armor_move(m) and c.b[sq] == int(pnd[2]):
					stats["break_then_captured"] += 1
				else:
					stats["break_then_saved"] += 1
			else:
				still.append(pnd)
		pending = still
		c.apply(m)
		plies += 1
	if war:
		var w := c as WarChess
		for s in 64:
			if w.is_armored(s):
				stats["armored_never_hit"] += 1
	var out := {"mode": mode, "level": level, "seed": seed_value, "plies": plies, "result": result,
		"winner": (1 - c.turn) if result == "mate" else -1, "material": _material(c)}
	out.merge(stats)
	print("SIM ", JSON.stringify(out))
