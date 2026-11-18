#!/usr/bin/env python3
"""Notas por jugada para «Qué pasaría» (las variantes "bad" de godot/data/explain/<id>.json).

Para cada jugada de la variante, salvo la primera (la del jugador, que ya tiene su explicación), Stockfish mira las
tres mejores jugadas de la posición y se guarda, sin redactar ningún «porque»:
  k  "o" única jugada legal · "f" casi obligada (la siguiente mejor es >= FORCED cp peor) · "s" da casi igual
     (otras a <= SAME cp: van en "a") · "" nada que destacar
  a  [[jugada en notación española, valoración desde quien mueve]] (solo con "s")
  r  hechos de las reglas: ["j"] estaba en jaque · ["t", pieza, casilla atacante, pieza atacante] la pieza movida
     estaba atacada (por una de menos valor o sin defensa) · ["x", pieza, casilla] captura · ["re"] recupera en la
     casilla de la captura anterior · ["+"] da jaque · ["#"] da mate
Salida: godot/data/notas/<id>.json = {"engine", "depth", "lines": {índice de la variante: {"u": primera uci,
"n": [nota por jugada, la 0 vacía]}}}.
Uso: python3 tools/notas/generar.py [segundos máximos]   (reanuda: guarda lo analizado en tools/notas/cache.json.gz)
"""
import chess, chess.engine, glob, gzip, json, os, sys, time
from multiprocessing import Pool

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "godot/data/explain")
OUT = os.path.join(ROOT, "godot/data/notas")
CACHE = os.path.join(ROOT, "tools/notas/cache.json.gz")
ENGINE = "/usr/games/stockfish"
DEPTH = 12
FORCED = 150
SAME = 40
MATE = 100000
ES = {"K": "R", "Q": "D", "R": "T", "B": "A", "N": "C"}
LETTER = {chess.PAWN: "p", chess.KNIGHT: "n", chess.BISHOP: "b", chess.ROOK: "r", chess.QUEEN: "q", chess.KING: "k"}
VALUE = {chess.PAWN: 1, chess.KNIGHT: 3, chess.BISHOP: 3, chess.ROOK: 5, chess.QUEEN: 9, chess.KING: 100}


def san_es(board, move):
    s = board.san(move)
    return "".join(ES.get(c, c) for c in s[:1]) + s[1:].replace("=Q", "=D").replace("=R", "=T").replace("=B", "=A").replace("=N", "=C")


def fmt(cp):
    if abs(cp) >= MATE - 1000:
        n = MATE - abs(cp)
        return ("M%d" if cp > 0 else "-M%d") % max(n, 1)
    v = cp / 100.0
    return ("+" if v > 0 else ("−" if v < 0 else "")) + ("%.1f" % abs(v)).replace(".", ",")


_eng = None


def _engine():
    global _eng
    if _eng is None:
        _eng = chess.engine.SimpleEngine.popen_uci(ENGINE)
        _eng.configure({"Threads": 1, "Hash": 32})
    return _eng


def analyse(fen):
    """[[uci, cp desde quien mueve], …] de las tres mejores; cp con mates como ±(MATE - n)."""
    b = chess.Board(fen)
    if b.is_game_over():
        return fen, []
    res = _engine().analyse(b, chess.engine.Limit(depth=DEPTH), multipv=3)
    out = []
    for r in res:
        if r.get("pv"):
            out.append([r["pv"][0].uci(), r["score"].pov(b.turn).score(mate_score=MATE)])
    return fen, out


def played_score(fen, uci):
    b = chess.Board(fen)
    r = _engine().analyse(b, chess.engine.Limit(depth=DEPTH), root_moves=[chess.Move.from_uci(uci)])
    return r["score"].pov(b.turn).score(mate_score=MATE)


def facts(board, move, prev):
    r = []
    if board.is_check():
        r.append(["j"])
    piece = board.piece_at(move.from_square)
    attackers = board.attackers(not board.turn, move.from_square)
    if attackers and piece and piece.piece_type != chess.KING:
        low = min(attackers, key=lambda s: VALUE[board.piece_at(s).piece_type])
        defended = bool(board.attackers(board.turn, move.from_square))
        if VALUE[board.piece_at(low).piece_type] < VALUE[piece.piece_type] or not defended:
            r.append(["t", LETTER[piece.piece_type], chess.square_name(low), LETTER[board.piece_at(low).piece_type]])
    if board.is_capture(move):
        if prev is not None and prev.to_square == move.to_square:
            r.append(["re"])
        cap = board.piece_at(move.to_square)
        if cap is None and board.is_en_passant(move):
            r.append(["x", "p", chess.square_name(move.to_square)])
        elif cap:
            r.append(["x", LETTER[cap.piece_type], chess.square_name(move.to_square)])
    after = board.copy()
    after.push(move)
    if after.is_checkmate():
        r.append(["#"])
    elif after.is_check():
        r.append(["+"])
    return r


def main():
    budget = float(sys.argv[1]) if len(sys.argv) > 1 else 1e9
    t0 = time.time()
    cache = {}
    if os.path.exists(CACHE):
        cache = json.load(gzip.open(CACHE, "rt"))
    files = sorted(glob.glob(os.path.join(SRC, "*.json")))
    todo = []
    for f in files:
        d = json.load(open(f))
        for l in d["lines"]:
            if l.get("tone") != "bad":
                continue
            b = chess.Board(l["fen"])
            for i, u in enumerate(l["ucis"]):
                if i > 0 and b.fen() not in cache:
                    todo.append(b.fen())
                b.push_uci(u)
    todo = list(dict.fromkeys(todo))
    print("pendientes:", len(todo), "en caché:", len(cache), flush=True)
    if todo:
        with Pool(2) as pool:
            done = 0
            for fen, out in pool.imap_unordered(analyse, todo, chunksize=20):
                cache[fen] = out
                done += 1
                if done % 2000 == 0:
                    json.dump(cache, gzip.open(CACHE, "wt"))
                    print(done, "en", int(time.time() - t0), "s", flush=True)
                if time.time() - t0 > budget:
                    pool.terminate()
                    break
        json.dump(cache, gzip.open(CACHE, "wt"))
        if any(f not in cache for f in todo):
            print("sin terminar: vuelve a lanzarlo", flush=True)
            return
    # Con todo analizado, se escriben las notas.
    os.makedirs(OUT, exist_ok=True)
    extra = {}
    stats = {"o": 0, "f": 0, "s": 0, "": 0}
    for f in files:
        d = json.load(open(f))
        lines = {}
        for li, l in enumerate(d["lines"]):
            if l.get("tone") != "bad":
                continue
            b = chess.Board(l["fen"])
            notes = []
            prev = None
            for i, u in enumerate(l["ucis"]):
                m = chess.Move.from_uci(u)
                if i == 0:
                    notes.append({})
                else:
                    fen = b.fen()
                    top = cache.get(fen, [])
                    n = {}
                    r = facts(b, m, prev)
                    if r:
                        n["r"] = r
                    if b.legal_moves.count() == 1:
                        n["k"] = "o"
                    elif top:
                        mine = next((s for (x, s) in top if x == u), None)
                        if mine is None:
                            key = fen + " " + u
                            if key not in extra:
                                extra[key] = played_score(fen, u)
                            mine = extra[key]
                        others = [(x, s) for (x, s) in top if x != u]
                        if top[0][0] == u and (not others or top[0][1] - others[0][1] >= FORCED):
                            n["k"] = "f"
                        else:
                            near = [(x, s) for (x, s) in others if abs(s - mine) <= SAME][:2]
                            if near:
                                n["k"] = "s"
                                n["v"] = fmt(mine)
                                n["a"] = [[san_es(b, chess.Move.from_uci(x)), fmt(s)] for (x, s) in near]
                    stats[n.get("k", "")] += 1
                    notes.append(n)
                prev = m
                b.push(m)
            lines[str(li)] = {"u": l["ucis"][0], "n": notes}
        pid = d["id"]
        json.dump({"engine": "Stockfish 16", "depth": DEPTH, "lines": lines}, open(os.path.join(OUT, pid + ".json"), "w"), ensure_ascii=False, separators=(",", ":"))
    if _eng:
        _eng.quit()
    print("hecho:", stats, flush=True)


if __name__ == "__main__":
    main()
