/**
 * Encuesta breve para H1 (utilidad percibida), H2 (dificultad) y H3 (comodidad y preferencia de tablero).
 * Se muestra tras 20 y 40 problemas de entrenamiento. Todas las preguntas se pueden saltar.
 */
import { useState, type JSX } from 'react';
import { getState, log, setState } from '../app/store';

export const SURVEY_AT = [20, 40];

interface Q {
  id: string;
  text: string;
  options: string[];
  when?: () => boolean;
}

const LIKERT = ['1 · Nada', '2', '3', '4', '5 · Mucho'];

const usedBoard = (b: '2d' | '3d') => () => getState().trials.some((t) => t.phase !== 'placement' && t.board === b);
const sawExplanations = () => getState().trials.some((t) => t.phase !== 'placement' && t.feedback === 'explained');

const QUESTIONS: Q[] = [
  { id: 'explain_helps', text: 'Las explicaciones me ayudan a entender por qué fallo.', options: LIKERT, when: sawExplanations },
  { id: 'difficulty', text: 'La dificultad de los problemas es…', options: ['Demasiado fácil', 'Algo fácil', 'Adecuada', 'Algo difícil', 'Demasiado difícil'] },
  { id: 'comfort_2d', text: 'Jugar en el tablero 2D me resulta cómodo.', options: LIKERT, when: usedBoard('2d') },
  { id: 'comfort_3d', text: 'Jugar en el tablero 3D me resulta cómodo.', options: LIKERT, when: usedBoard('3d') },
  { id: 'appeal_3d', text: 'El tablero 3D me resulta atractivo.', options: LIKERT, when: usedBoard('3d') },
  { id: 'prefer', text: '¿Qué tablero prefieres?', options: ['2D', '3D', 'Me da igual'], when: () => usedBoard('2d')() && usedBoard('3d')() },
];

export function Survey({ at, onDone }: { at: number; onDone: () => void }): JSX.Element {
  const qs = QUESTIONS.filter((q) => !q.when || q.when());
  const [answers, setAnswers] = useState<Record<string, number>>({});

  const finish = () => {
    for (const q of qs) {
      if (answers[q.id] !== undefined) {
        log({ type: 'survey', data: { at, question: q.id, answer: answers[q.id] + 1, label: q.options[answers[q.id]] } });
      }
    }
    setState((s) => ({ surveysDone: [...s.surveysDone, at] }));
    onDone();
  };

  return (
    <section className="cm-card cm-survey">
      <h2>Dos minutos para el estudio</h2>
      <p className="cm-quiet">Llevas {at} problemas. Tus respuestas se guardan solo en este navegador.</p>
      {qs.map((q) => (
        <fieldset key={q.id}>
          <legend>{q.text}</legend>
          <div className="cm-options">
            {q.options.map((o, i) => (
              <button key={o} className={answers[q.id] === i ? 'cm-chip cm-chip-on' : 'cm-chip'} onClick={() => setAnswers({ ...answers, [q.id]: i })}>
                {o}
              </button>
            ))}
          </div>
        </fieldset>
      ))}
      <div className="cm-row">
        <button className="cm-primary" onClick={finish}>
          Enviar y seguir
        </button>
        <button className="cm-link" onClick={finish}>
          Saltar
        </button>
      </div>
    </section>
  );
}
