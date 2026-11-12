/**
 * Lógica de sesión que conecta el núcleo con el estado: registra intentos, actualiza el rating,
 * gestiona la cola de repaso y decide qué problema toca.
 */
import type { AnimMode, BoardMode, Feedback, TrialRecord } from '../core/experiment';
import { primaryTheme } from '../core/themes';
import {
  DEFAULT_SELECT,
  dueReviews,
  nextPlacementPuzzle,
  pickTrainingPuzzle,
  recordAttempt,
  recordPlacement,
  startPlacement,
  type Experience,
} from '../core/training';
import type { AnalyzedPuzzle } from '../core/types';
import { BY_ID, POOL } from './data';
import { boardForTrial, getState, log, setState } from './store';
import type { PuzzleResult } from '../ui/PuzzleScreen';

export function beginPlacement(exp: Experience): void {
  setState({ experience: exp, placement: startPlacement(exp), screen: 'placement' });
  log({ type: 'placement_start', data: { experience: exp } });
}

export function pickPlacement(): AnalyzedPuzzle | null {
  const s = getState();
  if (!s.placement) return null;
  return nextPlacementPuzzle(s.placement, POOL);
}

export function trainingCount(): number {
  return getState().trials.filter((t) => t.phase !== 'placement').length;
}

export function feedbackFor(p: AnalyzedPuzzle): Feedback {
  return getState().themeFeedback[primaryTheme(p.themes)] ?? 'explained';
}

export function currentBoard(): BoardMode {
  const s = getState();
  return boardForTrial(s, trainingCount());
}

export interface NextTraining {
  puzzle: AnalyzedPuzzle;
  phase: 'training' | 'review';
  reviewOf?: Feedback;
}

export function pickNextTraining(): NextTraining | null {
  const s = getState();
  if (!s.rating) return null;
  const due = dueReviews(s.reviews, Date.now());
  if (due.length > 0) {
    const item = due[0];
    const puzzle = BY_ID.get(item.puzzleId);
    if (puzzle) {
      const failed = [...s.trials].reverse().find((t) => t.puzzleId === item.puzzleId && !t.correct);
      return { puzzle, phase: 'review', reviewOf: failed?.feedback };
    }
  }
  const puzzle = pickTrainingPuzzle(s.rating, s.trials, POOL, DEFAULT_SELECT);
  return puzzle ? { puzzle, phase: 'training' } : null;
}

interface Ctx {
  board: BoardMode;
  anim: AnimMode;
  feedback: Feedback;
  phase: 'placement' | 'training' | 'review';
  reviewOf?: Feedback;
}

/** Registra el resultado de un problema y devuelve el índice del intento, para completarlo luego. */
export function recordResult(p: AnalyzedPuzzle, r: PuzzleResult, ctx: Ctx): number {
  const s = getState();
  let trial: TrialRecord;
  if (ctx.phase === 'placement' && s.placement) {
    const placement = recordPlacement(s.placement, p, r.correct, r.ms);
    const a = placement.attempts[placement.attempts.length - 1];
    trial = { ...a, phase: 'placement', feedback: ctx.feedback, board: ctx.board, anim: ctx.anim, firstMoveMs: r.firstMoveMs, misTaps: r.misTaps, whyDepth: 0 };
    setState({ placement, rating: placement.rating, trials: [...s.trials, trial] });
    if (placement.done) log({ type: 'placement_done', data: { rating: Math.round(placement.rating.r), rd: Math.round(placement.rating.rd), items: placement.attempts.length } });
  } else {
    const rating = s.rating ?? { r: 1500, rd: 300, vol: 0.06 };
    const { rating: next, attempt } = recordAttempt(rating, p, r.correct, r.ms);
    trial = {
      ...attempt,
      phase: ctx.phase,
      feedback: ctx.feedback,
      board: ctx.board,
      anim: ctx.anim,
      firstMoveMs: r.firstMoveMs,
      misTaps: r.misTaps,
      whyDepth: 0,
      reviewOf: ctx.reviewOf,
    };
    // Cola de repaso: el problema servido sale de la cola; si se falla, vuelve a entrar.
    let reviews = s.reviews.filter((it) => it.puzzleId !== p.id).map((it) => ({ ...it, since: it.since + 1 }));
    if (!r.correct) reviews = [...reviews, { puzzleId: p.id, theme: primaryTheme(p.themes), failedAt: Date.now(), since: 0 }];
    setState({ rating: next, trials: [...s.trials, trial], reviews });
  }
  return getState().trials.length - 1;
}

/** Anota en el intento ya registrado el nivel máximo de «¿Por qué?» abierto. */
export function noteWhy(trialIndex: number, level: number): void {
  setState((s) => {
    const t = s.trials[trialIndex];
    if (!t || level <= t.whyDepth) return {};
    const trials = [...s.trials];
    trials[trialIndex] = { ...t, whyDepth: level };
    return { trials };
  });
}

/** Anota cuánto tiempo pasó el jugador leyendo el feedback. */
export function noteFeedbackTime(trialIndex: number, ms: number): void {
  setState((s) => {
    const t = s.trials[trialIndex];
    if (!t || t.feedbackMs !== undefined) return {};
    const trials = [...s.trials];
    trials[trialIndex] = { ...t, feedbackMs: Math.round(ms) };
    return { trials };
  });
}
