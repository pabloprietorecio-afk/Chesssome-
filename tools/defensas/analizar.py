#!/usr/bin/env python3
"""Las otras salidas del rival en la solución de cada problema, analizadas con Stockfish.

En el «paso a paso» de un problema, la respuesta del rival se etiqueta «Su mejor defensa» porque así viene en la
solución de Lichess. La app no lo comprobaba ni decía qué pasaba con las demás jugadas. Este script analiza, para cada
respuesta del rival con entre 2 y MAX_LEGAL jugadas legales, TODAS las jugadas (MultiPV) y guarda su valoración y la
continuación del motor. La app (core/move_why.gd, alternatives_paras) escribe con eso «Si Rh7, Cxf5+ …» y comprueba en
el tablero lo que afirma (mate, captura, jaque descubierto, pieza que cae).

Para las respuestas con más jugadas solo se comprueba si la respuesta de la solución está entre las mejores, que es lo
que afirma la frase genérica («es la que más resiste»); si otra jugada aguantaba claramente más, se guarda esa sola
(la entrada trae entonces menos jugadas que las legales).

Uso:  python3 tools/defensas/analizar.py [--depth 20] [--engine /usr/games/stockfish]
Necesita python-chess (pip install chess) y un Stockfish en el PATH.
Salida: godot/data/defensas.json
  {"motor", "profundidad", "posiciones": {"<piezas> <turno>": {"j": jugada de la solución, "v": su valoración,
   "o": [[jugada, valoración, [continuación del motor…]], …]}}}
  Valoraciones desde el bando que mueve (el que se defiende): centipeones (int) o mate ("#-2": le dan mate en 2).
"""
import argparse
import json
import os
import sys
import time

import chess
import chess.engine

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAX_LEGAL = 7
PV_PLIES = 7


def score_out(score: chess.engine.PovScore, turn: chess.Color):
    s = score.pov(turn)
    if s.is_mate():
        return "#%d" % s.mate()
    return int(s.score())


SAME_CP = 150


def rank(v) -> float:
    """Para ordenar valoraciones: mayor = mejor para el que se defiende (como DefenseData.rank)."""
    if isinstance(v, str):
        n = int(v[1:])
        return -1000000.0 - n if n < 0 else 1000000.0 - n  # mate en contra: cuanto más tarde, mejor
    return float(v)


def compare(played, other) -> int:
    """-1 si `other` es peor que la jugada de la solución, 0 si aguanta parecido, 1 si aguanta más
    (como DefenseData.compare)."""
    d = rank(played) - rank(other)
    pm, om = isinstance(played, str), isinstance(other, str)
    if not pm and not om:
        margin = max(float(SAME_CP), abs(float(played)) * 0.25)
        return -1 if d >= margin else (1 if d <= -margin else 0)
    if pm and om and (int(played[1:]) < 0) == (int(other[1:]) < 0):
        return 0 if d == 0 else (-1 if d > 0 else 1)
    return -1 if d > 0 else 1


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--depth", type=int, default=20)
    ap.add_argument("--engine", default="stockfish")
    ap.add_argument("--out", default=os.path.join(ROOT, "godot", "data", "defensas.json"))
    args = ap.parse_args()
    puzzles = json.load(open(os.path.join(ROOT, "godot", "data", "demo_puzzles.json")))["puzzles"]
    engine = chess.engine.SimpleEngine.popen_uci(args.engine)
    engine.configure({"Threads": 1, "Hash": 256})
    name = engine.id.get("name", "Stockfish")
    positions = {}
    big = {"total": 0, "mejor_o_parecida": 0, "peor": []}
    t0 = time.time()
    for n, p in enumerate(puzzles):
        board = chess.Board(p["fen"])
        for i, uci in enumerate(p["moves"]):
            legal = board.legal_moves.count()
            if i >= 2 and i % 2 == 0 and legal >= 2:
                if legal <= MAX_LEGAL:
                    infos = engine.analyse(board, chess.engine.Limit(depth=args.depth), multipv=legal)
                    entry = {"j": uci, "v": None, "o": []}
                    for info in infos:
                        pv = info.get("pv", [])
                        if not pv:
                            continue
                        mv = pv[0].uci()
                        val = score_out(info["score"], board.turn)
                        if mv == uci:
                            entry["v"] = val
                        else:
                            entry["o"].append([mv, val, [m.uci() for m in pv[1:1 + PV_PLIES]]])
                    if entry["v"] is None or len(entry["o"]) != legal - 1:
                        print("AVISO: análisis incompleto en", p["id"], i, file=sys.stderr)
                    else:
                        key = " ".join(board.fen().split(" ")[:2])
                        positions[key] = entry
                else:
                    # Solo se comprueba la frase genérica: ¿la respuesta de la solución está entre las mejores?
                    best = engine.analyse(board, chess.engine.Limit(depth=args.depth), multipv=1)[0]
                    mine = engine.analyse(board, chess.engine.Limit(depth=args.depth), root_moves=[chess.Move.from_uci(uci)])
                    b, m = score_out(best["score"], board.turn), score_out(mine["score"], board.turn)
                    big["total"] += 1
                    if best["pv"][0].uci() != uci and compare(m, b) > 0:
                        # Otra jugada aguantaba claramente más: se guarda solo esa, para que la app lo diga.
                        big["peor"].append([p["id"], i, uci, m, best["pv"][0].uci(), b])
                        key = " ".join(board.fen().split(" ")[:2])
                        positions[key] = {"j": uci, "v": m, "o": [[best["pv"][0].uci(), b, [x.uci() for x in best["pv"][1:1 + PV_PLIES]]]]}
                    else:
                        big["mejor_o_parecida"] += 1
            board.push_uci(uci)
        if n % 20 == 19:
            print("%d/%d problemas, %d posiciones, %.0f s" % (n + 1, len(puzzles), len(positions), time.time() - t0), file=sys.stderr)
    engine.quit()
    out = {"motor": name, "profundidad": args.depth, "posiciones": positions}
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        f.write("\n")
    print("%s, profundidad %d: %d posiciones guardadas (las de 2 a %d jugadas y las raras de más) -> %s" % (name, args.depth, len(positions), MAX_LEGAL, args.out))
    print("Respuestas con más de %d jugadas: %d; entre las mejores: %d; con otra que aguantaba más: %s" % (MAX_LEGAL, big["total"], big["mejor_o_parecida"], json.dumps(big["peor"])))


if __name__ == "__main__":
    main()
