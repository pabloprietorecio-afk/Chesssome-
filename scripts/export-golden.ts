/**
 * Genera los datos de oro con los que se comprueba el port a GDScript (godot/tests/).
 * El núcleo TypeScript es la referencia: cualquier cambio se hace primero aquí y después en Godot.
 * Uso: npm run golden
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { expectedScore, ratingForSuccess, update, type Rating, type Result } from '../src/core/glicko2';

const OUT = fileURLToPath(new URL('../godot/tests/golden/glicko2.json', import.meta.url));

/** Generador pseudoaleatorio determinista (mulberry32): mismo archivo en cada ejecución. */
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

export function buildGolden(): object {
  const rand = rng(20261113);
  const cases: { player: Rating; results: Result[]; tau: number }[] = [
    // Ejemplo publicado por Glickman.
    {
      player: { r: 1500, rd: 200, vol: 0.06 },
      results: [
        { opponent: { r: 1400, rd: 30 }, score: 1 },
        { opponent: { r: 1550, rd: 100 }, score: 0 },
        { opponent: { r: 1700, rd: 300 }, score: 0 },
      ],
      tau: 0.5,
    },
    // Sin resultados: solo crece la incertidumbre.
    { player: { r: 1500, rd: 200, vol: 0.06 }, results: [], tau: 0.5 },
    { player: { r: 900, rd: 345, vol: 0.09 }, results: [], tau: 0.5 },
  ];
  for (let i = 0; i < 300; i++) {
    const player = { r: 400 + rand() * 2400, rd: 30 + rand() * 320, vol: 0.03 + rand() * 0.06 };
    // La app actualiza tras cada problema: casi siempre un solo resultado.
    const n = rand() < 0.8 ? 1 : 2 + Math.floor(rand() * 3);
    const results = Array.from({ length: n }, () => ({
      opponent: { r: 400 + rand() * 2600, rd: 50 + rand() * 250 },
      score: rand() < 0.5 ? 0 : 1,
    }));
    cases.push({ player, results, tau: i % 10 === 0 ? 0.3 + rand() * 0.9 : 0.5 });
  }
  const expected = Array.from({ length: 100 }, () => {
    const playerR = 400 + rand() * 2400;
    const opp = { r: 400 + rand() * 2600, rd: 30 + rand() * 300 };
    return { playerR, opp, out: expectedScore({ r: playerR }, opp) };
  });
  const forSuccess = [0.5, 0.6, 0.7, 0.75, 0.8, 0.9].flatMap((p) =>
    [600, 1150, 1500, 2100].map((r) => ({ r, p, out: ratingForSuccess(r, p) })),
  );
  return {
    generatedBy: 'scripts/export-golden.ts (núcleo TypeScript, src/core/glicko2.ts)',
    update: cases.map((c) => ({ ...c, out: update(c.player, c.results, c.tau) })),
    expectedScore: expected,
    ratingForSuccess: forSuccess,
  };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const data = buildGolden();
  mkdirSync(dirname(OUT), { recursive: true });
  writeFileSync(OUT, JSON.stringify(data, null, 1) + '\n');
  console.log(`Escrito ${OUT}`);
}
