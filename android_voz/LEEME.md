# TutorVoz: preguntar al tutor hablando

`TutorVoz.java` es un complemento de Android (v2) para Godot: usa el reconocimiento de voz del propio Android
(`SpeechRecognizer`, normalmente el de Google) para convertir la pregunta hablada en texto. La app no graba ni
guarda audio: recibe el texto y lo manda como cualquier pregunta escrita (`/tutor/pregunta`).

- El CI lo copia en la plantilla de Gradle (`com/pabloprieto/voz/`, junto a `GodotApp.java`) y activa
  `res://addons/tutor_voz`, que lo registra en el manifiesto con el permiso `RECORD_AUDIO` y la consulta
  `android.speech.RecognitionService` (sin ella, en Android 11+ `isRecognitionAvailable` dice que no).
- Señales: `voz_lista`, `voz_parcial(texto)`, `voz_texto(texto)`, `voz_error(código)`, `voz_permiso(bool)`.
  Métodos: `available()`, `has_permission()`, `ask_permission()`, `start(idioma)`, `stop()`, `cancel()`.
- Sin el complemento (escritorio, pruebas, APK sin Gradle) el botón de micrófono no sale; queda escribir la
  pregunta, y el teclado de Android también deja dictar.
- Privacidad: la política y el formulario de seguridad de datos deben decir que el micrófono se usa solo mientras
  se pulsa «Hablar», a través del reconocimiento de voz del sistema, y que la app no guarda el audio.
- **Sin probar en un móvil** hasta el primer APK con él.
