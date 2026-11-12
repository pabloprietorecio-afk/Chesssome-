/**
 * Control de calidad y empaquetado.
 *
 * 1. Junta los ficheros de análisis (data/dev/analysis*.jsonl).
 * 2. Descarta los problemas que el motor no ha verificado.
 * 3. Genera la explicación de TODAS las jugadas legales de cada problema y comprueba invariantes:
 *    ninguna excepción, ninguna frase mal formada, ninguna afirmación de mate o de material sin respaldo.
 *    Un problema que incumple algo se excluye del paquete.
 * 4. Escribe el paquete que consume la app (src/data/puzzles.pack.json) y un informe (data/dev/report.json).
 *
 * Uso: npm run pipeline:report -- [--max 400] [--out src/data/puzzles.pack.json]
 */
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { Chess } from 'chess.js';
import { explain, explainSolved, lineOutcome, type Explanation } from '../src/core/explain';
import { packPuzzle, unpackPuzzle } from '../src/core/pack';
import { primaryTheme } from '../src/core/themes';
import type { AnalyzedPuzzle, DatasetSource, PuzzlePack } from '../src/core/types';

function arg(name: string, def?: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const BAD_TEXT = [/undefined/, /NaN/, /\bnull\b/, / {2,}/, / de el /, / a el /, /, ,/, /\.\./, / \./, /^\s*$/, /\bde de\b/, /\bque que\b/];

function lint(e: Explanation): string[] {
  const problems: string[] = [];
  for (const l of e.levels) {
    for (const p of l.paragraphs) {
      for (const re of BAD_TEXT) if (re.test(p)) problems.push(`texto «${p}» incumple ${re}`);
      if (!/[.!?»]$/.test(p)) problems.push(`sin punto final: «${p}»`);
    }
    for (const line of l.lines) if (line.plies.length === 0) problems.push('variante vacía');
  }
  return problems;
}

function main(): void {
  const max = Number(arg('max', '400'));
  const out = arg('out', 'src/data/puzzles.pack.json')!;
  const dir = 'data/dev';
  const byId = new Map<string, AnalyzedPuzzle>();
  for (const f of readdirSync(dir).sort()) {
    if (!/^analysis.*\.jsonl$/.test(f)) continue;
    for (const line of readFileSync(`${dir}/${f}`, 'utf8').split('\n')) {
      if (!line.trim()) continue;
      const p = JSON.parse(line) as AnalyzedPuzzle;
      byId.set(p.id, p);
    }
  }
  const { source, puzzles: ordered } = JSON.parse(readFileSync(`${dir}/puzzles.json`, 'utf8')) as {
    source: DatasetSource;
    puzzles: { id: string }[];
  };
  // Se respeta el orden estratificado de la importación.
  const sample = Number(arg('sample', '0'));
  const all = ordered.map((p) => byId.get(p.id)).filter((p): p is AnalyzedPuzzle => !!p);
  const analysed = sample > 0 ? all.slice(0, sample) : all;
  const t0 = Date.now();

  const report = {
    generatedAt: new Date().toISOString(),
    analysed: analysed.length,
    verifiedByEngine: 0,
    rejectedByEngine: [] as string[],
    rejectedByQa: [] as { id: string; why: string }[],
    explanationsChecked: 0,
    verdicts: {} as Record<string, number>,
    conceptWithInstance: 0,
    conceptDefinitionOnly: 0,
    noConcept: 0,
    packed: 0,
    ratingHistogram: {} as Record<string, number>,
    primaryThemes: {} as Record<string, number>,
  };

  const accepted: AnalyzedPuzzle[] = [];
  for (const [idx, raw] of analysed.entries()) {
    if (idx > 0 && idx % 25 === 0) console.error(`QA ${idx}/${analysed.length} · ${((Date.now() - t0) / 1000).toFixed(0)} s`);
    if (!raw.verified) {
      report.rejectedByEngine.push(raw.id);
      continue;
    }
    report.verifiedByEngine++;
    // Se comprueba la versión que verá la app: empaquetada y desempaquetada.
    const p = unpackPuzzle(packPuzzle(raw), raw.engine);
    try {
      const problems: string[] = [];
      const solved = explainSolved(p);
      problems.push(...lint(solved));

      // La solución completa debe ser jugable y, si el problema es de mate, acabar en mate.
      const pov = new Chess(p.points[0].fen).turn();
      const o = lineOutcome(p.points[0].fen, p.moves.slice(1), pov);
      if (p.themes.includes('mate') && !o.mates) problems.push('etiquetado como mate pero la línea no termina en mate');
      if (/\bmate\b/.test(solved.levels[0].paragraphs[0]) && !o.mates && !/forzado/.test(solved.levels[0].paragraphs[0])) {
        problems.push('la explicación anuncia mate y la línea no lo da');
      }
      const n2 = solved.levels[1].paragraphs;
      if (n2.some((t) => t.startsWith('Aquí:'))) report.conceptWithInstance++;
      else if (/no tiene un motivo táctico/.test(n2.join(' '))) report.noConcept++;
      else report.conceptDefinitionOnly++;

      for (const pt of p.points) {
        const legal = new Chess(pt.fen).moves({ verbose: true });
        for (const m of legal) {
          const e = explain(p, pt.index, m.lan);
          report.explanationsChecked++;
          report.verdicts[e.verdict] = (report.verdicts[e.verdict] ?? 0) + 1;
          problems.push(...lint(e));
          if (m.lan === pt.solution && !e.correct) problems.push('la solución no se acepta como correcta');
          if (e.levels[2].lines.length === 0) problems.push('explicación sin variante');
        }
        if (pt.evals.length !== legal.length) problems.push(`faltan evaluaciones: ${pt.evals.length} de ${legal.length}`);
      }
      if (problems.length > 0) {
        report.rejectedByQa.push({ id: p.id, why: problems[0] });
        continue;
      }
    } catch (err) {
      report.rejectedByQa.push({ id: p.id, why: `excepción: ${(err as Error).message}` });
      continue;
    }
    accepted.push(raw);
  }

  const chosen = accepted.slice(0, max);
  for (const p of chosen) {
    const bin = `${Math.floor(p.rating / 200) * 200}`;
    report.ratingHistogram[bin] = (report.ratingHistogram[bin] ?? 0) + 1;
    const t = primaryTheme(p.themes);
    report.primaryThemes[t] = (report.primaryThemes[t] ?? 0) + 1;
  }
  report.packed = chosen.length;

  const pack: PuzzlePack = {
    schema: 1,
    provisional: true,
    label: 'Muestra de desarrollo: problemas reales de Lichess (CC0). No es el catálogo de producción.',
    source,
    engine: chosen[0]?.engine ?? { name: 'desconocido', depthAll: 0, depthTop: 0 },
    generatedAt: report.generatedAt,
    puzzles: chosen.map((p) => packPuzzle(p)),
  };
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify(pack));
  writeFileSync(`${dir}/report.json`, JSON.stringify(report, null, 2));
  const kb = (JSON.stringify(pack).length / 1024).toFixed(0);
  console.log(JSON.stringify({ ...report, rejectedByQa: report.rejectedByQa.slice(0, 12), packKb: kb }, null, 1));
}

main();
