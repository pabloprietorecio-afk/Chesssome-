import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { Chess } from 'chess.js';
import { explain, explainSolved, isAccepted } from '../src/core/explain';
import { unpackPuzzle } from '../src/core/pack';
import type { PuzzlePack } from '../src/core/types';

// Paquete real generado por el pipeline (problemas de Lichess analizados con Stockfish).
const pack = JSON.parse(readFileSync(new URL('../src/data/puzzles.pack.json', import.meta.url), 'utf8')) as PuzzlePack;
const puzzles = pack.puzzles.map((p) => unpackPuzzle(p, pack.engine));

describe('paquete de datos', () => {
  it('declara su procedencia y su carácter provisional', () => {
    expect(pack.provisional).toBe(true);
    expect(pack.source.license).toBe('CC0-1.0');
    expect(puzzles.length).toBeGreaterThan(100);
  });
});

describe('explicaciones sobre problemas reales', () => {
  const sample = puzzles.slice(0, 25);
  it('la solución siempre se acepta y su explicación es positiva', () => {
    for (const p of sample) {
      expect(isAccepted(p, 0, p.points[0].solution)).toBe(true);
      const e = explainSolved(p);
      expect(e.correct).toBe(true);
      expect(e.levels[0].paragraphs[0].length).toBeGreaterThan(5);
    }
  });
  it('cualquier jugada legal produce una explicación completa', { timeout: 60000 }, () => {
    for (const p of sample.slice(0, 10)) {
      const pt = p.points[0];
      for (const m of new Chess(pt.fen).moves({ verbose: true })) {
        const e = explain(p, 0, m.lan);
        expect(e.headline).toBeTruthy();
        expect(e.levels).toHaveLength(4);
        expect(e.levels[2].lines.length).toBeGreaterThan(0);
        for (const l of e.levels) for (const t of l.paragraphs) expect(t).not.toMatch(/undefined|NaN|null/);
      }
    }
  });
  it('ejemplo documentado: Cxd4 en lugar del ataque doble (csSfA)', () => {
    const p = puzzles.find((x) => x.id === 'csSfA');
    if (!p) return; // el ejemplo solo existe si el problema está en el paquete
    const e = explain(p, 0, 'b5d4');
    expect(e.correct).toBe(false);
    expect(e.levels[0].paragraphs.join(' ')).toContain('La mejor era Cd6+, que gana la dama a cambio del caballo.');
    expect(e.levels[1].paragraphs.join(' ')).toContain('ataca a la vez al rey de e8 y a la dama de c8');
  });
});
