class_name Board3D
extends Node3D
## Mundo 3D del tablero: piezas de una colección, luz, cámara, marcadores y animaciones.
## No decide nada de ajedrez por su cuenta: usa Chess (core/chess.gd) para las reglas.
##
## Coordenadas: 1 unidad = 1 casilla. La columna «a» está en x = −3,5 y la fila 1 en z = +3,5
## (las blancas quedan hacia +Z, que es donde se pone la cámara cuando juegan blancas).

signal animations_finished

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
const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const PITCH_MIN := 36.0
const PITCH_MAX := 90.0
## Ampliación máxima con el pellizco de dos dedos (1 = el tablero encuadrado a lo ancho).
const ZOOM_MAX := 3.0
const DEFAULT_PITCH := 64.0

var chess: Chess = Chess.from_fen(START_FEN)
## 0 = blancas abajo, 1 = negras abajo.
var orientation := 0
var anim_mode: Anim = Anim.FAST
var set_id := "clasico"
var show_coordinates := true
## Acabado: "realista" (maderas con textura fotográfica y reflejos de estudio) o "ilustrado" (porcelana lisa).
var style := "realista"
## Contorno de tinta alrededor de las piezas (ver set_style y set_outline).
var outline := false

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
var _wood_mats: Array[ShaderMaterial] = []
var _squares_wood: ShaderMaterial
var _frame_wood: ShaderMaterial
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
	# Materiales del acabado realista: taracea de arce y nogal, marco de palisandro, piezas de boj y de ébano.
	_squares_wood = ShaderMaterial.new()
	_squares_wood.shader = load("res://board3d/shaders/squares_wood.gdshader") as Shader
	_squares_wood.set_shader_parameter("state", _state_tex)
	_squares_wood.set_shader_parameter("light_wood", _texture("arce"))
	_squares_wood.set_shader_parameter("light_normal", _texture("arce_normal"))
	_squares_wood.set_shader_parameter("dark_wood", _texture("nogal"))
	_squares_wood.set_shader_parameter("dark_normal", _texture("nogal_normal"))
	_frame_wood = ShaderMaterial.new()
	_frame_wood.shader = load("res://board3d/shaders/frame_wood.gdshader") as Shader
	_frame_wood.set_shader_parameter("wood", _texture("palisandro"))

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
	_pieces_root = Node3D.new()
	add_child(_pieces_root)

	var piece_shader := load("res://board3d/shaders/piece.gdshader") as Shader
	var outline_shader := load("res://board3d/shaders/outline.gdshader") as Shader
	var disc_shader := load("res://board3d/shaders/outline_disc.gdshader") as Shader
	var wood_shader := load("res://board3d/shaders/piece_wood.gdshader") as Shader
	for side in 2:
		var m := ShaderMaterial.new()
		m.shader = piece_shader
		_mats.append(m)
		var wm := ShaderMaterial.new()
		wm.shader = wood_shader
		wm.set_shader_parameter("wood", _texture("boj" if side == 0 else "ebano"))
		_wood_mats.append(wm)
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
	_built = true


static func _texture(texture_name: String) -> Texture2D:
	var path := "res://textures/%s.jpg" % texture_name
	if not ResourceLoader.exists(path):
		push_error("Falta la textura " + path)
		return null
	return load(path) as Texture2D


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


## Cambia el acabado: "realista" o "ilustrado". El contorno de tinta va con el ilustrado, salvo que se indique.
func set_style(style_name: String, with_outline: Variant = null) -> void:
	style = style_name if style_name in ["realista", "ilustrado"] else "realista"
	outline = (style == "ilustrado") if with_outline == null else bool(with_outline)
	if not _built:
		return
	_apply_style()
	set_theme(_theme_name)


## Contorno de tinta alrededor de las piezas, en cualquiera de los dos acabados.
func set_outline(on: bool) -> void:
	outline = on
	if not _built:
		return
	for node: Node3D in _pieces.values():
		_dress(node)
	for node: Node3D in _dying:
		if is_instance_valid(node):
			_dress(node)


func _piece_material(side: int) -> ShaderMaterial:
	return _wood_mats[side] if style == "realista" else _mats[side]


## Pone a una pieza el material del acabado y enseña u oculta su contorno.
func _dress(node: Node3D) -> void:
	var side := Chess.color_of(node.get_meta("piece"))
	(node.get_node("Malla") as MeshInstance3D).material_override = _piece_material(side)
	(node.get_node("Contorno") as MeshInstance3D).visible = outline
	(node.get_node("Peana") as MeshInstance3D).visible = outline


func _apply_style() -> void:
	var real := style == "realista"
	_squares_node.material_override = _squares_wood if real else _squares_mat
	_frame_node.material_override = _frame_wood if real else _frame_mat
	# El acabado realista se ilumina con el entorno de estudio (luz ambiente y reflejos); el ilustrado, con un
	# color de ambiente liso y sin reflejos.
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
	if style == "realista":
		# Estudio: luz principal cálida con sombra, ambiente y reflejos del entorno, y una contra suave.
		_env.ambient_light_sky_contribution = 1.0
		_env.ambient_light_energy = 0.62
		_sky_mat.set_shader_parameter("intensity", 1.0)
		_key.light_color = Color("fff1dc")
		_key.light_energy = 1.0
		_fill.light_energy = 0.0
		_rim_light.light_color = Color("dfe9ff")
		_rim_light.light_energy = 0.3
		_squares_wood.set_shader_parameter("light_tint", Color(1.0, 0.98, 0.94))
		_squares_wood.set_shader_parameter("dark_tint", Color(0.78, 0.7, 0.64))
		_frame_wood.set_shader_parameter("tint", Color(0.62, 0.56, 0.54))
		# Boj claro y ébano casi negro: los brillos del barniz son los que dibujan el volumen de las oscuras.
		_wood_mats[0].set_shader_parameter("tint", Color(1.08, 1.02, 0.9))
		_wood_mats[0].set_shader_parameter("rough", 0.36)
		_wood_mats[0].set_shader_parameter("rim_amount", 0.0)
		_wood_mats[1].set_shader_parameter("tint", Color(0.34, 0.31, 0.3))
		_wood_mats[1].set_shader_parameter("rough", 0.27)
		_wood_mats[1].set_shader_parameter("rim_color", Color("c9d6f2"))
		_wood_mats[1].set_shader_parameter("rim_amount", 0.14)
		outline_colors = [Color("2b1a10"), Color("050302")]
		light_label = Color("f6e9cf")
		dark_label = Color("5b3d27")
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
	var mesh: Mesh = _meshes[Chess.type_of(p)]
	var side := Chess.color_of(p)
	var mi := MeshInstance3D.new()
	mi.name = "Malla"
	mi.mesh = mesh
	mi.material_override = _piece_material(side)
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


## Selección: el contorno de la pieza se vuelve del color de acento.
func _set_glow(node: Node3D, amount: float) -> void:
	for part: String in ["Malla", "Contorno", "Peana"]:
		(node.get_node(part) as MeshInstance3D).set_instance_shader_parameter("glow", amount)


## Deja la pieza en reposo en su casilla.
func _rest(node: Node3D, s: int) -> void:
	var lift := 0.1 if s == selected else 0.0
	_pose(node, sq_pos(s) + Vector3(0.0, lift, 0.0), Vector3.UP, 0.0)
	var topple: float = node.get_meta("topple", 0.0)
	if topple != 0.0:
		_pose(node, sq_pos(s), node.get_meta("topple_axis", Vector3.RIGHT), topple)


func _pose(node: Node3D, pos: Vector3, axis: Vector3, angle: float, squash: float = 1.0, size: float = 1.0) -> void:
	if not is_instance_valid(node):
		return
	var yaw: float = node.get_meta("yaw", 0.0)
	var bas := Basis(Vector3.UP, yaw)
	if absf(angle) > 0.0001 and axis.length_squared() > 0.25:
		bas = Basis(axis.normalized(), angle) * bas
	var sc := PIECE_SCALE * maxf(size, 0.001)
	var wide := sc * PIECE_GIRTH / sqrt(maxf(squash, 0.05))
	node.transform = Transform3D(bas * Basis.from_scale(Vector3(wide, sc * squash, wide)), pos)


func set_fen(fen: String) -> void:
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


## Marca una jugada como la última sin moverla: para recuperar el resaltado al volver a una posición anterior.
func mark_last_move(from: int, to: int) -> void:
	last_from = from
	last_to = to
	if _built:
		_refresh_state()


## Flechas de las explicaciones: lista de diccionarios {from: int, to: int, tone: "good" | "bad" | "info"}.
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
	for ix: int in [-1, 1]:
		for iz: int in [-1, 1]:
			var fx := float(ix)
			var fz := float(iz)
			for q: Vector3 in [Vector3(fx * FRAME_HALF, 0.0, fz * FRAME_HALF), Vector3(fx * FRAME_HALF, -FRAME_THICK, fz * FRAME_HALF), Vector3(fx * 3.5, FIT_HEIGHT, fz * 3.5)]:
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
	for s: int in _pieces:
		var node: Node3D = _pieces[s]
		var c := sq_pos(s)
		var h: float = PIECE_HEIGHT[Chess.type_of(node.get_meta("piece"))] * PIECE_SCALE
		var ox := o.x - c.x
		var oz := o.z - c.z
		var qa := d.x * d.x + d.z * d.z
		var t := INF
		if qa > 1e-9:
			var qb := 2.0 * (ox * d.x + oz * d.z)
			var qc := ox * ox + oz * oz - PICK_RADIUS * PICK_RADIUS
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
			if tt > 0.0 and px * px + pz * pz <= PICK_RADIUS * PICK_RADIUS:
				t = tt
		if t < best:
			best = t
			piece_sq = s
	return Vector2i(plane_sq, piece_sq)


func is_own(s: int) -> bool:
	return s >= 0 and chess.b[s] != 0 and Chess.color_of(chess.b[s]) == chess.turn


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
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	_running = 0


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
	var mesh: Mesh = _meshes[Chess.type_of(p)]
	(node.get_node("Malla") as MeshInstance3D).mesh = mesh
	(node.get_node("Contorno") as MeshInstance3D).mesh = mesh
	_fit_disc(node, mesh)


## Juega una jugada legal: actualiza la posición al instante y anima según el modo.
## Con dropped = true la pieza ya está en su sitio (la soltó el dedo): solo se asienta.
func play_move(m: int, dropped: bool = false) -> void:
	finish_animations()
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
	if mode == Anim.NONE:
		_settle()
		return
	var a := from_pos
	var b := sq_pos(to)
	var dist := Vector2(b.x - a.x, b.z - a.z).length()
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var is_knight := Chess.type_of(mover.get_meta("piece")) == Chess.KNIGHT
	var check := chess.in_check()
	var mate := check and chess.legal_moves().is_empty()

	if mode == Anim.MINIMAL:
		var tm := _tw()
		tm.tween_method(_pose_line.bind(mover, a, b), 0.0, 1.0, 0.02 if dropped else 0.1)
		if rook != null:
			var tmr := _tw()
			tmr.tween_method(_pose_line.bind(rook, sq_pos(rook_from), sq_pos(rook_to)), 0.0, 1.0, 0.1)
		return

	var full := mode == Anim.FULL
	var dur := 0.0
	if not dropped:
		dur = clampf(0.26 + 0.035 * dist, 0.28, 0.46) if full else 0.16
		if is_knight and full:
			dur = 0.42
	var tw := _tw()
	if dropped:
		tw.tween_method(_pose_line.bind(mover, a, b), 0.0, 1.0, 0.06)
	elif is_knight:
		# El caballo salta dibujando su «L»: primero el tramo largo y luego el corto.
		var corner := Vector3(b.x, 0.0, a.z) if absf(b.x - a.x) > absf(b.z - a.z) else Vector3(a.x, 0.0, b.z)
		tw.tween_method(_pose_jump.bind(mover, a, corner if full else a.lerp(b, 0.5), b, 0.85 if full else 0.4), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tw.tween_method(_pose_slide.bind(mover, a, b, dir, 0.16 if full else 0.05, 0.15 if full else 0.0), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if promo > 0:
		tw.tween_method(_pose_size.bind(mover, b, 1.0, 0.05), 0.0, 1.0, 0.1 if full else 0.05)
		tw.tween_callback(_apply_promotion.bind(mover))
		tw.tween_method(_pose_size.bind(mover, b, 0.05, 1.0), 0.0, 1.0, 0.24 if full else 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_method(_pose_land.bind(mover, b, 0.08 if full else 0.04), 0.0, 1.0, 0.1 if full else 0.06)

	if victim != null:
		var tv := _tw()
		var vpos := sq_pos(victim_sq)
		if full:
			tv.tween_interval(maxf(dur * 0.72, 0.01))
			tv.tween_method(_pose_knock.bind(victim, vpos, dir), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
		else:
			tr.tween_method(_pose_slide.bind(rook, ra, rb, (rb - ra).normalized(), 0.05, 0.0), 0.0, 1.0, maxf(dur, 0.12)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if check:
		var king_sq := chess.king_sq(chess.turn)
		var king: Node3D = _pieces.get(king_sq)
		if king != null:
			var tk := _tw()
			tk.tween_interval(dur + 0.05)
			if mate:
				var away := sq_pos(king_sq) - b
				away.y = 0.0
				away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
				var axis := Vector3.UP.cross(away)
				king.set_meta("topple_axis", axis)
				king.set_meta("topple", 1.5)
				tk.tween_method(_pose_topple.bind(king, sq_pos(king_sq), axis), 0.0, 1.0, 0.7 if full else 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			elif full:
				tk.tween_method(_pose_wobble.bind(king, sq_pos(king_sq)), 0.0, 1.0, 0.36)


func _hide(node: Node3D) -> void:
	if is_instance_valid(node):
		node.visible = false


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
