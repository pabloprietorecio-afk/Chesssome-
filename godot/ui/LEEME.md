# Iconos e ilustraciones de la interfaz

Todo lo que hay aquí lo genera `tools/ui/icons.mjs` (`npm run ui:icons`). No se edita a mano.

| Archivo | Qué es |
| --- | --- |
| `iconos.bin` | Atlas de iconos, en blanco con transparencia (un PNG; la extensión evita que Godot lo importe y lo comprima). El color se lo da la app al dibujarlos. |
| `iconos.json` | Qué icono hay en cada celda del atlas. |
| `emblema.bin` | Emblema de la app: el caballo en relieve sobre una tesela pastel (PNG de 640 × 640). |
| `ui_icons.gd` | Carga de los iconos y del emblema (`UiIcons.texture("bulb")`, `UiIcons.emblem()`). |

## Procedencia y licencias

- **Iconos generales** (bombilla, huellas, ojo, chincheta, etc.): [Phosphor Icons](https://phosphoricons.com),
  paquete de npm `@phosphor-icons/core` 2.1.1, **licencia MIT** (copia en `LICENCIA-phosphor.txt`). Se usan casi
  todos en su variante «duotone»; solo se les cambia el color y la opacidad del relleno suave (del 20 % al 26 %).
  La licencia MIT pide conservar su aviso de copyright: antes de publicar la app hay que enseñarlo en una
  pantalla de licencias (pendiente).
- **Piezas de ajedrez** (`piece_*`, `token_pawn`) **y emblema**: salen de nuestras propias piezas 3D, a través
  del atlas de las fichas (`godot/sets/fichas/iconos.bin`, que genera `tools/pieces/fichas.mjs`). Sin arte ajeno.

Qué icono de Phosphor corresponde a cada nombre está en la tabla `ICONS` de `tools/ui/icons.mjs`.
