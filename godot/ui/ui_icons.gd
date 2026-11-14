class_name UiIcons
extends RefCounted
## Iconos e ilustraciones de la interfaz.
##
## Van en un atlas (iconos.bin) en blanco con transparencia: el color se lo da quien los dibuja, con
## `modulate`, así que un mismo icono vale para el tema claro, el oscuro y cualquier tono pastel.
## Los genera tools/ui/icons.mjs: los iconos generales son de Phosphor Icons (licencia MIT) y las piezas y el
## emblema salen de nuestras propias piezas 3D. Ver godot/ui/LEEME.md.
##
## Los archivos son PNG con otra extensión para que Godot no los importe (y no los comprima con pérdida):
## se leen tal cual, como el atlas de las fichas.

const ATLAS := "res://ui/iconos.bin"
const INDEX := "res://ui/iconos.json"
const EMBLEM := "res://ui/emblema.bin"
## Nivel Kids: iconos a color y fondo de juguetes (Fluent Emoji de Microsoft, licencia MIT; tools/ui/kids.mjs).
const KIDS_ATLAS := "res://ui/kids_iconos.bin"
const KIDS_INDEX := "res://ui/kids_iconos.json"
const KIDS_WALL := "res://ui/kids_fondo.bin"

static var _atlas: Image
static var _cell := 160
static var _cells := {}
static var _cache := {}
static var _tried := false
static var _kids_atlas: Image
static var _kids_cell := 160
static var _kids_cells := {}
static var _kids_tried := false


static func _ensure() -> void:
	if _tried:
		return
	_tried = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Falta el índice de iconos: " + INDEX)
		return
	_cell = int(data.get("cell", 160))
	_cells = data.get("icons", {})
	_atlas = _png(ATLAS)


static func _png(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
		push_error("No se puede cargar " + path)
		return null
	return img


## Nombres de todos los iconos del atlas.
static func names() -> Array:
	_ensure()
	return _cells.keys()


static func has(icon_name: String) -> bool:
	_ensure()
	return _atlas != null and _cells.has(icon_name)


## Textura de un icono (null si no existe). Con sus reducciones, para que se vea bien a cualquier tamaño.
static func texture(icon_name: String) -> Texture2D:
	_ensure()
	if _cache.has(icon_name):
		return _cache[icon_name]
	var tex: Texture2D = null
	if _atlas != null and _cells.has(icon_name):
		var at: Array = _cells[icon_name]
		var region := _atlas.get_region(Rect2i(int(at[0]) * _cell, int(at[1]) * _cell, _cell, _cell))
		region.generate_mipmaps()
		tex = ImageTexture.create_from_image(region)
	else:
		push_error("Icono desconocido: " + icon_name)
	_cache[icon_name] = tex
	return tex


## Emblema de la app: el caballo en relieve sobre una tesela pastel.
static func emblem() -> Texture2D:
	if not _cache.has("#emblema"):
		var tex: Texture2D = null
		var img := _png(EMBLEM)
		if img != null:
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
		_cache["#emblema"] = tex
	return _cache["#emblema"]


static func _ensure_kids() -> void:
	if _kids_tried:
		return
	_kids_tried = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIDS_INDEX)) if FileAccess.file_exists(KIDS_INDEX) else null
	if typeof(data) != TYPE_DICTIONARY:
		return
	_kids_cell = int(data.get("cell", 160))
	_kids_cells = data.get("icons", {})
	_kids_atlas = _png(KIDS_ATLAS)


## Icono a color del nivel Kids (null si ese icono no tiene versión Kids: entonces se usa el normal).
static func kids_texture(icon_name: String) -> Texture2D:
	_ensure_kids()
	var key := "#kids:" + icon_name
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if _kids_atlas != null and _kids_cells.has(icon_name):
		var at: Array = _kids_cells[icon_name]
		var region := _kids_atlas.get_region(Rect2i(int(at[0]) * _kids_cell, int(at[1]) * _kids_cell, _kids_cell, _kids_cell))
		region.generate_mipmaps()
		tex = ImageTexture.create_from_image(region)
	_cache[key] = tex
	return tex


## Fondo de juguetes en tonos pastel, para repetir en mosaico.
static func kids_wall() -> Texture2D:
	if not _cache.has("#kids_wall"):
		var img := _png(KIDS_WALL) if FileAccess.file_exists(KIDS_WALL) else null
		_cache["#kids_wall"] = ImageTexture.create_from_image(img) if img != null else null
	return _cache["#kids_wall"]
