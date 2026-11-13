/**
 * Utilidades de análisis compartidas por los dos pipelines del cine
 * (películas generadas y clips de vídeo real). Solo se usan en desarrollo: la app no lleva motor.
 */
import { Chess } from 'chess.js';
import type { UciEngine } from './uci';
import { classify, scoreValue, type FilmResult, type MoveVerdict } from '../src/core/cinema';
import type { MoveEval, Score } from '../src/core/types';

export const neg = (s: Score): Score => ('cp' in s ? { cp: -s.cp } : { mate: -s.mate });

/** SAN de una variante UCI desde una posición; corta en la primera jugada que no sea legal. */
export function pvToSan(fen: string, pv: string[]): { san: string[]; end?: MoveVerdict['lineEnd'] } {
  const c = new Chess(fen);
  const san: string[] = [];
  for (const u of pv) {
    try {
      san.push(c.move({ from: u.slice(0, 2), to: u.slice(2, 4), promotion: u[4] }).san);
    } catch {
      return { san };
    }
  }
  const end = c.isCheckmate() ? 'checkmate' : c.isStalemate() ? 'stalemate' : c.isInsufficientMaterial() ? 'insufficient' : undefined;
  return { san, end };
}

/** Si la jugada lleva directamente a un final de partida, se evalúa sin motor. */
export function terminalScore(fenAfter: string): Score | null {
  const c = new Chess(fenAfter);
  if (c.isCheckmate()) return { mate: 1 }; // desde el punto de vista de quien acaba de mover
  if (c.isStalemate() || c.isInsufficientMaterial()) return { cp: 0 };
  return null;
}

/** Evalúa TODAS las jugadas legales de una posición. Falla si el motor deja alguna sin analizar. */
export async function analyseAll(engine: UciEngine, fen: string, depth: number): Promise<Map<string, MoveEval>> {
  const legal = new Chess(fen).moves({ verbose: true });
  const res = await engine.analyse(fen, { depth, multipv: legal.length, maxPv: 10 });
  const map = new Map(res.map((m) => [m.uci, m]));
  for (const m of legal) {
    const uci = m.from + m.to + (m.promotion ?? '');
    if (!map.has(uci)) {
      // El motor no devuelve líneas para jugadas que acaban la partida (p. ej. ahogado inmediato).
      const t = terminalScore(m.after);
      if (t) map.set(uci, { uci, score: t, pv: [] });
      else throw new Error(`El motor no analizó ${uci} en ${fen}`);
    }
  }
  return map;
}

/** De mejor a peor para quien mueve. */
export const ranked = (evals: Map<string, MoveEval>): MoveEval[] => [...evals.values()].sort((a, b) => scoreValue(b.score) - scoreValue(a.score));

/** Veredicto de cada jugada (mantiene, estropea o dudosa) con la línea del motor en SAN. */
export function toVerdicts(fen: string, list: MoveEval[], target: FilmResult): MoveVerdict[] {
  return list.map((m) => {
    const c = new Chess(fen);
    const mv = c.move({ from: m.uci.slice(0, 2), to: m.uci.slice(2, 4), promotion: m.uci[4] });
    const { san, end } = pvToSan(c.fen(), m.pv);
    const v: MoveVerdict = { uci: m.uci, san: mv.san, cls: classify(m.score, target), score: m.score, line: san };
    const endNow = terminalScore(c.fen());
    if (endNow && 'cp' in endNow) v.lineEnd = c.isStalemate() ? 'stalemate' : 'insufficient';
    else if (end) v.lineEnd = end;
    return v;
  });
}
