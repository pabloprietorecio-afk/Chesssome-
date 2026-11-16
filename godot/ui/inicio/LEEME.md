# Imágenes de las pantallas de inicio

Las usa `ui/home_screens.gd` (`.bin` = PNG que Godot no importa; se cargan con `Image.load_png_from_buffer`).

| Archivo | Origen | Licencia |
|---|---|---|
| `fondo_cabecera[_noche].bin`, `fondo_suelo[_noche].bin` | Render propio con Blender (rey y peón de revolución + suelo), compuesto con numpy. Scripts en `tools/inicio/` (`piezas.py`, `fondo.py`, `suelo.py`, `exr2npy.py`). | Propias (los renders son de quien los crea). |
| `portada_caballo.bin`, `desafio_trofeo.bin` | Recortes, a tamaño nativo, de la imagen de referencia generada con IA que aportó Pablo (`tools/inicio/recortes.py`). | Pendiente de confirmar los términos de la herramienta de IA usada antes de publicar. |
| `icono.bin` | Dibujado con PIL a partir de la silueta del caballo de la propia app. | Propio. |

La fuente de la nota manuscrita es Caveat Bold (`godot/fonts/`, OFL 1.1, de `@fontsource/caveat`).
En japonés e hindi la nota usa la fuente normal, porque Caveat no tiene esos alfabetos.
