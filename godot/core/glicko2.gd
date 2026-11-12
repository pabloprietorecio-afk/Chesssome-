class_name Glicko2
## Glicko-2 (dominio público; descripción de Mark Glickman, "Example of the Glicko-2 system").
## Port línea a línea de src/core/glicko2.ts. La referencia es el código TypeScript: cualquier cambio
## se hace allí primero, se regenera tests/golden/glicko2.json (npm run golden) y se comprueba aquí
## con tests/test_glicko2.gd.
##
## Un rating es un Dictionary {"r": float, "rd": float, "vol": float}.
## Un resultado es {"opponent": {"r": float, "rd": float}, "score": float} (1 = acierto, 0 = fallo).

const SCALE := 173.7178


static func _g(phi: float) -> float:
	return 1.0 / sqrt(1.0 + (3.0 * phi * phi) / (PI * PI))


static func _e(mu: float, mu_j: float, phi_j: float) -> float:
	return 1.0 / (1.0 + exp(-_g(phi_j) * (mu - mu_j)))


## Probabilidad de acierto prevista para un jugador (rating player_r) frente a un problema.
static func expected_score(player_r: float, opp_r: float, opp_rd: float) -> float:
	return _e((player_r - 1500.0) / SCALE, (opp_r - 1500.0) / SCALE, opp_rd / SCALE)


## Función cuya raíz da la nueva volatilidad (paso 5 de Glickman).
static func _f(x: float, delta: float, phi: float, v: float, a: float, tau: float) -> float:
	var ex := exp(x)
	var num := ex * (delta * delta - phi * phi - v - ex)
	var den := 2.0 * (phi * phi + v + ex) * (phi * phi + v + ex)
	return num / den - (x - a) / (tau * tau)


## Actualiza el rating con los resultados de un periodo (en la app, normalmente un solo problema).
static func update(player: Dictionary, results: Array, tau: float = 0.5) -> Dictionary:
	var r0 := float(player["r"])
	var mu := (r0 - 1500.0) / SCALE
	var phi := float(player["rd"]) / SCALE
	var vol0 := float(player["vol"])
	if results.is_empty():
		return {"r": r0, "rd": minf(350.0, sqrt(phi * phi + vol0 * vol0) * SCALE), "vol": vol0}

	var v_inv := 0.0
	var sum := 0.0
	for res: Dictionary in results:
		var opp: Dictionary = res["opponent"]
		var mu_j := (float(opp["r"]) - 1500.0) / SCALE
		var phi_j := float(opp["rd"]) / SCALE
		var e := _e(mu, mu_j, phi_j)
		var gj := _g(phi_j)
		v_inv += gj * gj * e * (1.0 - e)
		sum += gj * (float(res["score"]) - e)
	var v := 1.0 / v_inv
	var delta := v * sum

	# Nueva volatilidad (algoritmo de Illinois).
	var a := log(vol0 * vol0)
	var big_a := a
	var big_b: float
	if delta * delta > phi * phi + v:
		big_b = log(delta * delta - phi * phi - v)
	else:
		var k := 1
		while _f(a - k * tau, delta, phi, v, a, tau) < 0.0:
			k += 1
		big_b = a - k * tau
	var f_a := _f(big_a, delta, phi, v, a, tau)
	var f_b := _f(big_b, delta, phi, v, a, tau)
	var i := 0
	while i < 100 and absf(big_b - big_a) > 1e-6:
		var big_c := big_a + ((big_a - big_b) * f_a) / (f_b - f_a)
		var f_c := _f(big_c, delta, phi, v, a, tau)
		if f_c * f_b <= 0.0:
			big_a = big_b
			f_a = f_b
		else:
			f_a = f_a / 2.0
		big_b = big_c
		f_b = f_c
		i += 1
	var vol := exp(big_a / 2.0)
	var phi_star := sqrt(phi * phi + vol * vol)
	var phi_new := 1.0 / sqrt(1.0 / (phi_star * phi_star) + 1.0 / v)
	var mu_new := mu + phi_new * phi_new * sum
	return {"r": mu_new * SCALE + 1500.0, "rd": phi_new * SCALE, "vol": vol}


## Rating del problema que da al jugador una probabilidad de acierto p.
## Con p = 0,75 el problema queda unos 190 puntos por debajo del jugador.
static func rating_for_success(player_r: float, p: float) -> float:
	return player_r - 400.0 * (log(p / (1.0 - p)) / log(10.0))
