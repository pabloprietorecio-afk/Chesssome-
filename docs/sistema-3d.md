# Sistema 3D (Godot)

Resumen técnico del tablero 3D. El diseño razonado (reglas de legibilidad, colecciones, animaciones) está en el
documento del proyecto, apartados 12–14 y «Sistema 3D y de animaciones» del MVP.

## Qué hay

| Componente | Archivo | Qué hace |
| --- | --- | --- |
| Reglas | `godot/core/chess.gd` | Jugadas legales, jaque, mate, enroque, al paso, promoción, FEN |
| Nivel | `godot/core/glicko2.gd` | Glicko-2, igual que `src/core/glicko2.ts` |
| Escena | `godot/board3d/board_3d.gd` | Cámara, luces, piezas, casillas, flechas, animaciones |
| Control | `godot/board3d/board_view_3d.gd` | Toque, arrastre, promoción, giro con dos dedos, seguir al móvil |
| Materiales | `godot/board3d/shaders/` | `piece`, `outline`, `outline_disc`, `squares`, `soft_shadow` |
| Colección | `godot/sets/clasico/` | Seis piezas y el marco, en GLB |
| Modelado | `tools/pieces/` | Genera los GLB desde campos de distancia (código propio) |
| Demo | `godot/demo/` | Pantalla de problema con problemas reales de `godot/data/demo_puzzles.json` |
| Tipografía | `godot/fonts/` | Inter e Inter Display (OFL 1.1) |
| Capturas | `godot/tests/shots.gd` | 16 capturas del tablero y 10 de la demo con toques simulados |

Renderizador: «Mobile» (Vulkan). Sin modelos, texturas ni código de modelado de terceros.

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
view.center_view()                      # vista en picado; default_view() vuelve a la inclinada
view.set_tilt_enabled(true)             # seguir la inclinación y el giro del móvil
view.set_view_locked(true)              # fijar la vista actual
```

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
node tools/pieces/preview.mjs clasico lineup top  # vistas previas locales en shots/pieces-*.png
```

Las partes de revolución se mallan de forma exacta (`latheMesh`); el resto, con «surface nets», relajación y
oclusión ambiental guardada por vértice.

## Verificación

Godot no se ejecuta en local en este proyecto: todo pasa por la CI (`.github/workflows/ci.yml`).

- Pruebas de oro: `godot/tests/test_chess.gd` (3.944 comprobaciones contra chess.js) y `test_glicko2.gd` (1.033).
  `npm run golden` regenera los datos y `tests/golden-godot.test.ts` falla si quedan desfasados.
- Capturas: la CI dibuja con Vulkan por software (lavapipe) a 1080 × 2400 y las publica en la rama `ci-shots`
  (las demás ramas, en `ci-shots-<rama>`). `scripts/ci-wait.sh` espera a la CI del último commit y las descarga
  en `shots/ci/`.
- La CI falla ante cualquier error de guion o de sombreador.
- APK de prueba con enlace fijo:
  https://github.com/pabloprietorecio-afk/Chesssome-/releases/download/ultimo-apk/Chessome-debug.apk

## Sin verificar

- Rendimiento, batería y tacto en un teléfono real.
- Sentido del giro al seguir al móvil (`ROLL_SIGN` y `TWIST_SIGN` en `board_view_3d.gd`): si va al revés, se cambia el signo.
- Comportamiento en teléfonos sin Vulkan.

## Pendiente

- Tablero 2D en Godot con la misma interfaz y alternancia 2D/3D para medir H3.
- Paisaje con el tiempo real en el cielo de la pantalla de problema (hoy es un cielo quieto).
- Mostrar explicaciones y flujo de entrenamiento en Godot.
- Niveles de calidad y pausa del dibujo en reposo.
- Partículas, sonido y bandeja de capturas.
- Hoja de animación por colección (datos) y más colecciones.
