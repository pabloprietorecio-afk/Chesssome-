// Mide el tiempo de análisis MultiPV del motor en este entorno (solo desarrollo).
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
const require = createRequire(import.meta.url);
const flavor = process.argv[2] || 'lite-single';
const depth = Number(process.argv[3] || 12);
const multipv = Number(process.argv[4] || 40);
const enginePath = require('stockfish').findEngine(flavor);
const child = spawn(process.execPath, [enginePath], { stdio: 'pipe' });
let buf = '';
const waiters = [];
child.stdout.on('data', (d) => {
  buf += d.toString();
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    for (const w of [...waiters]) w(line);
  }
});
child.stderr.on('data', (d) => process.stderr.write(d));
const send = (s) => child.stdin.write(s + '\n');
const until = (pred) => new Promise((res) => { const w = (l) => { if (pred(l)) { waiters.splice(waiters.indexOf(w), 1); res(l); } }; waiters.push(w); });
const t0 = Date.now();
send('uci'); await until((l) => l === 'uciok');
send(`setoption name MultiPV value ${multipv}`);
send('setoption name Hash value 64');
send('isready'); await until((l) => l === 'readyok');
console.log('init ms', Date.now() - t0, flavor);
// Posición del problema tewjc tras a2a7 (juegan negras)
const fens = [
  'r5k1/Rp3p1p/2b2qp1/3pr3/8/4P2P/2PN1PP1/Q3K2R b K - 0 19',
  '5r2/p3R2p/6p1/3B2k1/2p2b2/2P2P2/P5P1/1q2QK2 b - - 2 39',
];
for (const fen of fens) {
  const t1 = Date.now();
  let last = {}; let nodes = 0;
  const w = (l) => { const m = l.match(/ multipv (\d+) .* pv (\S+)/); if (m) { last[m[1]] = l; } const n = l.match(/ nodes (\d+)/); if (n) nodes = Number(n[1]); };
  waiters.push(w);
  send('ucinewgame'); send('position fen ' + fen); send(`go depth ${depth}`);
  const bm = await until((l) => l.startsWith('bestmove'));
  waiters.splice(waiters.indexOf(w), 1);
  const lines = Object.values(last);
  console.log(`depth ${depth} multipv ${multipv}: ${Date.now() - t1} ms, lines ${lines.length}, nodes ${nodes}, ${bm}`);
  console.log('  top:', lines[0]?.slice(0, 160));
  console.log('  last:', lines[lines.length - 1]?.slice(0, 160));
}
send('quit');
