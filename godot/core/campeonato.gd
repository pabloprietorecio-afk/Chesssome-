class_name Campeonato
extends RefCounted
## Modo Campeonato (docs/campeonato.md): una eliminatoria de 8 (cuartos, semifinal y final) contra siete rivales
## inventados, en una sala que sube de categoría con el nivel (de una escuela a un hotel de cinco estrellas).
##
## Los rivales son bots de la app: juegan con el nivel del rival (Bot.LEVELS) más cercano a su Elo y la app lo dice
## siempre. Las otras partidas del cuadro las «juega» la app entre ellos, con un resultado al azar según su Elo.
## Se juega con reloj y sin tutor. La final (tercera ronda) es Premium.
##
## El estado se guarda en user://campeonato.json: {"torneos": {clave: torneo}, "titulos": {clave: veces}}.
## Un torneo: {"cuadro": [8 ids], "elo_tu": n, "ronda": 0–2, "ganadores": [[...], [...], [...]],
## "estado": "en_curso" | "eliminado" | "campeon", "desempate": 0–2, "color": 0/1, "partidas": [...]}.

const PATH := "user://campeonato.json"
const YOU := "tu"
const ROUNDS := ["Cuartos de final", "Semifinal", "Final"]
## La tercera ronda (la final) es Premium (Pablo, 22 nov).
const PREMIUM_ROUND := 2
## Orden del cuadro de 8 por cabezas de serie: 1-8 y 4-5 en una mitad, 2-7 y 3-6 en la otra.
const SEEDING := [0, 7, 3, 4, 1, 6, 2, 5]
## Desempate: tras unas tablas, otra partida con los colores cambiados y más rápida; si vuelve a ser tablas,
## «armagedón»: las negras pasan con tablas.
const TIEBREAK_CLOCK := [5, 3]
const ARMAGEDDON_CLOCK := [4, 2]
## Probabilidad de tablas entre bots (del resultado simulado; si hay tablas, desempate al azar según el Elo).
const BOT_DRAW := 0.15

## Las salas, de la más sencilla a la más elegante; una por grupo de nivel del rival (Bot.GROUPS). «clock»:
## minutos e incremento en segundos. Imágenes en res://campeonato/salas/<clave>_entrada.bin y _pasillo.bin (JPEG).
const TOURNAMENTS := [
	{"key": "escuela", "group": 0, "name": "Torneo de la escuela", "place": "El gimnasio de una escuela", "clock": [10, 5]},
	{"key": "centro_civico", "group": 1, "name": "Torneo del barrio", "place": "La sala del centro cívico", "clock": [10, 5]},
	{"key": "club", "group": 2, "name": "Campeonato del club", "place": "Un club de ajedrez de los de siempre", "clock": [15, 10]},
	{"key": "casino", "group": 3, "name": "Campeonato regional", "place": "El salón de un casino histórico", "clock": [15, 10]},
	{"key": "palacio", "group": 4, "name": "Campeonato nacional", "place": "El salón de baile de un palacio", "clock": [20, 10]},
	# Los rivales del hotel son «Experto» (Stockfish en el móvil), que es de Premium entero: todo el torneo lo es.
	{"key": "hotel", "group": 5, "name": "Gran Torneo Internacional", "place": "El hall de un hotel de cinco estrellas", "clock": [25, 10], "premium_from": 0},
]

## Rivales por sala (personas inventadas, todas adultas). Retrato en res://campeonato/rivales/<sala>/<id>.bin (JPEG).
const RIVALS := {
	"escuela": [
		{"id": "lucia", "name": "Lucía Martín", "age": 34, "from": "Valencia (España)", "job": "Maestra", "bio": "Aprendió a jugar enseñando a sus alumnos.", "elo": 470},
		{"id": "tomas", "name": "Tomás Herrero", "age": 67, "from": "Zaragoza (España)", "job": "Conserje jubilado", "bio": "Lleva cuarenta años jugando en el bar, sin reloj.", "elo": 400},
		{"id": "amara", "name": "Amara Okafor", "age": 19, "from": "Madrid (España)", "job": "Estudiante de Biología", "bio": "Juega rápido y le encanta atacar.", "elo": 330},
		{"id": "kenji", "name": "Kenji Watanabe", "age": 45, "from": "Osaka (Japón)", "job": "Administrativo", "bio": "Empezó para jugar con su hija y se enganchó.", "elo": 280},
		{"id": "sofia", "name": "Sofía Ríos", "age": 52, "from": "Puebla (México)", "job": "Panadera", "bio": "Piensa cada jugada como una receta: sin prisa.", "elo": 210},
		{"id": "marco", "name": "Marco Bianchi", "age": 28, "from": "Turín (Italia)", "job": "Cocinero", "bio": "Le gustan las aperturas raras y los sacrificios.", "elo": 160},
		{"id": "priya", "name": "Priya Nair", "age": 38, "from": "Kochi (India)", "job": "Enfermera", "bio": "Juega entre turnos de noche. Muy ordenada.", "elo": 120},
	],
	"centro_civico": [
		{"id": "jorge", "name": "Jorge Salcedo", "age": 41, "from": "Sevilla (España)", "job": "Conductor de autobús", "bio": "Repasa partidas en el móvil entre parada y parada.", "elo": 1180},
		{"id": "ines", "name": "Inês Duarte", "age": 29, "from": "Oporto (Portugal)", "job": "Bibliotecaria", "bio": "Ha leído todos los libros de ajedrez de su biblioteca.", "elo": 1080},
		{"id": "samuel", "name": "Samuel Mensah", "age": 33, "from": "Acra (Ghana)", "job": "Electricista", "bio": "Paciente y muy difícil de sorprender.", "elo": 980},
		{"id": "elena", "name": "Elena Popescu", "age": 58, "from": "Bucarest (Rumanía)", "job": "Costurera", "bio": "Juega como cose: puntada a puntada.", "elo": 880},
		{"id": "raul", "name": "Raúl Ortega", "age": 24, "from": "Bilbao (España)", "job": "Repartidor", "bio": "Siempre con prisa, también en el tablero.", "elo": 800},
		{"id": "mei", "name": "Mei Chen", "age": 47, "from": "Taipéi (Taiwán)", "job": "Contable", "bio": "Cuenta cada peón dos veces.", "elo": 720},
		{"id": "andre", "name": "André Lefebvre", "age": 70, "from": "Lyon (Francia)", "job": "Cartero jubilado", "bio": "Jugó por correspondencia durante treinta años.", "elo": 660},
	],
	"club": [
		{"id": "carmen", "name": "Carmen Vidal", "age": 61, "from": "Barcelona (España)", "job": "Profesora de matemáticas jubilada", "bio": "Campeona del club tres veces seguidas.", "elo": 1640},
		{"id": "lukas", "name": "Lukas Weber", "age": 36, "from": "Múnich (Alemania)", "job": "Ingeniero", "bio": "Prepara las aperturas como un proyecto.", "elo": 1560},
		{"id": "diego", "name": "Diego Fernández", "age": 27, "from": "Buenos Aires (Argentina)", "job": "Programador", "bio": "Gran jugador de partidas rápidas.", "elo": 1490},
		{"id": "fatima", "name": "Fátima Benali", "age": 31, "from": "Casablanca (Marruecos)", "job": "Farmacéutica", "bio": "Defensas sólidas y finales precisos.", "elo": 1420},
		{"id": "ivan", "name": "Iván Petrov", "age": 55, "from": "Sofía (Bulgaria)", "job": "Taxista", "bio": "Se sabe de memoria cientos de partidas clásicas.", "elo": 1350},
		{"id": "hana", "name": "Hana Kobayashi", "age": 23, "from": "Tokio (Japón)", "job": "Estudiante de Música", "bio": "Juega con ritmo, como si fuera una partitura.", "elo": 1280},
		{"id": "pedro", "name": "Pedro Almeida", "age": 44, "from": "São Paulo (Brasil)", "job": "Arquitecto", "bio": "Construye sus ataques con calma.", "elo": 1210},
	],
	"casino": [
		{"id": "alvaro", "name": "Álvaro de la Vega", "age": 50, "from": "Madrid (España)", "job": "Notario", "bio": "No ha perdido una final del casino en diez años.", "elo": 1850},
		{"id": "natasha", "name": "Natasha Orlova", "age": 39, "from": "Riga (Letonia)", "job": "Profesora de ajedrez", "bio": "Sus alumnos ganan torneos; ella, también.", "elo": 1820},
		{"id": "rahul", "name": "Rahul Mehta", "age": 26, "from": "Bombay (India)", "job": "Analista financiero", "bio": "Calcula variantes muy largas sin pestañear.", "elo": 1790},
		{"id": "claire", "name": "Claire Dubois", "age": 45, "from": "París (Francia)", "job": "Médica", "bio": "Juega tranquila: nunca se precipita.", "elo": 1770},
		{"id": "tiago", "name": "Tiago Mourão", "age": 35, "from": "Lisboa (Portugal)", "job": "Periodista", "bio": "Le encantan las posiciones complicadas.", "elo": 1750},
		{"id": "yuki", "name": "Yuki Tanaka", "age": 30, "from": "Kioto (Japón)", "job": "Traductora", "bio": "Elegante y muy difícil de engañar.", "elo": 1730},
		{"id": "omar", "name": "Omar Haddad", "age": 57, "from": "Beirut (Líbano)", "job": "Joyero", "bio": "Pule cada ventaja hasta el final.", "elo": 1700},
	],
	"palacio": [
		{"id": "sebastian", "name": "Sebastián Morales", "age": 32, "from": "Santiago (Chile)", "job": "Maestro FIDE", "bio": "Campeón de su país en partidas rápidas.", "elo": 1960},
		{"id": "anna", "name": "Anna Kowalska", "age": 28, "from": "Cracovia (Polonia)", "job": "Maestra internacional femenina", "bio": "Ataques directos al rey.", "elo": 1945},
		{"id": "david", "name": "David Levin", "age": 48, "from": "Haifa (Israel)", "job": "Profesor universitario", "bio": "Estudia cada partida como un problema de lógica.", "elo": 1930},
		{"id": "valentina", "name": "Valentina Ferri", "age": 34, "from": "Milán (Italia)", "job": "Entrenadora", "bio": "Prepara a la selección juvenil de su región.", "elo": 1920},
		{"id": "kwame", "name": "Kwame Asante", "age": 37, "from": "Kumasi (Ghana)", "job": "Ingeniero de software", "bio": "Aprendió solo, con libros y paciencia.", "elo": 1905},
		{"id": "erik", "name": "Erik Lindqvist", "age": 52, "from": "Estocolmo (Suecia)", "job": "Compositor", "bio": "Busca la belleza en cada combinación.", "elo": 1890},
		{"id": "leila", "name": "Leila Karimi", "age": 29, "from": "Shiraz (Irán)", "job": "Arquitecta", "bio": "Estructuras sólidas y golpes inesperados.", "elo": 1880},
	],
	"hotel": [
		{"id": "viktor", "name": "Viktor Sokol", "age": 35, "from": "Praga (Chequia)", "job": "Gran maestro", "bio": "Favorito del torneo. Casi nunca pierde con blancas.", "elo": 2700},
		{"id": "mariana", "name": "Mariana Costa", "age": 30, "from": "Río de Janeiro (Brasil)", "job": "Gran maestra", "bio": "Juego agresivo y muy creativo.", "elo": 2620},
		{"id": "arjun", "name": "Arjun Rao", "age": 22, "from": "Chennai (India)", "job": "Gran maestro", "bio": "Joven prodigio: calcula más rápido que nadie.", "elo": 2560},
		{"id": "sophie", "name": "Sophie Laurent", "age": 41, "from": "Ginebra (Suiza)", "job": "Maestra internacional", "bio": "Experta en finales.", "elo": 2480},
		{"id": "daisuke", "name": "Daisuke Hara", "age": 46, "from": "Nagoya (Japón)", "job": "Gran maestro", "bio": "Paciente como nadie: espera tu error.", "elo": 2400},
		{"id": "isabel", "name": "Isabel Navarro", "age": 27, "from": "Granada (España)", "job": "Maestra internacional", "bio": "La gran promesa del ajedrez español.", "elo": 2280},
		{"id": "lin", "name": "Lin Mingzhe", "age": 38, "from": "Shanghái (China)", "job": "Maestro FIDE", "bio": "Aperturas muy preparadas.", "elo": 2150},
	],
}


# --- Datos ---

static func tournament(key: String) -> Dictionary:
	for t: Dictionary in TOURNAMENTS:
		if str(t["key"]) == key:
			return t
	return {}


static func index_of(key: String) -> int:
	for i in TOURNAMENTS.size():
		if str(TOURNAMENTS[i]["key"]) == key:
			return i
	return -1


static func rival(key: String, id: String) -> Dictionary:
	for r: Dictionary in RIVALS.get(key, []):
		if str(r["id"]) == id:
			return r
	return {}


## Nivel del rival de la app (Bot.LEVELS) con el que juega un rival: el de su grupo con el Elo más cercano.
## «Experto» (Stockfish en el móvil): por el Elo de Stockfish.
static func level_for(key: String, id: String) -> int:
	var t := tournament(key)
	var r := rival(key, id)
	if t.is_empty() or r.is_empty():
		return 0
	var best := -1
	var gap := INF
	for lv: int in Bot.group_levels(int(t["group"])):
		var cfg: Dictionary = Bot.LEVELS[lv]
		var e := float(cfg.get("sf_elo", cfg.get("elo", 0.0))) if cfg.has("sf_elo") else float(cfg.get("elo", 0.0))
		if cfg.has("sf_elo") and int(cfg["sf_elo"]) == 0:
			continue
		var d := absf(e - float(r["elo"]))
		if d < gap:
			gap = d
			best = lv
	return best if best >= 0 else Bot.group_levels(int(t["group"]))[0]


## Elo con el que entra el jugador al cuadro: su nivel de juego; sin partidas, el del rival más flojo de la sala.
static func elo_of(key: String, id: String, you_elo: float) -> float:
	if id == YOU:
		return you_elo
	return float(rival(key, id).get("elo", 0))


# --- Estado ---

static func load_state(path: String = PATH) -> Dictionary:
	var st := {"torneos": {}, "titulos": {}}
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			st["torneos"] = (data as Dictionary).get("torneos", {})
			st["titulos"] = (data as Dictionary).get("titulos", {})
	return st


static func save_state(st: Dictionary, path: String = PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(st))


## Sala abierta: la primera siempre; las demás, al ganar la anterior o si tu nivel de juego llega al Elo del rival
## más flojo de esa sala.
static func unlocked(st: Dictionary, key: String, you_elo: float) -> bool:
	var i := index_of(key)
	if i <= 0:
		return i == 0
	if int((st.get("titulos", {}) as Dictionary).get(str(TOURNAMENTS[i - 1]["key"]), 0)) > 0:
		return true
	var weakest := INF
	for r: Dictionary in RIVALS.get(key, []):
		weakest = minf(weakest, float(r["elo"]))
	return you_elo >= weakest


## Empieza (o vuelve a empezar) el torneo de una sala.
static func start(st: Dictionary, key: String, you_elo: float, rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array = [YOU]
	for r: Dictionary in RIVALS.get(key, []):
		ids.append(str(r["id"]))
	# Cabezas de serie por Elo (con un poco de azar para el jugador: no siempre cae en el mismo sitio).
	var noisy := you_elo + rng.randf_range(-60.0, 60.0)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return (noisy if a == YOU else elo_of(key, a, you_elo)) > (noisy if b == YOU else elo_of(key, b, you_elo)))
	var cuadro: Array = []
	for s: int in SEEDING:
		cuadro.append(ids[s])
	var t := {"cuadro": cuadro, "elo_tu": you_elo, "ronda": 0, "ganadores": [[], [], []], "estado": "en_curso",
		"desempate": 0, "color": rng.randi_range(0, 1), "partidas": []}
	(st["torneos"] as Dictionary)[key] = t
	return t


## Los participantes de una ronda, en orden de cuadro (8, 4 o 2).
static func players_in(t: Dictionary, round_i: int) -> Array:
	if round_i <= 0:
		return (t["cuadro"] as Array).duplicate()
	return ((t["ganadores"] as Array)[round_i - 1] as Array).duplicate()


## Emparejamientos de una ronda: [[a, b], …].
static func pairs(t: Dictionary, round_i: int) -> Array:
	var p := players_in(t, round_i)
	var out: Array = []
	for i in range(0, p.size() - 1, 2):
		out.append([p[i], p[i + 1]])
	return out


## Tu partida de la ronda en curso: {rival, ronda, color, clock, level, desempate}. Vacío si no te toca jugar.
static func current_match(t: Dictionary, key: String) -> Dictionary:
	if str(t.get("estado", "")) != "en_curso":
		return {}
	var r := int(t["ronda"])
	for pr: Array in pairs(t, r):
		if pr.has(YOU):
			var other := str(pr[1] if pr[0] == YOU else pr[0])
			var tb := int(t.get("desempate", 0))
			var clock: Array = tournament(key)["clock"]
			if tb == 1:
				clock = TIEBREAK_CLOCK
			elif tb >= 2:
				clock = ARMAGEDDON_CLOCK
			return {"rival": other, "ronda": r, "color": int(t.get("color", 0)), "clock": clock,
				"level": level_for(key, other), "desempate": tb}
	return {}


## Primera ronda de Premium de una sala: la final (en el hotel, todas).
static func premium_from(key: String) -> int:
	return int(tournament(key).get("premium_from", PREMIUM_ROUND))


## Hace falta Premium para jugar la ronda en curso.
static func needs_premium(t: Dictionary, premium: bool, key: String = "") -> bool:
	var first := premium_from(key) if key != "" else PREMIUM_ROUND
	return not premium and str(t.get("estado", "")) == "en_curso" and int(t.get("ronda", 0)) >= first


## Resultado al azar de una partida entre dos rivales (puntuación esperada de Elo; con tablas, desempate al azar).
static func simulate(a_elo: float, b_elo: float, rng: RandomNumberGenerator) -> int:
	var e := 1.0 / (1.0 + pow(10.0, (b_elo - a_elo) / 400.0))
	var x := rng.randf()
	if absf(x - e) < BOT_DRAW / 2.0:
		return 0 if rng.randf() < e else 1
	return 0 if x < e else 1


## Apunta tu resultado (1 ganas, 0.5 tablas, 0 pierdes). Con tablas, desempate (colores cambiados); en el
## armagedón las tablas valen para las negras. Cuando la eliminatoria se decide, se juegan las otras partidas de
## la ronda y se pasa a la siguiente. Devuelve {decided, won, tiebreak, estado}.
static func record(st: Dictionary, key: String, score: float, rng: RandomNumberGenerator) -> Dictionary:
	var t: Dictionary = (st["torneos"] as Dictionary).get(key, {})
	var m := current_match(t, key)
	if m.is_empty():
		return {}
	(t["partidas"] as Array).append({"ronda": int(m["ronda"]), "rival": m["rival"], "color": int(m["color"]),
		"desempate": int(m["desempate"]), "puntos": score})
	var won := false
	if score > 0.75:
		won = true
	elif score > 0.25:
		if int(m["desempate"]) >= 2:
			won = int(m["color"]) == 1
		else:
			t["desempate"] = int(m["desempate"]) + 1
			t["color"] = 1 - int(m["color"])
			return {"decided": false, "won": false, "tiebreak": int(t["desempate"]), "estado": "en_curso"}
	t["desempate"] = 0
	var r := int(t["ronda"])
	var winners: Array = []
	for pr: Array in pairs(t, r):
		if pr.has(YOU):
			winners.append(YOU if won else str(pr[1] if pr[0] == YOU else pr[0]))
		else:
			var w := simulate(elo_of(key, str(pr[0]), 0.0), elo_of(key, str(pr[1]), 0.0), rng)
			winners.append(str(pr[w]))
	(t["ganadores"] as Array)[r] = winners
	if not won:
		t["estado"] = "eliminado"
		# El resto del cuadro sigue hasta el final, para enseñar quién ganó.
		for rr in range(r + 1, ROUNDS.size()):
			var ws: Array = []
			for pr: Array in pairs(t, rr):
				ws.append(str(pr[simulate(elo_of(key, str(pr[0]), 0.0), elo_of(key, str(pr[1]), 0.0), rng)]))
			(t["ganadores"] as Array)[rr] = ws
	elif r >= ROUNDS.size() - 1:
		t["estado"] = "campeon"
		var titles: Dictionary = st["titulos"]
		titles[key] = int(titles.get(key, 0)) + 1
	else:
		t["ronda"] = r + 1
		# El color se alterna de una ronda a la siguiente.
		var last := int((t["partidas"] as Array)[-1]["color"])
		t["color"] = 1 - last
	return {"decided": true, "won": won, "tiebreak": 0, "estado": str(t["estado"])}


## Ganador del torneo (vacío si aún no se sabe).
static func champion(t: Dictionary) -> String:
	var last: Array = (t.get("ganadores", [[], [], []]) as Array)[ROUNDS.size() - 1]
	return str(last[0]) if not last.is_empty() else ""


## Nombre para mostrar de un participante.
static func display_name(key: String, id: String) -> String:
	return Loc.t("Tú") if id == YOU else str(rival(key, id).get("name", id))


## Retrato de un rival (vacío si aún no está en la app).
static func portrait_path(key: String, id: String) -> String:
	return "res://campeonato/rivales/%s/%s.bin" % [key, id]


static func room_path(key: String, shot: String) -> String:
	return "res://campeonato/salas/%s_%s.bin" % [key, shot]
