// Asistente de A Chess Way (/asistente): el jugador pide cosas con sus palabras («empieza una partida en nivel
// medio», «pon el tablero de mármol», «peón de rey dos pasos») y Claude elige acciones de una lista fija. La app
// las ejecuta (y las comprueba); aquí solo se validan su forma y sus valores. Petición de Pablo (21 nov).
import { noCredit, noCreditError } from "./credit.js";

const LEVELS = ["muy fácil", "fácil", "medio", "difícil", "muy difícil", "experto"];
const RHYTHMS = ["sin reloj", "3+2", "5+0", "10+0", "15+10", "30+0", "90+30"];
const SCREENS = ["inicio", "opciones", "jugar", "online", "mis_partidas", "entrenar", "aprender", "mi_nivel", "finales_campeones", "como_se_usa", "licencias", "reto_del_dia", "test_nivel", "repasar_fallos", "mi_icono", "idioma"];
const THEMES = ["mi_nivel", "doble", "linea", "defensor", "mate", "peon", "caza", "otros"];
const SWITCHES = ["sonido", "contorno", "seguir_movil", "fijar_giro", "pista_gestos", "tutor", "pulsar_reloj"];
const UCI = /^[a-h][1-8][a-h][1-8][qrbn]?$/;

const tool = (name, description, properties, required = []) => ({ name, description, input_schema: { type: "object", properties, required } });

export const TOOLS = [
  tool("empezar_partida", "Empieza una partida contra la app.", {
    nivel: { type: "string", enum: LEVELS, description: "Nivel del rival. «Intermedio» = medio; «principiante» = muy fácil; «experto» = Stockfish (subniveles 1–3 con Elo 2100, 2400 y 2700; el 4, sin límite)." },
    subnivel: { type: "integer", description: "Escalón dentro del nivel (1 = el más fácil). Opcional." },
    color: { type: "string", enum: ["blancas", "negras", "azar"] },
    ritmo: { type: "string", enum: RHYTHMS },
    war_chess: { type: "boolean", description: "Variante War Chess de la app (piezas con armadura)." },
  }, ["nivel"]),
  tool("mover", "Juega una jugada en la partida en curso. Solo si le toca al jugador. Elige una de las jugadas legales que te doy (en UCI).", {
    uci: { type: "string", description: "La jugada en UCI, p. ej. e2e4. Tiene que estar en la lista de jugadas legales." },
  }, ["uci"]),
  tool("cambiar_piezas", "Cambia el juego de piezas.", { piezas: { type: "string", enum: ["figuras", "fichas", "simple"], description: "figuras = piezas 3D clásicas (lo que la gente llama «piezas 3D», «fichas 3D», «piezas de verdad»); fichas = discos planos con el icono; simple = tablero plano desde arriba." } }, ["piezas"]),
  tool("cambiar_material", "Cambia el material del tablero y de las piezas.", { material: { type: "string", enum: ["madera", "mármol", "metal", "ilustrado"] } }, ["material"]),
  tool("inclinar_tablero", "Cambia la inclinación de la vista: ángulo de la cámara sobre el tablero. 90 = desde arriba (en picado); 64 = la vista normal; 36 = lo más tumbado posible.", { grados: { type: "number" } }, ["grados"]),
  tool("cambiar_tema", "Tema claro u oscuro.", { tema: { type: "string", enum: ["claro", "oscuro"] } }, ["tema"]),
  tool("animaciones", "Cuánto se animan las piezas.", { modo: { type: "string", enum: ["completas", "rápidas", "mínimas", "sin"] } }, ["modo"]),
  tool("ajuste", "Enciende o apaga un ajuste.", { nombre: { type: "string", enum: SWITCHES }, activo: { type: "boolean" } }, ["nombre", "activo"]),
  tool("cambiar_idioma", "Cambia el idioma de la app.", { idioma: { type: "string", enum: ["es", "en", "fr", "it", "pt", "de", "ru", "ja", "hi", "id"] } }, ["idioma"]),
  tool("abrir", "Abre una pantalla de la app (ver «Qué hay en la app» para lo que tiene cada una).", { pantalla: { type: "string", enum: SCREENS } }, ["pantalla"]),
  tool("entrenar", "Empieza a resolver problemas de táctica: a tu nivel o de un tema.", {
    tema: { type: "string", enum: THEMES, description: "mi_nivel = problemas a su nivel (lo normal); doble = ataques dobles y descubiertas; linea = clavadas y enfiladas; defensor = desviar, atraer y quitar defensas; mate = mates; peon = peones y coronación; caza = piezas sin defensa o atrapadas; otros." },
  }, ["tema"]),
  tool("ver_partidas_online", "Mira cuánta gente está esperando rival online ahora mismo, por ritmo, y se lo enseña al jugador.", {}),
  tool("accion_partida", "Botones de la partida en curso.", { accion: { type: "string", enum: ["pista", "deshacer", "explicamelo"] } }, ["accion"]),
  tool("preguntar_tutor", "Pasa una pregunta de ajedrez sobre la partida al tutor (que la analiza con Stockfish y la contesta).", { pregunta: { type: "string" } }, ["pregunta"]),
];

const ENUMS = {};
for (const t of TOOLS) for (const [k, v] of Object.entries(t.input_schema.properties)) if (v.enum) ENUMS[`${t.name}.${k}`] = v.enum;

// Una acción válida (nombre conocido, valores dentro de lo permitido) o null.
export function cleanAction(name, input, state) {
  const t = TOOLS.find((x) => x.name === name);
  if (!t || !input || typeof input !== "object") return null;
  const out = {};
  for (const [k, spec] of Object.entries(t.input_schema.properties)) {
    if (!(k in input)) continue;
    let v = input[k];
    if (spec.enum && !spec.enum.includes(v)) return null;
    if (spec.type === "number" || spec.type === "integer") {
      v = Number(v);
      if (!Number.isFinite(v)) return null;
    }
    if (spec.type === "boolean" && typeof v !== "boolean") return null;
    if (spec.type === "string" && typeof v !== "string") return null;
    out[k] = v;
  }
  for (const r of t.input_schema.required || []) if (!(r in out)) return null;
  if (name === "mover") {
    const legal = Array.isArray(state?.legal) ? state.legal.map(String) : [];
    if (!UCI.test(out.uci) || !legal.some((l) => l.endsWith("=" + out.uci))) return null;
  }
  if (name === "preguntar_tutor") out.pregunta = out.pregunta.slice(0, 400);
  return { name, input: out };
}

export function assistantPrompt(text, state, language) {
  const s = state && typeof state === "object" ? state : {};
  const system = [
    "Eres el asistente de A Chess Way, una app de ajedrez para móvil. El jugador te pide cosas con sus palabras (escritas o dictadas por voz, con posibles faltas) y tú las haces usando las herramientas, que son acciones de la app.",
    "Reglas:",
    "- Si lo que pide se puede hacer con las herramientas, úsalas directamente (varias si hace falta, en orden). Como mucho, una frase muy corta (menos de 12 palabras) diciendo lo que has hecho, p. ej. «Listo: piezas en figuras 3D.»",
    "- El jugador ve todo lo que escribes: nunca escribas tu razonamiento, dudas ni explicaciones de cómo has decidido. Si la petición es ambigua pero hay una opción razonable, elígela y hazla sin explicar.",
    "- Si no se puede, dilo con amabilidad en una o dos frases y sugiere lo más parecido que sí se puede y cómo hacerlo (qué tocar en la app).",
    "- El texto suele venir del dictado por voz, que no sabe de ajedrez: «al fin» es «alfil», «peor» puede ser «peón», «reina» es la dama, «ce», «de», «e»… son columnas (c, d, e), y los números pueden venir en letra. Interprétalo siempre en clave de ajedrez.",
    "- Para mover: el jugador puede decir la jugada en notación («e4», «Cf3») o con palabras («peón de rey dos pasos», «enroque corto», «la dama come el alfil»). Elige la jugada de la lista de jugadas legales que te doy; si no está claro cuál es o no es legal, pregunta o explica por qué no se puede, sin mover.",
    "- No inventes funciones que la app no tiene. Si pide algo peligroso o irreversible (borrar el progreso, rendirse), explica cómo hacerlo él mismo y no lo hagas.",
    "- Las preguntas de ajedrez sobre la partida (por qué una jugada es mala, qué planea el rival) van al tutor con «preguntar_tutor».",
    `- Contesta en el idioma ${language}. Sin markdown ni emojis.`,
    "",
    "Qué hay en la app (pantallas y qué hacer en cada una; úsalo para proponer y hacer cosas):",
    "- inicio: saludo con el nivel de táctica, la racha de días y el Elo de juego; tarjetas a Reto del día, Entrenar (o el test de nivel si no lo ha hecho), Jugar una partida, Partida online, Aprende desde cero y Mi nivel y mi plan.",
    "- reto_del_dia: el objetivo de cada día (tres pasos: problemas, una partida, repasar…); cumplirlo mantiene la racha de días.",
    "- test_nivel: unos problemas para medir su nivel de táctica (si aún no lo ha hecho, o para repetirlo).",
    "- entrenar (pantalla): el camino de niveles de táctica 0–10, «Repasar mis fallos», «Finales de campeones» y los temas. Para ponerse a resolver directamente, usa la herramienta «entrenar».",
    "- repasar_fallos: vuelve a los problemas que falló.",
    "- finales_campeones: momentos de partidas famosas con vídeo; el jugador elige qué jugaría.",
    "- aprender: el curso «Aprende desde cero» (cómo se mueve cada pieza, jaque, enroque…), lección a lección.",
    "- jugar: partidas contra la app: niveles muy fácil, fácil, medio, difícil, muy difícil (cada uno con subniveles, 13 en total, con su Elo) y «experto» (Stockfish dentro del móvil, Elo 2100, 2400, 2700 o sin límite; no en War Chess). Con o sin reloj, blancas, negras o al azar, y la variante War Chess (piezas con blindaje). Sin reloj hay deshacer, pista y el tutor IA; con reloj, no. Mejor usar «empezar_partida» si ya sabe qué quiere.",
    "- online: partidas contra personas por ritmos (3+2, 5+0, 10+0, 15+10…); se espera rival en un ritmo. Sin tutor ni pistas.",
    "- mis_partidas: el historial, con el análisis jugada a jugada de cada partida (con Stockfish si está en el móvil) y el nivel de juego.",
    "- mi_nivel: «Mi nivel y mi plan»: nivel de táctica, en qué falla por temas y qué le toca practicar; también su Elo de juego.",
    "- mi_icono: elegir el icono o foto del avatar.",
    "- opciones: piezas (figuras 3D, fichas, simple), material (madera, mármol, metal, ilustrado), tema claro/oscuro, inclinación del tablero, animaciones, sonido, idioma, tutor IA y otros ajustes; también «Cómo se usa» y las licencias.",
    "- El tutor IA (en partidas sin reloj contra la app): marca cada jugada (mejor, buena, imprecisión, error, error grave, oportunidad perdida), «Explícamelo» la enseña en el tablero, «Prueba otra vez» deja repetir una jugada mala y se le pueden hacer preguntas. 5 partidas gratis; después, premium.",
    "Si lo que pide existe con otro nombre (p. ej. «el desafío de hoy» = reto_del_dia, «ejercicios» o «puzzles» = entrenar, «ver mis errores» = repasar_fallos), hazlo. Antes de decir que algo no existe, repasa esta lista. Usa el «perfil» del estado (nivel, Elo, reto de hoy, racha, si hay Stockfish) para recomendar con datos: p. ej. si el reto de hoy está a medias, dile cuánto le falta.",
  ].join("\n");
  const lines = [`Estado de la app ahora: ${JSON.stringify({ ...s, legal: undefined })}`];
  if (Array.isArray(s.legal) && s.legal.length) lines.push(`Jugadas legales del jugador ahora (notación=UCI): ${s.legal.slice(0, 120).join(", ")}`);
  lines.push("", `Lo que pide el jugador: «${String(text).slice(0, 400)}»`);
  return { system, user: lines.join("\n") };
}

// Con acciones hechas, el texto solo vale si es una frase corta de confirmación: un texto largo suele ser el
// razonamiento del modelo en voz alta (Pablo, 23 nov: «que haga el cambio y ya está»), y no se enseña.
export function trimSay(say, acted) {
  const s = String(say || "").trim();
  if (!acted) return s;
  return s.length > 140 ? "" : s;
}

export async function assist(input, env) {
  const text = String(input?.text ?? "").trim();
  if (text.length < 2) throw Object.assign(new Error("petición vacía"), { status: 400 });
  if (!env.ANTHROPIC_API_KEY) throw Object.assign(new Error("falta la clave en el servidor"), { status: 500 });
  const language = String(input?.language ?? "es").slice(0, 5);
  const state = input?.state && typeof input.state === "object" ? input.state : {};
  const { system, user } = assistantPrompt(text, state, language);
  const base = { model: env.MODEL_ASSISTANT || "claude-haiku-5-5", max_tokens: 1024, system, tools: TOOLS, messages: [{ role: "user", content: user }] };
  const call = (body) => fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "anthropic-version": "2023-06-01", "x-api-key": env.ANTHROPIC_API_KEY },
    body: JSON.stringify(body),
  });
  let r = await call({ ...base, thinking: { type: "disabled" } });
  if (r.status === 400 && !(await noCredit(r))) r = await call({ ...base, max_tokens: 3000 });
  if (!r.ok) throw (await noCredit(r)) ? noCreditError() : Object.assign(new Error(`api ${r.status}`), { status: 502 });
  const data = await r.json();
  const content = data.content || [];
  let say = content.filter((c) => c.type === "text").map((c) => c.text).join(" ").trim().slice(0, 600);
  const actions = [];
  let dropped = 0;
  for (const c of content.filter((x) => x.type === "tool_use")) {
    const a = cleanAction(c.name, c.input, state);
    if (a) actions.push(a);
    else dropped += 1;
  }
  say = trimSay(say, actions.length > 0);
  return { say, actions: actions.slice(0, 6), dropped };
}
