// Voz del tutor (/voz/decir): lee en voz alta lo que contesta el tutor (Pablo, 22 nov: «la voz de A Tank Story me
// gusta para el tutor»). Es Kokoro-82M (Apache 2.0) con las mismas voces que el tutorial de A Tank Story
// (tools/voice_gen/tutorial_voice.py y voices_lang.py de Tank-Ahead), sin el efecto de radio.
// Kokoro no cabe en un Worker: lo sirve un proveedor con API compatible con la de OpenAI (/v1/audio/speech).
// Por defecto DeepInfra; se cambia con TTS_URL y TTS_MODEL (wrangler.toml). La clave, en el secreto TTS_API_KEY.
// Alemán, ruso e indonesio: Kokoro no tiene esas voces; la app usa la voz del sistema.

// Voz del tutorial de A Tank Story en cada idioma (la «radio» de voices_lang.py; en inglés, bm_george).
export const VOICES = {
  es: "em_santa",
  en: "bm_george",
  fr: "ff_siwis",
  it: "if_sara",
  pt: "pm_santa",
  ja: "jf_alpha",
  hi: "hf_alpha",
};

const MAX_CHARS = 1500;

// Cómo se dicen las jugadas en cada idioma. Las letras de las piezas son las de la notación de la app
// (godot/core/i18n/loc.gd, LETTERS): japonés e hindi usan las inglesas.
const WORDS = {
  es: {
    pieces: { R: "rey", D: "dama", T: "torre", A: "alfil", C: "caballo" },
    pawn: "peón de", takes: "toma en", to: "a", check: "jaque", mate: "jaque mate", promote: "y corona",
    short: "enroque corto", long: "enroque largo",
    files: { a: "a", b: "be", c: "ce", d: "de", e: "e", f: "efe", g: "ge", h: "hache" },
    ranks: ["uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho"],
  },
  en: {
    pieces: { K: "king", Q: "queen", R: "rook", B: "bishop", N: "knight" },
    pawn: "pawn", takes: "takes on", to: "to", check: "check", mate: "checkmate", promote: "promoting to",
    short: "castles kingside", long: "castles queenside",
    files: { a: "A", b: "B", c: "C", d: "D", e: "E", f: "F", g: "G", h: "H" },
    ranks: ["one", "two", "three", "four", "five", "six", "seven", "eight"],
  },
  fr: {
    pieces: { R: "roi", D: "dame", T: "tour", F: "fou", C: "cavalier" },
    pawn: "pion", takes: "prend en", to: "en", check: "échec", mate: "échec et mat", promote: "et devient",
    short: "petit roque", long: "grand roque",
    files: { a: "a", b: "bé", c: "cé", d: "dé", e: "e", f: "effe", g: "gé", h: "hache" },
    ranks: ["un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit"],
  },
  it: {
    pieces: { R: "re", D: "donna", T: "torre", A: "alfiere", C: "cavallo" },
    pawn: "pedone", takes: "prende in", to: "in", check: "scacco", mate: "scacco matto", promote: "e promuove a",
    short: "arrocco corto", long: "arrocco lungo",
    files: { a: "a", b: "bi", c: "ci", d: "di", e: "e", f: "effe", g: "gi", h: "acca" },
    ranks: ["uno", "due", "tre", "quattro", "cinque", "sei", "sette", "otto"],
  },
  pt: {
    pieces: { R: "rei", D: "dama", T: "torre", B: "bispo", C: "cavalo" },
    pawn: "peão de", takes: "captura em", to: "para", check: "xeque", mate: "xeque-mate", promote: "e promove a",
    short: "roque pequeno", long: "roque grande",
    files: { a: "a", b: "bê", c: "cê", d: "dê", e: "é", f: "efe", g: "gê", h: "agá" },
    ranks: ["um", "dois", "três", "quatro", "cinco", "seis", "sete", "oito"],
  },
  // Japonés e hindi: sin comprobar con un hablante nativo. Las casillas se dejan como se escriben.
  ja: {
    pieces: { K: "キング", Q: "クイーン", R: "ルーク", B: "ビショップ", N: "ナイト" },
    pawn: "ポーン", takes: "で取る", to: "", check: "チェック", mate: "チェックメイト", promote: "に昇格",
    short: "キングサイドキャスリング", long: "クイーンサイドキャスリング", after: true, comma: "、",
  },
  hi: {
    pieces: { K: "राजा", Q: "वज़ीर", R: "हाथी", B: "ऊँट", N: "घोड़ा" },
    pawn: "प्यादा", takes: "पर कब्ज़ा", to: "", check: "शह", mate: "शह और मात", promote: "बनता है",
    short: "छोटा कैसलिंग", long: "बड़ा कैसलिंग", after: true,
  },
};

const MOVE = /(?<![\p{L}\p{N}])(?:(O-O-O|0-0-0)|(O-O|0-0)|([KQRBNDTACF])?([a-h])?([1-8])?(x|:)?([a-h])([1-8])(?:=?([KQRBNDTACF]))?)([+#])?(?![\p{L}\p{N}])/gu;

function square(w, f, r) {
  if (!w.files) return `${f}${r}`;
  return `${w.files[f]} ${w.ranks[Number(r) - 1]}`;
}

// Una jugada en palabras. `null` si no parece una jugada de verdad (p. ej. una letra de pieza que no existe en el
// idioma: «A» en inglés).
function moveWords(w, m) {
  const [, longC, shortC, piece, fromF, fromR, cap, toF, toR, promo, sign] = m;
  let out;
  if (longC) out = w.long;
  else if (shortC) out = w.short;
  else {
    if (piece && !(piece in w.pieces)) return null;
    if (promo && !(promo in w.pieces)) return null;
    // Una casilla suelta («e5») se lee como casilla; un peón que captura, «peón de e toma en d5».
    const to = square(w, toF, toR);
    const name = piece ? w.pieces[piece] : (fromF && cap ? `${w.pawn} ${w.files ? w.files[fromF] : fromF}` : "");
    if (!name && !cap) out = to;
    else if (w.after) out = cap ? `${name} ${to} ${w.takes}` : `${name} ${to}`;
    else out = cap ? `${name} ${w.takes} ${to}` : `${name} ${w.to} ${to}`.replace(/\s+/g, " ");
    if (promo) out += ` ${w.promote} ${w.pieces[promo]}`;
  }
  const comma = w.comma ?? ", ";
  if (sign === "#") out += `${comma}${w.mate}`;
  else if (sign === "+") out += `${comma}${w.check}`;
  return out;
}

// El texto tal como debe sonar: sin markdown ni emojis, y las jugadas en palabras («Cxf5+» → «caballo toma en efe
// cinco, jaque»). Lo que no se reconoce se deja como está.
export function speakable(text, lang) {
  let t = String(text ?? "");
  t = t.replace(/```[\s\S]*?```/g, " ").replace(/^\s*(#+|>+|[-*•]\s)\s*/gm, "").replace(/[*_`|]+/g, " ");
  t = t.replace(/[\p{Extended_Pictographic}\u{FE0F}\u{200D}]/gu, "");
  t = t.replace(/[→⇒]/g, ", ").replace(/…/g, "...");
  const w = WORDS[lang];
  if (w) {
    t = t.replace(MOVE, (...m) => moveWords(w, m) ?? m[0]);
  }
  // Números de jugada sueltos («12.Cge2», «12...e5»): fuera, se entienden por el contexto.
  t = t.replace(/(?<![\p{N}])\d{1,3}\.{1,3}\s*(?=\p{L})/gu, "");
  t = t.replace(/([!?])\1+/g, "$1");
  return t.replace(/[ \t]+/g, " ").replace(/ ([,.;:!?])/g, "$1").replace(/([,;:])(?=[,;:])/g, "").replace(/\s*\n\s*/g, "\n").trim();
}

const b64 = (buf) => {
  const bytes = new Uint8Array(buf);
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
};

// POST /voz/decir {"text", "language"} → {"audio": MP3 en base64, "voice"}.
// Errores: 400 (texto no válido), 404 (idioma sin voz de Kokoro) y 503 (sin clave o el proveedor no contesta); en
// 404 y 503, «detail.texto» trae el texto preparado para que la app lo diga con la voz del sistema.
export async function speak(input, env, fetcher = fetch) {
  const lang = String(input?.language ?? "es").slice(0, 2);
  const raw = String(input?.text ?? "");
  if (raw.trim().length < 1 || raw.length > MAX_CHARS) throw Object.assign(new Error("texto no válido"), { status: 400 });
  // En los errores va también el texto ya preparado para leerlo: la app lo dice con la voz del sistema.
  const text = speakable(raw, lang);
  const fail = (msg, status, extra = {}) => Object.assign(new Error(msg), { status, detail: { texto: text, ...extra } });
  const voice = VOICES[lang];
  if (!voice) throw fail("idioma sin voz", 404);
  if (!env.TTS_API_KEY) throw fail("voz no disponible (falta la clave en el servidor)", 503);
  const r = await fetcher(env.TTS_URL || "https://api.deepinfra.com/v1/audio/speech", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${env.TTS_API_KEY}` },
    body: JSON.stringify({ model: env.TTS_MODEL || "hexgrad/Kokoro-82M", input: text, voice, response_format: "mp3", speed: Number(env.TTS_SPEED || 1.0) }),
  });
  if (!r.ok) {
    const said = (await r.text().catch(() => "")).slice(0, 300);
    throw fail(`voz: proveedor ${r.status}`, 503, { proveedor: said });
  }
  // Unos proveedores devuelven el audio tal cual; otros, un JSON con el audio en base64 (a veces como «data:»).
  const type = r.headers.get("content-type") || "";
  let audio = "";
  if (type.includes("json")) {
    const data = await r.json();
    audio = String(data?.audio ?? data?.data ?? "").replace(/^data:[^,]*,/, "");
  } else {
    audio = b64(await r.arrayBuffer());
  }
  if (audio.length < 100) throw fail("voz: respuesta sin audio", 503);
  return { audio, voice };
}
