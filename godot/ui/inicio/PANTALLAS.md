# Dos pantallas de inicio

El jugador elige en **Opciones → Pantalla de inicio** (se guarda en `chessome.cfg`, sección `app`, clave `inicio`).

- **Lista** (por defecto): fondo con rey y peón, tarjeta de nivel y siete filas. Es la de siempre, rehecha.
- **Rejilla**: cabecera con nivel y pastillas (racha, nivel de juego, avisos), portada, seis tarjetas, reto de la semana y barra inferior.

Las dos se construyen en `ui/home_screens.gd` (`build_list`, `build_grid`) y se ajustan solas a pantallas bajas sin desplazamiento (probado de 1080×2160 a 2640). El modo Kids conserva su inicio.
Decisiones: chip «Nivel de juego» (no puntos), pestaña «Mis partidas» (no Comunidad), «Aprende desde cero» ocupa el sitio de «Mi nivel y mi plan» en la rejilla, la campana abre «Tu día».
Tests: `tests/test_inicio.gd` (lógica) y `tests/inicio.tscn` (capturas; env `SOLO`, `IDIOMA`).
