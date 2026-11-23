class_name Campeonato
extends RefCounted
## Modo Campeonato (docs/campeonato.md): un torneo contra rivales inventados, en una sala que sube de categoría con
## el nivel (de una escuela a un hotel de cinco estrellas). El jugador elige el formato (FORMATS) y el ritmo de
## partida (siempre con reloj).
##
## Los rivales son bots de la app: juegan con el nivel del rival (Bot.LEVELS) más cercano a su Elo y la app lo dice
## siempre. Las otras partidas las «juega» la app entre ellos, con un resultado al azar según su Elo.
## Se juega con reloj y sin tutor. Desde la tercera ronda es Premium.
##
## El estado se guarda en user://campeonato.json: {"torneos": {clave: torneo}, "titulos": {clave: veces},
## "ultimo": {"formato": id, "ritmo": …}}.
## Un torneo: {"formato": id, "ritmo": [min, inc], "cuadro": [ids], "elo_tu": n, "ronda": n,
## "estado": "en_curso" | "eliminado" | "terminado" | "campeon", "desempate": 0–2, "color": 0/1, "partidas": [...]}.
## Eliminatorias (copa, copa con mini-match): "ganadores": [[...], [...], [...]]; en el mini-match, "juego" (0/1) y
## "marcador" (tus puntos en el cruce). Con tabla (cuadrangular, liga, suizo): "rondas": [[[a, b], …], …],
## "res": [{r, a, b, pa}] (pa = puntos de a) y, al acabar, "clasificacion": [ids] y "puesto".

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

## Formatos de torneo. «players»: jugadores; «rounds»: rondas; «table»: con clasificación por puntos (si no, eliminatoria).
## «games»: partidas que juegas como mucho (para el texto).
const FORMATS := [
	{"id": "copa", "name": "Copa", "icon": "crown", "players": 8, "rounds": 3, "table": false, "games": "3",
		"about": "Ocho jugadores. Cada cruce es una partida y quien pierde queda fuera: tres partidas si vas ganando."},
	{"id": "copa_match", "name": "Copa con mini-match", "icon": "flag", "players": 8, "rounds": 3, "table": false, "games": "6",
		"about": "Ocho jugadores. Cada cruce son dos partidas, una con cada color. Si empatáis, desempate rápido."},
	{"id": "cuadrangular", "name": "Cuadrangular", "icon": "users", "players": 4, "rounds": 3, "table": true, "games": "3",
		"about": "Cuatro jugadores (tú y tres rivales de la sala), todos contra todos: tres partidas. Gana quien sume más puntos."},
	{"id": "suizo", "name": "Suizo", "icon": "rows", "players": 8, "rounds": 5, "table": true, "games": "5",
		"about": "Ocho jugadores y cinco rondas contra rivales con puntos parecidos. Nadie queda eliminado."},
	{"id": "liga", "name": "Liga", "icon": "tiles", "players": 8, "rounds": 7, "table": true, "games": "7",
		"about": "Ocho jugadores, todos contra todos: siete partidas. Gana quien sume más puntos."},
]

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


## Definición de un formato (vacía si no existe).
static func format_def(id: String) -> Dictionary:
	for f: Dictionary in FORMATS:
		if str(f["id"]) == id:
			return f
	return {}


## Formato de un torneo (los guardados sin formato son copas de una partida).
static func format_of(t: Dictionary) -> String:
	var id := str(t.get("formato", "copa"))
	return id if not format_def(id).is_empty() else "copa"


## Con clasificación por puntos (cuadrangular, suizo, liga) o eliminatoria (copa).
static func is_table(t: Dictionary) -> bool:
	return bool(format_def(format_of(t)).get("table", false))


static func round_count(t: Dictionary) -> int:
	return int(format_def(format_of(t))["rounds"])


## Reloj del torneo: el elegido y, si no lo hay (torneos antiguos), el de la sala.
static func base_clock(t: Dictionary, key: String) -> Array:
	var c: Variant = t.get("ritmo", null)
	if c is Array and (c as Array).size() == 2 and int((c as Array)[0]) > 0:
		return [int((c as Array)[0]), int((c as Array)[1])]
	var room: Array = tournament(key).get("clock", [10, 5])
	return [int(room[0]), int(room[1])]


## Desempate y armagedón: más rápidos que la partida, salvo que ya sea un ritmo rápido.
static func tiebreak_clock(base: Array) -> Array:
	return base if int(base[0]) <= int(TIEBREAK_CLOCK[0]) else TIEBREAK_CLOCK


static func armageddon_clock(base: Array) -> Array:
	return base if int(base[0]) <= int(ARMAGEDDON_CLOCK[0]) else ARMAGEDDON_CLOCK


## Nombre de una ronda: «Cuartos de final», «Semifinal», «Final» en las copas; «Ronda 3» en los demás.
static func round_title(t: Dictionary, round_i: int) -> String:
	if not is_table(t):
		return Loc.t(str(ROUNDS[clampi(round_i, 0, ROUNDS.size() - 1)]))
	return Loc.f("Ronda %d", round_i + 1)


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
	var st := {"torneos": {}, "titulos": {}, "ultimo": {}}
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			st["torneos"] = (data as Dictionary).get("torneos", {})
			st["titulos"] = (data as Dictionary).get("titulos", {})
			st["ultimo"] = (data as Dictionary).get("ultimo", {})
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


## Empieza (o vuelve a empezar) el torneo de una sala, con el formato y el ritmo [minutos, incremento] elegidos
## (sin ritmo, el de la sala).
static func start(st: Dictionary, key: String, you_elo: float, rng: RandomNumberGenerator, formato: String = "copa", ritmo: Array = []) -> Dictionary:
	if format_def(formato).is_empty():
		formato = "copa"
	var fmt := format_def(formato)
	var rivals: Array = []
	for r: Dictionary in RIVALS.get(key, []):
		rivals.append(str(r["id"]))
	var n := int(fmt["players"])
	if rivals.size() > n - 1:
		# Menos rivales que los siete: de los más cercanos a tu nivel, con algo de azar.
		rivals.sort_custom(func(a: String, b: String) -> bool:
			return absf(elo_of(key, a, 0.0) - you_elo) < absf(elo_of(key, b, 0.0) - you_elo))
		var pool: Array = rivals.slice(0, mini(rivals.size(), n + 1))
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Variant = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		rivals = pool.slice(0, n - 1)
	var ids: Array = [YOU]
	ids.append_array(rivals)
	# Cabezas de serie por Elo (con un poco de azar para el jugador: no siempre cae en el mismo sitio).
	var noisy := you_elo + rng.randf_range(-60.0, 60.0)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return (noisy if a == YOU else elo_of(key, a, you_elo)) > (noisy if b == YOU else elo_of(key, b, you_elo)))
	var cuadro: Array = []
	if bool(fmt["table"]):
		cuadro = ids
	else:
		for s: int in SEEDING:
			cuadro.append(ids[s])
	var clock: Array = ritmo if ritmo.size() == 2 and int(ritmo[0]) > 0 else (tournament(key)["clock"] as Array).duplicate()
	var t := {"formato": formato, "ritmo": [int(clock[0]), int(clock[1])], "cuadro": cuadro, "elo_tu": you_elo, "ronda": 0,
		"ganadores": [] if bool(fmt["table"]) else [[], [], []], "estado": "en_curso", "desempate": 0, "juego": 0,
		"marcador": 0.0, "color": rng.randi_range(0, 1), "partidas": [], "rondas": [], "res": []}
	if bool(fmt["table"]):
		if formato == "suizo":
			(t["rondas"] as Array).append(swiss_pairs(t, key))
		else:
			t["rondas"] = round_robin(cuadro)
	(st["torneos"] as Dictionary)[key] = t
	return t


## Todos contra todos (método del círculo): n − 1 rondas de n / 2 cruces.
static func round_robin(ids: Array) -> Array:
	var n := ids.size()
	var ring := ids.duplicate()
	var out: Array = []
	for _r in n - 1:
		var round_pairs: Array = []
		for i in n / 2:
			round_pairs.append([ring[i], ring[n - 1 - i]])
		out.append(round_pairs)
		var last: Variant = ring.pop_back()
		ring.insert(1, last)
	return out


static func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## Cruces de la siguiente ronda del suizo: la primera, mitad alta contra mitad baja por Elo; las demás, por
## puntos, sin repetir rival.
static func swiss_pairs(t: Dictionary, key: String) -> Array:
	var ids: Array = (t["cuadro"] as Array).duplicate()
	var you_elo := float(t.get("elo_tu", 0.0))
	var pts := scores(t)
	ids.sort_custom(func(a: String, b: String) -> bool:
		if not is_equal_approx(float(pts[a]), float(pts[b])):
			return float(pts[a]) > float(pts[b])
		return elo_of(key, a, you_elo) > elo_of(key, b, you_elo))
	var out: Array = []
	if (t["res"] as Array).is_empty():
		for i in ids.size() / 2:
			out.append([ids[i], ids[i + ids.size() / 2]])
		return out
	var played := {}
	for g: Dictionary in t["res"]:
		played[_pair_key(str(g["a"]), str(g["b"]))] = true
	var found: Variant = _swiss_fill(ids, played)
	if found != null:
		return found as Array
	for i in range(0, ids.size() - 1, 2):
		out.append([ids[i], ids[i + 1]])
	return out


static func _swiss_fill(ids: Array, played: Dictionary) -> Variant:
	if ids.is_empty():
		return []
	var a: String = ids[0]
	for i in range(1, ids.size()):
		var b: String = ids[i]
		if played.has(_pair_key(a, b)):
			continue
		var rest := ids.duplicate()
		rest.remove_at(i)
		rest.remove_at(0)
		var tail: Variant = _swiss_fill(rest, played)
		if tail != null:
			var out: Array = [[a, b]]
			out.append_array(tail as Array)
			return out
	return null


## Puntos de cada participante en un torneo con tabla.
static func scores(t: Dictionary) -> Dictionary:
	var pts := {}
	for id: String in t["cuadro"]:
		pts[id] = 0.0
	for g: Dictionary in t.get("res", []):
		pts[str(g["a"])] = float(pts.get(str(g["a"]), 0.0)) + float(g["pa"])
		pts[str(g["b"])] = float(pts.get(str(g["b"]), 0.0)) + 1.0 - float(g["pa"])
	return pts


## Clasificación: por puntos, luego Sonneborn-Berger (puntos de los rivales a los que has ganado, y la mitad de los
## de los que has empatado); si siguen igualados, el jugador antes y luego el Elo. [{id, pts, sb}]
static func standings(t: Dictionary, key: String) -> Array:
	var pts := scores(t)
	var sb := {}
	for id: String in pts:
		sb[id] = 0.0
	for g: Dictionary in t.get("res", []):
		var a := str(g["a"])
		var b := str(g["b"])
		sb[a] = float(sb[a]) + float(g["pa"]) * float(pts[b])
		sb[b] = float(sb[b]) + (1.0 - float(g["pa"])) * float(pts[a])
	var out: Array = []
	for id: String in pts:
		out.append({"id": id, "pts": float(pts[id]), "sb": float(sb[id])})
	var you_elo := float(t.get("elo_tu", 0.0))
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if not is_equal_approx(float(x["pts"]), float(y["pts"])):
			return float(x["pts"]) > float(y["pts"])
		if not is_equal_approx(float(x["sb"]), float(y["sb"])):
			return float(x["sb"]) > float(y["sb"])
		if (x["id"] == YOU) != (y["id"] == YOU):
			return x["id"] == YOU
		return elo_of(key, str(x["id"]), you_elo) > elo_of(key, str(y["id"]), you_elo))
	return out


## Los participantes de una ronda (eliminatoria), en orden de cuadro (8, 4 o 2).
static func players_in(t: Dictionary, round_i: int) -> Array:
	if round_i <= 0:
		return (t["cuadro"] as Array).duplicate()
	return ((t["ganadores"] as Array)[round_i - 1] as Array).duplicate()


## Emparejamientos de una ronda: [[a, b], …].
static func pairs(t: Dictionary, round_i: int) -> Array:
	if is_table(t):
		var rs: Array = t.get("rondas", [])
		return (rs[round_i] as Array).duplicate(true) if round_i >= 0 and round_i < rs.size() else []
	var p := players_in(t, round_i)
	var out: Array = []
	for i in range(0, p.size() - 1, 2):
		out.append([p[i], p[i + 1]])
	return out


## Tu partida de la ronda en curso: {rival, ronda, color, clock, level, desempate, juego, juegos, marcador, titulo}.
## Vacío si no te toca jugar. «juegos» es 2 en el mini-match (y «juego», cuál de las dos).
static func current_match(t: Dictionary, key: String) -> Dictionary:
	if str(t.get("estado", "")) != "en_curso":
		return {}
	var r := int(t["ronda"])
	for pr: Array in pairs(t, r):
		if pr.has(YOU):
			var other := str(pr[1] if pr[0] == YOU else pr[0])
			var tb := int(t.get("desempate", 0))
			var clock: Array = base_clock(t, key)
			if tb == 1:
				clock = tiebreak_clock(clock)
			elif tb >= 2:
				clock = armageddon_clock(clock)
			var games := 2 if format_of(t) == "copa_match" and tb == 0 else 1
			var game_i := int(t.get("juego", 0)) if games == 2 else 0
			var title := round_title(t, r) + (" · %d/2" % (game_i + 1) if games == 2 else "")
			return {"rival": other, "ronda": r, "color": int(t.get("color", 0)), "clock": clock,
				"level": level_for(key, other), "desempate": tb, "juego": game_i, "juegos": games,
				"marcador": float(t.get("marcador", 0.0)), "titulo": title}
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


## Resultado al azar de una partida con tablas posibles: 1 gana a, 0,5 tablas, 0 gana b.
static func simulate_score(a_elo: float, b_elo: float, rng: RandomNumberGenerator) -> float:
	var e := 1.0 / (1.0 + pow(10.0, (b_elo - a_elo) / 400.0))
	var x := rng.randf()
	if absf(x - e) < BOT_DRAW / 2.0:
		return 0.5
	return 1.0 if x < e else 0.0


## Apunta tu resultado (1 ganas, 0.5 tablas, 0 pierdes) y juega las otras partidas de la ronda.
## Eliminatoria: con tablas, desempate (colores cambiados); en el armagedón las tablas valen para las negras; en el
## mini-match son dos partidas y el desempate llega solo si empatáis a un punto. Con tabla: las tablas son tablas
## y al acabar las rondas se cierra la clasificación.
## Devuelve {decided, won, tiebreak, estado} y, según el caso, {mini, marcador} o {tabla, puesto}.
static func record(st: Dictionary, key: String, score: float, rng: RandomNumberGenerator) -> Dictionary:
	var t: Dictionary = (st["torneos"] as Dictionary).get(key, {})
	var m := current_match(t, key)
	if m.is_empty():
		return {}
	(t["partidas"] as Array).append({"ronda": int(m["ronda"]), "rival": m["rival"], "color": int(m["color"]),
		"desempate": int(m["desempate"]), "puntos": score})
	if is_table(t):
		return _record_table(st, key, t, m, score, rng)
	return _record_knockout(st, key, t, m, score, rng)


static func _record_table(st: Dictionary, key: String, t: Dictionary, m: Dictionary, score: float, rng: RandomNumberGenerator) -> Dictionary:
	var r := int(t["ronda"])
	var res: Array = t["res"]
	res.append({"r": r, "a": YOU, "b": str(m["rival"]), "pa": score})
	for pr: Array in pairs(t, r):
		if not pr.has(YOU):
			res.append({"r": r, "a": str(pr[0]), "b": str(pr[1]),
				"pa": simulate_score(elo_of(key, str(pr[0]), 0.0), elo_of(key, str(pr[1]), 0.0), rng)})
	if r >= round_count(t) - 1:
		var table := standings(t, key)
		var order: Array = []
		for row: Dictionary in table:
			order.append(str(row["id"]))
		t["clasificacion"] = order
		t["puesto"] = order.find(YOU) + 1
		var top: Dictionary = table[0]
		var mine: Dictionary = table[order.find(YOU)]
		var champ := is_equal_approx(float(mine["pts"]), float(top["pts"])) and is_equal_approx(float(mine["sb"]), float(top["sb"]))
		t["estado"] = "campeon" if champ else "terminado"
		if champ:
			var titles: Dictionary = st["titulos"]
			titles[key] = int(titles.get(key, 0)) + 1
		return {"decided": true, "won": champ, "tiebreak": 0, "estado": str(t["estado"]), "tabla": true, "puesto": int(t["puesto"])}
	t["ronda"] = r + 1
	t["color"] = 1 - int(m["color"])
	if format_of(t) == "suizo":
		(t["rondas"] as Array).append(swiss_pairs(t, key))
	return {"decided": true, "won": score > 0.75, "tiebreak": 0, "estado": "en_curso", "tabla": true, "puesto": 0}


static func _record_knockout(st: Dictionary, key: String, t: Dictionary, m: Dictionary, score: float, rng: RandomNumberGenerator) -> Dictionary:
	var won := false
	if int(m["juegos"]) == 2:
		# Mini-match: dos partidas, una con cada color.
		if int(m["juego"]) == 0:
			t["marcador"] = score
			t["juego"] = 1
			t["color"] = 1 - int(m["color"])
			return {"decided": false, "won": false, "tiebreak": 0, "mini": 1, "marcador": score, "estado": "en_curso"}
		var total := float(t.get("marcador", 0.0)) + score
		t["juego"] = 0
		t["marcador"] = 0.0
		if is_equal_approx(total, 1.0):
			t["desempate"] = 1
			t["color"] = 1 - int(m["color"])
			return {"decided": false, "won": false, "tiebreak": 1, "mini": 2, "marcador": total, "estado": "en_curso"}
		won = total > 1.0
	elif score > 0.75:
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
	var last_round := round_count(t) - 1
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
		for rr in range(r + 1, last_round + 1):
			var ws: Array = []
			for pr: Array in pairs(t, rr):
				ws.append(str(pr[simulate(elo_of(key, str(pr[0]), 0.0), elo_of(key, str(pr[1]), 0.0), rng)]))
			(t["ganadores"] as Array)[rr] = ws
	elif r >= last_round:
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
	if is_table(t):
		var order: Array = t.get("clasificacion", [])
		return str(order[0]) if not order.is_empty() else ""
	var winners: Array = t.get("ganadores", [[], [], []])
	var last: Array = winners[round_count(t) - 1]
	return str(last[0]) if not last.is_empty() else ""


## Nombre para mostrar de un participante.
static func display_name(key: String, id: String) -> String:
	return Loc.t("Tú") if id == YOU else str(rival(key, id).get("name", id))


## Retrato de un rival (vacío si aún no está en la app).
static func portrait_path(key: String, id: String) -> String:
	return "res://campeonato/rivales/%s/%s.bin" % [key, id]


static func room_path(key: String, shot: String) -> String:
	return "res://campeonato/salas/%s_%s.bin" % [key, shot]
