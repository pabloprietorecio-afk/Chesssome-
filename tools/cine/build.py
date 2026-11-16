#!/usr/bin/env python3
"""Finales de campeones (cine, fase 1): convierte los clips del cine de la web (tools/cine/videocine.pack.json, sacado de
la rama `cine-video`, commit 17a1575, donde se comprobó cada jugada con Stockfish 19) en lecciones para la app:

    godot/data/cine.json            los clips, cada uno con su lección (mismo formato que las del curso)
    tools/i18n/claves_cine.json     los textos que hay que traducir
    tools/i18n/trad/cine.tsv        sus traducciones (desde tools/cine/trad.tsv, con las jugadas en la notación de
                                    cada idioma)

Cada pregunta es un ejercicio «move»: vale cualquier jugada que mantiene el resultado (veredicto «keeps» del motor);
el texto de cada respuesta lo compone la app (core/cine.gd) con el veredicto. Cada clip lleva además «film»: las marcas
del vídeo y el tablero sincronizado, para verlo dentro de la app con pausa en cada pregunta (fase 2).

Uso: python3 tools/cine/build.py   (necesita python-chess: pip install chess)"""
import json, os, re, sys
import chess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
I18N = os.path.join(ROOT, 'tools', 'i18n')
LANGS = ['en', 'fr', 'it', 'ja', 'pt', 'id', 'hi', 'de', 'ru']
# Letras de las piezas por idioma (las mismas que Loc.LETTERS), por tipo: caballo, alfil, torre, dama, rey.
LETTERS = {'es': 'CATDR', 'it': 'CATDR', 'en': 'NBRQK', 'ja': 'NBRQK', 'id': 'NBRQK', 'hi': 'NBRQK',
           'fr': 'CFTDR', 'pt': 'CBTDR', 'de': 'SLTDK', 'ru': ['К', 'С', 'Л', 'Ф', 'Кр']}
DRAW_SPOILS_CP = -250  # src/core/cinema.ts de la rama cine-video
EN_TO_ES = str.maketrans({'N': 'C', 'B': 'A', 'R': 'T', 'Q': 'D', 'K': 'R'})
SAN_ES = re.compile(r'(?<![^\W\d_])(?<!\d)([CATDR])([a-h]?[1-8]?x?[a-h][1-8])|=([CATD])(?=[+#]?(?![^\W_]))')


def es(san):
    """Jugada en notación inglesa (la de chess.js y python-chess) → española."""
    return san.translate(EN_TO_ES) if san[:1] in 'NBRQK' or '=' in san else san


def san_to(text, lang):
    """Las jugadas en notación española dentro de un texto, a la del idioma (como Loc.san_text)."""
    if lang in ('es', 'it'):
        return text
    letters = LETTERS[lang]
    def piece(ch):
        return letters['CATDR'.index(ch)]
    def sub(m):
        if m.group(1):
            return piece(m.group(1)) + m.group(2)
        return '=' + piece(m.group(3))
    return SAN_ES.sub(sub, text)


def numbered(board, sans):
    """«56.Rxf2 Ad5 57.Axd5…» (en español) a partir de la posición y las jugadas en inglés."""
    b = board.copy()
    out = []
    for i, san in enumerate(sans):
        mv = b.parse_san(san)
        n = b.fullmove_number
        if b.turn == chess.WHITE:
            out.append('%d.%s' % (n, es(b.san(mv))))
        elif i == 0:
            out.append('%d…%s' % (n, es(b.san(mv))))
        else:
            out.append(es(b.san(mv)))
        b.push(mv)
    return ' '.join(out)


def fen_after(clip, ply):
    tl = clip['timeline']
    i = ply - tl['fromPly']
    if ply == 0:
        return chess.STARTING_FEN
    moves = tl['moves']
    if 0 <= i < len(moves):
        return moves[i]['fenAfter']
    raise SystemExit('%s: sin posición tras la media jugada %d' % (clip['id'], ply))


def strip_colon(text):
    """El «por qué abandonó» acaba presentando una línea («Así habría seguido…:»); aquí no se enseña: fuera."""
    parts = re.split(r'(?<=[.!?])\s+', text.strip())
    return ' '.join(p for p in parts if not p.endswith(':'))


END_TAIL = 2.5  # src/core/videoCine.ts (trimEnd): el clip acaba poco después de la última jugada del tablero


def film_of(c):
    """Lo que necesita el vídeo dentro de la app (fase 2): marcas del clip (inicio, fin, una pausa por pregunta) y el
    tablero sincronizado (posición al empezar y segundo en que aparece cada media jugada), con las posiciones ya
    calculadas. Las marcas las puso Pablo viendo los vídeos en la web; «marks» dice si alguien las ha dado por
    verificadas. Sin inicio o sin alguna pausa, el clip no tiene vídeo con pausa (None)."""
    if c.get('start') is None or any(st.get('at') is None for st in c['stops']):
        return None
    for st in c['stops']:
        if len(st['questions']) != 1:
            raise SystemExit('%s: la app espera una pregunta por pausa' % c['id'])
    sync = c.get('sync') or {'startPly': c['stops'][0]['questions'][0]['ply'] - 1, 'marks': []}
    marks = sync.get('marks', [])
    end = c.get('end')
    if end is not None and marks:
        last = max(m['at'] for m in marks)
        if last + END_TAIL < end:
            end = round(last + END_TAIL, 2)
    # Orden: inicio < pausas < fin, y ninguna jugada de una pregunta en el tablero antes de su pausa.
    seq = [c['start']] + [st['at'] for st in c['stops']] + ([end] if end is not None else [])
    if any(b <= a for a, b in zip(seq, seq[1:])):
        raise SystemExit('%s: marcas fuera de orden %s' % (c['id'], seq))
    for st in c['stops']:
        qp = st['questions'][0]['ply']
        for m in marks:
            if m['ply'] >= qp and m['at'] < st['at']:
                raise SystemExit('%s: la media jugada %d aparece antes de su pausa' % (c['id'], m['ply']))
    last_ply = max([sync['startPly']] + [m['ply'] for m in marks] + [st['questions'][0]['ply'] for st in c['stops']])
    frames = {}
    tl = c['timeline']
    for ply in range(sync['startPly'], last_ply + 1):
        i = ply - tl['fromPly']
        if not 0 <= i < len(tl['moves']):
            raise SystemExit('%s: sin la media jugada %d' % (c['id'], ply))
        mv = tl['moves'][i]
        frames[str(ply)] = {'fen': mv['fenAfter'], 'from': mv['from'], 'to': mv['to']}
    return {
        'duration': c['video'].get('duration'), 'start': c['start'], 'end': end, 'marks': c.get('marks', 'pending'),
        'stops': [{'at': st['at'], 'resume': st.get('resumeAt')} for st in c['stops']],
        'sync': {'startPly': sync['startPly'], 'marks': marks, 'gaps': sync.get('gaps', [])},
        'frames': frames,
    }


def build():
    pack = json.load(open(os.path.join(HERE, 'videocine.pack.json'), encoding='utf8'))
    texts = []

    def say(t):
        if t and t not in texts:
            texts.append(t)
        return t

    clips = []
    for c in pack['clips']:
        orient = 1 if c['orientation'] == 'b' else 0
        exercises = []
        for stop in c['stops']:
            for q in stop['questions']:
                board = chess.Board(q['fen'])
                legal = {m.uci() for m in board.legal_moves}
                moves = {}
                for v in q['verdicts']:
                    if v['uci'] not in legal:
                        raise SystemExit('%s: %s no es legal' % (c['id'], v['uci']))
                    mv = chess.Move.from_uci(v['uci'])
                    after = board.copy()
                    after.push(mv)
                    sc = v.get('score', {})
                    # «Pierde» solo si el motor da la posición por perdida (como en la web: mate en contra o −2,5 o menos).
                    loses = (sc['mate'] < 0) if 'mate' in sc else (sc.get('cp', 0) <= DRAW_SPOILS_CP)
                    entry = {'ok': v['cls'] == 'keeps', 'c': v['cls'], 'san': es(board.san(mv)), 'loses': loses}
                    if v.get('line'):
                        entry['line'] = numbered(after, v['line'])
                    if v.get('lineEnd'):
                        entry['end'] = v['lineEnd']
                    moves[v['uci']] = entry
                missing = legal - set(moves)
                if missing:
                    raise SystemExit('%s: sin veredicto para %s' % (c['id'], sorted(missing)))
                if not any(m['ok'] for m in moves.values()):
                    raise SystemExit('%s: ninguna jugada vale en la media jugada %d' % (c['id'], q['ply']))
                lead = q.get('lead') or {}
                exercises.append({
                    'kind': 'move', 'ply': q['ply'], 'fen': q['fen'], 'text': say(q['question']), 'hint': say(q.get('hint') or ''),
                    'last': [lead['from'], lead['to']] if lead.get('from') else [],
                    'cine': {'target': q['target'], 'played': q['playedUci'], 'playedSan': es(q['played']['san']),
                             'playedCls': q['playedCls'], 'why': say(q['why'])},
                    'moves': moves,
                })
        lesson = c.get('lesson') or {}
        if lesson:
            start = chess.Board(fen_after(c, lesson['from']))
            for k, st in enumerate(lesson['steps']):
                b = start.copy()
                last = []
                for san in st['moves'].split():
                    mv = b.parse_san(san)
                    last = [chess.square_name(mv.from_square), chess.square_name(mv.to_square)]
                    b.push(mv)
                exercises.append({'kind': 'info', 'fen': b.fen(), 'text': say(st['text']), 'last': last,
                                  'arrows': [{'from': a['from'], 'to': a['to'], 'tone': a.get('tone', 'info')} for a in st.get('arrows', [])]})
        res = c.get('resignation')
        end_fen = c['timeline']['moves'][-1]['fenAfter']
        if res:
            last_mv = c['timeline']['moves'][-1]
            text = ' '.join(x for x in [say(res['hook']), say(strip_colon(res['why'])), say(res['outcome'])] if x)
            exercises.append({'kind': 'info', 'fen': end_fen, 'text': text, 'parts': [res['hook'], strip_colon(res['why']), res['outcome']],
                              'last': [last_mv['from'], last_mv['to']], 'arrows': []})
        last_mv = c['timeline']['moves'][-1]
        exercises.append({'kind': 'info', 'fen': end_fen, 'text': say(c['outro']), 'last': [last_mv['from'], last_mv['to']], 'arrows': []})
        v = c['video']
        film = film_of(c)
        clips.append({
            'id': c['id'], 'title': say(c['title']), 'subtitle': say(c['subtitle']), 'event': c['event'], 'year': c['year'],
            'white': c['white'], 'black': c['black'],
            'video': {'id': v['id'], 'channel': v['channel'], 'title': v['title'], 'start': int(c.get('start') or 0)},
            'film': film,
            'lesson': {'id': 'cine-' + c['id'], 'title': c['title'], 'icon': 'film', 'orientation': orient,
                       'intro': [c['subtitle'], say(c['intro'])],
                       'takeaway': say(lesson.get('takeaway', '')), 'lessonTitle': lesson.get('title', ''),
                       'exercises': exercises},
        })
    out = {'generatedBy': 'tools/cine/build.py', 'source': 'rama cine-video (17a1575), %s, profundidad %d' % (pack['engine']['name'], pack['engine']['depth']),
           'clips': clips}
    json.dump(out, open(os.path.join(ROOT, 'godot', 'data', 'cine.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=0)
    json.dump(texts, open(os.path.join(I18N, 'claves_cine.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=0)
    # Traducciones: tools/cine/trad.tsv (español \t en \t fr …, con las jugadas en notación española) → con la notación
    # de cada idioma, en tools/i18n/trad/cine.tsv.
    src = os.path.join(HERE, 'trad.tsv')
    rows = []
    if os.path.exists(src):
        for n, line in enumerate(open(src, encoding='utf8').read().split('\n')):
            if not line.strip():
                continue
            cols = line.split('\t')
            if len(cols) != len(LANGS) + 1:
                raise SystemExit('trad.tsv:%d: %d columnas' % (n + 1, len(cols)))
            rows.append('\t'.join([cols[0]] + [san_to(t, l) for t, l in zip(cols[1:], LANGS)]))
        open(os.path.join(I18N, 'trad', 'cine.tsv'), 'w', encoding='utf8').write('\n'.join(rows) + '\n')
    have = {r.split('\t')[0] for r in rows}
    print('%d clips, %d ejercicios, %d textos (%d sin traducir)' % (len(clips), sum(len(c['lesson']['exercises']) for c in clips), len(texts), len([t for t in texts if t.replace('\n', '\\n') not in have])))


if __name__ == '__main__':
    build()
