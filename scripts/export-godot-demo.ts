/**
 * Exporta la muestra de problemas de la app de Godot:
 *   godot/data/demo_puzzles.json        la lista de problemas
 *   godot/data/explain/<id>.json        las explicaciones de cada problema, ya redactadas
 *
 * Las explicaciones se generan aquí, con la misma capa explicativa que usa el prototipo web (src/core/explain.ts),
 * y viajan como datos: la app de Godot no redacta ni calcula ajedrez nuevo, solo las muestra.
 * Hay una explicación por cada jugada legal de cada punto de decisión, más la del problema resuelto.
 * Son los mismos problemas reales de Lichess (CC0) del paquete provisional de desarrollo.
 *
 * Cada problema lleva además lo que la evaluación necesita saber de él (src/core/assessment.ts): la
 * incertidumbre de su rating, la clave y la familia de su tema, si acaba en mate y cuántas jugadas pide.
 * Y cada jugada equivocada, su clase de error (ErrorKind).
 *
 * Uso: npx tsx scripts/export-godot-demo.ts [cuántos]   (npm run godot:demo)
 * Después hay que regenerar los datos de oro (npm run golden): la prueba de la evaluación usa esta lista.
 */
import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Chess } from 'chess.js';
import { itemOf } from '../src/core/assessment';
import { explain, explainSolved, type Explanation, type Line } from '../src/core/explain';
import { unpackPuzzle } from '../src/core/pack';
import { primaryTheme, themeName } from '../src/core/themes';
import type { AnalyzedPuzzle, PuzzlePack } from '../src/core/types';

const DATA = fileURLToPath(new URL('../godot/data/', import.meta.url));
const n = Number(process.argv[2] ?? 150);
const pack = JSON.parse(readFileSync(new URL('../src/data/puzzles.pack.json', import.meta.url), 'utf8')) as PuzzlePack;
const all = pack.puzzles.map((p) => unpackPuzzle(p, pack.engine)).sort((a, b) => a.rating - b.rating);
// De fácil a difícil. La muestra de desarrollo tiene muy pocos problemas fáciles (29 por debajo de 1200 y solo
// 2 por debajo de 1000): van todos, para medir lo mejor posible a quien empieza. El resto, repartidos por dificultad.
const easy = all.filter((p) => p.rating < 1200);
const rest = all.filter((p) => p.rating >= 1200);
const m = Math.max(2, n - easy.length);
const picked = [...easy, ...Array.from({ length: m }, (_, i) => rest[Math.floor((i * (rest.length - 1)) / (m - 1))])].slice(0, Math.max(n, 2));

const list = {
  provisional: true,
  source: 'Lichess (CC0), muestra de desarrollo',
  engine: pack.engine.name,
  puzzles: picked.map((p) => {
    const item = itemOf(p);
    return {
      id: p.id,
      fen: p.fen,
      moves: p.moves,
      rating: p.rating,
      rd: p.rd,
      theme: themeName(primaryTheme(p.themes)),
      key: item.theme,
      family: item.family,
      mate: item.mate,
      steps: item.steps,
      game: p.gameUrl,
    };
  }),
};
mkdirSync(DATA, { recursive: true });
writeFileSync(DATA + 'demo_puzzles.json', JSON.stringify(list) + '\n');

/**
 * Formato compacto de una explicación. Los textos se repiten mucho entre jugadas (el concepto, las cifras del
 * motor, los hechos), así que cada ficha lleva una tabla de textos, `S`, y las explicaciones guardan índices:
 *   s   jugada en notación española          b   la mejor jugada
 *   ok  1 si el problema la acepta           v   veredicto (best, alsoWins, slower, missed, loses)
 *   e   clase de error (ErrorKind; no va si la jugada es la del problema)
 *   h   titular (índice en S)
 *   l   los cuatro niveles: { t título, p párrafos, a flechas [desde, hasta, tono], n variantes, r filas de la tabla }
 *       (t, p y r son índices en S; n, índices en `lines`; una fila es «etiqueta⇥jugada⇥evaluación⇥profundidad⇥continuación»)
 *   f   hechos con su procedencia: [fuente, índice en S]
 * Las variantes van en `lines`: { label, tone, fen, ucis, text }. La app recalcula sus posiciones con sus
 * propias reglas (godot/core/chess.gd).
 */
function exportPuzzle(p: AnalyzedPuzzle) {
  const S: string[] = [];
  const sIndex = new Map<string, number>();
  const str = (text: string): number => {
    let i = sIndex.get(text);
    if (i === undefined) {
      i = S.length;
      S.push(text);
      sIndex.set(text, i);
    }
    return i;
  };
  const lines: { label: string; tone: string; fen: string; ucis: string[]; text: string }[] = [];
  const seen = new Map<string, number>();
  const lineIndex = (l: Line): number => {
    const item = { label: l.label, tone: l.tone, fen: l.startFen, ucis: l.plies.map((x) => x.uci), text: l.text };
    const key = JSON.stringify(item);
    let i = seen.get(key);
    if (i === undefined) {
      i = lines.length;
      lines.push(item);
      seen.set(key, i);
    }
    return i;
  };
  const packExplanation = (e: Explanation) => ({
    s: e.playedSan,
    b: e.bestSan,
    ok: e.correct ? 1 : 0,
    v: e.verdict,
    ...(e.errorKind ? { e: e.errorKind } : {}),
    h: str(e.headline),
    l: e.levels.map((lv) => ({
      t: str(lv.title),
      p: lv.paragraphs.map(str),
      a: lv.arrows.map((a) => [a.from, a.to, a.tone]),
      n: lv.lines.map(lineIndex),
      r: lv.table.map((r) => str([r.label, r.san, r.score, r.depth, r.continuation].join('\t'))),
    })),
    f: e.facts.map((f) => [f.source, str(f.text)]),
  });
  let count = 0;
  const points = p.points.map((pt, k) => {
    const chess = new Chess(pt.fen);
    const moves: Record<string, unknown> = {};
    for (const m of chess.moves({ verbose: true })) {
      const uci = m.from + m.to + (m.promotion ?? '');
      moves[uci] = packExplanation(explain(p, k, uci));
      count++;
    }
    return { fen: pt.fen, solution: pt.solution, moves };
  });
  const out = { id: p.id, engine: p.engine.name, depthAll: p.engine.depthAll, depthTop: p.engine.depthTop, solved: packExplanation(explainSolved(p)), points, lines, S };
  return { out, count };
}

const dir = DATA + 'explain/';
rmSync(dir, { recursive: true, force: true });
mkdirSync(dir, { recursive: true });
let total = 0;
let bytes = 0;
for (const p of picked) {
  const { out, count } = exportPuzzle(p);
  const text = JSON.stringify(out) + '\n';
  writeFileSync(`${dir}${p.id}.json`, text);
  total += count + 1;
  bytes += text.length;
}
console.log(`Escrito ${DATA}demo_puzzles.json: ${list.puzzles.length} problemas (${picked[0].rating}–${picked.at(-1)!.rating})`);
console.log(`Escritas ${readdirSync(dir).length} fichas de explicaciones en ${dir}: ${total} explicaciones, ${(bytes / 1e6).toFixed(2)} MB`);
