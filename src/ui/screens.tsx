/**
 * Pantallas sin tablero: bienvenida, experiencia, resultado del test, inicio, perfil, ajustes y datos del estudio.
 */
import { useMemo, useState, type JSX } from 'react';
import type { AnimMode, BoardMode } from '../core/experiment';
import { summarizeH1, summarizeH2, summarizeH3, trialsToCsv } from '../core/experiment';
import { levelBand, insights, measurableRange, themeStats, type Experience } from '../core/training';
import { THEMES, themeName } from '../core/themes';
import { PACK, POOL } from '../app/data';
import { beginPlacement, trainingCount } from '../app/session';
import { go, log, resetAll, setState, useAppState } from '../app/store';
import { BOARD_3D_READY } from './boardTypes';

const pct = (x: number) => (Number.isFinite(x) ? `${Math.round(x * 100)} %` : '—');
const num = (x: number, d = 0) => (Number.isFinite(x) ? x.toFixed(d).replace('.', ',') : '—');

export function Welcome(): JSX.Element {
  return (
    <section className="cm-hero">
      <h1>Entiende cada error, no solo la solución.</h1>
      <p>
        Chessome te pone problemas reales de ajedrez y, cuando fallas, te explica qué tenía de buena tu jugada, qué permitía al rival y qué
        conseguía la mejor. Cada frase sale del análisis de un motor o de las reglas del juego.
      </p>
      <button className="cm-primary cm-big" onClick={() => go('experience')}>
        Empezar
      </button>
      <p className="cm-quiet cm-small">
        Prototipo de investigación. Sin registro: tu progreso y tus respuestas se guardan solo en este navegador. Problemas de la base abierta de
        Lichess (CC0), analizados con {PACK.engine.name}.
      </p>
    </section>
  );
}

const EXPERIENCE: { key: Experience; title: string; text: string }[] = [
  { key: 'never', title: 'Nunca he jugado', text: 'No sé cómo se mueven las piezas.' },
  { key: 'rules', title: 'Sé mover las piezas', text: 'Conozco las reglas, pero apenas he jugado.' },
  { key: 'casual', title: 'Juego de vez en cuando', text: 'Con amigos o alguna partida en línea.' },
  { key: 'regular', title: 'Juego a menudo', text: 'Partidas en línea o en club con frecuencia.' },
];

export function ExperienceScreen(): JSX.Element {
  const [never, setNever] = useState(false);
  if (never) {
    return (
      <section className="cm-card">
        <h2>El curso de reglas llegará en la versión 2</h2>
        <p>
          Este prototipo empieza en los problemas, así que necesitas saber cómo se mueve cada pieza. Si quieres, puedes probar igualmente: el
          test empezará por los problemas más sencillos de la muestra.
        </p>
        <div className="cm-row">
          <button className="cm-primary" onClick={() => beginPlacement('never')}>
            Probar igualmente
          </button>
          <button className="cm-link" onClick={() => setNever(false)}>
            Volver
          </button>
        </div>
      </section>
    );
  }
  return (
    <section className="cm-card">
      <h2>¿Cuánto juegas?</h2>
      <p className="cm-quiet">Solo sirve para elegir el primer problema del test. El test decide tu nivel.</p>
      <div className="cm-choices">
        {EXPERIENCE.map((e) => (
          <button key={e.key} className="cm-choice" onClick={() => (e.key === 'never' ? setNever(true) : beginPlacement(e.key))}>
            <strong>{e.title}</strong>
            <span>{e.text}</span>
          </button>
        ))}
      </div>
      <p className="cm-quiet cm-small">El test tiene entre 8 y 12 problemas y dura unos 5 minutos. Durante el test solo verás si aciertas y la solución.</p>
    </section>
  );
}

export function PlacementResult(): JSX.Element {
  const s = useAppState();
  const r = s.placement?.rating ?? s.rating;
  const range = useMemo(() => measurableRange(POOL), []);
  if (!r) return <p className="cm-empty">Sin resultado.</p>;
  const band = levelBand(r.r);
  const lo = Math.round(r.r - r.rd);
  const hi = Math.round(r.r + r.rd);
  const atts = s.placement?.attempts ?? [];
  const ok = atts.filter((a) => a.correct).length;
  const edge = r.r < range.min + 50 ? 'low' : r.r > range.max - 50 ? 'high' : null;
  return (
    <section className="cm-card">
      <p className="cm-kicker">Tu nivel de partida</p>
      <h2>{band.name}</h2>
      <p className="cm-rating">
        {Math.round(r.r)} <span className="cm-quiet">· rango probable {lo}–{hi}</span>
      </p>
      <p>{band.blurb}</p>
      <p className="cm-quiet">
        Has acertado {ok} de {atts.length}. La cifra usa la escala de los problemas de Lichess; no es un Elo FIDE.
      </p>
      {edge && (
        <p className="cm-warn">
          {edge === 'high'
            ? 'Estás cerca del techo de la muestra de desarrollo: tu nivel real puede ser más alto.'
            : 'Estás cerca del suelo de la muestra de desarrollo: tu nivel real puede ser más bajo.'}
        </p>
      )}
      <div className="cm-callout">
        <strong>Cómo funciona el estudio.</strong> En la mitad de los temas verás explicaciones completas y en la otra mitad solo la solución, como en
        otras apps. Así podremos comparar qué enseña más.{BOARD_3D_READY ? ' Cada 10 problemas alternamos el tablero 2D y el 3D.' : ''}
      </div>
      <button className="cm-primary cm-big" onClick={() => go('train')}>
        Empezar a entrenar
      </button>
    </section>
  );
}

export function Home(): JSX.Element {
  const s = useAppState();
  const tips = insights(s.trials);
  const done = trainingCount();
  return (
    <section className="cm-card">
      <p className="cm-kicker">Hoy</p>
      {s.rating && (
        <p className="cm-rating">
          {Math.round(s.rating.r)} <span className="cm-quiet">· {levelBand(s.rating.r).name}</span>
        </p>
      )}
      <button className="cm-primary cm-big" onClick={() => go('train')}>
        {done > 0 ? 'Seguir entrenando' : 'Entrenar'}
      </button>
      {tips.length > 0 && (
        <ul className="cm-insights">
          {tips.map((t) => (
            <li key={t.theme} className={`cm-insight cm-${t.kind}`}>
              {t.text}
            </li>
          ))}
        </ul>
      )}
      {tips.length === 0 && <p className="cm-quiet">El entrenador comentará tus puntos fuertes y débiles cuando tenga al menos 5 intentos por tema.</p>}
    </section>
  );
}

export function Profile(): JSX.Element {
  const s = useAppState();
  const training = s.trials.filter((t) => t.phase !== 'placement');
  const stats = themeStats(s.trials).filter((t) => THEMES[t.theme]);
  const acc = training.length ? training.filter((t) => t.correct).length / training.length : NaN;
  return (
    <section className="cm-card">
      <h2>Tu progreso</h2>
      {s.rating ? (
        <p className="cm-rating">
          {Math.round(s.rating.r)} <span className="cm-quiet">· rango probable {Math.round(s.rating.r - s.rating.rd)}–{Math.round(s.rating.r + s.rating.rd)}</span>
        </p>
      ) : (
        <p>Aún no has hecho el test.</p>
      )}
      <p className="cm-quiet">
        {training.length} problemas de entrenamiento · acierto {pct(acc)}
      </p>
      <h3>Conceptos</h3>
      {stats.length === 0 && <p className="cm-quiet">Todavía no hay datos.</p>}
      {stats.length > 0 && (
        <table className="cm-table">
          <thead>
            <tr>
              <th>Tema</th>
              <th>Intentos</th>
              <th>Aciertos</th>
              <th>Previstos</th>
              <th>Estado</th>
            </tr>
          </thead>
          <tbody>
            {[...stats]
              .sort((a, b) => b.n - a.n)
              .map((t) => {
                const state = t.n >= 15 && t.correct >= t.expected ? 'Dominado' : t.n >= 1 ? 'En práctica' : 'Sin ver';
                return (
                  <tr key={t.theme}>
                    <td>{themeName(t.theme)}</td>
                    <td>{t.n}</td>
                    <td>{t.correct}</td>
                    <td>{num(t.expected, 1)}</td>
                    <td>{state}</td>
                  </tr>
                );
              })}
          </tbody>
        </table>
      )}
      <p className="cm-quiet cm-small">«Previstos» son los aciertos que tu nivel predice para esos problemas. Un tema queda dominado con 15 intentos o más y al menos tantos aciertos como los previstos.</p>
    </section>
  );
}

const ANIM_LABEL: Record<AnimMode, string> = { full: 'Completas', fast: 'Rápidas', minimal: 'Mínimas', none: 'Sin animaciones' };

export function SettingsScreen(): JSX.Element {
  const s = useAppState();
  const set = (key: string, value: string | boolean, patch: Partial<typeof s.settings>) => {
    setState({ settings: { ...s.settings, ...patch } });
    log({ type: 'setting', data: { key, value } });
  };
  return (
    <section className="cm-card">
      <h2>Ajustes</h2>
      <fieldset>
        <legend>Tablero</legend>
        <div className="cm-options">
          {(['2d', '3d'] as BoardMode[]).map((b) => (
            <button
              key={b}
              disabled={b === '3d' && !BOARD_3D_READY}
              className={s.settings.board === b ? 'cm-chip cm-chip-on' : 'cm-chip'}
              onClick={() => set('board', b, { board: b, studyAlternateBoard: false })}
            >
              {b === '2d' ? '2D' : BOARD_3D_READY ? '3D' : '3D (en construcción)'}
            </button>
          ))}
        </div>
        {BOARD_3D_READY && (
          <label className="cm-check">
            <input type="checkbox" checked={s.settings.studyAlternateBoard} onChange={(e) => set('studyAlternateBoard', e.target.checked, { studyAlternateBoard: e.target.checked })} />
            Alternar 2D y 3D cada 10 problemas (ayuda al estudio)
          </label>
        )}
      </fieldset>
      <fieldset>
        <legend>Animaciones</legend>
        <div className="cm-options">
          {(['full', 'fast', 'minimal', 'none'] as AnimMode[]).map((a) => (
            <button key={a} className={s.settings.anim === a ? 'cm-chip cm-chip-on' : 'cm-chip'} onClick={() => set('anim', a, { anim: a })}>
              {ANIM_LABEL[a]}
            </button>
          ))}
        </div>
      </fieldset>
      <label className="cm-check">
        <input type="checkbox" checked={s.settings.coordinates} onChange={(e) => set('coordinates', e.target.checked, { coordinates: e.target.checked })} />
        Mostrar coordenadas
      </label>
    </section>
  );
}

export function StudyScreen(): JSX.Element {
  const s = useAppState();
  const h1 = summarizeH1(s.trials);
  const h2 = summarizeH2(s.trials);
  const h3 = summarizeH3(s.trials, s.events);
  const [copied, setCopied] = useState<string | null>(null);
  const [confirm, setConfirm] = useState(false);
  const surveys = s.events.filter((e) => e.type === 'survey');

  const copy = async (label: string, text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(label);
    } catch {
      setCopied('error');
    }
  };

  return (
    <section className="cm-card">
      <h2>Datos del estudio</h2>
      <p className="cm-quiet">Todo se calcula con los datos de este navegador. Con un solo usuario las cifras son orientativas: el estudio necesita varias decenas.</p>

      <h3>H1 · ¿Explicar enseña más?</h3>
      <p className="cm-quiet cm-small">Intentos en temas donde ya habías recibido feedback. Residuo = acierto real menos el previsto por tu nivel.</p>
      <table className="cm-table">
        <thead>
          <tr>
            <th>Condición</th>
            <th>Intentos</th>
            <th>Acierto</th>
            <th>Residuo</th>
            <th>Repasos</th>
            <th>Acierto en repaso</th>
            <th>Tiempo en el feedback</th>
          </tr>
        </thead>
        <tbody>
          {(['explained', 'plain'] as const).map((f) => (
            <tr key={f}>
              <td>{f === 'explained' ? 'Con explicación' : 'Solo resultado'}</td>
              <td>{h1.byFeedback[f].n}</td>
              <td>{pct(h1.byFeedback[f].accuracy)}</td>
              <td>{num(h1.byFeedback[f].residual, 2)}</td>
              <td>{h1.reviews[f].n}</td>
              <td>{pct(h1.reviews[f].accuracy)}</td>
              <td>{Number.isFinite(h1.byFeedback[f].medianFeedbackMs) ? `${num(h1.byFeedback[f].medianFeedbackMs / 1000, 1)} s` : '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <h3>H2 · ¿El test acierta con la dificultad?</h3>
      <p>
        Primeros {h2.n} problemas tras el test: acierto {pct(h2.observed)} frente a {pct(h2.predicted)} previsto y {pct(h2.target)} objetivo. Error de
        predicción (Brier): {num(h2.brier, 3)}. {h2.n >= 10 ? (h2.withinBand ? 'Dentro de ±10 puntos del objetivo.' : 'Fuera de ±10 puntos del objetivo.') : ''}
      </p>

      <h3>H3 · ¿El 3D estorba?</h3>
      <table className="cm-table">
        <thead>
          <tr>
            <th>Tablero</th>
            <th>Problemas</th>
            <th>Mediana hasta 1.ª jugada</th>
            <th>Toques corregidos</th>
            <th>Residuo de acierto</th>
          </tr>
        </thead>
        <tbody>
          {(['2d', '3d'] as const).map((b) => (
            <tr key={b}>
              <td>{b.toUpperCase()}</td>
              <td>{h3.byBoard[b].n}</td>
              <td>{Number.isFinite(h3.byBoard[b].medianFirstMoveMs) ? `${num(h3.byBoard[b].medianFirstMoveMs / 1000, 1)} s` : '—'}</td>
              <td>{num(h3.byBoard[b].misTapsPerPuzzle, 2)}</td>
              <td>{num(h3.byBoard[b].accuracyResidual, 2)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="cm-quiet cm-small">
        Animaciones saltadas: {h3.animSkips} · cambios de ajustes: {h3.settingChanges} · respuestas de encuesta: {surveys.length}
      </p>

      <h3>Exportar</h3>
      <div className="cm-row">
        <button className="cm-chip" onClick={() => copy('intentos', trialsToCsv(s.trials))}>
          Copiar intentos (CSV)
        </button>
        <button className="cm-chip" onClick={() => copy('eventos', JSON.stringify(s.events))}>
          Copiar eventos (JSON)
        </button>
      </div>
      {copied && <p className="cm-quiet">{copied === 'error' ? 'No se pudo copiar en este navegador.' : `Copiados los ${copied}.`}</p>}

      <h3>Borrar</h3>
      {!confirm ? (
        <button className="cm-link cm-danger" onClick={() => setConfirm(true)}>
          Borrar todos mis datos y empezar de nuevo
        </button>
      ) : (
        <div className="cm-row">
          <span>¿Seguro? No se puede deshacer.</span>
          <button className="cm-chip cm-danger" onClick={resetAll}>
            Sí, borrar
          </button>
          <button className="cm-link" onClick={() => setConfirm(false)}>
            Cancelar
          </button>
        </div>
      )}

      <h3>Sobre los datos</h3>
      <p className="cm-quiet cm-small">
        {PACK.label} {POOL.length} problemas · motor {PACK.engine.name}, profundidad {PACK.engine.depthAll} para todas las jugadas y {PACK.engine.depthTop} para
        las tres mejores. Fuente: <a href={PACK.source.origin}>{PACK.source.origin}</a> ({PACK.source.license}).
      </p>
    </section>
  );
}
