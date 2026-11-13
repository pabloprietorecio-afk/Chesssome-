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
| Materiales | `godot/board3d/shaders/` | `piece`, `squares`, `backdrop`, `soft_shadow` |
| Colección | `godot/sets/clasico/` | Seis piezas y el marco, en GLB |
| Modelado | `tools/pieces/` | Genera los GLB desde campos de distancia (código propio) |
| Demo | `godot/demo/` | Problemas reales de `godot/data/demo_puzzles.json` |
| Capturas | `godot/tests/shots.gd` | 16 capturas del tablero y 4 de la demo con toques simulados |

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
view.board.set_theme("dark")            # "light" | "dark"
view.center_view()                      # vista en picado; default_view() vuelve a la inclinada
view.set_tilt_enabled(true)             # seguir la inclinación y el giro del móvil
view.set_view_locked(true)              # fijar la vista actual
```

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
- Capturas: la CI dibuja con Vulkan por software (lavapipe) y las publica en la rama `ci-shots`.
  `scripts/ci-wait.sh` espera a la CI del último commit y las descarga en `shots/ci/`.
- La CI falla ante cualquier error de guion o de sombreador.
- APK de prueba con enlace fijo:
  https://github.com/pabloprietorecio-afk/Chesssome-/releases/download/ultimo-apk/Chessome-debug.apk

## Sin verificar

- Rendimiento, batería y tacto en un teléfono real.
- Sentido del giro al seguir al móvil (`ROLL_SIGN` y `TWIST_SIGN` en `board_view_3d.gd`): si va al revés, se cambia el signo.
- Comportamiento en teléfonos sin Vulkan.

## Pendiente

- Tablero 2D en Godot con la misma interfaz y alternancia 2D/3D para medir H3.
- Mostrar explicaciones y flujo de entrenamiento en Godot.
- Niveles de calidad y pausa del dibujo en reposo.
- Partículas, sonido y bandeja de capturas.
- Hoja de animación por colección (datos) y más colecciones.
