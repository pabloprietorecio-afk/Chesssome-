/**
 * Partida online: se busca rival automáticamente (el siguiente jugador que entra) y se juega en directo.
 * Todo el emparejamiento y las jugadas viven en src/online; aquí solo está la pantalla.
 */
import { useEffect, useMemo, useState, type JSX } from 'react';
import { FIREBASE } from '../online/config';
import { OnlineMatch, type MatchState } from '../online/match';
import { Rtdb } from '../online/rtdb';
import { useAppState } from '../app/store';
import { BoardView } from './BoardView';
import { FlipClock } from './FlipClock';

function localStore() {
  try {
    const k = '__chessome_test__';
    window.localStorage.setItem(k, '1');
    window.localStorage.removeItem(k);
    return window.localStorage;
  } catch {
    return undefined; // sin almacenamiento: cada visita será un jugador nuevo
  }
}

export function OnlineScreen(): JSX.Element {
  const s = useAppState();
  const match = useMemo(() => new OnlineMatch(new Rtdb(FIREBASE, { store: localStore() })), []);
  const [st, setSt] = useState<MatchState>(match.current);
  const [since, setSince] = useState(() => Date.now());
  const search = () => {
    setSince(Date.now());
    void match.start();
  };

  useEffect(() => {
    const off = match.subscribe(setSt);
    return () => {
      off();
      void match.leave();
    };
  }, [match]);

  const live = st.phase === 'playing' || st.phase === 'ended' ? st : null;
  const anim = useMemo(() => {
    if (!live?.lastMove) return null;
    return { from: live.lastMove.from, to: live.lastMove.to, key: live.moves.length };
  }, [live?.lastMove, live?.moves.length]); // eslint-disable-line react-hooks/exhaustive-deps

  if (st.phase === 'idle' || st.phase === 'error') {
    return (
      <section className="cm-card">
        <h2>Partida online</h2>
        <p>Te emparejamos con el siguiente jugador que entre. Si no hay nadie esperando, abres una partida y esperas a tu rival.</p>
        {st.phase === 'error' && <p className="cm-insight cm-bad">{st.message}</p>}
        <button className="cm-primary cm-big" onClick={search}>
          Buscar rival
        </button>
        <p className="cm-quiet">Sin cuenta: tu jugador es anónimo y se recuerda en este navegador.</p>
      </section>
    );
  }

  if (st.phase === 'searching' || st.phase === 'waiting') {
    return (
      <section className="cm-card cm-online-wait" data-online-phase={st.phase}>
        <h2>Buscando rival</h2>
        <p className="cm-quiet">La partida empieza en cuanto entre otro jugador.</p>
        <FlipClock since={since} />
        <p className="cm-quiet cm-flip-caption">Tiempo de espera</p>
        <button className="cm-primary" onClick={() => void match.leave()}>
          Cancelar
        </button>
      </section>
    );
  }

  const mine = st.turn === st.color;
  const status =
    st.phase === 'ended' && st.end
      ? st.end.kind === 'draw'
        ? st.end.why
        : st.end.winner === st.color
          ? `¡Has ganado! ${st.end.why}`
          : `Has perdido. ${st.end.why}`
      : mine
        ? 'Tu turno'
        : 'Juega tu rival…';
  return (
    <div className="cm-puzzle" data-online-phase={st.phase} data-board-fen={st.fen}>
      <div className="cm-board-wrap">
        <div className="cm-progress">
          <span>Partida online</span>
          <span className="cm-quiet">Juegas con {st.color === 'w' ? 'blancas' : 'negras'}</span>
        </div>
        <div className={`cm-turn cm-turn-${st.turn}`}>{status}</div>
        <BoardView
          mode={s.settings.board}
          fen={st.fen}
          orientation={st.color}
          interactive={st.phase === 'playing' && mine}
          lastMove={st.lastMove}
          animate={anim}
          animMode={s.settings.anim}
          coordinates={s.settings.coordinates}
          onMove={(uci) => void match.play(uci)}
        />
      </div>
      <div className="cm-side">
        <div className="cm-card">
          <p className="cm-quiet">Jugadas: {st.moves.length}</p>
          <button className="cm-primary" onClick={() => void match.leave()}>
            {st.phase === 'ended' ? 'Salir' : 'Rendirse y salir'}
          </button>
        </div>
      </div>
    </div>
  );
}
