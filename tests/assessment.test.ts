import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { appPool, buildAssessmentGolden } from '../scripts/export-golden-assessment';
import {
  TEST,
  familyOf,
  nextTestItem,
  pickReviewItem,
  pickTrainingItem,
  plan,
  profile,
  recordTry,
  startTest,
  stat,
  status,
  type Item,
  type Outcome,
  type Try,
} from '../src/core/assessment';

const pool = appPool();
const ok: Outcome = { correct: true, failStep: -1, error: '', help: '', msFirst: 9000, ms: 15000 };
const bad = (error: Outcome['error'], failStep = 0, msFirst = 9000): Outcome => ({ correct: false, failStep, error, help: '', msFirst, ms: msFirst + 2000 });

/** Hace el test entero respondiendo con una regla fija. */
function run(answer: (item: Item, n: number) => Outcome, exp: Parameters<typeof startTest>[0] = 'casual') {
  let state = startTest(exp);
  while (!state.done) {
    const item = nextTestItem(state, pool, () => 0.5);
    if (!item) break;
    state = recordTry(state, item, answer(item, state.tries.length), 'test');
  }
  return state;
}

describe('Evaluación enriquecida', () => {
  it('agrupa los temas de Lichess en familias', () => {
    expect(familyOf('fork')).toBe('doble');
    expect(familyOf('pin')).toBe('linea');
    expect(familyOf('attraction')).toBe('defensor');
    expect(familyOf('backRankMate')).toBe('mate');
    expect(familyOf('mateIn2')).toBe('mate');
    expect(familyOf('hangingPiece')).toBe('caza');
    expect(familyOf('advantage')).toBe('otros');
  });

  it('el test tiene entre 8 y 12 problemas, sin repetir, y cubre mates y problemas largos', () => {
    for (const exp of ['never', 'rules', 'casual', 'regular'] as const) {
      for (const rule of [() => ok, () => bad('missed'), (_: Item, n: number) => (n % 2 ? ok : bad('mate'))]) {
        const state = run(rule, exp);
        const n = state.tries.length;
        expect(n).toBeGreaterThanOrEqual(TEST.minItems);
        expect(n).toBeLessThanOrEqual(TEST.maxItems);
        expect(new Set(state.tries.map((t) => t.id)).size).toBe(n);
        expect(state.tries.filter((t) => t.mate).length).toBeGreaterThanOrEqual(TEST.mateItems);
        expect(state.tries.filter((t) => t.steps >= 3).length).toBeGreaterThanOrEqual(TEST.longItems);
      }
    }
  });

  it('acertar sube el nivel y fallar lo baja', () => {
    expect(run(() => ok).rating.r).toBeGreaterThan(1500);
    expect(run(() => bad('mate')).rating.r).toBeLessThan(1000);
  });

  it('no califica una dimensión con menos de tres intentos', () => {
    const tries = run(() => bad('mate')).tries;
    expect(status(stat(tries.slice(0, 2)))).toBe('few');
    expect(status(stat(tries))).toBe('weak');
  });

  it('el perfil cuenta las clases de error, los fallos castigados por la respuesta y dónde se falla', () => {
    const state = run((item, n) => (n < 3 ? bad('mate', 0) : n < 5 ? bad('hangOther', Math.min(1, item.steps - 1)) : n < 6 ? bad('missed', 0) : ok));
    const pr = profile(state.tries);
    expect(pr.fails).toBe(6);
    expect(pr.errors.mate).toBe(3);
    expect(pr.errors.hangOther).toBe(2);
    expect(pr.errors.missed).toBe(1);
    expect(pr.replyBlind).toBe(5);
    // Dónde se falla solo tiene sentido en problemas de dos o más jugadas.
    const multi = state.tries.filter((t) => t.error !== '' && t.steps >= 2);
    expect(pr.failFirst + pr.failLater).toBe(multi.length);
    expect(pr.failLater).toBe(multi.filter((t) => t.failStep > 0).length);
    expect(pr.failLater).toBeGreaterThanOrEqual(1);
    expect(plan(state.rating, pr).habits).toContain('reply');
  });

  it('señala las jugadas equivocadas hechas muy deprisa', () => {
    const state = run((_, n) => (n % 3 === 0 ? bad('mate', 0, 2000) : ok));
    const pr = profile(state.tries);
    expect(pr.time.medianCorrect).toBe(9000);
    expect(pr.time.rushed).toBeGreaterThanOrEqual(2);
    expect(plan(state.rating, pr).habits).toContain('rushed');
  });

  it('el entrenamiento da más peso a lo flojo y no repite hasta agotar la muestra', () => {
    // Falla todos los mates y acierta lo demás: los mates salen más de lo que les tocaría.
    let state = run((item) => (item.mate ? bad('missed') : ok));
    const pr = profile(state.tries);
    expect(status(pr.mate)).toBe('weak');
    expect(plan(state.rating, pr).focus[0]).toEqual({ kind: 'mate' });
    const seen = new Set(state.tries.map((t) => t.id));
    let x = 0.123;
    const remaining = pool.length - seen.size;
    for (let i = 0; i < remaining; i++) {
      x = (x * 7.31 + 0.17) % 1;
      const item = pickTrainingItem(state.rating, state.tries, pool, () => x)!;
      expect(seen.has(item.id)).toBe(false);
      seen.add(item.id);
      state = recordTry(state, item, item.mate ? bad('missed') : ok, 'train');
    }
    expect(pickTrainingItem(state.rating, state.tries, pool, () => 0.5)).toBeNull();
    // Agotada la muestra, el repaso trae un problema fallado y sin resolver.
    const review = pickReviewItem(state.tries, pool)!;
    expect((state.tries.find((t) => t.id === review.id) as Try).correct).toBe(false);
  });

  it('godot/tests/golden/assessment.json está al día con src/core/assessment.ts y con la lista de problemas de la app', () => {
    const saved = JSON.parse(readFileSync(new URL('../godot/tests/golden/assessment.json', import.meta.url), 'utf8'));
    const fresh = JSON.parse(JSON.stringify(buildAssessmentGolden()));
    expect(saved).toEqual(fresh);
  });
});
