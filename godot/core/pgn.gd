class_name Pgn
extends RefCounted
## Lectura de partidas en PGN, el formato en que las dan Lichess y Chess.com: las cabeceras («[White "…"]») y las
## jugadas en notación inglesa (K, Q, R, B, N). Los comentarios, las variantes, los signos «!?» y los números de
## jugada se saltan. Cada jugada se comprueba con las reglas de la app (core/chess.gd): si una no es legal, la
## partida se corta ahí y se dice.

const _PIECES := {"N": Chess.KNIGHT, "B": Chess.BISHOP, "R": Chess.ROOK, "Q": Chess.QUEEN, "K": Chess.KING}
const RESULTS := ["1-0", "0-1", "1/2-1/2", "*"]


## Separa un texto con una o varias partidas. Devuelve [{tags: {"White": "…", …}, sans: ["e4", "e5", …]}].
static func parse_games(text: String) -> Array:
	var out: Array = []
	var tags := {}
	var movetext := ""
	var tag_re := RegEx.new()
	tag_re.compile("^\\[([A-Za-z0-9_]+)\\s+\"((?:[^\"\\\\]|\\\\.)*)\"\\s*\\]")
	for raw: String in text.replace("\r", "").split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("%"):
			continue
		if line.begins_with("["):
			var m := tag_re.search(line)
			if m != null:
				# Unas cabeceras después de unas jugadas: empieza otra partida.
				if movetext.strip_edges() != "":
					out.append({"tags": tags, "sans": moves_of(movetext)})
					tags = {}
					movetext = ""
				tags[m.get_string(1)] = m.get_string(2).replace("\\\"", "\"").replace("\\\\", "\\")
				continue
		movetext += line + "\n"
	if movetext.strip_edges() != "" or not tags.is_empty():
		out.append({"tags": tags, "sans": moves_of(movetext)})
	return out


## Las jugadas de un texto de jugadas, sin comentarios («{…}», «;…»), variantes («(…)»), signos ($1, !, ?),
## números de jugada ni el resultado.
static func moves_of(movetext: String) -> Array:
	var clean := ""
	var depth := 0
	var i := 0
	var n := movetext.length()
	while i < n:
		var ch := movetext[i]
		if ch == "{":
			var close := movetext.find("}", i)
			i = n if close < 0 else close + 1
			clean += " "
			continue
		if ch == ";":
			var eol := movetext.find("\n", i)
			i = n if eol < 0 else eol
			continue
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(depth - 1, 0)
			clean += " "
		elif depth == 0:
			clean += ch
		i += 1
	var num := RegEx.new()
	num.compile("^[0-9]+\\.+")
	var out: Array = []
	for tok0: String in clean.split(" ", false):
		for tok1: String in tok0.split("\n", false):
			for tok2: String in tok1.split("\t", false):
				var tok := num.sub(tok2.strip_edges(), "")
				if tok == "" or tok.begins_with("$") or tok in RESULTS:
					continue
				tok = tok.rstrip("!?")
				if tok == "":
					continue
				out.append(tok)
	return out


## La jugada legal de `pos` que corresponde a una jugada en notación inglesa («Nf3», «exd6», «O-O», «e8=Q+»,
## «Rad1», «Qh4xe1»), o -1 si no hay ninguna o hay más de una.
static func san_move(pos: Chess, san: String) -> int:
	var s := san.strip_edges().rstrip("+#!?").replace("e.p.", "").strip_edges()
	if s == "":
		return -1
	var legal := pos.legal_moves()
	var plain := s.replace("0", "O")
	if plain == "O-O" or plain == "O-O-O":
		var want := Chess.F_CASTLE_K if plain == "O-O" else Chess.F_CASTLE_Q
		for m in legal:
			if Chess.move_flag(m) == want:
				return m
		return -1
	var piece := Chess.PAWN
	if _PIECES.has(s[0]):
		piece = int(_PIECES[s[0]])
		s = s.substr(1)
	var promo := 0
	var eq := s.find("=")
	if eq >= 0:
		promo = int(_PIECES.get(s.substr(eq + 1, 1).to_upper(), 0))
		s = s.substr(0, eq)
	elif piece == Chess.PAWN and s.length() >= 3 and _PIECES.has(s[s.length() - 1].to_upper()) and s[s.length() - 1] != "b":
		# «e8Q»: coronación sin el signo «=». La «b» minúscula sería una columna, no un alfil.
		promo = int(_PIECES[s[s.length() - 1].to_upper()])
		s = s.substr(0, s.length() - 1)
	if s.length() < 2:
		return -1
	var dest := s.substr(s.length() - 2)
	if not _is_square(dest):
		return -1
	var to := Chess.sq_index(dest)
	var hint := s.substr(0, s.length() - 2).replace("x", "").replace("-", "")
	var found := -1
	for m in legal:
		if Chess.move_to(m) != to or Chess.move_promo(m) != promo:
			continue
		var from := Chess.move_from(m)
		if Chess.type_of(pos.b[from]) != piece:
			continue
		var name := Chess.sq_name(from)
		var ok := true
		for c: String in hint:
			if c >= "a" and c <= "h":
				ok = ok and name[0] == c
			elif c >= "1" and c <= "8":
				ok = ok and name[1] == c
			else:
				ok = false
		if not ok:
			continue
		if found >= 0:
			return -1
		found = m
	return found


static func _is_square(t: String) -> bool:
	return t.length() == 2 and t[0] >= "a" and t[0] <= "h" and t[1] >= "1" and t[1] <= "8"


## Juega las jugadas desde la posición inicial (la del FEN de las cabeceras, si la hay). Devuelve {inicio (FEN),
## jugadas (UCI), final (FEN), completa (todas eran legales), mate, ahogado}.
static func replay(game: Dictionary) -> Dictionary:
	var tags: Dictionary = game.get("tags", {})
	var start := Board3D.START_FEN
	if tags.has("FEN") and str(tags["FEN"]).strip_edges() != "":
		start = str(tags["FEN"]).strip_edges()
	var pos := Chess.from_fen(start)
	var uci: Array = []
	var complete := true
	for san: Variant in game.get("sans", []):
		var m := san_move(pos, str(san))
		if m < 0:
			complete = false
			break
		uci.append(Chess.uci(m))
		pos.apply(m)
	return {"inicio": start, "jugadas": uci, "final": pos.fen(), "completa": complete, "mate": pos.is_checkmate(), "ahogado": pos.is_stalemate()}
