/**
 * Evaluación inicial, perfil del jugador y selección de problemas.
 *
 * Decisiones (ver documento de diseño):
 *  - El test inicial estima UN nivel global con pocos problemas. El perfil por temas se construye después.
 *  - El rating de cada problema es fijo (el de Lichess). Solo se mueve el del jugador.
 *  - El tiempo de respuesta se registra, pero no cambia el rating.
 */
import { expectedScore, ratingForSuccess, update, type Rating } from './glicko2';
import { primaryTheme, THEMES } from './themes';
import type { AnalyzedPuzzle } from './types';

// ---------- Evaluación inicial ----------

export type Experience = 'never' | 'rules' | 'casual' | 'regular';

/** Punto de partida según lo que el jugador dice de sí mismo. La incertidumbre es alta a propósito. */
export const PRIOR: Record<Experience, Rating> = {
  never: { r: 600, rd: 300, vol: 0.06 },
  rules: { r: 850, rd: 300, vol: 0.06 },
  casual: { r: 1150, rd: 300, vol: 0.06 },
  regular: { r: 1500, rd: 300, vol: 0.06 },
};

export const PLACEMENT = {
  minItems: 8,
  maxItems: 12,
  /** Se termina antes si la incertidumbre baja de este valor. */
  targetRd: 115,
};

export interface Attempt {
  puzzleId: string;
  puzzleRating: number;
  theme: string;
  correct: boolean;
  ms: number;
  /** Probabilidad de acierto prevista ANTES del intento. */
  expected: number;
  at: number;
}

export interface PlacementState {
  rating: Rating;
  attempts: Attempt[];
  done: boolean;
}

export const startPlacement = (exp: Experience): PlacementState => ({ rating: { ...PRIOR[exp] }, attempts: [], done: false });

type Rand = () => number;

/**
 * Siguiente problema del test: el más cercano al nivel estimado (máxima información),
 * con un pequeño margen aleatorio y evitando repetir tema principal.
 */
export function nextPlacementPuzzle(state: PlacementState, pool: AnalyzedPuzzle[], rand: Rand = Math.random): AnalyzedPuzzle | null {
  const seen = new Set(state.attempts.map((a) => a.puzzleId));
  const usedThemes = new Map<string, number>();
  for (const a of state.attempts) usedThemes.set(a.theme, (usedThemes.get(a.theme) ?? 0) + 1);
  const target = state.rating.r + (rand() - 0.5) * 80;
  let best: AnalyzedPuzzle | null = null;
  let bestCost = Infinity;
  for (const p of pool) {
    if (seen.has(p.id)) continue;
    // En el test se prefieren problemas cortos: miden lo mismo con menos fatiga.
    const lengthPenalty = Math.max(0, p.points.length - 2) * 40;
    const themePenalty = (usedThemes.get(primaryTheme(p.themes)) ?? 0) * 35;
    const cost = Math.abs(p.rating - target) + lengthPenalty + themePenalty;
    if (cost < bestCost) {
      bestCost = cost;
      best = p;
    }
  }
  return best;
}

export function recordPlacement(state: PlacementState, p: AnalyzedPuzzle, correct: boolean, ms: number): PlacementState {
  const expected = expectedScore(state.rating, { r: p.rating, rd: p.rd });
  const rating = update(state.rating, [{ opponent: { r: p.rating, rd: p.rd }, score: correct ? 1 : 0 }]);
  const attempts = [...state.attempts, { puzzleId: p.id, puzzleRating: p.rating, theme: primaryTheme(p.themes), correct, ms, expected, at: Date.now() }];
  const n = attempts.length;
  const done = n >= PLACEMENT.maxItems || (n >= PLACEMENT.minItems && rating.rd <= PLACEMENT.targetRd);
  return { rating, attempts, done };
}

/** Rango de ratings que la muestra de problemas puede medir con fiabilidad. */
export function measurableRange(pool: AnalyzedPuzzle[]): { min: number; max: number } {
  const sorted = pool.map((p) => p.rating).sort((a, b) => a - b);
  if (sorted.length === 0) return { min: 0, max: 0 };
  // Se descartan las colas: con menos de 5 problemas no se puede medir.
  return { min: sorted[Math.min(4, sorted.length - 1)], max: sorted[Math.max(0, sorted.length - 5)] };
}

export interface LevelBand {
  key: 'beginner' | 'novice' | 'intermediate' | 'advanced' | 'expert';
  name: string;
  blurb: string;
}

/**
 * Tramos de nivel en la escala de problemas de Lichess. NO equivalen a Elo FIDE:
 * no hay una tabla de conversión verificada y la app no debe presentarlos como tal.
 */
export function levelBand(r: number): LevelBand {
  if (r < 1000) return { key: 'beginner', name: 'Principiante', blurb: 'Conoces las reglas. Toca aprender a ver capturas gratis y mates sencillos.' };
  if (r < 1300) return { key: 'novice', name: 'Iniciado', blurb: 'Ves amenazas directas. El siguiente paso son los golpes de dos jugadas.' };
  if (r < 1600) return { key: 'intermediate', name: 'Intermedio', blurb: 'Reconoces los motivos básicos. Falta calcular con precisión variantes más largas.' };
  if (r < 1900) return { key: 'advanced', name: 'Avanzado', blurb: 'Calculas bien. La mejora está en los motivos menos frecuentes y en la defensa.' };
  return { key: 'expert', name: 'Experto', blurb: 'Dominas la táctica habitual. Necesitas problemas largos y posiciones estratégicas.' };
}

// ---------- Perfil ----------

export interface ThemeStat {
  theme: string;
  n: number;
  correct: number;
  expected: number;
  /** (aciertos − previstos) / (n + k): negativo = peor de lo esperable para su nivel. */
  residual: number;
}

/** Estadística por tema con contracción: con pocos intentos el residuo se acerca a cero. */
export function themeStats(attempts: Attempt[], k = 5): ThemeStat[] {
  const map = new Map<string, { n: number; correct: number; expected: number }>();
  for (const a of attempts) {
    const s = map.get(a.theme) ?? { n: 0, correct: 0, expected: 0 };
    s.n++;
    s.correct += a.correct ? 1 : 0;
    s.expected += a.expected;
    map.set(a.theme, s);
  }
  return [...map.entries()]
    .map(([theme, s]) => ({ theme, ...s, residual: (s.correct - s.expected) / (s.n + k) }))
    .sort((x, y) => x.residual - y.residual);
}

export interface Insight {
  kind: 'strength' | 'weakness';
  theme: string;
  text: string;
}

/** Frases del entrenador. Solo habla de temas con datos suficientes para no inventar patrones. */
export function insights(attempts: Attempt[], minN = 5): Insight[] {
  const stats = themeStats(attempts).filter((s) => s.n >= minN && THEMES[s.theme]);
  const out: Insight[] = [];
  const weak = stats.filter((s) => s.residual <= -0.08).slice(0, 2);
  const strong = [...stats].reverse().filter((s) => s.residual >= 0.08).slice(0, 2);
  for (const s of strong) {
    out.push({ kind: 'strength', theme: s.theme, text: `${THEMES[s.theme].name}: aciertas ${s.correct} de ${s.n}, más de lo previsto para tu nivel.` });
  }
  for (const s of weak) {
    out.push({ kind: 'weakness', theme: s.theme, text: `${THEMES[s.theme].name}: aciertas ${s.correct} de ${s.n}, menos de lo previsto para tu nivel.` });
  }
  return out;
}

// ---------- Selección de problemas de entrenamiento ----------

export interface SelectOptions {
  /** Probabilidad de acierto objetivo (decisión de diseño: 0,75). */
  targetSuccess: number;
  /** Peso de los temas flojos: 0 = no se tienen en cuenta. */
  weaknessBoost: number;
  rand?: Rand;
}

export const DEFAULT_SELECT: SelectOptions = { targetSuccess: 0.75, weaknessBoost: 1.5 };

/**
 * Elige el siguiente problema: no visto, cerca de la dificultad objetivo y,
 * a igualdad, de un tema en el que el jugador rinde por debajo de lo previsto.
 */
export function pickTrainingPuzzle(
  rating: Rating,
  attempts: Attempt[],
  pool: AnalyzedPuzzle[],
  opts: SelectOptions = DEFAULT_SELECT,
): AnalyzedPuzzle | null {
  const rand = opts.rand ?? Math.random;
  const seen = new Set(attempts.map((a) => a.puzzleId));
  const target = ratingForSuccess(rating.r, opts.targetSuccess);
  const residual = new Map(themeStats(attempts).map((s) => [s.theme, s.residual]));
  const unseen = pool.filter((p) => !seen.has(p.id));
  if (unseen.length === 0) return null;
  for (const window of [60, 120, 200, 400, 5000]) {
    const cands = unseen.filter((p) => Math.abs(p.rating - target) <= window);
    if (cands.length < Math.min(6, unseen.length)) continue;
    const weights = cands.map((p) => {
      const res = residual.get(primaryTheme(p.themes)) ?? 0;
      return 1 + opts.weaknessBoost * Math.max(0, -res) * 5;
    });
    const total = weights.reduce((s, w) => s + w, 0);
    let x = rand() * total;
    for (let i = 0; i < cands.length; i++) {
      x -= weights[i];
      if (x <= 0) return cands[i];
    }
    return cands[cands.length - 1];
  }
  return unseen[0];
}

/** Aplica un intento de entrenamiento al rating y devuelve el intento registrado. */
export function recordAttempt(rating: Rating, p: AnalyzedPuzzle, correct: boolean, ms: number): { rating: Rating; attempt: Attempt } {
  const expected = expectedScore(rating, { r: p.rating, rd: p.rd });
  return {
    rating: update(rating, [{ opponent: { r: p.rating, rd: p.rd }, score: correct ? 1 : 0 }]),
    attempt: { puzzleId: p.id, puzzleRating: p.rating, theme: primaryTheme(p.themes), correct, ms, expected, at: Date.now() },
  };
}

// ---------- Repaso de errores ----------

export interface ReviewItem {
  puzzleId: string;
  theme: string;
  failedAt: number;
  /** Número de problemas resueltos desde el fallo. */
  since: number;
}

/** Un fallo vuelve a salir tras al menos `gap` problemas y `minMs` de espera: repaso espaciado mínimo. */
export function dueReviews(items: ReviewItem[], now: number, gap = 4, minMs = 10 * 60 * 1000): ReviewItem[] {
  return items.filter((it) => it.since >= gap && now - it.failedAt >= minMs);
}
