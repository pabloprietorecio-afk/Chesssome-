class_name EvolutionChart
extends Control
## Gráfica de evolución: la puntuación tras cada problema, con bandas de nivel al fondo (las de
## Assessment.LEVEL_FLOORS), relleno suave bajo la línea y los valores de inicio y de ahora.

var values: Array = []
var font: Font
var small_font: Font
var ink := Color("1b2540")
var quiet := Color("5b6782")
var line := Color("ffa366")
var grid := Color(0.36, 0.42, 0.6, 0.12)
var band := Color(0.36, 0.42, 0.6, 0.05)


func _draw() -> void:
	if values.size() < 2 or size.x < 60.0:
		return
	var lo := INF
	var hi := -INF
	for v: Variant in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	# Margen y al menos un tramo de nivel a la vista.
	var span := maxf(hi - lo, 120.0)
	lo -= span * 0.18
	hi += span * 0.18
	var left := 8.0
	var right := 150.0
	var top := 16.0
	var bottom := 54.0
	var w := size.x - left - right
	var h := size.y - top - bottom
	var to_y := func(v: float) -> float:
		return top + h * (1.0 - (v - lo) / (hi - lo))
	# Bandas de nivel, alternas, con su nombre a la derecha.
	var floors: Array = Assessment.LEVEL_FLOORS
	for i in floors.size():
		var a := float(floors[i])
		var b := float(floors[i + 1]) if i + 1 < floors.size() else 99999.0
		if b <= lo or a >= hi:
			continue
		var y0: float = to_y.call(minf(b, hi))
		var y1: float = to_y.call(maxf(a, lo))
		if i % 2 == 0:
			draw_rect(Rect2(left, y0, w, y1 - y0), band)
		if a > lo:
			draw_line(Vector2(left, y1), Vector2(left + w, y1), grid, 2.0)
		if small_font != null and y1 - y0 > 34.0:
			draw_string(small_font, Vector2(left + w + 16.0, (y0 + y1) * 0.5 + 12.0), Loc.t("Nivel %d") % i, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, quiet)
	# Línea y relleno.
	var pts := PackedVector2Array()
	var n := values.size()
	for i in n:
		pts.append(Vector2(left + w * float(i) / float(n - 1), to_y.call(float(values[i]))))
	var fill := pts.duplicate()
	fill.append(Vector2(left + w, top + h))
	fill.append(Vector2(left, top + h))
	var cols := PackedColorArray()
	for p in fill:
		var t := clampf((p.y - top) / h, 0.0, 1.0)
		cols.append(Color(line.r, line.g, line.b, 0.28 * (1.0 - t)))
	draw_polygon(fill, cols)
	draw_polyline(pts, line, 6.0, true)
	draw_circle(pts[n - 1], 12.0, line)
	draw_circle(pts[n - 1], 6.0, Color.WHITE)
	# Al pie: de dónde vienes y dónde estás.
	if small_font != null:
		draw_string(small_font, Vector2(left, size.y - 12.0), Loc.t("Problema 1 · %d") % roundi(float(values[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, quiet)
		var now := Loc.t("Ahora · %d") % roundi(float(values[n - 1]))
		var tw := small_font.get_string_size(now, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(small_font, Vector2(left + w - tw, size.y - 12.0), now, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
