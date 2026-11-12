/**
 * Panel de explicación con el botón «¿Por qué?» de profundidad progresiva.
 * Nivel 1: qué ha pasado · Nivel 2: concepto · Nivel 3: variantes jugables · Nivel 4: cifras del motor.
 */
import { useEffect, useRef, useState, type JSX } from 'react';
import type { Arrow, Explanation, Line } from '../core/explain';

export interface BoardOverride {
  fen: string;
  lastMove: { from: string; to: string } | null;
  arrows: Arrow[];
  animate: { from: string; to: string; key: number } | null;
}

const NEXT_LABEL: Record<number, string> = { 1: 'Explícame por qué', 2: 'Ver la variante', 3: 'Ver el análisis' };

interface Props {
  exp: Explanation;
  startLevel: 1 | 2 | 3 | 4;
  /** Posición del punto de decisión (para volver a ella al cerrar una variante). */
  baseFen: string;
  onBoard: (o: BoardOverride | null) => void;
  onLevel: (level: number) => void;
  onLinePlay: () => void;
}

export function ExplanationPanel({ exp, startLevel, baseFen, onBoard, onLevel, onLinePlay }: Props): JSX.Element {
  const [level, setLevel] = useState<number>(startLevel);
  const [active, setActive] = useState<{ line: number; ply: number } | null>(null);

  // Flechas del nivel más profundo abierto que tenga alguna; nunca se mezclan niveles.
  useEffect(() => {
    if (active) return;
    const withArrows = exp.levels.slice(0, Math.min(level, 2)).filter((l) => l.arrows.length > 0);
    const arrows = withArrows.length ? withArrows[withArrows.length - 1].arrows : [];
    onBoard({ fen: baseFen, lastMove: null, arrows: dedupe(arrows), animate: null });
  }, [level, active, exp, baseFen, onBoard]);

  // Las funciones del padre pueden cambiar en cada render: se guardan en una ref para no relanzar efectos.
  const onLevelRef = useRef(onLevel);
  onLevelRef.current = onLevel;
  useEffect(() => {
    onLevelRef.current(level);
  }, [level]);

  const lines = exp.levels[2].lines;

  const showPly = (li: number, ply: number) => {
    const line: Line = lines[li];
    if (ply < 0) {
      setActive({ line: li, ply: -1 });
      onBoard({ fen: line.startFen, lastMove: null, arrows: [], animate: null });
      return;
    }
    const p = line.plies[ply];
    const from = p.uci.slice(0, 2);
    const to = p.uci.slice(2, 4);
    setActive({ line: li, ply });
    onBoard({ fen: p.fenAfter, lastMove: { from, to }, arrows: [], animate: { from, to, key: Date.now() } });
    onLinePlay();
  };

  const closeLine = () => {
    setActive(null);
  };

  const tone = exp.correct ? 'good' : exp.verdict === 'alsoWins' || exp.verdict === 'slower' ? 'mid' : 'bad';

  return (
    <section className={`cm-explain cm-tone-${tone}`} aria-live="polite">
      <h2 className="cm-headline">{exp.headline}</h2>
      {exp.levels.slice(0, level).map((l) => (
        <div key={l.level} className={`cm-level cm-level-${l.level}`}>
          {l.level > 1 && <h3>{l.title}</h3>}
          {l.paragraphs.map((p, i) => (
            <p key={i}>{p}</p>
          ))}
          {l.level === 3 && (
            <div className="cm-lines">
              {lines.map((line, li) => {
                const isActive = active?.line === li;
                return (
                  <div key={li} className={`cm-line cm-line-${line.tone}`}>
                    <div className="cm-line-head">
                      <strong>{line.label}</strong>
                      <span className="cm-line-text">{line.text}</span>
                    </div>
                    <div className="cm-stepper">
                      <button onClick={() => showPly(li, -1)} aria-label="Al principio de la variante">
                        ⏮
                      </button>
                      <button onClick={() => showPly(li, isActive ? Math.max(-1, active!.ply - 1) : -1)} aria-label="Jugada anterior">
                        ◀
                      </button>
                      <button
                        onClick={() => showPly(li, isActive ? Math.min(line.plies.length - 1, active!.ply + 1) : 0)}
                        aria-label="Jugada siguiente"
                      >
                        ▶
                      </button>
                      {isActive && (
                        <>
                          <span className="cm-ply">
                            {active!.ply >= 0 ? `${active!.ply + 1}/${line.plies.length} · ${line.plies[active!.ply].san}` : 'inicio'}
                          </span>
                          <button className="cm-link" onClick={closeLine}>
                            Volver
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
          {l.level === 4 && l.table.length > 0 && (
            <table className="cm-engine">
              <thead>
                <tr>
                  <th></th>
                  <th>Jugada</th>
                  <th>Evaluación</th>
                  <th>Prof.</th>
                  <th>Continuación</th>
                </tr>
              </thead>
              <tbody>
                {l.table.map((r, i) => (
                  <tr key={i}>
                    <td>{r.label}</td>
                    <td>{r.san}</td>
                    <td>{r.score}</td>
                    <td>{r.depth}</td>
                    <td className="cm-cont">{r.continuation}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      ))}
      {level < 4 && (
        <button className="cm-why" onClick={() => setLevel(level + 1)}>
          {NEXT_LABEL[level]}
        </button>
      )}
      {level >= 2 && (
        <details className="cm-facts">
          <summary>¿De dónde sale cada dato?</summary>
          <ul>
            {exp.facts.map((f, i) => (
              <li key={i}>
                <span className={`cm-src cm-src-${f.source}`}>{f.source === 'motor' ? 'Motor' : f.source === 'reglas' ? 'Reglas' : 'Lichess'}</span> {f.text}
              </li>
            ))}
          </ul>
        </details>
      )}
    </section>
  );
}

function dedupe(arrows: Arrow[]): Arrow[] {
  const seen = new Set<string>();
  return arrows.filter((a) => {
    const k = `${a.from}${a.to}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}
