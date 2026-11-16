"""Ajusta el Elo de cada nivel del rival de la app a partir de las partidas de tests/calibrar.gd.

Modelo de Elo (logístico, base 10, escala 400) por máxima verosimilitud. Los Stockfish con UCI_Elo fijan la escala
(su Elo está anclado a CCRL 40/4, una lista de motores, no a jugadores humanos). A cada emparejamiento se le suma una
partida de tablas «virtual» para que un 100 % o un 0 % no lleve el Elo al infinito. El margen es ±2 errores típicos
(de la curvatura de la verosimilitud).

Uso: python tools/calibrar/ajustar.py resultados/*.json --salida calibracion.json --md calibracion.md
"""
import argparse
import json
import math

# Por índice de Bot.LEVELS (godot/core/bot.gd): los cinco de siempre y, detrás, los escalones nuevos del 17-11.
NAMES = ["Muy fácil 3", "Fácil 4", "Medio 3", "Difícil 2", "Muy difícil",
         "Muy fácil 1", "Muy fácil 2", "Fácil 1", "Fácil 2", "Fácil 3", "Medio 1", "Medio 2", "Difícil 1"]


def expected(ra, rb):
    return 1.0 / (1.0 + 10 ** ((rb - ra) / 400.0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--salida", default="calibracion.json")
    ap.add_argument("--md", default="calibracion.md")
    args = ap.parse_args()
    pairs = []  # (a, b_key, puntos_a, partidas)
    for f in args.files:
        d = json.load(open(f))
        pairs.append((int(d["a"]), str(d["b"]), float(d["puntos_a"]), int(d["partidas"])))
    # Agrupar por emparejamiento.
    agg = {}
    for a, b, p, n in pairs:
        k = (a, b)
        s, g = agg.get(k, (0.0, 0))
        agg[k] = (s + p, g + n)
    fixed = {}
    levels = sorted({a for a, _ in agg} | {int(b) for _, b in agg if not b.startswith("sf:")})
    for _, b in agg:
        if b.startswith("sf:"):
            fixed[b] = float(b[3:])
    if not fixed:
        raise SystemExit("Hace falta al menos un emparejamiento contra Stockfish para fijar la escala")
    r = {lv: 1500.0 for lv in levels}

    def rating(key):
        return fixed[key] if isinstance(key, str) and key.startswith("sf:") else r[int(key)]

    # Ascenso por gradiente / Newton diagonal.
    for _ in range(2000):
        grad = {lv: 0.0 for lv in levels}
        hess = {lv: 0.0 for lv in levels}
        for (a, b), (s, g) in agg.items():
            s2, g2 = s + 0.5, g + 1  # tablas virtual
            e = expected(r[a], rating(b))
            k = math.log(10) / 400.0
            grad[a] += k * (s2 - g2 * e)
            hess[a] += k * k * g2 * e * (1 - e)
            if not b.startswith("sf:"):
                bi = int(b)
                grad[bi] -= k * (s2 - g2 * e)
                hess[bi] += k * k * g2 * e * (1 - e)
        step = 0.0
        for lv in levels:
            if hess[lv] > 0:
                d = grad[lv] / hess[lv]
                d = max(-200.0, min(200.0, d))
                r[lv] += d
                step = max(step, abs(d))
        if step < 0.01:
            break
    out = {"escala": "Elo de Stockfish UCI_Elo (anclado a CCRL 40/4); no es Elo FIDE ni de Lichess", "niveles": {}, "emparejamientos": []}
    for lv in levels:
        h = 0.0
        for (a, b), (s, g) in agg.items():
            if a == lv or (not b.startswith("sf:") and int(b) == lv):
                e = expected(r[a], rating(b))
                k = math.log(10) / 400.0
                h += k * k * (g + 1) * e * (1 - e)
        se = 1.0 / math.sqrt(h) if h > 0 else float("inf")
        out["niveles"][str(lv)] = {"nombre": NAMES[lv] if lv < len(NAMES) else str(lv), "elo": round(r[lv]), "margen": round(2 * se)}
    for (a, b), (s, g) in sorted(agg.items()):
        out["emparejamientos"].append({"a": a, "b": b, "puntos_a": s, "partidas": g})
    json.dump(out, open(args.salida, "w"), ensure_ascii=False, indent=2)
    lines = ["# Fuerza medida de los niveles del rival", "", out["escala"] + ".", "", "| Nivel | Elo | Margen (±) |", "|---|---|---|"]
    for lv in levels:
        n = out["niveles"][str(lv)]
        lines.append(f"| {n['nombre']} | {n['elo']} | {n['margen']} |")
    lines += ["", "| A | B | Puntos de A | Partidas |", "|---|---|---|---|"]
    for p in out["emparejamientos"]:
        lines.append(f"| {NAMES[p['a']]} | {p['b'] if p['b'].startswith('sf:') else NAMES[int(p['b'])]} | {p['puntos_a']} | {p['partidas']} |")
    open(args.md, "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
