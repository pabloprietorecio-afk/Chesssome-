class_name Intro
extends Control
## Intro animada del arranque: el maestro pensando su jugada (vídeo de 4 s, sin sonido) sobre papel crema y, al
## final, «A Chess Way» escrito a mano (Caveat, OFL). Un toque la salta. Opciones → «Intro»: siempre, una vez, nunca.
## El vídeo es Ogg Theora (lo único que lee Godot); se mide y se prueba en tests/test_intro.gd.

signal finished

const VIDEO := "res://intro/intro.ogv"
const FONT := "res://fonts/Caveat-Bold.woff2"
const TITLE := "A Chess Way"
const PAPER := Color(0.957, 0.937, 0.886)
const INK := Color(0.2, 0.18, 0.16)
## Proporción del vídeo recortado (756 × 720).
const ASPECT := 720.0 / 756.0
const WRITE_FROM := 2.3
const WRITE_TIME := 1.5
const FREEZE_AT := 3.95
const HOLD := 1.0
const FADE := 0.4

var _player: VideoStreamPlayer
var _veil: ColorRect
var _veil_top: ColorRect
var _clip: Control
var _label: Label
var _done := false


static func available() -> bool:
	return ResourceLoader.exists(VIDEO)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := ColorRect.new()
	paper.color = PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	_player = VideoStreamPlayer.new()
	_player.stream = load(VIDEO)
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player)
	# El pie y la cabeza del vídeo se funden con el papel.
	_veil = _fade_strip(false)
	_veil_top = _fade_strip(true)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_label = Label.new()
	_label.text = TITLE
	_label.add_theme_color_override("font_color", INK)
	var font := load(FONT) as Font
	if font != null:
		_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 190)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_label)
	resized.connect(_layout)
	_layout()
	_player.play()
	var tw := create_tween()
	tw.tween_interval(WRITE_FROM)
	tw.tween_callback(_write)
	tw.tween_interval(FREEZE_AT - WRITE_FROM)
	# Congela el último fotograma: así no queda en blanco hasta que acaba el texto.
	tw.tween_callback(func() -> void: _player.paused = true)
	tw.tween_interval(WRITE_FROM + WRITE_TIME + HOLD - FREEZE_AT)
	tw.tween_callback(_leave)


func _fade_strip(top: bool) -> ColorRect:
	var strip := ColorRect.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 paper : source_color; uniform bool top; void fragment() { float a = top ? 1.0 - UV.y : UV.y; COLOR = vec4(paper.rgb, smoothstep(0.0, 1.0, a)); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paper", PAPER)
	mat.set_shader_parameter("top", top)
	strip.material = mat
	add_child(strip)
	return strip


func _layout() -> void:
	var w := size.x
	var vh := roundf(w * ASPECT)
	var text_size := _label.get_minimum_size()
	_label.size = text_size
	# Vídeo y título juntos, algo por encima del centro.
	var group := vh + text_size.y * 0.8
	var y0 := maxf((size.y - group) * 0.38, 0.0)
	_player.position = Vector2(0.0, y0)
	_player.size = Vector2(w, vh)
	_veil.position = Vector2(0.0, y0 + vh * 0.78)
	_veil.size = Vector2(w, vh * 0.22 + 2.0)
	_veil_top.position = Vector2(0.0, y0 - 2.0)
	_veil_top.size = Vector2(w, vh * 0.12 + 2.0)
	var top := y0 + vh - text_size.y * 0.1
	_clip.position = Vector2((w - text_size.x) * 0.5, top)
	if _clip.size.x < 1.0 and not _clip.has_meta("writing"):
		_clip.size = Vector2(0.0, text_size.y)


## Escribe el título de izquierda a derecha, con un ritmo algo irregular, como a mano.
func _write() -> void:
	_clip.set_meta("writing", true)
	var full := _label.get_minimum_size().x
	var tw := create_tween()
	tw.tween_property(_clip, "size:x", full * 0.38, WRITE_TIME * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.06)
	tw.tween_property(_clip, "size:x", full * 0.72, WRITE_TIME * 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.05)
	tw.tween_property(_clip, "size:x", full + 4.0, WRITE_TIME * 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _leave() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	tw.tween_callback(_end)


func _end() -> void:
	finished.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap and not _done:
		_leave()
