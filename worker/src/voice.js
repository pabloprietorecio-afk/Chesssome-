// Dictado (/voz): la app manda la grabación (WAV, 16 kHz, mono, en base64) y Whisper la transcribe con el vocabulario
// de ajedrez como contexto, para que «alfil» no salga «al fin» (Pablo, 22 nov). Workers AI, binding AI.

const PROMPTS = {
  es: "Partida de ajedrez. Alfil, caballo, torre, dama, rey, peón, enroque, jaque, jaque mate, captura, come, columna, fila. e4, d4, Cf3, Ac4, Dxe5, Txe8, O-O. Peón de rey dos pasos. ¿Por qué es mala mi jugada?",
  en: "Chess game. Bishop, knight, rook, queen, king, pawn, castle, check, checkmate, capture, takes, file, rank. e4, d4, Nf3, Bc4, Qxe5, Rxe8, O-O. King's pawn two squares. Why is my move bad?",
  fr: "Partie d'échecs. Fou, cavalier, tour, dame, roi, pion, roque, échec, échec et mat, prise. e4, d4, Cf3, Fc4.",
  it: "Partita a scacchi. Alfiere, cavallo, torre, donna, re, pedone, arrocco, scacco, scacco matto. e4, d4, Cf3, Ac4.",
  pt: "Partida de xadrez. Bispo, cavalo, torre, dama, rei, peão, roque, xeque, xeque-mate. e4, d4, Cf3, Bc4.",
  de: "Schachpartie. Läufer, Springer, Turm, Dame, König, Bauer, Rochade, Schach, Schachmatt. e4, d4, Sf3, Lc4.",
};

export async function transcribe(input, env) {
  const audio = String(input?.audio ?? "");
  if (audio.length < 100 || audio.length > 1_500_000 || !/^[A-Za-z0-9+/=]+$/.test(audio.slice(0, 200))) {
    throw Object.assign(new Error("audio no válido"), { status: 400 });
  }
  if (!env.AI) throw Object.assign(new Error("sin Workers AI en el servidor"), { status: 500 });
  const lang = String(input?.language ?? "es").slice(0, 2);
  const params = { audio, language: lang, vad_filter: true };
  if (PROMPTS[lang]) params.initial_prompt = PROMPTS[lang];
  const r = await env.AI.run(env.MODEL_VOICE || "@cf/openai/whisper-large-v3-turbo", params);
  const text = String(r?.text ?? "").trim().slice(0, 400);
  return { text };
}
