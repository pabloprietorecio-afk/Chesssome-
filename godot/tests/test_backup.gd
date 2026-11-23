extends SceneTree
## Copia de seguridad (core/backup.gd): empaquetar, validar, importar. Qué NO entra (token online, clave de la API),
## archivos manipulados, versión más nueva, y que un fallo no deja medio importado.
## Uso: godot --headless --path godot -s tests/test_backup.gd

var fallos := 0
const A := "user://_bk_a"
const B := "user://_bk_b"


func _initialize() -> void:
	_clean(A)
	_clean(B)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(A))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(B))

	# Dispositivo A: progreso, jugador, partidas; y archivos que NO deben viajar.
	_write(A, "chessome_progreso.json", {"version": 1, "dias": {"20400": {"p": 3}, "20401": {"p": 1}}, "aviso": {"activo": true, "hora": 21, "min": 0, "elegida": true}})
	_write(A, "chessome_jugador.json", {"version": 1, "rating": {"r": 1500.0, "rd": 100.0, "vol": 0.06}, "tries": [{"id": "a"}, {"id": "b"}, {"id": "c"}]})
	_write(A, "chessome_partidas.json", {"partidas": [{"x": 1}, {"x": 2}], "rivales": {}})
	_write_raw(A, "chessome_online.cfg", "[sesion]\nrefresco=\"SECRETO_TOKEN\"\n")
	_write_raw(A, "premium.cfg", "[x]\nclave=\"SECRETO_API\"\n")
	_write_raw(A, "chessome.cfg", "[vista]\ngiro_fijado=true\n")
	var png := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])
	var pf := FileAccess.open(A.path_join("chessome_avatar.png"), FileAccess.WRITE)
	pf.store_buffer(png)
	pf.close()

	var text := Backup.build(A, 1763935200)
	_check(not text.contains("SECRETO_TOKEN") and not text.contains("SECRETO_API"), "la copia no lleva el token online ni la clave de la API")
	_check(not text.contains("giro_fijado"), "la copia no lleva los ajustes del dispositivo")
	var v := Backup.validate(text)
	_check(bool(v["ok"]), "una copia propia es válida")
	var s: Dictionary = v["resumen"]
	_check(int(s["partidas"]) == 2 and int(s["problemas"]) == 3 and int(s["dias"]) == 2, "resumen: 2 partidas, 3 problemas, 2 días (%s)" % str(s))
	_check((v["datos"]["avatar"] as PackedByteArray) == png, "el avatar viaja intacto")

	# Dispositivo B: ya tenía otra cosa; se sustituye y lo anterior queda en copia_previa.json.
	_write(B, "chessome_progreso.json", {"version": 1, "dias": {"1": {"p": 9}}})
	_write(B, "campeonato.json", {"torneos": {}})
	_write_raw(B, "chessome_online.cfg", "[sesion]\nrefresco=\"TOKEN_DE_B\"\n")
	_check(Backup.restore(v["datos"], B), "se importa")
	var prog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(B.path_join("chessome_progreso.json")))
	_check((prog["dias"] as Dictionary).has("20400") and not (prog["dias"] as Dictionary).has("1"), "el progreso de B se sustituye por el de A")
	_check(not bool(prog["aviso"]["activo"]), "el aviso diario queda apagado (la alarma es de cada dispositivo)")
	_check(int(prog["aviso"]["hora"]) == 21, "…pero conserva la hora elegida")
	_check(not FileAccess.file_exists(B.path_join("campeonato.json")), "lo que la copia no trae se borra (se sustituye todo)")
	_check(FileAccess.get_file_as_string(B.path_join("chessome_online.cfg")).contains("TOKEN_DE_B"), "la sesión online de B no se toca")
	_check(FileAccess.file_exists(B.path_join("chessome_avatar.png")), "el avatar llega")
	var prev := Backup.validate(FileAccess.get_file_as_string(B.path_join(Backup.PREVIOUS)))
	_check(bool(prev["ok"]) and (prev["datos"]["archivos"] as Dictionary).has("campeonato.json"), "lo anterior de B queda en copia_previa.json y se puede volver a importar")
	_check(not FileAccess.file_exists(B.path_join("chessome_progreso.json.imp")), "no quedan archivos temporales")

	# Rechazos.
	_check(Backup.validate("")["error"] == "vacio", "vacío")
	_check(Backup.validate("hola")["error"] == "formato", "no es JSON")
	_check(Backup.validate("{\"app\":\"otra\",\"version\":1,\"archivos\":{}}")["error"] == "formato", "de otra app")
	_check(Backup.validate(JSON.stringify({"app": Backup.APP, "version": Backup.VERSION + 1, "archivos": {}}))["error"] == "version", "de una versión más nueva")
	_check(Backup.validate(JSON.stringify({"app": Backup.APP, "version": 1, "archivos": {}}))["error"] == "sin_datos", "sin archivos")
	var evil := {"app": Backup.APP, "version": 1, "archivos": {"../chessome_online.cfg": "{\"a\":1}"}}
	_check(Backup.validate(JSON.stringify(evil))["error"] == "archivo", "un nombre fuera de la lista blanca se rechaza")
	var evil2 := {"app": Backup.APP, "version": 1, "archivos": {"premium.cfg": "{\"a\":1}"}}
	_check(Backup.validate(JSON.stringify(evil2))["error"] == "archivo", "premium.cfg no se puede importar")
	var broken := {"app": Backup.APP, "version": 1, "archivos": {"chessome_progreso.json": "{roto"}}
	_check(Backup.validate(JSON.stringify(broken))["error"] == "archivo", "un archivo interno roto se rechaza")
	var bad_png := {"app": Backup.APP, "version": 1, "archivos": {"chessome_curso.json": "{\"done\":{}}"}, "avatar": Marshalls.raw_to_base64(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9]))}
	var vb := Backup.validate(JSON.stringify(bad_png))
	_check(bool(vb["ok"]) and (vb["datos"]["avatar"] as PackedByteArray).is_empty(), "un avatar que no es PNG se ignora, sin tirar la copia")

	# Archivos propios rotos no se copian (no se propaga un archivo malo).
	_write_raw(A, "chessome_curso.json", "{roto")
	var t2 := Backup.build(A, 0)
	_check(not (JSON.parse_string(t2)["archivos"] as Dictionary).has("chessome_curso.json"), "un archivo propio roto no entra en la copia")

	# Un fallo al escribir no deja nada a medias: la carpeta destino no existe.
	_check(not Backup.restore(v["datos"], "user://_no_existe_bk"), "si no se puede escribir, devuelve false")

	_check(Backup.file_name(1763935200) == "a-chess-way-2025-11-23.json", "nombre con la fecha (%s)" % Backup.file_name(1763935200))

	_clean(A)
	_clean(B)
	print("test_backup: %s" % ("OK" if fallos == 0 else "%d fallos" % fallos))
	quit(1 if fallos > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		fallos += 1
		printerr("FALLO: ", what)
	else:
		print("ok: ", what)


func _write(dir: String, name: String, data: Dictionary) -> void:
	_write_raw(dir, name, JSON.stringify(data))


func _write_raw(dir: String, name: String, text: String) -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for n in d.get_files():
		d.remove(n)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
