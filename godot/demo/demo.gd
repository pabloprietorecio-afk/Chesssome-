extends Control
## Demo del tablero 3D: problemas reales de Lichess para probar las piezas, la cámara y las animaciones.
## Todavía no es el entrenamiento completo (sin test de nivel ni explicaciones): sirve para juzgar el 3D.
## El estilo de la interfaz sigue docs/estilo-2d.md (inspirado en WakeAgenda).

const INK := Color("1b2540")
const QUIET := Color("5b6782")
const ACCENT := Color("ff7a1a")
const ACCENT_TEXT := Color("b84a0c")
const ACCENT_SOFT := Color("ffebd9")
const GOOD := Color("1f7a44")
const BAD := Color("c0392b")

var puzzles: Array = []
var index := 0
var puzzle: Dictionary = {}
var step := 0
var fen_before := ""
var run_id := 0
var dark := false

var view: BoardView3D
var bg: ColorRect
var title: Label
var body: Label
var card: PanelContainer
var anim_buttons: Array[Button] = []
var tilt_button: Button
var lock_button: Button
var theme_button: Button
var chips: Array[Button] = []


func _ready() -> void:
	_load_puzzles()
	_build_ui()
	_start(0)


func _load_puzzles() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_puzzles.json"))
	if typeof(data) == TYPE_DICTIONARY:
		puzzles = data.get("puzzles", [])


# ---------------------------------------------------------------- interfaz

func _box(color: Color, radius: int, shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(28.0)
	if shadow:
		s.shadow_color = Color(0.18, 0.36, 0.66, 0.18)
		s.shadow_size = 16
		s.shadow_offset = Vector2(0.0, 6.0)
	return s


func _style_button(b: Button, bg_color: Color, fg: Color, radius: int = 60, side_margin: float = 34.0) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := _box(bg_color.darkened(0.06) if state == "pressed" else bg_color, radius)
		s.content_margin_left = side_margin
		s.content_margin_right = side_margin
		s.content_margin_top = 18.0
		s.content_margin_bottom = 18.0
		b.add_theme_stylebox_override(state, s)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_font_size_override("font_size", 34)


func _chip(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 84.0)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	chips.append(b)
	return b


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_ui() -> void:
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	view = BoardView3D.new()
	view.custom_minimum_size = Vector2(1080.0, 1080.0)
	view.move_played.connect(_on_move_played)
	column.add_child(view)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 32)
	pad.add_theme_constant_override("margin_right", 32)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	pad.add_child(inner)

	card = PanelContainer.new()
	inner.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 6)
	card.add_child(card_box)
	title = _label("", 44, INK)
	body = _label("", 32, QUIET)
	card_box.add_child(title)
	card_box.add_child(body)

	var anim_row := HBoxContainer.new()
	anim_row.add_theme_constant_override("separation", 10)
	inner.add_child(anim_row)
	var names := ["Completas", "Rápidas", "Mínimas", "Sin"]
	for i in names.size():
		var b := _chip(names[i], _set_anim.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		anim_row.add_child(b)
		anim_buttons.append(b)

	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 10)
	inner.add_child(view_row)
	var center := _chip("Centrar", _on_center)
	var tilted := _chip("Inclinada", _on_default_view)
	tilt_button = _chip("Seguir al móvil", _on_toggle_tilt)
	lock_button = _chip("Fijar", _on_toggle_lock)
	theme_button = _chip("Oscuro", _on_toggle_theme)
	for b: Button in [center, tilted, tilt_button, lock_button, theme_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view_row.add_child(b)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	inner.add_child(actions)
	var solution := Button.new()
	solution.text = "Ver solución"
	solution.custom_minimum_size = Vector2(0.0, 112.0)
	solution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	solution.focus_mode = Control.FOCUS_NONE
	solution.pressed.connect(_on_solution)
	_style_button(solution, ACCENT_SOFT, ACCENT_TEXT)
	actions.add_child(solution)
	var next := Button.new()
	next.text = "Siguiente"
	next.custom_minimum_size = Vector2(0.0, 112.0)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(_on_next)
	_style_button(next, ACCENT, INK)
	actions.add_child(next)

	_apply_theme()
	_refresh_chips()


func _apply_theme() -> void:
	bg.color = Color("0a0f1e") if dark else Color("eaf1fb")
	card.add_theme_stylebox_override("panel", _box(Color("121a30") if dark else Color.WHITE, 44, true))
	title.add_theme_color_override("font_color", Color("edeff7") if dark else INK)
	body.add_theme_color_override("font_color", Color("a9b1c7") if dark else QUIET)
	view.board.set_theme("dark" if dark else "light")
	theme_button.text = "Claro" if dark else "Oscuro"


func _refresh_chips() -> void:
	var off_bg := Color("121a30") if dark else Color.WHITE
	var off_fg := Color("a9b1c7") if dark else QUIET
	var on_bg := Color("3a2416") if dark else ACCENT_SOFT
	var on_fg := Color("ff9a2e") if dark else ACCENT_TEXT
	for b in chips:
		var on := false
		if anim_buttons.has(b):
			on = anim_buttons.find(b) == int(view.board.anim_mode)
		elif b == tilt_button:
			on = view.tilt_enabled
		elif b == lock_button:
			on = view.view_locked
		_style_button(b, on_bg if on else off_bg, on_fg if on else off_fg, 42, 14.0)
		b.add_theme_font_size_override("font_size", 28)


func _set_anim(mode: int) -> void:
	view.board.anim_mode = mode as Board3D.Anim
	_refresh_chips()


func _on_center() -> void:
	view.center_view()


func _on_default_view() -> void:
	view.default_view()


func _on_toggle_tilt() -> void:
	view.set_tilt_enabled(not view.tilt_enabled)
	if view.tilt_enabled:
		view.set_view_locked(false)
	_refresh_chips()


func _on_toggle_lock() -> void:
	view.set_view_locked(not view.view_locked)
	_refresh_chips()


func _on_toggle_theme() -> void:
	dark = not dark
	_apply_theme()
	_refresh_chips()


# ---------------------------------------------------------------- problema

func _status(head: String, text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	title.text = head
	body.text = text
	var base := Color("edeff7") if dark else INK
	title.add_theme_color_override("font_color", base if color.a == 0.0 else color)


func _side_name() -> String:
	return "blancas" if view.board.chess.turn == 0 else "negras"


func _start(i: int) -> void:
	run_id += 1
	var my_run := run_id
	if puzzles.is_empty():
		_status("Sin problemas", "No se ha encontrado data/demo_puzzles.json.")
		return
	index = posmod(i, puzzles.size())
	puzzle = puzzles[index]
	step = 0
	view.board.set_arrows([])
	view.set_fen(puzzle["fen"])
	# Juega quien responde a la primera jugada (la del rival).
	view.set_orientation(1 - view.board.chess.turn)
	view.interactive = false
	_status("Problema %d de %d" % [index + 1, puzzles.size()], "Mira la jugada del rival…")
	await get_tree().create_timer(0.7).timeout
	if my_run != run_id:
		return
	var moves: Array = puzzle["moves"]
	view.show_move(str(moves[0]))
	step = 1
	await get_tree().create_timer(0.55).timeout
	if my_run != run_id:
		return
	_ask()


func _ask() -> void:
	fen_before = view.board.chess.fen()
	view.interactive = true
	_status("Juegan %s" % _side_name(), "Encuentra la mejor jugada. Problema real de Lichess · %s · dificultad %d" % [puzzle["theme"], int(puzzle["rating"])])


func _on_move_played(uci: String) -> void:
	var my_run := run_id
	var moves: Array = puzzle["moves"]
	if step >= moves.size():
		return
	var mate := view.board.chess.is_checkmate()
	if uci != str(moves[step]) and not mate:
		view.interactive = false
		_status("No es la mejor", "Prueba otra vez o mira la solución.", Color("ff7b7f") if dark else BAD)
		await get_tree().create_timer(0.9).timeout
		if my_run != run_id:
			return
		view.set_fen(fen_before)
		view.interactive = true
		return
	step += 1
	if mate or step >= moves.size():
		view.interactive = false
		_status("¡Resuelto!", "Pulsa «Siguiente» para otro problema.", Color("4cbf7a") if dark else GOOD)
		return
	view.interactive = false
	await get_tree().create_timer(0.55).timeout
	if my_run != run_id:
		return
	view.show_move(str(moves[step]))
	step += 1
	await get_tree().create_timer(0.45).timeout
	if my_run != run_id:
		return
	_ask()


func _on_solution() -> void:
	run_id += 1
	var my_run := run_id
	var moves: Array = puzzle.get("moves", [])
	if step < 1 or step >= moves.size():
		return
	view.interactive = false
	view.set_fen(fen_before)
	_status("La solución", "Mira cómo sigue.")
	while step < moves.size():
		await get_tree().create_timer(0.75).timeout
		if my_run != run_id:
			return
		view.show_move(str(moves[step]))
		step += 1
	_status("La solución", "Pulsa «Siguiente» para otro problema.")


func _on_next() -> void:
	_start(index + 1)
