class_name CineFilm
extends RefCounted
## El vídeo de un final de campeones dentro de la app (el cine, fase 2): el «director» que decide cuándo pausar el
## vídeo antes de cada pregunta y qué posición enseña el tablero mientras se ve. Portado tal cual de la rama
## `cine-video` (src/core/videoCine.ts: `direct`, `plyAt`, `syncCap`), con las mismas constantes.
##
## Lógica pura: no toca el reproductor. Recibe lecturas del tiempo y devuelve órdenes (cue, play, pause, seek) que
## ejecuta el reproductor nativo (core/cine_player.gd). Datos: `film` de cada clip en data/cine.json
## (tools/cine/build.py): start, end, duration, stops [{at, resume}], sync {startPly, marks, gaps}, frames.
##
## Reglas de YouTube que condicionan el diseño (ver claude/chessome-cine.md): solo funciones documentadas de su API;
## nada encima del reproductor; si el jugador pulsa ▶ durante una pregunta, no se le vuelve a parar (responder es
## opcional).

## Adelanto, en segundos, para compensar que el tiempo se lee cada 100 ms.
const EPS := 0.12
## Si el tiempo ya ha pasado la marca por más de esto, el jugador ha saltado por delante de la parada.
const LATE := 1.0
## Tras ordenar la pausa, margen en el que el reproductor puede seguir diciendo «reproduciendo».
const PAUSE_GRACE_MS := 600.0
## Ventana en la que se reintenta la pausa una sola vez si el reproductor no la obedeció.
const PAUSE_RETRY_MS := 1500.0
## Diferencia de duración, en segundos, a partir de la cual se sospecha un anuncio u otro vídeo.
const DURATION_TOLERANCE := 2.0
## Si al reanudar el vídeo está a menos de esto del punto de reanudación, no se salta: solo se reproduce.
const RESUME_NEAR := 1.5


static func initial() -> Dictionary:
	return {"phase": "idle", "mode": "film", "stop": 0, "video_on": false, "missed": "none", "ad": false,
		"pause_at": -1.0, "retries": 0, "error": 0}


## ¿Tiene el clip todo lo necesario para pausar solo?
static func can_auto_pause(film: Variant) -> bool:
	if not film is Dictionary or (film as Dictionary).get("start") == null:
		return false
	var stops: Array = (film as Dictionary).get("stops", [])
	if stops.is_empty():
		return false
	for st: Dictionary in stops:
		if st.get("at") == null:
			return false
	return true


static func _stop_at(film: Dictionary, i: int) -> Variant:
	var stops: Array = film.get("stops", [])
	if i < 0 or i >= stops.size():
		return null
	return (stops[i] as Dictionary).get("at")


static func _go(state: Dictionary, commands: Array = []) -> Dictionary:
	return {"state": state, "commands": commands}


## Transición del director. `e`: {type: start|tick|reveal|ask|jump|next|back|finish|error|answered, …}. Devuelve {state,
## commands}; commands: [{type: cue|play|pause|seek, at?}].
static func direct(film: Dictionary, s: Dictionary, e: Dictionary) -> Dictionary:
	var stops: Array = film.get("stops", [])
	var start: float = float(film.get("start", 0.0)) if film.get("start") != null else 0.0
	match str(e["type"]):
		"start":
			var base := initial()
			var want := str(e.get("mode", "film"))
			if (want == "film" or want == "free") and can_auto_pause(film):
				base.merge({"phase": "watching", "mode": "film", "video_on": true}, true)
				return _go(base, [{"type": "cue", "at": start}])
			if want == "free":
				base.merge({"phase": "reveal", "mode": "free", "video_on": true, "missed": "skipped"}, true)
				return _go(base, [{"type": "cue", "at": start}])
			base.merge({"phase": "asking", "mode": "direct"}, true)
			return _go(base)

		"error":
			var st := s.duplicate()
			st.merge({"video_on": false, "error": int(e.get("code", -1)), "ad": false, "pause_at": -1.0}, true)
			if s["phase"] == "watching":
				st.merge({"phase": "asking", "mode": "direct"}, true)
			elif s["phase"] == "reveal":
				st["phase"] = "ended"
			return _go(st)

		"reveal":
			if s["phase"] != "asking":
				return _go(s)
			var stop: Dictionary = stops[int(s["stop"])]
			var from: float = float(stop["resume"]) if stop.get("resume") != null else (float(stop["at"]) if stop.get("at") != null else start)
			var nxt := s.duplicate()
			nxt.merge({"phase": "reveal", "missed": "none", "pause_at": -1.0, "retries": 0}, true)
			if not bool(s["video_on"]):
				nxt["video_on"] = true
				return _go(nxt, [{"type": "cue", "at": from}])
			var near: bool = e.get("time") != null and absf(float(e["time"]) - from) <= RESUME_NEAR and stop.get("resume") == null
			return _go(nxt, [{"type": "play"}] if near else [{"type": "seek", "at": from}, {"type": "play"}])

		"ask":
			var now := float(e.get("now", 0.0))
			if s["phase"] == "reveal" and s["missed"] == "none":
				# Viendo cómo sigue el vídeo hacia la siguiente pausa: se va ya a esa pregunta (el vídeo salta a la pausa).
				var at: Variant = _stop_at(film, int(s["stop"]) + 1)
				if at == null:
					return _go(s)
				var st2 := s.duplicate()
				st2.merge({"phase": "asking", "stop": int(s["stop"]) + 1, "missed": "none", "pause_at": now, "retries": 0}, true)
				return _go(st2, [{"type": "seek", "at": float(at)}, {"type": "pause"}])
			if s["phase"] != "watching":
				return _go(s)
			var st3 := s.duplicate()
			st3.merge({"phase": "asking", "missed": "none", "pause_at": now, "retries": 0}, true)
			return _go(st3, [{"type": "pause"}])

		"jump":
			var at2: Variant = _stop_at(film, int(s["stop"]) + 1)
			if s["phase"] != "asking" or at2 == null:
				return _go(s)
			var on := bool(s["video_on"])
			var st4 := s.duplicate()
			st4.merge({"stop": int(s["stop"]) + 1, "missed": "none", "pause_at": float(e.get("now", 0.0)) if on else -1.0, "retries": 0}, true)
			return _go(st4, [{"type": "seek", "at": float(at2)}, {"type": "pause"}] if on else [])

		"next":
			if s["phase"] != "asking" or int(s["stop"]) + 1 >= stops.size():
				return _go(s)
			var st5 := s.duplicate()
			st5.merge({"stop": int(s["stop"]) + 1, "missed": "none"}, true)
			return _go(st5)

		"finish":
			var st6 := s.duplicate()
			st6.merge({"phase": "ended", "pause_at": -1.0}, true)
			return _go(st6)

		"back":
			if s["phase"] != "reveal" or s["missed"] == "none":
				return _go(s)
			var on2 := bool(s["video_on"])
			var st7 := s.duplicate()
			st7.merge({"phase": "asking", "missed": "none", "pause_at": float(e.get("now", 0.0)) if on2 else -1.0, "retries": 0}, true)
			return _go(st7, [{"type": "pause"}] if on2 else [])

		"answered":
			# Añadido en la app (no estaba en la rama): el jugador ya había respondido y ha pulsado ▶ en el reproductor
			# en vez de «Continuar». Sigue viendo con normalidad: no es «se saltó la pregunta».
			if s["phase"] != "reveal" or s["missed"] != "resumed":
				return _go(s)
			var st8 := s.duplicate()
			st8["missed"] = "none"
			return _go(st8)

		"tick":
			return _tick(film, s, e)
	return _go(s)


static func _tick(film: Dictionary, s: Dictionary, e: Dictionary) -> Dictionary:
	if not bool(s["video_on"]):
		return _go(s)
	var t := float(e["time"])
	var dur := float(e.get("duration", 0.0))
	var playing := bool(e.get("playing", false))
	var now := float(e.get("now", 0.0))
	var expected: Variant = film.get("duration")
	if expected != null and dur > 0.0 and absf(dur - float(expected)) > DURATION_TOLERANCE:
		# La duración no es la del vídeo: probablemente un anuncio. No se actúa.
		if bool(s["ad"]):
			return _go(s)
		var sa := s.duplicate()
		sa["ad"] = true
		return _go(sa)
	var st := s
	if bool(s["ad"]):
		st = s.duplicate()
		st["ad"] = false

	var stop := int(st["stop"])
	match str(st["phase"]):
		"watching":
			if not playing:
				return _go(st)
			var at := float(_stop_at(film, stop))
			if t >= at - EPS and t <= at + LATE:
				var a := st.duplicate()
				a.merge({"phase": "asking", "missed": "none", "pause_at": now, "retries": 0}, true)
				return _go(a, [{"type": "pause"}])
			if t > at + LATE:
				var b := st.duplicate()
				b.merge({"phase": "reveal", "missed": "skipped"}, true)
				return _go(b)
			return _go(st)
		"asking":
			if not playing:
				return _go(st)
			var issued := float(st["pause_at"])
			if issued >= 0.0:
				var dt := now - issued
				if dt < PAUSE_GRACE_MS:
					return _go(st)
				if int(st["retries"]) < 1 and dt < PAUSE_RETRY_MS:
					var r := st.duplicate()
					r.merge({"pause_at": now, "retries": int(st["retries"]) + 1}, true)
					return _go(r, [{"type": "pause"}])
			# El jugador ha pulsado ▶ en el reproductor: sigue viendo y no se le vuelve a parar.
			var res := st.duplicate()
			res.merge({"phase": "reveal", "missed": "resumed", "pause_at": -1.0}, true)
			return _go(res)
		"reveal":
			if not playing:
				return _go(st)
			var nat: Variant = _stop_at(film, stop + 1)
			if nat != null:
				if t >= float(nat) - EPS and t <= float(nat) + LATE:
					var a2 := st.duplicate()
					a2.merge({"phase": "asking", "stop": stop + 1, "missed": "none", "pause_at": now, "retries": 0}, true)
					return _go(a2, [{"type": "pause"}])
				if t > float(nat) + LATE:
					var b2 := st.duplicate()
					b2.merge({"stop": stop + 1, "missed": "skipped"}, true)
					return _go(b2)
				return _go(st)
			if film.get("end") != null and t >= float(film["end"]) - EPS:
				var en := st.duplicate()
				en.merge({"phase": "ended", "pause_at": now, "retries": 0}, true)
				return _go(en, [{"type": "pause"}])
			return _go(st)
	return _go(st)


## Media jugada que el tablero sincronizado debe mostrar en el segundo `t`.
static func ply_at(film: Dictionary, t: float) -> int:
	var sync: Dictionary = film.get("sync", {})
	var ply := int(sync.get("startPly", 0))
	for m: Dictionary in sync.get("marks", []):
		if float(m["at"]) <= t:
			ply = int(m["ply"])
		else:
			break
	return ply


## Última media jugada que el tablero puede enseñar sin destripar la próxima pregunta (red de seguridad además de la
## comprobación de tools/cine/build.py). `plies`: la media jugada de la pregunta de cada pausa. -1 = sin tope.
static func sync_cap(plies: Array, st: Dictionary) -> int:
	if str(st.get("mode", "film")) == "free":
		return -1
	var i := -1
	if st["phase"] == "watching":
		i = int(st["stop"])
	elif st["phase"] == "reveal":
		i = int(st["stop"]) + 1
	if i < 0 or i >= plies.size():
		return -1
	return int(plies[i]) - 1


## Lo que enseña el tablero en el segundo `t`: {ply, fen, from, to} (from/to vacíos si es la posición de partida).
static func frame_at(film: Dictionary, t: float, cap: int) -> Dictionary:
	var ply := ply_at(film, t)
	if cap >= 0:
		ply = mini(ply, cap)
	var frames: Dictionary = film.get("frames", {})
	var f: Dictionary = frames.get(str(ply), {})
	var start := int((film.get("sync", {}) as Dictionary).get("startPly", 0))
	return {"ply": ply, "fen": str(f.get("fen", "")), "from": str(f.get("from", "")) if ply > start else "", "to": str(f.get("to", "")) if ply > start else ""}


## ¿Está el segundo `t` en un tramo en que el vídeo no deja ver las jugadas (cortes, manos)?
static func in_gap(film: Dictionary, t: float) -> bool:
	for g: Dictionary in (film.get("sync", {}) as Dictionary).get("gaps", []):
		if t >= float(g["from"]) and t < float(g["to"]):
			return true
	return false
