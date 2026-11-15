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
const JAPANESE_FONT: String = "res://fonts/NotoSansJP-Subset.otf"
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
	if language != "es":
		var path := "res://data/i18n/%s.json" % language
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_DICTIONARY:
				_table = parsed
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
