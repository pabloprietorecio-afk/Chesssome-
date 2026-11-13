class_name BoardSounds
extends Node
## Sonidos de la partida: el roce de la pieza al arrastrarse, el golpe al posarse o capturar, el aviso de
## jaque y la caída del rey en el mate. Son grabaciones de objetos e instrumentos reales, de dominio público
## (godot/sounds/LEEME.md); aquí solo se elige una, se le da un nivel y se varía un poco el tono para que
## dos jugadas seguidas no suenen idénticas.
##
## Se conecta a la señal «sound» de Board3D:  board.sound.connect(sounds.play)

## Grabaciones de cada momento (godot/sounds/<nombre>.wav).
const FILES := {
	"slide": ["arrastre_1", "arrastre_2", "arrastre_3"],
	"place": ["posar_1", "posar_2", "posar_3"],
	"capture": ["captura_1", "captura_2"],
	"check": ["jaque"],
	"fall": ["caida_rey"],
}
## Nivel de cada momento, en decibelios. El roce va bajo: es un sonido continuo y cansa antes que un golpe.
const LEVEL_DB := {"slide": -12.0, "place": -7.0, "capture": -4.0, "check": -5.0, "fall": -3.0}
const VOICES := 5

var enabled := true

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _slide: AudioStreamPlayer
var _slide_tween: Tween
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for kind: String in FILES:
		var list: Array[AudioStream] = []
		for file: String in FILES[kind]:
			var path := "res://sounds/%s.wav" % file
			if ResourceLoader.exists(path):
				var stream := load(path) as AudioStream
				if stream != null:
					list.append(stream)
			else:
				push_warning("Falta el sonido " + path)
		_streams[kind] = list
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# El roce tiene su propia voz: hay que poder apagarlo cuando la pieza llega.
	_slide = AudioStreamPlayer.new()
	add_child(_slide)


func has_sound(kind: String) -> bool:
	return _streams.has(kind) and not (_streams[kind] as Array).is_empty()


## Suena un momento de la partida. En "slide", amount es lo que tarda la pieza en llegar, en segundos.
func play(kind: String, amount: float = 0.0) -> void:
	if not enabled or not has_sound(kind):
		return
	var list: Array = _streams[kind]
	var stream: AudioStream = list[_rng.randi() % list.size()]
	var level: float = LEVEL_DB.get(kind, -6.0)
	if kind == "slide":
		_play_slide(stream, level, amount)
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = level + _rng.randf_range(-1.5, 0.5)
	# El jaque es una figura de dos notas: no se le cambia el tono.
	p.pitch_scale = 1.0 if kind == "check" else _rng.randf_range(0.94, 1.07)
	p.play()


func _play_slide(stream: AudioStream, level: float, seconds: float) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide.stream = stream
	_slide.volume_db = level
	_slide.pitch_scale = _rng.randf_range(0.92, 1.1)
	_slide.play()
	# El roce se apaga justo antes de que la pieza se pose; el golpe lo pone "place" o "capture".
	_slide_tween = create_tween()
	_slide_tween.tween_interval(maxf(seconds - 0.07, 0.03))
	_slide_tween.tween_property(_slide, "volume_db", -50.0, 0.08)
	_slide_tween.tween_callback(_slide.stop)


## Corta lo que esté sonando (al cambiar de problema o al quitar el sonido).
func stop_all() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide.stop()
	for p in _players:
		p.stop()
