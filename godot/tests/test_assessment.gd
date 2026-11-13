extends SceneTree
## Prueba de oro de la evaluación: el port en GDScript (core/assessment.gd) debe elegir los mismos problemas
## y llegar a las mismas cifras que el núcleo TypeScript (src/core/assessment.ts).
## Los datos salen de scripts/export-golden-assessment.ts (npm run golden): jugadores simulados que hacen el
## test y un rato de entrenamiento sobre la lista de problemas de la app. Aquí se repite cada paso.
## Uso: godot --headless --path godot -s tests/test_assessment.gd

const RUTA := "res://tests/golden/assessment.json"
const LISTA := "res://data/demo_puzzles.json"

var fallos := 0
var hechos := 0


func _init() -> void:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	var lista: Variant = JSON.parse_string(FileAccess.get_file_as_string(LISTA))
	if typeof(datos) != TYPE_DICTIONARY or typeof(lista) != TYPE_DICTIONARY:
		print("FALLA no se pueden leer %s y %s" % [RUTA, LISTA])
		quit(1)
		return
	var pool: Array = []
	for p: Dictionary in lista["puzzles"]:
		pool.append(Assessment.item_of(p))
	_igual("problemas de la lista", pool.size(), int(datos["poolSize"]))
	var rango := Assessment.measurable_range(pool)
	_cerca("rango mínimo", rango["min"], datos["range"]["min"], 1e-9)
	_cerca("rango máximo", rango["max"], datos["range"]["max"], 1e-9)

	for c: Dictionary in datos["levels"]:
		_igual("nivel de %d" % int(c["r"]), Assessment.level_of(float(c["r"])), int(c["level"]))
	var pruebas := 0
	var entrenos := 0
	for run: Dictionary in datos["runs"]:
		var state := Assessment.start_test(str(run["experience"]))
		for paso: Dictionary in run["test"]:
			var item := Assessment.next_test_item(state, pool, float(paso["rand"]))
			_igual("problema del test", str(item.get("id", "")), str(paso["pick"]))
			if item.is_empty():
				break
			state = Assessment.record_try(state, item, paso["outcome"], "test")
			var ultimo: Dictionary = (state["tries"] as Array).back()
			_cerca("acierto previsto", ultimo["expected"], paso["expected"], 1e-12)
			_rating("test", state["rating"], paso["rating"])
			_igual("test terminado", bool(state["done"]), bool(paso["done"]))
			pruebas += 1
		var pr := Assessment.profile(state["tries"])
		_perfil("tras el test", pr, run["afterTest"]["profile"])
		_plan("tras el test", Assessment.plan(state["rating"], pr), run["afterTest"]["plan"])

		for paso: Dictionary in run["train"]:
			var item := Assessment.pick_training_item(state["rating"], state["tries"], pool, float(paso["rand"]))
			_igual("problema del entrenamiento", str(item.get("id", "")), str(paso["pick"]))
			if item.is_empty():
				break
			_cerca("peso", Assessment.training_weight(item, Assessment.profile(state["tries"])), paso["weight"], 1e-9)
			state = Assessment.record_try(state, item, paso["outcome"], "train")
			_rating("entrenamiento", state["rating"], paso["rating"])
			entrenos += 1
		var fin: Dictionary = run["final"]
		pr = Assessment.profile(state["tries"])
		_perfil("final", pr, fin["profile"])
		_plan("final", Assessment.plan(state["rating"], pr), fin["plan"])
		_igual("estado de mates", Assessment.status(pr["mate"]), str(fin["status"]["mate"]))
		_igual("estado de cálculo", Assessment.status(pr["long"]), str(fin["status"]["long"]))
		var estados: Array = fin["status"]["families"]
		for i in estados.size():
			_igual("estado de familia", Assessment.status(pr["families"][i]), str(estados[i]))
		_igual("repaso", str(Assessment.pick_review_item(state["tries"], pool).get("id", "")), str(fin["review"]))

	print("Evaluación: %d jugadores simulados, %d problemas de test y %d de entrenamiento, %d comprobaciones, %d fallos" % [(datos["runs"] as Array).size(), pruebas, entrenos, hechos, fallos])
	print("TODO OK" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	quit(0 if fallos == 0 else 1)


func _rating(que: String, got: Dictionary, want: Dictionary) -> void:
	_cerca(que + " r", got["r"], want["r"], 1e-6)
	_cerca(que + " rd", got["rd"], want["rd"], 1e-6)
	_cerca(que + " vol", got["vol"], want["vol"], 1e-9)


func _stat(que: String, got: Dictionary, want: Dictionary) -> void:
	_igual(que + " n", int(got["n"]), int(want["n"]))
	_igual(que + " aciertos", int(got["correct"]), int(want["correct"]))
	_cerca(que + " previstos", got["expected"], want["expected"], 1e-9)
	_cerca(que + " residuo", got["residual"], want["residual"], 1e-9)


func _perfil(que: String, got: Dictionary, want: Dictionary) -> void:
	_stat(que + " total", got["total"], want["total"])
	_stat(que + " mate", got["mate"], want["mate"])
	_stat(que + " cálculo", got["long"], want["long"])
	var fams: Array = want["families"]
	_igual(que + " familias", (got["families"] as Array).size(), fams.size())
	for i in mini(fams.size(), (got["families"] as Array).size()):
		_igual(que + " familia", str(got["families"][i]["family"]), str(fams[i]["family"]))
		_stat(que + " familia " + str(fams[i]["family"]), got["families"][i], fams[i])
	for key: String in ["failFirst", "failLater", "fails", "replyBlind", "helped"]:
		_igual(que + " " + key, int(got[key]), int(want[key]))
	for kind: String in Assessment.ERROR_KINDS:
		_igual(que + " errores " + kind, int(got["errors"][kind]), int(want["errors"][kind]))
	_igual(que + " tiempos n", int(got["time"]["n"]), int(want["time"]["n"]))
	_igual(que + " precipitados", int(got["time"]["rushed"]), int(want["time"]["rushed"]))
	for key: String in ["median", "medianCorrect", "medianWrong"]:
		_cerca(que + " tiempo " + key, got["time"][key], want["time"][key], 1e-9)


func _plan(que: String, got: Dictionary, want: Dictionary) -> void:
	_cerca(que + " dificultad", got["target"], want["target"], 1e-6)
	var focos: Array = want["focus"]
	_igual(que + " focos", (got["focus"] as Array).size(), focos.size())
	for i in mini(focos.size(), (got["focus"] as Array).size()):
		_igual(que + " foco", str(got["focus"][i]["kind"]) + ":" + str(got["focus"][i].get("family", "")), str(focos[i]["kind"]) + ":" + str(focos[i].get("family", "")))
	_igual(que + " hábitos", ",".join(PackedStringArray(got["habits"])), ",".join(PackedStringArray(want["habits"])))


func _igual(que: String, got: Variant, want: Variant) -> void:
	hechos += 1
	if got != want:
		fallos += 1
		if fallos <= 20:
			print("FALLA %s: Godot %s · TypeScript %s" % [que, str(got), str(want)])


func _cerca(que: String, got: Variant, want: Variant, tol: float) -> void:
	hechos += 1
	var g := float(got)
	var w := float(want)
	if absf(g - w) > tol * maxf(1.0, absf(w)):
		fallos += 1
		if fallos <= 20:
			print("FALLA %s: Godot %.12f · TypeScript %.12f" % [que, g, w])
