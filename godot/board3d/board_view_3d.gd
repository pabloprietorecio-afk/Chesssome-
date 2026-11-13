class_name BoardView3D
extends SubViewportContainer
## El tablero 3D como control de interfaz: se coloca en cualquier pantalla, recibe los toques y avisa de las
## jugadas. Ofrece lo mismo que el tablero 2D (misma información, mismos avisos) para poder compararlos.
##
## Toque: tocar una pieza y luego su destino, o arrastrarla. Con dos dedos se gira la vista.
## Opcional: la vista sigue la inclinación del móvil (giroscopio); se puede fijar o desactivar.

## La jugada ya se ha hecho en el tablero (texto UCI, p. ej. «e2e4»).
signal move_played(uci: String)
## Para medir toques fallidos: "select", "deselect", "illegal" o "move".
signal tapped(kind: String)

const DRAG_THRESHOLD := 18.0
## Sentido del giro con el móvil. Sin verificar en un dispositivo real: si gira al revés, cambiar el signo.
const ROLL_SIGN := 1.0
const TWIST_SIGN := 1.0

var board: Board3D
var interactive := true
## La vista sigue al móvil.
var tilt_enabled := false
## Vista fijada: ni el móvil ni los dedos la cambian.
var view_locked := false

var _viewport: SubViewport
var _touches := {}
var _orbiting := false
var _drag_from := -1
var _press_pos := Vector2.ZERO
var _dragging := false
var _press_same := false
var _promo_panel: PanelContainer
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
	stretch = true
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	board = Board3D.new()
	_viewport.add_child(board)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_promotion_panel()


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


## Botón «Centrar»: vista en picado sobre el tablero.
func center_view() -> void:
	board.animate_view(90.0, 0.0)
	_tilt_ref_set = false


## Vuelve a la vista inclinada de siempre.
func default_view() -> void:
	board.animate_view(Board3D.DEFAULT_PITCH, 0.0)
	_tilt_ref_set = false


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
				# Segundo dedo: se pasa a girar la vista y se suelta la pieza.
				_cancel_piece_drag()
				_orbiting = true
		else:
			var single := _touches.size() == 1 and not _orbiting
			_touches.erase(e.index)
			if single:
				_on_release(e.position)
			if _touches.is_empty():
				_orbiting = false
				_tilt_ref_set = false
		accept_event()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		_touches[e.index] = e.position
		if _orbiting:
			if not view_locked:
				board.set_view(board.cam_pitch + e.relative.y * 0.12, board.cam_yaw - e.relative.x * 0.16)
		else:
			_on_drag(e.position)
		accept_event()


func _reset_touch() -> void:
	_drag_from = -1
	_dragging = false
	_press_same = false


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
	if not interactive:
		return
	board.finish_animations()
	var pk := board.pick(pos)
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
	if sel >= 0:
		board.shake(sel)
		board.deselect()
		tapped.emit("illegal")


func _on_drag(pos: Vector2) -> void:
	if _drag_from < 0:
		return
	if not _dragging and pos.distance_to(_press_pos) > DRAG_THRESHOLD:
		_dragging = true
	if _dragging:
		board.drag_piece(_drag_from, pos)


func _on_release(_pos: Vector2) -> void:
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.96)
	style.set_corner_radius_all(36)
	style.set_content_margin_all(24.0)
	style.shadow_color = Color(0.18, 0.36, 0.66, 0.25)
	style.shadow_size = 18
	_promo_panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_promo_panel.add_child(row)
	var names := {Chess.QUEEN: "Dama", Chess.ROOK: "Torre", Chess.BISHOP: "Alfil", Chess.KNIGHT: "Caballo"}
	for t: int in names:
		var b := Button.new()
		b.text = names[t]
		b.custom_minimum_size = Vector2(190.0, 120.0)
		b.add_theme_font_size_override("font_size", 38)
		b.pressed.connect(_on_promotion_chosen.bind(t))
		row.add_child(b)
	add_child(_promo_panel)
	_promo_panel.set_anchors_preset(Control.PRESET_CENTER)
	_promo_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_promo_panel.grow_vertical = Control.GROW_DIRECTION_BOTH


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
