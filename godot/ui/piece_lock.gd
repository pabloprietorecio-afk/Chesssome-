class_name PieceLock
extends SubViewportContainer
## Código de 4 piezas para salir del modo Kids: un tablero 3D de 6 × 2 casillas con las 12 piezas (las 6 blancas
## delante y las 6 negras detrás, en el mismo orden; nuestras piezas clásicas) y, encima del tablero, 4 casillas vacías. Al tocar una pieza, una copia salta
## a la siguiente casilla libre (se pueden repetir). `code` es un texto de 4 letras: KQRBNP (blancas), kqrbnp (negras).

signal changed(code: String)
signal completed(code: String)

const ORDER := ["K", "Q", "R", "B", "N", "P", "k", "q", "r", "b", "n", "p"]
const FILES := {"k": "king", "q": "queen", "r": "rook", "b": "bishop", "n": "knight", "p": "pawn"}
const HEIGHTS := {"k": 1.4, "q": 1.3, "r": 1.0, "b": 1.16, "n": 1.1, "p": 0.92}
const SLOT_Z := -1.55
const SLOT_Y := 0.32

var code := ""
var enabled := true

var _vp: SubViewport
var _cam: Camera3D
var _pieces: Array[Node3D] = []
var _placed: Array[Node3D] = []
var _slots: Array[MeshInstance3D] = []
var _meshes: Dictionary = {}
var _ivory: StandardMaterial3D
var _ink: StandardMaterial3D
var _slot_mat: StandardMaterial3D
var _slot_on: StandardMaterial3D
var _busy := 0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.physics_object_picking = false
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.9)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.3
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.rotation_degrees = Vector3(-25.0, 150.0, 0.0)
	_vp.add_child(fill)
	_cam = Camera3D.new()
	_cam.fov = 37.0
	_vp.add_child(_cam)
	_cam.look_at_from_position(Vector3(0.0, 6.4, 4.4), Vector3(0.0, 0.25, -0.2))

	_ivory = _mat(Color(1.0, 0.96, 0.88), 0.35)
	_ink = _mat(Color(0.13, 0.17, 0.3), 0.32)
	_slot_mat = _mat(Color(1.0, 0.93, 0.85), 0.6)
	_slot_on = _mat(Color(1.0, 0.72, 0.45), 0.5)
	_build_board()
	_build_slots()
	for i in ORDER.size():
		var p := _make_piece(ORDER[i])
		p.position = _cell_pos(i)
		_vp.add_child(p)
		_pieces.append(p)
	_highlight()


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.clearcoat_enabled = true
	m.clearcoat = 0.25
	m.rim_enabled = true
	m.rim = 0.2
	return m


func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_vp.add_child(mi)
	return mi


func _build_board() -> void:
	var frame := _mat(Color(0.42, 0.27, 0.15), 0.5)
	_box(Vector3(6.5, 0.26, 2.5), frame, Vector3(0.0, -0.13, 0.5))
	var light := _mat(Color(0.82, 0.68, 0.5), 0.55)
	var dark := _mat(Color(0.55, 0.37, 0.22), 0.55)
	for r in 2:
		for c in 6:
			_box(Vector3(1.0, 0.06, 1.0), light if (r + c) % 2 == 0 else dark, Vector3(c - 2.5, 0.03, float(r)))


func _build_slots() -> void:
	# Las 4 casillas del código, en una repisa algo más alta, encima del tablero.
	_box(Vector3(5.6, 0.3, 1.5), _mat(Color(0.42, 0.27, 0.15), 0.5), Vector3(0.0, 0.0, SLOT_Z))
	for i in 4:
		_slots.append(_box(Vector3(1.08, 0.08, 1.08), _slot_mat, Vector3(_slot_x(i), 0.19, SLOT_Z)))


func _slot_x(i: int) -> float:
	return (i - 1.5) * 1.3


func _cell_pos(i: int) -> Vector3:
	# Blancas (0–5) en la fila de delante; negras (6–11) detrás.
	return Vector3((i % 6) - 2.5, 0.06, 1.0 if i < 6 else 0.0)


func _make_piece(letter: String) -> Node3D:
	var key := letter.to_lower()
	var white := letter == letter.to_upper()
	var holder := Node3D.new()
	var scene: Node3D = (load("res://sets/clasico/%s.glb" % FILES[key]) as PackedScene).instantiate()
	holder.add_child(scene)
	var box := AABB()
	var first := true
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = _ivory if white else _ink
		var b := mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := float(HEIGHTS[key]) / maxf(box.size.y, 0.001)
	scene.scale = Vector3(s, s, s)
	scene.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
	# Los caballos miran al centro; las negras, de frente como las blancas.
	scene.rotation_degrees.y = -90.0 if key == "n" else 0.0
	holder.set_meta("letter", letter)
	return holder


func _highlight() -> void:
	for i in _slots.size():
		_slots[i].material_override = _slot_on if (i == code.length() and enabled) else _slot_mat


func _gui_input(event: InputEvent) -> void:
	if not enabled or code.length() >= 4:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := _pick((event as InputEventMouseButton).position)
		if i >= 0:
			add_piece(ORDER[i])
			accept_event()


## Qué pieza hay bajo el dedo (-1 si ninguna): el rayo de la cámara a media altura de las piezas.
func _pick(pos: Vector2) -> int:
	var p := pos * Vector2(_vp.size.x / maxf(size.x, 1.0), _vp.size.y / maxf(size.y, 1.0))
	var from := _cam.project_ray_origin(p)
	var dir := _cam.project_ray_normal(p)
	var best := -1
	for h: float in [0.5, 0.2]:
		if absf(dir.y) < 0.001:
			continue
		var t := (h - from.y) / dir.y
		var hit := from + dir * t
		var c := int(floor(hit.x + 3.0))
		var r := int(floor(hit.z + 0.5))
		if c >= 0 and c < 6 and r >= 0 and r < 2:
			best = c if r == 1 else 6 + c
			break
	return best


## Pone una pieza en la siguiente casilla del código (también lo usan las pruebas).
func add_piece(letter: String) -> void:
	if code.length() >= 4 or not letter in ORDER:
		return
	var i: int = ORDER.find(letter)
	var slot := code.length()
	code += letter
	var copy := _make_piece(letter)
	var from := _pieces[i].position
	copy.position = from
	_vp.add_child(copy)
	_placed.append(copy)
	var to := Vector3(_slot_x(slot), 0.23, SLOT_Z)
	var mid := (from + to) * 0.5 + Vector3(0.0, 1.5, 0.0)
	_busy += 1
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(copy):
			var a := from.lerp(mid, t)
			var b := mid.lerp(to, t)
			copy.position = a.lerp(b, t)
			copy.rotation.y = TAU * t, 0.0, 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(copy, "scale", Vector3(1.08, 0.88, 1.08), 0.06)
	tw.tween_property(copy, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	copy.set_meta("tween", tw)
	tw.finished.connect(func() -> void:
		_busy -= 1
		if code.length() == 4 and _busy == 0:
			completed.emit(code))
	# La pieza de su casilla da un saltito.
	var src := _pieces[i]
	var hop := create_tween()
	hop.tween_property(src, "position:y", 0.3, 0.08)
	hop.tween_property(src, "position:y", 0.06, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_highlight()
	changed.emit(code)


## Quita la última pieza del código.
func back() -> void:
	if code.is_empty() or not enabled:
		return
	code = code.substr(0, code.length() - 1)
	var p: Node3D = _placed.pop_back()
	# Si aún iba por el aire, se para su vuelo.
	var flying: Tween = p.get_meta("tween", null)
	if flying != null and flying.is_valid() and flying.is_running():
		flying.kill()
		_busy -= 1
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector3(0.01, 0.01, 0.01), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.finished.connect(p.queue_free)
	_highlight()
	changed.emit(code)


## Vacía las 4 casillas; con `shake`, la repisa tiembla antes (código equivocado).
func clear(shake := false) -> void:
	var gone := _placed.duplicate()
	_placed.clear()
	code = ""
	var tw := create_tween()
	if shake:
		for k in 5:
			for s in _slots:
				tw.parallel().tween_property(s, "position:x", s.position.x + (0.12 if k % 2 == 0 else -0.12), 0.05)
			for p: Node3D in gone:
				tw.parallel().tween_property(p, "position:x", p.position.x + (0.12 if k % 2 == 0 else -0.12), 0.05)
			tw.tween_interval(0.0)
		for i in _slots.size():
			tw.parallel().tween_property(_slots[i], "position:x", _slot_x(i), 0.05)
	for p: Node3D in gone:
		tw.parallel().tween_property(p, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
	tw.finished.connect(func() -> void:
		for p: Node3D in gone:
			if is_instance_valid(p):
				p.queue_free())
	_highlight()
	changed.emit(code)


func set_enabled(on: bool) -> void:
	enabled = on
	modulate.a = 1.0 if on else 0.55
	if _slots.size() > 0:
		_highlight()
