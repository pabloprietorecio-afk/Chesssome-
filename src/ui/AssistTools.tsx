/**
 * Ayudas tras resolver un problema: «¿Y si juego…?», «Analizar en Lichess» y «Pregunta a una IA».
 * Solo aparecen fuera del test inicial y en la condición con explicación (ver PuzzleScreen).
 * Los iconos son propios: no se usan logotipos de Lichess ni de Google.
 */
import { useMemo, useState, type JSX } from 'react';
import { aiShareText, defaultQuestion, googleAiModeUrl, lichessAnalysisUrl } from '../core/assist';
import type { Explanation } from '../core/explain';
import type { AnalyzedPuzzle } from '../core/types';

export type AssistTool = 'whatif' | 'whatif_move' | 'whatif_exit' | 'lichess' | 'ai_open' | 'ai_share' | 'ai_copy' | 'ai_google';

interface Props {
  puzzle: AnalyzedPuzzle;
  /** Explicación sobre la que se pregunta: la del intento o la de la jugada probada. */
  exp: Explanation;
  decisionFen: string;
  whatIf: boolean;
  /** La explicación es de una jugada probada en «¿Y si juego…?», no jugada. */
  tried: boolean;
  levelLabel?: string;
  onWhatIf: (on: boolean) => void;
  onAssist: (tool: AssistTool) => void;
}

const IconBranch = (): JSX.Element => (
  <svg viewBox="0 0 24 24" aria-hidden="true" className="cm-ico">
    <path d="M6 3v10a5 5 0 0 0 5 5h3" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    <path d="M6 9h6a5 5 0 0 1 5 5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    <path d="M13 15l4 3-4 3M14 11l3 3 3-3" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const IconBoard = (): JSX.Element => (
  <svg viewBox="0 0 24 24" aria-hidden="true" className="cm-ico">
    <rect x="3" y="3" width="13" height="13" rx="1.5" fill="none" stroke="currentColor" strokeWidth="2" />
    <path d="M3 9.5h13M9.5 3v13" stroke="currentColor" strokeWidth="2" />
    <circle cx="17" cy="17" r="3.2" fill="var(--card)" stroke="currentColor" strokeWidth="2" />
    <path d="M19.4 19.4L22 22" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
  </svg>
);

const IconAsk = (): JSX.Element => (
  <svg viewBox="0 0 24 24" aria-hidden="true" className="cm-ico">
    <path d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v8a2.5 2.5 0 0 1-2.5 2.5H11l-5 4.5V16h0.5A2.5 2.5 0 0 1 4 13.5z" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
    <path d="M9.6 7.6a2.4 2.4 0 1 1 3.3 2.2c-.6.3-.9.7-.9 1.3v.4" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    <circle cx="12" cy="13.6" r="1" fill="currentColor" />
  </svg>
);

export function AssistTools({ puzzle, exp, decisionFen, whatIf, tried, levelLabel, onWhatIf, onAssist }: Props): JSX.Element {
  const [aiOpen, setAiOpen] = useState(false);
  const [question, setQuestion] = useState('');
  const [status, setStatus] = useState<string | null>(null);
  const text = useMemo(() => aiShareText({ puzzle, exp, levelLabel, question, tried }), [puzzle, exp, levelLabel, question, tried]);

  const copy = async (): Promise<boolean> => {
    try {
      await navigator.clipboard.writeText(text);
      setStatus('Copiado. Pégalo en la IA que prefieras.');
      onAssist('ai_copy');
      return true;
    } catch {
      setStatus('No se ha podido copiar automáticamente: selecciona el texto de abajo y cópialo.');
      return false;
    }
  };

  const share = async () => {
    const nav = navigator as Navigator & { share?: (d: { title?: string; text?: string }) => Promise<void> };
    if (typeof nav.share === 'function') {
      try {
        await nav.share({ title: 'Duda de ajedrez', text });
        onAssist('ai_share');
        setStatus(null);
        return;
      } catch (e) {
        // Si el usuario cierra el menú de compartir no hay que hacer nada más.
        if (e instanceof DOMException && e.name === 'AbortError') return;
      }
    }
    await copy();
  };

  return (
    <section className="cm-assist" aria-label="Más ayuda">
      <div className="cm-tools">
        <button className={`cm-tool${whatIf ? ' cm-tool-on' : ''}`} onClick={() => onWhatIf(!whatIf)} aria-pressed={whatIf}>
          <IconBranch />
          <span>{whatIf ? 'Volver a la explicación' : '¿Y si juego…?'}</span>
        </button>
        <a className="cm-tool" href={lichessAnalysisUrl(decisionFen)} target="_blank" rel="noreferrer" onClick={() => onAssist('lichess')}>
          <IconBoard />
          <span>Analizar en Lichess</span>
        </a>
        <button
          className={`cm-tool${aiOpen ? ' cm-tool-on' : ''}`}
          onClick={() => {
            if (!aiOpen) onAssist('ai_open');
            setAiOpen(!aiOpen);
            setStatus(null);
          }}
          aria-expanded={aiOpen}
        >
          <IconAsk />
          <span>Pregunta a una IA</span>
        </button>
      </div>

      {aiOpen && (
        <div className="cm-ai">
          <p className="cm-warn-soft">
            Las IA generales se equivocan a menudo en ajedrez, sobre todo al calcular jugadas. Comprueba en el tablero cualquier jugada que te
            propongan. Les mandamos la posición exacta y el análisis del motor, no una captura, para que partan de datos ciertos.
          </p>
          <label className="cm-ai-q">
            <span>Tu pregunta</span>
            <textarea rows={2} value={question} placeholder={defaultQuestion(exp)} onChange={(e) => setQuestion(e.target.value)} />
          </label>
          <div className="cm-ai-actions">
            <button className="cm-primary" onClick={share}>
              Compartir con una IA
            </button>
            <button className="cm-link" onClick={copy}>
              Copiar texto
            </button>
            <a className="cm-link" href={googleAiModeUrl(text)} target="_blank" rel="noreferrer" onClick={() => onAssist('ai_google')}>
              Abrir en Google (Modo IA)
            </a>
          </div>
          {status && (
            <p className="cm-quiet cm-small" role="status">
              {status}
            </p>
          )}
          <details className="cm-ai-preview">
            <summary>Ver el texto que se enviará</summary>
            <pre>{text}</pre>
          </details>
        </div>
      )}
    </section>
  );
}
