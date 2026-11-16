# Finales de campeones (el cine, fase 1)

Pablo, 16 nov: el cine entra en la app por fases. Esta es la primera: sin vídeo dentro de la app.

## Qué ve el jugador

- **Entrenar → «Finales de campeones»**: seis momentos de partidas famosas (los del cine de la web, rama
  `cine-video`). No en Kids.
- Cada final es una lección con el mismo motor que las del curso:
  1. **Presentación**: dónde y cuándo, qué estaba en juego. Chips: número de preguntas y canal del vídeo.
  2. **Preguntas** («¿Qué jugarías?», con la última jugada del rival marcada). Vale **cualquier jugada que mantiene
     el resultado** según el motor (veredicto «keeps»); la de la partida explica por qué; las demás dicen qué
     estropean («deja escapar la victoria», «pierde») y **cómo podría seguir** (la línea del motor). Si en la partida
     hubo un error, encontrar la buena es la respuesta y jugar la de la partida dice «Es lo que se jugó, pero…» y cuál
     era la correcta. «Pista»: primero la frase del clip; la segunda vez, la pieza. «¿Por qué?» del tablero, como en
     el curso.
  3. **Explicación** paso a paso de la partida (posiciones, última jugada y flechas), **por qué abandonó** (si
     abandonó) y cómo acabó.
  4. **Final**: estrellas, la lección que deja y **«Ver el vídeo»**, que abre el vídeo oficial en YouTube (la app o el
     navegador) desde el principio del momento. «Siguiente final».
- El progreso se guarda con el del curso (`cine-<id>` en `course_done`) y cuenta como lección para el reto del día.

## De dónde salen los datos

- `tools/cine/videocine.pack.json`: copia del paquete del cine de la web (rama `cine-video`, commit 17a1575): partidas
  reproducidas jugada a jugada y **todas las jugadas legales de cada pregunta evaluadas con Stockfish 19** (prof. 24).
- `tools/cine/build.py` (python-chess) lo convierte en `godot/data/cine.json`: comprueba que cada pregunta tiene
  veredicto para todas sus jugadas legales y alguna que vale, numera las líneas en notación española y saca los
  textos a traducir (`tools/i18n/claves_cine.json`).
- Traducciones: `tools/cine/trad.tsv` (con las jugadas en notación española) → `tools/i18n/trad/cine.tsv` con la
  notación de cada idioma. Las frases de las respuestas se componen en `core/cine.gd` y están en
  `tools/i18n/trad/ui_cine.tsv`.
- Prueba: `tests/test_cine.gd` (en la CI). Capturas: `tests/pantallas.tscn` (p34 a p41).

## Fase 2: el vídeo dentro de la app (16 nov)

Como funcionaba en la web (rama `cine-video`), con las marcas que puso Pablo viendo los vídeos:

- **Arriba, el vídeo** (reproductor oficial de YouTube, a todo el ancho, 16:9). Se carga **parado** en el inicio
  del clip: lo arranca el jugador con ▶ en el propio reproductor.
- **Debajo, el tablero sigue las jugadas del vídeo** (marcas `sync`), sin enseñar nunca la jugada de la próxima
  pregunta (tope por pausa, `CineFilm.sync_cap`).
- **Justo antes de cada pregunta, el vídeo se para solo** y la pregunta sale en el tablero, en la misma posición.
  «Ir a la pregunta» la trae sin esperar. Tras responder, «Seguir el vídeo» lo reanuda desde la pausa.
- **Responder es opcional** (norma de YouTube): «Seguir el vídeo» también sin contestar, o ▶ en el reproductor; en
  ese caso, «Volver a la pregunta». Si ya había respondido y pulsa ▶, sigue con normalidad (evento `answered`,
  añadido en la app).
- Al acabar el clip (2,5 s tras la última jugada del tablero, como en la web), se cierra el vídeo y sigue la
  explicación de la partida. Si el vídeo da error, sigue la lección sin vídeo.

### Piezas

| Pieza | Dónde |
| --- | --- |
| Datos (marcas, pausas, tablero sincronizado y sus posiciones) | `film` de cada clip en `data/cine.json`, de `tools/cine/build.py` (comprueba orden y que nada se destripa) |
| Director (cuándo parar), portado de `src/core/videoCine.ts` con las mismas constantes | `core/cine_film.gd` |
| Puente con el reproductor nativo | `core/cine_player.gd` |
| Reproductor nativo (WebView del sistema + API de iframe) | `android_cine/YouTubeCine.java`, registrado por `addons/youtube_cine` |
| Pantalla | `demo/demo.gd`, sección «El vídeo del final dentro de la app» |
| Pruebas | `tests/test_cine_film.gd` (las del director de la web, con sus números, y los seis clips reales), `tests/test_cine_video.gd` (recorrido entero con un reproductor simulado) |

Sin el complemento (escritorio, pruebas) todo sigue como en la fase 1: «Ver el vídeo» abre YouTube fuera.

### Por comprobar en el móvil

- Que YouTube acepta el reproductor en el WebView con la URL base `https://com.pabloprieto.chessome` (si no, da
  error y la lección sigue sin vídeo).
- Que la pausa cae antes de la jugada (en la web, ±0,1 s) y que «Seguir el vídeo» reanuda sin otro toque.
- Que el vídeo queda exactamente sobre su hueco (píxeles de la ventana de Godot) y se oculta con Opciones.
- Antes de publicar: enlazar las Condiciones de YouTube y su política de privacidad (Políticas III.A).
