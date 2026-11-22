extends SceneTree
## La voz del tutor (core/tutor_speech.gd, docs/voz-tutor.md) y las respuestas largas del asistente en la ventana
## (no en el aviso breve, que se salía de la pantalla). Sin red: el servidor de la voz se simula.
## Uso: godot --headless --path godot -s tests/test_voz_tutor.gd

var fallos := 0
var hechos := 0
var pedidos: Array = []


## Servidor simulado: un «MP3» de mentira (la app no llega a reproducirlo: mute_output) y lo que se le ha pedido.
func _fake(text: String, language: String) -> Dictionary:
	pedidos.append([text, language])
	if language == "de":
		return {"_error": 404, "texto": "Hallo, " + text}
	return {"audio": Marshalls.raw_to_base64("ID3-falso-".to_utf8_buffer())}


func _initialize() -> void:
	# Trozos: frases enteras, unas pocas por trozo.
	var parts := TutorSpeech.split("Primera frase. Segunda frase, algo más larga. ¿Tercera? ¡Cuarta!", 40)
	_ok(parts == ["Primera frase. Segunda frase, algo más larga.", "¿Tercera? ¡Cuarta!"] or parts.size() >= 2, "trozos por frases: %s" % str(parts))
	_ok(TutorSpeech.split("Una sola frase muy larga sin punto que pasa del límite de largo", 20).size() == 1, "una frase larga no se corta")
	_ok(TutorSpeech.split("Sin punto final", 300) == ["Sin punto final"], "sin punto final")
	var firsts := TutorSpeech.split("Uno dos tres. Cuatro cinco seis. Siete ocho nueve. Diez once doce.", 60, 20)
	_ok(firsts.size() == 2 and firsts[0] == "Uno dos tres.", "el primer trozo, más corto: %s" % str(firsts))
	_ok(CoachAI.speech_url({"tutor": "https://x.test/tutor"}) == "https://x.test/voz/decir" and CoachAI.speech_url({}) == "", "dirección de la voz")

	# La voz sola: pide los trozos en orden, guarda lo dicho y no lo vuelve a pedir.
	_clear_cache()
	var sp := TutorSpeech.new()
	sp.mute_output = true
	sp.fake_server = _fake
	root.add_child(sp)
	await _frames(1)
	var long_text := "La mejor era Cf3. Desarrolla el caballo y defiende e5. Además prepara el enroque corto. Fíjate en el alfil de c4: apunta a f7. Si el rival se descuida, Cg5 ataca ese peón dos veces."
	sp.say(long_text, "es")
	_ok(sp.speaking, "empieza a hablar")
	await _until(func() -> bool: return not sp.speaking)
	var n := pedidos.size()
	_ok(n >= 2 and str(pedidos[0][0]).begins_with("La mejor era Cf3.") and pedidos.all(func(p: Array) -> bool: return p[1] == "es"), "pide el texto en trozos, en orden: %s" % str(pedidos))
	_ok(not sp.speaking, "y acaba")
	sp.say(long_text, "es")
	await _until(func() -> bool: return not sp.speaking)
	_ok(pedidos.size() == n, "repetirlo no vuelve a pedirse (se guarda en el móvil)")
	# Idioma sin voz de Kokoro: la del sistema, con el texto que prepara el servidor.
	sp.say("Gut gespielt.", "de")
	await _until(func() -> bool: return not sp.speaking)
	_ok(sp.system_said.has("Hallo, Gut gespielt."), "sin voz de Kokoro: la del sistema, con el texto del servidor: %s" % str(sp.system_said))
	# Apagada: no dice nada.
	sp.enabled = false
	var before := pedidos.size()
	sp.say("Otra cosa distinta.", "es")
	_ok(not sp.speaking and pedidos.size() == before, "con la voz quitada, calla")
	sp.enabled = true
	# Parar a mitad.
	sp.say("Frase uno nueva. Frase dos nueva. Frase tres nueva.", "es")
	sp.stop()
	_ok(not sp.speaking, "parar")
	sp.queue_free()

	# En la app.
	Premium._loaded = true
	Premium.test_on = true
	Premium.coach_on = true
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo.tutor_speech.fake_server = _fake
	demo.tutor_speech.mute_output = true
	demo.coach.cfg = {"endpoint": "", "tutor": "http://127.0.0.1:9/tutor", "tutor_timeout_s": 2}
	demo.coach.hold_questions = true

	# Respuesta del tutor: se dice al llegar y tiene «Escuchar».
	pedidos.clear()
	demo.ask_mode = "tutor"
	demo.ask_state = "wait"
	demo.ask_text = "¿Por qué es mala mi jugada?"
	demo._ask_gen += 1
	demo._build_ask_window()
	await _frames(2)
	demo._on_tutor_answer(demo.run_id, demo._ask_gen, {"answer": "Porque dejas el peón de e5 sin defensa. Era mejor Cf3."})
	await _frames(2)
	_ok(demo.ask_state == "answer" and not pedidos.is_empty() and str(pedidos[0][0]).begins_with("Porque dejas"), "la respuesta del tutor se lee en voz alta: %s" % str(pedidos))
	_ok(_button_with(demo.confirm_node, "Escuchar") != null or _button_with(demo.confirm_node, "Parar la voz") != null, "con su botón «Escuchar»")
	demo._close_confirm()
	await _frames(2)
	_ok(not demo.tutor_speech.speaking, "al cerrar la ventana, calla")

	# Opción apagada: no se lee ni sale el botón.
	demo._set_tutor_speech(false)
	pedidos.clear()
	demo.ask_state = "wait"
	demo._ask_gen += 1
	demo._build_ask_window()
	demo._on_tutor_answer(demo.run_id, demo._ask_gen, {"answer": "Otra respuesta del tutor."})
	await _frames(2)
	_ok(pedidos.is_empty() and _button_with(demo.confirm_node, "Escuchar") == null, "con «Voz del tutor» quitada, ni voz ni botón")
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
	pedidos.clear()
	demo._on_assistant_reply(demo._ask_gen, {"say": long_say, "actions": [{"name": "cambiar_tema", "input": {"tema": "claro"}}]})
	await _frames(4)
	_ok(demo.ask_state == "answer" and demo.confirm_node != null and _has_text(demo.confirm_node, "Mi nivel y mi plan"), "respuesta larga del asistente: en la ventana semitransparente")
	_ok(not pedidos.is_empty(), "y se lee en voz alta")
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

	_clear_cache()
	print("voz del tutor: %d de %d bien" % [hechos - fallos, hechos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _clear_cache() -> void:
	if DirAccess.dir_exists_absolute(TutorSpeech.CACHE_DIR):
		for f in DirAccess.get_files_at(TutorSpeech.CACHE_DIR):
			DirAccess.remove_absolute(TutorSpeech.CACHE_DIR.path_join(f))


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
