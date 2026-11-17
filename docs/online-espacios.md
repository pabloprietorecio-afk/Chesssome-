# Partidas online: espacios por ritmo, reloj, denuncias y espera con la app minimizada

Peticiones de Pablo (16 nov 2026). Código: `godot/core/online.gd`, `godot/demo/demo.gd` (pantalla «Partida online»),
reglas: `firebase/database.rules.json`, prueba de las reglas: `firebase/test/`, complemento de Android:
`android_espera/`.

## Espacios

- Fijos: **Sin reloj, 5+3, 10+5, 15+10, 20 min y 30 min**, y **otro ritmo** (personalizado: de 1 a 180 minutos y de 0 a
  60 segundos por jugada). Los personalizados en los que alguien espera aparecen también en la lista.
- Cada espacio dice si hay alguien esperando («2 esperando · juegas ya», en verde) o no («Nadie: esperas tú»). La
  lista se actualiza cada 3 segundos.
- Tipo de partida por su duración estimada (minutos + 40 × incremento), con los cortes de Lichess: bala (< 3 min),
  blitz (< 8), rápida (< 25), clásica.
- Al entrar en un espacio: si alguien espera, te unes a la partida más antigua; si no, abres una y esperas. Los
  jugadores bloqueados no se emparejan (ni tú con ellos ni ellos contigo).
- La web de pruebas usaba otro nodo (`abiertas`): ya no se empareja con la app (la web se ha dejado de lado).

## War Chess online (17 nov)

- «Partida online» tiene **Modalidad: Clásica / War Chess**. Los espacios de War Chess son los mismos ritmos con una «w»
  delante (`w5+3`); se cuentan y emparejan aparte. Ver `docs/war-chess.md`.
- Las reglas de la base de datos admiten la «w» en `ritmo` (`espera` y `partidas`): **hay que publicarlas** (abajo).

## Reloj online

- Todas las partidas con tiempo llevan reloj. Pulsarlo a mano es opcional (ajuste «Pulsar el reloj» de Opciones, el
  mismo que contra el ordenador); si no, se pulsa solo al mover.
- Cada pulsación se guarda con la **hora del servidor** (`pulsos/<n>`); con ellas los dos móviles calculan lo mismo.
  Ves la jugada del rival en cuanto la hace, pero tu turno (y tu reloj) empieza cuando él pulsa.
- La partida (y el reloj de blancas) empieza cuando quien esperaba confirma que está (`listo`).
- Si a alguien se le acaba el tiempo, pierde (tablas si al otro no le queda material para dar mate). Lo apunta
  cualquiera de los dos en `fin`; vale el primero. Al rival que no pulsa se le dan 3 segundos de margen (su pulsación
  puede venir de camino).
- Límite conocido: sin servidor propio (Cloud Functions), un móvil manipulado podría apuntar una derrota falsa. Es el
  mismo nivel de confianza que el resto de la partida online.

## Esperar con la app minimizada (APK con avisos)

Ver `android_espera/LEEME.md`. Mientras esperas, un aviso fijo «Esperando rival · 5+3» (con «Dejar de esperar») mantiene
viva tu partida en espera; si entra alguien con la app minimizada, aviso «¡Rival encontrado!». Quien entra espera como
mucho un minuto a que vuelvas; si no, sigue buscando. Solo en el APK con avisos (compilado con Gradle).

## Normas, denuncias y bloqueos

- Antes de la primera partida online se aceptan las normas (respeto, nombre, sin ayudas, no hacer perder el tiempo,
  denuncias, qué se comparte). Se pueden releer desde «Partida online».
- Desde la fila del rival (botón «…»), en la partida: **Denunciar** (nombre ofensivo, ayudas o un programa, hacer
  perder el tiempo, gestos molestos, otra cosa) y **Bloquear**. Los bloqueados se gestionan en «Partida online».
- Las denuncias se guardan en `denuncias/` y **solo se leen en la consola de Firebase** (Realtime Database). Cada una
  lleva el identificador anónimo del denunciado (`contra`), su nombre, la partida y el motivo.
- **Vetar a alguien:** en la consola, añadir `vetados/<identificador> = true`. Las reglas le impiden abrir partidas o
  unirse a ellas. (Si borra la app y la vuelve a instalar, tendrá otro identificador: sin cuentas de usuario no hay
  forma de evitarlo.)
- Esto no son unas condiciones de uso legales: antes de Google Play hacen falta unas de verdad y la política de
  privacidad (revisadas por alguien que sepa).

## Publicar las reglas (lo hace Pablo)

1. Esperar a que el CI pase el trabajo «Reglas de Firebase (emulador)»: prueba las reglas contra el emulador oficial.
2. Firebase → Realtime Database → Reglas: pegar `firebase/database.rules.json` y publicar.
3. Hasta que se publiquen, la versión nueva de la app no puede jugar online (escribe en `espera`, `listo`, `pulsos`…,
   que las reglas viejas no permiten).

## App Check

No se ha activado. Con Godot no hay SDK de Firebase: haría falta un complemento nativo de Android, el proveedor Play
Integrity exige la app en Google Play Console (con la huella SHA-256 de la firma) y, al activar la obligación, los APK de
prueba sin token de depuración dejarían de poder jugar online. Se deja para cuando la app esté en Google Play; el APK con
Gradle ya permite añadir el complemento.

## «¿Sigues ahí?» y ganar por abandono (16 nov)

Problema: quien deja la app sin rendirse obliga al rival a esperar hasta que se le acabe el reloj (30 minutos en
«30 min») o para siempre en «Sin reloj».

- **Cuándo se pregunta**: a quien le toca y lleva sin jugar la quinta parte de su tiempo, entre 1 y 5 minutos
  (5+3 → 1 min, 10+5 → 2, 15+10 → 3, 20 → 4, 30 → 5); sin reloj, 3 minutos (`Online.idle_limit_ms`).
- **Qué ve**: una ventana «¿Sigues ahí?» con vibración. «Sigo aquí» (o tocar fuera) escribe
  `partidas/<id>/sigo/<uid>` con la hora del servidor y la cuenta vuelve a empezar.
- **El rival**: si pasan 30 s más (y 15 s de margen por la red) sin jugada ni «Sigo aquí», le sale «Tu rival no
  contesta» con «Ganar por abandono» o «Seguir esperando» (vuelve a ofrecerlo al minuto). Ganar escribe
  `fin = {tipo: "abandono", pierde, de, t}`; los dos lo leen y la partida se borra a los 30 s.
- **Si vuelve tarde** (la partida ya se borró): si le tocaba y llevaba más del límite sin contestar, su app lo
  cuenta como derrota por abandono; si no, como que se fue el rival.
- Cada móvil mide con su propio reloj desde que ve empezar el turno (no hacen falta horas del servidor para cada
  jugada, y vale también sin reloj).
- Como «tiempo», «abandono» lo apunta la app de quien gana: sin Cloud Functions se podría falsear (igual que hoy).
- Reglas: `sigo/$uid` (solo el propio, `now`, antes del fin), `fin.tipo` «tiempo» o «abandono», gesto «tiempo».
