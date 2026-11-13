extends Control
## Demo del tablero 3D: problemas reales de Lichess para probar las piezas, la cámara y las animaciones.
## Todavía no es el entrenamiento completo (sin test de nivel ni explicaciones): sirve para juzgar el 3D
## y la pantalla de problema en un móvil. El estilo sigue docs/estilo-2d.md (inspirado en WakeAgenda).
##
## Composición en un móvil alto: barra arriba, botones abajo (zona del pulgar) y, centrado entre ambos,
## un bloque con el titular, el tablero de lado a lado y la ficha del problema. Las opciones no ocupan
## pantalla: se abren en una hoja inferior.

enum Phase { INTRO, SOLVING, WRONG, REPLY, SOLVED, SHOWING, SHOWN }

const LIGHT := {
	"bg": Color("eaf1fb"), "surface": Color("ffffff"), "ink": Color("1b2540"), "quiet": Color("5b6782"),
	"accent": Color("ff7a1a"), "accent_ink": Color("1b2540"), "accent_text": Color("b84a0c"),
	"accent_soft": Color("ffe6d0"), "good": Color("1f7a44"), "bad": Color("c0392b"),
	"track": Color("c9d5e8"), "field": Color("eef3fb"), "scrim": Color(0.07, 0.1, 0.22, 0.42),
	"shadow": Color(0.16, 0.3, 0.6, 0.16), "halo": Color(1.0, 1.0, 1.0, 0.9),
}
const DARK := {
	"bg": Color("0a0f1e"), "surface": Color("161e38"), "ink": Color("edeff7"), "quiet": Color("a3acc4"),
	"accent": Color("ff7a1a"), "accent_ink": Color("1b2540"), "accent_text": Color("ff9a3c"),
	"accent_soft": Color("3a2416"), "good": Color("4cbf7a"), "bad": Color("ff7b7f"),
	"track": Color("2c3759"), "field": Color("1f2946"), "scrim": Color(0.0, 0.0, 0.03, 0.6),
	"shadow": Color(0.0, 0.0, 0.0, 0.36), "halo": Color(0.2, 0.29, 0.6, 0.5),
}

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

var view: BoardView3D
var bg: ColorRect
var halo: TextureRect
var chrome: VBoxContainer
var board_slot: Control
var counter: Label
var title: Label
var subtitle: Label
var turn_dot: Panel
var meta: Label
var left_button: Button
var right_button: Button
var overlay: Control

var font_regular: Font
var font_medium: Font
var font_semibold: Font
var font_display: Font


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

	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Resplandor suave detrás del tablero. El tablero 3D es transparente: todo el fondo es de esta pantalla.
	halo = TextureRect.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(halo)
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
	bg.color = _c("bg")
	_paint_halo()
	view.set_board_theme("dark" if dark else "light")

	var inset := _insets()
	chrome = VBoxContainer.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.add_theme_constant_override("separation", 0)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)

	# Barra superior: contador y botones redondos (vista y opciones).
	chrome.add_child(_spacer(inset.x + 22.0))
	var bar_pad := _pad(40, 0, 36, 0)
	chrome.add_child(bar_pad)
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

	chrome.add_child(_spacer(0.0, true))

	# Titular, pegado al tablero.
	var head_pad := _pad(40, 0, 40, 10)
	chrome.add_child(head_pad)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_pad.add_child(head)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title_row)
	turn_dot = Panel.new()
	turn_dot.custom_minimum_size = Vector2(40.0, 40.0)
	turn_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	turn_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(turn_dot)
	title = _text("", 68, _c("ink"), font_display)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	subtitle = _text("", 34, _c("quiet"), font_regular)
	head.add_child(subtitle)

	# Hueco del tablero: el tablero 3D se coloca encima de este hueco (ver _place_board).
	board_slot = Control.new()
	board_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_slot.item_rect_changed.connect(_place_board)
	chrome.add_child(board_slot)

	# Ficha del problema.
	var meta_pad := _pad(40, 6, 40, 0)
	chrome.add_child(meta_pad)
	meta = _text("", 28, _c("quiet"), font_medium)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_pad.add_child(meta)

	chrome.add_child(_spacer(0.0, true))

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
	view.position = rect.position
	view.size = rect.size
	var side := rect.size.x * 1.55
	halo.size = Vector2(side, side)
	halo.position = rect.get_center() - halo.size * 0.5


func _paint_halo() -> void:
	var g := Gradient.new()
	var inner := _c("halo")
	g.set_color(0, inner)
	g.set_color(1, Color(inner.r, inner.g, inner.b, 0.0))
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	halo.texture = tex


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

	# Punto con el color del bando que juega.
	var white_to_move := view.board.chess.turn == 0
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color("f8f0e0") if white_to_move else Color("2a3557")
	dot.set_corner_radius_all(20)
	dot.set_border_width_all(4)
	dot.border_color = Color("262e4c") if white_to_move else (Color("9db2e0") if dark else Color("0a0f22"))
	turn_dot.add_theme_stylebox_override("panel", dot)
	turn_dot.visible = show_dot

	# El tema del problema es una pista: solo se dice cuando ya está resuelto o mostrado.
	var done := phase == Phase.SOLVED or phase == Phase.SHOWN
	if total == 0:
		meta.text = ""
	elif done and theme_name != "":
		meta.text = "%s · dificultad %d · problema real de Lichess" % [theme_name, rating]
	else:
		meta.text = "Dificultad %d · problema real de Lichess" % rating

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

	box.add_child(_caption("Animaciones"))
	box.add_child(_segments(["Completas", "Rápidas", "Mínimas", "Sin"], int(view.board.anim_mode), _set_anim))
	box.add_child(_caption("Vista"))
	box.add_child(_segments(["Inclinada", "En picado"], 1 if top_view else 0, _set_top_view))
	box.add_child(_switch_row("Seguir al móvil", "La vista acompaña la inclinación y el giro del teléfono.", view.tilt_enabled, _set_tilt))
	box.add_child(_switch_row("Fijar la vista", "Ni el móvil ni los dedos la mueven.", view.view_locked, _set_lock))
	var tip := _text("Con dos dedos sobre el tablero se gira la vista.", 26, _c("quiet"), font_regular)
	box.add_child(tip)
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


func _on_toggle_view() -> void:
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
