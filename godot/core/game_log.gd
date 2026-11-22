class_name GameLog
extends RefCounted
## Historial de partidas en este dispositivo: contra quién (rivales online por su identificador anónimo, que es
## el mismo en cada partida desde su móvil, o el ordenador y su nivel), con qué color, el resultado y las jugadas
## (para volver a analizarlas). Y las estadísticas que salen de él. No se sube a ningún sitio.

const PATH := "user://chessome_partidas.json"
const MAX_GAMES := 300


static func load_log(path: String = PATH) -> Dictionary:
	var empty := {"partidas": [], "rivales": {}}
	if not FileAccess.file_exists(path):
		return empty
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not ((data as Dictionary).get("partidas") is Array):
		return empty
	if not ((data as Dictionary).get("rivales") is Dictionary):
		(data as Dictionary)["rivales"] = {}
	return data


static func save_log(log: Dictionary, path: String = PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(log))


## Añade una partida. `game`: {fecha, tipo ("online" | "ordenador"), rival_id, rival_nombre, color, resultado
## (1 ganada, 0 tablas, −1 perdida), motivo, inicio (FEN), jugadas (UCI)}. `rival`: lo que enseñó el rival (nombre,
## nivel, icono, foto) o {}.
static func add(log: Dictionary, game: Dictionary, rival: Dictionary) -> Dictionary:
	var games: Array = log["partidas"]
	games.push_front(game)
	if games.size() > MAX_GAMES:
		games.resize(MAX_GAMES)
	var rivals: Dictionary = log["rivales"]
	var id := str(game["rival_id"])
	var r: Dictionary = rivals.get(id, {"partidas": 0, "ganadas": 0, "tablas": 0, "perdidas": 0})
	r["nombre"] = str(game["rival_nombre"])
	r["tipo"] = str(game["tipo"])
	for k: String in ["nivel", "icono", "foto"]:
		if rival.has(k):
			r[k] = rival[k]
	r["partidas"] = int(r["partidas"]) + 1
	var res := int(game["resultado"])
	var key := "ganadas" if res > 0 else ("tablas" if res == 0 else "perdidas")
	r[key] = int(r[key]) + 1
	r["ultima"] = int(game["fecha"])
	rivals[id] = r
	return log


## Partidas para que el nivel de juego deje de ser provisional.
const RATED_MIN := 10


## Nivel de juego: Glicko-2 con las partidas, de la más antigua a la más reciente. Contra el ordenador, cada nivel
## cuenta con su fuerza medida (Bot.LEVELS: «elo» y «rd»; tools/calibrar), y los que no la tienen no cuentan; online,
## con el nivel de juego que enseñó el rival (su desviación, como poco 60, para que un número dudoso pese menos). Las partidas con ayudas no cuentan. `levels` es para las pruebas. Devuelve {r, rd, n (partidas que cuentan), provisional}.
static func game_rating(log: Dictionary, levels: Array = []) -> Dictionary:
	if levels.is_empty():
		levels = Bot.LEVELS
	var rating := {"r": 1500.0, "rd": 350.0, "vol": 0.06}
	var n := 0
	var games: Array = log.get("partidas", [])
	for i in range(games.size() - 1, -1, -1):
		var g: Dictionary = games[i]
		# Con ayudas (deshacer, pistas, «Prueba otra vez») la partida se guarda, pero no mide tu nivel.
		if bool(g.get("ayudas", false)):
			continue
		var id := str(g.get("rival_id", ""))
		var opp := {}
		if id.begins_with("bot:"):
			var lv := int(id.substr(4))
			if lv >= 0 and lv < levels.size() and (levels[lv] as Dictionary).has("elo"):
				opp = {"r": float(levels[lv]["elo"]), "rd": float(levels[lv].get("rd", 60.0))}
		else:
			# Online: el nivel de juego que enseñó el rival (lo calcula su app; no se puede comprobar).
			var rj: Variant = g.get("rival_juego", {})
			if rj is Dictionary and (rj as Dictionary).has("r") and (rj as Dictionary).has("rd"):
				opp = {"r": clampf(float(rj["r"]), 100.0, 3500.0), "rd": clampf(float(rj["rd"]), 60.0, 350.0)}
		if opp.is_empty():
			continue
		var res := int(g.get("resultado", 0))
		var score := 1.0 if res > 0 else (0.5 if res == 0 else 0.0)
		rating = Glicko2.update(rating, [{"opponent": opp, "score": score}])
		n += 1
	return {"r": float(rating["r"]), "rd": float(rating["rd"]), "n": n, "provisional": n < RATED_MIN}


## Cómo terminó una partida, para filtrar: mate, tiempo, abandono, rendicion, tablas u otros. Sale del texto
## guardado (vale también para las partidas antiguas).
static func reason(g: Dictionary) -> String:
	var text := str(g.get("motivo", "")).to_lower()
	if text.contains("abandon"):
		return "abandono"
	if text.contains("tiempo"):
		return "tiempo"
	if text.contains("rendido"):
		return "rendicion"
	if int(g.get("resultado", 0)) == 0:
		return "tablas"
	if text.contains("mate"):
		return "mate"
	return "otros"


## Partidas que pasan un filtro: resultado ("", "ganadas", "tablas", "perdidas") y final ("" o uno de reason).
## Devuelve los índices en la lista (la más reciente, primero).
static func filtered(log: Dictionary, result: String, why: String) -> Array:
	var out: Array = []
	var games: Array = log["partidas"]
	for i in games.size():
		var g: Dictionary = games[i]
		var res := int(g.get("resultado", 0))
		if result == "ganadas" and res <= 0 or result == "perdidas" and res >= 0 or result == "tablas" and res != 0:
			continue
		if why != "" and reason(g) != why:
			continue
		out.append(i)
	return out


## {total, ganadas, tablas, perdidas, online, ordenador, blancas: [g, t, p], negras: [g, t, p], racha (actual:
## positiva de victorias, negativa de derrotas), mejor_racha}.
static func stats(log: Dictionary) -> Dictionary:
	var s := {"total": 0, "ganadas": 0, "tablas": 0, "perdidas": 0, "online": 0, "ordenador": 0, "blancas": [0, 0, 0], "negras": [0, 0, 0], "racha": 0, "mejor_racha": 0}
	var games: Array = log["partidas"]
	for g: Dictionary in games:
		var res := int(g["resultado"])
		s["total"] = int(s["total"]) + 1
		var key := "ganadas" if res > 0 else ("tablas" if res == 0 else "perdidas")
		s[key] = int(s[key]) + 1
		var tipo := "online" if str(g.get("tipo", "")) == "online" else "ordenador"
		s[tipo] = int(s[tipo]) + 1
		var side: Array = s["blancas"] if int(g.get("color", 0)) == 0 else s["negras"]
		side[0 if res > 0 else (1 if res == 0 else 2)] += 1
	# Rachas: las partidas van de la más reciente a la más antigua.
	var run := 0
	for g: Dictionary in games:
		var res := int(g["resultado"])
		if res == 0:
			break
		if run == 0 or signi(run) == res:
			run += res
		else:
			break
	s["racha"] = run
	var best := 0
	var cur := 0
	for i in range(games.size() - 1, -1, -1):
		cur = cur + 1 if int((games[i] as Dictionary)["resultado"]) > 0 else 0
		best = maxi(best, cur)
	s["mejor_racha"] = best
	return s


## Rivales ordenados por la última partida (los más recientes primero): [[id, datos], …].
static func rivals_by_date(log: Dictionary) -> Array:
	var out: Array = []
	var rivals: Dictionary = log["rivales"]
	for id: String in rivals:
		out.append([id, rivals[id]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int((a[1] as Dictionary).get("ultima", 0)) > int((b[1] as Dictionary).get("ultima", 0)))
	return out


## Nombre válido para enseñar a otros: 2–16 caracteres de letras, números, espacios y . _ -; sin palabras
## malsonantes de una lista básica. Devuelve "" si es válido o el motivo.
static func name_problem(name: String) -> String:
	var n := name.strip_edges()
	if n.length() < 2 or n.length() > 16:
		return "Entre 2 y 16 caracteres."
	var re := RegEx.new()
	re.compile("^[A-Za-zÁÉÍÓÚÜÑáéíóúüñÇç0-9 ._-]+$")
	if re.search(n) == null:
		return "Solo letras, números, espacios y . _ -"
	# Palabra a palabra (para no rechazar nombres como «Penélope» por contener otra palabra dentro).
	var plain := n.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("0", "o").replace("1", "i").replace("3", "e").replace("4", "a")
	for w: String in plain.replace(".", " ").replace("_", " ").replace("-", " ").split(" ", false):
		for bad: String in ["puta", "puto", "mierda", "polla", "coño", "cabron", "joder", "gilipollas", "maricon", "nazi", "hitler", "zorra", "follar", "imbecil", "subnormal", "fuck", "shit", "bitch"]:
			if w.begins_with(bad):
				return "Ese nombre no está permitido."
	return ""
