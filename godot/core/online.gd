class_name Online
extends Node
## Partida online con Firebase Realtime Database (REST + escucha en directo SSE), sin complementos.
##   espera/<id>     {creador, latido, ritmo, no/<uid>}      partidas que esperan rival, por espacio (ritmo)
##   partidas/<id>   {creador, ritmo, rival, unidoEn, listo, jugadas/<n>, pulsos/<n>, fin, perfiles, gestos}
##   denuncias/<id>  {de, contra, nombre, partida, motivo, t}  solo se escriben (se leen en la consola)
## Espacios: cada partida tiene un ritmo «minutos+segundos por jugada» («0+0», sin reloj). Entrar en un espacio =
## unirse a la partida más antigua y viva de ese ritmo (lo decide la base de datos, atómicamente) o abrir una y
## esperar. Si dos abren a la vez, el de la partida más reciente se une a la más antigua.
## Reloj: cada pulsación (pulsos/<n>, tras la jugada n) lleva la hora del servidor; con ellas los dos calculan lo
## mismo. Quien se pasa de tiempo pierde: lo apunta cualquiera de los dos en «fin» (el primero que llega vale).
## «no/<uid>»: jugadores que el creador ha bloqueado (no se unen a su partida).
## «listo»: quien esperaba ha visto entrar al rival (puede que tuviera la app minimizada y vuelva al tocar el aviso).
## Hasta entonces no empieza la partida ni corre el reloj; si no vuelve en JOIN_WAIT_MS, el que entró se va y sigue
## buscando.
## La web (src/online) usaba «abiertas»: ya no se empareja con la app.
## Colores: 0 blancas, 1 negras (como en Chess).

signal started(color: int)
## Me he unido a una partida, pero quien esperaba aún no ha vuelto a la app (rival: su perfil, si ha llegado).
signal matched
## Quien esperaba no volvió a tiempo: sigo buscando en el mismo espacio.
signal retry
signal move_received(uci: String)
## Cambió el reloj de la partida (una pulsación nueva).
signal clock_changed
signal ended(reason: String, winner: int)
signal failed(message: String)
## Lo que enseña el rival (nivel, icono, foto en base64), cuando llega.
signal rival_profile(profile: Dictionary)
## Un gesto del chat (mine: si lo mandé yo).
signal gesture(mine: bool, kind: String)
signal _auth_done

const API_KEY := "AIzaSyDCBUYJqrn1Q6AKB9rA5eSBzIUw3dpTWe4"
const DB_HOST := "a-chess-way-default-rtdb.europe-west1.firebasedatabase.app"
const SAVE_PATH := "user://chessome_online.cfg"
const MARGIN := 300.0
const HEARTBEAT := 10.0
const SCAN := 3.0
const FRESH_MS := 30000.0
## Tras el final se deja un rato la partida (para los gestos de «buena partida»); después se borra.
const CLEANUP := 30.0
## «¿Sigues ahí?» (Pablo, 16 nov): a quien le toca y no juega se le pregunta pasado idle_limit_ms (relativo al
## ritmo); tiene IDLE_ANSWER_MS para contestar y, con IDLE_GRACE_MS más de margen por la red, su rival puede dar la
## partida por ganada. Así nadie espera hasta que se acabe un reloj de 30 minutos (o para siempre, sin reloj).
const IDLE_ANSWER_MS := 30000.0
const IDLE_GRACE_MS := 15000.0
const IDLE_UNTIMED_MS := 180000.0
const MONTHS := {"Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6, "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12}

## Gestos del chat: solo estos, sin texto libre.
## «tiempo» («¡Tu tiempo!»): para meter prisa al rival cuando le toca; tiene su propio botón, no va en la fila.
const GESTURES := ["saludo", "aplauso", "genial", "arriba", "abajo", "buena", "tiempo"]
const GESTURE_TEXT := {"saludo": "¡Hola!", "aplauso": "¡Bravo!", "genial": "¡Genial!", "arriba": "Bien", "abajo": "Vaya", "buena": "Buena partida", "tiempo": "¡Tu tiempo!"}
## Espacios fijos (ritmos); además, cada uno puede abrir el suyo (personalizado).
const SPACES := ["0+0", "5+3", "10+5", "15+10", "20+0", "30+0"]
## Ritmo válido (igual que en las reglas de la base de datos): «0+0» o de 1 a 180 minutos y de 0 a 60 segundos.
## Con una «w» delante, el espacio es de War Chess («w5+3»): son espacios aparte, así que nunca se juntan una partida
## clásica y una de War Chess (y las versiones de la app sin War Chess no los ven: su expresión no admite la «w»).
const RHYTHM_RE := "^w?(0\\+0|([1-9]|[1-9][0-9]|1[0-7][0-9]|180)\\+([0-9]|[1-5][0-9]|60))$"
## Al rival que no pulsa a tiempo se le da por perdido este margen después (su pulsación puede venir de camino).
const FLAG_GRACE_MS := 3000.0
## Lo que se espera a que vuelva quien esperaba con la app minimizada.
const JOIN_WAIT_MS := 60000.0
## Motivos de denuncia (como en las reglas).
const REPORT_REASONS := ["nombre", "trampas", "abandono", "conducta", "otro"]

## idle, searching, waiting, playing, ended
var phase := "idle"
## Lo que se enseña al rival: {"nivel": −1…10, "icono": "piece_…", "foto": base64 (solo si se quiere)}.
var my_profile := {"nivel": -1}
## Nivel de juego propio ({r, rd, n}; vacío si no hay). Va aparte del perfil: si las reglas de Firebase todavía no
## lo admiten, falla solo esa escritura y el perfil (nombre, nivel, icono) llega igual.
var my_game_rating := {}
var rival := {}
## Identificador anónimo del rival (el mismo en cada partida desde su móvil): sirve para reconocerlo después.
var rival_uid := ""
var _rival_json := ""
var _seen_gestures := {}
var _last_gesture := 0
var uid := ""
var game_id := ""
var my_color := -1
## Ritmo del espacio elegido y, en la partida, el reloj (ms) que sale de él.
var rhythm := "0+0"
var base_ms := 0.0
var inc_ms := 0.0
## Jugadores bloqueados (uid → nombre); los pone la app. No me uno a sus partidas ni ellos a las mías.
var blocked := {}
var _clock := {}
var _my_press := {"n": -1, "at": 0.0}
var _ended_sent := false
var _offset_fine := false
## Partidas de las que me fui porque quien esperaba no volvió (no me vuelvo a unir a ellas).
var _skip := {}
var _doc_seen := false
var _listo_sent := false
## Complemento de Android EsperaOnline (solo en el APK compilado con Gradle): mientras espero, un servicio en primer
## plano mantiene viva la partida en espera y avisa si entra alguien con la app minimizada.
var _bg: Object = null
var _bg_on := false

var _id_token := ""
var _refresh_token := ""
var _expires_at := 0.0
var _auth_busy := false
var _offset_ms := 0.0
var _rng := RandomNumberGenerator.new()
var _role := ""
var _seen := false
var _applied := 0
## Turno: cuándo empezó (reloj local, ms) el turno de quien mueve ahora y su clave (para ver cuándo cambia).
var _turn_key := ""
var _turn_at := 0
## «Sigo aquí» de cada jugador: lo último que se leyó de la base de datos y cuándo se vio cambiar (reloj local).
var _sigo := {}
var _sigo_at := {}
var _lobby_cleaned := false
var _hb_t := 0.0
var _scan_t := 0.0
var _hb_busy := false
var _scan_busy := false
var _gen := 0

var _sse: HTTPClient
var _sse_state := 0 # 0 parado, 1 conectando, 2 pidiendo, 3 recibiendo, 5 preparando
var _sse_path := ""
var _sse_buf := ""
var _sse_wait := 0.0
var _sse_token := ""
var _sse_tree: Variant = null


func _ready() -> void:
	_rng.randomize()
	if Engine.has_singleton("EsperaOnline"):
		_bg = Engine.get_singleton("EsperaOnline")
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_refresh_token = str(cfg.get_value("sesion", "refresco", ""))


# ---------------------------------------------------------------- funciones puras (con prueba)

## Identificador de partida: hora UTC con segundos + 6 caracteres al azar. Ordena cronológicamente por clave.
static func new_game_id(unix_s: int, rng: RandomNumberGenerator) -> String:
	var t := Time.get_datetime_dict_from_unix_time(unix_s)
	var chars := "0123456789abcdefghijklmnopqrstuvwxyz"
	var tail := ""
	for i in 6:
		tail += chars[rng.randi_range(0, 35)]
	return "%04d%02d%02d-%02d%02d%02d-%s" % [int(t["year"]), int(t["month"]), int(t["day"]), int(t["hour"]), int(t["minute"]), int(t["second"]), tail]


## Color por la paridad de la hora del servidor al unirse el rival: par, el creador juega con blancas.
static func color_of(unido_en: int, role: String) -> int:
	var creator_white := unido_en % 2 == 0
	return 0 if (role == "creador") == creator_white else 1


static func is_fresh(latido: Variant, server_now_ms: float, max_age_ms: float = FRESH_MS) -> bool:
	if not (latido is float or latido is int):
		return false
	return absf(server_now_ms - float(latido)) <= max_age_ms


## Cabecera Date de HTTP («Sun, 15 Nov 2026 04:00:00 GMT») en milisegundos Unix; −1 si no se entiende.
static func parse_http_date(s: String) -> float:
	var parts := s.strip_edges().split(" ", false)
	if parts.size() < 5:
		return -1.0
	var mon := int(MONTHS.get(str(parts[2]), 0))
	var hms := str(parts[4]).split(":")
	if mon == 0 or hms.size() != 3:
		return -1.0
	var unix := Time.get_unix_time_from_datetime_dict({"year": int(parts[3]), "month": mon, "day": int(parts[1]), "hour": int(hms[0]), "minute": int(hms[1]), "second": int(hms[2])})
	return float(unix) * 1000.0


## Lector de eventos SSE: devuelve {buffer: lo que falta por completar, events: [{event, data}]}.
static func sse_push(buffer: String, text: String) -> Dictionary:
	var buf := (buffer + text).replace("\r\n", "\n")
	var events: Array = []
	var i := buf.find("\n\n")
	while i >= 0:
		var block := buf.substr(0, i)
		buf = buf.substr(i + 2)
		var ev := ""
		var data := ""
		for line: String in block.split("\n"):
			if line.begins_with("event:"):
				ev = line.substr(6).strip_edges()
			elif line.begins_with("data:"):
				data += line.substr(5).strip_edges()
		if ev != "":
			var parsed: Variant = null
			if data != "":
				parsed = JSON.parse_string(data)
			events.append({"event": ev, "data": parsed})
		i = buf.find("\n\n")
	return {"buffer": buf, "events": events}


static func _set_path(base: Variant, parts: Array, value: Variant) -> Variant:
	if parts.is_empty():
		return value
	var d: Dictionary = {}
	if base is Dictionary:
		d = (base as Dictionary).duplicate()
	elif base is Array:
		var arr: Array = base
		for k in arr.size():
			if arr[k] != null:
				d[str(k)] = arr[k]
	var key := str(parts[0])
	var child: Variant = _set_path(d.get(key), parts.slice(1), value)
	if child == null:
		d.erase(key)
	else:
		d[key] = child
	if d.is_empty():
		return null
	return d


## Copia local de lo que se escucha: aplica un evento put o patch.
static func apply_event(root: Variant, ev: Dictionary) -> Variant:
	var kind := str(ev.get("event", ""))
	if kind != "put" and kind != "patch":
		return root
	var payload: Variant = ev.get("data")
	if not (payload is Dictionary):
		return root
	var p: Dictionary = payload
	var parts: Array = []
	for s in str(p.get("path", "/")).split("/", false):
		parts.append(str(s))
	if kind == "put":
		return _set_path(root, parts, p.get("data"))
	var r: Variant = root
	var changes: Variant = p.get("data")
	if changes is Dictionary:
		var cd: Dictionary = changes
		for k in cd.keys():
			var sub := parts.duplicate()
			for s2 in str(k).split("/", false):
				sub.append(str(s2))
			r = _set_path(r, sub, cd[k])
	return r


## Jugadas (UCI) en orden y sin huecos.
static func moves_of(doc: Variant) -> Array:
	var out: Array = []
	if not (doc is Dictionary):
		return out
	var j: Variant = (doc as Dictionary).get("jugadas")
	var n := 0
	while true:
		var m: Variant = null
		if j is Dictionary:
			m = (j as Dictionary).get(str(n))
		elif j is Array and n < (j as Array).size():
			m = (j as Array)[n]
		if not (m is String):
			break
		out.append(m)
		n += 1
	return out


## Nombre de un ritmo para leer: «Sin reloj», «5+3», «20 min».
static func rhythm_label(r: String) -> String:
	var p := rhythm_parts(r)
	if int(p[0]) == 0:
		return Loc.t("Sin reloj")
	if int(p[1]) == 0:
		return Loc.f("%d min", int(p[0]))
	return "%d+%d" % [int(p[0]), int(p[1])]


## Si el ritmo es válido («5+3»; «0+0» = sin reloj).
static func rhythm_ok(r: String) -> bool:
	var re := RegEx.new()
	re.compile(RHYTHM_RE)
	return re.search(r) != null


## [minutos, segundos por jugada] del ritmo («0+0» → [0, 0]; «w5+3» → [5, 3]).
static func rhythm_parts(r: String) -> Array:
	if not rhythm_ok(r):
		return [0, 0]
	var p := r.trim_prefix("w").split("+")
	return [int(p[0]), int(p[1])]


## Si el espacio es de War Chess («w5+3»).
static func is_war(space: String) -> bool:
	return space.begins_with("w")


## El espacio de un ritmo en una modalidad: («5+3», true) → «w5+3».
static func space_of(r: String, war: bool) -> String:
	r = r.trim_prefix("w")
	return "w" + r if war else r


## Nombre del espacio para los avisos y la espera: «5+3» o «War Chess · 5+3».
static func space_label(space: String) -> String:
	return ("War Chess · " if is_war(space) else "") + rhythm_label(space)


## Reloj que sale de las pulsaciones (horas del servidor, ms): {left: [blancas, negras] al terminar la última
## pulsación, side: a quién le corre, since: desde qué hora, presses: cuántas, flag: quién se pasó de tiempo al
## pulsar (−1, nadie)}. Las blancas empiezan a contar cuando empieza la partida («listo»).
static func clock_state(doc: Variant, base: float, inc: float) -> Dictionary:
	var left := [base, base]
	var since := 0.0
	var n := 0
	var flag := -1
	if doc is Dictionary:
		var d: Dictionary = doc
		since = float(d.get("listo", d.get("unidoEn", 0)))
		var p: Variant = d.get("pulsos")
		while true:
			var t: Variant = null
			if p is Dictionary:
				t = (p as Dictionary).get(str(n))
			elif p is Array and n < (p as Array).size():
				t = (p as Array)[n]
			if not (t is float or t is int):
				break
			var side := n % 2
			left[side] = float(left[side]) - (float(t) - since)
			if float(left[side]) < 0.0 and flag < 0:
				flag = side
			left[side] = float(left[side]) + inc
			since = float(t)
			n += 1
	return {"left": left, "side": n % 2, "since": since, "presses": n, "flag": flag}


## Partidas en espera por espacio: {ritmo: [ids, el más antiguo primero]}; sin las mías, las viejas, las de
## jugadores bloqueados y las de quien me ha bloqueado.
static func spaces_of(rows: Variant, my_uid: String, server_now_ms: float, blocked_uids: Dictionary) -> Dictionary:
	var out := {}
	if not (rows is Dictionary):
		return out
	for k in (rows as Dictionary).keys():
		var row: Variant = (rows as Dictionary)[k]
		if not (row is Dictionary):
			continue
		var rd: Dictionary = row
		var who := str(rd.get("creador", ""))
		var r := str(rd.get("ritmo", ""))
		if who == "" or who == my_uid or blocked_uids.has(who) or not rhythm_ok(r):
			continue
		if rd.get("no") is Dictionary and (rd["no"] as Dictionary).has(my_uid):
			continue
		if not is_fresh(rd.get("latido"), server_now_ms):
			continue
		if not out.has(r):
			out[r] = []
		(out[r] as Array).append(str(k))
	for r in out.keys():
		(out[r] as Array).sort()
	return out


## Color de quien juega (0/1) si ya empezó la partida y participa; −1 si no.
static func color_for(doc: Variant, my_uid: String) -> int:
	if not (doc is Dictionary):
		return -1
	var d: Dictionary = doc
	if not (d.has("creador") and d.has("rival") and d.has("unidoEn")):
		return -1
	var stamp := int(d["unidoEn"])
	if str(d["creador"]) == my_uid:
		return color_of(stamp, "creador")
	if str(d["rival"]) == my_uid:
		return color_of(stamp, "rival")
	return -1


# ---------------------------------------------------------------- sesión anónima y peticiones

func _http(method: HTTPClient.Method, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"code": 0, "body": "", "headers": PackedStringArray()}
	var r: Array = await req.request_completed
	req.queue_free()
	return {"code": int(r[1]), "body": (r[3] as PackedByteArray).get_string_from_utf8(), "headers": r[2]}


func _note_date(headers: PackedStringArray) -> float:
	for h in headers:
		if str(h).to_lower().begins_with("date:"):
			var ms := parse_http_date(str(h).substr(5))
			if ms > 0.0:
				# La cabecera va en segundos enteros: la diferencia real está entre «coarse» y un segundo más. Si
				# ya hay una medida fina (de una hora del servidor escrita por mí) y cuadra, se queda.
				var coarse := ms - Time.get_unix_time_from_system() * 1000.0
				if not (_offset_fine and _offset_ms >= coarse - 600.0 and _offset_ms <= coarse + 1600.0):
					_offset_ms = coarse + 500.0
					_offset_fine = false
				return _server_now()
	return _server_now()


## Medida fina de la hora del servidor: una hora del servidor (ms) escrita por mí, entre el envío y la respuesta.
func _calibrate(server_ms: Variant, sent_ms: float, recv_ms: float) -> void:
	if not (server_ms is float or server_ms is int) or recv_ms - sent_ms > 4000.0:
		return
	_offset_ms = float(server_ms) - (sent_ms + recv_ms) * 0.5
	_offset_fine = true


func _server_now() -> float:
	return Time.get_unix_time_from_system() * 1000.0 + _offset_ms


func _ensure_session() -> bool:
	if _id_token != "" and _expires_at - Time.get_unix_time_from_system() > MARGIN:
		return true
	if _auth_busy:
		await _auth_done
		return _id_token != ""
	_auth_busy = true
	var ok: bool = await _open_session()
	_auth_busy = false
	_auth_done.emit()
	return ok


func _open_session() -> bool:
	if _refresh_token != "":
		var r := await _http(HTTPClient.METHOD_POST, "https://securetoken.googleapis.com/v1/token?key=" + API_KEY, PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), "grant_type=refresh_token&refresh_token=" + _refresh_token.uri_encode())
		if int(r["code"]) == 200:
			var j: Variant = JSON.parse_string(str(r["body"]))
			if j is Dictionary:
				var d: Dictionary = j
				_take_session(str(d.get("id_token", "")), str(d.get("refresh_token", _refresh_token)), str(d.get("user_id", "")), float(str(d.get("expires_in", "3600"))))
				return _id_token != ""
	var r2 := await _http(HTTPClient.METHOD_POST, "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + API_KEY, PackedStringArray(["Content-Type: application/json"]), JSON.stringify({"returnSecureToken": true}))
	if int(r2["code"]) != 200:
		return false
	var j2: Variant = JSON.parse_string(str(r2["body"]))
	if not (j2 is Dictionary):
		return false
	var d2: Dictionary = j2
	_take_session(str(d2.get("idToken", "")), str(d2.get("refreshToken", "")), str(d2.get("localId", "")), float(str(d2.get("expiresIn", "3600"))))
	return _id_token != ""


func _take_session(id_token: String, refresh_token: String, user: String, expires_in: float) -> void:
	_id_token = id_token
	_refresh_token = refresh_token
	uid = user
	_expires_at = Time.get_unix_time_from_system() + expires_in
	var cfg := ConfigFile.new()
	cfg.set_value("sesion", "refresco", refresh_token)
	cfg.save(SAVE_PATH)


## Petición a la base de datos: {status, json, now (hora del servidor en ms)}.
func request(method: HTTPClient.Method, path: String, body: Variant = null, query: String = "") -> Dictionary:
	if not await _ensure_session():
		return {"status": 0, "json": null, "now": _server_now()}
	var q := query + ("&" if query != "" else "") + "auth=" + _id_token
	var data := "" if body == null else JSON.stringify(body)
	var sent := Time.get_unix_time_from_system() * 1000.0
	var r := await _http(method, "https://%s/%s.json?%s" % [DB_HOST, path, q], PackedStringArray(), data)
	var recv := Time.get_unix_time_from_system() * 1000.0
	var parsed: Variant = null
	if str(r["body"]) != "":
		parsed = JSON.parse_string(str(r["body"]))
	var now := _note_date(r["headers"])
	return {"status": int(r["code"]), "json": parsed, "now": now, "sent": sent, "recv": recv}


# ---------------------------------------------------------------- emparejamiento

## Partidas en espera de cada espacio: {ok, status, spaces: {ritmo: [ids]}} (ver spaces_of).
func lobby() -> Dictionary:
	if not await _ensure_session():
		return {"ok": false, "status": 0, "spaces": {}}
	var r := await request(HTTPClient.METHOD_GET, "espera", null, "orderBy=%22%24key%22&limitToLast=100")
	if int(r["status"]) != 200:
		return {"ok": false, "status": int(r["status"]), "spaces": {}}
	return {"ok": true, "status": 200, "spaces": spaces_of(r["json"], uid, float(r["now"]), blocked)}


## Busca rival en el espacio `space` (ritmo): se une a una partida que espera o abre la suya. Las señales avisan
## del resto.
func start(space: String = "0+0") -> void:
	if phase != "idle" and phase != "ended":
		return
	_skip = {}
	await _search(space)


func _search(space: String) -> void:
	_reset()
	rhythm = space if rhythm_ok(space) else "0+0"
	var parts := rhythm_parts(rhythm)
	base_ms = float(parts[0]) * 60000.0
	inc_ms = float(parts[1]) * 1000.0
	phase = "searching"
	var gen := _gen
	if not await _ensure_session():
		_fail("No se pudo conectar. Revisa tu conexión a Internet.")
		return
	var c := await _candidates("")
	if gen != _gen:
		return
	if not bool(c["ok"]):
		_fail(Loc.f("No se pudo leer la lista de partidas (código %d).", int(c["status"])))
		return
	var ids: Array = c["ids"]
	for id in ids:
		if await _try_join(str(id)):
			return
		if gen != _gen:
			return
	await _open()


func _reset() -> void:
	_gen += 1
	rival = {}
	rival_uid = ""
	_rival_json = ""
	_seen_gestures = {}
	game_id = ""
	my_color = -1
	_clock = {}
	_my_press = {"n": -1, "at": 0.0}
	_ended_sent = false
	_doc_seen = false
	_listo_sent = false
	_role = ""
	_seen = false
	_applied = 0
	_turn_key = ""
	_turn_at = 0
	_sigo = {}
	_sigo_at = {}
	_lobby_cleaned = false
	_hb_t = 0.0
	_scan_t = 0.0
	_stop_stream()


func _fail(message: String) -> void:
	_gen += 1
	_stop_stream()
	phase = "idle"
	failed.emit(message)


## Partidas que esperan en mi espacio, de otros jugadores y vivas, la más antigua primero (con `before`, solo las
## anteriores).
func _candidates(before: String) -> Dictionary:
	var l := await lobby()
	if not bool(l["ok"]):
		return {"ok": false, "status": int(l["status"]), "ids": []}
	var ids: Array = []
	for idv in (l["spaces"] as Dictionary).get(rhythm, []):
		var id := str(idv)
		if (before == "" or id < before) and not _skip.has(id):
			ids.append(id)
	return {"ok": true, "status": 200, "ids": ids}


func _try_join(id: String) -> bool:
	var r := await request(HTTPClient.METHOD_PATCH, "partidas/" + id, {"rival": uid, "unidoEn": {".sv": "timestamp"}})
	if int(r["status"]) != 200:
		return false # otro jugador se adelantó, o la partida ya no existe
	if r["json"] is Dictionary:
		_calibrate((r["json"] as Dictionary).get("unidoEn"), float(r["sent"]), float(r["recv"]))
	game_id = id
	_role = "rival"
	phase = "joining"
	_listen("partidas/" + id)
	_send_profile(id)
	matched.emit()
	return true


## El perfil propio, dentro de la partida (se borra con ella). Si no se puede escribir, la partida sigue igual.
func _send_profile(id: String) -> void:
	await request(HTTPClient.METHOD_PUT, "partidas/%s/perfiles/%s" % [id, uid], my_profile)
	if not my_game_rating.is_empty():
		await request(HTTPClient.METHOD_PUT, "partidas/%s/perfiles/%s/juego" % [id, uid], my_game_rating)


## Gesto del chat. Uno cada segundo y medio como mucho.
func send_gesture(kind: String) -> bool:
	if (phase != "playing" and phase != "ended") or game_id == "" or not GESTURES.has(kind):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_gesture < 1500:
		return false
	_last_gesture = now
	var r := await request(HTTPClient.METHOD_POST, "partidas/%s/gestos" % game_id, {"de": uid, "g": kind, "t": {".sv": "timestamp"}})
	return int(r["status"]) == 200


## Bloqueados para la fila de `espera`: {"no/<uid>": true, …}, los 50 últimos.
static func blocked_row(list: Dictionary) -> Dictionary:
	var out := {}
	var keys: Array = list.keys()
	for k in keys.slice(maxi(0, keys.size() - 50)):
		out["no/" + str(k)] = true
	return out


func _open() -> void:
	var gen := _gen
	var id := new_game_id(int(_server_now() / 1000.0), _rng)
	var a := await request(HTTPClient.METHOD_PATCH, "partidas/" + id, {"creador": uid, "ritmo": rhythm})
	var row := {"creador": uid, "latido": {".sv": "timestamp"}, "ritmo": rhythm}
	# Los que he bloqueado no se unen a mi partida (los 50 últimos). Van como rutas («no/<uid>»): las reglas solo
	# dejan escribir cada uno por separado; la lista entera de golpe («no»: {…}) daba 401 («código 200/401», 16 nov).
	row.merge(blocked_row(blocked))
	var b := await request(HTTPClient.METHOD_PATCH, "espera/" + id, row)
	if int(b["status"]) == 200 and b["json"] is Dictionary:
		_calibrate((b["json"] as Dictionary).get("latido"), float(b["sent"]), float(b["recv"]))
	if gen != _gen:
		return
	if int(a["status"]) != 200 or int(b["status"]) != 200:
		_fail(Loc.f("No se pudo abrir la partida (código %d/%d).", [int(a["status"]), int(b["status"])]))
		return
	game_id = id
	_role = "creador"
	phase = "waiting"
	_listen("partidas/" + id)
	_send_profile(id)


func _process(delta: float) -> void:
	if _bg != null and (phase == "waiting") != _bg_on:
		_bg_on = phase == "waiting"
		if _bg_on:
			_bg_start()
		else:
			_bg.call("stop")
	if phase == "joining" and _sse_tree is Dictionary:
		# Quien esperaba no vuelve: me voy y sigo buscando en el mismo espacio.
		var since := float((_sse_tree as Dictionary).get("unidoEn", 0))
		if since > 0.0 and _server_now() - since > JOIN_WAIT_MS:
			_give_up_join()
	if phase == "waiting":
		_hb_t += delta
		_scan_t += delta
		if _hb_t >= HEARTBEAT and not _hb_busy:
			_hb_t = 0.0
			_heartbeat()
		if _scan_t >= SCAN and not _scan_busy:
			_scan_t = 0.0
			_scan_older()
	_sse_tick(delta)


## Servicio de espera (Android): la sesión, la partida y los textos de sus avisos, en el idioma de la app.
func _bg_start() -> void:
	if _bg == null or game_id == "":
		return
	OS.request_permission("android.permission.POST_NOTIFICATIONS")
	_bg.call("start", {
		"host": DB_HOST, "game": game_id, "token": _id_token, "refresh": _refresh_token, "apiKey": API_KEY,
		"expiresAt": int(_expires_at),
		"title": Loc.f("Esperando rival · %s", space_label(rhythm)),
		"text": Loc.t("Te avisamos cuando entre alguien. Puedes salir de la app."),
		"foundTitle": Loc.t("¡Rival encontrado!"),
		"foundText": Loc.t("Vuelve a la app en menos de un minuto para empezar la partida."),
		# Con el nombre del rival (si tiene): el servicio cambia {nombre} por el suyo.
		"foundNamed": Loc.f("{nombre} quiere jugar %s contigo. Vuelve en menos de un minuto para empezar.", space_label(rhythm)),
		"playLabel": Loc.t("Jugar ahora"),
		"backLabel": Loc.t("Volver"),
		"stopLabel": Loc.t("Dejar de esperar"),
		"channelWait": Loc.t("Esperando rival"),
		"channelFound": Loc.t("Rival encontrado"),
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _bg != null and str(_bg.call("state")) == "cancelled":
		# Se tocó «Dejar de esperar» en el aviso: el servicio ya borró la partida en espera.
		_bg.call("clearState")
		_bg_on = false
		_gen += 1
		_stop_stream()
		phase = "idle"
		game_id = ""
		failed.emit(Loc.t("Has dejado de esperar desde el aviso."))


func _heartbeat() -> void:
	_hb_busy = true
	var r := await request(HTTPClient.METHOD_PATCH, "espera/" + game_id, {"latido": {".sv": "timestamp"}})
	if int(r["status"]) == 200 and r["json"] is Dictionary:
		_calibrate((r["json"] as Dictionary).get("latido"), float(r["sent"]), float(r["recv"]))
	_hb_busy = false


## Si mientras espero otro jugador abrió una partida anterior a la mía, me uno a ella (así no esperamos los dos).
func _scan_older() -> void:
	_scan_busy = true
	var gen := _gen
	var mine := game_id
	var c := await _candidates(mine)
	if bool(c["ok"]) and gen == _gen and phase == "waiting":
		var ids: Array = c["ids"]
		for idv in ids:
			var id := str(idv)
			if gen != _gen or phase != "waiting":
				break
			var r := await request(HTTPClient.METHOD_PATCH, "partidas/" + id, {"rival": uid, "unidoEn": {".sv": "timestamp"}})
			if int(r["status"]) == 200:
				if r["json"] is Dictionary:
					_calibrate((r["json"] as Dictionary).get("unidoEn"), float(r["sent"]), float(r["recv"]))
				_stop_stream()
				await request(HTTPClient.METHOD_DELETE, "espera/" + mine)
				await request(HTTPClient.METHOD_DELETE, "partidas/" + mine)
				game_id = id
				_role = "rival"
				_seen = false
				phase = "joining"
				_listen("partidas/" + id)
				_send_profile(id)
				matched.emit()
				break
	_scan_busy = false


func _give_up_join() -> void:
	var id := game_id
	_skip[id] = true
	_gen += 1
	_stop_stream()
	game_id = ""
	_role = ""
	_seen = false
	phase = "idle"
	await request(HTTPClient.METHOD_DELETE, "partidas/" + id)
	if phase == "idle":
		retry.emit()
		var keep := _skip.duplicate()
		_reset()
		_skip = keep
		await _search(rhythm)


## La partida en la que esperaba ha desaparecido (el que entró se cansó de esperar): abro otra en el mismo espacio.
func _reopen() -> void:
	var old := game_id
	_gen += 1
	_stop_stream()
	game_id = ""
	phase = "idle"
	await request(HTTPClient.METHOD_DELETE, "espera/" + old)
	if phase == "idle":
		var keep := _skip.duplicate()
		_reset()
		_skip = keep
		await _search(rhythm)


# ---------------------------------------------------------------- partida en directo

func _on_tree() -> void:
	var doc: Variant = _sse_tree
	if doc == null:
		# La partida desapareció: si estaba en juego y no había terminado, el rival se fue.
		if _seen and phase == "playing":
			# Si me tocaba y llevaba sin contestar más de lo que el rival tiene que esperar, lo más probable es que la
			# diera por ganada (y la borrase) mientras yo no estaba; si no, se fue él.
			var gone := on_move() == my_color and idle_ms(my_color) > idle_limit_ms(base_ms) + IDLE_ANSWER_MS
			phase = "ended"
			if gone:
				ended.emit("ausencia", 1 - my_color)
			else:
				ended.emit("abandoned", my_color)
			_stop_stream()
		elif _doc_seen and phase == "waiting":
			_reopen()
		elif _doc_seen and phase == "joining":
			_give_up_join()
		return
	_doc_seen = true
	var color := color_for(doc, uid)
	if color < 0:
		return
	_seen = true
	my_color = color
	if _role == "creador" and not _lobby_cleaned:
		_lobby_cleaned = true
		_fire(HTTPClient.METHOD_DELETE, "espera/" + game_id)
	_check_extras(doc)
	if not (doc as Dictionary).has("listo"):
		# Ha entrado el rival: si soy quien esperaba, aviso de que estoy (empieza la partida); si entré yo, espero.
		if _role == "creador" and not _listo_sent:
			_listo_sent = true
			_send_listo()
		return
	if phase == "searching" or phase == "waiting" or phase == "joining":
		phase = "playing"
		_applied = 0
		started.emit(color)
	if phase != "playing":
		return
	_check_fin(doc)
	if phase != "playing":
		return
	var moves := moves_of(doc)
	while _applied < moves.size():
		var i := _applied
		_applied += 1
		# Las jugadas pares son de blancas, las impares de negras; las propias ya se hicieron en el tablero.
		if i % 2 != my_color:
			move_received.emit(str(moves[i]))
		if phase != "playing":
			return
	if base_ms > 0.0:
		_check_clock(doc)
	_track_turn()


func _send_listo() -> void:
	var id := game_id
	var r := await request(HTTPClient.METHOD_PUT, "partidas/%s/listo" % id, {".sv": "timestamp"})
	if int(r["status"]) == 200:
		_calibrate(r["json"], float(r["sent"]), float(r["recv"]))
	elif id == game_id and phase == "waiting":
		# El que entró ya se había ido: a esperar otra vez.
		_reopen()


## Reloj: pulsaciones nuevas y quién se ha pasado de tiempo (al pulsar tarde, o apuntado en «fin»).
func _check_clock(doc: Variant) -> void:
	var c := clock_state(doc, base_ms, inc_ms)
	var changed := _clock.is_empty() or int(c["presses"]) != int(_clock.get("presses", -1))
	_clock = c
	if int(_my_press["n"]) >= 0 and int(c["presses"]) > int(_my_press["n"]):
		_my_press = {"n": -1, "at": 0.0}
	if changed:
		clock_changed.emit()
	var loser := int(c["flag"])
	if loser == 0 or loser == 1:
		_end_on_time(loser)


## Lo que diga «fin»: derrota por tiempo o por abandono («ausencia»), la apuntase quien la apuntase.
func _check_fin(doc: Variant) -> void:
	var fin: Variant = (doc as Dictionary).get("fin")
	if not fin is Dictionary:
		return
	var loser := int((fin as Dictionary).get("pierde", -1))
	if loser != 0 and loser != 1:
		return
	match str((fin as Dictionary).get("tipo", "")):
		"tiempo":
			_end_on_time(loser)
		"abandono":
			_end_with(loser, "ausencia")


func _end_on_time(loser: int) -> void:
	_end_with(loser, "tiempo")


func _end_with(loser: int, reason: String) -> void:
	if _ended_sent or phase != "playing":
		return
	_ended_sent = true
	phase = "ended"
	ended.emit(reason, 1 - loser)
	if not is_inside_tree():
		return
	var id := game_id
	var gen := _gen
	await get_tree().create_timer(CLEANUP).timeout
	if gen == _gen:
		_stop_stream()
		await request(HTTPClient.METHOD_DELETE, "partidas/" + id)


## Cuánto puede estar sin jugar quien mueve antes de «¿Sigues ahí?»: la quinta parte del tiempo de cada uno, entre
## 1 y 5 minutos (5+3 → 1 min, 10+5 → 2, 15+10 → 3, 20 → 4, 30 → 5); sin reloj, 3 minutos.
static func idle_limit_ms(base: float) -> float:
	if base <= 0.0:
		return IDLE_UNTIMED_MS
	return clampf(base * 0.2, 60000.0, 300000.0)


## A quién le toca (0 blancas, 1 negras). Con reloj, a quien le corre el reloj (si he jugado y no he pulsado, sigo
## siendo yo); sin reloj, por el número de jugadas.
func on_move() -> int:
	if base_ms > 0.0 and not _clock.is_empty():
		return int(clock_now()["side"])
	return _applied % 2


## Apunta cuándo empieza cada turno (con el reloj de este móvil).
func _track_turn() -> void:
	var key := "%d/%d" % [on_move(), int(_clock.get("presses", 0)) if base_ms > 0.0 else _applied]
	if key != _turn_key:
		_turn_key = key
		_turn_at = Time.get_ticks_msec()


## Cuánto lleva sin jugar ni decir «Sigo aquí» quien mueve (0 si no le toca a `side`).
func idle_ms(side: int) -> float:
	if phase != "playing" or side < 0 or on_move() != side or _turn_key == "":
		return 0.0
	var who := uid if side == my_color else rival_uid
	var since := maxi(_turn_at, int(_sigo_at.get(who, _turn_at)))
	return float(Time.get_ticks_msec() - since)


## «Sigo aquí»: se apunta con la hora del servidor; el rival lo ve y vuelve a esperar.
func still_here() -> void:
	if phase != "playing" or game_id == "":
		return
	_sigo_at[uid] = Time.get_ticks_msec()
	await request(HTTPClient.METHOD_PUT, "partidas/%s/sigo/%s" % [game_id, uid], {".sv": "timestamp"})


## Mi rival no juega ni contesta: gano por abandono. Se apunta en «fin» (si las reglas aún no lo admiten, la
## partida se borra igual y su app lo entiende al volver).
func claim_abandon(loser: int) -> void:
	if phase != "playing" or (loser != 0 and loser != 1):
		return
	await request(HTTPClient.METHOD_PUT, "partidas/%s/fin" % game_id, {"tipo": "abandono", "pierde": loser, "de": uid, "t": {".sv": "timestamp"}})
	_end_with(loser, "ausencia")


## Reloj ahora mismo (ms): {left: [blancas, negras], side: a quién le corre}. Si mi pulsación va de camino, mi reloj
## ya está parado.
func clock_now() -> Dictionary:
	if _clock.is_empty():
		return {"left": [base_ms, base_ms], "side": 0}
	var left: Array = (_clock["left"] as Array).duplicate()
	var side := int(_clock["side"])
	var since := float(_clock["since"])
	if int(_my_press["n"]) == int(_clock["presses"]) and side == my_color:
		var at := float(_my_press["at"])
		left[side] = float(left[side]) - maxf(0.0, at - since) + inc_ms
		side = 1 - side
		since = at
	left[side] = float(left[side]) - maxf(0.0, _server_now() - since)
	return {"left": left, "side": side}


## Si ya puedo mover: es mi turno en el tablero y, con reloj, el rival ha pulsado tras su jugada.
func my_turn_open() -> bool:
	if base_ms <= 0.0 or _clock.is_empty():
		return true
	return int(_clock["presses"]) >= _applied


## Perfil del rival y gestos nuevos (también con la partida terminada: «buena partida»).
func _check_extras(doc: Variant) -> void:
	var d: Dictionary = doc
	var other := str(d.get("rival", "")) if str(d.get("creador", "")) == uid else str(d.get("creador", ""))
	rival_uid = other
	var perfiles: Variant = d.get("perfiles")
	if perfiles is Dictionary and (perfiles as Dictionary).get(other) is Dictionary:
		var p: Dictionary = (perfiles as Dictionary)[other]
		var text := JSON.stringify(p)
		if text != _rival_json:
			_rival_json = text
			rival = p
			rival_profile.emit(p)
	var sigo: Variant = d.get("sigo")
	if sigo is Dictionary:
		for k: Variant in (sigo as Dictionary).keys():
			var v: Variant = (sigo as Dictionary)[k]
			if _sigo.get(str(k)) != v:
				_sigo[str(k)] = v
				_sigo_at[str(k)] = Time.get_ticks_msec()
	var gestos: Variant = d.get("gestos")
	if gestos is Dictionary:
		var keys: Array = (gestos as Dictionary).keys()
		keys.sort()
		for k in keys:
			if _seen_gestures.has(str(k)):
				continue
			_seen_gestures[str(k)] = true
			var g: Variant = (gestos as Dictionary)[k]
			if g is Dictionary and GESTURES.has(str((g as Dictionary).get("g", ""))):
				gesture.emit(str((g as Dictionary).get("de", "")) == uid, str((g as Dictionary)["g"]))


func _fire(method: HTTPClient.Method, path: String) -> void:
	await request(method, path)


## Jugada propia (UCI). Con reloj y `press`, pulsa el reloj a la vez (pulsado automático). Devuelve true si se
## escribió.
func play(uci: String, press: bool = false) -> bool:
	if phase != "playing":
		return false
	var n := _applied
	_applied = maxi(_applied, n + 1)
	_track_turn()
	var r: Dictionary
	if press and base_ms > 0.0:
		_my_press = {"n": n, "at": _server_now()}
		r = await request(HTTPClient.METHOD_PATCH, "partidas/" + game_id, {"jugadas/%d" % n: uci, "pulsos/%d" % n: {".sv": "timestamp"}})
		if int(r["status"]) == 200 and r["json"] is Dictionary:
			_calibrate((r["json"] as Dictionary).get("pulsos/%d" % n), float(r["sent"]), float(r["recv"]))
	else:
		r = await request(HTTPClient.METHOD_PUT, "partidas/%s/jugadas/%d" % [game_id, n], uci)
	return int(r["status"]) == 200


## Pulso mi reloj tras mi última jugada (pulsado a mano).
func press() -> bool:
	if phase != "playing" or base_ms <= 0.0 or _applied == 0 or (_applied - 1) % 2 != my_color:
		return false
	var n := _applied - 1
	_my_press = {"n": n, "at": _server_now()}
	_track_turn()
	var r := await request(HTTPClient.METHOD_PUT, "partidas/%s/pulsos/%d" % [game_id, n], {".sv": "timestamp"})
	if int(r["status"]) == 200:
		_calibrate(r["json"], float(r["sent"]), float(r["recv"]))
	return int(r["status"]) == 200


## Se le acabó el tiempo a `loser` (lo veo yo): se apunta en la partida; vale el primero que llega.
func claim_time(loser: int) -> void:
	if phase != "playing" or base_ms <= 0.0:
		return
	await request(HTTPClient.METHOD_PUT, "partidas/%s/fin" % game_id, {"tipo": "tiempo", "pierde": loser, "de": uid, "t": {".sv": "timestamp"}})
	_end_on_time(loser)


## Denuncia a un jugador (motivo de REPORT_REASONS). Devuelve true si se envió.
func report(against: String, rival_name: String, reason: String, game: String) -> bool:
	if against == "" or not REPORT_REASONS.has(reason) or not await _ensure_session():
		return false
	var r := await request(HTTPClient.METHOD_POST, "denuncias", {"de": uid, "contra": against.left(128), "nombre": rival_name.left(16), "partida": game.left(40), "motivo": reason, "t": {".sv": "timestamp"}})
	return int(r["status"]) == 200


## La partida terminó en el tablero: se deja un momento para que el rival reciba la última jugada y se borra.
func finish() -> void:
	if phase != "playing":
		return
	phase = "ended"
	var id := game_id
	var gen := _gen
	await get_tree().create_timer(CLEANUP).timeout
	if gen == _gen:
		_stop_stream()
	await request(HTTPClient.METHOD_DELETE, "partidas/" + id)


## Rendirse o salir: la partida se borra y el rival se entera.
func leave() -> void:
	if phase == "idle":
		return
	var id := game_id
	var role := _role
	var was := phase
	_gen += 1
	_stop_stream()
	phase = "idle"
	game_id = ""
	if id != "" and (was == "waiting" or was == "playing" or was == "ended"):
		if role == "creador":
			await request(HTTPClient.METHOD_DELETE, "espera/" + id)
		await request(HTTPClient.METHOD_DELETE, "partidas/" + id)


# ---------------------------------------------------------------- escucha SSE (HTTPClient)

func _listen(path: String) -> void:
	_sse_path = path
	_sse_buf = ""
	_sse_tree = null
	_sse_wait = 0.0
	_sse_state = 0


func _stop_stream() -> void:
	_sse_path = ""
	_sse_state = 0
	_sse_tree = null
	if _sse != null:
		_sse.close()
		_sse = null


func _sse_fail() -> void:
	if _sse != null:
		_sse.close()
		_sse = null
	_sse_state = 0
	_sse_wait = 1.5


func _sse_begin() -> void:
	_sse_state = 5
	var gen := _gen
	var ok: bool = await _ensure_session()
	if gen != _gen or _sse_path == "":
		return
	if not ok:
		_sse_fail()
		return
	_sse_token = _id_token
	_sse_buf = ""
	_sse = HTTPClient.new()
	if _sse.connect_to_host("https://" + DB_HOST) != OK:
		_sse_fail()
		return
	_sse_state = 1


func _sse_tick(delta: float) -> void:
	if _sse_path == "":
		return
	if _sse_state == 0:
		_sse_wait -= delta
		if _sse_wait <= 0.0:
			_sse_begin()
		return
	if _sse_state == 5 or _sse == null:
		return
	_sse.poll()
	var st := _sse.get_status()
	match st:
		HTTPClient.STATUS_CONNECTED:
			if _sse_state == 1:
				var err := _sse.request(HTTPClient.METHOD_GET, "/%s.json?auth=%s" % [_sse_path, _sse_token], PackedStringArray(["Accept: text/event-stream"]))
				if err != OK:
					_sse_fail()
				else:
					_sse_state = 2
			else:
				_sse_fail()
		HTTPClient.STATUS_BODY:
			if _sse_state == 2:
				if _sse.get_response_code() != 200:
					_sse_fail()
					return
				_sse_state = 3
			# El token se renueva antes de caducar: se reconecta con el nuevo.
			if _expires_at - Time.get_unix_time_from_system() < MARGIN - 10.0:
				_sse_fail()
				_sse_wait = 0.0
				return
			var guard := 0
			while guard < 20:
				guard += 1
				var chunk := _sse.read_response_body_chunk()
				if chunk.is_empty():
					break
				var res := sse_push(_sse_buf, chunk.get_string_from_utf8())
				_sse_buf = str(res["buffer"])
				var evs: Array = res["events"]
				for evv in evs:
					var ev: Dictionary = evv
					var kind := str(ev["event"])
					if kind == "put" or kind == "patch":
						_sse_tree = apply_event(_sse_tree, ev)
						_on_tree()
						if _sse_path == "":
							return
					elif kind == "auth_revoked" or kind == "cancel":
						_sse_fail()
						_sse_wait = 0.0
						return
		HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_sse_fail()
