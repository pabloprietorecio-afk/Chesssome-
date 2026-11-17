class_name ClockPicker
extends VBoxContainer
## Selector de hora con un reloj grande, el mismo de los eventos de WakeAgenda (app de Pablo:
## app/src/main/java/com/wakeagenda/app/ui/components/ClockTimePickerDialog.kt y ClockMath.kt, Jetpack Compose),
## pasado a Godot con los colores y las letras de A Chess Way:
##  - Arriba, la hora y los minutos en dos fichas grandes; se toca una para cambiar a ella.
##  - Primero se toca la hora (anillo exterior 12, 1…11; interior 00, 13…23) y pasa sola a los minutos, que se
##    eligen tocando o arrastrando. La aguja va con una bolita y se mueve con una animación corta.
## Los botones («Cancelar», «Aceptar») los pone quien lo abre.

signal changed(hour: int, minute: int)

enum Mode { HOUR, MINUTE }

## Por debajo de esta fracción del radio se toca el anillo interior de las horas.
const INNER_RING_THRESHOLD := 0.65
const OUTER_RING := 0.78
const INNER_RING := 0.50
const HAND_TIME := 0.14

var hour := 21
var minute := 0
var mode := Mode.HOUR
var primary := Color("ffa366")
var on_primary := Color("1b2540")
var face_color := Color("eef1f8")
var ink := Color("1b2540")
var quiet := Color("6b7690")
var font_bold: Font
var font_medium: Font
## Tamaños (en píxeles de diseño de la app).
var chip_size := Vector2(250, 180)
var chip_font := 120
var dial_font := 54
var dial_inner_font := 42
var hint_font := 42
## Diámetro de la esfera (se ajusta al ancho disponible).
var diameter := 700.0

var _chips: Array[Button] = []
var _hint: Label
var _face: Control
var _hand := Vector2.ZERO
var _hand_tween: Tween
var _fade := 1.0
var _dragging := false


## La geometría, como ClockMath de WakeAgenda: ángulos en grados, en el sentido de las agujas y desde las 12.
static func hour_at(angle_deg: float, radius_fraction: float) -> int:
	var slot := posmod(roundi(angle_deg / 30.0), 12)
	if radius_fraction >= INNER_RING_THRESHOLD:
		return 12 if slot == 0 else slot
	return 0 if slot == 0 else 12 + slot


static func minute_at(angle_deg: float) -> int:
	return posmod(roundi(angle_deg / 6.0), 60)


static func angle_of_hour(h: int) -> float:
	return posmod(h, 12) * 30.0


static func angle_of_minute(m: int) -> float:
	return posmod(m, 60) * 6.0


## 00 y 13…23 están en el anillo interior; 1…12, en el exterior.
static func is_inner_ring(h: int) -> bool:
	return h == 0 or h > 12


## Ángulo (0° arriba, sentido horario) de un toque a dx, dy del centro (la y de pantalla crece hacia abajo).
static func angle_of(dx: float, dy: float) -> float:
	return fposmod(rad_to_deg(atan2(dx, -dy)) + 360.0, 360.0)


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 26)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 18)
	add_child(header)
	_chips = [_chip(Mode.HOUR), _chip(Mode.MINUTE)]
	header.add_child(_chips[0])
	var colon := Label.new()
	colon.text = ":"
	colon.add_theme_font_size_override("font_size", chip_font)
	if font_bold != null:
		colon.add_theme_font_override("font", font_bold)
	colon.add_theme_color_override("font_color", ink)
	header.add_child(colon)
	header.add_child(_chips[1])
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", hint_font)
	if font_medium != null:
		_hint.add_theme_font_override("font", font_medium)
	_hint.add_theme_color_override("font_color", quiet)
	add_child(_hint)
	_face = Control.new()
	_face.custom_minimum_size = Vector2(diameter, diameter)
	_face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_face.mouse_filter = Control.MOUSE_FILTER_STOP
	_face.draw.connect(_draw_face)
	_face.gui_input.connect(_on_face_input)
	add_child(_face)
	_hand = _hand_target()
	_refresh(false)


func set_time(h: int, m: int) -> void:
	hour = clampi(h, 0, 23)
	minute = clampi(m, 0, 59)
	if is_inside_tree():
		_refresh(false)


func set_mode(m: Mode) -> void:
	if m == mode:
		return
	mode = m
	_fade = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_fade", 1.0, 0.18)
	tw.parallel().tween_method(func(_v: float) -> void: _face.queue_redraw(), 0.0, 1.0, 0.18)
	_refresh(true)


func _chip(m: Mode) -> Button:
	var b := Button.new()
	b.custom_minimum_size = chip_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", chip_font)
	if font_bold != null:
		b.add_theme_font_override("font", font_bold)
	b.pressed.connect(set_mode.bind(m))
	return b


func _refresh(animate: bool) -> void:
	for i in 2:
		var b := _chips[i]
		var on := (mode == Mode.HOUR) == (i == 0)
		b.text = "%02d" % (hour if i == 0 else minute)
		for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = primary if on else Color(face_color, 0.85)
			sb.set_corner_radius_all(int(chip_size.y * 0.3))
			b.add_theme_stylebox_override(state, sb)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(key, on_primary if on else ink)
	_hint.text = Loc.t("Toca la hora") if mode == Mode.HOUR else Loc.t("Toca o arrastra para los minutos")
	var target := _hand_target()
	if _hand_tween != null:
		_hand_tween.kill()
	if animate and is_inside_tree():
		_hand_tween = create_tween()
		_hand_tween.tween_method(func(p: Vector2) -> void:
			_hand = p
			_face.queue_redraw(), _hand, target, HAND_TIME)
	else:
		_hand = target
		_face.queue_redraw()


func _radius() -> float:
	return diameter * 0.5


func _polar(distance: float, angle_deg: float) -> Vector2:
	var r := _radius()
	var a := deg_to_rad(angle_deg)
	return Vector2(r + distance * sin(a), r - distance * cos(a))


func _hand_target() -> Vector2:
	var r := _radius()
	if mode == Mode.HOUR:
		return _polar(r * (INNER_RING if is_inner_ring(hour) else OUTER_RING), angle_of_hour(hour))
	return _polar(r * OUTER_RING, angle_of_minute(minute))


func _on_face_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var e := event as InputEventMouseButton
		if e.pressed:
			_dragging = true
			pick(e.position, false)
		elif _dragging:
			_dragging = false
			pick(e.position, true)
		_face.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pick((event as InputEventMouseMotion).position, false)
		_face.accept_event()


## Un toque o un arrastre en la esfera, en coordenadas de la esfera. Al soltar en la hora, pasa a los minutos.
func pick(pos: Vector2, finish: bool) -> void:
	var r := _radius()
	var d := pos - Vector2(r, r)
	if d.length() < r * 0.12:
		return
	var angle := angle_of(d.x, d.y)
	if mode == Mode.HOUR:
		var h := hour_at(angle, d.length() / r)
		if h != hour:
			hour = h
			_tick()
			_refresh(true)
		if finish:
			set_mode(Mode.MINUTE)
	else:
		var m := minute_at(angle)
		if m != minute:
			minute = m
			_tick()
			_refresh(true)


func _tick() -> void:
	changed.emit(hour, minute)
	if OS.has_feature("android"):
		Input.vibrate_handheld(8)


func _draw_face() -> void:
	var r := _radius()
	var c := Vector2(r, r)
	# Esfera con un degradado suave hacia el borde.
	for k in range(14, 0, -1):
		var t := float(k) / 14.0
		_face.draw_circle(c, r * t, Color(face_color, lerpf(0.3, 0.85, t)).lerp(Color(face_color, 0.85), t))
	# Una marca por minuto; más grande cada 5.
	for i in 60:
		var big := i % 5 == 0
		_face.draw_circle(_polar(r * 0.94, i * 6.0), 6.5 if big else 3.5, Color(ink, 0.4 if big else 0.18))
	# Aguja con su bolita.
	var bubble := 54.0 if mode == Mode.HOUR and is_inner_ring(hour) else 64.0
	_face.draw_line(c, _hand, primary, 7.0, true)
	_face.draw_circle(_hand, bubble + 15.0, Color(primary, 0.18))
	_face.draw_circle(_hand, bubble, primary)
	_face.draw_circle(c, 15.0, primary)
	# Cifras.
	var font := font_medium if font_medium != null else ThemeDB.fallback_font
	var bold := font_bold if font_bold != null else font
	var alpha := _fade
	if mode == Mode.HOUR:
		for slot in 12:
			var outer_h := 12 if slot == 0 else slot
			_number("%d" % outer_h, _polar(r * OUTER_RING, slot * 30.0), dial_font, hour == outer_h, font, bold, alpha)
			var inner_h := 0 if slot == 0 else 12 + slot
			_number("%02d" % inner_h, _polar(r * INNER_RING, slot * 30.0), dial_inner_font, hour == inner_h, font, bold, alpha)
	else:
		var odd := minute % 5 != 0
		for slot in 12:
			var v := slot * 5
			# Con un minuto suelto (32), las cifras que tapa la bolita se apagan para que no se monten.
			var near := odd and absf(angle_difference(deg_to_rad(slot * 30.0), deg_to_rad(angle_of_minute(minute)))) < deg_to_rad(20.0)
			_number("%02d" % v, _polar(r * OUTER_RING, slot * 30.0), dial_font, minute == v, font, bold, alpha * (0.18 if near else 1.0))
		# Un minuto que no es múltiplo de 5 no tiene cifra en la esfera: se escribe sobre la bolita.
		if minute % 5 != 0:
			_number("%02d" % minute, _hand, dial_font, true, font, bold, alpha)


func _number(text: String, at: Vector2, font_size: int, selected: bool, font: Font, bold: Font, alpha: float) -> void:
	var f := bold if selected else font
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := at + Vector2(-sz.x * 0.5, f.get_ascent(font_size) - sz.y * 0.5)
	_face.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(on_primary if selected else ink, alpha))
