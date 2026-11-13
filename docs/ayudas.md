# Ayudas tras un problema

Tres ayudas que aparecen al terminar un problema, debajo de la explicación. Implementadas en el prototipo web (`src/ui/AssistTools.tsx`, `src/core/assist.ts`); esta página es la especificación para la versión Godot.

## Cuándo aparecen

| Situación | ¿Se muestran? | Motivo |
| --- | --- | --- |
| Test inicial de nivel | No | Ayudar mientras se mide contamina la medida. |
| Entrenamiento, tema con explicación (condición «explained» de H1) | Sí | |
| Entrenamiento, tema de control (condición «plain» de H1) | No | Si el grupo de control tuviera ayudas, H1 no mediría nada. |
| Fuera del estudio (producto final) | Sí, siempre | |
| Sección infantil | Solo «¿Y si juego…?» | Las otras dos sacan al niño de la app o envían datos a terceros: necesitan control parental (Apple 1.3, Google Play Families). |

## 1. «¿Y si juego…?»

- El tablero vuelve a la posición de decisión (la del fallo, o la primera si se acertó) y se puede mover cualquier pieza del bando que juega.
- Cada jugada probada muestra su explicación con los mismos cuatro niveles y el botón «Explícame por qué».
- El tablero no cambia de posición tras probar una jugada: se queda en la posición de decisión con las flechas de la explicación, para poder probar otra enseguida. Mientras se reproduce una variante no se puede mover.
- «Volver a la explicación» devuelve a la explicación del intento.
- No usa red ni IA: la explicación de **todas** las jugadas legales ya está generada y revisada por el pipeline (de media, 73,8 por problema; 4,7 KB por problema comprimido con brotli).
- Godot: leer la explicación precalculada de `(problema, punto, jugada)`; nada se genera en el dispositivo.

## 2. «Analizar en Lichess»

- Abre `https://lichess.org/analysis/<FEN>` con los espacios del FEN como `%20` (formato del foro de Lichess; ver `lichessAnalysisUrl`).
- Posición: la de decisión.
- Godot: `OS.shell_open(url)`. Hay informes en el foro de Godot de fallos al abrir el navegador en algunos Samsung/Xiaomi con Android 11+: probar en dispositivos reales antes de publicar.
- Icono propio (tablero con lupa). No se usa el logotipo de Lichess.

## 3. «Pregunta a una IA»

- Se envía **texto**, no una captura: posición FEN, quién juega, jugada hecha (o «estoy probando…» si viene de «¿Y si juego…?»), solución, tabla del motor con profundidad, enlace a Lichess, nivel del jugador y su pregunta (o una pregunta por defecto). Ver `aiShareText`.
- Motivo: las IA generales leen mal tableros en imagen y se equivocan a menudo al calcular; con el FEN y el análisis verificado parten de datos ciertos. El texto les pide usar solo jugadas legales y decir cuándo no están seguras.
- Aviso visible antes de compartir: las IA generales se equivocan a menudo en ajedrez; comprobar en el tablero cualquier jugada propuesta.
- Acciones:
  - **Compartir con una IA**: menú de compartir del sistema; el usuario elige la app (Google, Gemini, ChatGPT…).
  - **Copiar texto**.
  - **Abrir en Google (Modo IA)**: `https://www.google.com/search?udm=50&q=<texto>`. `udm=50` no está documentado por Google; si deja de funcionar, se abre una búsqueda normal.
- Sin datos personales: solo el nivel aproximado del jugador.
- Icono propio (bocadillo con interrogación). No se usan logotipos de Google ni de otras IA: las directrices de marca de Google exigen permiso.
- Godot:
  - Compartir: `Intent.ACTION_SEND` con `text/plain`. En el foro de Godot (4.6.1) se crea el Intent desde GDScript con `JavaClassWrapper`; cómo lanzarlo en 4.7 está **sin verificar**. Alternativa: el plugin de compartir de Godot Mobile Plugins (licencia MIT según la Asset Library).
  - Copiar: `DisplayServer.clipboard_set(texto)`.

## Registro (estudio)

Evento `assist` con `data.tool`: `whatif` (entrar), `whatif_move` (con `uci`), `whatif_exit`, `lichess`, `ai_open`, `ai_share`, `ai_copy`, `ai_google`. Las ayudas solo existen en la condición con explicación, así que forman parte de ese tratamiento en H1.
