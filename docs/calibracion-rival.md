# Fuerza medida de los niveles del rival

Elo de Stockfish UCI_Elo (anclado a CCRL 40/4); no es Elo FIDE ni de Lichess. La app enseña el Elo redondeado a la
decena en la ventana de subniveles, con esa aclaración.

13 niveles en los cinco grupos de siempre (decisión de Pablo, 17 nov 2026: Muy fácil 1–3, Fácil 1–4, Medio 1–3,
Difícil 1–2 y Muy difícil; Medio 1 hacia 1200). Los cinco niveles de siempre no cambiaron de parámetros: son el
último escalón de su grupo. Su Elo sí se movió un poco con las partidas nuevas (más datos, mismo ajuste).

| Nivel | Índice | Elo | Margen (±) | Profundidad | Ruido | Al azar | Piensa (s) |
|---|---|---|---|---|---|---|---|
| Muy fácil 1 | 5 | 132 | 102 | 1 | 300 | 0.57 | 0.6 |
| Muy fácil 2 | 6 | 276 | 80 | 1 | 250 | 0.47 | 0.6 |
| Muy fácil 3 | 0 | 447 | 81 | 1 | 200 | 0.35 | 0.6 |
| Fácil 1 | 7 | 672 | 89 | 1 | 130 | 0.22 | 0.8 |
| Fácil 2 | 8 | 867 | 96 | 2 | 100 | 0.18 | 1.0 |
| Fácil 3 | 9 | 1009 | 82 | 2 | 75 | 0.1 | 1.0 |
| Fácil 4 | 1 | 1164 | 77 | 2 | 60 | 0.06 | 1.0 |
| Medio 1 | 10 | 1229 | 73 | 3 | 110 | 0.05 | 1.5 |
| Medio 2 | 11 | 1442 | 91 | 3 | 45 | 0.01 | 1.5 |
| Medio 3 | 2 | 1626 | 78 | 4 | 12 | 0.0 | 2.0 |
| Difícil 1 | 12 | 1733 | 84 | 4 | 0 | 0.0 | 2.5 |
| Difícil 2 | 3 | 1828 | 75 | 6 | 0 | 0.0 | 3.0 |
| Muy difícil | 4 | 1920 | 91 | 12 | 0 | 0.0 | 5.0 |

## Cómo se midió

- Partidas de cada nivel contra sus vecinos y, desde Medio 1, contra Stockfish con UCI_Elo 1320, 1600 y 2000
  (reloj de Stockfish 60 s + 0,6 s; el rival de la app con sus tiempos). Stockfish no baja de 1320: por debajo, la
  escala sale solo de las partidas entre niveles y es menos precisa.
- Ajuste por máxima verosimilitud de todas las tandas a la vez (tools/calibrar/ajustar.py sobre
  tools/calibrar/resultados). Margen = ±2 errores típicos; en la app, rd = la mitad.
- 15-16 nov: los cinco niveles de siempre (runs 43755392831 y 43763802148, Stockfish 16).
- 17 nov: los escalones nuevos, en tres rondas (runs 43981405753, 43992453813 y 43999764358; Stockfish 17.1 en los
  servidores de GitHub desde la segunda). Las dos primeras sirvieron para ajustar parámetros: lo que se descartó
  está en tools/calibrar/pruebas. Las tandas de las rondas 2 y 3 se reconstruyeron de la línea «HECHO» de cada
  registro.
- En un móvil, los niveles con tope de tiempo (sobre todo Difícil 2 y Muy difícil) pueden jugar algo peor que en
  el servidor.

## Tandas

| A | B | Puntos de A | Partidas |
|---|---|---|---|
| Muy fácil 3 | Fácil 4 | 0.0 | 24 |
| Muy fácil 3 | Fácil 1 | 9.0 | 40 |
| Fácil 4 | Medio 3 | 0.0 | 24 |
| Fácil 4 | sf:1320 | 5.0 | 16 |
| Medio 3 | Difícil 2 | 5.0 | 24 |
| Medio 3 | sf:1320 | 19.0 | 24 |
| Difícil 2 | Muy difícil | 9.5 | 24 |
| Difícil 2 | sf:1320 | 23.5 | 24 |
| Difícil 2 | sf:1600 | 17.0 | 24 |
| Muy difícil | sf:1600 | 15.0 | 24 |
| Muy difícil | sf:2000 | 16.0 | 24 |
| Muy fácil 1 | Muy fácil 3 | 3.0 | 24 |
| Muy fácil 1 | Muy fácil 2 | 12.0 | 40 |
| Muy fácil 2 | Muy fácil 3 | 11.5 | 40 |
| Muy fácil 2 | Fácil 1 | 1.0 | 24 |
| Fácil 2 | Fácil 1 | 24.5 | 32 |
| Fácil 2 | Fácil 3 | 9.5 | 32 |
| Fácil 3 | Fácil 4 | 9.0 | 32 |
| Fácil 3 | Medio 1 | 5.0 | 24 |
| Medio 1 | Fácil 4 | 18.5 | 32 |
| Medio 1 | Medio 2 | 5.0 | 24 |
| Medio 1 | sf:1320 | 9.5 | 24 |
| Medio 2 | Medio 3 | 4.0 | 24 |
| Medio 2 | sf:1320 | 18.0 | 24 |
| Difícil 1 | Medio 3 | 16.5 | 24 |
| Difícil 1 | Difícil 2 | 8.0 | 24 |
| Difícil 1 | sf:1600 | 16.5 | 24 |
