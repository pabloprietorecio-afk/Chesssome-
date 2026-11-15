class_name ProgressConfig
extends RefCounted
## Todos los valores de equilibrio del reto del día, la racha, el reto semanal y las insignias. Para ajustar el
## ritmo se cambia SOLO este archivo: la lógica (core/progress.gd) no tiene números dentro.

# ---------------------------------------------------------------- reto del día
## Problemas que hay que resolver cada día.
const DAILY_PROBLEMS := 3
## Fallos antiguos que hay que repasar (basta con intentarlos). Solo se pide si hay alguno que repasar.
const DAILY_REVIEWS := 1
## Partidas (contra el ordenador u online) que hay que jugar. No se pide en el nivel Kids.
const DAILY_GAMES := 1
## Lecciones del curso, cuando no hay nada que repasar y quedan lecciones.
const DAILY_LESSONS := 1
## Una partida solo cuenta si el jugador hizo al menos tantas jugadas propias (así no se suman rendiciones).
const MIN_OWN_MOVES_FOR_GAME := 8

# ---------------------------------------------------------------- racha
## Días de gracia por semana: un día sin jugar que no corta la racha. 0 = sin gracia.
const GRACE_PER_WEEK := 1
## Días de historial que se guardan (el resumen y la racha no necesitan más).
const KEEP_DAYS := 90

# ---------------------------------------------------------------- reto semanal
## Problemas de la categoría de la semana que hay que resolver.
const WEEKLY_PROBLEMS := 5
## La categoría de la semana necesita al menos tantos problemas disponibles en la muestra.
const WEEKLY_MIN_POOL := 8

# ---------------------------------------------------------------- insignias
## Días de racha que dan insignia.
const STREAK_BADGES := [3, 7, 30]
## Retos del día completados que dan insignia.
const DAILY_CHALLENGE_BADGES := [10, 30]
## Retos semanales completados que dan insignia.
const WEEKLY_CHALLENGE_BADGES := [1, 5]
