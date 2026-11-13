/**
 * Pantallas de juego: test de nivel y entrenamiento.
 */
import { useCallback, useMemo, useRef, useState, type JSX } from 'react';
import type { Feedback } from '../core/experiment';
import { levelBand, PLACEMENT } from '../core/training';
import type { AnalyzedPuzzle } from '../core/types';
import { currentBoard, feedbackFor, noteFeedbackTime, noteWhy, pickNextTraining, pickPlacement, recordResult, trainingCount } from '../app/session';
import { getState, go, log, useAppState } from '../app/store';
import { PuzzleScreen, type PuzzleResult } from './PuzzleScreen';
import { Survey, SURVEY_AT } from './Survey';

export function PlacementScreen(): JSX.Element {
  const s = useAppState();
  const [puzzle, setPuzzle] = useState<AnalyzedPuzzle | null>(() => pickPlacement());
  const trialIdx = useRef(-1);
  const resultAt = useRef(0);
  const n = s.placement?.attempts.length ?? 0;

  const onResult = useCallback(
    (r: PuzzleResult) => {
      if (!puzzle) return;
      trialIdx.current = recordResult(puzzle, r, { board: s.settings.board, anim: s.settings.anim, feedback: 'plain', phase: 'placement' });
      resultAt.current = performance.now();
    },
    [puzzle, s.settings.board, s.settings.anim],
  );

  if (!puzzle) return <p className="cm-empty">No quedan problemas en la muestra.</p>;

  return (
    <PuzzleScreen
      puzzle={puzzle}
      phase="placement"
      feedback="plain"
      board={s.settings.board}
      anim={s.settings.anim}
      coordinates={s.settings.coordinates}
      startLevel={1}
      header={
        <div className="cm-progress" aria-label={`Problema ${Math.min(n + 1, PLACEMENT.maxItems)} del test`}>
          <span>Test de nivel</span>
          <span className="cm-bar">
            <span style={{ width: `${(Math.min(n, PLACEMENT.maxItems) / PLACEMENT.maxItems) * 100}%` }} />
          </span>
          <span>
            {Math.min(n + (s.placement && !s.placement.done ? 1 : 0), PLACEMENT.maxItems)} / {PLACEMENT.minItems}–{PLACEMENT.maxItems}
          </span>
        </div>
      }
      onResult={onResult}
      onWhy={() => undefined}
      onLinePlay={() => log({ type: 'line_play', puzzleId: puzzle.id, phase: 'placement' })}
      onTap={(k) => log({ type: k === 'illegal' ? 'illegal_target' : k, puzzleId: puzzle.id, phase: 'placement' })}
      onNext={() => {
        noteFeedbackTime(trialIdx.current, performance.now() - resultAt.current);
        const st = getState();
        if (st.placement?.done) {
          go('placementResult');
          return;
        }
        const next = pickPlacement();
        if (next) {
          setPuzzle(next);
          log({ type: 'puzzle_shown', puzzleId: next.id, phase: 'placement', board: s.settings.board });
        } else go('placementResult');
      }}
    />
  );
}

export function TrainScreen(): JSX.Element {
  const s = useAppState();
  const [current, setCurrent] = useState(() => pickNextTraining());
  const [surveyDue, setSurveyDue] = useState<number | null>(null);
  const trialIdx = useRef(-1);
  const resultAt = useRef(0);
  const index = useMemo(() => trainingCount(), [current]); // eslint-disable-line react-hooks/exhaustive-deps
  const board = useMemo(() => currentBoard(), [current]); // eslint-disable-line react-hooks/exhaustive-deps
  const feedback: Feedback = current ? feedbackFor(current.puzzle) : 'explained';
  const startLevel: 1 | 3 = (s.rating?.r ?? 0) >= 1600 ? 3 : 1;
  const previousBoard = useRef(board);
  const switched = previousBoard.current !== board;
  previousBoard.current = board;

  const onResult = useCallback(
    (r: PuzzleResult) => {
      if (!current) return;
      trialIdx.current = recordResult(current.puzzle, r, {
        board,
        anim: s.settings.anim,
        feedback,
        phase: current.phase,
        reviewOf: current.reviewOf,
      });
      resultAt.current = performance.now();
    },
    [current, board, s.settings.anim, feedback],
  );

  if (surveyDue !== null) {
    return (
      <Survey
        at={surveyDue}
        onDone={() => {
          setSurveyDue(null);
          setCurrent(pickNextTraining());
        }}
      />
    );
  }

  if (!current) {
    return (
      <div className="cm-empty">
        <p>Has visto todos los problemas de la muestra de desarrollo.</p>
        <button className="cm-primary" onClick={() => go('study')}>
          Ver los datos del estudio
        </button>
      </div>
    );
  }

  return (
    <PuzzleScreen
      key={`${current.puzzle.id}-${index}`}
      puzzle={current.puzzle}
      phase={current.phase}
      feedback={feedback}
      board={board}
      anim={s.settings.anim}
      coordinates={s.settings.coordinates}
      startLevel={startLevel}
      header={
        <div className="cm-progress">
          <span>{current.phase === 'review' ? 'Repaso de un error' : `Entrenamiento · ${index + 1}`}</span>
          <span className="cm-quiet">
            {s.rating ? `Tu nivel: ${Math.round(s.rating.r)}` : ''}
            {s.settings.studyAlternateBoard && switched && index > 0 ? ` · Ahora, tablero ${board === '3d' ? '3D' : '2D'}` : ''}
          </span>
        </div>
      }
      onResult={onResult}
      onWhy={(level) => {
        noteWhy(trialIdx.current, level);
        if (level > startLevel) log({ type: 'why_open', puzzleId: current.puzzle.id, data: { level }, phase: current.phase, feedback });
      }}
      onLinePlay={() => log({ type: 'line_play', puzzleId: current.puzzle.id, phase: current.phase, feedback })}
      levelLabel={s.rating ? `${levelBand(s.rating.r).name} (${Math.round(s.rating.r)} en Chessome)` : undefined}
      onAssist={(tool, data) => log({ type: 'assist', puzzleId: current.puzzle.id, phase: current.phase, feedback, data: { tool, ...data } })}
      onTap={(k) => log({ type: k === 'illegal' ? 'illegal_target' : k, puzzleId: current.puzzle.id, phase: current.phase, board })}
      onNext={() => {
        noteFeedbackTime(trialIdx.current, performance.now() - resultAt.current);
        const done = trainingCount();
        const st = getState();
        const due = SURVEY_AT.find((n) => done >= n && !st.surveysDone.includes(n));
        if (due !== undefined) {
          setSurveyDue(due);
          return;
        }
        const next = pickNextTraining();
        setCurrent(next);
        if (next) log({ type: 'puzzle_shown', puzzleId: next.puzzle.id, phase: next.phase, board: currentBoard() });
      }}
    />
  );
}

