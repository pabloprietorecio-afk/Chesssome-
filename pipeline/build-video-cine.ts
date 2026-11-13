/**
 * Comprueba y empaqueta los clips de vídeo real del «Cine de finales».
 *
 * Uso: npx tsx pipeline/build-video-cine.ts [--depth 24] [--deeper 10]
 *
 * Para cada clip:
 * 1. Se reproduce la partida entera con chess.js: una sola jugada ilegal y el clip se rechaza.
 * 2. La posición de cada pregunta sale de esa reproducción, nunca escrita a mano.
 * 3. Stockfish evalúa TODAS las jugadas legales de cada pregunta. El resultado que se busca
 *    (ganar o hacer tablas) se deduce de la mejor jugada; si la posición no tiene un resultado claro
 *    para quien mueve, la pregunta se rechaza.
 * 4. Se anota si la jugada de la partida mantiene ese resultado (lo normal) o fue un error histórico.
 * 5. Las marcas de tiempo se comprueban solo por coherencia (orden, dentro del vídeo). Que la pausa caiga
 *    justo antes de la jugada solo lo puede comprobar una persona viendo el vídeo: por eso existe
 *    marks: 'pending' | 'verified'.
 *
 * Si algo falla, el programa termina con error y no escribe el paquete.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { UciEngine } from './uci';
import { CLIPS } from './video-clips';
import { analyseAll, neg, ranked, toVerdicts } from './cine-engine';
import { classify, DRAW_KEEPS_CP, WIN_SPOILS_CP, type FilmResult } from '../src/core/cinema';
import { canAutoPause, marksProblems, replay, type Clip, type ClipQuestion, type ClipSource, type ClipStop, type VideoCinePack } from '../src/core/videoCine';
import { sanEs } from '../src/core/lang';
import type { Color } from '../src/core/types';

function arg(name: string, def: string): string {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}
const DEPTH = Number(arg('depth', '24'));
const DEEPER = Number(arg('deeper', '10'));
const OUT = arg('out', 'src/data/videocine.pack.json');
const REPORT = arg('report', 'data/dev/videocine-report.json');
const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

interface QReport {
  ply: number;
  played: string;
  target: FilmResult;
  playedCls: string;
  proof: string;
  keeps: string[];
  spoils: string[];
  unclear: string[];
}
interface ClipReport {
  id: string;
  ok: boolean;
  errors: string[];
  warnings: string[];
  questions: QReport[];
}

async function buildClip(engine: UciEngine, src: ClipSource): Promise<{ clip?: Clip; report: ClipReport }> {
  const report: ClipReport = { id: src.id, ok: false, errors: [], warnings: [], questions: [] };
  const fail = (m: string) => report.errors.push(m);
  const warn = (m: string) => report.warnings.push(m);

  let game;
  try {
    game = replay(src.moves, src.id);
  } catch (e) {
    fail((e as Error).message);
    return { report };
  }

  // Vídeo y marcas
  if (!/^[\w-]{11}$/.test(src.video.id)) fail(`Identificador de vídeo no válido: ${src.video.id}`);
  // Regla del proyecto: solo vídeos del canal del titular de los derechos. Una copia resubida por terceros no entra.
  if (!src.video.official) fail('El canal del vídeo no está marcado como oficial (titular de los derechos).');
  const marks = { start: src.start, end: src.end, stops: src.stops.map((s) => s.at), duration: src.video.duration };
  const anyMark = marks.start != null || marks.end != null || marks.stops.some((x) => x != null);
  if (anyMark) for (const p of marksProblems(marks)) fail(`Marcas: ${p}`);
  if (src.marks === 'verified' && !canAutoPause({ start: src.start, stops: src.stops })) fail('marks es «verified» pero faltan marcas.');
  if (src.marks === 'verified' && src.video.duration == null) fail('marks es «verified» pero falta la duración del vídeo (protege frente a anuncios y reediciones).');
  if (!anyMark) warn('Sin marcas de tiempo: el clip no pausa solo; solo funciona «directo a la pregunta».');

  // Preguntas
  let lastPly = 0;
  const stops: ClipStop[] = [];
  for (const stop of src.stops) {
    const questions: ClipQuestion[] = [];
    let prevInStop: number | null = null;
    if (stop.questions.length === 0) fail('Hay una parada sin preguntas.');
    for (const q of stop.questions) {
      if (!Number.isInteger(q.ply) || q.ply < 1 || q.ply > game.length) {
        fail(`Pregunta con media jugada fuera de la partida: ${q.ply}`);
        continue;
      }
      if (q.ply <= lastPly) fail(`Las preguntas tienen que ir en orden: ${q.ply} tras ${lastPly}.`);
      lastPly = q.ply;
      const fen = q.ply === 1 ? START : game[q.ply - 2].fenAfter;
      const played = game[q.ply - 1];
      const playedUci = played.from + played.to + (/=([QRBN])/.exec(played.san)?.[1].toLowerCase() ?? '');
      const mover: Color = fen.split(' ')[1] === 'w' ? 'w' : 'b';
      const label = `${played.number}${played.san}`;

      const evals = await analyseAll(engine, fen, DEPTH);
      // Las jugadas con veredicto dudoso entre las mejores se miran más a fondo antes de decidir.
      let list = ranked(evals);
      const top = list.slice(0, 4).map((m) => m.uci);
      const doubt = (cp: number) => (cp > WIN_SPOILS_CP && cp < 300) || (cp < DRAW_KEEPS_CP && cp > -250);
      if ([...top, playedUci].some((u) => { const s = evals.get(u)!.score; return 'cp' in s && doubt(s.cp); })) {
        const deep = await engine.analyse(fen, { depth: DEPTH + DEEPER, multipv: Math.min(5, evals.size), maxPv: 10 });
        for (const m of deep) evals.set(m.uci, m);
        list = ranked(evals);
        warn(`${label}: veredictos dudosos a profundidad ${DEPTH}; las mejores jugadas se repitieron a ${DEPTH + DEEPER}.`);
      }
      const best = list[0];
      let target: FilmResult;
      if (classify(best.score, 'win') === 'keeps') target = 'win';
      else if ('cp' in best.score && best.score.cp >= DRAW_KEEPS_CP && best.score.cp <= WIN_SPOILS_CP) target = 'draw';
      else {
        fail(`${label}: la posición no tiene un resultado claro para quien mueve (mejor jugada: ${JSON.stringify(best.score)}).`);
        continue;
      }
      const verdicts = toVerdicts(fen, list, target);
      const pv = verdicts.find((v) => v.uci === playedUci);
      if (!pv) {
        fail(`${label}: la jugada de la partida no está entre las legales analizadas.`);
        continue;
      }
      const by = (k: string) => verdicts.filter((v) => v.cls === k).map((v) => v.san);
      if (pv.cls !== 'keeps') warn(`${label}: la jugada de la partida queda «${pv.cls}»; la app la presentará como error histórico.`);
      if (by('spoils').length === 0) warn(`${label}: ninguna jugada estropea el resultado; la pregunta no distingue.`);
      if (by('keeps').length > 1) warn(`${label}: varias jugadas mantienen el resultado: ${by('keeps').join(', ')}.`);
      if (pv.cls === 'keeps' && !q.why.includes(sanEs(played.san.replace(/[+#]/g, '')))) warn(`${label}: la explicación no nombra la jugada (${sanEs(played.san)}).`);

      // ¿Mate forzado tras la jugada de la partida? Solo entonces se habla de prueba.
      let proof: 'mate' | 'engine' = 'mate' in pv.score && pv.score.mate > 0 ? 'mate' : 'engine';
      if (proof === 'engine' && target === 'win' && pv.cls === 'keeps') {
        const after = await engine.analyse(played.fenAfter, { depth: DEPTH + DEEPER + 6, multipv: 1, maxPv: 1 });
        const s = after[0]?.score;
        if (s && 'mate' in neg(s) && (neg(s) as { mate: number }).mate > 0) proof = 'mate';
      }

      const bridge = prevInStop == null ? [] : game.slice(prevInStop, q.ply - 1);
      prevInStop = q.ply;
      questions.push({ ...q, fen, mover, lead: q.ply >= 2 ? game[q.ply - 2] : null, bridge, played, playedUci, playedCls: pv.cls, target, verdicts, proof });
      report.questions.push({ ply: q.ply, played: label, target, playedCls: pv.cls, proof, keeps: by('keeps'), spoils: by('spoils'), unclear: by('unclear') });
    }
    stops.push({ at: stop.at, resumeAt: stop.resumeAt ?? null, questions });
  }

  report.ok = report.errors.length === 0;
  if (!report.ok) return { report };
  const { moves: _moves, stops: _stops, ...rest } = src;
  return { clip: { ...rest, stops, tail: game.slice(lastPly), plies: game.length }, report };
}

const engine = await UciEngine.start('lite-single', 128);
const clips: Clip[] = [];
const reports: ClipReport[] = [];
for (const src of CLIPS) {
  const t = Date.now();
  const { clip, report } = await buildClip(engine, src);
  reports.push(report);
  console.log(`${report.ok ? 'OK ' : 'ERR'} ${src.id} (${((Date.now() - t) / 1000).toFixed(1)} s)`);
  for (const e of report.errors) console.log('   error:', e);
  for (const w of report.warnings) console.log('   aviso:', w);
  for (const q of report.questions) console.log(`   ${q.played} [${q.target}, ${q.proof}]: mantienen [${q.keeps.join(' ')}] dudosas [${q.unclear.join(' ')}] estropean ${q.spoils.length}`);
  if (clip) clips.push(clip);
}
engine.quit();

mkdirSync(dirname(REPORT), { recursive: true });
writeFileSync(REPORT, JSON.stringify({ engine: engine.name, depth: DEPTH, reports }, null, 1));
if (reports.some((r) => !r.ok)) {
  console.error('Hay clips con errores: no se escribe el paquete.');
  process.exit(1);
}
const pack: VideoCinePack = { version: 1, engine: { name: engine.name, depth: DEPTH }, builtAt: new Date().toISOString().slice(0, 10), clips };
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(pack));
console.log(`Paquete escrito en ${OUT} (${clips.length} clips, ${JSON.stringify(pack).length} bytes).`);
