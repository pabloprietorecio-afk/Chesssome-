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

static var language: String = "es"
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
