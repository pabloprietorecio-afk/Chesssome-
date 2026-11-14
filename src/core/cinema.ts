/**
 * «Cine de finales»: películas generadas por la app a partir de unas jugadas y unos rótulos.
 *
 * Una película no es un vídeo: es una posición inicial, una lista de pasos (rótulos y jugadas)
 * y, en algunas jugadas, una pausa «¿Qué jugarías?». El pipeline (pipeline/build-cine.ts)
 * comprueba cada película con Stockfish y añade el veredicto de todas las jugadas legales en
 * cada pausa, de modo que la app no necesita motor y nunca afirma algo que el motor contradiga.
 *
 * Reglas de redacción (las comprueba el pipeline donde se puede):
 * - Los rótulos los escribimos nosotros. No se copian comentarios de libros ni de bases de datos.
 * - Toda jugada del bando protagonista mantiene el resultado anunciado según el motor.
 * - Las jugadas del rival no pueden ser errores que «regalen» la lección: quedan a poca distancia
 *   de su mejor defensa según el motor.
 */
import { Chess } from 'chess.js';
import type { Color, Score } from './types';
import { sanEs } from './lang';

export type FilmKind = 'technique' | 'study' | 'game';
export type FilmResult = 'win' | 'draw';

export interface FilmPause {
  /** Pregunta que se muestra antes de la jugada. */
  question: string;
  /** Pista opcional, sin dar la jugada. */
  hint?: string;
  /** Por qué la jugada de la película es la buena (texto propio, revisado contra el análisis). */
  why: string;
}

export type FilmStep =
  | { kind: 'title'; text: string }
  | { kind: 'move'; san: string; caption?: string; pause?: FilmPause };

/** Película tal como la escribimos (fuente). */
export interface FilmSource {
  id: string;
  title: string;
  /** Subtítulo de cartel: «Final teórico», «Estudio, 1895»… */
  subtitle: string;
  kind: FilmKind;
  /** Bando que protagoniza la lección y resultado que consigue con buen juego. */
  hero: Color;
  result: FilmResult;
  fen: string;
  orientation: Color;
  /** Origen y situación de derechos, en una frase. */
  credit: string;
  steps: FilmStep[];
}

/** Clasificación de una jugada en una pausa, según el motor y el resultado que se busca. */
export type VerdictClass = 'keeps' | 'spoils' | 'unclear';

export interface MoveVerdict {
  uci: string;
  san: string;
  cls: VerdictClass;
  score: Score;
  /** Mejor respuesta del motor y continuación, en SAN inglesa (se traduce al mostrarla). */
  line: string[];
  /** Cómo acaba la línea del motor, si acaba en algo comprobable sin motor. */
  lineEnd?: 'stalemate' | 'checkmate' | 'insufficient';
}

export interface PausePack {
  /** Índice del paso de tipo 'move' que lleva la pausa. */
  step: number;
  answerUci: string;
  verdicts: MoveVerdict[];
}

export type Certificate =
  | { kind: 'mate'; ply: number; mateIn: number }
  | { kind: 'engine-draw'; depth: number }
  | { kind: 'engine-only'; depth: number };

export interface FilmPacked extends FilmSource {
  pauses: PausePack[];
  certificate: Certificate;
}

export interface CinemaPack {
  version: 1;
  engine: { name: string; depth: number };
  builtAt: string;
  films: FilmPacked[];
}

/** Umbrales de clasificación, en centipeones desde el punto de vista del bando que mueve. */
export const WIN_KEEPS_CP = 300;
export const WIN_SPOILS_CP = 100;
export const DRAW_KEEPS_CP = -60;
export const DRAW_SPOILS_CP = -250;

/** Valor comparable de una evaluación: los mates dominan a cualquier ventaja material. */
export function scoreValue(s: Score): number {
  if ('cp' in s) return s.cp;
  return s.mate > 0 ? 100000 - s.mate : -100000 - s.mate;
}

/** ¿Mantiene la jugada el resultado buscado? `score` es desde el punto de vista de quien mueve. */
export function classify(score: Score, target: FilmResult): VerdictClass {
  if ('mate' in score) return score.mate > 0 ? 'keeps' : 'spoils';
  const cp = score.cp;
  if (target === 'win') return cp >= WIN_KEEPS_CP ? 'keeps' : cp <= WIN_SPOILS_CP ? 'spoils' : 'unclear';
  return cp >= DRAW_KEEPS_CP ? 'keeps' : cp <= DRAW_SPOILS_CP ? 'spoils' : 'unclear';
}

/** Un fotograma de la película: lo que se ve en pantalla en un instante. */
export type Frame =
  | { kind: 'title'; text: string; fen: string; step: number }
  | {
      kind: 'move';
      step: number;
      /** Posición antes y después de la jugada. */
      before: string;
      after: string;
      san: string;
      uci: string;
      from: string;
      to: string;
      captured: boolean;
      /** «1.», «1…», etc. */
      number: string;
      caption?: string;
      pause?: FilmPause;
    };

/** Convierte la fuente en fotogramas. Lanza un error si alguna jugada es ilegal. */
export function frames(film: Pick<FilmSource, 'fen' | 'steps' | 'id'>): Frame[] {
  const chess = new Chess(film.fen);
  const out: Frame[] = [];
  film.steps.forEach((st, i) => {
    if (st.kind === 'title') {
      out.push({ kind: 'title', text: st.text, fen: chess.fen(), step: i });
      return;
    }
    const before = chess.fen();
    const moveNo = Number(before.split(' ')[5]);
    const white = chess.turn() === 'w';
    let m;
    try {
      m = chess.move(st.san);
    } catch {
      throw new Error(`${film.id}: jugada ilegal en el paso ${i}: ${st.san} (${before})`);
    }
    out.push({
      kind: 'move',
      step: i,
      before,
      after: chess.fen(),
      san: m.san,
      uci: m.from + m.to + (m.promotion ?? ''),
      from: m.from,
      to: m.to,
      captured: !!m.captured,
      number: white ? `${moveNo}.` : `${moveNo}…`,
      caption: st.caption,
      pause: st.pause,
    });
  });
  return out;
}

/** Texto de una línea del motor en notación española con números de jugada. */
export function lineText(fen: string, sans: string[]): string {
  const parts: string[] = [];
  const fields = fen.split(' ');
  let n = Number(fields[5]);
  let white = fields[1] === 'w';
  sans.forEach((s, i) => {
    if (white) parts.push(`${n}.${sanEs(s)}`);
    else parts.push(i === 0 ? `${n}…${sanEs(s)}` : sanEs(s));
    if (!white) n++;
    white = !white;
  });
  return parts.join(' ');
}

export interface PauseAnswer {
  outcome: 'answer' | 'also-good' | 'spoils' | 'unclear' | 'unknown';
  /** Texto para el jugador. No inventa: solo usa el veredicto del motor y el texto propio de la película. */
  text: string;
  /** Línea del motor que refuta la jugada, si la hay. */
  line?: string;
}

/**
 * Responde a la jugada del jugador en una pausa.
 * `beforeFen` es la posición de la pausa y `playedUci` la jugada del jugador.
 */
export function judgePause(pause: PausePack, beforeFen: string, playedUci: string, filmPause: FilmPause, target: FilmResult): PauseAnswer {
  const answer = pause.verdicts.find((v) => v.uci === pause.answerUci);
  const answerEs = answer ? sanEs(answer.san) : '';
  if (playedUci === pause.answerUci) return { outcome: 'answer', text: filmPause.why };
  const v = pause.verdicts.find((x) => x.uci === playedUci);
  if (!v) return { outcome: 'unknown', text: `No hay análisis para esa jugada. La película sigue con ${answerEs}.` };
  const mine = sanEs(v.san);
  // La línea del motor empieza por la respuesta del rival a la jugada del jugador.
  const after = new Chess(beforeFen);
  after.move(v.san);
  const line = v.line.length ? lineText(after.fen(), v.line) : undefined;
  if (v.cls === 'keeps') {
    const goal = target === 'win' ? 'también gana' : 'también mantiene las tablas';
    return { outcome: 'also-good', text: `${mine} ${goal}. La película sigue con ${answerEs}, que es la idea del final.`, line };
  }
  if (v.cls === 'spoils') {
    const lost = target === 'win' ? 'deja escapar la victoria' : 'pierde';
    const end =
      v.lineEnd === 'stalemate'
        ? ' La línea acaba en ahogado: tablas.'
        : v.lineEnd === 'checkmate'
          ? ' La línea acaba en mate.'
          : v.lineEnd === 'insufficient'
            ? ' La línea acaba sin material para dar mate: tablas.'
            : '';
    return { outcome: 'spoils', text: `${mine} ${lost}.${end}`, line };
  }
  return { outcome: 'unclear', text: `El motor no da un veredicto claro sobre ${mine}. La película sigue con ${answerEs}.`, line };
}

/** Bando que debe responder en una pausa: el que mueve en esa posición. */
export const turnOf = (fen: string): Color => (fen.split(' ')[1] === 'w' ? 'w' : 'b');

/** Etiqueta honesta de cómo se ha comprobado la película. */
export function certificateText(c: Certificate): string {
  if (c.kind === 'mate') return `Comprobada con Stockfish: mate forzado encontrado.`;
  if (c.kind === 'engine-draw') return `Tablas según Stockfish (profundidad ${c.depth}). No comprobada con tablas de finales.`;
  return `Comprobada con Stockfish (profundidad ${c.depth}), sin prueba de mate.`;
}
