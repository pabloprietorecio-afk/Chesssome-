# Vídeos de espera

`caballo_1.ogv`, `caballo_2.ogv` y `caballo_3.ogv`: el caballo del logo saltando de su cuadrado y volviendo a él.
Los generó Pablo con PixVerse (modo de primer y último fotograma, con el logo sobre el fondo lila como los dos) y se
convierten con `tools/espera/videos.sh` (720 × 720, 24 fps, sin sonido, Ogg Theora). Los usa `ui/knight_wait.gd` en
las pantallas de espera del análisis de una partida, al azar.

- Godot no importa los `.ogv`: van en el filtro de exportación (`espera/*.ogv`) de `export_presets.cfg`.
- **Los primeros llevan la marca de agua de PixVerse** (arriba a la derecha): hay que cambiarlos por las descargas
  sin marca de agua, como el vídeo de la intro.
- Imagen de IA: confirmar los términos de uso comercial de PixVerse antes de publicar (igual que la intro).
