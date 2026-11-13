/**
 * Ayudas fuera de la explicación propia: analizar la posición en Lichess y preguntar a una IA general.
 *
 * A la IA se le manda TEXTO (posición, jugadas y cifras del motor), no una captura: las IA generales leen
 * mal los tableros en imagen y se equivocan a menudo al calcular, así que se les da la posición exacta
 * y el análisis verificado para que su respuesta parta de datos ciertos.
 */
import { Chess } from 'chess.js';
import { buildLine, type Explanation } from './explain';
import type { AnalyzedPuzzle } from './types';

/**
 * Tablero de análisis de Lichess con la posición cargada.
 * Formato comprobado en el foro de Lichess: lichess.org/analysis/<FEN con los espacios como %20>.
 */
export function lichessAnalysisUrl(fen: string): string {
  return 'https://lichess.org/analysis/' + fen.trim().split(/\s+/).join('%20');
}

/**
 * Abre la búsqueda de Google en Modo IA. El parámetro udm=50 no está documentado por Google
 * (lo han observado terceros): si deja de funcionar, la búsqueda se abre en modo normal.
 */
export function googleAiModeUrl(text: string): string {
  return 'https://www.google.com/search?udm=50&q=' + encodeURIComponent(text);
}

export interface ShareInput {
  puzzle: AnalyzedPuzzle;
  /** Explicación de la jugada que se pregunta (la del jugador o la que ha probado en «¿Y si juego…?»). */
  exp: Explanation;
  /** Nivel del jugador en palabras, p. ej. "Iniciado (1150 en Chessome)". */
  levelLabel?: string;
  question?: string;
  /** La jugada no se jugó: se está probando con «¿Y si juego…?». */
  tried?: boolean;
}

/** Pregunta por defecto, según si la jugada fue la buena. */
export function defaultQuestion(exp: Explanation): string {
  if (exp.correct) return `¿Por qué ${exp.bestSan} es la mejor jugada en esta posición? Explícamelo de forma sencilla.`;
  return `¿Por qué ${exp.playedSan} no funciona y ${exp.bestSan} sí? Explícamelo de forma sencilla.`;
}

/** Texto que se comparte con una IA general: todo lo que necesita saber, sin datos personales. */
export function aiShareText({ puzzle, exp, levelLabel, question, tried }: ShareInput): string {
  const pt = puzzle.points[exp.pointIndex];
  const side = new Chess(pt.fen).turn() === 'w' ? 'las blancas' : 'las negras';
  const solution = buildLine(pt.fen, puzzle.moves.slice(1 + 2 * exp.pointIndex), '', 'good').text;
  const rows = exp.levels[3].table;
  const out: string[] = [
    'Estoy aprendiendo ajedrez y tengo una duda sobre esta posición de un problema real de Lichess.',
    '',
    `Posición (FEN): ${pt.fen}`,
    `Juegan ${side}.`,
    tried
      ? `Estoy probando ${exp.playedSan}${exp.correct ? ', que es la mejor jugada.' : `; la mejor es ${exp.bestSan}.`}`
      : exp.correct
        ? `He jugado ${exp.playedSan}, que es la mejor jugada.`
        : `He jugado ${exp.playedSan}, pero la mejor era ${exp.bestSan}.`,
    `Solución: ${solution}`,
  ];
  if (rows.length > 0) {
    out.push('', `Análisis de ${puzzle.engine.name} (positivo = ventaja para quien mueve):`);
    for (const r of rows) out.push(`- ${r.san}: ${r.score}, profundidad ${r.depth}. Sigue: ${r.continuation}`);
  }
  out.push('', `Tablero: ${lichessAnalysisUrl(pt.fen)}`);
  if (levelLabel) out.push(`Mi nivel: ${levelLabel}.`);
  out.push(
    '',
    `Mi pregunta: ${question?.trim() || defaultQuestion(exp)}`,
    '',
    'Usa solo jugadas legales en esta posición, apóyate en el análisis del motor y, si no estás seguro de algo, dilo.',
  );
  return out.join('\n');
}
