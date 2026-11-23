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
## Volumen de los comentarios del público (exclamaciones, lamento) y de los aplausos, en dB. Bajos: el murmullo
## manda y los comentarios asoman por encima (petición de Pablo, 23 nov: «más murmullos y menos altos los
## comentarios»).
const CROWD_DB := -15.0
const CHEER_DB := -6.0


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


## Murmullo de la sala, en bucle (más bajo durante la partida). Sonidos: tools/campeonato/sonidos.sh (CC0).
static func ambient_start(d: Node, key: String, volume_db: float = -8.0) -> void:
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


static func ambient_volume(volume_db: float) -> void:
	_ambient_base = volume_db
	if _ambient != null and is_instance_valid(_ambient) and _ambient.playing:
		_kill_ambient_tween()
		_ambient_tw = _ambient.create_tween()
		_ambient_tw.tween_property(_ambient, "volume_db", volume_db, 1.2)


## La sala reacciona a una jugada: el murmullo sube unos segundos y vuelve a su nivel.
static func ambient_swell(up_db: float = 6.0, hold: float = 2.2) -> void:
	if _ambient == null or not is_instance_valid(_ambient) or not _ambient.playing:
		return
	_kill_ambient_tween()
	_ambient_tw = _ambient.create_tween()
	_ambient_tw.tween_property(_ambient, "volume_db", _ambient_base + up_db, 0.5).set_trans(Tween.TRANS_SINE)
	_ambient_tw.tween_interval(hold)
	_ambient_tw.tween_property(_ambient, "volume_db", _ambient_base, 2.5).set_trans(Tween.TRANS_SINE)


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
	body.add_child(d._para("Ocho jugadores y eliminatoria, con reloj y sin ayudas, como en un torneo de verdad. Cuanto más alto el nivel, más elegante la sala.", d.F_SUB, quiet, d.font_medium))
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
		return Loc.f("En juego: %s", Loc.t(str(Campeonato.ROUNDS[int(t["ronda"])])))
	if titles > 0:
		return Loc.t("Campeón") + ("" if titles == 1 else " ×%d" % titles)
	return ""


# --- Cuadro de un torneo ---

static func open_room(d: Variant, key: String, news: String = "") -> void:
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
	var clock: Array = t["clock"]
	hcol.add_child(d._para(Loc.t(str(t["place"])) + " · " + Loc.f("%d min + %d s por jugada", [int(clock[0]), int(clock[1])]), d.F_FOOT, Color(1, 1, 1, 0.86), d.font_medium))
	body.add_child(head)
	body.add_child(d._spacer(24.0))
	if news != "":
		var tone: Array = d._tint("butter")
		body.add_child(d._chip(news, tone[0], tone[1], "flag"))
		body.add_child(d._spacer(18.0))
	if tour.is_empty():
		body.add_child(d._para("Siete rivales te esperan. Ganas tres partidas y eres campeón.", d.F_BODY, ink, d.font_semibold))
		body.add_child(d._spacer(18.0))
		body.add_child(_rival_strip(d, key))
	else:
		for r in Campeonato.ROUNDS.size():
			body.add_child(_round_block(d, key, tour, r))
			body.add_child(d._spacer(18.0))
	body.add_child(d._spacer(8.0, true))
	var go := {"font_size": d.F_BODY, "height": 116.0, "icon": 56.0, "radius": 58, "trailing": true, "glow": d._c("glow")}
	var plain := {"font_size": d.F_SUB, "height": 96.0, "icon": 44.0, "font": d.font_medium}
	var estado := str(tour.get("estado", ""))
	if tour.is_empty() or estado != "en_curso":
		var label := "Empezar el torneo" if tour.is_empty() else "Jugar otro torneo"
		footer.add_child(d._button("play", label, Callable(d, "_campeonato_new").bind(key), d._c("accent"), d._c("accent_ink"), go))
	else:
		var m := Campeonato.current_match(tour, key)
		var round_name := Loc.t(str(Campeonato.ROUNDS[int(m["ronda"])]))
		var label := Loc.f("Jugar: %s", round_name)
		if int(m["desempate"]) == 1:
			label = Loc.t("Jugar el desempate")
		elif int(m["desempate"]) >= 2:
			label = Loc.t("Jugar el armagedón")
		var b: Button = d._button("play", label, Callable(d, "_campeonato_play").bind(key), d._c("accent"), d._c("accent_ink"), go)
		footer.add_child(b)
		if Campeonato.needs_premium(tour, Premium.active(), key):
			footer.add_child(d._para("Todo este torneo es de Premium (juega Stockfish)." if Campeonato.premium_from(key) == 0 else "La final es de Premium.", d.F_FOOT, quiet, d.font_medium))
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
	return pill


## Una ronda del cuadro: sus partidas, con el ganador resaltado.
static func _round_block(d: Variant, key: String, tour: Dictionary, r: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var playing := str(tour.get("estado", "")) == "en_curso" and int(tour.get("ronda", 0)) == r
	var title := Loc.t(str(Campeonato.ROUNDS[r]))
	if r >= Campeonato.premium_from(key):
		title += " · Premium"
	col.add_child(d._line(title.to_upper(), d.F_CAP, d._c("accent_text") if playing else d._c("quiet"), d.font_semibold))
	var winners: Array = (tour["ganadores"] as Array)[r]
	var pairs := Campeonato.pairs(tour, r) if r == 0 or not ((tour["ganadores"] as Array)[r - 1] as Array).is_empty() else []
	if pairs.is_empty():
		col.add_child(d._para("Por decidir.", d.F_SUB, d._c("quiet"), d.font_medium))
		return col
	for pr: Array in pairs:
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		var paper: Color = d._c("surface")
		sb.bg_color = Color(paper.r, paper.g, paper.b, 0.92)
		sb.set_corner_radius_all(28)
		sb.content_margin_left = 22.0
		sb.content_margin_right = 22.0
		sb.content_margin_top = 14.0
		sb.content_margin_bottom = 14.0
		if pr.has(Campeonato.YOU) and playing:
			sb.border_color = d._c("accent")
			sb.set_border_width_all(4)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 8)
		box.add_child(rows)
		for id: String in pr:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(_face(d, key, id, 76.0))
			var won := winners.has(id)
			var lost := not winners.is_empty() and not won
			var name: Label = d._line(Campeonato.display_name(key, id), d.F_SUB, d._c("ink") if not lost else d._c("quiet"), d.font_semibold if won else d.font_medium)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(name)
			var elo := roundi(Campeonato.elo_of(key, id, float(tour.get("elo_tu", 0.0))))
			var e: Label = d._line("%d" % elo, d.F_FOOT, d._c("quiet"), d.font_medium)
			e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(e)
			if won:
				row.add_child(d._icon("check", 44.0, d._c("good")))
			rows.add_child(row)
		col.add_child(box)
	return col


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
	ambient_start(d, key, -6.0)
	var shots: Array = [Campeonato.room_path(key, "entrada"), Campeonato.room_path(key, "pasillo"), Campeonato.portrait_path(key, str(m["rival"]))]
	var state := {"skip": false, "done": false}
	var skipper := Button.new()
	skipper.flat = true
	skipper.focus_mode = Control.FOCUS_NONE
	skipper.set_anchors_preset(Control.PRESET_FULL_RECT)
	skipper.pressed.connect(func() -> void: state["skip"] = true)
	layer.add_child(skipper)
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
	var round_name := Loc.t(str(Campeonato.ROUNDS[int(m["ronda"])]))
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
