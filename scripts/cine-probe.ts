// Busca pausas para el cine: clasifica todas las jugadas legales de cada FEN. Uso: T=win|draw D=20 npx tsx scripts/cine-probe.ts FEN...
import { Chess } from 'chess.js';
import { UciEngine } from '../pipeline/uci';
import { classify, type FilmResult } from '../src/core/cinema';
const target = (process.env.T ?? 'draw') as FilmResult;
const depth = Number(process.env.D ?? 20);
const e = await UciEngine.start();
for (const fen of process.argv.slice(2)) {
  const c = new Chess(fen);
  const legal = c.moves({ verbose: true });
  const r = await e.analyse(fen, { depth, multipv: legal.length, maxPv: 8 });
  const cls = r.map((m) => `${c.move(m.uci) && c.undo()?.san}:${classify(m.score, target)[0]}(${'cp' in m.score ? m.score.cp : '#' + m.score.mate})`);
  console.log(`\n${fen}\n  ${cls.join('  ')}`);
}
e.quit();
