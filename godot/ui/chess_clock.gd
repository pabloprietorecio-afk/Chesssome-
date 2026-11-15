class_name ChessClock
extends Control
## Reloj de ajedrez «de verdad», dibujado con una ligera perspectiva: un cuerpo en cuña con dos pantallas que
## muestran el tiempo que le queda a cada uno y dos pulsadores encima.
##
## Como en un reloj real, el pulsador del lado que está corriendo está arriba: al pulsar el tuyo, baja, sube el del
## rival y empieza a correr su tiempo. Toda la mitad izquierda (la tuya) responde al toque, para acertar sin mirar.
## La animación del pulsador (`up_mine`) la lleva quien usa el reloj; aquí solo se dibuja.
##
## El modelo está en unidades propias (x a la derecha, y hacia arriba, z hacia quien mira) y se proyecta con una
## cámara de perspectiva un poco por encima; después se encaja en el rectángulo del control.

signal pressed_mine
## Has tocado tu lado cuando no tocaba pulsar (para avisar con suavidad).
signal pressed_early

## Tiempo que le queda a cada uno, en milisegundos: [tuyo, del rival].
var times := [0.0, 0.0]
## Quién corre: 0 = tú, 1 = el rival, -1 = nadie (partida terminada).
var running := 0
## Altura de tu pulsador: 1 = arriba, 0 = abajo. El del rival, al revés.
var up_mine := 1.0
## Toca pulsar: tu pulsador se ilumina y una flecha lo señala.
var call_press := false
## Puede pulsarse ahora (si no, un toque solo da `pressed_early`).
var can_press := false
var labels := ["TÚ", "RIVAL"]
var digits_font: Font
var label_font: Font
var dark := false
var accent := Color("ffa366")

# Medidas del modelo.
const W := 10.0
const H := 2.3
const Z_BACK := -1.7
const Z_TOP_FRONT := 0.55
const Z_BOTTOM_FRONT := 1.55
const BTN_X := 2.45
const BTN_W := 2.7
const BTN_D := 1.35
const BTN_Z := -0.55
const BTN_UP := 0.78
const BTN_DOWN := 0.16

## Texturas (se generan una vez, en segundo plano): nogal para el cuerpo y metal cepillado para el panel.
static var _wood: NoiseTexture2D
static var _metal: NoiseTexture2D

var _cam := Vector3(0.0, 12.5, 13.0)
var _look := Vector3(0.0, 0.9, 0.0)
var _right := Vector3.RIGHT
var _upv := Vector3.UP
var _fwd := Vector3.FORWARD
var _scale := 1.0
var _offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _wood == null:
		_wood = _make_wood()
		_metal = _make_metal()
	for t: Texture2D in [_wood, _metal]:
		if not t.changed.is_connected(queue_redraw):
			t.changed.connect(queue_redraw)


## Veta de nogal: ruido con el dominio deformado y una rampa de tonos que se alternan (los anillos). Al
## dibujarla se estira a lo largo, y salen las vetas.
static func _make_wood() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = 7
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.006
	n.fractal_octaves = 2
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 40.0
	n.domain_warp_frequency = 0.01
	var g := Gradient.new()
	var dark_wood := Color("4a2c1a")
	var mid_wood := Color("6b4128")
	var light_wood := Color("8a5a36")
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for k in 15:
		offs.append(float(k) / 14.0)
		cols.append([dark_wood, mid_wood, light_wood, mid_wood][k % 4])
	g.offsets = offs
	g.colors = cols
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.noise = n
	t.color_ramp = g
	return t


## Metal cepillado: ruido muy fino que, estirado a lo largo, da las rayas del cepillado.
static func _make_metal() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = 3
	n.noise_type = FastNoiseLite.TYPE_VALUE
	n.frequency = 0.35
	n.fractal_octaves = 2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color("1d222c"), Color("2a303c"), Color("394150")])
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.noise = n
	t.color_ramp = g
	return t


func _gui_input(e: InputEvent) -> void:
	var at := Vector2(-1.0, -1.0)
	# Los toques llegan como ratón (emulación de Godot), así que basta con esto.
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (e as InputEventMouseButton).position
	if at.x < 0.0 or at.x >= size.x * 0.5:
		return
	accept_event()
	if can_press:
		pressed_mine.emit()
	else:
		pressed_early.emit()


## Texto del tiempo: m:ss, h:mm:ss con más de una hora y décimas por debajo de diez segundos.
static func time_text(ms: float) -> String:
	if ms < 10000.0:
		return "%.1f" % (maxf(ms, 0.0) / 1000.0)
	var secs := int(ceil(ms / 1000.0))
	if secs >= 3600:
		return "%d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	return "%d:%02d" % [secs / 60, secs % 60]


# ---------------------------------------------------------------- proyección

func _setup_camera() -> void:
	_fwd = (_look - _cam).normalized()
	_right = _fwd.cross(Vector3.UP).normalized()
	_upv = _right.cross(_fwd)
	# Encaje: se proyectan las esquinas del cuerpo y de los pulsadores levantados.
	_scale = 1.0
	_offset = Vector2.ZERO
	var pts: Array[Vector2] = []
	for x: float in [-W * 0.5, W * 0.5]:
		pts.append(_raw(Vector3(x, 0.0, Z_BOTTOM_FRONT)))
		pts.append(_raw(Vector3(x, H, Z_BACK)))
		pts.append(_raw(Vector3(x * 0.72, H + BTN_UP + 0.95, BTN_Z - BTN_D * 0.5)))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	var pad := Vector2(12.0, 10.0)
	var avail := size - pad * 2.0
	_scale = minf(avail.x / r.size.x, avail.y / r.size.y)
	_offset = pad + (avail - r.size * _scale) * 0.5 - r.position * _scale


func _raw(p: Vector3) -> Vector2:
	var v := p - _cam
	var zc := v.dot(_fwd)
	return Vector2(v.dot(_right), -v.dot(_upv)) / zc * 10.0


func _p(p: Vector3) -> Vector2:
	return _raw(p) * _scale + _offset


## Rectángulo redondeado en coordenadas de una cara (u, v en [0, 1]) llevado a 3D por `to3`.
func _face_poly(to3: Callable, u0: float, v0: float, u1: float, v1: float, ru: float, rv: float) -> PackedVector2Array:
	return _face_uv(to3, u0, v0, u1, v1, ru, rv)[0]


## Lo mismo, con las coordenadas de la cara de cada punto (para las texturas): [puntos, uv].
func _face_uv(to3: Callable, u0: float, v0: float, u1: float, v1: float, ru: float, rv: float) -> Array:
	var out := PackedVector2Array()
	var uv := PackedVector2Array()
	var corners := [[u1 - ru, v0 + rv, -PI * 0.5], [u1 - ru, v1 - rv, 0.0], [u0 + ru, v1 - rv, PI * 0.5], [u0 + ru, v0 + rv, PI]]
	for c: Array in corners:
		for k in 7:
			var a := float(c[2]) + PI * 0.5 * float(k) / 6.0
			var u := float(c[0]) + cos(a) * ru
			var v := float(c[1]) + sin(a) * rv
			out.append(_p(to3.call(u, v)))
			uv.append(Vector2(u, v))
	return [out, uv]


## Polígono con textura: `uv` en coordenadas de la cara, llevadas a un trozo de la textura (`rect`), y un tinte.
func _textured(pts: PackedVector2Array, uv: PackedVector2Array, tex: Texture2D, rect: Rect2, tint: Color) -> void:
	if tex == null or tex.get_width() <= 1:
		draw_colored_polygon(pts, tint.darkened(0.55))
		return
	var tuv := PackedVector2Array()
	for q in uv:
		tuv.append(rect.position + q * rect.size)
	draw_polygon(pts, PackedColorArray([tint]), tuv, tex)


func _top3(u: float, v: float) -> Vector3:
	# Cara de arriba: u de izquierda a derecha, v de atrás hacia delante.
	return Vector3(lerpf(-W * 0.5, W * 0.5, u), H, lerpf(Z_BACK, Z_TOP_FRONT, v))


func _front3(u: float, v: float) -> Vector3:
	# Cara de delante (inclinada hacia atrás): v de arriba abajo.
	return Vector3(lerpf(-W * 0.5, W * 0.5, u), lerpf(H, 0.0, v), lerpf(Z_TOP_FRONT, Z_BOTTOM_FRONT, v))


# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return
	_setup_camera()
	var body_top := Color("2a3247") if dark else Color("fbfcff")
	var body_front := Color("1f2638") if dark else Color("e4e9f3")
	var edge := Color("3a4460") if dark else Color("ffffff")
	var outline := Color(0.0, 0.0, 0.0, 0.35) if dark else Color(0.18, 0.24, 0.42, 0.16)
	# Sombra suave sobre la mesa, un poco por delante del cuerpo (varias capas que se van abriendo).
	for layer in 6:
		var grow := 0.035 * float(layer)
		var sh := PackedVector2Array()
		for k in 48:
			var a := TAU * float(k) / 48.0
			sh.append(_p(Vector3(cos(a) * W * (0.47 + grow), 0.0, 0.35 + sin(a) * (1.55 + grow * 4.0))))
		draw_colored_polygon(sh, Color(0.1, 0.14, 0.3, (0.035 if not dark else 0.09)))
	# Cuerpo de nogal: la cara de delante, un poco más oscura (le llega menos luz), y la de arriba.
	var front := _face_uv(_front3, 0.0, 0.0, 1.0, 1.0, 0.035, 0.12)
	var top := _face_uv(_top3, 0.0, 0.0, 1.0, 1.0, 0.035, 0.14)
	_textured(front[0], front[1], _wood, Rect2(0.5, 0.0, 0.16, 1.0), Color(0.86, 0.86, 0.86))
	draw_polyline(_closed(front[0]), Color(0.1, 0.05, 0.02, 0.5), 2.0, true)
	_textured(top[0], top[1], _wood, Rect2(0.2, 0.0, 0.16, 1.0), Color.WHITE)
	# Barniz: un brillo suave que cruza la cara de arriba.
	var gloss := _face_poly(_top3, 0.08, 0.18, 0.92, 0.42, 0.03, 0.1)
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.07))
	draw_polyline(_closed(top[0]), Color(0.1, 0.05, 0.02, 0.5), 2.0, true)
	# Canto entre las dos caras, con un brillo.
	draw_line(_p(_front3(0.02, 0.0)), _p(_front3(0.98, 0.0)), Color(1.0, 0.85, 0.7, 0.35), 3.0, true)
	# Panel de metal cepillado con las pantallas, y sus cuatro tornillos.
	var panel := _face_uv(_front3, 0.03, 0.08, 0.97, 0.94, 0.03, 0.12)
	_textured(panel[0], panel[1], _metal, Rect2(0.3, 0.0, 0.025, 1.0), Color.WHITE)
	draw_polyline(_closed(panel[0]), Color(1, 1, 1, 0.16), 2.0, true)
	for corner: Vector2 in [Vector2(0.05, 0.18), Vector2(0.95, 0.18), Vector2(0.05, 0.84), Vector2(0.95, 0.84)]:
		_draw_screw(_p(_front3(corner.x, corner.y)))
	_draw_plate()
	# Pantallas.
	for side in 2:
		_draw_screen(side)
	# Huecos de los pulsadores y pulsadores (primero el de detrás no importa: no se tapan).
	for side in 2:
		var cx := -BTN_X if side == 0 else BTN_X
		var slot := _box_top_poly(cx, H + 0.001, BTN_W + 0.36, BTN_D + 0.3)
		draw_colored_polygon(slot, Color("141a28") if dark else Color("cfd7e6"))
	for side in 2:
		_draw_button(side)
	if call_press:
		_draw_call()


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.append(p[0])
	return out


func _draw_screen(side: int) -> void:
	var u0 := 0.055 if side == 0 else 0.53
	var u1 := 0.47 if side == 0 else 0.945
	u0 += 0.035 if side == 0 else 0.0
	u1 -= 0.0 if side == 0 else 0.035
	var on := running == side
	# Bisel: un marco claro arriba y oscuro abajo, como hundido en el panel.
	var bezel := _face_poly(_front3, u0 - 0.008, 0.13, u1 + 0.008, 0.68, 0.028, 0.1)
	draw_colored_polygon(bezel, Color("0b0d12"))
	draw_polyline(_closed(bezel), Color(1, 1, 1, 0.12), 2.0, true)
	var lcd_on := Color("142a22") if on else Color("10161a")
	var lcd := _face_poly(_front3, u0, 0.15, u1, 0.66, 0.025, 0.09)
	draw_colored_polygon(lcd, lcd_on)
	# Luz de la pantalla encendida (más clara por arriba).
	if on:
		draw_colored_polygon(_face_poly(_front3, u0 + 0.004, 0.16, u1 - 0.004, 0.42, 0.02, 0.07), Color(0.5, 1.0, 0.8, 0.06))
	var ms := float(times[side])
	var low := ms < 10000.0 and running != -1
	var ink := Color("ff7a8a") if low else (Color("d9fff0") if on else Color("5e6a72"))
	if digits_font != null:
		var text := time_text(ms)
		# Segmentos apagados detrás de las cifras, como en una pantalla de cristal líquido.
		var ghost := ""
		for ch in text:
			ghost += "8" if ch >= "0" and ch <= "9" else ch
		_draw_on_front(ghost, digits_font, u0, 0.19, u1, 0.62, Color(1, 1, 1, 0.045), 0.78)
		_draw_on_front(text, digits_font, u0, 0.19, u1, 0.62, ink, 0.78)
	# Brillo del cristal en diagonal.
	var g0 := _p(_front3(u0 + 0.02, 0.17))
	var g1 := _p(_front3(u0 + 0.12, 0.17))
	var g2 := _p(_front3(u0 + 0.07, 0.62))
	var g3 := _p(_front3(u0 - 0.0, 0.62))
	draw_colored_polygon(PackedVector2Array([g0, g1, g2, g3]), Color(1, 1, 1, 0.04))
	# Etiqueta grabada debajo; se ilumina la del lado que corre.
	if label_font != null:
		var lab_ink := accent if on else Color("9aa3b5")
		_draw_on_front(str(labels[side]), label_font, u0, 0.72, u1, 0.9, lab_ink, 0.95)


## Texto centrado en un recuadro de la cara de delante, con la deformación de la perspectiva (aproximada con una
## transformación afín a partir de tres esquinas).
func _draw_on_front(text: String, f: Font, u0: float, v0: float, u1: float, v1: float, ink: Color, fill: float) -> void:
	var tl := _p(_front3(u0, v0))
	var tr := _p(_front3(u1, v0))
	var bl := _p(_front3(u0, v1))
	var box_w := maxf((tr - tl).length(), 1.0)
	var box_h := box_w * (bl - tl).length() / maxf((tr - tl).length(), 1.0)
	var fs := int(box_h * fill)
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	if ts.x > box_w * 0.92:
		fs = int(float(fs) * box_w * 0.92 / ts.x)
		ts = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var xf := Transform2D((tr - tl) / box_w, (bl - tl) / box_h, tl)
	draw_set_transform_matrix(xf)
	var base := (box_h - (f.get_ascent(fs) + f.get_descent(fs))) * 0.5 + f.get_ascent(fs)
	draw_string(f, Vector2((box_w - ts.x) * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _box_top_poly(cx: float, y: float, w: float, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := 0.22
	var corners := [[cx + w * 0.5 - r, BTN_Z - d * 0.5 + r, -PI * 0.5], [cx + w * 0.5 - r, BTN_Z + d * 0.5 - r, 0.0], [cx - w * 0.5 + r, BTN_Z + d * 0.5 - r, PI * 0.5], [cx - w * 0.5 + r, BTN_Z - d * 0.5 + r, PI]]
	for c: Array in corners:
		for k in 6:
			var a := float(c[2]) + PI * 0.5 * float(k) / 5.0
			out.append(_p(Vector3(float(c[0]) + cos(a) * r, y, float(c[1]) + sin(a) * r)))
	return out


func _draw_button(side: int) -> void:
	var up := up_mine if side == 0 else 1.0 - up_mine
	var h := lerpf(BTN_DOWN, BTN_UP, clampf(up, 0.0, 1.0))
	var cx := -BTN_X if side == 0 else BTN_X
	var x0 := cx - BTN_W * 0.5
	var x1 := cx + BTN_W * 0.5
	var z0 := BTN_Z - BTN_D * 0.5
	var z1 := BTN_Z + BTN_D * 0.5
	var y0 := H
	var y1 := H + h
	var base: Color
	if side == 0:
		base = accent.lightened(0.12) if call_press else accent
	else:
		base = Color("8c95a6")
	# Cuerpo del pulsador cromado (lateral y frente, con un degradado de reflejo) y la tapa de color.
	var sx := x1 if side == 0 else x0
	var chrome_hi := Color("e9edf3")
	var chrome_lo := Color("7c8594")
	draw_polygon(PackedVector2Array([_p(Vector3(sx, y0, z0)), _p(Vector3(sx, y1, z0)), _p(Vector3(sx, y1, z1)), _p(Vector3(sx, y0, z1))]), PackedColorArray([chrome_lo.darkened(0.25), chrome_lo, chrome_lo.darkened(0.1), chrome_lo.darkened(0.35)]))
	draw_polygon(PackedVector2Array([_p(Vector3(x0, y0, z1)), _p(Vector3(x1, y0, z1)), _p(Vector3(x1, y1, z1)), _p(Vector3(x0, y1, z1))]), PackedColorArray([chrome_lo, chrome_lo.darkened(0.15), chrome_hi, chrome_hi.darkened(0.08)]))
	# Brillo horizontal en el frente cromado.
	var ym := lerpf(y0, y1, 0.62)
	draw_line(_p(Vector3(x0 + 0.08, ym, z1)), _p(Vector3(x1 - 0.08, ym, z1)), Color(1, 1, 1, 0.55), 2.0, true)
	var top := _box_top_poly(cx, y1, BTN_W, BTN_D)
	draw_colored_polygon(top, base)
	# Brillo de la tapa (más claro hacia atrás, donde da la luz).
	draw_colored_polygon(_box_top_poly(cx, y1 + 0.001, BTN_W * 0.86, BTN_D * 0.5).slice(0), Color(1, 1, 1, 0.12))
	draw_polyline(_closed(top), base.lightened(0.4), 2.0, true)


## Flecha que baja y sube sobre tu pulsador cuando toca pulsar.
func _draw_call() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var bob := sin(t * 6.0) * 0.18
	var y := H + BTN_UP + 0.62 + bob
	var tip := _p(Vector3(-BTN_X, y, BTN_Z))
	var l := _p(Vector3(-BTN_X - 0.42, y + 0.42, BTN_Z))
	var r := _p(Vector3(-BTN_X + 0.42, y + 0.42, BTN_Z))
	draw_polyline(PackedVector2Array([l, tip, r]), accent.darkened(0.2), maxf(5.0, size.y * 0.022), true)


func _draw_screw(at: Vector2) -> void:
	var r := maxf(3.0, size.y * 0.011)
	draw_circle(at, r, Color("8d96a6"))
	draw_circle(at + Vector2(-r * 0.25, -r * 0.25), r * 0.55, Color("c9d0db"))
	draw_line(at + Vector2(-r * 0.7, r * 0.3), at + Vector2(r * 0.7, -r * 0.3), Color("4d5563"), maxf(1.5, r * 0.3), true)


## Placa de latón en el centro de arriba, con el nombre grabado.
func _draw_plate() -> void:
	var pts := PackedVector2Array()
	var uv := PackedVector2Array()
	var corners := [[0.42, 0.28], [0.58, 0.28], [0.58, 0.8], [0.42, 0.8]]
	for c: Array in corners:
		pts.append(_p(_top3(float(c[0]), float(c[1]))))
	draw_polygon(pts, PackedColorArray([Color("e8cf8a"), Color("d8b86a"), Color("a8843e"), Color("b8954c")]))
	draw_polyline(_closed(pts), Color("6e5424"), 2.0, true)
	if label_font != null:
		var tl := pts[0]
		var tr := pts[1]
		var bl := pts[3]
		var w := (tr - tl).length()
		var h := (bl - tl).length()
		var xf := Transform2D((tr - tl) / w, (bl - tl) / h, tl)
		draw_set_transform_matrix(xf)
		var fs := int(h * 0.36)
		for i in 2:
			var line: String = ["A CHESS", "WAY"][i]
			var ts: Vector2 = label_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var y := h * (0.44 if i == 0 else 0.86)
			draw_string(label_font, Vector2((w - ts.x) * 0.5, y + 1.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.8, 0.5))
			draw_string(label_font, Vector2((w - ts.x) * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("5a4218"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
