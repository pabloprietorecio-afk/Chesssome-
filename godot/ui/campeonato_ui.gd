class_name CampeonatoUI
extends RefCounted
## Pantallas del modo Campeonato (core/campeonato.gd, docs/campeonato.md): las salas, el cuadro de cada torneo, el
## paseo por la sala hasta la mesa (fotos con movimiento y sonido de ambiente) y lo que pasa al acabar cada partida.
## Funciones estáticas que reciben la pantalla principal (demo.gd), como HomeScreens.
##
## Las fotos son JPEG con extensión .bin (Godot no las importa ni las recomprime): res://campeonato/salas/ y
## res://campeonato/rivales/<sala>/. Si falta alguna, se ve un fondo liso: nada se rompe.

const SOUNDS := "res://campeonato/sonidos/"
const ALIVE_SHADER := preload("res://ui/foto_viva.gdshader")
## Tiempo de cada foto del paseo y del fundido entre fotos (segundos).
const SHOT_TIME := 3.2
const FADE := 0.9

static var _cache := {}
static var _ambient: AudioStreamPlayer
static var _fx: AudioStreamPlayer
static var _last_cheer := -100000
static var _faces := {}
static var _ambient_base := -8.0
static var _ambient_tw: Tween
static var _ambient_key := ""
## Volumen de los comentarios del público (exclamaciones, lamento) y de los aplausos, en dB. Bajos: el murmullo
## manda y los comentarios asoman por encima (petición de Pablo, 23 nov: «más murmullos y menos altos los
## comentarios»). Los aplausos del final, algo más altos que todo lo demás (también petición de Pablo).
const CROWD_DB := -15.0
const CHEER_DB := -3.0


# --- Fotos y sonido ---

static func photo(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load_jpg_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			tex = ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex


## Mapa de profundidad de una foto (<foto>_prof.bin, PNG en grises; blanco = cerca), o null.
static func depth_of(path: String) -> Texture2D:
	var p := path.replace(".bin", "_prof.bin")
	if _cache.has(p):
		return _cache[p]
	var tex: Texture2D = null
	if FileAccess.file_exists(p):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(p)) == OK:
			tex = ImageTexture.create_from_image(img)
	_cache[p] = tex
	return tex


## «Foto viva»: la foto se mueve en 2,5D según su profundidad (ui/foto_viva.gdshader). Devuelve el material para
## animar «shader_parameter/shift» (o null si la foto no tiene mapa de profundidad).
static func alive(pic: TextureRect, path: String, focus: float) -> ShaderMaterial:
	var depth := depth_of(path)
	if depth == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = ALIVE_SHADER
	mat.set_shader_parameter("depth_tex", depth)
	mat.set_shader_parameter("focus", focus)
	mat.set_shader_parameter("shift", Vector2.ZERO)
	pic.material = mat
	return mat


## Foto que llena su caja sin deformarse (recorta lo que sobra).
static func cover(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


static func _stream(file: String) -> AudioStream:
	var path := SOUNDS + file
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


## Salas grandes (casino, palacio, hotel): más público, otro murmullo y aplausos de sala grande.
static func big_room(key: String) -> bool:
	return Campeonato.index_of(key) >= 3


## Silencio del murmullo (botón del paseo y de la partida); se recuerda en el estado del campeonato.
static func murmullo_off(d: Variant) -> bool:
	return bool((d.campeonato_state() as Dictionary).get("silencio", false))


static func set_murmullo_off(d: Variant, off: bool) -> void:
	(d.campeonato_state() as Dictionary)["silencio"] = off
	d.campeonato_save()
	if off:
		ambient_stop()
	elif _ambient_key != "":
		ambient_start(d, _ambient_key, _ambient_base)


## Botón redondo de altavoz; tachado cuando el murmullo está silenciado. Al tocarlo, silencia o devuelve el murmullo.
static func mute_button(d: Variant, side: float = 76.0) -> Button:
	var b: Button = d._round_button("sound", func() -> void: pass, side, d._c("field"), d._c("ink"), false)
	b.name = "silencio"
	var strike := ColorRect.new()
	strike.color = Color("c0392b")
	strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strike.size = Vector2(side * 0.78, 6.0)
	strike.pivot_offset = strike.size * 0.5
	strike.position = Vector2(side * 0.5, side * 0.5) - strike.size * 0.5
	strike.rotation = deg_to_rad(-42.0)
	b.add_child(strike)
	var refresh := func() -> void:
		var off := murmullo_off(d)
		strike.visible = off
		b.modulate.a = 0.6 if off else 1.0
	refresh.call()
	b.pressed.connect(func() -> void:
		set_murmullo_off(d, not murmullo_off(d))
		refresh.call())
	return b


## Murmullo de la sala, en bucle (más bajo durante la partida). Sonidos: tools/campeonato/sonidos.sh (CC0).
static func ambient_start(d: Node, key: String, volume_db: float = -16.0) -> void:
	_ambient_key = key
	_ambient_base = volume_db
	if murmullo_off(d):
		return
	var s := _stream("murmullo_%s.ogg" % ("b" if big_room(key) else "a"))
	if s == null:
		return
	if _ambient == null or not is_instance_valid(_ambient):
		_ambient = AudioStreamPlayer.new()
		_ambient.bus = "Master"
		d.add_child(_ambient)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	if _ambient.stream != s or not _ambient.playing:
		_ambient.stream = s
		_ambient.play()
	_kill_ambient_tween()
	_ambient_base = volume_db
	_ambient.volume_db = volume_db
	_breathe()


## El murmullo respira: baja unos 9 dB y vuelve a subir despacio, para que no suene siempre igual (Pablo, 23 nov).
static func _breathe() -> void:
	if _ambient == null or not is_instance_valid(_ambient):
		return
	_kill_ambient_tween()
	_ambient_tw = _ambient.create_tween()
	_ambient_tw.tween_interval(3.0)
	_ambient_tw.tween_property(_ambient, "volume_db", _ambient_base - 9.0, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambient_tw.tween_interval(2.5)
	_ambient_tw.tween_property(_ambient, "volume_db", _ambient_base, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambient_tw.tween_interval(4.0)
	_ambient_tw.set_loops()


static func ambient_volume(volume_db: float) -> void:
	_ambient_base = volume_db
	if _ambient != null and is_instance_valid(_ambient) and _ambient.playing:
		_kill_ambient_tween()
		_ambient_tw = _ambient.create_tween()
		_ambient_tw.tween_property(_ambient, "volume_db", volume_db, 1.2)
		_ambient_tw.tween_callback(_breathe)


## La sala reacciona a una jugada: el murmullo sube unos segundos y vuelve a su nivel.
static func ambient_swell(up_db: float = 3.0, hold: float = 1.6) -> void:
	if _ambient == null or not is_instance_valid(_ambient) or not _ambient.playing:
		return
	_kill_ambient_tween()
	_ambient_tw = _ambient.create_tween()
	_ambient_tw.tween_property(_ambient, "volume_db", _ambient_base + up_db, 0.5).set_trans(Tween.TRANS_SINE)
	_ambient_tw.tween_interval(hold)
	_ambient_tw.tween_property(_ambient, "volume_db", _ambient_base, 2.5).set_trans(Tween.TRANS_SINE)
	_ambient_tw.tween_callback(_breathe)


static func _kill_ambient_tween() -> void:
	if _ambient_tw != null and _ambient_tw.is_valid():
		_ambient_tw.kill()
	_ambient_tw = null


static func ambient_stop() -> void:
	if _ambient != null and is_instance_valid(_ambient):
		_ambient.stop()


## Un efecto (aplausos, lamento, exclamación). `kind`: el nombre sin número; si hay varios (exclamacion_1.ogg,
## exclamacion_2.ogg…), uno al azar.
static func effect(d: Node, kind: String, volume_db: float = -4.0) -> void:
	var options: Array = []
	for i in range(1, 6):
		var s := _stream("%s_%d.ogg" % [kind, i])
		if s != null:
			options.append(s)
	var single := _stream("%s.ogg" % kind)
	if single != null:
		options.append(single)
	if options.is_empty():
		return
	if _fx == null or not is_instance_valid(_fx):
		_fx = AudioStreamPlayer.new()
		d.add_child(_fx)
	_fx.stream = options[randi() % options.size()]
	_fx.volume_db = volume_db
	_fx.play()


## El público reacciona a una gran jugada: una captura de torre o dama, una coronación o un jaque mate.
## Como mucho una vez cada 20 segundos (si no, cansa).
static func react(d: Node, before: Chess, m: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_cheer < 20000:
		return
	var captured := before.b[Chess.move_to(m)]
	var big := captured != 0 and Chess.type_of(captured) in [Chess.ROOK, Chess.QUEEN]
	var after := Chess.from_fen(before.fen())
	after.apply(m)
	if after.is_checkmate():
		return  # Al acabar suenan los aplausos o el lamento.
	if big or Chess.move_promo(m) != 0:
		_last_cheer = now
		effect(d, "exclamacion", CROWD_DB)
		ambient_swell()


# --- Lista de salas ---

static func open_list(d: Variant) -> void:
	var page: Dictionary = d._page("campeonato")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var ink: Color = d._c("ink")
	var quiet: Color = d._c("quiet")
	body.add_child(d._para("Campeonato", d.F_TITLE + 8, ink, d.font_display))
	body.add_child(d._spacer(6.0))
	body.add_child(d._para("Elige el formato y el ritmo, con reloj y sin ayudas, como en un torneo de verdad. Cuanto más alto el nivel, más elegante la sala.", d.F_SUB, quiet, d.font_medium))
	body.add_child(d._spacer(30.0))
	var st: Dictionary = d.campeonato_state()
	var you: float = d.campeonato_elo()
	for t: Dictionary in Campeonato.TOURNAMENTS:
		if str(t["key"]) == "hotel" and not bool(d.campeonato_stockfish()):
			continue
		body.add_child(_room_card(d, t, st, you))
		body.add_child(d._spacer(24.0))
	body.add_child(d._para("Los rivales son personajes inventados: todos son bots de la app. Las fotos están hechas con IA.", d.F_FOOT, quiet, d.font_regular))
	body.add_child(d._spacer(8.0, true))
	footer.add_child(d._button("home", "Inicio", Callable(d, "_open_home"), d._c("field"), ink, {"font_size": d.F_SUB, "height": 96.0, "icon": 44.0, "font": d.font_medium}))


## Tarjeta de una sala: su foto, el nombre, dónde se juega, el Elo de los rivales y cómo va.
static func _room_card(d: Variant, t: Dictionary, st: Dictionary, you: float) -> Button:
	var key := str(t["key"])
	var open := Campeonato.unlocked(st, key, you)
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size = Vector2(0.0, 380.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if open:
		card.pressed.connect(Callable(d, "_open_campeonato_room").bind(key))
	else:
		card.pressed.connect(Callable(d, "_campeonato_locked").bind(_lock_text(t, st)))
	var clip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2a2a33")
	sb.set_corner_radius_all(36)
	clip.add_theme_stylebox_override("panel", sb)
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(clip)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(holder)
	var pic := cover(photo(Campeonato.room_path(key, "pasillo")))
	if not open:
		pic.modulate = Color(0.55, 0.55, 0.6)
	holder.add_child(pic)
	holder.add_child(_shade(0.15, 0.82))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 4)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 36.0
	col.offset_right = -36.0
	col.offset_bottom = -28.0
	holder.add_child(col)
	var white := Color(1, 1, 1)
	col.add_child(d._para(str(t["name"]), d.F_TITLE2, white, d.font_display))
	var span := _elo_span(key)
	col.add_child(d._para(Loc.t(str(t["place"])) + " · " + Loc.f("Rivales de %d a %d", [span[0], span[1]]), d.F_FOOT, Color(1, 1, 1, 0.86), d.font_medium))
	var chips := HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("h_separation", 10)
	var clock: Array = t["clock"]
	chips.add_child(d._chip("%d+%d" % [int(clock[0]), int(clock[1])], Color(1, 1, 1, 0.9), Color("22222a"), "clock"))
	var state := _state_text(d, key, st)
	if not open:
		chips.add_child(d._chip("Cerrada", Color(1, 1, 1, 0.9), Color("22222a"), "block"))
	elif state != "":
		chips.add_child(d._chip(state, d._tint("butter")[0], d._tint("butter")[1], "crown" if state.begins_with(Loc.t("Campeón")) else "flag"))
	if Campeonato.premium_from(key) == 0:
		chips.add_child(d._chip("Premium", d._tint("lilac")[0], d._tint("lilac")[1], "spark"))
	col.add_child(d._spacer(6.0))
	col.add_child(chips)
	return card


## Degradado oscuro de abajo arriba, para leer el texto blanco sobre la foto.
static func _shade(top_alpha: float, bottom_alpha: float) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, top_alpha))
	g.set_color(1, Color(0, 0, 0, bottom_alpha))
	g.set_offset(0, 0.35)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


static func _elo_span(key: String) -> Array:
	var lo := 99999
	var hi := 0
	for r: Dictionary in Campeonato.RIVALS.get(key, []):
		lo = mini(lo, int(r["elo"]))
		hi = maxi(hi, int(r["elo"]))
	return [lo, hi]


static func _lock_text(t: Dictionary, st: Dictionary) -> String:
	var i := Campeonato.index_of(str(t["key"]))
	var prev: Dictionary = Campeonato.TOURNAMENTS[maxi(0, i - 1)]
	return Loc.f("Se abre al ganar «%s» o al llegar a %d de nivel de juego.", [Loc.t(str(prev["name"])), int(_elo_span(str(t["key"]))[0])])


static func _state_text(_d: Variant, key: String, st: Dictionary) -> String:
	var t: Dictionary = (st.get("torneos", {}) as Dictionary).get(key, {})
	var titles := int((st.get("titulos", {}) as Dictionary).get(key, 0))
	if not t.is_empty() and str(t.get("estado", "")) == "en_curso":
		return Loc.f("En juego: %s", Campeonato.round_title(t, int(t["ronda"])))
	if titles > 0:
		return Loc.t("Campeón") + ("" if titles == 1 else " ×%d" % titles)
	return ""


# --- Cuadro de un torneo ---

## Al volver de una partida («animate»): las derrotas de la ronda y los nuevos emparejamientos se van enseñando.
const ROUND_NONE := -99


static func open_room(d: Variant, key: String, news: String = "", animate: bool = false) -> void:
	var t := Campeonato.tournament(key)
	var page: Dictionary = d._page("campeonato_sala")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var ink: Color = d._c("ink")
	var quiet: Color = d._c("quiet")
	var st: Dictionary = d.campeonato_state()
	var tour: Dictionary = (st["torneos"] as Dictionary).get(key, {})
	# Cabecera: la foto de la entrada con el nombre del torneo.
	var head := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2a2a33")
	sb.set_corner_radius_all(36)
	head.add_theme_stylebox_override("panel", sb)
	head.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	head.custom_minimum_size = Vector2(0.0, 300.0)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(holder)
	var entrance := photo(Campeonato.room_path(key, "entrada"))
	holder.add_child(cover(entrance if entrance != null else photo(Campeonato.room_path(key, "pasillo"))))
	holder.add_child(_shade(0.1, 0.8))
	var hcol := VBoxContainer.new()
	hcol.alignment = BoxContainer.ALIGNMENT_END
	hcol.set_anchors_preset(Control.PRESET_FULL_RECT)
	hcol.offset_left = 36.0
	hcol.offset_right = -36.0
	hcol.offset_bottom = -24.0
	hcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(hcol)
	hcol.add_child(d._para(str(t["name"]), d.F_TITLE2, Color.WHITE, d.font_display))
	var place := Loc.t(str(t["place"]))
	if not tour.is_empty():
		var clock := Campeonato.base_clock(tour, key)
		place += " · " + Loc.f("%d min + %d s por jugada", [int(clock[0]), int(clock[1])])
	hcol.add_child(d._para(place, d.F_FOOT, Color(1, 1, 1, 0.86), d.font_medium))
	body.add_child(head)
	body.add_child(d._spacer(24.0))
	if news != "":
		var tone: Array = d._tint("butter")
		body.add_child(d._chip(news, tone[0], tone[1], "flag"))
		body.add_child(d._spacer(18.0))
	var estado := str(tour.get("estado", ""))
	if tour.is_empty():
		body.add_child(d._para("Siete rivales te esperan. Elige cómo jugar el torneo.", d.F_BODY, ink, d.font_semibold))
		body.add_child(d._spacer(18.0))
		body.add_child(_rival_strip(d, key))
	else:
		var fmt := Campeonato.format_def(Campeonato.format_of(tour))
		var clock := Campeonato.base_clock(tour, key)
		var tone2: Array = d._tint("sky")
		body.add_child(d._chip("%s · %d+%d" % [Loc.t(str(fmt["name"])), int(clock[0]), int(clock[1])], tone2[0], tone2[1], str(fmt["icon"])))
		body.add_child(d._spacer(18.0))
		var mm := Campeonato.current_match(tour, key)
		if not mm.is_empty() and int(mm["juegos"]) == 2 and int(mm["juego"]) == 1:
			var tone3: Array = d._tint("butter")
			body.add_child(d._chip(Loc.f("Marcador del mini-match: %s – %s", [pts_text(float(mm["marcador"])), pts_text(1.0 - float(mm["marcador"]))]), tone3[0], tone3[1], "flag"))
			body.add_child(d._spacer(18.0))
		var anim := {}
		var blocks: Array = []
		if animate:
			anim = {"hecha": -1}
			var winners_all: Array = tour.get("ganadores", [])
			for r in winners_all.size():
				if not (winners_all[r] as Array).is_empty():
					anim["hecha"] = r
			var n_pairs := Campeonato.pairs(tour, maxi(0, int(anim["hecha"]))).size()
			anim["nuevos"] = 0.6 + 0.55 * float(n_pairs) + 0.6
			if Campeonato.is_table(tour):
				anim = {"tabla": true}
			elif int(anim["hecha"]) < 0:
				anim = {}
		if Campeonato.is_table(tour):
			body.add_child(_table_block(d, key, tour, anim))
			body.add_child(d._spacer(18.0))
		else:
			var hecha := int(anim["hecha"]) if not anim.is_empty() else ROUND_NONE
			if hecha == ROUND_NONE:
				var gan: Array = tour.get("ganadores", [])
				for r in gan.size():
					if not (gan[r] as Array).is_empty():
						hecha = r
			body.add_child(CampeonatoCuadro.create(d, key, tour, not anim.is_empty(), maxi(0, hecha)))
			body.add_child(d._spacer(18.0))
	body.add_child(d._spacer(8.0, true))
	var go := {"font_size": d.F_BODY, "height": 116.0, "icon": 56.0, "radius": 58, "trailing": true, "glow": d._c("glow")}
	var plain := {"font_size": d.F_SUB, "height": 96.0, "icon": 44.0, "font": d.font_medium}
	if tour.is_empty() or estado != "en_curso":
		var label := "Empezar el torneo" if tour.is_empty() else "Jugar otro torneo"
		footer.add_child(d._button("play", label, Callable(d, "_campeonato_options").bind(key), d._c("accent"), d._c("accent_ink"), go))
	else:
		var m := Campeonato.current_match(tour, key)
		var label := Loc.f("Jugar: %s", str(m["titulo"]))
		if int(m["desempate"]) == 1:
			label = Loc.t("Jugar el desempate")
		elif int(m["desempate"]) >= 2:
			label = Loc.t("Jugar el armagedón")
		var b: Button = d._button("play", label, Callable(d, "_campeonato_play").bind(key), d._c("accent"), d._c("accent_ink"), go)
		footer.add_child(b)
		if Campeonato.needs_premium(tour, Premium.active(), key):
			footer.add_child(d._para(_premium_note(key, tour), d.F_FOOT, quiet, d.font_medium))
	footer.add_child(d._button("back", "Salas", Callable(d, "_open_campeonato"), d._c("field"), ink, plain))


## Los siete rivales, en fila, antes de empezar.
static func _rival_strip(d: Variant, key: String) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 18)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r: Dictionary in Campeonato.RIVALS.get(key, []):
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 6)
		col.custom_minimum_size = Vector2(220.0, 0.0)
		col.add_child(_face(d, key, str(r["id"]), 150.0))
		var n: Label = d._line(str(r["name"]).split(" ")[0], d.F_CAP + 2, d._c("ink"), d.font_semibold)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var e: Label = d._line("%d" % int(r["elo"]), d.F_CAP, d._c("quiet"), d.font_medium)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(e)
		flow.add_child(col)
	return flow


## Cara redonda de un participante (tú: tu insignia de pieza).
static func _face(d: Variant, key: String, id: String, side: float) -> Control:
	var disc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = d._c("field")
	sb.set_corner_radius_all(int(side / 2.0))
	sb.border_color = d._c("surface")
	sb.set_border_width_all(4)
	disc.add_theme_stylebox_override("panel", sb)
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	disc.custom_minimum_size = Vector2(side, side)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id == Campeonato.YOU:
		var c := CenterContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(d._icon("piece_king", side * 0.55, d._c("ink")))
		disc.add_child(c)
		return disc
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(holder)
	var pic := cover(photo(Campeonato.portrait_path(key, id)))
	# Los retratos son de cabeza y hombros: la cara va en el tercio de arriba.
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	holder.add_child(pic)
	return disc


## Recorte de la cara de un retrato: [x, y, lado] en fracciones del ancho y del alto. Medido con
## tools/campeonato/caras.py (data/campeonato_caras.json); si falta, la parte de arriba del centro.
static func face_region(key: String, id: String) -> Array:
	if _faces.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/campeonato_caras.json")) if FileAccess.file_exists("res://data/campeonato_caras.json") else null
		_faces = data if data is Dictionary else {"": []}
	var r: Variant = _faces.get("%s/%s" % [key, id], [])
	if r is Array and (r as Array).size() == 3:
		return r
	return [0.2, 0.0, 0.6]


## El rival encima del tablero en las partidas del Campeonato (arriba a la izquierda, como en chess.com): su cara,
## su nombre y que es un bot. `thinking`: le toca; el aro de la cara late y dice «pensando…».
static func game_tag(d: Variant, key: String, id: String, thinking: bool, side: float) -> Control:
	var rival := Campeonato.rival(key, id)
	var pill := PanelContainer.new()
	pill.name = "campeonato_rival"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	var paper: Color = d._c("surface")
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.94)
	sb.set_corner_radius_all(int(side / 2.0) + 10)
	sb.content_margin_left = 10.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.content_margin_right = 36.0
	sb.shadow_color = d._c("shadow")
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0.0, 4.0)
	pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	pill.add_child(row)
	var disc := PanelContainer.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(side, side)
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var ring := StyleBoxFlat.new()
	ring.bg_color = d._c("field")
	ring.set_corner_radius_all(int(side / 2.0))
	ring.set_border_width_all(6)
	var accent: Color = d._c("accent")
	ring.border_color = accent if thinking else d._c("field")
	disc.add_theme_stylebox_override("panel", ring)
	var tex := photo(Campeonato.portrait_path(key, id))
	if tex != null:
		var reg := face_region(key, id)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(float(reg[0]) * tex.get_width(), float(reg[1]) * tex.get_height(), float(reg[2]) * tex.get_width(), float(reg[2]) * tex.get_width())
		var pic := TextureRect.new()
		pic.texture = at
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.add_child(pic)
	row.add_child(disc)
	if thinking:
		# Mientras piensa, el aro late despacio.
		var beat := pill.create_tween().set_loops()
		beat.tween_property(ring, "border_color", Color(accent.r, accent.g, accent.b, 0.35), 0.7).set_trans(Tween.TRANS_SINE)
		beat.tween_property(ring, "border_color", accent, 0.7).set_trans(Tween.TRANS_SINE)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	col.add_child(d._line(str(rival.get("name", "")), d.F_SUB, d._c("ink"), d.font_semibold))
	var sub := Loc.t("Bot · pensando…") if thinking else Loc.f("Bot · Elo %d", int(rival.get("elo", 0)))
	col.add_child(d._line(sub, d.F_CAP, d._c("accent_text") if thinking else d._c("quiet"), d.font_medium))
	row.add_child(col)
	var quiet := mute_button(d, minf(side * 0.62, 72.0))
	quiet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(quiet)
	return pill


## Una ronda de la eliminatoria. Con «anim» (al volver de una partida): la ronda recién decidida enseña sus derrotas
## una a una, y las siguientes aparecen después con sus nuevos emparejamientos.
static func _round_block(d: Variant, key: String, tour: Dictionary, r: int, anim: Dictionary = {}) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var playing := str(tour.get("estado", "")) == "en_curso" and int(tour.get("ronda", 0)) == r
	var title := Campeonato.round_title(tour, r)
	if r >= Campeonato.premium_from(key):
		title += " · Premium"
	col.add_child(d._line(title.to_upper(), d.F_CAP, d._c("accent_text") if playing else d._c("quiet"), d.font_semibold))
	var winners: Array = (tour["ganadores"] as Array)[r]
	var pairs := Campeonato.pairs(tour, r) if r == 0 or not ((tour["ganadores"] as Array)[r - 1] as Array).is_empty() else []
	if pairs.is_empty():
		col.add_child(d._para("Por decidir.", d.F_SUB, d._c("quiet"), d.font_medium))
		return col
	var done := int(anim.get("hecha", -1))
	var delay_new := float(anim.get("nuevos", 0.0))
	for j in pairs.size():
		var pr: Array = pairs[j]
		var box := _pair_box(d, key, pr, {"winners": winners, "highlight": pr.has(Campeonato.YOU) and playing, "elo_tu": float(tour.get("elo_tu", 0.0))})
		col.add_child(box)
		if not anim.is_empty():
			if r == done:
				_strike(box, 0.6 + 0.55 * j)
			elif r > done:
				_reveal(box, delay_new + 1.3 * float(r - done - 1) + 0.4 * j)
	return col


## Dos jugadores en una tarjeta: cara, nombre, Elo y, si lo hay, su resultado. Los que pierden salen apagados y con
## una cruz (se pueden tachar poco a poco con _strike). «scores»: {id: texto} para las partidas con tabla.
static func _pair_box(d: Variant, key: String, pr: Array, opts: Dictionary) -> PanelContainer:
	var winners: Array = opts.get("winners", [])
	var scores: Dictionary = opts.get("scores", {})
	var box := _paper(d, bool(opts.get("highlight", false)))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	box.add_child(rows)
	var made: Array = []
	for id: String in pr:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_face(d, key, id, 76.0))
		var won := winners.has(id)
		var lost := not winners.is_empty() and not won
		var name: Label = d._line(Campeonato.display_name(key, id), d.F_SUB, d._c("ink"), d.font_semibold if won else d.font_medium)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name)
		var elo: Label = d._line("%d" % roundi(Campeonato.elo_of(key, id, float(opts.get("elo_tu", 0.0)))), d.F_FOOT, d._c("quiet"), d.font_medium)
		elo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(elo)
		if scores.has(id):
			var sc: Label = d._line(str(scores[id]), d.F_SUB, d._c("ink"), d.font_display)
			sc.custom_minimum_size.x = 56.0
			sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			sc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(sc)
		if won:
			row.add_child(d._icon("check", 44.0, d._c("good")))
		var cross: Control = null
		if lost:
			cross = d._icon("close", 44.0, Color("c0392b"))
			row.add_child(cross)
			row.modulate.a = 0.45
		row.set_meta("lost", lost)
		row.set_meta("cross", cross)
		rows.add_child(row)
		made.append(row)
	box.set_meta("rows", made)
	return box


## Aparece poco a poco (con un ligero desplazamiento hacia arriba) tras «delay» segundos.
static func _reveal(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(node, "modulate:a", 1.0, 0.5)


## Tacha al perdedor de la tarjeta: se apaga y le sale la cruz, tras «delay» segundos.
static func _strike(box: Control, delay: float) -> void:
	for row: Control in box.get_meta("rows", []):
		if not bool(row.get_meta("lost", false)):
			continue
		row.modulate.a = 1.0
		var cross: Control = row.get_meta("cross")
		if cross != null:
			cross.modulate.a = 0.0
		var tw := row.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(row, "modulate:a", 0.45, 0.5)
		if cross != null:
			var tx := cross.create_tween()
			tx.tween_interval(delay)
			tx.tween_property(cross, "modulate:a", 1.0, 0.3)
			cross.pivot_offset = Vector2(22.0, 22.0)
			var tp := cross.create_tween()
			tp.tween_interval(delay)
			tp.tween_property(cross, "scale", Vector2(1.5, 1.5), 0.15)
			tp.tween_property(cross, "scale", Vector2.ONE, 0.2)


## Lleva el scroll de la página hasta un bloque, tras «delay» segundos.
static func _scroll_to(d: Variant, node: Control, delay: float, dur: float = 0.8) -> void:
	await (d as Node).get_tree().create_timer(delay).timeout
	if not is_instance_valid(node) or d.progress_scroll == null or not is_instance_valid(d.progress_scroll):
		return
	var sc: ScrollContainer = d.progress_scroll
	var target := int(node.global_position.y - sc.global_position.y + float(sc.scroll_vertical)) - 24
	target = clampi(target, 0, maxi(0, int(sc.get_v_scroll_bar().max_value)))
	sc.create_tween().tween_property(sc, "scroll_vertical", target, dur).set_trans(Tween.TRANS_SINE)


## Puntos en texto: 0, ½, 1, 1½…
static func pts_text(p: float) -> String:
	var whole := int(floor(p + 0.001))
	var half := p - float(whole) > 0.25
	if half:
		return "½" if whole == 0 else "%d½" % whole
	return "%d" % whole


static func _premium_note(key: String, tour: Dictionary) -> String:
	if Campeonato.premium_from(key) == 0:
		return "Todo este torneo es de Premium (juega Stockfish)."
	return "La final es de Premium." if not Campeonato.is_table(tour) else "Desde la tercera ronda es de Premium."


## Tarjeta blanca redondeada para las filas de un torneo.
static func _paper(d: Variant, highlight: bool) -> PanelContainer:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var paper: Color = d._c("surface")
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.92)
	sb.set_corner_radius_all(28)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	if highlight:
		sb.border_color = d._c("accent")
		sb.set_border_width_all(4)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## Cuadrangular, suizo y liga: lo que pasó en la última ronda, la clasificación, la ronda que viene y tus partidas.
## Con «anim»: las partidas de la ronda aparecen una a una, la clasificación se reordena y salen los nuevos cruces.
## Devuelve un contenedor con los bloques; «destino» (meta) es el bloque al que llevar el scroll al final.
static func _table_block(d: Variant, key: String, tour: Dictionary, anim: Dictionary = {}) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var playing := str(tour.get("estado", "")) == "en_curso"
	var res: Array = tour.get("res", [])
	var you_elo := float(tour.get("elo_tu", 0.0))
	var last_r := -1
	for g: Dictionary in res:
		last_r = maxi(last_r, int(g["r"]))
	var animating := not anim.is_empty() and last_r >= 0
	var t_results := 0.5
	var games: Array = []
	for g: Dictionary in res:
		if int(g["r"]) == last_r:
			games.append(g)
	# Tu partida primero.
	games.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return (str(x["a"]) == Campeonato.YOU or str(x["b"]) == Campeonato.YOU) and not (str(y["a"]) == Campeonato.YOU or str(y["b"]) == Campeonato.YOU))
	var first_block: Control = null
	if last_r >= 0:
		var rb := VBoxContainer.new()
		rb.add_theme_constant_override("separation", 10)
		rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rb.add_child(d._line((Loc.t("Resultados") + " · " + Campeonato.round_title(tour, last_r)).to_upper(), d.F_CAP, d._c("accent_text") if animating else d._c("quiet"), d.font_semibold))
		for j in games.size():
			var g: Dictionary = games[j]
			var a_id := str(g["a"])
			var b_id := str(g["b"])
			var pa := float(g["pa"])
			var winners: Array = []
			if pa > 0.75:
				winners = [a_id]
			elif pa < 0.25:
				winners = [b_id]
			var box := _pair_box(d, key, [a_id, b_id], {"winners": winners, "scores": {a_id: pts_text(pa), b_id: pts_text(1.0 - pa)},
				"highlight": a_id == Campeonato.YOU or b_id == Campeonato.YOU, "elo_tu": you_elo})
			rb.add_child(box)
			if animating:
				_reveal(box, t_results + 0.5 * j)
				_strike(box, t_results + 0.5 * j + 0.5)
		col.add_child(rb)
		col.add_child(d._spacer(8.0))
		first_block = rb
	var t_stand := t_results + 0.5 * games.size() + 0.9 if animating else 0.0
	# Clasificación (antes de la última ronda y ahora).
	var head: Label = d._line(Loc.t("Clasificación").to_upper(), d.F_CAP, d._c("accent_text") if playing else d._c("quiet"), d.font_semibold)
	col.add_child(head)
	var box_t := _paper(d, false)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	box_t.add_child(rows)
	var table := Campeonato.standings(tour, key)
	var old_pos := {}
	var old_pts := {}
	if animating:
		var before := tour.duplicate(true)
		var kept: Array = []
		for g: Dictionary in res:
			if int(g["r"]) < last_r:
				kept.append(g)
		before["res"] = kept
		var prev := Campeonato.standings(before, key)
		for i in prev.size():
			old_pos[str(prev[i]["id"])] = i
			old_pts[str(prev[i]["id"])] = float(prev[i]["pts"])
	var row_nodes: Array = []
	var olds: Array = []
	for i in table.size():
		var row_data: Dictionary = table[i]
		var id := str(row_data["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rank: Label = d._line("%d" % (i + 1), d.F_SUB, d._c("quiet"), d.font_medium)
		rank.custom_minimum_size.x = 40.0
		rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(rank)
		row.add_child(_face(d, key, id, 76.0))
		var name: Label = d._line(Campeonato.display_name(key, id), d.F_SUB, d._c("ink"), d.font_semibold if id == Campeonato.YOU else d.font_medium)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name)
		var elo: Label = d._line("%d" % roundi(Campeonato.elo_of(key, id, you_elo)), d.F_FOOT, d._c("quiet"), d.font_medium)
		elo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(elo)
		var shown_pts := float(old_pts.get(id, row_data["pts"])) if animating else float(row_data["pts"])
		var pts: Label = d._line(pts_text(shown_pts), d.F_SUB, d._c("ink"), d.font_display)
		pts.custom_minimum_size.x = 70.0
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(pts)
		if animating and not is_equal_approx(shown_pts, float(row_data["pts"])):
			var new_text := pts_text(float(row_data["pts"]))
			var tw := pts.create_tween()
			tw.tween_interval(t_stand)
			tw.tween_callback(func() -> void:
				pts.text = new_text
				pts.add_theme_color_override("font_color", d._c("accent_text")))
		rows.add_child(row)
		row_nodes.append(row)
		olds.append(int(old_pos.get(id, i)))
	col.add_child(box_t)
	if animating:
		_slide_rows(d, row_nodes, olds, t_stand)
	col.add_child(d._spacer(8.0))
	# La ronda que viene: todos los cruces.
	var dest: Control = first_block if animating else null
	var next_block: Control = null
	if playing:
		var nr := int(tour["ronda"])
		var nb := VBoxContainer.new()
		nb.add_theme_constant_override("separation", 10)
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nb.add_child(d._line((Loc.t("Siguiente") + " · " + Campeonato.round_title(tour, nr)).to_upper(), d.F_CAP, d._c("accent_text"), d.font_semibold))
		var prs := Campeonato.pairs(tour, nr)
		for j in prs.size():
			var pr: Array = prs[j]
			var bx := _pair_box(d, key, pr, {"highlight": pr.has(Campeonato.YOU), "elo_tu": you_elo})
			nb.add_child(bx)
			if animating:
				_reveal(bx, t_stand + 1.4 + 0.4 * j)
		col.add_child(nb)
		col.add_child(d._spacer(8.0))
		next_block = nb
	# Tus partidas.
	col.add_child(d._line(Loc.t("Tus partidas").to_upper(), d.F_CAP, d._c("quiet"), d.font_semibold))
	var mine := {}
	for g: Dictionary in res:
		if str(g["a"]) == Campeonato.YOU or str(g["b"]) == Campeonato.YOU:
			mine[int(g["r"])] = g
	var current := Campeonato.current_match(tour, key)
	var last_shown := int(tour.get("ronda", 0)) if playing else Campeonato.round_count(tour) - 1
	for r in range(0, last_shown + 1):
		var game_box := _paper(d, playing and r == int(tour.get("ronda", 0)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rival_id := ""
		var result := ""
		if mine.has(r):
			var g: Dictionary = mine[r]
			var you_a := str(g["a"]) == Campeonato.YOU
			rival_id = str(g["b"] if you_a else g["a"])
			result = pts_text(float(g["pa"]) if you_a else 1.0 - float(g["pa"]))
		elif not current.is_empty() and r == int(current["ronda"]):
			rival_id = str(current["rival"])
		var rh: Label = d._line(Campeonato.round_title(tour, r), d.F_FOOT, d._c("quiet"), d.font_medium)
		rh.custom_minimum_size.x = 150.0
		rh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(rh)
		if rival_id != "":
			row.add_child(_face(d, key, rival_id, 60.0))
		var who: Label = d._line(Campeonato.display_name(key, rival_id) if rival_id != "" else "—", d.F_SUB, d._c("ink"), d.font_medium)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(who)
		var res_label: Label = d._line(result if result != "" else Loc.t("Por jugar"), d.F_SUB, d._c("ink") if result != "" else d._c("quiet"), d.font_display if result != "" else d.font_medium)
		res_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(res_label)
		game_box.add_child(row)
		col.add_child(game_box)
	if animating:
		if dest != null:
			_scroll_to(d, dest, 0.35, 0.5)
		if next_block != null:
			_scroll_to(d, next_block, t_stand + 1.2, 1.0)
	return col


## Las filas de la clasificación parten de su puesto anterior y se deslizan al nuevo, tras «delay» segundos.
static func _slide_rows(d: Variant, rows: Array, olds: Array, delay: float) -> void:
	await (d as Node).get_tree().process_frame
	await (d as Node).get_tree().process_frame
	if rows.size() < 2 or not is_instance_valid(rows[0]) or not is_instance_valid(rows[1]):
		return
	var step: float = (rows[1] as Control).position.y - (rows[0] as Control).position.y
	for i in rows.size():
		var row: Control = rows[i]
		if not is_instance_valid(row):
			continue
		var dy := float(int(olds[i]) - i) * step
		if is_zero_approx(dy):
			continue
		var target := row.position.y
		row.position.y = target + dy
		row.z_index = 1 if dy > 0.0 else 0
		var tw := row.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(row, "position:y", target, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- El paseo hasta la mesa ---

## Fotos a pantalla completa con movimiento (entrada → pasillo → tu rival en la mesa) y el murmullo de la sala.
## Al final, la tarjeta del rival con «Sentarse a jugar». Un toque salta al final.
static func walk(d: Variant, key: String) -> void:
	var st: Dictionary = d.campeonato_state()
	var tour: Dictionary = (st["torneos"] as Dictionary)[key]
	var m := Campeonato.current_match(tour, key)
	var rival := Campeonato.rival(key, str(m["rival"]))
	var layer := Control.new()
	layer.name = "CampeonatoPaseo"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	(d as Node).add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	ambient_start(d, key, -15.0)
	var shots: Array = [Campeonato.room_path(key, "entrada"), Campeonato.room_path(key, "pasillo"), Campeonato.portrait_path(key, str(m["rival"]))]
	var state := {"skip": false, "done": false}
	var skipper := Button.new()
	skipper.flat = true
	skipper.focus_mode = Control.FOCUS_NONE
	skipper.set_anchors_preset(Control.PRESET_FULL_RECT)
	skipper.pressed.connect(func() -> void: state["skip"] = true)
	layer.add_child(skipper)
	var quiet := mute_button(d, 84.0)
	quiet.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quiet.position = Vector2((d as Control).size.x - 84.0 - 28.0, 70.0)
	layer.add_child(quiet)
	var size: Vector2 = (d as Control).size
	var prev: TextureRect = null
	for i in shots.size():
		if state["skip"] or not is_instance_valid(layer):
			break
		var tex := photo(str(shots[i]))
		if tex == null:
			continue
		var pic := cover(tex)
		pic.pivot_offset = size / 2.0
		pic.modulate.a = 0.0
		layer.add_child(pic)
		layer.move_child(pic, layer.get_child_count() - 2)
		var last := i == shots.size() - 1
		var tw := pic.create_tween().set_parallel(true)
		tw.tween_property(pic, "modulate:a", 1.0, FADE)
		# Se avanza hacia el fondo de la sala (acercando la imagen); el rival, más despacio.
		pic.scale = Vector2.ONE * (1.0 if not last else 1.04)
		tw.tween_property(pic, "scale", Vector2.ONE * (1.10 if not last else 1.0), SHOT_TIME + FADE).set_trans(Tween.TRANS_SINE)
		# Foto viva: al andar, lo cercano se desplaza más que el fondo (en el rival, el foco en la persona).
		var mat := alive(pic, str(shots[i]), 0.55 if last else 0.3)
		if mat != null:
			var to := Vector2(0.010, -0.016) if not last else Vector2(-0.006, -0.008)
			tw.tween_property(mat, "shader_parameter/shift", to, SHOT_TIME + FADE).from(Vector2(-0.004, 0.0)).set_trans(Tween.TRANS_SINE)
		if prev != null:
			var old := prev
			pic.create_tween().tween_property(old, "modulate:a", 0.0, FADE).finished.connect(func() -> void:
				if is_instance_valid(old):
					old.queue_free())
		prev = pic
		var waited := 0.0
		var stay := SHOT_TIME if not last else FADE
		while waited < stay and not state["skip"] and is_instance_valid(layer):
			await (d as Node).get_tree().process_frame
			waited += (d as Node).get_process_delta_time()
	if not is_instance_valid(layer):
		return
	skipper.queue_free()
	if prev == null:
		prev = cover(photo(Campeonato.portrait_path(key, str(m["rival"]))))
		prev.pivot_offset = size / 2.0
		layer.add_child(prev)
	# El rival «respira»: un vaivén lento de la cámara mientras lees su tarjeta.
	var still := prev.material as ShaderMaterial
	if still == null:
		still = alive(prev, Campeonato.portrait_path(key, str(m["rival"])), 0.55)
	if still != null:
		var loop := prev.create_tween().set_loops()
		loop.tween_property(still, "shader_parameter/shift", Vector2(0.007, -0.004), 3.4).set_trans(Tween.TRANS_SINE)
		loop.tween_property(still, "shader_parameter/shift", Vector2(-0.007, -0.008), 3.4).set_trans(Tween.TRANS_SINE)
	_rival_card(d, layer, key, m, rival)


## Tarjeta del rival sobre su foto: quién es, que es un bot, el reloj, tu color y «Sentarse a jugar».
static func _rival_card(d: Variant, layer: Control, key: String, m: Dictionary, rival: Dictionary) -> void:
	layer.add_child(_shade(0.0, 0.85))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset: Vector2 = d._insets()
	col.offset_left = 56.0
	col.offset_right = -56.0
	col.offset_bottom = -(inset.y + 48.0)
	col.add_theme_constant_override("separation", 10)
	layer.add_child(col)
	var white := Color.WHITE
	var soft := Color(1, 1, 1, 0.86)
	var round_name := str(m["titulo"])
	if int(m["desempate"]) == 1:
		round_name += " · " + Loc.t("Desempate")
	elif int(m["desempate"]) >= 2:
		round_name += " · " + Loc.t("Armagedón")
	col.add_child(d._line(round_name.to_upper(), d.F_CAP + 2, soft, d.font_semibold))
	col.add_child(d._para(str(rival.get("name", "")), d.F_TITLE + 6, white, d.font_display))
	col.add_child(d._para(Loc.f("%d años · %s · %s", [int(rival.get("age", 0)), Loc.t(str(rival.get("job", ""))), Loc.t(str(rival.get("from", "")))]), d.F_SUB, soft, d.font_medium))
	col.add_child(d._para("«%s»" % Loc.t(str(rival.get("bio", ""))), d.F_SUB, soft, d.font_regular))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lv := int(m["level"])
	chips.add_child(d._chip(Loc.f("Bot · Elo %d", int(rival.get("elo", 0))), Color(1, 1, 1, 0.92), Color("22222a"), "bot"))
	var clock: Array = m["clock"]
	chips.add_child(d._chip("%d+%d" % [int(clock[0]), int(clock[1])], Color(1, 1, 1, 0.92), Color("22222a"), "clock"))
	chips.add_child(d._chip("Juegas con blancas" if int(m["color"]) == 0 else "Juegas con negras", Color(1, 1, 1, 0.92), Color("22222a"), "sun" if int(m["color"]) == 0 else "moon"))
	col.add_child(d._spacer(6.0))
	col.add_child(chips)
	if int(m["desempate"]) >= 2:
		col.add_child(d._para("Armagedón: si hay tablas, pasan las negras.", d.F_FOOT, soft, d.font_medium))
	col.add_child(d._spacer(18.0))
	var go := {"font_size": d.F_BODY, "height": 116.0, "icon": 56.0, "radius": 58, "trailing": true, "glow": d._c("glow")}
	col.add_child(d._button("piece_knight", "Sentarse a jugar", func() -> void:
		layer.queue_free()
		d._campeonato_start_game(key, lv), d._c("accent"), d._c("accent_ink"), go))
	col.add_child(d._button("back", "Ahora no", func() -> void:
		layer.queue_free()
		ambient_stop(), Color(1, 1, 1, 0.16), white, {"font_size": d.F_SUB, "height": 92.0, "icon": 44.0, "font": d.font_medium}))
	if bool(d.campeonato_stockfish()) == false and Bot.uses_stockfish(lv):
		col.add_child(d._para("Sin Stockfish en este dispositivo: juega el rival «Muy difícil».", d.F_FOOT, soft, d.font_regular))
