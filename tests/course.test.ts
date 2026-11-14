import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { buildCourse, mirrorFen, solveCollect } from '../scripts/export-course';
import { voiceId, voiceLines } from '../scripts/export-voice';

describe('Curso «Aprende a jugar»', () => {
  it('cada ejercicio se puede resolver y está bien planteado (si no, buildCourse lanza un error)', () => {
    const c = buildCourse();
    expect(c.lessons).toBeGreaterThanOrEqual(15);
    expect(c.exercises).toBeGreaterThanOrEqual(45);
  });

  it('encuentra el camino más corto y respeta las casillas atacadas', () => {
    expect(solveCollect('8/8/8/8/8/8/8/R7 w - - 0 1', 'a1', ['a6', 'f6'], false).par).toBe(2);
    // El peón de b7 defiende a6: hay que capturarlo antes.
    const safe = solveCollect('8/1p6/n7/8/8/8/8/R7 w - - 0 1', 'a1', [], true);
    expect(safe.solution.indexOf('b1b7')).toBeLessThan(safe.solution.length - 1);
    expect(() => solveCollect('8/1p6/b7/8/8/8/8/R7 w - - 0 1', 'a1', [], true)).toThrow();
  });

  it('godot/data/curso.json está al día con src/course/course.ts', () => {
    const saved = JSON.parse(readFileSync(new URL('../godot/data/curso.json', import.meta.url), 'utf8'));
    expect(saved).toEqual(JSON.parse(JSON.stringify(buildCourse())));
  });

  it('nivel Kids: cada jugada juzgada tiene su frase sencilla, sin casillas, y hay pocas frases distintas (llevan voz)', () => {
    const c = buildCourse();
    const lines = voiceLines(c as never);
    expect(lines.length).toBeLessThan(300);
    for (const u of c.units) for (const l of u.lessons) for (const e of l.exercises as Record<string, unknown>[]) {
      expect(String(e.kids ?? '')).not.toBe('');
      for (const j of Object.values((e.moves ?? {}) as Record<string, { k: string }>)) expect(j.k).not.toMatch(/\b[a-h][1-8]\b/);
    }
    const index = JSON.parse(readFileSync(new URL('../godot/data/voz.json', import.meta.url), 'utf8'));
    for (const t of lines) expect(index[t]).toBe(voiceId(t));
  });

  it('dar la vuelta a una posición la deja igual si se repite', () => {
    const fen = 'r3k2r/pp3ppp/8/3pP3/8/8/PP3PPP/R3K2R b KQq d3 0 20';
    expect(mirrorFen(mirrorFen(fen))).toBe(fen);
    expect(mirrorFen(fen).split(' ').slice(1, 4)).toEqual(['w', 'Qkq', 'd6']);
  });
});
