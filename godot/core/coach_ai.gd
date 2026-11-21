class_name CoachAI
extends Node
## Profesor IA durante las partidas (premium). Corrige los errores del jugador mientras juega, con la voz de un
## profesor.
##
## Reparto del trabajo (docs/profesor-ia.md):
##   - **Qué** ha pasado lo decide la app, con hechos comprobados en el tablero (GameReview.analyze_move: mate que se
##     escapa, mate permitido, pieza a tiro, captura que no se hizo). La IA no calcula jugadas ni evalúa posiciones:
##     los modelos de lenguaje se equivocan a menudo en ajedrez.
##   - **Cómo** se cuenta lo redacta la IA (Claude Haiku): una explicación corta y cercana, a la medida del nivel.
##   - Comprobación de la respuesta: si nombra una casilla que no está en los hechos, se descarta y se enseña el
##     texto comprobado. Sin red, sin clave o con error, también.
##
## Conexión (data/coach_ai.json):
##   - "endpoint" vacío: llamada directa a la API de Claude con la clave de prueba que se pega en Opciones. Solo en
##     compilaciones de depuración: una clave dentro de un APK publicado la puede sacar cualquiera.
##   - "endpoint" con una URL: el servidor propio (worker/, Cloudflare Workers) recibe solo los hechos, construye
##     la petición y le pone la clave. La app nunca tiene la clave.
##
## Datos que salen del móvil: la posición (FEN), la jugada, los hechos comprobados, el nivel aproximado y el idioma.
## Nada personal. Nunca en el nivel Kids (Premium.coach_applies).

signal answered(run: int, ply: int, text: String, from_ai: bool)
## Tutor con Stockfish (worker/src/tutor.js): la valoración de una jugada y, aparte, la lección de Claude.
## `data` vacío = no ha llegado (sin red, tiempo agotado o respuesta rara): vale el motor local.
signal judged(run: int, gen: int, data: Dictionary)
signal lesson_ready(run: int, gen: int, data: Dictionary)
## Respuesta a una pregunta libre ({answer, show} o {_error: código HTTP, 0 sin conexión}).
signal asked(run: int, gen: int, data: Dictionary)

const CONFIG := "res://data/coach_ai.json"
## Una casilla suelta o dentro de una jugada («Cxf5+», «exd5»): delante puede ir una pieza o la «x» de captura,
## pero no otra letra minúscula (así «abc1» no cuenta).
const SQUARE := "(?<![a-wyz])([a-h][1-8])(?![0-9])"

var cfg: Dictionary = {}
var busy := false
## Peticiones hechas en esta sesión (para las pruebas y para vigilar el gasto).
var calls := 0
## Pruebas: las preguntas no salen a la red y la respuesta la pone la prueba (llamando a la app directamente).
var hold_questions := false


func _init() -> void:
	cfg = load_config()
	# Con el ejecutable del editor (las pruebas y las capturas de la CI), sin servidor: las 5 partidas gratis harían
	# que cualquier prueba con una partida llamase a Stockfish y a Claude (y gastase). El móvil no lleva «editor».
	if OS.has_feature("editor"):
		cfg.erase("tutor")
		cfg["endpoint"] = ""


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return parsed if parsed is Dictionary else {}


## Dirección del tutor con Stockfish ("" = no hay: solo el motor local).
static func tutor_url(config: Dictionary) -> String:
	return str(config.get("tutor", ""))


const VERDICTS := ["brilliant", "best", "good", "inaccuracy", "mistake", "blunder"]


## La respuesta del tutor tiene la forma esperada: una valoración conocida y la línea de la jugada, paso a paso.
static func remote_ok(data: Dictionary) -> bool:
	if not VERDICTS.has(str(data.get("verdict", ""))) or not (data.get("lines") is Dictionary):
		return false
	var lines: Dictionary = data["lines"]
	for key: String in ["played", "best"]:
		if not (lines.get(key) is Array):
			return false
		for step: Variant in lines[key]:
			if not (step is Dictionary) or str((step as Dictionary).get("uci", "")).length() < 4 or str((step as Dictionary).get("fen", "")) == "":
				return false
			var pos := Chess.from_fen(str((step as Dictionary)["fen"]))
			if pos.find_uci(str((step as Dictionary)["uci"])) < 0:
				return false
	return not (lines["played"] as Array).is_empty()


## Casillas que un texto nombra sueltas («el peón de e5»), en orden y sin repetir. Las que van dentro de una jugada
## («Cge2», «Dxe5») no cuentan: esas ya las marca la propia jugada.
static func squares_in(text: String) -> Array:
	var re := RegEx.create_from_string("(?<![A-Za-z0-9])[a-h][1-8](?![A-Za-z0-9])")
	var out: Array = []
	for m in re.search_all(text):
		if not out.has(m.get_string()):
			out.append(m.get_string())
	return out


## Flechas del tutor ({from: "g1", to: "e2", tone}) como las quiere el tablero (casillas por índice).
static func board_arrows(step: Dictionary) -> Array:
	var out: Array = []
	var raw: Variant = step.get("arrows", [])
	if not (raw is Array):
		return out
	for a: Variant in raw:
		if not (a is Dictionary):
			continue
		var from := str((a as Dictionary).get("from", ""))
		var to := str((a as Dictionary).get("to", ""))
		if from.length() != 2 or to.length() != 2:
			continue
		var tone := str((a as Dictionary).get("tone", "info"))
		out.append({"from": Chess.sq_index(from), "to": Chess.sq_index(to), "tone": tone if ["good", "bad", "info"].has(tone) else "info"})
	return out


## Lo que se manda para pedir la lección de una jugada ya valorada.
static func lesson_payload(lesson: Dictionary, rating: float, language: String) -> Dictionary:
	var lines: Dictionary = lesson.get("lines", {})
	var ucis := func(steps: Variant) -> Array:
		var out: Array = []
		if steps is Array:
			for s: Variant in steps:
				out.append(str((s as Dictionary).get("uci", "")))
		return out
	return {
		"fen": str(lesson.get("fen", "")), "uci": str(lesson.get("uci", "")),
		"played": ucis.call(lines.get("played", [])), "best": ucis.call(lines.get("best", [])),
		"verdict": str(lesson.get("verdict", "good")), "win_best": int(lesson.get("win_best", -1)), "win_played": int(lesson.get("win_played", -1)),
		"rating": int(round(rating)), "language": language,
	}


## Cómo se llamaría ahora: "server" (servidor propio), "direct" (clave de prueba) o "" (no se puede: se queda el
## texto comprobado).
static func endpoint_mode(config: Dictionary, key: String, debug: bool) -> String:
	if str(config.get("endpoint", "")) != "":
		return "server"
	if debug and key.strip_edges() != "":
		return "direct"
	return ""


## Si el motor ve la jugada tan buena como la mejor (hasta estas centésimas de peón), se le cree aunque deje
## material a tiro: o hay compensación o se perdía igual.
const TRUST_LOSS := 30
const RANK := {"only": 0, "best": 0, "good": 1, "inaccuracy": 2, "mistake": 3, "blunder": 4}


## Valoración de una jugada para el profesor en vivo. Junta dos vistas:
##   - el motor de la app (GameDetail.entry): la mejor, buena, imprecisión, error, error grave. Sus umbrales son
##     anchos y su valoración mezcla material y posición: un peón regalado puede salirle «buena» (pierde 1 peón
##     pero «gana» desarrollo; partida de Pablo, 21-11: 12.Cge2 dejando e5 a la dama).
##   - lo que se ve en el tablero a una jugada vista (GameReview.analyze_move): pieza o peón a tiro, captura gratis
##     que no se hizo, mates en una. Si lo hay y el motor no ve la jugada casi igual que la mejor, la valoración
##     sube como mínimo a imprecisión (un peón) o error (una pieza), y la explicación es la de ese hecho, que dice
##     qué quedó a tiro y qué jugada lo evitaba.
## Devuelve la entrada de GameDetail con «short» (para la tarjeta), «full» (ventana) y, si subió, «raised».
static func judge(fen: String, uci: String, color: int, ply: int, seconds: float) -> Dictionary:
	var pos := Chess.from_fen(fen)
	var m := pos.find_uci(uci)
	if m < 0:
		return {}
	var e := GameDetail.entry(Bot.new(4), pos, m, color, ply, seconds)
	var paras: Array = e.get("paras", [])
	e["full"] = " ".join(paras).strip_edges()
	# En la tarjeta, lo que importa: qué permite y cuál era la mejor (sin la primera frase, que cuenta tu jugada).
	e["short"] = " ".join(paras.slice(1)).strip_edges() if paras.size() > 1 else str(e["full"])
	var verdict := str(e.get("verdict", ""))
	if int(RANK.get(verdict, 0)) == 0 or int(e.get("loss", 0)) <= TRUST_LOSS:
		return e
	var moment := GameReview.analyze_move(fen, uci, ply)
	if moment.is_empty():
		return e
	var least := material_floor(moment, pos, m)
	if int(RANK[least]) > int(RANK.get(verdict, 0)):
		e["verdict"] = least
		e["raised"] = true
	e["moment"] = str(moment["kind"])
	e["full"] = str(moment["text"])
	e["short"] = str(moment["text"])
	var better := pos.find_uci(str(moment.get("better", "")))
	if better >= 0:
		e["best_san"] = SanEs.san(pos, better)
		e["best_uci"] = Chess.uci(better)
	return e


## Valoración mínima por lo que se pierde a la vista: un peón, imprecisión; una pieza, error; un mate, error grave.
static func material_floor(moment: Dictionary, pos: Chess, m: int) -> String:
	match str(moment.get("kind", "")):
		"allowed_mate":
			return GameDetail.BLUNDER
		"missed_mate":
			return GameDetail.MISTAKE
		"hang":
			return GameDetail.MISTAKE if -GameReview.net(pos, m) >= 300 else GameDetail.INACCURACY
		"missed_capture":
			var better := pos.find_uci(str(moment.get("better", "")))
			var gain := (GameReview.net(pos, better) if better >= 0 else 0) - GameReview.net(pos, m)
			return GameDetail.MISTAKE if gain >= 300 else GameDetail.INACCURACY
	return GameDetail.GOOD


## Hechos de un error para el profesor. `moment`: lo que devuelve GameReview.analyze_move.
static func facts_for(moment: Dictionary, played_san: String, better_san: String, rating: float, language: String) -> Dictionary:
	return {
		"fen": str(moment.get("fen", "")),
		"kind": str(moment.get("kind", "")),
		"played": played_san,
		"better": better_san,
		"verified": str(moment.get("text", "")),
		"rating": int(round(rating)),
		"language": language,
	}


static func level_words(rating: int) -> String:
	if rating <= 0:
		return "nivel desconocido: trátalo como principiante"
	if rating < 1000:
		return "principiante (unos %d puntos)" % rating
	if rating < 1500:
		return "aficionado (unos %d puntos)" % rating
	if rating < 1900:
		return "jugador de club (unos %d puntos)" % rating
	return "jugador fuerte (unos %d puntos)" % rating


const KIND_WORDS := {
	"missed_mate": "tenía jaque mate en una jugada y no lo dio",
	"allowed_mate": "su jugada permite al rival dar jaque mate en una",
	"hang": "su jugada deja material a tiro: el rival puede capturar y ganarlo",
	"missed_capture": "podía capturar una pieza mal defendida y ganar material, y no lo hizo",
	"inaccuracy": "su jugada es imprecisa: había otra claramente mejor",
	"mistake": "su jugada es un error: según el análisis de la app pierde ventaja o material",
	"blunder": "su jugada es un error grave: según el análisis de la app pierde mucho material o permite un mate",
}


## Cuerpo de la petición a la API de mensajes de Claude.
static func build_body(facts: Dictionary, config: Dictionary) -> Dictionary:
	var lang := str(facts.get("language", "es"))
	var lang_name := str(Loc.NAMES.get(lang, "Español"))
	var system := "\n".join([
		"Eres el profesor de ajedrez de la app A Chess Way. Tu alumno juega una partida contra la app y acaba de cometer un error.",
		"Tu trabajo es explicárselo como un buen profesor: claro, cercano y breve, sin regañar.",
		"Reglas estrictas:",
		"- Usa SOLO los hechos que te doy. Están comprobados en el tablero. No calcules jugadas ni evalúes la posición por tu cuenta.",
		"- No nombres ninguna casilla ni jugada que no aparezca en los hechos.",
		"- Como mucho 3 frases. Termina con un consejo práctico para la próxima jugada.",
		"- Adapta el vocabulario al nivel del alumno.",
		"- Escribe en %s, con la notación de ajedrez de ese idioma. Sin markdown, sin listas, sin emojis." % lang_name,
	])
	var user := "\n".join([
		"Nivel del alumno: %s." % level_words(int(facts.get("rating", 0))),
		"Posición antes de su jugada (FEN): %s" % str(facts.get("fen", "")),
		"Jugada del alumno: %s" % str(facts.get("played", "")),
		"Qué ha pasado: %s." % str(KIND_WORDS.get(str(facts.get("kind", "")), "error")),
		"Jugada mejor (comprobada): %s" % (str(facts.get("better", "")) if str(facts.get("better", "")) != "" else "no indicada"),
		"Explicación comprobada (redáctala con tus palabras, sin añadir nada): %s" % str(facts.get("verified", "")),
	])
	return {
		"model": str(config.get("model", "claude-haiku-5-5")),
		"max_tokens": int(config.get("max_tokens", 220)),
		"system": system,
		"messages": [{"role": "user", "content": user}],
		# Solo hay que redactar: sin razonamiento previo, que gastaría los tokens antes de escribir.
		"thinking": {"type": "disabled"},
	}


## Casillas que la IA puede nombrar: las de los hechos (texto comprobado y jugadas).
static func allowed_squares(facts: Dictionary) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string(SQUARE)
	for field: String in ["verified", "played", "better"]:
		for m in re.search_all(str(facts.get(field, ""))):
			out[m.get_string(1)] = true
	return out


## La respuesta vale si no está vacía, no es enorme y no nombra casillas fuera de los hechos.
static func answer_ok(text: String, facts: Dictionary) -> bool:
	var t := text.strip_edges()
	if t.length() < 10 or t.length() > 700:
		return false
	var allowed := allowed_squares(facts)
	var re := RegEx.create_from_string(SQUARE)
	for m in re.search_all(t):
		if not allowed.has(m.get_string(1)):
			return false
	return true


## Texto de la respuesta de la API de mensajes ("" si no se entiende).
static func parse_answer(body: String) -> String:
	var data: Variant = JSON.parse_string(body)
	if not (data is Dictionary):
		return ""
	var content: Variant = (data as Dictionary).get("content", [])
	if not (content is Array):
		return ""
	var parts: Array[String] = []
	for c: Variant in content:
		if c is Dictionary and str((c as Dictionary).get("type", "")) == "text":
			parts.append(str((c as Dictionary)["text"]))
	return "".join(parts).strip_edges()


## Pide la explicación. Siempre acaba emitiendo `answered`: con el texto de la IA si llega y es válido; si no, con
## el texto comprobado (from_ai = false).
func ask(facts: Dictionary, run: int, ply: int) -> void:
	var verified := str(facts.get("verified", ""))
	var how := endpoint_mode(cfg, Premium.test_key, Premium.test_allowed())
	if how == "" or busy:
		answered.emit(run, ply, verified, false)
		return
	busy = true
	calls += 1
	var url := str(cfg.get("endpoint", "")) if how == "server" else str(cfg.get("api_url", "https://api.anthropic.com/v1/messages"))
	var headers := PackedStringArray(["content-type: application/json", "anthropic-version: 2023-06-01"])
	if how == "direct":
		headers.append("x-api-key: " + Premium.test_key.strip_edges())
	var req := HTTPRequest.new()
	req.timeout = float(cfg.get("timeout_s", 20))
	add_child(req)
	# Al servidor propio (worker/) solo van los hechos: el prompt lo construye él, con la clave.
	var payload: Dictionary = {"facts": facts} if how == "server" else build_body(facts, cfg)
	var err := req.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		req.queue_free()
		busy = false
		answered.emit(run, ply, verified, false)
		return
	var r: Array = await req.request_completed
	req.queue_free()
	busy = false
	var code := int(r[1])
	var text := parse_answer((r[3] as PackedByteArray).get_string_from_utf8()) if code == 200 else ""
	if code != 200:
		push_warning("Profesor IA: respuesta %d" % code)
	if text != "" and answer_ok(text, facts):
		answered.emit(run, ply, text, true)
	else:
		answered.emit(run, ply, verified, false)


## POST con JSON; devuelve el diccionario de la respuesta o {} (sin red, error o respuesta que no es un objeto).
func _post(url: String, payload: Dictionary, seconds: float) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = seconds
	add_child(req)
	var err := req.request(url, PackedStringArray(["content-type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		req.queue_free()
		return {"_error": 0}
	var r: Array = await req.request_completed
	req.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS or int(r[1]) != 200:
		if int(r[1]) != 0:
			push_warning("Tutor: respuesta %d" % int(r[1]))
		return {"_error": int(r[1])}
	var data: Variant = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	return data if data is Dictionary else {}


## Pide a Stockfish (por el servidor) la valoración de una jugada. Siempre acaba emitiendo `judged`.
func judge_remote(fen: String, uci: String, run: int, gen: int) -> void:
	var url := tutor_url(cfg)
	if url == "":
		judged.emit(run, gen, {})
		return
	calls += 1
	var data := await _post(url, {"fen": fen, "uci": uci}, float(cfg.get("tutor_timeout_s", 7)))
	judged.emit(run, gen, data if remote_ok(data) else {})


## Pide a Claude (por el servidor) la lección de una jugada ya valorada. Siempre acaba emitiendo `lesson_ready`.
func lesson_remote(payload: Dictionary, run: int, gen: int) -> void:
	var url := tutor_url(cfg)
	if url == "":
		lesson_ready.emit(run, gen, {})
		return
	calls += 1
	var data := await _post(url + "/leccion", payload, float(cfg.get("lesson_timeout_s", 30)))
	lesson_ready.emit(run, gen, data if data.get("played") is Array else {})


## Pregunta libre: la partida (las últimas 16 jugadas como mucho, desde la posición de antes), el color del alumno
## y la pregunta. `history`: posiciones (FEN) de la partida, una más que `moves`.
static func ask_payload(history: Array, moves: Array, color: int, question: String, rating: int, language: String) -> Dictionary:
	var k := maxi(0, moves.size() - 16)
	var start := str(history[k]) if k < history.size() else str(history[0])
	return {"start": start, "moves": moves.slice(k), "player": "w" if color == 0 else "b", "question": question.strip_edges().left(400), "rating": rating, "language": language}


## Respuesta a una pregunta válida: texto y, si la hay, la línea para el tablero (pasos con posición legal).
static func question_ok(data: Dictionary) -> bool:
	if str(data.get("answer", "")).length() < 3:
		return false
	var show: Variant = data.get("show")
	if show == null:
		return true
	if not (show is Dictionary) or not ((show as Dictionary).get("steps") is Array):
		return false
	for step: Variant in (show as Dictionary)["steps"]:
		if not (step is Dictionary):
			return false
		if str((step as Dictionary).get("fen", "")) == "" or str((step as Dictionary).get("uci", "")).length() < 4:
			return false
		var pos := Chess.from_fen(str((step as Dictionary)["fen"]))
		if pos.find_uci(str((step as Dictionary)["uci"])) < 0:
			return false
	return true


## Pregunta al tutor (Claude, con Stockfish como herramienta). Siempre acaba emitiendo `asked`.
func ask_remote(payload: Dictionary, run: int, gen: int) -> void:
	var url := tutor_url(cfg)
	if url == "":
		asked.emit(run, gen, {"_error": -1})
		return
	calls += 1
	if hold_questions:
		return
	var data := await _post(url + "/pregunta", payload, float(cfg.get("ask_timeout_s", 60)))
	if data.has("_error") or not question_ok(data):
		asked.emit(run, gen, {"_error": int(data.get("_error", 502))})
		return
	asked.emit(run, gen, data)
