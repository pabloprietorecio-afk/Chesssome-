extends SceneTree
## Entrenar → «Repasar mis fallos» (un usuario, 17-11: «¿dónde se repasan los fallos antiguos?»): todos los fallos sin
## resolver seguidos, del más antiguo al más reciente; cada uno una vez por sesión; al final, cuántos quedan.
## Uso: godot --headless --path godot -s tests/test_repaso_fallos.gd

var fallos := 0
var hechos := 0


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	var pool: Array = demo.pool
	var a: Dictionary = pool[10]
	var b: Dictionary = pool[20]
	var c: Dictionary = pool[30]
	var d: Dictionary = pool[40]
	var p := Assessment.start_test("casual")
	p["done"] = true
	for step: Array in [[a, false], [b, false], [c, true], [a, false], [d, false], [d, true]]:
		p = Assessment.record_try(p, step[0], {"correct": step[1]}, "train")
	p["done"] = true
	demo.player = p
	demo.reviewed = {}
	_ok(demo._pending_fails() == [str(a["id"]), str(b["id"])], "pendientes: los fallados sin resolver, sin repetir, del más antiguo al más reciente")

	demo._open_train_hub()
	await _frames(3)
	var btn := _find_button(demo.progress, Loc.t("Repasar mis fallos"))
	_ok(btn != null, "«Repasar mis fallos» en Entrenar")
	_ok(_has_text(demo.progress, Loc.f("%d problemas sin resolver, del más antiguo al más reciente.", 2)), "con cuántos quedan")
	btn.emit_signal("pressed")
	await _frames(3)
	_ok(demo.mode == "train" and demo.review_session and demo.is_review, "empieza la sesión de repaso")
	_ok(str(demo.puzzle.get("id", "")) == str(a["id"]), "por el fallo más antiguo")
	demo._set_phase(demo.Phase.SHOWN)
	await _frames(3)
	_ok(demo.reviewed.has(str(a["id"])), "verlo resuelto lo da por repasado")
	_ok(_has_text(demo.card, Loc.f("Repaso %d de %d", [1, 2])), "la ficha dice «Repaso 1 de 2»")
	demo._next_training()
	await _frames(3)
	_ok(str(demo.puzzle.get("id", "")) == str(b["id"]) and demo.is_review, "después, el siguiente fallo")
	# Se lo salta sin resolver: se acaba la sesión y queda pendiente.
	demo._next_training()
	await _frames(3)
	_ok(not demo.review_session, "sin más fallos, se acaba la sesión")
	_ok(demo.confirm_node != null and _has_text(demo.confirm_node, Loc.f("Has pasado por todos. Te quedan %d sin resolver: saldrán la próxima vez.", 1)), "y dice cuántos quedan")
	var back := _find_button(demo.confirm_node, Loc.t("Volver a Entrenar"))
	_ok(back != null and _find_button(demo.confirm_node, Loc.t("Seguir entrenando")) != null, "con «Seguir entrenando» y «Volver a Entrenar»")
	back.emit_signal("pressed")
	await _frames(3)
	_ok(demo.progress_kind == "train_hub" and _has_text(demo.progress, Loc.t("1 problema sin resolver.")), "de vuelta en Entrenar, queda 1")
	# Otra sesión: el que se saltó vuelve.
	demo._start_review_session()
	await _frames(3)
	_ok(str(demo.puzzle.get("id", "")) == str(b["id"]), "en otra sesión vuelve el que se saltó")
	demo._set_phase(demo.Phase.SOLVED)
	demo._next_training()
	await _frames(3)
	_ok(demo.confirm_node != null and _has_text(demo.confirm_node, Loc.t("Has repasado todos tus fallos. Los que falles a partir de ahora aparecerán aquí.")), "sin fallos pendientes: todos repasados")
	_find_button(demo.confirm_node, Loc.t("Seguir entrenando")).emit_signal("pressed")
	await _frames(3)
	_ok(demo.mode == "train" and not demo.review_session and demo.confirm_node == null, "«Seguir entrenando»: el entrenamiento de siempre")
	# Sin fallos: lo dice y no empieza nada.
	demo._open_train_hub()
	await _frames(3)
	_ok(_has_text(demo.progress, Loc.t("No te queda ninguno: los que falles aparecerán aquí.")), "Entrenar dice que no queda ninguno")
	demo._start_review_session()
	await _frames(3)
	_ok(demo.confirm_node != null and _has_text(demo.confirm_node, Loc.t("No te quedan fallos")) and not demo.review_session, "y al tocarlo, un aviso")
	demo._close_confirm()
	# «Tu día» → «Ir» del repaso sigue yendo a uno solo, sin sesión.
	p = Assessment.record_try(demo.player, pool[50], {"correct": false}, "train")
	demo.player = p
	demo._go_review()
	await _frames(3)
	_ok(str(demo.puzzle.get("id", "")) == str(pool[50]["id"]) and not demo.review_session, "el «Ir» de Tu día va a un fallo suelto")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _find_button(n: Node, text: String) -> Button:
	if n == null:
		return null
	if n is Button and _first_label(n) == text:
		return n
	for ch in n.get_children():
		var found := _find_button(ch, text)
		if found != null:
			return found
	return null


func _first_label(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	for ch in n.get_children():
		var t := _first_label(ch)
		if t != "":
			return t
	return ""


func _has_text(n: Node, text: String) -> bool:
	if n == null:
		return false
	if n is Label and (n as Label).text.contains(text):
		return true
	for ch in n.get_children():
		if _has_text(ch, text):
			return true
	return false


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
