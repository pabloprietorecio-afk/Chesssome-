class_name HomeScreens
extends RefCounted
## Las dos pantallas de inicio entre las que elige el jugador (Opciones → «Pantalla de inicio»):
##   · «lista»: la portada con el rey, la tarjeta del nivel y una fila por cada cosa que se puede hacer.
##   · «rejilla»: cabecera con racha y nivel de juego, portada con el nivel, seis tarjetas, el reto de la
##     semana y una barra de secciones al pie.
## Las dos caben sin desplazamiento en un móvil alto (1080 × 2400 unidades); en pantallas más bajas las filas
## y las tarjetas encogen y, si aun así no caben, se desplazan. El nivel Kids conserva su inicio de siempre.
##
## Se dibujan con los colores, las letras y los iconos de la app (se le piden a la pantalla principal, `d`),
## así que siguen el tema claro u oscuro y el idioma. Las medidas salen del diseño (390 puntos de ancho):
## u(puntos) las pasa a unidades del lienzo. Las ilustraciones están en godot/ui/inicio (ver su LEEME).

const STYLES: Array[String] = ["lista", "rejilla"]
const NAMES: Array[String] = ["Lista", "Rejilla"]
const ART := "res://ui/inicio/"
## Letra manuscrita de las notas (Caveat, OFL): latín, latín ampliado y cirílico.
const NOTE_FONT := "res://fonts/Caveat-Bold.woff2"
const NOTE_FONT_MORE: Array[String] = ["res://fonts/Caveat-Bold-ext.woff2", "res://fonts/Caveat-Bold-cyrillic.woff2"]
## Unidades del lienzo (1080 de ancho) por punto del diseño (390 de ancho).
const U := 1080.0 / 390.0
## Idiomas que la letra manuscrita no sabe escribir: sus notas van con la letra normal.
const NO_SCRIPT: Array[String] = ["ja", "hi"]

static var _tex := {}
static var _note_font: Font
static var _note_tried := false


static func u(points: float) -> float:
	return roundf(points * U)


## Ilustración de godot/ui/inicio (un PNG con otra extensión, como los iconos: Godot no lo importa ni lo comprime).
static func art(file: String) -> Texture2D:
	if _tex.has(file):
		return _tex[file]
	var bytes := FileAccess.get_file_as_bytes(ART + file + ".bin")
	var img := Image.new()
	var tex: Texture2D = null
	if not bytes.is_empty() and img.load_png_from_buffer(bytes) == OK:
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	else:
		push_error("No se puede cargar " + ART + file + ".bin")
	_tex[file] = tex
	return tex


static func note_font(d: Variant) -> Font:
	if Loc.language in NO_SCRIPT:
		return d.font_medium
	if not _note_tried:
		_note_tried = true
		if ResourceLoader.exists(NOTE_FONT):
			_note_font = load(NOTE_FONT) as Font
			var more: Array[Font] = []
			for path: String in NOTE_FONT_MORE:
				if ResourceLoader.exists(path):
					more.append(load(path) as Font)
			# Lo que no sepa escribir ninguna de las tres (un signo raro), con la letra normal.
			if d.font_medium != null:
				more.append(d.font_medium)
			_note_font.fallbacks = more
	return _note_font if _note_font != null else d.font_medium


## Degradado vertical de varios colores: [[posición 0–1, color], …].
class Wash extends Control:
	var stops: Array = []

	func _draw() -> void:
		for i in range(stops.size() - 1):
			var y0 := float(stops[i][0]) * size.y
			var y1 := float(stops[i + 1][0]) * size.y
			var c0: Color = stops[i][1]
			var c1: Color = stops[i + 1][1]
			draw_polygon(
				PackedVector2Array([Vector2(0.0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0.0, y1)]),
				PackedColorArray([c0, c0, c1, c1]))


## Trazo de rotulador bajo una nota manuscrita.
class Swoosh extends Control:
	var color := Color.BLACK

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 17:
			var t := float(i) / 16.0
			pts.append(Vector2(t * size.x, size.y * (0.85 - 0.62 * t - 0.2 * sin(t * PI))))
		draw_polyline(pts, color, maxf(3.0, size.y * 0.22), true)


# ---------------------------------------------------------------- piezas comunes

static func _box(bg: Color, radius: float, border := Color(0, 0, 0, 0), border_w := 0, shadow := Color(0, 0, 0, 0), shadow_size := 0, shadow_y := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 12
	if border.a > 0.0 and border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow.a > 0.0 and shadow_size > 0:
		sb.shadow_color = shadow
		sb.shadow_size = shadow_size
		sb.shadow_offset = Vector2(0.0, shadow_y)
	return sb


## Botón que es una tarjeta: su fondo y, al pulsarlo, el mismo algo más oscuro. Deja pasar el arrastre.
static func _card(sb: StyleBoxFlat, on_press: Callable, label: String, height: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	for state: String in ["normal", "hover", "focus", "disabled", "pressed", "hover_pressed"]:
		var s := sb.duplicate() as StyleBoxFlat
		if state.ends_with("pressed"):
			s.bg_color = sb.bg_color.darkened(0.06)
			s.shadow_size = int(sb.shadow_size * 0.5)
		b.add_theme_stylebox_override(state, s)
	if height > 0.0:
		b.custom_minimum_size = Vector2(0.0, height)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	b.set_meta("label", label)
	return b


static func _fill(c: Control, left := 0.0, top := 0.0, right := 0.0, bottom := 0.0) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = left
	c.offset_top = top
	c.offset_right = -right
	c.offset_bottom = -bottom
	return c


static func _quiet(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _panel(sb: StyleBox, min_size := Vector2.ZERO) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Texto de una línea que cabe en max_w: si no cabe, baja la letra (hasta un 80 %) y, si ni así, se recorta con «…».
## Con tight, la etiqueta mide justo lo que su texto (para ponerle algo pegado detrás).
static func _fit(d: Variant, text: String, font_size: float, color: Color, font: Font, max_w: float, tight := false) -> Label:
	var s := Loc.t(text)
	var fs := int(font_size)
	var lowest := int(font_size * 0.8)
	while fs > lowest and font != null and _text_w(font, s, fs) > max_w:
		fs -= 1
	var l: Label = d._text(s, fs, color, font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tight:
		l.custom_minimum_size = Vector2(minf(ceilf(_text_w(font, s, fs)) + 1.0, max_w), 0.0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		l.custom_minimum_size = Vector2(0.0, 0.0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _text_w(font: Font, text: String, font_size: int) -> float:
	if font == null:
		return float(text.length()) * float(font_size) * 0.55
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Texto que parte en líneas (como mucho `lines`) dentro del ancho que le den.
static func _wrap(d: Variant, text: String, font_size: float, color: Color, font: Font, lines: int, line_h: float) -> Label:
	var l: Label = d._text(text, int(font_size), color, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if font != null and line_h > 0.0:
		# El alto real de la línea, no el de la fuente latina: en japonés o hindi entra otra fuente, más alta,
		# y con la cuenta de Inter la segunda línea no cabía y se quedaba en puntos suspensivos.
		var real := _real_h(font, l.text, int(font_size))
		l.add_theme_constant_override("line_spacing", int(line_h - real))
		l.custom_minimum_size = Vector2(0.0, line_h * float(lines - 1) + maxf(line_h, real) + 6.0)
	return l


## Aprieta una columna para que quepa en «room»: «pairs» son sus textos ([Label, fuente]) y «others» lo que
## miden los demás hijos. Solo actúa cuando no cabe (fuentes más altas que la latina).
static func _squeeze(box: BoxContainer, pairs: Array, others: float, room: float) -> void:
	var tall := others
	for pair: Array in pairs:
		var lb: Label = pair[0]
		tall += _real_h(pair[1], lb.text, lb.get_theme_font_size("font_size"))
	if tall > room and box.get_child_count() > 1:
		box.add_theme_constant_override("separation", int(floorf((room - tall) / float(box.get_child_count() - 1))))


## Alto de una línea de este texto tal como se va a pintar (con las fuentes de reserva que le toquen).
static func _real_h(font: Font, text: String, font_size: int) -> float:
	if font == null:
		return float(font_size) * 1.3
	var line := TextLine.new()
	line.add_string(text if text != "" else "A", font, font_size)
	return maxf(line.get_size().y, font.get_height(font_size))


static func _vbox(sep := 0.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(sep))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func _hbox(sep := 0.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(sep))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func _gap(w: float, h: float, grow_h := false, grow_v := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if grow_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if grow_v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Mete un control entre dos márgenes laterales.
static func _inset(c: Control, margin: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(margin))
	m.add_theme_constant_override("margin_right", int(margin))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m

## Icono de la app (ui/inicio/icono.bin, tools/inicio/icono.py) con la sombra suave que lleva en el diseño de Pablo:
## medida en su captura, cae hacia abajo (unos 12 px bajo una tesela de 223 y apenas 5 a los lados) y oscurece el
## fondo como mucho un 17 %. La pinta una caja con las mismas esquinas, debajo de la imagen y un poco metida para no asomar.
## `grow`: se dibuja ese factor más grande, hacia la derecha y centrado en alto, sin cambiar lo que ocupa en la
## maqueta (en la cabecera de la lista, el diseño la lleva un 6,7 % mayor que su hueco, con el título en su sitio).
static func _icon_mark(side: float, grow := 1.0) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(side, side)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.55, 0.2)
	sb.set_corner_radius_all(int(roundf(side * grow * 0.255)))
	sb.corner_detail = 16
	sb.shadow_color = Color(0.32, 0.18, 0.1, 0.22)
	sb.shadow_size = maxi(int(roundf(side * grow * 0.036)), 2)
	sb.shadow_offset = Vector2(0.0, side * grow * 0.018)
	shade.add_theme_stylebox_override("panel", sb)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var extra := side * (grow - 1.0)
	var tuck := maxf(side * grow * 0.012, 1.0)
	shade.offset_left = tuck
	shade.offset_top = tuck - extra * 0.5
	shade.offset_right = extra - tuck
	shade.offset_bottom = extra * 0.5 - tuck
	box.add_child(shade)
	var mark := TextureRect.new()
	mark.texture = art("icono")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.offset_top = -extra * 0.5
	mark.offset_right = extra
	mark.offset_bottom = extra * 0.5
	box.add_child(mark)
	return box


static func _center_v(c: Control) -> Control:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


## Barra de avance: pista y relleno.
static func _bar(track: Color, fill: Color, value: float, height: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0.0, height)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_fill(_panel(_box(track, height * 0.5))))
	if value > 0.0:
		var done := _panel(_box(fill, height * 0.5))
		done.set_anchors_preset(Control.PRESET_FULL_RECT)
		done.anchor_right = clampf(value, 0.04, 1.0)
		holder.add_child(done)
	return holder


## Tesela de color con su icono.
static func _tile(d: Variant, icon_name: String, bg: Color, ink: Color, side: float, icon_side: float, radius: float) -> Panel:
	var tile := _panel(_box(bg, radius), Vector2(side, side))
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pic: TextureRect = d._icon(icon_name, icon_side, ink)
	pic.set_anchors_preset(Control.PRESET_CENTER)
	pic.offset_left = -icon_side * 0.5
	pic.offset_top = -icon_side * 0.5
	pic.offset_right = icon_side * 0.5
	pic.offset_bottom = icon_side * 0.5
	tile.add_child(pic)
	return tile


static func _mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## Lo que el jugador lleva hoy del reto: [hechos, total, racha, completo].
static func _today(d: Variant) -> Array:
	var s: Dictionary = d._prog()
	var day: int = d._prog_day()
	Progress.ensure_today(s, day, d._prog_ctx())
	var goals: Array = Progress.goals(s, day)
	var done := 0
	for g: Dictionary in goals:
		if bool(g["hecho"]):
			done += 1
	return [done, goals.size(), Progress.streak_now(s, day), bool((s["reto"] as Dictionary)["completo"])]


static func _page_root(d: Variant) -> Control:
	var root: Control = d._home_root()
	return root


# ================================================================ LISTA

static func build_list(d: Variant, items: Array) -> void:
	var root := _page_root(d)
	var dark: bool = d.dark
	var ink: Color = d._c("ink")
	var quiet: Color = d._c("quiet")
	var inset: Vector2 = d._insets()
	var H: float = d.size.y
	var page: Color = Color("e7e4f1") if not dark else Color("101533")

	# Fondo: el color de la página, que abajo se vuelve melocotón (de noche, añil), con el rey arriba y el damero al pie.
	var wash := Wash.new()
	if dark:
		wash.stops = [[0.0, page], [0.3, Color("12173a")], [0.72, Color("161a3f")], [1.0, Color("1d1838")]]
	else:
		wash.stops = [[0.0, page], [0.26, page], [0.4, Color("f2f0f9")], [0.6, Color("f6f1f6")], [0.8, Color("fbeee6")], [0.93, Color("fde5d6")], [1.0, Color("fde1cc")]]
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_fill(wash))
	var top := maxf(inset.x + u(4.0), u(50.0))
	var hero := TextureRect.new()
	hero.texture = art("fondo_cabecera_noche" if dark else "fondo_cabecera")
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_SCALE
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# La portada baja con la franja de la cámara: el rey siempre asoma por detrás de la tarjeta del nivel.
	hero.offset_top = top - u(50.0)
	hero.offset_bottom = hero.offset_top + u(256.0)
	root.add_child(hero)
	if hero.offset_top > 0.0:
		var sky := ColorRect.new()
		sky.color = Color("eceaf4") if not dark else Color("0f1433")
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sky.set_anchors_preset(Control.PRESET_TOP_WIDE)
		sky.offset_bottom = hero.offset_top + 2.0
		root.add_child(sky)
		root.move_child(sky, hero.get_index())
	var floor_pic := TextureRect.new()
	floor_pic.texture = art("fondo_suelo_noche" if dark else "fondo_suelo")
	floor_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_pic.stretch_mode = TextureRect.STRETCH_SCALE
	floor_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_pic.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	floor_pic.offset_top = -u(57.0)
	root.add_child(floor_pic)

	var side := u(16.0)
	var bottom := inset.y + u(14.0)
	# Margen que se deja dentro de la zona que se desplaza para que no recorte las sombras de las tarjetas.
	var air := u(8.0)
	var column := _vbox(0.0)
	_fill(column, side - air, top, side - air, bottom)
	root.add_child(column)

	# Cabecera: el icono de la app, el nombre y la pregunta.
	var head := _hbox(u(16.0))
	head.custom_minimum_size = Vector2(0.0, u(76.0))
	head.add_child(_icon_mark(u(76.0), 1.067))
	var names := _vbox(0.0)
	names.alignment = BoxContainer.ALIGNMENT_BEGIN
	names.add_child(_gap(0.0, u(5.0)))
	var title: Label = d._line("A Chess Way", int(u(28.5)), ink, d.font_display)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(title)
	var ask: Label = _fit(d, "¿Qué quieres hacer?", u(14.5), quiet, d.font_medium, u(170.0))
	names.add_child(ask)
	names.add_child(_gap(0.0, u(8.0)))
	var rule := _panel(_box(Color("f26a1e") if not dark else d._c("accent"), u(1.5)), Vector2(u(48.0), u(3.0)))
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	names.add_child(rule)
	_squeeze(names, [[title, d.font_display], [ask, d.font_medium]], u(16.0), u(76.0))
	head.add_child(names)
	column.add_child(_inset(head, air))
	var head_gap := _gap(0.0, u(62.0))
	column.add_child(head_gap)

	# Lo que ocupa lo fijo, para repartir el resto entre las filas.
	var fixed := top + u(76.0) + u(62.0) + bottom + u(44.0) + u(12.0)
	if d._has_player():
		column.add_child(_inset(_list_level(d), air))
		column.add_child(_gap(0.0, u(10.0) - u(6.0)))
		fixed += u(88.0) + u(10.0)
	var n := maxi(items.size(), 1)
	var gap := u(8.0)
	var free := H - fixed - gap * float(n - 1)
	# Pantallas bajas: antes de que haga falta desplazar, se acorta el aire entre la cabecera y la tarjeta.
	var lacking := u(54.0) * float(n) - free
	if lacking > 0.0:
		var cut := minf(lacking, u(26.0))
		head_gap.custom_minimum_size.y = u(62.0) - cut
		free += cut
	var row_h := clampf(floorf(free / float(n)), u(54.0), u(70.0))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	d.progress_scroll = scroll
	var rows := _vbox(gap)
	var rows_pad := MarginContainer.new()
	rows_pad.add_theme_constant_override("margin_left", int(air))
	rows_pad.add_theme_constant_override("margin_right", int(air))
	rows_pad.add_theme_constant_override("margin_top", int(u(6.0)))
	rows_pad.add_theme_constant_override("margin_bottom", int(u(8.0)))
	rows_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_pad.add_child(rows)
	scroll.add_child(rows_pad)
	var today: Array = _today(d) if d._has_player() else []
	for def: Array in items:
		rows.add_child(_list_row(d, def, row_h, today))
	column.add_child(_gap(0.0, u(12.0) - u(8.0)))

	# Pie: «Opciones» en una píldora, centrada; el idioma, a su derecha.
	var foot := Control.new()
	foot.custom_minimum_size = Vector2(0.0, u(44.0))
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_inset(foot, air))
	var paper: Color = d._c("surface")
	var pill := _card(_box(Color(paper.r, paper.g, paper.b, 0.9), u(22.0), Color(1, 1, 1, 0.9 if not dark else 0.08), 3, d._c("shadow"), 18, 8.0), Callable(d, "_open_options"), "Opciones", u(44.0))
	var pill_row := _hbox(u(8.0))
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_row.add_child(_center_v(d._icon("sliders", u(19.0), ink)))
	var pill_text: Label = d._line("Opciones", int(u(15.5)), ink, d.font_medium)
	pill_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(pill_text)
	pill.add_child(_fill(pill_row, u(18.0), 0.0, u(18.0), 0.0))
	pill.set_anchors_preset(Control.PRESET_CENTER)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.offset_top = -u(22.0)
	pill.offset_bottom = u(22.0)
	# El ancho sale del texto, y se rehace si el texto cambia de medida después (fuente que llega tarde, idioma):
	# calculado una sola vez al construir, en algún móvil la palabra se salía de la píldora.
	var fit_pill := func() -> void:
		if not is_instance_valid(pill) or not is_instance_valid(pill_row):
			return
		var w := pill_row.get_combined_minimum_size().x + u(36.0)
		pill.custom_minimum_size = Vector2(w, u(44.0))
		pill.offset_left = -w * 0.5
		pill.offset_right = w * 0.5
	pill_row.minimum_size_changed.connect(fit_pill)
	pill_text.resized.connect(fit_pill)
	fit_pill.call()
	fit_pill.call_deferred()
	foot.add_child(pill)
	var flag: Button = d._flag_button()
	flag.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	flag.offset_right = 0.0
	flag.offset_left = -u(44.0)
	flag.offset_top = -u(22.0)
	flag.offset_bottom = u(22.0)
	flag.custom_minimum_size = Vector2(u(44.0), u(44.0))
	foot.add_child(flag)


## Tarjeta del nivel de la lista: insignia, nivel de táctica con su barra, lo que falta y el nivel de juego.
static func _list_level(d: Variant) -> Button:
	var dark: bool = d.dark
	var ink: Color = d._c("ink")
	var quiet: Color = d._c("quiet")
	var r := float(d.player["rating"]["r"])
	var lv: int = Assessment.level_of(r)
	var top_level: int = Assessment.LEVEL_FLOORS.size() - 1
	var bg := Color("fbeee4") if not dark else Color("2a2233")
	var card := _card(_box(bg, u(20.0), Color(1, 1, 1, 0.92 if not dark else 0.08), 3, Color(0.58, 0.4, 0.3, 0.16) if not dark else d._c("shadow"), 22, 10.0), Callable(d, "_open_progress").bind("progress"), "Mi nivel", u(88.0))
	var row := _hbox(u(12.0))
	card.add_child(_fill(row, u(14.0), 0.0, u(14.0), 0.0))
	var badge_button := Button.new()
	badge_button.flat = true
	badge_button.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		badge_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	badge_button.custom_minimum_size = Vector2(u(60.0), u(60.0))
	badge_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_button.pressed.connect(Callable(d, "_open_avatar"))
	badge_button.set_meta("label", "Tu icono")
	var badge: Control = d._level_badge(r, u(60.0), d._badge_elo())
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_button.add_child(badge)
	row.add_child(badge_button)
	var words := _vbox(0.0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text_w := 1080.0 - u(32.0) - u(28.0) - u(60.0) - u(12.0) - u(12.0) - u(18.0)
	words.add_child(_fit(d, Loc.t("Táctica: nivel %d de %d · %s") % [lv, top_level, Loc.t(str(d._rank(lv)[1]))], u(16.5), ink, d.font_display, text_w))
	words.add_child(_gap(0.0, u(4.0)))
	words.add_child(_bar(Color(0.95, 0.42, 0.12, 0.18), Color("f26a1e") if not dark else d._c("accent"), d._level_progress(r), u(5.0)))
	words.add_child(_gap(0.0, u(4.0)))
	var left_text := Loc.t("¡Nivel máximo!")
	if lv + 1 < Assessment.LEVEL_FLOORS.size():
		left_text = Loc.f("Te faltan %d puntos para el nivel %d", [maxi(1, int(ceil(float(Assessment.LEVEL_FLOORS[lv + 1]) - r))), lv + 1])
	var lines: Array = [[words.get_child(0), d.font_display]]
	var left_label: Label = _fit(d, left_text, u(13.5), quiet, d.font_medium, text_w)
	words.add_child(left_label)
	lines.append([left_label, d.font_medium])
	var gr: Dictionary = GameLog.game_rating(d._log())
	if int(gr["n"]) > 0:
		var game_label: Label = _fit(d, Loc.f("Juego: %d%s", [roundi(float(gr["r"])), Loc.t(" (provisional)") if bool(gr["provisional"]) else ""]), u(13.5), quiet, d.font_medium, text_w)
		words.add_child(game_label)
		lines.append([game_label, d.font_medium])
	# La tarjeta mide siempre lo mismo (de eso depende el reparto de las filas): con fuentes más altas
	# (japonés, hindi) las líneas se aprietan lo justo para caber.
	_squeeze(words, lines, u(13.0), u(88.0) - u(8.0))
	row.add_child(words)
	row.add_child(_center_v(d._icon("caret", u(18.0), quiet)))
	return card


## Fila de la lista: tesela con icono, título, detalle y la flecha en su círculo. El reto del día enseña además
## sus tres pasos.
static func _list_row(d: Variant, def: Array, height: float, today: Array) -> Button:
	var dark: bool = d.dark
	var ink: Color = d._c("ink")
	var quiet: Color = d._c("quiet")
	var paper: Color = d._c("surface")
	var heading := str(def[2])
	var icon_name := "users" if heading == "Partida online" else str(def[0])
	var tint: Array = d._tint(str(def[1]))
	var card := _card(_box(Color(paper.r, paper.g, paper.b, 0.94), u(20.0), Color(1, 1, 1, 0.9 if not dark else 0.07), 3, d._c("shadow"), 16, 7.0), def[4], heading, height)
	var row := _hbox(u(16.0))
	card.add_child(_fill(row, u(12.0), 0.0, u(12.0), 0.0))
	var side := minf(u(50.0), height - u(14.0))
	row.add_child(_tile(d, icon_name, tint[0], tint[1], side, side * 0.6, u(14.0)))
	var words := _vbox(0.0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text_w := 1080.0 - u(32.0) - u(24.0) - side - u(16.0) - u(16.0) - u(32.0)
	words.add_child(_fit(d, heading, u(17.0), ink, d.font_display, text_w))
	if _text_w(d.font_regular, Loc.t(str(def[3])), int(u(14.0) * 0.86)) > text_w and height >= u(62.0):
		words.add_child(_wrap(d, str(def[3]), u(12.5), quiet, d.font_regular, 2, u(15.0)))
	else:
		words.add_child(_fit(d, str(def[3]), u(14.0), quiet, d.font_regular, text_w))
	if heading == "Reto del día" and today.size() >= 2 and int(today[1]) > 0:
		words.add_child(_gap(0.0, u(4.0)))
		var pips := _hbox(u(4.0))
		for i in int(today[1]):
			var on := i < int(today[0])
			pips.add_child(_panel(_box((Color("f26a1e") if not dark else d._c("accent")) if on else d._c("track"), u(1.5)), Vector2(u(26.0), u(3.0))))
		words.add_child(pips)
	row.add_child(words)
	var chip := _panel(_box(d._c("field") if dark else Color("f0eefa"), u(16.0)), Vector2(u(32.0), u(32.0)))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var arrow: TextureRect = d._icon("caret", u(15.0), ink)
	arrow.set_anchors_preset(Control.PRESET_CENTER)
	arrow.offset_left = -u(7.5)
	arrow.offset_top = -u(7.5)
	arrow.offset_right = u(7.5)
	arrow.offset_bottom = u(7.5)
	chip.add_child(arrow)
	row.add_child(chip)
	return card


# ================================================================ REJILLA

## En oscuro, los dibujos (y el degradado que llevan detrás, igual al de su cielo) se tiñen de noche: así no se
## nota dónde acaba el dibujo y empieza la tarjeta.
const NIGHT_HERO := Color(0.3, 0.33, 0.58)
const NIGHT_BANNER := Color(0.3, 0.38, 0.34)

## Colores de las tarjetas de la rejilla en claro: [fondo, tesela, tinta del icono]. En oscuro salen de los tonos de la app.
const GRID_LIGHT := {
	"butter": [Color("fbf6eb"), Color("f9e5b1"), Color("7a4f1c")],
	"peach": [Color("fcf1ee"), Color("f7d9cb"), Color("b5452c")],
	"mint": [Color("eef7f1"), Color("d0ead9"), Color("2f6b43")],
	"sky": [Color("eef3fd"), Color("d5e0f9"), Color("2c46ba")],
	"lilac": [Color("f1eefb"), Color("dcd2f7"), Color("4938bc")],
	"ice": [Color("eef4fd"), Color("d2e4f8"), Color("2e5bbc")],
}


static func _grid_colors(d: Variant, tint_name: String) -> Array:
	if not bool(d.dark):
		return GRID_LIGHT[tint_name]
	var t: Array = d._tint("sky" if tint_name == "ice" else tint_name)
	var paper: Color = d._c("surface")
	return [_mix(paper, t[0], 0.45), _mix(t[0], t[1], 0.16), t[1]]


static func build_grid(d: Variant) -> void:
	var root := _page_root(d)
	var dark: bool = d.dark
	var inset: Vector2 = d._insets()
	var H: float = d.size.y
	var wash := Wash.new()
	if dark:
		wash.stops = [[0.0, Color("0e1433")], [0.5, Color("13173a")], [1.0, Color("171636")]]
	else:
		wash.stops = [[0.0, Color("e8ecfb")], [0.45, Color("eeeefb")], [1.0, Color("f6f4fa")]]
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_fill(wash))

	var side := u(14.0)
	var top := maxf(inset.x + u(8.0), u(30.0))
	var bottom := inset.y + u(14.0)
	var gap := u(10.0)
	var nav_h := u(56.0)
	var head_h := u(50.0)
	var hero_h := u(159.0)
	var banner_h := u(84.0)
	var cell_gap := u(8.0)
	var room := H - top - bottom - nav_h - u(8.0) - head_h - hero_h - banner_h - gap * 3.0 - cell_gap * 2.0
	# Pantallas bajas: antes de que haga falta desplazar, ceden la portada, el reto de la semana y los huecos.
	var lacking := u(118.0) * 3.0 - room
	if lacking > 0.0:
		var from_hero := minf(lacking, u(19.0))
		hero_h -= from_hero
		var from_banner := clampf(lacking - from_hero, 0.0, u(12.0))
		banner_h -= from_banner
		var from_gap := clampf((lacking - from_hero - from_banner) / 3.0, 0.0, u(3.0))
		gap -= from_gap
		room += from_hero + from_banner + from_gap * 3.0
	var card_h := clampf(floorf(room / 3.0), u(118.0), u(140.0))

	var air := u(8.0)
	var column := _vbox(0.0)
	_fill(column, side - air, top - u(4.0), side - air, bottom)
	root.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	d.progress_scroll = scroll
	var body := _vbox(gap)
	var body_pad := MarginContainer.new()
	body_pad.add_theme_constant_override("margin_left", int(air))
	body_pad.add_theme_constant_override("margin_right", int(air))
	body_pad.add_theme_constant_override("margin_top", int(u(4.0)))
	body_pad.add_theme_constant_override("margin_bottom", int(u(8.0)))
	body_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_pad.add_child(body)
	scroll.add_child(body_pad)
	body.add_child(_grid_header(d, head_h))
	body.add_child(_grid_hero(d, hero_h))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(cell_gap))
	grid.add_theme_constant_override("v_separation", int(cell_gap))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cell_w := floorf((1080.0 - side * 2.0 - cell_gap) / 2.0)
	for def: Array in _grid_items(d):
		grid.add_child(_grid_card(d, def, cell_w, card_h))
	body.add_child(grid)
	body.add_child(_grid_banner(d, banner_h))
	column.add_child(_inset(_grid_nav(d, nav_h), air))


## Cabecera de la rejilla: insignia, saludo y nivel; a la derecha, la racha, el nivel de juego y los avisos.
static func _grid_header(d: Variant, height: float) -> Control:
	var dark: bool = d.dark
	var ink: Color = d._c("ink")
	var quiet: Color = d._c("quiet")
	var paper: Color = d._c("surface")
	var has_player: bool = d._has_player()
	var row := _hbox(u(8.0))
	row.custom_minimum_size = Vector2(0.0, height)
	var chips := _hbox(u(4.0))
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_sb := _box(Color(paper.r, paper.g, paper.b, 0.78 if not dark else 0.9), u(14.0), Color(1, 1, 1, 0.95 if not dark else 0.07), 3, d._c("shadow"), 8, 3.0)
	var chips_w := 0.0
	if has_player:
		var today := _today(d)
		var streak := int(today[2])
		var fire := Control.new()
		fire.custom_minimum_size = Vector2(u(21.0), u(21.0))
		fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var flame: TextureRect = d._icon("fire", u(21.0), Color("f2600f") if streak > 0 else d._c("track"))
		fire.add_child(_fill(flame))
		if streak > 0:
			var core: TextureRect = d._icon("fire", u(10.5), Color("ffc93c"))
			core.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			core.offset_left = -u(5.25)
			core.offset_right = u(5.25)
			core.offset_top = -u(12.0)
			core.offset_bottom = -u(1.5)
			fire.add_child(core)
		var streak_chip := _grid_stat(d, chip_sb, fire, str(streak), "día" if streak == 1 else "días", Callable(d, "_open_day"), "Racha")
		chips.add_child(streak_chip)
		chips_w += streak_chip.custom_minimum_size.x + u(4.0)
		var gr: Dictionary = GameLog.game_rating(d._log())
		if int(gr["n"]) > 0:
			var coin := _panel(_box(Color("f2ac22"), u(11.0), Color("ffe07a"), 5), Vector2(u(22.0), u(22.0)))
			var crown: TextureRect = d._icon("crown", u(12.0), Color("fff1c0"))
			crown.set_anchors_preset(Control.PRESET_CENTER)
			crown.offset_left = -u(6.0)
			crown.offset_top = -u(6.0)
			crown.offset_right = u(6.0)
			crown.offset_bottom = u(6.0)
			coin.add_child(crown)
			var game_chip := _grid_stat(d, chip_sb, coin, str(roundi(float(gr["r"]))), "juego", Callable(d, "_open_my_games_from").bind("home"), "Nivel de juego")
			chips.add_child(game_chip)
			chips_w += game_chip.custom_minimum_size.x + u(4.0)
		# Avisos: abre «Tu día» (ahí está el aviso diario). El punto rojo, mientras quede algo del reto de hoy.
		var bell := _card(chip_sb, Callable(d, "_open_day"), "Avisos", u(38.0))
		bell.custom_minimum_size = Vector2(u(38.0), u(38.0))
		var bell_icon: TextureRect = d._icon("bell", u(19.0), ink)
		bell_icon.set_anchors_preset(Control.PRESET_CENTER)
		bell_icon.offset_left = -u(9.5)
		bell_icon.offset_top = -u(9.5)
		bell_icon.offset_right = u(9.5)
		bell_icon.offset_bottom = u(9.5)
		bell.add_child(bell_icon)
		if not bool(today[3]):
			var dot := _panel(_box(Color("e0492b"), u(4.5), d._c("wash_top") if dark else Color("eef0fb"), 4), Vector2(u(10.0), u(10.0)))
			dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			dot.offset_left = -u(8.0)
			dot.offset_right = u(2.0)
			dot.offset_top = -u(2.0)
			dot.offset_bottom = u(8.0)
			bell.add_child(dot)
		chips.add_child(bell)
		chips_w += u(38.0)
	else:
		# Sin nivel todavía: aquí va el idioma, a mano.
		var flag: Button = d._flag_button()
		flag.custom_minimum_size = Vector2(u(44.0), u(44.0))
		chips.add_child(flag)
		chips_w += u(44.0)

	# A la izquierda: quién eres. Ocupa lo que dejen libre las pastillas.
	var who_w := 1080.0 - u(28.0) - chips_w - u(8.0)
	var who := Button.new()
	who.flat = true
	who.focus_mode = Control.FOCUS_NONE
	who.mouse_filter = Control.MOUSE_FILTER_PASS
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		who.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.custom_minimum_size = Vector2(0.0, height)
	who.clip_contents = true
	who.set_meta("label", "Mi nivel")
	var who_row := _hbox(u(8.0))
	who.add_child(_fill(who_row))
	if has_player:
		var r := float(d.player["rating"]["r"])
		var lv: int = Assessment.level_of(r)
		who.pressed.connect(Callable(d, "_open_progress").bind("progress"))
		# El icono es un botón aparte (como en la lista): cambia el icono o la foto; el resto lleva a «Mi nivel».
		var badge_button := Button.new()
		badge_button.flat = true
		badge_button.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			badge_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		badge_button.custom_minimum_size = Vector2(u(48.0), u(48.0))
		badge_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge_button.mouse_filter = Control.MOUSE_FILTER_STOP
		badge_button.pressed.connect(Callable(d, "_open_avatar"))
		badge_button.set_meta("label", "Tu icono")
		var badge: Control = d._level_badge(r, u(48.0), d._badge_elo())
		badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_button.add_child(badge)
		who_row.add_child(badge_button)
		var words := _vbox(-u(3.5))
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text_w := who_w - u(48.0) - u(8.0)
		var hello_label: Label = _fit(d, "¡Hola!", u(12.5), quiet, d.font_medium, text_w)
		words.add_child(hello_label)
		var name_row := _hbox(u(5.0))
		var tactic: Label = _fit(d, "Táctica", u(20.0), ink, d.font_display, text_w - u(20.0), true)
		name_row.add_child(tactic)
		name_row.add_child(_center_v(d._icon("caret", u(13.0), quiet)))
		words.add_child(name_row)
		var level_row := _hbox(u(4.0))
		level_row.add_child(_center_v(d._icon(str(d._rank(lv)[0]), u(13.0), quiet)))
		var level_label: Label = _fit(d, Loc.t("Nivel %d · %s") % [lv, Loc.t(str(d._rank(lv)[1]))], u(11.5), quiet, d.font_medium, text_w - u(17.0))
		level_row.add_child(level_label)
		words.add_child(level_row)
		# Tres líneas en el alto de la cabecera: con fuentes más altas (japonés, hindi) se aprietan lo justo.
		var tall := 0.0
		for pair: Array in [[hello_label, d.font_medium], [tactic, d.font_display], [level_label, d.font_medium]]:
			var lb: Label = pair[0]
			tall += _real_h(pair[1], lb.text, lb.get_theme_font_size("font_size"))
		words.add_theme_constant_override("separation", int(minf(-u(3.5), floorf((height - tall) / 2.0))))
		who_row.add_child(words)
	else:
		who.pressed.connect(Callable(d, "_open_experience"))
		var emblem := _icon_mark(u(48.0))
		emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		who_row.add_child(emblem)
		var hello := _vbox(0.0)
		hello.alignment = BoxContainer.ALIGNMENT_CENTER
		hello.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hello.add_child(_fit(d, "¡Hola!", u(12.5), quiet, d.font_medium, who_w - u(56.0)))
		hello.add_child(_fit(d, "¿Qué quieres hacer?", u(17.0), ink, d.font_display, who_w - u(56.0)))
		who_row.add_child(hello)
	row.add_child(who)
	row.add_child(chips)
	return row


## Pastilla de la cabecera: un dibujo, un número y su nombre debajo.
static func _grid_stat(d: Variant, sb: StyleBoxFlat, picture: Control, number: String, label: String, on_press: Callable, meta: String) -> Button:
	var chip := _card(sb, on_press, meta, u(38.0))
	var row := _hbox(u(4.0))
	chip.add_child(_fill(row, u(6.0), 0.0, u(8.0), 0.0))
	row.add_child(_center_v(picture))
	var words := _vbox(-u(1.0))
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var big: Label = d._line(number, int(u(15.0)), d._c("ink"), d.font_display)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(big)
	var small: Label = d._line(label, int(u(11.0)), d._c("quiet"), d.font_medium)
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(small)
	row.add_child(words)
	var text_w := maxf(_text_w(d.font_display, Loc.t(number), int(u(15.0))), _text_w(d.font_medium, Loc.t(label), int(u(11.0))))
	chip.custom_minimum_size = Vector2(u(6.0) + picture.custom_minimum_size.x + u(4.0) + ceilf(text_w) + u(8.0) + 2.0, u(38.0))
	return chip


## Portada de la rejilla: el nombre, el lema, la tarjeta del nivel y el caballo en la montaña.
static func _grid_hero(d: Variant, height: float) -> Button:
	var dark: bool = d.dark
	var ink: Color = d._c("ink")
	var quiet: Color = d._c("quiet")
	var has_player: bool = d._has_player()
	var bg := Color("e4e9fa") if not dark else Color("e4e9fa") * NIGHT_HERO
	bg.a = 1.0
	var action := Callable(d, "_open_progress").bind("progress") if has_player else Callable(d, "_open_experience")
	var hero := _card(_box(bg, u(18.0), Color(1, 1, 1, 0.92 if not dark else 0.08), 3, Color(0.36, 0.41, 0.7, 0.2) if not dark else d._c("shadow"), 24, 10.0), action, "Portada", height)
	# El dibujo va recortado a la forma de la tarjeta.
	var clip := _panel(_box(bg, u(17.0)))
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	hero.add_child(_fill(clip, 3.0, 3.0, 3.0, 3.0))
	var glow := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	# El mismo degradado que trae el cielo del dibujo, para que no se note dónde empieza.
	var sky_stops := [[0.0, "ebedfb"], [0.27, "e9ecfb"], [0.39, "e7edfb"], [0.52, "e4eafa"], [0.61, "dde5fa"], [0.7, "dee1fa"], [0.8, "dadefb"], [1.0, "dcddf9"]]
	g.set_offset(0, 0.0)
	g.set_offset(1, 1.0)
	g.set_color(0, Color(str(sky_stops[0][1])))
	g.set_color(1, Color(str(sky_stops[sky_stops.size() - 1][1])))
	for i in range(1, sky_stops.size() - 1):
		g.add_point(float(sky_stops[i][0]), Color(str(sky_stops[i][1])))
	grad.gradient = g
	grad.width = 256
	grad.height = 4
	glow.texture = grad
	if dark:
		glow.modulate = NIGHT_HERO
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_fill(glow))
	var pic := TextureRect.new()
	pic.texture = art("portada_caballo")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pic.offset_left = -u(152.0)
	pic.offset_top = -u(126.5)
	if dark:
		pic.modulate = NIGHT_HERO
	clip.add_child(pic)

	# Portada acortada (pantallas bajas): el título y el lema suben un poco y la tarjeta del nivel se queda
	# en una línea menos, para que no se pisen.
	var compact: bool = height < u(158.0)
	var title := _hbox(u(7.0))
	title.position = Vector2(u(16.0), u(7.0 if compact else 10.0))
	var t1: Label = d._line("A Chess", int(u(29.0)), ink, d.font_display)
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(t1)
	var t2: Label = d._line("Way", int(u(29.0)), Color("4252c8") if not dark else Color("9fb0ff"), d.font_display)
	t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(t2)
	hero.add_child(title)
	var tagline := _fit(d, "Mejora cada día, una jugada a la vez.", u(12.5), ink if dark else Color("2b3056"), d.font_medium, u(222.0))
	tagline.position = Vector2(u(16.0), u(43.0 if compact else 47.0))
	tagline.size = Vector2(u(222.0), u(17.0))
	hero.add_child(tagline)

	# Nota manuscrita, girada, en la esquina.
	var hand: Color = Color("1f2756") if not dark else Color("dfe4ff")
	var note := _vbox(u(2.0))
	var nf := note_font(d)
	var script: bool = nf != d.font_medium
	var note_text: Label = d._text("Pequeños\nretos,\ngrandes\njugadores", int(u(14.0 if script else 10.5)), hand, nf)
	note_text.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	note_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if nf != null:
		note_text.add_theme_constant_override("line_spacing", int(u(12.5 if script else 12.0) - nf.get_height(int(u(14.0 if script else 10.5)))))
	note.add_child(note_text)
	var stroke := Swoosh.new()
	stroke.color = hand
	stroke.custom_minimum_size = Vector2(u(26.0), u(7.0))
	stroke.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(stroke)
	hero.add_child(note)
	var note_fs := int(u(14.0 if script else 10.5))
	var note_w := 0.0
	var note_lines: PackedStringArray = Loc.t("Pequeños\nretos,\ngrandes\njugadores").split("\n")
	for line: String in note_lines:
		note_w = maxf(note_w, _text_w(nf, line, note_fs))
	note_text.custom_minimum_size = Vector2(ceilf(note_w) + 2.0, u(12.5 if script else 12.0) * float(note_lines.size()))
	var note_size := Vector2(note_text.custom_minimum_size.x, note_text.custom_minimum_size.y + u(2.0) + u(7.0))
	note.size = note_size
	note.position = Vector2(1080.0 - u(28.0) - u(8.0) - note_size.x, u(7.0))
	note.pivot_offset = note_size * 0.5
	note.rotation = deg_to_rad(-9.0)

	# Tarjeta del nivel (o la invitación al test), abajo a la izquierda.
	var paper: Color = d._c("surface")
	var mini := _panel(_box(Color(paper.r, paper.g, paper.b, 0.94), u(14.0), Color(1, 1, 1, 1.0 if not dark else 0.08), 3, Color(0.31, 0.35, 0.67, 0.16) if not dark else d._c("shadow"), 12, 5.0))
	mini.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mini.offset_left = u(10.0)
	mini.offset_right = u(10.0) + u(212.0)
	mini.offset_bottom = -u(10.0)
	mini.offset_top = -u(10.0) - u(62.0 if compact else 76.0)
	hero.add_child(mini)
	var mini_row := _hbox(u(7.0))
	mini.add_child(_fill(mini_row, u(8.0), u(8.0), u(8.0), u(8.0)))
	var text_w := u(212.0) - u(16.0) - u(32.0) - u(7.0)
	var sky_tint: Array = d._tint("sky")
	var words := _vbox(0.0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	if has_player:
		var r := float(d.player["rating"]["r"])
		var lv: int = Assessment.level_of(r)
		var rank_tile := _tile(d, str(d._rank(lv)[0]), Color("d5e0f9") if not dark else sky_tint[0], Color("3a4fc8") if not dark else sky_tint[1], u(32.0), u(19.0), u(10.0))
		rank_tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mini_row.add_child(rank_tile)
		var line := _hbox(u(6.0))
		var counter := ""
		if lv + 1 < Assessment.LEVEL_FLOORS.size():
			var lo := float(Assessment.LEVEL_FLOORS[lv])
			var hi := float(Assessment.LEVEL_FLOORS[lv + 1])
			counter = "%d / %d" % [int(floor(r - lo)), int(hi - lo)]
		var counter_w: float = d.font_medium.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1, int(u(11.0))).x if counter != "" else 0.0
		line.add_child(_fit(d, Loc.t("Nivel %d · %s") % [lv, Loc.t(str(d._rank(lv)[1]))], u(13.5), ink, d.font_display, text_w - counter_w - u(6.0)))
		if counter != "":
			var count: Label = d._line(counter, int(u(11.0)), quiet, d.font_medium)
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(count)
		words.add_child(line)
		words.add_child(_gap(0.0, u(4.0)))
		words.add_child(_bar(d._c("track") if dark else Color("e0e3f1"), Color("6a66ee") if not dark else Color("8f8cff"), d._level_progress(r), u(6.0)))
		words.add_child(_gap(0.0, u(4.0)))
		var left_text := Loc.t("¡Nivel máximo!")
		if lv + 1 < Assessment.LEVEL_FLOORS.size():
			left_text = Loc.f("Te faltan %d puntos para el nivel %d", [maxi(1, int(ceil(float(Assessment.LEVEL_FLOORS[lv + 1]) - r))), lv + 1])
		if compact:
			words.add_child(_fit(d, left_text, u(11.0), quiet, d.font_regular, text_w))
		else:
			words.add_child(_wrap(d, left_text, u(11.0), quiet, d.font_regular, 2, u(13.0)))
	else:
		var cap_tile := _tile(d, "cap", Color("d5e0f9") if not dark else sky_tint[0], Color("3a4fc8") if not dark else sky_tint[1], u(32.0), u(20.0), u(10.0))
		cap_tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mini_row.add_child(cap_tile)
		words.add_child(_fit(d, "Test de nivel", u(13.5), ink, d.font_display, text_w))
		words.add_child(_gap(0.0, u(3.0)))
		words.add_child(_wrap(d, "Unos problemas para saber por dónde empezar.", u(11.0), quiet, d.font_regular, 2 if compact else 3, u(13.0)))
	mini_row.add_child(words)
	return hero


## Las seis tarjetas: [icono, tono, título, subtítulo, descripción, qué abre].
static func _grid_items(d: Variant) -> Array:
	var has_player: bool = d._has_player()
	var items: Array = []
	if has_player:
		var today := _today(d)
		var sub := Loc.t("¡Cumplido hoy!") if bool(today[3]) else (Loc.t("Hoy %d de %d") % [int(today[0]), int(today[1])] if int(today[1]) > 0 else Loc.t("Tu objetivo de hoy"))
		items.append(["flag", "butter", "Reto del día", sub, "Tres pasos cada día para mantener tu racha.", Callable(d, "_open_day")])
		if bool(d.player.get("done", false)):
			items.append(["target", "peach", "Entrenar", "Problemas a tu nivel", "Mates, ataques dobles, clavadas y más.", Callable(d, "_home_train")])
		else:
			items.append(["cap", "peach", "Seguir con el test de nivel", "Lo dejaste a medias.", "Unos problemas para saber por dónde empezar.", Callable(d, "_home_test")])
	else:
		items.append(["cap", "butter", "Test de nivel", "Descubre tu nivel", "Unos problemas para saber por dónde empezar.", Callable(d, "_open_experience")])
		items.append(["target", "peach", "Entrenar", "Problemas a tu nivel", "Mates, ataques dobles, clavadas y más.", Callable(d, "_open_experience")])
	items.append(["piece_knight", "mint", "Jugar una partida", "Contra el ordenador", "13 niveles de dificultad.", Callable(d, "_open_game_setup").bind(true)])
	items.append(["users", "sky", "Partida online", "Contra otra persona", "Demuestra tu nivel en tiempo real.", Callable(d, "_open_online_home")])
	var lessons: Array = d._course_lessons()
	var done := 0
	for l: Dictionary in lessons:
		if d.course_done.has(str(l["id"])):
			done += 1
	var lesson_text := Loc.f("%d de %d lecciones hechas.", [done, lessons.size()]) if done > 0 else Loc.t("%d lecciones, paso a paso.") % lessons.size()
	items.append(["chick", "lilac", "Aprende desde cero", "Cómo se mueve cada pieza", lesson_text, Callable(d, "_open_course")])
	if d.KIDS_ENABLED:
		items.append(["baby", "ice", "Modo Kids", "Desde 8 años, con voz", "Una forma divertida de aprender.", Callable(d, "_set_kids").bind(true)])
	elif has_player:
		# Sin Kids, su hueco es para «Mi nivel y mi plan» (si no, la rejilla queda coja).
		items.append(["trend", "ice", "Mi nivel y mi plan", "En qué fallas", "Y qué te toca practicar ahora.", Callable(d, "_open_progress").bind("progress")])
	return items


static func _grid_card(d: Variant, def: Array, width: float, height: float) -> Button:
	var dark: bool = d.dark
	var ink: Color = d._c("ink")
	var quiet: Color = d._c("quiet")
	var colors := _grid_colors(d, str(def[1]))
	var card := _card(_box(colors[0], u(16.0), Color(1, 1, 1, 0.95 if not dark else 0.07), 3, Color(0.36, 0.41, 0.7, 0.12) if not dark else d._c("shadow"), 14, 5.0), def[5], str(def[2]), height)
	card.custom_minimum_size = Vector2(width, height)
	var pad_x := u(12.0)
	var column := _vbox(0.0)
	card.add_child(_fill(column, pad_x, u(10.0), pad_x, u(8.0)))
	var top := _hbox(u(8.0))
	# En tarjetas bajas (pantallas cortas), la tesela encoge.
	var tile_side := clampf(height - u(90.0), u(30.0), u(42.0))
	var tile := _tile(d, str(def[0]), colors[1], colors[2], tile_side, tile_side * 0.62, tile_side * 0.31)
	tile.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(tile)
	# El título, al lado de la tesela y apoyado en su borde de abajo (Pablo, 16 nov): en una línea si cabe; si no,
	# en dos, un poco más pequeño.
	var arrow_w := u(14.0)
	var title_w := width - pad_x * 2.0 - tile_side - u(8.0) * 2.0 - arrow_w
	var title_box := _vbox(0.0)
	title_box.alignment = BoxContainer.ALIGNMENT_END
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_text := Loc.t(str(def[2]))
	if d.font_display == null or _text_w(d.font_display, title_text, int(u(16.0) * 0.86)) <= title_w:
		title_box.add_child(_fit(d, title_text, u(16.0), ink, d.font_display, title_w))
	else:
		var two := _wrap(d, title_text, u(14.5), ink, d.font_display, 2, u(16.5))
		two.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		title_box.add_child(two)
	top.add_child(title_box)
	var arrow: TextureRect = d._icon("caret", arrow_w, quiet)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(arrow)
	column.add_child(top)
	column.add_child(_gap(0.0, u(7.0)))
	var text_w := width - pad_x * 2.0
	column.add_child(_fit(d, str(def[3]), u(13.0), _mix(ink, quiet, 0.45), d.font_medium, text_w))
	column.add_child(_gap(0.0, u(1.0)))
	column.add_child(_wrap(d, str(def[4]), u(12.0), quiet, d.font_regular, 2, u(14.0)))
	return card


## Franja del reto de la semana, con el trofeo.
static func _grid_banner(d: Variant, height: float) -> Button:
	var dark: bool = d.dark
	var ink: Color = d._c("ink")
	var has_player: bool = d._has_player()
	var mint: Array = d._tint("mint")
	var bg := Color("e3f0e6") if not dark else Color("e6f1e7") * NIGHT_BANNER
	bg.a = 1.0
	var action := Callable(d, "_open_day") if has_player else Callable(d, "_open_experience")
	var banner := _card(_box(bg, u(18.0), Color(1, 1, 1, 0.92 if not dark else 0.08), 3, Color(0.31, 0.55, 0.39, 0.16) if not dark else d._c("shadow"), 20, 8.0), action, "Reto de la semana", height)
	var clip := _panel(_box(bg, u(17.0)))
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	banner.add_child(_fill(clip, 3.0, 3.0, 3.0, 3.0))
	# Detrás del dibujo, el mismo degradado verde que trae su fondo.
	var field := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	var stops := [[0.0, "ddeedf"], [0.2, "e1eee4"], [0.4, "e6f1e7"], [0.6, "e8f2ea"], [1.0, "e6f1e7"]]
	g.set_offset(0, 0.0)
	g.set_offset(1, 1.0)
	g.set_color(0, Color(str(stops[0][1])))
	g.set_color(1, Color(str(stops[stops.size() - 1][1])))
	for i in range(1, stops.size() - 1):
		g.add_point(float(stops[i][0]), Color(str(stops[i][1])))
	grad.gradient = g
	grad.width = 128
	grad.height = 4
	field.texture = grad
	field.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field.stretch_mode = TextureRect.STRETCH_SCALE
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark:
		field.modulate = NIGHT_BANNER
	clip.add_child(_fill(field))
	var pic := TextureRect.new()
	pic.texture = art("desafio_trofeo")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var pic_h := height - 6.0
	pic.offset_left = -roundf(pic_h * 461.0 / 207.0)
	pic.offset_top = -pic_h
	if dark:
		pic.modulate = NIGHT_BANNER
	clip.add_child(pic)

	var row := _hbox(u(10.0))
	banner.add_child(_fill(row, u(12.0), 0.0, u(12.0), 0.0))
	var tile := _tile(d, "calendar", Color("5aa86a") if not dark else mint[1].darkened(0.35), Color.WHITE, u(40.0), u(23.0), u(12.0))
	row.add_child(tile)
	var words := _vbox(0.0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.custom_minimum_size = Vector2(u(150.0), 0.0)
	var text_w := u(150.0)
	var soft: Color = Color("35513f") if not dark else Color("d3e2d8")
	words.add_child(_fit(d, "Reto de la semana", u(16.0), ink, d.font_display, text_w))
	var value := 0.0
	var show_bar := false
	if has_player:
		var s: Dictionary = d._prog()
		var w: Dictionary = s["semana"]
		if str(w["familia"]) != "":
			var family := str(Assessment.FAMILY_NAME.get(str(w["familia"]), str(w["familia"])))
			words.add_child(_fit(d, family, u(12.5), soft, d.font_medium, text_w))
			var goal := maxi(int(w["meta"]), 1)
			var made := mini(int(w["hecho"]), goal)
			words.add_child(_fit(d, Loc.t("¡Cumplido!") if bool(w["completo"]) else Loc.t("%d de %d problemas resueltos") % [made, goal], u(12.5), soft, d.font_medium, text_w))
			value = float(made) / float(goal)
			show_bar = true
		else:
			words.add_child(_wrap(d, "Resuelve problemas esta semana.", u(12.5), soft, d.font_medium, 2, u(16.0)))
	else:
		words.add_child(_wrap(d, "Haz el test de nivel para empezar.", u(12.5), soft, d.font_medium, 2, u(16.0)))
	if show_bar:
		words.add_child(_gap(0.0, u(5.0)))
		var bar := _bar(Color(0.25, 0.51, 0.33, 0.22) if not dark else d._c("track"), Color("3f8253") if not dark else mint[1], value, u(5.0))
		bar.custom_minimum_size = Vector2(u(96.0), u(5.0))
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		words.add_child(bar)
	row.add_child(words)

	var arrow: TextureRect = d._icon("caret", u(14.0), ink)
	arrow.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	arrow.offset_left = -u(12.0) - u(14.0)
	arrow.offset_right = -u(12.0)
	arrow.offset_top = u(12.0)
	arrow.offset_bottom = u(12.0) + u(14.0)
	banner.add_child(arrow)
	var hand: Color = Color("1f2756") if not dark else Color("e6ecff")
	var nf := note_font(d)
	var script: bool = nf != d.font_medium
	var note := _vbox(0.0)
	# La nota no debe comerse la copa: si en un idioma sale larga, baja un poco de cuerpo.
	var cheer_fs := int(u(14.5 if script else 11.0))
	var cheer_low := int(float(cheer_fs) * 0.78)
	while cheer_fs > cheer_low and _text_w(nf, Loc.t("¡Tú puedes!"), cheer_fs) > u(64.0):
		cheer_fs -= 1
	var cheer: Label = d._text("¡Tú puedes!", cheer_fs, hand, nf)
	cheer.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	cheer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(cheer)
	var stroke := Swoosh.new()
	stroke.color = hand
	stroke.custom_minimum_size = Vector2(u(28.0), u(7.0))
	stroke.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(stroke)
	banner.add_child(note)
	cheer.custom_minimum_size = Vector2(ceilf(_text_w(nf, Loc.t("¡Tú puedes!"), cheer_fs)) + 2.0, u(15.0))
	var note_size := Vector2(cheer.custom_minimum_size.x, u(15.0) + u(7.0))
	note.size = note_size
	note.position = Vector2(1080.0 - u(28.0) - u(6.0) - note_size.x, height - u(14.0) - note_size.y)
	note.pivot_offset = note_size * 0.5
	note.rotation = deg_to_rad(-13.0)
	return banner


## Barra de secciones flotante: Inicio, Progreso, Mis partidas y Opciones.
static func _grid_nav(d: Variant, height: float) -> Control:
	var dark: bool = d.dark
	var paper: Color = d._c("surface")
	var lilac: Array = d._tint("lilac")
	var bar := _panel(_box(Color(paper.r, paper.g, paper.b, 0.92), u(20.0), Color(1, 1, 1, 1.0 if not dark else 0.08), 3, d._c("shadow"), 20, 8.0), Vector2(0.0, height))
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := _hbox(u(2.0))
	bar.add_child(_fill(row, u(6.0), u(5.0), u(6.0), u(5.0)))
	var progress_action := Callable(d, "_open_progress").bind("progress") if d._has_player() else Callable(d, "_open_experience")
	var defs := [
		["nav_home", "Inicio", Callable(), true],
		["nav_bars", "Progreso", progress_action, false],
		["nav_games", "Mis partidas", Callable(d, "_open_my_games_from").bind("home"), false],
		["nav_gear", "Opciones", Callable(d, "_open_options"), false],
	]
	var tab_w := (1080.0 - u(28.0) - u(12.0) - u(6.0)) / 4.0
	for def: Array in defs:
		var on := bool(def[3])
		var color: Color = (Color("4534c4") if not dark else lilac[1]) if on else (Color("3a3f5e") if not dark else d._c("quiet"))
		var tab := _card(_box((Color("eceafb") if not dark else lilac[0]) if on else Color(0, 0, 0, 0), u(15.0)), def[2], str(def[1]), 0.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := _vbox(u(2.0))
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		tab.add_child(_fill(column))
		var pic: TextureRect = d._icon(str(def[0]), u(21.0), color)
		column.add_child(pic)
		var label := _fit(d, str(def[1]), u(11.5), color, d.font_semibold if on else d.font_medium, tab_w - u(6.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		row.add_child(tab)
	return bar
