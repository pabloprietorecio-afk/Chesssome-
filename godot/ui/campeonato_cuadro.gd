class_name CampeonatoCuadro
extends Control
## El cuadro de una copa (Campeonato) como un árbol vivo: cuartos abajo, semifinal encima y final arriba. Al volver de
## una partida (Pablo, 23 nov: «que sea mucho más espectacular… para diferenciarnos»): se tachan las derrotas de la
## ronda, la ficha de cada vencedor sale volando por una flecha curva y, con la de su compañero de cruce, forma una
## ficha nueva que se eleva sobre las anteriores y queda levitando. Al final, la corona del campeón.

const GAP := 14.0
const LABEL_H := 40.0
const ARROW_GAP := 92.0
const FACE := [52.0, 72.0, 84.0]
const CARD_W := [0.0, 310.0, 390.0]
const CARD_H := [170.0, 200.0, 232.0]
const ROUNDS := 3

## Flechas entre fichas: se dibujan siguiendo a las fichas (que levitan), con un trazo que va creciendo.
class Arrows extends Control:
	var links: Array = []
	var color := Color("ff8a3d")

	func _process(_delta: float) -> void:
		if not links.is_empty():
			queue_redraw()

	func _draw() -> void:
		for link: Dictionary in links:
			var p := float(link["p"])
			if p <= 0.0:
				continue
			var a: Control = link["a"]
			var b: Control = link["b"]
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var pts := Arrows.curve(a, b, p)
			var alpha := float(link["alpha"])
			if pts.size() < 2:
				continue
			draw_polyline(pts, Color(color.r, color.g, color.b, 0.18 * alpha), 20.0, true)
			draw_polyline(pts, Color(color.r, color.g, color.b, alpha), 7.0, true)
			if p >= 0.999:
				var tip := pts[pts.size() - 1]
				var dir := (tip - pts[pts.size() - 4]).normalized()
				var side := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([tip + dir * 6.0, tip - dir * 26.0 + side * 17.0, tip - dir * 26.0 - side * 17.0]), Color(color.r, color.g, color.b, alpha))

	static func start_of(a: Control) -> Vector2:
		return a.position + Vector2(a.size.x * 0.5, 4.0)

	static func end_of(b: Control) -> Vector2:
		return b.position + Vector2(b.size.x * 0.5, b.size.y - 2.0)

	static func point(a: Control, b: Control, t: float) -> Vector2:
		var p0 := start_of(a)
		var p3 := end_of(b)
		var p1 := p0 + Vector2(0.0, -ARROW_GAP * 0.62)
		var p2 := p3 + Vector2(0.0, ARROW_GAP * 0.62)
		var u := 1.0 - t
		return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3

	static func curve(a: Control, b: Control, p: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 28
		for i in n + 1:
			var t := p * float(i) / float(n)
			pts.append(Arrows.point(a, b, t))
		return pts


var d: Variant
var key := ""
var tour: Dictionary = {}
var animate := false
## Ronda recién decidida (de donde parte la animación).
var done_round := 0

var cards: Array = []
var _labels: Array = []
var _arrows: Arrows
var _accent := Color("ff8a3d")
var _dead := false


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
	_accent = d._c("accent")
	var total := 0.0
	for r in ROUNDS:
		total += LABEL_H + float(CARD_H[r]) + (ARROW_GAP if r < ROUNDS - 1 else 0.0)
	custom_minimum_size = Vector2(0.0, total + 24.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arrows = Arrows.new()
	_arrows.color = _accent
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in ROUNDS:
		var title := Campeonato.round_title(tour, r)
		if r >= Campeonato.premium_from(key):
			title += " · Premium"
		var playing := str(tour.get("estado", "")) == "en_curso" and int(tour.get("ronda", 0)) == r
		var lab: Label = d._line(title.to_upper(), d.F_CAP, d._c("accent_text") if playing else d._c("quiet"), d.font_semibold)
		var lsb := StyleBoxFlat.new()
		lsb.bg_color = Color(1.0, 1.0, 1.0, 0.82)
		lsb.set_corner_radius_all(20)
		lsb.content_margin_left = 14.0
		lsb.content_margin_right = 14.0
		lsb.content_margin_top = 3.0
		lsb.content_margin_bottom = 3.0
		lab.add_theme_stylebox_override("normal", lsb)
		lab.z_index = 5
		add_child(lab)
		_labels.append(lab)
		var row: Array = []
		var count := 4 >> r
		for i in count:
			var card := _make_card(r, i)
			add_child(card["w"])
			row.append(card)
		cards.append(row)
	add_child(_arrows)
	_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_populate()
	_layout()
	if animate:
		_play.call_deferred()


func _exit_tree() -> void:
	_dead = true


# --- Fichas ---

func _make_card(r: int, index: int) -> Dictionary:
	var w := Control.new()
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := Panel.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.1, 0.12, 0.25, 0.22)
	ssb.set_corner_radius_all(100)
	shadow.add_theme_stylebox_override("panel", ssb)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate.a = 0.0
	w.add_child(shadow)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var paper: Color = d._c("surface")
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.97)
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	sb.shadow_color = Color(0.1, 0.12, 0.25, 0.10 + 0.07 * float(r))
	sb.shadow_size = 10 + 8 * r
	sb.shadow_offset = Vector2(0.0, 6.0 + 6.0 * float(r))
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows)
	var row_nodes: Array = []
	var faces: Array = []
	var names: Array = []
	var checks: Array = []
	var crosses: Array = []
	for _s in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := _placeholder(float(FACE[r]))
		row.add_child(face)
		var name: Label = d._line("", d.F_SUB if r > 0 else d.F_CAP + 2, d._c("ink"), d.font_medium)
		name.clip_text = true
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.custom_minimum_size.x = 10.0
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name)
		var mark_size := 30.0 + 6.0 * float(r)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(mark_size, mark_size)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ok: Control = d._icon("check", mark_size, d._c("good"))
		ok.modulate.a = 0.0
		var bad: Control = d._icon("close", mark_size, Color("c0392b"))
		bad.modulate.a = 0.0
		for mk: Control in [ok, bad]:
			mk.set_anchors_preset(Control.PRESET_FULL_RECT)
			mk.pivot_offset = Vector2(mark_size, mark_size) * 0.5
			slot.add_child(mk)
		row.add_child(slot)
		rows.add_child(row)
		row_nodes.append(row)
		faces.append(face)
		names.append(name)
		checks.append(ok)
		crosses.append(bad)
	w.modulate.a = 0.5
	return {"w": w, "panel": panel, "shadow": shadow, "style": sb, "rows": row_nodes, "faces": faces, "names": names, "checks": checks,
		"crosses": crosses, "ids": ["", ""], "round": r, "index": index, "filled": false, "float": null}


func _placeholder(side: float) -> Control:
	var disc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = d._c("field")
	sb.set_corner_radius_all(int(side / 2.0))
	disc.add_theme_stylebox_override("panel", sb)
	disc.custom_minimum_size = Vector2(side, side)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var q: Label = d._line("?", int(side * 0.5), d._c("quiet"), d.font_display)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(q)
	return disc


## Pone a un jugador en una de las dos filas de una ficha (con un «pop» si va animado).
func _fill(card: Dictionary, s: int, id: String, animated: bool) -> void:
	var r := int(card["round"])
	var row: HBoxContainer = card["rows"][s]
	var old: Control = card["faces"][s]
	var face: Control = CampeonatoUI._face(d, key, id, float(FACE[r]))
	row.add_child(face)
	row.move_child(face, 0)
	row.remove_child(old)
	old.queue_free()
	card["faces"][s] = face
	card["ids"][s] = id
	var name: Label = card["names"][s]
	name.text = Campeonato.display_name(key, id).split(" ")[0]
	var strong := id == Campeonato.YOU
	name.add_theme_font_override("font", d.font_semibold if strong else d.font_medium)
	if animated:
		face.pivot_offset = Vector2(float(FACE[r]), float(FACE[r])) * 0.5
		face.scale = Vector2(0.3, 0.3)
		name.modulate.a = 0.0
		var tw := face.create_tween()
		tw.tween_property(face, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		name.create_tween().tween_property(name, "modulate:a", 1.0, 0.35)


func _all_known(r: int) -> bool:
	if r == 0:
		return true
	return not ((tour["ganadores"] as Array)[r - 1] as Array).is_empty()


func _winners(r: int) -> Array:
	return (tour["ganadores"] as Array)[r]


## Estado de partida: lo que ya se sabe, relleno; y las rondas decididas, con sus derrotas marcadas. En una animación,
## solo hasta la ronda recién decidida (sin marcar), y lo demás, vacío hasta que llegue volando.
func _populate() -> void:
	var upto := done_round if animate else ROUNDS - 1
	for r in ROUNDS:
		if r > upto or not _all_known(r):
			continue
		var prs := Campeonato.pairs(tour, r)
		for i in prs.size():
			var card: Dictionary = cards[r][i]
			_fill(card, 0, str(prs[i][0]), false)
			_fill(card, 1, str(prs[i][1]), false)
			card["filled"] = true
			(card["w"] as Control).modulate.a = 1.0
			if r > 0:
				_float(card)
			if not animate or r < done_round:
				if not _winners(r).is_empty():
					_mark(card, _winners(r), false, 0.0)
		if r > 0 and not _winners(r - 1).is_empty() and (not animate or r <= done_round):
			_link_round(r - 1, 1.0, 0.45)
	_ring_current()


func _link_round(r: int, p: float, alpha: float) -> void:
	for i in (4 >> (r + 1)):
		for s in 2:
			_arrows.links.append({"a": cards[r][2 * i + s]["w"], "b": cards[r + 1][i]["w"], "p": p, "alpha": alpha, "round": r, "pair": 2 * i + s})


## Los dos de una ficha: el vencedor, con su marca verde; el otro, apagado y con una cruz roja.
func _mark(card: Dictionary, winners: Array, animated: bool, delay: float) -> void:
	for s in 2:
		var id := str(card["ids"][s])
		var row: Control = card["rows"][s]
		var won := winners.has(id)
		var mark: Control = card["checks"][s] if won else card["crosses"][s]
		if not won:
			if animated:
				row.create_tween().tween_interval(delay)
				var tw := row.create_tween()
				tw.tween_interval(delay)
				tw.tween_property(row, "modulate:a", 0.42, 0.5)
			else:
				row.modulate.a = 0.42
		if animated:
			var tm := mark.create_tween()
			tm.tween_interval(delay)
			tm.tween_property(mark, "modulate:a", 1.0, 0.2)
			mark.scale = Vector2(0.2, 0.2)
			var tp := mark.create_tween()
			tp.tween_interval(delay)
			tp.tween_property(mark, "scale", Vector2(1.6, 1.6), 0.18)
			tp.tween_property(mark, "scale", Vector2.ONE, 0.22)
		else:
			mark.modulate.a = 1.0


func _ring_current() -> void:
	if str(tour.get("estado", "")) != "en_curso":
		return
	var r := int(tour.get("ronda", 0))
	for card: Dictionary in cards[r]:
		if card["ids"].has(Campeonato.YOU):
			var st: StyleBoxFlat = card["style"]
			st.border_color = _accent
			st.set_border_width_all(5)
			var panel: Control = card["panel"]
			var tw := panel.create_tween().set_loops()
			tw.tween_property(panel, "self_modulate", Color(1.0, 0.94, 0.86), 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(panel, "self_modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)


## Las fichas de la semifinal y la final levitan: suben y bajan despacio y su sombra se encoge y se estira.
func _float(card: Dictionary) -> void:
	if card["float"] != null:
		return
	var r := int(card["round"])
	var amp := 7.0 + 3.0 * float(r - 1)
	var panel: Control = card["panel"]
	var shadow: Control = card["shadow"]
	var tw := panel.create_tween().set_loops()
	var phase := 0.35 * float(card["index"]) + 0.2 * float(r)
	tw.tween_interval(phase)
	tw.tween_property(panel, "position:y", -amp, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(panel, "position:y", amp * 0.3, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	card["float"] = tw
	shadow.modulate.a = 1.0
	var ts := shadow.create_tween().set_loops()
	ts.tween_interval(phase)
	ts.tween_property(shadow, "scale", Vector2(0.84, 0.84), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ts.tween_property(shadow, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Posiciones ---

func _layout() -> void:
	var width := size.x
	if width < 100.0:
		return
	var w0 := (width - 3.0 * GAP) / 4.0
	var centers: Array = []
	var c0: Array = []
	for i in 4:
		c0.append(float(i) * (w0 + GAP) + w0 * 0.5)
	centers.append(c0)
	var c1: Array = [(c0[0] + c0[1]) * 0.5, (c0[2] + c0[3]) * 0.5]
	centers.append(c1)
	centers.append([(c1[0] + c1[1]) * 0.5])
	# De arriba abajo: final (r = 2), semifinal (1), cuartos (0).
	var top := 0.0
	for r in range(ROUNDS - 1, -1, -1):
		var lab: Control = _labels[r]
		lab.position = Vector2(0.0, top)
		var cw := w0 if r == 0 else float(CARD_W[r])
		for i in cards[r].size():
			var card: Dictionary = cards[r][i]
			var wrap: Control = card["w"]
			wrap.size = Vector2(cw, float(CARD_H[r]))
			wrap.position = Vector2(float(centers[r][i]) - cw * 0.5, top + LABEL_H)
			var panel: Control = card["panel"]
			panel.size = wrap.size
			panel.position.x = 0.0
			var shadow: Control = card["shadow"]
			shadow.size = Vector2(cw * 0.7, 20.0)
			shadow.position = Vector2(cw * 0.15, float(CARD_H[r]) + 14.0)
			shadow.pivot_offset = shadow.size * 0.5
		top += LABEL_H + float(CARD_H[r]) + ARROW_GAP


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
	var gan: Array = tour["ganadores"]
	var last := done_round
	for r in gan.size():
		if not (gan[r] as Array).is_empty():
			last = r
	await _wait(0.5)
	for r in range(done_round, last + 1):
		if _dead:
			return
		await _strike_round(r)
		if _dead:
			return
		if r + 1 < ROUNDS and not _winners(r).is_empty():
			await _fly_round(r)
		elif r == ROUNDS - 1:
			await _crown()
	_ring_current()


## Las derrotas de una ronda, una a una.
func _strike_round(r: int) -> void:
	var winners := _winners(r)
	for i in cards[r].size():
		var card: Dictionary = cards[r][i]
		if not bool(card["filled"]):
			continue
		_mark(card, winners, true, 0.0)
		CuadroSonidos.play(d, "thud", -7.0)
		_pulse(card["panel"])
		await _wait(0.55)
	await _wait(0.35)


func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.04, 1.04), 0.14)
	tw.tween_property(node, "scale", Vector2.ONE, 0.2)


## Las fichas de los vencedores de la ronda r vuelan por sus flechas hasta las fichas nuevas de la ronda siguiente.
func _fly_round(r: int) -> void:
	var winners := _winners(r)
	var n := winners.size()
	var landed := {}
	for k in n:
		var src: Dictionary = cards[r][k]
		var dst: Dictionary = cards[r + 1][k / 2]
		var s := k % 2
		var id := str(winners[k])
		var delay := 0.28 * float(k)
		_fly_token(src, dst, s, id, delay, landed)
	await _wait(0.28 * float(n - 1) + 1.0 + 0.9)


func _fly_token(src: Dictionary, dst: Dictionary, s: int, id: String, delay: float, landed: Dictionary) -> void:
	var r := int(src["round"])
	var a: Control = src["w"]
	var b: Control = dst["w"]
	var link := {"a": a, "b": b, "p": 0.0, "alpha": 0.9, "round": r, "pair": 0}
	_arrows.links.append(link)
	var side := float(FACE[r])
	var token: Control = CampeonatoUI._face(d, key, id, side)
	token.modulate.a = 0.0
	token.z_index = 10
	add_child(token)
	var row_i: int = src["ids"].find(id)
	var from: Control = src["faces"][maxi(0, row_i)]
	var start_c := from.global_position - global_position + Vector2(side, side) * 0.5
	token.pivot_offset = Vector2(side, side) * 0.5
	token.position = start_c - Vector2(side, side) * 0.5
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		token.modulate.a = 1.0
		CuadroSonidos.play(d, "whoosh", -10.0))
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(token):
			return
		var top_c := Arrows.start_of(a)
		var lift := clampf(t / 0.18, 0.0, 1.0)
		var pos: Vector2
		if t < 0.18:
			pos = start_c.lerp(top_c, lift)
		else:
			pos = Arrows.point(a, b, (t - 0.18) / 0.82)
		link["p"] = clampf((t - 0.18) / 0.82, 0.0, 1.0)
		var sc := 1.0 + 0.35 * sin(clampf(t, 0.0, 1.0) * PI)
		token.scale = Vector2(sc, sc)
		token.position = pos - Vector2(side, side) * 0.5
	, 0.0, 1.0, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(token):
			token.queue_free()
		_fill(dst, s, id, true)
		_burst(Arrows.end_of(b) + Vector2(0.0, -float(CARD_H[r + 1]) * 0.25), 0.7)
		CuadroSonidos.play(d, "chime", -12.0)
		landed[b] = int(landed.get(b, 0)) + 1
		if int(landed[b]) >= 2:
			_lift(dst))


## La ficha nueva, completa, se eleva sobre las anteriores y empieza a levitar.
func _lift(card: Dictionary) -> void:
	card["filled"] = true
	var wrap: Control = card["w"]
	wrap.pivot_offset = wrap.size * 0.5
	var tw := wrap.create_tween().set_parallel(true)
	tw.tween_property(wrap, "modulate:a", 1.0, 0.3)
	wrap.scale = Vector2(0.9, 0.9)
	tw.tween_property(wrap, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_burst(wrap.position + wrap.size * 0.5, 1.6)
	CuadroSonidos.play(d, "chime", -5.0)
	_float(card)


## Un anillo y unas chispas que salen de un punto.
func _burst(at: Vector2, power: float) -> void:
	var ring := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = _accent
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
	for _i in int(8.0 * power):
		var dot := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color("ffd24a") if rng.randf() < 0.6 else _accent
		ds.set_corner_radius_all(10)
		dot.add_theme_stylebox_override("panel", ds)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz := rng.randf_range(8.0, 16.0)
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


## La corona cae sobre el campeón de la final.
func _crown() -> void:
	var final_card: Dictionary = cards[ROUNDS - 1][0]
	var winners := _winners(ROUNDS - 1)
	if winners.is_empty():
		return
	var s: int = final_card["ids"].find(str(winners[0]))
	if s < 0:
		return
	var face: Control = final_card["faces"][s]
	var crown: Control = d._icon("crown", 96.0, Color("f2b01e"))
	crown.z_index = 12
	crown.pivot_offset = Vector2(48.0, 48.0)
	add_child(crown)
	var target := face.global_position - global_position + Vector2(float(FACE[2]) * 0.5 - 48.0, -70.0)
	crown.position = target + Vector2(0.0, -220.0)
	crown.modulate.a = 0.0
	var tw := crown.create_tween().set_parallel(true)
	tw.tween_property(crown, "modulate:a", 1.0, 0.2)
	tw.tween_property(crown, "position", target, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await _wait(0.7)
	CuadroSonidos.play(d, "fanfare", -3.0)
	_burst(target + Vector2(48.0, 48.0), 2.4)
	var bob := crown.create_tween().set_loops()
	bob.tween_property(crown, "position:y", target.y - 8.0, 1.2).set_trans(Tween.TRANS_SINE)
	bob.tween_property(crown, "position:y", target.y, 1.2).set_trans(Tween.TRANS_SINE)
