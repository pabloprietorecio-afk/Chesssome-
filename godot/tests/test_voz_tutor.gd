extends SceneTree
## La voz del tutor (core/tutor_speech.gd, docs/voz-tutor.md): el lector de texto del móvil, con las jugadas en
## palabras; y las respuestas largas del asistente en la ventana (no en el aviso breve, que se salía de la pantalla).
## En la CI no hay lector: se comprueba lo que se le mandaría (system_said).
## Uso: godot --headless --path godot -s tests/test_voz_tutor.gd

var fallos := 0
var hechos := 0


func _said(demo: Control) -> Array:
	return demo.tutor_speech.system_said


func _initialize() -> void:
	# Las jugadas, en palabras (el lector las deletrearía).
	var cases := [
		["es", "Con 12.Cge2 dejas e5. Dxh6+ y Cf7#.", "Con caballo a e dos dejas e cinco. dama toma en hache seis, jaque y caballo a efe siete, jaque mate."],
		["es", "**Ojo** 😉: exd5 y O-O-O", "Ojo: peón de e toma en de cinco y enroque largo"],
		["es", "e8=D+", "e ocho y corona dama, jaque"],
		["es", "¿Ves a3? Txe8+!! gana.", "¿Ves a tres? torre toma en e ocho, jaque! gana."],
		["en", "Qxh6+ then O-O", "queen takes on H six, check then castles kingside"],
		["en", "Ac4?", "Ac4?"],
		["de", "Sf3 und Dxh6#", "Springer nach eff drei und Dame schlägt auf ha sechs, Schachmatt"],
		["ru", "Крg8 и Фxh6", "король на жэ восемь и ферзь берёт на аш шесть"],
		["ja", "Nf3 のあと Qxh6+", "ナイト f3 のあと クイーン h6 で取る、チェック"],
	]
	for c: Array in cases:
		var got := TutorSpeech.speakable(str(c[1]), str(c[0]))
		_ok(got == str(c[2]), "%s: «%s» → «%s» (esperaba «%s»)" % [c[0], c[1], got, c[2]])

	# La voz: la de España si la hay, y mejor sin conexión.
	var voices := [
		{"id": "es-us-x-esd-network", "language": "es_US"},
		{"id": "es-es-x-eea-network", "language": "es_ES"},
		{"id": "es-es-x-eed-local", "language": "es_ES"},
		{"id": "en-gb-x-rjs-local", "language": "en_GB"},
	]
	_ok(TutorSpeech.pick_voice(voices, "es") == "es-es-x-eed-local", "español: la de España y sin conexión")
	_ok(TutorSpeech.pick_voice(voices.slice(0, 1), "es") == "es-us-x-esd-network", "sin la de España, otra en español")
	_ok(TutorSpeech.pick_voice(voices, "fr") == "", "sin voces del idioma: la de Android por defecto")

	var sp := TutorSpeech.new()
	sp.mute_output = true
	root.add_child(sp)
	await _frames(1)
	sp.say("La mejor era Cf3.", "es")
	_ok(sp.system_said == ["La mejor era caballo a efe tres."], "al lector va el texto preparado: %s" % str(sp.system_said))
	sp.enabled = false
	sp.say("Otra cosa.", "es")
	_ok(sp.system_said.size() == 1 and not sp.speaking, "con la voz quitada, calla")
	sp.queue_free()

	# En la app.
	Premium._loaded = true
	Premium.test_on = true
	Premium.coach_on = true
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo.tutor_speech.mute_output = true
	demo.coach.cfg = {"endpoint": "", "tutor": "http://127.0.0.1:9/tutor", "tutor_timeout_s": 2}
	demo.coach.hold_questions = true

	# Respuesta del tutor: se dice al llegar y tiene «Escuchar».
	_said(demo).clear()
	demo.ask_mode = "tutor"
	demo.ask_state = "wait"
	demo.ask_text = "¿Por qué es mala mi jugada?"
	demo._ask_gen += 1
	demo._build_ask_window()
	await _frames(2)
	demo._on_tutor_answer(demo.run_id, demo._ask_gen, {"answer": "Porque dejas el peón de e5 sin defensa. Era mejor Cf3."})
	await _frames(2)
	_ok(demo.ask_state == "answer" and _said(demo) == ["Porque dejas el peón de e cinco sin defensa. Era mejor caballo a efe tres."], "la respuesta del tutor se lee en voz alta: %s" % str(_said(demo)))
	_ok(_button_with(demo.confirm_node, "Escuchar") != null or _button_with(demo.confirm_node, "Parar la voz") != null, "con su botón «Escuchar»")
	demo._close_confirm()
	await _frames(2)
	_ok(not demo.tutor_speech.speaking, "al cerrar la ventana, calla")

	# Opción apagada: no se lee ni sale el botón.
	demo._set_tutor_speech(false)
	_said(demo).clear()
	demo.ask_state = "wait"
	demo._ask_gen += 1
	demo._build_ask_window()
	demo._on_tutor_answer(demo.run_id, demo._ask_gen, {"answer": "Otra respuesta del tutor."})
	await _frames(2)
	_ok(_said(demo).is_empty() and _button_with(demo.confirm_node, "Escuchar") == null, "con «Voz del tutor» quitada, ni voz ni botón")
	demo._close_confirm()
	demo._set_tutor_speech(true)
	await _frames(2)

	# Asistente: una respuesta larga ya no va en el aviso breve (se salía de la pantalla): va en la ventana.
	_ok(demo.fits_toast("Hecho.") and not demo.fits_toast("Te abro «Mi nivel y mi plan», donde ves en qué temas fallas exactamente y qué te toca practicar, lo mejor para mejorar.") and not demo.fits_toast("Uno.\nDos."), "qué cabe en el aviso breve")
	demo._open_assistant()
	await _frames(2)
	demo.ask_text = "¿qué tengo que practicar?"
	demo._send_question()
	var long_say := "Te abro «Mi nivel y mi plan», donde ves en qué temas fallas exactamente y qué te toca practicar, lo mejor para mejorar."
	_said(demo).clear()
	demo._on_assistant_reply(demo._ask_gen, {"say": long_say, "actions": [{"name": "cambiar_tema", "input": {"tema": "claro"}}]})
	await _frames(4)
	_ok(demo.ask_state == "answer" and demo.confirm_node != null and _has_text(demo.confirm_node, "Mi nivel y mi plan"), "respuesta larga del asistente: en la ventana semitransparente")
	_ok(not _said(demo).is_empty() and str(_said(demo)[0]).begins_with("Te abro"), "y se lee en voz alta")
	demo._close_confirm()
	await _frames(2)
	demo._open_assistant()
	demo.ask_text = "tema claro"
	demo._send_question()
	demo._on_assistant_reply(demo._ask_gen, {"say": "Hecho.", "actions": [{"name": "cambiar_tema", "input": {"tema": "claro"}}]})
	await _frames(4)
	_ok(demo.ask_state == "" and demo.confirm_node == null, "respuesta corta: aviso breve y la ventana se cierra")

	# El aviso breve nunca se sale de la pantalla.
	demo._prog_toast(long_say, "", false)
	await _frames(3)
	var pill := demo._prog_toast_node.get_child(0) as Control
	_ok(pill.position.x >= 0.0 and pill.position.x + pill.size.x <= demo.size.x + 1.0, "aviso con texto largo: dentro de la pantalla (%.0f–%.0f de %.0f)" % [pill.position.x, pill.position.x + pill.size.x, demo.size.x])

	print("voz del tutor: %d de %d bien" % [hechos - fallos, hechos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _until(cond: Callable) -> void:
	for i in 600:
		if cond.call():
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _button_with(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and ((node as Button).text.contains(Loc.t(text)) or _has_text(node, text)):
		return node
	for c in node.get_children():
		var b := _button_with(c, text)
		if b != null:
			return b
	return null


func _has_text(node: Node, text: String) -> bool:
	if node == null:
		return false
	var want := Loc.t(text)
	if (node is Label and (node as Label).text.contains(want)) or (node is Button and (node as Button).text.contains(want)):
		return true
	for c in node.get_children():
		if _has_text(c, text):
			return true
	return false


func _ok(cond: bool, what: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + what)
