# Texturas de los acabados realistas

Fotografías de materiales de dos bibliotecas de dominio público. Las dos publican todos sus recursos bajo
**CC0**: se pueden usar, modificar y redistribuir, también en un producto comercial, sin atribución obligatoria.

- **Poly Haven** — https://polyhaven.com/license
- **ambientCG** — https://docs.ambientcg.com/license

Licencias comprobadas el 13 nov 2026.

| Archivo | Recurso | Biblioteca | Uso |
| --- | --- | --- | --- |
| `arce.jpg`, `arce_normal.jpg` | [White Maple Veneer](https://polyhaven.com/a/white_maple_veneer) (Jenelle van Heerden) | Poly Haven | Madera: casillas claras |
| `nogal.jpg`, `nogal_normal.jpg` | [Walnut Veneer](https://polyhaven.com/a/walnut_veneer) (Jenelle van Heerden) | Poly Haven | Madera: casillas oscuras |
| `palisandro.jpg` | [Rosewood Veneer1](https://polyhaven.com/a/rosewood_veneer1) (Jenelle van Heerden) | Poly Haven | Madera: marco |
| `boj.jpg` | [Bamboo Veneer](https://polyhaven.com/a/bamboo_veneer) (Jenelle van Heerden) | Poly Haven | Madera: piezas claras |
| `ebano.jpg` | [Flamed Black Veneer](https://polyhaven.com/a/flamed_black_veneer) (Jenelle van Heerden) | Poly Haven | Madera: piezas oscuras |
| `marmol_crema.jpg` | [Marble 014](https://ambientcg.com/a/Marble014) | ambientCG | Mármol: casillas claras |
| `marmol_pizarra.jpg` | [Marble 023](https://ambientcg.com/a/Marble023) | ambientCG | Mármol: casillas oscuras |
| `marmol_blanco.jpg` | [Marble 021](https://ambientcg.com/a/Marble021) | ambientCG | Mármol: piezas claras |
| `marmol_negro.jpg` | [Marble 016](https://ambientcg.com/a/Marble016) | ambientCG | Mármol: piezas oscuras y marco |
| `acero.jpg`, `acero_normal.jpg` | [Metal 009](https://ambientcg.com/a/Metal009) | ambientCG | Metal: casillas (acero cepillado) |
| `laton.jpg` | [Metal 048 B](https://ambientcg.com/a/Metal048B) | ambientCG | Metal: piezas claras |
| `bronce.jpg` | [Metal 036](https://ambientcg.com/a/Metal036) | ambientCG | Metal: piezas oscuras y marco |

Los nombres de los archivos dicen qué material representan en el juego, no siempre el fotografiado (el «boj» es
una chapa de bambú; el «ébano», una chapa teñida de negro).

Cómo se obtuvieron: `tools/assets/fetch.sh` los descarga en la CI con las API públicas de las dos bibliotecas
(versión de 1K) y `tools/assets/prepare.py` los reduce y renombra. No están retocados.
