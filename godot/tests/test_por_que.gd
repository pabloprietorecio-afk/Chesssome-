extends SceneTree
## «¿Por qué ha jugado eso el rival?» mientras se resuelve un problema: explica la jugada sin dar la solución (antes
## decía «Pero es un error: permite Cxh6+ y, tras Dxh6, Dxh6»). Resuelto, el «paso a paso» lo cuenta todo, con las
## otras jugadas del rival (docs/defensas.md).
## Uso: godot --headless --path godot -s tests/test_por_que.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(6)
	demo.player = Assessment.start_test("casual")
	demo.player["done"] = true
	demo.mode = "train"
	demo._close_progress()
	demo._start(int(demo._index_of["dekIo"]))
	await create_timer(0.5).timeout
	demo._begin()
	await _until(func() -> bool: return demo.phase == demo.Phase.SOLVING and demo.ask_step == 1)
	_ok(demo.phase == demo.Phase.SOLVING and demo.ask_step == 1, "el rival ha jugado f5 y toca resolver")
	demo._toggle_move_why()
	var t := _text(demo.why_paras)
	_ok(t.contains("Pero es un error. ¿Ves por qué?"), "el rival se ha equivocado, y se dice")
	_ok(not t.contains("Cxh6") and not t.contains("permite"), "pero no se da la solución: %s" % t)
	demo._toggle_move_why()
	# La primera jugada de la solución; el rival contesta Dxh6.
	demo.view.show_move("g4h6")
	demo._on_move_played("g4h6")
	await _until(func() -> bool: return demo.phase == demo.Phase.SOLVING and demo.ask_step == 3)
	_ok(demo.phase == demo.Phase.SOLVING and demo.ask_step == 3, "tras Cxh6+ Dxh6 toca la segunda jugada")
	demo._toggle_move_why()
	t = _text(demo.why_paras)
	_ok(t.contains("Si Rh7, Cxf5+ es jaque descubierto") and t.contains("Rh8 aguantaba más o menos igual."), "por qué Dxh6: qué pasaba con las otras salidas")
	_ok(not t.contains("a cambio de la dama") and not t.contains("seguiría") and not t.contains("es la que más resiste"), "sin dar la jugada que falta ni la frase genérica: %s" % t)
	demo._toggle_move_why()
	demo.view.show_move("h5h6")
	demo._on_move_played("h5h6")
	await _until(func() -> bool: return demo.phase == demo.Phase.SOLVED)
	_ok(demo.phase == demo.Phase.SOLVED, "resuelto")
	var story := _text(demo._story_paras())
	_ok(story.contains("Con Dxh6, al menos se lleva tu caballo a cambio de la dama.") and story.contains("Rh8 aguantaba más o menos igual: seguiría Cxf5+."), "resuelto: el paso a paso lo cuenta todo")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _text(paras: Array) -> String:
	var out := ""
	for p: Dictionary in paras:
		out += str(p["text"]) + " "
	return out


func _until(cond: Callable, seconds: float = 12.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await create_timer(0.1).timeout


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
