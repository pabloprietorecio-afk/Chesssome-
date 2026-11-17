class_name WarChess
extends Chess
## War Chess: ajedrez normal más reglas nuevas que se van añadiendo poco a poco (docs/war-chess.md).
##
## Regla 1 — BLINDAJE. En vez de mover, una pieza que no sea el rey puede blindarse (gasta el turno). Cada pieza
## se blinda una sola vez en la partida. Atacar una pieza blindada no la captura: le rompe el blindaje y la pieza
## atacante se queda en su casilla. El blindaje se pierde al mover la pieza (ARMOR_TRAVELS = false): es una
## posición fortificada, no una armadura que se lleva a todas partes.
##
## Jugadas nuevas (mismo formato de int que Chess): blindarse = origen y destino iguales con la marca F_ARMOR
## (en UCI «e2e2»); romper un blindaje = de la atacante a la blindada con la marca F_BREAK (en UCI como una
## captura, «c4f7», sin coronación aunque sea un peón que llega a la última fila).
##
## El estado va en un séptimo campo del FEN: «war:<blindadas>:<gastadas>», casillas separadas por puntos o «-».
## Así sirve todo lo que guarda posiciones como texto (historial, deshacer, partidas guardadas).

const F_ARMOR := 5
const F_BREAK := 6
const TAG := "war"
## ¿Se lleva la pieza su blindaje al moverse? Decisión de diseño (ver docs/war-chess.md): no.
const ARMOR_TRAVELS := false

## 1 = la pieza de esa casilla está blindada.
var armored := PackedByteArray()
## 1 = la pieza de esa casilla ya ha gastado su blindaje (lo tenga aún o se lo hayan roto).
var spent := PackedByteArray()


func _init() -> void:
	armored.resize(64)
	spent.resize(64)


## Posición de War Chess a partir de un FEN (con o sin el campo «war:…»).
static func from_war_fen(text: String) -> WarChess:
	var base := Chess.from_fen(text)
	var c := WarChess.new()
	c.b = base.b
	c.turn = base.turn
	c.castle = base.castle
	c.ep = base.ep
	c.half = base.half
	c.full = base.full
	var parts := text.strip_edges().split(" ", false)
	if parts.size() > 6 and parts[6].begins_with(TAG + ":"):
		var f := parts[6].split(":")
		if f.size() >= 3:
			c._read_squares(f[1], c.armored)
			c._read_squares(f[2], c.spent)
	return c


## Cualquier FEN: WarChess si lleva el campo de War Chess, Chess si no.
static func parse(text: String) -> Chess:
	if is_war_fen(text):
		return from_war_fen(text)
	return Chess.from_fen(text)


static func is_war_fen(text: String) -> bool:
	var parts := text.strip_edges().split(" ", false)
	return parts.size() > 6 and parts[6].begins_with(TAG + ":")


## FEN de salida de una partida de War Chess.
static func start_fen(fen: String) -> String:
	var parts := fen.strip_edges().split(" ", false)
	while parts.size() < 6:
		parts.append(["w", "-", "-", "0", "1"][parts.size() - 1])
	return " ".join(parts.slice(0, 6)) + " " + TAG + ":-:-"


func _read_squares(text: String, into: PackedByteArray) -> void:
	if text == "-" or text == "":
		return
	for name in text.split("."):
		if name.length() == 2:
			var s := Chess.sq_index(name)
			if s >= 0 and s < 64:
				into[s] = 1


func _write_squares(from: PackedByteArray) -> String:
	var names: Array[String] = []
	for s in 64:
		if from[s] != 0:
			names.append(Chess.sq_name(s))
	return "-" if names.is_empty() else ".".join(names)


func war_field() -> String:
	return "%s:%s:%s" % [TAG, _write_squares(armored), _write_squares(spent)]


func fen() -> String:
	return super.fen() + " " + war_field()


func copy() -> Chess:
	var c := WarChess.new()
	c.b = b.duplicate()
	c.turn = turn
	c.castle = castle
	c.ep = ep
	c.half = half
	c.full = full
	c.armored = armored.duplicate()
	c.spent = spent.duplicate()
	return c


func is_armored(s: int) -> bool:
	return s >= 0 and s < 64 and b[s] != 0 and armored[s] != 0


## ¿Puede blindarse ahora la pieza de `s`? (Del bando que mueve, no el rey, sin blindaje gastado.)
func can_armor(s: int) -> bool:
	if s < 0 or s > 63:
		return false
	var p := b[s]
	if p == 0 or Chess.color_of(p) != turn or Chess.type_of(p) == KING:
		return false
	return spent[s] == 0


## Blindajes que le quedan por usar a un bando.
func armors_left(color: int) -> int:
	var n := 0
	for s in 64:
		var p := b[s]
		if p != 0 and Chess.color_of(p) == color and Chess.type_of(p) != KING and spent[s] == 0:
			n += 1
	return n


static func armor_move(s: int) -> int:
	return s | (s << 6) | (F_ARMOR << 15)


static func is_armor_move(m: int) -> bool:
	return Chess.move_flag(m) == F_ARMOR


static func is_break_move(m: int) -> bool:
	return Chess.move_flag(m) == F_BREAK


func pseudo_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := {}
	for m in super.pseudo_moves():
		var to := Chess.move_to(m)
		var flag := Chess.move_flag(m)
		if flag == F_EN_PASSANT:
			# Al paso contra un peón blindado: no hay captura (solo puede pasar si el blindaje viajara).
			if armored[(to & 7) + 8 * (Chess.move_from(m) >> 3)] != 0:
				continue
		elif b[to] != 0 and armored[to] != 0:
			# Atacar una pieza blindada: rompe el blindaje y no se mueve. Una sola jugada aunque fuera coronación.
			var k := Chess.move_from(m) | (to << 6) | (F_BREAK << 15)
			if not seen.has(k):
				seen[k] = true
				out.append(k)
			continue
		out.append(m)
	for s in 64:
		if can_armor(s):
			out.append(armor_move(s))
	return out


func apply(m: int) -> void:
	var from := Chess.move_from(m)
	var to := Chess.move_to(m)
	var flag := Chess.move_flag(m)
	if flag == F_ARMOR or flag == F_BREAK:
		if flag == F_ARMOR:
			armored[from] = 1
			spent[from] = 1
			half += 1
		else:
			armored[to] = 0
			# Un golpe cambia la posición tanto como una captura: la cuenta de las 50 jugadas vuelve a cero.
			half = 0
		ep = -1
		if turn == 1:
			full += 1
		turn = 1 - turn
		return
	var arm := armored[from]
	var used := spent[from]
	var rook_from := -1
	var rook_to := -1
	if flag == F_CASTLE_K:
		rook_from = to + 1
		rook_to = to - 1
	elif flag == F_CASTLE_Q:
		rook_from = to - 2
		rook_to = to + 1
	var rook_arm := armored[rook_from] if rook_from >= 0 else 0
	var rook_used := spent[rook_from] if rook_from >= 0 else 0
	super.apply(m)
	armored[from] = 0
	spent[from] = 0
	armored[to] = arm if ARMOR_TRAVELS else 0
	spent[to] = used
	if flag == F_EN_PASSANT:
		var victim := (to & 7) + 8 * (from >> 3)
		armored[victim] = 0
		spent[victim] = 0
	if rook_from >= 0:
		armored[rook_from] = 0
		spent[rook_from] = 0
		armored[rook_to] = rook_arm if ARMOR_TRAVELS else 0
		spent[rook_to] = rook_used
