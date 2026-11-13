# Chessome · prototipo MVP

Prototipo para comprobar tres hipótesis antes de construir el producto:

1. **H1.** Explicar por qué una jugada es buena o mala enseña más que mostrar solo el resultado y la solución.
2. **H2.** Un test inicial corto sitúa al jugador en la dificultad adecuada.
3. **H3.** Un tablero 3D con animaciones resulta atractivo sin perjudicar el juego. *(El tablero 3D se construye en su propia fase; ver «Estado».)*

Diseño, investigación y especificación: documento «Chessome — investigación, diseño y MVP».

## Puesta en marcha

```bash
npm install
npm run dev          # app en http://localhost:5173
npm test             # pruebas del núcleo y de las explicaciones sobre problemas reales
npm run build:single # dist/chessome.html: la app entera en un solo fichero
```

## Pipeline de datos

La app no incluye motor: lee un paquete con el análisis ya hecho. El paquete se genera así:

```bash
# 1. Importar y validar el CSV oficial de Lichess (descomprimido con zstd)
npm run pipeline:import -- --in data/raw/lichess_db_puzzle.csv --out data/dev/puzzles.json \
     --via "https://database.lichess.org/lichess_db_puzzle.csv.zst"

# 2. Analizar con Stockfish (se puede repartir en varios procesos con --shard i/n)
npm run pipeline:analyze -- --in data/dev/puzzles.json --out data/dev/analysis.0.jsonl \
     --limit 420 --shard 0/2 --depth-all 12 --depth-top 16

# 3. Verificar, revisar todas las explicaciones y empaquetar
npm run pipeline:report -- --max 420   # escribe src/data/puzzles.pack.json y data/dev/report.json
```

`scripts/show-explanations.ts` y `scripts/one.ts` imprimen explicaciones para revisarlas a ojo.
`scripts/e2e.mjs` recorre la app en Chrome sin interfaz y guarda capturas en `shots/`.

## Versión Godot (Android)

El tablero 3D y la app Android se construyen en Godot 4.7 con GDScript, en `godot/`. El núcleo TypeScript sigue siendo la referencia:

- Las explicaciones de los problemas se generan en el pipeline y Godot solo las muestra (así cada texto es uno de los que pasaron el control de calidad).
- Lo que sí se porta a GDScript (reglas, Glicko-2, selección de ejercicios, registro del experimento) se comprueba contra datos de oro generados desde TypeScript: `npm run golden` escribe `godot/tests/golden/`, y `tests/golden-godot.test.ts` falla si esos datos se quedan desfasados.

```bash
npm run golden                                              # regenerar datos de oro
godot --headless --path godot --import
godot --headless --path godot -s tests/test_glicko2.gd      # prueba de oro de Glicko-2
```

La CI (`.github/workflows/ci.yml`) ejecuta en cada push los tests de TypeScript, las pruebas de oro en Godot (reglas y Glicko-2), dibuja 20 capturas del tablero 3D y de la demo (rama `ci-shots`) y genera un APK de depuración con enlace fijo:

https://github.com/pabloprietorecio-afk/Chesssome-/releases/download/ultimo-apk/Chessome-debug.apk

`android_firma/debug.keystore` es una clave solo de depuración y se sube a propósito para que cada APK se instale encima del anterior; la clave de publicación nunca debe subirse al repositorio.

El tablero 3D usa el renderizador «Mobile» (Vulkan) y una colección de piezas propia generada por código (`tools/pieces`). Resumen técnico en `docs/sistema-3d.md`.

## Estructura

```
src/core/        Núcleo sin DOM: reglas, detectores tácticos, explicaciones, Glicko-2, selección, experimento
src/app/         Estado, persistencia local y lógica de sesión
src/ui/          Pantallas, tablero 2D, panel de explicación, encuesta (tablero 3D: pendiente)
src/data/        Paquete de problemas analizados que consume la app
pipeline/        Importación, análisis con Stockfish y control de calidad
tests/           Pruebas (Vitest)
godot/           App Godot: núcleo portado (core/), tablero 3D (board3d/), piezas (sets/), demo y pruebas (tests/)
tools/pieces/    Modelado de las piezas 3D por código (campos de distancia → GLB)
scripts/         Utilidades de desarrollo y prueba en navegador
data/raw/        Muestra de 1.000 problemas reales de Lichess
data/dev/        Problemas importados, análisis del motor e informe de calidad
```

## Datos y licencias

| Pieza | Licencia | Notas |
| --- | --- | --- |
| Problemas de Lichess | CC0 | Muestra de desarrollo tomada de https://github.com/kagisearch/llm-chess-puzzles (MIT), que los extrajo al azar de la base de Lichess. En producción se usa el volcado oficial de https://database.lichess.org/ |
| Stockfish 19 (stockfish.js) | GPL-3.0 | Solo en el pipeline. No se distribuye con la app |
| chess.js | BSD-2-Clause | Reglas del juego |
| React, Vite, three.js | MIT | |
| Definiciones de temas | Propias | Redactadas desde cero; los textos de Lichess son AGPL y no se usan |
| Piezas 2D | Propias | Dibujadas para el proyecto |
| Glicko-2 | Dominio público | Implementación propia (TypeScript y port a GDScript) |
| Godot Engine 4.7.2 | MIT | Motor de la app Android |
| Piezas y tablero 3D | Propias | Modeladas por código del proyecto (`tools/pieces`); sin modelos ni texturas de terceros |

El paquete de datos está marcado como `provisional: true`: es una muestra de desarrollo, no el catálogo de producción.

## Estado

- Hecho: pipeline, núcleo de explicaciones con control de calidad, Glicko-2 y test de nivel, entrenamiento con condiciones del experimento, tablero 2D, panel «Explícame por qué» (también tras acertar), encuesta, pantalla de resultados y exportación.
- Hecho: ayudas tras el problema — «¿Y si juego…?», «Analizar en Lichess» y «Pregunta a una IA» (especificación en `docs/ayudas.md`).
- Hecho: estilo 2D inspirado en WakeAgenda (tokens, componentes, barra flotante y tablero «cielo»; ver `docs/estilo-2d.md`).
- Hecho: tema claro, oscuro o automático (Ajustes).
- Diseñado, sin implementar: fondos de escena con piezas de ajedrez bajo el tiempo del usuario (MET Norway, opcional; ver `docs/estilo-2d.md`).
- Diseñado, sin implementar: «Cine de finales», películas generadas por la app con filtro de cine antiguo (ver `docs/cine-finales.md`). Va después de las piezas 3D.
- Hecho (Godot): reglas portadas y verificadas contra chess.js, colección 3D «Clásico de autor», tablero 3D con toque y arrastre, cuatro modos de animación, temas claro y oscuro, vista en picado, giro con dos dedos, seguir al móvil y fijar vista, y demo con 60 problemas reales (`docs/sistema-3d.md`).
- Sin verificar: el APK en un teléfono real (rendimiento, tacto y sentido del giro con los sensores).
- Pendiente (Godot): tablero 2D y alternancia 2D/3D para medir H3, explicaciones y entrenamiento, niveles de calidad, sonido y partículas.
- Provisional (web): `src/ui/Board3D.tsx` sigue desactivado (`BOARD_3D_READY` en `src/ui/boardTypes.ts`); el 3D real es el de Godot.
