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
const PIECE_SCALE := 0.94
const PICK_RADIUS := 0.34
const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const PITCH_MIN := 36.0
const PITCH_MAX := 90.0
const DEFAULT_PITCH := 58.0

var chess: Chess = Chess.from_fen(START_FEN)
## 0 = blancas abajo, 1 = negras abajo.
var orientation := 0
var anim_mode: Anim = Anim.FAST
var set_id := "clasico"
var show_coordinates := true

var camera: Camera3D
var cam_pitch := DEFAULT_PITCH
var cam_yaw := 0.0
var cam_fov := 26.0

var last_from := -1
var last_to := -1
var selected := -1

var _targets := PackedInt32Array()
var _pieces := {}
var _meshes := {}
var _mats: Array[ShaderMaterial] = []
var _squares_mat: ShaderMaterial
var _frame_mat: StandardMaterial3D
var _backdrop_mat: ShaderMaterial
var _shadow_mat: ShaderMaterial
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
var _drag_sq := -1
var _built := false


func _ready() -> void:
	_build()
	set_theme(_theme_name)
	set_fen(chess.fen())
	set_orientation(orientation)


# ---------------------------------------------------------------- construcción

func _build() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_light_rig = Node3D.new()
	add_child(_light_rig)
	_key = DirectionalLight3D.new()
	_key.rotation = Vector3(deg_to_rad(-56.0), deg_to_rad(-34.0), 0.0)
	_key.shadow_enabled = true
	_key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_key.directional_shadow_max_distance = 42.0
	_key.shadow_blur = 1.6
	_key.light_angular_distance = 1.0
	_light_rig.add_child(_key)
	_fill = DirectionalLight3D.new()
	_fill.rotation = Vector3(deg_to_rad(-32.0), deg_to_rad(138.0), 0.0)
	_fill.shadow_enabled = false
	_light_rig.add_child(_fill)

	camera = Camera3D.new()
	camera.fov = cam_fov
	camera.near = 0.5
	camera.far = 120.0
	add_child(camera)
	camera.make_current()

	# Fondo: un plano lejano pegado a la cámara.
	var quad := QuadMesh.new()
	quad.size = Vector2(60.0, 60.0)
	var backdrop := MeshInstance3D.new()
	backdrop.mesh = quad
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = load("res://board3d/shaders/backdrop.gdshader") as Shader
	backdrop.material_override = _backdrop_mat
	backdrop.position = Vector3(0.0, 0.0, -100.0)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(backdrop)

	# Sombra de contacto.
	var shadow_plane := PlaneMesh.new()
	shadow_plane.size = Vector2(15.0, 15.0)
	var shadow := MeshInstance3D.new()
	shadow.mesh = shadow_plane
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = load("res://board3d/shaders/soft_shadow.gdshader") as Shader
	shadow.material_override = _shadow_mat
	shadow.position = Vector3(0.0, -0.43, 0.0)
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

	# Coordenadas: un juego para cada lado, se enseña el del lado que juega abajo.
	for side in 2:
		var group := Node3D.new()
		var sgn := 1.0 if side == 0 else -1.0
		var yaw := 0.0 if side == 0 else PI
		for i in 8:
			group.add_child(_make_label("abcdefgh"[i], Vector3(i - 3.5, 0.012, 4.26 * sgn), yaw))
			group.add_child(_make_label(str(i + 1), Vector3(-4.26 * sgn, 0.012, 3.5 - i), yaw))
		add_child(group)
		_labels.append(group)

	_arrows_root = Node3D.new()
	add_child(_arrows_root)
	_pieces_root = Node3D.new()
	add_child(_pieces_root)

	var piece_shader := load("res://board3d/shaders/piece.gdshader") as Shader
	for side in 2:
		var m := ShaderMaterial.new()
		m.shader = piece_shader
		_mats.append(m)
	for t: int in PIECE_FILES:
		_meshes[t] = _load_mesh("res://sets/%s/%s.glb" % [set_id, PIECE_FILES[t]])
	_built = true


func _make_label(text: String, pos: Vector3, yaw: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 44
	l.pixel_size = 0.0046
	l.outline_size = 0
	l.shaded = false
	l.position = pos
	l.rotation = Vector3(-PI / 2.0, yaw, 0.0)
	return l


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

func set_theme(theme_name: String) -> void:
	_theme_name = theme_name
	if not _built:
		return
	var dark := theme_name == "dark"
	_env.background_color = Color("0c1224") if dark else Color("e6eef9")
	_env.ambient_light_color = Color("aebbe0") if dark else Color("dfe8f6")
	_env.ambient_light_energy = 0.42 if dark else 0.62
	_key.light_color = Color("fff0dc") if dark else Color("fff5e6")
	_key.light_energy = 1.0 if dark else 1.05
	_fill.light_color = Color("9db4ff") if dark else Color("cfe0ff")
	_fill.light_energy = 0.22 if dark else 0.28
	_backdrop_mat.set_shader_parameter("top_color", Color("0b1020") if dark else Color("f4f8ff"))
	_backdrop_mat.set_shader_parameter("bottom_color", Color("141d38") if dark else Color("dce8f7"))
	_backdrop_mat.set_shader_parameter("halo_color", Color("2b3a6b") if dark else Color("ffffff"))
	_backdrop_mat.set_shader_parameter("halo", 0.55 if dark else 0.4)
	_shadow_mat.set_shader_parameter("shadow_color", Color("02040c") if dark else Color("1f2d55"))
	_shadow_mat.set_shader_parameter("strength", 0.55 if dark else 0.32)
	_frame_mat.albedo_color = Color("222d4d") if dark else Color("2b3859")
	_squares_mat.set_shader_parameter("light_sq", Color("d3deef") if dark else Color("e8eff8"))
	_squares_mat.set_shader_parameter("dark_sq", Color("7d94b8") if dark else Color("8ea5c8"))
	# Claras: marfil con el borde algo más oscuro. Oscuras: azul tinta con el borde más claro.
	_mats[0].set_shader_parameter("base_color", Color("f3ebdc"))
	_mats[0].set_shader_parameter("rim_color", Color("a3927a"))
	_mats[0].set_shader_parameter("rim_amount", 0.42)
	_mats[1].set_shader_parameter("base_color", Color("2a3554"))
	_mats[1].set_shader_parameter("rim_color", Color("8ea4d2"))
	_mats[1].set_shader_parameter("rim_amount", 0.5)
	var label_color := Color("93a4c8") if dark else Color("aebcd8")
	for group in _labels:
		for l in group.get_children():
			(l as Label3D).modulate = label_color


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
	var mi := MeshInstance3D.new()
	mi.name = "Malla"
	mi.mesh = _meshes[Chess.type_of(p)]
	mi.material_override = _mats[Chess.color_of(p)]
	node.add_child(mi)
	node.set_meta("piece", p)
	node.set_meta("yaw", _yaw_for(p))
	_pieces_root.add_child(node)
	_rest(node, s)
	return node


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
	var wide := sc / sqrt(maxf(squash, 0.05))
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
		_state_img.set_pixel(s & 7, s >> 3, Color8(hi[s], mark[s], 0, 255))
	_state_tex.update(_state_img)


## Flechas de las explicaciones: lista de diccionarios {from: int, to: int, tone: "good" | "bad" | "info"}.
func set_arrows(arrows: Array) -> void:
	for n in _arrows_root.get_children():
		_arrows_root.remove_child(n)
		n.queue_free()
	for a: Dictionary in arrows:
		var tone: String = a.get("tone", "info")
		var color := Color("1f9a52") if tone == "good" else (Color("e5484d") if tone == "bad" else Color("7c5cfa"))
		var mi := MeshInstance3D.new()
		mi.mesh = _arrow_mesh(sq_pos(int(a["from"])), sq_pos(int(a["to"])))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(color.r, color.g, color.b, 0.86)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, 0.014, 0.0)
		_arrows_root.add_child(mi)


func _arrow_mesh(a: Vector3, b: Vector3) -> ArrayMesh:
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var start := a + dir * 0.3
	var tip := b + dir * 0.1
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
	if camera == null:
		return
	var yaw := deg_to_rad(cam_yaw + (180.0 if orientation == 1 else 0.0))
	var pitch := deg_to_rad(clampf(cam_pitch, PITCH_MIN, PITCH_MAX))
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var up := back.cross(right)
	# Distancia para que el tablero con su marco quepa a lo ancho en el borde más cercano.
	var half := tan(deg_to_rad(cam_fov) * 0.5)
	var dist := 4.85 / half + 4.5 * cos(pitch)
	# El punto de mira baja un poco con la cámara inclinada: las piezas del fondo sobresalen hacia arriba.
	var target := Vector3(0.0, 0.25, 0.0) - Vector3(sin(yaw), 0.0, cos(yaw)) * (0.55 * cos(pitch))
	camera.fov = cam_fov
	camera.transform = Transform3D(Basis(right, up, back), target + back * dist)


func set_view(pitch: float, yaw: float) -> void:
	cam_pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	cam_yaw = wrapf(yaw, -180.0, 180.0)
	apply_camera()


func _view_step(t: float, p0: float, y0: float, p1: float, y1: float) -> void:
	set_view(lerpf(p0, p1, t), lerpf(y0, y1, t))


## Lleva la cámara con suavidad a una vista (por ejemplo, en picado: pitch = 90).
func animate_view(pitch: float, yaw: float, seconds: float = 0.4) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	if seconds <= 0.0 or anim_mode == Anim.NONE:
		set_view(pitch, yaw)
		return
	_cam_tween = create_tween()
	_cam_tween.tween_method(_view_step.bind(cam_pitch, cam_yaw, pitch, yaw), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
			(node.get_node("Malla") as MeshInstance3D).set_instance_shader_parameter("glow", 1.0 if q == s else 0.0)
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
	(node.get_node("Malla") as MeshInstance3D).mesh = _meshes[Chess.type_of(p)]


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
		(_pieces[selected].get_node("Malla") as MeshInstance3D).set_instance_shader_parameter("glow", 0.0)
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
