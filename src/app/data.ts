/**
 * Carga el paquete de problemas analizados que genera el pipeline (src/data/puzzles.pack.json).
 * El paquete es una MUESTRA DE DESARROLLO de problemas reales de Lichess (CC0) y lo indica en `provisional`.
 */
import packJson from '../data/puzzles.pack.json';
import { unpackPuzzle } from '../core/pack';
import { primaryTheme } from '../core/themes';
import type { AnalyzedPuzzle, PuzzlePack } from '../core/types';

export const PACK = packJson as unknown as PuzzlePack;

export const POOL: AnalyzedPuzzle[] = PACK.puzzles.map((p) => unpackPuzzle(p, PACK.engine));

export const BY_ID: Map<string, AnalyzedPuzzle> = new Map(POOL.map((p) => [p.id, p]));

/** Temas principales ordenados por frecuencia en el paquete (para repartir condiciones del experimento). */
export const THEMES_BY_FREQUENCY: string[] = (() => {
  const counts = new Map<string, number>();
  for (const p of POOL) {
    const t = primaryTheme(p.themes);
    counts.set(t, (counts.get(t) ?? 0) + 1);
  }
  return [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).map(([t]) => t);
})();
