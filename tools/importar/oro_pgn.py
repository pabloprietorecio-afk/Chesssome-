#!/usr/bin/env python3
"""Pruebas de oro del lector de PGN (godot/core/pgn.gd), hechas con python-chess (GPL-3.0; solo como herramienta,
no va en la app). Partidas al azar (con semilla fija) que pasan por enroques, capturas al paso, coronaciones y
jugadas que hay que desambiguar; se escriben en PGN como lo dan Chess.com (comentarios de reloj, «1...») y Lichess,
y se guarda la lista de jugadas en UCI que tiene que salir.
Uso: pip install chess && python3 tools/importar/oro_pgn.py  ->  godot/tests/golden/pgn.json"""
import json, os, random
import chess, chess.pgn

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'godot', 'tests', 'golden', 'pgn.json')


def random_game(rng, plies):
    b = chess.Board()
    while not b.is_game_over() and len(b.move_stack) < plies:
        moves = list(b.legal_moves)
        # Un poco de preferencia por capturas, coronaciones y enroques, para que salgan más.
        special = [m for m in moves if b.is_capture(m) or m.promotion or b.is_castling(m)]
        b.push(rng.choice(special) if special and rng.random() < 0.35 else rng.choice(moves))
    return b


def san_list(b):
    replay = chess.Board()
    out = []
    for m in b.move_stack:
        out.append(replay.san(m))
        replay.push(m)
    return out


def chesscom_movetext(sans):
    parts = []
    for i, s in enumerate(sans):
        clk = '{[%%clk 0:0%d:%02d.%d]}' % (2 - (i % 3), 59 - (i % 60), i % 10)
        if i % 2 == 0:
            parts.append('%d. %s %s' % (i // 2 + 1, s, clk))
        else:
            parts.append('%d... %s %s' % (i // 2 + 1, s, clk))
    return ' '.join(parts)


def lichess_movetext(sans):
    parts = []
    for i, s in enumerate(sans):
        parts.append(('%d. %s' % (i // 2 + 1, s)) if i % 2 == 0 else s)
    return ' '.join(parts)


def main():
    rng = random.Random(20261126)
    cases = []
    stats = {'enroques': 0, 'al_paso': 0, 'coronaciones': 0, 'desambiguadas': 0}
    for k in range(40):
        b = random_game(rng, rng.randint(30, 260))
        sans = san_list(b)
        replay = chess.Board()
        for m in b.move_stack:
            stats['enroques'] += replay.is_castling(m)
            stats['al_paso'] += replay.is_en_passant(m)
            stats['coronaciones'] += bool(m.promotion)
            s = replay.san(m)
            stats['desambiguadas'] += s[0] in 'NBRQK' and len(s.replace('x', '').rstrip('+#')) > 3
            replay.push(m)
        res = b.result(claim_draw=False)
        style = 'chesscom' if k % 2 == 0 else 'lichess'
        text = chesscom_movetext(sans) if style == 'chesscom' else lichess_movetext(sans)
        cases.append({'style': style, 'movetext': text + ' ' + res, 'result': res,
                      'uci': [m.uci() for m in b.move_stack], 'final': b.fen(), 'mate': b.is_checkmate(),
                      'stalemate': b.is_stalemate()})
    json.dump({'cases': cases, 'stats': stats}, open(OUT, 'w'), indent=0)
    print(len(cases), 'partidas;', stats, '->', OUT)


if __name__ == '__main__':
    main()
