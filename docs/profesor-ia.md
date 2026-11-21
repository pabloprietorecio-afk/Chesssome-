# Profesor IA (premium)

Petición de Pablo (21 nov 2026): una IA que corrija al jugador mientras juega, como un profesor, en la versión
premium, y poder activarla para probarla.

## Qué hace
- En las partidas contra el rival de la app (sin reloj, sin red, fuera de Kids y de las variantes), tras cada jugada
  del jugador el motor de la app la valora en otro hilo (GameDetail.entry, como el detalle de partida): la mejor,
  buena, imprecisión, error o error grave.
- Sale la chapa en el tablero y la valoración en la tarjeta, **en todas las jugadas**: «!» la mejor, marca de
  «buena», «?!» imprecisión, «?» error, «??» error grave. «!!» no: el motor de la app no es lo bastante fuerte para
  afirmar una jugada brillante.
- La chapa se queda hasta tu siguiente jugada: el tablero la borra con cada movimiento, así que se repone tras la
  jugada del rival (salvo que capture esa pieza) y al volver de mirar jugadas atrás. El rival espera a que salga
  la valoración (y medio segundo más) antes de mover, como mucho 3 s.
- Imprecisión: la explicación comprobada del análisis (qué hace, qué permite, cuál era la mejor), sin IA.
- Error y error grave: «El profesor está mirando tu jugada…» y la explicación de **Claude Haiku 5.5**, redactada a
  partir de esos mismos hechos. Si nombra una casilla que no está en los hechos, se descarta y queda el texto
  comprobado. Sin red, también.
- Antes (hasta el 21 nov) solo usaba el detector corto de GameReview (pieza a tiro, mate…, dos peones o más):
  callaba casi siempre. Se cambió al motor.
- En el APK de pruebas, una línea gris dice qué ha decidido el profesor y por qué.

## Cómo probarlo (APK de depuración)
1. Opciones → Premium → «Premium de prueba».
2. Pegar una clave de la API de Claude (Claude Console, con saldo) y «Guardar la clave». Se guarda solo en el móvil
   (`user://premium.cfg`).
3. Jugar una partida sin reloj. Sin clave también funciona, con los textos comprobados en lugar de la IA.

En el AAB de publicación no salen ni el interruptor de prueba ni el campo de la clave (`OS.is_debug_build()`).

## Coste
Una petición por error: unos 1.500 tokens de entrada y 150 de salida. Con Haiku 5.5 (0,10 $ / 0,50 $ por millón,
precios de octubre de 2026) son unos 0,0002 $ por corrección; con unos 6 errores por partida, ~0,1 céntimos.
La suscripción de claude.ai no cubre la API: se paga aparte en Claude Console.

## Pendiente para publicar
- **Servidor propio**: hecho en `worker/` (Cloudflare Workers, plan gratuito), se despliega con
  `.github/workflows/worker.yml` cuando están los secretos CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID y
  ANTHROPIC_API_KEY. La app le manda solo los hechos; el prompt y la clave están en el servidor. Límite: 10
  peticiones por minuto por IP. Dirección: https://achessway-profesor.pablo-prieto-recio.workers.dev/profesor
  (`endpoint` de `data/coach_ai.json`; el despliegue la prueba con un error de verdad).
  **No comprueba que el jugador sea premium** (no hay compra real todavía): hasta entonces, la protección es el
  límite por IP y el límite de gasto que se ponga en Claude Console.
- **Compra real** (Google Play Billing): plugin de facturación y producto en Play Console; hoy `Premium.purchased`
  no lo pone nadie.
- Textos nuevos sin traducir (salen en español en los otros idiomas).
- Privacidad: la política y el formulario de seguridad de datos deben decir que la posición y la jugada se envían a
  Anthropic para redactar la explicación (nada personal). La app es de público mixto: revisar la política de
  Familias antes de activarlo en producción.
- Sin verificar en un móvil real.

## Pruebas
`godot/tests/test_profesor_ia.gd` (detección, petición, comprobación de la respuesta, cuándo comenta) y
`godot/tests/test_profesor_app.gd` (la tarjeta en una partida y la sección Premium de Opciones), en la CI.
