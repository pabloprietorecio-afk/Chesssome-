class_name LangBoard
extends Control
## Caballo en 3D pintado con la bandera del idioma, que sigue por el fondo de la tesela (ui/idiomas/<código>.bin, que
## genera tests/gen_idiomas_caballo.gd con nuestro caballo clásico). Si faltara la imagen, se dibuja a mano el tablero que
## hacía de bandera:
## Tablero de ajedrez que hace de bandera del idioma: un tablero de 8 × 8 con marco de madera en el que las
## casillas llevan los colores de la bandera (las claras, tal cual; las oscuras, más oscuras), así se ve a la vez
## que es un tablero y de qué idioma. Banderas lisas, sin escudos: España, Reino Unido (inglés), Francia, Italia,
## Japón, Brasil (portugués), Indonesia, India (hindi), Alemania y Rusia. Lo dibuja el código: sin arte ajeno.

const TEX := 192
const SQUARES := 8

var code: String = "es":
	set(value):
		code = value
		queue_redraw()
## Marca el idioma elegido con un anillo.
var current: bool = false:
	set(value):
		current = value
		queue_redraw()
var ring_color := Color(0.36, 0.55, 0.95)

static var _cache: Dictionary = {}
static var _tiles: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## La tesela de la torre del idioma, o null si no está la imagen.
static func tile_for(lang: String) -> Texture2D:
	if _tiles.has(lang):
		return _tiles[lang]
	var tex: Texture2D = null
	var path := "res://ui/idiomas/%s.bin" % lang
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_tiles[lang] = tex
	return tex


static func texture_for(lang: String) -> ImageTexture:
	if _cache.has(lang):
		return _cache[lang]
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var cell := float(TEX) / float(SQUARES)
	for y in TEX:
		for x in TEX:
			var u := (float(x) + 0.5) / float(TEX)
			var v := (float(y) + 0.5) / float(TEX)
			var c := flag_color(lang, u, v)
			var dark_sq := (int(float(x) / cell) + int(float(y) / cell)) % 2 == 1
			if dark_sq:
				c = c.darkened(0.3)
			else:
				c = c.lerp(Color.WHITE, 0.06)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[lang] = tex
	return tex


func _draw() -> void:
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	var tile := tile_for(code)
	if tile != null:
		_draw_tile(tile, origin, side)
		return
	var frame := side * 0.09
	var radius := int(side * 0.16)
	# Sombra suave y marco de madera, como un tablero de verdad.
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0)
	shadow.shadow_color = Color(0, 0, 0, 0.22)
	shadow.shadow_size = int(side * 0.07)
	shadow.shadow_offset = Vector2(0, side * 0.04)
	shadow.set_corner_radius_all(radius)
	draw_style_box(shadow, Rect2(origin, Vector2(side, side)))
	var wood := StyleBoxFlat.new()
	wood.bg_color = Color(0.55, 0.36, 0.2)
	wood.border_color = Color(0.4, 0.25, 0.13)
	wood.set_border_width_all(maxi(1, int(side * 0.018)))
	wood.set_corner_radius_all(radius)
	draw_style_box(wood, Rect2(origin, Vector2(side, side)))
	var inner := Rect2(origin + Vector2(frame, frame), Vector2(side - frame * 2.0, side - frame * 2.0))
	draw_texture_rect(texture_for(code), inner, false)
	# Brillo arriba, como el barniz.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.18)), Color(1, 1, 1, 0.08))
	draw_rect(inner, Color(0.25, 0.15, 0.07, 0.5), false, maxf(1.0, side * 0.01))
	if current:
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.border_color = ring_color
		ring.set_border_width_all(maxi(3, int(side * 0.05)))
		ring.set_corner_radius_all(radius + int(side * 0.06))
		var grow := side * 0.07
		draw_style_box(ring, Rect2(origin - Vector2(grow, grow), Vector2(side + grow * 2.0, side + grow * 2.0)))


func _draw_tile(tile: Texture2D, origin: Vector2, side: float) -> void:
	var radius := int(side * 0.266)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.0)
	shadow.shadow_color = Color(0.1, 0.06, 0.03, 0.26)
	shadow.shadow_size = int(side * 0.06)
	shadow.shadow_offset = Vector2(0, side * 0.035)
	shadow.set_corner_radius_all(radius)
	draw_style_box(shadow, Rect2(origin + Vector2(side, side) * 0.02, Vector2(side, side) * 0.96))
	draw_texture_rect(tile, Rect2(origin, Vector2(side, side)), false)
	if current:
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.border_color = ring_color
		ring.set_border_width_all(maxi(3, int(side * 0.05)))
		ring.set_corner_radius_all(radius + int(side * 0.06))
		var grow := side * 0.07
		draw_style_box(ring, Rect2(origin - Vector2(grow, grow), Vector2(side + grow * 2.0, side + grow * 2.0)))


## Color de la bandera sin el tablero en el punto (u, v), de 0 a 1.
static func flag_color(lang: String, u: float, v: float) -> Color:
	match lang:
		"es":
			return Color(0.78, 0.1, 0.12) if (v < 0.25 or v > 0.75) else Color(0.99, 0.76, 0.05)
		"fr":
			if u < 1.0 / 3.0:
				return Color(0.0, 0.14, 0.58)
			return Color(0.97, 0.97, 0.95) if u < 2.0 / 3.0 else Color(0.93, 0.16, 0.22)
		"it":
			if u < 1.0 / 3.0:
				return Color(0.0, 0.57, 0.27)
			return Color(0.97, 0.97, 0.95) if u < 2.0 / 3.0 else Color(0.8, 0.1, 0.14)
		"ja":
			var d := Vector2(u - 0.5, v - 0.5).length()
			return Color(0.74, 0.0, 0.18) if d < 0.22 else Color(0.97, 0.97, 0.95)
		"en":
			return _union_jack(u, v)
		"pt":
			return _brazil(u, v)
		"id":
			return Color(0.84, 0.09, 0.16) if v < 0.5 else Color(0.97, 0.97, 0.95)
		"hi":
			return _india(u, v)
		"de":
			if v < 1.0 / 3.0:
				return Color(0.08, 0.08, 0.08)
			return Color(0.87, 0.0, 0.0) if v < 2.0 / 3.0 else Color(1.0, 0.81, 0.0)
		"ru":
			if v < 1.0 / 3.0:
				return Color(0.97, 0.97, 0.95)
			return Color(0.0, 0.22, 0.65) if v < 2.0 / 3.0 else Color(0.84, 0.17, 0.13)
	return Color(0.6, 0.6, 0.6)


## Brasil: campo verde, rombo amarillo y disco azul (sin la banda del lema).
static func _brazil(u: float, v: float) -> Color:
	var x := (u - 0.5) * 2.0
	var y := (v - 0.5) * 2.0
	if Vector2(x, y).length() < 0.42:
		return Color(0.0, 0.16, 0.56)
	if absf(x) / 0.92 + absf(y) / 0.78 < 1.0:
		return Color(1.0, 0.85, 0.0)
	return Color(0.0, 0.6, 0.25)


## India: azafrán, blanco y verde, con la rueda azul marino de 24 radios.
static func _india(u: float, v: float) -> Color:
	var x := (u - 0.5) * 2.0
	var y := (v - 0.5) * 2.0
	var d := Vector2(x, y).length()
	if d < 0.3:
		var spoke := absf(sin(atan2(y, x) * 12.0)) > 0.86
		if d > 0.23 or d < 0.07 or spoke:
			return Color(0.0, 0.0, 0.5)
	if v < 1.0 / 3.0:
		return Color(1.0, 0.6, 0.2)
	return Color(0.97, 0.97, 0.95) if v < 2.0 / 3.0 else Color(0.07, 0.53, 0.03)


## Union Jack en un cuadrado: cruces de San Jorge, San Andrés y San Patricio con sus bordes blancos.
static func _union_jack(u: float, v: float) -> Color:
	var blue := Color(0.0, 0.14, 0.4)
	var white := Color(0.96, 0.96, 0.95)
	var red := Color(0.78, 0.07, 0.17)
	var x := (u - 0.5) * 40.0
	var y := (v - 0.5) * 40.0
	if absf(x) < 3.4 or absf(y) < 3.4:
		return red if (absf(x) < 2.2 or absf(y) < 2.2) else white
	if absf(x) < 5.6 or absf(y) < 5.6:
		return white
	# Diagonales; la franja roja va desplazada (mitad superior y, por media vuelta, la inferior).
	var px := x
	var py := y
	if py > 0.0:
		px = -x
		py = -y
	var upper_left := px < 0.0
	var s := (py - px) / 1.4142 if upper_left else (py + px) / 1.4142
	var shifted := s - (1.6 if upper_left else -1.6)
	if absf(shifted) < 1.1:
		return red
	if absf(s) < 3.6:
		return white
	return blue
