import { readFileSync } from 'node:fs';
import { explain, explainSolved } from '../src/core/explain';
const id = process.argv[2], uci = process.argv[3];
for (const f of ['analysis.0.jsonl', 'analysis.1.jsonl']) for (const l of readFileSync(new URL('../data/dev/' + f, import.meta.url), 'utf8').split('\n')) {
  if (!l.trim()) continue; const p = JSON.parse(l); if (p.id !== id) continue;
  const e = uci ? explain(p, 0, uci) : explainSolved(p);
  console.log(e.verdict, '|', e.headline); for (const lv of e.levels) { console.log(' N' + lv.level); for (const x of lv.paragraphs) console.log('   ' + x); for (const r of lv.table) console.log('   ·', r.label, r.san, r.score, 'p' + r.depth, r.continuation); }
  console.log(' HECHOS'); for (const x of e.facts) console.log('   [' + x.source + '] ' + x.text);
}
