extends SceneTree
## Intro animada (ui/intro.gd): el vídeo se carga, se coloca arriba con el título debajo y un toque la salta.
## Uso: godot --headless --path godot -s tests/test_intro.gd

var fallos := 0
var hechos := 0
var _terminada := false


func _initialize() -> void:
	_ok(Intro.available(), "el vídeo de la intro está en el proyecto")
	var stream = load(Intro.VIDEO)
	_ok(stream is VideoStreamTheora, "el vídeo es Ogg Theora (lo único que lee Godot)")
	var holder := Control.new()
	holder.size = Vector2(1080, 2160)
	root.add_child(holder)
	var intro := Intro.new()
	intro.finished.connect(func() -> void: _terminada = true)
	holder.add_child(intro)
	intro.size = Vector2(1080, 2160)
	await process_frame
	await process_frame
	var player: VideoStreamPlayer = intro._player
	_ok(is_equal_approx(player.size.x, 1080.0) and absf(player.size.y - 1029.0) < 2.0, "el vídeo ocupa el ancho, con su proporción")
	_ok(intro._clip.position.y >= player.position.y + player.size.y - 60.0, "el título va debajo del vídeo")
	_ok(intro._clip.position.x > 0.0 and intro._clip.position.x + intro._label.size.x <= 1080.0, "el título cabe en el ancho")
	_ok(intro._clip.size.x < 1.0, "al empezar, el título aún no está escrito")
	# Un toque la salta.
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	intro._gui_input(tap)
	await create_timer(Intro.FADE + 0.3).timeout
	_ok(_terminada, "un toque termina la intro")
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
