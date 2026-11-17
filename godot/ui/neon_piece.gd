class_name NeonPiece
extends Control
## El contorno de la pieza que el jugador acaba de tocar, en grande y encima del tablero (idea de Pablo, 17-11: a veces
## se mueve la pieza que no era). Solo el contorno, fino y en gris azulado a media opacidad (Pablo, 17-11: el neón
## naranja se veía demasiado): el tablero se sigue viendo por dentro y los toques pasan a través.
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

## Gris azulado, discreto: se lee sobre las casillas claras y las oscuras sin llamar la atención.
var neon := Color("707f9e")
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
	# Aparece suave, sin parpadeo.
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.14)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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


## Del campo de distancias al contorno: una línea fina en el borde y un halo suave que se apaga hacia fuera.
static func _neon_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type canvas_item;
uniform vec4 neon : source_color = vec4(0.44, 0.5, 0.62, 1.0);
uniform float spread = 26.0;
uniform float line_px = 2.6;
uniform float glow_px = 5.0;
uniform float strength = 0.5;
void fragment() {
	float d = (texture(TEXTURE, UV).a - 0.5) * 2.0 * spread;
	float ad = abs(d);
	float aa = max(fwidth(d), 0.001);
	// Una línea fina en el borde y un halo muy suave alrededor, todo a media opacidad: se nota sin tapar el tablero.
	float core = 1.0 - smoothstep(line_px - aa, line_px + aa, ad);
	float glow = exp(-ad / (d > 0.0 ? glow_px * 0.45 : glow_px));
	float a = max(core, glow * 0.3) * strength;
	COLOR = vec4(neon.rgb, a * COLOR.a);
}
"""
	return _shader
