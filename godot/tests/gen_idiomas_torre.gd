extends SceneTree
## Genera ui/idiomas/<código>.bin: una torre de marfil en 3D (nuestra pieza clásica) sobre una tesela de esquinas
## redondeadas con los colores de la bandera de cada idioma. Es una herramienta, no una prueba.
## Uso: xvfb-run -a godot --path godot --rendering-driver vulkan --rendering-method mobile -s tests/gen_idiomas_torre.gd
## Variable TORRE_SOLO=1: solo guarda la torre en /tmp/torre.png.

const S := 512
const RADIUS := 0.266


func _initialize() -> void:
	var rook := await _render_rook()
	rook.save_png("/tmp/torre.png")
	if OS.get_environment("TORRE_SOLO") != "":
		quit()
		return
	DirAccess.make_dir_recursive_absolute("res://ui/idiomas")
	for code: String in Loc.LANGUAGES:
		var tile := _tile(code, rook)
		var png := tile.save_png_to_buffer()
		var f := FileAccess.open("res://ui/idiomas/%s.bin" % code, FileAccess.WRITE)
		f.store_buffer(png)
		f.close()
		tile.save_png("/tmp/tile_%s.png" % code)
		print("hecho ", code)
	quit()


## La torre clásica sobre fondo transparente, con luz suave de estudio y material de marfil.
func _render_rook() -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.97, 0.92)
	env.ambient_light_energy = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.8, 0.6)
	fill.light_energy = 0.3
	fill.rotation_degrees = Vector3(-10.0, 140.0, 0.0)
	vp.add_child(fill)
	var scene: Node = (load("res://sets/clasico/rook.glb") as PackedScene).instantiate()
	vp.add_child(scene)
	await process_frame
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.97, 0.93, 0.85)
	mat.roughness = 0.42
	mat.metallic_specular = 0.55
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.35
	mat.clearcoat_roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.93, 0.8)
	mat.emission_energy_multiplier = 0.1
	mat.rim_enabled = true
	mat.rim = 0.3
	mat.rim_tint = 0.5
	var box := AABB()
	var first := true
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = mat
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var cam := Camera3D.new()
	cam.fov = 18.0
	vp.add_child(cam)
	var c := box.get_center()
	var h := maxf(box.size.y, box.size.x)
	var dist := h * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.42
	var pitch := deg_to_rad(13.0)
	cam.look_at_from_position(c + Vector3(0.0, sin(pitch), cos(pitch)) * dist, c)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _tile(code: String, rook: Image) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var corner := S * RADIUS
	for y in S:
		var v := (float(y) + 0.5) / float(S)
		for x in S:
			var u := (float(x) + 0.5) / float(S)
			var c := LangBoard.flag_color(code, u, v)
			# Brillo de la tesela: más clara arriba, algo más honda abajo (como el icono de la app).
			var g := lerpf(1.07, 0.9, v)
			c = Color(minf(c.r * g, 1.0), minf(c.g * g, 1.0), minf(c.b * g, 1.0), 1.0)
			c.a = _rounded_alpha(float(x) + 0.5, float(y) + 0.5, corner)
			img.set_pixel(x, y, c)
	# Sombra de la torre: su silueta, borrosa, algo más abajo.
	var fit := int(S * 0.98)
	var r := rook.duplicate() as Image
	r.resize(fit, fit, Image.INTERPOLATE_LANCZOS)
	var shadow := Image.create(S, S, false, Image.FORMAT_RGBA8)
	shadow.blit_rect(r, Rect2i(0, 0, fit, fit), Vector2i((S - fit) / 2, (S - fit) / 2 + int(S * 0.025)))
	_shade(img, shadow, S / 14, 0.5)
	var edge := Image.create(S, S, false, Image.FORMAT_RGBA8)
	edge.blit_rect(r, Rect2i(0, 0, fit, fit), Vector2i((S - fit) / 2, (S - fit) / 2))
	_shade(img, edge, S / 70, 0.7)
	img.blend_rect(r, Rect2i(0, 0, fit, fit), Vector2i((S - fit) / 2, (S - fit) / 2))
	# El rectángulo redondeado vuelve a recortar lo que se hubiera salido.
	for y in S:
		for x in S:
			var p := img.get_pixel(x, y)
			p.a = minf(p.a, _rounded_alpha(float(x) + 0.5, float(y) + 0.5, corner))
			img.set_pixel(x, y, p)
	return img


func _rounded_alpha(x: float, y: float, r: float) -> float:
	var dx := maxf(maxf(r - x, x - (S - r)), 0.0)
	var dy := maxf(maxf(r - y, y - (S - r)), 0.0)
	var d := sqrt(dx * dx + dy * dy)
	return clampf(r - d + 0.5, 0.0, 1.0)


## Oscurece `img` con la silueta de `sil` difuminada (reduciendo y ampliando) y multiplicada por `strength`.
func _shade(img: Image, sil: Image, blur_div: int, strength: float) -> void:
	var soft := sil.duplicate() as Image
	soft.resize(maxi(S / blur_div, 2), maxi(S / blur_div, 2), Image.INTERPOLATE_BILINEAR)
	soft.resize(S, S, Image.INTERPOLATE_BILINEAR)
	for y in S:
		for x in S:
			var a := clampf(soft.get_pixel(x, y).a * strength * 1.6, 0.0, 1.0) if blur_div > 40 else soft.get_pixel(x, y).a * strength
			if a > 0.0:
				var p := img.get_pixel(x, y)
				var k := 1.0 - a
				img.set_pixel(x, y, Color(p.r * k + 0.12 * a, p.g * k + 0.06 * a, p.b * k + 0.03 * a, p.a))
