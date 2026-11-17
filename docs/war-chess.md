# War Chess

Modalidad experimental (rama `war-chess`). Se juega exactamente igual que el ajedrez y se le van añadiendo
reglas una a una. Por ahora solo contra el ordenador: **no** hay War Chess online ni en Kids, y sus partidas no
cuentan para el nivel de juego ni para los retos (como las demás variantes).

Dónde: **Jugar una partida → Modalidad → War Chess**.

## Regla 1 — Blindaje (17 nov 2026)

Lo que pidió Pablo:

- Todas las piezas salvo el rey pueden mover como siempre **o blindarse**. Blindarse gasta el turno.
- Con blindaje, la pieza se dibuja con un escudo al lado y su casilla se tiñe levemente de rojo.
- Una pieza blindada puede ser atacada por cualquier pieza. El ataque le quita el blindaje.
- Al perder el blindaje, la pieza se sacude sobre su casilla con un golpe metálico (una sacudida corta, que no
  entorpezca el juego).
- Cada pieza se puede blindar una vez.

### Ajustes del 17 nov (01:45, decididos por Pablo)

- **Peón atrincherado**: el blindaje de un peón aguanta **dos golpes** de cualquier pieza que no sea un peón (el rey
  incluido); un peón lo rompe a la primera. El daño se acumula: tras el primer golpe, el siguiente lo rompe venga de
  quien venga. Cada golpe, también el primero, reinicia la cuenta de 50 jugadas. Las demás piezas siguen con un
  golpe. Objetivo: que el que defiende gane un tiempo cuando le atacan «desde arriba» y premiar el ataque con peones
  (romper peones con peones).
- **Sin blindajes seguidos**: un bando no puede blindar en dos turnos seguidos suyos. Si acabas de blindar, la
  etiqueta lo dice («Blindar: el turno que viene») y el botón no aparece.
- Se ve así: el peón atrincherado lleva **dos escudos** superpuestos (el número de escudos = golpes que aguanta). El
  primer golpe de una pieza hace saltar el de atrás, agrietado, y el de delante da un respingo y se queda.
- FEN: `war:<blindadas>:<gastadas>:<agrietadas>:<último>` (se siguen leyendo los de tres campos).

### Sin tercera repetición (17 nov, 02:05, decidido por Pablo tras comparar con otros juegos)

- Es **ilegal** una jugada que deje por tercera vez una posición ya vista (colocación, turno, enroques, al paso y
  blindajes), como en Arimaa (y parecido al superko del go). Quien solo tiene jugadas así, **pierde**. Desaparece
  el jaque perpetuo como recurso de tablas.
- Si el jugador toca una casilla y la regla le había quitado alguna jugada, la nota lo explica.
- El texto del peón pasa a «trinchera»: «solo otro peón la rompe de un golpe; las piezas necesitan dos».
- `WarChess.seen` (posiciones vistas) lo pone la partida desde su historial (`demo._war_sync_seen`); se comparte
  entre copias. El rival solo lo usa en la primera jugada de su búsqueda.

### Decisiones tomadas al implementarla (cambiables)

| Duda | Decisión | Por qué |
|---|---|---|
| ¿Se lleva la pieza el blindaje al moverse? | **No: lo pierde al mover** (`WarChess.ARMOR_TRAVELS = false`). | Si viajara, una dama blindada podría dar jaque pegada al rey sin que nadie pudiera quitarla (golpearla no la retira) y casi cualquier ataque sería gratis. Así el blindaje es una posición fortificada, que es lo que dice la casilla roja. |
| ¿Dónde queda la pieza atacante? | **En su casilla.** Golpear gasta el turno. | Es lo más simple de leer: el golpe no cambia nada más. |
| ¿Blindarse saca del jaque? | **No.** Y golpear a la pieza blindada que da jaque tampoco lo resuelve (sigue ahí). | Coherente con las reglas del ajedrez: una jugada legal no puede dejar al rey atacado. |
| Peón que golpea en la última fila | **No corona** (no se mueve). Una sola jugada. | |
| Al paso contra un peón blindado | No hay captura (solo podría pasar si el blindaje viajara). | |
| Coronar | La pieza nueva conserva lo de su peón: si ya gastó el blindaje, no lo recupera. | |
| Cuenta de 50 jugadas | Blindarse cuenta como jugada normal; golpear la reinicia (como una captura). | Los golpes están acotados (≤ 15 por bando), así que no alargan la partida sin fin. |
| Repetición | La posición incluye los blindajes. | |

### ¿Se puede atascar?

No. Cada pieza se blinda una vez, así que en toda la partida hay como mucho 15 blindajes y 15 golpes por bando;
las reglas de 50 jugadas y de triple repetición siguen. En las pruebas (`tests/test_war.gd`), el rival contra sí
mismo termina sus partidas o llega al límite de jugadas sin problemas.

Lo que sí cambia y hay que vigilar jugando:

- **Casi no hay ahogado ni zugzwang** mientras quede un blindaje: blindarse es una jugada que no mueve nada.
- Riesgo de juego defensivo (blindarlo todo). Cuesta un tiempo por pieza y el rival lo recupera golpeando, así que
  no debería compensar, pero hay que probarlo.

### Ideas apuntadas para probar después

- **Límite de blindajes por bando** (Pablo, 17 nov: «quizás haya que meter un máximo»). Propuesta: 3 por bando;
  lo convierte en un recurso escaso y la partida va más rápida. La etiqueta «Blindajes: tú N · rival N» ya lo
  enseña.
- **Alternativa de Pablo (17 nov): quitarse el blindaje gasta un turno.** La pieza blindada no puede moverse
  mientras lo tenga; para moverla, primero hay que gastar un turno en quitárselo. Si está amenazada, o se espera a
  que la amenaza desaparezca, o se quita el blindaje y entonces puede ser capturada. Diferencias con lo
  implementado: aquí moverse quita el blindaje gratis (en la misma jugada); con su idea, cuesta un tiempo más y la
  pieza queda inmóvil mientras está blindada. Falta decidir si una pieza blindada inmóvil sigue atacando (dando
  jaque, cubriendo casillas): lo natural es que sí. Sería fácil de cambiar en `core/war_chess.gd` (una jugada
  «desblindar» y quitar las jugadas normales de las piezas blindadas).

## Cómo se ve y cómo se juega

- **Blindar**: al seleccionar una pieza que puede blindarse aparece, flotando junto a ella, una pastilla con el
  escudo y «Blindar». Se coloca donde no tape ninguna casilla a la que pueda ir la pieza. No es un doble toque sobre
  la pieza a propósito: blindarse sin querer costaría un turno.
- **Escudo**: arte propio (`tools/war/escudo.py` → `godot/board3d/escudo.bin` y `escudo_roto.bin`): escudo de
  punta con ribete de latón, campo rojo, cheurón de acero y umbo; sin cruces ni símbolos con otro significado.
  Va a la derecha de la pieza, a media altura, siempre visible.
- **Casilla roja**: canal A de la textura de estado del tablero (128 = blindada); los dos sombreadores de las
  casillas la tiñen de rojo suave.
- **Ataques que solo rompen un blindaje**: al seleccionar la atacante, esa casilla se marca con un anillo rojo
  discontinuo (no con el anillo de captura).
- **Blindarse**: el escudo baja con un pequeño rebote, la pieza se agacha un poco «como quien se cubre» y suena
  una chapa de metal.
- **Golpe**: la atacante embiste un tercio del camino y vuelve; el escudo se hincha un instante ya agrietado, saltan
  chispas, sale despedido girando y se desvanece; la pieza golpeada da una sacudida corta (tres vaivenes en 0,22 s)
  con un golpe metálico. En «Completas» dura unos 0,4 s; «Rápidas», un 30 % menos; «Mínimas», sin embestida;
  «Sin», solo el sonido. La posición cambia antes de la animación: nunca bloquea el juego.
- **Notación**: blindarse `[Cf3]`; golpear `Ax[f7]`.
- **Pista**: si lo mejor es blindarse, se marca la pieza con la chapa del escudo (no hay flecha).

## Sonidos

Grabaciones CC0 del paquete «100 CC0 metal and wood SFX», de rubberduck (OpenGameArt), las mismas que ya usa la
app, preparadas con `tools/assets/prepare-sounds.py` (recorte, entrada y salida suaves, nivel). Elegidas por
medidas, sin oírlas: hay que juzgarlas en el móvil.

| Archivo | Origen | Uso |
|---|---|---|
| `golpe_metal_1.wav` | `metal_hit_03` | Golpe al blindaje (con cuerpo grave) |
| `golpe_metal_2.wav` | `metal_hit_01` | Golpe al blindaje (más agudo y corto) |
| `blindaje.wav` | `metal_sheet_01` | Blindarse |

## El rival

`core/bot.gd` juega War Chess con las mismas reglas (`WarChess` hereda de `Chess`). Evaluación: un blindaje sin
usar vale 6 centipeones; una pieza blindada no suma nada por estarlo (lo que vale el blindaje, que el ataque no la
capture, ya lo ve la búsqueda). Con un premio fijo por blindar, el rival se pasaba la partida blindando. Los
niveles flojos blindan más (sus jugadas al azar incluyen blindajes). La fuerza de los niveles **no está medida**
en War Chess.

## Archivos

- `godot/core/war_chess.gd` — reglas (blindaje, FEN con el campo `war:<blindadas>:<gastadas>`).
- `godot/board3d/board_3d.gd` — escudos, casilla roja, animaciones; `board_view_3d.gd` — botón «Blindar».
- `godot/demo/demo.gd` — modalidad en «Jugar una partida», notas del rival, pista, etiqueta de blindajes.
- Pruebas: `tests/test_war.gd` (reglas, notación, rival, tablero) y `tests/test_war_app.gd` (la app entera).
  Capturas: `tests/war_shots.tscn` (en la CI, junto a las del tablero).

## Simulación (17 nov, 01:30): ¿cambia algo o solo alarga un turno?

`tests/sim_war.gd`: el rival contra sí mismo, nivel Medio 2 (profundidad 3, 0,1 s por jugada), 14 partidas de War
Chess y 14 de ajedrez clásico con las mismas semillas (las dos primeras jugadas de cada bando, al azar).

| | Clásica | War Chess |
|---|---|---|
| Medias jugadas por partida (media / mediana) | 111 / 104 | 119 / 113,5 |
| Final | 12 mates, 2 repeticiones | 12 mates, 1 repetición, 1 al límite de 240 |
| Blindajes por partida | — | 6,6 (49 con la pieza atacada, 44 sin amenaza) |
| Golpes a blindajes | — | 28 en 14 partidas |
| Tras el golpe, la pieza cae en la jugada siguiente | — | 9 de 28 (32 %) |
| Tras el golpe, la pieza se salva | — | 19 de 28 (68 %) |
| Piezas que acaban blindadas sin haber recibido un golpe | — | 11 |

Lectura (con cautela: es un rival flojo, sin búsqueda que entienda bien la regla, y pocas partidas):

- **Alarga poco**: unas 8 medias jugadas más (≈ 7 %).
- **En un tercio de los golpes, el blindaje solo retrasó la captura un turno.** En los otros dos tercios la pieza
  se salvó: el dueño usó la jugada que le da el golpe para apartarla o defenderla.
- **La cuenta de tiempos es neutra**: blindarse cuesta un tiempo al que se defiende y romperlo cuesta uno al que
  ataca. En la práctica, blindarse es como «retirarse sin moverse». Su valor real aparece cuando la pieza **no
  puede o no debe moverse**: clavada, bloqueando un peón pasado, tapando un jaque o defendiendo a otra. Es una
  hipótesis: la simulación no mide estos casos todavía.
- Casi la mitad de los blindajes se hacen sin amenaza y muchos no reciben nunca un golpe: tiempos perdidos (sobre
  todo por la poca profundidad del rival).

### Segunda simulación, con el peón atrincherado y sin blindajes seguidos (17 nov, 02:10)

Mismo rival y método; 14 partidas de cada (semillas 1000–1006 y 2000–2006, las mismas en las dos modalidades).

| | Clásica | War Chess v1 | War Chess v2 |
|---|---|---|---|
| Medias jugadas (media / mediana) | 102 / 95 | 119 / 113,5 * | 93 / 84,5 |
| Final | 12 mates, 2 repeticiones | 12 mates, 1 repetición, 1 al límite * | 10 mates, 4 repeticiones |
| Blindajes por partida | — | 6,6 | 3,9 (22 de 55, de peones) |
| Blindajes con la pieza atacada | — | 53 % | 67 % |
| Golpes que rompen / que solo agrietan | — | 28 / — | 13 / 2 |
| Pieza capturada justo tras romperle el blindaje | — | 9 de 28 | 6 de 13 |

\* v1: semillas 1000–1013, ver arriba.

Lectura (muestra pequeña, mucho ruido entre partidas):

- **Ya no alarga**: con las dos reglas nuevas, las partidas duran lo mismo o algo menos que las clásicas.
- **Se blinda menos y mejor**: casi la mitad de blindajes que antes, y dos de cada tres con la pieza amenazada.
  «Sin blindajes seguidos» corta el blindar por blindar.
- **Los peones se blindan mucho (40 %) y las piezas casi nunca los golpean** (solo 2 grietas): un peón blindado
  es, en la práctica, intocable para las piezas. Su efecto está en la estructura, no en los golpes.
- **Más repeticiones** (4 de 14 frente a 2 de 14). Puede ser ruido o el primer síntoma de fortalezas. A vigilar con
  más partidas o con un rival más fuerte.

### Tercera simulación, sin tercera repetición (17 nov, 02:20)

| | Clásica | v2 | v3 (sin repetición) |
|---|---|---|---|
| Medias jugadas (media / mediana) | 102 / 95 | 93 / 84,5 | 136 / 132 |
| Final | 12 mates, 2 repeticiones | 10 mates, 4 repeticiones | 13 mates, 1 al límite de 240 |
| Blindajes por partida | — | 3,9 | 6,2 (44 de 87, de peones) |
| Golpes que rompen / que solo agrietan | — | 13 / 2 | 18 / 5 |

- **Funciona contra las tablas**: ninguna partida acaba por repetición; 13 de 14 terminan en mate.
- **Pero las partidas son más largas** (+33 % frente a la clásica): las que antes acababan en tablas siguen hasta el
  mate (o hasta el límite), y en partidas largas se blinda más.
- Ojo: el rival piensa con tiempo limitado y no siempre juega igual con la misma semilla, así que las comparaciones
  partida a partida son aproximadas. Hace falta probarlo jugando (o con más partidas y un rival más fuerte).

Ideas para que la regla pese más (por probar): límite de 3 blindajes por bando; que golpear un blindaje deje a la
atacante «aturdida» un turno (no puede volver a atacar); o la alternativa de Pablo (quitarse el blindaje gasta un
turno), que encarece blindarse y lo convierte en un compromiso.
