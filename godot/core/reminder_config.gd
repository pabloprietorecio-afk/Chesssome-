class_name ReminderConfig
extends RefCounted
## Valores del aviso diario («echa una partida o cumple tu reto»). Para ajustarlo se cambia SOLO este archivo.

## Hora del aviso, fija (decisión de Pablo, 16 nov): a las 21:00 de la hora local, para acabar el reto del día. El
## jugador solo elige si lo quiere o no.
const HOUR := 21
## Mientras el jugador entre al menos cada tantos días, el aviso es diario.
const IGNORED_DAYS_LIMIT := 3
## Pasados esos días sin entrar, un aviso por semana (a los 7 y a los 14 días), y después ninguno.
const STOP_AFTER_DAYS := 14
## Cuántos días hacia delante se busca el próximo aviso.
const LOOKAHEAD_DAYS := 16
## Un aviso que caería dentro de tantos segundos ya no se programa.
const MIN_LEAD_SECONDS := 60
