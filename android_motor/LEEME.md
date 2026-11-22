# MotorStockfish: Stockfish 19 dentro del móvil

Decisión de Pablo (21 nov 2026): valorar las jugadas del tutor con Stockfish en el propio móvil (gratis, sin
límites, sin depender de chess-api.com, que solo da 100 ms por análisis).

- **Qué es**: Stockfish 19 (etiqueta `sf_19`, commit `edb0d9db6731067ec50ce619ff372b463bc4dd5d`), **sin cambios**,
  compilado por la CI con el NDK de Android (`make build ARCH=arm64-universal COMP=ndk`: elige la variante más rápida del procesador). Pesa ~96 MB, casi todo la red neuronal: el APK pasa de ~61 a ~152 MB. Pablo prefiere lo más potente aunque pese (21 nov).
  Va en el APK como `lib/arm64-v8a/libstockfish.so`: Android solo deja ejecutar programas que vienen como librerías
  nativas, y por eso la plantilla de Gradle se ajusta para que se extraigan al instalar (`useLegacyPackaging`).
- `MotorStockfish.java` (complemento de Godot v2) arranca el programa y habla con él por UCI. GDScript:
  `core/local_engine.gd` (`LocalEngine.analyze(fen, ms)`), 800 ms por posición. El tutor analiza la posición de
  antes y la de después de la jugada; el servidor solo prepara las líneas y las flechas con esos análisis
  (`engine` en `/tutor`), y Claude escribe. Sin conexión, la valoración se hace en el móvil (`CoachAI.local_judge`).
- Las preguntas libres a Claude siguen usando el Stockfish del servidor (Claude analiza desde allí).
- Sin el complemento (escritorio, pruebas, APK sin Gradle) todo sigue como antes, con el Stockfish del servidor.

## Licencia (GPL v3)
Stockfish es software libre bajo la GPL v3 o posterior. La app cumple así (no es asesoramiento legal; revisar
antes de publicar):
- Opciones → **Licencias**: el aviso de copyright de Stockfish, que va sin garantía, el texto entero de la licencia
  (`godot/data/licencias/gpl-3.0.txt`, copia de su `Copying.txt`) y el enlace al código de la versión exacta
  (https://github.com/official-stockfish/Stockfish/tree/sf_19). Como no se cambia nada, ese código es el que va en
  la app; las órdenes de compilación están en `.github/workflows/ci.yml`.
- Si algún día se cambia el código de Stockfish, hay que publicar esos cambios y enlazarlos ahí.
- La app habla con Stockfish como programa aparte (UCI), como cualquier interfaz de ajedrez.

## Más allá del tutor (22 nov)

- **Rival «Experto»** (core/bot.gd, niveles 13–16): `play(id, fen, millis, elo)` juega con `UCI_LimitStrength` y
  `UCI_Elo` (2100, 2400, 2700; 0 = sin límite). Solo se ofrece si Stockfish está en el móvil y fuera de Kids y War Chess.
- **«Pista»**: la mejor jugada de Stockfish (600 ms); sin él, la del rival «Medio» de la app.
- **Análisis de la partida**: cada posición una vez (500 ms) y la nota por la caída de la probabilidad de ganar,
  con los umbrales de chess.com, como el tutor (GameDetail.pre_from_engine).
