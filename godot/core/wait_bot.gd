class_name WaitBot
extends RefCounted
## Rival de la espera online (docs/espera-bot.md): si nadie entra en el espacio, la app ofrece jugar contra Robi, un
## bot. **Siempre se dice que es un bot** (nombre, página de espera y título de la partida); lo que imita de un rival
## humano es el trato: saluda, felicita alguna buena jugada, no contesta de golpe y se despide con «Buena partida».
## Nunca finge ser una persona ni habla de sí mismo como si lo fuera.

const NAME := "Robi"
const VALUES := {"p": 1, "n": 3, "b": 3, "r": 5, "q": 9}
## Como mucho una felicitación cada tantas jugadas del jugador (no es un loro).
const CHEER_GAP := 4


## Material que el jugador (`color`: 0 blancas, 1 negras) ha capturado con su jugada, comparando las dos posiciones.
static func captured_value(fen_before: String, fen_after: String, color: int) -> int:
	return _material(fen_before, 1 - color) - _material(fen_after, 1 - color)


static func _material(fen: String, side: int) -> int:
	var total := 0
	for ch in fen.get_slice(" ", 0):
		var low := ch.to_lower()
		if not VALUES.has(low):
			continue
		var white := ch != low
		if (side == 0) == white:
			total += int(VALUES[low])
	return total


## Gesto tras una jugada del jugador ("" = nada). Felicita capturas de pieza (3 o más) que no son un error
## comprobado, y no siempre (`roll` entre 0 y 1).
static func cheer_for(captured: int, blunder: bool, moves_since: int, roll: float) -> String:
	if blunder or captured < 3 or moves_since < CHEER_GAP:
		return ""
	if captured >= 9:
		return "genial"
	return "arriba" if roll < 0.6 else ""


## Despedida al acabar: si gana el jugador, primero «¡Bravo!»; siempre «Buena partida».
static func farewell(player_won: int) -> Array:
	return ["aplauso", "buena"] if player_won > 0 else ["buena"]


## Cuánto «piensa» antes de jugar, como una persona: entre 1,2 y 4 segundos (más al principio no: las primeras
## jugadas van rápidas), y nunca más de una cuarentava parte de su reloj.
static func think_ms(roll: float, ply: int, clock_left_ms: float) -> float:
	var ms := lerpf(600.0, 1500.0, roll) if ply < 8 else lerpf(1200.0, 4000.0, roll)
	if clock_left_ms > 0.0:
		ms = minf(ms, clock_left_ms / 40.0)
	return maxf(ms, 550.0)
