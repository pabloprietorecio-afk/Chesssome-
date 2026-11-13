extends SceneTree
## Prueba de oro de las reglas: core/chess.gd debe coincidir con chess.js en las jugadas legales de cada
## posición de los problemas reales, en la posición tras cada jugada, en jaque/mate/ahogado y en los
## recuentos «perft» de posiciones de prueba. Datos: scripts/export-golden-chess.ts (npm run golden).
## Uso: godot --headless --path godot -s tests/test_chess.gd

const RUTA := "res://tests/golden/chess.json"

var fallos := 0
var hechos := 0


func _init() -> void:
	var txt := FileAccess.get_file_as_string(RUTA)
	var datos: Variant = JSON.parse_string(txt)
	if typeof(datos) != TYPE_DICTIONARY:
		print("FALLA no se puede leer %s" % RUTA)
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	for row: Dictionary in datos["positions"]:
		var c := Chess.from_fen(row["fen"])
		var legal := PackedStringArray()
		for lm in c.legal_moves():
			legal.append(Chess.uci(lm))
		legal.sort()
		_igual("jugadas legales de " + str(row["fen"]), " ".join(legal), row["legal"])
		var m := c.find_uci(row["move"])
		if m < 0:
			_falla("la jugada %s no sale como legal en %s" % [row["move"], row["fen"]])
			continue
		var d := c.after(m)
		_igual("posición tras %s en %s" % [row["move"], row["fen"]], d.fen_core(), row["after"])
		_igual("jaque tras %s en %s" % [row["move"], row["fen"]], d.in_check(), row["check"])
		_igual("mate tras %s en %s" % [row["move"], row["fen"]], d.is_checkmate(), row["mate"])
		_igual("ahogado tras %s en %s" % [row["move"], row["fen"]], d.is_stalemate(), row["stalemate"])
	print("Posiciones: %d comprobaciones en %.1f s" % [hechos, (Time.get_ticks_msec() - t0) / 1000.0])
	t0 = Time.get_ticks_msec()
	for row: Dictionary in datos["perft"]:
		var c := Chess.from_fen(row["fen"])
		_igual("perft 1 de " + str(row["fen"]), c.perft(1), int(row["d1"]))
		_igual("perft 2 de " + str(row["fen"]), c.perft(2), int(row["d2"]))
		if int(row["d3"]) > 0:
			_igual("perft 3 de " + str(row["fen"]), c.perft(3), int(row["d3"]))
	print("Perft en %.1f s" % [(Time.get_ticks_msec() - t0) / 1000.0])
	print("Reglas: %d comprobaciones, %d fallos" % [hechos, fallos])
	print("TODO OK" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	quit(0 if fallos == 0 else 1)


func _igual(que: String, got: Variant, want: Variant) -> void:
	hechos += 1
	if got != want:
		_falla("%s: Godot «%s» · chess.js «%s»" % [que, str(got), str(want)])


func _falla(msg: String) -> void:
	fallos += 1
	if fallos <= 15:
		print("FALLA " + msg)
