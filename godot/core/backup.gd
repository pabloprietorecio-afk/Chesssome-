class_name Backup
extends RefCounted
## Copia de seguridad del progreso para pasarlo a otro dispositivo (Opciones → «Copia de seguridad»). Todo en un
## solo archivo JSON que el jugador mueve como quiera (correo, Drive, Quick Share…). No hay cuenta ni servidor.
##
## Qué entra: SOLO los archivos de la lista blanca FILES (+ el avatar). Nunca `chessome_online.cfg` (token de
## sesión) ni `premium.cfg` (clave de la API de las pruebas), ni los ajustes del dispositivo (`chessome.cfg`).
## Al importar solo se escriben nombres de la lista blanca: un archivo de copia manipulado no puede escribir en
## otras rutas.
##
## Importar SUSTITUYE lo que hay. Antes se guarda lo anterior en `copia_previa.json` (con el mismo formato, se
## puede volver a importar).

const APP := "a-chess-way"
const VERSION := 1
## Archivos JSON del progreso. Los que falten en la copia se borran al importar (se sustituye todo).
const FILES := ["chessome_progreso.json", "chessome_jugador.json", "chessome_curso.json", "chessome_partidas.json", "campeonato.json"]
const AVATAR := "chessome_avatar.png"
const PREVIOUS := "copia_previa.json"
## Tamaños máximos (un archivo de copia muy grande no es nuestro).
const MAX_TOTAL := 16 * 1024 * 1024
const MAX_AVATAR := 600 * 1024
const PNG_MAGIC := [0x89, 0x50, 0x4E, 0x47]


## Texto JSON de la copia con lo que hay ahora en `dir`. `now`: segundos Unix (para las pruebas).
static func build(dir: String = "user://", now: int = -1) -> String:
	var files := {}
	for name: String in FILES:
		var path := dir.path_join(name)
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		if _parse_dict(text).is_empty():
			continue # roto o vacío: no se copia
		files[name] = text
	var out := {"app": APP, "version": VERSION, "creado": now if now >= 0 else int(Time.get_unix_time_from_system()), "archivos": files}
	var avatar_path := dir.path_join(AVATAR)
	if FileAccess.file_exists(avatar_path):
		var bytes := FileAccess.get_file_as_bytes(avatar_path)
		if bytes.size() > 0 and bytes.size() <= MAX_AVATAR and _is_png(bytes):
			out["avatar"] = Marshalls.raw_to_base64(bytes)
	return JSON.stringify(out)


## Revisa un texto de copia. Devuelve {"ok": true, "datos": {...}, "resumen": {...}} o {"ok": false, "error": clave}.
## Claves de error: "vacio", "grande", "formato" (no es JSON o no es de la app), "version" (de una versión más
## nueva de la app), "archivo" (un archivo interno roto o con un nombre no permitido), "sin_datos".
static func validate(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {"ok": false, "error": "vacio"}
	if text.length() > MAX_TOTAL:
		return {"ok": false, "error": "grande"}
	var data := _parse_dict(text)
	if data.is_empty() or str(data.get("app", "")) != APP:
		return {"ok": false, "error": "formato"}
	var version := int(data.get("version", 0))
	if version < 1:
		return {"ok": false, "error": "formato"}
	if version > VERSION:
		return {"ok": false, "error": "version"}
	var files_v: Variant = data.get("archivos")
	if not (files_v is Dictionary):
		return {"ok": false, "error": "formato"}
	var files: Dictionary = files_v
	var clean := {}
	for key: Variant in files:
		var name := str(key)
		if not FILES.has(name) or not (files[key] is String):
			return {"ok": false, "error": "archivo"}
		if _parse_dict(files[key]).is_empty():
			return {"ok": false, "error": "archivo"}
		clean[name] = files[key]
	var avatar := PackedByteArray()
	if data.has("avatar"):
		if not (data["avatar"] is String):
			return {"ok": false, "error": "archivo"}
		avatar = Marshalls.base64_to_raw(data["avatar"])
		if avatar.size() > MAX_AVATAR or not _is_png(avatar):
			avatar = PackedByteArray() # el avatar es opcional: si está mal, se ignora
	if clean.is_empty():
		return {"ok": false, "error": "sin_datos"}
	return {"ok": true, "datos": {"archivos": clean, "avatar": avatar, "creado": int(data.get("creado", 0))}, "resumen": summary(clean)}


## Lo que se enseña antes de confirmar: partidas guardadas, problemas intentados y días con actividad.
static func summary(files: Dictionary) -> Dictionary:
	var games := 0
	var tries := 0
	var days := 0
	if files.has("chessome_partidas.json"):
		var g: Variant = _parse_dict(files["chessome_partidas.json"]).get("partidas")
		games = (g as Array).size() if g is Array else 0
	if files.has("chessome_jugador.json"):
		var t: Variant = _parse_dict(files["chessome_jugador.json"]).get("tries")
		tries = (t as Array).size() if t is Array else 0
	if files.has("chessome_progreso.json"):
		var d: Variant = _parse_dict(files["chessome_progreso.json"]).get("dias")
		days = (d as Dictionary).size() if d is Dictionary else 0
	return {"partidas": games, "problemas": tries, "dias": days}


## Aplica una copia ya validada (`validate(...)["datos"]`) en `dir`. Primero guarda lo anterior en `copia_previa.json`.
## Escribe todo en archivos temporales y solo si todo salió bien los renombra: un fallo a medias no deja la
## carpeta con la mitad de cada dispositivo. Devuelve si se pudo.
static func restore(datos: Dictionary, dir: String = "user://") -> bool:
	var files: Dictionary = (datos.get("archivos", {}) as Dictionary).duplicate()
	if files.is_empty():
		return false
	# El aviso diario programado en el sistema es de este dispositivo: se deja apagado para que se vuelva a activar
	# (con su permiso) y no quede «activo» sin alarma.
	if files.has("chessome_progreso.json"):
		var progress := _parse_dict(files["chessome_progreso.json"])
		if progress.get("aviso") is Dictionary:
			(progress["aviso"] as Dictionary)["activo"] = false
			files["chessome_progreso.json"] = JSON.stringify(progress)
	# Lo anterior, por si el jugador se arrepiente.
	var previous := build(dir)
	var pf := FileAccess.open(dir.path_join(PREVIOUS), FileAccess.WRITE)
	if pf != null:
		pf.store_string(previous)
		pf.close()
	var tmps := {}
	for name: String in files:
		var tmp := dir.path_join(name + ".imp")
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		if f == null:
			_remove_all(tmps.values())
			return false
		f.store_string(str(files[name]))
		f.close()
		tmps[name] = tmp
	var avatar: PackedByteArray = datos.get("avatar", PackedByteArray())
	var avatar_tmp := ""
	if avatar.size() > 0:
		avatar_tmp = dir.path_join(AVATAR + ".imp")
		var af := FileAccess.open(avatar_tmp, FileAccess.WRITE)
		if af == null:
			_remove_all(tmps.values())
			return false
		af.store_buffer(avatar)
		af.close()
	for name: String in tmps:
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmps[name]), ProjectSettings.globalize_path(dir.path_join(name))) != OK:
			_remove_all(tmps.values())
			return false
	if avatar_tmp != "":
		DirAccess.rename_absolute(ProjectSettings.globalize_path(avatar_tmp), ProjectSettings.globalize_path(dir.path_join(AVATAR)))
	# Se sustituye todo: lo que la copia no trae, fuera.
	for name: String in FILES:
		if not files.has(name) and FileAccess.file_exists(dir.path_join(name)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(name)))
	return true


## Nombre propuesto para el archivo, con la fecha (p. ej. «a-chess-way-2026-11-23.json»).
static func file_name(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "a-chess-way-%04d-%02d-%02d.json" % [d["year"], d["month"], d["day"]]


static func _parse_dict(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.data is Dictionary):
		return {}
	return parser.data


static func _is_png(bytes: PackedByteArray) -> bool:
	if bytes.size() < 8:
		return false
	for i in 4:
		if bytes[i] != PNG_MAGIC[i]:
			return false
	return true


static func _remove_all(paths: Array) -> void:
	for p: Variant in paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(p)))
