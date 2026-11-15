class_name FlipClock
extends Control
## Reloj de láminas («split-flap») con aspecto iOS: cuenta minutos y segundos desde `start_ms`.
## Cada cifra es una tarjeta partida en dos mitades; al cambiar, la mitad de arriba cae sobre la de abajo
## (acelerando, como por gravedad) y la nueva mitad de abajo se asienta con un pequeño rebote.
## Las mitades son nodos que recortan su contenido (clip_contents) y se aplastan con `scale.y`.

const FLIP := 0.5

var start_ms := 0
var font: Font
var ink := Color("1b2540")
var dots := Color("5b6782")
var card_top := Color("ffffff")
var card_bottom := Color("f3f5fa")
var slit := Color(0.1, 0.14, 0.3, 0.12)
var shadow := Color(0.16, 0.22, 0.45, 0.14)
var card_w := 150.0
var card_h := 210.0
var gap := 14.0
var colon_w := 60.0

var _cards: Array[FlipCard] = []


## Una cara completa de una tarjeta (las dos mitades con su cifra); cada mitad visible es un recorte de ella.
class Face extends Control:
	var digit := "0"
	var clock: FlipClock

	func show_digit(d: String) -> void:
		if d != digit:
			digit = d
			queue_redraw()

	func _draw() -> void:
		clock.draw_face(self, digit)


## Media tarjeta: recorta una cara a su mitad superior o inferior.
class Half extends Control:
	var face: Face

	func _init(clock: FlipClock, top: bool) -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(clock.card_w, clock.card_h * 0.5)
		position = Vector2(0.0, 0.0 if top else clock.card_h * 0.5)
		pivot_offset = Vector2(clock.card_w * 0.5, clock.card_h * 0.5 if top else 0.0)
		face = Face.new()
		face.clock = clock
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.size = Vector2(clock.card_w, clock.card_h)
		face.position = Vector2(0.0, 0.0 if top else -clock.card_h * 0.5)
		add_child(face)


class FlipCard extends Control:
	var top: Half
	var bottom: Half
	var fall: Half
	var rise: Half
	var digit := ""
	var t := -1.0

	func _init(clock: FlipClock) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(clock.card_w, clock.card_h)
		top = Half.new(clock, true)
		bottom = Half.new(clock, false)
		fall = Half.new(clock, true)
		rise = Half.new(clock, false)
		for h: Half in [top, bottom, fall, rise]:
			add_child(h)
		fall.visible = false
		rise.visible = false

	func set_digit(d: String, animate: bool) -> void:
		if d == digit:
			return
		var old := digit
		digit = d
		if not animate or old == "":
			top.face.show_digit(d)
			bottom.face.show_digit(d)
			return
		# Arriba ya se ve la cifra nueva; la lámina vieja cae y tapa la mitad de abajo con la nueva.
		top.face.show_digit(d)
		bottom.face.show_digit(old)
		fall.face.show_digit(old)
		rise.face.show_digit(d)
		t = 0.0
		_pose()

	func step(delta: float) -> void:
		if t < 0.0:
			return
		t += delta / FLIP
		if t >= 1.0:
			t = -1.0
			bottom.face.show_digit(digit)
		_pose()

	func _pose() -> void:
		if t < 0.0:
			fall.visible = false
			rise.visible = false
			top.modulate = Color.WHITE
			bottom.modulate = Color.WHITE
			return
		if t < 0.5:
			var a := t / 0.5
			fall.visible = true
			rise.visible = false
			fall.scale = Vector2(1.0, maxf(0.001, 1.0 - a * a))
			fall.modulate = Color.WHITE.lerp(Color(0.74, 0.77, 0.86), a)
			top.modulate = Color(0.82, 0.84, 0.9).lerp(Color.WHITE, a)
			bottom.modulate = Color.WHITE.lerp(Color(0.9, 0.91, 0.95), a)
		else:
			var b := (t - 0.5) / 0.5
			fall.visible = false
			rise.visible = true
			# Asienta con un rebote corto al llegar abajo.
			var e := 1.0 - pow(1.0 - b, 3.0)
			var bounce := 0.06 * sin(b * PI) * (1.0 - b)
			rise.scale = Vector2(1.0, clampf(e - bounce, 0.001, 1.0))
			rise.modulate = Color(0.78, 0.8, 0.88).lerp(Color.WHITE, b)
			top.modulate = Color.WHITE
			bottom.modulate = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_total_w(), card_h + 30.0)
	for i in 4:
		var c := FlipCard.new(self)
		_cards.append(c)
		add_child(c)
	_layout()
	_tick(false)
	resized.connect(_layout)


## Cambia el tema (claro u oscuro) sin rehacer el reloj.
func set_dark(on: bool) -> void:
	if on:
		card_top = Color("2b3350")
		card_bottom = Color("252c47")
		slit = Color(0, 0, 0, 0.45)
		shadow = Color(0, 0, 0, 0.4)
	for c in _cards:
		for h: Half in [c.top, c.bottom, c.fall, c.rise]:
			h.face.queue_redraw()
	queue_redraw()


func _total_w() -> float:
	return card_w * 4.0 + gap * 2.0 + colon_w


func _x(i: int) -> float:
	var x0 := (size.x - _total_w()) * 0.5
	var x := x0 + float(i) * (card_w + gap)
	if i >= 2:
		x += colon_w - gap
	return x


func _layout() -> void:
	for i in _cards.size():
		_cards[i].position = Vector2(_x(i), 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	_tick(true)
	for c in _cards:
		c.step(delta)


func _tick(animate: bool) -> void:
	var secs := maxi(0, int((Time.get_ticks_msec() - start_ms) / 1000))
	var m := mini(secs / 60, 99)
	var s := secs % 60 if secs / 60 <= 99 else 59
	var text := "%02d%02d" % [m, s]
	for i in _cards.size():
		_cards[i].set_digit(text[i], animate)


func _draw() -> void:
	# Sombras suaves bajo cada tarjeta.
	for i in 4:
		var sb := StyleBoxFlat.new()
		sb.bg_color = card_bottom
		sb.set_corner_radius_all(int(card_w * 0.2))
		sb.shadow_color = shadow
		sb.shadow_size = 22
		sb.shadow_offset = Vector2(0.0, 10.0)
		draw_style_box(sb, Rect2(Vector2(_x(i), 0.0), Vector2(card_w, card_h)))
	# Los dos puntos entre minutos y segundos.
	var cx := _x(1) + card_w + colon_w * 0.5
	var r := card_w * 0.065
	draw_circle(Vector2(cx, card_h * 0.36), r, dots)
	draw_circle(Vector2(cx, card_h * 0.64), r, dots)


## Dibuja una cara completa: mitad de arriba algo más clara, cifra centrada y la ranura del medio.
func draw_face(ci: CanvasItem, digit: String) -> void:
	var w := card_w
	var h := card_h
	var rad := int(w * 0.2)
	var up := StyleBoxFlat.new()
	up.bg_color = card_top
	up.corner_radius_top_left = rad
	up.corner_radius_top_right = rad
	up.anti_aliasing = true
	ci.draw_style_box(up, Rect2(0.0, 0.0, w, h * 0.5))
	var down := StyleBoxFlat.new()
	down.bg_color = card_bottom
	down.corner_radius_bottom_left = rad
	down.corner_radius_bottom_right = rad
	down.anti_aliasing = true
	ci.draw_style_box(down, Rect2(0.0, h * 0.5, w, h * 0.5))
	if font != null:
		var fs := int(h * 0.7)
		var tw := font.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# Las cifras de Inter miden ~0,73 em de alto: se centran sobre la ranura.
		ci.draw_string(font, Vector2((w - tw) * 0.5, h * 0.5 + fs * 0.73 * 0.5), digit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	ci.draw_rect(Rect2(0.0, h * 0.5 - 1.5, w, 3.0), slit)
