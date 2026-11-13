class_name BoardView3D
extends Control
## El tablero 3D como control de interfaz: se coloca en cualquier pantalla, recibe los toques y avisa de las
## jugadas. Ofrece lo mismo que el tablero 2D (misma información, mismos avisos) para poder compararlos.
##
## Toque: tocar una pieza y luego su destino, o arrastrarla.
## Dos dedos: pellizcar amplía el tablero (puede hacerse más ancho que la pantalla); arrastrarlos gira la
## vista o, si el tablero está ampliado, lo desplaza. Con el tablero ampliado también se desplaza con un
## dedo, arrastrando desde donde no haya una pieza propia.
## Opcional: la vista sigue la inclinación del móvil (giroscopio); se puede fijar o desactivar.
##
## El 3D se dibuja en una vista opaca con el mismo color de fondo que la pantalla y a los píxeles reales
## del dispositivo (no a las unidades del lienzo): así el tablero sale nítido en cualquier móvil.

## La jugada ya se ha hecho en el tablero (texto UCI, p. ej. «e2e4»).
signal move_played(uci: String)
## Para medir toques fallidos: "select", "deselect", "illegal" o "move".
signal tapped(kind: String)

const DRAG_THRESHOLD := 18.0
## Recorrido de los dos dedos a partir del cual se decide qué gesto es.
const GESTURE_THRESHOLD := 14.0
## Sentido del giro con el móvil. Sin verificar en un dispositivo real: si gira al revés, cambiar el signo.
const ROLL_SIGN := 1.0
const TWIST_SIGN := 1.0
## Fundido de los bordes de arriba y de abajo con el fondo de la pantalla.
const FADE_SHADER := """
shader_type canvas_item;
uniform float fade_top = 0.0;
uniform float fade_bottom = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 1.0;
	if (fade_top > 0.0) {
		a *= smoothstep(0.0, fade_top, UV.y);
	}
	if (fade_bottom > 0.0) {
		a *= smoothstep(0.0, fade_bottom, 1.0 - UV.y);
	}
	COLOR = vec4(c.rgb, a);
}
"""

var board: Board3D
var interactive := true
## La vista sigue al móvil.
var tilt_enabled := false
## Vista fijada: ni el móvil ni los dedos la cambian.
var view_locked := false
## Franja (en unidades del lienzo), arriba y abajo, en la que la vista se funde con el fondo de la pantalla.
## Sirve para colocar el control algo más alto que el hueco del tablero sin que se note dónde acaba.
var edge_fade := 0.0:
	set(value):
		edge_fade = maxf(value, 0.0)
		_sync_surface()

var _surface: SubViewportContainer
var _viewport: SubViewport
var _fade: ShaderMaterial
## Píxeles de la vista 3D por cada unidad de este control.
var _ratio := Vector2.ONE
enum Gesture { NONE, PENDING, ZOOM, ORBIT }

var _touches := {}
## Hay (o ha habido, hasta que se levanten todos) dos dedos en la pantalla: no se tocan piezas.
var _multi := false
var _gesture := Gesture.NONE
var _g_start_dist := 0.0
var _g_start_mid := Vector2.ZERO
var _g_dist := 0.0
var _g_mid := Vector2.ZERO
## Toque de un dedo donde no hay nada que seleccionar: al arrastrar, desplaza el tablero ampliado.
var _empty_press := false
var _panning := false
var _pan_last := Vector2.ZERO
var _drag_from := -1
var _press_pos := Vector2.ZERO
var _dragging := false
var _press_same := false
var _promo_panel: PanelContainer
var _promo_title: Label
var _promo_buttons: Array[Button] = []
var _promo_moves := PackedInt32Array()
var _promo_dropped := false
var _tilt_ref_set := false
var _tilt_ref_elev := 0.0
var _tilt_ref_roll := 0.0
var _tilt_base_pitch := 0.0
var _tilt_base_yaw := 0.0
var _tilt_twist := 0.0
var _tilt_pitch := 0.0
var _tilt_yaw := 0.0


func _init() -> void:
	_surface = SubViewportContainer.new()
	# Sin estirar: la vista 3D tiene el tamaño en píxeles reales y el contenedor se escala para ocupar el control.
	_surface.stretch = false
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_shader := Shader.new()
	fade_shader.code = FADE_SHADER
	_fade = ShaderMaterial.new()
	_fade.shader = fade_shader
	_surface.material = _fade
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true
	_viewport.size = Vector2i(64, 64)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_surface.add_child(_viewport)
	add_child(_surface)
	board = Board3D.new()
	_viewport.add_child(board)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_promotion_panel()
	get_viewport().size_changed.connect(_sync_surface)
	_sync_surface()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_surface()


## Ajusta la vista 3D al tamaño del control en píxeles reales de la pantalla.
func _sync_surface() -> void:
	if _surface == null or not is_inside_tree() or size.x < 1.0 or size.y < 1.0:
		return
	var canvas := get_viewport_rect().size
	var window := get_window().size
	var px := 1.0
	if canvas.x > 0.0 and window.x > 0:
		px = clampf(float(window.x) / canvas.x, 0.25, 4.0)
	var want := Vector2i(maxi(int(round(size.x * px)), 8), maxi(int(round(size.y * px)), 8))
	if _viewport.size != want:
		_viewport.size = want
	_ratio = Vector2(want) / size
	_surface.position = Vector2.ZERO
	_surface.size = Vector2(want)
	_surface.scale = Vector2.ONE / _ratio
	_fade.set_shader_parameter("fade_top", edge_fade / size.y)
	_fade.set_shader_parameter("fade_bottom", edge_fade / size.y)


## De un punto de este control (unidades del lienzo) al mismo punto en la vista 3D (píxeles), y al revés.
func local_to_view(p: Vector2) -> Vector2:
	return p * _ratio


func view_to_local(p: Vector2) -> Vector2:
	return p / _ratio


# ---------------------------------------------------------------- interfaz pública

func set_fen(fen: String) -> void:
	_hide_promotion()
	_reset_touch()
	board.set_fen(fen)


func set_orientation(o: int) -> void:
	board.set_orientation(o)
	_tilt_ref_set = false


## Juega una jugada desde fuera (la del rival, la solución…). Devuelve false si no es legal.
func show_move(uci: String) -> bool:
	var m := board.chess.find_uci(uci)
	if m < 0:
		return false
	board.play_move(m)
	return true


## Tema claro u oscuro ("light" | "dark") del tablero y de sus ventanas, y color de fondo de la pantalla
## que lo contiene (la vista 3D se pinta de ese color para que no se note dónde acaba).
## (No se llama set_theme: ese nombre ya es de Control.)
func set_board_theme(theme_name: String, backdrop: Color = Color(0, 0, 0, 0)) -> void:
	if backdrop.a > 0.0:
		board.set_backdrop(backdrop)
	board.set_theme(theme_name)
	_style_promotion(theme_name == "dark")


## La vista actual es (casi) en picado.
func is_top_view() -> bool:
	return board.cam_pitch > 84.0


## Botón «Centrar»: vista en picado sobre el tablero, entero (deshace la ampliación).
func center_view() -> void:
	board.animate_view(90.0, 0.0)
	_tilt_ref_set = false


## Vuelve a la vista inclinada de siempre, con el tablero entero.
func default_view() -> void:
	board.animate_view(Board3D.DEFAULT_PITCH, 0.0)
	_tilt_ref_set = false


## El jugador ha ampliado el tablero con los dedos.
func is_zoomed() -> bool:
	return board.zoom > 1.02


## Deshace la ampliación sin cambiar la inclinación ni el giro.
func reset_zoom() -> void:
	board.animate_view(board.cam_pitch, board.cam_yaw, 0.3)


func set_tilt_enabled(on: bool) -> void:
	tilt_enabled = on
	_tilt_ref_set = false


func set_view_locked(on: bool) -> void:
	view_locked = on
	_tilt_ref_set = false


# ---------------------------------------------------------------- toques

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_on_press(e.position)
			else:
				# Segundo dedo: se suelta la pieza y empieza un gesto de dos dedos.
				_cancel_piece_drag()
				_multi = true
				_start_gesture()
		else:
			var single := _touches.size() == 1 and not _multi
			_touches.erase(e.index)
			if single:
				_on_release(e.position)
			if _touches.size() < 2:
				_gesture = Gesture.NONE
			if _touches.is_empty():
				_multi = false
				_tilt_ref_set = false
		accept_event()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		_touches[e.index] = e.position
		if _multi:
			_two_finger_update()
		else:
			_on_drag(e.position)
		accept_event()


# ---------------------------------------------------------------- dos dedos: ampliar, desplazar y girar

func _two_fingers() -> PackedVector2Array:
	var keys := _touches.keys()
	keys.sort()
	return PackedVector2Array([_touches[keys[0]], _touches[keys[1]]])


func _start_gesture() -> void:
	var f := _two_fingers()
	_gesture = Gesture.PENDING
	_g_start_dist = f[0].distance_to(f[1])
	_g_start_mid = (f[0] + f[1]) * 0.5
	_g_dist = _g_start_dist
	_g_mid = _g_start_mid


func _two_finger_update() -> void:
	if _touches.size() < 2 or view_locked or _gesture == Gesture.NONE:
		return
	var f := _two_fingers()
	var dist := f[0].distance_to(f[1])
	var mid := (f[0] + f[1]) * 0.5
	if _gesture == Gesture.PENDING:
		var spread := absf(dist - _g_start_dist)
		var travel := mid.distance_to(_g_start_mid)
		if maxf(spread, travel) < GESTURE_THRESHOLD:
			return
		# Si los dedos se separan o se juntan, es ampliar. Si van a la par: con el tablero ampliado es
		# desplazarlo (y el pellizco sigue ampliando); sin ampliar, es girar la vista.
		_gesture = Gesture.ZOOM if (spread >= travel or board.zoom > 1.02) else Gesture.ORBIT
		_g_dist = dist
		_g_mid = mid
		return
	if _gesture == Gesture.ZOOM:
		if _g_dist > 1.0 and dist > 1.0:
			board.zoom_at(dist / _g_dist, local_to_view(mid))
		board.pan_by((mid - _g_mid) * _ratio)
	elif _gesture == Gesture.ORBIT:
		var d := mid - _g_mid
		board.set_view(board.cam_pitch + d.y * 0.24, board.cam_yaw - d.x * 0.32)
	_g_dist = dist
	_g_mid = mid


# ---------------------------------------------------------------- un dedo: piezas (y desplazar si está ampliado)

func _reset_touch() -> void:
	_drag_from = -1
	_dragging = false
	_press_same = false
	_empty_press = false
	_panning = false


func _cancel_piece_drag() -> void:
	if _dragging:
		board.cancel_drag()
	_reset_touch()


func _on_press(pos: Vector2) -> void:
	if _promo_panel.visible:
		_hide_promotion()
		board.cancel_drag()
		board.deselect()
		return
	_reset_touch()
	if interactive:
		board.finish_animations()
		var pk := board.pick(local_to_view(pos))
		var sel := board.selected
		if sel >= 0:
			var dest := -1
			if pk.y >= 0 and board.is_target(pk.y):
				dest = pk.y
			elif pk.x >= 0 and board.is_target(pk.x):
				dest = pk.x
			if dest >= 0:
				_try_move(dest, false)
				return
		var own := -1
		if pk.y >= 0 and board.is_own(pk.y):
			own = pk.y
		elif pk.x >= 0 and board.is_own(pk.x):
			own = pk.x
		if own >= 0:
			_press_same = own == sel
			if not _press_same:
				board.select(own)
				tapped.emit("select")
			_drag_from = own
			_press_pos = pos
			_dragging = false
			return
	# Aquí no hay nada que seleccionar (o ahora no se puede jugar). Qué era el toque se decide al soltar:
	# si el tablero está ampliado y el dedo se arrastra, lo desplaza; si no, es un toque en vacío.
	_empty_press = true
	_press_pos = pos
	_pan_last = pos


func _on_drag(pos: Vector2) -> void:
	if _empty_press:
		if not _panning and not view_locked and board.zoom > 1.02 and pos.distance_to(_press_pos) > DRAG_THRESHOLD:
			_panning = true
			_pan_last = pos
		if _panning:
			board.pan_by((pos - _pan_last) * _ratio)
			_pan_last = pos
		return
	if _drag_from < 0:
		return
	if not _dragging and pos.distance_to(_press_pos) > DRAG_THRESHOLD:
		_dragging = true
	if _dragging:
		board.drag_piece(_drag_from, local_to_view(pos))


func _on_release(_pos: Vector2) -> void:
	if _empty_press:
		# Toque en vacío con una pieza seleccionada: «ahí no» y se suelta la selección.
		if not _panning and interactive and board.selected >= 0:
			board.shake(board.selected)
			board.deselect()
			tapped.emit("illegal")
		_reset_touch()
		return
	if _drag_from < 0:
		return
	if _dragging:
		var dest := board.drag_square()
		if dest >= 0 and dest != _drag_from and board.is_target(dest):
			_try_move(dest, true)
		else:
			board.cancel_drag()
			if dest != _drag_from:
				tapped.emit("illegal")
	elif _press_same:
		board.deselect()
		tapped.emit("deselect")
	_reset_touch()


func _try_move(dest: int, dropped: bool) -> void:
	var moves := board.moves_to(dest)
	if moves.is_empty():
		return
	if moves.size() > 1:
		_promo_moves = moves
		_promo_dropped = dropped
		_promo_panel.visible = true
		return
	_commit(moves[0], dropped)


func _commit(m: int, dropped: bool) -> void:
	var uci := Chess.uci(m)
	board.play_move(m, dropped)
	tapped.emit("move")
	move_played.emit(uci)


# ---------------------------------------------------------------- promoción

func _build_promotion_panel() -> void:
	_promo_panel = PanelContainer.new()
	_promo_panel.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_promo_panel.add_child(column)
	_promo_title = Label.new()
	_promo_title.text = "¿En qué pieza se convierte?"
	_promo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_promo_title.add_theme_font_size_override("font_size", 32)
	column.add_child(_promo_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var names := {Chess.QUEEN: "Dama", Chess.ROOK: "Torre", Chess.BISHOP: "Alfil", Chess.KNIGHT: "Caballo"}
	for t: int in names:
		var b := Button.new()
		b.text = names[t]
		b.custom_minimum_size = Vector2(196.0, 116.0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 36)
		b.pressed.connect(_on_promotion_chosen.bind(t))
		row.add_child(b)
		_promo_buttons.append(b)
	add_child(_promo_panel)
	_promo_panel.set_anchors_preset(Control.PRESET_CENTER)
	_promo_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_promo_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_style_promotion(false)


func _style_promotion(dark: bool) -> void:
	if _promo_panel == null:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("151d36") if dark else Color.WHITE
	panel.set_corner_radius_all(40)
	panel.set_content_margin_all(26.0)
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.45) if dark else Color(0.12, 0.2, 0.42, 0.28)
	panel.shadow_size = 28
	panel.shadow_offset = Vector2(0.0, 8.0)
	_promo_panel.add_theme_stylebox_override("panel", panel)
	_promo_title.add_theme_color_override("font_color", Color("a9b1c7") if dark else Color("5b6782"))
	var fg := Color("edeff7") if dark else Color("1b2540")
	for b in _promo_buttons:
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("222c4e") if dark else Color("eaf1fb")
			if state == "pressed":
				sb.bg_color = Color("3a2416") if dark else Color("ffebd9")
			sb.set_corner_radius_all(30)
			sb.set_content_margin_all(14.0)
			b.add_theme_stylebox_override(state, sb)
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, fg)


func _hide_promotion() -> void:
	if _promo_panel != null:
		_promo_panel.visible = false
	_promo_moves = PackedInt32Array()


func _on_promotion_chosen(piece_type: int) -> void:
	var chosen := -1
	for m in _promo_moves:
		if Chess.move_promo(m) == piece_type:
			chosen = m
	var dropped := _promo_dropped
	_hide_promotion()
	if chosen >= 0:
		_commit(chosen, dropped)


# ---------------------------------------------------------------- la vista sigue al móvil

func _process(delta: float) -> void:
	if not tilt_enabled or view_locked or not _touches.is_empty():
		# Con un dedo en la pantalla la vista se queda quieta: el tablero no puede moverse bajo el dedo.
		_tilt_ref_set = false
		return
	var g := Input.get_gravity()
	if g.length() < 1.0:
		return
	g = g.normalized()
	# Elevación del móvil: 0 tumbado sobre la mesa, 90° de pie. No depende del signo de los ejes.
	var elev := rad_to_deg(atan2(absf(g.y), absf(g.z)))
	var roll := rad_to_deg(asin(clampf(g.x, -1.0, 1.0)))
	var gyro := Input.get_gyroscope()
	var twist_rate := rad_to_deg(gyro.dot(g))
	if not _tilt_ref_set:
		_tilt_ref_set = true
		_tilt_ref_elev = elev
		_tilt_ref_roll = roll
		_tilt_base_pitch = board.cam_pitch
		_tilt_base_yaw = board.cam_yaw
		_tilt_twist = 0.0
		_tilt_pitch = board.cam_pitch
		_tilt_yaw = board.cam_yaw
		return
	if absf(twist_rate) > 1.5:
		_tilt_twist = clampf(_tilt_twist + twist_rate * delta * TWIST_SIGN, -70.0, 70.0)
	# Tumbar el móvil acerca la vista al picado; ladearlo o girarlo rodea el tablero.
	var want_pitch := clampf(_tilt_base_pitch + (_tilt_ref_elev - elev), Board3D.PITCH_MIN, Board3D.PITCH_MAX)
	var want_yaw := _tilt_base_yaw + clampf((roll - _tilt_ref_roll) * 1.2 * ROLL_SIGN, -40.0, 40.0) + _tilt_twist
	var k := 1.0 - exp(-delta * 9.0)
	_tilt_pitch = lerpf(_tilt_pitch, want_pitch, k)
	_tilt_yaw = lerpf(_tilt_yaw, want_yaw, k)
	if absf(_tilt_pitch - board.cam_pitch) > 0.02 or absf(_tilt_yaw - board.cam_yaw) > 0.02:
		board.set_view(_tilt_pitch, _tilt_yaw)
