# Voz del tutor (22 nov 2026)

Petición de Pablo: «Vamos a poner voz a las respuestas del tutor». Primero se hizo con Kokoro (la voz em_santa de A
Tank Story) generada en un servidor externo (DeepInfra, commit 613b572). Ese mismo día Pablo prefirió no depender de un
servidor externo: «¿no podemos poner un lector de texto, de pantalla? Marcamos lo que es la respuesta de la IA del
resto del texto y la leemos». Se quitó el servidor de voz y se usa el lector del móvil.

## Cómo funciona
- `core/tutor_speech.gd` manda el texto al **motor de voz del sistema** (en Android, el «Texto a voz» de los ajustes;
  normalmente el de Google) con `DisplayServer.tts_speak` de Godot (`audio/general/text_to_speech=true` en
  project.godot). Sin servidor, sin coste y sin conexión (si la voz está descargada en el móvil).
- No es TalkBack (que lee toda la pantalla): la app sabe qué texto es de la IA y solo pasa ese.
- Antes de leerlo, las jugadas se pasan a palabras en el idioma de la app: «Cxf5+» → «caballo toma en efe cinco,
  jaque», «O-O» → «enroque corto», «exd5» → «peón de e toma en de cinco»; fuera markdown, emojis y números de jugada.
  Español, inglés, francés, italiano, portugués, alemán, ruso e indonesio con casillas dichas; japonés e hindi con
  piezas en palabras y casillas escritas (sin revisar por un nativo).
- La voz: la del idioma de la app; en español, la de España si el móvil la tiene (es_ES), y mejor una que funcione
  sin conexión. Si no hay ninguna del idioma, la que Android tenga por defecto.

## Qué se lee
- Las respuestas a las preguntas al tutor y las del asistente, al llegar.
- La explicación completa del profesor («Ver completa»), al abrirla.
- Cada paso de la lección en el tablero; si el texto de Claude llega con la lección ya abierta, se dice ese.
- Botón **«Escuchar» / «Parar la voz»** debajo de cada texto. Cerrar la ventana o la lección la calla.
- **Opciones → Premium → «Voz del tutor»** (encendida de serie). Nunca en Kids (tiene su propia voz grabada).

## Límites
- La voz no es la de A Tank Story: depende del móvil. En Android se cambia (y se descargan otras) en Ajustes →
  Accesibilidad / Sistema → Salida de texto a voz. Si algún día se quiere la de A Tank Story, el código del servidor
  con Kokoro está en el commit 613b572.
- Sin probar en un móvil.

## Respuestas largas del asistente (arreglo del mismo día)
Captura de Pablo (22 nov): la frase del asistente salía en el aviso breve amarillo y se salía de la pantalla por los
dos lados. Ahora el aviso breve es solo para frases cortas (60 caracteres, una línea: `demo.fits_toast`); lo demás se
queda en la ventana semitransparente con la respuesta. Además, el aviso breve ya no se sale nunca: un texto largo baja
de línea.

## Pruebas
`godot/tests/test_voz_tutor.gd` (jugadas en palabras en varios idiomas, elección de la voz, la opción, el botón y la
respuesta larga del asistente), en la CI.
