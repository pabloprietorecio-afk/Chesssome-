# YouTubeCine: el vídeo de los Finales de campeones dentro de la app

`YouTubeCine.java` es un complemento de Android (v2) para Godot: pone el reproductor oficial de YouTube (API de
iframe) en el WebView del sistema, encima del hueco que le deja la pantalla del cine, y cuenta a GDScript el tiempo
del vídeo cada 100 ms. El director (`godot/core/cine_film.gd`) decide cuándo pausar; `godot/core/cine_player.gd` es
el puente con este complemento.

- El CI lo copia en la plantilla de Gradle (`com/pabloprieto/cine/`, junto a `GodotApp.java`) y activa
  `res://addons/youtube_cine`, que lo registra en el manifiesto (`org.godotengine.plugin.v2.YouTubeCine`).
- Sin el complemento (escritorio, pruebas, APK sin Gradle) la app hace lo de antes: «Ver el vídeo» abre YouTube fuera.
- Requisitos de YouTube: URL base `https://com.pabloprieto.chessome` (Referer), nada encima del reproductor,
  al menos 200 × 200 px, solo funciones documentadas. Detalle en `claude/chessome-cine.md` (proyecto).
- **Sin probar en un móvil** hasta el primer APK con él.
