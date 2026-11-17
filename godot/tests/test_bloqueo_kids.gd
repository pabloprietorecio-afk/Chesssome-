extends SceneTree
## Bloqueo para salir del modo Kids: crear el código de 4 piezas (dos veces), salir con él, fallos y espera.
## Uso: godot --headless --path godot -s tests/test_bloqueo_kids.gd

var fails := 0
var demo: Control
var called := 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("ok   ", msg)
	else:
		fails += 1
		print("FALLA ", msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(t: float) -> void:
	await create_timer(t).timeout


func _lock() -> PieceLock:
	if demo.progress == null or not is_instance_valid(demo.progress):
		return null
	var found: Array = demo.progress.find_children("*", "SubViewportContainer", true, false)
	return found[0] as PieceLock if not found.is_empty() else null


func _type(code: String) -> void:
	var l := _lock()
	for ch in code:
		l.add_piece(ch)
		await _frames(3)
	await _secs(0.9)


func _then() -> void:
	called += 1


func _initialize() -> void:
	demo = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(20)

	demo._open_lock_create(_then, "")
	await _frames(4)
	_ok(_lock() != null, "la página de crear el código lleva el tablero 3D de piezas")
	_ok(_lock().ORDER.size() == 12, "con las 12 piezas (6 blancas y 6 negras)")
	_lock().add_piece("Q")
	_lock().add_piece("Q")
	await _frames(3)
	_lock().back()
	await _secs(0.3)
	_ok(_lock().code == "Q", "«Borrar» quita la última pieza")
	await _type("nRp")
	_ok(_lock() != null and _lock().code == "", "con 4 piezas pasa a «Repite el código»")
	await _type("QnRk")
	await _secs(1.6)
	_ok(demo.kids_lock == "" and called == 0, "si la repetición no coincide, no se guarda nada")
	await _type("QnRp")
	await _type("QnRp")
	_ok(demo.kids_lock == "piezas" and called == 1, "repetido igual: se guarda el código y se sigue")
	_ok(demo.kids_code_hash != "" and demo.kids_code_hash != "QnRp", "se guarda la huella, no el código")
	demo._close_confirm()

	called = 0
	demo._open_gate(_then)
	await _frames(4)
	_ok(_lock() != null, "salir de Kids pide el código de piezas")
	await _type("QnRp")
	_ok(called == 1 and demo.kids_fails == 0, "con el código bueno se sale")

	called = 0
	demo._open_gate(_then)
	await _frames(4)
	for k in 3:
		await _type("KKKK")
		await _secs(1.4)
	_ok(called == 0 and demo.kids_fails == 3, "tres fallos no abren")
	var left: float = demo.kids_wait_until - Time.get_unix_time_from_system()
	_ok(left > 50.0 and left <= 60.0, "tras el tercer fallo, 1 minuto de espera (%.0f s)" % left)
	_ok(not _lock().enabled, "mientras espera, el tablero no responde")
	demo.kids_wait_until = 0.0
	await _secs(1.4)
	_ok(_lock().enabled, "pasada la espera, vuelve a responder")
	await _type("KKKK")
	await _secs(1.4)
	left = demo.kids_wait_until - Time.get_unix_time_from_system()
	_ok(left > 110.0 and left <= 120.0, "otro fallo: la espera se dobla (%.0f s)" % left)
	demo.kids_wait_until = 0.0
	await _secs(1.4)
	await _type("QnRp")
	_ok(called == 1 and demo.kids_fails == 0, "con el código bueno se sale y se olvidan los fallos")

	demo._reset_kids_lock()
	_ok(demo.kids_lock == "" and demo.kids_code_hash == "", "«Cambiar el bloqueo de Kids» lo borra")
	print("TODO OK" if fails == 0 else "FALLOS: %d" % fails)
	quit(fails)
