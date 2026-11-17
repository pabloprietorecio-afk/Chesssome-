extends SceneTree
## «Problemas» tras el análisis de una partida (un usuario, 17-11: «He practicado el mate del pasillo no sé cuántas
## veces»): primero los que no ha visto, después los fallados sin resolver y los resueltos solo si no queda otra.
## Uso: godot --headless --path godot -s tests/test_practica.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	var themes := ["Mate en 1", "Mate del pasillo"]
	demo.player = {"rating": {"r": 1489.0, "rd": 160.0, "vol": 0.06}, "tries": []}
	var first: Array = demo._practice_for(themes)
	_ok(first.size() == 5, "cinco problemas")
	_ok(first.all(func(i: int) -> bool: return themes.has(str(demo.puzzles[i]["theme"]))), "todos de esos temas")
	# Los resuelve: la vez siguiente, otros cinco.
	for i: int in first:
		(demo.player["tries"] as Array).append({"id": str(demo.puzzles[i]["id"]), "correct": true})
	var second: Array = demo._practice_for(themes)
	_ok(second.size() == 5 and second.all(func(i: int) -> bool: return not first.has(i)), "tras resolverlos, otros cinco (no los mismos)")
	# Uno fallado y sin resolver va antes que los resueltos, pero después de los no vistos.
	var all_ids: Array = []
	for i in demo.puzzles.size():
		if themes.has(str(demo.puzzles[i]["theme"])):
			all_ids.append(i)
	demo.player["tries"] = []
	for i: int in all_ids:
		(demo.player["tries"] as Array).append({"id": str(demo.puzzles[i]["id"]), "correct": true})
	var failed: int = all_ids[3]
	demo.player["tries"][3] = {"id": str(demo.puzzles[failed]["id"]), "correct": false}
	var third: Array = demo._practice_for(themes)
	_ok(third.size() == 5 and int(third[0]) == failed, "si ya los ha visto todos, primero el que falló")
	# Sin ver ninguno: varía de una vez a otra (no siempre el mismo orden).
	demo.player["tries"] = []
	var orders := {}
	for k in 8:
		orders[str(demo._practice_for(themes))] = true
	_ok(orders.size() > 1, "no sale siempre en el mismo orden (%d órdenes)" % orders.size())
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
