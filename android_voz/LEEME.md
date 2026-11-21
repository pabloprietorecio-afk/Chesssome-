# TutorVoz: preguntar al tutor hablando

`TutorVoz.java` es un complemento de Android (v2) para Godot. Primero abre la ventana de dictado del sistema
(`RecognizerIntent`, normalmente la de Google, la misma que el micrófono del teclado: no necesita permiso propio);
si el móvil no tiene ninguna, usa el reconocedor por debajo (`SpeechRecognizer`) con el permiso del micrófono.
En el primer APK solo se usaba el reconocedor y en el Xiaomi de Pablo cortaba a los dos segundos (error «no te he
oído»): en esos móviles el reconocedor por defecto es el del fabricante (21 nov). La app no graba ni
guarda audio: recibe el texto y lo manda como cualquier pregunta escrita (`/tutor/pregunta`).

- El CI lo copia en la plantilla de Gradle (`com/pabloprieto/voz/`, junto a `GodotApp.java`) y activa
  `res://addons/tutor_voz`, que lo registra en el manifiesto con el permiso `RECORD_AUDIO` y la consulta
  `android.speech.RecognitionService` y `android.speech.action.RECOGNIZE_SPEECH` (sin ellas, en Android 11+ la app
  no ve el reconocedor ni la ventana de dictado). Cerrar la ventana sin hablar da el error -2 (no se avisa).
  En el APK de pruebas el aviso de error lleva el código de Android entre paréntesis.
- Señales: `voz_lista`, `voz_parcial(texto)`, `voz_texto(texto)`, `voz_error(código)`, `voz_permiso(bool)`.
  Métodos: `available()`, `has_permission()`, `ask_permission()`, `start(idioma)`, `stop()`, `cancel()`.
- Sin el complemento (escritorio, pruebas, APK sin Gradle) el botón de micrófono no sale; queda escribir la
  pregunta, y el teclado de Android también deja dictar.
- Privacidad: la política y el formulario de seguridad de datos deben decir que el micrófono se usa solo mientras
  se pulsa «Hablar», a través del reconocimiento de voz del sistema, y que la app no guarda el audio.
- **Sin probar en un móvil** hasta el primer APK con él.
