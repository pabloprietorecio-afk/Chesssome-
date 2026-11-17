class_name NeonPiece
extends Control
## El contorno de la pieza que el jugador acaba de tocar, en grande y encima del tablero, como un neón naranja
## (idea de Pablo, 17-11: a veces se mueve la pieza que no era). Solo el contorno: el tablero se sigue viendo por
## dentro y los toques pasan a través.
##
## Se dibuja con un campo de distancias de cada silueta (ui/neon_piezas.bin, de tools/ui/icons.mjs a partir de
## nuestras piezas 3D): una línea brillante justo en el borde y un resplandor que se apaga hacia fuera, nítidos a
## cualquier tamaño.

const ATLAS := "res://ui/neon_piezas.bin"
## Celda de cada pieza en el atlas y alcance del campo (los mismos que en tools/ui/icons.mjs).
const CELL := 256
const SPREAD := 26.0
## Lado del contorno respecto al lado menor del tablero.
const SIZE := 0.74
const PIECE_INDEX := {Chess.PAWN: 0, Chess.KNIGHT: 1, Chess.BISHOP: 2, Chess.ROOK: 3, Chess.QUEEN: 4, Chess.KING: 5}

## Naranja de neón (más vivo que el naranja pastel de los botones, para que se lea sobre casillas claras y oscuras).
var neon := Color("ff5a08")
## Sin animaciones: aparece y desaparece de golpe.
var still := false
## Tipo de pieza que se enseña (Chess.PAWN…Chess.KING) o 0.
var piece := 0
var _tween: Tween
static var _atlas: Texture2D
static var _shader: Shader


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	var m := ShaderMaterial.new()
	m.shader = _neon_shader()
	material = m


func _ready() -> void:
	(material as ShaderMaterial).set_shader_parameter("neon", neon)
	(material as ShaderMaterial).set_shader_parameter("spread", SPREAD)


## Enciende el contorno de una pieza (tipo de Chess, sin color).
func show_piece(type: int) -> void:
	if not PIECE_INDEX.has(type) or texture() == null:
		hide_piece()
		return
	piece = type
	visible = true
	queue_redraw()
	if _tween != null:
		_tween.kill()
	pivot_offset = size * 0.5
	if still:
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	# Como un tubo de neón al encenderse: un parpadeo rápido y luego fijo.
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.06)
	_tween.tween_property(self, "modulate:a", 0.35, 0.05)
	_tween.tween_property(self, "modulate:a", 1.0, 0.07)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Apaga el contorno.
func hide_piece() -> void:
	piece = 0
	if _tween != null:
		_tween.kill()
	if still or not visible:
		modulate.a = 0.0
		visible = false
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_tween.tween_callback(func() -> void: visible = false)


func shown() -> bool:
	return piece != 0 and visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
		queue_redraw()


func _draw() -> void:
	var tex := texture()
	if tex == null or not PIECE_INDEX.has(piece):
		return
	var side := minf(size.x, size.y) * SIZE
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var src := Rect2(float(PIECE_INDEX[piece]) * CELL, 0.0, CELL, CELL)
	draw_texture_rect_region(tex, rect, src)


static func texture() -> Texture2D:
	if _atlas == null:
		var bytes := FileAccess.get_file_as_bytes(ATLAS)
		var img := Image.new()
		if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
			push_error("No se puede cargar " + ATLAS)
			return null
		_atlas = ImageTexture.create_from_image(img)
	return _atlas


## Del campo de distancias al neón: línea caliente (casi blanca en el centro) en el borde y resplandor naranja
## que se apaga hacia fuera (y un poco hacia dentro).
static func _neon_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type canvas_item;
uniform vec4 neon : source_color = vec4(1.0, 0.42, 0.06, 1.0);
uniform float spread = 26.0;
uniform float line_px = 3.4;
uniform float glow_px = 7.5;
void fragment() {
	float d = (texture(TEXTURE, UV).a - 0.5) * 2.0 * spread;
	float ad = abs(d);
	float aa = max(fwidth(d), 0.001);
	// Tubo: línea naranja intensa con el centro más claro (no blanco: sobre las casillas claras se perdería).
	float core = 1.0 - smoothstep(line_px - aa, line_px + aa, ad);
	float hot = 1.0 - smoothstep(0.0, line_px * 0.6 + aa, ad);
	// Resplandor naranja hacia fuera (y menos hacia dentro) y una sombra oscura muy suave justo fuera del tubo, para
	// que se lea sobre las casillas claras.
	float glow = exp(-ad / (d > 0.0 ? glow_px * 0.45 : glow_px));
	float shade = d < 0.0 ? exp(-max(ad - line_px, 0.0) / 3.0) * (1.0 - core) : 0.0;
	vec3 tube = mix(neon.rgb, vec3(1.0, 0.72, 0.38), hot * 0.75);
	// Capas: la sombra debajo y el neón (tubo y resplandor) encima.
	float g = max(core, glow * 0.72);
	vec3 lit = mix(neon.rgb, tube, core);
	float s = shade * 0.2;
	float a = g + s * (1.0 - g);
	vec3 rgb = a > 0.0 ? (lit * g + vec3(0.22, 0.08, 0.0) * s * (1.0 - g)) / a : lit;
	COLOR = vec4(rgb, a * COLOR.a);
}
"""
	return _shader
