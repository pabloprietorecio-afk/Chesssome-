extends SceneTree
## Mide la fuerza de los niveles del rival de la app (core/bot.gd) jugando partidas: contra Stockfish con fuerza
## limitada (UCI_LimitStrength + UCI_Elo, anclado a CCRL 40/4 según la documentación de Stockfish) o contra otro
## nivel. Se usa en la CI (.github/workflows/calibrar-bot.yml); el ajuste final lo hace tools/calibrar/ajustar.py.
##
## Uso: godot --headless --path godot -s tests/calibrar.gd -- --a 3 --b sf:1320 --partidas 24 --salida res.json
##      [--stockfish /usr/games/stockfish] [--semilla 1]
## Stockfish juega con reloj de 60 s + 0,6 s por jugada, el ritmo con el que está calibrado su UCI_Elo.
##   --a      nivel del bot (índice de Bot.LEVELS: 0–12)
##   --b      otro nivel («2») o Stockfish con un Elo («sf:1320»)
## Colores alternos y aperturas variadas (líneas conocidas de unas pocas jugadas), para que los niveles sin ruido
## no repitan siempre la misma partida. Más de 160 jugadas (medias) = tablas.

const OPENINGS := [
	"",
	"e2e4 e7e5 g1f3 b8c6 f1c4 f8c5",
	"e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6",
	"e2e4 e7e6 d2d4 d7d5",
	"e2e4 c7c6 d2d4 d7d5",
	"d2d4 d7d5 c2c4 e7e6 b1c3 g8f6",
	"d2d4 g8f6 c2c4 g7g6 b1c3 f8g7",
	"c2c4 e7e5 b1c3 g8f6",
	"e2e4 d7d5 e4d5 d8d5 b1c3 d5a5",
	"e2e4 e7e5 g1f3 b8c6 f1b5 a7a6",
	"g1f3 d7d5 g2g3 g8f6 f1g2",
	"e2e4 g7g6 d2d4 f8g7",
]

var _sf_pipe: FileAccess
var _sf_pid := -1
const SF_START_MS := 60000.0
const SF_INC_MS := 600.0


func _init() -> void:
	var args := _args()
	var a := int(args.get("a", "0"))
	var b := str(args.get("b", "1"))
	var games := int(args.get("partidas", "10"))
	var out_path := str(args.get("salida", "res.json"))
	var seed_base := int(args.get("semilla", "1"))
	if b.begins_with("sf:"):
		if not _sf_start(str(args.get("stockfish", "stockfish")), int(b.substr(3))):
			print("ERROR: no se puede arrancar Stockfish")
			quit(1)
			return
	var score := 0.0
	var results: Array = []
	for g in games:
		var a_white := g % 2 == 0
		var opening: String = OPENINGS[(g / 2) % OPENINGS.size()]
		var bot_a := Bot.new(a, "", seed_base * 1000 + g)
		var bot_b: Bot = null if b.begins_with("sf:") else Bot.new(int(b), "", seed_base * 1000 + g + 500)
		var r := _play(bot_a, bot_b, a_white, opening)
		# r: 1 gana blancas, 0 tablas, −1 ganan negras → puntos de A
		var pts := 0.5 if r == 0 else (1.0 if (r == 1) == a_white else 0.0)
		score += pts
		results.append({"partida": g, "a_blancas": a_white, "apertura": opening, "puntos_a": pts})
		print("partida %d: A %s · %s → %.1f (total %.1f/%d)" % [g + 1, "blancas" if a_white else "negras", "inicial" if opening == "" else opening.substr(0, 20), pts, score, g + 1])
	if _sf_pid >= 0:
		_sf_send("quit")
	var data := {"a": a, "b": b, "partidas": games, "puntos_a": score, "reloj_stockfish": "60+0.6", "resultados": results}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("HECHO %s" % JSON.stringify({"a": a, "b": b, "partidas": games, "puntos_a": score}))
	quit()


func _args() -> Dictionary:
	var out := {}
	var list := OS.get_cmdline_user_args()
	var i := 0
	while i < list.size():
		var k := str(list[i])
		if k.begins_with("--") and i + 1 < list.size():
			out[k.substr(2)] = str(list[i + 1])
			i += 2
		else:
			i += 1
	return out


## Una partida. Devuelve 1 (ganan blancas), 0 (tablas) o −1 (ganan negras).
func _play(bot_a: Bot, bot_b: Bot, a_white: bool, opening: String) -> int:
	var pos := Chess.from_fen(Board3D.START_FEN)
	var played: Array = []
	var seen := {}
	for u in opening.split(" ", false):
		var m0 := pos.find_uci(u)
		if m0 < 0:
			break
		pos.apply(m0)
		played.append(u)
	var start := Board3D.START_FEN
	var sf_ms := SF_START_MS
	for ply in 160:
		if pos.legal_moves().is_empty():
			if pos.in_check():
				return -1 if pos.turn == 0 else 1
			return 0
		if pos.half >= 100 or _bare(pos):
			return 0
		var key := " ".join(pos.fen().split(" ").slice(0, 4))
		seen[key] = int(seen.get(key, 0)) + 1
		if int(seen[key]) >= 3:
			return 0
		var a_turn := (pos.turn == 0) == a_white
		var m := -1
		if a_turn:
			m = bot_a.choose(pos)
		elif bot_b != null:
			m = bot_b.choose(pos)
		else:
			var t0 := Time.get_ticks_msec()
			m = pos.find_uci(_sf_move(start, played, sf_ms))
			sf_ms -= float(Time.get_ticks_msec() - t0)
			if sf_ms <= 0.0:
				# Stockfish pierde por tiempo (no debería pasar).
				return 1 if a_white else -1
			sf_ms += SF_INC_MS
		if m < 0:
			print("ERROR: jugada no válida en %s" % pos.fen())
			return 0
		played.append(Chess.uci(m))
		pos.apply(m)
	return 0


func _bare(pos: Chess) -> bool:
	var minors := 0
	for p in pos.b:
		if p == 0:
			continue
		var t := Chess.type_of(p)
		if t == Chess.PAWN or t == Chess.ROOK or t == Chess.QUEEN:
			return false
		if t == Chess.KNIGHT or t == Chess.BISHOP:
			minors += 1
	return minors <= 1


# ---------------------------------------------------------------- Stockfish por UCI

func _sf_start(path: String, elo: int) -> bool:
	var info := OS.execute_with_pipe(path, [])
	if info.is_empty():
		return false
	_sf_pipe = info["stdio"]
	_sf_pid = int(info["pid"])
	_sf_send("uci")
	_sf_wait("uciok")
	_sf_send("setoption name Threads value 1")
	_sf_send("setoption name Hash value 16")
	_sf_send("setoption name UCI_LimitStrength value true")
	_sf_send("setoption name UCI_Elo value %d" % elo)
	_sf_send("isready")
	_sf_wait("readyok")
	return true


func _sf_send(line: String) -> void:
	_sf_pipe.store_string(line + "\n")
	_sf_pipe.flush()


func _sf_wait(prefix: String) -> String:
	var until := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		var line := _sf_pipe.get_line()
		if line.begins_with(prefix):
			return line
		if line == "":
			OS.delay_msec(2)
	print("ERROR: Stockfish no responde (%s)" % prefix)
	return ""


func _sf_move(start: String, played: Array, clock_ms: float) -> String:
	_sf_send("position fen %s moves %s" % [start, " ".join(PackedStringArray(played))] if not played.is_empty() else "position fen %s" % start)
	var c := int(clock_ms)
	_sf_send("go wtime %d btime %d winc %d binc %d" % [c, c, int(SF_INC_MS), int(SF_INC_MS)])
	var line := _sf_wait("bestmove")
	return line.split(" ")[1] if line.split(" ").size() > 1 else ""
