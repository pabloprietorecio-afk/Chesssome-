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
