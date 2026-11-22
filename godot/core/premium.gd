class_name Premium
extends RefCounted
## Versión premium de A Chess Way (22 nov, decisión de Pablo):
##   - Gratis para todos: las chapas de cada jugada (Stockfish) y el asistente. Las explicaciones («Explícamelo») y las
##     preguntas al tutor, en las 5 primeras partidas con tutor.
##   - Premium (suscripción «premium_mensual»): 300 explicaciones o preguntas al mes y el rival «Experto» (Stockfish).
##   - Recargas («explicaciones_100»): 100 más, para quien agote el cupo (o sin suscripción).
## La compra es de Google Play (core/pagos.gd, android_pagos/) y la verifica el servidor, que lleva el cupo
## (worker/src/cuentas.js): la app nunca se da a sí misma por premium. `purchased` viene del servidor.
##   - «Premium de prueba»: un interruptor en Opciones que solo sale en las compilaciones de depuración (el APK de
##     la CI). En el AAB de publicación no aparece y no cuenta aunque quede guardado.
##
## Se guarda aparte de los ajustes (user://premium.cfg), junto con la clave de la API de las pruebas: así la clave
## nunca viaja en el repositorio ni en el paquete de la app; solo está en el móvil de quien la pega.

const PATH := "user://premium.cfg"

static var purchased := false
## Cuenta anónima de este móvil para el servidor (cupo y compras): 32 cifras hexadecimales al azar.
static var account := ""
## Último estado que dio el servidor: {premium, quedan, extra, gratis, caduca, mes}.
static var server := {}
static var test_on := false
## Clave de la API de Claude para probar sin servidor propio. Solo en depuración (ver CoachAI.endpoint_mode).
static var test_key := ""
## El profesor durante las partidas (lo elige el jugador; hace falta premium).
static var coach_on := true
## Prueba gratis para todos (decisión de Pablo, 21 nov): las 5 primeras partidas con profesor no piden premium.
## Cuenta una partida en cuanto el profesor mira la primera jugada; esa partida sigue con profesor hasta el final.
const TRIAL_GAMES := 5
static var trial_used := 0
## Partida (run_id de la app) que ya ha gastado su turno de prueba: no vuelve a contar.
static var trial_run := -1
## Ya se avisó de que la prueba se acabó (el aviso sale una vez).
static var trial_told := false
static var _loaded := false


static func load_state() -> void:
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_ensure_account()
		return
	purchased = bool(cfg.get_value("premium", "comprado", false))
	# Premium guardado de otra sesión: vale hasta su fecha (luego lo confirma el servidor).
	var until := int((cfg.get_value("cuenta", "estado", {}) as Dictionary).get("caduca", 0)) if cfg.get_value("cuenta", "estado", {}) is Dictionary else 0
	if purchased and until > 0 and until < int(Time.get_unix_time_from_system() * 1000.0):
		purchased = false
	test_on = bool(cfg.get_value("premium", "prueba", false))
	test_key = str(cfg.get_value("premium", "clave_prueba", ""))
	coach_on = bool(cfg.get_value("profesor", "activo", true))
	trial_used = int(cfg.get_value("profesor", "partidas_gratis", 0))
	trial_told = bool(cfg.get_value("profesor", "aviso_fin_prueba", false))
	account = str(cfg.get_value("cuenta", "id", ""))
	var st: Variant = cfg.get_value("cuenta", "estado", {})
	server = st if st is Dictionary else {}
	_ensure_account()


## La cuenta anónima (se crea la primera vez).
static func account_id() -> String:
	_ensure_account()
	return account


static func _ensure_account() -> void:
	if account.length() == 32:
		return
	account = Crypto.new().generate_random_bytes(16).hex_encode()
	save_state()


static func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("premium", "comprado", purchased)
	cfg.set_value("premium", "prueba", test_on)
	cfg.set_value("premium", "clave_prueba", test_key)
	cfg.set_value("profesor", "activo", coach_on)
	cfg.set_value("profesor", "partidas_gratis", trial_used)
	cfg.set_value("profesor", "aviso_fin_prueba", trial_told)
	cfg.set_value("cuenta", "id", account)
	cfg.set_value("cuenta", "estado", server)
	cfg.save(PATH)


## Las pruebas solo valen en depuración.
static func test_allowed() -> bool:
	return OS.is_debug_build()


static func active() -> bool:
	if not _loaded:
		load_state()
	return purchased or (test_on and test_allowed())


## Partidas gratis con profesor que quedan.
static func trial_left() -> int:
	if not _loaded:
		load_state()
	return maxi(0, TRIAL_GAMES - trial_used)


## Las chapas (Stockfish) son para todos: el tutor puede ir en cualquier partida que lo admita.
static func coach_allowed(_run: int = -1) -> bool:
	return true


## Explicaciones y preguntas (gastan IA): premium, una partida gratis (la que ya cuenta o una que quede) o recargas.
## El servidor tiene la última palabra (cupo: 402 si no hay).
static func explain_allowed(run: int = -1) -> bool:
	return active() or (run >= 0 and trial_run == run) or trial_left() > 0 or int(server.get("extra", 0)) > 0


## El estado que manda el servidor (tras una explicación, una compra o al abrir la app).
static func set_status(st: Dictionary) -> void:
	if not _loaded:
		load_state()
	if not st.has("premium"):
		return
	server = st
	purchased = bool(st["premium"])
	save_state()


## La partida `run` empieza a usar el profesor: sin premium, gasta una de las gratis (una vez por partida).
## Devuelve qué partida gratis es (1…5), o 0 si no cuenta (premium, o ya no quedan).
static func use_trial(run: int) -> int:
	if active():
		return 0
	if trial_run == run:
		return trial_used
	if trial_left() <= 0:
		return 0
	trial_used += 1
	trial_run = run
	save_state()
	return trial_used


## Si el profesor tiene que comentar esta partida: premium (o partida gratis), elegido por el jugador, y una
## partida normal sin reloj, sin red y fuera del nivel Kids (con reloj no hay pistas, como en una partida oficial).
static func coach_applies(kids: bool, online: bool, clocked: bool, variant: String, run: int = -1) -> bool:
	return coach_allowed(run) and coach_on and not kids and not online and not clocked and variant == ""
