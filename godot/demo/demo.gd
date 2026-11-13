extends Control
## Demo del tablero 3D: problemas reales de Lichess para probar las piezas, la cámara y las animaciones.
## Todavía no es el entrenamiento completo (sin test de nivel ni explicaciones): sirve para juzgar el 3D
## y la pantalla de problema en un móvil. El estilo sigue docs/estilo-2d.md (inspirado en WakeAgenda).
##
## Composición en un móvil alto: barra arriba, el tablero de lado a lado, debajo la tarjeta del entrenador
## (qué toca, qué ha pasado y la ficha del problema: ahí irá la explicación) y, al pie, los botones, en la
## zona del pulgar. Las opciones no ocupan pantalla: se abren en una hoja inferior.

enum Phase { INTRO, SOLVING, WRONG, REPLY, SOLVED, SHOWING, SHOWN }

const LIGHT := {
	"bg": Color("eaf1fb"), "surface": Color("ffffff"), "ink": Color("1b2540"), "quiet": Color("5b6782"),
	"accent": Color("ff7a1a"), "accent_ink": Color("1b2540"), "accent_text": Color("b84a0c"),
	"accent_soft": Color("ffe6d0"), "good": Color("1f7a44"), "bad": Color("c0392b"),
	"track": Color("c9d5e8"), "field": Color("eef3fb"), "scrim": Color(0.07, 0.1, 0.22, 0.42),
	"shadow": Color(0.16, 0.3, 0.6, 0.16), "sky": Color("cfe1fb"), "cloud": Color("f7fbff"),
}
const DARK := {
	"bg": Color("0a0f1e"), "surface": Color("161e38"), "ink": Color("edeff7"), "quiet": Color("a3acc4"),
	"accent": Color("ff7a1a"), "accent_ink": Color("1b2540"), "accent_text": Color("ff9a3c"),
	"accent_soft": Color("3a2416"), "good": Color("4cbf7a"), "bad": Color("ff7b7f"),
	"track": Color("2c3759"), "field": Color("1f2946"), "scrim": Color(0.0, 0.0, 0.03, 0.6),
	"shadow": Color(0.0, 0.0, 0.0, 0.36), "sky": Color("141d44"), "cloud": Color("f4e6b6"),
}
## La vista 3D es algo más alta que el hueco del tablero y se funde con el fondo por arriba y por abajo:
## así caben la sombra del tablero y las cabezas de las piezas del fondo, y no se nota dónde acaba la vista.
const VIEW_BLEED_TOP := 64.0
const VIEW_BLEED_BOTTOM := 110.0
const VIEW_FADE := 48.0

var puzzles: Array = []
var index := 0
var puzzle: Dictionary = {}
## Índice de la jugada de la solución que toca jugar ahora.
var step := 0
## Índice de la jugada que se le pidió al jugador la última vez (para volver a ella).
var ask_step := 0
var fen_before := ""
var run_id := 0
var dark := false
var phase: Phase = Phase.INTRO
var options_open := false
var top_view := false
## Acabado del tablero (ver Board3D.FINISHES). El contorno de tinta va por defecto con el ilustrado.
const STYLES := ["madera", "marmol", "metal", "ilustrado"]
const STYLE_NAMES := ["Madera", "Mármol", "Metal", "Ilustrado"]
var board_style := "madera"
var board_outline := false

var view: BoardView3D
var bg: SkyBackdrop
var bar_row: Control
var chrome: VBoxContainer
var board_slot: Control
var counter: Label
var title: Label
var subtitle: Label
var turn_dot: TurnMark
var meta_row: HBoxContainer
var left_button: Button
var right_button: Button
var overlay: Control

var font_regular: Font
var font_medium: Font
var font_semibold: Font
var font_display: Font


## Fondo de la pantalla: cielo. Arriba es algo más intenso y se va fundiendo con el color de fondo; en el
## hueco que queda sobre el tablero en los móviles altos hay unas nubes (de día) o la luna y estrellas (de noche).
## Es el sitio previsto para los paisajes con el tiempo real (docs/estilo-2d.md); de momento, un cielo quieto.
class SkyBackdrop extends Control:
	var base := Color.WHITE
	var top := Color.WHITE
	var ornament := Color.WHITE
	var night := false
	## Franja libre para los adornos: desde debajo de la barra hasta donde empieza la vista del tablero.
	var band_top := 0.0
	var band_bottom := 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), base)
		var fade_end := clampf(band_bottom, 0.0, size.y)
		if fade_end > 8.0:
			draw_polygon(
				PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, fade_end), Vector2(0.0, fade_end)]),
				PackedColorArray([top, top, base, base]))
		var band := band_bottom - band_top
		if band < 220.0:
			return
		if night:
			_stars(band)
			_moon(Vector2(size.x * 0.2, band_top + band * 0.42))
		else:
			_cloud(Vector2(size.x * 0.25, band_top + band * 0.4), 1.2)
			_cloud(Vector2(size.x * 0.74, band_top + band * 0.68), 0.84)
			_cloud(Vector2(size.x * 0.58, band_top + band * 0.15), 0.54)

	func _sky_at(y: float) -> Color:
		return top.lerp(base, clampf(y / maxf(band_bottom, 1.0), 0.0, 1.0))

	func _cloud(c: Vector2, k: float) -> void:
		var body := StyleBoxFlat.new()
		body.bg_color = ornament
		body.set_corner_radius_all(int(24.0 * k))
		draw_style_box(body, Rect2(c + Vector2(-96.0, -8.0) * k, Vector2(196.0, 48.0) * k))
		for puff: Vector3 in [Vector3(-56.0, -4.0, 32.0), Vector3(-14.0, -22.0, 46.0), Vector3(36.0, -10.0, 38.0), Vector3(70.0, 8.0, 26.0)]:
			draw_circle(c + Vector2(puff.x, puff.y) * k, puff.z * k, ornament, true, -1.0, true)

	func _moon(c: Vector2) -> void:
		draw_circle(c, 30.0, ornament, true, -1.0, true)
		# El mordisco de la luna: un círculo del color del cielo en ese punto.
		draw_circle(c + Vector2(13.0, -9.0), 26.0, _sky_at(c.y - 9.0), true, -1.0, true)

	func _stars(band: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261113
		for i in 26:
			var p := Vector2(rng.randf_range(36.0, size.x - 36.0), band_top + rng.randf_range(0.02, 0.86) * band)
			var r := rng.randf_range(1.6, 3.4)
			var a := rng.randf_range(0.28, 0.9)
			draw_circle(p, r, Color(0.86, 0.91, 1.0, a), true, -1.0, true)


## Botón redondo con un icono dibujado a mano (sin archivos de imagen).
class IconButton extends Button:
	var kind := ""
	var ink := Color.WHITE
	var paper := Color.BLACK

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"options":
				# Tres deslizadores.
				var ys: Array[float] = [-15.0, 0.0, 15.0]
				var xs: Array[float] = [9.0, -9.0, 4.0]
				for i in 3:
					var y := c.y + ys[i]
					draw_line(Vector2(c.x - 20.0, y), Vector2(c.x + 20.0, y), ink, 4.5, true)
					var knob := Vector2(c.x + xs[i], y)
					draw_circle(knob, 8.5, paper)
					draw_arc(knob, 6.5, 0.0, TAU, 28, ink, 4.5, true)
			"view":
				# Un tablero visto en perspectiva.
				var pts := PackedVector2Array([c + Vector2(-13.0, -12.0), c + Vector2(13.0, -12.0), c + Vector2(21.0, 13.0), c + Vector2(-21.0, 13.0), c + Vector2(-13.0, -12.0)])
				draw_polyline(pts, ink, 4.5, true)
				draw_line(c + Vector2(0.0, -12.0), c + Vector2(0.0, 13.0), ink, 3.0, true)
				draw_line(c + Vector2(-16.5, -1.0), c + Vector2(16.5, -1.0), ink, 3.0, true)
			"close":
				draw_line(c + Vector2(-13.0, -13.0), c + Vector2(13.0, 13.0), ink, 4.5, true)
				draw_line(c + Vector2(13.0, -13.0), c + Vector2(-13.0, 13.0), ink, 4.5, true)


## Marca del turno: un peón pequeño con el color del bando que juega.
class TurnMark extends Control:
	var fill := Color.WHITE
	var line := Color.BLACK

	func _draw() -> void:
		var o := Vector2((size.x - 40.0) * 0.5, (size.y - 44.0) * 0.5)
		# Primero la silueta engordada, en el color de la línea; encima, el relleno.
		for pass_index in 2:
			var grow := 3.0 if pass_index == 0 else 0.0
			var color := line if pass_index == 0 else fill
			var base := StyleBoxFlat.new()
			base.bg_color = color
			base.set_corner_radius_all(int(4.0 + grow))
			draw_style_box(base, Rect2(o + Vector2(6.0 - grow, 33.0 - grow), Vector2(28.0 + grow * 2.0, 8.0 + grow * 2.0)))
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(14.0 - grow, 18.0 - grow), o + Vector2(26.0 + grow, 18.0 - grow),
				o + Vector2(30.0 + grow, 35.0), o + Vector2(10.0 - grow, 35.0)]), color)
			draw_circle(o + Vector2(20.0, 12.0), 9.0 + grow, color, true, -1.0, true)


## Interruptor de dos posiciones.
class Switch extends Button:
	var on := false
	var on_color := Color.ORANGE
	var off_color := Color.GRAY
	var knob_color := Color.WHITE

	func _draw() -> void:
		var track := StyleBoxFlat.new()
		track.bg_color = on_color if on else off_color
		track.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var d := size.y - 12.0
		var knob := StyleBoxFlat.new()
		knob.bg_color = knob_color
		knob.set_corner_radius_all(int(d * 0.5))
		var x := (size.x - d - 6.0) if on else 6.0
		draw_style_box(knob, Rect2(Vector2(x, 6.0), Vector2(d, d)))


func _ready() -> void:
	font_regular = _load_font("Inter-Regular.woff2")
	font_medium = _load_font("Inter-Medium.woff2")
	font_semibold = _load_font("Inter-SemiBold.woff2")
	font_display = _load_font("InterDisplay-Bold.woff2")
	_load_puzzles()

	bg = SkyBackdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# El tablero 3D pinta su propio fondo con el color de esta pantalla (ver BoardView3D.set_board_theme).
	view = BoardView3D.new()
	view.move_played.connect(_on_move_played)
	add_child(view)

	_build_chrome()
	resized.connect(_layout)
	_start(0)


func _notification(what: int) -> void:
	# El botón «atrás» de Android cierra las opciones.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and options_open:
		_close_options()


func _load_font(file: String) -> Font:
	var path := "res://fonts/" + file
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null


func _load_puzzles() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_puzzles.json"))
	if typeof(data) == TYPE_DICTIONARY:
		puzzles = data.get("puzzles", [])


# ---------------------------------------------------------------- piezas de la interfaz

func _c(key: String) -> Color:
	var palette: Dictionary = DARK if dark else LIGHT
	return palette[key]


func _text(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	# Una sola línea, siempre: si el texto cambia, nada se mueve de sitio.
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _pad(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


func _spacer(height: float, grow: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if grow:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _style_button(b: Button, fill: Color, fg: Color, radius: int, font_size: int, font: Font, glow: Color = Color(0, 0, 0, 0)) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill.darkened(0.08) if state == "pressed" else fill
		sb.set_corner_radius_all(radius)
		sb.content_margin_left = 26.0
		sb.content_margin_right = 26.0
		sb.content_margin_top = 16.0
		sb.content_margin_bottom = 16.0
		if glow.a > 0.0 and state != "pressed":
			sb.shadow_color = glow
			sb.shadow_size = 18
			sb.shadow_offset = Vector2(0.0, 8.0)
		b.add_theme_stylebox_override(state, sb)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_font_size_override("font_size", font_size)
	if font != null:
		b.add_theme_font_override("font", font)


## Etiqueta en forma de píldora.
func _chip(text: String, fill: Color, fg: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(32)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 27)
	l.add_theme_color_override("font_color", fg)
	if font_medium != null:
		l.add_theme_font_override("font", font_medium)
	chip.add_child(l)
	return chip


func _icon_button(kind: String, on_press: Callable) -> IconButton:
	var b := IconButton.new()
	b.kind = kind
	b.ink = _c("ink")
	b.paper = _c("surface")
	b.custom_minimum_size = Vector2(96.0, 96.0)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	_style_button(b, _c("surface"), _c("ink"), 48, 30, null, _c("shadow"))
	return b


func _insets() -> Vector2:
	# Margen seguro arriba y abajo (muesca de la cámara, barra de gestos), en unidades del lienzo.
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var canvas := get_viewport_rect().size
	if win.y <= 0 or safe.size.y <= 0 or canvas.y <= 0.0:
		return Vector2.ZERO
	var k := canvas.y / float(win.y)
	var top := clampf(float(safe.position.y) * k, 0.0, 170.0)
	var bottom := clampf(float(win.y - safe.end.y) * k, 0.0, 130.0)
	return Vector2(top, bottom)


# ---------------------------------------------------------------- pantalla

## Construye todo menos el tablero. Se rehace entero al cambiar de tema: es barato y no deja estilos a medias.
func _build_chrome() -> void:
	if chrome != null:
		chrome.visible = false
		chrome.queue_free()
	var th := Theme.new()
	if font_regular != null:
		th.default_font = font_regular
	th.default_font_size = 32
	theme = th
	bg.base = _c("bg")
	bg.top = _c("sky")
	bg.ornament = _c("cloud")
	bg.night = dark
	bg.queue_redraw()
	view.set_board_style(board_style, board_outline)
	view.set_board_theme("dark" if dark else "light", _c("bg"))

	var inset := _insets()
	chrome = VBoxContainer.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.add_theme_constant_override("separation", 0)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)

	# Barra superior: contador y botones redondos (vista y opciones).
	# En pantalla completa la zona de la barra de estado sigue teniendo la cámara y los avisos del sistema:
	# se deja siempre un margen arriba, aunque el sistema no informe de ninguno.
	chrome.add_child(_spacer(maxf(inset.x, 60.0) + 18.0))
	var bar_pad := _pad(40, 0, 36, 0)
	chrome.add_child(bar_pad)
	bar_row = bar_pad
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_pad.add_child(bar)
	counter = _text("", 30, _c("quiet"), font_medium)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(counter)
	bar.add_child(_icon_button("view", _on_toggle_view))
	bar.add_child(_icon_button("options", _open_options))

	# El espacio que sobra en un móvil alto va sobre todo arriba: el tablero queda más cerca del pulgar.
	var top_gap := _spacer(0.0, true)
	top_gap.size_flags_stretch_ratio = 1.0
	chrome.add_child(top_gap)

	# Hueco del tablero: el tablero 3D se coloca encima de este hueco (ver _place_board).
	board_slot = Control.new()
	board_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_slot.item_rect_changed.connect(_place_board)
	chrome.add_child(board_slot)

	# Tarjeta del entrenador, bajo el tablero: titular, una línea de apoyo y la ficha del problema.
	var card_pad := _pad(28, 20, 28, 0)
	chrome.add_child(card_pad)
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = _c("surface")
	card_style.set_corner_radius_all(48)
	card_style.content_margin_left = 40.0
	card_style.content_margin_right = 40.0
	card_style.content_margin_top = 30.0
	card_style.content_margin_bottom = 34.0
	card_style.shadow_color = _c("shadow")
	card_style.shadow_size = 30
	card_style.shadow_offset = Vector2(0.0, 12.0)
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_pad.add_child(card)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(head)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title_row)
	turn_dot = TurnMark.new()
	turn_dot.custom_minimum_size = Vector2(46.0, 50.0)
	turn_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	turn_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(turn_dot)
	title = _text("", 58, _c("ink"), font_display)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	subtitle = _text("", 33, _c("quiet"), font_regular)
	head.add_child(subtitle)
	head.add_child(_spacer(20.0))
	meta_row = HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 12)
	meta_row.custom_minimum_size = Vector2(0.0, 58.0)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(meta_row)

	var bottom_gap := _spacer(28.0, true)
	bottom_gap.size_flags_stretch_ratio = 0.45
	chrome.add_child(bottom_gap)

	# Acciones, abajo.
	var actions_pad := _pad(36, 0, 36, 0)
	chrome.add_child(actions_pad)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions_pad.add_child(actions)
	left_button = Button.new()
	right_button = Button.new()
	for b: Button in [left_button, right_button]:
		b.custom_minimum_size = Vector2(0.0, 124.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		actions.add_child(b)
	left_button.pressed.connect(_on_left)
	right_button.pressed.connect(_on_right)
	chrome.add_child(_spacer(inset.y + 34.0))

	_refresh()
	_layout()
	_place_board.call_deferred()
	if options_open:
		_build_sheet()


## El hueco del tablero es tan alto como hace falta para que el tablero vaya de lado a lado, y no más:
## lo que sobra en un móvil alto se reparte por encima y por debajo del bloque central.
func _layout() -> void:
	if chrome == null or board_slot == null:
		return
	var canvas := get_viewport_rect().size
	var fixed := 0.0
	for child in chrome.get_children():
		if child != board_slot and child is Control:
			fixed += (child as Control).get_combined_minimum_size().y
	board_slot.custom_minimum_size = Vector2(0.0, clampf(canvas.y - fixed, 320.0, maxf(canvas.x, 320.0)))


func _place_board() -> void:
	if board_slot == null or not is_instance_valid(board_slot):
		return
	var rect := board_slot.get_global_rect()
	var top := clampf(rect.position.y, 0.0, VIEW_BLEED_TOP)
	var bottom := clampf(size.y - rect.end.y, 0.0, VIEW_BLEED_BOTTOM)
	view.position = Vector2(rect.position.x, rect.position.y - top)
	view.size = Vector2(rect.size.x, rect.size.y + top + bottom)
	view.edge_fade = VIEW_FADE
	# El tablero se encuadra dentro del hueco; lo que sobra por arriba y por abajo es solo fondo y sombra.
	var h := maxf(view.size.y, 1.0)
	view.board.fit_pad = Vector4(0.012, (top + 6.0) / h, 0.012, (bottom + 6.0) / h)
	view.board.apply_camera()
	# El cielo se funde con el fondo justo antes de la vista del tablero; sus adornos van entre la barra y ella.
	bg.band_top = bar_row.get_global_rect().end.y + 16.0 if bar_row != null and is_instance_valid(bar_row) else 0.0
	bg.band_bottom = view.position.y
	bg.queue_redraw()


## Pone los textos y los botones que corresponden a la fase del problema.
func _refresh() -> void:
	if title == null or not is_instance_valid(title):
		return
	var total := puzzles.size()
	counter.text = ("Problema %d de %d" % [index + 1, total]) if total > 0 else "Sin problemas"
	var theme_name := str(puzzle.get("theme", ""))
	var rating := int(puzzle.get("rating", 0))
	var head := ""
	var sub := ""
	var tone := _c("ink")
	var show_dot := false
	match phase:
		Phase.INTRO:
			head = "Mira al rival"
			sub = "Fíjate en su jugada: después te toca a ti."
		Phase.SOLVING:
			head = "Juegan %s" % ("blancas" if view.board.chess.turn == 0 else "negras")
			sub = "Encuentra la mejor jugada." if ask_step <= 1 else "Sigue: todavía hay más."
			show_dot = true
		Phase.WRONG:
			head = "No es la mejor"
			sub = "Vuelve a intentarlo o mira la solución."
			tone = _c("bad")
		Phase.REPLY:
			head = "¡Bien!"
			sub = "Mira cómo responde el rival…"
			tone = _c("good")
		Phase.SOLVED:
			head = "¡Resuelto!"
			sub = "Puedes repetirlo o pasar al siguiente."
			tone = _c("good")
		Phase.SHOWING:
			head = "La solución"
			sub = "Mira cómo sigue…"
		Phase.SHOWN:
			head = "La solución"
			sub = "Puedes repetirlo o pasar al siguiente."
	if total == 0:
		head = "Sin problemas"
		sub = "No se ha encontrado data/demo_puzzles.json."
	title.text = head
	title.add_theme_color_override("font_color", tone)
	subtitle.text = sub

	# Peón con el color del bando que juega, según el acabado. En el tema oscuro, las oscuras llevan el canto claro.
	var white_to_move := view.board.chess.turn == 0
	var swatches: Array = view.board.piece_swatches()
	var mark_fill: Color = swatches[0] if white_to_move else swatches[1]
	turn_dot.fill = mark_fill
	if white_to_move:
		turn_dot.line = mark_fill.darkened(0.72)
	else:
		turn_dot.line = mark_fill.lightened(0.6) if dark else mark_fill.darkened(0.6)
	turn_dot.queue_redraw()
	turn_dot.visible = show_dot

	# Etiquetas. El tema del problema es una pista: solo se enseña cuando ya está resuelto o mostrado.
	var done := phase == Phase.SOLVED or phase == Phase.SHOWN
	for old_chip in meta_row.get_children():
		meta_row.remove_child(old_chip)
		old_chip.queue_free()
	if total > 0:
		if done and theme_name != "":
			meta_row.add_child(_chip(theme_name, _c("accent_soft"), _c("accent_text")))
		meta_row.add_child(_chip("Dificultad %d" % rating, _c("field"), _c("ink")))
		meta_row.add_child(_chip("Problema real de Lichess", _c("field"), _c("quiet")))

	left_button.text = "Repetir" if done else "Ver solución"
	right_button.text = "Siguiente" if done else "Saltar"
	_style_button(left_button, _c("accent_soft"), _c("accent_text"), 62, 36, font_semibold)
	if done:
		# El naranja pleno solo aparece cuando toca avanzar.
		_style_button(right_button, _c("accent"), _c("accent_ink"), 62, 36, font_semibold, Color(1.0, 0.48, 0.1, 0.34))
	else:
		_style_button(right_button, _c("surface"), _c("ink"), 62, 36, font_semibold, _c("shadow"))


func _set_phase(p: Phase) -> void:
	phase = p
	_refresh()


# ---------------------------------------------------------------- opciones (hoja inferior)

func _open_options() -> void:
	options_open = true
	_build_sheet()
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.14)


func _close_options() -> void:
	options_open = false
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.queue_free()
	overlay = null


func _sync_sheet() -> void:
	if options_open:
		_build_sheet.call_deferred()


func _on_scrim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		_close_options()


func _build_sheet() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.queue_free()
	if not options_open:
		overlay = null
		return
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var scrim := ColorRect.new()
	scrim.color = _c("scrim")
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	overlay.add_child(scrim)

	var sheet := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _c("surface")
	sb.corner_radius_top_left = 60
	sb.corner_radius_top_right = 60
	sb.content_margin_left = 44.0
	sb.content_margin_right = 44.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 44.0 + _insets().y
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	sb.shadow_size = 40
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay.add_child(sheet)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	sheet.add_child(box)

	var grab_row := CenterContainer.new()
	var grab := Panel.new()
	grab.custom_minimum_size = Vector2(92.0, 9.0)
	var grab_style := StyleBoxFlat.new()
	grab_style.bg_color = _c("track")
	grab_style.set_corner_radius_all(5)
	grab.add_theme_stylebox_override("panel", grab_style)
	grab_row.add_child(grab)
	box.add_child(grab_row)

	var header := HBoxContainer.new()
	var heading := _text("Opciones", 48, _c("ink"), font_display)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	var close := _icon_button("close", _close_options)
	_style_button(close, _c("field"), _c("ink"), 48, 30, null)
	close.paper = _c("field")
	header.add_child(close)
	box.add_child(header)

	box.add_child(_caption("Acabado"))
	box.add_child(_segments(STYLE_NAMES, STYLES.find(board_style), _set_style_index))
	box.add_child(_switch_row("Contorno de las piezas", "Una línea de tinta alrededor de cada pieza.", board_outline, _set_outline))
	box.add_child(_caption("Animaciones"))
	box.add_child(_segments(["Completas", "Rápidas", "Mínimas", "Sin"], int(view.board.anim_mode), _set_anim))
	box.add_child(_caption("Vista"))
	box.add_child(_segments(["Inclinada", "En picado"], 1 if top_view else 0, _set_top_view))
	box.add_child(_switch_row("Seguir al móvil", "La vista acompaña la inclinación y el giro del teléfono.", view.tilt_enabled, _set_tilt))
	box.add_child(_switch_row("Fijar la vista", "Ni el móvil ni los dedos la mueven.", view.view_locked, _set_lock))
	box.add_child(_text("Pellizca el tablero con dos dedos para ampliarlo; el botón de vista lo deja entero.", 26, _c("quiet"), font_regular))
	box.add_child(_text("Con dos dedos también giras la vista o mueves el tablero ampliado.", 26, _c("quiet"), font_regular))
	box.add_child(_caption("Tema"))
	box.add_child(_segments(["Claro", "Oscuro"], 1 if dark else 0, _set_theme_index))


func _caption(text: String) -> MarginContainer:
	var m := _pad(4, 18, 0, 0)
	m.add_child(_text(text.to_upper(), 24, _c("quiet"), font_semibold))
	return m


## Fila de botones en la que solo uno está elegido.
func _segments(names: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in names.size():
		var b := Button.new()
		b.text = str(names[i])
		b.custom_minimum_size = Vector2(0.0, 92.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		if i == selected:
			_style_button(b, _c("accent_soft"), _c("accent_text"), 46, 30, font_semibold)
		else:
			_style_button(b, _c("field"), _c("quiet"), 46, 30, font_medium)
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	return row


func _switch_row(label: String, hint: String, value: bool, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_text(label, 34, _c("ink"), font_medium))
	texts.add_child(_text(hint, 26, _c("quiet"), font_regular))
	row.add_child(texts)
	var sw := Switch.new()
	sw.on = value
	sw.on_color = _c("accent")
	sw.off_color = _c("track")
	sw.knob_color = Color.WHITE
	sw.custom_minimum_size = Vector2(108.0, 62.0)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		sw.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	sw.pressed.connect(on_change.bind(not value))
	row.add_child(sw)
	return row


func _set_style_index(i: int) -> void:
	board_style = STYLES[clampi(i, 0, STYLES.size() - 1)]
	# Cada acabado tiene su contorno por defecto: el ilustrado lo lleva; los realistas, no.
	board_outline = board_style == "ilustrado"
	view.set_board_style(board_style, board_outline)
	_refresh()
	_sync_sheet()


func _set_outline(on: bool) -> void:
	board_outline = on
	view.board.set_outline(on)
	_sync_sheet()


func _set_anim(mode: int) -> void:
	view.board.anim_mode = mode as Board3D.Anim
	_sync_sheet()


func _set_top_view(i: int) -> void:
	top_view = i == 1
	if top_view:
		view.center_view()
	else:
		view.default_view()
	_sync_sheet()


## Botón de vista: si el tablero está ampliado, lo devuelve a su tamaño; si no, cambia entre inclinada y en picado.
func _on_toggle_view() -> void:
	if view.is_zoomed():
		view.reset_zoom()
		return
	_set_top_view(0 if top_view else 1)


func _set_tilt(on: bool) -> void:
	view.set_tilt_enabled(on)
	if on:
		view.set_view_locked(false)
	_sync_sheet()


func _set_lock(on: bool) -> void:
	view.set_view_locked(on)
	_sync_sheet()


func _set_theme_index(i: int) -> void:
	_set_dark(i == 1)


func _set_dark(on: bool) -> void:
	if dark == on:
		return
	dark = on
	_build_chrome.call_deferred()


# ---------------------------------------------------------------- problema

func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


## Vuelve a la posición en la que se pidió la jugada, con la del rival resaltada.
func _restore_position() -> void:
	view.set_fen(fen_before)
	var moves: Array = puzzle.get("moves", [])
	if ask_step >= 1 and ask_step - 1 < moves.size():
		var rival := str(moves[ask_step - 1])
		view.board.mark_last_move(Chess.sq_index(rival.substr(0, 2)), Chess.sq_index(rival.substr(2, 2)))


func _start(i: int) -> void:
	run_id += 1
	var my_run := run_id
	if puzzles.is_empty():
		_refresh()
		return
	index = posmod(i, puzzles.size())
	puzzle = puzzles[index]
	step = 0
	ask_step = 0
	view.board.set_arrows([])
	view.set_fen(puzzle["fen"])
	# Juega quien responde a la primera jugada (la del rival).
	view.set_orientation(1 - view.board.chess.turn)
	view.interactive = false
	_set_phase(Phase.INTRO)
	await _wait(0.7)
	if my_run != run_id:
		return
	var moves: Array = puzzle["moves"]
	view.show_move(str(moves[0]))
	step = 1
	await _wait(0.55)
	if my_run != run_id:
		return
	_ask()


func _ask() -> void:
	fen_before = view.board.chess.fen()
	ask_step = step
	view.interactive = true
	_set_phase(Phase.SOLVING)


func _on_move_played(uci: String) -> void:
	var my_run := run_id
	var moves: Array = puzzle["moves"]
	if step >= moves.size():
		return
	var mate := view.board.chess.is_checkmate()
	if uci != str(moves[step]) and not mate:
		view.interactive = false
		_set_phase(Phase.WRONG)
		await _wait(0.9)
		if my_run != run_id:
			return
		_restore_position()
		view.interactive = true
		_set_phase(Phase.SOLVING)
		return
	step += 1
	if mate or step >= moves.size():
		view.interactive = false
		_set_phase(Phase.SOLVED)
		return
	view.interactive = false
	_set_phase(Phase.REPLY)
	await _wait(0.55)
	if my_run != run_id:
		return
	view.show_move(str(moves[step]))
	step += 1
	await _wait(0.45)
	if my_run != run_id:
		return
	_ask()


func _show_solution() -> void:
	var moves: Array = puzzle.get("moves", [])
	if phase == Phase.INTRO or phase == Phase.SHOWING or ask_step < 1 or ask_step >= moves.size():
		return
	run_id += 1
	var my_run := run_id
	view.interactive = false
	_restore_position()
	step = ask_step
	_set_phase(Phase.SHOWING)
	while step < moves.size():
		await _wait(0.75)
		if my_run != run_id:
			return
		view.show_move(str(moves[step]))
		step += 1
	_set_phase(Phase.SHOWN)


## Botón izquierdo: «Ver solución» mientras se resuelve; «Repetir» cuando el problema ha terminado.
func _on_left() -> void:
	if phase == Phase.SOLVED or phase == Phase.SHOWN:
		_start(index)
	else:
		_show_solution()


## Botón derecho: «Saltar» o «Siguiente».
func _on_right() -> void:
	_start(index + 1)
