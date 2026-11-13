# Test de nivel, perfil y plan (apartado 2 del diseño)

Qué mide la evaluación de Chessome, cómo, y qué no mide. La referencia es `src/core/assessment.ts`; la app usa
el port `godot/core/assessment.gd`, comprobado contra ella con una prueba de oro (`godot/tests/test_assessment.gd`).

## El recorrido en la app

1. **Bienvenida** y **pregunta de experiencia** (nunca he jugado, sé mover las piezas, juego de vez en cuando,
   juego a menudo). Solo fija el punto de partida, con mucha incertidumbre (Glicko-2, RD 300).
2. **Test de nivel**: entre 8 y 12 problemas reales. Un intento por problema, sin ayudas («No lo sé» cuenta
   como fallo). Tras cada problema, una explicación breve; la explicación a fondo queda para el entrenamiento.
   Termina cuando la incertidumbre baja de 115 o al llegar a 12. Si se cierra la app, sigue por donde iba.
3. **Resultado**: nivel, perfil por dimensiones y plan.
4. **Entrenamiento**: cada problema lo eligen el nivel y los puntos flojos. El nivel se mueve con cada
   problema y el perfil se afina. «Mi nivel y mi plan» está siempre a mano (la píldora de la barra superior).

Se puede saltar el test (en la pregunta de experiencia o a mitad del test): se empieza desde el nivel más bajo (600, con los problemas más fáciles) y el nivel se ajusta al jugar. Lo ya contestado se conserva en el perfil.

## Qué se guarda de cada intento

| Dato | De dónde sale |
| --- | --- |
| Acierto o fallo | Solo es acierto resolver el problema entero, a la primera y sin ayuda |
| En qué jugada se falló | La primera jugada equivocada: la primera del problema o una posterior |
| Clase de error | La consecuencia de esa jugada según el motor y las reglas (ver abajo) |
| Ayuda | Pista, un paso, solución o «no lo sé» |
| Tiempo | Hasta la primera jugada y hasta terminar el problema |
| Qué medía el problema | Familia táctica (temas de Lichess agrupados), si acaba en mate, cuántas jugadas pide |
| Acierto previsto | La probabilidad de acertar que daba su nivel antes del intento |

### Clases de error

Cada jugada legal de cada posición está analizada con el motor (es lo que permite explicarla). De ahí sale su
clase, la misma información que usa la explicación (`ErrorKind` en `src/core/explain.ts`):

| Clase | Qué significa |
| --- | --- |
| Mate en contra | La jugada permite mate (en la respuesta o forzado) |
| Pieza movida a una casilla atacada | La respuesta captura la pieza recién movida y se pierde material |
| Otra pieza sin defensa | La respuesta captura otra pieza y se pierde material |
| Pérdida de material en pocas jugadas | Se pierde material sin una captura inmediata |
| Posición perdida | El motor la da por perdida, sin pérdida concreta a corto plazo |
| Ocasión desaprovechada | No pierde, pero deja pasar el golpe |
| Ganaba, pero no era la más precisa | También gana |

En los 150 problemas de la app hay 11.044 jugadas equivocadas clasificadas: otra pieza sin defensa 3.294,
posición perdida 2.363, pieza movida a una casilla atacada 2.120, mate en contra 1.395, ocasión
desaprovechada 1.094, pérdida de material 771 y ganaba igual 7.

## Los requisitos del apartado 2, uno por uno

| Requisito | ¿Se mide? | Cómo |
| --- | --- | --- |
| Nivel | Sí | Glicko-2 frente al rating de cada problema |
| Tipo de error | Sí | Clase de la primera jugada equivocada |
| Capacidad táctica | Sí, por familias | Aciertos frente a los previstos en cada familia de motivos |
| Visión de mate | Sí | Problemas cuya solución acaba en mate; el test incluye al menos dos |
| Cálculo de variantes | Sí, desde el nivel 3 | Problemas de tres jugadas o más (al menos dos en el test) y si se falla tras acertar la primera. Por debajo de unos 900 casi no hay problemas largos (4 de 96 en los niveles 0–2): ahí queda «Pocos datos» |
| Reconocimiento de amenazas | En parte | Cuántos fallos castiga la respuesta inmediata del rival (mate o pieza a tiro) |
| Piezas desprotegidas | En parte | Las dos clases de error de pieza a tiro. Problemas específicos casi no hay (2 en la muestra) |
| Tiempo empleado | Sí | Mediana hasta la primera jugada; fallos hechos en menos de la mitad del tiempo de los aciertos |
| Comprensión del desarrollo | **No** | Los problemas tácticos no la miden |
| Seguridad del rey | **No** | Solo de rebote: los fallos que permiten mate |
| Capacidad estratégica | **No** | Los problemas tácticos no la miden |

Las tres que no se miden necesitan posiciones de otro tipo (aperturas y medio juego con una pregunta: qué pieza
desarrollar, cuál es la peor pieza, cambiar o no). No existen en una base libre que podamos usar tal cual:
habría que construirlas a partir de partidas reales y validarlas con el motor y con un entrenador. La app lo
dice («Sin medir todavía») en lugar de inventar una cifra.

## Niveles

Los problemas y el jugador se agrupan en niveles del 0 al 10 por dificultad (`LEVEL_FLOORS` en
`src/core/assessment.ts`): 0 por debajo de 600, después tramos de 150 puntos hasta 1650 y más anchos arriba
(1650, 1800, 2000). El jugador ve «Nivel 3», no un número suelto; la puntuación exacta queda en la página de
progreso. La app lleva hasta 32 problemas de cada nivel, repartidos por dificultad dentro del nivel, y la página
de progreso cuenta cuántos de cada nivel ha resuelto. Saltar el test empieza en el nivel 0.

## Cómo se califica una dimensión

- De cada dimensión se cuentan los aciertos y los que eran de esperar por la dificultad de sus problemas.
  El residuo es (aciertos − previstos) / (n + 5): con pocos intentos se acerca a cero.
- Con menos de tres intentos no se califica («Pocos datos»). Si el residuo es −0,08 o menos, «A reforzar»;
  si es 0,08 o más, «Fuerte»; si no, «En tu nivel».
- **Con 8–12 problemas esto son indicios, no un veredicto**, y la pantalla lo dice. El perfil se afina con cada
  problema del entrenamiento.

## El plan

- **Dificultad**: problemas con una probabilidad de acierto prevista de 0,75 (unos 190 puntos por debajo del
  nivel).
- **Focos** (dos como mucho): las dimensiones calificadas «A reforzar», de más a menos. Sus problemas pesan
  más al elegir.
- **Hábitos**, cuando los datos los señalan: mirar la respuesta del rival (la mitad o más de tres o más fallos
  se castigaban con la respuesta inmediata), no precipitarse (dos o más fallos rápidos) y calcular hasta el
  final (dos o más fallos después de acertar la primera jugada).
- **Repaso de errores**: cada tres problemas nuevos vuelve un fallo anterior (los del test, los primeros),
  cuando han pasado al menos cuatro problemas desde él. Ahora con todas las ayudas y la explicación completa.
  No mueve el nivel.
- Agotados los problemas nuevos, vuelve el que se falló hace más tiempo y no se ha resuelto después.

## Límites conocidos

- **Problemas fáciles (resuelto el 13 nov).** La muestra inicial casi no tenía problemas por debajo de 1100. Se
  descargó el volcado oficial de Lichess en la CI (`.github/workflows/problemas.yml`), se eligieron 1.330 problemas
  por debajo de 1300 (popularidad ≥ 80 y jugados al menos 1.000 veces, 70 por cada tramo de 50 puntos) y se
  analizaron con Stockfish: 1.219 verificados (un trabajo de análisis se colgó y se descartó). Con los anteriores,
  el paquete tiene 1.639 problemas, de 399 a 2.147.
- **Los umbrales son decisiones de diseño sin validar**: las cuotas del test, el −0,08, el mínimo de tres
  intentos, la mitad del tiempo, la probabilidad 0,75. Hay que contrastarlos con jugadores reales.
- El nivel está en la escala de problemas de Lichess. **No es Elo** ni hay una tabla de conversión verificada.
- El tiempo no cambia el nivel: solo describe. No hay datos de cuánto tarda otra gente, así que solo se compara
  a cada jugador consigo mismo.
- Repetir el test borra el historial anterior.

## Verificación

- `tests/assessment.test.ts`: el test tiene entre 8 y 12 problemas sin repetir y cubre mates y problemas
  largos; el perfil cuenta bien; el entrenamiento da más peso a lo flojo y no repite hasta agotar la muestra.
- `godot/tests/test_assessment.gd`: ocho jugadores simulados hacen el test y treinta problemas de
  entrenamiento; Godot elige los mismos problemas y llega a las mismas cifras que TypeScript.
- `godot/tests/test_explain.gd`: toda jugada equivocada lleva su clase de error.
- Capturas del recorrido completo en la CI (`50_` a `59_`), con dos problemas contestados con toques simulados.
