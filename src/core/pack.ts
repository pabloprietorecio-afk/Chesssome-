import type { AnalyzedPuzzle, DecisionPoint, EngineInfo, MoveEval, PackedPuzzle, Score } from './types';

/**
 * Empaquetado compacto del análisis para que el paquete de datos pese poco.
 * Una evaluación se escribe "uci:score:pv1 pv2 …" y las evaluaciones se separan con ";".
 * El score es "c<centipeones>" o "m<mate en n>" (negativo = te dan mate).
 */

export function packScore(s: Score): string {
  return 'cp' in s ? `c${s.cp}` : `m${s.mate}`;
}

export function unpackScore(s: string): Score {
  const n = Number(s.slice(1));
  if (!Number.isFinite(n)) throw new Error(`Score inválido: ${s}`);
  return s[0] === 'm' ? { mate: n } : { cp: n };
}

export function packEvals(evals: MoveEval[], maxPv: number): string {
  return evals.map((e) => `${e.uci}:${packScore(e.score)}:${e.pv.slice(0, maxPv).join(' ')}`).join(';');
}

export function unpackEvals(s: string): MoveEval[] {
  if (!s) return [];
  return s.split(';').map((part) => {
    const [uci, score, pv] = part.split(':');
    return { uci, score: unpackScore(score), pv: pv ? pv.split(' ') : [] };
  });
}

export function packPuzzle(p: AnalyzedPuzzle, maxPvAll = 6, maxPvTop = 10): PackedPuzzle {
  return {
    i: p.id,
    f: p.fen,
    m: p.moves.join(' '),
    r: p.rating,
    d: p.rd,
    p: p.popularity,
    n: p.plays,
    t: p.themes.join(' '),
    g: p.gameUrl,
    o: p.openingTags.join(' '),
    a: p.points.map((pt) => [pt.fen, pt.solution, packEvals(pt.evals, maxPvAll), packEvals(pt.top, maxPvTop)]),
  };
}

export function unpackPuzzle(p: PackedPuzzle, engine: EngineInfo): AnalyzedPuzzle {
  const points: DecisionPoint[] = p.a.map(([fen, solution, evals, top], index) => ({
    index,
    fen,
    solution,
    evals: unpackEvals(evals),
    top: unpackEvals(top),
    agree: true,
  }));
  return {
    id: p.i,
    fen: p.f,
    moves: p.m.split(' '),
    rating: p.r,
    rd: p.d,
    popularity: p.p,
    plays: p.n,
    themes: p.t ? p.t.split(' ') : [],
    gameUrl: p.g,
    openingTags: p.o ? p.o.split(' ') : [],
    points,
    engine,
    verified: true,
  };
}
