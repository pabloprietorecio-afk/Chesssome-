class_name CampeonatoCuadro
extends Control
## El cuadro de una copa (Campeonato) como una pirámide de cartas con foto clavadas en un corcho (en el gran hotel,
## una pantalla gigante): cuartos abajo (8 cartas), semifinal (4), final (2) y el campeón arriba. Cada pareja,
## unida por un hilo entre sus chinchetas. Al volver de una partida (Pablo, 23 nov, a partir de un vídeo de
## PixVerse): a cada eliminado se le tacha con una X roja y su carta se deshace en polvo; la de cada vencedor sube
## con una estela suave a la fila de arriba, que levita sobre el corcho con su sombra. Al final, corona y fanfarria.

const PAD := 22.0
const LABEL_H := 44.0
const ROW_GAP := 34.0
const PAIR_GAP := 8.0
const GROUP_GAP := 22.0
## Ancho de las cartas de semifinal, final y campeón (las de cuartos se reparten el ancho).
const CARD_W := [0.0, 156.0, 196.0, 236.0]
const NAME_H := [36.0, 44.0, 50.0, 56.0]
const PHOTO_RATIO := 1.25
const CARD_PAD := 7.0
const LEVELS := 4
const TEX := "res://textures/campeonato/"
const GOLD := Color("f2b01e")
const RED := Color("d0302a")

## Hilos entre las parejas (de chincheta a chincheta, combados) y estelas de las cartas que suben.
class Threads extends Control:
	var links: Array = []
	var trails: Array = []
	var color := Color("c0392b")
	var glow := Color("ffe9b0")

	func _process(_delta: float) -> void:
		if not links.is_empty() or not trails.is_empty():
			queue_redraw()

	func _draw() -> void:
		for link: Dictionary in links:
			var p := float(link["p"])
			var a: Control = link["a"]
			var b: Control = link["b"]
			if p <= 0.0 or not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var pa := Threads.pin_of(a)
			var pb := Threads.pin_of(b)
			var sag := 12.0 + 0.05 * pa.distance_to(pb)
			var pts := PackedVector2Array()
			for i in 25:
				var t := p * float(i) / 24.0
				pts.append(pa.lerp(pb, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
			draw_polyline(pts, Color(0.1, 0.03, 0.0, 0.25), 6.0, true)
			draw_polyline(pts, color, 3.5, true)
		for tr: Dictionary in trails:
			var pts: PackedVector2Array = tr["pts"]
			var alpha := float(tr["alpha"])
			if pts.size() < 2 or alpha <= 0.0:
				continue
			var n := pts.size()
			for i in range(1, n):
				var k := float(i) / float(n)
				draw_line(pts[i - 1], pts[i], Color(glow.r, glow.g, glow.b, 0.16 * alpha * k), 46.0 * k + 6.0, true)
				draw_line(pts[i - 1], pts[i], Color(1.0, 1.0, 1.0, 0.55 * alpha * k), 7.0 * k + 1.0, true)

	## Centro de la chincheta de una carta (que puede estar levitando).
	static func pin_of(wrap: Control) -> Vector2:
		var lift: Control = wrap.get_meta("lift")
		return wrap.position + lift.position + Vector2(wrap.size.x * 0.5, 2.0)


## La X roja de los eliminados, que se dibuja de un trazo.
class XMark extends Control:
	var amount := 0.0:
		set(v):
			amount = v
			queue_redraw()

	func _draw() -> void:
		if amount <= 0.0:
			return
		var m := size.x * 0.14
		var a1 := Vector2(m, m)
		var b1 := Vector2(size.x - m, size.y - m)
		var a2 := Vector2(size.x - m, m)
		var b2 := Vector2(m, size.y - m)
		var w := maxf(9.0, size.x * 0.11)
		var first := clampf(amount * 2.0, 0.0, 1.0)
		var second := clampf(amount * 2.0 - 1.0, 0.0, 1.0)
		for seg: Array in [[a1, b1, first], [a2, b2, second]]:
			var f := float(seg[2])
			if f <= 0.0:
				continue
			var e: Vector2 = (seg[0] as Vector2).lerp(seg[1], f)
			draw_line(seg[0] + Vector2(3, 4), e + Vector2(3, 4), Color(0.2, 0.0, 0.0, 0.3), w, true)
			draw_line(seg[0], e, RED, w, true)
			draw_circle(seg[0], w * 0.5, RED)
			draw_circle(e, w * 0.5, RED)


var d: Variant
var key := ""
var tour: Dictionary = {}
var animate := false
## Ronda recién decidida (de donde parte la animación).
var done_round := 0
var hotel := false

## cards[nivel][i]: nivel 0 = cuartos … 3 = campeón.
var cards: Array = []
var _labels: Array = []
var _threads: Threads
var _board: Panel
var _lights: Array = []
var _accent := Color("ff8a3d")
var _paper := Color("fbf3df")
var _ink := Color("2b2b3d")
var _dead := false
var _crown: Control
var _crown_bob: Tween


static func create(dem: Variant, k: String, t: Dictionary, anim: bool, done: int) -> CampeonatoCuadro:
	var c := CampeonatoCuadro.new()
	c.d = dem
	c.key = k
	c.tour = t
	c.animate = anim
	c.done_round = done
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accent = d._c("accent")
	hotel = key == "hotel"
	if hotel:
		_paper = Color("f4f6ff")
	custom_minimum_size = Vector2(0.0, _height_for(1000.0))
	_build_board()
	_threads = Threads.new()
	_threads.color = GOLD if hotel else Color("c0392b")
	_threads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lv in LEVELS:
		var title := Loc.t("Campeón") if lv == LEVELS - 1 else Campeonato.round_title(tour, lv)
		if lv < LEVELS - 1 and lv >= Campeonato.premium_from(key):
			title += " · Premium"
		var playing := str(tour.get("estado", "")) == "en_curso" and int(tour.get("ronda", 0)) == lv
		var col := Color("c8d0ff") if hotel else Color("5b3a1e")
		if playing:
			col = Color("ffd24a") if hotel else Color("b03224")
		var lab: Label = d._line(title.to_upper(), d.F_CAP, col, d.font_semibold)
		var lsb := StyleBoxFlat.new()
		lsb.bg_color = Color(0.03, 0.05, 0.18, 0.78) if hotel else Color(0.99, 0.95, 0.84, 0.95)
		lsb.set_corner_radius_all(20)
		lsb.content_margin_left = 16.0
		lsb.content_margin_right = 16.0
		lsb.content_margin_top = 3.0
		lsb.content_margin_bottom = 3.0
		lab.add_theme_stylebox_override("normal", lsb)
		lab.z_index = 5
		add_child(lab)
		_labels.append(lab)
	add_child(_threads)
	_threads.set_anchors_preset(Control.PRESET_FULL_RECT)
	_threads.z_index = 3
	for lv in LEVELS:
		var row: Array = []
		for i in (8 >> lv):
			var card := _make_card(lv, i)
			add_child(card["w"])
			row.append(card)
		cards.append(row)
	resized.connect(_layout)
	_populate()
	_layout()
	if animate:
		_play.call_deferred()


func _exit_tree() -> void:
	_dead = true


# --- Medidas ---

func _w0(width: float) -> float:
	return (width - 2.0 * PAD - 4.0 * PAIR_GAP - 3.0 * GROUP_GAP) / 8.0


func _card_w(lv: int, width: float) -> float:
	return _w0(width) if lv == 0 else float(CARD_W[lv])


func _card_h(lv: int, width: float) -> float:
	return _card_w(lv, width) * PHOTO_RATIO + float(NAME_H[lv]) + 2.0 * CARD_PAD


func _height_for(width: float) -> float:
	var h := 2.0 * PAD
	for lv in LEVELS:
		h += LABEL_H + _card_h(lv, width) + (ROW_GAP if lv > 0 else 0.0)
	return h + 16.0


# --- El panel ---

## Un corcho con marco de madera (o la pantalla gigante del hotel) y dos focos desde arriba.
func _build_board() -> void:
	_board = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1f44") if hotel else Color("c4975c")
	sb.set_corner_radius_all(44)
	sb.set_border_width_all(16)
	sb.border_color = Color("2c3157") if hotel else Color("7a4a24")
	_board.add_theme_stylebox_override("panel", sb)
	_board.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	var tex := TextureRect.new()
	tex.texture = load(TEX + ("pantalla.jpg" if hotel else "corcho.jpg")) as Texture2D
	tex.stretch_mode = TextureRect.STRETCH_SCALE if hotel else TextureRect.STRETCH_TILE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(tex)
	for i in 2:
		var cone := Polygon2D.new()
		var tint := Color(0.75, 0.85, 1.0) if hotel else Color(1.0, 0.93, 0.74)
		cone.polygon = PackedVector2Array([Vector2(-26, 0), Vector2(26, 0), Vector2(220, 900), Vector2(-220, 900)])
		cone.vertex_colors = PackedColorArray([Color(tint, 0.30), Color(tint, 0.30), Color(tint, 0.0), Color(tint, 0.0)])
		_board.add_child(cone)
		_lights.append(cone)


# --- Las cartas ---

func _make_card(lv: int, index: int) -> Dictionary:
	var w := Control.new()
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := Panel.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.12, 0.05, 0.0, 0.30)
	ssb.set_corner_radius_all(100)
	shadow.add_theme_stylebox_override("panel", ssb)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.visible = lv > 0
	w.add_child(shadow)
	var lift := Control.new()
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(lift)
	w.set_meta("lift", lift)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _paper
	sb.set_corner_radius_all(12 if hotel else 6)
	sb.shadow_color = Color(0.12, 0.05, 0.0, 0.28 + 0.05 * float(lv))
	sb.shadow_size = 6 + 5 * lv
	sb.shadow_offset = Vector2(2.0 + 2.0 * float(lv), 5.0 + 5.0 * float(lv))
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.add_child(panel)
	var photo := Panel.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = d._c("field")
	psb.set_corner_radius_all(8 if hotel else 3)
	photo.add_theme_stylebox_override("panel", psb)
	photo.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(photo)
	var name_size := [d.F_CAP - 4, d.F_CAP, d.F_FOOT, d.F_SUB][lv] as int
	var name: Label = d._line("", name_size, _ink, d.font_semibold)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name)
	var x := XMark.new()
	x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(x)
	var check := _check_badge(26.0 + 4.0 * float(lv))
	check.modulate.a = 0.0
	lift.add_child(check)
	var pin := _make_pin()
	lift.add_child(pin)
	# Las de cuartos, un poco torcidas (siempre igual), como clavadas a mano.
	w.rotation = deg_to_rad(sin(float(lv * 7 + index) * 2.3 + 0.7) * (1.6 if lv == 0 else 0.8))
	var card := {"w": w, "lift": lift, "panel": panel, "style": sb, "photo": photo, "name": name, "x": x, "check": check,
		"pin": pin, "shadow": shadow, "level": lv, "index": index, "id": "", "float": null}
	_set_card(card, "")
	return card


func _check_badge(side: float) -> Control:
	var b := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2e9e5b")
	sb.set_corner_radius_all(int(side))
	sb.set_border_width_all(3)
	sb.border_color = Color.WHITE
	b.add_theme_stylebox_override("panel", sb)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size = Vector2(side, side)
	b.size = Vector2(side, side)
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(d._icon("check", side * 0.62, Color.WHITE))
	b.add_child(c)
	b.pivot_offset = Vector2(side, side) * 0.5
	return b


func _make_pin() -> Control:
	var pin := Control.new()
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.size = Vector2(26.0, 26.0)
	var body := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ffd24a") if hotel else Color("d7372b")
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(0.1, 0.03, 0.0, 0.4)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2.0, 3.0)
	body.add_theme_stylebox_override("panel", sb)
	body.size = Vector2(26.0, 26.0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(body)
	var hi := Panel.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(1.0, 1.0, 1.0, 0.65)
	hsb.set_corner_radius_all(8)
	hi.add_theme_stylebox_override("panel", hsb)
	hi.size = Vector2(8.0, 8.0)
	hi.position = Vector2(6.0, 5.0)
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(hi)
	return pin


## Pone a un jugador en una carta («» = carta vacía: un hueco a la espera, con interrogación o con la corona).
func _set_card(card: Dictionary, id: String) -> void:
	card["id"] = id
	var lv := int(card["level"])
	var photo: Panel = card["photo"]
	for c in photo.get_children():
		c.queue_free()
	var name: Label = card["name"]
	var wrap: Control = card["w"]
	if id == "":
		name.text = ""
		var c := CenterContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		if lv == LEVELS - 1:
			c.add_child(d._icon("crown", 84.0, Color(GOLD, 0.45)))
		else:
			var q: Label = d._line("?", int(32.0 + 8.0 * float(lv)), d._c("quiet"), d.font_display)
			c.add_child(q)
		photo.add_child(c)
		wrap.modulate.a = 0.45
		return
	wrap.modulate.a = 1.0
	name.text = Campeonato.display_name(key, id).split(" ")[0]
	if id == Campeonato.YOU:
		var bg := ColorRect.new()
		bg.color = _accent.lerp(Color.WHITE, 0.55)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		photo.add_child(bg)
		var c := CenterContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.add_child(d._icon("piece_king", 40.0 + 14.0 * float(lv), d._c("ink")))
		photo.add_child(c)
		return
	var tex := CampeonatoUI.photo(Campeonato.portrait_path(key, id))
	if tex == null:
		var c := CenterContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.add_child(d._icon("users", 40.0 + 14.0 * float(lv), d._c("quiet")))
		photo.add_child(c)
		return
	# Los retratos son cuadrados: se recortan los lados para la carta vertical.
	var sz := tex.get_size()
	var rw := minf(sz.x, sz.y / PHOTO_RATIO)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2((sz.x - rw) * 0.5, 0.0, rw, minf(sz.y, rw * PHOTO_RATIO))
	var pic := TextureRect.new()
	pic.texture = at
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	photo.add_child(pic)


## Eliminado: X roja y la carta apagada (sin animación, para el estado guardado).
func _set_lost(card: Dictionary) -> void:
	(card["x"] as XMark).amount = 1.0
	(card["w"] as Control).modulate.a = 0.32


func _set_won(card: Dictionary) -> void:
	(card["check"] as Control).modulate.a = 1.0


func _gold(card: Dictionary) -> void:
	var st: StyleBoxFlat = card["style"]
	st.border_color = GOLD
	st.set_border_width_all(6)
	st.shadow_color = Color(GOLD, 0.55)
	st.shadow_size = 22


# --- Estado ---

func _known(lv: int) -> bool:
	return lv == 0 or not _winners(lv - 1).is_empty()


func _winners(r: int) -> Array:
	var gan: Array = tour.get("ganadores", [])
	return gan[r] if r < gan.size() else []


func _ids_of(lv: int) -> Array:
	if lv == LEVELS - 1:
		return _winners(LEVELS - 2)
	var out: Array = []
	for pr: Array in Campeonato.pairs(tour, lv):
		out.append(str(pr[0]))
		out.append(str(pr[1]))
	return out


## Lo que ya se sabe, en su sitio. En una animación, solo hasta la ronda recién decidida (sin marcar todavía);
## lo de arriba, en hueco, hasta que llegue subiendo.
func _populate() -> void:
	var upto := done_round if animate else LEVELS - 1
	for lv in LEVELS:
		if lv > upto or not _known(lv):
			continue
		var ids := _ids_of(lv)
		for i in mini(ids.size(), cards[lv].size()):
			_set_card(cards[lv][i], str(ids[i]))
			if lv > 0:
				_float(cards[lv][i])
		if lv < LEVELS - 1:
			_link_level(lv, 1.0)
		if lv == LEVELS - 1:
			_gold(cards[lv][0])
			_place_crown.call_deferred(false)
		elif not animate or lv < done_round:
			_mark_static(lv)
	_ring_current()


func _mark_static(lv: int) -> void:
	var winners := _winners(lv)
	if winners.is_empty():
		return
	for card: Dictionary in cards[lv]:
		if str(card["id"]) == "":
			continue
		if winners.has(card["id"]):
			_set_won(card)
		else:
			_set_lost(card)


func _link_level(lv: int, p: float) -> Array:
	var made: Array = []
	for i in (cards[lv].size() / 2):
		var link := {"a": cards[lv][2 * i]["w"], "b": cards[lv][2 * i + 1]["w"], "p": p}
		_threads.links.append(link)
		made.append(link)
	return made


func _ring_current() -> void:
	if str(tour.get("estado", "")) != "en_curso":
		return
	var r := int(tour.get("ronda", 0))
	for card: Dictionary in cards[r]:
		if str(card["id"]) == Campeonato.YOU:
			var st: StyleBoxFlat = card["style"]
			st.border_color = _accent
			st.set_border_width_all(5)
			var panel: Control = card["panel"]
			var tw := panel.create_tween().set_loops()
			tw.tween_property(panel, "self_modulate", Color(1.0, 0.92, 0.84), 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(panel, "self_modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)


## Las cartas de las filas altas levitan sobre el corcho: suben y bajan despacio y su sombra se encoge y se estira.
func _float(card: Dictionary) -> void:
	if card["float"] != null:
		return
	var lv := int(card["level"])
	var amp := 5.0 + 2.5 * float(lv)
	var lift: Control = card["lift"]
	var shadow: Control = card["shadow"]
	shadow.visible = true
	var phase := 0.37 * float(card["index"]) + 0.23 * float(lv)
	var tw := lift.create_tween().set_loops()
	tw.tween_interval(phase)
	tw.tween_property(lift, "position:y", -amp - 6.0 * float(lv), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(lift, "position:y", amp * 0.3 - 6.0 * float(lv), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	card["float"] = tw
	var ts := shadow.create_tween().set_loops()
	ts.tween_interval(phase)
	ts.tween_property(shadow, "scale", Vector2(0.86, 0.8), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ts.tween_property(shadow, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Posiciones ---

func _layout() -> void:
	var width := size.x
	if width < 200.0:
		return
	var want := _height_for(width)
	if absf(custom_minimum_size.y - want) > 1.0:
		custom_minimum_size.y = want
	var w0 := _w0(width)
	var centers: Array = []
	var c0: Array = []
	var x := PAD
	for i in 8:
		c0.append(x + w0 * 0.5)
		x += w0 + (PAIR_GAP if i % 2 == 0 else GROUP_GAP)
	centers.append(c0)
	for lv in range(1, LEVELS):
		var prev: Array = centers[lv - 1]
		var cur: Array = []
		for i in (prev.size() / 2):
			cur.append((float(prev[2 * i]) + float(prev[2 * i + 1])) * 0.5)
		centers.append(cur)
	# Las parejas de semifinal y final se separan un poco más de lo que da la pirámide, para que quepan.
	var top := PAD
	for lv in range(LEVELS - 1, -1, -1):
		var lab: Control = _labels[lv]
		lab.reset_size()
		lab.position = Vector2(PAD + 4.0, top)
		var cw := _card_w(lv, width)
		var ch := _card_h(lv, width)
		for i in cards[lv].size():
			var card: Dictionary = cards[lv][i]
			var wrap: Control = card["w"]
			wrap.size = Vector2(cw, ch)
			wrap.position = Vector2(float(centers[lv][i]) - cw * 0.5, top + LABEL_H)
			wrap.pivot_offset = wrap.size * 0.5
			(card["lift"] as Control).size = wrap.size
			var panel: Control = card["panel"]
			panel.size = wrap.size
			var photo: Control = card["photo"]
			photo.position = Vector2(CARD_PAD, CARD_PAD)
			photo.size = Vector2(cw - 2.0 * CARD_PAD, cw * PHOTO_RATIO - CARD_PAD)
			var name: Control = card["name"]
			name.position = Vector2(4.0, CARD_PAD + cw * PHOTO_RATIO - CARD_PAD)
			name.size = Vector2(cw - 8.0, float(NAME_H[lv]) + CARD_PAD)
			var xm: Control = card["x"]
			xm.position = Vector2.ZERO
			xm.size = wrap.size
			var chk: Control = card["check"]
			chk.position = Vector2(cw - chk.size.x * 0.75, -chk.size.y * 0.25)
			var pin: Control = card["pin"]
			pin.position = Vector2(cw * 0.5 - 13.0, -11.0)
			var shadow: Control = card["shadow"]
			shadow.size = Vector2(cw * 0.8, 22.0)
			shadow.position = Vector2(cw * 0.1, ch + 8.0)
			shadow.pivot_offset = shadow.size * 0.5
		top += LABEL_H + ch + ROW_GAP
	_board.position = Vector2.ZERO
	_board.size = Vector2(width, top - ROW_GAP + PAD)
	for i in _lights.size():
		var cone: Polygon2D = _lights[i]
		cone.position = Vector2(width * (0.24 + 0.52 * float(i)), -4.0)
	if _crown != null and is_instance_valid(_crown) and not _crown.has_meta("flying"):
		_place_crown(false)


# --- La animación ---

func _wait(seconds: float) -> void:
	if _dead or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


func _play() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _dead:
		return
	var last := done_round - 1
	for r in LEVELS - 1:
		if not _winners(r).is_empty():
			last = r
	await _wait(0.5)
	for r in range(done_round, last + 1):
		if _dead:
			return
		await _strike_round(r)
		if _dead:
			return
		await _rise_round(r)
		if r == LEVELS - 2:
			await _place_crown(true)
	_ring_current()


## Las derrotas de una ronda, pareja a pareja: X roja que se dibuja y la carta que se deshace en polvo.
func _strike_round(r: int) -> void:
	var winners := _winners(r)
	for i in (cards[r].size() / 2):
		for s in 2:
			var card: Dictionary = cards[r][2 * i + s]
			if str(card["id"]) == "":
				continue
			if winners.has(card["id"]):
				_won_fx(card)
			else:
				_lost_fx(card)
		CuadroSonidos.play(d, "thud", -7.0)
		await _wait(0.6)
	await _wait(0.4)


func _won_fx(card: Dictionary) -> void:
	var chk: Control = card["check"]
	chk.scale = Vector2(0.2, 0.2)
	var tw := chk.create_tween().set_parallel(true)
	tw.tween_property(chk, "modulate:a", 1.0, 0.15)
	tw.tween_property(chk, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wrap: Control = card["w"]
	var tp := wrap.create_tween()
	tp.tween_property(wrap, "scale", Vector2(1.06, 1.06), 0.14)
	tp.tween_property(wrap, "scale", Vector2.ONE, 0.25)


func _lost_fx(card: Dictionary) -> void:
	var x: XMark = card["x"]
	var tx := x.create_tween()
	tx.tween_property(x, "amount", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var wrap: Control = card["w"]
	var tw := wrap.create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(_dust.bind(wrap))
	tw.tween_property(wrap, "modulate:a", 0.32, 0.6)
	var ts := wrap.create_tween()
	ts.tween_interval(0.45)
	ts.tween_property(wrap, "scale", Vector2(0.94, 0.94), 0.6)


## Polvo de papel que se lleva una carta eliminada.
func _dust(wrap: Control) -> void:
	if _dead or not is_instance_valid(wrap):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(wrap.position.x * 3.0 + wrap.position.y)
	for _i in 22:
		var dot := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.bg_color = _paper.darkened(rng.randf_range(0.0, 0.25)) if rng.randf() < 0.75 else Color(RED, 0.9)
		ds.set_corner_radius_all(3)
		dot.add_theme_stylebox_override("panel", ds)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz := rng.randf_range(5.0, 12.0)
		dot.size = Vector2(sz, sz)
		dot.position = wrap.position + Vector2(rng.randf() * wrap.size.x, rng.randf() * wrap.size.y)
		dot.z_index = 9
		dot.rotation = rng.randf() * TAU
		add_child(dot)
		var drift := Vector2(rng.randf_range(-40.0, 70.0), rng.randf_range(-120.0, -30.0))
		var dur := rng.randf_range(0.7, 1.2)
		var td := dot.create_tween().set_parallel(true)
		td.tween_property(dot, "position", dot.position + drift, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		td.tween_property(dot, "rotation", dot.rotation + rng.randf_range(-3.0, 3.0), dur)
		td.tween_property(dot, "modulate:a", 0.0, dur).set_delay(0.2)
		td.chain().tween_callback(dot.queue_free)


## Los vencedores de la ronda r suben, cada uno con su estela, a su sitio en la fila de arriba.
func _rise_round(r: int) -> void:
	var winners := _winners(r)
	var landed := {"n": 0}
	for k in winners.size():
		var src: Dictionary = {}
		for card: Dictionary in cards[r]:
			if str(card["id"]) == str(winners[k]):
				src = card
		if src.is_empty() or k >= cards[r + 1].size():
			continue
		_fly(src, cards[r + 1][k], str(winners[k]), 0.3 * float(k), landed)
	await _wait(0.3 * float(winners.size() - 1) + 1.2 + 0.5)
	if r + 1 < LEVELS - 1:
		var links := _link_level(r + 1, 0.0)
		for link: Dictionary in links:
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void: link["p"] = v, 0.0, 1.0, 0.5)
		await _wait(0.7)


func _fly(src: Dictionary, dst: Dictionary, id: String, delay: float, landed: Dictionary) -> void:
	var lv := int(dst["level"])
	var a: Control = src["w"]
	var b: Control = dst["w"]
	var clone := _make_card(lv, int(dst["index"]))
	var cw: Control = clone["w"]
	add_child(cw)
	_set_card(clone, id)
	cw.modulate.a = 0.0
	cw.z_index = 12
	cw.rotation = 0.0
	cw.size = b.size
	cw.pivot_offset = Vector2.ZERO
	for k: String in ["lift", "panel", "x"]:
		(clone[k] as Control).size = b.size
	(clone["photo"] as Control).position = (dst["photo"] as Control).position
	(clone["photo"] as Control).size = (dst["photo"] as Control).size
	(clone["name"] as Control).position = (dst["name"] as Control).position
	(clone["name"] as Control).size = (dst["name"] as Control).size
	(clone["pin"] as Control).visible = false
	var trail := {"pts": PackedVector2Array(), "alpha": 1.0}
	_threads.trails.append(trail)
	var s0 := a.size.x / b.size.x
	var p0 := a.position
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		cw.modulate.a = 1.0
		CuadroSonidos.play(d, "whoosh", -10.0))
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(cw):
			return
		var p1 := b.position + (dst["lift"] as Control).position
		var sc := lerpf(s0, 1.0, t)
		var mid := (p0 + p1) * 0.5 + Vector2(0.0, -90.0)
		var u := 1.0 - t
		var pos := u * u * p0 + 2.0 * u * t * mid + t * t * p1
		cw.scale = Vector2(sc, sc) * (1.0 + 0.12 * sin(t * PI))
		cw.position = pos
		var center := pos + b.size * sc * 0.5
		var pts: PackedVector2Array = trail["pts"]
		pts.append(center)
		if pts.size() > 18:
			pts.remove_at(0)
		trail["pts"] = pts
	, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(cw):
			cw.queue_free()
		_set_card(dst, id)
		if lv == LEVELS - 1:
			_gold(dst)
		_float(dst)
		var bw: Control = dst["w"]
		bw.scale = Vector2(1.08, 1.08)
		bw.create_tween().tween_property(bw, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_burst(bw.position + bw.size * 0.5, 0.8 if lv < LEVELS - 1 else 1.6)
		CuadroSonidos.play(d, "chime", -9.0)
		landed["n"] = int(landed["n"]) + 1
		var fade := create_tween()
		fade.tween_method(func(v: float) -> void: trail["alpha"] = v, 1.0, 0.0, 0.6)
		fade.tween_callback(func() -> void: _threads.trails.erase(trail)))


## Un anillo y unas chispas que salen de un punto.
func _burst(at: Vector2, power: float) -> void:
	var ring := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = GOLD
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(100)
	ring.add_theme_stylebox_override("panel", sb)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(40.0, 40.0)
	ring.pivot_offset = Vector2(20.0, 20.0)
	ring.position = at - Vector2(20.0, 20.0)
	ring.z_index = 8
	add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(4.5, 4.5) * power, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 7.0 + at.y * 13.0)
	for _i in int(9.0 * power):
		var dot := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color("ffd24a") if rng.randf() < 0.6 else _accent
		ds.set_corner_radius_all(10)
		dot.add_theme_stylebox_override("panel", ds)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz := rng.randf_range(8.0, 15.0)
		dot.size = Vector2(sz, sz)
		dot.position = at - dot.size * 0.5
		dot.z_index = 9
		add_child(dot)
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(60.0, 140.0) * power
		var td := dot.create_tween().set_parallel(true)
		td.tween_property(dot, "position", dot.position + Vector2(cos(ang), sin(ang)) * dist, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		td.tween_property(dot, "modulate:a", 0.0, 0.7).set_delay(0.15)
		td.chain().tween_callback(dot.queue_free)


## La corona del campeón, encima de su carta (cayendo, con fanfarria, si va animada).
func _place_crown(animated: bool) -> void:
	var card: Dictionary = cards[LEVELS - 1][0]
	if str(card["id"]) == "":
		return
	var wrap: Control = card["w"]
	if _crown == null or not is_instance_valid(_crown):
		_crown = d._icon("crown", 92.0, GOLD)
		_crown.z_index = 14
		_crown.pivot_offset = Vector2(46.0, 46.0)
		_crown.rotation = deg_to_rad(-22.0)
		_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_crown)
	var target := wrap.position + Vector2(-50.0, -52.0)
	if not animated:
		_crown.position = target
		_bob_crown(target)
		return
	_crown.set_meta("flying", true)
	_crown.position = target + Vector2(0.0, -260.0)
	_crown.modulate.a = 0.0
	var tw := _crown.create_tween().set_parallel(true)
	tw.tween_property(_crown, "modulate:a", 1.0, 0.2)
	tw.tween_property(_crown, "position", target, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await _wait(0.8)
	if _dead:
		return
	_crown.remove_meta("flying")
	CuadroSonidos.play(d, "fanfare", -3.0)
	_burst(target + Vector2(46.0, 46.0), 2.4)
	_bob_crown(target)
	await _wait(1.0)


func _bob_crown(target: Vector2) -> void:
	if _crown_bob != null and _crown_bob.is_valid():
		_crown_bob.kill()
	var bob := _crown.create_tween().set_loops()
	_crown_bob = bob
	bob.tween_property(_crown, "position:y", target.y - 9.0, 1.3).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_crown, "position:y", target.y, 1.3).set_trans(Tween.TRANS_SINE)
