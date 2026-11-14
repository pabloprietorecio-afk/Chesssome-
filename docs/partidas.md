# Partidas contra el rival

Petición de Pablo (14 nov 2026): una opción para jugar contra un bot con varios niveles, y una partida al final de
cada grupo de lecciones, acorde a lo aprendido.

## El rival (`godot/core/bot.gd`)

- Búsqueda alfa-beta propia en GDScript sobre las reglas de la app (`core/chess.gd`), con capturas al final de la
  búsqueda y profundización iterativa con límite de tiempo. Evaluación propia y sencilla (material, centro, avance de
  peones, desarrollo, refugio del rey); no se ha copiado de ningún motor.
- Cinco niveles: Muy fácil, Fácil, Medio, Difícil y Muy difícil. Cambian la profundidad, un ruido fijo por jugada
  (errores «humanos», no temblor) y la probabilidad de jugar al azar. Todos dan el mate en una si lo tienen.
- **La fuerza no está medida contra jugadores reales.** Es un rival para principiantes y aficionados; el nivel más
  alto no es un motor de club fuerte. Para eso haría falta Stockfish (GPL-3.0): meterlo en la app obliga a
  distribuir el código de la app bajo GPL o a cumplir sus condiciones; decisión pendiente.
- Piensa en otro hilo, para no congelar la pantalla. «Muy difícil» piensa hasta 4 s por jugada (en el ordenador de
  la CI; en un móvil, la búsqueda llega menos lejos en ese tiempo).
- Prueba: `godot/tests/test_bot.gd` (jugadas legales, mates en una, no regalar la dama, guerra de peones, notación,
  partidas enteras: «Medio» y «Muy difícil» ganan a «Muy fácil»).

## En la app

- **Opciones → Jugar una partida:** color (blancas, negras o al azar) y nivel.
- **Al final de cada unidad del curso**, la lección final ofrece «Partida»:
  - Cómo se mueven las piezas → guerra de peones (sin reyes; gana quien corona, quien captura todo o quien deja al
    otro sin jugadas), contra «Muy fácil».
  - Capturar → peones y caballos (mismas reglas), contra «Fácil».
  - Jaque y jaque mate → primera partida entera, contra «Muy fácil».
  - Jugadas especiales → partida contra «Fácil».
  - Practica el mate → partida contra «Medio»; después, el test de nivel (fuera del nivel Kids).
- **Ritmo** (petición de Pablo, 14 nov): sin reloj (por defecto), 3+2, 5+0, 10+0, 15+10, 30+0, 90+30 y «Otro»
  (minutos e incremento a elegir). «10+0» son 10 minutos por jugador; «15+10», 15 minutos y 10 segundos más por
  jugada. Con reloj no hay deshacer ni pistas, como en una partida oficial; quien se queda sin tiempo pierde, salvo
  que el rival no tenga material para dar mate (tablas; regla simplificada: solo rey, o rey y una pieza menor). El
  rival reparte su tiempo (1/30 de lo que le queda más casi todo el incremento). En el nivel Kids no hay reloj.
- **Pulsar el reloj** (petición de Pablo; ajuste en Opciones, activado por defecto): tras cada jugada, tu tiempo
  sigue corriendo hasta que pulsas «Pulsar reloj» (el incremento se suma al pulsar). Si no lo pulsas en 15 s, aviso
  en la tarjeta y vibración (otro ajuste, también activado por defecto).
- Durante la partida: Salir, Deshacer (vuelve a la última vez que te tocaba), Pista (lo que jugaría «Medio», con
  una flecha) y Rendirse. Fin: jaque mate, ahogado, 50 jugadas, triple repetición y material insuficiente.
- En el nivel Kids: sin notación, con voz al empezar, al recibir jaque y al acabar.

## Pendiente

- Análisis educativo después de la partida (apartado 11 del documento de diseño).
- Medir la fuerza de cada nivel (partidas entre niveles y contra jugadores con Elo conocido).
- Pista sin congelar la pantalla (ahora piensa hasta 1,5 s en el hilo principal).

## Análisis después de la partida (`godot/core/review.gd`)

Petición de Pablo (14 nov): detectar los momentos donde el jugador podía aprender algo y conectarlos con lecciones
y problemas.

- **Solo se dicen cosas comprobables** con las reglas y con la cuenta del cambio de piezas en una casilla (SEE). No
  se convierten números del rival en frases. Clases de momento: mate del rival permitido (había otra jugada que lo
  evitaba), mate en una que se escapó, pieza a tiro (otra jugada no perdía nada), captura gratis que no se hizo
  (salvo si la jugada daba jaque), y en la apertura: el rey movido sin enrocar y la misma pieza por tercera vez con
  dos o más piezas menores sin sacar. Como mucho seis momentos, los más importantes.
- La vista es corta (una jugada y media): no ve combinaciones largas, planes ni estructura. La página lo dice.
- En la app: tras la partida, «Análisis» → lista de momentos con «Ver» (posición en el tablero, flecha roja con tu
  jugada y verde con la otra), «Lección» (la del curso que lo enseña) y «Problemas» (hasta 5 problemas de ese tema,
  cerca de tu nivel). Nivel Kids: frases fijas con voz.
- Se guarda un resumen de cada partida analizada en `user://chessome_partidas.json` (fecha, nivel, resultado,
  clases de momento): base para que el entrenador elija lecciones más adelante.
- Prueba: `godot/tests/test_review.gd` (en la CI).
