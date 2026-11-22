# Modo Campeonato (idea pendiente, 22 nov)

Apuntado a petición de Pablo para cuando estén terminadas las tareas en curso (curva de puntos esperados y
Stockfish propio). Todavía no hay nada hecho.

## Lo que pidió

- **Campeonato contra el móvil.** El jugador participa en un campeonato contra rivales de la app.
- **Rivales con perfil propio.** Varios jugadores, cada uno con su perfil y una foto realista hecha por IA.
- **Por niveles.** Campeonatos de distintos niveles.
- **Premium a partir de la tercera ronda.** Las dos primeras rondas son gratis; para seguir hace falta Premium.
- **La sala sube de categoría con el nivel.** Se empieza en una escuela y se acaba en el hall de un gran hotel de cinco
  estrellas. Todo lo más fotorrealista posible.
- **Ambientación de torneo real.**
  - El jugador avanza por una sala con jugadores hasta llegar a su mesa, donde le espera el rival.
  - Sonido de ambiente y murmullos.
  - Exclamaciones ante grandes jugadas.
  - Aplausos si gana y lamentos si pierde.

## Condiciones que ya sabemos

- Los rivales son bots y la app tiene que decirlo siempre (regla de la app: un bot nunca se hace pasar por una
  persona). La foto y el perfil pueden ser realistas, pero el jugador tiene que saber que son personajes de la app.
- Las fotos tienen que ser de personas inventadas, nunca de personas reales.
- El nivel de los rivales puede salir de la escala de Elo de los bots (docs/calibracion-rival.md).

## Decisiones (23 nov)

- **Formato:** eliminatoria de 8 (cuartos, semifinal y final). Las otras partidas del cuadro las juega la app entre
  bots (resultado según su Elo). La final, tercera ronda, es Premium.
- **Salas:** fotos fotorrealistas hechas con IA (FLUX.2 en Workers AI) con movimiento de cámara y sonido. Una sala
  por grupo de nivel: escuela (Muy fácil), centro cívico (Fácil), club de ajedrez (Medio), casino histórico
  (Difícil), palacio (Muy difícil) y gran hotel de cinco estrellas (Experto).
- **Rivales:** siete por campeonato, personas inventadas y adultas, con retrato fotorrealista hecho con IA. Siempre
  se dice que son bots.
- **Partidas:** con reloj y sin tutor, como en un torneo de verdad. Al terminar, la partida se puede revisar.

## Imágenes

`.github/workflows/campeonato-imagenes.yml` genera un lote (`tools/campeonato/lote_N.json`) con un estudio temporal en
Cloudflare que se borra al acabar, y deja las imágenes en la rama `campeonato-imagenes` para revisarlas. Lote 1: el
pasillo de las seis salas y los siete rivales de la escuela, para aprobar el estilo.

## Hecho (23 nov)

- `core/campeonato.gd`: datos (6 salas, 42 rivales con Elo y nivel del rival de la app), cuadro por cabezas de serie,
  desempate (5+3, colores cambiados) y armagedón (4+2, las negras pasan con tablas), simulación de las otras partidas
  por Elo, final Premium (en el hotel, todo el torneo: sus rivales son «Experto»), salas que se abren al ganar la
  anterior o al llegar al Elo de su rival más flojo. Estado en `user://campeonato.json`.
- `ui/campeonato_ui.gd`: lista de salas con su foto, cuadro, paseo (entrada → pasillo → rival, con movimiento de
  cámara y fundidos; un toque lo salta), tarjeta del rival (siempre «Bot»), reacciones del público y sonido de sala.
- En la partida: reloj de la sala, sin tutor ni pistas (como toda partida con reloj); abandonar cuenta como derrota;
  al acabar, «Seguir el torneo» (sin «Otra»). El resultado se apunta una sola vez, al acabar.
- Inicio: «Campeonato» en la lista y una tarjeta con foto en la rejilla.
- Fotos: `godot/campeonato/` (JPEG con extensión .bin, 5,8 MB), con `tools/campeonato/a_la_app.py`.

## Pendiente

- Sonidos (murmullo por sala, exclamaciones, aplausos, lamento) en `godot/campeonato/sonidos/`: sin ellos la app
  funciona en silencio. Hay que buscarlos con licencia libre (CC0) o generarlos.
- Vídeos de Pablo con PixVerse (el rival da la mano): `godot/campeonato/rivales/<sala>/<id>.ogv` sustituirá a la foto.
- Más rivales por sala (Pablo hará más caras con PixVerse) y traducir los textos nuevos a los nueve idiomas.
