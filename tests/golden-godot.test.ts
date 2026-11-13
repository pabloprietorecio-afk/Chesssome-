import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { buildGolden } from '../scripts/export-golden';
import { buildChessGolden } from '../scripts/export-golden-chess';

// Si alguien cambia el núcleo TypeScript sin regenerar los datos de oro, Godot se compararía contra
// valores viejos. Este test lo impide: los datos guardados deben coincidir con lo que calcula hoy el núcleo.
describe('Datos de oro para Godot', () => {
  it('godot/tests/golden/glicko2.json está al día con src/core/glicko2.ts', () => {
    const saved = JSON.parse(readFileSync(new URL('../godot/tests/golden/glicko2.json', import.meta.url), 'utf8'));
    const fresh = JSON.parse(JSON.stringify(buildGolden()));
    expect(saved.update.length).toBe(fresh.update.length);
    for (let i = 0; i < fresh.update.length; i++) {
      const a = saved.update[i].out;
      const b = fresh.update[i].out;
      expect(a.r).toBeCloseTo(b.r, 9);
      expect(a.rd).toBeCloseTo(b.rd, 9);
      expect(a.vol).toBeCloseTo(b.vol, 12);
    }
    fresh.expectedScore.forEach((e: { out: number }, i: number) => expect(saved.expectedScore[i].out).toBeCloseTo(e.out, 12));
    fresh.ratingForSuccess.forEach((e: { out: number }, i: number) => expect(saved.ratingForSuccess[i].out).toBeCloseTo(e.out, 9));
  });

  it('godot/tests/golden/chess.json está al día con chess.js y el paquete de problemas', { timeout: 60000 }, () => {
    const saved = JSON.parse(readFileSync(new URL('../godot/tests/golden/chess.json', import.meta.url), 'utf8'));
    const fresh = JSON.parse(JSON.stringify(buildChessGolden()));
    expect(saved.perft).toEqual(fresh.perft);
    expect(saved.positions.length).toBe(fresh.positions.length);
    for (const i of [0, 1, 2, 100, 400, fresh.positions.length - 1]) expect(saved.positions[i]).toEqual(fresh.positions[i]);
  });
});
