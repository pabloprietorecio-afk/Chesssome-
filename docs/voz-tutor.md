# Voz del tutor (22 nov 2026)

Petición de Pablo: «Vamos a poner voz a las respuestas del tutor. La voz generada para A Tank Story me gusta para el
tutor».

## Qué voz
- **Kokoro-82M** (Apache 2.0), la misma que el tutorial de A Tank Story (repositorio Tank-Ahead,
  `tools/voice_gen/tutorial_voice.py` y `voices_lang.py`): español **em_santa**, inglés bm_george, francés ff_siwis,
  italiano if_sara, portugués pm_santa (de Brasil: Kokoro no tiene de Portugal), japonés jf_alpha, hindi hf_alpha.
- **Sin el efecto de radio** de A Tank Story (filtro de banda, estática y pitido): en un profesor que habla mucho
  cansaría y se entendería peor. Si se quiere, se puede añadir.
- Alemán, ruso e indonesio: Kokoro no tiene esas voces (A Tank Story usa Supertonic, que no se puede ejecutar en el
  servidor). Ahí habla la voz del sistema del móvil (motor de voz de Android, `DisplayServer.tts_*` de Godot).

## Cómo funciona
- Las respuestas del tutor son de la IA (cambian cada vez): no se pueden pregrabar como en A Tank Story. El servidor
  (`worker/src/speech.js`, ruta `/voz/decir`) pide el audio a un proveedor que sirve Kokoro con una API como la de
  OpenAI (`/v1/audio/speech`). Por defecto **DeepInfra** (`TTS_URL`, `TTS_MODEL` en `wrangler.toml`; clave en el
  secreto `TTS_API_KEY`). Kokoro no cabe en un Worker de Cloudflare y Workers AI no lo tiene (sus voces son otras:
  Deepgram Aura, MeloTTS…).
- Antes de mandarlo, el servidor pasa las jugadas a palabras, en el idioma de la app: «Cxf5+» → «caballo toma en efe
  cinco, jaque», «O-O» → «enroque corto», «exd5» → «peón de e toma en de cinco»; quita el markdown y los emojis.
  Japonés e hindi: palabras de piezas sin revisar por un nativo y casillas tal cual.
- La app (`core/tutor_speech.gd`) parte el texto en trozos de unas frases (el primero corto, para que empiece antes),
  pide el siguiente mientras suena el anterior y **guarda lo dicho en el móvil** (`user://voz_tutor`, hasta 300
  trozos): repetirlo no cuesta nada. Sin servidor, sin red o sin clave: la voz del sistema, con el texto ya preparado
  que devuelve el servidor.

## Qué se lee
- Las respuestas a las preguntas al tutor (y las del asistente), al llegar.
- La explicación completa del profesor («Ver completa»), al abrirla.
- Cada paso de la lección en el tablero («Explícamelo» y «Enséñamelo en el tablero»); si el texto de Claude llega con
  la lección ya abierta, se dice ese.
- Botón **«Escuchar» / «Parar la voz»** debajo de cada texto. Cerrar la ventana o la lección la calla.
- **Opciones → Premium → «Voz del tutor»** (encendida de serie). Nunca en Kids (tiene su propia voz).

## Respuestas largas del asistente (arreglo del mismo día)
Captura de Pablo (22 nov): la frase del asistente salía en el aviso breve amarillo y se salía de la pantalla por los
dos lados. Ahora el aviso breve es solo para frases cortas (60 caracteres, una línea: `demo.fits_toast`); lo demás se
queda en la ventana semitransparente con la respuesta. Además, el aviso breve ya no se sale nunca: un texto largo baja
de línea.

## Coste
DeepInfra cobra Kokoro por caracteres: entre 0,62 y 0,99 $ por millón según su propia web (dos cifras distintas en
dos páginas, 22 nov). Una respuesta de 500 caracteres: unos 0,05 céntimos de dólar; mucho menos que la de Claude.
Límite: 40 trozos por minuto por IP (`SPEAK_IP`).

## Pendiente
- **Pablo**: cuenta en DeepInfra, clave de API y secreto `TTS_API_KEY` en GitHub (el despliegue la sube a Cloudflare y
  prueba una frase). Hasta entonces, el tutor habla con la voz del sistema.
- Sin comprobar en un proveedor real que la voz `em_santa` esté disponible (DeepInfra no publica la lista de voces en
  la página del modelo; Kokoro v1.0 tiene 54 voces y em_santa es una de ellas). El despliegue lo comprueba.
- Privacidad: el texto de la respuesta va a DeepInfra para leerlo (nada personal). Añadirlo a la política.
- El servidor no exige cuenta para la voz (como el dictado): la protección es el límite por IP y el largo (1.500).
- Sin probar en un móvil.

## Pruebas
`worker/test.mjs` (jugadas en palabras, petición al proveedor, errores) y `godot/tests/test_voz_tutor.gd` (trozos,
lo guardado no se vuelve a pedir, voz del sistema en alemán, la opción, el botón y la respuesta larga del asistente).
