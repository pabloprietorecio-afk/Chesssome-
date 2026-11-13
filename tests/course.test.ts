import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { buildCourse, solveCollect } from '../scripts/export-course';

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
});
