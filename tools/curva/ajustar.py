#!/usr/bin/env python3
"""Convierte la medición de tools/curva/medir.py (curva_cruda.json) en la tabla de puntos esperados que usan el
servidor y la app (godot/data/curva_puntos.json).

La tabla es la media real de puntos por tramo de Elo y evaluación, sin forzar una fórmula. Se probó a ajustar una
curva en S (como la de Lichess) por tramo, pero los datos no tienen esa forma: con evaluaciones grandes, los
aficionados siguen sacando bastantes más puntos de los que da la S, y la S ajustada se quedaba corta justo donde
importa (con 1500: −650 → 0,197 de verdad frente a 0,165 de la S; −900 → 0,092 frente a 0,112). Con la S, regalar
un caballo con −6,5 bajaba 5 puntos; con los datos, 10.

Pasos:
1. Media ponderada con un núcleo gaussiano en Elo (60) y evaluación (25 cp), descontando la diferencia de Elo con
   el rival (regresión en la diferencia y el valor en 0: es lo que se espera contra uno del mismo nivel). Si en un punto hay menos de MIN_N
   posiciones (los extremos, los niveles altos), el núcleo se ensancha hasta tenerlas.
2. Simetría: E(cp) = (E(cp) + 1 − E(−cp)) / 2 (lo que saca uno lo pierde el otro).
3. Los tramos de Elo con menos de un millón de posiciones copian el más cercano que sí las tiene.
4. Monótona en la evaluación y en el Elo (regresión isótona: con ventaja, el más fuerte saca al menos lo mismo).
5. Mates a favor / en contra: la media por tramo, suavizada igual; un mate vale al menos lo mejor de la tabla.

Uso: python3 ajustar.py curva_cruda.json [--ritmo l|b|todo] [--out godot/data/curva_puntos.json]
"""
import argparse
import json
import math
import sys

import numpy as np

ELOS = list(range(600, 2701, 100))
GRID = list(range(-2000, 2001, 25))
MIN_N = 4000
MIN_ROW = 1_000_000  # posiciones para que un tramo de Elo tenga fila propia


def lichess(cp):
    return 1 / (1 + math.exp(-0.00368208 * cp))


def isotonic(y, w):
    """Regresión isótona creciente (PAV), ponderada."""
    blocks = []  # [suma y·w, suma w, cuántos]
    for yi, wi in zip(y, w):
        blocks.append([yi * wi, wi, 1])
        while len(blocks) > 1 and blocks[-2][0] / blocks[-2][1] > blocks[-1][0] / blocks[-1][1]:
            a = blocks.pop()
            blocks[-1][0] += a[0]
            blocks[-1][1] += a[1]
            blocks[-1][2] += a[2]
    out = []
    for s, ws, n in blocks:
        out += [s / ws] * n
    return np.array(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("--ritmo", default="l", choices=["l", "b", "todo"])
    ap.add_argument("--out", default="godot/data/curva_puntos.json")
    a = ap.parse_args()
    raw = json.load(open(a.raw))
    cats = ["l", "b"] if a.ritmo == "todo" else [a.ritmo]

    # Casillas: (elo, diferencia con el rival, cp) → [n, suma]; los mates, con cp = ±inf. Las mediciones antiguas no
    # traen la diferencia (clave de tres partes): cuentan como diferencia 0.
    cells = {}
    for key, (n, s) in raw["celdas"].items():
        parts = key.split("|")
        c, e, b = parts[0], int(parts[1]), parts[-1]
        g = int(parts[2]) if len(parts) == 4 else 0
        if c not in cats:
            continue
        x = math.inf if b == "M+" else -math.inf if b == "M-" else float(b)
        t = cells.setdefault((e, g, x), [0, 0.0])
        t[0] += n
        t[1] += s
    keys = list(cells)
    E = np.array([k[0] for k in keys], dtype=float)
    G = np.array([k[1] for k in keys], dtype=float)
    C = np.array([k[2] for k in keys], dtype=float)
    N = np.array([cells[k][0] for k in keys], dtype=float)
    Y = np.array([cells[k][1] / cells[k][0] for k in keys])
    finite = np.isfinite(C)
    with_gap = bool((G != 0).any())

    def estimate(w):
        """Puntos con el rival del mismo Elo: regresión ponderada en la diferencia, y el valor en 0."""
        sw = w.sum()
        if not with_gap:
            return float((w * Y).sum() / sw)
        gm = (w * G).sum() / sw
        ym = (w * Y).sum() / sw
        var = (w * (G - gm) ** 2).sum()
        slope = (w * (G - gm) * (Y - ym)).sum() / var if var > 0 else 0.0
        return float(ym - slope * gm)

    def kernel(elo, cp):
        se, sc = 60.0, 25.0
        for _ in range(12):
            w = np.where(finite, N * np.exp(-(((E - elo) / se) ** 2) - ((np.where(finite, C, 0) - cp) / sc) ** 2), 0.0)
            if w.sum() >= MIN_N:
                break
            se *= 1.4
            sc *= 1.4
        return estimate(w), float(w.sum())

    rows = []
    weights = []
    for elo in ELOS:
        vals, ns = zip(*(kernel(elo, cp) for cp in GRID))
        v = np.array(vals)
        v = (v + 1 - v[::-1]) / 2  # GRID es simétrica: v[::-1] es E(−cp)
        nn = np.array(ns)
        nn = (nn + nn[::-1]) / 2
        rows.append(isotonic(v, nn))
        weights.append(nn)

    # Tramos con muy pocas posiciones (las partidas lentas de 2500+ son pocas): copian el tramo fiable más cercano.
    per_elo = {elo: float(N[(E == elo)].sum()) for elo in ELOS}
    good = [i for i, elo in enumerate(ELOS) if per_elo[elo] >= MIN_ROW]
    if good:
        for i, elo in enumerate(ELOS):
            if per_elo[elo] < MIN_ROW:
                j = min(good, key=lambda g: abs(g - i))
                rows[i] = rows[j].copy()
                weights[i] = weights[j]

    # Monótona también en el Elo: con ventaja, un jugador más fuerte saca al menos lo mismo (y con desventaja, como
    # mucho lo mismo). Arregla el ruido de los tramos altos, con pocas partidas lentas (2500+).
    R = np.array(rows)
    Wr = np.array([w.sum() for w in weights])
    for j, cp in enumerate(GRID):
        if cp > 0:
            R[:, j] = isotonic(R[:, j], Wr)
        elif cp < 0:
            R[:, j] = -isotonic(-R[:, j], Wr)
    rows = [isotonic(r, w) for r, w in zip(R, weights)]

    def mate_row(x):
        out = []
        sel = C == x
        se = 60.0
        for elo in ELOS:
            se = 60.0
            while True:
                w = np.where(sel, N * np.exp(-(((E - elo) / se) ** 2)), 0.0)
                if w.sum() >= MIN_N or se > 2000:
                    break
                se *= 1.4
            out.append(estimate(w) if w.sum() > 0 else (0.97 if x > 0 else 0.03))
        return out

    mp = mate_row(math.inf)
    mm = mate_row(-math.inf)
    # Simetría de los mates y, como mucho / como poco, lo de la tabla.
    mate_for = [max((p + 1 - m) / 2, r[-1]) for p, m, r in zip(mp, mm, rows)]
    mate_against = [min(1 - f, r[0]) for f, r in zip(mate_for, rows)]

    total = N.sum()
    print(f"Partidas usadas: {raw['partidas_usadas']} (de {raw['partidas_leidas']} leídas); ritmo: {a.ritmo}; {int(total)} posiciones; "
          + ("descontando la diferencia con el rival" if with_gap else "sin la diferencia con el rival"))
    show = [-900, -650, -300, -100, 0, 100, 300, 650, 900]
    print("Elo    " + "  ".join(f"{c:>6d}" for c in show) + "   mate+   mate-   Ce4(-650→-900)")
    for i, elo in enumerate(ELOS):
        r = rows[i]
        at = {c: r[GRID.index(c)] for c in show}
        print(f"{elo:4d}   " + "  ".join(f"{at[c]:6.3f}" for c in show) + f"   {mate_for[i]:.3f}   {mate_against[i]:.3f}   {100 * (at[-650] - at[-900]):5.1f}")
    print("Lichess" + "  ".join(f"{lichess(c):6.3f}" for c in show) + f"                   {100 * (lichess(-650) - lichess(-900)):5.1f}")

    table = {
        "fuente": f"Partidas de Lichess con evaluación ({raw['partidas_usadas']} partidas, {int(total)} posiciones; ritmo {a.ritmo}); tools/curva/medir.py y tools/curva/ajustar.py",
        "modelo": "media real de puntos del jugador por tramo de Elo y evaluación desde su lado (suavizada, simétrica y monótona)",
        "elos": ELOS,
        "cp": GRID,
        "puntos": [[round(float(x), 4) for x in r] for r in rows],
        "mate_a_favor": [round(x, 4) for x in mate_for],
        "mate_en_contra": [round(x, 4) for x in mate_against],
    }
    if a.out != "-":
        json.dump(table, open(a.out, "w"), ensure_ascii=False, separators=(",", ":"))
        print(f"\nTabla escrita en {a.out}")


if __name__ == "__main__":
    sys.exit(main())
