/**
 * Reloj de láminas («split-flap») con aspecto iOS: muestra mm:ss desde `since` (ms de Date.now()).
 * Cada cifra es una tarjeta partida; al cambiar, la mitad de arriba cae y la nueva mitad de abajo se asienta.
 */
import { useEffect, useRef, useState, type JSX } from 'react';

function FlipDigit({ value }: { value: string }): JSX.Element {
  const [cur, setCur] = useState(value);
  const [prev, setPrev] = useState(value);
  const [flips, setFlips] = useState(0);
  const last = useRef(value);
  useEffect(() => {
    if (value === last.current) return;
    setPrev(last.current);
    setCur(value);
    setFlips((n) => n + 1);
    last.current = value;
  }, [value]);
  return (
    <span className="cm-flip" aria-hidden="true">
      <span className="cm-flip-half cm-flip-top">
        <span>{cur}</span>
      </span>
      <span className="cm-flip-half cm-flip-bottom">
        <span>{flips ? prev : cur}</span>
      </span>
      {flips > 0 && (
        <>
          <span key={`f${flips}`} className="cm-flip-half cm-flip-top cm-flip-fall">
            <span>{prev}</span>
          </span>
          <span key={`r${flips}`} className="cm-flip-half cm-flip-bottom cm-flip-rise">
            <span>{cur}</span>
          </span>
        </>
      )}
    </span>
  );
}

export function FlipClock({ since }: { since: number }): JSX.Element {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 200);
    return () => clearInterval(t);
  }, []);
  const secs = Math.max(0, Math.floor((now - since) / 1000));
  const m = Math.min(99, Math.floor(secs / 60));
  const s = secs >= 6000 ? 59 : secs % 60;
  const text = `${String(m).padStart(2, '0')}${String(s).padStart(2, '0')}`;
  return (
    <div className="cm-flipclock" role="timer" aria-label={`Tiempo de espera: ${m} min ${s} s`}>
      <FlipDigit value={text[0]} />
      <FlipDigit value={text[1]} />
      <span className="cm-flip-colon" aria-hidden="true" />
      <FlipDigit value={text[2]} />
      <FlipDigit value={text[3]} />
    </div>
  );
}
