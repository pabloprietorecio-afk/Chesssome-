class_name Board3D
extends Node3D
## Mundo 3D del tablero: piezas de una colección, luz, cámara, marcadores y animaciones.
## No decide nada de ajedrez por su cuenta: usa Chess (core/chess.gd) para las reglas.
##
## Coordenadas: 1 unidad = 1 casilla. La columna «a» está en x = −3,5 y la fila 1 en z = +3,5
## (las blancas quedan hacia +Z, que es donde se pone la cámara cuando juegan blancas).

signal animations_finished
## Momentos de la partida que suenan (los pone en sonido BoardSounds): "slide" (la pieza se arrastra; amount es
## lo que dura), "place" (se asienta), "capture", "check" y "fall" (cae el rey en el mate).
signal sound(kind: String, amount: float)

enum Anim { FULL, FAST, MINIMAL, NONE }

const PIECE_FILES := {1: "pawn", 2: "knight", 3: "bishop", 4: "rook", 5: "queen", 6: "king"}
## Altura de cada pieza en casillas (para elegirla al tocar).
const PIECE_HEIGHT := {1: 0.84, 2: 1.09, 3: 1.25, 4: 0.99, 5: 1.53, 6: 1.76}
const PIECE_SCALE := 1.0
## Las piezas van algo más anchas que el modelo: llenan mejor la casilla sin tapar más las de detrás.
const PIECE_GIRTH := 1.06
const PICK_RADIUS := 0.38
## Semilado y grosor del marco (tools/pieces/board.mjs).
const FRAME_HALF := 4.14
const FRAME_THICK := 0.36
## Altura que se reserva para las piezas al encuadrar (un rey en una casilla de esquina).
const FIT_HEIGHT := 1.8
## Grosor del contorno de las piezas, en casillas.
const OUTLINE_WIDTH := 0.026
## Color del contorno de las piezas negras (amarillo, para que se vea sobre piezas y casillas oscuras).
const BLACK_OUTLINE := Color("f5c542")
## Juegos de piezas: figuras de la colección o fichas planas con el icono de la pieza en relieve.
const PIECE_SETS := ["clasico", "fichas", "simple", "reino", "safari", "espacio", "piratas", "dino", "aventura"]
## Juego «Aventura»: personajes 3D con esqueleto y animaciones (KayKit Adventurers, CC0; ver tools/pieces/aventura.py)
## de pie sobre la ficha de su pieza. Por tipo de pieza: personaje, tamaño, accesorios que lleva y sus animaciones.
const RIG_DIR := "res://sets/aventura/"
const RIG := {
	1: {"who": "rogue_hooded", "size": 0.52, "show": ["Knife"], "walk": "Walking_A", "pace": 1.5, "attack": "1H_Melee_Attack_Stab"},
	2: {"who": "knight", "size": 0.64, "show": ["1H_Sword", "Round_Shield", "Knight_Helmet"], "walk": "Jump_Full_Long", "pace": 1.0, "attack": "1H_Melee_Attack_Chop"},
	3: {"who": "mage", "size": 0.64, "show": ["2H_Staff", "Mage_Hat", "Mage_Cape"], "walk": "Walking_A", "pace": 1.3, "attack": "Spellcast_Shoot", "ranged": true},
	4: {"who": "barbarian", "size": 0.68, "show": ["1H_Axe", "Barbarian_Round_Shield", "Barbarian_Hat"], "walk": "Walking_C", "pace": 1.2, "attack": "1H_Melee_Attack_Slice_Horizontal"},
	5: {"who": "rogue", "size": 0.70, "show": ["Knife", "Knife_Offhand", "Rogue_Cape"], "walk": "Running_A", "pace": 1.1, "attack": "Dualwield_Melee_Attack_Slice"},
	6: {"who": "knight", "size": 0.80, "show": ["2H_Sword", "Knight_Helmet", "Knight_Cape"], "walk": "Walking_C", "pace": 1.0, "attack": "2H_Melee_Attack_Chop"},
}
const RIG_LOOPS := ["Idle", "Walking_A", "Walking_C", "Running_A"]
const RIG_BODY := ["ArmLeft", "ArmRight", "Body", "Head", "LegLeft", "LegRight"]
## Las negras: los mismos personajes, oscurecidos.
const RIG_DARK := Color(0.36, 0.38, 0.56)
## Juegos planos (un dibujo por pieza): «Simple» y los mundos del nivel Kids (tools/pieces/mundos_arte.py).
const FLAT_ATLAS := {
	"simple": "res://sets/simple/iconos.bin",
	"reino": "res://sets/mundos/reino.bin",
	"safari": "res://sets/mundos/safari.bin",
	"espacio": "res://sets/mundos/espacio.bin",
	"piratas": "res://sets/mundos/piratas.bin",
	"dino": "res://sets/mundos/dino.bin",
}
## Juego «Simple»: el dibujo plano de cada pieza (tools/pieces/simple_arte.py), mirando siempre a la cámara y lo más
## grande que cabe en su casilla, sin relieve ni contorno 3D.
const SIMPLE_ATLAS := "res://sets/simple/iconos.bin"
## Lado del dibujo en casillas, a vista de pájaro (con el tablero inclinado se encoge para caber en la casilla).
const SIMPLE_SIZE := 0.96
## Alto de un recortable de pie, en casillas.
const STANDEE_SIZE := 1.6
## Tamaño del peón respecto a las demás fichas.
const PAWN_TOKEN_SCALE := 0.84
## Medidas de la ficha (tools/pieces/fichas.mjs), en casillas.
const TOKEN := {"radius": 0.4, "height": 0.165, "field_radius": 0.343, "face_height": 0.152, "icon_radius": 0.31, "sd_range": 0.05}
## Con fichas no hay piezas altas que tapen ni que se salgan por arriba: el tablero puede llenar más la vista.
const FIT_HEIGHT_TOKENS := 0.3
## Acabados realistas: materiales con textura fotográfica (godot/textures) y reflejos del entorno de estudio.
## El tablero abarca los tonos medios y las piezas, los extremos: las claras son más claras que las casillas
## claras y las oscuras, más oscuras que las casillas oscuras. Así cada pieza destaca sobre las dos casillas.
const FINISHES := {
	"madera": {
		"light": {"tex": "arce", "normal": "arce_normal", "tint": Color(0.98, 0.94, 0.86), "grain": 0.24, "turn": 1.0},
		"dark": {"tex": "nogal", "normal": "nogal_normal", "tint": Color(0.8, 0.72, 0.66), "grain": 0.16, "turn": 0.0},
		"board": {"rough": 0.3, "coat": 0.4, "metallic": 0.0, "normal_depth": 0.6, "joint": 0.5},
		"frame": {"tex": "palisandro", "tint": Color(0.62, 0.56, 0.54), "rough": 0.3, "coat": 0.4, "metallic": 0.0, "grain": 0.22},
		"pieces": [
			{"tex": "boj", "tint": Color(1.08, 1.02, 0.9), "grain": 0.3, "rough": 0.36, "coat": 0.35, "metallic": 0.0, "rim": 0.0},
			{"tex": "ebano", "tint": Color(0.34, 0.31, 0.3), "grain": 0.3, "rough": 0.27, "coat": 0.35, "metallic": 0.0, "rim": 0.14},
		],
		"labels": [Color("f6e9cf"), Color("5b3d27")],
		"outline": [Color("2b1a10"), Color("050302")],
		"swatch": [Color("e7cf9c"), Color("2b2422")],
		"light_setup": {"key": 1.0, "ambient": 0.62, "sky": 1.0, "rim": 0.3},
	},
	"marmol": {
		"light": {"tex": "marmol_crema", "normal": "", "tint": Color(0.96, 0.95, 0.93), "grain": 0.3, "turn": 0.0},
		"dark": {"tex": "marmol_pizarra", "normal": "", "tint": Color(0.86, 0.9, 0.96), "grain": 0.3, "turn": 0.0},
		"board": {"rough": 0.16, "coat": 0.0, "metallic": 0.0, "normal_depth": 0.0, "joint": 0.42},
		"frame": {"tex": "marmol_negro", "tint": Color(0.5, 0.5, 0.52), "rough": 0.16, "coat": 0.0, "metallic": 0.0, "grain": 0.3},
		"pieces": [
			{"tex": "marmol_blanco", "tint": Color(0.9, 0.9, 0.91), "grain": 0.45, "rough": 0.2, "coat": 0.0, "metallic": 0.0, "rim": 0.0},
			{"tex": "marmol_negro", "tint": Color(0.55, 0.55, 0.57), "grain": 0.45, "rough": 0.16, "coat": 0.0, "metallic": 0.0, "rim": 0.12},
		],
		"labels": [Color("eef2f8"), Color("5a5348")],
		"outline": [Color("3a3a40"), Color("050506")],
		"swatch": [Color("f1f0ee"), Color("2a2b2e")],
		"light_setup": {"key": 0.95, "ambient": 0.6, "sky": 1.0, "rim": 0.3},
	},
	"metal": {
		"light": {"tex": "acero", "normal": "acero_normal", "tint": Color(1.22, 1.24, 1.28), "grain": 0.3, "turn": 0.0},
		"dark": {"tex": "acero", "normal": "acero_normal", "tint": Color(0.46, 0.5, 0.58), "grain": 0.3, "turn": 1.0},
		"board": {"rough": 0.42, "coat": 0.0, "metallic": 1.0, "normal_depth": 1.0, "joint": 0.6},
		"frame": {"tex": "bronce", "tint": Color(0.7, 0.7, 0.72), "rough": 0.36, "coat": 0.0, "metallic": 1.0, "grain": 0.3},
		"pieces": [
			{"tex": "laton", "tint": Color(1.0, 0.86, 0.6), "grain": 0.4, "rough": 0.24, "coat": 0.0, "metallic": 1.0, "rim": 0.0},
			{"tex": "bronce", "tint": Color(0.6, 0.7, 0.95), "grain": 0.4, "rough": 0.26, "coat": 0.0, "metallic": 1.0, "rim": 0.0},
		],
		"labels": [Color("eef1f6"), Color("30343c")],
		"outline": [Color("3a2c10"), Color("040506")],
		"swatch": [Color("e2bd62"), Color("33363e")],
		"light_setup": {"key": 0.85, "ambient": 0.7, "sky": 1.25, "rim": 0.25},
	},
}
const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const PITCH_MIN := 36.0
const PITCH_MAX := 90.0
## Ampliación máxima con el pellizco de dos dedos (1 = el tablero encuadrado a lo ancho).
const ZOOM_MAX := 3.0
const DEFAULT_PITCH := 64.0

var chess: Chess = Chess.from_fen(START_FEN)
## 0 = blancas abajo, 1 = negras abajo.
var orientation := 0
var anim_mode: Anim = Anim.FAST:
	set(value):
		anim_mode = value
		set_process(true)
var set_id := "clasico"
var show_coordinates := true
## Acabado: "madera", "marmol" o "metal" (realistas, ver FINISHES) o "ilustrado" (porcelana lisa).
var style := "madera"
## Contorno de tinta alrededor de las piezas (ver set_style y set_outline).
var outline := false
## Juego de piezas: "clasico" o "fichas" (ver set_piece_set).
var piece_set := "clasico"

var camera: Camera3D
var cam_pitch := DEFAULT_PITCH
var cam_yaw := 0.0
## Campo de visión horizontal: muy estrecho, para que las casillas del fondo apenas se encojan
## (con 14° y la vista inclinada, la fila del fondo mide un 90 % de la de delante).
var cam_fov := 14.0
## Margen libre alrededor del tablero al encuadrar, en fracción del ancho o del alto de la vista:
## izquierda, arriba, derecha, abajo.
var fit_pad := Vector4(0.012, 0.02, 0.012, 0.02)
## Ampliación elegida por el jugador: 1 = tablero encuadrado; más = el tablero no cabe entero en la vista.
var zoom := 1.0
## Desplazamiento de la vista cuando está ampliada, en casillas sobre el plano de la cámara (derecha, arriba).
var pan := Vector2.ZERO

var last_from := -1
var last_to := -1
var selected := -1

var _targets := PackedInt32Array()
var _pieces := {}
var _meshes := {}
var _mats: Array[ShaderMaterial] = []
var _tex_mats: Array[ShaderMaterial] = []
var _token_mats: Array[ShaderMaterial] = []
var _token_mesh: Mesh
var _simple_tex: Texture2D
var _flat_cache := {}
var _badge: Node3D
var _badge_tex: Texture2D
var _rig_scenes := {}
var _rig_dark := {}
## Ejes de la cámara (los calcula apply_camera): los recortables miran siempre hacia ella.
var _cam_right := Vector3.RIGHT
var _cam_up := Vector3.FORWARD
var _cam_back := Vector3.UP
## 0 con el tablero visto desde arriba, 1 con el tablero inclinado: lo «de pie» que está un recortable.
var _stand := 0.0
var _flat_size := 0.96
var _life_t := 0.0
var _idle_wait := 2.0
var _idle_tween: Tween
var _star_tex: Texture2D
var _simple_pixel := 0.96 / 256.0
var _icons_tex: Texture2D
var _sfx_tweens: Array[Tween] = []
var _squares_tex: ShaderMaterial
var _frame_tex: ShaderMaterial
var _textures := {}
var _squares_node: MeshInstance3D
var _frame_node: MeshInstance3D
var _sky: Sky
var _sky_mat: ShaderMaterial
var _rim_light: DirectionalLight3D
var _outline_mats: Array[ShaderMaterial] = []
var _disc_mats: Array[ShaderMaterial] = []
var _disc_mesh: ArrayMesh
var _label_font: Font
var _squares_mat: ShaderMaterial
var _frame_mat: StandardMaterial3D
var _shadow_mat: ShaderMaterial
var _shadow_node: MeshInstance3D
var _env: Environment
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _light_rig: Node3D
var _state_img: Image
var _state_tex: ImageTexture
var _pieces_root: Node3D
var _arrows_root: Node3D
## Lecciones: estrellas que recoger (casilla → nodo) y la única pieza que se puede mover (−1 = cualquiera propia).
var _goals_root: Node3D
var _goals := {}
var _goal_t := 0.0
var only_square := -1
var _labels: Array[Node3D] = []
var _tweens: Array[Tween] = []
var _running := 0
var _dying: Array[Node3D] = []
var _cam_tween: Tween
var _theme_name := "light"
## Color (tal como debe verse) del fondo de la pantalla que contiene el tablero.
var _backdrop := Color("eaf1fb")
var _drag_sq := -1
var _built := false
## Datos del último encuadre, para ampliar y desplazar: tangentes del medio campo de visión y distancia.
var _fit_th := 0.1
var _fit_tv := 0.1
var _fit_dist := 30.0


func _ready() -> void:
	_build()
	_apply_style()
	set_theme(_theme_name)
	set_fen(chess.fen())
	set_orientation(orientation)
	# El encuadre depende de la forma de la vista: se rehace cada vez que cambia de tamaño.
	get_viewport().size_changed.connect(apply_camera)


# ---------------------------------------------------------------- construcción

func _build() -> void:
	_env = Environment.new()
	# Fondo liso del mismo color que la pantalla que contiene el tablero (ver set_backdrop): la vista es opaca
	# y, aun así, no se nota dónde acaba. (Una vista transparente no sirve aquí: el renderizador «Mobile»
	# solo guarda 2 bits de transparencia y las sombras suaves salen a franjas.)
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = pre_tonemap(_backdrop)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.tonemap_white = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_light_rig = Node3D.new()
	add_child(_light_rig)
	_key = DirectionalLight3D.new()
	# Luz alta: sombras cortas, que no ensucian las casillas vecinas.
	_key.rotation = Vector3(deg_to_rad(-66.0), deg_to_rad(-34.0), 0.0)
	_key.shadow_enabled = true
	_key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_key.directional_shadow_max_distance = 42.0
	_key.shadow_blur = 1.8
	_key.shadow_opacity = 0.72
	_key.light_angular_distance = 1.0
	_light_rig.add_child(_key)
	_fill = DirectionalLight3D.new()
	_fill.rotation = Vector3(deg_to_rad(-32.0), deg_to_rad(138.0), 0.0)
	_fill.shadow_enabled = false
	_light_rig.add_child(_fill)
	# Luz de contra, baja y desde el fondo: dibuja el filo de las piezas en el acabado realista.
	_rim_light = DirectionalLight3D.new()
	_rim_light.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(205.0), 0.0)
	_rim_light.shadow_enabled = false
	_rim_light.light_energy = 0.0
	_light_rig.add_child(_rim_light)
	# Entorno de estudio (solo para la luz ambiente y los reflejos del acabado realista; no se ve de fondo).
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://board3d/shaders/studio_sky.gdshader") as Shader
	_sky = Sky.new()
	_sky.sky_material = _sky_mat
	_sky.radiance_size = Sky.RADIANCE_SIZE_256
	_sky.process_mode = Sky.PROCESS_MODE_QUALITY

	camera = Camera3D.new()
	camera.fov = cam_fov
	camera.near = 0.5
	camera.far = 160.0
	# El campo de visión es el horizontal: el tablero se encuadra a lo ancho sea cual sea el alto de la vista.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(camera)
	camera.make_current()

	# Sombra de contacto.
	var shadow_plane := PlaneMesh.new()
	shadow_plane.size = Vector2(15.0, 15.0)
	var shadow := MeshInstance3D.new()
	shadow.mesh = shadow_plane
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = load("res://board3d/shaders/soft_shadow.gdshader") as Shader
	# Sombra que nace bajo el marco y se pierde en media casilla: asienta el tablero sin parecer otra losa.
	_shadow_mat.set_shader_parameter("half_size", FRAME_HALF - 0.45)
	_shadow_mat.set_shader_parameter("spread", 1.05)
	shadow.material_override = _shadow_mat
	shadow.position = Vector3(0.0, -FRAME_THICK - 0.02, 0.0)
	_shadow_node = shadow
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

	# Marco.
	var frame := MeshInstance3D.new()
	frame.mesh = _load_mesh("res://sets/%s/board.glb" % set_id)
	_frame_mat = StandardMaterial3D.new()
	_frame_mat.vertex_color_use_as_albedo = true
	_frame_mat.roughness = 0.5
	frame.material_override = _frame_mat
	add_child(frame)
	_frame_node = frame

	# Casillas.
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	var squares := MeshInstance3D.new()
	squares.mesh = plane
	squares.position = Vector3(0.0, 0.004, 0.0)
	squares.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_squares_mat = ShaderMaterial.new()
	_squares_mat.shader = load("res://board3d/shaders/squares.gdshader") as Shader
	_state_img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	_state_img.fill(Color(0.0, 0.0, 0.0, 1.0))
	_state_tex = ImageTexture.create_from_image(_state_img)
	_squares_mat.set_shader_parameter("state", _state_tex)
	squares.material_override = _squares_mat
	add_child(squares)
	_squares_node = squares
	# Materiales de los acabados realistas: sus texturas y parámetros se ponen al elegir el acabado (_apply_style).
	_squares_tex = ShaderMaterial.new()
	_squares_tex.shader = load("res://board3d/shaders/squares_textured.gdshader") as Shader
	_squares_tex.set_shader_parameter("state", _state_tex)
	_frame_tex = ShaderMaterial.new()
	_frame_tex.shader = load("res://board3d/shaders/frame_textured.gdshader") as Shader

	# Coordenadas dentro de las casillas del borde, como en los tableros en pantalla: así el marco puede ser
	# fino y el tablero ocupa casi todo el ancho. Un juego para cada lado; se enseña el del lado que juega abajo.
	if ResourceLoader.exists("res://fonts/Inter-SemiBold.woff2"):
		_label_font = load("res://fonts/Inter-SemiBold.woff2") as Font
	for side in 2:
		var group := Node3D.new()
		var sgn := 1.0 if side == 0 else -1.0
		var yaw := 0.0 if side == 0 else PI
		var edge := 0 if side == 0 else 7
		for i in 8:
			# Letra de la columna: esquina inferior derecha de la casilla de la fila más cercana.
			group.add_child(_make_label("abcdefgh"[i], Vector3(i - 3.5 + 0.385 * sgn, 0.012, 3.865 * sgn), yaw, (i + edge) % 2 == 0))
			# Número de la fila: esquina inferior izquierda de la casilla de la columna de la izquierda, pegado
			# al borde. Ahí no lo tapan ni la base de la pieza de su casilla ni el cuerpo de la de delante.
			group.add_child(_make_label(str(i + 1), Vector3(-3.922 * sgn, 0.012, 3.5 - i + 0.36 * sgn), yaw, (edge + i) % 2 == 0))
		add_child(group)
		_labels.append(group)

	_arrows_root = Node3D.new()
	add_child(_arrows_root)
	_goals_root = Node3D.new()
	add_child(_goals_root)
	_pieces_root = Node3D.new()
	add_child(_pieces_root)

	var piece_shader := load("res://board3d/shaders/piece.gdshader") as Shader
	var outline_shader := load("res://board3d/shaders/outline.gdshader") as Shader
	var disc_shader := load("res://board3d/shaders/outline_disc.gdshader") as Shader
	var textured_shader := load("res://board3d/shaders/piece_textured.gdshader") as Shader
	var token_shader := load("res://board3d/shaders/piece_token.gdshader") as Shader
	for side in 2:
		var m := ShaderMaterial.new()
		m.shader = piece_shader
		_mats.append(m)
		var tm := ShaderMaterial.new()
		tm.shader = textured_shader
		_tex_mats.append(tm)
		var km := ShaderMaterial.new()
		km.shader = token_shader
		for key: String in ["icon_radius", "field_radius", "face_height", "sd_range"]:
			km.set_shader_parameter(key, TOKEN[key])
		_token_mats.append(km)
		var om := ShaderMaterial.new()
		om.shader = outline_shader
		om.set_shader_parameter("width", OUTLINE_WIDTH)
		_outline_mats.append(om)
		var dm := ShaderMaterial.new()
		dm.shader = disc_shader
		_disc_mats.append(dm)
	_disc_mesh = _make_disc()
	for t: int in PIECE_FILES:
		_meshes[t] = _load_mesh("res://sets/%s/%s.glb" % [set_id, PIECE_FILES[t]])
	_token_mesh = _load_mesh("res://sets/fichas/token.glb")
	_icons_tex = _load_icons("res://sets/fichas/iconos.bin")
	for km in _token_mats:
		km.set_shader_parameter("icons", _icons_tex)
	_built = true


## Atlas de iconos de las fichas. Es un PNG de datos (normales y distancias, no colores): se carga tal cual,
## sin pasar por el importador de texturas, para que no lo comprima con pérdida.
static func _load_icons(path: String) -> Texture2D:
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
		push_error("No se pueden cargar los iconos de las fichas: " + path)
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.0, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Textura de godot/textures por su nombre ("" = ninguna). Se cargan al usarlas por primera vez.
func _texture(texture_name: String) -> Texture2D:
	if texture_name == "":
		return null
	if not _textures.has(texture_name):
		var path := "res://textures/%s.jpg" % texture_name
		if ResourceLoader.exists(path):
			_textures[texture_name] = load(path) as Texture2D
		else:
			push_error("Falta la textura " + path)
			_textures[texture_name] = null
	return _textures[texture_name]


func is_realistic() -> bool:
	return FINISHES.has(style)


## Colores de las piezas claras y oscuras del acabado actual, para dibujarlas en la interfaz (marca del turno).
func piece_swatches() -> Array:
	if is_realistic():
		return FINISHES[style]["swatch"]
	return [Color("f8f0e0"), Color("2a3557")]


func _make_label(text: String, pos: Vector3, yaw: float, on_dark: bool) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if _label_font != null:
		l.font = _label_font
	l.font_size = 48
	l.pixel_size = 0.004
	l.outline_size = 0
	l.shaded = false
	l.position = pos
	l.rotation = Vector3(-PI / 2.0, yaw, 0.0)
	# Sobre casilla oscura va en el color de las claras y al revés.
	l.set_meta("on_dark", on_dark)
	return l


## Disco de radio 1 en el plano del tablero, para el contorno de la base de cada pieza.
func _make_disc() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 40
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		for v: Vector3 in [Vector3.ZERO, Vector3(cos(a1), 0.0, sin(a1)), Vector3(cos(a0), 0.0, sin(a0))]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


static func _load_mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("No se puede cargar el modelo " + path)
		return null
	var inst := scene.instantiate()
	var found := _find_mesh(inst)
	var mesh: Mesh = found.mesh if found != null else null
	inst.free()
	return mesh


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for child in n.get_children():
		var r := _find_mesh(child)
		if r != null:
			return r
	return null


# ---------------------------------------------------------------- tema

## Color de fondo de la pantalla que contiene el tablero, tal como debe verse.
func set_backdrop(color: Color) -> void:
	_backdrop = Color(color.r, color.g, color.b, 1.0)
	if _built:
		_env.background_color = pre_tonemap(_backdrop)


## Color que hay que dar a un fondo sin iluminar para que, después del tonemapper fílmico de la escena
## (blanco = 1, exposición = 1), se vea en pantalla como «color».
static func pre_tonemap(color: Color) -> Color:
	var lin := color.srgb_to_linear()
	return Color(_inverse_filmic(lin.r), _inverse_filmic(lin.g), _inverse_filmic(lin.b), 1.0).linear_to_srgb()


## Inversa de la curva fílmica de Godot (constantes de su tonemapper, con el sesgo de exposición ya aplicado).
static func _inverse_filmic(y: float) -> float:
	var a := 0.88
	var b := 0.6
	var c := 0.1
	var d := 0.2
	var e := 0.01
	var f := 0.3
	var white := (a + c * b + d * e) / (a + b + d * f) - e / f
	var t := clampf(y, 0.0, 1.0) * white + e / f
	# t·(a·x² + b·x + d·f) = a·x² + c·b·x + d·e
	var qa := a * (t - 1.0)
	var qb := b * (t - c)
	var qc := d * (t * f - e)
	if absf(qa) < 0.000001:
		return maxf(-qc / qb, 0.0)
	var disc := maxf(qb * qb - 4.0 * qa * qc, 0.0)
	return maxf((-qb - sqrt(disc)) / (2.0 * qa), 0.0)


## Cambia el acabado: "madera", "marmol", "metal" o "ilustrado". El contorno de tinta va con el ilustrado,
## salvo que se indique otra cosa.
func set_style(style_name: String, with_outline: Variant = null) -> void:
	style = style_name if (FINISHES.has(style_name) or style_name == "ilustrado") else "madera"
	outline = (style == "ilustrado") if with_outline == null else bool(with_outline)
	if not _built:
		return
	_apply_style()
	set_theme(_theme_name)


## Contorno de tinta alrededor de las piezas, en cualquier acabado.
func set_outline(on: bool) -> void:
	outline = on
	if not _built:
		return
	for node: Node3D in _pieces.values():
		_dress(node)
	for node: Node3D in _dying:
		if is_instance_valid(node):
			_dress(node)


## Fichas, o personajes articulados (que van de pie sobre su ficha).
func is_tokens() -> bool:
	return piece_set == "fichas" or piece_set == "aventura"


## Personajes 3D con esqueleto y animaciones.
func is_rigged() -> bool:
	return piece_set == "aventura"


## Juego plano (un dibujo por pieza): «Simple» o uno de los mundos Kids.
func is_flat() -> bool:
	return FLAT_ATLAS.has(piece_set)


func is_simple() -> bool:
	return piece_set == "simple"


## Mundo Kids: recortables que se ponen de pie al inclinar el tablero y tienen vida propia.
func is_standee() -> bool:
	return is_flat() and piece_set != "simple"


## Cambia el juego de piezas ("clasico" o "fichas") sin tocar la posición.
func set_piece_set(set_name: String) -> void:
	var wanted := set_name if PIECE_SETS.has(set_name) else "clasico"
	if wanted == piece_set:
		return
	piece_set = wanted
	if not _built:
		return
	finish_animations()
	for s: int in _pieces:
		var node: Node3D = _pieces[s]
		node.set_meta("yaw", _yaw_for(node.get_meta("piece")))
		# Un rey volcado por el mate se queda volcado, a la manera de su juego de piezas.
		if float(node.get_meta("topple", 0.0)) != 0.0:
			node.set_meta("topple", PI if is_tokens() else 1.5)
			node.set_meta("topple_lift", TOKEN["height"] if is_tokens() else 0.0)
		_dress(node)
		_rest(node, s)
	_refresh_state()
	apply_camera()
	set_process(true)


func _piece_material(side: int) -> ShaderMaterial:
	if is_tokens():
		return _token_mats[side]
	return _tex_mats[side] if is_realistic() else _mats[side]


func _piece_mesh(piece_type: int) -> Mesh:
	return _token_mesh if is_tokens() else _meshes[piece_type]


## Altura de una pieza, para elegirla al tocar.
func _piece_height(piece_type: int) -> float:
	if is_flat():
		return 0.3
	if is_tokens():
		return float(TOKEN["height"])
	return float(PIECE_HEIGHT[piece_type]) * PIECE_SCALE


## Pone a una pieza la malla y el material de su juego y de su acabado, y enseña u oculta su contorno.
func _dress(node: Node3D) -> void:
	var piece: int = node.get_meta("piece")
	var side := Chess.color_of(piece)
	var piece_type := Chess.type_of(piece)
	var mesh := _piece_mesh(piece_type)
	var body := node.get_node("Malla") as MeshInstance3D
	var hull := node.get_node("Contorno") as MeshInstance3D
	var disc := node.get_node("Peana") as MeshInstance3D
	if body.mesh != mesh:
		body.mesh = mesh
		hull.mesh = mesh
		_fit_disc(node, mesh)
	body.material_override = _piece_material(side)
	# Icono de la ficha: su casilla en el atlas (tres columnas, dos filas, en el orden de PIECE_FILES).
	var cell := piece_type - 1
	body.set_instance_shader_parameter("icon_cell", Vector2(float(cell % 3), floorf(float(cell) / 3.0)))
	# Fichas: el peón, algo más pequeño que las demás (petición de Pablo).
	var small := Vector3.ONE * (PAWN_TOKEN_SCALE if is_tokens() and piece_type == Chess.PAWN else 1.0)
	body.scale = small
	hull.scale = small
	if mesh != null:
		var r := mesh.get_aabb().size.x * 0.5 * small.x + OUTLINE_WIDTH
		disc.scale = Vector3(r, 1.0, r)
	hull.visible = outline and not is_flat()
	disc.visible = outline and not is_flat()
	body.visible = not is_flat()
	_dress_figure(node, piece)
	var flat := node.get_node_or_null("Plano") as Sprite3D
	if is_flat():
		if flat == null:
			flat = Sprite3D.new()
			flat.name = "Plano"
			# Sin «billboard»: la orientación hacia la cámara la pone _pose_flat, que además lo inclina, lo
			# aplasta y lo voltea como a un recortable de papel.
			flat.no_depth_test = true
			flat.shaded = false
			flat.double_sided = true
			flat.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			flat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			flat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flat.region_enabled = true
			node.add_child(flat)
		flat.texture = _simple_texture()
		var px := float(flat.texture.get_height()) * 0.5 if flat.texture != null else 256.0
		flat.region_rect = Rect2((piece_type - 1) * px, side * px, px, px)
		flat.pixel_size = 1.0 / px
		flat.position = Vector3(0.0, 0.02, 0.0)
		flat.visible = true
		if not node.has_meta("phase"):
			node.set_meta("phase", randf() * TAU)
	elif flat != null:
		flat.visible = false


func _apply_style() -> void:
	var real := is_realistic()
	if real:
		var fin: Dictionary = FINISHES[style]
		for key: String in ["light", "dark"]:
			var half: Dictionary = fin[key]
			_squares_tex.set_shader_parameter(key + "_tex", _texture(half["tex"]))
			_squares_tex.set_shader_parameter(key + "_normal", _texture(half["normal"]))
			_squares_tex.set_shader_parameter(key + "_tint", half["tint"])
			_squares_tex.set_shader_parameter(key + "_grain", half["grain"])
			_squares_tex.set_shader_parameter(key + "_turn", half["turn"])
		var board: Dictionary = fin["board"]
		_squares_tex.set_shader_parameter("rough", board["rough"])
		_squares_tex.set_shader_parameter("coat", board["coat"])
		_squares_tex.set_shader_parameter("metallic", board["metallic"])
		_squares_tex.set_shader_parameter("normal_depth", board["normal_depth"])
		_squares_tex.set_shader_parameter("joint_dark", board["joint"])
		var frame: Dictionary = fin["frame"]
		_frame_tex.set_shader_parameter("wood", _texture(frame["tex"]))
		for key: String in ["tint", "rough", "coat", "metallic", "grain"]:
			_frame_tex.set_shader_parameter(key, frame[key])
		for side in 2:
			var piece: Dictionary = fin["pieces"][side]
			_tex_mats[side].set_shader_parameter("wood", _texture(piece["tex"]))
			_tex_mats[side].set_shader_parameter("tint", piece["tint"])
			_tex_mats[side].set_shader_parameter("grain_scale", piece["grain"])
			_tex_mats[side].set_shader_parameter("rough", piece["rough"])
			_tex_mats[side].set_shader_parameter("coat", piece["coat"])
			_tex_mats[side].set_shader_parameter("metallic", piece["metallic"])
			_tex_mats[side].set_shader_parameter("rim_amount", piece["rim"])
			_tex_mats[side].set_shader_parameter("rim_color", Color("c9d6f2"))
	# Fichas: el cuerpo es del material de su bando y el icono, del material del bando contrario.
	for side in 2:
		var km := _token_mats[side]
		if real:
			var own: Dictionary = FINISHES[style]["pieces"][side]
			var other: Dictionary = FINISHES[style]["pieces"][1 - side]
			km.set_shader_parameter("use_textures", 1.0)
			km.set_shader_parameter("wood", _texture(own["tex"]))
			km.set_shader_parameter("inlay_tex", _texture(other["tex"]))
			km.set_shader_parameter("tint", own["tint"])
			km.set_shader_parameter("inlay_tint", other["tint"])
			km.set_shader_parameter("grain_scale", own["grain"])
			km.set_shader_parameter("rough", own["rough"])
			km.set_shader_parameter("inlay_rough", other["rough"])
			km.set_shader_parameter("metallic", own["metallic"])
			km.set_shader_parameter("inlay_metallic", other["metallic"])
			km.set_shader_parameter("coat", own["coat"])
			km.set_shader_parameter("rim_amount", own["rim"])
			km.set_shader_parameter("rim_color", Color("c9d6f2"))
		else:
			var flat: Array[Color] = [Color("f8f0e0"), Color("2a3557")]
			km.set_shader_parameter("use_textures", 0.0)
			km.set_shader_parameter("tint", flat[side])
			km.set_shader_parameter("inlay_tint", flat[1 - side])
			km.set_shader_parameter("rough", 0.42)
			km.set_shader_parameter("inlay_rough", 0.42)
			km.set_shader_parameter("metallic", 0.0)
			km.set_shader_parameter("inlay_metallic", 0.0)
			km.set_shader_parameter("coat", 0.0)
			km.set_shader_parameter("rim_amount", 0.36 if side == 0 else 0.56)
			km.set_shader_parameter("rim_color", Color("94846c") if side == 0 else Color("9db2e0"))
	_squares_node.material_override = _squares_tex if real else _squares_mat
	_frame_node.material_override = _frame_tex if real else _frame_mat
	# Los acabados realistas se iluminan con el entorno de estudio (luz ambiente y reflejos); el ilustrado, con
	# un color de ambiente liso y sin reflejos.
	_env.sky = _sky if real else null
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if real else Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if real else Environment.REFLECTION_SOURCE_DISABLED
	for node: Node3D in _pieces.values():
		_dress(node)
	for node: Node3D in _dying:
		if is_instance_valid(node):
			_dress(node)


func set_theme(theme_name: String) -> void:
	_theme_name = theme_name
	if not _built:
		return
	var dark := theme_name == "dark"
	_shadow_mat.set_shader_parameter("shadow_color", Color("000208") if dark else Color("203060"))
	_shadow_mat.set_shader_parameter("strength", 0.75 if dark else 0.36)
	var outline_colors: Array[Color] = [Color("262e4c"), Color("0a0f22")]
	var light_label := Color.WHITE
	var dark_label := Color.BLACK
	if is_realistic():
		# Estudio: luz principal cálida con sombra, ambiente y reflejos del entorno, y una contra suave.
		var fin: Dictionary = FINISHES[style]
		var setup: Dictionary = fin["light_setup"]
		_env.ambient_light_sky_contribution = 1.0
		_env.ambient_light_energy = setup["ambient"]
		_sky_mat.set_shader_parameter("intensity", setup["sky"])
		_key.light_color = Color("fff1dc")
		_key.light_energy = setup["key"]
		_fill.light_energy = 0.0
		_rim_light.light_color = Color("dfe9ff")
		_rim_light.light_energy = setup["rim"]
		outline_colors[0] = fin["outline"][0]
		outline_colors[1] = fin["outline"][1]
		light_label = fin["labels"][0]
		dark_label = fin["labels"][1]
	else:
		_env.ambient_light_color = Color("aebbe0") if dark else Color("dfe8f6")
		_env.ambient_light_energy = 0.42
		_key.light_color = Color("fff0dc") if dark else Color("fff5e6")
		_key.light_energy = 0.9 if dark else 0.76
		_fill.light_color = Color("9db4ff") if dark else Color("cfe0ff")
		_fill.light_energy = 0.2 if dark else 0.16
		_rim_light.light_energy = 0.0
		_frame_mat.albedo_color = Color("202b4e") if dark else Color("27335a")
		# Casillas con cuerpo: las claras no llegan al blanco, para que las piezas de marfil destaquen sobre ellas.
		var light_sq := Color("bfcfea") if dark else Color("bdcdea")
		var dark_sq := Color("6481b5") if dark else Color("6683b7")
		_squares_mat.set_shader_parameter("light_sq", light_sq)
		_squares_mat.set_shader_parameter("dark_sq", dark_sq)
		# Claras: marfil limpio. Oscuras: azul tinta con el canto más claro.
		_mats[0].set_shader_parameter("base_color", Color("f8f0e0"))
		_mats[0].set_shader_parameter("rim_color", Color("94846c"))
		_mats[0].set_shader_parameter("rim_amount", 0.36)
		_mats[1].set_shader_parameter("base_color", Color("2a3557"))
		_mats[1].set_shader_parameter("rim_color", Color("9db2e0"))
		_mats[1].set_shader_parameter("rim_amount", 0.56)
		light_label = light_sq.lightened(0.65)
		dark_label = dark_sq.darkened(0.3)
	# Las negras llevan el contorno amarillo: en tinta oscura no se veía, y así una pieza negra se separa bien de la
	# que tiene delante o detrás en la vista 3D (petición de Pablo).
	outline_colors[1] = BLACK_OUTLINE
	for i in 2:
		_outline_mats[i].set_shader_parameter("outline_color", outline_colors[i])
		_disc_mats[i].set_shader_parameter("outline_color", outline_colors[i])
	for group in _labels:
		for l in group.get_children():
			(l as Label3D).modulate = light_label if l.get_meta("on_dark", false) else dark_label


# ---------------------------------------------------------------- posición y piezas

static func sq_pos(s: int) -> Vector3:
	return Vector3((s & 7) - 3.5, 0.0, 3.5 - (s >> 3))


## Giro de cada pieza para que se lea bien desde el lado del jugador:
## los caballos miran al rival en tres cuartos y el corte del alfil queda hacia la cámara.
func _yaw_for(p: int) -> float:
	if is_tokens():
		# El icono queda derecho para quien juega abajo, sea del color que sea la ficha.
		return 0.0 if orientation == 0 else PI
	var t := Chess.type_of(p)
	var white := Chess.color_of(p) == 0
	var yaw := PI if white else 0.0
	if t == Chess.KNIGHT:
		yaw = deg_to_rad(125.0 if white else 55.0)
		if orientation == 1:
			yaw = -yaw
	elif t == Chess.BISHOP:
		yaw = deg_to_rad(-45.0 if orientation == 0 else 135.0)
	return yaw


func _make_piece(p: int, s: int) -> Node3D:
	var node := Node3D.new()
	var mesh := _piece_mesh(Chess.type_of(p))
	var side := Chess.color_of(p)
	var mi := MeshInstance3D.new()
	mi.name = "Malla"
	mi.mesh = mesh
	node.add_child(mi)
	# Contorno: la misma malla con el material de casco invertido. No proyecta sombra.
	var hull := MeshInstance3D.new()
	hull.name = "Contorno"
	hull.mesh = mesh
	hull.material_override = _outline_mats[side]
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hull.visible = outline
	node.add_child(hull)
	# Y un disco bajo la base, que cierra el contorno donde la pieza toca el tablero.
	var disc := MeshInstance3D.new()
	disc.name = "Peana"
	disc.mesh = _disc_mesh
	disc.material_override = _disc_mats[side]
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = Vector3(0.0, 0.007, 0.0)
	disc.visible = outline
	node.add_child(disc)
	_fit_disc(node, mesh)
	node.set_meta("piece", p)
	node.set_meta("yaw", _yaw_for(p))
	_dress(node)
	_pieces_root.add_child(node)
	_rest(node, s)
	return node


## El disco de la base mide lo que la base de la malla más el grosor del contorno.
func _fit_disc(node: Node3D, mesh: Mesh) -> void:
	var radius := 0.33
	if mesh != null:
		radius = mesh.get_aabb().size.x * 0.5
	var r := radius + OUTLINE_WIDTH
	(node.get_node("Peana") as MeshInstance3D).scale = Vector3(r, 1.0, r)


## Atlas del juego «Simple» (se carga al usarlo por primera vez).
func _simple_texture() -> Texture2D:
	var key := piece_set if FLAT_ATLAS.has(piece_set) else "simple"
	if not _flat_cache.has(key):
		var path := str(FLAT_ATLAS[key])
		var bytes := FileAccess.get_file_as_bytes(path)
		var img := Image.new()
		if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
			push_error("No se pueden cargar las piezas planas: " + path)
			img = Image.create(12, 2, false, Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		_flat_cache[key] = ImageTexture.create_from_image(img)
	_simple_tex = _flat_cache[key]
	return _simple_tex


## Con el tablero inclinado, el dibujo (que mira a la cámara) se encoge lo justo para caber en el fondo aparente de
## su casilla.
func _size_simple(pitch: float) -> void:
	var tex := _simple_texture() if is_flat() else _simple_tex
	if tex == null:
		return
	var px := float(tex.get_height()) * 0.5
	_simple_pixel = 1.0 / px
	# «Simple» cabe siempre en el fondo aparente de su casilla. Los recortables de los mundos se ponen de pie al
	# inclinar el tablero (con los pies en el centro de la casilla) y entonces pueden ser más altos que ella.
	_stand = clampf((1.0 - sin(pitch)) / 0.2, 0.0, 1.0) if is_standee() else 0.0
	_flat_size = lerpf(SIMPLE_SIZE * clampf(sin(pitch), 0.55, 1.0), STANDEE_SIZE, _stand)
	if not is_flat():
		return
	if not _running > 0:
		for s: int in _pieces:
			_rest(_pieces[s], s)


## Personaje articulado de una pieza (juego «Aventura»): lo crea, lo cambia si la pieza ha coronado o lo quita.
func _dress_figure(node: Node3D, piece: int) -> void:
	var fig := node.get_node_or_null("Figura") as Node3D
	if not is_rigged():
		if fig != null:
			node.remove_child(fig)
			fig.queue_free()
		var mark := node.get_node_or_null("Marca")
		if mark != null:
			node.remove_child(mark)
			mark.queue_free()
		return
	if fig != null and int(fig.get_meta("piece", -1)) == piece:
		return
	if fig != null:
		node.remove_child(fig)
		fig.queue_free()
	var kind := Chess.type_of(piece)
	var side := Chess.color_of(piece)
	var cfg: Dictionary = RIG[kind]
	var template := _rig_scene(str(cfg["who"]))
	if template == null:
		return
	fig = template.duplicate() as Node3D
	fig.name = "Figura"
	fig.set_meta("piece", piece)
	var size: float = cfg["size"]
	fig.scale = Vector3.ONE * size / PIECE_GIRTH
	fig.position = Vector3(0.0, float(TOKEN["height"]) * (PAWN_TOKEN_SCALE if kind == Chess.PAWN else 1.0), 0.0)
	var show: Array = cfg["show"]
	for mi: MeshInstance3D in fig.find_children("*", "MeshInstance3D", true, false):
		var part := false
		for tag: String in RIG_BODY:
			if str(mi.name).contains(tag):
				part = true
		mi.visible = part or show.has(str(mi.name))
		if side == 1 and mi.visible and mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var base := mi.mesh.surface_get_material(i) as BaseMaterial3D
				if base == null:
					continue
				if not _rig_dark.has(base):
					var dark := base.duplicate() as BaseMaterial3D
					dark.albedo_color = RIG_DARK
					_rig_dark[base] = dark
				mi.set_surface_override_material(i, _rig_dark[base])
	node.add_child(fig)
	_mark_figure(node, fig, piece)
	_face(node, _forward_yaw(side))
	var ap := _fig_player(node)
	if ap != null:
		ap.play("Idle")
		ap.seek(randf() * 1.2, true)


## Sobre la cabeza de cada personaje, una chapita con el dibujo de su pieza: así se sabe enseguida qué es cada
## figura. Blanca con el dibujo oscuro para las blancas; oscura con el dibujo claro para las negras. Siempre se ve
## (sin prueba de profundidad) y mira a la cámara.
func _mark_figure(node: Node3D, fig: Node3D, piece: int) -> void:
	var old := node.get_node_or_null("Marca")
	if old != null:
		node.remove_child(old)
		old.queue_free()
	var icon := UiIcons.texture(["", "piece_pawn", "piece_knight", "piece_bishop", "piece_rook", "piece_queen", "piece_king"][Chess.type_of(piece)])
	if icon == null:
		return
	# Altura de la cabeza (o del sombrero): la parte más alta de lo que se ve del personaje.
	var top := 0.0
	for mi: MeshInstance3D in fig.find_children("*", "MeshInstance3D", true, false):
		if mi.visible and mi.mesh != null:
			var box := mi.mesh.get_aabb()
			top = maxf(top, (fig.transform * mi.transform * box.end).y)
	if top <= 0.0:
		top = 1.0
	var side := Chess.color_of(piece)
	var mark := Node3D.new()
	mark.name = "Marca"
	mark.position = Vector3(0.0, top + 0.16, 0.0)
	var disc := Sprite3D.new()
	disc.texture = _round_texture()
	disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	disc.no_depth_test = true
	disc.shaded = false
	disc.pixel_size = 0.0027
	disc.modulate = Color("fdfdff") if side == 0 else Color("1b2540")
	disc.render_priority = 3
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(disc)
	var pic := Sprite3D.new()
	pic.texture = icon
	pic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pic.no_depth_test = true
	pic.shaded = false
	pic.pixel_size = 0.17 / maxf(1.0, float(icon.get_width()))
	pic.modulate = Color("1b2540") if side == 0 else Color("f5c542")
	pic.render_priority = 4
	pic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(pic)
	node.add_child(mark)


## Disco blanco con el borde suave (para las chapas): se dibuja una vez.
func _round_texture() -> Texture2D:
	if _badge_tex == null:
		var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		for y in 96:
			for x in 96:
				var d := Vector2(float(x) - 47.5, float(y) - 47.5).length()
				var a := clampf(46.0 - d, 0.0, 1.0)
				var rim := clampf(d - 39.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a).lerp(Color(0.92, 0.92, 0.92, a), rim))
		_badge_tex = ImageTexture.create_from_image(img)
	return _badge_tex


func _exit_tree() -> void:
	for scene: Variant in _rig_scenes.values():
		if scene != null and is_instance_valid(scene):
			(scene as Node).free()
	_rig_scenes.clear()


## Carga (una vez) el .glb de un personaje y prepara sus animaciones en bucle.
func _rig_scene(who: String) -> Node3D:
	if not _rig_scenes.has(who):
		var bytes := FileAccess.get_file_as_bytes(RIG_DIR + who + ".bin")
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var scene: Node3D = null
		if not bytes.is_empty() and doc.append_from_buffer(bytes, "", state) == OK:
			scene = doc.generate_scene(state) as Node3D
		if scene == null:
			push_error("No se puede cargar el personaje: " + who)
		else:
			var ap := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap != null:
				for anim_name: String in RIG_LOOPS:
					if ap.has_animation(anim_name):
						ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
				ap.playback_default_blend_time = 0.12
		_rig_scenes[who] = scene
	return _rig_scenes[who]


func _fig_player(node: Node3D) -> AnimationPlayer:
	if not is_instance_valid(node):
		return null
	var fig := node.get_node_or_null("Figura")
	return fig.find_child("AnimationPlayer", true, false) as AnimationPlayer if fig != null else null


func _fig_play(node: Node3D, anim_name: String, speed: float = 1.0) -> void:
	var ap := _fig_player(node)
	if ap != null and ap.has_animation(anim_name):
		ap.play(anim_name, -1.0, speed)


## Deja en cola la vuelta al reposo cuando acabe lo que esté haciendo.
func _fig_then_idle(node: Node3D) -> void:
	var ap := _fig_player(node)
	if ap != null:
		ap.queue("Idle")


func _fig_len(node: Node3D, anim_name: String) -> float:
	var ap := _fig_player(node)
	return ap.get_animation(anim_name).length if ap != null and ap.has_animation(anim_name) else 0.5


## Gira el personaje hacia un rumbo del tablero (su ficha no gira).
func _face(node: Node3D, yaw_world: float) -> void:
	if not is_instance_valid(node):
		return
	var fig := node.get_node_or_null("Figura") as Node3D
	if fig != null:
		fig.rotation.y = yaw_world - float(node.get_meta("yaw", 0.0))


func _face_dir(node: Node3D, dir: Vector3) -> void:
	_face(node, atan2(dir.x, dir.z))


## Rumbo «hacia el rival» de cada bando: las blancas avanzan hacia −z.
func _forward_yaw(side: int) -> float:
	return PI if side == 0 else 0.0


## Bola de magia del alfil (un mago): vuela hasta la pieza que come.
func _spell(from_pos: Vector3, to_pos: Vector3, seconds: float) -> void:
	var orb := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.22
	orb.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.85, 1.0)
	orb.material_override = mat
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.position = from_pos + Vector3(0.0, 0.75, 0.0)
	add_child(orb)
	var tw := create_tween()
	tw.tween_property(orb, "position", to_pos + Vector3(0.0, 0.55, 0.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(orb.queue_free)


## Selección: el contorno de la pieza se vuelve del color de acento.
func _set_glow(node: Node3D, amount: float) -> void:
	for part: String in ["Malla", "Contorno", "Peana"]:
		(node.get_node(part) as MeshInstance3D).set_instance_shader_parameter("glow", amount)
	# Simple: la pieza elegida se tiñe un poco del color de acento.
	var flat := node.get_node_or_null("Plano") as Sprite3D
	if flat != null:
		flat.modulate = Color.WHITE.lerp(Color(1.0, 0.75, 0.5), amount)


## Deja la pieza en reposo en su casilla.
func _rest(node: Node3D, s: int) -> void:
	var lift := 0.1 if s == selected else 0.0
	_pose(node, sq_pos(s) + Vector3(0.0, lift, 0.0), Vector3.UP, 0.0)
	var topple: float = node.get_meta("topple", 0.0)
	if topple != 0.0 and is_rigged():
		# El rey articulado no vuelca la ficha: se queda tumbado él.
		var ap := _fig_player(node)
		if ap != null and ap.current_animation != "Death_B":
			ap.play("Death_B_Pose")
	elif topple != 0.0:
		var lift_up: float = node.get_meta("topple_lift", 0.0)
		_pose(node, sq_pos(s) + Vector3(0.0, lift_up, 0.0), node.get_meta("topple_axis", Vector3.RIGHT), topple)


func _pose(node: Node3D, pos: Vector3, axis: Vector3, angle: float, squash: float = 1.0, size: float = 1.0) -> void:
	if not is_instance_valid(node):
		return
	if is_flat():
		_pose_flat(node, pos, axis, angle, squash, size)
		return
	var yaw: float = node.get_meta("yaw", 0.0)
	var bas := Basis(Vector3.UP, yaw)
	if absf(angle) > 0.0001 and axis.length_squared() > 0.25:
		bas = Basis(axis.normalized(), angle) * bas
	var sc := PIECE_SCALE * maxf(size, 0.001)
	var wide := sc * PIECE_GIRTH / sqrt(maxf(squash, 0.05))
	node.transform = Transform3D(bas * Basis.from_scale(Vector3(wide, sc * squash, wide)), pos)


## Pose de un recortable: mira a la cámara y traduce el giro de la pieza a gestos de papel. Girar sobre el eje
## vertical lo voltea (se ve de canto y se da la vuelta); inclinarse de lado lo balancea sobre los pies; inclinarse
## hacia la cámara o lejos de ella lo acorta. Además respira un poco, cada pieza a su ritmo.
func _pose_flat(node: Node3D, pos: Vector3, axis: Vector3, angle: float, squash: float, size: float) -> void:
	node.transform = Transform3D(Basis.IDENTITY, pos)
	var flat := node.get_node_or_null("Plano") as Sprite3D
	if flat == null:
		return
	var sx := 1.0
	var sy := 1.0
	var roll := 0.0
	if absf(angle) > 0.0001 and axis.length_squared() > 0.25:
		var ax := axis.normalized()
		var spin := ax.y
		var toward := Vector3(_cam_back.x, 0.0, _cam_back.z)
		toward = toward.normalized() if toward.length() > 0.15 else Vector3(_cam_up.x, 0.0, _cam_up.z).normalized()
		var side := Vector3.UP.cross(toward)
		if absf(spin) > 0.7:
			sx = cos(angle * spin)
			sx = signf(sx) * maxf(absf(sx), 0.06) if sx != 0.0 else 0.06
		else:
			roll = angle * ax.dot(toward)
			sy = maxf(cos(clampf(angle * ax.dot(side), -1.3, 1.3)), 0.25)
	var breath := 0.0
	if is_standee() and anim_mode == Anim.FULL:
		breath = 0.028 * sin(_life_t * 2.3 + float(node.get_meta("phase", 0.0)))
	var sc := _flat_size * maxf(size, 0.001)
	var wide := sc / sqrt(maxf(squash, 0.05))
	var bas := Basis(_cam_right, _cam_up, _cam_back) * Basis(Vector3.BACK, roll)
	flat.transform = Transform3D(bas * Basis.from_scale(Vector3(wide * sx * (1.0 - breath * 0.5), sc * squash * sy * (1.0 + breath), 1.0)), Vector3(0.0, 0.02, 0.0))
	# De pie, los pies van en el centro de la casilla; visto desde arriba, el dibujo va centrado.
	var px := float(flat.region_rect.size.y)
	flat.offset = Vector2(0.0, px * 0.46 * _stand)


func set_fen(fen: String) -> void:
	set_badge(-1, "")
	_kill_tweens()
	chess = Chess.from_fen(fen)
	last_from = -1
	last_to = -1
	selected = -1
	_drag_sq = -1
	_targets = PackedInt32Array()
	if not _built:
		return
	for n in _pieces_root.get_children():
		_pieces_root.remove_child(n)
		n.queue_free()
	_pieces.clear()
	_dying.clear()
	for s in 64:
		if chess.b[s] != 0:
			_pieces[s] = _make_piece(chess.b[s], s)
	_refresh_state()


func set_orientation(o: int) -> void:
	orientation = o
	if not _built:
		return
	_light_rig.rotation.y = PI if o == 1 else 0.0
	_env.sky_rotation = Vector3(0.0, PI if o == 1 else 0.0, 0.0)
	# La sombra del tablero cae un poco hacia el lado del jugador.
	_shadow_node.position.z = -0.16 if o == 1 else 0.16
	_labels[0].visible = show_coordinates and o == 0
	_labels[1].visible = show_coordinates and o == 1
	for s: int in _pieces:
		var node: Node3D = _pieces[s]
		node.set_meta("yaw", _yaw_for(node.get_meta("piece")))
		_rest(node, s)
	apply_camera()


# ---------------------------------------------------------------- resaltados y flechas

func _refresh_state() -> void:
	var hi := PackedByteArray()
	hi.resize(64)
	var mark := PackedByteArray()
	mark.resize(64)
	if last_from >= 0:
		hi[last_from] = 1
	if last_to >= 0:
		hi[last_to] = 2
	if selected >= 0:
		hi[selected] = 3
	if chess.in_check():
		hi[chess.king_sq(chess.turn)] = 4
	for m in _targets:
		var to := Chess.move_to(m)
		mark[to] = 2 if chess.b[to] != 0 or Chess.move_flag(m) == Chess.F_EN_PASSANT else 1
	for s in 64:
		_state_img.set_pixel(s & 7, s >> 3, Color8(hi[s], mark[s], 255 if chess.b[s] != 0 else 0, 255))
	_state_tex.update(_state_img)
	# Con fichas, el rey en jaque se tiñe: la ficha tapa casi toda la casilla resaltada.
	var alert_sq := chess.king_sq(chess.turn) if is_tokens() and chess.in_check() else -1
	for s: int in _pieces:
		((_pieces[s] as Node3D).get_node("Malla") as MeshInstance3D).set_instance_shader_parameter("alert", 1.0 if s == alert_sq else 0.0)


## Marca una jugada como la última sin moverla: para recuperar el resaltado al volver a una posición anterior.
func mark_last_move(from: int, to: int) -> void:
	last_from = from
	last_to = to
	if _built:
		_refresh_state()


## Flechas de las explicaciones: lista de diccionarios {from: int, to: int, tone: "good" | "bad" | "info"}.
## Valoración de una jugada, a la manera de las anotaciones de ajedrez («!», «?», «??»…): una chapa redonda en la
## esquina de la casilla de destino. Con texto vacío se quita.
## Chapa de anotación sobre una casilla: un disco de color con un signo («!», «?!»…) o, con `icon`, un icono
## (la marca de «buena», la de «única»).
func set_badge(sq: int, glyph: String, color: Color = Color.WHITE, icon: Texture2D = null) -> void:
	if _badge != null and is_instance_valid(_badge):
		_badge.queue_free()
	_badge = null
	if (glyph == "" and icon == null) or sq < 0:
		return
	if _badge_tex == null:
		var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		for y in 96:
			for x in 96:
				var d := Vector2(float(x) - 47.5, float(y) - 47.5).length()
				var a := clampf(46.0 - d, 0.0, 1.0)
				var rim := clampf(d - 39.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a).lerp(Color(0.92, 0.92, 0.92, a), rim))
		_badge_tex = ImageTexture.create_from_image(img)
	_badge = Node3D.new()
	var disc := Sprite3D.new()
	disc.texture = _badge_tex
	disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	disc.no_depth_test = true
	disc.shaded = false
	disc.pixel_size = 0.0042
	disc.modulate = color
	disc.render_priority = 3
	_badge.add_child(disc)
	if icon != null:
		var pic := Sprite3D.new()
		pic.texture = icon
		pic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pic.no_depth_test = true
		pic.shaded = false
		pic.pixel_size = 0.27 / maxf(1.0, float(icon.get_width()))
		pic.modulate = Color.WHITE
		pic.render_priority = 4
		_badge.add_child(pic)
		_badge.position = sq_pos(sq) + (_cam_right + _cam_up) * 0.36 + Vector3(0.0, 0.06, 0.0)
		add_child(_badge)
		return
	var mark := Label3D.new()
	mark.text = glyph
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.shaded = false
	mark.font_size = 64 if glyph.length() < 2 else 52
	mark.pixel_size = 0.0042
	mark.outline_size = 0
	mark.modulate = Color.WHITE
	mark.render_priority = 4
	_badge.add_child(mark)
	_badge.position = sq_pos(sq) + (_cam_right + _cam_up) * 0.36 + Vector3(0.0, 0.06, 0.0)
	add_child(_badge)


func set_arrows(arrows: Array) -> void:
	for n in _arrows_root.get_children():
		_arrows_root.remove_child(n)
		n.queue_free()
	for a: Dictionary in arrows:
		var tone: String = a.get("tone", "info")
		var color := Color("1f9a52") if tone == "good" else (Color("e5484d") if tone == "bad" else Color("7c5cfa"))
		var mi := MeshInstance3D.new()
		mi.mesh = _arrow_mesh(sq_pos(int(a["from"])), sq_pos(int(a["to"])), chess.b[int(a["to"])] != 0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(color.r, color.g, color.b, 0.86)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, 0.014, 0.0)
		_arrows_root.add_child(mi)


## La flecha sale del borde de la pieza de origen y, si el destino está ocupado, se detiene antes de su base.
func _arrow_mesh(a: Vector3, b: Vector3, occupied: bool) -> ArrayMesh:
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var start := a + dir * 0.4
	var tip := b - dir * 0.36 if occupied else b + dir * 0.12
	var neck := tip - dir * 0.42
	var w := 0.085
	var hw := 0.24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [start - side * w, start + side * w, neck + side * w, start - side * w, neck + side * w, neck - side * w, neck - side * hw, neck + side * hw, tip]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
	return st.commit()


# ---------------------------------------------------------------- cámara

func apply_camera() -> void:
	if camera == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		return
	var yaw := deg_to_rad(cam_yaw + (180.0 if orientation == 1 else 0.0))
	var pitch := deg_to_rad(clampf(cam_pitch, PITCH_MIN, PITCH_MAX))
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var up := back.cross(right)
	_cam_right = right
	_cam_up = up
	_cam_back = back
	# Encuadre: la cámara se coloca a la menor distancia a la que caben, dentro de la vista y con su margen,
	# las esquinas del marco y la altura de las piezas. En un móvil en vertical manda el ancho: el tablero
	# va de lado a lado. Si la vista es baja (o se gira el tablero), manda el alto y la cámara se aleja.
	var th := tan(deg_to_rad(cam_fov) * 0.5)
	var tv := th * vp.y / vp.x
	var lim_l := -1.0 + 2.0 * fit_pad.x
	var lim_r := 1.0 - 2.0 * fit_pad.z
	var lim_t := 1.0 - 2.0 * fit_pad.y
	var lim_b := -1.0 + 2.0 * fit_pad.w
	var pa := PackedFloat32Array()
	var pb := PackedFloat32Array()
	var pc := PackedFloat32Array()
	var fit_height := FIT_HEIGHT_TOKENS if (is_tokens() and not is_rigged()) or is_flat() else FIT_HEIGHT
	_size_simple(pitch)
	for ix: int in [-1, 1]:
		for iz: int in [-1, 1]:
			var fx := float(ix)
			var fz := float(iz)
			for q: Vector3 in [Vector3(fx * FRAME_HALF, 0.0, fz * FRAME_HALF), Vector3(fx * FRAME_HALF, -FRAME_THICK, fz * FRAME_HALF), Vector3(fx * 3.5, fit_height, fz * 3.5)]:
				pa.append(q.dot(right))
				pb.append(q.dot(up))
				pc.append(q.dot(back))
	var n := pa.size()
	var sx := 0.0
	var sy := 0.0
	var dist := 10.0
	for _pass in 8:
		dist = -1.0e9
		for i in n:
			dist = maxf(dist, (pa[i] - sx) / (lim_r * th) + pc[i])
			dist = maxf(dist, (pa[i] - sx) / (lim_l * th) + pc[i])
			dist = maxf(dist, (pb[i] - sy) / (lim_t * tv) + pc[i])
			dist = maxf(dist, (pb[i] - sy) / (lim_b * tv) + pc[i])
		# Con esa distancia, se centra lo que sobra a cada lado.
		var x_min := 1.0e9
		var x_max := -1.0e9
		var y_min := 1.0e9
		var y_max := -1.0e9
		for i in n:
			var depth := dist - pc[i]
			var xn := (pa[i] - sx) / (depth * th)
			var yn := (pb[i] - sy) / (depth * tv)
			x_min = minf(x_min, xn)
			x_max = maxf(x_max, xn)
			y_min = minf(y_min, yn)
			y_max = maxf(y_max, yn)
		sx -= ((lim_r - x_max) - (x_min - lim_l)) * 0.5 * th * dist
		sy -= ((lim_t - y_max) - (y_min - lim_b)) * 0.5 * tv * dist
	# Lo que ocupa el tablero en la vista con ese encuadre (coordenadas de −1 a 1).
	var ext_l := 1.0e9
	var ext_r := -1.0e9
	var ext_b := 1.0e9
	var ext_t := -1.0e9
	for i in n:
		var d := dist - pc[i]
		ext_l = minf(ext_l, (pa[i] - sx) / (d * th))
		ext_r = maxf(ext_r, (pa[i] - sx) / (d * th))
		ext_b = minf(ext_b, (pb[i] - sy) / (d * tv))
		ext_t = maxf(ext_t, (pb[i] - sy) / (d * tv))
	_fit_th = th
	_fit_tv = tv
	_fit_dist = dist
	# Ampliación: se estrecha el campo de visión (la perspectiva no cambia) y la cámara se desplaza de lado.
	# El desplazamiento se limita para que el tablero siga cubriendo la zona que ocupaba sin ampliar.
	zoom = clampf(zoom, 1.0, ZOOM_MAX)
	var hx := th * dist / zoom
	var hy := tv * dist / zoom
	var lo_x := ext_l * th * dist - lim_l * hx
	var hi_x := ext_r * th * dist - lim_r * hx
	pan.x = clampf(pan.x, lo_x, hi_x) if lo_x <= hi_x else (lo_x + hi_x) * 0.5
	var lo_y := ext_b * tv * dist - lim_b * hy
	var hi_y := ext_t * tv * dist - lim_t * hy
	pan.y = clampf(pan.y, lo_y, hi_y) if lo_y <= hi_y else (lo_y + hi_y) * 0.5
	camera.fov = rad_to_deg(2.0 * atan(th / zoom))
	# Planos de recorte ceñidos al tablero: con la cámara lejos, así no se pierde precisión de profundidad.
	camera.near = maxf(0.5, dist - 16.0)
	camera.far = dist + 30.0
	camera.transform = Transform3D(Basis(right, up, back), right * (sx + pan.x) + up * (sy + pan.y) + back * dist)
	_key.directional_shadow_max_distance = dist + 12.0


## Amplía o reduce alrededor de un punto de la vista (en píxeles): lo que está bajo los dedos se queda bajo ellos.
func zoom_at(factor: float, view_pos: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var before := zoom
	var after := clampf(zoom * factor, 1.0, ZOOM_MAX)
	if vp.x < 2.0 or vp.y < 2.0 or is_equal_approx(before, after):
		return
	var m := Vector2(view_pos.x / vp.x * 2.0 - 1.0, 1.0 - view_pos.y / vp.y * 2.0)
	var k := 1.0 / before - 1.0 / after
	pan += Vector2(m.x * _fit_th, m.y * _fit_tv) * _fit_dist * k
	zoom = after
	apply_camera()


## Desplaza la vista ampliada siguiendo al dedo (en píxeles de la vista).
func pan_by(delta: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 2.0 or vp.y < 2.0 or zoom <= 1.0:
		return
	pan.x -= delta.x * 2.0 * _fit_th * _fit_dist / (zoom * vp.x)
	pan.y += delta.y * 2.0 * _fit_tv * _fit_dist / (zoom * vp.y)
	apply_camera()


## Vuelve al tablero encuadrado, sin ampliar.
func reset_zoom() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	apply_camera()


func set_view(pitch: float, yaw: float) -> void:
	cam_pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	cam_yaw = wrapf(yaw, -180.0, 180.0)
	apply_camera()


func _view_step(t: float, p0: float, y0: float, p1: float, y1: float, z0: float, pan0: Vector2, unzoom: bool) -> void:
	if unzoom:
		zoom = lerpf(z0, 1.0, t)
		pan = pan0.lerp(Vector2.ZERO, t)
	set_view(lerpf(p0, p1, t), lerpf(y0, y1, t))


## Lleva la cámara con suavidad a una vista (por ejemplo, en picado: pitch = 90). Por defecto, además,
## deshace la ampliación: el tablero vuelve a verse entero.
func animate_view(pitch: float, yaw: float, seconds: float = 0.4, unzoom: bool = true) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	if seconds <= 0.0 or anim_mode == Anim.NONE:
		if unzoom:
			zoom = 1.0
			pan = Vector2.ZERO
		set_view(pitch, yaw)
		return
	_cam_tween = create_tween()
	_cam_tween.tween_method(_view_step.bind(cam_pitch, cam_yaw, pitch, yaw, zoom, pan, unzoom), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- toque

## Qué hay bajo un punto de la pantalla: x = casilla del plano del tablero, y = casilla de la pieza tocada (−1 si nada).
func pick(screen_pos: Vector2) -> Vector2i:
	var o := camera.project_ray_origin(screen_pos)
	var d := camera.project_ray_normal(screen_pos)
	var plane_sq := -1
	if d.y < -0.0001:
		var hit := o + d * (-o.y / d.y)
		var f := int(floor(hit.x + 4.0))
		var r := int(floor(4.0 - hit.z))
		if f >= 0 and f < 8 and r >= 0 and r < 8:
			plane_sq = f + 8 * r
	var best := INF
	var piece_sq := -1
	# Las fichas son más anchas que el pie de las figuras.
	var reach := 0.43 if is_tokens() else PICK_RADIUS
	for s: int in _pieces:
		var node: Node3D = _pieces[s]
		var c := sq_pos(s)
		var h := _piece_height(Chess.type_of(node.get_meta("piece")))
		var ox := o.x - c.x
		var oz := o.z - c.z
		var qa := d.x * d.x + d.z * d.z
		var t := INF
		if qa > 1e-9:
			var qb := 2.0 * (ox * d.x + oz * d.z)
			var qc := ox * ox + oz * oz - reach * reach
			var disc := qb * qb - 4.0 * qa * qc
			if disc >= 0.0:
				var t0 := (-qb - sqrt(disc)) / (2.0 * qa)
				var y0 := o.y + d.y * t0
				if t0 > 0.0 and y0 >= 0.0 and y0 <= h:
					t = t0
		if t == INF and d.y < -0.0001:
			# Por la tapa de arriba.
			var tt := (h - o.y) / d.y
			var px := o.x + d.x * tt - c.x
			var pz := o.z + d.z * tt - c.z
			if tt > 0.0 and px * px + pz * pz <= reach * reach:
				t = tt
		if t < best:
			best = t
			piece_sq = s
	return Vector2i(plane_sq, piece_sq)


func is_own(s: int) -> bool:
	if only_square >= 0 and s != only_square:
		return false
	return s >= 0 and chess.b[s] != 0 and Chess.color_of(chess.b[s]) == chess.turn


# ---------------------------------------------------------------- estrellas de las lecciones

## Pone una estrella dorada, flotando, en cada casilla de la lista (las de antes se quitan).
func set_goals(squares: Array) -> void:
	for n in _goals_root.get_children():
		_goals_root.remove_child(n)
		n.queue_free()
	_goals = {}
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffc93c")
	mat.emission_enabled = true
	mat.emission = Color("ffb300")
	mat.emission_energy_multiplier = 0.45
	mat.roughness = 0.35
	mat.metallic = 0.2
	var mesh := _star_mesh()
	for sq: Variant in squares:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.position = sq_pos(int(sq)) + Vector3(0.0, 0.32, 0.0)
		_goals_root.add_child(mi)
		_goals[int(sq)] = mi
	set_process(true)


func has_goal(s: int) -> bool:
	return _goals.has(s)


func goals_left() -> int:
	return _goals.size()


## Las estrellas miran a la cámara, se balancean un poco y flotan.
func _process(delta: float) -> void:
	var alive := is_standee() and anim_mode == Anim.FULL
	if alive:
		_live(delta)
	if _goals.is_empty():
		if not alive:
			set_process(false)
		return
	_goal_t += delta
	var yaw := deg_to_rad(cam_yaw + (180.0 if orientation == 1 else 0.0))
	var pitch := deg_to_rad(clampf(cam_pitch, PITCH_MIN, PITCH_MAX))
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var i := 0
	for sq: int in _goals:
		var mi: Node3D = _goals[sq]
		var phase := _goal_t * 2.2 + float(i) * 0.9
		var face := back.rotated(Vector3.UP, sin(phase) * 0.45)
		var up := Vector3.UP if absf(face.y) < 0.98 else Vector3.FORWARD
		mi.basis = Basis.looking_at(-face, up)
		mi.position.y = 0.34 + 0.05 * sin(phase * 0.8)
		i += 1


## Vida propia de los recortables: respiran y, de vez en cuando, uno da un saltito o se balancea.
func _live(delta: float) -> void:
	_life_t += delta
	if _running > 0:
		return
	var busy: Node3D = null
	if _idle_tween != null and _idle_tween.is_valid() and _idle_tween.is_running():
		busy = _idle_tween.get_meta("node", null)
	for s: int in _pieces:
		var node: Node3D = _pieces[s]
		if node != busy and node.visible and float(node.get_meta("topple", 0.0)) == 0.0:
			_rest(node, s)
	_idle_wait -= delta
	if _idle_wait > 0.0 or busy != null or _pieces.is_empty():
		return
	_idle_wait = randf_range(1.2, 2.8)
	var squares := _pieces.keys()
	var sq: int = squares[randi() % squares.size()]
	var who: Node3D = _pieces[sq]
	if sq == selected or float(who.get_meta("topple", 0.0)) != 0.0:
		return
	_idle_tween = create_tween()
	_idle_tween.set_meta("node", who)
	var at := sq_pos(sq)
	match randi() % 3:
		0:
			_idle_tween.tween_method(_pose_hop.bind(who, at, 0.16), 0.0, 1.0, 0.36)
			_idle_tween.tween_method(_pose_land.bind(who, at, 0.1), 0.0, 1.0, 0.12)
		1:
			_idle_tween.tween_method(_pose_sway.bind(who, at, 0.22), 0.0, 1.0, 0.7)
		_:
			_idle_tween.tween_method(_pose_twirl.bind(who, at, at), 0.0, 1.0, 0.5)


func _stop_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null


func _pose_hop(t: float, node: Node3D, pos: Vector3, height: float) -> void:
	_pose(node, pos + Vector3(0.0, height * sin(PI * t), 0.0), Vector3.UP, 0.0, 1.0 + 0.1 * sin(PI * t))


func _pose_sway(t: float, node: Node3D, pos: Vector3, amount: float) -> void:
	_pose(node, pos, _cam_back, amount * sin(TAU * 1.5 * t) * sin(PI * t))


## Estrellitas que saltan donde un recortable come a otro.
func _burst(at: Vector3) -> void:
	if _star_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var v := Vector2(float(x) - 31.5, float(y) - 31.5) / 31.5
				var ang := atan2(v.y, v.x)
				var edge := 0.55 + 0.42 * cos(ang * 5.0 + PI * 0.5)
				var a := clampf((edge - v.length()) * 10.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.86, 0.25, a))
		_star_tex = ImageTexture.create_from_image(img)
	for i in 7:
		var star := Sprite3D.new()
		star.texture = _star_tex
		star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		star.no_depth_test = true
		star.shaded = false
		star.pixel_size = 0.0045
		star.render_priority = 2
		star.position = at + Vector3(0.0, 0.3, 0.0)
		_pieces_root_for_fx().add_child(star)
		var ang := TAU * float(i) / 7.0 + randf() * 0.5
		var out := (_cam_right * cos(ang) + _cam_up * sin(ang)) * randf_range(0.5, 0.85)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(star, "position", star.position + out, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "modulate:a", 0.0, 0.38).set_ease(Tween.EASE_IN)
		tw.tween_property(star, "pixel_size", 0.0015, 0.38)
		tw.chain().tween_callback(star.queue_free)


func _pieces_root_for_fx() -> Node:
	return self


## Recoge la estrella de una casilla: sube, crece un poco y desaparece.
func take_goal(s: int) -> void:
	if not _goals.has(s):
		return
	var mi: Node3D = _goals[s]
	_goals.erase(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "position:y", mi.position.y + 0.6, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.5, 0.35)
	tw.chain().tween_callback(mi.queue_free)
	sound.emit("place", 0.6)


## Estrella de cinco puntas con algo de grosor, de pie, para que se vea desde la cámara inclinada.
func _star_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := 0.37
	var inner := 0.16
	var depth := 0.06
	var pts: Array[Vector2] = []
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := PI * 0.5 + TAU * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	for side: float in [-1.0, 1.0]:
		var n := Vector3(0.0, 0.0, side)
		for i in 10:
			var p0 := pts[i]
			var p1 := pts[(i + 1) % 10]
			st.set_normal(n)
			st.add_vertex(Vector3(0.0, 0.0, depth * side))
			if side > 0.0:
				st.add_vertex(Vector3(p0.x, p0.y, depth * 0.4 * side))
				st.add_vertex(Vector3(p1.x, p1.y, depth * 0.4 * side))
			else:
				st.add_vertex(Vector3(p1.x, p1.y, depth * 0.4 * side))
				st.add_vertex(Vector3(p0.x, p0.y, depth * 0.4 * side))
	for i in 10:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % 10]
		var e := (p1 - p0).normalized()
		var n := Vector3(e.y, -e.x, 0.0)
		var a0 := Vector3(p0.x, p0.y, depth * 0.4)
		var a1 := Vector3(p1.x, p1.y, depth * 0.4)
		var b0 := Vector3(p0.x, p0.y, -depth * 0.4)
		var b1 := Vector3(p1.x, p1.y, -depth * 0.4)
		for v: Vector3 in [a0, b0, a1, a1, b0, b1]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


func is_target(s: int) -> bool:
	for m in _targets:
		if Chess.move_to(m) == s:
			return true
	return false


## Jugadas legales de la pieza seleccionada que acaban en la casilla s (varias si hay promoción).
func moves_to(s: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in _targets:
		if Chess.move_to(m) == s:
			out.append(m)
	return out


func select(s: int) -> void:
	var prev := selected
	selected = s
	_targets = PackedInt32Array()
	if s >= 0:
		for m in chess.legal_moves():
			if Chess.move_from(m) == s:
				_targets.append(m)
	for q: int in [prev, s]:
		if q >= 0 and _pieces.has(q):
			var node: Node3D = _pieces[q]
			_rest(node, q)
			_set_glow(node, 1.0 if q == s else 0.0)
	_refresh_state()


func deselect() -> void:
	select(-1)


## La pieza sigue al dedo, levantada, mientras se arrastra.
func drag_piece(s: int, screen_pos: Vector2) -> void:
	if not _pieces.has(s):
		return
	_drag_sq = s
	var o := camera.project_ray_origin(screen_pos)
	var d := camera.project_ray_normal(screen_pos)
	if d.y > -0.0001:
		return
	var hit := o + d * ((0.25 - o.y) / d.y)
	hit.x = clampf(hit.x, -4.4, 4.4)
	hit.z = clampf(hit.z, -4.4, 4.4)
	_pose(_pieces[s], Vector3(hit.x, 0.3, hit.z), Vector3.UP, 0.0, 1.0, 1.06)


## Casilla sobre la que está la pieza arrastrada (−1 si está fuera del tablero).
func drag_square() -> int:
	if _drag_sq < 0 or not _pieces.has(_drag_sq):
		return -1
	var p: Vector3 = (_pieces[_drag_sq] as Node3D).position
	var f := int(floor(p.x + 4.0))
	var r := int(floor(4.0 - p.z))
	if f < 0 or f > 7 or r < 0 or r > 7:
		return -1
	return f + 8 * r


func cancel_drag() -> void:
	if _drag_sq >= 0 and _pieces.has(_drag_sq):
		_rest(_pieces[_drag_sq], _drag_sq)
	_drag_sq = -1


## «Así no»: la pieza niega con un temblor corto.
## Una pieza «intenta» ir a `to` y no puede: da un salto hacia allí, tiembla a medio camino y vuelve a su casilla.
## Para explicar por qué el rey no puede escapar. No cambia la posición.
func try_square(from: int, to: int) -> void:
	if anim_mode == Anim.NONE or not _pieces.has(from):
		return
	var node: Node3D = _pieces[from]
	var a := sq_pos(from)
	var b := a.lerp(sq_pos(to), 0.55)
	var tw := _tw()
	tw.tween_method(func(t: float) -> void:
		_pose(node, a.lerp(b, t) + Vector3(0.0, sin(t * PI) * 0.3, 0.0), Vector3.UP, 0.0), 0.0, 1.0, 0.3)
	tw.tween_method(_pose_shake.bind(node, b), 0.0, 1.0, 0.3)
	tw.tween_method(func(t: float) -> void:
		_pose(node, b.lerp(a, t) + Vector3(0.0, sin(t * PI) * 0.12, 0.0), Vector3.UP, 0.0), 0.0, 1.0, 0.26)


func shake(s: int) -> void:
	if anim_mode == Anim.NONE or anim_mode == Anim.MINIMAL or not _pieces.has(s):
		return
	var tw := _tw()
	tw.tween_method(_pose_shake.bind(_pieces[s], sq_pos(s)), 0.0, 1.0, 0.22)


func _pose_shake(t: float, node: Node3D, pos: Vector3) -> void:
	_pose(node, pos + Vector3(sin(t * TAU * 3.0) * 0.07 * (1.0 - t), 0.0, 0.0), Vector3.UP, 0.0)


# ---------------------------------------------------------------- animaciones

func is_animating() -> bool:
	return _running > 0


func _tw() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	_running += 1
	tw.finished.connect(_on_tween_finished)
	return tw


func _on_tween_finished() -> void:
	_running -= 1
	if _running <= 0:
		_running = 0
		_tweens.clear()
		_settle()


func _kill_tweens() -> void:
	_stop_idle()
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	_running = 0
	for tw in _sfx_tweens:
		if tw.is_valid():
			tw.kill()
	_sfx_tweens.clear()


## Avisa de un sonido ahora o dentro de un rato. Si las animaciones se cortan, los avisos pendientes se pierden.
func _sfx(kind: String, delay: float = 0.0, amount: float = 0.0) -> void:
	if delay <= 0.001:
		sound.emit(kind, amount)
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(sound.emit.bind(kind, amount))
	_sfx_tweens.append(tw)


## Termina de golpe cualquier animación en curso: el tablero queda en su estado final.
func finish_animations() -> void:
	if _running <= 0:
		return
	_kill_tweens()
	_settle()


func _settle() -> void:
	for n in _dying:
		if is_instance_valid(n):
			n.queue_free()
	_dying.clear()
	for s: int in _pieces:
		var node: Node3D = _pieces[s]
		_apply_promotion(node)
		if s != _drag_sq:
			_rest(node, s)
	animations_finished.emit()


func _apply_promotion(node: Node3D) -> void:
	if not node.has_meta("promote_to"):
		return
	var p: int = node.get_meta("promote_to")
	node.remove_meta("promote_to")
	node.set_meta("piece", p)
	node.set_meta("yaw", _yaw_for(p))
	_dress(node)


## Juega una jugada legal: actualiza la posición al instante y anima según el modo.
## Con dropped = true la pieza ya está en su sitio (la soltó el dedo): solo se asienta.
func play_move(m: int, dropped: bool = false) -> void:
	set_badge(-1, "")
	finish_animations()
	_stop_idle()
	var from := Chess.move_from(m)
	var to := Chess.move_to(m)
	var flag := Chess.move_flag(m)
	var promo := Chess.move_promo(m)
	var mover_color := chess.turn
	var mover: Node3D = _pieces.get(from)
	var victim_sq := to
	if flag == Chess.F_EN_PASSANT:
		victim_sq = (to & 7) + 8 * (from >> 3)
	var victim: Node3D = _pieces.get(victim_sq)
	var from_pos := sq_pos(from)
	if dropped and mover != null:
		from_pos = mover.position

	# Estado lógico primero: nada de lo que sigue puede bloquear el juego.
	chess.apply(m)
	if selected >= 0 and _pieces.has(selected):
		_set_glow(_pieces[selected], 0.0)
	selected = -1
	_drag_sq = -1
	_targets = PackedInt32Array()
	last_from = from
	last_to = to
	if victim != null:
		_pieces.erase(victim_sq)
		_dying.append(victim)
	_pieces.erase(from)
	if mover != null:
		_pieces[to] = mover
		if promo > 0:
			mover.set_meta("promote_to", promo + (Chess.BLACK_BIT if mover_color == 1 else 0))
	var rook: Node3D = null
	var rook_from := -1
	var rook_to := -1
	if flag == Chess.F_CASTLE_K:
		rook_from = to + 1
		rook_to = to - 1
	elif flag == Chess.F_CASTLE_Q:
		rook_from = to - 2
		rook_to = to + 1
	if rook_from >= 0:
		rook = _pieces.get(rook_from)
		_pieces.erase(rook_from)
		if rook != null:
			_pieces[rook_to] = rook
	_refresh_state()
	if mover == null:
		_settle()
		return

	var mode := anim_mode
	var check := chess.in_check()
	var mate := check and chess.legal_moves().is_empty()
	var landing := "capture" if victim != null else "place"
	if mode == Anim.NONE or mode == Anim.MINIMAL:
		# Sin animación que acompañar: la pieza se posa y, si toca, suena el jaque o la caída del rey.
		_sfx(landing)
		if mate:
			_mark_fallen_king(to)
			_sfx("fall", 0.12)
		elif check:
			_sfx("check", 0.1)
	if mode == Anim.NONE:
		_settle()
		return
	var a := from_pos
	var b := sq_pos(to)
	var dist := Vector2(b.x - a.x, b.z - a.z).length()
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var kind := Chess.type_of(mover.get_meta("piece"))
	var is_knight := kind == Chess.KNIGHT

	if mode == Anim.MINIMAL:
		var tm := _tw()
		tm.tween_method(_pose_line.bind(mover, a, b), 0.0, 1.0, 0.02 if dropped else 0.1)
		if rook != null:
			var tmr := _tw()
			tmr.tween_method(_pose_line.bind(rook, sq_pos(rook_from), sq_pos(rook_to)), 0.0, 1.0, 0.1)
		return

	var full := mode == Anim.FULL
	if is_rigged():
		_play_rigged(mover, victim, kind, a, b, dir, dist, full, dropped, promo, sq_pos(victim_sq), rook, rook_from, rook_to, check, mate, to)
		return
	var dur := 0.0
	if not dropped:
		dur = clampf(0.26 + 0.035 * dist, 0.28, 0.46) if full else 0.16
		if is_knight and full:
			dur = 0.42
		elif full:
			# Cada pieza tiene su paso: el peón desfila, la torre es pesada, el rey no tiene prisa.
			dur *= float({Chess.PAWN: 1.15, Chess.ROOK: 1.1, Chess.QUEEN: 1.1, Chess.KING: 1.35}.get(kind, 1.0))
	# Sonido: las piezas que se deslizan se oyen arrastrarse hasta que llegan; todas se oyen al posarse.
	if not dropped and not is_knight:
		_sfx("slide", 0.0, dur)
	_sfx(landing, dur + (0.02 if dropped else 0.0))
	var tw := _tw()
	var lively := full and is_standee() and not dropped
	if lively:
		# El recortable mira hacia donde va y coge impulso antes de salir.
		var flat := mover.get_node_or_null("Plano") as Sprite3D
		var across := dir.dot(_cam_right)
		if flat != null and absf(across) > 0.3:
			flat.flip_h = across < 0.0
		tw.tween_method(_pose_land.bind(mover, a, 0.18), 0.0, 1.0, 0.12)
	if dropped:
		tw.tween_method(_pose_line.bind(mover, a, b), 0.0, 1.0, 0.06)
	elif is_knight:
		# El caballo salta dibujando su «L»: primero el tramo largo y luego el corto.
		var corner := Vector3(b.x, 0.0, a.z) if absf(b.x - a.x) > absf(b.z - a.z) else Vector3(a.x, 0.0, b.z)
		tw.tween_method(_pose_jump.bind(mover, a, corner if full else a.lerp(b, 0.5), b, 0.85 if full else 0.4), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif full:
		_walk(tw, mover, kind, a, b, dir, dist, dur)
	else:
		tw.tween_method(_pose_slide.bind(mover, a, b, dir, 0.05, 0.0), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if promo > 0:
		tw.tween_method(_pose_size.bind(mover, b, 1.0, 0.05), 0.0, 1.0, 0.1 if full else 0.05)
		tw.tween_callback(_apply_promotion.bind(mover))
		tw.tween_method(_pose_size.bind(mover, b, 0.05, 1.0), 0.0, 1.0, 0.24 if full else 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var thud := 0.04
		if full:
			thud = 0.16 if kind == Chess.ROOK else (0.12 if kind == Chess.KING or (is_knight and victim != null) else 0.08)
		tw.tween_method(_pose_land.bind(mover, b, thud), 0.0, 1.0, 0.1 if full else 0.06)
		if lively and victim != null:
			# Después de comer, lo celebra con un saltito.
			tw.tween_interval(0.12)
			tw.tween_method(_pose_hop.bind(mover, b, 0.3), 0.0, 1.0, 0.3)
			tw.tween_method(_pose_land.bind(mover, b, 0.1), 0.0, 1.0, 0.1)

	if victim != null:
		var tv := _tw()
		var vpos := sq_pos(victim_sq)
		if full:
			# La pieza comida se asusta cuando ve venir el ataque y cae según quién la ataca.
			var hit := maxf(dur * (0.9 if is_knight else 0.72), 0.01) + (0.12 if lively else 0.0)
			if lively:
				var tb := _tw()
				tb.tween_interval(hit)
				tb.tween_callback(_burst.bind(vpos))
			var fear := minf(hit * 0.5, 0.14)
			tv.tween_interval(hit - fear)
			tv.tween_method(_pose_fear.bind(victim, vpos, dir), 0.0, 1.0, fear)
			_strike(tv, victim, kind, vpos, dir)
		else:
			tv.tween_interval(maxf(dur * 0.4, 0.01))
			tv.tween_method(_pose_size.bind(victim, vpos, 1.0, 0.02), 0.0, 1.0, maxf(dur * 0.6, 0.06))
		tv.tween_callback(_hide.bind(victim))

	if rook != null:
		var tr := _tw()
		var ra := sq_pos(rook_from)
		var rb := sq_pos(rook_to)
		if full:
			tr.tween_interval(maxf(dur * 0.8, 0.01))
			tr.tween_method(_pose_jump.bind(rook, ra, ra.lerp(rb, 0.5), rb, 0.75), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tr.tween_method(_pose_land.bind(rook, rb, 0.07), 0.0, 1.0, 0.09)
			_sfx("place", maxf(dur * 0.8, 0.01) + 0.28)
		else:
			tr.tween_method(_pose_slide.bind(rook, ra, rb, (rb - ra).normalized(), 0.05, 0.0), 0.0, 1.0, maxf(dur, 0.12)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if check:
		var king_sq := chess.king_sq(chess.turn)
		var king: Node3D = _pieces.get(king_sq)
		if king != null:
			var tk := _tw()
			tk.tween_interval(dur + 0.05)
			if mate:
				var axis := _mark_fallen_king(to)
				var fall := 0.7 if full else 0.3
				if is_tokens():
					# La ficha del rey se da la vuelta: queda bocabajo.
					tk.tween_method(_pose_flip.bind(king, sq_pos(king_sq), axis), 0.0, 1.0, fall * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					_sfx("fall", dur + 0.05 + fall * 0.62)
				else:
					tk.tween_method(_pose_topple.bind(king, sq_pos(king_sq), axis), 0.0, 1.0, fall).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
					# El rey toca el tablero por primera vez a un tercio de la caída (primer rebote).
					_sfx("fall", dur + 0.05 + fall * 0.36)
			else:
				_sfx("check", dur + 0.05)
				if full:
					tk.tween_method(_pose_wobble.bind(king, sq_pos(king_sq)), 0.0, 1.0, 0.36)
		elif mate:
			_sfx("fall", dur + 0.1)
		else:
			_sfx("check", dur + 0.05)


## Deja anotado que el rey del bando que mueve ha caído (mate) y hacia dónde: así se queda volcado.
## Devuelve el eje del vuelco.
func _mark_fallen_king(attacker_sq: int) -> Vector3:
	var king_sq := chess.king_sq(chess.turn)
	var away := sq_pos(king_sq) - sq_pos(attacker_sq)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	var axis := Vector3.UP.cross(away)
	var king: Node3D = _pieces.get(king_sq)
	if king != null:
		king.set_meta("topple_axis", axis)
		king.set_meta("topple", PI if is_tokens() else 1.5)
		king.set_meta("topple_lift", TOKEN["height"] if is_tokens() else 0.0)
	return axis


func _hide(node: Node3D) -> void:
	if is_instance_valid(node):
		node.visible = false


## Jugada con personajes articulados: andan hasta su casilla mirando hacia donde van; al comer, atacan con su arma
## (el mago lanza un hechizo desde lejos) y la otra pieza recibe el golpe y cae; con jaque el rey se cubre y con
## mate cae al suelo.
func _play_rigged(mover: Node3D, victim: Node3D, kind: int, a: Vector3, b: Vector3, dir: Vector3, dist: float, full: bool, dropped: bool, promo: int, vpos: Vector3, rook: Node3D, rook_from: int, rook_to: int, check: bool, mate: bool, to: int) -> void:
	var cfg: Dictionary = RIG[kind]
	var side := Chess.color_of(mover.get_meta("piece"))
	var walk := str(cfg["walk"])
	var pace: float = cfg["pace"]
	var quick := 1.0 if full else 2.2
	var jumper := kind == Chess.KNIGHT
	var tw := _tw()
	var t := 0.0
	var landing := "capture" if victim != null else "place"
	if dropped:
		tw.tween_method(_pose_line.bind(mover, a, b), 0.0, 1.0, 0.06)
		t = 0.06
		if victim != null:
			_hide(victim)
	else:
		var stop := b
		var ranged := bool(cfg.get("ranged", false))
		if victim != null:
			# Los de cuerpo a cuerpo se paran a un paso de la pieza; el mago ataca desde donde está.
			var gap := (b - a).normalized() * minf(0.8, dist * 0.6)
			stop = a if ranged else b - gap
		var first := Vector2(stop.x - a.x, stop.z - a.z).length()
		tw.tween_callback(_face_dir.bind(mover, dir))
		if first > 0.05:
			var d1 := _rig_walk(tw, mover, a, stop, first, walk, pace, jumper, quick)
			t += d1
		if victim != null:
			var attack := str(cfg["attack"])
			var swing := _fig_len(mover, attack) / (1.25 * quick)
			var hit := swing * (0.62 if ranged else 0.45)
			tw.tween_callback(_fig_play.bind(mover, attack, 1.25 * quick))
			if ranged:
				tw.tween_interval(hit * 0.75)
				tw.tween_callback(_spell.bind(a, vpos, hit * 0.4))
				tw.tween_interval(swing - hit * 0.75)
			else:
				tw.tween_interval(swing)
			# La pieza comida mira a quien la ataca, recibe el golpe, cae y desaparece.
			var tv := _tw()
			var fall := _fig_len(victim, "Death_A") / (1.3 * quick)
			tv.tween_interval(maxf(t - 0.25, 0.0))
			tv.tween_callback(_face_dir.bind(victim, -dir))
			tv.tween_interval(t + hit - maxf(t - 0.25, 0.0))
			tv.tween_callback(_fig_play.bind(victim, "Death_A", 1.3 * quick))
			tv.tween_callback(_burst.bind(vpos))
			tv.tween_interval(fall)
			tv.tween_method(_pose_size.bind(victim, vpos, 1.0, 0.02), 0.0, 1.0, 0.18)
			tv.tween_callback(_hide.bind(victim))
			_sfx("capture", t + hit)
			t += swing
			var rest := Vector2(b.x - stop.x, b.z - stop.z).length()
			t += _rig_walk(tw, mover, stop, b, rest, walk if not jumper else "Walking_A", pace, false, quick)
		_sfx("place", t)
	if promo > 0:
		tw.tween_method(_pose_size.bind(mover, b, 1.0, 0.05), 0.0, 1.0, 0.1)
		tw.tween_callback(_apply_promotion.bind(mover))
		tw.tween_method(_pose_size.bind(mover, b, 0.05, 1.0), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t += 0.34
	# Al llegar: vuelve a mirar al rival y, si ha comido, lo celebra.
	tw.tween_callback(_face.bind(mover, _forward_yaw(side)))
	if victim != null and full and not dropped:
		tw.tween_callback(_fig_play.bind(mover, "Cheer", 1.4))
		tw.tween_callback(_fig_then_idle.bind(mover))
	else:
		tw.tween_callback(_fig_play.bind(mover, "Idle"))
	if dropped and victim == null:
		_sfx(landing)

	if rook != null:
		var tr := _tw()
		var ra := sq_pos(rook_from)
		var rb := sq_pos(rook_to)
		tr.tween_interval(t * 0.5)
		tr.tween_callback(_face_dir.bind(rook, (rb - ra).normalized()))
		_rig_walk(tr, rook, ra, rb, (rb - ra).length(), "Walking_C", 1.6, false, quick)
		tr.tween_callback(_face.bind(rook, _forward_yaw(side)))
		tr.tween_callback(_fig_play.bind(rook, "Idle"))

	if check:
		var king_sq := chess.king_sq(chess.turn)
		var king: Node3D = _pieces.get(king_sq)
		if mate:
			_mark_fallen_king(to)
			_sfx("fall", t + 0.45)
		else:
			_sfx("check", t + 0.05)
		if king != null:
			var tk := _tw()
			tk.tween_interval(t + 0.05)
			tk.tween_callback(_face_dir.bind(king, b - sq_pos(king_sq)))
			if mate:
				tk.tween_callback(_fig_play.bind(king, "Death_B", 1.0))
				tk.tween_interval(_fig_len(king, "Death_B"))
			else:
				tk.tween_callback(_fig_play.bind(king, "Block", 1.0))
				tk.tween_interval(_fig_len(king, "Block"))
				tk.tween_callback(_face.bind(king, _forward_yaw(1 - side)))
				tk.tween_callback(_fig_play.bind(king, "Idle"))


## Un tramo andando (o saltando, el caballo). Devuelve lo que dura.
func _rig_walk(tw: Tween, node: Node3D, from_pos: Vector3, to_pos: Vector3, length: float, walk: String, pace: float, jump: bool, quick: float) -> float:
	if length < 0.02:
		return 0.0
	var seconds := 0.0
	if jump:
		seconds = _fig_len(node, walk) / (1.5 * quick)
		tw.tween_callback(_fig_play.bind(node, walk, 1.5 * quick))
		tw.tween_method(_pose_jump.bind(node, from_pos, from_pos.lerp(to_pos, 0.5), to_pos, 0.55), 0.0, 1.0, seconds * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(seconds * 0.2)
	else:
		# Unas 2,6 casillas por segundo, con un mínimo para que se vean los pasos.
		seconds = clampf(length / (2.6 * pace), 0.3, 1.5) / quick
		tw.tween_callback(_fig_play.bind(node, walk, pace * quick))
		tw.tween_method(_pose_line.bind(node, from_pos, to_pos), 0.0, 1.0, seconds)
	return seconds


## El paso de cada pieza (animaciones completas): cada una se mueve con su carácter.
func _walk(tw: Tween, mover: Node3D, kind: int, a: Vector3, b: Vector3, dir: Vector3, dist: float, dur: float) -> void:
	match kind:
		Chess.PAWN:
			# El peón desfila: pasitos cortos, balanceándose de un pie a otro.
			tw.tween_method(_pose_march.bind(mover, a, b, dir, maxi(2, roundi(dist * 2.0)), 0.07, 0.13), 0.0, 1.0, dur).set_trans(Tween.TRANS_LINEAR)
		Chess.BISHOP:
			# El alfil se desliza inclinado hacia delante, con un vaivén de esquiador.
			tw.tween_method(_pose_glide.bind(mover, a, b, dir, 0.05 * minf(dist, 3.0) / 3.0 + 0.02), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		Chess.ROOK:
			# La torre rueda pesada, a ras de tablero y temblando; frena en seco.
			tw.tween_method(_pose_rumble.bind(mover, a, b, dir, maxf(dist, 1.0)), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Chess.QUEEN:
			# La dama avanza girando sobre sí misma, elegante.
			tw.tween_method(_pose_twirl.bind(mover, a, b), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		Chess.KING:
			# El rey camina despacio, con dos pasos solemnes.
			tw.tween_method(_pose_march.bind(mover, a, b, dir, 2, 0.05, 0.09), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			tw.tween_method(_pose_slide.bind(mover, a, b, dir, 0.16, 0.15), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Cómo cae la pieza comida, según quién la ataca.
func _strike(tv: Tween, victim: Node3D, attacker: int, vpos: Vector3, dir: Vector3) -> void:
	var side := Vector3.UP.cross(dir)
	match attacker:
		Chess.KNIGHT:
			# El caballo cae encima: la aplasta.
			tv.tween_method(_pose_crush.bind(victim, vpos), 0.0, 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Chess.ROOK:
			# La torre embiste: sale despedida lejos, dando vueltas.
			tv.tween_method(_pose_fling.bind(victim, vpos, dir, 1.5, 0.45, 3.0), 0.0, 1.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Chess.BISHOP:
			# El alfil la corta de lado: cae hacia un costado.
			tv.tween_method(_pose_fling.bind(victim, vpos, (dir + side * 1.2).normalized(), 0.6, 0.2, 1.6), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Chess.QUEEN:
			# La dama la hace girar como una peonza hasta desaparecer.
			tv.tween_method(_pose_spin_out.bind(victim, vpos), 0.0, 1.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Chess.KING:
			# Ante el rey, se inclina y se retira.
			tv.tween_method(_pose_bow.bind(victim, vpos, dir), 0.0, 1.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			# El peón da un empujón.
			tv.tween_method(_pose_knock.bind(victim, vpos, dir), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _pose_march(t: float, node: Node3D, a: Vector3, b: Vector3, dir: Vector3, steps: int, hop: float, sway: float) -> void:
	var beat := sin(PI * float(steps) * t)
	var foot := 1.0 if int(floor(float(steps) * minf(t, 0.999))) % 2 == 0 else -1.0
	_pose(node, a.lerp(b, t) + Vector3(0.0, hop * absf(beat), 0.0), dir, sway * absf(beat) * foot)


func _pose_glide(t: float, node: Node3D, a: Vector3, b: Vector3, dir: Vector3, weave: float) -> void:
	var side := Vector3.UP.cross(dir)
	var env := sin(PI * t)
	_pose(node, a.lerp(b, t) + side * (weave * sin(TAU * 1.5 * t) * env) + Vector3(0.0, 0.05 * env, 0.0), side, 0.24 * env)


func _pose_rumble(t: float, node: Node3D, a: Vector3, b: Vector3, dir: Vector3, dist: float) -> void:
	var shake := 0.014 * sin(t * dist * 26.0) * sin(PI * t)
	_pose(node, a.lerp(b, t) + Vector3(0.0, absf(shake), 0.0), Vector3.UP.cross(dir), -0.06 * sin(PI * t) + shake)


func _pose_twirl(t: float, node: Node3D, a: Vector3, b: Vector3) -> void:
	_pose(node, a.lerp(b, t) + Vector3(0.0, 0.12 * sin(PI * t), 0.0), Vector3.UP, TAU * t, 1.0 + 0.04 * sin(PI * t))


func _pose_fear(t: float, node: Node3D, pos: Vector3, dir: Vector3) -> void:
	# Se echa hacia atrás y tiembla.
	_pose(node, pos + Vector3(0.0, 0.02 * absf(sin(t * TAU * 2.0)), 0.0), Vector3.UP.cross(dir), 0.16 * t, 1.0 - 0.06 * t)


func _pose_crush(t: float, node: Node3D, pos: Vector3) -> void:
	_pose(node, pos, Vector3.UP, 0.0, lerpf(1.0, 0.06, t), 1.0 - 0.3 * t * t)


func _pose_fling(t: float, node: Node3D, pos: Vector3, dir: Vector3, far: float, high: float, turns: float) -> void:
	_pose(node, pos + dir * (far * t) + Vector3(0.0, high * sin(PI * t), 0.0), Vector3.UP.cross(dir), turns * TAU * 0.5 * t, 1.0, 1.0 - t * t)


func _pose_spin_out(t: float, node: Node3D, pos: Vector3) -> void:
	_pose(node, pos + Vector3(0.0, 0.25 * t, 0.0), Vector3.UP, TAU * 2.0 * t, 1.0 + 0.3 * t, 1.0 - t)


func _pose_bow(t: float, node: Node3D, pos: Vector3, dir: Vector3) -> void:
	var bow := sin(PI * minf(t * 2.0, 1.0))
	var leave := clampf(t * 2.0 - 1.0, 0.0, 1.0)
	_pose(node, pos + dir * (0.5 * leave), Vector3.UP.cross(dir), -0.5 * bow, 1.0, 1.0 - leave)


func _pose_line(t: float, node: Node3D, a: Vector3, b: Vector3) -> void:
	_pose(node, a.lerp(b, t), Vector3.UP, 0.0)


func _pose_slide(t: float, node: Node3D, a: Vector3, b: Vector3, dir: Vector3, lift: float, lean: float) -> void:
	# Se inclina hacia delante al arrancar y hacia atrás al frenar.
	var axis := Vector3.UP.cross(dir)
	_pose(node, a.lerp(b, t) + Vector3(0.0, lift * sin(PI * t), 0.0), axis, lean * sin(TAU * t))


func _pose_jump(t: float, node: Node3D, a: Vector3, corner: Vector3, b: Vector3, height: float) -> void:
	var k := 0.62
	var p := a.lerp(corner, t / k) if t < k else corner.lerp(b, (t - k) / (1.0 - k))
	_pose(node, p + Vector3(0.0, height * sin(PI * t), 0.0), Vector3.UP, 0.0, 1.0 + 0.06 * sin(PI * t))


func _pose_land(t: float, node: Node3D, pos: Vector3, amount: float) -> void:
	_pose(node, pos, Vector3.UP, 0.0, 1.0 - amount * sin(PI * t))


func _pose_size(t: float, node: Node3D, pos: Vector3, s0: float, s1: float) -> void:
	_pose(node, pos, Vector3.UP, 0.0, 1.0, lerpf(s0, s1, t))


func _pose_knock(t: float, node: Node3D, pos: Vector3, dir: Vector3) -> void:
	var axis := Vector3.UP.cross(dir)
	_pose(node, pos + dir * (0.5 * t) + Vector3(0.0, 0.28 * sin(PI * t), 0.0), axis, 1.5 * t, 1.0, 1.0 - t * t)


func _pose_wobble(t: float, node: Node3D, pos: Vector3) -> void:
	_pose(node, pos, Vector3.FORWARD, 0.13 * sin(t * TAU * 3.0) * (1.0 - t))


func _pose_topple(t: float, node: Node3D, pos: Vector3, axis: Vector3) -> void:
	_pose(node, pos, axis, 1.5 * t)


## Vuelco de una ficha: salta, gira media vuelta y cae bocabajo.
func _pose_flip(t: float, node: Node3D, pos: Vector3, axis: Vector3) -> void:
	var h: float = TOKEN["height"]
	_pose(node, pos + Vector3(0.0, h * t + 0.5 * sin(PI * t), 0.0), axis, PI * t)
