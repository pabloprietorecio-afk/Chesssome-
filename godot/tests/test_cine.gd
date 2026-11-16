extends SceneTree
## Finales de campeones (core/cine.gd, data/cine.json): cada pregunta tiene veredicto para todas sus jugadas legales,
## al menos una que vale y la de la partida; cada respuesta tiene texto; los pasos de explicación tienen posiciones y
## flechas válidas; y los textos están traducidos (con las jugadas en la notación de cada idioma).
## Uso: godot --headless --path godot -s tests/test_cine.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	var clips := Cine.clips()
	_ok(clips.size() == 6, "seis finales (%d)" % clips.size())
	var questions := 0
	for c: Dictionary in clips:
		var l: Dictionary = c["lesson"]
		var id := str(c["id"])
		_ok(Cine.is_lesson(str(l["id"])) and Cine.clip_of(str(l["id"])) == c, id + ": su lección")
		_ok(Cine.video_url(c).begins_with("https://www.youtube.com/watch?v=" + str(c["video"]["id"])), id + ": enlace al vídeo")
		for e: Dictionary in l["exercises"]:
			var pos := Chess.from_fen(str(e["fen"]))
			_ok(pos != null, id + ": posición válida")
			for sq: Variant in e.get("last", []):
				_ok(Chess.sq_index(str(sq)) >= 0, id + ": casilla de la última jugada")
			for a: Dictionary in e.get("arrows", []):
				_ok(Chess.sq_index(str(a["from"])) >= 0 and Chess.sq_index(str(a["to"])) >= 0, id + ": flecha")
			if str(e["kind"]) != "move":
				_ok(Cine.info_text(e) != "", id + ": texto del paso")
				continue
			questions += 1
			var moves: Dictionary = e["moves"]
			var legal := pos.legal_moves()
			_ok(moves.size() == legal.size(), "%s: veredicto para las %d jugadas legales (%d)" % [id, legal.size(), moves.size()])
			var good := 0
			for m in legal:
				var u := Chess.uci(m)
				_ok(moves.has(u), "%s: veredicto de %s" % [id, u])
				if bool((moves.get(u, {}) as Dictionary).get("ok", false)):
					good += 1
				_ok(Cine.answer(e, u) != "", "%s: respuesta a %s" % [id, u])
			_ok(good >= 1, id + ": alguna jugada vale")
			_ok(moves.has(str(e["cine"]["played"])), id + ": la jugada de la partida es legal")
	_ok(questions == 11, "once preguntas (%d)" % questions)

	# Respuestas en español: la de la partida explica por qué; otra que no gana dice qué estropea y cómo seguiría.
	var ding: Dictionary = clips[0]["lesson"]["exercises"][0]
	_ok(Cine.answer(ding, "b2f2").begins_with("Txf2: cambiar las torres"), "la jugada de la partida: su explicación")
	var wrong := Cine.answer(ding, "b2b1")
	_ok(wrong.begins_with("Tb1+ deja escapar la victoria.") and wrong.contains("Así podría seguir: 56.Rh2"), "una que no gana: " + wrong)
	var carlsen: Dictionary = clips[1]["lesson"]["exercises"][0]
	var err := Cine.answer(carlsen, "f4e2")
	_ok(err.begins_with("Es lo que se jugó en la partida, pero Ce2+") and err.contains("Lo correcto era"), "error de la partida: " + err)
	_ok(Cine.answer(carlsen, "f8e8").begins_with("Te8 mantiene las tablas."), "la buena cuando en la partida se falló")

	# Traducciones: los textos de los clips y las frases de las respuestas, con la notación de cada idioma.
	var keys: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cine.json"))
	for lang: String in ["en", "fr", "it", "ja", "pt", "id", "hi", "de", "ru"]:
		Loc.apply(lang)
		var missing := 0
		for c: Dictionary in clips:
			for t: Variant in [c["title"], c["subtitle"], (c["lesson"] as Dictionary)["intro"][1], (c["lesson"] as Dictionary)["takeaway"]]:
				if not Loc.has(str(t)):
					missing += 1
			for e: Dictionary in (c["lesson"] as Dictionary)["exercises"]:
				for t: Variant in ([e["text"]] if not e.has("parts") else e["parts"]):
					if not Loc.has(str(t)):
						missing += 1
		_ok(missing == 0, "%s: textos de los finales traducidos (faltan %d)" % [lang, missing])
		var w := Cine.answer(ding, "b2b1")
		_ok(not w.contains("deja escapar") and not w.contains("Así podría"), "%s: respuesta traducida: %s" % [lang, w])
	Loc.apply("en")
	_ok(Cine.answer(ding, "b2b1").begins_with("Rb1+"), "inglés: Tb1+ se escribe Rb1+")
	_ok(Loc.t("Ding acaba de jugar 55.Tf2. Juegan las negras: ¿qué jugarías?").contains("55.Rf2"), "inglés: la notación dentro del texto")
	Loc.apply("es")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
