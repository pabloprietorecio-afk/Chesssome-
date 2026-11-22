#!/usr/bin/env python3
"""Curva de puntos esperados por nivel (22 nov): lee por la entrada un volcado PGN de Lichess y, de las partidas que
traen evaluación del motor (%eval), apunta para cada posición y cada jugador: su Elo, la evaluación desde su lado y lo
que sacó en la partida (1, ½ o 0). Agrupa por Elo (tramos de 100), ritmo (blitz o lento) y evaluación (tramos de
25 centipeones; los mates aparte). Salida: JSON con [posiciones, suma de puntos] por casilla.

Es lo que chess.com llama «Expected Points» (puntos esperados según el Elo del jugador y la evaluación), medido con
datos públicos: chess.com no publica su curva.

Uso: zstdcat lichess_db_standard_rated_AAAA-MM.pgn.zst | python3 medir.py --games 1500000 > curva_cruda.json
"""
import argparse
import json
import re
import sys
import time

EVAL = re.compile(rb"\[%eval (#?-?[0-9.]+)\]")
CP_STEP = 25
CP_MAX = 2500


def category(tc: bytes) -> str:
    # Lichess: duración estimada = base + 40 × incremento.
    try:
        base, inc = tc.split(b"+")
        t = int(base) + 40 * int(inc)
    except Exception:
        return ""
    if t < 179:
        return ""  # bala: el reloj decide más que la posición
    return "b" if t < 479 else "l"  # blitz / lento (rápidas y clásicas)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", type=int, default=1_500_000, help="partidas con evaluación que leer")
    ap.add_argument("--minutes", type=float, default=150.0, help="tope de tiempo")
    ap.add_argument("--max-gap", type=int, default=150, help="diferencia máxima de Elo entre los dos")
    ap.add_argument("--ritmos", default="bl", help="ritmos que apuntar: b (blitz), l (lento)")
    a = ap.parse_args()
    cells: dict = {}
    head = {}
    seen = used = 0
    t0 = time.time()
    for line in sys.stdin.buffer:
        if line.startswith(b"["):
            if line.startswith(b"[Event "):
                head = {}
                seen += 1
            sp = line.find(b" ")
            if sp > 1:
                head[line[1:sp]] = line[sp + 2 : line.rfind(b'"')]
            continue
        if b"%eval" not in line:
            continue
        try:
            we, be = int(head.get(b"WhiteElo", b"?")), int(head.get(b"BlackElo", b"?"))
        except ValueError:
            continue
        res = head.get(b"Result", b"")
        sw = {b"1-0": 1.0, b"0-1": 0.0, b"1/2-1/2": 0.5}.get(res)
        cat = category(head.get(b"TimeControl", b""))
        term = head.get(b"Termination", b"")
        if sw is None or not cat or cat not in a.ritmos or abs(we - be) > a.max_gap or term in (b"Abandoned", b"Rules infraction"):
            continue
        evals = EVAL.findall(line)
        if len(evals) < 10:
            continue
        used += 1
        for ply, e in enumerate(evals):
            if ply < 4:
                continue  # las primeras jugadas: todo es ≈ 0
            for color, elo, score, gap in ((1, we, sw, we - be), (-1, be, 1.0 - sw, be - we)):
                rb = max(600, min(2700, (elo // 100) * 100))
                gb = int(round(gap / 50.0)) * 50
                if e.startswith(b"#"):
                    n = int(e[1:])
                    key = "M+" if n * color > 0 else "M-"
                else:
                    cp = float(e) * 100.0 * color
                    cp = max(-CP_MAX, min(CP_MAX, cp))
                    key = str(int(round(cp / CP_STEP)) * CP_STEP)
                k = f"{cat}|{rb}|{gb}|{key}"
                c = cells.get(k)
                if c is None:
                    cells[k] = [1, score]
                else:
                    c[0] += 1
                    c[1] += score
        if used % 100_000 == 0:
            print(f"{used} partidas con evaluación de {seen} leídas, {time.time() - t0:.0f} s", file=sys.stderr, flush=True)
        if used >= a.games or time.time() - t0 > a.minutes * 60:
            break
    json.dump({"partidas_leidas": seen, "partidas_usadas": used, "paso_cp": CP_STEP, "celdas": cells}, sys.stdout)
    print(f"FIN: {used} partidas con evaluación de {seen} leídas, {len(cells)} casillas, {time.time() - t0:.0f} s", file=sys.stderr)


if __name__ == "__main__":
    main()
