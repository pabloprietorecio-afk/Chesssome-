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
    body: JSON.stringify({ fen, depth: Number(env.STOCKFISH_DEPTH || 18), maxThinkingTime: 100, variants: 1 }),
    signal: AbortSignal.timeout(8000),
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
    const mv = UCI.test(uci) ? play(chess, uci) : null;
    if (!mv) break;
    steps.push({ ...facts(chess, mv), fen: before });
    if (chess.isGameOver()) break;
  }
  return steps;
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

export function verdictFor(drop, isBest, allowsMate, missedMate) {
  if (isBest) return "best";
  if (allowsMate || drop >= 15) return "blunder";
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
  const [A, B] = await Promise.all([askEngine(fen, env, raw), after.isGameOver() ? null : askEngine(after.fen(), env, raw)]);
  const mine = (e) => (player === "w" ? e.win : 100 - e.win);
  const iMate = (e) => e && e.mate !== null && e.mate > 0 === (player === "w");
  const theyMate = (e) => e && e.mate !== null && e.mate > 0 !== (player === "w");
  const winBest = mine(A);
  const winPlayed = after.isCheckmate() ? 100 : B ? mine(B) : 50;
  const isBest = uci === A.move || after.isCheckmate();
  const drop = isBest ? 0 : Math.max(0, winBest - winPlayed);
  const allowsMate = theyMate(B) && !theyMate(A);
  const missedMate = iMate(A) && Math.abs(A.mate) <= 3 && !iMate(B) && !after.isCheckmate();
  let verdict = verdictFor(drop, isBest, allowsMate, missedMate);

  const bad = verdict === "inaccuracy" || verdict === "mistake" || verdict === "blunder";
  const playedSteps = buildLine(fen, [uci, ...(B ? chain(B.move, B.line) : [])], 6);
  const bestSteps = isBest ? [] : buildLine(fen, chain(A.move, A.line), 5);
  // Brillante: la mejor jugada, que entrega una pieza, sin estar ya ganado del todo ni quedar peor.
  if (verdict === "best" && playedSteps.length && isSacrifice(playedSteps[0]) && winPlayed >= 45 && winBest <= 97) {
    verdict = "brilliant";
  }
  const out = {
    verdict, drop: Math.round(drop * 10) / 10, win_best: Math.round(winBest), win_played: Math.round(winPlayed),
    best: A.move, player, depth: A.depth,
    lines: {
      played: publicLine(playedSteps, player, "played", bad),
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
    "- Cada texto: 1 o 2 frases cortas. Di qué hace esa jugada y por qué importa (qué captura, qué ataca, qué deja sin defensa).",
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
  const ucis = (v) => (Array.isArray(v) ? v.map(String).filter((u) => UCI.test(u)).slice(0, 6) : []);
  const playedUcis = ucis(input?.played);
  const played = buildLine(fen, playedUcis, 6);
  const best = buildLine(fen, ucis(input?.best), 5);
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
