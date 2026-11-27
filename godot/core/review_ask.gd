class_name ReviewAsk
extends RefCounted
## Cuándo enseñar la ventanita de valoración de Google Play (In-App Review API, complemento PagosGoogle → `valorar`).
## Informe de testers (27 nov) y normas de Google (developer.android.com/guide/playcore/in-app-review):
## - nunca desde un botón (si Google ya no la enseña, el botón no haría nada): solo en un buen momento del juego,
##   al cerrar la enhorabuena de subir de nivel;
## - sin preguntar nada antes («¿Te gusta la app?»): se llama a Google y ya;
## - cuando el jugador ya conoce la app y sin insistir: unos días de uso, bastantes problemas resueltos, como mucho
##   tres veces y con meses entre una y otra. Google tiene además su propio cupo y puede no enseñar nada.
## El botón «Valorar la app» de Opciones es otra cosa: abre la ficha de Play.

const MIN_DAYS := 3
const MIN_SOLVED := 20
const MAX_ASKS := 3
const GAP_S := 90 * 24 * 3600

const STORE_URL := "https://play.google.com/store/apps/details?id=com.pabloprieto.chessome"


static func new_state() -> Dictionary:
	return {"veces": 0, "ultima": 0}


static func clean(v: Variant) -> Dictionary:
	var s := new_state()
	if v is Dictionary:
		s["veces"] = maxi(0, int((v as Dictionary).get("veces", 0)))
		s["ultima"] = maxi(0, int((v as Dictionary).get("ultima", 0)))
	return s


## `days`: días distintos con la app usada; `solved`: problemas resueltos; `now`: segundos Unix.
static func should_ask(state: Dictionary, days: int, solved: int, now: int, kids: bool) -> bool:
	if kids:
		return false
	if days < MIN_DAYS or solved < MIN_SOLVED:
		return false
	if int(state.get("veces", 0)) >= MAX_ASKS:
		return false
	var last := int(state.get("ultima", 0))
	return last <= 0 or now - last >= GAP_S


static func asked(state: Dictionary, now: int) -> void:
	state["veces"] = int(state.get("veces", 0)) + 1
	state["ultima"] = now
