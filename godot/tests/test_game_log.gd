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
	# Cómo terminó y filtros
	_ok(GameLog.reason({"motivo": "Se te ha acabado el tiempo.", "resultado": -1}) == "tiempo", "por tiempo")
	_ok(GameLog.reason({"motivo": "Tu rival ha abandonado la partida: ¡has ganado!", "resultado": 1}) == "abandono", "abandono")
	_ok(GameLog.reason({"motivo": "Te has rendido.", "resultado": -1}) == "rendicion", "rendición")
	_ok(GameLog.reason({"motivo": "No queda material para dar mate: tablas.", "resultado": 0}) == "tablas", "tablas (no mate)")
	_ok(GameLog.reason({"motivo": "Jaque mate: gana el rival.", "resultado": -1}) == "mate", "mate")
	var flog := {"partidas": [{"resultado": -1, "motivo": "Se te ha acabado el tiempo."}, {"resultado": 1, "motivo": "¡Jaque mate! Has ganado."}, {"resultado": -1, "motivo": "Jaque mate: gana el rival."}], "rivales": {}}
	_ok(GameLog.filtered(flog, "perdidas", "") == [0, 2], "solo perdidas")
	_ok(GameLog.filtered(flog, "perdidas", "tiempo") == [0], "perdidas por tiempo")
	_ok(GameLog.filtered(flog, "", "mate") == [1, 2], "todas por mate")
	# Nivel de juego: solo cuentan los niveles con fuerza medida.
	var levels := [{"name": "A"}, {"name": "B", "elo": 1400.0, "rd": 40.0}]
	var glog := {"partidas": [], "rivales": {}}
	_ok(int(GameLog.game_rating(glog, levels)["n"]) == 0, "sin partidas, sin nivel de juego")
	for k in 6:
		GameLog.add(glog, {"fecha": 1000 + k, "tipo": "ordenador", "rival_id": "bot:1", "rival_nombre": "B", "color": 0, "resultado": 1, "motivo": "", "inicio": "", "jugadas": ["e2e4"]}, {})
	GameLog.add(glog, {"fecha": 2000, "tipo": "ordenador", "rival_id": "bot:0", "rival_nombre": "A", "color": 0, "resultado": -1, "motivo": "", "inicio": "", "jugadas": ["e2e4"]}, {})
	var gr := GameLog.game_rating(glog, levels)
	_ok(int(gr["n"]) == 6 and bool(gr["provisional"]), "cuentan 6 partidas (el nivel sin medir no)")
	_ok(float(gr["r"]) > 1500.0, "ganar siempre a un 1400 sube el nivel de juego")
	GameLog.add(glog, {"fecha": 3000, "tipo": "online", "rival_id": "u9", "rival_nombre": "Eva", "color": 1, "resultado": 0, "motivo": "", "inicio": "", "jugadas": ["e2e4"], "rival_juego": {"r": 1700, "rd": 90, "n": 12}}, {})
	GameLog.add(glog, {"fecha": 3100, "tipo": "online", "rival_id": "u8", "rival_nombre": "Leo", "color": 1, "resultado": 1, "motivo": "", "inicio": "", "jugadas": ["e2e4"]}, {})
	_ok(int(GameLog.game_rating(glog, levels)["n"]) == 7, "online cuenta si el rival enseñó su nivel de juego")
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
