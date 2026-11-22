class_name Intro
extends Control
## Intro animada del arranque: el caballo de marfil salta por el tablero y vuelve a su tesela naranja, el icono de la
## app (vídeo de Pablo hecho con PixVerse a partir del fotograma final que le preparamos; sin texto ni sonido). Al
## final, «A Chess Way» se escribe a mano (Caveat, OFL) en el suelo crema del vídeo y debajo se traza el subrayado
## naranja del inicio. Con su sonido (el del mismo vídeo, igualado al volumen de los efectos de la app), salvo con
## el sonido apagado en Opciones. Un toque la salta. Opciones → «Intro»: siempre, una vez, nunca.
##
## El vídeo es Ogg Theora (lo único que lee Godot), recortado sin las franjas negras (864 × 1520) y sin el corte del
## principio. Tiene que estar en el filtro de exportación (intro/*.ogv): Godot no lo importa y, si falta, la intro no
## sale. La CI lo comprueba. Pruebas: tests/test_intro.gd.

signal finished

const VIDEO := "res://intro/intro.ogv"
## Sonido del vídeo (mismo recorte), en Ogg Vorbis: −19 LUFS, como «lección terminada»; picos a −3,3 dB.
const SOUND := "res://intro/intro_sonido.ogg"
## Volumen de reproducción: el de los efectos de la app (demo.gd, sfx_player).
const SOUND_DB := -4.0
const FONT := "res://fonts/Caveat-Bold.woff2"
const TITLE := "A Chess Way"
## Proporción del vídeo (alto / ancho).
const ASPECT := 1520.0 / 864.0
## Colores de los bordes del vídeo (medidos en sus fotogramas): el fondo de la pantalla los continúa.
const TOP := Color8(226, 225, 235)
const BOTTOM := Color8(246, 223, 199)
## Tinta del título y naranja del subrayado: los de la cabecera del inicio (ui/home_screens.gd).
const INK := Color("1b2540")
const RULE := Color("f26a1e")
## Alto del título dentro del vídeo (fracción): en el suelo crema, bajo el tablero y la tesela.
const TITLE_AT := 0.77
## Tiempos, en segundos desde que arranca el vídeo (dura 3,9 s).
const WRITE_FROM := 2.95
const WRITE_TIME := 1.15
const RULE_TIME := 0.35
const FREEZE_AT := 3.85
const HOLD := 0.75
const FADE := 0.4

var _player: VideoStreamPlayer
## Con sonido (lo decide la app según Opciones antes de añadir la intro).
var sound := true
var _audio: AudioStreamPlayer
var _audio_wait := 0.0
var _wash: Control
var _fade_top: ColorRect
var _fade_bottom: ColorRect
var _clip: Control
var _label: Label
var _rule: Line2D
var _rule_full := PackedVector2Array()
var _done := false
## «Cargando…» con una rueda que gira: sale si el vídeo tarda en arrancar (móviles lentos, 22 nov).
var _loading: Control
var _since := 0.0
var _started := false
## Si el vídeo no arranca en este tiempo, la intro sigue igual (con el último plan: el título sobre el fondo).
const START_TIMEOUT := 4.0
## Sin vídeo aún pasado este tiempo, se enseña «Cargando…» (antes, no: en un móvil rápido no da tiempo a verlo).
const LOADING_AFTER := 0.25


static func available() -> bool:
	return ResourceLoader.exists(VIDEO)


func _ready() -> void:
	# Ya dentro del árbol, set_anchors_preset conserva el tamaño que tenía (0 × 0): hay que mover también los
	# márgenes. Fue el fallo de la primera versión en el móvil.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wash = Wash.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wash)
	_player = VideoStreamPlayer.new()
	_player.stream = load(VIDEO)
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player)
	# Los bordes del vídeo se funden con el fondo (en pantallas más altas que el vídeo).
	_fade_top = _fade_strip(TOP, true)
	_fade_bottom = _fade_strip(BOTTOM, false)
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
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_label)
	_rule = Line2D.new()
	_rule.default_color = RULE
	_rule.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rule.end_cap_mode = Line2D.LINE_CAP_ROUND
	_rule.joint_mode = Line2D.LINE_JOINT_ROUND
	_rule.antialiased = true
	add_child(_rule)
	if sound and ResourceLoader.exists(SOUND):
		_audio = AudioStreamPlayer.new()
		_audio.stream = load(SOUND)
		_audio.volume_db = SOUND_DB
		add_child(_audio)
	_loading = Loading.new()
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.modulate.a = 0.0
	(_loading as Loading).text = Loc.t("Cargando…")
	(_loading as Loading).font = font
	add_child(_loading)
	resized.connect(_layout)
	_layout()
	_player.play()
	# Del arranque de Android (mismo papel) al vídeo, sin salto.
	_player.modulate.a = 0.0


## La animación del título va con el vídeo: empieza cuando sale su primer fotograma (en un móvil lento el vídeo
## tarda en arrancar y el título se escribía antes de tiempo).
func _start_timeline() -> void:
	if _started:
		return
	_started = true
	if _loading != null:
		create_tween().tween_property(_loading, "modulate:a", 0.0, 0.15)
	create_tween().tween_property(_player, "modulate:a", 1.0, 0.3)
	var tw := create_tween()
	tw.tween_interval(WRITE_FROM)
	tw.tween_callback(_write)
	tw.tween_interval(FREEZE_AT - WRITE_FROM)
	# Congela el último fotograma: así no queda en blanco mientras se acaba de escribir.
	tw.tween_callback(func() -> void: _player.paused = true)
	tw.tween_interval(maxf(WRITE_FROM + WRITE_TIME + RULE_TIME + HOLD - FREEZE_AT, 0.1))
	tw.tween_callback(_leave)


## El sonido arranca con el primer fotograma del vídeo (el descodificador tarda un poco en empezar), y como mucho
## medio segundo después, por si el vídeo no avanza.
func _process(delta: float) -> void:
	if not _started:
		_since += delta
		if _player.stream_position > 0.0 or _since >= START_TIMEOUT:
			_start_timeline()
		elif _since >= LOADING_AFTER and _loading != null and _loading.modulate.a < 1.0:
			_loading.modulate.a = minf(1.0, _loading.modulate.a + delta * 4.0)
		if _loading != null:
			_loading.queue_redraw()
		return
	if _audio == null or _audio.playing or _done or _audio_wait < 0.0:
		return
	_audio_wait += delta
	if _player.stream_position > 0.0 or _audio_wait > 0.5:
		_audio.play(maxf(_player.stream_position, 0.0))
		_audio_wait = -1.0


func _fade_strip(color: Color, top: bool) -> ColorRect:
	var strip := ColorRect.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; uniform bool top; void fragment() { float a = top ? 1.0 - UV.y : UV.y; COLOR = vec4(tint.rgb, smoothstep(0.0, 1.0, a)); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("top", top)
	strip.material = mat
	add_child(strip)
	return strip


func _layout() -> void:
	var w := size.x
	if w < 1.0:
		return
	if _loading != null:
		_loading.position = Vector2.ZERO
		_loading.size = size
	# El vídeo, a todo el ancho; si la pantalla es más baja que el vídeo, a todo el alto (se recortan los lados).
	var vw := w
	var vh := roundf(w * ASPECT)
	if vh > size.y:
		vh = size.y
		vw = roundf(vh / ASPECT)
	var y0 := roundf((size.y - vh) * 0.5)
	var x0 := roundf((w - vw) * 0.5)
	_wash.position = Vector2.ZERO
	_wash.size = size
	_player.position = Vector2(x0, y0)
	_player.size = Vector2(vw, vh)
	var band := vh * 0.06
	_fade_top.position = Vector2(0.0, y0 - 1.0)
	_fade_top.size = Vector2(w, band)
	_fade_bottom.position = Vector2(0.0, y0 + vh - band + 1.0)
	_fade_bottom.size = Vector2(w, band)
	# Título: a la medida del ancho (como el nombre en la cabecera del inicio, algo más grande).
	_label.add_theme_font_size_override("font_size", int(roundf(w * 0.17)))
	var text_size := _label.get_minimum_size()
	_label.size = text_size
	var cy := y0 + vh * TITLE_AT
	_clip.position = Vector2(roundf((w - text_size.x) * 0.5), roundf(cy - text_size.y * 0.5))
	if _clip.size.x < 1.0 and not _clip.has_meta("writing"):
		_clip.size = Vector2(0.0, text_size.y)
	_clip.size.y = text_size.y
	# Subrayado: un trazo a mano alzada, algo curvo, bajo la palabra «Way» y un poco más allá.
	var left := _clip.position.x + text_size.x * 0.52
	var right := _clip.position.x + text_size.x * 1.02
	var base := _clip.position.y + text_size.y * 0.93
	_rule_full = PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		_rule_full.append(Vector2(lerpf(left, right, t), base + sin(t * PI) * -w * 0.012 + t * w * 0.006))
	_rule.width = maxf(w * 0.011, 3.0)
	if not _clip.has_meta("ruled"):
		_rule.points = PackedVector2Array()


## Escribe el título de izquierda a derecha, con un ritmo algo irregular, como a mano; después, el subrayado.
func _write() -> void:
	_clip.set_meta("writing", true)
	var full := _label.get_minimum_size().x
	var tw := create_tween()
	tw.tween_property(_clip, "size:x", full * 0.14, WRITE_TIME * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.07)
	tw.tween_property(_clip, "size:x", full * 0.56, WRITE_TIME * 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.06)
	tw.tween_property(_clip, "size:x", full + 6.0, WRITE_TIME * 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: _clip.set_meta("ruled", true))
	tw.tween_method(_draw_rule, 0.0, 1.0, RULE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw_rule(t: float) -> void:
	var n := _rule_full.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	var reach := t * float(n - 1)
	for i in n:
		if float(i) <= reach:
			pts.append(_rule_full[i])
	var k := int(floorf(reach))
	if k < n - 1:
		pts.append(_rule_full[k].lerp(_rule_full[k + 1], reach - float(k)))
	_rule.points = pts


func _leave() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	if _audio != null:
		# Si se salta, el sonido se apaga a la vez que la imagen.
		tw.parallel().tween_property(_audio, "volume_db", -40.0, FADE)
	tw.tween_callback(_end)


func _end() -> void:
	finished.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap and not _done:
		_leave()


## «Cargando…»: una rueda naranja que gira y el texto debajo, en el centro de la pantalla.
class Loading extends Control:
	var text := ""
	var font: Font

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.05
		var w := maxf(6.0, r * 0.22)
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(c, r, 0.0, TAU, 48, Color(RULE.r, RULE.g, RULE.b, 0.18), w, true)
		var a := fmod(t * TAU * 0.9, TAU)
		draw_arc(c, r, a, a + TAU * 0.3, 32, RULE, w, true)
		if font != null and text != "":
			var fs := int(r * 0.9)
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-tw * 0.5, r + w + fs * 1.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


## Fondo de la pantalla: del color de arriba del vídeo al de abajo.
class Wash extends Control:
	func _draw() -> void:
		var pts := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])
		draw_polygon(pts, PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
