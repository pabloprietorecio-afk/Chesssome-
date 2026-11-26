extends SceneTree
## «Importar mis partidas» (core/pgn.gd y core/game_import.gd): el lector de PGN frente a python-chess
## (tests/golden/pgn.json, de tools/importar/oro_pgn.py), las respuestas de Lichess (PGN) y de Chess.com (JSON), el
## resultado y cómo terminó cada partida para el jugador, y el guardado aparte de «Mis partidas».
## Uso: godot --headless --path godot -s tests/test_importar.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	_golden()
	_san_cases()
	_lichess()
	_chesscom()
	_store()
	_requests()
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## 40 partidas al azar de python-chess, escritas como las da Chess.com (con relojes y «1...») y como Lichess.
func _golden() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/pgn.json"))
	var bad := 0
	var n := 0
	for c: Dictionary in data["cases"]:
		var text := "[Event \"Prueba\"]\n[White \"a\"]\n[Black \"b\"]\n[Result \"%s\"]\n\n%s\n" % [str(c["result"]), str(c["movetext"])]
		var games := Pgn.parse_games(text)
		if games.size() != 1:
			bad += 1
			continue
		var play := Pgn.replay(games[0])
		var final_core := " ".join(str(c["final"]).split(" ").slice(0, 3))
		var ok: bool = play["jugadas"] == c["uci"] and bool(play["completa"]) and Chess.from_fen(str(play["final"])).fen_core() == final_core and bool(play["mate"]) == bool(c["mate"]) and bool(play["ahogado"]) == bool(c["stalemate"])
		if not ok:
			bad += 1
			print("  partida %d (%s): %d de %d jugadas" % [n, str(c["style"]), (play["jugadas"] as Array).size(), (c["uci"] as Array).size()])
		n += 1
	_ok(n == 40 and bad == 0, "40 partidas de python-chess: mismas jugadas, misma posición final, mate y ahogado (%d mal)" % bad)
	var st: Dictionary = data["stats"]
	_ok(int(st["enroques"]) > 0 and int(st["al_paso"]) > 0 and int(st["coronaciones"]) > 0 and int(st["desambiguadas"]) > 0, "las partidas de oro pasan por enroques, al paso, coronaciones y desambiguación")


func _san_cases() -> void:
	var start := Chess.from_fen(Board3D.START_FEN)
	_ok(Chess.uci(Pgn.san_move(start, "Nf3")) == "g1f3", "Nf3")
	_ok(Chess.uci(Pgn.san_move(start, "e4!?")) == "e2e4", "con signos de anotación")
	_ok(Pgn.san_move(start, "Ke2") < 0, "jugada ilegal: -1")
	_ok(Pgn.san_move(start, "") < 0 and Pgn.san_move(start, "zz9") < 0, "texto raro: -1")
	# Enroques con «0-0» (cero) además de «O-O».
	var castle := Chess.from_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	_ok(Chess.uci(Pgn.san_move(castle, "0-0")) == "e1g1", "0-0 con ceros")
	_ok(Chess.uci(Pgn.san_move(castle, "O-O-O+")) == "e1c1", "O-O-O")
	# Dos caballos que pueden ir a d7: sin decir cuál no vale; con la columna, sí.
	var knights := Chess.from_fen("4k3/8/8/8/8/2N1N3/8/4K3 w - - 0 1")
	_ok(Pgn.san_move(knights, "Nd5") < 0, "ambigua sin desambiguar: -1")
	_ok(Chess.uci(Pgn.san_move(knights, "Ncd5")) == "c3d5" and Chess.uci(Pgn.san_move(knights, "Ned5")) == "e3d5", "desambiguación por columna")
	var rooks := Chess.from_fen("4k3/R7/8/8/8/8/R7/4K3 w - - 0 1")
	_ok(Chess.uci(Pgn.san_move(rooks, "R2a5")) == "a2a5" and Chess.uci(Pgn.san_move(rooks, "R7a5")) == "a7a5", "desambiguación por fila")
	# Coronaciones: «e8=Q», «e8Q», y «bxa8=N».
	var promo := Chess.from_fen("rn5k/1P2P3/8/8/8/8/8/4K3 w - - 0 1")
	_ok(Chess.uci(Pgn.san_move(promo, "e8=Q+")) == "e7e8q", "e8=Q")
	_ok(Chess.uci(Pgn.san_move(promo, "e8R")) == "e7e8r", "e8R sin «=»")
	_ok(Chess.uci(Pgn.san_move(promo, "bxa8=N")) == "b7a8n", "captura coronando")
	_ok(Chess.uci(Pgn.san_move(promo, "bxa8=Q")) == "b7a8q", "bxa8=Q")
	# Al paso, con y sin «e.p.».
	var ep := Chess.from_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	_ok(Chess.uci(Pgn.san_move(ep, "exd6")) == "e5d6" and Chess.uci(Pgn.san_move(ep, "exd6 e.p.")) == "e5d6", "al paso")
	# Comentarios, variantes anidadas, NAG, «;» y el resultado no son jugadas.
	var sans := Pgn.moves_of("1. e4 {buena} (1. d4 d5 (1... Nf6)) 1... e5 $1 2. Nf3; comentario hasta el final\n2... Nc6 1-0")
	_ok(sans == ["e4", "e5", "Nf3", "Nc6"], "se saltan comentarios, variantes, signos y el resultado")
	_ok(Pgn.moves_of("1.e4 e5 2.Nf3") == ["e4", "e5", "Nf3"], "número pegado a la jugada")
	# Una jugada que no se puede leer: la partida se corta ahí.
	var cut := Pgn.replay({"tags": {}, "sans": ["e4", "e5", "Ke3", "Nc6"]})
	_ok((cut["jugadas"] as Array).size() == 2 and not bool(cut["completa"]), "jugada ilegal: la partida se corta ahí")
	# Desde una posición (cabecera FEN).
	var from_pos := Pgn.replay({"tags": {"FEN": "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1", "SetUp": "1"}, "sans": ["e4", "Kd7"]})
	_ok(from_pos["jugadas"] == ["e2e4", "e8d7"] and str(from_pos["inicio"]).begins_with("4k3/"), "partida desde una posición")


const LICHESS_PGN := """[Event "Rated blitz game"]
[Site "https://lichess.org/AbCd1234"]
[Date "2026.11.20"]
[White "PabloTest"]
[Black "rival_uno"]
[Result "1-0"]
[UTCDate "2026.11.20"]
[UTCTime "18:03:12"]
[WhiteElo "1500"]
[BlackElo "1480"]
[Variant "Standard"]
[TimeControl "180+2"]
[ECO "C20"]
[Termination "Normal"]

1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0


[Event "Rated rapid game"]
[Site "https://lichess.org/EfGh5678"]
[Date "2026.11.21"]
[White "OtroJugador"]
[Black "pablotest"]
[Result "1-0"]
[UTCDate "2026.11.21"]
[UTCTime "09:00:00"]
[WhiteElo "1610"]
[BlackElo "1502"]
[Variant "Standard"]
[TimeControl "600+0"]
[Termination "Time forfeit"]

1. d4 d5 2. c4 e6 3. Nc3 Nf6 1-0


[Event "Casual chess960 game"]
[Site "https://lichess.org/Chess960x"]
[White "PabloTest"]
[Black "alguien"]
[Result "0-1"]
[UTCDate "2026.11.22"]
[UTCTime "10:00:00"]
[Variant "Chess960"]
[FEN "bbqnnrkr/pppppppp/8/8/8/8/PPPPPPPP/BBQNNRKR w HFhf - 0 1"]

1. e4 e5 0-1


[Event "Rated blitz game"]
[Site "https://lichess.org/IjKl9012"]
[White "PabloTest"]
[Black "tercero"]
[Result "1/2-1/2"]
[UTCDate "2026.11.19"]
[UTCTime "20:30:00"]
[Variant "Standard"]
[Termination "Normal"]

1. e4 e5 2. Nf3 Nc6 1/2-1/2
"""


func _lichess() -> void:
	var games := GameImport.from_lichess(LICHESS_PGN, "pablotest")
	_ok(games.size() == 3, "Lichess: 3 partidas (la de Chess960 no)")
	if games.size() != 3:
		return
	var g0: Dictionary = games[0]
	var g1: Dictionary = games[1]
	var g2: Dictionary = games[2]
	_ok(str(g0["url"]).ends_with("EfGh5678") and str(g1["url"]).ends_with("AbCd1234") and str(g2["url"]).ends_with("IjKl9012"), "de la más reciente a la más antigua")
	_ok(int(g1["color"]) == 0 and int(g1["resultado"]) == 1 and str(g1["motivo"]) == "Jaque mate: has ganado.", "mate comprobado en el tablero")
	_ok(int(g0["color"]) == 1 and int(g0["resultado"]) == -1 and str(g0["motivo"]) == "Se te acabó el tiempo.", "con negras, perdida por tiempo (nombre sin distinguir mayúsculas)")
	_ok(int(g2["resultado"]) == 0 and str(g2["motivo"]) == "Tablas.", "tablas sin más detalle (Lichess no dice cuáles)")
	_ok(str(g0["rival_nombre"]) == "OtroJugador · Lichess" and int(g0["rival_elo"]) == 1610, "rival y su Elo")
	_ok(int(g1["fecha"]) == int(Time.get_unix_time_from_datetime_string("2026-11-20T18:03:12")), "fecha de UTCDate y UTCTime")
	_ok(g1["jugadas"] == ["e2e4", "e7e5", "f1c4", "b8c6", "d1h5", "g8f6", "h5f7"], "jugadas en UCI")
	_ok(str(g1["inicio"]) == Board3D.START_FEN and str(g1["ritmo"]) == "180+2", "posición inicial y ritmo")
	_ok(GameImport.from_lichess(LICHESS_PGN, "nadie").is_empty(), "un nombre que no juega ninguna: nada")
	_ok(GameImport.from_lichess("", "pablotest").is_empty(), "respuesta vacía: nada")


func _chesscom() -> void:
	var month := {"games": [
		{"url": "https://www.chess.com/game/live/111", "end_time": 1794000000, "rules": "chess", "white": {"username": "PabloTest", "result": "win"}, "black": {"username": "rivalA", "result": "resigned"},
			"pgn": "[Event \"Live Chess\"]\n[Site \"Chess.com\"]\n[White \"PabloTest\"]\n[Black \"rivalA\"]\n[Result \"1-0\"]\n[WhiteElo \"1200\"]\n[BlackElo \"1190\"]\n[TimeControl \"300\"]\n\n1. e4 {[%clk 0:04:59.9]} 1... e5 {[%clk 0:04:58.1]} 2. Nf3 {[%clk 0:04:57]} 2... Nc6 {[%clk 0:04:55]} 1-0\n"},
		{"url": "https://www.chess.com/game/live/222", "end_time": 1794100000, "rules": "chess", "white": {"username": "rivalB", "result": "agreed"}, "black": {"username": "pablotest", "result": "agreed"},
			"pgn": "[White \"rivalB\"]\n[Black \"pablotest\"]\n[Result \"1/2-1/2\"]\n\n1. d4 {[%clk 0:09:59]} 1... d5 {[%clk 0:09:58]} 1/2-1/2\n"},
		{"url": "https://www.chess.com/game/live/333", "end_time": 1794200000, "rules": "chess960", "white": {"username": "pablotest", "result": "win"}, "black": {"username": "x", "result": "timeout"},
			"pgn": "[White \"pablotest\"]\n[Black \"x\"]\n[Result \"1-0\"]\n\n1. e4 e5 1-0\n"},
		{"url": "https://www.chess.com/game/daily/444", "end_time": 1793900000, "rules": "chess", "white": {"username": "rivalC", "result": "win"}, "black": {"username": "PabloTest", "result": "timeout"},
			"pgn": "[White \"rivalC\"]\n[Black \"PabloTest\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Qh5 Ke7 1-0\n"},
	]}
	var games := GameImport.from_chesscom(JSON.stringify(month), "PabloTest")
	_ok(games.size() == 3, "Chess.com: 3 partidas (la de Chess960 no)")
	if games.size() != 3:
		return
	_ok(str((games[0] as Dictionary)["url"]).ends_with("/222") and str((games[2] as Dictionary)["url"]).ends_with("/444"), "ordenadas por end_time")
	var draw: Dictionary = games[0]
	_ok(int(draw["color"]) == 1 and int(draw["resultado"]) == 0 and str(draw["motivo"]) == "Tablas de mutuo acuerdo.", "tablas de mutuo acuerdo, con negras")
	var won: Dictionary = games[1]
	_ok(int(won["resultado"]) == 1 and str(won["motivo"]) == "El rival se ha rendido." and won["jugadas"] == ["e2e4", "e7e5", "g1f3", "b8c6"], "ganada por rendición; relojes fuera")
	_ok(str(won["rival_nombre"]) == "rivalA · Chess.com" and int(won["rival_elo"]) == 1190 and int(won["fecha"]) == 1794000000, "rival, Elo y fecha")
	var lost: Dictionary = games[2]
	_ok(int(lost["resultado"]) == -1 and str(lost["motivo"]) == "Se te acabó el tiempo.", "perdida por tiempo")
	var months := GameImport.chesscom_months("{\"archives\": [\"https://api.chess.com/pub/player/pablotest/games/2026/10\", \"https://api.chess.com/pub/player/pablotest/games/2026/11\", \"https://otro.sitio/x\"]}")
	_ok(months == ["https://api.chess.com/pub/player/pablotest/games/2026/11", "https://api.chess.com/pub/player/pablotest/games/2026/10"], "meses, el más reciente primero (y solo de api.chess.com)")
	_ok(GameImport.chesscom_months("no es json").is_empty() and GameImport.from_chesscom("{}", "x").is_empty(), "respuestas raras: nada")
	var merged := GameImport.merge(games, GameImport.from_chesscom(JSON.stringify(month), "PabloTest"))
	_ok(merged.size() == 3, "juntar meses no repite partidas")


func _store() -> void:
	var path := "user://_test_importadas.json"
	var store := GameImport.load_store(path)
	_ok(str(store["ultima"]) == "lichess" and not store.has("lichess"), "sin nada guardado")
	var games := GameImport.from_lichess(LICHESS_PGN, "PabloTest")
	GameImport.put(store, "lichess", " PabloTest ", games, 1794300000)
	GameImport.put(store, "chesscom", "otro", [], 1794300001)
	GameImport.save_store(store, path)
	var back := GameImport.load_store(path)
	_ok(str(back["ultima"]) == "chesscom" and str(back["lichess"]["usuario"]) == "PabloTest" and (back["lichess"]["partidas"] as Array).size() == 3, "se guarda y se lee")
	var g := GameImport.normalized((back["lichess"]["partidas"] as Array)[1])
	_ok(typeof(g["color"]) == TYPE_INT and typeof(g["resultado"]) == TYPE_INT and int(g["resultado"]) == 1, "los números vuelven como enteros")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"lichess\": 5, \"ultima\": \"x\"}")
	f.close()
	var odd := GameImport.load_store(path)
	_ok(not odd.has("lichess") and str(odd["ultima"]) == "lichess", "un archivo raro no rompe nada")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _requests() -> void:
	var url := GameImport.lichess_url("Pablo_Test")
	_ok(url.begins_with("https://lichess.org/api/games/user/Pablo_Test?") and url.contains("max=20") and url.contains("perfType=ultraBullet,bullet,blitz,rapid,classical,correspondence") and url.contains("finished=true"), "dirección de Lichess")
	_ok("Accept: application/x-chess-pgn" in GameImport.lichess_headers() and GameImport.user_agent("0.1.250").begins_with("AChessWay/0.1.250 (Android; +https://"), "cabeceras de Lichess y User-Agent")
	_ok(GameImport.chesscom_archives_url("PabloTest") == "https://api.chess.com/pub/player/pablotest/games/archives", "dirección de Chess.com, en minúsculas")
	_ok(GameImport.username_problem("Pablo_Test-1") == "" and GameImport.username_problem("a") != "" and GameImport.username_problem("José") != "" and GameImport.username_problem("a b") != "" and GameImport.username_problem("_abc") != "", "nombres de usuario")
	_ok(GameImport.error_text("lichess", 404).contains("Lichess") and GameImport.error_text("chesscom", 429).contains("Chess.com") and GameImport.error_text("lichess", 0) != "" and GameImport.error_text("lichess", 500).contains("500"), "mensajes de error")


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
