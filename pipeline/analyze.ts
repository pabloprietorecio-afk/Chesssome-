/**
 * Analiza con Stockfish cada punto de decisión de cada problema y guarda el resultado en JSONL.
 *
 * Uso:
 *   npm run pipeline:analyze -- --in data/dev/puzzles.json --out data/dev/analysis.jsonl \
 *        [--depth-all 12] [--depth-top 18] [--limit 300] [--shard 0/2] [--flavor lite-single]
 *
 * - Pasada amplia: MultiPV = nº de jugadas legales. Da evaluación y refutación de CUALQUIER jugada del usuario.
 * - Pasada profunda: MultiPV = 3. Da la evaluación fina de la mejor jugada y de sus alternativas.
 * - Verificación: la solución de Lichess debe ser la primera opción del motor. Si no lo es, el problema
 *   queda marcado verified=false y no entra en el paquete de la app.
 * - Reanudable: los problemas ya presentes en el fichero de salida se saltan.
 */
import { appendFileSync, existsSync, readFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { Chess } from 'chess.js';
import { UciEngine } from './uci';
import type { AnalyzedPuzzle, DecisionPoint, MoveEval, Puzzle, Score } from '../src/core/types';

function arg(name: string, def?: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const applyUci = (chess: Chess, uci: string) =>
  chess.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });

/** Valor comparable de una evaluación: los mates dominan a cualquier ventaja material. */
export function scoreValue(s: Score): number {
  if ('cp' in s) return s.cp;
  return s.mate > 0 ? 100000 - s.mate : -100000 - s.mate;
}

async function analysePuzzle(
  engine: UciEngine,
  p: Puzzle,
  depthAll: number,
  depthTop: number,
): Promise<AnalyzedPuzzle> {
  const chess = new Chess(p.fen);
  applyUci(chess, p.moves[0]);
  const points: DecisionPoint[] = [];
  for (let k = 1; k < p.moves.length; k += 2) {
    const fen = chess.fen();
    const solution = p.moves[k];
    const legal = chess.moves({ verbose: true });
    const evalsRaw = await engine.analyse(fen, { depth: depthAll, multipv: legal.length, maxPv: 8 });
    const top = await engine.analyse(fen, { depth: depthTop, multipv: Math.min(3, legal.length), maxPv: 12 });

    // Garantiza una entrada por jugada legal. Si el motor omitiera alguna, se deja constancia y el problema no se verifica.
    const seen = new Set(evalsRaw.map((e) => e.uci));
    const missing = legal.filter((m) => !seen.has(m.lan)).length;
    const evals: MoveEval[] = [...evalsRaw].sort((a, b) => scoreValue(b.score) - scoreValue(a.score));

    // Las dos pasadas se guardan por separado para no mezclar profundidades:
    // `top` manda para las jugadas que cubre y `evals` da cobertura al resto.

    // ¿Coincide con la solución? En un mate en 1 Lichess acepta cualquier jugada que dé mate.
    const best = top[0];
    let agree = missing === 0 && !!best && best.uci === solution;
    if (!agree && missing === 0 && best) {
      const probe = new Chess(fen);
      applyUci(probe, solution);
      const solutionMates = probe.isCheckmate();
      const bestMates = 'mate' in best.score && best.score.mate === 1;
      if (solutionMates && bestMates) agree = true;
    }
    points.push({ index: points.length, fen, solution, evals, top, agree });
    applyUci(chess, solution);
    if (k + 1 < p.moves.length) applyUci(chess, p.moves[k + 1]);
  }
  return {
    ...p,
    points,
    engine: { name: engine.name, depthAll, depthTop },
    verified: points.every((pt) => pt.agree),
  };
}

async function main(): Promise<void> {
  const input = arg('in', 'data/dev/puzzles.json')!;
  const output = arg('out', 'data/dev/analysis.jsonl')!;
  const depthAll = Number(arg('depth-all', '12'));
  const depthTop = Number(arg('depth-top', '18'));
  const limit = Number(arg('limit', '0'));
  const flavor = arg('flavor', 'lite-single')!;
  const [shard, shards] = (arg('shard', '0/1') as string).split('/').map(Number);

  const { puzzles } = JSON.parse(readFileSync(input, 'utf8')) as { puzzles: Puzzle[] };
  const done = new Set<string>();
  if (existsSync(output)) {
    for (const line of readFileSync(output, 'utf8').split('\n')) {
      if (line.trim()) done.add((JSON.parse(line) as { id: string }).id);
    }
  }
  mkdirSync(dirname(output), { recursive: true });
  const todo = puzzles
    .slice(0, limit > 0 ? limit : puzzles.length)
    .filter((_, i) => i % shards === shard)
    .filter((p) => !done.has(p.id));

  const engine = await UciEngine.start(flavor);
  const t0 = Date.now();
  let ok = 0;
  for (let i = 0; i < todo.length; i++) {
    const res = await analysePuzzle(engine, todo[i], depthAll, depthTop);
    appendFileSync(output, JSON.stringify(res) + '\n');
    if (res.verified) ok++;
    if ((i + 1) % 10 === 0 || i === todo.length - 1) {
      const s = ((Date.now() - t0) / 1000).toFixed(0);
      console.log(`[${shard}/${shards}] ${i + 1}/${todo.length} analizados, ${ok} verificados, ${s}s`);
    }
  }
  engine.quit();
}

if (process.argv[1] && process.argv[1].endsWith('analyze.ts')) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
