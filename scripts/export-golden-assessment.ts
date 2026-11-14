/**
 * Datos de oro de la evaluación (src/core/assessment.ts) para comprobar el port a GDScript
 * (godot/core/assessment.gd, con godot/tests/test_assessment.gd).
 *
 * Simula jugadores de distinto nivel haciendo el test y un rato de entrenamiento sobre la misma lista de
 * problemas que lleva la app (godot/data/demo_puzzles.json), y guarda cada elección y cada cifra. Las
 * respuestas y los números al azar van en el archivo: Godot repite la simulación paso a paso y tiene que
 * llegar a lo mismo.
 *
 * Uso: npm run golden   (después de npm run godot:demo si ha cambiado la lista de problemas)
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  levelOf,
  measurableRange,
  nextTestItem,
  pickReviewItem,
  pickTrainingItem,
  plan,
  profile,
  recordTry,
  startTest,
  status,
  trainingWeight,
  type Help,
  type Item,
  type Outcome,
} from '../src/core/assessment';
import type { ErrorKind } from '../src/core/explain';
import { expectedScore } from '../src/core/glicko2';
import type { Experience } from '../src/core/training';

const OUT = fileURLToPath(new URL('../godot/tests/golden/assessment.json', import.meta.url));
const LIST = fileURLToPath(new URL('../godot/data/demo_puzzles.json', import.meta.url));

function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const KINDS: Exclude<ErrorKind, ''>[] = ['mate', 'hangMoved', 'hangOther', 'material', 'worse', 'missed', 'slower'];

/** La lista de problemas de la app, tal y como la lee Godot. */
export function appPool(): Item[] {
  const list = JSON.parse(readFileSync(LIST, 'utf8')) as { puzzles: { id: string; rating: number; rd: number; key: string; family: Item['family']; mate: boolean; steps: number }[] };
  return list.puzzles.map((p) => ({ id: p.id, rating: p.rating, rd: p.rd, theme: p.key, family: p.family, mate: p.mate, steps: p.steps }));
}

export function buildAssessmentGolden(): object {
  const pool = appPool();
  const runs: object[] = [];
  const cases: { experience: Experience; skill: number; seed: number }[] = [
    { experience: 'never', skill: 700, seed: 11 },
    { experience: 'rules', skill: 950, seed: 12 },
    { experience: 'casual', skill: 1300, seed: 13 },
    { experience: 'casual', skill: 1650, seed: 14 },
    { experience: 'regular', skill: 1500, seed: 15 },
    { experience: 'regular', skill: 2050, seed: 16 },
    { experience: 'rules', skill: 1900, seed: 17 },
    { experience: 'regular', skill: 900, seed: 18 },
  ];
  for (const c of cases) {
    const rand = rng(20261113 + c.seed);
    const answer = (item: Item, training: boolean): Outcome => {
      const correct = rand() < expectedScore({ r: c.skill }, { r: item.rating, rd: item.rd });
      let help: Help = '';
      if (!correct) {
        const x = rand();
        if (training) help = x < 0.15 ? 'hint' : x < 0.3 ? 'step' : x < 0.4 ? 'solution' : '';
        else help = x < 0.15 ? 'giveup' : '';
      }
      // Con ayuda puede haber habido antes una jugada equivocada, o no.
      const wrongMove = !correct && (help === '' || rand() < 0.5);
      const msFirst = help === 'giveup' ? 0 : Math.round(1500 + rand() * 60000);
      return {
        correct,
        failStep: wrongMove ? Math.floor(rand() * item.steps) : -1,
        error: wrongMove ? KINDS[Math.floor(rand() * KINDS.length)] : '',
        help,
        msFirst,
        ms: msFirst + Math.round(rand() * 40000),
      };
    };
    let state = startTest(c.experience);
    const test: object[] = [];
    while (!state.done) {
      const jitter = rand();
      const item = nextTestItem(state, pool, () => jitter);
      if (!item) break;
      const outcome = answer(item, false);
      state = recordTry(state, item, outcome, 'test');
      test.push({ rand: jitter, pick: item.id, outcome, expected: state.tries.at(-1)!.expected, rating: state.rating, done: state.done });
    }
    const afterTest = { profile: profile(state.tries), plan: plan(state.rating, profile(state.tries)) };
    const train: object[] = [];
    for (let i = 0; i < 30; i++) {
      const x = rand();
      const item = pickTrainingItem(state.rating, state.tries, pool, () => x);
      if (!item) break;
      const weight = trainingWeight(item, profile(state.tries));
      const outcome = answer(item, true);
      state = recordTry(state, item, outcome, 'train');
      train.push({ rand: x, pick: item.id, weight, outcome, rating: state.rating });
    }
    const pr = profile(state.tries);
    runs.push({
      experience: c.experience,
      test,
      afterTest,
      train,
      final: {
        profile: pr,
        plan: plan(state.rating, pr),
        status: { mate: status(pr.mate), long: status(pr.long), families: pr.families.map((f) => status(f)) },
        review: pickReviewItem(state.tries, pool)?.id ?? '',
      },
    });
  }
  const levels = [0, 399, 599, 600, 749, 750, 1049, 1050, 1499, 1500, 1999, 2000, 2500].map((r) => ({ r, level: levelOf(r) }));
  return { generatedBy: 'scripts/export-golden-assessment.ts (núcleo TypeScript, src/core/assessment.ts)', poolSize: pool.length, range: measurableRange(pool), levels, runs };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const data = buildAssessmentGolden();
  mkdirSync(dirname(OUT), { recursive: true });
  writeFileSync(OUT, JSON.stringify(data) + '\n');
  console.log(`Escrito ${OUT}`);
}
