# Importar mis partidas (Lichess y Chess.com)

Petición de Pablo (26 nov 2026), tras analizar la idea de importar partidas desde una foto: primero lo que sirve a
más gente sin saber qué es un FEN o un PGN, traer las partidas escribiendo el nombre de usuario.

## En la app

- **Mis partidas → Importar partidas** (no en el nivel Kids). Se elige Lichess o Chess.com, se escribe el nombre
  de usuario (sin contraseña ni cuenta) y «Traer mis partidas» trae las **20 más recientes** de ajedrez normal.
- Tocar una la abre en el tablero con su análisis (el mismo de las partidas de la app: `core/review.gd`), con
  «Jugada a jugada» y un botón «Importadas» para volver a la lista. El color del jugador sale de su nombre en la
  partida (sin distinguir mayúsculas).
- Se guardan **aparte** (`user://chessome_importadas.json`, la última tanda de cada servicio): **no** se suman a
  «Mis partidas», a las estadísticas, al nivel de juego ni a los retos, porque no se han jugado en la app y el rival
  no es un nivel con fuerza medida. El resumen del análisis sí se guarda como el de cualquier partida analizada.
- Errores que se explican: sin conexión, nombre que no existe (404), cuenta cerrada (410), «429» (se espera un
  minuto antes de volver a preguntar a ese servicio), otro código. Nombre: 2 a 30 letras inglesas, números, «_» y «-».

## Cómo se piden (`core/game_import.gd`)

- **Lichess**: `GET https://lichess.org/api/games/user/{usuario}?max=20&perfType=ultraBullet,bullet,blitz,rapid,classical,correspondence&finished=true…`
  con `Accept: application/x-chess-pgn`: una sola petición, en PGN. Su documentación (lichess.org/api) pide una
  petición cada vez y, tras un 429, esperar un minuto entero.
- **Chess.com** (Published-Data API): `GET https://api.chess.com/pub/player/{usuario}/games/archives` (lista de
  meses) y, del más reciente hacia atrás (como mucho tres), `GET` de cada mes, en JSON (`pgn`, `rules`, `white`,
  `black` con `username` y `result`, `end_time`, `url`). Se descartan las que no son `rules: "chess"`. Su
  documentación dice que el acceso en serie no tiene límite, que en paralelo puede dar 429 y que conviene un
  User-Agent reconocible con contacto: se manda `AChessWay/<versión> (Android; +<ficha de Google Play>)`.
- Las variantes (Chess960, Crazyhouse…) no se traen: las reglas de la app no las juegan.
- Cómo terminó: el mate y el ahogado se **comprueban en el tablero**; lo demás sale de lo que dice el servicio
  (códigos de Chess.com: `resigned`, `timeout`, `agreed`…; en Lichess, la cabecera `Termination`, que solo
  distingue «Time forfeit» y «Abandoned»; si no, «Has ganado / perdido / Tablas»).

## El lector de PGN (`core/pgn.gd`)

- Cabeceras, jugadas en notación inglesa (K Q R B N), enroques con O o con 0, coronaciones con y sin «=», al paso
  con «e.p.», desambiguación por columna, fila o casilla; salta comentarios `{…}` y `;`, variantes `(…)`
  anidadas, NAG `$n`, signos `!?` y números de jugada (también pegados: `1.e4`). Cada jugada se busca entre las
  legales de `core/chess.gd`: si una no se puede leer, la partida se corta ahí y la lista lo dice («incompleta»).
- Pruebas: `tests/test_importar.gd` (40 partidas al azar generadas con python-chess, `tools/importar/oro_pgn.py`
  → `tests/golden/pgn.json`, con enroques, al paso, coronaciones y desambiguaciones; respuestas de ejemplo de los
  dos servicios) y `tests/test_importar_app.gd` (la página y el análisis, sin red).

## Sin comprobar

- **No se ha probado contra los servidores reales**: desde el entorno de desarrollo no se llega a lichess.org ni a
  api.chess.com. Las respuestas de ejemplo de las pruebas siguen la documentación de los dos servicios; hay que
  probarlo en el móvil con una cuenta real de cada uno.
- **Condiciones de uso**: la documentación de Chess.com no da una licencia aparte; dice que sus API son públicas,
  pide respetar su propiedad intelectual y remite las dudas a legal@chess.com. La de Lichess no trae condiciones
  propias de la API en lo que se ha leído. Antes de publicar, leer las condiciones de uso de los dos sitios (y, si
  hay dudas, preguntarles). La app solo trae las partidas públicas del usuario que escribe su nombre, para
  analizarlas en su móvil; no las publica ni las reparte.
- La política de privacidad (`docs/privacidad/index.html`, apartado 3) ya lo cuenta.
- No van en la copia de seguridad (`core/backup.gd`): se pueden volver a traer.
