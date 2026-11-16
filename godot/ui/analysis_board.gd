class_name AnalysisBoard
extends Control
## Mini tablero de las pantallas de espera del análisis de una partida. En vez de una ruedecita que no dice nada,
## enseña la partida del jugador:
##  - «Analizando jugada a jugada…»: la jugada que se está analizando en ese momento (`show_move`, una por cada
##    aviso de progreso), con la pieza deslizándose, sus casillas marcadas y unas ondas en la casilla de llegada
##    mientras se piensa; debajo, una barra con lo que va de análisis (`progress`).
##  - «Analizando la partida…»: la partida entera en bucle (`replay`).
## Se dibuja con código (piezas del atlas de la interfaz, que salen de nuestras piezas 3D): ligero, para no
## quitarle tiempo al hilo del análisis. Con las animaciones apagadas (`still`), solo la posición y la barra.

const GLIDE := 0.32
const PING_PERIOD := 1.1
const BAR_GAP := 30.0
const BAR_H := 14.0
const PIECE_NAMES := {"p": "pawn", "n": "knight", "b": "bishop", "r": "rook", "q": "queen", "k": "king"}

var light := Color("f1eefc")
var dark := Color("c7bdf0")
var frame := Color("ffffff")
var mark := Color("ffa366")
var track := Color("c9d5e8")
var white_fill := Color("fbfbff")
var black_fill := Color("1b2540")
var outline := Color("1b2540")
## Negras abajo (el jugador llevaba las negras).
var flipped := false
## Sin animaciones: la posición cambia de golpe y no hay ondas.
var still := false
## Lo que va de análisis (0 a 1); negativo, sin barra.
var progress := -1.0:
	set(value):
		progress = value
		if still or _bar < 0.0:
			_bar = value

var _board: Array = []
var _after: Array = []
var _from := -1
var _to := -1
var _captured := ""
var _glide := 1.0
var _clock := 0.0
var _landed_at := 0.0
var _bar := -1.0
var _replay_fens: Array = []
var _replay_moves: Array = []
var _replay_i := 0
var _replay_every := 0.55
var _replay_wait := 0.0
var _tex := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = _empty()
	_after = _empty()


## Lado del tablero; el control mide eso de ancho y un poco más de alto si lleva barra.
func set_side(side: float, with_bar: bool) -> void:
	custom_minimum_size = Vector2(side, side + (BAR_GAP + BAR_H if with_bar else 0.0))
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## Una posición, sin jugada.
func show_position(fen: String) -> void:
	_board = _parse(fen)
	_after = _board.duplicate()
	_from = -1
	_to = -1
	_captured = ""
	_glide = 1.0
	queue_redraw()


## La jugada `uci` desde la posición `fen`: la pieza se desliza y, al llegar, queda la posición de después.
func show_move(fen: String, uci: String) -> void:
	var pos := Chess.from_fen(fen)
	var m := pos.find_uci(uci)
	if m < 0 or uci.length() < 4:
		show_position(fen)
		return
	_board = _parse(fen)
	_after = _parse(pos.after(m).fen())
	_from = _square(uci.substr(0, 2))
	_to = _square(uci.substr(2, 2))
	_captured = str(_board[_to])
	_glide = 1.0 if still else 0.0
	if still:
		_board = _after.duplicate()
	_landed_at = _clock + (0.0 if still else GLIDE)
	queue_redraw()


## La partida entera en bucle, una jugada cada `every` segundos.
func replay(fens: Array, moves: Array, every: float = 0.55) -> void:
	_replay_fens = fens
	_replay_moves = moves
	_replay_every = every
	_replay_i = 0
	_replay_wait = 0.0
	if not fens.is_empty():
		show_position(str(fens[0]))
	if still and not fens.is_empty():
		# Sin animaciones: la posición final, quieta.
		show_position(str(fens[fens.size() - 1]))
		_replay_fens = []


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if _glide < 1.0:
		_glide = minf(1.0, _glide + delta / GLIDE)
		if _glide >= 1.0:
			_board = _after.duplicate()
	if _bar >= 0.0 and progress >= 0.0:
		_bar = move_toward(_bar, progress, delta * 0.9)
	if not _replay_fens.is_empty() and not _replay_moves.is_empty():
		_replay_wait -= delta
		if _replay_wait <= 0.0:
			if _replay_i >= mini(_replay_moves.size(), _replay_fens.size()):
				_replay_i = 0
				show_position(str(_replay_fens[0]))
				_replay_wait = _replay_every * 2.0
			else:
				show_move(str(_replay_fens[_replay_i]), str(_replay_moves[_replay_i]))
				_replay_i += 1
				_replay_wait = _replay_every
	queue_redraw()


func _draw() -> void:
	var side := minf(size.x, custom_minimum_size.x)
	var origin := Vector2((size.x - side) * 0.5, 0.0)
	var pad := side * 0.035
	var cell := (side - pad * 2.0) / 8.0
	var top_left := origin + Vector2(pad, pad)
	# Marco con sombra suave.
	var box := StyleBoxFlat.new()
	box.bg_color = frame
	box.set_corner_radius_all(int(side * 0.05))
	box.shadow_color = Color(0.16, 0.12, 0.4, 0.16)
	box.shadow_size = int(side * 0.04)
	box.shadow_offset = Vector2(0, side * 0.015)
	draw_style_box(box, Rect2(origin, Vector2(side, side)))
	# Casillas (la esquina redondeada del marco se ve alrededor).
	for row in 8:
		for col in 8:
			var c := light if (row + col) % 2 == 0 else dark
			draw_rect(Rect2(top_left + Vector2(col, row) * cell, Vector2(cell, cell)), c)
	# Casillas de la jugada.
	for sq: int in [_from, _to]:
		if sq >= 0:
			draw_rect(Rect2(top_left + _cell_of(sq) * cell, Vector2(cell, cell)), Color(mark, 0.42))
	# Ondas en la casilla de llegada mientras se analiza.
	if not still and _to >= 0 and _clock >= _landed_at:
		var center := top_left + (_cell_of(_to) + Vector2(0.5, 0.5)) * cell
		for k in 2:
			var t := fposmod((_clock - _landed_at) / PING_PERIOD + k * 0.5, 1.0)
			var r := cell * lerpf(0.42, 1.55, t)
			draw_arc(center, r, 0.0, TAU, 48, Color(mark, 0.55 * (1.0 - t)), maxf(2.0, cell * 0.07 * (1.0 - t)), true)
	# Piezas quietas.
	for sq in 64:
		var p := str(_board[sq])
		if p == "" or (_glide < 1.0 and (sq == _from or sq == _to)):
			continue
		_draw_piece(p, top_left + _cell_of(sq) * cell, cell, 1.0, 1.0)
	# La que se mueve (y la capturada, que se desvanece al llegar).
	if _glide < 1.0 and _from >= 0:
		var e := 1.0 - pow(1.0 - _glide, 3.0)
		if _captured != "":
			_draw_piece(_captured, top_left + _cell_of(_to) * cell, cell, 1.0 - e, 1.0)
		var at := top_left + _cell_of(_from).lerp(_cell_of(_to), e) * cell
		var lift := 1.0 + 0.1 * sin(PI * _glide)
		_draw_piece(str(_board[_from]), at, cell, 1.0, lift)
	# Barra de progreso.
	if _bar >= 0.0:
		var y := origin.y + side + BAR_GAP
		var w := side * 0.82
		var x := origin.x + (side - w) * 0.5
		var bar := StyleBoxFlat.new()
		bar.bg_color = track
		bar.set_corner_radius_all(int(BAR_H * 0.5))
		draw_style_box(bar, Rect2(x, y, w, BAR_H))
		if _bar > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = mark
			fill.set_corner_radius_all(int(BAR_H * 0.5))
			draw_style_box(fill, Rect2(x, y, maxf(BAR_H, w * clampf(_bar, 0.0, 1.0)), BAR_H))


## Una pieza: las blancas, claras con contorno oscuro; las negras, oscuras.
func _draw_piece(p: String, at: Vector2, cell: float, alpha: float, scale: float) -> void:
	var tex := _texture(p.to_lower())
	if tex == null or alpha <= 0.0:
		return
	var s := cell * 0.86 * scale
	var rect := Rect2(at + Vector2(cell - s, cell - s) * 0.5, Vector2(s, s))
	if p == p.to_upper():
		var o := maxf(1.5, cell * 0.035)
		for d: Vector2 in [Vector2(o, 0), Vector2(-o, 0), Vector2(0, o), Vector2(0, -o)]:
			draw_texture_rect(tex, Rect2(rect.position + d, rect.size), false, Color(outline, alpha))
		draw_texture_rect(tex, rect, false, Color(white_fill, alpha))
	else:
		draw_texture_rect(tex, rect, false, Color(black_fill, alpha))


func _texture(p: String) -> Texture2D:
	if not _tex.has(p):
		_tex[p] = UiIcons.texture("piece_" + str(PIECE_NAMES.get(p, "pawn"))) if UiIcons.has("piece_" + str(PIECE_NAMES.get(p, "pawn"))) else null
	return _tex[p]


## Columna y fila en pantalla (en casillas) de una casilla 0–63 (0 = a8, como en el FEN).
func _cell_of(sq: int) -> Vector2:
	var row := sq / 8
	var col := sq % 8
	if flipped:
		row = 7 - row
		col = 7 - col
	return Vector2(col, row)


static func _square(name: String) -> int:
	var file := name.unicode_at(0) - 97
	var rank := name.unicode_at(1) - 49
	if file < 0 or file > 7 or rank < 0 or rank > 7:
		return -1
	return (7 - rank) * 8 + file


static func _empty() -> Array:
	var out: Array = []
	out.resize(64)
	out.fill("")
	return out


static func _parse(fen: String) -> Array:
	var out := _empty()
	var rows := fen.split(" ")[0].split("/")
	for r in mini(rows.size(), 8):
		var col := 0
		for ch in rows[r]:
			if ch >= "1" and ch <= "8":
				col += int(ch)
			elif col < 8:
				out[r * 8 + col] = ch
				col += 1
	return out
