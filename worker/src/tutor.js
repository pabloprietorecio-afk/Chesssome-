// Tutor de A Chess Way (docs/profesor-ia.md): Stockfish dice la verdad y Claude la explica.
//
//   POST /tutor          {fen, uci}                       → valoración de la jugada y dos líneas para enseñar
//   POST /tutor/leccion  {fen, uci, played, best, ...}    → un texto del profesor por cada jugada de esas líneas
//
// Stockfish se consulta en un servicio externo (STOCKFISH_URL; por defecto chess-api.com). Todo lo que se dice de
// una jugada (qué pieza mueve, qué captura, qué ataca) lo calcula aquí chess.js; Claude solo lo cuenta.
import { Chess } from "chess.js";

export const VALUE = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 100 };
const UCI = /^[a-h][1-8][a-h][1-8][qrbn]?$/;
const LINE_MAX = 4;
const PIECE_ES = { p: "peón", n: "caballo", b: "alfil", r: "torre", q: "dama", k: "rey" };
export const LANGUAGES = {
  es: "Español", en: "English", pt: "Português", fr: "Français", de: "Deutsch", it: "Italiano",
  ru: "Русский", hi: "हिन्दी", id: "Bahasa Indonesia", ja: "日本語",
};
// Letras de las piezas en la notación de cada idioma (las mismas que en la app: core/i18n/loc.gd).
const LETTERS = {
  es: { N: "C", B: "A", R: "T", Q: "D", K: "R" }, it: { N: "C", B: "A", R: "T", Q: "D", K: "R" },
  fr: { N: "C", B: "F", R: "T", Q: "D", K: "R" }, pt: { N: "C", B: "B", R: "T", Q: "D", K: "R" },
  de: { N: "S", B: "L", R: "T", Q: "D", K: "K" }, ru: { N: "К", B: "С", R: "Л", Q: "Ф", K: "Кр" },
};
export const localSan = (san, lang) => (LETTERS[lang] ? san.replace(/[NBRQK]/g, (c) => LETTERS[lang][c]) : san);

// Probabilidad de ganar (0–100) a partir de centésimas de peón: la fórmula de Lichess.
export const winPct = (cp) => 50 + 50 * (2 / (1 + Math.exp(-0.00368208 * cp)) - 1);

// Respuesta del servicio de Stockfish, normalizada. Valores desde el punto de vista de las blancas.
export function readEngine(d) {
  if (Array.isArray(d)) d = d.find((x) => x && x.type === "bestmove") || d[d.length - 1];
  if (!d || typeof d !== "object") return null;
  const move = String(d.move || d.lan || `${d.from || ""}${d.to || ""}${d.promotion || ""}`);
  if (!UCI.test(move)) return null;
  let mate = d.mate === null || d.mate === undefined || d.mate === "" ? null : Number(d.mate);
  let cp;
  if (mate !== null && Number.isFinite(mate) && mate !== 0) {
    cp = mate > 0 ? 10000 : -10000;
  } else {
    mate = null;
    cp = Number(d.centipawns);
    if (!Number.isFinite(cp)) cp = Math.round(Number(d.eval) * 100);
    if (!Number.isFinite(cp)) cp = 0;
  }
  let win = Number(d.winChance);
  if (!Number.isFinite(win) || mate !== null) win = winPct(cp);
  const line = Array.isArray(d.continuationArr) ? d.continuationArr.map(String).filter((u) => UCI.test(u)) : [];
  return { move, cp, mate, win, line, depth: Number(d.depth) || 0 };
}

async function askEngine(fen, env, raw) {
  const r = await fetch(env.STOCKFISH_URL || "https://chess-api.com/v1", {
    method: "POST",
    headers: { "content-type": "application/json" },
    // taskId: el servicio empareja cada respuesta con su petición.
    body: JSON.stringify({ fen, depth: Number(env.STOCKFISH_DEPTH || 18), maxThinkingTime: 100, variants: 1, taskId: Math.random().toString(36).slice(2, 11) }),
    signal: AbortSignal.timeout(10000),
  });
  if (!r.ok) throw new Error(`stockfish ${r.status}`);
  const data = await r.json();
  if (raw) raw.push(data);
  const out = readEngine(data);
  if (!out) throw new Error("stockfish sin jugada");
  return out;
}

const play = (chess, uci) => {
  try {
    return chess.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
  } catch {
    return null;
  }
};

// Lo que pasa en el tablero con una jugada (ya hecha en `chess`): qué ataca la pieza movida y quién la ataca.
function facts(chess, mv) {
  const me = mv.color;
  const them = me === "w" ? "b" : "w";
  const attacks = [];
  for (const row of chess.board()) {
    for (const p of row) {
      if (p && p.color === them && chess.attackers(p.square, me).includes(mv.to)) {
        attacks.push({ piece: p.type, square: p.square, defended: chess.attackers(p.square, them).length > 0 });
      }
    }
  }
  const piece = mv.promotion || mv.piece;
  const attackedBy = chess.attackers(mv.to, them).map((sq) => ({ piece: chess.get(sq).type, square: sq }));
  const defenders = chess.attackers(mv.to, me).length;
  return {
    uci: mv.from + mv.to + (mv.promotion || ""), san: mv.san, color: me, piece, from: mv.from, to: mv.to,
    captured: mv.captured || "", promotion: mv.promotion || "", check: chess.inCheck(), mate: chess.isCheckmate(),
    castle: mv.isKingsideCastle?.() || mv.isQueensideCastle?.() || /[kq]/.test(mv.flags), attacks, attackedBy, defenders,
  };
}

// Una línea de jugadas (UCI) desde `fen`: se corta en la primera ilegal. Cada paso lleva sus hechos y la posición
// de antes.
export function buildLine(fen, ucis, max) {
  const chess = new Chess(fen);
  const steps = [];
  for (const uci of ucis.slice(0, max)) {
    const before = chess.fen();
    const prev = new Chess(before);
    const mv = UCI.test(uci) ? play(chess, uci) : null;
    if (!mv) break;
    steps.push({ ...facts(chess, mv), ...solves(prev, chess, mv), fen: before });
    if (chess.isGameOver()) break;
  }
  return steps;
}

// Lo que la jugada resuelve: si para un jaque (y cómo) y qué piezas propias amenazadas pasa a defender o salva.
// Con esto el profesor puede decir lo importante: «para el jaque y a la vez defiende el alfil de c4» (Pablo, 21 nov).
export function solves(prev, after, mv) {
  const me = mv.color;
  const them = me === "w" ? "b" : "w";
  let parries = "";
  if (prev.inCheck()) {
    const kingSq = prev.board().flat().find((p) => p && p.type === "k" && p.color === me).square;
    const checkers = prev.attackers(kingSq, them);
    if (mv.piece === "k") parries = "mueve el rey";
    else if (mv.captured && checkers.includes(mv.to)) parries = "captura la pieza que daba jaque";
    else parries = "se interpone";
  }
  // Piezas propias (no el rey) atacadas por el rival: antes sin defensa, o que la movida defiende ahora.
  const defends = [];
  const saved = [];
  for (const row of after.board()) {
    for (const p of row) {
      if (!p || p.color !== me || p.type === "k" || p.square === mv.to) continue;
      if (!after.attackers(p.square, them).length) {
        if (prev.attackers(p.square, them).length && prev.get(p.square)?.type === p.type) saved.push({ piece: p.type, square: p.square, how: "ya no está atacada" });
        continue;
      }
      const byMoved = after.attackers(p.square, me).includes(mv.to);
      const before = prev.get(p.square)?.type === p.type ? prev.attackers(p.square, me).length : -1;
      if (byMoved) defends.push({ piece: p.type, square: p.square, wasUndefended: before === 0 });
    }
  }
  return { parries, defends, saved };
}

// ¿Entrega material la jugada? La pieza movida (no un peón ni el rey) queda donde el rival la gana: sin defensa, o
// atacada por algo que vale menos. Cuenta lo que capturó al llegar y lo que recuperaría al recapturar.
export function isSacrifice(step) {
  const v = VALUE[step.piece];
  if (step.piece === "p" || step.piece === "k" || step.mate) return false;
  const takers = step.attackedBy.filter((a) => a.piece !== "k" || step.defenders === 0);
  if (!takers.length) return false;
  const cheapest = Math.min(...takers.map((a) => VALUE[a.piece]));
  const got = step.captured ? VALUE[step.captured] : 0;
  const back = step.defenders > 0 ? Math.min(cheapest, 9) : 0;
  if (step.defenders > 0 && cheapest >= v) return false;
  return v - got - back >= 2;
}

const chain = (first, rest) => (rest[0] === first ? rest : [first, ...rest]);

// Flechas de un paso: la jugada (verde si es del alumno y buena, roja si es su error o el castigo del rival) y
// las amenazas de verdad que crea (a algo sin defender o que vale más).
function arrows(step, player, lineKind, index, bad) {
  const mine = step.color === player;
  let tone = "info";
  if (mine) tone = lineKind === "played" && index === 0 && bad ? "bad" : "good";
  else if (lineKind === "played" && (step.captured || step.check)) tone = "bad";
  const out = [{ from: step.from, to: step.to, tone }];
  const threats = step.attacks
    .filter((a) => a.piece !== "k" && (!a.defended || VALUE[a.piece] > VALUE[step.piece]))
    .sort((a, b) => VALUE[b.piece] - VALUE[a.piece])
    .slice(0, 2);
  for (const t of threats) out.push({ from: step.to, to: t.square, tone: mine ? "good" : "bad" });
  return out;
}

const publicLine = (steps, player, kind, bad) =>
  steps.map((s, i) => ({ uci: s.uci, fen: s.fen, arrows: arrows(s, player, kind, i, bad) }));

// Umbrales de chess.com (modelo de puntos esperados): imprecisión 5–10, error 10–20, error grave 20 o más puntos de
// probabilidad de ganar perdidos. Antes, los de Lichess (error grave desde 15): perder un peón en una posición igualada
// salía «error grave» y Pablo lo vio exagerado (21 nov).
export function verdictFor(drop, isBest, allowsMate, missedMate) {
  if (isBest) return "best";
  if (allowsMate || drop >= 20) return "blunder";
  if (drop >= 10 || missedMate) return "mistake";
  if (drop >= 5) return "inaccuracy";
  return "good";
}

// Valoración de una jugada con Stockfish. Lanza Error con `status` si la petición no vale.
export async function judge(input, env, debug) {
  const fen = String(input?.fen ?? "");
  const uci = String(input?.uci ?? "");
  let chess;
  try {
    chess = new Chess(fen);
  } catch {
    throw Object.assign(new Error("posición no válida"), { status: 400 });
  }
  if (!UCI.test(uci)) throw Object.assign(new Error("jugada no válida"), { status: 400 });
  const player = chess.turn();
  const after = new Chess(fen);
  if (!play(after, uci)) throw Object.assign(new Error("jugada ilegal"), { status: 400 });
  const raw = debug ? [] : null;
  // Con Stockfish en el móvil, la app manda sus análisis (engine.A antes de la jugada, engine.B después, con la forma
  // de chess-api.com): aquí solo se preparan las líneas y las flechas. Si no vienen o no valen, se analiza aquí.
  const eng = input?.engine && typeof input.engine === "object" ? input.engine : null;
  const given = (e, at) => {
    const r = eng ? readEngine(e) : null;
    return r && play(new Chess(at), r.move) ? r : null;
  };
  const localA = given(eng?.A, fen);
  const localB = after.isGameOver() ? null : given(eng?.B, after.fen());
  // Una consulta detrás de otra: dos a la vez contra el servicio se quedaban colgadas (21 nov).
  const A = localA || (await askEngine(fen, env, raw));
  const B = after.isGameOver() ? null : localB || (await askEngine(after.fen(), env, raw));
  const fromPhone = Boolean(localA && (localB || after.isGameOver()));
  const mine = (e) => (player === "w" ? e.win : 100 - e.win);
  const iMate = (e) => e && e.mate !== null && e.mate > 0 === (player === "w");
  const theyMate = (e) => e && e.mate !== null && e.mate > 0 !== (player === "w");
  let winBest = mine(A);
  let winPlayed = after.isCheckmate() ? 100 : B ? mine(B) : 50;
  let isBest = uci === A.move || after.isCheckmate();
  let drop = isBest ? 0 : Math.max(0, winBest - winPlayed);
  const allowsMate = theyMate(B) && !theyMate(A);
  const missedMate = iMate(A) && Math.abs(A.mate) <= 3 && !iMate(B) && !after.isCheckmate();
  let verdict = verdictFor(drop, isBest, allowsMate, missedMate);
  // Segunda opinión antes de llamar «error» a una jugada: otro análisis de la posición tras la jugada (con 100 ms, un
  // análisis suelto puede salir corto; al repetir la posición el servicio suele llegar más hondo: 15 → 18). Vale la
  // valoración más favorable al alumno; un mate permitido no se discute. (Se probó `searchmoves` para valorar la jugada
  // desde la misma posición que la mejor, pero chess-api.com lo ignora: devolvía la mejor, 21 nov.)
  // Desde el 22 nov, también para las imprecisiones y cuando el análisis viene del móvil (0,8 s por posición: Ac4
  // salió «imprecisión» y al preguntar, el análisis del servidor daba 1–2 puntos; Pablo: la chapa y la explicación no
  // pueden contradecirse). Con el móvil se repiten aquí las dos posiciones, la de antes y la de después.
  let confirmed = null;
  const doubtful = verdict === "inaccuracy" || verdict === "mistake" || verdict === "blunder";
  if (doubtful && !allowsMate && !after.isGameOver()) {
    try {
      const P = await askEngine(after.fen(), env, raw);
      confirmed = mine(P);
      if (confirmed > winPlayed) winPlayed = confirmed;
      if (fromPhone) {
        const Q = await askEngine(fen, env, raw);
        if (Q.move === uci) isBest = true;
        if (mine(Q) < winBest) winBest = mine(Q);
      }
      drop = isBest ? 0 : Math.max(0, winBest - winPlayed);
      verdict = verdictFor(drop, isBest, allowsMate, missedMate);
    } catch (e) {
      // Sin segunda opinión: vale la primera.
      if (raw) raw.push({ error: String(e?.message || e) });
    }
  }

  // Oportunidad perdida (como «Miss» en chess.com): la jugada no deja al alumno peor que antes de la jugada del
  // rival (`prev`: su probabilidad tras su jugada anterior), pero el rival le había dejado algo mucho mejor. No es un
  // error suyo: no ha estropeado nada, no ha visto el regalo (Pablo, 22 nov: d3 marcada «error grave» cuando el rival
  // acababa de permitir e6+).
  const prev = Number(input?.prev);
  if ((verdict === "mistake" || verdict === "blunder") && !allowsMate && Number.isFinite(prev) && prev >= 0 && prev <= 100 && winPlayed >= prev - 5) {
    verdict = "miss";
  }
  const bad = verdict === "inaccuracy" || verdict === "mistake" || verdict === "blunder" || verdict === "miss";
  // Dos líneas para enseñar, cortas (cuatro jugadas): lo que jugó y cómo sigue, y la mejor. Si Stockfish no dio
  // la continuación de la mejor (con poco tiempo a veces solo da la primera jugada), se le pregunta.
  const playedSteps = buildLine(fen, [uci, ...(B ? chain(B.move, B.line) : [])], LINE_MAX);
  let bestUcis = isBest ? [] : chain(A.move, A.line);
  if (bad && bestUcis.length < 2 && !fromPhone) {
    const next = new Chess(fen);
    if (play(next, A.move) && !next.isGameOver()) {
      try {
        const C = await askEngine(next.fen(), env, raw);
        bestUcis = [A.move, ...chain(C.move, C.line)];
      } catch {
        // Sin continuación: la línea buena se queda en una jugada.
      }
    }
  }
  const bestSteps = buildLine(fen, bestUcis, LINE_MAX);
  // Brillante: la mejor jugada, que entrega una pieza, sin estar ya ganado del todo ni quedar peor.
  if (verdict === "best" && playedSteps.length && isSacrifice(playedSteps[0]) && winPlayed >= 45 && winBest <= 97) {
    verdict = "brilliant";
  }
  const out = {
    verdict, drop: Math.round(drop * 10) / 10, win_best: Math.round(winBest), win_played: Math.round(winPlayed),
    best: A.move, player, depth: A.depth, ...(confirmed !== null ? { second: Math.round(confirmed) } : {}), ...(fromPhone ? { phone: true } : {}),
    lines: {
      played: publicLine(playedSteps, player, "played", bad && verdict !== "miss"),
      best: publicLine(bestSteps, player, "best", bad),
    },
  };
  if (raw) out.raw = raw;
  return out;
}

// ---------------------------------------------------------------- lección de Claude

const SQUARE = /(?<![a-wyz])([a-h][1-8])(?![0-9])/g;

function describeBoard(fen) {
  const chess = new Chess(fen);
  const sides = { w: [], b: [] };
  for (const row of chess.board()) for (const p of row) if (p) sides[p.color].push(`${PIECE_ES[p.type]} ${p.square}`);
  return { text: `Blancas: ${sides.w.join(", ")}.\nNegras: ${sides.b.join(", ")}.`, squares: chess.board().flat().filter(Boolean).map((p) => p.square) };
}

function describeStep(s, i, player, lang) {
  const who = s.color === player ? "ALUMNO" : "RIVAL";
  const bits = [`${i + 1}. [${who}] ${localSan(s.san, lang)}: ${PIECE_ES[s.promotion ? "p" : s.piece]} de ${s.from} a ${s.to}`];
  if (s.parries) bits.push(`PARA EL JAQUE (${s.parries})`);
  if (s.defends?.length) bits.push("la pieza movida DEFIENDE a: " + s.defends.map((d) => `${PIECE_ES[d.piece]} de ${d.square}, que está atacada${d.wasUndefended ? " y antes no tenía defensa" : ""}`).join(", "));
  if (s.saved?.length) bits.push("deja de estar atacada: " + s.saved.map((d) => `${PIECE_ES[d.piece]} de ${d.square}`).join(", "));
  if (s.castle) bits.push("es un enroque");
  if (s.promotion) bits.push(`corona ${PIECE_ES[s.promotion]}`);
  if (s.captured) bits.push(`captura ${PIECE_ES[s.captured]} en ${s.to}`);
  if (s.mate) bits.push("es jaque mate");
  else if (s.check) bits.push("da jaque");
  if (s.attacks.length) bits.push("la pieza movida ataca: " + s.attacks.map((a) => `${PIECE_ES[a.piece]} de ${a.square}${a.defended ? "" : " (sin defensa)"}`).join(", "));
  if (s.attackedBy.length) bits.push(`queda atacada por: ${s.attackedBy.map((a) => `${PIECE_ES[a.piece]} de ${a.square}`).join(", ")}; ${s.defenders ? "está defendida" : "NO está defendida"}`);
  return bits.join("; ") + ".";
}

function material(steps, player) {
  let net = 0;
  for (const s of steps) if (s.captured) net += (s.color === player ? 1 : -1) * VALUE[s.captured];
  if (net === 0) return "material igualado";
  return net > 0 ? `el alumno gana ${net} punto(s) de material` : `el alumno pierde ${-net} punto(s) de material`;
}

const VERDICT_ES = {
  brilliant: "brillante: la mejor jugada, y además entrega una pieza", best: "la mejor jugada", good: "buena",
  inaccuracy: "imprecisión", mistake: "error", blunder: "error grave",
  miss: "oportunidad perdida: su jugada no le deja peor que antes, pero el rival le había dejado una jugada mucho mejor que no vio",
};

export function lessonPrompt(fen, played, best, info) {
  const lang = info.language in LANGUAGES ? info.language : "es";
  const board = describeBoard(fen);
  const player = new Chess(fen).turn();
  const good = !best.length;
  const system = [
    "Eres un profesor de ajedrez sentado junto a tu alumno, delante del tablero de la app A Chess Way.",
    "El alumno acaba de jugar. Vas a enseñarle sobre el tablero, jugada a jugada, qué pasa con su jugada" + (good ? "." : " y qué pasaría con la mejor."),
    "La app mueve las piezas y pinta flechas mientras se lee tu texto: escribe UN texto por cada jugada de cada línea, en el mismo orden.",
    "Habla como un profesor: cercano, de tú, sin regañar. En la línea buena usa el condicional: «Si hubieras jugado…, estarías atacando…».",
    "Reglas estrictas:",
    "- Usa SOLO los hechos que te doy: los ha comprobado Stockfish y un programa. No calcules jugadas ni evalúes por tu cuenta.",
    "- No nombres casillas, piezas ni jugadas que no aparezcan en los datos. Escribe las jugadas exactamente como te las doy.",
    "- Si la valoración es «oportunidad perdida», no digas que su jugada es mala ni que pierde algo: di que no pierde nada, pero que el rival le había dejado una ocasión mucho mejor, y enséñala.",
    "- Cada texto: 1 o 2 frases cortas. Empieza por lo MÁS importante de esa jugada: si para un jaque, si defiende o salva una pieza amenazada, si captura, si deja algo sin defensa. Si hace varias cosas a la vez (p. ej. para el jaque y además defiende una pieza), dilo: es lo que el alumno tiene que aprender.",
    "- No digas lo obvio (de qué casilla sale la pieza) si hay algo más importante que decir.",
    `- Escribe en ${LANGUAGES[lang]}. Sin markdown ni emojis.`,
    "Devuelve SOLO un objeto JSON, sin nada antes ni después, con esta forma:",
    `{"resumen": "1-2 frases con la idea clave", "jugada": [${played.length} textos], "mejor": [${best.length} textos], "consejo": "una frase práctica para la próxima vez"}`,
  ].join("\n");
  const user = [
    `Nivel del alumno: ${info.rating > 0 ? `unos ${info.rating} puntos` : "desconocido, trátalo como principiante"}.`,
    `El alumno juega con ${player === "w" ? "blancas" : "negras"}.`,
    "Posición antes de su jugada:",
    board.text,
    `Valoración de Stockfish para su jugada: ${VERDICT_ES[info.verdict] || "buena"}.` + (info.win_best >= 0 && info.win_played >= 0 && !good ? ` Su probabilidad de ganar pasa de ${info.win_best}% (con la mejor) a ${info.win_played}% (con la suya).` : ""),
    "",
    `LÍNEA «jugada» (lo que jugó y cómo sigue según Stockfish), ${played.length} jugadas. Al final: ${material(played, player)}.`,
    ...played.map((s, i) => describeStep(s, i, player, lang)),
    ...(best.length ? ["", `LÍNEA «mejor» (lo que recomienda Stockfish), ${best.length} jugadas. Al final: ${material(best, player)}.`, ...best.map((s, i) => describeStep(s, i, player, lang))] : []),
  ].join("\n");
  const allowed = new Set(board.squares);
  for (const s of [...played, ...best]) {
    allowed.add(s.from);
    allowed.add(s.to);
  }
  return { system, user, allowed };
}

// Texto válido: ni vacío ni enorme, y sin casillas ajenas a los datos. Si no, "" (la app pone su texto propio).
export function cleanText(text, allowed, max = 420) {
  const t = typeof text === "string" ? text.trim() : "";
  if (t.length < 3 || t.length > max) return "";
  for (const m of t.matchAll(SQUARE)) if (!allowed.has(m[1])) return "";
  return t;
}

export function parseLesson(raw, nPlayed, nBest, allowed) {
  let data = null;
  try {
    const a = raw.indexOf("{");
    const b = raw.lastIndexOf("}");
    data = JSON.parse(raw.slice(a, b + 1));
  } catch {
    return null;
  }
  if (!data || typeof data !== "object") return null;
  const list = (v, n) => Array.from({ length: n }, (_, i) => cleanText(Array.isArray(v) ? v[i] : "", allowed));
  return {
    summary: cleanText(data.resumen, allowed, 500), advice: cleanText(data.consejo, allowed, 300),
    played: list(data.jugada, nPlayed), best: list(data.mejor, nBest),
  };
}

export async function lesson(input, env) {
  const fen = String(input?.fen ?? "");
  try {
    new Chess(fen);
  } catch {
    throw Object.assign(new Error("posición no válida"), { status: 400 });
  }
  const ucis = (v) => (Array.isArray(v) ? v.map(String).filter((u) => UCI.test(u)).slice(0, LINE_MAX) : []);
  const playedUcis = ucis(input?.played);
  const played = buildLine(fen, playedUcis, LINE_MAX);
  const best = buildLine(fen, ucis(input?.best), LINE_MAX);
  if (!played.length || played.length !== playedUcis.length) throw Object.assign(new Error("línea no válida"), { status: 400 });
  const num = (v, lo, hi) => (Number.isFinite(Number(v)) && Number(v) >= lo && Number(v) <= hi ? Math.round(Number(v)) : -1);
  const info = {
    language: String(input?.language ?? "es"), verdict: String(input?.verdict ?? "good"),
    rating: Math.max(0, num(input?.rating, 0, 3500)), win_best: num(input?.win_best, 0, 100), win_played: num(input?.win_played, 0, 100),
  };
  const { system, user, allowed } = lessonPrompt(fen, played, best, info);
  if (!env.ANTHROPIC_API_KEY) throw Object.assign(new Error("falta la clave en el servidor"), { status: 500 });
  const base = { model: env.MODEL_TUTOR || "claude-sonnet-5-5", max_tokens: Number(env.MAX_TOKENS_TUTOR || 1200), system, messages: [{ role: "user", content: user }] };
  const ask = (body) => fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "anthropic-version": "2023-06-01", "x-api-key": env.ANTHROPIC_API_KEY },
    body: JSON.stringify(body),
  });
  let r = await ask({ ...base, thinking: { type: "disabled" } });
  if (r.status === 400) r = await ask({ ...base, max_tokens: base.max_tokens + 2500 });
  if (!r.ok) throw Object.assign(new Error(`api ${r.status}`), { status: 502 });
  const data = await r.json();
  const text = (data.content || []).filter((c) => c.type === "text").map((c) => c.text).join("");
  const out = parseLesson(text, played.length, best.length, allowed);
  if (!out) throw Object.assign(new Error("respuesta sin forma"), { status: 502, detail: { stop_reason: data.stop_reason ?? null, types: (data.content || []).map((c) => c.type) } });
  return out;
}

// ---------------------------------------------------------------- preguntas libres (/tutor/pregunta)
// El alumno pregunta lo que quiera durante la partida («¿por qué no puedo comer en e5?», «¿y si muevo el
// caballo?»). Claude contesta como profesor, pero no calcula: para cualquier jugada o línea pide a Stockfish que la
// analice con la herramienta «analizar». Si quiere enseñar algo en el tablero, devuelve la línea y el servidor la
// comprueba (legal) antes de mandarla a la app.

const HISTORY_MAX = 16;
const TOOL_ROUNDS = 3;

export const ASK_TOOL = {
  name: "analizar",
  description: "Juega en el tablero una o varias jugadas (UCI, p. ej. g1f3) desde una posición de la partida y pide a Stockfish su valoración y cómo seguiría. Úsala SIEMPRE antes de afirmar qué pasa con una jugada.",
  input_schema: {
    type: "object",
    properties: {
      desde: { type: "integer", description: "Número de la posición desde la que jugar (de las que te doy). Si no lo pones: la que el alumno tiene en pantalla." },
      jugadas: { type: "array", items: { type: "string" }, description: "Jugadas en UCI, en orden, de 1 a 4. Vacío: solo valorar la posición." },
    },
    required: ["jugadas"],
  },
};

// Replay de la partida que manda la app: posiciones (FEN) y jugadas, desde `start`.
export function replay(start, moves) {
  const chess = new Chess(start);
  const fens = [chess.fen()];
  const done = [];
  for (const uci of moves.slice(-HISTORY_MAX)) {
    const mv = UCI.test(uci) ? play(chess, uci) : null;
    if (!mv) throw Object.assign(new Error("partida no válida"), { status: 400 });
    done.push({ uci, san: mv.san, color: mv.color });
    fens.push(chess.fen());
  }
  return { fens, done };
}

// Lo que el alumno tiene en pantalla si no es la partida en directo (un paso de la lección, una jugada anterior):
// sus posiciones se añaden detrás de las de la partida, y la última es la que está mirando.
export function addShown(ctx, shown) {
  if (!shown || typeof shown !== "object") return;
  const label = String(shown.label ?? "").slice(0, 200);
  let chess;
  try {
    chess = new Chess(String(shown.start ?? ""));
  } catch {
    return;
  }
  const first = ctx.fens.length;
  ctx.fens.push(chess.fen());
  ctx.shownMoves = [];
  for (const uci of (Array.isArray(shown.moves) ? shown.moves.map(String) : []).slice(0, LINE_MAX + 1)) {
    const mv = UCI.test(uci) ? play(chess, uci) : null;
    if (!mv) break;
    ctx.shownMoves.push({ uci, san: mv.san, color: mv.color });
    ctx.fens.push(chess.fen());
  }
  ctx.shown = { first, last: ctx.fens.length - 1, label };
}

function legalList(fen, lang) {
  return new Chess(fen).moves({ verbose: true }).map((m) => `${localSan(m.san, lang)}=${m.from}${m.to}${m.promotion || ""}`).join(", ");
}

const pctFor = (e, side) => Math.round(side === "w" ? e.win : 100 - e.win);

// Lo que devuelve la herramienta: las jugadas con sus hechos, la valoración y cómo seguiría Stockfish.
export async function runTool(input, ctx, env) {
  const idx = Number.isInteger(input?.desde) ? input.desde : ctx.fens.length - 1;
  if (idx < 0 || idx >= ctx.fens.length) return { text: `Error: «desde» va de 0 a ${ctx.fens.length - 1}.` };
  const where = ctx.shown && idx >= ctx.shown.first ? " (del ejemplo en pantalla)" : "";
  const fen = ctx.fens[idx];
  const ucis = Array.isArray(input?.jugadas) ? input.jugadas.map(String).slice(0, LINE_MAX) : [];
  const steps = buildLine(fen, ucis, LINE_MAX);
  if (steps.length !== ucis.length) {
    const bad = ucis[steps.length];
    const at = new Chess(fen);
    for (const s of steps) play(at, s.uci);
    return { text: `Error: ${bad} no es legal en esa posición. Jugadas legales allí: ${legalList(at.fen(), ctx.lang)}.` };
  }
  const end = new Chess(fen);
  for (const s of steps) play(end, s.uci);
  for (const s of steps) {
    ctx.allowed.add(s.from);
    ctx.allowed.add(s.to);
    for (const a of s.attacks) ctx.allowed.add(a.square);
    for (const a of s.attackedBy) ctx.allowed.add(a.square);
  }
  const lines = [`Desde la posición ${idx}${where}${idx === ctx.fens.length - 1 ? " (la que ve el alumno)" : ""}. ${situation(fen, ctx.player)}`];
  if (steps.length) lines.push(...steps.map((s, i) => describeStep(s, i, ctx.player, ctx.lang)));
  if (end.isCheckmate()) {
    lines.push("La posición final es jaque mate.");
    return { text: lines.join("\n") };
  }
  if (end.isDraw()) {
    lines.push("La posición final es tablas.");
    return { text: lines.join("\n") };
  }
  let E;
  try {
    E = await askEngine(end.fen(), env, null);
  } catch {
    lines.push("Stockfish no ha contestado: no afirmes nada de la valoración.");
    return { text: lines.join("\n") };
  }
  const cont = buildLine(end.fen(), chain(E.move, E.line), LINE_MAX);
  for (const s of cont) {
    ctx.allowed.add(s.from);
    ctx.allowed.add(s.to);
  }
  const mate = E.mate !== null ? ` Hay mate en ${Math.abs(E.mate)} para las ${E.mate > 0 ? "blancas" : "negras"}.` : "";
  lines.push(`Valoración de Stockfish (profundidad ${E.depth}): el alumno tiene un ${pctFor(E, ctx.player)}% de probabilidad de ganar.${mate}`);
  if (cont.length) {
    lines.push(`Cómo seguiría (lo mejor para ambos, según Stockfish) — ${material(cont, ctx.player)}:`);
    lines.push(...cont.map((s, i) => describeStep(s, i, ctx.player, ctx.lang)));
  }
  return { text: lines.join("\n") };
}

function situation(fen, player) {
  const c = new Chess(fen);
  const turn = c.turn();
  const who = turn === player ? "le toca al alumno" : "le toca al rival";
  const check = c.isCheckmate() ? ", y es JAQUE MATE" : c.inCheck() ? `, y el rey de las ${turn === "w" ? "blancas" : "negras"} ESTÁ EN JAQUE` : ", sin jaque";
  return `Mueven las ${turn === "w" ? "blancas" : "negras"} (${who})${check}.`;
}

export function askPrompt(ctx, question, rating, previous = []) {
  const lang = ctx.lang;
  const gameLast = ctx.shown ? ctx.shown.first - 1 : ctx.fens.length - 1;
  // Lo que mira el alumno: el ejemplo en pantalla o, si no hay, la partida en directo.
  const now = ctx.fens[ctx.shown ? ctx.shown.last : gameLast];
  const live = ctx.fens[gameLast];
  for (const sq of describeBoard(live).squares) ctx.allowed.add(sq);
  const board = describeBoard(now);
  for (const sq of board.squares) ctx.allowed.add(sq);
  for (const m of new Chess(now).moves({ verbose: true })) {
    ctx.allowed.add(m.from);
    ctx.allowed.add(m.to);
  }
  for (const d of [...ctx.done, ...(ctx.shownMoves || [])]) {
    ctx.allowed.add(d.uci.slice(0, 2));
    ctx.allowed.add(d.uci.slice(2, 4));
  }
  const system = [
    "Eres el profesor de ajedrez de la app A Chess Way, sentado junto a tu alumno mientras juega contra la app.",
    "El alumno te hace una pregunta (escrita o dictada por voz: puede venir con faltas o con las jugadas mal dichas; el dictado no sabe de ajedrez: «al fin» es «alfil», «peor» puede ser «peón», «reina» es la dama, «ce», «de», «e» son columnas). Contesta como un buen profesor: claro, cercano, de tú, sin regañar, y breve (2 a 4 frases).",
    "Reglas estrictas:",
    "- No calcules jugadas ni valores posiciones de cabeza. Para cualquier jugada o línea de la que vayas a hablar, usa antes la herramienta «analizar» (Stockfish) y basa tu respuesta en lo que devuelve.",
    "- No nombres casillas, piezas ni jugadas que no salgan en los datos o en lo que devuelve la herramienta.",
    "- Si la pregunta no es de ajedrez ni de esta partida, contesta en una frase que solo puedes ayudar con la partida.",
    "- Si con la jugada del alumno el rival tiene algo mejor, dilo. Si la jugada del alumno era buena, explica por qué.",
    "- Nunca le digas qué jugar ahora si no te lo pide; si te pide ayuda para la jugada actual, dale una pista (qué mirar), no la jugada, salvo que la pida expresamente.",
    "- Habla SIEMPRE de la posición que el alumno tiene en pantalla (te la doy abajo). Si está mirando un ejemplo de la lección o una jugada anterior, «esto», «aquí», «el peón», «si como» se refieren a ese ejemplo, no a la partida en directo. No mezcles las dos: si mencionas la partida en directo, dilo claramente.",
    "- No digas que hay jaque, mate o una amenaza si no sale en los datos de esa posición.",
    `- Escribe en ${LANGUAGES[lang]}, con la notación de ajedrez de ese idioma. Sin markdown ni emojis.`,
    "Cuando tengas la respuesta, devuelve SOLO un objeto JSON, sin nada antes ni después:",
    '{"respuesta": "tu texto", "mostrar": {"desde": número de posición, "jugadas": ["uci", ...]} o null}',
    "«mostrar» es una línea de 1 a 4 jugadas (UCI, ya analizadas con la herramienta) que la app enseñará en el tablero, moviendo las piezas y con flechas, mientras el alumno lee. Úsala cuando ayude a ver lo que explicas.",
  ].join("\n");
  const who = (c) => (c === ctx.player ? "ALUMNO" : "RIVAL");
  const hist = ctx.done.map((d, i) => `${i}→${i + 1}: ${who(d.color)} ${localSan(d.san, lang)} (${d.uci})`);
  const lines = [
    `Nivel del alumno: ${rating > 0 ? `unos ${rating} puntos` : "desconocido, trátalo como principiante"}.`,
    `El alumno juega con ${ctx.player === "w" ? "blancas" : "negras"}.`,
    `PARTIDA EN DIRECTO. Últimas jugadas (la posición 0 es la de antes de la primera; la de ahora en la partida es la ${gameLast}):`,
    hist.length ? hist.join("\n") : "(ninguna todavía)",
    `En la partida en directo: ${situation(live, ctx.player)}`,
  ];
  if (ctx.shown) {
    const sh = ctx.shownMoves.map((d, i) => `${ctx.shown.first + i}→${ctx.shown.first + i + 1}: ${who(d.color)} ${localSan(d.san, lang)} (${d.uci})`);
    lines.push(
      "",
      `LO QUE EL ALUMNO TIENE AHORA EN PANTALLA no es la partida en directo: ${ctx.shown.label || "un ejemplo"}.`,
      `Posiciones del ejemplo: de la ${ctx.shown.first} a la ${ctx.shown.last} (la ${ctx.shown.last} es la que ve). Jugadas del ejemplo:`,
      sh.length ? sh.join("\n") : "(ninguna: es esa posición tal cual)",
    );
  }
  lines.push(
    "",
    `Posición que ve el alumno (número ${ctx.shown ? ctx.shown.last : gameLast}): ${situation(now, ctx.player)}`,
    board.text,
    `Jugadas legales en esa posición (notación=UCI): ${legalList(now, lang)}`,
  );
  const j = ctx.judged;
  if (j && typeof j === "object" && UCI.test(String(j.uci)) && VERDICT_ES[j.verdict]) {
    const nums = Number.isFinite(j.win_best) && Number.isFinite(j.win_played) && j.win_best >= 0 ? ` (según ese análisis, su probabilidad de ganar pasó de ${j.win_best}% a ${j.win_played}%)` : "";
    lines.push(
      "",
      `La app marcó la última jugada del alumno (${j.uci}) como «${VERDICT_ES[j.verdict]}», con el análisis de Stockfish${nums}. El alumno ve esa marca y es la valoración de la app: tu respuesta no puede contradecirla.`,
      `Si pregunta por la marca, explícala con esos números (cuánto bajó su probabilidad de ganar) y con lo que hacía mejor la mejor jugada. No digas que no es una ${VERDICT_ES[j.verdict]}, ni que «no es mala jugada», ni que «mirándola con más calma» es otra cosa. Si la herramienta te da cifras algo distintas (cada análisis llega a una profundidad), no las uses para corregir la marca.`,
    );
  }
  const prev = (Array.isArray(previous) ? previous : []).slice(-3);
  if (prev.length) {
    lines.push("", "Lo que ya te ha preguntado en esta partida (por si la pregunta sigue el hilo):");
    for (const p of prev) lines.push(`- Alumno: «${String(p?.q ?? "").slice(0, 300)}» / Tú: «${String(p?.a ?? "").slice(0, 600)}»`);
  }
  lines.push("", `Pregunta del alumno: «${question}»`);
  const user = lines.join("\n");
  return { system, user };
}

export function parseAnswer(raw, ctx) {
  let data = null;
  try {
    data = JSON.parse(raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1));
  } catch {
    return null;
  }
  const answer = cleanText(data?.respuesta, ctx.allowed, 900);
  if (!answer) return null;
  let show = null;
  const m = data?.mostrar;
  if (m && typeof m === "object" && Array.isArray(m.jugadas)) {
    const idx = Number.isInteger(m.desde) ? m.desde : ctx.fens.length - 1;
    if (idx >= 0 && idx < ctx.fens.length) {
      const ucis = m.jugadas.map(String).slice(0, LINE_MAX);
      const steps = buildLine(ctx.fens[idx], ucis, LINE_MAX);
      if (steps.length && steps.length === ucis.length) {
        show = { from: idx, steps: publicLine(steps, ctx.player, "best", false) };
      }
    }
  }
  return { answer, show };
}

export async function answerQuestion(input, env) {
  const question = String(input?.question ?? "").trim().slice(0, 400);
  if (question.length < 2) throw Object.assign(new Error("pregunta vacía"), { status: 400 });
  const moves = Array.isArray(input?.moves) ? input.moves.map(String) : [];
  let ctx;
  try {
    const { fens, done } = replay(String(input?.start ?? ""), moves);
    ctx = { fens, done, lang: String(input?.language ?? "es") in LANGUAGES ? String(input?.language ?? "es") : "es", allowed: new Set() };
  } catch (e) {
    throw Object.assign(new Error(e?.status ? e.message : "posición no válida"), { status: 400 });
  }
  ctx.player = input?.player === "b" ? "b" : "w";
  addShown(ctx, input?.shown);
  ctx.judged = input?.judged;
  const rating = Math.max(0, Math.min(3500, Math.round(Number(input?.rating) || 0)));
  const { system, user } = askPrompt(ctx, question, rating, input?.previous);
  if (!env.ANTHROPIC_API_KEY) throw Object.assign(new Error("falta la clave en el servidor"), { status: 500 });
  const call = (body) => fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "anthropic-version": "2023-06-01", "x-api-key": env.ANTHROPIC_API_KEY },
    body: JSON.stringify(body),
  });
  const messages = [{ role: "user", content: user }];
  const base = { model: env.MODEL_TUTOR || "claude-sonnet-5-5", max_tokens: Number(env.MAX_TOKENS_ASK || 1000), system, tools: [ASK_TOOL] };
  let tools = 0;
  let retried = 0;
  for (let round = 0; round <= TOOL_ROUNDS + 2; round++) {
    // En la última vuelta ya no se ofrece la herramienta: tiene que contestar.
    const body = { ...base, messages, ...(round >= TOOL_ROUNDS ? { tool_choice: { type: "none" } } : {}) };
    let r = await call({ ...body, thinking: { type: "disabled" } });
    if (r.status === 400) r = await call({ ...body, max_tokens: base.max_tokens + 2500 });
    if (!r.ok) throw Object.assign(new Error(`api ${r.status}`), { status: 502 });
    const data = await r.json();
    const content = data.content || [];
    const uses = content.filter((c) => c.type === "tool_use");
    if (!uses.length || round >= TOOL_ROUNDS) {
      const text = content.filter((c) => c.type === "text").map((c) => c.text).join("");
      const out = parseAnswer(text, ctx);
      if (out) return { ...out, tools };
      // Una segunda oportunidad: casillas que no salen en los datos (o sin el JSON). Se le dice cuáles.
      const strange = [...new Set([...text.matchAll(SQUARE)].map((m) => m[1]).filter((sq) => !ctx.allowed.has(sq)))];
      // Dos oportunidades para corregirse; después, error (con el motivo, para el registro).
      if (retried >= 2) throw Object.assign(new Error("respuesta sin forma"), { status: 502, detail: { stop_reason: data.stop_reason ?? null, strange, text: text.slice(0, 300) } });
      retried += 1;
      messages.push({ role: "assistant", content });
      messages.push({ role: "user", content: strange.length
        ? `Tu respuesta nombra casillas que no salen en los datos ni en lo analizado: ${strange.join(", ")}. Analízalas con la herramienta o quítalas, y devuelve el JSON.`
        : "Devuelve la respuesta en el JSON pedido, sin nada más." });
      continue;
    }
    messages.push({ role: "assistant", content });
    const results = [];
    for (const u of uses) {
      tools += 1;
      const res = u.name === ASK_TOOL.name ? await runTool(u.input, ctx, env) : { text: "Herramienta desconocida." };
      results.push({ type: "tool_result", tool_use_id: u.id, content: res.text });
    }
    messages.push({ role: "user", content: results });
  }
  throw Object.assign(new Error("sin respuesta"), { status: 502 });
}
