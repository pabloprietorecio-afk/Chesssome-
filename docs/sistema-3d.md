# Sistema 3D y pantalla de problema (Godot)

Resumen técnico del tablero 3D y de la pantalla de problema de la app. El diseño razonado (reglas de legibilidad, colecciones, animaciones) está en el
documento del proyecto, apartados 12–14 y «Sistema 3D y de animaciones» del MVP.

## Qué hay

| Componente | Archivo | Qué hace |
| --- | --- | --- |
| Reglas | `godot/core/chess.gd` | Jugadas legales, jaque, mate, enroque, al paso, promoción, FEN |
| Nivel | `godot/core/glicko2.gd` | Glicko-2, igual que `src/core/glicko2.ts` |
| Evaluación | `godot/core/assessment.gd` | Test de nivel, perfil por dimensiones y plan, igual que `src/core/assessment.ts` (ver `docs/evaluacion.md`) |
| Explicaciones | `godot/core/explain_data.gd` | Lee las explicaciones ya redactadas de cada problema (`godot/data/explain/`) y la clase de error de cada jugada |
| Escena | `godot/board3d/board_3d.gd` | Cámara, luces, piezas, casillas, flechas, animaciones y avisos de sonido |
| Control | `godot/board3d/board_view_3d.gd` | Toque, arrastre, promoción, ampliar y girar con dos dedos, fijar el giro, seguir al móvil |
| Sonido | `godot/board3d/board_sounds.gd` | Reproduce las grabaciones de `godot/sounds/` cuando la escena avisa |
| Materiales | `godot/board3d/shaders/` | Realistas: `squares_textured`, `frame_textured`, `piece_textured`, `studio_sky`. Ilustrado: `squares`, `piece`. Fichas: `piece_token`. Comunes: `outline`, `outline_disc`, `soft_shadow` |
| Texturas | `godot/textures/` | Fotografías de madera, mármol y metal (CC0), con su procedencia en `LEEME.md` |
| Colecciones | `godot/sets/clasico/`, `godot/sets/fichas/` | Figuras (seis piezas y el marco, en GLB) y fichas planas (una ficha y el atlas de iconos) |
| Modelado | `tools/pieces/` | Genera los GLB y los iconos desde campos de distancia (código propio) |
| Pantalla | `godot/demo/` | La app: bienvenida, experiencia, test de nivel, resultado y plan, entrenamiento adaptado y progreso, sobre 150 problemas reales (`godot/data/demo_puzzles.json`) |
| Iconos | `godot/ui/` | Atlas de iconos (Phosphor, MIT, y piezas propias) y emblema; los genera `tools/ui/icons.mjs` |
| Tipografía | `godot/fonts/` | Inter e Inter Display (OFL 1.1) |
| Capturas | `godot/tests/shots.gd` | 89 capturas: tablero, fichas, la pantalla de problema y el test de nivel, con toques y gestos simulados |

Renderizador: «Mobile» (Vulkan). Modelos, iconos de las piezas y código de modelado propios. Las texturas de
los acabados realistas son de Poly Haven y ambientCG, y los sonidos de OpenGameArt y Versilian Studios; todo
bajo CC0. Los iconos generales de la interfaz son de Phosphor Icons (MIT).

## Uso de `BoardView3D`

```gdscript
var view := BoardView3D.new()
add_child(view)
view.set_fen("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")
view.set_orientation(0)                 # 0 = blancas abajo, 1 = negras abajo
view.move_played.connect(func(uci): print(uci))
view.show_move("f1b5")                  # jugada del rival o de la solución, animada
view.board.anim_mode = Board3D.Anim.FULL  # FULL, FAST (por defecto), MINIMAL, NONE
view.set_board_theme("dark", Color("0a0f1e"))  # tema y color de fondo de la pantalla que lo contiene
view.edge_fade = 48.0                   # franja en la que la vista se funde con ese fondo, arriba y abajo
view.board.fit_pad = Vector4(0.012, 0.06, 0.012, 0.08)  # margen del encuadre: izquierda, arriba, derecha, abajo
view.set_board_style("marmol")          # acabado: "madera", "marmol", "metal" o "ilustrado"
view.board.set_outline(true)            # contorno de tinta (por defecto, solo en el ilustrado)
view.set_piece_set("fichas")            # juego de piezas: "clasico" (figuras) o "fichas"
view.set_sound_enabled(false)           # sonido de las jugadas
view.center_view()                      # vista en picado; default_view() vuelve a la inclinada (las dos deshacen el zoom)
view.reset_zoom()                       # tablero entero otra vez, sin cambiar inclinación ni giro
view.set_tilt_enabled(true)             # seguir la inclinación y el giro del móvil
view.set_view_locked(true)              # fijar la vista actual
```

## Acabados

| Acabado | Tablero | Piezas | Notas |
| --- | --- | --- | --- |
| Madera (por defecto) | Taracea de arce y nogal, marco de palisandro, barnizado | Boj claro y ébano | Veta en vertical en las piezas |
| Mármol | Mármol crema y pizarra azulada, pulido | Mármol blanco y negro veteado | Sin barniz: brilla la propia piedra |
| Metal | Acero cepillado, con el cepillado cruzado entre casillas | Latón y acero oscuro | Las piezas reflejan el entorno de estudio |
| Ilustrado | Azul cielo liso | Porcelana marfil y azul tinta, con contorno | El estilo de la primera versión |

- Los tres realistas son **datos** (`Board3D.FINISHES`): texturas, tintes, tamaño de la veta, brillo, barniz, metal y
  luz de cada uno. Añadir otro es añadir una entrada y sus texturas.
- **Regla de contraste:** el tablero abarca los tonos medios y las piezas, los extremos. Las claras son más claras
  que las casillas claras y las oscuras, más oscuras que las casillas oscuras.
- **Reflejos:** un entorno de estudio dibujado por código (`studio_sky.gdshader`: paredes claras, suelo cálido y
  cuatro cajas de luz) da la luz ambiente y los brillos. No se ve de fondo y gira con el lado del jugador.
- **Texturas:** se proyectan por los tres ejes en las piezas (no tienen coordenadas de textura); en el tablero,
  cada casilla toma un trozo distinto. Se importan comprimidas y con mipmaps (`importer_defaults` en `project.godot`).
- **Contorno de tinta:** opcional en cualquier acabado; por defecto solo lo lleva el ilustrado.

## Cómo se dibuja

- **Vista opaca con el fondo igualado.** La vista 3D pinta su fondo del mismo color que la pantalla y se funde
  con ella por arriba y por abajo: no se nota dónde acaba. El color se calcula con la inversa del tonemapper
  fílmico (`Board3D.pre_tonemap`). No sirve una vista transparente: el renderizador «Mobile» guarda solo 2 bits
  de alfa y las sombras suaves salen a franjas (comprobado en la CI).
- **Píxeles reales.** `BoardView3D` es un `Control`; dentro lleva la vista 3D al tamaño en píxeles del
  dispositivo y la escala para ocupar el control. Así el tablero sale nítido aunque el lienzo de la interfaz
  esté en otras unidades. Los toques se convierten con `local_to_view` y `view_to_local`.
- **Encuadre.** La cámara se coloca a la menor distancia a la que caben el marco y las piezas dentro de la
  vista con su margen (`fit_pad`). En un móvil en vertical manda el ancho: el tablero va de lado a lado.
  Campo de visión de 14° e inclinación de 64°: la fila del fondo mide un 90 % de la de delante.
- **Contorno.** Cada pieza se dibuja otra vez engordada 0,026 casillas y solo por sus caras traseras («casco
  invertido»), más un disco bajo la base: una línea de tinta de grosor constante. Al seleccionar, la línea se
  vuelve del color de acento.
- **Coordenadas dentro de las casillas del borde**, pegadas al canto, para que el marco pueda ser fino.

## Gestos

| Gesto | Qué hace |
| --- | --- |
| Un dedo sobre una pieza propia | Seleccionar; tocar el destino o arrastrarla para jugar |
| Pellizco con dos dedos | Ampliar o reducir alrededor de los dedos, de ×1 (tablero entero) a ×3. El tablero puede ser más ancho que la pantalla |
| Girar dos dedos (como un mapa) | Gira el tablero lo mismo que los dedos y hacia el mismo lado |
| Dos dedos a la par | Con el tablero ampliado, desplazarlo. Sin ampliar, inclinar y rodear la vista |
| Un dedo desde donde no hay pieza propia | Con el tablero ampliado, desplazarlo |
| Chincheta (barra superior) | Fija el giro: ni los dedos ni el móvil giran o inclinan el tablero. Ampliar y desplazar siguen funcionando |
| Botón de vista | Si está ampliado, lo deja entero. Si no, alterna entre inclinada y en picado (y lo endereza) |

- La ampliación estrecha el campo de visión (no acerca la cámara), así la perspectiva no cambia.
- El desplazamiento se limita: el tablero siempre cubre la zona que ocupaba sin ampliar.
- El gesto de dos dedos se decide en los primeros 14 px según lo que más pese: separar los dedos (ampliar),
  girarlos (girar el tablero) o llevarlos a la par (inclinar o desplazar). Mientras se amplía, el tablero no gira.
- **Se endereza solo.** Si al soltar los dedos el tablero queda a menos de 8° de estar derecho, vuelve a 0°: un
  giro tan pequeño suele ser sin querer (Pablo lo vio en su móvil: el tablero quedaba torcido).
- Un pellizco mínimo (menos de ×1,12) tampoco amplía: vuelve al tablero entero.
- **Pista de gestos.** En el hueco de encima del tablero, una animación pequeña (dos dedos que se separan y
  luego giran, con un tablerito que crece y gira) y el texto «Amplía y gira con dos dedos». Viene activada, y
  se apaga sola la primera vez que el jugador amplía, gira o desplaza el tablero (`BoardView3D.view_gesture`).
  Se puede volver a encender en Opciones. Solo se enseña si cabe y si el giro no está fijado.
- La ampliación se conserva de un problema al siguiente; el giro fijado y la pista, entre sesiones.

## Fichas

Segundo juego de piezas (`Board3D.PIECE_SETS`): una ficha plana, la misma para todas, con el icono de cada pieza
en bajorrelieve. Se combina con cualquier acabado.

- **Los iconos son propios.** `tools/pieces/fichas.mjs` mira de perfil las piezas de la colección clásica (el rey,
  de frente, para que se vea la cruz), las ensancha un poco y guarda, por cada punto, hacia dónde mira la
  superficie (aplanada como en una medalla), la distancia al contorno y la sombra de los recovecos. Es un atlas
  de datos de 3 × 2 iconos (`godot/sets/fichas/iconos.bin`: un PNG con otra extensión para que Godot no lo
  comprima con pérdida).
- **El material** (`piece_token.gdshader`) usa esos datos: el relieve responde a la luz de la escena y el borde
  del icono sale nítido a cualquier ampliación. El cuerpo es del material de su bando y el icono, del material
  del bando contrario (boj con ébano, mármol blanco con negro, latón con acero).
- Los iconos quedan derechos para quien juega abajo, sea cual sea el color de la ficha.
- Al no haber piezas altas, el tablero se encuadra algo más grande (`FIT_HEIGHT_TOKENS`).
- La ficha tapa casi toda su casilla, así que el **jaque** tiñe de rojo la ficha del rey. En el **mate**, la ficha
  del rey se da la vuelta y queda bocabajo.

## Sonido

`Board3D` emite la señal `sound(kind, amount)` en los momentos que suenan y `BoardSounds` pone la grabación:

| Aviso | Cuándo | Grabación |
| --- | --- | --- |
| `slide` | La pieza empieza a deslizarse (`amount` = lo que tarda en llegar; el roce se apaga justo antes) | `arrastre_1…3` |
| `place` | La pieza se asienta (también al soltarla con el dedo y la torre del enroque) | `posar_1…3` |
| `capture` | Se asienta capturando | `captura_1…2` |
| `check` | Jaque | `jaque` (dos golpes de timbal a un semitono) |
| `fall` | El rey toca el tablero en el mate | `caida_rey` |

El caballo salta: no se arrastra. Si las animaciones se cortan con un toque, los avisos pendientes se pierden.
Cada vez se elige una grabación al azar y se varía un poco el tono. Procedencia y licencias (todas CC0), y los
límites de estas grabaciones, en `godot/sounds/LEEME.md`.

## Explicaciones y pantalla de problema

- **Las explicaciones viajan redactadas.** `npm run godot:demo` (`scripts/export-godot-demo.ts`) genera, con la
  misma capa explicativa del prototipo web, una explicación por cada jugada legal de cada punto de decisión
  (11.575 para los 150 problemas, 11,3 MB) y la del problema resuelto. La app no redacta ni calcula ajedrez
  nuevo. Tras regenerarlas hay que regenerar también los datos de oro (`npm run golden`).
- **Test de nivel, perfil y plan**: ver `docs/evaluacion.md`. La app arranca por la bienvenida, la pregunta de
  experiencia y el test; después entrena con problemas elegidos por el nivel y los puntos flojos. El jugador
  se guarda en `user://chessome_jugador.json`.
- **Si el jugador falla**, la tarjeta cuenta qué hace su jugada y qué permite, con la variante para verla en
  el tablero, pero no dice cuál era la mejor: puede reintentar.
- **Ayuda graduada mientras se resuelve** (barra del pie, también tras un fallo), de menos a más:
  - **Pista**: la primera vez, el tema del problema («Busca esto: clavada»); la segunda, además, qué pieza hay
    que mover, que queda elegida en el tablero con sus destinos. Nunca dice la jugada. El tema viene de las
    etiquetas de Lichess; los que no orientan («Ventaja clara») se saltan.
  - **Un paso**: juega solo la jugada que toca y explica por qué es esa (la misma explicación de cuatro
    niveles). Con «Seguir», responde el rival y el jugador continúa con el resto del problema.
  - **Solución**: enseña la solución entera, como antes.
  - **Saltar**: pasa al problema siguiente.
- **Al resolver o pedir la solución**, cuatro niveles con «Explícame por qué»: qué ha pasado, el concepto (con
  flechas sobre la posición de la decisión), la variante jugada a jugada y las cifras del motor. «Datos de la
  posición» (de dónde sale cada dato) solo aparece en el último nivel.
- **Ayudas** (`docs/ayudas.md`): «¿Y si juego…?», «Analizar en Lichess» (abre el navegador) y «Pregunta a una
  IA» (copia el texto con la posición y el análisis, o abre Google en Modo IA). En Android no hay menú de
  compartir del sistema sin un complemento propio: de momento, copiar.
- La tarjeta mide lo que su contenido y, si no cabe, se desplaza. El tablero sube cuando la explicación pide
  sitio y no vuelve a bajar hasta el problema siguiente.
- **Bienvenida** de primer uso (también en Opciones → «Cómo se usa Chessome»), **ajustes guardados**
  (`user://chessome.cfg`) y **versión de la app** al pie de Opciones (la escribe la CI en `data/version.json`).

## Diseño de la interfaz

Decisiones de Pablo tras probar la versión 35 en su móvil (13 nov): todo se veía pequeño; aire de app móvil
(inspiración en los diseños de Apple), tonos pastel, iconos grandes y botones ilustrados; y **la app no explica
cómo funciona por dentro** (nada de «cada frase sale del análisis de un motor»).

- **Letra.** El lienzo mide 1080 unidades de ancho y un móvil corriente unos 393 puntos: un punto son unas
  2,75 unidades. El cuerpo iba a 33 unidades (12 puntos, pequeño); ahora va a 42 (15 puntos). Escala en
  `demo.gd`: `F_LARGE` 100, `F_TITLE` 66, `F_TITLE2` 58, `F_HEAD` 46, `F_BODY` 42, `F_SUB` 38, `F_FOOT` 34,
  `F_CAP` 30. Ningún texto baja de 30 (11 puntos).
- **Tonos pastel.** Seis tonos (melocotón, menta, lila, cielo, mantequilla y rosa), cada uno con su fondo y su
  tinta, en claro y en oscuro (`TINTS_LIGHT`, `TINTS_DARK`). El acento pleno (un naranja suavizado) solo
  aparece en el botón que hace avanzar.
- **Iconos.** `UiIcons` (`godot/ui/`): un atlas en blanco con transparencia que la app tiñe al dibujar. Los
  generales son de Phosphor Icons (MIT), en su variante de dos tonos; las piezas y el emblema salen de nuestras
  piezas 3D. Se generan con `npm run ui:icons` (`tools/ui/icons.mjs`); procedencia en `godot/ui/LEEME.md`.
- **Botones ilustrados** (`_button`): icono y texto, en fila o con el icono encima. La barra de ayuda son
  cuatro teselas pastel con su icono; las ayudas de después del problema, tres teselas grandes; en Opciones,
  figuras y fichas se eligen por su dibujo y los acabados por sus dos colores de pieza.
- **Bienvenida**: emblema (el caballo en relieve sobre una tesela pastel), nombre, una frase y cuatro ideas con
  su icono grande; el botón «Empezar», siempre a la vista al pie.
- **Textos.** La app dice qué puede hacer el jugador, no cómo está hecha. Las cifras del motor siguen en el
  cuarto nivel de la explicación, para quien las pide.

## Reglas del sistema

- La posición lógica cambia al instante; la animación es solo presentación y cualquier toque la termina
  (`finish_animations()`).
- Las señales (última jugada, selección, jaque, destinos, sombra de contacto) se pintan en el material de las casillas
  a partir de una textura de estado de 8×8. Nada flota sobre las piezas.
- El toque comprueba primero el cilindro de cada pieza y después la casilla del plano.
- Con un dedo en la pantalla, la vista no se mueve aunque esté activo «Seguir al móvil».
- Una colección es una carpeta `godot/sets/<id>/` con `pawn, knight, bishop, rook, queen, king, board` en GLB.

## Generar piezas

```bash
node tools/pieces/generate.mjs clasico            # todas las piezas → godot/sets/clasico/*.glb
node tools/pieces/generate.mjs clasico knight     # una sola
node tools/pieces/board.mjs                       # marco del tablero
node tools/pieces/fichas.mjs                      # ficha e iconos → godot/sets/fichas/ (y shots/fichas-iconos.png)
node tools/pieces/preview.mjs clasico lineup top  # vistas previas locales en shots/pieces-*.png
```

Las partes de revolución se mallan de forma exacta (`latheMesh`); el resto, con «surface nets», relajación y
oclusión ambiental guardada por vértice.

## Verificación

Godot no se ejecuta en local en este proyecto: todo pasa por la CI (`.github/workflows/ci.yml`).

- Pruebas de oro: `godot/tests/test_chess.gd` (3.944 comprobaciones contra chess.js) y `test_glicko2.gd` (1.033).
  `npm run golden` regenera los datos y `tests/golden-godot.test.ts` falla si quedan desfasados.
- `godot/tests/test_explain.gd`: cada jugada legal de cada punto de decisión tiene su explicación (ni una más ni
  una menos), con sus cuatro niveles y su clase de error, y todas las variantes se pueden jugar legalmente con
  las reglas en GDScript (11.575 explicaciones).
- `godot/tests/test_assessment.gd`: el test de nivel, el perfil y el plan dan lo mismo que el núcleo TypeScript
  (ocho jugadores simulados).
- Capturas: la CI dibuja con Vulkan por software (lavapipe) a 1080 × 2400 y las publica en la rama `ci-shots`
  (las demás ramas, en `ci-shots-<rama>`). `scripts/ci-wait.sh` espera a la CI del último commit y las descarga
  en `shots/ci/`.
- La CI falla ante cualquier error de guion o de sombreador.
- APK de prueba con enlace fijo:
  https://github.com/pabloprietorecio-afk/Chesssome-/releases/download/ultimo-apk/Chessome-debug.apk

## Sin verificar

- Rendimiento, batería y tacto en un teléfono real.
- **Cómo suenan los sonidos**: se eligieron por medidas (duración, golpes, espectro), sin oírlos, y en la CI no
  hay audio. Hay que juzgarlos de oído en un teléfono.
- Que «Analizar en Lichess», «Abrir en Google» y copiar al portapapeles funcionen en el teléfono (en la CI solo
  se comprueba el texto y la dirección).
- Sentido del giro al seguir al móvil (`ROLL_SIGN` y `TWIST_SIGN` en `board_view_3d.gd`): si va al revés, se cambia el signo.
- El tacto del pellizco, del giro y del arrastre con dedos de verdad (en la CI se simulan los toques).
- Que la letra tenga ya buen tamaño en el teléfono de Pablo (la medida es por cálculo: 15 puntos de cuerpo).
- Comportamiento en teléfonos sin Vulkan.

## Pendiente

- Tablero 2D en Godot con la misma interfaz y alternancia 2D/3D para medir H3.
- Con el tablero ampliado, llevar la vista a la jugada del rival si cae fuera de la pantalla.
- Paisaje con el tiempo real en el cielo de la pantalla de problema (hoy es un cielo quieto).
- Problemas fáciles (por debajo de 1100): la muestra casi no tiene y el test no mide bien a quien empieza.
- Posiciones para medir desarrollo, seguridad del rey y estrategia (hoy «sin medir»).
- Curso de reglas para quien nunca ha jugado.
- Pantalla de licencias en la app (Phosphor Icons pide conservar su aviso MIT) antes de publicarla.
- Icono de la app en el lanzador de Android con el emblema nuevo.
- Sonidos por material (mármol, metal) y grabaciones de piezas de ajedrez de verdad.
- Menú de compartir del sistema en «Pregunta a una IA» (necesita un complemento de Android).
- Niveles de calidad y pausa del dibujo en reposo.
- Partículas, sonido y bandeja de capturas.
- Hoja de animación por colección (datos) y más colecciones.
