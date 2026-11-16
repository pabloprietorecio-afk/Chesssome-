# Fuerza medida de los niveles del rival

Elo de Stockfish UCI_Elo (anclado a CCRL 40/4); no es Elo FIDE ni de Lichess.

| Nivel | Elo | Margen (±) |
|---|---|---|
| Muy fácil | 457 | 496 |
| Fácil | 1133 | 151 |
| Medio | 1589 | 113 |
| Difícil | 1807 | 87 |
| Muy difícil | 1912 | 91 |

| A | B | Puntos de A | Partidas |
|---|---|---|---|
| Muy fácil | Fácil | 0.0 | 24 |
| Fácil | Medio | 0.0 | 24 |
| Fácil | sf:1320 | 5.0 | 16 |
| Medio | Difícil | 5.0 | 24 |
| Medio | sf:1320 | 19.0 | 24 |
| Difícil | Muy difícil | 9.5 | 24 |
| Difícil | sf:1320 | 23.5 | 24 |
| Difícil | sf:1600 | 17.0 | 24 |
| Muy difícil | sf:1600 | 15.0 | 24 |
| Muy difícil | sf:2000 | 16.0 | 24 |

Medición del 15 y 16 nov 2026 (runs 43755392831 y 43763802148 de `calibrar-bot.yml`). La primera se paró antes
de las tandas de «Muy difícil» porque la cuenta llegó al límite de minutos de GitHub Actions (el repositorio era
privado); esas tandas (contra Stockfish 1600 y 2000, y contra «Difícil») se jugaron en la segunda, con el
repositorio ya público. Los resultados se sacaron de las líneas «HECHO» de los registros de cada tanda
(tools/calibrar/resultados) y el ajuste se hizo con todas a la vez (tools/calibrar/ajustar.py). Stockfish 16
(paquete de Ubuntu), UCI_LimitStrength + UCI_Elo, reloj 60 s + 0,6 s; el rival de la app, con sus tiempos de
siempre. En la app, rd = la mitad del margen.
