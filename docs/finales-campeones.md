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

## Lo que no hace (fase 2)

- **Vídeo dentro de la app con pausa automática** antes de cada jugada: necesita un WebView nativo (Godot no lo
  trae) y las marcas de tiempo de cada clip verificadas (hoy, las seis están «pending»).
- YouTube: el vídeo se abre fuera, con un enlace; nada de anuncios propios en estas pantallas (regla III.G.1.d de
  YouTube, ver `claude/chessome-cine.md`).
