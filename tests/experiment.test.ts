import { describe, expect, it } from 'vitest';
import { assignThemes, summarizeH1, summarizeH2, type TrialRecord } from '../src/core/experiment';
import { insights, pickTrainingPuzzle, recordPlacement, startPlacement, themeStats } from '../src/core/training';
import type { AnalyzedPuzzle } from '../src/core/types';

const trial = (o: Partial<TrialRecord>): TrialRecord => ({
  puzzleId: 'x', puzzleRating: 1500, theme: 'fork', correct: true, ms: 1000, expected: 0.75, at: 0,
  phase: 'training', feedback: 'explained', board: '2d', anim: 'fast', firstMoveMs: 800, misTaps: 0, whyDepth: 1, ...o,
});

describe('experimento', () => {
  it('reparte los temas casi a partes iguales y de forma reproducible', () => {
    const themes = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const a1 = assignThemes(themes, 'semilla');
    const a2 = assignThemes(themes, 'semilla');
    expect(a1).toEqual(a2);
    const explained = Object.values(a1).filter((f) => f === 'explained').length;
    expect(explained).toBe(4);
    // Los dos temas más frecuentes caen en condiciones distintas.
    expect(a1.a).not.toBe(a1.b);
  });

  it('H1 ignora el primer intento de cada tema y compara residuos', () => {
    const trials = [
      trial({ theme: 'fork', feedback: 'explained', correct: false }),
      trial({ theme: 'fork', feedback: 'explained', correct: true, expected: 0.5 }),
      trial({ theme: 'pin', feedback: 'plain', correct: false }),
      trial({ theme: 'pin', feedback: 'plain', correct: false, expected: 0.5 }),
    ];
    const h1 = summarizeH1(trials);
    expect(h1.byFeedback.explained.n).toBe(1);
    expect(h1.byFeedback.explained.residual).toBeCloseTo(0.5);
    expect(h1.byFeedback.plain.residual).toBeCloseTo(-0.5);
    expect(h1.residualGap).toBeCloseTo(1);
  });

  it('H2 compara el acierto observado con el objetivo', () => {
    const trials = Array.from({ length: 20 }, (_, i) => trial({ correct: i % 4 !== 0 }));
    const h2 = summarizeH2(trials);
    expect(h2.observed).toBeCloseTo(0.75);
    expect(h2.withinBand).toBe(true);
  });
});

describe('entrenamiento', () => {
  const fake = (id: string, rating: number, theme: string): AnalyzedPuzzle => ({
    id, fen: '', moves: ['a', 'b'], rating, rd: 75, popularity: 90, plays: 1000, themes: [theme], gameUrl: '', openingTags: [],
    points: [{ index: 0, fen: '', solution: 'b', evals: [], top: [], agree: true }], engine: { name: 't', depthAll: 1, depthTop: 1 }, verified: true,
  });
  const pool = Array.from({ length: 200 }, (_, i) => fake(`p${i}`, 800 + i * 7, i % 2 ? 'fork' : 'pin'));

  it('el test termina entre 8 y 12 problemas', () => {
    let st = startPlacement('casual');
    let n = 0;
    while (!st.done) {
      st = recordPlacement(st, pool[n * 9], n % 3 !== 0, 1000);
      n++;
    }
    expect(n).toBeGreaterThanOrEqual(8);
    expect(n).toBeLessThanOrEqual(12);
  });

  it('elige problemas cerca de la dificultad objetivo (75 % previsto)', () => {
    const rating = { r: 1500, rd: 80, vol: 0.06 };
    let seed = 3;
    const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
    for (let i = 0; i < 20; i++) {
      const p = pickTrainingPuzzle(rating, [], pool, { targetSuccess: 0.75, weaknessBoost: 1.5, rand })!;
      expect(Math.abs(p.rating - 1309)).toBeLessThanOrEqual(60);
    }
  });

  it('el entrenador no opina con menos de 5 intentos por tema', () => {
    const atts = [trial({ theme: 'pin', correct: false }), trial({ theme: 'pin', correct: false })];
    expect(insights(atts)).toHaveLength(0);
    const many = Array.from({ length: 8 }, () => trial({ theme: 'pin', correct: false, expected: 0.7 }));
    const ins = insights(many);
    expect(ins[0]?.kind).toBe('weakness');
    expect(themeStats(many)[0].residual).toBeLessThan(0);
  });
});
