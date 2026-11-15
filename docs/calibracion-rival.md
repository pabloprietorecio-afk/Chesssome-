# Fuerza medida de los niveles del rival

Elo de Stockfish UCI_Elo (anclado a CCRL 40/4); no es Elo FIDE ni de Lichess.

| Nivel | Elo | Margen (±) |
|---|---|---|
| Muy fácil | 453 | 496 |
| Fácil | 1129 | 151 |
| Medio | 1578 | 110 |
| Difícil | 1782 | 106 |

| A | B | Puntos de A | Partidas |
|---|---|---|---|
| Muy fácil | Fácil | 0.0 | 24 |
| Fácil | Medio | 0.0 | 24 |
| Fácil | sf:1320 | 5.0 | 16 |
| Medio | Difícil | 5.0 | 24 |
| Medio | sf:1320 | 19.0 | 24 |
| Difícil | sf:1320 | 23.5 | 24 |
| Difícil | sf:1600 | 17.0 | 24 |

Medición del 15 nov 2026 (run 43755392831 de `calibrar-bot.yml`). Se paró antes de terminar las tandas de
«Muy difícil» (contra Stockfish 1600 y 2000, y contra «Difícil») porque la cuenta llegó al límite de minutos
de GitHub Actions; los resultados de las tandas terminadas se sacaron de sus registros. Stockfish 16 (paquete
de Ubuntu), UCI_LimitStrength + UCI_Elo, reloj 60 s + 0,6 s; el rival de la app, con sus tiempos de siempre.
