# Nivel Kids (desde 8 años)

Decisiones de Pablo (14 nov 2026): dentro de la misma app, como un nivel que el usuario elige; desde los 8 años;
movimientos, fichas y explicaciones muy fáciles; voz con Kokoro.

## Qué es

- **Entrada:** botón «Modo Kids · desde 8 años» en la bienvenida, o el interruptor «Modo Kids» en Opciones.
- **Contenido:** el curso «Aprende a jugar» completo (las mismas posiciones, comprobadas igual) con textos propios
  (`src/course/kids.ts`): frases cortas, de tú, sin notación y sin nombres de casillas (salvo en la lección del
  tablero). Las frases tras cada jugada también tienen su versión Kids (`k` en `godot/data/curso.json`), escrita
  para que haya pocas distintas: así todas pueden llevar voz.
- **Práctica final (para todos):** unidad «Practica el mate» con 12 mates en una jugada de partidas reales de
  Lichess (CC0), los más fáciles y populares del paquete, con piezas variadas y una sola jugada que da mate. Si en la
  partida jugaban negras, la posición se da la vuelta (`mirrorFen`) para que siempre jueguen blancas.
- **Pista** en los ejercicios de jugada (también fuera del nivel Kids): señala la pieza que hay que mover.
- **Fuera del nivel Kids:** test de nivel, entrenamiento con problemas, niveles, «Analizar en Lichess», «Pregunta a
  una IA» y cualquier enlace. En el nivel Kids solo se llega al curso.
- **Salir del nivel Kids** pide una multiplicación (6–9 × 6–9) con tres respuestas: una puerta para adultos sencilla.
  Entrar no la pide.

## Aspecto (14 nov, petición de Pablo)

- Iconos a color en los botones (Fluent Emoji de Microsoft, estilo Flat, licencia MIT; `tools/ui/kids.mjs`):
  bombilla, flechas, casa, engranaje, caballito de tiovivo para «Partida», etc. Si un icono no tiene versión Kids,
  se usa el normal.
- Fondo de peluches y juguetes en tonos pastel (osito, cometa, globo, pato, pelota, cohete, tren, dado…), en mosaico
  sobre el cielo y en las páginas, y dentro de la ventana del resultado.
- El tablero no se mueve en las lecciones ni en las partidas (para todos, no solo en Kids). Al acabar un ejercicio,
  el resultado y los botones (Repetir / Siguiente) salen en una ventana semitransparente encima del tablero.

## Voz

- Kokoro-82M (pesos Apache-2.0), voz española `ef_dora` por defecto (hay también `em_alex` y `em_santa`; muestras en
  la versión preliminar «voces-muestra» del repositorio).
- Para el español, Kokoro fonetiza con espeak-ng, que es GPL-3.0. Por eso la voz **no se genera en el móvil**: la CI
  (`.github/workflows/voz.yml`, rama `voz-fetch` → `voz-src`) genera un OGG por frase con `tools/voz/generar.py` y en
  la app solo van los audios (`godot/voz/<id>.ogg`). El id es un resumen del texto: si una frase cambia, su audio
  también.
- Flujo: `npm run course` → `npm run voice` (escribe `tools/voz/lineas.json` y `godot/data/voz.json`) → push a
  `voz-fetch` → copiar `godot/voz/` de la rama `voz-src`.
- La prueba `godot/tests/test_course.gd` comprueba que cada frase Kids está en el índice de la voz. Una frase sin
  audio no rompe nada: simplemente no suena.

## Google Play

- Público objetivo: declarar **9–12 años y mayores** (público mixto) y cumplir la política de familias. Pablo prefería
  no declararlo; se decidió declararlo porque Google revisa la ficha y el contenido, y la app no tiene anuncios,
  cuentas ni analítica, así que cumplir sale barato.
- Pendiente antes de publicar: política de privacidad, revisión de SDK, revisión legal (LOPDGDD art. 7: menores de
  14 y consentimiento de los padres si se recogieran datos; ahora no se recoge ninguno).
- Sin verificar: si el cine (vídeos de YouTube, rama `cine-video`) es compatible con la política de familias. Si
  entra en main, no debe aparecer en el nivel Kids.

## Pendiente

- Piezas «Cuarto de juegos» (modelos 3D nuevos): de momento el nivel Kids usa las figuras o las fichas.
- Minijuegos con pocas piezas (la guerra de peones, mates básicos contra un rival que se mueve).
- Probar con niños de verdad: ¿se entienden las frases? ¿la voz va demasiado rápida?
