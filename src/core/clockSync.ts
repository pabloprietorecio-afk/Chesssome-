/**
 * Estimar en qué segundo de un vídeo se hace cada jugada a partir de los relojes de la partida.
 *
 * Las retransmisiones oficiales guardan el reloj de cada jugador tras cada jugada ([%clk] en el PGN).
 * Con eso se sabe cuánto pensó cada jugada y, sumando, cuánto tiempo real pasó entre dos jugadas.
 * Si el vídeo es continuo (sin cortes), basta con saber el segundo de UNA jugada (el «ancla») para
 * estimar el de todas las demás.
 *
 * Precisión: los relojes tienen resolución de 1 s y la suma de tiempos se telescopa por bando
 * (solo cuentan la primera y la última lectura de cada jugador), así que el error no crece con la
 * distancia al ancla: ±2 s como mucho por redondeo, más lo que tarde el jugador en pulsar el reloj
 * tras soltar la pieza. Si el vídeo tiene cortes, la estimación falla a partir del corte.
 */

export interface Period {
  /** Jugadas de este periodo; null = hasta el final. */
  moves: number | null;
  /** Segundos que se añaden al empezar el periodo (el primero es el tiempo inicial). */
  base: number;
  /** Incremento por jugada en este periodo, en segundos. */
  inc: number;
}

/** «1:07:23» o «7:23» → segundos. */
export function parseClock(s: string): number {
  const parts = s.trim().split(':').map(Number);
  if (parts.length < 2 || parts.length > 3 || parts.some((x) => !Number.isFinite(x) || x < 0)) throw new Error(`Reloj no válido: ${s}`);
  return parts.reduce((acc, x) => acc * 60 + x, 0);
}

/**
 * TimeControl del PGN: periodos separados por «:», cada uno «jugadas/segundos» o «segundos», con «+incremento» opcional.
 * Ejemplo del Mundial 2024: «40/7200:1800+30» = 120 min para 40 jugadas y después 30 min con 30 s por jugada.
 */
export function parseTimeControl(tc: string): Period[] {
  const out = tc.split(':').map((p) => {
    const m = /^(?:(\d+)\/)?(\d+)(?:\+(\d+))?$/.exec(p.trim());
    if (!m) throw new Error(`TimeControl no válido: ${tc}`);
    return { moves: m[1] ? Number(m[1]) : null, base: Number(m[2]), inc: m[3] ? Number(m[3]) : 0 };
  });
  if (out.length === 0) throw new Error(`TimeControl vacío: ${tc}`);
  return out;
}

/** Incremento y bonificación que recibe un jugador al completar su jugada número `moveNo`. */
export function creditAfterMove(periods: Period[], moveNo: number): number {
  let first = 1;
  for (let i = 0; i < periods.length; i++) {
    const p = periods[i];
    const last = p.moves == null ? Infinity : first + p.moves - 1;
    if (moveNo <= last) {
      const bonus = moveNo === last && i + 1 < periods.length ? periods[i + 1].base : 0;
      return p.inc + bonus;
    }
    first = last + 1;
  }
  return 0;
}

export interface ClockData {
  timeControl: string;
  /** Media jugada de la primera lectura (1 = primera jugada de las blancas). */
  firstPly: number;
  /** Reloj de quien acaba de mover, tras cada media jugada, desde firstPly. */
  values: string[];
  source: string;
}

/**
 * Tiempo pensado en cada media jugada: reloj anterior del mismo bando − reloj actual + incremento.
 * Devuelve un mapa media jugada → segundos, solo para las que se pueden calcular.
 */
export function thinkTimes(data: ClockData): Map<number, number> {
  const periods = parseTimeControl(data.timeControl);
  const clk = new Map<number, number>();
  data.values.forEach((v, i) => clk.set(data.firstPly + i, parseClock(v)));
  const out = new Map<number, number>();
  for (const [ply, after] of clk) {
    const before = clk.get(ply - 2);
    if (before == null) continue;
    const moveNo = Math.ceil(ply / 2);
    const t = before - after + creditAfterMove(periods, moveNo);
    if (t < 0) throw new Error(`Tiempo negativo en la media jugada ${ply}: revisa los relojes.`);
    out.set(ply, t);
  }
  return out;
}

/**
 * Momento (segundos, relativo) en que se pulsa el reloj tras cada media jugada.
 * El origen es la primera media jugada cuyo siguiente tiempo de reflexión se conoce.
 */
export function pressTimes(data: ClockData): Map<number, number> {
  const think = thinkTimes(data);
  const plies = [...think.keys()].sort((a, b) => a - b);
  const out = new Map<number, number>();
  if (plies.length === 0) return out;
  let t = 0;
  out.set(plies[0] - 1, 0);
  for (let p = plies[0]; think.has(p); p++) {
    t += think.get(p)!;
    out.set(p, t);
  }
  return out;
}

/** Segundo del vídeo en que se pulsa el reloj tras cada media jugada, dado el ancla. */
export function videoTimes(data: ClockData, anchor: { ply: number; at: number }): Map<number, number> {
  const press = pressTimes(data);
  const base = press.get(anchor.ply);
  if (base == null) throw new Error(`No hay tiempo para la media jugada del ancla (${anchor.ply}).`);
  const out = new Map<number, number>();
  for (const [p, t] of press) out.set(p, Math.round((anchor.at + t - base) * 100) / 100);
  return out;
}

/** Antelación por defecto de la pausa respecto a la pulsación del reloj: la mano empieza a moverse antes. */
export const PAUSE_LEAD = 3;
/** Separación mínima con la jugada anterior, para que esta ya se vea en el vídeo. */
export const AFTER_PREVIOUS = 1;

/**
 * Segundo sugerido para pausar antes de la media jugada `ply`: un poco antes de que se pulse su reloj,
 * pero después de que se haya visto la jugada anterior. Si las dos jugadas están demasiado juntas, null.
 */
export function suggestPause(times: Map<number, number>, ply: number, lead = PAUSE_LEAD): number | null {
  const at = times.get(ply);
  if (at == null) return null;
  const prev = times.get(ply - 1);
  const t = at - lead;
  if (prev != null && t < prev + AFTER_PREVIOUS) {
    const mid = (prev + at) / 2;
    return mid - prev >= 0.5 ? Math.round(mid * 100) / 100 : null;
  }
  return Math.round(t * 100) / 100;
}

/** La pieza se posa un poco antes de pulsar el reloj: el tablero sincronizado cambia este tiempo antes. */
export const BOARD_LEAD = 0.5;
/** Si el clip aún no tiene inicio, empieza este tiempo antes de la primera jugada con reloj. */
export const START_LEAD = 5;

/**
 * Tablero sincronizado estimado con los relojes: posición al empezar el clip y segundo en que aparece
 * cada media jugada siguiente (un poco antes de que se pulse su reloj). Las marcas van seguidas y paran
 * en la primera media jugada sin reloj o pasado el fin del clip.
 */
export function suggestSync(
  times: Map<number, number>,
  o: { start: number | null; end: number | null; minStart: number; maxStart: number },
): { start: number; sync: { startPly: number; marks: { ply: number; at: number }[] } } | null {
  const plies = [...times.keys()].sort((a, b) => a - b);
  if (plies.length === 0) return null;
  const boardAt = (p: number) => Math.round((times.get(p)! - BOARD_LEAD) * 100) / 100;
  const start = o.start ?? Math.max(0, Math.round((boardAt(plies[0]) - START_LEAD) * 100) / 100);
  // Posición al empezar: la última jugada que ya se ve en el inicio del clip.
  const seen = plies.filter((p) => boardAt(p) <= start);
  const startPly = Math.min(o.maxStart, Math.max(o.minStart, seen.length ? seen[seen.length - 1] : plies[0] - 1));
  const marks: { ply: number; at: number }[] = [];
  for (let p = startPly + 1; times.has(p); p++) {
    const at = Math.max(boardAt(p), start);
    if (o.end != null && at > o.end) break;
    marks.push({ ply: p, at });
  }
  return { start, sync: { startPly, marks } };
}
