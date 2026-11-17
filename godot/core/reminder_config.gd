class_name ReminderConfig
extends RefCounted
## Valores del aviso diario («echa una partida o cumple tu reto»). Para ajustarlo se cambia SOLO este archivo.

## Hora del aviso si el jugador no elige otra: las 21:00 de la hora local, para acabar el reto del día (Pablo, 16
## nov). Desde el 17 nov se puede cambiar en «Tu día» con un reloj (ui/clock_picker.gd).
const HOUR := 21
## Mientras el jugador entre al menos cada tantos días, el aviso es diario.
const IGNORED_DAYS_LIMIT := 3
## Pasados esos días sin entrar, un aviso por semana (a los 7 y a los 14 días), y después ninguno.
const STOP_AFTER_DAYS := 14
## Cuántos días hacia delante se busca el próximo aviso.
const LOOKAHEAD_DAYS := 16
## Un aviso que caería dentro de tantos segundos ya no se programa.
const MIN_LEAD_SECONDS := 60
