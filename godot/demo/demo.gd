extends Control
## Pantalla de problema de la app: problemas reales de Lichess sobre el tablero 3D, con su explicación.
## Todavía no es el entrenamiento completo (falta el test de nivel y la elección de problemas según el
## jugador), pero ya enseña lo que distingue a Chessome: cuando fallas, te explica qué tenía de bueno tu
## jugada y qué permite; cuando aciertas o pides la solución, por qué funciona, en cuatro niveles de
## profundidad. Las explicaciones vienen ya redactadas y verificadas (core/explain_data.gd).
## El estilo: aire de app móvil (letra grande, tonos pastel, iconos grandes y botones con su ilustración);
## ver docs/sistema-3d.md, «Diseño de la interfaz».
##
## Composición en un móvil alto: barra arriba, el tablero de lado a lado, debajo la tarjeta del entrenador
## (qué toca, qué ha pasado y la explicación, con desplazamiento si es larga) y, al pie, los botones, en la
## zona del pulgar. Las opciones no ocupan pantalla: se abren en una hoja inferior.

## STEP: se ha resuelto solo una jugada («Un paso») y se enseña su explicación; el jugador sigue con el resto.
enum Phase { INTRO, SOLVING, WRONG, REPLY, SOLVED, SHOWING, SHOWN, STEP }

const LIGHT := {
	"bg": Color("eaf1fb"), "surface": Color("ffffff"), "ink": Color("1b2540"), "quiet": Color("5b6782"),
	"accent": Color("ffa366"), "accent_ink": Color("1b2540"), "accent_text": Color("b84a0c"),
	"accent_soft": Color("ffe6d3"), "good": Color("1f7a44"), "bad": Color("c0392b"),
	"track": Color("c9d5e8"), "field": Color("eef3fb"), "scrim": Color(0.07, 0.1, 0.22, 0.42),
	"shadow": Color(0.16, 0.3, 0.6, 0.16), "sky": Color("cfe1fb"), "cloud": Color("f7fbff"),
	"glow": Color(1.0, 0.55, 0.25, 0.32),
	"wash_top": Color("dfe9ff"), "wash_mid": Color("efe9ff"), "wash_bottom": Color("fff2e8"),
}
const DARK := {
	"bg": Color("0a0f1e"), "surface": Color("161e38"), "ink": Color("edeff7"), "quiet": Color("a3acc4"),
	"accent": Color("ffa366"), "accent_ink": Color("1b2540"), "accent_text": Color("ffab73"),
	"accent_soft": Color("3a2416"), "good": Color("4cbf7a"), "bad": Color("ff7b7f"),
	"track": Color("2c3759"), "field": Color("1f2946"), "scrim": Color(0.0, 0.0, 0.03, 0.6),
	"shadow": Color(0.0, 0.0, 0.0, 0.36), "sky": Color("141d44"), "cloud": Color("f4e6b6"),
	"glow": Color(1.0, 0.5, 0.2, 0.22),
	"wash_top": Color("0d1330"), "wash_mid": Color("15173a"), "wash_bottom": Color("1c1530"),
}
## Tonos pastel para las teselas de los iconos y los botones ilustrados: [fondo, tinta].
const TINTS_LIGHT := {
	"peach": [Color("ffe3d3"), Color("d9591e")], "mint": [Color("dcf3e6"), Color("1b8a5a")],
	"lilac": [Color("e7e1fb"), Color("5b48c8")], "sky": [Color("d9e9ff"), Color("236fd1")],
	"butter": [Color("fff0c4"), Color("a86e00")], "rose": [Color("ffdde6"), Color("c93a6c")],
}
const TINTS_DARK := {
	"peach": [Color("472a1b"), Color("ffb48a")], "mint": [Color("173a2c"), Color("7fe0b0")],
	"lilac": [Color("2c2754"), Color("b9adff")], "sky": [Color("17304f"), Color("8fc2ff")],
	"butter": [Color("3f3312"), Color("ffd772")], "rose": [Color("47202f"), Color("ff9dbd")],
}
## Tamaños de letra, en unidades del lienzo (1080 de ancho). Un móvil corriente mide unos 393 puntos de
## ancho, así que un punto son unas 2,75 unidades: el cuerpo va a unos 15 puntos (antes iba a 12 y se leía
## pequeño en el teléfono).
const F_LARGE := 100
const F_TITLE := 66
const F_TITLE2 := 58
const F_HEAD := 46
const F_BODY := 42
const F_SUB := 38
const F_FOOT := 34
const F_CAP := 30
## Alto de la fila de botones del pie.
const BAR_HEIGHT := 142.0
## La vista 3D es algo más alta que el hueco del tablero y se funde con el fondo por arriba y por abajo:
## así caben la sombra del tablero y las cabezas de las piezas del fondo, y no se nota dónde acaba la vista.
const VIEW_BLEED_TOP := 64.0
const VIEW_BLEED_BOTTOM := 110.0
const VIEW_FADE := 48.0
## Alto mínimo que se reserva siempre a la tarjeta del entrenador. Lo que sobra por encima de lo que la
## tarjeta necesita en cada momento va de cielo, sobre el tablero (ver _card_room y _layout).
const CARD_MIN := 350.0
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
## Pista animada sobre el tablero: recuerda que se puede ampliar y girar. Viene activada y se apaga sola
## la primera vez que el jugador amplía, gira o desplaza el tablero (se puede volver a activar en Opciones).
var gesture_hint := true
## Pistas pedidas en la jugada actual: 0 ninguna, 1 el tema del problema, 2 además la pieza que hay que mover.
var hint_level := 0
## Posición tras la jugada que se resolvió con «Un paso» (para seguir desde ella).
var step_fen := ""

## Modo de la pantalla: "free" (los problemas en orden y sin nivel: es lo que usan las pruebas), "test" (test
## de nivel: un intento por problema y sin ayudas) o "train" (entrenamiento adaptado al nivel y al perfil).
var mode := "free"
## Lo que la evaluación sabe de cada problema (Assessment.item_of), en el orden de la lista, y dónde está cada id.
var pool: Array = []
var _index_of := {}
## El jugador: {rating, tries, done} (ver Assessment). Vacío hasta que hace el test o lo salta.
var player := {}
## Lo que dijo de su experiencia ("never", "rules", "casual" o "regular") y si saltó el test.
var experience := ""
var test_skipped := false
## El intento en curso: {item, t0, ms_first, fail_step, error, help, recorded} (ver _record).
var _try := {}
## Nivel antes y después del intento anotado en este problema (para enseñar el cambio al terminar).
var _rating_shown: Array = []
var _rng := RandomNumberGenerator.new()
const PLAYER_PATH := "user://chessome_jugador.json"
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
## Mientras se decide una misma jugada el tablero solo sube (cuando la explicación pide sitio); vuelve a bajar
## cuando toca la jugada siguiente o empieza otro problema. Así no se mueve bajo el dedo entre un intento y otro.
var _gap_limit := INF
## Alto de todo lo que no es tablero, cielo ni tarjeta (barra, botones y márgenes), según el último reparto.
var _fixed_height := 0.0
var _ai_status: Label
var _saved_anim := int(Board3D.Anim.FAST)
var _saved_lock := false

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
## Botones del pie. left_button es «Solución» (o «Repetir» al terminar); right_button, «Saltar» («Siguiente»
## al terminar, «Seguir» tras resolver un paso). hint_button y step_button solo existen mientras se resuelve.
var actions: HBoxContainer
var left_button: Button
var right_button: Button
var hint_button: Button
var step_button: Button
var pin_button: Button
var gesture_tip: GestureHint
var _actions_mode := ""
var _tip_note := false
var _tip_note_id := 0
var overlay: Control
## Zona desplazable de la hoja abierta (opciones o ayuda).
var sheet_scroll: ScrollContainer
var welcome: Control
## Página a pantalla completa abierta: la pregunta de experiencia ("experience"), el resultado del test
## ("result") o el progreso ("progress"). Y su zona desplazable.
var progress: Control
var progress_kind := ""
var progress_scroll: ScrollContainer
## Píldora de la barra con el nivel del jugador (solo en el entrenamiento): abre el progreso.
var level_pill: Button

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
	## Si es mayor que cero, los adornos no bajan de aquí (debajo va la pista de gestos).
	var ornament_bottom := -1.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), base)
		var fade_end := clampf(band_bottom, 0.0, size.y)
		if fade_end > 8.0:
			draw_polygon(
				PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, fade_end), Vector2(0.0, fade_end)]),
				PackedColorArray([top, top, base, base]))
		var band := (ornament_bottom if ornament_bottom > 0.0 else band_bottom) - band_top
		if band < 200.0:
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


## Fondo de la bienvenida: un degradado pastel de arriba abajo con unas manchas de color muy suaves.
class PastelBackdrop extends Control:
	var top := Color.WHITE
	var mid := Color.WHITE
	var bottom := Color.WHITE
	## Manchas: [centro (0–1, 0–1), radio (en anchos de pantalla), color].
	var blobs: Array = []

	func _draw() -> void:
		var h := size.y * 0.5
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, h), Vector2(0.0, h)]),
			PackedColorArray([top, top, mid, mid]))
		draw_polygon(
			PackedVector2Array([Vector2(0.0, h), Vector2(size.x, h), Vector2(size.x, size.y), Vector2(0.0, size.y)]),
			PackedColorArray([mid, mid, bottom, bottom]))
		for blob: Array in blobs:
			var c := Vector2(float(blob[0].x) * size.x, float(blob[0].y) * size.y)
			var r := float(blob[1]) * size.x
			var inner: Color = blob[2]
			var outer := Color(inner.r, inner.g, inner.b, 0.0)
			# Abanico de triángulos: opaco en el centro y transparente en el borde.
			var steps := 40
			for i in steps:
				var a0 := TAU * float(i) / float(steps)
				var a1 := TAU * float(i + 1) / float(steps)
				draw_polygon(
					PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]),
					PackedColorArray([inner, outer, outer]))


## Pista animada sobre el tablero: dos dedos que primero se separan (el tablero crece) y luego giran (el
## tablero gira con ellos), junto a un texto. También sirve para avisos breves (por ejemplo, al fijar el giro).
class GestureHint extends Control:
	var paper := Color.WHITE
	var ink := Color.BLACK
	var quiet := Color.GRAY
	var accent := Color.ORANGE
	var board_light := Color.WHITE
	var board_dark := Color.GRAY
	var shadow := Color(0, 0, 0, 0.2)
	var font: Font
	var font_size := 34
	var text := ""
	## Con true se dibuja la animación de los dedos; con false, solo el texto (un aviso).
	var animated := true
	var _t := 0.0

	const ANIM_W := 150.0
	const PAD := 26.0

	func fit() -> void:
		var w := PAD * 2.0
		if animated:
			w += ANIM_W + 8.0
		if font != null and text != "":
			w += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		custom_minimum_size = Vector2(w, 124.0)
		size = custom_minimum_size

	func _process(delta: float) -> void:
		if visible and animated:
			_t = fmod(_t + delta, 4.4)
			queue_redraw()

	func _draw() -> void:
		var pill := StyleBoxFlat.new()
		pill.bg_color = paper
		pill.set_corner_radius_all(int(size.y * 0.5))
		pill.shadow_color = shadow
		pill.shadow_size = 18
		pill.shadow_offset = Vector2(0.0, 6.0)
		draw_style_box(pill, Rect2(Vector2.ZERO, size))
		var x := PAD
		if animated:
			_draw_gesture(Vector2(x + ANIM_W * 0.5, size.y * 0.5))
			x += ANIM_W + 8.0
		if font != null and text != "":
			var ascent := font.get_ascent(font_size)
			var descent := font.get_descent(font_size)
			draw_string(font, Vector2(x, (size.y + ascent - descent) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, ink)

	func _draw_gesture(c: Vector2) -> void:
		# Dos tiempos: ampliar (0–1,9 s) y girar (2,2–4,1 s), con una pausa entre ellos.
		var grow := 0.0
		var turn := 0.0
		if _t < 1.9:
			grow = sin(PI * _t / 1.9)
		elif _t >= 2.2 and _t < 4.1:
			turn = sin(PI * (_t - 2.2) / 1.9)
		grow = grow * grow
		turn = turn * turn
		var k := 1.0 + 0.36 * grow
		var angle := deg_to_rad(36.0) * turn
		# El tablerito: cuatro casillas, que crecen y giran con los dedos.
		draw_set_transform(c, angle, Vector2(k, k))
		var half := 25.0
		var frame := StyleBoxFlat.new()
		frame.bg_color = board_dark
		frame.set_corner_radius_all(7)
		draw_style_box(frame, Rect2(Vector2(-half - 3.0, -half - 3.0), Vector2(half * 2.0 + 6.0, half * 2.0 + 6.0)))
		draw_rect(Rect2(Vector2(-half, -half), Vector2(half, half)), board_light)
		draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(half, half)), board_light)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Los dos dedos, en diagonal: se separan al ampliar y giran alrededor del centro al girar.
		var reach := 34.0 + 22.0 * grow
		var base := deg_to_rad(-40.0) + angle
		for side: float in [-1.0, 1.0]:
			var p := c + Vector2(cos(base), sin(base)) * reach * side
			draw_circle(p, 15.0, Color(accent.r, accent.g, accent.b, 0.28), true, -1.0, true)
			draw_circle(p, 9.5, accent, true, -1.0, true)


## Muestra de un acabado: una pieza clara y otra oscura, como dos discos que se solapan.
class SwatchMark extends Control:
	var light := Color.WHITE
	var dark := Color.BLACK
	var rim := Color(0, 0, 0, 0.18)

	func _draw() -> void:
		var r := minf(size.y * 0.5 - 3.0, size.x * 0.3)
		var c := size * 0.5
		for def: Array in [[c + Vector2(r * 0.55, 0.0), dark], [c - Vector2(r * 0.55, 0.0), light]]:
			draw_circle(def[0], r + 3.0, rim, true, -1.0, true)
			draw_circle(def[0], r, def[1], true, -1.0, true)


## Marca del turno: un peón pequeño con el color del bando que juega.
class TurnMark extends Control:
	var fill := Color.WHITE
	var line := Color.BLACK
	var k := 1.0

	func _draw() -> void:
		draw_set_transform(Vector2((size.x - 40.0 * k) * 0.5, (size.y - 44.0 * k) * 0.5), 0.0, Vector2(k, k))
		var o := Vector2.ZERO
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
		var d := size.y - 14.0
		var knob := StyleBoxFlat.new()
		knob.bg_color = knob_color
		knob.set_corner_radius_all(int(d * 0.5))
		var x := (size.x - d - 7.0) if on else 7.0
		draw_style_box(knob, Rect2(Vector2(x, 7.0), Vector2(d, d)))


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
	view.view_gesture.connect(_on_view_gesture)
	add_child(view)
	view.set_piece_set(piece_set)
	view.set_sound_enabled(sound_on)
	view.set_view_locked(_saved_lock)
	view.board.anim_mode = _saved_anim as Board3D.Anim

	_rng.randomize()
	_build_chrome()
	resized.connect(_layout)
	if not use_settings:
		# Sin jugador (las pruebas): los problemas en orden.
		_start(0)
		return
	_load_player()
	if _has_player():
		# Vuelve por donde iba: a medio test o entrenando.
		if bool(player.get("done", false)):
			mode = "train"
			_next_training()
		else:
			mode = "test"
			_next_test()
	else:
		_idle()
		if welcome_seen:
			_open_experience()
		else:
			_open_welcome()


func _notification(what: int) -> void:
	# El botón «atrás» de Android cierra lo que haya abierto encima de la pantalla.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if welcome != null and is_instance_valid(welcome):
			_close_welcome()
		elif progress != null and is_instance_valid(progress):
			_leave_progress()
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
	pool = []
	_index_of = {}
	for i in puzzles.size():
		var item := Assessment.item_of(puzzles[i])
		pool.append(item)
		_index_of[item["id"]] = i


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
	gesture_hint = bool(cfg.get_value("vista", "pista_de_gestos", gesture_hint))
	_saved_lock = bool(cfg.get_value("vista", "giro_fijado", false))
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
	cfg.set_value("vista", "pista_de_gestos", gesture_hint)
	cfg.set_value("vista", "giro_fijado", view.view_locked if view != null else _saved_lock)
	cfg.save(SETTINGS_PATH)


# ---------------------------------------------------------------- el jugador

func _has_player() -> bool:
	return player.has("rating")


func _load_player() -> void:
	if not FileAccess.file_exists(PLAYER_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAYER_PATH))
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("rating")) != TYPE_DICTIONARY or typeof(data.get("tries")) != TYPE_ARRAY:
		return
	var rating: Dictionary = data["rating"]
	if not (rating.has("r") and rating.has("rd") and rating.has("vol")):
		return
	player = {"rating": rating, "tries": data["tries"], "done": bool(data.get("done", false))}
	experience = str(data.get("experience", ""))
	test_skipped = bool(data.get("skipped", false))


func _save_player() -> void:
	if not use_settings or not _has_player():
		return
	var file := FileAccess.open(PLAYER_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": 1, "experience": experience, "skipped": test_skipped, "rating": player["rating"], "tries": player["tries"], "done": bool(player.get("done", false))}))
	file.close()


## Problemas del test ya contestados.
func _test_count() -> int:
	var n := 0
	for t: Dictionary in player.get("tries", []):
		if str(t.get("phase", "")) == "test":
			n += 1
	return n


# ---------------------------------------------------------------- piezas de la interfaz

func _c(key: String) -> Color:
	var palette: Dictionary = DARK if dark else LIGHT
	return palette[key]


## Tono pastel por su nombre: [fondo, tinta].
func _tint(tint_name: String) -> Array:
	var tints: Dictionary = TINTS_DARK if dark else TINTS_LIGHT
	return tints.get(tint_name, tints["peach"])


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


func _style_button(b: Button, fill: Color, fg: Color, radius: int, font_size: int, font: Font, glow: Color = Color(0, 0, 0, 0), border: Color = Color(0, 0, 0, 0)) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill.darkened(0.08) if state == "pressed" else fill
		sb.set_corner_radius_all(radius)
		sb.content_margin_left = 26.0
		sb.content_margin_right = 26.0
		sb.content_margin_top = 16.0
		sb.content_margin_bottom = 16.0
		if border.a > 0.0:
			sb.border_color = border
			sb.set_border_width_all(5)
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


## Icono de la interfaz (ver UiIcons), con el color que se le pida.
func _icon(icon_name: String, side: float, color: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiIcons.texture(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(side, side)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Tesela pastel con un icono grande dentro.
func _icon_tile(icon_name: String, tint_name: String, side: float, icon_side: float) -> PanelContainer:
	var colors := _tint(tint_name)
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = colors[0]
	sb.set_corner_radius_all(int(side * 0.3))
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(side, side)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(_icon(icon_name, icon_side, colors[1]))
	return tile


## Botón ilustrado: icono y texto, en fila o (vertical = true) con el icono encima. Deja pasar el arrastre:
## si el dedo empieza encima, la lista de debajo se desplaza igual. Opciones: font_size, icon (lado del
## icono), vertical, trailing (icono detrás del texto), radius, height, glow, border, font, icon_color, wrap.
func _button(icon_name: String, text: String, on_press: Callable, fill: Color, fg: Color, opt: Dictionary = {}) -> Button:
	var vertical := bool(opt.get("vertical", false))
	var font_size := int(opt.get("font_size", F_BODY))
	var height := float(opt.get("height", 112.0))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(on_press)
	_style_button(b, fill, fg, int(opt.get("radius", 40 if vertical else int(height * 0.5))), font_size, font_semibold, opt.get("glow", Color(0, 0, 0, 0)), opt.get("border", Color(0, 0, 0, 0)))
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4 if vertical else 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(box)
	var label: Label = null
	if text != "":
		label = Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", fg)
		var font: Font = opt.get("font", font_semibold)
		if font != null:
			label.add_theme_font_override("font", font)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(opt.get("wrap", false)):
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_constant_override("line_spacing", -2)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var picture: TextureRect = null
	if icon_name != "":
		picture = _icon(icon_name, float(opt.get("icon", 52.0)), opt.get("icon_color", fg))
	if bool(opt.get("trailing", false)):
		if label != null:
			box.add_child(label)
		if picture != null:
			box.add_child(picture)
	else:
		if picture != null:
			box.add_child(picture)
		if label != null:
			box.add_child(label)
	b.set_meta("label", text)
	b.set_meta("label_node", label)
	# Un botón no mide a sus hijos: su tamaño mínimo se le da a mano, el del contenido más el relleno.
	var pad_x := float(opt.get("pad_x", 22.0 if vertical else 40.0))
	var fit := func() -> void:
		if is_instance_valid(b) and is_instance_valid(box):
			var need := box.get_combined_minimum_size()
			b.custom_minimum_size = Vector2(need.x + pad_x * 2.0, maxf(height, need.y + 24.0))
	box.minimum_size_changed.connect(fit)
	fit.call()
	return b


## Texto de un botón ilustrado (lo usan las pruebas).
func button_label(b: Button) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	return str(b.get_meta("label", b.text))


## Botón de texto (con icono opcional) dentro de la tarjeta.
func _card_button(text: String, on_press: Callable, fill: Color, fg: Color, font_size: int = F_SUB, icon_name: String = "") -> Button:
	return _button(icon_name, text, on_press, fill, fg, {"font_size": font_size, "height": 100.0, "icon": 48.0})


## Botón redondo con un icono.
func _round_button(icon_name: String, on_press: Callable, side: float = 112.0, fill: Variant = null, fg: Variant = null, with_shadow: bool = true) -> Button:
	var paper: Color = _c("surface") if fill == null else fill
	var tone: Color = _c("ink") if fg == null else fg
	var b := _button(icon_name, "", on_press, paper, tone, {"height": side, "icon": side * 0.54, "pad_x": side * 0.23, "radius": int(side * 0.5), "glow": _c("shadow") if with_shadow else Color(0, 0, 0, 0)})
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b


## Etiqueta en forma de píldora.
func _chip(text: String, fill: Color, fg: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", F_CAP + 2)
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
	l.add_theme_constant_override("line_spacing", 8)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


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
	if gesture_tip != null and is_instance_valid(gesture_tip):
		gesture_tip.queue_free()
	var th := Theme.new()
	if font_regular != null:
		th.default_font = font_regular
	th.default_font_size = F_BODY
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

	# Barra superior: contador y botones redondos (chincheta del giro, vista y opciones).
	# En pantalla completa la zona de la barra de estado sigue teniendo la cámara y los avisos del sistema:
	# se deja siempre un margen arriba, aunque el sistema no informe de ninguno.
	chrome.add_child(_spacer(maxf(inset.x, 60.0) + 18.0))
	var bar_pad := _pad(40, 0, 36, 0)
	chrome.add_child(bar_pad)
	bar_row = bar_pad
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_pad.add_child(bar)
	var lilac := _tint("lilac")
	level_pill = _button("cap", "Nivel", _open_progress.bind("progress"), lilac[0], lilac[1], {"font_size": F_SUB, "height": 100.0, "icon": 54.0, "pad_x": 30.0})
	level_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	level_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_pill.visible = false
	bar.add_child(level_pill)
	counter = _text("", F_SUB, _c("quiet"), font_medium)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(counter)
	pin_button = _pin_button()
	bar.add_child(pin_button)
	bar.add_child(_round_button("view", _on_toggle_view))
	bar.add_child(_round_button("sliders", _open_options))

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
	card_style.set_corner_radius_all(52)
	card_style.content_margin_left = 42.0
	card_style.content_margin_right = 28.0
	card_style.content_margin_top = 32.0
	card_style.content_margin_bottom = 32.0
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
	card_body.add_theme_constant_override("separation", 16)
	card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.minimum_size_changed.connect(_fit_card)
	body_pad.add_child(card_body)

	chrome.add_child(_spacer(26.0))

	# Acciones, abajo: los botones cambian con la fase del problema (ver _build_actions).
	var actions_pad := _pad(32, 0, 32, 0)
	chrome.add_child(actions_pad)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions_pad.add_child(actions)
	_actions_mode = ""
	chrome.add_child(_spacer(inset.y + 34.0))

	# Pista de gestos, sobre el tablero (ver _place_tip).
	gesture_tip = GestureHint.new()
	gesture_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gesture_tip.paper = _c("surface")
	gesture_tip.ink = _c("ink")
	gesture_tip.accent = _c("accent_text")
	gesture_tip.board_light = Color("f3ead8")
	gesture_tip.board_dark = Color("a97f5f")
	gesture_tip.shadow = _c("shadow")
	gesture_tip.font = font_medium
	gesture_tip.font_size = F_SUB
	gesture_tip.text = "Amplía y gira con dos dedos"
	gesture_tip.visible = false
	gesture_tip.fit()
	add_child(gesture_tip)

	_refresh(false)
	_place_board.call_deferred()
	if sheet_kind == "options":
		_build_sheet()
	elif sheet_kind == "ai":
		_build_ai_sheet()


## Chincheta de la barra: fija el giro del tablero (ni los dedos ni el móvil lo giran) o lo vuelve a soltar.
func _pin_button() -> Button:
	var locked := view.view_locked
	var tint := _tint("peach")
	if locked:
		return _round_button("pin_on", _on_toggle_pin, 112.0, tint[0], tint[1])
	return _round_button("pin", _on_toggle_pin)


func _on_toggle_pin() -> void:
	_set_lock(not view.view_locked)
	_note("Giro fijado" if view.view_locked else "Giro libre")


## Aviso breve en el hueco de encima del tablero.
func _note(text: String) -> void:
	if gesture_tip == null or not is_instance_valid(gesture_tip):
		return
	_tip_note_id += 1
	var my_note := _tip_note_id
	gesture_tip.animated = false
	gesture_tip.text = text
	gesture_tip.fit()
	_tip_note = true
	_place_tip()
	await _wait(1.7)
	if my_note != _tip_note_id or not is_instance_valid(gesture_tip):
		return
	_tip_note = false
	gesture_tip.animated = true
	gesture_tip.text = "Amplía y gira con dos dedos"
	gesture_tip.fit()
	_place_tip()


## El jugador ha ampliado, girado o desplazado el tablero: ya sabe hacerlo y la pista sobra.
func _on_view_gesture(_kind: String) -> void:
	if not gesture_hint:
		return
	gesture_hint = false
	_save_settings()
	_place_tip()
	_sync_sheet()


## Coloca la pista de gestos (o el aviso) en el hueco entre la barra y el tablero, si cabe.
func _place_tip() -> void:
	if gesture_tip == null or not is_instance_valid(gesture_tip) or board_slot == null or not is_instance_valid(board_slot):
		return
	var slot_top := board_slot.get_global_rect().position.y
	var bar_bottom := bar_row.get_global_rect().end.y if bar_row != null and is_instance_valid(bar_row) else 0.0
	var room := slot_top - bar_bottom
	var fits := room >= gesture_tip.size.y + 56.0
	gesture_tip.visible = _tip_note or (gesture_hint and not view.view_locked and welcome == null and progress == null and fits)
	var y := slot_top - gesture_tip.size.y - 34.0
	if not fits:
		y = bar_bottom + 14.0
	gesture_tip.position = Vector2((size.x - gesture_tip.size.x) * 0.5, y)
	# Las nubes (o la luna) se quedan por encima de la pista.
	bg.ornament_bottom = gesture_tip.position.y - 12.0 if gesture_tip.visible and fits else -1.0
	bg.queue_redraw()


## Sitio que pide la tarjeta según lo que enseña: poco mientras se resuelve, más con la explicación de un
## fallo o de la solución, y todo el que haya cuando se profundiza o se prueban otras jugadas.
func _card_room() -> float:
	var e := _shown_exp()
	if whatif or (not e.is_empty() and not exp_partial and exp_level >= 2):
		return INF
	if not e.is_empty():
		return 900.0 if exp_partial else 980.0
	return CARD_MIN + 60.0 + (170.0 if hint_level > 0 else 0.0)


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
	var gap := minf(maxf(0.0, (free - _card_room()) * 0.86), _gap_limit)
	_gap_limit = gap
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
	var room := get_viewport_rect().size.y - _fixed_height - board_slot.custom_minimum_size.y - top_gap.custom_minimum_size.y - 20.0 - 64.0
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
	_place_tip()


# ---------------------------------------------------------------- tarjeta del entrenador

## Explicación que toca enseñar ahora ({} si ninguna) y a qué nivel.
func _shown_exp() -> Dictionary:
	if whatif:
		return whatif_exp
	if phase == Phase.WRONG or phase == Phase.SOLVED or phase == Phase.SHOWN or phase == Phase.STEP:
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
	level_pill.visible = mode == "train" and _has_player()
	if level_pill.visible:
		(level_pill.get_meta("label_node") as Label).text = "Nivel %d" % int(round(float(player["rating"]["r"])))
		counter.text = ""
	elif mode == "test":
		var answered := not _try.is_empty() and bool(_try.get("recorded", false))
		counter.text = "Test de nivel · problema %d" % (_test_count() + (0 if answered else 1))
	else:
		counter.text = ("Problema %d de %d" % [index + 1, total]) if total > 0 else "Sin problemas"
	_build_card()
	_build_actions()
	_layout(animate)


## Botones del pie. Mientras se resuelve: Pista, Un paso, Solución y Saltar. Tras resolver un paso: Solución y
## Seguir. Con el problema terminado: Repetir y Siguiente (el color pleno solo aparece cuando toca avanzar).
## En el test de nivel no hay ayudas: «No lo sé» mientras se resuelve y «Siguiente» al terminar cada problema.
func _build_actions() -> void:
	if actions == null or not is_instance_valid(actions):
		return
	var done := phase == Phase.SOLVED or phase == Phase.SHOWN
	var kind := "done" if done else ("step" if phase == Phase.STEP else "solve")
	var last_test := mode == "test" and done and bool(player.get("done", false))
	var key := "%s:%s:%s" % [mode, kind, str(last_test)]
	var can_help := phase == Phase.SOLVING or phase == Phase.WRONG
	if key != _actions_mode:
		_actions_mode = key
		for old in actions.get_children():
			(old as CanvasItem).visible = false
			old.queue_free()
		hint_button = null
		step_button = null
		var wide := {"font_size": F_BODY, "height": BAR_HEIGHT, "icon": 56.0, "radius": 60}
		var go := wide.duplicate()
		go["glow"] = _c("glow")
		go["trailing"] = true
		var row: Array[Button] = []
		if mode == "test":
			if kind == "solve":
				var quiet := wide.duplicate()
				quiet["glow"] = _c("shadow")
				left_button = _button("why", "No lo sé", _on_left, _c("surface"), _c("ink"), quiet)
			else:
				left_button = _button("next", "Ver mi nivel" if last_test else "Siguiente", _on_right, _c("accent"), _c("accent_ink"), go)
			right_button = left_button
			row = [left_button]
		elif kind == "solve":
			hint_button = _tool_button("bulb", "Pista", _on_hint, "butter")
			step_button = _tool_button("step", "Un paso", _on_step, "mint")
			left_button = _tool_button("eye", "Solución", _on_left, "lilac")
			right_button = _tool_button("skip", "Saltar", _on_right, "sky")
			row = [hint_button, step_button, left_button, right_button]
		else:
			if kind == "done":
				left_button = _button("retry", "Repetir", _on_left, _c("accent_soft"), _c("accent_text"), wide)
			else:
				left_button = _button("eye", "Solución", _on_left, _c("accent_soft"), _c("accent_text"), wide)
			right_button = _button("next", "Siguiente" if kind == "done" else "Seguir", _on_right, _c("accent"), _c("accent_ink"), go)
			row = [left_button, right_button]
		for b: Button in row:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(b)
	# La pista y el paso solo tienen sentido cuando le toca jugar al jugador.
	for b: Button in [hint_button, step_button]:
		if b != null and is_instance_valid(b):
			b.disabled = not can_help
			b.modulate.a = 1.0 if can_help else 0.42
	if kind == "solve" and left_button != null and is_instance_valid(left_button):
		var can_show := phase != Phase.INTRO and phase != Phase.SHOWING
		if mode == "test":
			can_show = phase == Phase.SOLVING
		left_button.disabled = not can_show
		left_button.modulate.a = 1.0 if can_show else 0.42


## Botón de la barra de ayuda: una tesela pastel con su icono grande y el nombre debajo.
func _tool_button(icon_name: String, text: String, on_press: Callable, tint_name: String) -> Button:
	var tint := _tint(tint_name)
	var b := _button(icon_name, text, on_press, tint[0], _c("ink"), {"vertical": true, "font_size": F_FOOT, "height": BAR_HEIGHT, "icon": 62.0, "radius": 44, "icon_color": tint[1], "pad_x": 8.0})
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


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
			if mode == "test" and ask_step <= 1:
				sub = "Encuentra la mejor jugada. Solo hay un intento."
			show_dot = true
		Phase.WRONG:
			head = "No es la mejor"
			sub = "Vuelve a intentarlo."
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
		Phase.STEP:
			head = "Este paso"
			sub = "Pulsa «Seguir» y continúa tú."
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
	title_row.add_theme_constant_override("separation", 20)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_body.add_child(title_row)
	turn_dot = TurnMark.new()
	turn_dot.k = 1.3
	turn_dot.custom_minimum_size = Vector2(60.0, 64.0)
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
	title = _para(head, F_TITLE2 if not e.is_empty() or whatif else F_TITLE, tone, font_display)
	title.add_theme_constant_override("line_spacing", 0)
	title_row.add_child(title)

	if whatif:
		_add_whatif(e)
	elif not e.is_empty():
		_add_explanation(e, exp_level, exp_partial)
		if mode == "test":
			# El test es breve: la explicación a fondo llega después, en el entrenamiento.
			if done and not bool(e.get("correct", false)):
				card_body.add_child(_para("Lo repasaremos con calma en el entrenamiento.", F_SUB, _c("quiet"), font_regular))
		elif done:
			_add_tools()
		elif phase == Phase.STEP:
			card_body.add_child(_para("Pulsa «Seguir» y continúa tú con el resto.", F_SUB, _c("quiet"), font_regular))
	else:
		card_body.add_child(_para(sub, F_BODY, _c("quiet"), font_regular))
	if hint_level > 0 and not whatif and (phase == Phase.SOLVING or phase == Phase.WRONG):
		card_body.add_child(_hint_block())

	# Ficha del problema. El tema es una pista: solo se enseña cuando ya está resuelto o mostrado.
	# Con una explicación o una pista a la vista no se repite: el sitio es para ellas.
	if total > 0 and not whatif and (done or (e.is_empty() and hint_level == 0)):
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 12)
		chips.add_theme_constant_override("v_separation", 10)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if done and theme_name != "":
			chips.add_child(_chip(theme_name, _c("accent_soft"), _c("accent_text")))
		if mode == "test":
			# En el test no se enseña la dificultad: no hay que saber por dónde va la estimación.
			chips.add_child(_chip("Test de nivel", _c("field"), _c("ink")))
		else:
			if done and _rating_shown.size() == 2:
				var up := float(_rating_shown[1]) >= float(_rating_shown[0])
				var chip_tint := _tint("mint" if up else "peach")
				chips.add_child(_chip("Nivel %d → %d" % [int(round(float(_rating_shown[0]))), int(round(float(_rating_shown[1])))], chip_tint[0], chip_tint[1]))
			chips.add_child(_chip("Dificultad %d" % rating, _c("field"), _c("ink")))
			chips.add_child(_chip("Problema real de Lichess", _c("field"), _c("quiet")))
		var chips_pad := _pad(0, 8, 0, 0)
		chips_pad.add_child(chips)
		card_body.add_child(chips_pad)

	_fit_card.call_deferred()
	card_scroll.set_deferred("scroll_vertical", scroll_to)


func _section(text: String) -> MarginContainer:
	var m := _pad(0, 14, 0, 0)
	m.add_child(_text(text.to_upper(), F_CAP, _c("quiet"), font_semibold))
	return m


## Fila con una tesela de icono a la izquierda y texto a la derecha.
func _icon_row(icon_name: String, tint_name: String, heading: String, text: String, side: float = 92.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := _icon_tile(icon_name, tint_name, side, side * 0.6)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading != "":
		texts.add_child(_para(heading, F_BODY, _c("ink"), font_semibold))
	if text != "":
		texts.add_child(_para(text, F_SUB, _c("ink") if heading == "" else _c("quiet"), font_regular))
	row.add_child(texts)
	return row


## Pista de la jugada: primero el tema del problema; después, además, qué pieza hay que mover.
func _hint_block() -> PanelContainer:
	var paper: Color = _tint("butter")[0]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.6)
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_name := _hint_theme()
	var lines := PackedStringArray()
	if theme_name != "":
		lines.append("Busca esto: %s." % theme_name.to_lower())
	if hint_level >= 2 or theme_name == "":
		lines.append("Mueve %s." % _hint_piece())
	panel.add_child(_icon_row("bulb", "butter", "Pista", " ".join(lines), 84.0))
	return panel


## Tema del problema, si sirve de pista ("" si no dice nada sobre qué buscar).
func _hint_theme() -> String:
	var theme_name := str(puzzle.get("theme", ""))
	return "" if theme_name.begins_with("Ventaja") else theme_name


## «la torre de d1»: la pieza de la jugada que toca.
func _hint_piece() -> String:
	var moves: Array = puzzle.get("moves", [])
	if ask_step < 1 or ask_step >= moves.size() or fen_before == "":
		return "otra pieza"
	var from := Chess.sq_index(str(moves[ask_step]).substr(0, 2))
	var names := ["", "el peón", "el caballo", "el alfil", "la torre", "la dama", "el rey"]
	var piece := Chess.type_of(Chess.from_fen(fen_before).b[from])
	return "%s de %s" % [names[clampi(piece, 0, 6)], Chess.sq_name(from)]


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
		card_body.add_child(_para(str(first[i]), F_BODY, _c("ink"), font_regular))
	if mode == "test":
		return
	var lines: Array = (levels[2] as Dictionary)["lines"]
	if partial:
		# Lo que pasaría tras la jugada, para verlo en el tablero.
		for line: Dictionary in lines:
			if str(line.get("tone", "")) == "bad":
				card_body.add_child(_line_block(line, "Qué pasaría"))
		if hint_level == 0:
			card_body.add_child(_para("Prueba otra jugada. Si te atascas, pide una pista o que resuelva solo este paso.", F_SUB, _c("quiet"), font_regular))
		return
	if level >= 2:
		var concept: Dictionary = levels[1]
		card_body.add_child(_section(str(concept["title"])))
		for text: Variant in concept["paragraphs"]:
			card_body.add_child(_para(str(text), F_BODY, _c("ink"), font_regular))
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
			card_body.add_child(_para(str(text), F_FOOT, _c("quiet"), font_regular))
	if level < 4:
		var tint := _tint("lilac")
		var why := _button(["why", "line", "chart"][level - 1], str(WHY_LABELS[level]), _on_why, tint[0], tint[1], {"font_size": F_BODY, "height": 116.0, "icon": 60.0})
		var why_pad := _pad(0, 8, 0, 0)
		why_pad.add_child(why)
		card_body.add_child(why_pad)
	if level >= 4:
		# Solo al fondo del todo, para quien quiera comprobarlo: de dónde sale cada dato.
		var facts: Array = e.get("facts", [])
		var toggle := _card_button("Datos de la posición" if not facts_open else "Ocultar los datos", _on_toggle_facts, _c("field"), _c("quiet"), F_FOOT, "info")
		card_body.add_child(toggle)
		if facts_open:
			for fact: Array in facts:
				var source := str(SOURCE_NAMES.get(str(fact[0]), str(fact[0])))
				card_body.add_child(_para("%s · %s" % [source, str(fact[1])], F_FOOT, _c("quiet"), font_regular))


## Una variante con sus botones para verla jugada a jugada en el tablero.
func _line_block(line: Dictionary, label: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var good := str(line.get("tone", "")) == "good"
	box.add_child(_para(label, F_SUB, _c("good") if good else _c("bad"), font_semibold))
	box.add_child(_para(str(line.get("text", "")), F_SUB, _c("ink"), font_medium))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var active := not line_on.is_empty() and line_on == line
	var ucis: Array = line.get("ucis", [])
	var steps := [["first", -1], ["prev", maxi(-1, line_ply - 1) if active else -1], ["play", mini(ucis.size() - 1, line_ply + 1) if active else 0]]
	for step_def: Array in steps:
		var kind := str(step_def[0])
		var b := _round_button("play" if kind == "prev" else kind, _step_line.bind(line, int(step_def[1])), 96.0, _c("field"), _c("ink"), false)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		if kind == "prev":
			# El mismo triángulo de «siguiente», mirando al otro lado.
			for child in b.get_child(0).get_children():
				if child is TextureRect:
					(child as TextureRect).flip_h = true
		row.add_child(b)
	if active:
		var where := "inicio" if line_ply < 0 else "%d de %d" % [line_ply + 1, ucis.size()]
		var mark := _text(where, F_FOOT, _c("quiet"), font_medium)
		mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(mark)
		var back := _button("back", "Volver", _leave_line, _c("accent_soft"), _c("accent_text"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0})
		row.add_child(back)
	box.add_child(row)
	return box


## Fila de la tabla del motor: etiqueta, jugada, evaluación y profundidad; debajo, la continuación.
func _engine_row(row: PackedStringArray) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_para("%s · %s · %s · prof. %s" % [row[0], row[1], row[2], row[3]], F_SUB, _c("ink"), font_medium))
	box.add_child(_para(row[4], F_FOOT, _c("quiet"), font_regular))
	return box


## Ayudas de después del problema: probar otra jugada, analizar en Lichess y preguntar a una IA.
## Tres teselas ilustradas, una al lado de otra.
func _add_tools() -> void:
	if explain == null or not explain.ok:
		return
	card_body.add_child(_section("Más ayuda"))
	card_body.add_child(_tool_tiles([
		["whatif", "¿Y si juego…?", _toggle_whatif, "sky"],
		["search", "Analizar en Lichess", _open_lichess, "mint"],
		["spark", "Pregunta a una IA", _open_ai, "rose"],
	]))


func _tool_tiles(defs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for def: Array in defs:
		var tint := _tint(str(def[3]))
		var b := _button(str(def[0]), str(def[1]), def[2], tint[0], _c("ink"), {"vertical": true, "wrap": true, "font_size": F_FOOT, "height": 214.0, "icon": 76.0, "radius": 44, "icon_color": tint[1], "pad_x": 10.0, "font": font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


func _add_whatif(e: Dictionary) -> void:
	if e.is_empty():
		var fen := _decision_fen()
		var side := "blancas" if fen != "" and Chess.from_fen(fen).turn == 0 else "negras"
		card_body.add_child(_para("Mueve cualquier pieza de las %s y te explico qué pasaría con esa jugada." % side, F_BODY, _c("ink"), font_regular))
	else:
		card_body.add_child(_para("Probando %s" % str(e.get("san", "")), F_SUB, _c("quiet"), font_semibold))
		_add_explanation(e, whatif_level, false)
		card_body.add_child(_para("Prueba otra jugada en el tablero o vuelve a la explicación.", F_SUB, _c("quiet"), font_regular))
	var back := _card_button("Volver a la explicación", _toggle_whatif, _c("field"), _c("ink"), F_SUB, "back")
	card_body.add_child(back)
	if not e.is_empty():
		card_body.add_child(_tool_tiles([
			["search", "Analizar en Lichess", _open_lichess, "mint"],
			["spark", "Pregunta a una IA", _open_ai, "rose"],
		]))


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
		_ai_status.visible = true


## Abre la búsqueda de Google en Modo IA con la pregunta. El parámetro udm=50 no está documentado por Google
## (lo han observado terceros): si deja de funcionar, la búsqueda se abre en modo normal.
func _open_google_ai() -> void:
	OS.shell_open("https://www.google.com/search?udm=50&q=" + _ai_text().uri_encode())


func _build_ai_sheet() -> void:
	var box := _sheet("Pregunta a una IA")
	if box == null:
		return
	box.add_child(_para("Las IA generales se equivocan a menudo en ajedrez, sobre todo al calcular jugadas. Comprueba en el tablero cualquier jugada que te propongan.", F_SUB, _c("ink"), font_regular))
	var copy := _button("copy", "Copiar el texto", _copy_ai_text, _c("accent"), _c("accent_ink"), {"font_size": F_BODY, "height": 124.0, "icon": 56.0, "glow": _c("glow")})
	box.add_child(copy)
	var tint := _tint("sky")
	var google := _button("open", "Abrir en Google (Modo IA)", _open_google_ai, tint[0], tint[1], {"font_size": F_SUB, "height": 112.0, "icon": 52.0})
	box.add_child(google)
	_ai_status = _para("", F_SUB, _c("good"), font_medium)
	_ai_status.visible = false
	box.add_child(_ai_status)
	box.add_child(_caption("Texto que se copia"))
	var preview := _para(_ai_text(), F_CAP, _c("quiet"), font_regular)
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
	var heading := _text(heading_text, F_TITLE2, _c("ink"), font_display)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	header.add_child(_round_button("close", _close_options, 100.0, _c("field"), _c("ink"), false))
	header_pad.add_child(header)
	frame.add_child(header_pad)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	sheet_scroll = scroll
	var box_pad := _pad(0, 0, 14, 0)
	box_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box_pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
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
	if _has_player():
		var mine_tint := _tint("lilac")
		box.add_child(_button("cap", "Mi nivel y mi plan", _open_progress.bind("progress"), mine_tint[0], mine_tint[1], {"font_size": F_SUB, "height": 112.0, "icon": 56.0}))
	box.add_child(_caption("Piezas"))
	box.add_child(_picture_tiles([["piece_knight", "Figuras"], ["token_pawn", "Fichas"]], SETS.find(piece_set), _set_pieces_index))
	box.add_child(_caption("Material"))
	box.add_child(_swatch_tiles(STYLES.find(board_style)))
	box.add_child(_switch_row("outline", "lilac", "Contorno de las piezas", "Una línea de tinta alrededor de cada pieza.", board_outline, _set_outline))
	box.add_child(_switch_row("sound", "mint", "Sonido", "Arrastre y golpe de las piezas, jaque y caída del rey.", sound_on, _set_sound))
	box.add_child(_caption("Animaciones"))
	box.add_child(_segments(["Completas", "Rápidas", "Mínimas", "Sin"], int(view.board.anim_mode), _set_anim))
	box.add_child(_caption("Vista"))
	box.add_child(_segments(["Inclinada", "En picado"], 1 if top_view else 0, _set_top_view))
	box.add_child(_switch_row("pin", "peach", "Fijar el giro", "El tablero no gira con los dedos ni con el móvil. Ampliar sigue funcionando.", view.view_locked, _set_lock))
	box.add_child(_switch_row("zoom", "sky", "Pista de gestos", "Recuerda, sobre el tablero, que se puede ampliar y girar con dos dedos.", gesture_hint, _set_gesture_hint))
	box.add_child(_switch_row("phone", "butter", "Seguir al móvil", "La vista acompaña la inclinación y el giro del teléfono.", view.tilt_enabled, _set_tilt))
	box.add_child(_caption("Tema"))
	box.add_child(_segments(["Claro", "Oscuro"], 1 if dark else 0, _set_theme_index, ["sun", "moon"]))
	var tint := _tint("lilac")
	var how := _button("book", "Cómo se usa Chessome", _open_welcome, tint[0], tint[1], {"font_size": F_SUB, "height": 112.0, "icon": 54.0})
	var how_pad := _pad(0, 18, 0, 0)
	how_pad.add_child(how)
	box.add_child(how_pad)
	var about := _para("Chessome · %s" % app_version, F_CAP, _c("quiet"), font_regular)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(about)


func _caption(text: String) -> MarginContainer:
	var m := _pad(4, 18, 0, 0)
	m.add_child(_text(text.to_upper(), F_CAP, _c("quiet"), font_semibold))
	return m


## Estilo de una opción de elegir una entre varias: la elegida, en el tono de acento y con su borde.
func _choice_colors(chosen: bool) -> Array:
	if chosen:
		return [_c("accent_soft"), _c("accent_text"), _c("accent")]
	return [_c("field"), _c("quiet"), Color(0, 0, 0, 0)]


## Fila de botones en la que solo uno está elegido. Con iconos, cada botón lleva el suyo delante.
func _segments(names: Array, selected: int, on_pick: Callable, icons: Array = []) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in names.size():
		var colors := _choice_colors(i == selected)
		var b := _button(str(icons[i]) if i < icons.size() else "", str(names[i]), on_pick.bind(i), colors[0], colors[1], {"font_size": F_FOOT, "height": 108.0, "icon": 48.0, "pad_x": 12.0, "border": colors[2], "font": font_semibold if i == selected else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


## Teselas con un dibujo grande y su nombre: para elegir entre figuras y fichas.
func _picture_tiles(defs: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for i in defs.size():
		var def: Array = defs[i]
		var colors := _choice_colors(i == selected)
		var b := _button(str(def[0]), str(def[1]), on_pick.bind(i), colors[0], colors[1], {"vertical": true, "font_size": F_SUB, "height": 214.0, "icon": 104.0, "radius": 44, "border": colors[2], "font": font_semibold if i == selected else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


## Teselas de los acabados: cada una enseña sus dos colores de pieza.
func _swatch_tiles(selected: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in STYLES.size():
		var colors := _choice_colors(i == selected)
		var b := _button("", str(STYLE_NAMES[i]), _set_style_index.bind(i), colors[0], colors[1], {"vertical": true, "font_size": F_FOOT, "height": 178.0, "radius": 40, "pad_x": 6.0, "border": colors[2], "font": font_semibold if i == selected else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mark := SwatchMark.new()
		var swatch: Array = [Color("f8f0e0"), Color("2a3557")]
		if Board3D.FINISHES.has(STYLES[i]):
			swatch = Board3D.FINISHES[STYLES[i]]["swatch"]
		mark.light = swatch[0]
		mark.dark = swatch[1]
		mark.custom_minimum_size = Vector2(120.0, 76.0)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner := b.get_child(0)
		inner.add_child(mark)
		inner.move_child(mark, 0)
		row.add_child(b)
	return row


func _switch_row(icon_name: String, tint_name: String, label: String, hint: String, value: bool, on_change: Callable) -> MarginContainer:
	var row := _icon_row(icon_name, tint_name, label, hint, 96.0)
	var sw := Switch.new()
	sw.on = value
	sw.on_color = _c("accent")
	sw.off_color = _c("track")
	sw.knob_color = Color.WHITE
	sw.custom_minimum_size = Vector2(124.0, 72.0)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.focus_mode = Control.FOCUS_NONE
	sw.mouse_filter = Control.MOUSE_FILTER_PASS
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		sw.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	sw.pressed.connect(on_change.bind(not value))
	row.add_child(sw)
	var spaced := _pad(0, 10, 0, 10)
	spaced.add_child(row)
	return spaced


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
	if on and view.view_locked:
		_set_lock(false)
		return
	_sync_sheet()


func _set_lock(on: bool) -> void:
	view.set_view_locked(on)
	_save_settings()
	# La chincheta de la barra cambia de aspecto: se pone una nueva en su sitio.
	if pin_button != null and is_instance_valid(pin_button):
		var bar := pin_button.get_parent()
		var at := pin_button.get_index()
		var fresh := _pin_button()
		pin_button.visible = false
		pin_button.queue_free()
		bar.add_child(fresh)
		bar.move_child(fresh, at)
		pin_button = fresh
	_place_tip()
	_sync_sheet()


func _set_gesture_hint(on: bool) -> void:
	gesture_hint = on
	_save_settings()
	_place_tip()
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
## Emblema, nombre y cuatro ideas con su icono grande; el botón, siempre a la vista al pie.
func _open_welcome() -> void:
	if sheet_kind != "":
		_close_options()
	if welcome != null and is_instance_valid(welcome):
		welcome.queue_free()
	welcome = Control.new()
	welcome.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(welcome)
	var back := PastelBackdrop.new()
	back.top = _c("wash_top")
	back.mid = _c("wash_mid")
	back.bottom = _c("wash_bottom")
	var glow := 0.5 if not dark else 0.22
	var rose: Color = _tint("rose")[0]
	var sky: Color = _tint("sky")[0]
	var butter: Color = _tint("butter")[0]
	back.blobs = [
		[Vector2(0.95, 0.1), 0.62, Color(rose.r, rose.g, rose.b, glow)],
		[Vector2(0.02, 0.34), 0.5, Color(sky.r, sky.g, sky.b, glow)],
		[Vector2(0.9, 0.78), 0.56, Color(butter.r, butter.g, butter.b, glow * 0.9)],
	]
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	welcome.add_child(back)
	var inset := _insets()
	var pad := _pad(60, int(maxf(inset.x, 60.0)) + 20, 60, int(inset.y) + 44)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	pad.add_child(column)

	# Lo de arriba se desplaza si el móvil es bajo; el botón no se mueve.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	body.add_child(_spacer(10.0, true))
	var emblem := TextureRect.new()
	emblem.texture = UiIcons.emblem()
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(390.0, 390.0)
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(emblem)
	var name_label := _para("Chessome", F_LARGE, _c("ink"), font_display)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(name_label)
	body.add_child(_spacer(6.0))
	var claim := _para("Aprende ajedrez\nentendiendo cada jugada.", F_HEAD + 4, _c("quiet"), font_medium)
	claim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(claim)
	body.add_child(_spacer(54.0, true))
	var rows := [
		["tap", "peach", "Juega", "Toca una pieza y su destino, o arrástrala."],
		["bulb", "butter", "Si fallas, te lo explico", "Verás qué pasaría y podrás volver a intentarlo."],
		["why", "lilac", "Pregunta «por qué»", "Cada solución, explicada paso a paso."],
		["sliders", "mint", "A tu gusto", "Figuras o fichas, materiales, sonido y animaciones."],
	]
	for i in rows.size():
		var def: Array = rows[i]
		if i > 0:
			body.add_child(_spacer(42.0))
		body.add_child(_welcome_row(str(def[0]), str(def[1]), str(def[2]), str(def[3])))
	body.add_child(_spacer(20.0, true))

	column.add_child(_spacer(22.0))
	var note := _para("Todavía no hay curso de reglas: necesitas saber cómo se mueven las piezas.", F_FOOT + 2, _c("quiet"), font_regular)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	column.add_child(_spacer(26.0))
	var go := _button("next", "Empezar", _close_welcome, _c("accent"), _c("accent_ink"), {"font_size": F_HEAD, "height": 148.0, "icon": 60.0, "trailing": true, "glow": _c("glow")})
	go.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(go)
	_place_tip()


## Una idea de la bienvenida: tesela pastel con un icono grande, titular y una línea de texto.
func _welcome_row(icon_name: String, tint_name: String, heading: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := _icon_tile(icon_name, tint_name, 152.0, 94.0)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_para(heading, F_HEAD + 6, _c("ink"), font_semibold))
	texts.add_child(_para(text, F_BODY, _c("quiet"), font_regular))
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
	_place_tip()
	# Primera vez: tras la bienvenida, la pregunta de experiencia y el test de nivel.
	if use_settings and not _has_player() and progress == null:
		_open_experience()


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
	_gap_limit = INF
	last_wrong = {}
	hint_level = 0
	step_fen = ""
	step = 0
	ask_step = 0
	_rating_shown = []
	_try = {}
	if mode != "free" and _has_player() and index < pool.size():
		var item: Dictionary = pool[index]
		# Un problema ya anotado (al repetirlo, o en un repaso) no vuelve a mover el nivel.
		var seen := false
		for t: Dictionary in player["tries"]:
			if str(t["id"]) == str(item["id"]):
				seen = true
				break
		_try = {"item": item, "t0": 0, "ms_first": 0.0, "fail_step": -1, "error": "", "help": "", "recorded": seen}
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
	hint_level = 0
	# Jugada nueva: el tablero vuelve a bajar a su sitio de resolver (pudo subir para dejar sitio a una explicación).
	_gap_limit = INF
	# El reloj del intento empieza cuando el jugador puede mover por primera vez.
	if not _try.is_empty() and int(_try["t0"]) == 0:
		_try["t0"] = Time.get_ticks_msec()
	view.interactive = true
	_set_phase(Phase.SOLVING)


## «Pista»: la primera vez, el tema del problema; la segunda, además, la pieza que hay que mover (queda
## elegida en el tablero, con sus destinos a la vista). No dice la jugada.
func _on_hint() -> void:
	if mode == "test" or (phase != Phase.SOLVING and phase != Phase.WRONG):
		return
	var moves: Array = puzzle.get("moves", [])
	if ask_step < 1 or ask_step >= moves.size():
		return
	_mark_help("hint")
	if hint_level < 2:
		hint_level += 1
	if hint_level == 1 and _hint_theme() == "":
		hint_level = 2
	if hint_level >= 2:
		# La pieza se señala en la posición de la decisión: si se estaba viendo otra cosa, se vuelve a ella.
		run_id += 1
		line_on = {}
		line_ply = -1
		_restore_position()
		if phase == Phase.WRONG:
			view.board.set_arrows(_arrows_for(expl, 1, true))
		view.interactive = true
		view.board.select(Chess.sq_index(str(moves[ask_step]).substr(0, 2)))
	_keep_scroll = true
	_refresh()
	card_scroll.set_deferred("scroll_vertical", 100000)


## «Un paso»: juega solo la jugada que toca y explica por qué es esa. El resto lo sigue resolviendo el jugador.
func _on_step() -> void:
	if mode == "test" or (phase != Phase.SOLVING and phase != Phase.WRONG):
		return
	var moves: Array = puzzle.get("moves", [])
	if ask_step < 1 or ask_step >= moves.size():
		return
	_mark_help("step")
	run_id += 1
	var my_run := run_id
	var k := _point()
	var uci := str(moves[ask_step])
	view.interactive = false
	_clear_explanation()
	hint_level = 0
	view.board.set_arrows([])
	_restore_position()
	step = ask_step
	await _wait(0.25)
	if my_run != run_id:
		return
	# La posición de después del paso se calcula con las reglas, no se lee del tablero (que está animando).
	var before := Chess.from_fen(fen_before)
	var move := before.find_uci(uci)
	if move < 0:
		_ask()
		return
	var after := before.after(move)
	step_fen = after.fen()
	view.show_move(uci)
	step += 1
	if explain != null and explain.ok:
		expl = explain.for_move(k, uci)
		if not expl.is_empty():
			expl["headline"] = "Este paso: %s" % str(expl.get("san", ""))
			expl["asked"] = true
		exp_point = k
	# Si era la última jugada, el problema queda resuelto: no hay nada más que seguir.
	_set_phase(Phase.SHOWN if step >= moves.size() or after.is_checkmate() else Phase.STEP)


## «Seguir», tras «Un paso»: responde el rival y vuelve a tocarle al jugador.
func _on_continue() -> void:
	if phase != Phase.STEP:
		return
	var moves: Array = puzzle.get("moves", [])
	run_id += 1
	var my_run := run_id
	_clear_explanation()
	view.board.set_arrows([])
	view.interactive = false
	# El tablero puede estar enseñando la posición de la decisión o una variante: vuelve a la de después del paso.
	if step_fen != "":
		view.set_fen(step_fen)
		if step >= 1 and step - 1 < moves.size():
			var mine := str(moves[step - 1])
			view.board.mark_last_move(Chess.sq_index(mine.substr(0, 2)), Chess.sq_index(mine.substr(2, 2)))
	last_wrong = {}
	_set_phase(Phase.INTRO)
	await _wait(0.5)
	if my_run != run_id:
		return
	if step < moves.size():
		view.show_move(str(moves[step]))
		step += 1
	await _wait(0.5)
	if my_run != run_id:
		return
	_ask()


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
	if not _try.is_empty() and float(_try["ms_first"]) <= 0.0 and int(_try["t0"]) > 0:
		_try["ms_first"] = maxf(1.0, float(Time.get_ticks_msec() - int(_try["t0"])))
	var mate := view.board.chess.is_checkmate()
	if uci != str(moves[step]) and not mate:
		# Fallo: se cuenta qué hace la jugada y qué permite, y se deja reintentar.
		view.interactive = false
		var k := _point()
		last_wrong = {"point": k, "uci": uci}
		_clear_explanation()
		hint_level = 0
		expl = _explanation_for(k, uci)
		exp_point = k
		# La primera jugada equivocada decide el intento: en qué paso fue y qué clase de error.
		if not _try.is_empty() and not bool(_try["recorded"]):
			_try["fail_step"] = k
			_try["error"] = str(expl.get("error", ""))
			_record(false)
		if mode == "test":
			# En el test hay un solo intento: se explica el fallo, con la jugada buena, y se pasa al siguiente.
			exp_partial = false
			_set_phase(Phase.SHOWN)
			await _wait(0.9)
			if my_run != run_id:
				return
			_show_decision(_arrows_for(expl, 1, false))
			return
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
	hint_level = 0
	if mate or step >= moves.size():
		view.interactive = false
		if explain != null and explain.ok:
			expl = explain.solved()
		# Resuelto sin fallos ni ayudas: acierto. (Si antes hubo un fallo o una ayuda, ya está anotado.)
		_record(true)
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
	_mark_help("solution")
	run_id += 1
	var my_run := run_id
	var k := _point()
	view.interactive = false
	_clear_explanation()
	hint_level = 0
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


## «Solución» mientras se resuelve; «Repetir» cuando el problema ha terminado. En el test, «No lo sé».
func _on_left() -> void:
	if mode == "test":
		_on_right()
	elif phase == Phase.SOLVED or phase == Phase.SHOWN:
		_start(index)
	else:
		_show_solution()


## «Saltar» o «Siguiente»; tras «Un paso», «Seguir». En el test: «No lo sé» mientras se resuelve y, al
## terminar cada problema, el siguiente (o el resultado, si ya hay datos suficientes).
func _on_right() -> void:
	if mode == "test":
		if phase == Phase.SOLVED or phase == Phase.SHOWN:
			if bool(player.get("done", false)):
				_finish_test()
			else:
				_next_test()
		elif phase == Phase.SOLVING:
			_give_up()
	elif phase == Phase.STEP:
		_on_continue()
	elif mode == "train":
		_next_training()
	else:
		_start(index + 1)


# ---------------------------------------------------------------- test de nivel y entrenamiento

## Tablero quieto mientras se enseñan la bienvenida y la pregunta de experiencia.
func _idle() -> void:
	run_id += 1
	puzzle = {}
	explain = null
	_clear_explanation()
	_try = {}
	view.board.set_arrows([])
	view.set_fen(Board3D.START_FEN)
	view.set_orientation(0)
	view.interactive = false
	_set_phase(Phase.INTRO)


## Empieza el test de nivel desde lo que el jugador dice de su experiencia.
func _start_test(exp: String) -> void:
	experience = exp
	test_skipped = false
	player = Assessment.start_test(exp)
	mode = "test"
	_close_progress()
	_save_player()
	_next_test()


## Sin test: se entrena desde un nivel provisional, que se va afinando con cada problema.
func _skip_test() -> void:
	if experience == "":
		experience = "casual"
	test_skipped = true
	player = Assessment.start_test(experience)
	player["done"] = true
	mode = "train"
	_close_progress()
	_save_player()
	_next_training()


func _next_test() -> void:
	var item := Assessment.next_test_item(player, pool, _rng.randf())
	if item.is_empty():
		player["done"] = true
		_finish_test()
		return
	_start(int(_index_of[item["id"]]))


## El test ha terminado: se enseña el resultado. Detrás queda el modo de entrenamiento.
func _finish_test() -> void:
	mode = "train"
	_save_player()
	_open_progress("result")


## Siguiente problema del entrenamiento: según el nivel y los puntos flojos; agotados los nuevos, un repaso.
func _next_training() -> void:
	if pool.is_empty() or not _has_player():
		_start(index + 1)
		return
	var item := Assessment.pick_training_item(player["rating"], player["tries"], pool, _rng.randf())
	if item.is_empty():
		item = Assessment.pick_review_item(player["tries"], pool)
	_start(int(_index_of[item["id"]]))


## Anota el intento en curso (una sola vez por problema): mueve el nivel y lo guarda.
func _record(correct: bool) -> void:
	if mode == "free" or _try.is_empty() or bool(_try.get("recorded", true)) or not _has_player():
		return
	_try["recorded"] = true
	var t0 := int(_try["t0"])
	var outcome := {
		"correct": correct,
		"failStep": int(_try["fail_step"]),
		"error": str(_try["error"]),
		"help": str(_try["help"]),
		"msFirst": float(_try["ms_first"]),
		"ms": float(Time.get_ticks_msec() - t0) if t0 > 0 else 0.0,
	}
	var before := float(player["rating"]["r"])
	player = Assessment.record_try(player, _try["item"], outcome, mode)
	_rating_shown = [before, float(player["rating"]["r"])]
	_save_player()


## Pedir ayuda decide el intento: cuenta como no resuelto por uno mismo.
func _mark_help(kind: String) -> void:
	if _try.is_empty() or bool(_try.get("recorded", true)):
		return
	_try["help"] = kind
	_record(false)


## «No lo sé» (en el test): se anota y se enseña la solución.
func _give_up() -> void:
	if phase != Phase.SOLVING:
		return
	_mark_help("giveup")
	_show_solution()


# ---------------------------------------------------------------- páginas: experiencia, resultado y progreso

## Página a pantalla completa con fondo pastel: arriba una zona que se desplaza y abajo un pie fijo.
## Devuelve {"body": VBoxContainer, "footer": VBoxContainer}.
func _page(kind: String) -> Dictionary:
	_close_progress()
	if sheet_kind != "":
		_close_options()
	progress_kind = kind
	progress = Control.new()
	progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(progress)
	var back := PastelBackdrop.new()
	back.top = _c("wash_top")
	back.mid = _c("wash_mid")
	back.bottom = _c("wash_bottom")
	var glow := 0.5 if not dark else 0.22
	var rose: Color = _tint("rose")[0]
	var sky: Color = _tint("sky")[0]
	var butter: Color = _tint("butter")[0]
	back.blobs = [
		[Vector2(0.95, 0.08), 0.62, Color(sky.r, sky.g, sky.b, glow)],
		[Vector2(0.0, 0.4), 0.5, Color(rose.r, rose.g, rose.b, glow * 0.8)],
		[Vector2(0.92, 0.8), 0.56, Color(butter.r, butter.g, butter.b, glow * 0.9)],
	]
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	progress.add_child(back)
	var inset := _insets()
	var pad := _pad(48, int(maxf(inset.x, 60.0)) + 20, 48, int(inset.y) + 40)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	progress.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	pad.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	progress_scroll = scroll
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	column.add_child(_spacer(20.0))
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 0)
	column.add_child(footer)
	_place_tip()
	return {"body": body, "footer": footer}


func _close_progress() -> void:
	if progress != null and is_instance_valid(progress):
		progress.visible = false
		progress.queue_free()
	progress = null
	progress_kind = ""
	_place_tip()


## Salir de la página abierta (botón «atrás»): del resultado se pasa a entrenar; de la pregunta de
## experiencia no se sale sin contestar (o sin saltar el test).
func _leave_progress() -> void:
	if progress_kind == "result":
		_start_training()
	elif progress_kind == "progress" or (progress_kind == "experience" and _has_player()):
		_close_progress()


func _start_training() -> void:
	mode = "train"
	_close_progress()
	_next_training()


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Pregunta de experiencia: el punto de partida del test. Cuatro opciones con su dibujo.
func _open_experience() -> void:
	var page := _page("experience")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(8.0, true))
	var tile := _icon_tile("cap", "lilac", 156.0, 98.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(24.0))
	body.add_child(_centered(_para("¿Cuánto has jugado?", F_TITLE + 12, _c("ink"), font_display)))
	body.add_child(_spacer(4.0))
	body.add_child(_centered(_para("Así el test empieza cerca de tu nivel.", F_HEAD, _c("quiet"), font_medium)))
	body.add_child(_spacer(40.0))
	var options := [
		["never", "book", "butter", "Nunca he jugado", "Aún no hay curso de reglas, pero puedes probar."],
		["rules", "piece_pawn", "mint", "Sé mover las piezas", "Conozco las reglas y poco más."],
		["casual", "piece_knight", "sky", "Juego de vez en cuando", "Alguna partida con amigos o en el móvil."],
		["regular", "piece_queen", "rose", "Juego a menudo", "En un club o por internet."],
	]
	for def: Array in options:
		body.add_child(_option_button(str(def[1]), str(def[2]), str(def[3]), str(def[4]), _start_test.bind(str(def[0]))))
		body.add_child(_spacer(20.0))
	body.add_child(_spacer(8.0, true))
	footer.add_child(_centered(_para("El test tiene entre 8 y 12 problemas, con un solo intento y sin ayudas. Al terminar verás tu nivel, en qué fallas y un plan.", F_FOOT + 2, _c("quiet"), font_regular)))
	footer.add_child(_spacer(14.0))
	if _has_player():
		# Se llega aquí desde «Repetir el test»: se puede dejar todo como estaba.
		footer.add_child(_button("", "Cancelar", _close_progress, Color(0, 0, 0, 0), _c("quiet"), {"font_size": F_SUB, "height": 96.0, "font": font_medium}))
	else:
		footer.add_child(_button("", "Saltar el test", _skip_test, Color(0, 0, 0, 0), _c("quiet"), {"font_size": F_SUB, "height": 96.0, "font": font_medium}))


## Opción grande: tesela con dibujo, titular, una línea de texto y una flecha.
func _option_button(icon_name: String, tint_name: String, heading: String, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(on_press)
	_style_button(b, _c("surface"), _c("ink"), 48, F_BODY, font_semibold, _c("shadow"))
	var pad := _pad(26, 24, 30, 24)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(pad)
	var row := _icon_row(icon_name, tint_name, heading, text, 120.0)
	pad.add_child(row)
	row.add_child(_icon("next", 46.0, _c("quiet")))
	var fit := func() -> void:
		if is_instance_valid(b) and is_instance_valid(pad):
			b.custom_minimum_size = Vector2(0.0, pad.get_combined_minimum_size().y)
	pad.minimum_size_changed.connect(fit)
	fit.call()
	b.set_meta("label", heading)
	return b


## Tarjeta blanca de una página, con sus filas dentro.
func _panel() -> Array:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _c("surface")
	sb.set_corner_radius_all(48)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0.0, 10.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 30)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows)
	return [panel, rows]


## Calificación de una dimensión del perfil, como etiqueta. "" = sin etiqueta.
func _status_chip(state: String) -> Control:
	var chip: PanelContainer = null
	match state:
		"weak":
			var rose := _tint("rose")
			chip = _chip("A reforzar", rose[0], rose[1])
		"strong":
			var mint := _tint("mint")
			chip = _chip("Fuerte", mint[0], mint[1])
		"ok":
			chip = _chip("En tu nivel", _c("field"), _c("ink"))
		"few":
			chip = _chip("Pocos datos", _c("field"), _c("quiet"))
	return chip


## Fila del perfil o del plan: tesela con icono, titular, detalle y, si la hay, su calificación.
func _profile_row(icon_name: String, tint_name: String, heading: String, text: String, state: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_icon_row(icon_name, tint_name, heading, text, 92.0))
	var chip := _status_chip(state)
	if chip != null:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(_spacer_w(116.0))
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		line.add_child(chip)
		box.add_child(line)
	return box


func _spacer_w(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## «18 s» o «1 min 5 s».
func _duration(ms: float) -> String:
	var seconds := int(round(ms / 1000.0))
	if seconds < 60:
		return "%d s" % maxi(seconds, 1)
	return "%d min %d s" % [seconds / 60, seconds % 60] if seconds % 60 != 0 else "%d min" % (seconds / 60)


## Resultado del test ("result") o progreso ("progress"): el nivel, el perfil por dimensiones y el plan.
func _open_progress(kind: String = "progress") -> void:
	if not _has_player():
		return
	var page := _page(kind)
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var rating: Dictionary = player["rating"]
	var tries: Array = player["tries"]
	var pr := Assessment.profile(tries)
	var todo := Assessment.plan(rating, pr)
	var r := float(rating["r"])
	var band := Assessment.level_band(r)
	var limits := Assessment.measurable_range(pool)

	# El nivel.
	body.add_child(_spacer(4.0))
	body.add_child(_centered(_para("TU NIVEL" if kind != "result" else "RESULTADO DEL TEST", F_CAP, _c("quiet"), font_semibold)))
	var level_text := str(int(round(r)))
	var limit_note := ""
	if r < float(limits["min"]):
		level_text = "Menos de %d" % int(limits["min"])
		limit_note = "Esta muestra de problemas casi no tiene otros más fáciles: por debajo de ese nivel el número no es fiable."
	elif r > float(limits["max"]):
		level_text = "Más de %d" % int(limits["max"])
		limit_note = "Esta muestra de problemas casi no tiene otros más difíciles: por encima de ese nivel el número no es fiable."
	var number := _centered(_para(level_text, F_LARGE + 44 if limit_note == "" else F_LARGE, _c("ink"), font_display))
	number.add_theme_constant_override("line_spacing", -8)
	body.add_child(number)
	var band_row := CenterContainer.new()
	band_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lilac := _tint("lilac")
	band_row.add_child(_chip(str(band["name"]), lilac[0], lilac[1]))
	body.add_child(band_row)
	body.add_child(_spacer(18.0))
	body.add_child(_centered(_para(str(band["blurb"]), F_BODY, _c("ink"), font_regular)))
	body.add_child(_spacer(10.0))
	var margin := int(round(2.0 * float(rating["rd"]) / 10.0)) * 10
	var small := "Margen: ±%d. Se afina con cada problema. Es la escala de los problemas de Lichess, no Elo." % margin
	if limit_note != "":
		small = limit_note + " " + small
	if tries.is_empty():
		small = "Has saltado el test: es un nivel provisional. " + small
	body.add_child(_centered(_para(small, F_FOOT, _c("quiet"), font_regular)))

	# El perfil.
	body.add_child(_spacer(40.0))
	var n := tries.size()
	body.add_child(_text(("PERFIL · %d PROBLEMAS" % n) if n != 1 else "PERFIL · 1 PROBLEMA", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(8.0))
	if n < 20:
		body.add_child(_para("Primeras observaciones: con tan pocos problemas son indicios, no un veredicto. Se afinan al entrenar.", F_FOOT + 2, _c("quiet"), font_regular))
		body.add_child(_spacer(14.0))
	var made := _panel()
	var rows: VBoxContainer = made[1]
	body.add_child(made[0])
	# Las familias con datos para calificarlas van cada una en su fila; las demás, juntas al final.
	var few := PackedStringArray()
	for f: Dictionary in pr["families"]:
		var family_name := str(Assessment.FAMILY_NAME.get(f["family"], f["family"]))
		var family_state := Assessment.status(f)
		if family_state == "few":
			few.append("%s, %d de %d" % [family_name.to_lower(), int(f["correct"]), int(f["n"])])
		else:
			rows.add_child(_profile_row("whatif", "sky", family_name, "%d de %d acertados" % [int(f["correct"]), int(f["n"])], family_state))
	var mate: Dictionary = pr["mate"]
	if int(mate["n"]) > 0:
		rows.add_child(_profile_row("target", "rose", "Visión de mate", "%d de %d problemas que acaban en mate" % [int(mate["correct"]), int(mate["n"])], Assessment.status(mate)))
	var long: Dictionary = pr["long"]
	if int(long["n"]) > 0:
		var calc := "%d de %d problemas de tres jugadas o más." % [int(long["correct"]), int(long["n"])]
		if int(pr["failLater"]) > 0:
			calc += " En %d acertaste la primera jugada y fallaste después." % int(pr["failLater"])
		rows.add_child(_profile_row("line", "lilac", "Cálculo", calc, Assessment.status(long)))
	var fails := int(pr["fails"])
	if fails > 0:
		var parts := PackedStringArray()
		for error_kind: String in Assessment.ERROR_KINDS:
			var count := int(pr["errors"][error_kind])
			if count > 0:
				parts.append("%s ×%d" % [_error_name(error_kind), count])
		var detail := " · ".join(parts) + "."
		if int(pr["replyBlind"]) > 0:
			detail += " %d de %d se castigaban con la respuesta inmediata del rival." % [int(pr["replyBlind"]), fails]
		rows.add_child(_profile_row("wrong", "peach", "Tus jugadas equivocadas: %d" % fails, detail))
	var time: Dictionary = pr["time"]
	if int(time["n"]) > 0:
		var pace := "Sueles tardar %s en mover." % _duration(float(time["median"]))
		if int(time["rushed"]) > 0:
			pace += " %d fallos llegaron en menos de la mitad de lo que tardas cuando aciertas." % int(time["rushed"])
		rows.add_child(_profile_row("clock", "butter", "Ritmo", pace))
	if not few.is_empty():
		rows.add_child(_profile_row("chart", "sky", "Con pocos datos todavía", _sentence("; ".join(few) + ".")))
	rows.add_child(_profile_row("info", "mint", "Sin medir todavía", "Desarrollo, seguridad del rey y estrategia. Los problemas tácticos no las miden: hacen falta posiciones de otro tipo."))

	# El plan.
	body.add_child(_spacer(40.0))
	body.add_child(_text("TU PLAN", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(12.0))
	var plan_made := _panel()
	var plan_rows: VBoxContainer = plan_made[1]
	body.add_child(plan_made[0])
	var target := float(todo["target"])
	var lowest := float(pool[0]["rating"]) if not pool.is_empty() else 0.0
	if target < lowest:
		plan_rows.add_child(_profile_row("target", "peach", "Los problemas más fáciles que hay", "La muestra empieza en %d: al principio fallarás más de lo que conviene." % int(lowest)))
	else:
		plan_rows.add_child(_profile_row("target", "peach", "Problemas de dificultad %d" % int(round(target)), "Algo por debajo de tu nivel, para acertar unos tres de cada cuatro."))
	var focus: Array = todo["focus"]
	if focus.is_empty():
		plan_rows.add_child(_profile_row("whatif", "sky", "Problemas variados", "Todavía no hay un punto flojo claro."))
	for item: Dictionary in focus:
		var what := "mate"
		if str(item["kind"]) == "long":
			what = "tres jugadas o más"
		elif str(item["kind"]) == "family":
			what = str(Assessment.FAMILY_NAME.get(item["family"], "")).to_lower()
		plan_rows.add_child(_profile_row("flag", "rose", "Más problemas de %s" % what, "Es donde rindes por debajo de tu nivel: saldrán más a menudo."))
	for habit: String in todo["habits"]:
		match habit:
			"reply":
				plan_rows.add_child(_profile_row("eye", "lilac", "Mira la respuesta del rival", "Antes de soltar la pieza, busca sus jaques, capturas y amenazas."))
			"rushed":
				plan_rows.add_child(_profile_row("clock", "butter", "Sin prisa", "Tus fallos llegan muy rápido. Dedica a cada jugada el tiempo que usas cuando aciertas."))
			"followThrough":
				plan_rows.add_child(_profile_row("line", "mint", "Calcula hasta el final", "Aciertas la primera jugada y fallas después: repasa la variante entera antes de mover."))
	body.add_child(_spacer(20.0))

	var go := {"font_size": F_HEAD, "height": 148.0, "icon": 60.0, "trailing": true, "glow": _c("glow")}
	if kind == "result":
		var start := _button("next", "Empezar a entrenar", _start_training, _c("accent"), _c("accent_ink"), go)
		start.mouse_filter = Control.MOUSE_FILTER_STOP
		footer.add_child(start)
	else:
		var keep := _button("next", "Seguir entrenando", _close_progress, _c("accent"), _c("accent_ink"), go)
		keep.mouse_filter = Control.MOUSE_FILTER_STOP
		footer.add_child(keep)
		footer.add_child(_spacer(8.0))
		footer.add_child(_button("retry", "Repetir el test de nivel", _open_experience, Color(0, 0, 0, 0), _c("quiet"), {"font_size": F_SUB, "height": 92.0, "icon": 44.0, "font": font_medium}))


## La frase, con su primera letra en mayúscula.
func _sentence(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1) if text != "" else ""


## Clase de una jugada equivocada, como nombre corto para la lista del perfil.
func _error_name(kind: String) -> String:
	match kind:
		"mate":
			return "mate en contra"
		"hangMoved":
			return "pieza movida a una casilla atacada"
		"hangOther":
			return "otra pieza sin defensa"
		"material":
			return "pérdida de material en pocas jugadas"
		"worse":
			return "posición perdida"
		"missed":
			return "ocasión desaprovechada"
		"slower":
			return "ganaba, pero no era la más precisa"
	return kind
