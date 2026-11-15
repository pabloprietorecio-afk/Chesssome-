class_name ReminderConfig
extends RefCounted
## Valores del aviso diario («echa una partida o cumple tu reto»). Para ajustarlo se cambia SOLO este archivo.

## Hora por defecto del aviso (el jugador podrá elegirla).
const DEFAULT_HOUR := 19
## Mientras el jugador entre al menos cada tantos días, el aviso es diario.
const IGNORED_DAYS_LIMIT := 3
## Pasados esos días sin entrar, un aviso por semana (a los 7 y a los 14 días), y después ninguno.
const STOP_AFTER_DAYS := 14
## Cuántos días hacia delante se busca el próximo aviso.
const LOOKAHEAD_DAYS := 16
## Un aviso que caería dentro de tantos segundos ya no se programa.
const MIN_LEAD_SECONDS := 60
