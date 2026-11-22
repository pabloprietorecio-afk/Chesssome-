#!/usr/bin/env python3
"""Ajusta la curva de puntos esperados (tools/curva/medir.py → curva_cruda.json) y escribe la tabla que usan el
servidor y la app (godot/data/curva_puntos.json).

Para cada tramo de Elo: puntos = suelo + (1 − 2·suelo) / (1 + exp(−k·cp)) — una curva en S (como la de Lichess)
con su pendiente k y un suelo (lo que se sigue sacando con la partida perdida: errores del rival, tiempo…). Se ajusta
con mínimos cuadrados ponderados por el número de posiciones; después, k y el suelo se suavizan a lo largo del Elo.
Los mates (a favor / en contra) se toman tal cual, por tramo.

Uso: python3 ajustar.py curva_cruda.json [--ritmo l|b|todo] > informe.txt   (escribe la tabla)
"""
import argparse
import json
import math
import sys

import numpy as np
from scipy.optimize import least_squares

ELOS = list(range(600, 2701, 100))
GRID = list(range(-2000, 2001, 50))


def curve(cp, k, floor):
    return floor + (1 - 2 * floor) / (1 + np.exp(-k * cp))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("--ritmo", default="todo", choices=["l", "b", "todo"])
    ap.add_argument("--out", default="godot/data/curva_puntos.json")
    ap.add_argument("--min", type=int, default=200, help="posiciones mínimas por casilla")
    a = ap.parse_args()
    raw = json.load(open(a.raw))
    cats = ["l", "b"] if a.ritmo == "todo" else [a.ritmo]
    cells = raw["celdas"]

    fits = {}
    mates = {}
    print(f"Partidas usadas: {raw['partidas_usadas']} (de {raw['partidas_leidas']} leídas); ritmo: {a.ritmo}")
    print("Elo   posiciones    k (1/cp)   suelo   ±error   mate+   mate-   E(-700)  E(-900)  E(+300)")
    for elo in ELOS:
        xs, ys, ws = [], [], []
        mp = [0, 0.0]
        mm = [0, 0.0]
        for cat in cats:
            for key, (n, s) in cells.items():
                c, e, b = key.split("|")
                if c != cat or int(e) != elo:
                    continue
                if b == "M+":
                    mp[0] += n
                    mp[1] += s
                elif b == "M-":
                    mm[0] += n
                    mm[1] += s
                else:
                    xs.append(float(b))
                    ys.append(s / n)
                    ws.append(n)
        # Casillas iguales de varios ritmos: se suman.
        agg = {}
        for x, y, w in zip(xs, ys, ws):
            t = agg.setdefault(x, [0, 0.0])
            t[0] += w
            t[1] += y * w
        X = np.array(sorted(x for x in agg if agg[x][0] >= a.min))
        if len(X) < 20:
            print(f"{elo:5d}   pocas posiciones: se interpola")
            continue
        W = np.array([agg[x][0] for x in X], dtype=float)
        Y = np.array([agg[x][1] / agg[x][0] for x in X])
        sw = np.sqrt(W)
        res = least_squares(lambda p: (curve(X, p[0], p[1]) - Y) * sw, x0=[0.004, 0.05], bounds=([1e-4, 0.0], [0.05, 0.3]))
        k, floor = res.x
        err = float(np.sqrt(np.sum(W * (curve(X, k, floor) - Y) ** 2) / np.sum(W)))
        fits[elo] = {"k": float(k), "suelo": float(floor), "n": int(W.sum()), "error": err}
        mates[elo] = (mp[1] / mp[0] if mp[0] >= a.min else None, mm[1] / mm[0] if mm[0] >= a.min else None)
        f = lambda cp: curve(np.array([cp]), k, floor)[0]
        print(f"{elo:5d}  {int(W.sum()):11d}   {k:.6f}   {floor:.3f}   {err:.3f}   "
              f"{mates[elo][0] if mates[elo][0] is not None else float('nan'):.3f}   {mates[elo][1] if mates[elo][1] is not None else float('nan'):.3f}   "
              f"{f(-700):.3f}    {f(-900):.3f}    {f(300):.3f}")

    if not fits:
        sys.exit("sin datos")
    # Suavizado a lo largo del Elo (media ponderada con vecinos) e interpolación de los tramos sin datos.
    known = sorted(fits)
    def smooth(field):
        out = {}
        for elo in ELOS:
            num = den = 0.0
            for e in known:
                w = fits[e]["n"] * math.exp(-((e - elo) / 150.0) ** 2)
                num += w * fits[e][field]
                den += w
            out[elo] = num / den
        return out
    ks = smooth("k")
    fl = smooth("suelo")
    mp_known = [(e, mates[e][0]) for e in known if mates[e][0] is not None]
    mm_known = [(e, mates[e][1]) for e in known if mates[e][1] is not None]
    def interp(pts, elo, default):
        if not pts:
            return default
        es = [p[0] for p in pts]
        vs = [p[1] for p in pts]
        return float(np.interp(elo, es, vs))
    table = {
        "fuente": f"Partidas de Lichess con evaluación ({raw['partidas_usadas']} partidas; volcado en volcado.txt del flujo «Curva de puntos esperados»); ritmo {a.ritmo}; tools/curva/ajustar.py",
        "modelo": "puntos = suelo + (1 - 2·suelo) / (1 + exp(-k·cp)), por tramo de Elo (del jugador que juega)",
        "elos": ELOS,
        "cp": GRID,
        "k": [round(ks[e], 7) for e in ELOS],
        "suelo": [round(fl[e], 4) for e in ELOS],
        "puntos": [[round(float(curve(np.array([c]), ks[e], fl[e])[0]), 4) for c in GRID] for e in ELOS],
    }
    top = [row[-1] for row in table["puntos"]]
    bottom = [row[0] for row in table["puntos"]]
    # Un mate a favor vale al menos lo que la mejor evaluación de la tabla (y uno en contra, como mucho la peor).
    table["mate_a_favor"] = [round(max(interp(mp_known, e, 0.97), top[i]), 4) for i, e in enumerate(ELOS)]
    table["mate_en_contra"] = [round(min(interp(mm_known, e, 0.03), bottom[i]), 4) for i, e in enumerate(ELOS)]
    json.dump(table, open(a.out, "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"\nTabla escrita en {a.out}")


if __name__ == "__main__":
    main()
