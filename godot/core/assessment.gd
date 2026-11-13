class_name Assessment
## Evaluación enriquecida: el test de nivel, el perfil del jugador y el plan de entrenamiento.
## Port de src/core/assessment.ts. La referencia es el código TypeScript: cualquier cambio se hace allí
## primero, se regeneran los datos de oro (npm run golden) y se comprueba aquí con tests/test_assessment.gd.
##
## De cada intento no se guarda solo si acierta: también qué medía el problema (familia táctica, si acaba en
## mate, cuántas jugadas pide), en qué paso se falló, qué clase de error fue la jugada, si hubo ayuda y cuánto
## se tardó. Con eso se construye un perfil por dimensiones y un plan.
##
## Qué NO se mide: la comprensión del desarrollo, la seguridad del rey como concepto posicional y la
## capacidad estratégica. Los problemas tácticos no las miden y aquí no se inventa una medida.
##
## Tipos (todos Dictionary, con las mismas claves que en TypeScript):
##   problema  {id, rating, rd, theme, family, mate, steps}
##   resultado {correct, failStep, error, help, msFirst, ms}
##   intento   problema + resultado + {expected, phase}
##   estado    {rating: {r, rd, vol}, tries: [intento…], done}

## Punto de partida según lo que el jugador dice de sí mismo. La incertidumbre es alta a propósito.
const PRIOR := {
	"never": {"r": 600.0, "rd": 300.0, "vol": 0.06},
	"rules": {"r": 850.0, "rd": 300.0, "vol": 0.06},
	"casual": {"r": 1150.0, "rd": 300.0, "vol": 0.06},
	"regular": {"r": 1500.0, "rd": 300.0, "vol": 0.06},
}
## El test tiene entre MIN_ITEMS y MAX_ITEMS problemas; termina antes si la incertidumbre baja de TARGET_RD.
const MIN_ITEMS := 8
const MAX_ITEMS := 12
const TARGET_RD := 115.0
## El test incluye, si la muestra lo permite, al menos estos problemas de mate y de tres o más jugadas.
const MATE_ITEMS := 2
const LONG_ITEMS := 2
## Los dos primeros problemas solo buscan el nivel; las cuotas cuentan desde el tercero.
const QUOTA_FROM := 2
## Cuánto se aleja el test de la dificultad ideal para cubrir una cuota (puntos de rating).
const QUOTA_BONUS := 90.0
## Probabilidad de acierto con la que se eligen los problemas del entrenamiento (decisión de diseño).
const TARGET_SUCCESS := 0.75

const FAMILIES := ["doble", "linea", "defensor", "mate", "peon", "caza", "otros"]
const FAMILY_NAME := {
	"doble": "Ataques dobles y descubiertas",
	"linea": "Clavadas y enfiladas",
	"defensor": "Desviar, atraer y quitar defensas",
	"mate": "Mates",
	"peon": "Peones y coronación",
	"caza": "Piezas sin defensa o atrapadas",
	"otros": "Otros",
}
## Clases de error de una jugada equivocada, por su consecuencia (ver ErrorKind en src/core/explain.ts).
const ERROR_KINDS := ["mate", "hangMoved", "hangOther", "material", "worse", "missed", "slower"]


## Lo que la evaluación necesita saber de un problema de data/demo_puzzles.json.
static func item_of(p: Dictionary) -> Dictionary:
	return {
		"id": str(p.get("id", "")),
		"rating": float(p.get("rating", 1500)),
		"rd": float(p.get("rd", 80)),
		"theme": str(p.get("key", "")),
		"family": str(p.get("family", "otros")),
		"mate": bool(p.get("mate", false)),
		"steps": int(p.get("steps", 1)),
	}


static func start_test(experience: String) -> Dictionary:
	var prior: Dictionary = PRIOR.get(experience, PRIOR["casual"])
	return {"rating": prior.duplicate(), "tries": [], "done": false}


## Siguiente problema del test ({} si no quedan): el más cercano al nivel estimado (el que más informa), con
## un pequeño margen aleatorio (rand, de 0 a 1), sin repetir tema y cubriendo lo que el perfil necesita medir.
static func next_test_item(state: Dictionary, pool: Array, rand: float) -> Dictionary:
	var tries: Array = state["tries"]
	var seen := {}
	var used := {}
	var mates := 0
	var longs := 0
	for t: Dictionary in tries:
		seen[t["id"]] = true
		used[t["theme"]] = int(used.get(t["theme"], 0)) + 1
		if bool(t["mate"]):
			mates += 1
		if int(t["steps"]) >= 3:
			longs += 1
	var n := tries.size()
	var need_mate := n >= QUOTA_FROM and mates < MATE_ITEMS
	var need_long := n >= QUOTA_FROM and longs < LONG_ITEMS
	var target := float(state["rating"]["r"]) + (rand - 0.5) * 80.0
	var best := {}
	var best_cost := INF
	for p: Dictionary in pool:
		if seen.has(p["id"]):
			continue
		var steps := int(p["steps"])
		var cost := absf(float(p["rating"]) - target) + float(int(used.get(p["theme"], 0))) * 35.0
		# Los problemas largos cansan: solo entran los que hacen falta para medir el cálculo.
		cost += float(maxi(0, steps - (3 if need_long else 2))) * 40.0
		if need_mate and bool(p["mate"]):
			cost -= QUOTA_BONUS
		if need_long and steps >= 3:
			cost -= QUOTA_BONUS
		if cost < best_cost:
			best_cost = cost
			best = p
	return best


## Anota un intento: mueve el rating (Glicko-2) y, en el test, decide si ya hay datos suficientes.
## phase: "test" o "train".
static func record_try(state: Dictionary, item: Dictionary, outcome: Dictionary, phase: String) -> Dictionary:
	var rating: Dictionary = state["rating"]
	var expected := Glicko2.expected_score(float(rating["r"]), float(item["rating"]), float(item["rd"]))
	var result := {"opponent": {"r": float(item["rating"]), "rd": float(item["rd"])}, "score": 1.0 if bool(outcome["correct"]) else 0.0}
	var new_rating := Glicko2.update(rating, [result])
	var t := item.duplicate()
	t["correct"] = bool(outcome["correct"])
	t["failStep"] = int(outcome.get("failStep", -1))
	t["error"] = str(outcome.get("error", ""))
	t["help"] = str(outcome.get("help", ""))
	t["msFirst"] = float(outcome.get("msFirst", 0))
	t["ms"] = float(outcome.get("ms", 0))
	t["expected"] = expected
	t["phase"] = phase
	var tries: Array = (state["tries"] as Array).duplicate()
	tries.append(t)
	var done := bool(state["done"])
	if phase == "test":
		var n := 0
		for x: Dictionary in tries:
			if str(x["phase"]) == "test":
				n += 1
		done = n >= MAX_ITEMS or (n >= MIN_ITEMS and float(new_rating["rd"]) <= TARGET_RD)
	return {"rating": new_rating, "tries": tries, "done": done}


## Rango de ratings que la muestra puede medir (se descartan las colas de menos de cinco problemas): {min, max}.
static func measurable_range(pool: Array) -> Dictionary:
	var sorted: Array[float] = []
	for p: Dictionary in pool:
		sorted.append(float(p["rating"]))
	sorted.sort()
	if sorted.is_empty():
		return {"min": 0.0, "max": 0.0}
	return {"min": sorted[mini(4, sorted.size() - 1)], "max": sorted[maxi(0, sorted.size() - 5)]}


# ---------------------------------------------------------------- perfil

## {n, correct, expected, residual}. residual = (aciertos − previstos) / (n + k): negativo = peor de lo
## esperable para su nivel; con pocos intentos se acerca a cero.
static func stat(tries: Array, k: float = 5.0) -> Dictionary:
	var correct := 0
	var expected := 0.0
	for t: Dictionary in tries:
		if bool(t["correct"]):
			correct += 1
		expected += float(t["expected"])
	var n := tries.size()
	return {"n": n, "correct": correct, "expected": expected, "residual": (float(correct) - expected) / (float(n) + k)}


## Calificación de una dimensión: "few" (menos de min_n intentos: no se califica), "weak", "ok" o "strong".
static func status(s: Dictionary, min_n: int = 3) -> String:
	if int(s["n"]) < min_n:
		return "few"
	if float(s["residual"]) <= -0.08:
		return "weak"
	if float(s["residual"]) >= 0.08:
		return "strong"
	return "ok"


static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var v: Array[float] = []
	for x: Variant in values:
		v.append(float(x))
	v.sort()
	var mid := v.size() >> 1
	return v[mid] if v.size() % 2 == 1 else (v[mid - 1] + v[mid]) / 2.0


static func _family_before(a: Dictionary, b: Dictionary) -> bool:
	var ra := float(a["residual"])
	var rb := float(b["residual"])
	if ra != rb:
		return ra < rb
	return FAMILIES.find(a["family"]) < FAMILIES.find(b["family"])


## Perfil por dimensiones:
##   total, mate (problemas que acaban en mate), long (tres o más jugadas): estadísticas
##   families: familias con algún intento (sin la de mates), de más floja a más fuerte
##   failFirst / failLater: en problemas de dos o más jugadas, fallos en la primera jugada y después de acertarla
##   errors: jugadas equivocadas por clase; fails: cuántas; replyBlind: las que castiga la respuesta inmediata
##   helped: intentos con ayuda o abandonados
##   time: {n, median, medianCorrect, medianWrong, rushed} (ms hasta la primera jugada)
static func profile(tries: Array) -> Dictionary:
	var families: Array = []
	for family: String in FAMILIES:
		if family == "mate":
			continue
		var own: Array = []
		for t: Dictionary in tries:
			if str(t["family"]) == family:
				own.append(t)
		if own.is_empty():
			continue
		var s := stat(own)
		s["family"] = family
		families.append(s)
	families.sort_custom(Assessment._family_before)

	var errors := {}
	for kind: String in ERROR_KINDS:
		errors[kind] = 0
	var fails := 0
	var reply_blind := 0
	var fail_first := 0
	var fail_later := 0
	var helped := 0
	var mates: Array = []
	var longs: Array = []
	var timed: Array = []
	var right: Array = []
	var wrong: Array = []
	for t: Dictionary in tries:
		if bool(t["mate"]):
			mates.append(t)
		if int(t["steps"]) >= 3:
			longs.append(t)
		if float(t["msFirst"]) > 0.0:
			timed.append(float(t["msFirst"]))
			if bool(t["correct"]):
				right.append(float(t["msFirst"]))
			if str(t["error"]) != "":
				wrong.append(float(t["msFirst"]))
		if str(t["help"]) != "":
			helped += 1
		var error := str(t["error"])
		if error == "":
			continue
		fails += 1
		errors[error] = int(errors.get(error, 0)) + 1
		if error == "mate" or error == "hangMoved" or error == "hangOther":
			reply_blind += 1
		if int(t["steps"]) >= 2:
			if int(t["failStep"]) == 0:
				fail_first += 1
			elif int(t["failStep"]) > 0:
				fail_later += 1
	var median_correct := _median(right)
	var rushed := 0
	if right.size() >= 3:
		for ms: float in wrong:
			if ms < 0.5 * median_correct:
				rushed += 1
	return {
		"total": stat(tries),
		"families": families,
		"mate": stat(mates),
		"long": stat(longs),
		"failFirst": fail_first,
		"failLater": fail_later,
		"errors": errors,
		"fails": fails,
		"replyBlind": reply_blind,
		"helped": helped,
		"time": {"n": timed.size(), "median": _median(timed), "medianCorrect": median_correct, "medianWrong": _median(wrong), "rushed": rushed},
	}


# ---------------------------------------------------------------- plan (itinerario)

static func _cand_before(a: Dictionary, b: Dictionary) -> bool:
	var ra := float(a["residual"])
	var rb := float(b["residual"])
	if ra != rb:
		return ra < rb
	return int(a["order"]) < int(b["order"])


## Plan: {target, focus, habits}.
##   target  dificultad de los problemas (la que da la probabilidad de acierto objetivo)
##   focus   como mucho dos dimensiones flojas, de más a menos: {kind: "family", family} | {kind: "mate"} | {kind: "long"}
##   habits  "reply" (mirar la respuesta del rival), "rushed" (no precipitarse), "followThrough" (seguir la variante)
static func plan(rating: Dictionary, pr: Dictionary) -> Dictionary:
	var cands: Array = []
	for f: Dictionary in pr["families"]:
		if status(f) == "weak":
			cands.append({"focus": {"kind": "family", "family": f["family"]}, "residual": f["residual"], "order": 2 + FAMILIES.find(f["family"])})
	if status(pr["mate"]) == "weak":
		cands.append({"focus": {"kind": "mate"}, "residual": pr["mate"]["residual"], "order": 0})
	if status(pr["long"]) == "weak":
		cands.append({"focus": {"kind": "long"}, "residual": pr["long"]["residual"], "order": 1})
	cands.sort_custom(Assessment._cand_before)
	var focus: Array = []
	for i in mini(2, cands.size()):
		focus.append(cands[i]["focus"])
	var habits: Array = []
	if int(pr["fails"]) >= 3 and int(pr["replyBlind"]) * 2 >= int(pr["fails"]):
		habits.append("reply")
	if int(pr["time"]["rushed"]) >= 2:
		habits.append("rushed")
	if int(pr["failLater"]) >= 2 and int(pr["failLater"]) >= int(pr["failFirst"]):
		habits.append("followThrough")
	return {"target": Glicko2.rating_for_success(float(rating["r"]), TARGET_SUCCESS), "focus": focus, "habits": habits}


# ---------------------------------------------------------------- entrenamiento

## Peso de un problema al elegir: más alto si pertenece a una dimensión en la que el jugador rinde menos de lo previsto.
static func training_weight(item: Dictionary, pr: Dictionary, boost: float = 1.5) -> float:
	var lack := 0.0
	for f: Dictionary in pr["families"]:
		if str(f["family"]) == str(item["family"]):
			lack += maxf(0.0, -float(f["residual"]))
			break
	if bool(item["mate"]):
		lack += maxf(0.0, -float(pr["mate"]["residual"]))
	if int(item["steps"]) >= 3:
		lack += maxf(0.0, -float(pr["long"]["residual"]))
	return 1.0 + boost * lack * 5.0


## Elige uno al azar (rand, de 0 a 1), con más probabilidad cuanto mayor es su peso.
static func _weighted_pick(cands: Array, pr: Dictionary, rand: float) -> Dictionary:
	var weights: Array[float] = []
	var total := 0.0
	for p: Dictionary in cands:
		var w := training_weight(p, pr)
		weights.append(w)
		total += w
	var x := rand * total
	for i in cands.size():
		x -= weights[i]
		if x <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


static func _nearer(a: Array, b: Array) -> bool:
	if float(a[0]) != float(b[0]):
		return float(a[0]) < float(b[0])
	return int(a[1]) < int(b[1])


## Siguiente problema del entrenamiento: no visto, cerca de la dificultad objetivo y, entre los que cumplen,
## con más probabilidad los de las dimensiones flojas. {} si ya no quedan problemas sin ver. rand: de 0 a 1.
static func pick_training_item(rating: Dictionary, tries: Array, pool: Array, rand: float) -> Dictionary:
	var seen := {}
	for t: Dictionary in tries:
		seen[t["id"]] = true
	var unseen: Array = []
	for p: Dictionary in pool:
		if not seen.has(p["id"]):
			unseen.append(p)
	if unseen.is_empty():
		return {}
	var target := Glicko2.rating_for_success(float(rating["r"]), TARGET_SUCCESS)
	var pr := profile(tries)
	for window: float in [60.0, 120.0, 200.0, 400.0]:
		var cands: Array = []
		for p: Dictionary in unseen:
			if absf(float(p["rating"]) - target) <= window:
				cands.append(p)
		if cands.size() >= mini(6, unseen.size()):
			return _weighted_pick(cands, pr, rand)
	# No hay bastantes cerca (le pasa a quien queda por debajo o por encima de la muestra): los seis más próximos.
	var order: Array = []
	for i in unseen.size():
		order.append([absf(float(unseen[i]["rating"]) - target), i])
	order.sort_custom(Assessment._nearer)
	var nearest: Array = []
	for i in mini(6, order.size()):
		nearest.append(unseen[int(order[i][1])])
	return _weighted_pick(nearest, pr, rand)


## Repaso: cuando no quedan problemas sin ver, vuelve el que se falló hace más tiempo y no se ha resuelto
## después; si no hay ninguno pendiente, el que hace más que no se ve.
static func pick_review_item(tries: Array, pool: Array) -> Dictionary:
	var last := {}
	for i in tries.size():
		var t: Dictionary = tries[i]
		last[t["id"]] = [i, bool(t["correct"])]
	var best := {}
	var best_key := INF
	for p: Dictionary in pool:
		if not last.has(p["id"]):
			return p
		var l: Array = last[p["id"]]
		var key := float(int(l[0])) + (1e9 if bool(l[1]) else 0.0)
		if key < best_key:
			best_key = key
			best = p
	return best


# ---------------------------------------------------------------- textos

## Tramo de nivel en la escala de problemas de Lichess: {key, name, blurb}. NO equivale a Elo FIDE: no hay
## una tabla de conversión verificada y la app no debe presentarlo como tal.
static func level_band(r: float) -> Dictionary:
	if r < 1000.0:
		return {"key": "beginner", "name": "Principiante", "blurb": "Conoces las reglas. Toca aprender a ver capturas gratis y mates sencillos."}
	if r < 1300.0:
		return {"key": "novice", "name": "Iniciado", "blurb": "Ves amenazas directas. El siguiente paso son los golpes de dos jugadas."}
	if r < 1600.0:
		return {"key": "intermediate", "name": "Intermedio", "blurb": "Reconoces los motivos básicos. Falta calcular con precisión variantes más largas."}
	if r < 1900.0:
		return {"key": "advanced", "name": "Avanzado", "blurb": "Calculas bien. La mejora está en los motivos menos frecuentes y en la defensa."}
	return {"key": "expert", "name": "Experto", "blurb": "Dominas la táctica habitual. Necesitas problemas largos y posiciones estratégicas."}


## Qué pasaba con una jugada equivocada, en pocas palabras (para la lista de fallos del perfil).
static func error_text(kind: String) -> String:
	match kind:
		"mate":
			return "permitía mate"
		"hangMoved":
			return "dejaba a tiro la pieza movida"
		"hangOther":
			return "dejaba otra pieza sin defensa"
		"material":
			return "perdía material en pocas jugadas"
		"worse":
			return "dejaba la posición perdida"
		"missed":
			return "dejaba pasar la ocasión"
		"slower":
			return "ganaba, pero no era la más precisa"
	return ""
