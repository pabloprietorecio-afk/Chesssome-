// Puntos esperados según el nivel (22 nov, Pablo: «lo más parecido posible a chess.com»). chess.com clasifica las
// jugadas por los «puntos esperados» que pierden, y esos puntos salen de la evaluación del motor **y del Elo de quien
// juega** (no publica su curva). Aquí la curva está medida con partidas públicas de Lichess con evaluación
// (tools/curva/): para cada nivel y cada evaluación, cuántos puntos sacó de verdad ese jugador. La misma tabla la usa
// la app (godot/core/coach_ai.gd).
//
// Antes se usaba una sola curva (la de Lichess, ajustada con jugadores de ~2300): a 7 peones por debajo daba un 8 %,
// y regalar un caballo (8 % → 4 %) salía «buena» (Pablo, 22 nov). Un jugador de club con 7 peones menos todavía saca
// bastante más que un 8 %, y perder un caballo le cuesta más de 5 puntos.
import { Chess } from "chess.js";
import curva from "../../godot/data/curva_puntos.json" with { type: "json" };

export const DEFAULT_ELO = 1500;
export const VALUE = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 0 };

export const cleanElo = (v) => {
  const n = Number(v);
  return Number.isFinite(n) && n >= 100 && n <= 3500 ? n : DEFAULT_ELO;
};

function along(xs, x) {
  if (x <= xs[0]) return [0, 0, 0];
  const last = xs.length - 1;
  if (x >= xs[last]) return [last, last, 0];
  let i = 0;
  while (xs[i + 1] < x) i++;
  return [i, i + 1, (x - xs[i]) / (xs[i + 1] - xs[i])];
}

const lerp = (a, b, t) => a + (b - a) * t;

// Puntos esperados (0–100) del jugador con `elo` cuando la evaluación, desde su lado, es `cp` centipeones o mate en
// `mate` (positivo: a su favor). La tabla va por Elo y por evaluación; entre medias, se interpola.
export function expected(cp, mate, elo = DEFAULT_ELO) {
  const [e0, e1, te] = along(curva.elos, cleanElo(elo));
  if (mate !== null && mate !== undefined && Number(mate) !== 0) {
    const row = Number(mate) > 0 ? curva.mate_a_favor : curva.mate_en_contra;
    return 100 * lerp(row[e0], row[e1], te);
  }
  const [c0, c1, tc] = along(curva.cp, Number(cp) || 0);
  const at = (e) => lerp(curva.puntos[e][c0], curva.puntos[e][c1], tc);
  return 100 * lerp(at(e0), at(e1), te);
}

// Evaluación (forma de readEngine: cp y mate desde las blancas) → puntos esperados del jugador `player` («w»/«b»).
export function expectedFor(e, player, elo) {
  const sign = player === "w" ? 1 : -1;
  if (e.mate !== null && e.mate !== undefined) return expected(0, e.mate * sign, elo);
  return expected(e.cp * sign, null, elo);
}

// --- Red de seguridad del material ---

function balance(chess, player) {
  let s = 0;
  for (const row of chess.board()) for (const p of row) if (p) s += (p.color === player ? 1 : -1) * VALUE[p.type];
  return s;
}

// Material del jugador (sus piezas menos las del rival) al final de una línea, sin cortar a mitad de un cambio: el
// de la última posición de la línea en la que la siguiente jugada no es una captura (o la última, si no hay).
export function materialAfter(fen, ucis, player, max = 10) {
  const c = new Chess(fen);
  const plies = [];
  for (const u of ucis.slice(0, max)) {
    let mv = null;
    try {
      mv = c.move({ from: u.slice(0, 2), to: u.slice(2, 4), promotion: u[4] || undefined });
    } catch {
      mv = null;
    }
    if (!mv) break;
    plies.push({ bal: balance(c, player), capture: Boolean(mv.captured) });
  }
  if (!plies.length) return null;
  // Desde la respuesta del rival en adelante (la jugada sola no cuenta: puede ser el principio de un cambio).
  for (let i = plies.length - 1; i >= 1; i--) {
    const nextIsCapture = i + 1 < plies.length && plies[i + 1].capture;
    if (!nextIsCapture) return { bal: plies[i].bal, plies: plies.length };
  }
  return { bal: plies[plies.length - 1].bal, plies: plies.length };
}

// Nota mínima de una jugada que pierde material sin compensación frente a la mejor línea: el motor confirma la
// pérdida (`cpDrop`, centipeones desde el lado del jugador) y la línea jugada acaba con menos material que la mejor.
// Dos peones o más (una pieza menor por un peón, por ejemplo): al menos «error»; torre o dama: «error grave». Así un
// regalo nunca sale «buena», vaya como vaya la partida (Pablo, 22 nov: Ce4 dejaba el caballo por un peón y salió
// «buena»). Con la partida igualada, los puntos esperados ya lo marcan; esto cuenta en las posiciones muy decantadas.
export function materialFloor(lossPawns, cpDrop) {
  if (!(cpDrop >= 150)) return null;
  if (lossPawns >= 5) return "blunder";
  if (lossPawns >= 2) return "mistake";
  return null;
}

const RANK = { best: 0, brilliant: 0, excellent: 1, good: 1, inaccuracy: 2, mistake: 3, blunder: 4 };

// La peor de dos notas (para aplicar el mínimo del material).
export function atLeast(verdict, floor) {
  if (!floor || verdict === "best" || verdict === "brilliant") return verdict;
  return (RANK[floor] ?? 0) > (RANK[verdict] ?? 0) ? floor : verdict;
}
