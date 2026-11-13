/**
 * Comprueba y empaqueta las películas del «Cine de finales».
 *
 * Uso: npx tsx pipeline/build-cine.ts [--depth 20] [--out src/data/cine.pack.json]
 *
 * Para cada película:
 * 1. Todas las jugadas deben ser legales (chess.js).
 * 2. Cada jugada del protagonista debe mantener el resultado anunciado según Stockfish
 *    (ganar: ≥ +3 peones o mate; tablas: ≥ −0,6 peones).
 * 3. Cada jugada del rival debe quedar a ≤ 1,5 peones de su mejor defensa: así la película
 *    no enseña una victoria que solo existe porque el rival se equivoca.
 * 4. En cada pausa se analizan TODAS las jugadas legales y se guardan su veredicto y la línea del motor.
 *    La respuesta de la película tiene que ser de las que mantienen el resultado.
 * 5. Certificado: en las de victoria se busca un mate forzado en la línea. Las de tablas solo pueden
 *    llevar «tablas según el motor»: sin tablas de finales no hay prueba completa.
 *
 * Si algo falla, el programa termina con error y no escribe el paquete.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { Chess } from 'chess.js';
import { UciEngine } from './uci';
import { FILMS } from './cine-films';
import {
  classify,
  frames,
  scoreValue,
  turnOf,
  type Certificate,
  type CinemaPack,
  type FilmPacked,
  type FilmResult,
  type MoveVerdict,
  type PausePack,
} from '../src/core/cinema';
import type { Score } from '../src/core/types';
import { analyseAll as analyseAllAt, neg, ranked as rankEvals, toVerdicts } from './cine-engine';

function arg(name: string, def: string): string {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const DEPTH = Number(arg('depth', '20'));
const OUT = arg('out', 'src/data/cine.pack.json');
const REPORT = arg('report', 'data/dev/cine-report.json');
const OPP_TOLERANCE_CP = 150;
const DEEPER = Number(arg('deeper', '8'));

const analyseAll = (engine: UciEngine, fen: string) => analyseAllAt(engine, fen, DEPTH);

interface FilmReport {
  id: string;
  ok: boolean;
  errors: string[];
  warnings: string[];
  certificate?: Certificate;
  plies: { n: string; san: string; mover: 'hero' | 'rival'; score: Score; best: string; bestScore: Score }[];
  pauses: { step: number; answer: string; keeps: string[]; spoils: string[]; unclear: string[] }[];
}

async function buildFilm(engine: UciEngine, src: (typeof FILMS)[number]): Promise<{ packed?: FilmPacked; report: FilmReport }> {
  const report: FilmReport = { id: src.id, ok: false, errors: [], warnings: [], plies: [], pauses: [] };
  let fr;
  try {
    fr = frames(src);
  } catch (e) {
    report.errors.push((e as Error).message);
    return { report };
  }
  const pauses: PausePack[] = [];
  let mateCert: Certificate | null = null;
  let ply = 0;
  const target: FilmResult = src.result;

  for (const f of fr) {
    if (f.kind !== 'move') continue;
    ply++;
    const mover = turnOf(f.before);
    const isHero = mover === src.hero;
    const evals = await analyseAll(engine, f.before);
    let ranked = rankEvals(evals);
    let best = ranked[0];
    let played = evals.get(f.uci)!;
    // Una jugada del protagonista con veredicto dudoso se vuelve a mirar más a fondo antes de decidir.
    if (isHero && classify(played.score, target) === 'unclear') {
      const deep = await engine.analyse(f.before, { depth: DEPTH + DEEPER, multipv: Math.min(4, evals.size), maxPv: 10 });
      const again = deep.find((m) => m.uci === f.uci);
      if (again) {
        evals.set(f.uci, again);
        played = again;
        report.warnings.push(`${f.number}${f.san}: dudosa a profundidad ${DEPTH}; a ${DEPTH + DEEPER}: ${JSON.stringify(again.score)}.`);
      }
    }
    ranked = rankEvals(evals);
    best = ranked[0];
    const bestSan = new Chess(f.before).move({ from: best.uci.slice(0, 2), to: best.uci.slice(2, 4), promotion: best.uci[4] }).san;
    report.plies.push({ n: f.number, san: f.san, mover: isHero ? 'hero' : 'rival', score: played.score, best: bestSan, bestScore: best.score });

    // Certificado de mate: puntuación desde el punto de vista del protagonista.
    const heroScore = isHero ? played.score : neg(played.score);
    if (!mateCert && target === 'win' && 'mate' in heroScore && heroScore.mate > 0) {
      mateCert = { kind: 'mate', ply, mateIn: heroScore.mate };
    }

    if (isHero) {
      const cls = classify(played.score, target);
      if (cls !== 'keeps') report.errors.push(`${f.number}${f.san}: la jugada del protagonista queda «${cls}» (${JSON.stringify(played.score)}).`);
    } else {
      const gap = scoreValue(best.score) - scoreValue(played.score);
      // Si la mejor defensa también pierde (o también hace tablas, en una película de tablas que el rival intenta ganar),
      // la jugada del rival no cambia el resultado: se admite, pero queda anotada.
      const resultSafe = classify(neg(best.score), target) === 'keeps' && classify(neg(played.score), target) === 'keeps';
      if (gap > OPP_TOLERANCE_CP && resultSafe) report.warnings.push(`${f.number}${f.san}: el rival no elige la defensa más tenaz (${bestSan}); el resultado no cambia.`);
      else if (gap > OPP_TOLERANCE_CP) report.errors.push(`${f.number}${f.san}: el rival se aleja ${gap} de su mejor defensa (${bestSan}, ${JSON.stringify(best.score)}).`);
    }

    if (f.pause) {
      if (!isHero) {
        report.errors.push(`${f.number}${f.san}: las pausas solo se permiten en jugadas del protagonista.`);
        continue;
      }
      const verdicts: MoveVerdict[] = toVerdicts(f.before, ranked, target);
      const by = (k: MoveVerdict['cls']) => verdicts.filter((v) => v.cls === k).map((v) => v.san);
      report.pauses.push({ step: f.step, answer: f.san, keeps: by('keeps'), spoils: by('spoils'), unclear: by('unclear') });
      if (by('spoils').length === 0) report.warnings.push(`${f.number}${f.san}: ninguna jugada estropea el resultado; la pausa no distingue.`);
      pauses.push({ step: f.step, answerUci: f.uci, verdicts });
    }
  }

  // Última posición: también puede aportar el mate.
  const last = [...fr].reverse().find((f) => f.kind === 'move');
  let certificate: Certificate;
  if (target === 'win') {
    if (!mateCert && last && last.kind === 'move') {
      const c = new Chess(last.after);
      if (c.isCheckmate()) mateCert = { kind: 'mate', ply, mateIn: 0 };
      else {
        const top = await engine.analyse(last.after, { depth: DEPTH + 4, multipv: 1, maxPv: 1 });
        const s = top[0]?.score;
        if (s) {
          const heroS = turnOf(last.after) === src.hero ? s : neg(s);
          if ('mate' in heroS && heroS.mate > 0) mateCert = { kind: 'mate', ply: ply + 1, mateIn: heroS.mate };
        }
      }
    }
    certificate = mateCert ?? { kind: 'engine-only', depth: DEPTH };
    if (!mateCert) report.warnings.push('Sin mate forzado encontrado: la victoria queda «según el motor».');
  } else {
    certificate = { kind: 'engine-draw', depth: DEPTH };
  }
  report.certificate = certificate;
  report.ok = report.errors.length === 0;
  return { packed: report.ok ? { ...src, pauses, certificate } : undefined, report };
}

const engine = await UciEngine.start('lite-single', 128);
const films: FilmPacked[] = [];
const reports: FilmReport[] = [];
for (const src of FILMS) {
  const t = Date.now();
  const { packed, report } = await buildFilm(engine, src);
  reports.push(report);
  console.log(`${report.ok ? 'OK ' : 'ERR'} ${src.id} (${((Date.now() - t) / 1000).toFixed(1)} s) ${report.certificate ? JSON.stringify(report.certificate) : ''}`);
  for (const e of report.errors) console.log('   error:', e);
  for (const w of report.warnings) console.log('   aviso:', w);
  for (const p of report.pauses) console.log(`   pausa ${p.answer}: mantienen [${p.keeps.join(' ')}] estropean [${p.spoils.join(' ')}] dudosas [${p.unclear.join(' ')}]`);
  if (packed) films.push(packed);
}
engine.quit();

mkdirSync(dirname(REPORT), { recursive: true });
writeFileSync(REPORT, JSON.stringify({ engine: engine.name, depth: DEPTH, reports }, null, 1));
if (reports.some((r) => !r.ok)) {
  console.error('Hay películas con errores: no se escribe el paquete.');
  process.exit(1);
}
const pack: CinemaPack = { version: 1, engine: { name: engine.name, depth: DEPTH }, builtAt: new Date().toISOString().slice(0, 10), films };
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(pack));
console.log(`Paquete escrito en ${OUT} (${films.length} películas, ${JSON.stringify(pack).length} bytes).`);
