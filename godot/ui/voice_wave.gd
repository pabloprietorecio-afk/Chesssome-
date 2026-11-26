class_name VoiceWave
extends Control
## La onda del dictado, dentro del campo de texto del asistente y del tutor (Pablo, 26 nov: «hablas, pero no se mueve
## nada en pantalla»). Barras que siguen el volumen real de la voz (`push`, unas diez veces por segundo, desde
## TutorVoice.level): la última medida en el centro y las anteriores hacia los lados, así la voz se ve salir del
## centro. Sin voz (nivel 0) las barras se quedan quietas en una línea de puntos: nada se mueve si no te oye.
## Con texto ya en el campo (`compact`), solo unas barras pegadas a la derecha.

const BARS := 25
const COMPACT_BARS := 7
const BAR_W := 10.0
const GAP := 11.0
## Ancho que ocupa en modo compacto (el campo deja ese margen a la derecha).
const COMPACT_W := COMPACT_BARS * (BAR_W + GAP) + 24.0

var color := Color("ff8a3d")
var compact := false:
	set(value):
		compact = value
		queue_redraw()

## Niveles recibidos, el último primero (uno por barra, del centro hacia fuera).
var _hist := PackedFloat32Array()
## Altura de cada barra ahora mismo (0 a 1), que se acerca a la que toca sin saltos.
var _shown := PackedFloat32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hist.resize(BARS / 2 + 1)
	_shown.resize(BARS)
	set_process(false)


func push(value: float) -> void:
	for i in range(_hist.size() - 1, 0, -1):
		_hist[i] = _hist[i - 1]
	_hist[0] = clampf(value, 0.0, 1.0)
	set_process(true)


## Ya no escucha (se está pasando a texto): a la línea quieta.
func settle() -> void:
	_hist.fill(0.0)
	set_process(true)


## Lo que debería medir la barra i: su nivel del historial, algo menos hacia los bordes y con una forma fija por
## barra para que no parezca un bloque (fija: no se mueve sola).
func target(i: int) -> float:
	var c := BARS / 2
	var d := absi(i - c)
	var edge := float(d) / float(c)
	var shape := 0.78 + 0.22 * absf(sin(float(i) * 1.73))
	return _hist[d] * (1.0 - 0.5 * edge * edge) * shape


func level_shown() -> float:
	var top := 0.0
	for v in _shown:
		top = maxf(top, v)
	return top


func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta * 16.0)
	var moving := false
	for i in BARS:
		var t := target(i)
		var v := lerpf(_shown[i], t, k)
		if absf(v - t) < 0.003:
			v = t
		else:
			moving = true
		_shown[i] = v
	queue_redraw()
	if not moving:
		set_process(false)


func _draw() -> void:
	var first := 0
	var count := BARS
	if compact:
		first = BARS / 2 - COMPACT_BARS / 2
		count = COMPACT_BARS
	var width := count * BAR_W + (count - 1) * GAP
	var x0 := (size.x - width) * 0.5
	if compact:
		x0 = size.x - width - 30.0
	var mid := size.y * 0.5
	var full := size.y * 0.62
	var rest := Color(color, 0.45)
	for n in count:
		var v := _shown[first + n]
		var h := maxf(BAR_W, full * v)
		var x := x0 + n * (BAR_W + GAP)
		var col := rest.lerp(color, clampf(v * 3.0, 0.0, 1.0))
		var r := BAR_W * 0.5
		# Barra de puntas redondas: un rectángulo y dos círculos.
		draw_rect(Rect2(x, mid - h * 0.5 + r, BAR_W, h - BAR_W), col)
		draw_circle(Vector2(x + r, mid - h * 0.5 + r), r, col, true, -1.0, true)
		draw_circle(Vector2(x + r, mid + h * 0.5 - r), r, col, true, -1.0, true)
