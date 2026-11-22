class_name TutorSpeech
extends Node
## La voz del tutor: lee en voz alta lo que contesta, con el lector de texto del propio móvil (el motor de voz de
## Android, a través de Godot: DisplayServer.tts_*). Sin servidor ni coste, y funciona sin conexión (Pablo, 22 nov:
## «en vez de depender de un servidor externo, ¿no podemos poner un lector de texto?»). docs/voz-tutor.md.
## - Solo se lee el texto de la IA que se le pasa (no la pantalla entera, como haría TalkBack).
## - Antes, las jugadas se pasan a palabras en el idioma de la app («Cxf5+» → «caballo toma en efe cinco, jaque»):
##   el lector las deletrearía.
## - La voz: la del idioma de la app, con preferencia por la de España en español (y Portugal en portugués) y por las
##   que funcionan sin conexión. Cada móvil tiene las suyas: se instalan y se cambian en los ajustes de Android.

signal speaking_changed(on: bool)

## Variante preferida de cada idioma (las voces de Android se llaman por su «locale»: es_ES, pt_PT…).
const PREFERRED := {"es": "es_es", "pt": "pt_pt", "en": "en_gb", "fr": "fr_fr", "it": "it_it", "de": "de_de", "ru": "ru_ru", "id": "id_id", "hi": "hi_in", "ja": "ja_jp"}

var enabled := true
var speaking := false
## Pruebas: lo que se ha mandado al lector (ya preparado).
var system_said: Array = []
## Pruebas: no llamar al lector (en el ordenador de la CI no hay).
var mute_output := false

var _utterance := 0


func _ready() -> void:
	if available():
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_end)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_end)


## El móvil tiene lector y está activado en project.godot (audio/general/text_to_speech).
static func available() -> bool:
	return bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)) and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)


## Lee el texto (corta lo que estuviera leyendo).
func say(text: String, language: String) -> void:
	stop()
	if not enabled:
		return
	var clean := speakable(text, language)
	if clean == "":
		return
	system_said.append(clean)
	if mute_output or not available():
		return
	_utterance += 1
	_set_speaking(true)
	DisplayServer.tts_speak(clean, pick_voice(DisplayServer.tts_get_voices(), language), 100, 1.0, 1.0, _utterance, true)


func stop() -> void:
	if speaking and available():
		DisplayServer.tts_stop()
	_utterance += 1
	_set_speaking(false)


func _on_end(id: int) -> void:
	# Llega desde el hilo del lector.
	_end_main.call_deferred(id)


func _end_main(id: int) -> void:
	if id == _utterance:
		_set_speaking(false)


func _set_speaking(on: bool) -> void:
	if speaking != on:
		speaking = on
		speaking_changed.emit(on)


## La voz para un idioma, entre las del móvil ({id, language}; en Android, language es «es_ES»): primero la variante
## preferida, después cualquiera del idioma; en cada caso, mejor las que no necesitan conexión («local» en su
## nombre). "" si no hay ninguna (Android usa entonces la voz por defecto).
static func pick_voice(voices: Array, language: String) -> String:
	var want := str(PREFERRED.get(language, language))
	var best := ""
	var best_score := -1
	for v: Variant in voices:
		if not v is Dictionary:
			continue
		var lang := str((v as Dictionary).get("language", "")).replace("-", "_").to_lower()
		var id := str((v as Dictionary).get("id", ""))
		if not (lang == language or lang.begins_with(language + "_")):
			continue
		var score := (2 if lang.begins_with(want) else 0) + (1 if id.to_lower().contains("local") else 0)
		if score > best_score:
			best_score = score
			best = id
	return best


# ---------------------------------------------------------------- texto preparado para leer

## Cómo se dicen las jugadas en cada idioma. Las letras de las piezas son las de la notación de la app (Loc.LETTERS):
## japonés, indonesio e hindi usan las inglesas. Japonés e hindi, sin revisar por un nativo; ahí las casillas se
## dejan escritas (el lector las lee letra y número).
const WORDS := {
	"es": {"pieces": {"R": "rey", "D": "dama", "T": "torre", "A": "alfil", "C": "caballo"}, "pawn": "peón de", "takes": "toma en", "to": "a",
		"check": "jaque", "mate": "jaque mate", "promote": "y corona", "short": "enroque corto", "long": "enroque largo",
		"files": ["a", "be", "ce", "de", "e", "efe", "ge", "hache"], "ranks": ["uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho"]},
	"en": {"pieces": {"K": "king", "Q": "queen", "R": "rook", "B": "bishop", "N": "knight"}, "pawn": "pawn", "takes": "takes on", "to": "to",
		"check": "check", "mate": "checkmate", "promote": "promoting to", "short": "castles kingside", "long": "castles queenside",
		"files": ["A", "B", "C", "D", "E", "F", "G", "H"], "ranks": ["one", "two", "three", "four", "five", "six", "seven", "eight"]},
	"fr": {"pieces": {"R": "roi", "D": "dame", "T": "tour", "F": "fou", "C": "cavalier"}, "pawn": "pion", "takes": "prend en", "to": "en",
		"check": "échec", "mate": "échec et mat", "promote": "et devient", "short": "petit roque", "long": "grand roque",
		"files": ["a", "bé", "cé", "dé", "e", "effe", "gé", "hache"], "ranks": ["un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit"]},
	"it": {"pieces": {"R": "re", "D": "donna", "T": "torre", "A": "alfiere", "C": "cavallo"}, "pawn": "pedone", "takes": "prende in", "to": "in",
		"check": "scacco", "mate": "scacco matto", "promote": "e promuove a", "short": "arrocco corto", "long": "arrocco lungo",
		"files": ["a", "bi", "ci", "di", "e", "effe", "gi", "acca"], "ranks": ["uno", "due", "tre", "quattro", "cinque", "sei", "sette", "otto"]},
	"pt": {"pieces": {"R": "rei", "D": "dama", "T": "torre", "B": "bispo", "C": "cavalo"}, "pawn": "peão de", "takes": "captura em", "to": "para",
		"check": "xeque", "mate": "xeque-mate", "promote": "e promove a", "short": "roque pequeno", "long": "roque grande",
		"files": ["a", "bê", "cê", "dê", "é", "efe", "gê", "agá"], "ranks": ["um", "dois", "três", "quatro", "cinco", "seis", "sete", "oito"]},
	"de": {"pieces": {"K": "König", "D": "Dame", "T": "Turm", "L": "Läufer", "S": "Springer"}, "pawn": "Bauer", "takes": "schlägt auf", "to": "nach",
		"check": "Schach", "mate": "Schachmatt", "promote": "und wird zur", "short": "kurze Rochade", "long": "lange Rochade",
		"files": ["a", "be", "ze", "de", "e", "eff", "ge", "ha"], "ranks": ["eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht"]},
	"ru": {"pieces": {"Кр": "король", "Ф": "ферзь", "Л": "ладья", "С": "слон", "К": "конь"}, "pawn": "пешка", "takes": "берёт на", "to": "на",
		"check": "шах", "mate": "мат", "promote": "и превращается в", "short": "короткая рокировка", "long": "длинная рокировка",
		"files": ["а", "бэ", "цэ", "дэ", "е", "эф", "жэ", "аш"], "ranks": ["один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь"]},
	"id": {"pieces": {"K": "raja", "Q": "menteri", "R": "benteng", "B": "gajah", "N": "kuda"}, "pawn": "pion", "takes": "makan di", "to": "ke",
		"check": "skak", "mate": "skakmat", "promote": "dan promosi menjadi", "short": "rokade pendek", "long": "rokade panjang",
		"files": ["a", "be", "ce", "de", "e", "ef", "ge", "ha"], "ranks": ["satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan"]},
	"ja": {"pieces": {"K": "キング", "Q": "クイーン", "R": "ルーク", "B": "ビショップ", "N": "ナイト"}, "pawn": "ポーン", "takes": "で取る", "to": "",
		"check": "チェック", "mate": "チェックメイト", "promote": "に昇格", "short": "キングサイドキャスリング", "long": "クイーンサイドキャスリング", "after": true, "comma": "、"},
	"hi": {"pieces": {"K": "राजा", "Q": "वज़ीर", "R": "हाथी", "B": "ऊँट", "N": "घोड़ा"}, "pawn": "प्यादा", "takes": "पर कब्ज़ा", "to": "",
		"check": "शह", "mate": "शह और मात", "promote": "बनता है", "short": "छोटा कैसलिंग", "long": "बड़ा कैसलिंग", "after": true},
}

static var _move_re: Dictionary = {}


static func _re(language: String) -> RegEx:
	if _move_re.has(language):
		return _move_re[language]
	var letters: Array = (WORDS[language]["pieces"] as Dictionary).keys()
	letters.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var p := "(?:" + "|".join(letters) + ")"
	# Enroque, o pieza + columna/fila de origen + captura + casilla + coronación + jaque/mate. Ni letra ni número
	# pegados delante o detrás: «e5» dentro de una palabra no es una casilla.
	var pattern := "(?<![\\p{L}\\p{N}])(?:(O-O-O|0-0-0)|(O-O|0-0)|(%s)?([a-h])?([1-8])?([x:×])?([a-h])([1-8])(?:=?(%s))?)([+#])?(?![\\p{L}\\p{N}])" % [p, p]
	var re := RegEx.create_from_string(pattern)
	_move_re[language] = re
	return re


static func _square(w: Dictionary, f: String, r: String) -> String:
	if not w.has("files"):
		return f + r
	return "%s %s" % [(w["files"] as Array)["abcdefgh".find(f)], (w["ranks"] as Array)[int(r) - 1]]


static func _move_words(w: Dictionary, m: RegExMatch) -> String:
	var out := ""
	if m.get_string(1) != "":
		out = str(w["long"])
	elif m.get_string(2) != "":
		out = str(w["short"])
	else:
		var pieces: Dictionary = w["pieces"]
		var piece := m.get_string(3)
		var from_f := m.get_string(4)
		var cap := m.get_string(6) != ""
		var to := _square(w, m.get_string(7), m.get_string(8))
		var name := str(pieces[piece]) if piece != "" else ""
		if name == "" and from_f != "" and cap:
			name = "%s %s" % [w["pawn"], (w["files"] as Array)["abcdefgh".find(from_f)] if w.has("files") else from_f]
		if name == "" and not cap:
			out = to
		elif bool(w.get("after", false)):
			out = "%s %s %s" % [name, to, w["takes"]] if cap else "%s %s" % [name, to]
		else:
			out = "%s %s %s" % [name, w["takes"], to] if cap else ("%s %s %s" % [name, w["to"], to]).strip_edges()
		if m.get_string(9) != "":
			out += " %s %s" % [w["promote"], pieces[m.get_string(9)]]
	var comma := str(w.get("comma", ", "))
	if m.get_string(10) == "#":
		out += comma + str(w["mate"])
	elif m.get_string(10) == "+":
		out += comma + str(w["check"])
	return out


## El texto tal como debe sonar: sin markdown ni emojis, y las jugadas en palabras. Lo que no se reconoce, tal cual.
static func speakable(text: String, language: String) -> String:
	var t := text
	t = RegEx.create_from_string("(?m)^\\s*(#+|>+|[-*•]\\s)\\s*").sub(t, "", true)
	t = RegEx.create_from_string("[*_`|]+").sub(t, " ", true)
	t = RegEx.create_from_string("[\\x{1F000}-\\x{1FAFF}\\x{2600}-\\x{27BF}\\x{FE0F}\\x{200D}]").sub(t, "", true)
	t = t.replace("→", ", ").replace("⇒", ", ").replace("…", "...")
	if WORDS.has(language):
		var w: Dictionary = WORDS[language]
		var out := ""
		var at := 0
		for m: RegExMatch in _re(language).search_all(t):
			out += t.substr(at, m.get_start() - at) + _move_words(w, m)
			at = m.get_end()
		t = out + t.substr(at)
	# Números de jugada («12.Cge2», «12...e5»): fuera, se entienden por el contexto.
	t = RegEx.create_from_string("(?<![\\p{N}])\\d{1,3}\\.{1,3}\\s*(?=\\p{L})").sub(t, "", true)
	t = RegEx.create_from_string("([!?])\\1+").sub(t, "$1", true)
	t = RegEx.create_from_string("[ \\t]+").sub(t, " ", true)
	t = RegEx.create_from_string(" ([,.;:!?])").sub(t, "$1", true)
	t = RegEx.create_from_string("\\s*\\n\\s*").sub(t, "\n", true)
	return t.strip_edges()
