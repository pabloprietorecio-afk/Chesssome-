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
##   - "endpoint" con una URL: el servidor propio (p. ej. una Cloud Function) recibe el mismo cuerpo, le pone la
##     clave y comprueba que el jugador es premium. Es lo que hace falta para publicar.
##
## Datos que salen del móvil: la posición (FEN), la jugada, los hechos comprobados, el nivel aproximado y el idioma.
## Nada personal. Nunca en el nivel Kids (Premium.coach_applies).

signal answered(run: int, ply: int, text: String, from_ai: bool)

const CONFIG := "res://data/coach_ai.json"
## Una casilla suelta o dentro de una jugada («Cxf5+», «exd5»): delante puede ir una pieza o la «x» de captura,
## pero no otra letra minúscula (así «abc1» no cuenta).
const SQUARE := "(?<![a-wyz])([a-h][1-8])(?![0-9])"

var cfg: Dictionary = {}
var busy := false
## Peticiones hechas en esta sesión (para las pruebas y para vigilar el gasto).
var calls := 0


func _init() -> void:
	cfg = load_config()


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return parsed if parsed is Dictionary else {}


## Cómo se llamaría ahora: "server" (servidor propio), "direct" (clave de prueba) o "" (no se puede: se queda el
## texto comprobado).
static func endpoint_mode(config: Dictionary, key: String, debug: bool) -> String:
	if str(config.get("endpoint", "")) != "":
		return "server"
	if debug and key.strip_edges() != "":
		return "direct"
	return ""


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
	var err := req.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(build_body(facts, cfg)))
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
