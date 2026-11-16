class_name KnightWait
extends Control
## Animación de las esperas largas (el análisis de una partida): el caballo del logo en vídeos cortos que empiezan y
## acaban en el logo (PixVerse, a partir del logo; tools/espera/videos.sh). Se encadenan al azar, sin repetir el
## mismo dos veces seguidas, con un fundido corto entre uno y otro (los finales no coinciden al píxel). Van en una
## tarjeta de esquinas redondeadas porque su fondo cambia de color durante el vídeo y no se puede fundir con el de
## la pantalla. Debajo, si se pide, una barra con lo que va de análisis.
## Con las animaciones apagadas (`still`), el logo quieto.
## Los .ogv tienen que estar en el filtro de exportación (espera/*.ogv): Godot no los importa.

const CLIPS := ["res://espera/caballo_1.ogv", "res://espera/caballo_2.ogv", "res://espera/caballo_3.ogv"]
const XFADE := 0.3
const BAR_GAP := 34.0
const BAR_H := 14.0
## Radio de las esquinas, en fracción del lado.
const RADIUS := 0.08
## Fondo de la tarjeta (el gris lila de los vídeos en reposo): se ve en el modo quieto y mientras carga.
const PAPER := Color8(229, 228, 237)

var mark := Color("ffa366")
var track := Color("c9d5e8")
var still := false
## Lo que va (0 a 1); negativo, sin barra.
var progress := -1.0:
	set(value):
		progress = value
		if still or _bar < 0.0:
			_bar = value

var _side := 600.0
var _players: Array[VideoStreamPlayer] = []
var _front := 0
var _last := -1
var _fading := false
var _bar := -1.0
var _rng := RandomNumberGenerator.new()
var _logo: TextureRect
static var _mask: Shader


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


func set_side(side: float, with_bar: bool) -> void:
	_side = side
	custom_minimum_size = Vector2(side, side + (BAR_GAP + BAR_H if with_bar else 0.0))
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _ready() -> void:
	if still:
		_logo = TextureRect.new()
		_logo.texture = HomeScreens.art("icono")
		_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo.position = Vector2(_side * 0.24, _side * 0.24)
		_logo.size = Vector2(_side * 0.52, _side * 0.52)
		add_child(_logo)
		return
	for i in 2:
		var p := VideoStreamPlayer.new()
		p.expand = true
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.position = Vector2.ZERO
		p.size = Vector2(_side, _side)
		p.material = _rounded()
		p.modulate.a = 0.0
		add_child(p)
		_players.append(p)
	_play_next(true)


## Un vídeo al azar, distinto del último.
func pick() -> int:
	if CLIPS.size() <= 1:
		return 0
	var i := _rng.randi_range(0, CLIPS.size() - 2)
	if i >= _last and _last >= 0:
		i += 1
	return i


func _play_next(first: bool = false) -> void:
	var i := pick()
	_last = i
	var back := _players[1 - _front] if not first else _players[_front]
	back.stream = load(str(CLIPS[i]))
	back.play()
	move_child(back, -1)
	if first:
		back.modulate.a = 1.0
		return
	_fading = true
	back.modulate.a = 0.0
	var old := _players[_front]
	var tw := create_tween()
	tw.tween_property(back, "modulate:a", 1.0, XFADE)
	tw.tween_callback(func() -> void:
		old.stop()
		old.modulate.a = 0.0
		_front = 1 - _front
		_fading = false)


## Cuál suena ahora (para las pruebas).
func current() -> int:
	return _last


func _process(delta: float) -> void:
	if _bar >= 0.0 and progress >= 0.0:
		_bar = move_toward(_bar, progress, delta * 0.9)
		queue_redraw()
	if still or _fading or _players.is_empty():
		return
	var p := _players[_front]
	var length := p.get_stream_length()
	if not p.is_playing() or (length > 0.0 and p.stream_position >= length - XFADE):
		_play_next()


func _draw() -> void:
	# Tarjeta con sombra suave (los vídeos van encima, recortados con las mismas esquinas).
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.set_corner_radius_all(int(_side * RADIUS))
	box.shadow_color = Color(0.16, 0.12, 0.4, 0.16)
	box.shadow_size = int(_side * 0.04)
	box.shadow_offset = Vector2(0, _side * 0.015)
	draw_style_box(box, Rect2(Vector2.ZERO, Vector2(_side, _side)))
	if _bar >= 0.0:
		var y := _side + BAR_GAP
		var w := _side * 0.82
		var x := (_side - w) * 0.5
		var bar := StyleBoxFlat.new()
		bar.bg_color = track
		bar.set_corner_radius_all(int(BAR_H * 0.5))
		draw_style_box(bar, Rect2(x, y, w, BAR_H))
		if _bar > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = mark
			fill.set_corner_radius_all(int(BAR_H * 0.5))
			draw_style_box(fill, Rect2(x, y, maxf(BAR_H, w * clampf(_bar, 0.0, 1.0)), BAR_H))


## Recorte con esquinas redondeadas (y bordes suaves), respetando el fundido (modulate).
static func _rounded() -> ShaderMaterial:
	if _mask == null:
		_mask = Shader.new()
		_mask.code = """
shader_type canvas_item;
uniform float radius = 0.08;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 q = abs(UV - 0.5) - (0.5 - radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float aa = max(fwidth(d), 0.0015);
	c.a *= 1.0 - smoothstep(-aa, aa, d);
	COLOR = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _mask
	m.set_shader_parameter("radius", RADIUS)
	return m
