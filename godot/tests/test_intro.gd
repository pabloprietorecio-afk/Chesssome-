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
	# Como en la app: se añade a la pantalla ya montada, sin darle tamaño a mano (así falló en el móvil:
	# la intro medía 0 × 0 y solo se veía el título, cortado, encima del inicio).
	var holder := Control.new()
	holder.size = Vector2(1080, 2160)
	root.add_child(holder)
	await process_frame
	var intro := Intro.new()
	intro.finished.connect(func() -> void: _terminada = true)
	holder.add_child(intro)
	await process_frame
	await process_frame
	_ok(intro.size == holder.size, "la intro ocupa toda la pantalla (mide %s)" % str(intro.size))
	# Si la pantalla cambia de tamaño (barra del sistema, giro), la sigue.
	holder.size = Vector2(1080, 2340)
	await process_frame
	_ok(intro.size == holder.size, "la intro sigue a la pantalla si cambia de tamaño")
	holder.size = Vector2(1080, 2160)
	await process_frame
	var player: VideoStreamPlayer = intro._player
	_ok(is_equal_approx(player.size.x, 1080.0) and absf(player.size.y - 1080.0 * Intro.ASPECT) < 2.0, "el vídeo ocupa el ancho, con su proporción")
	_ok(player.position.y >= 0.0 and player.position.y + player.size.y <= 2160.0 + 1.0, "y cabe en la pantalla")
	var title_mid: float = intro._clip.position.y + intro._label.size.y * 0.5
	_ok(title_mid > 2160.0 * 0.62 and title_mid < 2160.0 * 0.9, "el título va en el tercio de abajo, en el suelo del vídeo (%.0f)" % title_mid)
	_ok(intro._clip.position.x > 0.0 and intro._clip.position.x + intro._label.size.x <= 1080.0, "el título cabe en el ancho")
	_ok(intro._clip.size.x < 1.0, "al empezar, el título aún no está escrito")
	# Sonido: el del vídeo, que arranca con él, al volumen de los efectos de la app.
	_ok(intro._audio != null and intro._audio.stream is AudioStreamOggVorbis, "la intro lleva su sonido (Ogg Vorbis)")
	await create_timer(0.7).timeout
	_ok(intro._audio.playing, "el sonido arranca con el vídeo")
	_ok(is_equal_approx(intro._audio.volume_db, Intro.SOUND_DB), "al volumen de los efectos")
	# Un toque la salta.
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	intro._gui_input(tap)
	await create_timer(Intro.FADE * 0.6).timeout
	_ok(is_instance_valid(intro) and intro._audio.volume_db < Intro.SOUND_DB - 3.0, "al saltarla, el sonido se apaga con la imagen")
	await create_timer(Intro.FADE + 0.3).timeout
	_ok(_terminada, "un toque termina la intro")
	# Con el sonido apagado en Opciones, sin sonido.
	var quiet := Intro.new()
	quiet.sound = false
	holder.add_child(quiet)
	await process_frame
	_ok(quiet._audio == null, "con el sonido apagado, la intro va en silencio")
	quiet.queue_free()
	await _en_la_app()
	print("%d comprobaciones, %d fallos" % [hechos, fallos])
	if fallos == 0:
		print("TODO OK")
	quit(1 if fallos > 0 else 0)


## Por el camino de la app: el inicio montado y la intro encima, tapándolo entero.
func _en_la_app() -> void:
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	root.add_child(demo)
	await process_frame
	await process_frame
	demo.intro_mode = "always"
	demo.use_settings = true
	demo._play_intro()
	demo.use_settings = false
	await process_frame
	await process_frame
	var intro: Intro = null
	for child in demo.get_children():
		if child is Intro:
			intro = child
	_ok(intro != null, "la app pone la intro al arrancar")
	if intro == null:
		return
	_ok(intro.size == demo.size and demo.size.x > 0.0, "en la app, la intro tapa toda la pantalla")
	_ok(intro.get_index() == demo.get_child_count() - 1, "la intro queda encima de todo")
	demo.intro_mode = "never"
	intro.queue_free()
	await process_frame
	var antes := demo.get_child_count()
	demo.use_settings = true
	demo._play_intro()
	demo.use_settings = false
	_ok(demo.get_child_count() == antes, "con «Nunca», no sale")
	demo.queue_free()


func _ok(cond: bool, nombre: String) -> void:
	hechos += 1
	if not cond:
		fallos += 1
		print("FALLO: " + nombre)
