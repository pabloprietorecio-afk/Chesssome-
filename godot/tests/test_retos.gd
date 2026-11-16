extends SceneTree
## Los retos se actualizan al jugar de verdad (la app entera, no solo core/progress.gd). En el móvil no avanzaban:
##  - «Repasa un fallo antiguo»: el repaso es un problema ya intentado y solo se anotaba el primer intento.
##  - Reto de la semana: solo contaba un problema nuevo acertado a la primera; los resueltos tras un fallo o ya
##    vistos (los que quedan cuando se han visto casi todos los de la categoría) no contaban.
## Uso: godot --headless --path godot -s tests/test_retos.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	# Un jugador con un fallo antiguo (problema A) y otro problema (B) ya visto y acertado, los dos de la misma
	# categoría, que es la de la semana.
	var a: Dictionary = demo.pool[3]
	var fam := str(a["family"])
	var b := {}
	for p: Dictionary in demo.pool:
		if str(p["family"]) == fam and str(p["id"]) != str(a["id"]):
			b = p
			break
	var pl: Dictionary = Assessment.start_test("never")
	pl = Assessment.record_try(pl, a, {"correct": false, "failStep": 0, "error": "otra"}, "train")
	pl = Assessment.record_try(pl, b, {"correct": true}, "train")
	pl["done"] = true
	demo.player = pl
	var s: Dictionary = demo._prog()
	var day: int = demo._prog_day()
	Progress.ensure_today(s, day, demo._prog_ctx())
	s["reto"]["metas"] = [{"tipo": "problemas", "meta": 3, "hecho": false}, {"tipo": "repaso", "meta": 1, "hecho": false}]
	s["semana"]["familia"] = fam
	s["semana"]["hecho"] = 0
	s["semana"]["completo"] = false
	s["semana"]["ids"] = []

	# 1. «Ir» del repaso y resolverlo.
	demo._go_review()
	_ok(demo.is_review and str(demo.puzzle["id"]) == str(a["id"]), "«Ir» abre el fallo antiguo como repaso")
	_ok(await _solve(demo), "el repaso se resuelve")
	var g: Array = Progress.goals(s, day)
	_ok(bool(g[1]["hecho"]) and int(g[1]["actual"]) == 1, "«Repasa un fallo antiguo» queda hecho")
	_ok(int(s["semana"]["hecho"]) == 1, "y el repaso, de la categoría de la semana, cuenta para ella (%d)" % int(s["semana"]["hecho"]))
	_ok(int(g[0]["actual"]) == 0, "un repaso no cuenta como problema nuevo")

	# 2. Un problema ya visto de la categoría (desde la lista de su nivel), resuelto: cuenta.
	demo._start_level_puzzle(str(b["id"]), Assessment.level_of(float(b["rating"])))
	_ok(await _solve(demo), "el problema ya visto se resuelve")
	_ok(int(s["semana"]["hecho"]) == 2, "un problema ya visto cuenta para la semana (%d)" % int(s["semana"]["hecho"]))

	# 3. El mismo otra vez: no cuenta dos veces.
	demo._start_level_puzzle(str(b["id"]), Assessment.level_of(float(b["rating"])))
	await _solve(demo)
	_ok(int(s["semana"]["hecho"]) == 2, "repetir el mismo no cuenta otra vez")

	# 4. «Ir» del reto de la semana: un problema nuevo de la categoría, resuelto a la primera.
	demo._train_family(fam)
	var c_id := str(demo.puzzle.get("id", ""))
	var c_new := true
	for t: Dictionary in pl["tries"]:
		if str(t["id"]) == c_id:
			c_new = false
	_ok(str(demo.pool[demo.index]["family"]) == fam, "«Ir» de la semana da un problema de su categoría")
	_ok(await _solve(demo), "el problema nuevo se resuelve")
	_ok(int(s["semana"]["hecho"]) == 3, "un problema nuevo de la categoría cuenta (%d)" % int(s["semana"]["hecho"]))
	if c_new:
		_ok(int(Progress.goals(s, day)[0]["actual"]) == 1, "y cuenta para «Resuelve 3 problemas»")

	# 5. Con la solución a la vista no cuenta para la semana.
	var before := int(s["semana"]["hecho"])
	demo._train_family(fam)
	demo._begin()
	await _until(demo, func() -> bool: return demo.phase == demo.Phase.SOLVING and demo.view.interactive)
	demo._show_solution()
	await _until(demo, func() -> bool: return demo.phase == demo.Phase.SHOWN)
	_ok(int(s["semana"]["hecho"]) == before, "ver la solución no cuenta para la semana")

	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Juega la solución del problema en pantalla hasta resolverlo. Devuelve si se resolvió.
func _solve(demo: Control) -> bool:
	for i in 400:
		if demo.phase == demo.Phase.SOLVED:
			return true
		if demo.phase == demo.Phase.INTRO and demo.intro_waiting:
			demo._begin()
		if demo.phase == demo.Phase.SOLVING and demo.view.interactive:
			var moves: Array = demo.puzzle["moves"]
			if demo.step < moves.size():
				demo._on_move_played(str(moves[demo.step]))
		await create_timer(0.1).timeout
	return demo.phase == demo.Phase.SOLVED


func _until(demo: Control, cond: Callable) -> void:
	for i in 400:
		if cond.call():
			return
		await create_timer(0.1).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
