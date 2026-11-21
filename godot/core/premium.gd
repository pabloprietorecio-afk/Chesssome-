class_name Premium
extends RefCounted
## Versión premium de A Chess Way. Hoy solo trae el profesor IA en las partidas (core/coach_ai.gd).
##
## Estado:
##   - La compra real (Google Play Billing) **no está montada**: hace falta un plugin de facturación y el producto
##     creado en Play Console. Cuando exista, `purchased` se pondrá a true al confirmar la compra.
##   - «Premium de prueba»: un interruptor en Opciones que solo sale en las compilaciones de depuración (el APK de
##     la CI). En el AAB de publicación no aparece y no cuenta aunque quede guardado.
##
## Se guarda aparte de los ajustes (user://premium.cfg), junto con la clave de la API de las pruebas: así la clave
## nunca viaja en el repositorio ni en el paquete de la app; solo está en el móvil de quien la pega.

const PATH := "user://premium.cfg"

static var purchased := false
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
		return
	purchased = bool(cfg.get_value("premium", "comprado", false))
	test_on = bool(cfg.get_value("premium", "prueba", false))
	test_key = str(cfg.get_value("premium", "clave_prueba", ""))
	coach_on = bool(cfg.get_value("profesor", "activo", true))
	trial_used = int(cfg.get_value("profesor", "partidas_gratis", 0))
	trial_told = bool(cfg.get_value("profesor", "aviso_fin_prueba", false))


static func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("premium", "comprado", purchased)
	cfg.set_value("premium", "prueba", test_on)
	cfg.set_value("premium", "clave_prueba", test_key)
	cfg.set_value("profesor", "activo", coach_on)
	cfg.set_value("profesor", "partidas_gratis", trial_used)
	cfg.set_value("profesor", "aviso_fin_prueba", trial_told)
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


## Si esta partida puede llevar profesor: premium, o la partida ya contada en la prueba, o quedan partidas gratis.
static func coach_allowed(run: int = -1) -> bool:
	return active() or (run >= 0 and trial_run == run) or trial_left() > 0


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
