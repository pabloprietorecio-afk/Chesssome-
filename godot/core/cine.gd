class_name Cine
extends RefCounted
## Finales de campeones (el cine, fase 1): momentos de partidas famosas convertidos en lecciones. Cada pregunta es
## un ejercicio «move» en el que vale cualquier jugada que mantiene el resultado; las explicaciones de la lección y
## del abandono son pasos «info». Sin vídeo dentro de la app (fase 2): al final se abre el vídeo oficial en YouTube.
## Datos: data/cine.json, que genera tools/cine/build.py a partir de los clips comprobados con el motor en la web.

const DATA := "res://data/cine.json"

static var _clips: Array = []


static func clips() -> Array:
	if _clips.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_clips = (d as Dictionary).get("clips", [])
	return _clips


## Las lecciones de todos los clips, en orden.
static func lessons() -> Array:
	var out: Array = []
	for c: Dictionary in clips():
		out.append(c["lesson"])
	return out


static func is_lesson(id: String) -> bool:
	return id.begins_with("cine-")


## El clip de una lección del cine ({} si no lo es).
static func clip_of(lesson_id: String) -> Dictionary:
	for c: Dictionary in clips():
		if str((c["lesson"] as Dictionary)["id"]) == lesson_id:
			return c
	return {}


## El vídeo oficial en YouTube, desde el principio del momento.
static func video_url(clip: Dictionary) -> String:
	var v: Dictionary = clip.get("video", {})
	var t := int(v.get("start", 0))
	return "https://www.youtube.com/watch?v=%s%s" % [str(v.get("id", "")), ("&t=%ds" % t) if t >= 1 else ""]


## Texto de un paso «info» con varias partes (el abandono): cada una se traduce por separado.
static func info_text(ex: Dictionary) -> String:
	var parts: Array = ex.get("parts", [])
	if parts.is_empty():
		return Loc.t(str(ex.get("text", "")))
	var out: Array = []
	for p: Variant in parts:
		if str(p) != "":
			out.append(Loc.t(str(p)))
	return (" " if Loc.language != "ja" else "").join(out)


## Lo que se dice tras jugar `uci` en una pregunta: si mantiene el resultado, por qué; si no, qué estropea y cómo
## podría seguir. Solo con el veredicto guardado y los textos del clip (nada inventado).
static func answer(ex: Dictionary, uci: String) -> String:
	var info: Dictionary = ex.get("cine", {})
	var v: Dictionary = (ex.get("moves", {}) as Dictionary).get(uci, {})
	# Las jugadas de los datos vienen en notación española: se pasan aquí a la del idioma (Loc.f ya no toca una
	# jugada suelta, porque las del tablero llegan escritas en la notación del idioma).
	var played := Loc.san_text(str(info.get("playedSan", "")))
	var win := str(info.get("target", "")) == "win"
	var sep := " " if Loc.language != "ja" else ""
	if v.is_empty():
		return Loc.f("En la partida se jugó %s.", played)
	var mine := Loc.san_text(str(v.get("san", "")))
	var cls := str(v.get("c", ""))
	var played_ok := str(info.get("playedCls", "")) == "keeps"
	var why := Loc.t(str(info.get("why", "")))
	var out: Array = []
	if uci == str(info.get("played", "")):
		if played_ok:
			return why
		out.append(Loc.f("Es lo que se jugó en la partida, pero %s deja escapar la victoria." if win and not bool(v.get("loses", false)) else "Es lo que se jugó en la partida, pero %s pierde.", mine))
	elif cls == "keeps" and not played_ok:
		# En la partida hubo aquí un error: encontrar una jugada que mantiene el resultado es la respuesta.
		return sep.join([Loc.f("%s gana." if win else "%s mantiene las tablas.", mine), why])
	elif cls == "keeps":
		return Loc.f("%s también gana. En la partida se jugó %s." if win else "%s también mantiene las tablas. En la partida se jugó %s.", [mine, played])
	elif cls == "spoils":
		out.append(Loc.f("%s deja escapar la victoria." if win and not bool(v.get("loses", false)) else "%s pierde.", mine))
	else:
		out.append(Loc.f("%s no está tan clara: puede que no baste. En la partida se jugó %s.", [mine, played]))
	if str(v.get("line", "")) != "":
		out.append(Loc.f("Así podría seguir: %s.", Loc.san_text(str(v["line"]))))
	match str(v.get("end", "")):
		"checkmate":
			out.append(Loc.t("Y acaba en mate."))
		"stalemate":
			out.append(Loc.t("Y acaba en ahogado: tablas."))
		"insufficient":
			out.append(Loc.t("Y no queda material para dar mate: tablas."))
	if uci == str(info.get("played", "")) and not played_ok:
		for u: Variant in (ex.get("moves", {}) as Dictionary).keys():
			if bool((ex["moves"][u] as Dictionary).get("ok", false)):
				out.append(Loc.f("Lo correcto era %s.", Loc.san_text(str((ex["moves"][u] as Dictionary).get("san", "")))))
				break
	return sep.join(out)
