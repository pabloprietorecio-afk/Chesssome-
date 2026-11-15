# Reto del día, racha y reto semanal

Capa de constancia alrededor del juego, sin monedas ni XP: el progreso real sigue siendo el nivel de habilidad (Glicko-2).

- **Reto del día** (`Progress.ensure_today`): resolver 3 problemas; repasar un fallo antiguo (solo si hay fallos que repasar) o hacer una lección (si quedan); jugar una partida (no en Kids). Una partida cuenta con al menos 8 jugadas propias.
- **Racha**: un día cuenta con cualquier actividad. Un día sin jugar se perdona una vez por semana (lunes–domingo).
- **Reto semanal**: 5 problemas resueltos de la categoría más floja del jugador (la de «Mi nivel y mi plan»), o una que se va turnando; no se repite la de la semana anterior.
- **Insignias**: racha de 3, 7 y 30 días; 10 y 30 retos del día; 1 y 5 retos semanales.
- Nada de esto se usa en el nivel Kids.

## Dónde está
- `godot/core/progress_config.gd`: **todos los valores** (metas, gracia, insignias). Es el único sitio que hay que tocar para equilibrar.
- `godot/core/progress.gd`: lógica pura y guardado (`user://chessome_progreso.json`, versionado, escritura atómica).
- `godot/demo/demo.gd`: tres enganches (`_record` → `_prog_problem`, fin de lección → `_prog_lesson`, `_record_game` → `_prog_game`), la tarjeta del inicio y la página «Tu día» (`_open_day`).
- `godot/tests/test_progress.gd` (en el CI) y las capturas `p1b`–`p1d` de `tests/pantallas.gd`.

## Pendiente
- El progreso vive solo en el dispositivo; se perderá al cambiar de móvil hasta que exista la cuenta opcional.
- Recordatorios (notificaciones): no incluidos.
