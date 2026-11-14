# Sonidos de la partida

Son grabaciones de objetos e instrumentos reales, todas de **dominio público (CC0 1.0)**: se pueden usar,
modificar y redistribuir, también con fines comerciales, sin pedir permiso y sin obligación de citar al autor.
Aun así, aquí queda la procedencia de cada una. Licencias comprobadas el 13 de noviembre de 2026.

| Archivos | Qué suena | Grabación de origen | Autor | Dónde |
|---|---|---|---|---|
| `arrastre_1.wav`, `arrastre_2.wav`, `arrastre_3.wav` | La pieza se arrastra por el tablero | `scrape-1` y `scrape-2` de «Scrapes»: un objeto arrastrado sobre un bloque de hormigón | Sin autor indicado en la página; se grabaron para el juego Stendhal | [OpenGameArt](https://opengameart.org/content/scrapes) |
| `posar_1.wav`, `posar_2.wav`, `posar_3.wav` | La pieza se asienta en su casilla | `wood_hit_07`, `wood_hit_03` y `wood_hit_06` de «100 CC0 metal and wood SFX» | rubberduck | [OpenGameArt](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) |
| `captura_1.wav`, `captura_2.wav` | Captura | `wood_hit_08` y `wood_hit_04` del mismo paquete | rubberduck | [OpenGameArt](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) |
| `caida_rey.wav` | El rey cae en el mate | `wood_falling_01` del mismo paquete: un objeto de madera que cae y rebota | rubberduck | [OpenGameArt](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) |
| `jaque.wav` | Aviso de jaque | Dos golpes de timbal de «VSCO 2: Community Edition» (`Timpani4_Hit_v3` y `Timpani2_Hit_v3`), a un semitono, el segundo más fuerte | Versilian Studios (grabado por Sam Gossner y Simon Dalzell) | [GitHub](https://github.com/sgossner/VSCO-2-CE) |

Lo único que se hace con las grabaciones es recortarlas, darles entrada y salida suaves, ajustar el nivel y,
en el jaque, poner un golpe de timbal detrás de otro. No hay síntesis. El proceso está en
`tools/assets/prepare-sounds.py`; las grabaciones de OpenGameArt se bajan en la CI con
`tools/assets/fetch-sounds.sh` (rama `sonidos-fetch` → rama `assets-snd`).

## Límites que conviene conocer

- **Ninguna es una grabación de piezas de ajedrez sobre un tablero.** Son madera contra madera y un roce sobre
  hormigón: se parecen, pero no es lo mismo. Las grabaciones CC0 de piezas de ajedrez de verdad que hemos
  encontrado están en Freesound (por ejemplo, [«Chess piece sliding 1», de Alnotreally](https://freesound.org/people/Alnotreally/sounds/801348/)),
  que no permite bajarlas de forma automática: hay que hacerlo a mano, con una cuenta. Si se bajan, basta
  dejarlas aquí con el mismo nombre de archivo.
- **Se han elegido sin oírlas**: quien las preparó (Claude) no puede escuchar audio. La elección se hizo por
  medidas: duración, número de golpes, reparto de frecuencias y forma de onda. Hay que juzgarlas de oído en
  un teléfono.
- Los sonidos de Lichess no se pueden usar en una app comercial: su licencia es AGPLv3+ o no libre
  (ver `COPYING.md` en el repositorio de Lichess).
