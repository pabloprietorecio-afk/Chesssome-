class_name Loc
extends RefCounted
## Idiomas de la app (como en A Tank Story). El texto del código está en español y es la clave: en español se
## muestra tal cual; en los demás idiomas se busca en su tabla, data/i18n/<idioma>.json ({"texto en español":
## "traducción"}) y, si no está, también se muestra tal cual.
##
## Uso: Loc.t("TEXTO") o Loc.t("Nivel %d de %d") % [a, b]. Las etiquetas y botones con un texto fijo se traducen
## solos (Godot traduce el texto de los controles con TranslationServer); Loc.t hace falta con los textos que
## se componen (con «%», sumando trozos) antes de ponerlos en pantalla.
## Cambiar de idioma: Loc.apply(código) y rehacer la pantalla.

const LANGUAGES: Array[String] = ["es", "en", "fr", "it", "ja", "pt", "id", "hi", "de", "ru"]
## Cada idioma escrito en su propio idioma, como se ve en el selector.
const NAMES: Dictionary = {"es": "Español", "en": "English", "fr": "Français", "it": "Italiano", "ja": "日本語",
		"pt": "Português", "id": "Bahasa Indonesia", "hi": "हिन्दी", "de": "Deutsch", "ru": "Русский"}
## Lo que se ve sobre el tablerito que hace de bandera.
const CODES: Dictionary = {"es": "ES", "en": "EN", "fr": "FR", "it": "IT", "ja": "日本", "pt": "PT", "id": "ID",
		"hi": "हि", "de": "DE", "ru": "RU"}
## Subconjunto de Noto Sans JP (OFL) con los caracteres japoneses de la app (tools/i18n/fonts.py).
const JAPANESE_FONT: String = "res://fonts/NotoSansJP-Subset.ttf"
## Noto Sans Devanagari (OFL), para el hindi.
const DEVANAGARI_FONT: String = "res://fonts/NotoSansDevanagari-Medium.ttf"

## Letras de las piezas en la notación de cada idioma, por tipo (Chess: 2 caballo, 3 alfil, 4 torre, 5 dama, 6 rey).
## Japonés, indonesio e hindi usan las inglesas, como sus libros y webs de ajedrez.
const LETTERS: Dictionary = {
	"es": ["", "", "C", "A", "T", "D", "R"], "it": ["", "", "C", "A", "T", "D", "R"],
	"en": ["", "", "N", "B", "R", "Q", "K"], "ja": ["", "", "N", "B", "R", "Q", "K"],
	"id": ["", "", "N", "B", "R", "Q", "K"], "hi": ["", "", "N", "B", "R", "Q", "K"],
	"fr": ["", "", "C", "F", "T", "D", "R"], "pt": ["", "", "C", "B", "T", "D", "R"],
	"de": ["", "", "S", "L", "T", "D", "K"], "ru": ["", "", "К", "С", "Л", "Ф", "Кр"],
}
const _ES_TYPE: Dictionary = {"C": 2, "A": 3, "T": 4, "D": 5, "R": 6}

static var language: String = "es"
static var _san_re: RegEx = null
static var _exp_re: RegEx = null
static var _al_re: RegEx = null
static var _split_re: RegEx = null
## Plantillas de las explicaciones de los problemas (data/i18n/<idioma>.json, sección con clave "@exp"):
## «Tras {1}, la pieza de {2} puede capturarse…» → traducción con los mismos {n}, en el orden que pida el idioma.
static var _exp: Dictionary = {}
## Idiomas que escriben los decimales con punto (los demás, con coma, como el español).
const DECIMAL_POINT: Array[String] = ["en", "ja", "hi"]
## Piezas tal como salen en las explicaciones: «tu dama», «el caballo rival», «la torre blanca», «peones»…
const _EXP_PIECE := "(?:(?:[Ee]l|[Ll]as?|[Ll]os|[Uu]na?|[Tt]us?|[Ss]us?) )?(?:peón|peones|caballos?|alfil(?:es)?|torres?|damas?|reye?s?)(?: (?:blanc[oa]s?|negr[oa]s?|rival(?:es)?))?"
const _EXP_SAN := "(?:[RDTAC][a-h]?[1-8]?x?[a-h][1-8](?:=[DTAC])?[+#]?|[a-h]x[a-h][1-8](?:=[DTAC])?[+#]?|[a-h][1-8](?:=[DTAC])?[+#]?|O-O-O[+#]?|O-O[+#]?)"
static var _table: Dictionary = {}
static var _catalog: Translation = null
static var _fallback_fonts: Dictionary = {}


## El idioma del móvil, si la app lo tiene; si no, inglés.
static func device_language() -> String:
	var code := OS.get_locale_language()
	return code if code in LANGUAGES else "en"


## Activa un idioma: carga su tabla (solo la del idioma activo, para no gastar memoria) y la registra en
## TranslationServer para que los controles se traduzcan solos.
static func apply(code: String) -> void:
	language = code if code in LANGUAGES else "es"
	if _catalog != null:
		TranslationServer.remove_translation(_catalog)
		_catalog = null
	_table = {}
	_exp = {}
	if language != "es":
		var path := "res://data/i18n/%s.json" % language
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_DICTIONARY:
				_table = parsed
		_exp = _table.get("@exp", {})
		_table.erase("@exp")
		_catalog = Translation.new()
		_catalog.locale = language
		for key: String in _table:
			_catalog.add_message(StringName(key), StringName(str(_table[key])))
		TranslationServer.add_translation(_catalog)
	_update_font_fallbacks()
	TranslationServer.set_locale(language)


## Traduce `message` al idioma activo (tal cual si no está en la tabla).
static func t(message: String) -> String:
	if language == "es" or message.is_empty():
		return message
	return str(_table.get(message, message))


## Traduce una plantilla con «%» y también los textos que se meten en ella (nombres de piezas, de niveles…):
## Loc.f("Nivel %d · %s", [3, "Alfil"]) → "Level 3 · Bishop". Lo que no está en la tabla (jugadas, nombres
## de jugadores) entra tal cual.
static func f(template: String, args: Variant) -> String:
	if language == "es":
		return template % args
	if args is Array:
		var out: Array = []
		for a: Variant in args:
			out.append(t(a) if a is String else a)
		return t(template) % out
	if args is String:
		return t(template) % t(args)
	return t(template) % args


## Letra de una pieza (tipo de Chess) en la notación del idioma activo.
static func piece_letter(piece_type: int) -> String:
	return str((LETTERS.get(language, LETTERS["es"]) as Array)[piece_type])


## Pasa las jugadas escritas en notación española dentro de un texto («Dxf2+», «Cd3», «e8=D») a la notación
## del idioma activo. Solo toca lo que tiene forma de jugada: letra de pieza seguida de casilla.
static func san_text(text: String) -> String:
	if language == "es" or language == "it" or text.is_empty():
		return text
	if _san_re == null:
		_san_re = RegEx.new()
		_san_re.compile("(?<![\\p{L}\\d])([CATDR])([a-h]?[1-8]?x?[a-h][1-8])|=([CATD])(?=[+#]?(?![\\p{L}\\d]))")
	var out := ""
	var at := 0
	for m: RegExMatch in _san_re.search_all(text):
		out += text.substr(at, m.get_start() - at)
		if m.get_string(1) != "":
			out += piece_letter(int(_ES_TYPE[m.get_string(1)])) + m.get_string(2)
		else:
			out += "=" + piece_letter(int(_ES_TYPE[m.get_string(3)]))
		at = m.get_end()
	return out + text.substr(at)


## Una frase de las explicaciones de los problemas convertida en plantilla: las jugadas (y sus números), las cifras y
## las piezas pasan a {1}, {2}… Devuelve [plantilla, valores, tipos] (tipo "m" jugadas, "n" cifra, "p" pieza).
## «al caballo» y «del caballo» se leen como «a el caballo» y «de el caballo»: así la pieza lleva siempre su artículo
## y salen muchas menos plantillas.
static func exp_template(text: String) -> Array:
	if _exp_re == null:
		_exp_re = RegEx.new()
		var move := "(?:\\d+(?:\\.|…) ?)?" + _EXP_SAN
		_exp_re.compile("(?<![\\p{L}\\d])(?:(" + move + "(?: " + move + ")*)|(" + _EXP_PIECE + ")|([−+-]?\\d+(?:[.,]\\d+)?)|(?<=Lichess: )([A-Za-z0-9]+))(?![\\p{L}\\d])")
		_al_re = RegEx.new()
		_al_re.compile("(?<![\\p{L}])(a|de)l (?=(?:peón|caballo|alfil|rey)(?![\\p{L}]))")
		_split_re = RegEx.new()
		_split_re.compile("(?<=[.!?]) (?=[A-ZÁÉÍÓÚ¡¿«{])|(?<=^Aquí:) ")
	text = _al_re.sub(text, "$1 el ", true)
	var out := ""
	var values: Array = []
	var kinds: Array = []
	var at := 0
	for m: RegExMatch in _exp_re.search_all(text):
		out += text.substr(at, m.get_start() - at)
		values.append(m.get_string())
		kinds.append("m" if m.get_string(1) != "" else ("p" if m.get_string(2) != "" else ("t" if m.get_string(4) != "" else "n")))
		out += "{%d}" % values.size()
		at = m.get_end()
	return [out + text.substr(at), values, kinds]


## Las frases de una plantilla, cada una con sus huecos numerados desde {1}: [[frase, [números globales]], …].
static func exp_sentences(template: String) -> Array:
	var parts: Array = []
	var at := 0
	for m: RegExMatch in _split_re.search_all(template):
		parts.append(template.substr(at, m.get_start() - at))
		at = m.get_end()
	parts.append(template.substr(at))
	var out: Array = []
	var hole := RegEx.create_from_string("\\{(\\d+)\\}")
	for part: String in parts:
		var globals: Array = []
		var local := ""
		var p := 0
		for m: RegExMatch in hole.search_all(part):
			local += part.substr(p, m.get_start() - p)
			globals.append(int(m.get_string(1)))
			local += "{%d}" % globals.size()
			p = m.get_end()
		out.append([local + part.substr(p), globals])
	return out


## Traduce una frase de las explicaciones de los problemas (que vienen escritas en español): la parte en frases, busca
## cada plantilla en la tabla del idioma y rellena los huecos. Si falta alguna frase, la deja entera en español.
static func explain(text: String) -> String:
	if language == "es" or text.is_empty():
		return text
	if _table.has(text):
		return str(_table[text])
	var tpl := exp_template(text)
	var values: Array = tpl[1]
	var kinds: Array = tpl[2]
	var shown: Array = []
	for i in values.size():
		var v := str(values[i])
		match str(kinds[i]):
			"m":
				v = san_text(v)
			"p":
				v = t(v)
			"n":
				if language in DECIMAL_POINT:
					v = v.replace(",", ".")
		shown.append(v)
	var out: Array = []
	for sentence: Array in exp_sentences(tpl[0]):
		if not _exp.has(sentence[0]):
			return text
		var piece := str(_exp[sentence[0]])
		var globals: Array = sentence[1]
		for k in globals.size():
			var g := int(globals[k]) - 1
			# {n:acc}: la pieza como complemento directo (alemán y ruso declinan: «einen Turm», «ладью»).
			if piece.contains("{%d:acc}" % (k + 1)):
				var acc := str(values[g])
				piece = piece.replace("{%d:acc}" % (k + 1), t("acc:" + acc) if str(kinds[g]) == "p" and has("acc:" + acc) else str(shown[g]))
			piece = piece.replace("{%d}" % (k + 1), str(shown[g]))
		out.append(piece)
	return (" " if language != "ja" else "").join(out)


## Si hay traducción de `message` en el idioma activo (para las pruebas).
static func has(message: String) -> bool:
	return language == "es" or _table.has(message)


## Inter no trae kanji, kana ni devanagari: se añade la fuente del idioma activo como respaldo de todas las
## fuentes de la app. Solo en esos idiomas: son más altas y en los demás cambiarían la altura de las líneas.
static func add_fallbacks(fonts: Array) -> void:
	for f: Variant in fonts:
		if f is Font and not _fallback_fonts.has(f):
			_fallback_fonts[f] = true
	_update_font_fallbacks()


static func _update_font_fallbacks() -> void:
	var wanted_path := ""
	if language == "ja":
		wanted_path = JAPANESE_FONT
	elif language == "hi":
		wanted_path = DEVANAGARI_FONT
	var wanted: Font = null
	if wanted_path != "" and ResourceLoader.exists(wanted_path):
		wanted = load(wanted_path)
	var fonts: Array = _fallback_fonts.keys()
	fonts.append(ThemeDB.fallback_font)
	for font: Font in fonts:
		if font == null:
			continue
		var base: Font = font
		if font is FontVariation and (font as FontVariation).base_font != null:
			base = (font as FontVariation).base_font
		var chain: Array[Font] = []
		for existing: Font in base.fallbacks:
			if existing != null and existing.resource_path != JAPANESE_FONT and existing.resource_path != DEVANAGARI_FONT:
				chain.append(existing)
		if wanted != null:
			chain.append(wanted)
		base.fallbacks = chain
