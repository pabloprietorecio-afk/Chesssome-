// Profesor IA de A Chess Way (docs/profesor-ia.md).
// POST /profesor  {"facts": {...}}  →  {"content": [{"type": "text", "text": "..."}]}
// La app manda solo los hechos comprobados de un error; el prompt se construye aquí, así nadie puede usar este
// servidor (ni la clave) para pedirle a Claude otra cosa que explicar un error de ajedrez.

export const KINDS = {
  missed_mate: "tenía jaque mate en una jugada y no lo dio",
  allowed_mate: "su jugada permite al rival dar jaque mate en una",
  hang: "su jugada deja material a tiro: el rival puede capturar y ganarlo",
  missed_capture: "podía capturar una pieza mal defendida y ganar material, y no lo hizo",
};

export const LANGUAGES = {
  es: "Español", en: "English", pt: "Português", fr: "Français", de: "Deutsch", it: "Italiano",
  ru: "Русский", hi: "हिन्दी", id: "Bahasa Indonesia", tr: "Türkçe", ar: "العربية", ja: "日本語", zh: "中文",
};

const FEN = /^[pnbrqkPNBRQK1-8]+(\/[pnbrqkPNBRQK1-8]+){7} [wb] (-|[KQkq]{1,4}) (-|[a-h][36]) \d{1,3} \d{1,4}$/;
const SAN = /^[KQRBNDTACRSPFLa-hO0x1-8=+#-]{1,10}$/u;

// Hechos válidos o null.
export function cleanFacts(f) {
  if (!f || typeof f !== "object") return null;
  const fen = String(f.fen ?? "");
  const kind = String(f.kind ?? "");
  const played = String(f.played ?? "");
  const better = String(f.better ?? "");
  const verified = String(f.verified ?? "");
  const rating = Number(f.rating ?? 0);
  const language = String(f.language ?? "es");
  if (!FEN.test(fen) || !(kind in KINDS)) return null;
  if (!SAN.test(played) || (better !== "" && !SAN.test(better))) return null;
  if (verified.length < 10 || verified.length > 600) return null;
  if (!Number.isFinite(rating) || rating < 0 || rating > 3500) return null;
  return { fen, kind, played, better, verified, rating: Math.round(rating), language: language in LANGUAGES ? language : "es" };
}

export function levelWords(r) {
  if (r <= 0) return "nivel desconocido: trátalo como principiante";
  if (r < 1000) return `principiante (unos ${r} puntos)`;
  if (r < 1500) return `aficionado (unos ${r} puntos)`;
  if (r < 1900) return `jugador de club (unos ${r} puntos)`;
  return `jugador fuerte (unos ${r} puntos)`;
}

// Igual que CoachAI.build_body en la app (godot/core/coach_ai.gd).
export function buildBody(f, model, maxTokens) {
  const system = [
    "Eres el profesor de ajedrez de la app A Chess Way. Tu alumno juega una partida contra la app y acaba de cometer un error.",
    "Tu trabajo es explicárselo como un buen profesor: claro, cercano y breve, sin regañar.",
    "Reglas estrictas:",
    "- Usa SOLO los hechos que te doy. Están comprobados en el tablero. No calcules jugadas ni evalúes la posición por tu cuenta.",
    "- No nombres ninguna casilla ni jugada que no aparezca en los hechos.",
    "- Como mucho 3 frases. Termina con un consejo práctico para la próxima jugada.",
    "- Adapta el vocabulario al nivel del alumno.",
    `- Escribe en ${LANGUAGES[f.language]}, con la notación de ajedrez de ese idioma. Sin markdown, sin listas, sin emojis.`,
  ].join("\n");
  const user = [
    `Nivel del alumno: ${levelWords(f.rating)}.`,
    `Posición antes de su jugada (FEN): ${f.fen}`,
    `Jugada del alumno: ${f.played}`,
    `Qué ha pasado: ${KINDS[f.kind]}.`,
    `Jugada mejor (comprobada): ${f.better || "no indicada"}`,
    `Explicación comprobada (redáctala con tus palabras, sin añadir nada): ${f.verified}`,
  ].join("\n");
  return { model, max_tokens: maxTokens, system, messages: [{ role: "user", content: user }] };
}

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json; charset=utf-8" } });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== "/profesor") return json({ error: "no existe" }, 404);
    if (request.method !== "POST") return json({ error: "solo POST" }, 405);
    if (env.PER_IP) {
      const ip = request.headers.get("cf-connecting-ip") || "?";
      const { success } = await env.PER_IP.limit({ key: ip });
      if (!success) return json({ error: "demasiadas peticiones" }, 429);
    }
    if (Number(request.headers.get("content-length") || 0) > 4000) return json({ error: "demasiado grande" }, 413);
    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "json no válido" }, 400);
    }
    const facts = cleanFacts(body?.facts);
    if (!facts) return json({ error: "hechos no válidos" }, 400);
    if (!env.ANTHROPIC_API_KEY) return json({ error: "falta la clave en el servidor" }, 500);
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "content-type": "application/json", "anthropic-version": "2023-06-01", "x-api-key": env.ANTHROPIC_API_KEY },
      body: JSON.stringify(buildBody(facts, env.MODEL || "claude-haiku-5-5", Number(env.MAX_TOKENS || 220))),
    });
    if (!r.ok) return json({ error: `api ${r.status}` }, 502);
    const data = await r.json();
    const text = (data.content || []).filter((c) => c.type === "text").map((c) => c.text).join("").trim();
    return json({ content: [{ type: "text", text }] });
  },
};
