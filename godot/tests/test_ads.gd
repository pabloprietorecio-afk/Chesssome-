extends SceneTree
## Anuncios entre actividades (core/ads.gd): cuándo tocan y cuándo no. La parte del plugin no se prueba aquí
## (sin Android no existe); sí que, sin él, la app no hace nada y el reloj de uso avanza.
## Uso: godot --headless --path godot -s tests/test_ads.gd

var fallos := 0
var hechos := 0
const C := {"first_s": 600, "gap_s": 480, "max_per_session": 3}


func _init() -> void:
	_ok(not Ads.is_due(599.0, -1.0, 0, C, false, true), "antes de los 10 minutos de uso no hay anuncio")
	_ok(Ads.is_due(600.0, -1.0, 0, C, false, true), "a los 10 minutos toca el primero")
	_ok(not Ads.is_due(2000.0, -1.0, 0, C, true, true), "bloqueado (Kids, online…): nunca")
	_ok(not Ads.is_due(2000.0, -1.0, 0, C, false, false), "sin anuncio cargado: no toca")
	_ok(not Ads.is_due(1000.0, 700.0, 1, C, false, true), "tras uno, hay que esperar el hueco")
	_ok(Ads.is_due(1180.0, 700.0, 1, C, false, true), "pasado el hueco, toca otro")
	_ok(not Ads.is_due(9999.0, 700.0, 3, C, false, true), "tope por sesión")
	_ok(not Ads.is_due(9999.0, -1.0, 3, C, false, true), "tope por sesión también sin último")
	# Sin plugin (aquí): no está disponible y nada ocurre.
	var ads := Ads.new()
	_ok(not Ads.available(), "sin Android ni plugin no hay anuncios")
	ads.start()
	ads.tick(0.5)
	ads.tick(30.0)  # un salto (la app estuvo minimizada): solo cuenta 1 s
	_ok(is_equal_approx(ads.active_s, 1.5), "el reloj de uso ignora los saltos largos")
	_ok(not ads.maybe_show(false), "sin puente no sale nada")
	# Los datos de la CI: IDs de prueba por defecto y reglas razonables.
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Ads.CONFIG))
	_ok(str(cfg["app_id"]).contains("~") and str(cfg["interstitial"]).contains("/"), "ads.json: app_id lleva ~ y el bloque, /")
	_ok(int(cfg["first_s"]) >= 300 and int(cfg["gap_s"]) >= 300, "ads.json: pocos anuncios (≥5 min)")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
