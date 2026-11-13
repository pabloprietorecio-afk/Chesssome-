/**
 * Experimento del MVP: asignación de condiciones, registro de eventos y métricas de las tres hipótesis.
 *
 *  H1  Explicar enseña más que decir solo "correcto / incorrecto".
 *      Diseño intra-sujeto: cada TEMA se asigna a una condición por usuario. Así el rendimiento
 *      posterior en un tema puede atribuirse al tipo de feedback recibido en ese tema.
 *  H2  El test inicial sitúa al jugador en la dificultad adecuada.
 *      Se compara el acierto observado tras el test con el previsto.
 *  H3  El 3D animado gusta sin estorbar.
 *      Se comparan tiempos y toques corregidos entre tablero 2D y 3D.
 *
 * Todo se guarda en el dispositivo. No hay servidor ni cuentas.
 */
import type { Attempt } from './training';

export type Feedback = 'explained' | 'plain';
export type BoardMode = '2d' | '3d';
export type AnimMode = 'full' | 'fast' | 'minimal' | 'none';

/** Hash determinista de cadena (FNV-1a) para que la asignación sea reproducible. */
export function hash(str: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/**
 * Reparte los temas entre las dos condiciones. Los temas se ordenan por frecuencia y se asignan
 * con el patrón A-B-B-A para que ambas condiciones reciban un número parecido de problemas.
 * La semilla del usuario decide cuál de las dos condiciones es "A".
 */
export function assignThemes(themesByFrequency: string[], userSeed: string): Record<string, Feedback> {
  const first: Feedback = hash(userSeed) % 2 === 0 ? 'explained' : 'plain';
  const second: Feedback = first === 'explained' ? 'plain' : 'explained';
  const out: Record<string, Feedback> = {};
  themesByFrequency.forEach((t, i) => {
    out[t] = i % 4 === 0 || i % 4 === 3 ? first : second;
  });
  return out;
}

// ---------- Registro de eventos ----------

export type EventType =
  | 'cine'
  | 'placement_start'
  | 'placement_done'
  | 'puzzle_shown'
  | 'select'
  | 'deselect'
  | 'illegal_target'
  | 'move'
  | 'why_open'
  | 'line_play'
  /** Ayudas tras el problema: «¿Y si juego…?», Lichess, IA (data.tool). */
  | 'assist'
  | 'anim_skip'
  | 'setting'
  | 'survey'
  | 'session_end';

export interface LogEvent {
  t: number;
  type: EventType;
  puzzleId?: string;
  board?: BoardMode;
  anim?: AnimMode;
  feedback?: Feedback;
  phase?: 'placement' | 'training' | 'review';
  /** Datos propios de cada evento (jugada, ms, nivel abierto, respuesta de encuesta…). */
  data?: Record<string, string | number | boolean>;
}

/** Intento enriquecido con el contexto del experimento. */
export interface TrialRecord extends Attempt {
  phase: 'placement' | 'training' | 'review';
  feedback: Feedback;
  board: BoardMode;
  anim: AnimMode;
  /** Milisegundos desde que se muestra el problema hasta la primera jugada. */
  firstMoveMs: number;
  /** Toques corregidos antes de la primera jugada: deselecciones y destinos ilegales. */
  misTaps: number;
  /** Nivel máximo de "¿Por qué?" abierto (0 = ninguno). */
  whyDepth: number;
  /** Si es un repaso, el feedback que recibió cuando falló. */
  reviewOf?: Feedback;
  /** Milisegundos que el jugador pasa en la pantalla de feedback (para controlar el tiempo de estudio en H1). */
  feedbackMs?: number;
}

// ---------- Métricas ----------

const mean = (xs: number[]): number => (xs.length ? xs.reduce((s, x) => s + x, 0) / xs.length : NaN);
const median = (xs: number[]): number => {
  if (!xs.length) return NaN;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

export interface H1Summary {
  /** Por condición: nº de intentos posteriores a haber recibido feedback en ese tema, acierto y residuo medio. */
  byFeedback: Record<Feedback, { n: number; accuracy: number; residual: number; medianFeedbackMs: number }>;
  /** Repasos de errores: acierto según el feedback recibido al fallar. */
  reviews: Record<Feedback, { n: number; accuracy: number }>;
  /** Diferencia de residuo (explicado − solo resultado). Positivo favorece a explicar. */
  residualGap: number;
}

/**
 * H1. Para cada tema se ignora el PRIMER intento de entrenamiento (aún no ha habido feedback en ese tema)
 * y se mide el resto: acierto real menos acierto previsto por rating. Comparar residuos, y no aciertos,
 * descuenta que una condición haya recibido problemas más fáciles.
 */
export function summarizeH1(trials: TrialRecord[]): H1Summary {
  const seenTheme = new Set<string>();
  const later: TrialRecord[] = [];
  for (const t of trials) {
    if (t.phase !== 'training') continue;
    if (seenTheme.has(t.theme)) later.push(t);
    seenTheme.add(t.theme);
  }
  const agg = (fb: Feedback) => {
    const xs = later.filter((t) => t.feedback === fb);
    const all = trials.filter((t) => t.phase === 'training' && t.feedback === fb && t.feedbackMs !== undefined);
    return {
      n: xs.length,
      accuracy: mean(xs.map((t) => (t.correct ? 1 : 0))),
      residual: mean(xs.map((t) => (t.correct ? 1 : 0) - t.expected)),
      // Tiempo de estudio: si explicar ayuda solo porque se mira más rato, aquí se verá.
      medianFeedbackMs: median(all.map((t) => t.feedbackMs as number)),
    };
  };
  const rev = (fb: Feedback) => {
    const xs = trials.filter((t) => t.phase === 'review' && t.reviewOf === fb);
    return { n: xs.length, accuracy: mean(xs.map((t) => (t.correct ? 1 : 0))) };
  };
  const byFeedback = { explained: agg('explained'), plain: agg('plain') };
  return {
    byFeedback,
    reviews: { explained: rev('explained'), plain: rev('plain') },
    residualGap: byFeedback.explained.residual - byFeedback.plain.residual,
  };
}

export interface H2Summary {
  n: number;
  observed: number;
  predicted: number;
  /** Error cuadrático medio de la predicción (Brier). 0,25 equivale a no saber nada. */
  brier: number;
  target: number;
  withinBand: boolean;
}

/** H2. Acierto en los primeros `window` problemas de entrenamiento frente al previsto y al objetivo. */
export function summarizeH2(trials: TrialRecord[], target = 0.75, window = 20, band = 0.1): H2Summary {
  const xs = trials.filter((t) => t.phase === 'training').slice(0, window);
  const observed = mean(xs.map((t) => (t.correct ? 1 : 0)));
  return {
    n: xs.length,
    observed,
    predicted: mean(xs.map((t) => t.expected)),
    brier: mean(xs.map((t) => ((t.correct ? 1 : 0) - t.expected) ** 2)),
    target,
    withinBand: xs.length > 0 && Math.abs(observed - target) <= band,
  };
}

export interface H3Summary {
  byBoard: Record<BoardMode, { n: number; medianFirstMoveMs: number; misTapsPerPuzzle: number; accuracyResidual: number }>;
  animSkips: number;
  settingChanges: number;
}

/** H3. Mismos indicadores en 2D y en 3D. La encuesta de atractivo se resume aparte. */
export function summarizeH3(trials: TrialRecord[], events: LogEvent[]): H3Summary {
  const agg = (b: BoardMode) => {
    const xs = trials.filter((t) => t.board === b && t.phase !== 'placement');
    return {
      n: xs.length,
      medianFirstMoveMs: median(xs.map((t) => t.firstMoveMs)),
      misTapsPerPuzzle: mean(xs.map((t) => t.misTaps)),
      accuracyResidual: mean(xs.map((t) => (t.correct ? 1 : 0) - t.expected)),
    };
  };
  return {
    byBoard: { '2d': agg('2d'), '3d': agg('3d') },
    animSkips: events.filter((e) => e.type === 'anim_skip').length,
    settingChanges: events.filter((e) => e.type === 'setting').length,
  };
}

/** Exporta los intentos como CSV para analizarlos fuera de la app. */
export function trialsToCsv(trials: TrialRecord[]): string {
  const cols: (keyof TrialRecord)[] = [
    'at', 'phase', 'puzzleId', 'puzzleRating', 'theme', 'correct', 'expected', 'ms', 'firstMoveMs',
    'misTaps', 'feedback', 'board', 'anim', 'whyDepth', 'reviewOf', 'feedbackMs',
  ];
  const rows = trials.map((t) => cols.map((c) => (t[c] === undefined ? '' : String(t[c]))).join(','));
  return [cols.join(','), ...rows].join('\n');
}
