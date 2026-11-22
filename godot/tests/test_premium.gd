extends SceneTree
## Premium y cupo (22 nov): compras de Google Play (simuladas) verificadas por el servidor (simulado), la ventana de
## Premium cuando no hay cupo y el rival «Experto» reservado a Premium.
## Uso: godot --headless --path godot -s tests/test_premium.gd

var fallos := 0
var hechos := 0


class FakePlay extends Object:
	var calls: Array = []
	func conectar() -> void: calls.append("conectar")
	func productos(a: String, b: String) -> void: calls.append("productos")
	func consultar() -> void: calls.append("consultar")
	func comprar(id: String, cuenta: String) -> void: calls.append("comprar:%s:%d" % [id, cuenta.length()])
	func reconocer(t: String) -> void: calls.append("reconocer:" + t)
	func consumir(t: String) -> void: calls.append("consumir:" + t)


func _initialize() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await _frames(4)
	demo.gesture_hint = false
	Premium._loaded = true
	Premium.purchased = false
	Premium.test_on = false
	Premium.server = {}
	var play := FakePlay.new()
	demo.pagos.fake = play
	var server_calls: Array = []
	demo.coach.fake_premium = func(path: String, body: Dictionary) -> Dictionary:
		await process_frame
		server_calls.append(path)
		if path == "/premium/alta":
			return {"premium": true, "quedan": 300, "extra": 0, "gratis": 40, "caduca": int(Time.get_unix_time_from_system() * 1000.0) + 86400000, "mes": 300}
		if path == "/premium/recarga":
			return {"premium": true, "quedan": 300, "extra": 100, "gratis": 40, "caduca": int(Time.get_unix_time_from_system() * 1000.0) + 86400000, "mes": 300}
		return {"premium": false, "quedan": 0, "extra": 0, "gratis": 40, "caduca": 0, "mes": 300}

	# Precios de Google Play.
	demo.pagos._on_connected(true)
	demo.pagos._on_products('[{"id":"premium_mensual","precio":"4,99 €"},{"id":"explicaciones_100","precio":"1,99 €"}]')
	_ok(play.calls.has("productos") and play.calls.has("consultar") and demo.pagos.prices["premium_mensual"] == "4,99 €", "al conectar: precios y compras pendientes")

	# La ventana de Premium (sin cupo) y comprar.
	demo._open_premium_offer("premium")
	await _frames(2)
	_ok(_has_text(demo.confirm_node, "Hazte Premium · 4,99 €/mes") and _has_text(demo.confirm_node, "Restaurar compras"), "ventana de Premium con el precio de Google Play")
	demo._buy("premium_mensual")
	_ok(play.calls.has("comprar:premium_mensual:32"), "comprar: abre Google Play con la cuenta anónima")

	# Google Play confirma la compra: el servidor la verifica; después se reconoce.
	await demo.pagos._on_purchases('[{"productos":["premium_mensual"],"token":"tok-sub","pagada":true,"reconocida":false}]')
	await _frames(2)
	_ok(server_calls.has("/premium/alta") and Premium.active() and play.calls.has("reconocer:tok-sub"), "suscripción: el servidor la verifica, ya es Premium y se reconoce")

	# Recarga: el servidor la apunta y se consume.
	demo._close_confirm()
	await demo.pagos._on_purchases('[{"productos":["explicaciones_100"],"token":"tok-pack","pagada":true,"reconocida":false}]')
	await _frames(2)
	_ok(server_calls.has("/premium/recarga") and int(Premium.server.get("extra", 0)) == 100 and play.calls.has("consumir:tok-pack"), "recarga: el servidor la apunta (100 más) y se consume")

	# Compra pendiente (sin pagar): no se manda al servidor.
	server_calls.clear()
	await demo.pagos._on_purchases('[{"productos":["premium_mensual"],"token":"tok-x","pagada":false,"reconocida":false}]')
	_ok(server_calls.is_empty(), "una compra pendiente de pago no se da por buena")

	# Sin cupo en una pregunta (402): ventana de recarga.
	demo._close_confirm()
	demo.ask_state = "wait"
	demo._on_tutor_answer(demo.run_id, demo._ask_gen, {"_error": 402, "_motivo": "cupo"})
	await _frames(2)
	_ok(demo.confirm_node == demo._premium_offer_node and _has_text(demo.confirm_node, "Has usado las explicaciones de este mes.") and _has_text(demo.confirm_node, "100 explicaciones más · 1,99 €"), "sin cupo: ofrece una recarga")

	# «Experto», solo Premium.
	demo._close_confirm()
	Premium.set_status({"premium": false, "quedan": 0, "extra": 0, "gratis": 0, "caduca": 0, "mes": 300})
	demo._pick_sublevel(Bot.APP_GROUPS)
	await _frames(2)
	_ok(demo._premium_offer_reason == "experto" and demo.confirm_node == demo._premium_offer_node, "«Experto» sin Premium: ventana de Premium")
	demo._close_confirm()

	print("TODO OK" if fallos == 0 else "FALLOS: %d de %d" % [fallos, hechos])
	quit(1 if fallos > 0 else 0)


func _has_text(node: Node, text: String) -> bool:
	if node == null:
		return false
	if (node is Label and (node as Label).text.contains(Loc.t(text))) or (node is Button and str(node.get_meta("label", "")).contains(text)):
		return true
	var meta: Variant = node.get_meta("label_node", null)
	if meta is Label and (meta as Label).text.contains(text):
		return true
	for c in node.get_children():
		if _has_text(c, text):
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ok(cond: bool, what: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + what)
