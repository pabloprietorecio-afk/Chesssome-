// Cuentas y cupo de las explicaciones (lecciones «Explícamelo» y preguntas al tutor), 22 nov (Pablo: «hazlo como has
// propuesto»):
//   - Premium (suscripción «premium_mensual», 4,99 €/mes): 300 explicaciones o preguntas al mes (mes natural, UTC).
//   - Recarga («explicaciones_100», 1,99 €): 100 más, que no caducan; se gastan cuando se acaba el cupo del mes.
//   - Gratis: un cupo pequeño de por vida (la app da 5 partidas con tutor; esto es la red del servidor).
// La cuenta es un identificador anónimo que genera la app (no hay nombre ni correo). Cada compra se verifica con
// Google (Android Publisher API) con una cuenta de servicio (secreto GOOGLE_PLAY_SA); sin ella, no se dan de alta
// compras. El estado de cada cuenta vive en un Durable Object (uno por cuenta: sin carreras al descontar).

export const PREMIUM_MONTHLY = 300;
export const FREE_TOTAL = 40;
export const PACK_SIZE = 100;
export const PRODUCTS = { sub: "premium_mensual", pack: "explicaciones_100" };

const ACCOUNT = /^[a-f0-9]{32}$/;
export const cleanAccount = (v) => (ACCOUNT.test(String(v ?? "")) ? String(v) : null);
const TOKEN = /^[A-Za-z0-9._\-]{20,600}$/;
export const cleanToken = (v) => (TOKEN.test(String(v ?? "")) ? String(v) : null);

// Probadores (Pablo, 23 nov: «necesito probar todo»): cuentas que el servidor trata como premium sin compra ni
// cupo. Lista separada por comas en la variable PROBADORES (wrangler.toml); la cuenta sale en Opciones → Premium
// del APK de pruebas.
export function isTester(env, account) {
  return Boolean(account) && String(env?.PROBADORES ?? "").split(",").map((x) => x.trim()).filter(Boolean).includes(account);
}

export function testerStatus(now) {
  return { premium: true, quedan: PREMIUM_MONTHLY, extra: 0, gratis: FREE_TOTAL, caduca: now + 30 * 24 * 3600 * 1000, mes: PREMIUM_MONTHLY, probador: true };
}

export const monthOf = (ms) => new Date(ms).toISOString().slice(0, 7);

export function emptyRecord() {
  return { free_used: 0, month: "", used: 0, extra: 0, sub: null };
}

// Lo que se le enseña a la app.
export function status(rec, now) {
  const premium = Boolean(rec.sub && rec.sub.expiry > now);
  const used = rec.month === monthOf(now) ? rec.used : 0;
  return {
    premium,
    quedan: premium ? Math.max(0, PREMIUM_MONTHLY - used) : 0,
    extra: rec.extra,
    gratis: Math.max(0, FREE_TOTAL - rec.free_used),
    caduca: premium ? rec.sub.expiry : 0,
    mes: PREMIUM_MONTHLY,
  };
}

// Gasta una explicación. Devuelve { ok, rec, from } o { ok: false, reason: "cupo" | "premium" }.
export function spend(rec, now) {
  const r = { ...rec };
  const month = monthOf(now);
  if (r.month !== month) { r.month = month; r.used = 0; }
  if (r.sub && r.sub.expiry > now && r.used < PREMIUM_MONTHLY) { r.used += 1; return { ok: true, rec: r, from: "mes" }; }
  if (r.extra > 0) { r.extra -= 1; return { ok: true, rec: r, from: "extra" }; }
  if (!(r.sub && r.sub.expiry > now) && r.free_used < FREE_TOTAL) { r.free_used += 1; return { ok: true, rec: r, from: "gratis" }; }
  return { ok: false, reason: r.sub && r.sub.expiry > now ? "cupo" : "premium" };
}

// Devuelve lo gastado si la explicación falló (no se cobra lo que no llega).
export function refund(rec, from, now) {
  const r = { ...rec };
  if (from === "mes" && r.month === monthOf(now) && r.used > 0) r.used -= 1;
  if (from === "extra") r.extra += 1;
  if (from === "gratis" && r.free_used > 0) r.free_used -= 1;
  return r;
}

// Durable Object: una instancia por cuenta (idFromName), y otra por compra («compra:<token>») para que una recarga
// no se cobre dos veces ni la usen dos cuentas.
export class Cuentas {
  constructor(state) {
    this.storage = state.storage;
  }

  async fetch(request) {
    const { op, now = Date.now(), ...arg } = await request.json();
    const rec = { ...emptyRecord(), ...((await this.storage.get("rec")) || {}) };
    const reply = (o) => new Response(JSON.stringify(o), { headers: { "content-type": "application/json" } });
    if (op === "estado") return reply({ rec, status: status(rec, now) });
    if (op === "gastar") {
      const s = spend(rec, now);
      if (s.ok) await this.storage.put("rec", s.rec);
      return reply(s.ok ? { ok: true, from: s.from, status: status(s.rec, now) } : { ok: false, reason: s.reason, status: status(rec, now) });
    }
    if (op === "devolver") {
      const r = refund(rec, arg.from, now);
      await this.storage.put("rec", r);
      return reply({ status: status(r, now) });
    }
    if (op === "suscripcion") {
      rec.sub = { token: arg.token, product: arg.product, expiry: Number(arg.expiry) || 0, checked: now };
      await this.storage.put("rec", rec);
      return reply({ status: status(rec, now) });
    }
    if (op === "recarga") {
      rec.extra += PACK_SIZE;
      await this.storage.put("rec", rec);
      return reply({ status: status(rec, now) });
    }
    // Registro de una compra: la primera cuenta que la reclama se la queda.
    if (op === "reclamar") {
      const owner = await this.storage.get("owner");
      if (owner && owner !== arg.account) return reply({ ok: false, owner });
      if (!owner) await this.storage.put("owner", arg.account);
      return reply({ ok: true, fresh: !owner });
    }
    return new Response("op?", { status: 400 });
  }
}

// --- Google Play (Android Publisher API) con la cuenta de servicio ---

const b64url = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlText = (s) => b64url(new TextEncoder().encode(s));
let cachedToken = null;

async function googleToken(env) {
  if (!env.GOOGLE_PLAY_SA) throw Object.assign(new Error("compras no configuradas en el servidor"), { status: 503 });
  if (cachedToken && cachedToken.until > Date.now() && cachedToken.sa === env.GOOGLE_PLAY_SA) return cachedToken.value;
  let sa;
  try {
    sa = JSON.parse(env.GOOGLE_PLAY_SA || "");
  } catch {
    throw Object.assign(new Error("compras no configuradas en el servidor"), { status: 503 });
  }
  const now = Math.floor(Date.now() / 1000);
  const aud = sa.token_uri || "https://oauth2.googleapis.com/token";
  const head = b64urlText(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64urlText(JSON.stringify({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/androidpublisher", aud, iat: now, exp: now + 3600 }));
  const pem = String(sa.private_key || "").replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claims}`));
  const r = await fetch(aud, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: `grant_type=${encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")}&assertion=${head}.${claims}.${b64url(sig)}`,
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.access_token) throw Object.assign(new Error("Google no acepta la cuenta de servicio"), { status: 503 });
  cachedToken = { value: j.access_token, until: Date.now() + 50 * 60 * 1000, sa: env.GOOGLE_PLAY_SA };
  return j.access_token;
}

async function play(env, path) {
  const pkg = env.PACKAGE_NAME || "com.pabloprieto.chessome";
  const r = await fetch(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/purchases/${path}`, {
    headers: { authorization: `Bearer ${await googleToken(env)}` },
  });
  const j = await r.json().catch(() => ({}));
  if (r.status === 404 || r.status === 400 || r.status === 410) throw Object.assign(new Error("compra no encontrada"), { status: 400 });
  if (!r.ok) throw Object.assign(new Error(`Google ${r.status}`), { status: 502 });
  return j;
}

// Suscripción: activa (o en periodo de gracia) y hasta cuándo.
export async function checkSubscription(env, token) {
  const j = await play(env, `subscriptionsv2/tokens/${encodeURIComponent(token)}`);
  const items = Array.isArray(j.lineItems) ? j.lineItems : [];
  const mine = items.filter((i) => i.productId === PRODUCTS.sub);
  const expiry = Math.max(0, ...mine.map((i) => Date.parse(i.expiryTime) || 0));
  const active = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"].includes(j.subscriptionState);
  return { valid: mine.length > 0, active, expiry: active ? expiry : 0 };
}

// Recarga: comprada (purchaseState 0).
export async function checkPack(env, token) {
  const j = await play(env, `products/${PRODUCTS.pack}/tokens/${encodeURIComponent(token)}`);
  return { valid: j.purchaseState === 0 };
}

// --- Rutas ---

const obj = (env, name) => env.CUENTAS.get(env.CUENTAS.idFromName(name));
export async function call(env, name, body) {
  const r = await obj(env, name).fetch("https://cuentas/", { method: "POST", body: JSON.stringify(body) });
  return r.json();
}

// /premium/estado, /premium/alta (suscripción), /premium/recarga. Si la suscripción guardada ya pasó de fecha, se
// vuelve a mirar en Google (se renueva sola cada mes).
export async function premiumRoute(path, input, env) {
  const account = cleanAccount(input?.cuenta);
  if (!account) throw Object.assign(new Error("cuenta no válida"), { status: 400 });
  if (path === "/premium/estado" && isTester(env, account)) return testerStatus(Date.now());
  if (!env.CUENTAS) throw Object.assign(new Error("cuentas no configuradas"), { status: 503 });
  if (path === "/premium/estado") {
    const { rec, status: st } = await call(env, account, { op: "estado" });
    if (rec.sub && !st.premium && rec.sub.token && env.GOOGLE_PLAY_SA && Date.now() - (rec.sub.checked || 0) > 60 * 60 * 1000) {
      try {
        const s = await checkSubscription(env, rec.sub.token);
        return (await call(env, account, { op: "suscripcion", token: rec.sub.token, product: PRODUCTS.sub, expiry: s.expiry })).status;
      } catch {
        // Sin respuesta de Google: vale lo guardado.
      }
    }
    return st;
  }
  const token = cleanToken(input?.token);
  if (!token) throw Object.assign(new Error("compra no válida"), { status: 400 });
  if (path === "/premium/alta") {
    const s = await checkSubscription(env, token);
    if (!s.valid) throw Object.assign(new Error("no es la suscripción premium"), { status: 400 });
    return (await call(env, account, { op: "suscripcion", token, product: PRODUCTS.sub, expiry: s.expiry })).status;
  }
  if (path === "/premium/recarga") {
    const s = await checkPack(env, token);
    if (!s.valid) throw Object.assign(new Error("recarga no pagada"), { status: 400 });
    const claim = await call(env, `compra:${token}`, { op: "reclamar", account });
    if (!claim.ok) throw Object.assign(new Error("esa recarga ya es de otra cuenta"), { status: 409 });
    if (!claim.fresh) return (await call(env, account, { op: "estado" })).status;
    return (await call(env, account, { op: "recarga" })).status;
  }
  throw Object.assign(new Error("no existe"), { status: 404 });
}

// Para /tutor/leccion y /tutor/pregunta: gasta una (o dice por qué no) y, si la explicación falla, la devuelve.
// Sin cuenta (versiones de la app anteriores al cupo) se deja pasar mientras REQUIRE_ACCOUNT no sea "1".
export async function withQuota(input, env, run) {
  const account = cleanAccount(input?.cuenta);
  if (isTester(env, account)) return { ...(await run()), cupo: testerStatus(Date.now()) };
  if (!account || !env.CUENTAS) {
    if (env.REQUIRE_ACCOUNT === "1") throw Object.assign(new Error("actualiza la app"), { status: 426 });
    return run();
  }
  const s = await call(env, account, { op: "gastar" });
  if (!s.ok) throw Object.assign(new Error(s.reason === "cupo" ? "cupo agotado" : "hace falta premium"), { status: 402, detail: { motivo: s.reason, cupo: s.status } });
  try {
    const out = await run();
    return { ...out, cupo: s.status };
  } catch (e) {
    await call(env, account, { op: "devolver", from: s.from }).catch(() => {});
    throw e;
  }
}
