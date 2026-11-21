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


static func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("premium", "comprado", purchased)
	cfg.set_value("premium", "prueba", test_on)
	cfg.set_value("premium", "clave_prueba", test_key)
	cfg.set_value("profesor", "activo", coach_on)
	cfg.save(PATH)


## Las pruebas solo valen en depuración.
static func test_allowed() -> bool:
	return OS.is_debug_build()


static func active() -> bool:
	if not _loaded:
		load_state()
	return purchased or (test_on and test_allowed())


## Si el profesor tiene que comentar esta partida: premium, elegido por el jugador, y una partida normal sin reloj,
## sin red y fuera del nivel Kids (con reloj no hay pistas, como en una partida oficial).
static func coach_applies(kids: bool, online: bool, clocked: bool, variant: String) -> bool:
	return active() and coach_on and not kids and not online and not clocked and variant == ""
