# Profesor IA (premium)

Petición de Pablo (21 nov 2026): una IA que corrija al jugador mientras juega, como un profesor, en la versión
premium, y poder activarla para probarla.

## Qué hace
- En las partidas contra el rival de la app (sin reloj, sin red, fuera de Kids y de las variantes), tras cada jugada
  del jugador se busca un error comprobable: mate que se escapa, mate permitido, pieza a tiro, captura que no se hizo
  (`GameReview.analyze_move`, la misma vista corta del análisis de la partida).
- Si lo hay, la tarjeta enseña «El profesor está mirando tu jugada…» y después la explicación de **Claude Haiku 5.5**,
  redactada con la voz de un profesor y adaptada al nivel del jugador.
- La IA no calcula ni evalúa: recibe los hechos ya comprobados y solo los redacta. Si su respuesta nombra una casilla
  que no está en los hechos, se descarta y se enseña el texto comprobado. Sin red, sin clave o con error, también.
- Jugadas sin error: el profesor no dice nada (y no se gasta ninguna petición).

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
- **Servidor propio** (`endpoint` en `data/coach_ai.json`): recibe el mismo cuerpo, añade la clave y comprueba que el
  jugador es premium. Una clave dentro del APK la puede sacar cualquiera.
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
