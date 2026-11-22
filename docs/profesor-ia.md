# Profesor IA (premium)

Petición de Pablo (21 nov 2026): una IA que corrija al jugador mientras juega, como un profesor, en la versión
premium, y poder activarla para probarla.

## Tutor con Stockfish y lección sobre el tablero (21 nov)
Petición de Pablo: «mandar la jugada a Stockfish», y que el profesor enseñe sobre el tablero qué habría pasado,
moviendo las piezas y pintando flechas mientras lo explica. Además: poder preguntar en cualquier jugada (también si
era la mejor) y distinguir la jugada brillante.
- **Juez: Stockfish**, en el servidor (`worker/src/tutor.js`, ruta `/tutor`). La app manda la posición y la jugada;
  el servidor pregunta a chess-api.com (Stockfish, profundidad 18), dos veces seguidas (antes y después de la
  jugada; en paralelo se colgaba) y valora por la caída de la probabilidad de ganar (fórmula de Lichess): menos de
  5 puntos buena, 5 imprecisión, 10 error, 15 error grave; dejar un mate es error grave; la misma que la del motor,
  «la mejor». **Brillante («!!»)**: la mejor, entregando material, sin estar ya ganado (≤ 97 %) ni perdido (≥ 45 %).
- Devuelve dos líneas de hasta 4 jugadas: lo que pasa con tu jugada y lo que habría pasado con la mejor, cada paso
  con su posición y sus flechas (rojas: lo que queda atacado o se pierde; verdes: lo que se defiende o se gana).
- **Profesor: Claude Sonnet 5.5** (`/tutor/leccion`): con esas líneas ya comprobadas escribe un resumen, una frase
  por jugada y un consejo, en el idioma de la app y al nivel del jugador. No decide nada de ajedrez: solo redacta.
- En la app (`CoachAI.judge_remote`, `lesson_remote`; demo.gd `_on_coach_judged`, `_on_coach_lesson`): tras tu jugada
  salen a la vez el motor local y la petición al servidor. Si Stockfish contesta en 6 s, manda su valoración; si
  no, vale la del motor local (lo de siempre, sin lección). El rival espera a la valoración.
- **«Explícamelo»** en el bloque del profesor, en todas las jugadas con respuesta de Stockfish. Abre la lección en
  el propio tablero: «Lo que jugaste» (rojo) paso a paso y después «Lo que era mejor» (verde), con Cerrar, Anterior
  y Siguiente; al terminar, el tablero vuelve a la partida. En imprecisiones y errores la lección se pide sola; en
  las jugadas buenas, al tocar el botón. Mientras Claude no contesta (o si falla), cada paso lleva el texto que la
  app sabe decir de esa jugada (MoveWhy).
- Límites del servidor: `/tutor` 40 por minuto por IP; `/tutor/leccion` 10.
- Stockfish propio (22 nov, tras más de una hora sin respuesta de chess-api.com): `worker/motor`, Stockfish 19 en un
  contenedor de Cloudflare (Containers, plan Workers Paid de 5 $/mes; 1 vCPU y 6 GiB, 1 s por posición, se apaga
  tras 3 minutos sin consultas). El servidor llega a él por un service binding (`MOTOR`) y, si no contesta, pasa a
  chess-api.com. Si el contenedor no se puede desplegar, el servidor se despliega igual, solo con chess-api.com.
- Coste (precios de octubre de 2026): la lección son unos 900 tokens de entrada y 350 de salida con Sonnet 5.5
  (2 $ / 10 $ por millón): ~0,5 céntimos de dólar por lección.
- Pruebas: `worker/test.mjs` (16, con el motor y Claude simulados), las del despliegue (12.Cge2 de la partida de
  Pablo: error grave, 62 % → 42 %, mejor f4) y `godot/tests/test_tutor.gd` (30, sin red).

- **Parpadeo rosa** (idea de Pablo, 21 nov: a muchos les cuesta localizar «e5» por la notación): en cada paso de
  la lección, las casillas que nombra el texto del profesor (menos las de la propia jugada, que ya van marcadas)
  parpadean en rosa, y su pieza también (Board3D.set_focus; vale para todos los juegos de piezas).

## Preguntas libres y micrófono (21 nov)
Petición de Pablo: preguntar al tutor en cualquier momento, también por voz.
- **Servidor** (`/tutor/pregunta`, `ask` en worker/src/tutor.js): la app manda las 16 últimas jugadas (desde la
  posición de antes), el color del alumno y la pregunta. Claude Sonnet 5.5 contesta como profesor, pero **no
  calcula**: tiene una herramienta, «analizar», que juega una línea desde cualquier posición de esas y pide a
  Stockfish la valoración y cómo seguiría (hasta 3 vueltas). Devuelve `{answer, show}`: el texto y, si quiere
  enseñarla, una línea de hasta 4 jugadas que el servidor comprueba (legal) antes de mandarla. Si la respuesta
  nombra casillas que no salen en los datos, se le pide una vez que las analice o las quite; si insiste, error.
  Límite: 10 por minuto por IP (el mismo que la lección).
- **En la app**: botón redondo con el bocadillo (o el micrófono) en el bloque del tutor, en cualquier momento de
  la partida. Ventana semitransparente y arrastrable con el cuadro de texto, tres ideas para empezar y
  «Preguntar». La respuesta trae «Enséñamelo en el tablero» (la línea se ve como la lección, con flechas) y las
  casillas que nombra parpadean en rosa. Muchas preguntas seguidas (429) o sin conexión: lo dice y deja reintentar.
- **Micrófono**: complemento de Android propio (android_voz/TutorVoz.java + addons/tutor_voz), con el
  reconocimiento de voz del sistema; la app no graba audio, recibe el texto y pregunta directamente. Pide el
  permiso del micrófono la primera vez. Solo en el APK con Gradle (el de «APK (Gradle…)»); en el APK sencillo
  de la CI no hay botón «Hablar», pero el teclado de Android deja dictar.
- Coste estimado (sin medir): 2–4 llamadas a Sonnet 5.5 por pregunta, ~1–2 céntimos de dólar.
- **Pendiente**: que el tutor recuerde las preguntas anteriores de la partida (hoy cada una va sola). Leer la
  respuesta en voz alta: hecho el 22 nov (docs/voz-tutor.md).

## Interruptor «Tutor IA» (21 nov)
En la barra de arriba de todas las partidas contra la app (no en Kids): enciende y apaga el tutor sin ir a
Opciones (es el mismo ajuste). Con reloj, online, variantes o sin partidas gratis sale apagado y atenuado, y al
tocarlo explica por qué.

## 5 partidas gratis para todos (21 nov)
Decisión de Pablo: el profesor va gratis en las 5 primeras partidas de cualquier jugador; después, premium
(`Premium.TRIAL_GAMES`, `trial_used` en user://premium.cfg). Cuenta una partida al mirar la primera jugada y esa
partida sigue con profesor hasta el final. La tarjeta dice «Profesor IA · gratis 2 de 5»; Opciones, cuántas
quedan; la tarjeta, «Gratis 2/5». En las partidas gratis la lección de Claude solo se pide al tocar «Explícamelo»
(en premium, en los fallos se prepara sola). Al acabarse, un aviso una sola vez («hazte premium») y nada más. Kids, online, reloj y variantes: nunca.
Ojo: la compra aún no existe, así que tras las 5 no hay forma de seguir. Y el servidor no distingue a nadie: lo que
cuesta la prueba se paga igual (ver Coste).
Las pruebas y capturas (ejecutable del editor) no llaman al servidor: si no, cada partida de prueba gastaría.

## Qué hace
- En las partidas contra el rival de la app (sin reloj, sin red, fuera de Kids y de las variantes), tras cada jugada
  del jugador el motor de la app la valora en otro hilo (GameDetail.entry, como el detalle de partida): la mejor,
  buena, imprecisión, error o error grave.
- **El material a la vista manda** (CoachAI.judge, 21 nov): la valoración del motor mezcla material y posición y sus
  umbrales son anchos, así que un peón regalado le podía salir «buena» (12.Cge2 dejando e5: «pierde 70»). Ahora, si
  el detector corto (GameReview.analyze_move) ve material a tiro o una captura gratis sin hacer y el motor no ve
  la jugada casi igual que la mejor (más de 30 de pérdida), la valoración sube como mínimo a imprecisión (un peón)
  o error (una pieza), y la explicación es la de ese hecho: qué quedó a tiro y qué jugada lo evitaba.
- Sale la chapa en el tablero y la valoración en la tarjeta, **en todas las jugadas**: «!» la mejor, marca de
  «buena», «?!» imprecisión, «?» error, «??» error grave. «!!» solo con Stockfish (arriba): el motor de la app no es lo
  bastante fuerte para afirmar una jugada brillante.
- **Leyenda encima del tablero** (petición de Pablo, 21 nov): las cinco valoraciones con su chapa y su nombre, y la
  de tu última jugada resaltada (las demás, apagadas). Flota en el hueco entre la barra y el tablero, como la pista
  de gestos. En pantallas sin ese hueco (16:9) o con la pista de gestos a la vista no sale, y la valoración va
  escrita en la tarjeta. La prueba automática corre en 16:9 (sin hueco): la leyenda se comprobó con capturas a
  1080 × 2400, en claro y en oscuro.
- **En la tarjeta, corto; entero, en una ventana**: el bloque del profesor enseña dos líneas como mucho (en los
  textos comprobados, sin la primera frase, que cuenta tu propia jugada: «Permite Cxe4. La mejor era Cc3…») y un
  botón de color «Ver completa»; también vale tocar cualquier punto del bloque. La ventana trae la valoración, la
  explicación entera y «Entendido».
- La ventana es bastante transparente (fondo al 62 %, las demás al 86 %) y **se puede arrastrar** con el dedo para
  destapar el tablero (un asa arriba y una nota abajo lo indican); se abre donde se dejó la última vez.
- Lo que el análisis cuenta de la mejor jugada (que no se jugó) va como hipótesis: «La mejor era h4. Si la hubieras
  jugado: El peón de h4 es pasado…» (antes parecía hablar de un peón que no estaba; GameDetail.after_best, también
  en el detalle de partida). Traducida a los diez idiomas (tools/i18n/trad/ui_profesor.tsv). Ojo: las tablas de
  godot/data/i18n tienen 10 frases que no están en los .tsv; `build.py` las borraría, así que esta se añadió a mano.
- La chapa se queda hasta tu siguiente jugada: el tablero la borra con cada movimiento, así que se repone tras la
  jugada del rival (salvo que capture esa pieza) y al volver de mirar jugadas atrás. El rival espera a que salga
  la valoración (y medio segundo más) antes de mover, como mucho 3 s.
- Imprecisión: la explicación comprobada del análisis (qué hace, qué permite, cuál era la mejor), sin IA.
- Error y error grave: «El profesor está mirando tu jugada…» y la explicación de **Claude Haiku 5.5**, redactada a
  partir de esos mismos hechos. Si nombra una casilla que no está en los hechos, se descarta y queda el texto
  comprobado. Sin red, también.
- Antes (hasta el 21 nov) solo usaba el detector corto de GameReview (pieza a tiro, mate…, dos peones o más):
  callaba casi siempre. Se cambió al motor.
- En el APK de pruebas, una línea gris dice qué ha decidido el profesor y por qué.

## Cómo probarlo (APK de depuración)
1. Opciones → Premium → «Premium de prueba».
2. Pegar una clave de la API de Claude (Claude Console, con saldo) y «Guardar la clave». Se guarda solo en el móvil
   (`user://premium.cfg`).
3. Jugar una partida sin reloj. Sin clave también funciona, con los textos comprobados en lugar de la IA.

En el AAB de publicación no salen ni el interruptor de prueba ni el campo de la clave (`OS.is_debug_build()`).

## Coste
Una petición por error: unos 1.500 tokens de entrada y 150 de salida. Con Haiku 5.5 (0,10 $ / 0,50 $ por millón,
precios de octubre de 2026) son unos 0,0002 $ por corrección; con unos 6 errores por partida, ~0,1 céntimos.
La suscripción de claude.ai no cubre la API: se paga aparte en Claude Console.

## Pendiente para publicar
- **Servidor propio**: hecho en `worker/` (Cloudflare Workers, plan gratuito), se despliega con
  `.github/workflows/worker.yml` cuando están los secretos CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID y
  ANTHROPIC_API_KEY. La app le manda solo los hechos; el prompt y la clave están en el servidor. Límite: 10
  peticiones por minuto por IP. Dirección: https://achessway-profesor.pablo-prieto-recio.workers.dev/profesor
  (`endpoint` de `data/coach_ai.json`; el despliegue la prueba con un error de verdad).
  **No comprueba que el jugador sea premium** (no hay compra real todavía): hasta entonces, la protección es el
  límite por IP y el límite de gasto que se ponga en Claude Console.
- **Compra real** (Google Play Billing): plugin de facturación y producto en Play Console; hoy `Premium.purchased`
  no lo pone nadie.
- Textos nuevos sin traducir (salen en español en los otros idiomas).
- Privacidad: la política y el formulario de seguridad de datos deben decir que la posición y la jugada se envían a
  Anthropic para redactar la explicación (nada personal). La app es de público mixto: revisar la política de
  Familias antes de activarlo en producción.
- Sin verificar en un móvil real.

## Pruebas
`godot/tests/test_profesor_ia.gd` (detección, petición, comprobación de la respuesta, cuándo comenta) y
`godot/tests/test_profesor_app.gd` (la tarjeta en una partida y la sección Premium de Opciones), en la CI.

## Traducciones (21 nov)
Todos los textos del tutor, Robi y las preguntas, en los nueve idiomas: `tools/i18n/trad/ui_tutor.tsv`. Las 10 frases
que solo estaban en las tablas van ahora en `tools/i18n/trad/ui_detalle.tsv`, así que `build.py` ya no borra nada.
Los textos que la app manda a Claude (instrucciones) siguen en español a propósito: Claude contesta en el idioma
de la app. Los textos de depuración (APK de pruebas) no se traducen.

## Correcciones tras la primera prueba de Pablo (21 nov)
- Preguntaba mirando un ejemplo de la lección y el tutor contestaba sobre la partida en directo (le dijo que estaba
  en jaque, que era verdad en la partida pero no en el ejemplo). Ahora la pregunta lleva lo que hay en pantalla
  (`shown`: el paso de la lección, la línea de una respuesta o la jugada a la que se ha vuelto con «Atrás») y el
  servidor lo marca como lo que mira el alumno; la herramienta analiza desde ahí por defecto. Va también el hilo
  (las 3 últimas preguntas y respuestas).
- Apagar el tutor con la lección abierta dejaba el ejemplo en el tablero con la tarjeta de la partida: ahora el
  tablero vuelve a la partida.
- Esperando la respuesta: «El tutor está preparando tu respuesta», bombilla y puntos animados, sin botones; al
  llegar, sale la respuesta.
- Rosa solo en las piezas amenazadas que nombra el texto (no en la que ataca: parpadeaba la dama de b4).
- Lección: el servidor le da a Claude si la jugada para el jaque (y cómo) y qué piezas amenazadas defiende o salva,
  y se le pide que empiece por eso (5.Cbd2 contra Db4+: para el jaque y defiende el alfil de c4 a la vez).

## Valoraciones más justas (21 nov)
Pablo vio «error grave» en jugadas que el propio tutor, al preguntarle, decía que no lo eran.
- Umbrales de chess.com (puntos esperados): imprecisión 5–10, error 10–20, error grave 20 o más puntos de
  probabilidad perdidos (antes, los de Lichess: error grave desde 15; perder un peón en una posición igualada salía
  «error grave»).
- chess-api.com da como mucho 100 ms y profundidad 18, y la valoración salía de dos análisis sueltos (antes y después
  de la jugada): en posiciones tácticas, diferencias falsas. Ahora, antes de marcar «error» o «error grave», se pide
  una segunda opinión: Stockfish valora la posición tras la jugada otra vez (al repetirla, el servicio llega más hondo; `searchmoves` lo ignora); vale la más
  favorable al alumno (`second` en la respuesta). Un mate permitido no se discute.
- Las preguntas llevan cómo se marcó la última jugada (`judged`): si al analizarla el tutor ve otra cosa, lo explica
  con datos en vez de contradecir la marca sin más.
- Un análisis más profundo de verdad necesita Stockfish propio (pendiente antes de publicar).

## Stockfish dentro del móvil (21 nov)
Decisión de Pablo: Stockfish 19 en el propio móvil en vez de un servidor (Cloud Run). Detalle y licencia en
`android_motor/LEEME.md`. Cada jugada: 0,8 s de análisis antes y 0,8 s después, en el móvil; el servidor solo prepara
las líneas con esos análisis (sin chess-api.com) y Claude escribe. Sin conexión, las chapas salen igual (valoración
en el móvil, sin «brillante» ni flechas de amenazas). Las preguntas libres siguen con el Stockfish del servidor.
Opciones → Licencias: aviso de Stockfish, GPL v3 entera y enlace al código de sf_19.

## Oportunidad perdida (22 nov)
Pablo vio «error grave» en 12.d3, una jugada tranquila que no perdía nada: el rival acababa de jugar Ab7 y dejaba e6+
con ataque. Stockfish compara con la mejor jugada, y perder esa ocasión cae como un error. Ahora, como el «Miss» de
chess.com: si la jugada sería error o error grave pero no deja al alumno peor que antes de la jugada del rival (`prev`:
su probabilidad tras su jugada anterior, con 5 puntos de margen), se marca «Oportunidad perdida» (chapa rosa con una
X; en la leyenda, en el sitio de «Error»). El texto: «No pierdes nada, pero el rival te había dejado algo mucho mejor:
e6+». Claude lo explica así (no dice que la jugada sea mala). En el servidor y sin conexión (local_judge).
