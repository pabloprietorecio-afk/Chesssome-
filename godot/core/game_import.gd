class_name GameImport
extends RefCounted
## «Importar mis partidas»: las últimas partidas de un jugador de Lichess o de Chess.com, con solo su nombre de
## usuario (sin contraseña ni cuenta). Aquí están las direcciones, las cabeceras y la lectura de las respuestas; la
## petición la hace la app (demo.gd, una a la vez, como piden los dos servicios). Ver docs/importar.md.
##
## - Lichess: GET https://lichess.org/api/games/user/{usuario} con «Accept: application/x-chess-pgn» (PGN).
## - Chess.com (Published-Data API): GET https://api.chess.com/pub/player/{usuario}/games/archives da la lista de
##   meses; cada mes, GET …/games/{AAAA}/{MM} da sus partidas en JSON (con «pgn», «rules», «white», «black»,
##   «end_time», «url»). Pide un User-Agent reconocible con un contacto.
##
## Las partidas importadas se guardan aparte (PATH), no en «Mis partidas»: no cuentan para tus estadísticas, tu
## nivel de juego ni los retos, porque no se han jugado en la app (y el rival no es uno de sus niveles medidos).

const PATH := "user://chessome_importadas.json"
## Partidas que se traen cada vez (las más recientes).
const MAX := 20
const SOURCES := ["lichess", "chesscom"]
const SOURCE_NAMES := {"lichess": "Lichess", "chesscom": "Chess.com"}
## Contacto en el User-Agent (Chess.com lo pide): la ficha de la app en Google Play, que enseña el contacto del
## desarrollador.
const CONTACT := "https://play.google.com/store/apps/details?id=com.pabloprieto.chessome"
## Solo ajedrez normal: sin variantes (Chess960, Crazyhouse…), que las reglas de la app no saben jugar.
const LICHESS_PERFS := "ultraBullet,bullet,blitz,rapid,classical,correspondence"


## Nombre de usuario que se puede pedir: letras inglesas, números, «_» y «-» (2 a 30, empezando por letra o
## número). Devuelve "" si vale o el motivo. Que exista lo dice el servicio.
static func username_problem(name: String) -> String:
	var n := name.strip_edges()
	if n.length() < 2 or n.length() > 30:
		return "Entre 2 y 30 caracteres."
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9][A-Za-z0-9_-]+$")
	if re.search(n) == null:
		return "Solo letras sin acentos, números, «_» y «-»."
	return ""


static func user_agent(version: String = "") -> String:
	return "AChessWay/%s (Android; +%s)" % [version if version != "" else "0.1", CONTACT]


static func lichess_url(name: String) -> String:
	return "https://lichess.org/api/games/user/%s?max=%d&perfType=%s&finished=true&moves=true&tags=true&clocks=false&evals=false&opening=false" % [name.strip_edges().uri_encode(), MAX, LICHESS_PERFS]


static func lichess_headers(version: String = "") -> PackedStringArray:
	return PackedStringArray(["Accept: application/x-chess-pgn", "User-Agent: " + user_agent(version)])


static func chesscom_archives_url(name: String) -> String:
	return "https://api.chess.com/pub/player/%s/games/archives" % name.strip_edges().to_lower().uri_encode()


static func chesscom_headers(version: String = "") -> PackedStringArray:
	return PackedStringArray(["Accept: application/json", "User-Agent: " + user_agent(version)])


## Los meses con partidas, del más reciente al más antiguo (las direcciones que da Chess.com).
static func chesscom_months(json_text: String) -> Array:
	var data: Variant = _json(json_text)
	if not (data is Dictionary) or not ((data as Dictionary).get("archives") is Array):
		return []
	var out: Array = []
	for u: Variant in (data as Dictionary)["archives"]:
		var s := str(u)
		if s.begins_with("https://api.chess.com/"):
			out.append(s)
	out.reverse()
	return out


## Lo que dice el servicio cuando la petición no ha ido bien, para el jugador. `code` 0: no hubo respuesta.
static func error_text(source: String, code: int) -> String:
	var who := str(SOURCE_NAMES.get(source, source))
	if code == 0:
		return "No se ha podido conectar. Comprueba la conexión a Internet."
	if code == 404:
		return Loc.f("No hay ningún jugador con ese nombre en %s.", who)
	if code == 429:
		return Loc.f("%s pide esperar un poco antes de volver a preguntar. Prueba dentro de un minuto.", who)
	if code == 410:
		return Loc.f("Esa cuenta ya no está disponible en %s.", who)
	return Loc.f("%s no ha respondido bien (código %d). Prueba más tarde.", [who, code])


## Partidas de Lichess (un texto PGN con varias) de `username`, de la más reciente a la más antigua.
static func from_lichess(pgn_text: String, username: String) -> Array:
	var out: Array = []
	for g: Dictionary in Pgn.parse_games(pgn_text):
		var rec := record(g, username, "lichess", {})
		if not rec.is_empty():
			out.append(rec)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["fecha"]) > int(b["fecha"]))
	return out.slice(0, MAX)


## Partidas de un mes de Chess.com (JSON) de `username`, de la más reciente a la más antigua.
static func from_chesscom(json_text: String, username: String) -> Array:
	var data: Variant = _json(json_text)
	if not (data is Dictionary) or not ((data as Dictionary).get("games") is Array):
		return []
	var out: Array = []
	for item: Variant in (data as Dictionary)["games"]:
		if not (item is Dictionary):
			continue
		var j: Dictionary = item
		if str(j.get("rules", "chess")) != "chess" or str(j.get("pgn", "")) == "":
			continue
		var games := Pgn.parse_games(str(j["pgn"]))
		if games.is_empty():
			continue
		var white: Dictionary = j.get("white", {}) if j.get("white", {}) is Dictionary else {}
		var black: Dictionary = j.get("black", {}) if j.get("black", {}) is Dictionary else {}
		var extra := {"fecha": int(j.get("end_time", 0)), "url": str(j.get("url", "")), "codigos": [str(white.get("result", "")), str(black.get("result", ""))], "blancas": str(white.get("username", "")), "negras": str(black.get("username", ""))}
		var rec := record(games[0], username, "chesscom", extra)
		if not rec.is_empty():
			out.append(rec)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["fecha"]) > int(b["fecha"]))
	return out.slice(0, MAX)


## Junta las partidas de varios meses, sin repetir, y se queda con las MAX más recientes.
static func merge(a: Array, b: Array) -> Array:
	var seen := {}
	var out: Array = []
	for g: Dictionary in a + b:
		var key := str(g.get("url", "")) + "|" + str(g.get("fecha", 0))
		if seen.has(key):
			continue
		seen[key] = true
		out.append(g)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["fecha"]) > int(y["fecha"]))
	return out.slice(0, MAX)


## Una partida leída del PGN, como la guarda la app para analizarla: {fuente, fecha, rival_nombre, rival_elo, color,
## resultado (1, 0, −1 para el jugador), motivo, inicio (FEN), jugadas (UCI), url, ritmo, cortada (alguna jugada no
## se pudo leer y la partida acaba antes)}. {} si el jugador no es ninguno de los dos o no hay jugadas.
## `extra` (Chess.com): fecha, url, codigos [blancas, negras], blancas, negras (nombres).
static func record(game: Dictionary, username: String, source: String, extra: Dictionary) -> Dictionary:
	var tags: Dictionary = game.get("tags", {})
	var variant := str(tags.get("Variant", "Standard"))
	if not (variant in ["Standard", "From Position", ""]):
		return {}
	var white := str(extra.get("blancas", "")) if str(extra.get("blancas", "")) != "" else str(tags.get("White", ""))
	var black := str(extra.get("negras", "")) if str(extra.get("negras", "")) != "" else str(tags.get("Black", ""))
	var me := username.strip_edges().to_lower()
	var color := -1
	if white.to_lower() == me:
		color = 0
	elif black.to_lower() == me:
		color = 1
	if color < 0:
		return {}
	var play := Pgn.replay(game)
	if (play["jugadas"] as Array).is_empty():
		return {}
	var tag_result := str(tags.get("Result", "*"))
	var white_score := 1 if tag_result == "1-0" else (-1 if tag_result == "0-1" else 0)
	var res := white_score if color == 0 else -white_score
	var opp := black if color == 0 else white
	var elo_tag := "BlackElo" if color == 0 else "WhiteElo"
	var fecha := int(extra.get("fecha", 0))
	if fecha <= 0:
		fecha = _tag_time(tags)
	var url := str(extra.get("url", ""))
	if url == "":
		url = str(tags.get("Site", tags.get("Link", "")))
	if not url.begins_with("https://"):
		url = ""
	var rec := {
		"fuente": source,
		"fecha": fecha,
		"rival_nombre": "%s · %s" % [opp if opp != "" else "?", str(SOURCE_NAMES.get(source, source))],
		"rival_elo": int(str(tags.get(elo_tag, "0"))) if str(tags.get(elo_tag, "")).is_valid_int() else 0,
		"color": color,
		"resultado": res,
		"motivo": _reason(tags, play, res, source, extra, color),
		"inicio": str(play["inicio"]),
		"jugadas": play["jugadas"],
		"url": url,
		"ritmo": str(tags.get("TimeControl", "")),
	}
	if not bool(play["completa"]):
		rec["cortada"] = true
	return rec


## Cómo terminó, dicho para el jugador. Solo lo que se sabe: el mate y el ahogado se comprueban en el tablero; lo
## demás, de lo que dice el servicio (códigos de Chess.com; en Lichess, la cabecera «Termination»).
static func _reason(tags: Dictionary, play: Dictionary, res: int, source: String, extra: Dictionary, color: int) -> String:
	if bool(play["completa"]) and bool(play["mate"]):
		return "Jaque mate: has ganado." if res > 0 else "Jaque mate: gana el rival."
	if bool(play["completa"]) and bool(play["ahogado"]) and res == 0:
		return "Tablas por ahogado."
	if source == "chesscom":
		var codes: Array = extra.get("codigos", ["", ""])
		var mine := str(codes[color]) if codes.size() == 2 else ""
		var theirs := str(codes[1 - color]) if codes.size() == 2 else ""
		var loser := theirs if res > 0 else mine
		if res != 0:
			match loser:
				"checkmated":
					return "Jaque mate: has ganado." if res > 0 else "Jaque mate: gana el rival."
				"resigned":
					return "El rival se ha rendido." if res > 0 else "Te has rendido."
				"timeout":
					return "Al rival se le acabó el tiempo." if res > 0 else "Se te acabó el tiempo."
				"abandoned":
					return "El rival abandonó la partida." if res > 0 else "Abandonaste la partida."
		else:
			match mine:
				"agreed":
					return "Tablas de mutuo acuerdo."
				"repetition":
					return "Tablas por triple repetición."
				"stalemate":
					return "Tablas por ahogado."
				"insufficient":
					return "Tablas: no queda material para dar mate."
				"50move":
					return "Tablas por la regla de las 50 jugadas."
				"timevsinsufficient":
					return "Tablas: se acabó el tiempo, pero el otro no tenía material para dar mate."
	else:
		var term := str(tags.get("Termination", ""))
		if term == "Time forfeit":
			if res > 0:
				return "Al rival se le acabó el tiempo."
			if res < 0:
				return "Se te acabó el tiempo."
			return "Tablas: se acabó el tiempo, pero el otro no tenía material para dar mate."
		if term == "Abandoned":
			return "El rival abandonó la partida." if res > 0 else ("Abandonaste la partida." if res < 0 else "Partida abandonada.")
	if res > 0:
		return "Has ganado."
	if res < 0:
		return "Has perdido."
	return "Tablas."


## Fecha de las cabeceras («UTCDate» y «UTCTime», o «Date»), en segundos; 0 si no hay.
static func _tag_time(tags: Dictionary) -> int:
	var d := str(tags.get("UTCDate", tags.get("Date", ""))).replace(".", "-")
	if d.length() != 10 or d.contains("?"):
		return 0
	var t := str(tags.get("UTCTime", "00:00:00"))
	if t.length() != 8:
		t = "00:00:00"
	return int(Time.get_unix_time_from_datetime_string(d + "T" + t))


## JSON sin mensajes de error en la consola si el texto no lo es (una respuesta rara de un servicio): null.
static func _json(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


# ---------------------------------------------------------------- guardado (aparte de «Mis partidas»)

## {lichess: {usuario, partidas, fecha}, chesscom: {…}, ultima: "lichess" | "chesscom"}.
static func load_store(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ultima": "lichess"}
	var data: Variant = _json(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return {"ultima": "lichess"}
	var d: Dictionary = data
	if not (str(d.get("ultima", "")) in SOURCES):
		d["ultima"] = "lichess"
	for s: String in SOURCES:
		if d.has(s) and not (d[s] is Dictionary and (d[s] as Dictionary).get("partidas") is Array):
			d.erase(s)
	return d


static func save_store(store: Dictionary, path: String = PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(store))


## Guarda las partidas traídas de `source` para `username` (sustituyen a las de antes de ese servicio).
static func put(store: Dictionary, source: String, username: String, games: Array, now: int) -> Dictionary:
	store[source] = {"usuario": username.strip_edges(), "partidas": games.slice(0, MAX), "fecha": now}
	store["ultima"] = source
	return store


## JSON da los números como decimales: los que la app usa como enteros, de vuelta a enteros.
static func normalized(g: Dictionary) -> Dictionary:
	var out := g.duplicate(true)
	for k: String in ["fecha", "color", "resultado", "rival_elo"]:
		out[k] = int(out.get(k, 0))
	return out
