class_name Online
extends Node
## Partida online con Firebase Realtime Database (REST + escucha en directo SSE), sin complementos.
## Lo mismo que src/online (TypeScript): emparejamiento automático, jugadas en directo y limpieza.
##   abiertas/<id>   {creador, latido}                     partidas que esperan rival
##   partidas/<id>   {creador, rival, unidoEn, jugadas/<n>}
## Entrar = unirse a la partida abierta más antigua y viva (lo decide la base de datos, atómicamente) o abrir una.
## Si dos abren a la vez, el de la partida más reciente se une a la más antigua.
## Colores: 0 blancas, 1 negras (como en Chess).

signal started(color: int)
signal move_received(uci: String)
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
const MONTHS := {"Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6, "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12}

## Gestos del chat: solo estos, sin texto libre.
const GESTURES := ["saludo", "aplauso", "genial", "arriba", "abajo", "buena"]
const GESTURE_TEXT := {"saludo": "¡Hola!", "aplauso": "¡Bravo!", "genial": "¡Genial!", "arriba": "Bien", "abajo": "Vaya", "buena": "Buena partida"}

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

var _id_token := ""
var _refresh_token := ""
var _expires_at := 0.0
var _auth_busy := false
var _offset_ms := 0.0
var _rng := RandomNumberGenerator.new()
var _role := ""
var _seen := false
var _applied := 0
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
				_offset_ms = ms - Time.get_unix_time_from_system() * 1000.0
				return ms
	return _server_now()


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
	var r := await _http(method, "https://%s/%s.json?%s" % [DB_HOST, path, q], PackedStringArray(), data)
	var parsed: Variant = null
	if str(r["body"]) != "":
		parsed = JSON.parse_string(str(r["body"]))
	var now := _note_date(r["headers"])
	return {"status": int(r["code"]), "json": parsed, "now": now}


# ---------------------------------------------------------------- emparejamiento

## Busca rival: se une a una partida abierta o abre la suya. Las señales avisan del resto.
func start() -> void:
	if phase != "idle" and phase != "ended":
		return
	_reset()
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
	_role = ""
	_seen = false
	_applied = 0
	_lobby_cleaned = false
	_hb_t = 0.0
	_scan_t = 0.0
	_stop_stream()


func _fail(message: String) -> void:
	_gen += 1
	_stop_stream()
	phase = "idle"
	failed.emit(message)


## Partidas abiertas y vivas de otros jugadores, la más antigua primero (con `before`, solo las anteriores).
func _candidates(before: String) -> Dictionary:
	var r := await request(HTTPClient.METHOD_GET, "abiertas", null, Loc.t("orderBy=%22%24key%22&limitToLast=20"))
	if int(r["status"]) != 200:
		return {"ok": false, "status": int(r["status"]), "ids": []}
	var ids: Array = []
	if r["json"] is Dictionary:
		var rows: Dictionary = r["json"]
		for k in rows.keys():
			var id := str(k)
			var row: Variant = rows[k]
			if not (row is Dictionary):
				continue
			var rd: Dictionary = row
			if str(rd.get("creador", "")) == uid:
				continue
			if not is_fresh(rd.get("latido"), float(r["now"])):
				continue
			if before != "" and id >= before:
				continue
			ids.append(id)
	ids.sort()
	return {"ok": true, "status": 200, "ids": ids}


func _try_join(id: String) -> bool:
	var r := await request(HTTPClient.METHOD_PATCH, "partidas/" + id, {"rival": uid, "unidoEn": {".sv": "timestamp"}})
	if int(r["status"]) != 200:
		return false # otro jugador se adelantó, o la partida ya no existe
	game_id = id
	_role = "rival"
	_listen("partidas/" + id)
	_send_profile(id)
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


func _open() -> void:
	var gen := _gen
	var id := new_game_id(int(_server_now() / 1000.0), _rng)
	var a := await request(HTTPClient.METHOD_PUT, "partidas/%s/creador" % id, uid)
	var b := await request(HTTPClient.METHOD_PATCH, "abiertas/" + id, {"creador": uid, "latido": {".sv": "timestamp"}})
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


func _heartbeat() -> void:
	_hb_busy = true
	await request(HTTPClient.METHOD_PATCH, "abiertas/" + game_id, {"latido": {".sv": "timestamp"}})
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
				_stop_stream()
				await request(HTTPClient.METHOD_DELETE, "abiertas/" + mine)
				await request(HTTPClient.METHOD_DELETE, "partidas/" + mine)
				game_id = id
				_role = "rival"
				_seen = false
				_listen("partidas/" + id)
				_send_profile(id)
				break
	_scan_busy = false


# ---------------------------------------------------------------- partida en directo

func _on_tree() -> void:
	var doc: Variant = _sse_tree
	if doc == null:
		# La partida desapareció: si estaba en juego y no había terminado, el rival se fue.
		if _seen and phase == "playing":
			phase = "ended"
			ended.emit("abandoned", my_color)
			_stop_stream()
		return
	var color := color_for(doc, uid)
	if color < 0:
		return
	_seen = true
	my_color = color
	if _role == "creador" and not _lobby_cleaned:
		_lobby_cleaned = true
		_fire(HTTPClient.METHOD_DELETE, "abiertas/" + game_id)
	if phase == "searching" or phase == "waiting":
		phase = "playing"
		_applied = 0
		started.emit(color)
	_check_extras(doc)
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


## Jugada propia (UCI). Devuelve true si se escribió.
func play(uci: String) -> bool:
	if phase != "playing":
		return false
	var n := _applied
	var r := await request(HTTPClient.METHOD_PUT, "partidas/%s/jugadas/%d" % [game_id, n], uci)
	if int(r["status"]) != 200:
		return false
	_applied = maxi(_applied, n + 1)
	return true


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
			await request(HTTPClient.METHOD_DELETE, "abiertas/" + id)
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
				var err := _sse.request(HTTPClient.METHOD_GET, Loc.f("/%s.json?auth=%s", [_sse_path, _sse_token]), PackedStringArray(["Accept: text/event-stream"]))
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
