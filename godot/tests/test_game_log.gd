extends SceneTree
## Historial de partidas y estadísticas (core/game_log.gd) y el filtro de nombres para jugar online.
## Uso: godot --headless --path godot -s tests/test_game_log.gd

var fallos := 0
var hechos := 0


func _init() -> void:
	var log := {"partidas": [], "rivales": {}}
	var t := 1794700000
	for def: Array in [["u1", "Ana", 1, 0], ["bot:2", "Ordenador · Medio", -1, 1], ["u1", "Ana", 1, 1], ["u2", "Luis", 0, 0], ["u1", "Ana", 1, 0]]:
		t += 60
		GameLog.add(log, {"fecha": t, "tipo": "ordenador" if str(def[0]).begins_with("bot:") else "online", "rival_id": def[0], "rival_nombre": def[1], "color": def[3], "resultado": def[2], "motivo": "", "inicio": "", "jugadas": ["e2e4"]}, {"nivel": 4, "icono": "piece_rook"} if def[0] == "u1" else {})
	var st := GameLog.stats(log)
	_ok(int(st["total"]) == 5 and int(st["ganadas"]) == 3 and int(st["tablas"]) == 1 and int(st["perdidas"]) == 1, "recuento")
	_ok(int(st["online"]) == 4 and int(st["ordenador"]) == 1, "online y ordenador")
	_ok(st["blancas"] == [2, 1, 0] and st["negras"] == [1, 0, 1], "por color")
	_ok(int(st["racha"]) == 1 and int(st["mejor_racha"]) == 1, "rachas")
	var ana: Dictionary = log["rivales"]["u1"]
	_ok(int(ana["partidas"]) == 3 and int(ana["ganadas"]) == 3 and int(ana["nivel"]) == 4, "rival que se repite")
	var order := GameLog.rivals_by_date(log)
	_ok(str(order[0][0]) == "u1", "rivales por fecha")
	_ok(str((log["partidas"][0] as Dictionary)["rival_nombre"]) == "Ana", "la última partida, primero")
	# Guardar y leer
	GameLog.save_log(log, "user://_test_log.json")
	var back := GameLog.load_log("user://_test_log.json")
	_ok((back["partidas"] as Array).size() == 5, "se guarda y se lee")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_test_log.json"))
	# Nombres
	_ok(GameLog.name_problem("Penélope") == "", "Penélope vale")
	_ok(GameLog.name_problem("Pablo_88") == "", "con números y guion bajo")
	_ok(GameLog.name_problem("p") != "", "muy corto")
	_ok(GameLog.name_problem("puta madre") != "", "palabra malsonante")
	_ok(GameLog.name_problem("<script>") != "", "caracteres raros")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
