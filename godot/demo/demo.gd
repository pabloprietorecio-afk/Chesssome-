extends Control
## Pantalla de problema de la app: problemas reales de Lichess sobre el tablero 3D, con su explicación.
## Todavía no es el entrenamiento completo (falta el test de nivel y la elección de problemas según el
## jugador), pero ya enseña lo que distingue a Chessome: cuando fallas, te explica qué tenía de bueno tu
## jugada y qué permite; cuando aciertas o pides la solución, por qué funciona, en cuatro niveles de
## profundidad. Las explicaciones vienen ya redactadas y verificadas (core/explain_data.gd).
## El estilo sigue docs/estilo-2d.md (inspirado en WakeAgenda).
##
## Composición en un móvil alto: barra arriba, el tablero de lado a lado, debajo la tarjeta del entrenador
## (qué toca, qué ha pasado y la explicación, con desplazamiento si es larga) y, al pie, los botones, en la
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
## Alto mínimo que se reserva a la tarjeta del entrenador y sitio que se le deja mientras se resuelve
## (lo demás va de cielo, encima del tablero). Cuando hay explicación completa, el tablero sube y la
## tarjeta se queda con todo el sitio.
const CARD_MIN := 300.0
const CARD_ROOM := 470.0
const SETTINGS_PATH := "user://chessome.cfg"
const WHY_LABELS := {1: "Explícame por qué", 2: "Ver la variante", 3: "Ver el análisis"}
const SOURCE_NAMES := {"motor": "Motor", "reglas": "Reglas", "lichess": "Lichess"}

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
## Juego de piezas: figuras o fichas planas con el icono en relieve (Board3D.PIECE_SETS).
const SETS := ["clasico", "fichas"]
const SET_NAMES := ["Figuras", "Fichas"]
var piece_set := "clasico"
var sound_on := true
## Con false no se leen ni se guardan los ajustes ni se enseña la bienvenida (lo usan las pruebas).
var use_settings := true
var welcome_seen := false
var app_version := ""

## Explicaciones del problema actual y lo que se está enseñando de ellas.
var explain: ExplainData
## Explicación a la vista ({} si no hay), nivel abierto (1–4) y punto de decisión al que se refiere.
var expl: Dictionary = {}
var exp_level := 1
var exp_point := 0
## El jugador todavía puede reintentar: se le cuenta qué hace su jugada y qué permite, no cuál era la mejor.
var exp_partial := false
## Último fallo en el punto de decisión actual: {point, uci}.
var last_wrong: Dictionary = {}
## «¿Y si juego…?»: el jugador prueba jugadas en la posición de decisión y recibe su explicación.
var whatif := false
var whatif_exp: Dictionary = {}
var whatif_level := 1
var facts_open := false
## Variante que se está viendo en el tablero ({} si ninguna) y por qué jugada va (−1 = al principio).
var line_on: Dictionary = {}
var line_ply := -1
var sheet_kind := ""
var _keep_scroll := false
var _gap_tween: Tween
## Alto de todo lo que no es tablero, cielo ni tarjeta (barra, botones y márgenes), según el último reparto.
var _fixed_height := 0.0
var _ai_status: Label
var _saved_anim := int(Board3D.Anim.FAST)

var view: BoardView3D
var bg: SkyBackdrop
var bar_row: Control
var chrome: VBoxContainer
var board_slot: Control
var top_gap: Control
var card_pad: MarginContainer
var card: PanelContainer
var card_scroll: ScrollContainer
var card_body: VBoxContainer
var counter: Label
var title: Label
var turn_dot: TurnMark
var left_button: Button
var right_button: Button
var overlay: Control
var welcome: Control

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
			"next":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-9.0, -14.0), c + Vector2(13.0, 0.0), c + Vector2(-9.0, 14.0)]), ink)
			"prev":
				draw_colored_polygon(PackedVector2Array([c + Vector2(9.0, -14.0), c + Vector2(-13.0, 0.0), c + Vector2(9.0, 14.0)]), ink)
			"first":
				draw_colored_polygon(PackedVector2Array([c + Vector2(13.0, -14.0), c + Vector2(-7.0, 0.0), c + Vector2(13.0, 14.0)]), ink)
				draw_line(c + Vector2(-11.0, -14.0), c + Vector2(-11.0, 14.0), ink, 4.5, true)


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
	_load_version()
	if use_settings:
		_load_settings()

	bg = SkyBackdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# El tablero 3D pinta su propio fondo con el color de esta pantalla (ver BoardView3D.set_board_theme).
	view = BoardView3D.new()
	view.move_played.connect(_on_move_played)
	add_child(view)
	view.set_piece_set(piece_set)
	view.set_sound_enabled(sound_on)
	view.board.anim_mode = _saved_anim as Board3D.Anim

	_build_chrome()
	resized.connect(_layout)
	_start(0)
	if use_settings and not welcome_seen:
		_open_welcome()


func _notification(what: int) -> void:
	# El botón «atrás» de Android cierra lo que haya abierto encima de la pantalla.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if welcome != null and is_instance_valid(welcome):
			_close_welcome()
		elif sheet_kind != "":
			_close_options()
		elif whatif:
			_toggle_whatif()


func _load_font(file: String) -> Font:
	var path := "res://fonts/" + file
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null


func _load_puzzles() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_puzzles.json"))
	if typeof(data) == TYPE_DICTIONARY:
		puzzles = data.get("puzzles", [])


## Versión de la app, para enseñarla en Opciones: la escribe la CI en data/version.json al generar el APK.
func _load_version() -> void:
	app_version = "versión de desarrollo"
	if not FileAccess.file_exists("res://data/version.json"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/version.json"))
	if typeof(data) == TYPE_DICTIONARY and str(data.get("version", "")) != "":
		app_version = "versión %s" % str(data["version"])
		if str(data.get("commit", "")) != "":
			app_version += " · %s" % str(data["commit"])


# ---------------------------------------------------------------- ajustes guardados

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var style := str(cfg.get_value("tablero", "acabado", board_style))
	if STYLES.has(style):
		board_style = style
	board_outline = bool(cfg.get_value("tablero", "contorno", board_style == "ilustrado"))
	var pieces := str(cfg.get_value("tablero", "piezas", piece_set))
	if SETS.has(pieces):
		piece_set = pieces
	dark = bool(cfg.get_value("pantalla", "oscuro", dark))
	sound_on = bool(cfg.get_value("sonido", "activo", sound_on))
	welcome_seen = bool(cfg.get_value("app", "bienvenida_vista", false))
	_saved_anim = clampi(int(cfg.get_value("tablero", "animaciones", _saved_anim)), 0, 3)


func _save_settings() -> void:
	if not use_settings:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("tablero", "acabado", board_style)
	cfg.set_value("tablero", "contorno", board_outline)
	cfg.set_value("tablero", "piezas", piece_set)
	cfg.set_value("tablero", "animaciones", int(view.board.anim_mode) if view != null else _saved_anim)
	cfg.set_value("pantalla", "oscuro", dark)
	cfg.set_value("sonido", "activo", sound_on)
	cfg.set_value("app", "bienvenida_vista", welcome_seen)
	cfg.save(SETTINGS_PATH)


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


## Párrafo: texto que salta de línea para caber en el ancho que tenga.
func _para(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 6)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## Botón de texto dentro de la tarjeta. Deja pasar el arrastre: si el dedo empieza encima, la tarjeta se desplaza igual.
func _card_button(text: String, on_press: Callable, fill: Color, fg: Color, font_size: int = 31) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(0.0, 84.0)
	b.pressed.connect(on_press)
	_style_button(b, fill, fg, 42, font_size, font_semibold)
	return b


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

	# Cielo sobre el tablero: mientras se resuelve, el tablero queda más cerca del pulgar; cuando llega la
	# explicación completa, este hueco se cierra y el tablero sube (ver _layout).
	top_gap = _spacer(0.0)
	chrome.add_child(top_gap)

	# Hueco del tablero: el tablero 3D se coloca encima de este hueco (ver _place_board).
	board_slot = Control.new()
	board_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_slot.item_rect_changed.connect(_place_board)
	chrome.add_child(board_slot)

	# Tarjeta del entrenador, bajo el tablero. Ocupa lo que necesita su contenido y, si no cabe, se desplaza.
	card_pad = _pad(28, 20, 28, 0)
	card_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_pad.resized.connect(_fit_card)
	chrome.add_child(card_pad)
	card = PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = _c("surface")
	card_style.set_corner_radius_all(48)
	card_style.content_margin_left = 40.0
	card_style.content_margin_right = 26.0
	card_style.content_margin_top = 30.0
	card_style.content_margin_bottom = 30.0
	card_style.shadow_color = _c("shadow")
	card_style.shadow_size = 30
	card_style.shadow_offset = Vector2(0.0, 12.0)
	card.add_theme_stylebox_override("panel", card_style)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_pad.add_child(card)
	card_scroll = ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card.add_child(card_scroll)
	var body_pad := _pad(0, 0, 14, 0)
	body_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(body_pad)
	card_body = VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 14)
	card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.minimum_size_changed.connect(_fit_card)
	body_pad.add_child(card_body)

	chrome.add_child(_spacer(26.0))

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

	_refresh(false)
	_place_board.call_deferred()
	if sheet_kind == "options":
		_build_sheet()
	elif sheet_kind == "ai":
		_build_ai_sheet()


## Hay una explicación completa a la vista: la tarjeta necesita sitio y el tablero sube.
func _explaining() -> bool:
	return (phase == Phase.SOLVED or phase == Phase.SHOWN) and not expl.is_empty()


## Reparte el alto: el hueco del tablero es tan alto como hace falta para que el tablero vaya de lado a lado
## (y no más); la tarjeta se queda con lo que sobra, salvo el trozo de cielo que va encima del tablero
## mientras se resuelve.
func _layout(animate: bool = false) -> void:
	if chrome == null or board_slot == null or top_gap == null:
		return
	var canvas := get_viewport_rect().size
	var fixed := 0.0
	for child in chrome.get_children():
		if child != board_slot and child != top_gap and child != card_pad and child is Control:
			fixed += (child as Control).get_combined_minimum_size().y
	_fixed_height = fixed
	var board_h := clampf(canvas.y - fixed - CARD_MIN, 320.0, maxf(canvas.x, 320.0))
	board_slot.custom_minimum_size = Vector2(0.0, board_h)
	var free := maxf(canvas.y - fixed - board_h, CARD_MIN)
	var gap := 0.0 if _explaining() else maxf(0.0, (free - CARD_ROOM) * 0.78)
	if _gap_tween != null and _gap_tween.is_valid():
		_gap_tween.kill()
	if animate and view.board.anim_mode != Board3D.Anim.NONE and absf(top_gap.custom_minimum_size.y - gap) > 2.0:
		_gap_tween = create_tween()
		_gap_tween.tween_property(top_gap, "custom_minimum_size:y", gap, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		top_gap.custom_minimum_size = Vector2(0.0, gap)
	_fit_card()


## La tarjeta mide lo que su contenido, hasta el sitio que hay; a partir de ahí, el contenido se desplaza.
func _fit_card() -> void:
	if card_scroll == null or not is_instance_valid(card_scroll) or card_pad == null:
		return
	# Sitio entre el tablero y los botones con el hueco de cielo que hay ahora mismo (puede estar cerrándose),
	# menos el margen de la tarjeta y su relleno.
	var room := get_viewport_rect().size.y - _fixed_height - board_slot.custom_minimum_size.y - top_gap.custom_minimum_size.y - 20.0 - 60.0
	var need := card_body.get_combined_minimum_size().y
	var want := clampf(need, 60.0, maxf(room, 60.0))
	if absf(card_scroll.custom_minimum_size.y - want) > 0.5:
		card_scroll.custom_minimum_size = Vector2(0.0, want)


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


# ---------------------------------------------------------------- tarjeta del entrenador

## Explicación que toca enseñar ahora ({} si ninguna) y a qué nivel.
func _shown_exp() -> Dictionary:
	if whatif:
		return whatif_exp
	if phase == Phase.WRONG or phase == Phase.SOLVED or phase == Phase.SHOWN:
		return expl
	return {}


func _shown_level() -> int:
	return whatif_level if whatif else exp_level


func _tone_color(e: Dictionary) -> Color:
	if bool(e.get("correct", false)):
		return _c("good")
	var verdict := str(e.get("verdict", ""))
	return _c("accent_text") if verdict == "alsoWins" or verdict == "slower" else _c("bad")


## Pone los textos y los botones que corresponden a la fase del problema.
func _refresh(animate: bool = true) -> void:
	if card_body == null or not is_instance_valid(card_body):
		return
	var total := puzzles.size()
	counter.text = ("Problema %d de %d" % [index + 1, total]) if total > 0 else "Sin problemas"
	_build_card()

	var done := phase == Phase.SOLVED or phase == Phase.SHOWN
	left_button.text = "Repetir" if done else "Ver solución"
	right_button.text = "Siguiente" if done else "Saltar"
	_style_button(left_button, _c("accent_soft"), _c("accent_text"), 62, 36, font_semibold)
	if done:
		# El naranja pleno solo aparece cuando toca avanzar.
		_style_button(right_button, _c("accent"), _c("accent_ink"), 62, 36, font_semibold, Color(1.0, 0.48, 0.1, 0.34))
	else:
		_style_button(right_button, _c("surface"), _c("ink"), 62, 36, font_semibold, _c("shadow"))
	_layout(animate)


func _build_card() -> void:
	var scroll_to := card_scroll.scroll_vertical if _keep_scroll else 0
	_keep_scroll = false
	for old in card_body.get_children():
		card_body.remove_child(old)
		old.queue_free()
	var total := puzzles.size()
	var theme_name := str(puzzle.get("theme", ""))
	var rating := int(puzzle.get("rating", 0))
	var e := _shown_exp()
	var done := phase == Phase.SOLVED or phase == Phase.SHOWN

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
	if whatif:
		head = "¿Y si juego…?"
		tone = _c("ink")
		show_dot = false
	if not e.is_empty():
		head = str(e.get("headline", head))
		tone = _c("ink") if bool(e.get("asked", false)) else _tone_color(e)
		if whatif:
			head = "Es la mejor jugada" if bool(e.get("correct", false)) else head
	if total == 0:
		head = "Sin problemas"
		sub = "No se ha encontrado data/demo_puzzles.json."

	# Titular, con el peón del bando que juega mientras se resuelve.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_body.add_child(title_row)
	turn_dot = TurnMark.new()
	turn_dot.custom_minimum_size = Vector2(46.0, 50.0)
	turn_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	turn_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var white_to_move := view.board.chess.turn == 0
	var swatches: Array = view.board.piece_swatches()
	var mark_fill: Color = swatches[0] if white_to_move else swatches[1]
	turn_dot.fill = mark_fill
	if white_to_move:
		turn_dot.line = mark_fill.darkened(0.72)
	else:
		turn_dot.line = mark_fill.lightened(0.6) if dark else mark_fill.darkened(0.6)
	turn_dot.visible = show_dot
	title_row.add_child(turn_dot)
	title = _para(head, 50 if not e.is_empty() or whatif else 58, tone, font_display)
	title.add_theme_constant_override("line_spacing", 0)
	title_row.add_child(title)

	if whatif:
		_add_whatif(e)
	elif not e.is_empty():
		_add_explanation(e, exp_level, exp_partial)
		if done:
			_add_tools()
	else:
		card_body.add_child(_para(sub, 33, _c("quiet"), font_regular))

	# Ficha del problema. El tema es una pista: solo se enseña cuando ya está resuelto o mostrado.
	if total > 0 and not whatif:
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 12)
		chips.add_theme_constant_override("v_separation", 10)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if done and theme_name != "":
			chips.add_child(_chip(theme_name, _c("accent_soft"), _c("accent_text")))
		chips.add_child(_chip("Dificultad %d" % rating, _c("field"), _c("ink")))
		chips.add_child(_chip("Problema real de Lichess", _c("field"), _c("quiet")))
		var chips_pad := _pad(0, 8, 0, 0)
		chips_pad.add_child(chips)
		card_body.add_child(chips_pad)

	_fit_card.call_deferred()
	card_scroll.set_deferred("scroll_vertical", scroll_to)


func _section(text: String) -> MarginContainer:
	var m := _pad(0, 12, 0, 0)
	m.add_child(_text(text.to_upper(), 24, _c("quiet"), font_semibold))
	return m


## Los bloques de una explicación hasta el nivel abierto. Con partial = true solo se cuenta qué hace la jugada
## y qué permite (el jugador todavía puede reintentar): ni la mejor jugada ni los niveles siguientes.
func _add_explanation(e: Dictionary, level: int, partial: bool) -> void:
	var levels: Array = e.get("levels", [])
	if levels.size() < 4:
		return
	var first: Array = (levels[0] as Dictionary)["paragraphs"]
	var count := first.size()
	if partial and not bool(e.get("correct", false)) and count > 1:
		# La última frase dice cuál era la mejor jugada.
		count -= 1
	for i in count:
		card_body.add_child(_para(str(first[i]), 33, _c("ink"), font_regular))
	var lines: Array = (levels[2] as Dictionary)["lines"]
	if partial:
		# Lo que pasaría tras la jugada, para verlo en el tablero.
		for line: Dictionary in lines:
			if str(line.get("tone", "")) == "bad":
				card_body.add_child(_line_block(line, "Qué pasaría"))
		card_body.add_child(_para("Prueba otra jugada o mira la solución.", 29, _c("quiet"), font_regular))
		return
	if level >= 2:
		var concept: Dictionary = levels[1]
		card_body.add_child(_section(str(concept["title"])))
		for text: Variant in concept["paragraphs"]:
			card_body.add_child(_para(str(text), 31, _c("ink"), font_regular))
	if level >= 3:
		card_body.add_child(_section(str((levels[2] as Dictionary)["title"])))
		for line: Dictionary in lines:
			card_body.add_child(_line_block(line, str(line.get("label", ""))))
	if level >= 4:
		var engine: Dictionary = levels[3]
		card_body.add_child(_section(str(engine["title"])))
		for row: PackedStringArray in engine["rows"]:
			if row.size() >= 5:
				card_body.add_child(_engine_row(row))
		for text: Variant in engine["paragraphs"]:
			card_body.add_child(_para(str(text), 26, _c("quiet"), font_regular))
	if level < 4:
		var why := _card_button(str(WHY_LABELS[level]), _on_why, _c("accent_soft"), _c("accent_text"), 33)
		var why_pad := _pad(0, 8, 0, 0)
		why_pad.add_child(why)
		card_body.add_child(why_pad)
	if level >= 2:
		var facts: Array = e.get("facts", [])
		var toggle := _card_button("¿De dónde sale cada dato?" if not facts_open else "Ocultar de dónde sale cada dato", _on_toggle_facts, _c("field"), _c("quiet"), 28)
		toggle.custom_minimum_size = Vector2(0.0, 72.0)
		card_body.add_child(toggle)
		if facts_open:
			for fact: Array in facts:
				var source := str(SOURCE_NAMES.get(str(fact[0]), str(fact[0])))
				card_body.add_child(_para("%s · %s" % [source, str(fact[1])], 26, _c("quiet"), font_regular))


## Una variante con sus botones para verla jugada a jugada en el tablero.
func _line_block(line: Dictionary, label: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var good := str(line.get("tone", "")) == "good"
	box.add_child(_para(label, 29, _c("good") if good else _c("bad"), font_semibold))
	box.add_child(_para(str(line.get("text", "")), 30, _c("ink"), font_medium))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var active := not line_on.is_empty() and line_on == line
	var ucis: Array = line.get("ucis", [])
	var steps := [["first", -1], ["prev", maxi(-1, line_ply - 1) if active else -1], ["next", mini(ucis.size() - 1, line_ply + 1) if active else 0]]
	for step_def: Array in steps:
		var b := IconButton.new()
		b.kind = str(step_def[0])
		b.ink = _c("ink")
		b.paper = _c("field")
		b.custom_minimum_size = Vector2(84.0, 76.0)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(_step_line.bind(line, int(step_def[1])))
		_style_button(b, _c("field"), _c("ink"), 38, 30, null)
		row.add_child(b)
	if active:
		var where := "inicio" if line_ply < 0 else "%d de %d" % [line_ply + 1, ucis.size()]
		var mark := _text(where, 27, _c("quiet"), font_medium)
		mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(mark)
		var back := _card_button("Volver", _leave_line, _c("accent_soft"), _c("accent_text"), 28)
		back.custom_minimum_size = Vector2(0.0, 76.0)
		row.add_child(back)
	box.add_child(row)
	return box


## Fila de la tabla del motor: etiqueta, jugada, evaluación y profundidad; debajo, la continuación.
func _engine_row(row: PackedStringArray) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_para("%s · %s · %s · prof. %s" % [row[0], row[1], row[2], row[3]], 29, _c("ink"), font_medium))
	box.add_child(_para(row[4], 26, _c("quiet"), font_regular))
	return box


## Ayudas de después del problema: probar otra jugada, analizar en Lichess y preguntar a una IA.
func _add_tools() -> void:
	if explain == null or not explain.ok:
		return
	card_body.add_child(_section("Más ayuda"))
	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 12)
	tools.add_theme_constant_override("v_separation", 12)
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_child(_card_button("¿Y si juego…?", _toggle_whatif, _c("field"), _c("ink"), 29))
	tools.add_child(_card_button("Analizar en Lichess", _open_lichess, _c("field"), _c("ink"), 29))
	tools.add_child(_card_button("Pregunta a una IA", _open_ai, _c("field"), _c("ink"), 29))
	card_body.add_child(tools)


func _add_whatif(e: Dictionary) -> void:
	if e.is_empty():
		var fen := _decision_fen()
		var side := "blancas" if fen != "" and Chess.from_fen(fen).turn == 0 else "negras"
		card_body.add_child(_para("Mueve cualquier pieza de las %s y te explico qué pasaría con esa jugada." % side, 33, _c("ink"), font_regular))
		card_body.add_child(_para("Las explicaciones salen del mismo análisis verificado del motor.", 28, _c("quiet"), font_regular))
	else:
		card_body.add_child(_para("Probando %s" % str(e.get("san", "")), 28, _c("quiet"), font_semibold))
		_add_explanation(e, whatif_level, false)
		card_body.add_child(_para("Prueba otra jugada en el tablero o vuelve a la explicación.", 28, _c("quiet"), font_regular))
	var back := _card_button("Volver a la explicación", _toggle_whatif, _c("accent_soft"), _c("accent_text"), 31)
	card_body.add_child(back)
	if not e.is_empty():
		var tools := HFlowContainer.new()
		tools.add_theme_constant_override("h_separation", 12)
		tools.add_theme_constant_override("v_separation", 12)
		tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tools.add_child(_card_button("Analizar en Lichess", _open_lichess, _c("field"), _c("ink"), 29))
		tools.add_child(_card_button("Pregunta a una IA", _open_ai, _c("field"), _c("ink"), 29))
		card_body.add_child(tools)


func _set_phase(p: Phase) -> void:
	phase = p
	_refresh()


# ---------------------------------------------------------------- explicación en el tablero

## Flechas que acompañan a una explicación: las del nivel más profundo abierto que tenga alguna (solo de los
## dos primeros niveles; los demás enseñan variantes). Mientras se puede reintentar, nunca la de la solución.
func _arrows_for(e: Dictionary, level: int, partial: bool) -> Array:
	var levels: Array = e.get("levels", [])
	var out: Array = []
	for i in mini(mini(level, 2), levels.size()):
		var arrows: Array = (levels[i] as Dictionary)["arrows"]
		if not arrows.is_empty():
			out = arrows
	var seen := {}
	var unique: Array = []
	for a: Dictionary in out:
		var key := int(a["from"]) * 64 + int(a["to"])
		if seen.has(key) or (partial and str(a["tone"]) == "good"):
			continue
		seen[key] = true
		unique.append(a)
	return unique


## Enseña la posición en la que había que decidir, con la jugada del rival resaltada y unas flechas.
func _show_decision(arrows: Array) -> void:
	var fen := explain.point_fen(exp_point) if explain != null and explain.ok else fen_before
	if fen == "":
		return
	view.set_fen(fen)
	var moves: Array = puzzle.get("moves", [])
	if 2 * exp_point < moves.size():
		var rival := str(moves[2 * exp_point])
		view.board.mark_last_move(Chess.sq_index(rival.substr(0, 2)), Chess.sq_index(rival.substr(2, 2)))
	view.board.set_arrows(arrows)
	view.interactive = whatif or phase == Phase.WRONG


## Deja el tablero como corresponde a lo que se está explicando. En el primer nivel no se toca: sigue a la
## vista la posición final (el mate, la pieza ganada). Desde el segundo, se vuelve a la posición de la decisión.
func _sync_board_to_explanation() -> void:
	if not line_on.is_empty():
		return
	var e := _shown_exp()
	if whatif:
		_show_decision(_arrows_for(e, whatif_level, false) if not e.is_empty() else [])
	elif phase == Phase.WRONG:
		_show_decision(_arrows_for(e, 1, true))
	elif not e.is_empty() and exp_level >= 2:
		_show_decision(_arrows_for(e, exp_level, false))


## Botón «Explícame por qué» / «Ver la variante» / «Ver el análisis»: un nivel más de profundidad.
func _on_why() -> void:
	if whatif:
		whatif_level = mini(whatif_level + 1, 4)
	else:
		exp_level = mini(exp_level + 1, 4)
	_keep_scroll = true
	_refresh()
	_sync_board_to_explanation()


func _on_toggle_facts() -> void:
	facts_open = not facts_open
	_keep_scroll = true
	_refresh()


## Enseña una variante en el tablero: ply = −1 la posición de partida; n, la jugada n (se ve moverse).
func _step_line(line: Dictionary, ply: int) -> void:
	var ucis: Array = line.get("ucis", [])
	if ucis.is_empty():
		return
	run_id += 1
	line_on = line
	line_ply = clampi(ply, -1, ucis.size() - 1)
	view.interactive = false
	view.board.set_arrows([])
	if line_ply < 0:
		view.set_fen(str(line.get("fen", "")))
	else:
		var before := ExplainData.line_fen(line, line_ply)
		if before == "":
			return
		view.set_fen(before)
		view.show_move(str(ucis[line_ply]))
	_keep_scroll = true
	_refresh()


## Deja de ver la variante y vuelve a la posición de la decisión.
func _leave_line() -> void:
	line_on = {}
	line_ply = -1
	_keep_scroll = true
	_refresh()
	var e := _shown_exp()
	if whatif:
		_show_decision(_arrows_for(e, whatif_level, false) if not e.is_empty() else [])
	elif phase == Phase.WRONG:
		_show_decision(_arrows_for(e, 1, true))
	else:
		_show_decision(_arrows_for(e, maxi(exp_level, 1), false))


## «¿Y si juego…?»: entra o sale del modo de probar jugadas.
func _toggle_whatif() -> void:
	if explain == null or not explain.ok:
		return
	run_id += 1
	whatif = not whatif
	whatif_exp = {}
	whatif_level = 1
	line_on = {}
	line_ply = -1
	facts_open = false
	if whatif:
		_show_decision([])
	else:
		_show_decision(_arrows_for(expl, maxi(exp_level, 1), false))
	_refresh()


## Posición sobre la que se pregunta: la de la decisión que se está explicando.
func _decision_fen() -> String:
	if explain != null and explain.ok:
		return explain.point_fen(exp_point)
	return fen_before


## Tablero de análisis de Lichess con la posición cargada (lichess.org/analysis/<FEN con %20 por espacio>).
func _lichess_url(fen: String) -> String:
	return "https://lichess.org/analysis/" + "%20".join(fen.strip_edges().split(" ", false))


func _open_lichess() -> void:
	var fen := _decision_fen()
	if fen != "":
		OS.shell_open(_lichess_url(fen))


## Texto que se lleva a una IA general: la posición exacta y el análisis del motor, no una captura. Las IA
## generales leen mal los tableros en imagen y se equivocan al calcular: así parten de datos ciertos.
func _ai_text() -> String:
	var e := _shown_exp()
	if e.is_empty():
		e = expl
	var fen := _decision_fen()
	if e.is_empty() or fen == "":
		return ""
	var side := "las blancas" if Chess.from_fen(fen).turn == 0 else "las negras"
	var played := str(e.get("san", ""))
	var best := str(e.get("best", ""))
	var correct := bool(e.get("correct", false))
	var out := PackedStringArray([
		"Estoy aprendiendo ajedrez y tengo una duda sobre esta posición de un problema real de Lichess.",
		"",
		"Posición (FEN): %s" % fen,
		"Juegan %s." % side,
	])
	var question := ""
	if whatif:
		out.append("Estoy probando %s%s" % [played, ", que es la mejor jugada." if correct else "; la mejor es %s." % best])
	elif bool(e.get("asked", false)):
		out.append("La mejor jugada es %s." % best)
	elif correct:
		out.append("He jugado %s, que es la mejor jugada." % played)
	else:
		out.append("He jugado %s, pero la mejor era %s." % [played, best])
	if correct or bool(e.get("asked", false)):
		question = "¿Por qué %s es la mejor jugada en esta posición? Explícamelo de forma sencilla." % best
	else:
		question = "¿Por qué %s no funciona y %s sí? Explícamelo de forma sencilla." % [played, best]
	var levels: Array = e.get("levels", [])
	if levels.size() >= 4:
		for line: Dictionary in (levels[2] as Dictionary)["lines"]:
			if str(line.get("tone", "")) == "good":
				out.append("Solución: %s" % str(line.get("text", "")))
				break
		var rows: Array = (levels[3] as Dictionary)["rows"]
		if not rows.is_empty():
			out.append("")
			out.append("Análisis de %s (positivo = ventaja para quien mueve):" % explain.engine)
			for row: PackedStringArray in rows:
				if row.size() >= 5:
					out.append("- %s: %s, profundidad %s. Sigue: %s" % [row[1], row[2], row[3], row[4]])
	out.append("")
	out.append("Tablero: %s" % _lichess_url(fen))
	out.append("")
	out.append("Mi pregunta: %s" % question)
	out.append("")
	out.append("Usa solo jugadas legales en esta posición, apóyate en el análisis del motor y, si no estás seguro de algo, dilo.")
	return "\n".join(out)


func _open_ai() -> void:
	sheet_kind = "ai"
	options_open = false
	_build_ai_sheet()
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.14)


func _copy_ai_text() -> void:
	DisplayServer.clipboard_set(_ai_text())
	if _ai_status != null and is_instance_valid(_ai_status):
		_ai_status.text = "Copiado. Pégalo en la IA que prefieras."


## Abre la búsqueda de Google en Modo IA con la pregunta. El parámetro udm=50 no está documentado por Google
## (lo han observado terceros): si deja de funcionar, la búsqueda se abre en modo normal.
func _open_google_ai() -> void:
	OS.shell_open("https://www.google.com/search?udm=50&q=" + _ai_text().uri_encode())


func _build_ai_sheet() -> void:
	var box := _sheet("Pregunta a una IA")
	if box == null:
		return
	box.add_child(_para("Las IA generales se equivocan a menudo en ajedrez, sobre todo al calcular jugadas. Comprueba en el tablero cualquier jugada que te propongan.", 30, _c("ink"), font_regular))
	box.add_child(_para("Les mandamos la posición exacta y el análisis del motor, no una captura, para que partan de datos ciertos.", 28, _c("quiet"), font_regular))
	var copy := _card_button("Copiar el texto", _copy_ai_text, _c("accent"), _c("accent_ink"), 34)
	copy.custom_minimum_size = Vector2(0.0, 104.0)
	box.add_child(copy)
	var google := _card_button("Abrir en Google (Modo IA)", _open_google_ai, _c("field"), _c("ink"), 32)
	google.custom_minimum_size = Vector2(0.0, 96.0)
	box.add_child(google)
	_ai_status = _para("", 28, _c("good"), font_medium)
	box.add_child(_ai_status)
	box.add_child(_caption("Texto que se envía"))
	var preview := _para(_ai_text(), 24, _c("quiet"), font_regular)
	box.add_child(preview)


# ---------------------------------------------------------------- hojas inferiores (opciones y ayuda)

func _open_options() -> void:
	options_open = true
	sheet_kind = "options"
	_build_sheet()
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.14)


## Cierra la hoja que haya abierta (opciones o ayuda).
func _close_options() -> void:
	options_open = false
	sheet_kind = ""
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.queue_free()
	overlay = null


func _sync_sheet() -> void:
	if sheet_kind == "options":
		_build_sheet.call_deferred()


func _on_scrim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		_close_options()


## Arma una hoja inferior vacía, con su título y su botón de cerrar, y devuelve la caja donde va el contenido.
## Si el contenido no cabe en la pantalla, se desplaza.
func _sheet(heading_text: String) -> VBoxContainer:
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.queue_free()
	if sheet_kind == "":
		overlay = null
		return null
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
	sb.content_margin_right = 30.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 44.0 + _insets().y
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	sb.shadow_size = 40
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay.add_child(sheet)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 14)
	sheet.add_child(frame)
	var grab_row := CenterContainer.new()
	var grab := Panel.new()
	grab.custom_minimum_size = Vector2(92.0, 9.0)
	var grab_style := StyleBoxFlat.new()
	grab_style.bg_color = _c("track")
	grab_style.set_corner_radius_all(5)
	grab.add_theme_stylebox_override("panel", grab_style)
	grab_row.add_child(grab)
	frame.add_child(grab_row)

	var header_pad := _pad(0, 0, 14, 0)
	var header := HBoxContainer.new()
	var heading := _text(heading_text, 48, _c("ink"), font_display)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	var close := _icon_button("close", _close_options)
	_style_button(close, _c("field"), _c("ink"), 48, 30, null)
	close.paper = _c("field")
	header.add_child(close)
	header_pad.add_child(header)
	frame.add_child(header_pad)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var box_pad := _pad(0, 0, 14, 0)
	box_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box_pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_pad.add_child(box)
	# La hoja mide lo que su contenido, hasta dejar a la vista un poco de la pantalla de detrás.
	var fit := _fit_sheet.bind(scroll, box)
	box.minimum_size_changed.connect(fit)
	fit.call_deferred()
	return box


func _fit_sheet(scroll: ScrollContainer, box: VBoxContainer) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(box):
		return
	var room := get_viewport_rect().size.y - 330.0 - _insets().x - _insets().y
	var want := clampf(box.get_combined_minimum_size().y, 80.0, maxf(room, 240.0))
	if absf(scroll.custom_minimum_size.y - want) > 0.5:
		scroll.custom_minimum_size = Vector2(0.0, want)


func _build_sheet() -> void:
	var box := _sheet("Opciones")
	if box == null:
		return
	box.add_child(_caption("Piezas"))
	box.add_child(_segments(SET_NAMES, SETS.find(piece_set), _set_pieces_index))
	box.add_child(_caption("Material"))
	box.add_child(_segments(STYLE_NAMES, STYLES.find(board_style), _set_style_index))
	box.add_child(_switch_row("Contorno de las piezas", "Una línea de tinta alrededor de cada pieza.", board_outline, _set_outline))
	box.add_child(_switch_row("Sonido", "Arrastre y golpe de las piezas, jaque y caída del rey.", sound_on, _set_sound))
	box.add_child(_caption("Animaciones"))
	box.add_child(_segments(["Completas", "Rápidas", "Mínimas", "Sin"], int(view.board.anim_mode), _set_anim))
	box.add_child(_caption("Vista"))
	box.add_child(_segments(["Inclinada", "En picado"], 1 if top_view else 0, _set_top_view))
	box.add_child(_switch_row("Seguir al móvil", "La vista acompaña la inclinación y el giro del teléfono.", view.tilt_enabled, _set_tilt))
	box.add_child(_switch_row("Fijar la vista", "Ni el móvil ni los dedos la mueven.", view.view_locked, _set_lock))
	box.add_child(_para("Pellizca el tablero con dos dedos para ampliarlo; el botón de vista lo deja entero. Con dos dedos también giras la vista o mueves el tablero ampliado.", 26, _c("quiet"), font_regular))
	box.add_child(_caption("Tema"))
	box.add_child(_segments(["Claro", "Oscuro"], 1 if dark else 0, _set_theme_index))
	var how := _card_button("Cómo funciona Chessome", _open_welcome, _c("field"), _c("ink"), 31)
	how.custom_minimum_size = Vector2(0.0, 92.0)
	var how_pad := _pad(0, 16, 0, 0)
	how_pad.add_child(how)
	box.add_child(how_pad)
	var about := _para("Chessome · %s" % app_version, 24, _c("quiet"), font_regular)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(about)


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
		b.mouse_filter = Control.MOUSE_FILTER_PASS
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
	sw.mouse_filter = Control.MOUSE_FILTER_PASS
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		sw.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	sw.pressed.connect(on_change.bind(not value))
	row.add_child(sw)
	return row


func _set_pieces_index(i: int) -> void:
	piece_set = SETS[clampi(i, 0, SETS.size() - 1)]
	view.set_piece_set(piece_set)
	_save_settings()
	_sync_sheet()


func _set_style_index(i: int) -> void:
	board_style = STYLES[clampi(i, 0, STYLES.size() - 1)]
	# Cada acabado tiene su contorno por defecto: el ilustrado lo lleva; los realistas, no.
	board_outline = board_style == "ilustrado"
	view.set_board_style(board_style, board_outline)
	_save_settings()
	_keep_scroll = true
	_refresh(false)
	_sync_sheet()


func _set_outline(on: bool) -> void:
	board_outline = on
	view.board.set_outline(on)
	_save_settings()
	_sync_sheet()


func _set_sound(on: bool) -> void:
	sound_on = on
	view.set_sound_enabled(on)
	_save_settings()
	_sync_sheet()


func _set_anim(mode: int) -> void:
	view.board.anim_mode = mode as Board3D.Anim
	_saved_anim = mode
	_save_settings()
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
	_save_settings()
	_keep_scroll = true
	_build_chrome.call_deferred()


# ---------------------------------------------------------------- bienvenida

## Pantalla de bienvenida: qué es Chessome y cómo se usa. Sale la primera vez y desde Opciones.
func _open_welcome() -> void:
	if sheet_kind != "":
		_close_options()
	if welcome != null and is_instance_valid(welcome):
		welcome.queue_free()
	welcome = Control.new()
	welcome.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(welcome)
	var back := ColorRect.new()
	back.color = _c("bg")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome.add_child(back)
	var inset := _insets()
	var pad := _pad(56, int(maxf(inset.x, 60.0)) + 60, 56, int(inset.y) + 44)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	pad.add_child(box)
	box.add_child(_text("Chessome", 40, _c("accent_text"), font_display))
	var claim := _para("Entiende cada error, no solo la solución.", 76, _c("ink"), font_display)
	claim.add_theme_constant_override("line_spacing", -4)
	box.add_child(claim)
	box.add_child(_para("Problemas reales de ajedrez con una explicación de verdad: cada frase sale del análisis de un motor o de las reglas del juego.", 33, _c("quiet"), font_regular))
	box.add_child(_spacer(10.0))
	box.add_child(_welcome_row("1", "Juega", "Toca una pieza y su destino, o arrástrala. Primero mueve el rival; después te toca a ti."))
	box.add_child(_welcome_row("2", "Si fallas, te lo explico", "Qué tenía de bueno tu jugada y qué permite. Puedes ver en el tablero lo que pasaría y volver a intentarlo."))
	box.add_child(_welcome_row("3", "Pregunta «por qué»", "Al resolverlo o ver la solución: el concepto, la variante jugada a jugada y las cifras del motor. Y prueba «¿Y si juego…?» con cualquier otra jugada."))
	box.add_child(_welcome_row("4", "A tu gusto", "Pellizca el tablero para ampliarlo. En Opciones eliges figuras o fichas, el material, el sonido y las animaciones."))
	box.add_child(_spacer(0.0, true))
	box.add_child(_para("Todavía no hay curso de reglas: hace falta saber cómo se mueven las piezas.", 27, _c("quiet"), font_regular))
	var go := Button.new()
	go.text = "Empezar"
	go.custom_minimum_size = Vector2(0.0, 128.0)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_close_welcome)
	_style_button(go, _c("accent"), _c("accent_ink"), 64, 38, font_semibold, Color(1.0, 0.48, 0.1, 0.34))
	box.add_child(go)


func _welcome_row(number: String, heading: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _c("accent_soft")
	sb.set_corner_radius_all(40)
	badge.add_theme_stylebox_override("panel", sb)
	badge.custom_minimum_size = Vector2(80.0, 80.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var num := _text(number, 36, _c("accent_text"), font_display)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(num)
	row.add_child(badge)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_para(heading, 38, _c("ink"), font_semibold))
	texts.add_child(_para(text, 30, _c("quiet"), font_regular))
	row.add_child(texts)
	return row


func _close_welcome() -> void:
	if welcome != null and is_instance_valid(welcome):
		welcome.visible = false
		welcome.queue_free()
	welcome = null
	if not welcome_seen:
		welcome_seen = true
		_save_settings()


# ---------------------------------------------------------------- problema

func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


## Punto de decisión en el que está el jugador (0 = su primera jugada).
func _point() -> int:
	return maxi(ask_step - 1, 0) >> 1


func _explanation_for(k: int, uci: String) -> Dictionary:
	if explain == null or not explain.ok:
		return {}
	return explain.for_move(k, uci)


## Vuelve a la posición en la que se pidió la jugada, con la del rival resaltada.
func _restore_position() -> void:
	view.set_fen(fen_before)
	var moves: Array = puzzle.get("moves", [])
	if ask_step >= 1 and ask_step - 1 < moves.size():
		var rival := str(moves[ask_step - 1])
		view.board.mark_last_move(Chess.sq_index(rival.substr(0, 2)), Chess.sq_index(rival.substr(2, 2)))


func _clear_explanation() -> void:
	expl = {}
	exp_level = 1
	exp_point = 0
	exp_partial = false
	whatif = false
	whatif_exp = {}
	whatif_level = 1
	facts_open = false
	line_on = {}
	line_ply = -1


func _start(i: int) -> void:
	run_id += 1
	var my_run := run_id
	if puzzles.is_empty():
		_refresh()
		return
	index = posmod(i, puzzles.size())
	puzzle = puzzles[index]
	explain = ExplainData.load_for(str(puzzle.get("id", "")))
	_clear_explanation()
	last_wrong = {}
	step = 0
	ask_step = 0
	view.sounds.stop_all()
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
	view.board.set_arrows([])
	if whatif:
		# «¿Y si juego…?»: se explica la jugada probada y el tablero vuelve a la posición de la decisión.
		view.interactive = false
		whatif_exp = _explanation_for(exp_point, uci)
		whatif_level = 1
		facts_open = false
		_refresh()
		await _wait(0.9)
		if my_run != run_id or not whatif:
			return
		_show_decision(_arrows_for(whatif_exp, 1, false))
		return
	var moves: Array = puzzle["moves"]
	if step >= moves.size():
		return
	var mate := view.board.chess.is_checkmate()
	if uci != str(moves[step]) and not mate:
		# Fallo: se cuenta qué hace la jugada y qué permite, y se deja reintentar.
		view.interactive = false
		var k := _point()
		last_wrong = {"point": k, "uci": uci}
		_clear_explanation()
		expl = _explanation_for(k, uci)
		exp_point = k
		exp_partial = true
		_set_phase(Phase.WRONG)
		await _wait(0.9)
		if my_run != run_id:
			return
		_restore_position()
		view.board.set_arrows(_arrows_for(expl, 1, true))
		view.interactive = true
		return
	step += 1
	_clear_explanation()
	if mate or step >= moves.size():
		view.interactive = false
		if explain != null and explain.ok:
			expl = explain.solved()
		_set_phase(Phase.SOLVED)
		return
	last_wrong = {}
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
	var k := _point()
	view.interactive = false
	_clear_explanation()
	view.board.set_arrows([])
	_restore_position()
	step = ask_step
	_set_phase(Phase.SHOWING)
	while step < moves.size():
		await _wait(0.75)
		if my_run != run_id:
			return
		view.show_move(str(moves[step]))
		step += 1
	# La explicación: si el jugador había fallado aquí, la de su jugada (qué permitía y cuál era la mejor);
	# si pidió la solución sin probar, la de la solución.
	if explain != null and explain.ok:
		if int(last_wrong.get("point", -1)) == k:
			expl = explain.for_move(k, str(last_wrong.get("uci", "")))
		else:
			expl = explain.solved() if k == 0 else explain.for_move(k, explain.point_solution(k))
			if not expl.is_empty():
				expl["headline"] = "La solución"
				expl["asked"] = true
		exp_point = k
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
