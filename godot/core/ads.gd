class_name Ads
extends RefCounted
## Anuncios entre actividades (AdMob, plugin de Poing Studios, MIT). Reglas de producto (decisión de Pablo, 16 nov):
##  - Nunca en Kids, ni en el cine, ni en el reloj, ni en mitad de una partida, problema o lección: solo al abrir
##    el inicio, que es el momento entre actividades.
##  - Pocos: el primero tras `first_s` segundos de uso real y luego uno cada `gap_s` como mínimo (`max_per_session`).
##  - Todas las peticiones salen como «tratamiento dirigido a niños» y contenido G (app de público mixto sin
##    pantalla de edad): sin anuncios personalizados. Cuesta ingresos, pero evita necesitar una pantalla de edad.
## Lógica pura aquí (se prueba en tests/test_ads.gd); el puente con el plugin está en core/ads_admob.gd, que
## solo existe en las compilaciones de Android con el plugin (la CI lo crea de ads_admob.gdtxt). Sin él, no hace nada.

const BRIDGE := "res://core/ads_admob.gd"
const CONFIG := "res://data/ads.json"
const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"

var cfg := {"first_s": 600, "gap_s": 480, "max_per_session": 6}
var active_s := 0.0
var last_shown_s := -1.0
var shown := 0
var _bridge: RefCounted = null
var _started := false


## ¿Toca enseñar un anuncio ahora? `blocked`: algo lo impide (Kids, online, cine, anuncio ya en pantalla…).
static func is_due(active: float, last_shown: float, count: int, config: Dictionary, blocked: bool, ready: bool) -> bool:
	if blocked or not ready:
		return false
	if count >= int(config.get("max_per_session", 6)):
		return false
	if last_shown < 0.0:
		return active >= float(config.get("first_s", 600))
	return active - last_shown >= float(config.get("gap_s", 480))


## Hay plugin y estamos en Android (si no, nada de lo demás se carga).
static func available() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("PoingGodotAdMob") and ResourceLoader.exists(BRIDGE)


func load_config() -> void:
	if not FileAccess.file_exists(CONFIG):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if parsed is Dictionary:
		for k in (parsed as Dictionary):
			cfg[k] = parsed[k]


## ¿Ya se ha arrancado (y pedido el consentimiento)?
func started() -> bool:
	return _started


## Una vez, con el inicio ya en pantalla (y nunca en Kids).
func start() -> void:
	if _started or not available():
		return
	_started = true
	load_config()
	var script: GDScript = load(BRIDGE)
	_bridge = script.new()
	_bridge.start(cfg)


## Llamar cada fotograma con el tiempo de uso real (se ignoran saltos largos, p. ej. tras minimizar).
func tick(delta: float) -> void:
	active_s += minf(delta, 1.0)


## Al abrir el inicio. Devuelve true si ha salido un anuncio.
func maybe_show(blocked: bool) -> bool:
	if _bridge == null:
		return false
	if not is_due(active_s, last_shown_s, shown, cfg, blocked, bool(_bridge.call("is_ready"))):
		return false
	if _bridge.call("show"):
		last_shown_s = active_s
		shown += 1
		return true
	return false
