# TutorVoz: preguntar al tutor hablando

`TutorVoz.java` es un complemento de Android (v2) para Godot: el reconocimiento de voz del sistema
(`SpeechRecognizer`, normalmente el de Google), sin interfaz propia. Está copiado del de A Tank Story
(repositorio Tank-Ahead, `android_plugins/speech_commands`), que funciona en el móvil de Pablo, con los mismos
extras que el dictado de WakeAgenda. El primer TutorVoz forzaba `EXTRA_LANGUAGE_PREFERENCE` y en el móvil de Pablo
cortaba a los dos segundos con «no te he oído» (21 nov): A Tank Story ya había aprendido que eso hace fallar al
servicio de Google. Si el servicio corta sin resultado final pero ya había entendido algo, vale eso. El permiso del
micrófono lo pide GDScript (`OS.request_permission`), como allí.

- El CI lo copia en la plantilla de Gradle (`com/pabloprieto/voz/`, junto a `GodotApp.java`) y activa
  `res://addons/tutor_voz`, que lo registra en el manifiesto con el permiso `RECORD_AUDIO` y la consulta
  `android.speech.RecognitionService` (sin ella, en Android 11+ la app no ve el reconocedor) y el micrófono como
  hardware opcional. En el APK de pruebas el aviso de error lleva el código de Android entre paréntesis.
- Señales: `voz_lista`, `voz_parcial(texto)`, `voz_texto(texto)`, `voz_error(código)`, `voz_audio(wav)` y
  `voz_nivel(0–1)`: el volumen de la voz para la onda del campo de texto (0 en silencio; con la grabación propia,
  medido sobre el ruido de fondo cada 100 ms; con el reconocedor del sistema, su `onRmsChanged`).
  Métodos: `available()`, `start(idioma)`, `stop()`, `cancel()`.
- Sin el complemento (escritorio, pruebas, APK sin Gradle) el botón de micrófono no sale; queda escribir la
  pregunta, y el teclado de Android también deja dictar.
- Privacidad: la política y el formulario de seguridad de datos deben decir que el micrófono se usa solo mientras
  se pulsa «Hablar», a través del reconocimiento de voz del sistema, y que la app no guarda el audio.
- **Sin probar en un móvil** hasta el primer APK con él.
