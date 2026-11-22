class_name Pagos
extends Node
## Compras en Google Play (complemento Android «PagosGoogle», android_pagos/): Premium («premium_mensual») y recargas
## de 100 explicaciones («explicaciones_100»). Cada compra se manda al servidor, que la verifica con Google y lleva
## el cupo (worker/src/cuentas.js, por CoachAI.premium_call); después se reconoce (suscripción) o se consume
## (recarga), para que Google no la devuelva a los 3 días. Sin el complemento (escritorio, pruebas): `available()`
## es false y la app lo dice.

signal changed
## Mensaje para el jugador (compra hecha, error…).
signal note(text: String)

const SUB := "premium_mensual"
const PACK := "explicaciones_100"

## Precios de Google Play (en la moneda del jugador), cuando llegan: {id: "4,99 €"}.
var prices := {}
var connected := false
var busy := false
var coach: CoachAI
## Pruebas: sustituye al complemento ({"conectar", "productos", "comprar", "consultar", "reconocer", "consumir"}).
var fake: Object = null
var _plugin: Object = null


func setup(coach_ai: CoachAI) -> void:
	coach = coach_ai
	if Engine.has_singleton("PagosGoogle"):
		_plugin = Engine.get_singleton("PagosGoogle")
		_plugin.connect("conectado", _on_connected)
		_plugin.connect("productos", _on_products)
		_plugin.connect("compras", _on_purchases)
		_plugin.connect("fallo", _on_failed)
		_plugin.connect("hecho", _on_done)


func _p() -> Object:
	return fake if fake != null else _plugin


func available() -> bool:
	return _p() != null


## Al abrir la app: conecta, pide precios y mira si hay compras sin confirmar (o de otro móvil).
func start() -> void:
	if _p() != null:
		_p().call("conectar")


func _on_connected(ok: bool) -> void:
	connected = ok
	if ok:
		_p().call("productos", SUB, PACK)
		_p().call("consultar")
	changed.emit()


func _on_products(json: String) -> void:
	var list: Variant = JSON.parse_string(json)
	if list is Array:
		for p: Variant in list:
			if p is Dictionary and str(p.get("precio", "")) != "":
				prices[str(p["id"])] = str(p["precio"])
	changed.emit()


func buy(id: String) -> void:
	if _p() == null:
		note.emit(Loc.t("Las compras solo funcionan en la app instalada desde Google Play."))
		return
	if not connected:
		start()
		note.emit(Loc.t("Conectando con Google Play… Prueba otra vez en un momento."))
		return
	_p().call("comprar", id, Premium.account_id())


## «Restaurar compras»: vuelve a mirar en Google Play (otro móvil, reinstalación).
func restore() -> void:
	if _p() == null:
		note.emit(Loc.t("Las compras solo funcionan en la app instalada desde Google Play."))
		return
	if not connected:
		start()
		return
	_p().call("consultar")


func _on_purchases(json: String) -> void:
	var list: Variant = JSON.parse_string(json)
	if not (list is Array):
		return
	for p: Variant in list:
		if p is Dictionary and bool(p.get("pagada", false)):
			await _confirm(p)
	changed.emit()


## Una compra pagada: el servidor la verifica y la apunta; después, se reconoce o se consume.
func _confirm(p: Dictionary) -> void:
	var products: Array = p.get("productos", []) if p.get("productos") is Array else []
	var token := str(p.get("token", ""))
	if token == "" or coach == null:
		return
	busy = true
	if products.has(SUB):
		var st := await coach.premium_call("/premium/alta", {"token": token})
		busy = false
		if st.has("_error"):
			note.emit(_server_error(int(st["_error"])))
			return
		if not bool(p.get("reconocida", false)):
			_p().call("reconocer", token)
			note.emit(Loc.t("¡Ya eres Premium! Gracias por apoyar A Chess Way."))
	elif products.has(PACK):
		var st := await coach.premium_call("/premium/recarga", {"token": token})
		busy = false
		if st.has("_error"):
			note.emit(_server_error(int(st["_error"])))
			return
		_p().call("consumir", token)
		note.emit(Loc.f("Recarga hecha: tienes %d explicaciones extra.", int(st.get("extra", 0))))
	busy = false


func _server_error(code: int) -> String:
	if code == 503:
		return Loc.t("No se ha podido confirmar la compra ahora. Se volverá a intentar al abrir la app; no se te cobra dos veces.")
	if code == 409:
		return Loc.t("Esa compra ya está asociada a otra cuenta.")
	return Loc.t("No se ha podido confirmar la compra (sin conexión). Se volverá a intentar al abrir la app.")


func _on_failed(code: int, _message: String) -> void:
	# 1: el jugador canceló; 7: ya la tiene (se restaura).
	if code == 1:
		return
	if code == 7:
		restore()
		return
	note.emit(Loc.t("Google Play no ha podido hacer la compra. Prueba otra vez más tarde."))


func _on_done(_what: String, _token: String) -> void:
	changed.emit()
