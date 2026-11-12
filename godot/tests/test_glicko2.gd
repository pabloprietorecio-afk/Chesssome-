extends SceneTree
## Prueba de oro de Glicko-2: el port en GDScript (core/glicko2.gd) debe dar lo mismo que el núcleo
## TypeScript. Los datos salen de scripts/export-golden.ts (npm run golden).
## Uso: godot --headless --path godot -s tests/test_glicko2.gd

const RUTA := "res://tests/golden/glicko2.json"

var fallos := 0
var hechos := 0


func _init() -> void:
	var txt := FileAccess.get_file_as_string(RUTA)
	if txt.is_empty():
		print("FALLA no se puede leer %s" % RUTA)
		quit(1)
		return
	var datos: Variant = JSON.parse_string(txt)
	if typeof(datos) != TYPE_DICTIONARY:
		print("FALLA %s no es un objeto JSON" % RUTA)
		quit(1)
		return

	for c: Dictionary in datos["update"]:
		var got := Glicko2.update(c["player"], c["results"], float(c["tau"]))
		var want: Dictionary = c["out"]
		_comprueba("update r", got["r"], want["r"], 1e-6)
		_comprueba("update rd", got["rd"], want["rd"], 1e-6)
		_comprueba("update vol", got["vol"], want["vol"], 1e-9)

	for c: Dictionary in datos["expectedScore"]:
		var opp: Dictionary = c["opp"]
		var got_e := Glicko2.expected_score(float(c["playerR"]), float(opp["r"]), float(opp["rd"]))
		_comprueba("expected_score", got_e, c["out"], 1e-12)

	for c: Dictionary in datos["ratingForSuccess"]:
		_comprueba("rating_for_success", Glicko2.rating_for_success(float(c["r"]), float(c["p"])), c["out"], 1e-9)

	print("Glicko-2: %d comprobaciones, %d fallos" % [hechos, fallos])
	print("TODO OK" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	quit(0 if fallos == 0 else 1)


func _comprueba(que: String, got: Variant, want: Variant, tol: float) -> void:
	hechos += 1
	var g := float(got)
	var w := float(want)
	if absf(g - w) > tol * maxf(1.0, absf(w)):
		fallos += 1
		if fallos <= 20:
			print("FALLA %s: Godot %.12f · TypeScript %.12f" % [que, g, w])
