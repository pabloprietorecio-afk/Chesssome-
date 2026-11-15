// Prueba de Firebase Realtime Database para las partidas online de Chessome.
// Comprueba las reglas de seguridad y mide el retraso real de las jugadas con escucha en directo (SSE).
// Solo usa fetch de Node 22; no imprime tokens. Salida: 0 si todo va bien, 1 si algo falla.
import { readFileSync } from 'node:fs';

const cfg = JSON.parse(readFileSync(new URL('./firebase-config.json', import.meta.url), 'utf8'));
const base = cfg.databaseURL.replace(/\/$/, '');
let fallos = 0;

function resultado(nombre, ok, detalle = '') {
  if (!ok) fallos++;
  console.log(`${ok ? 'OK    ' : 'FALLO '} ${nombre}${detalle ? ' — ' + detalle : ''}`);
}

async function sesionAnonima() {
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${cfg.apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  const j = await r.json();
  if (!r.ok) {
    const msg = j?.error?.message ?? r.status;
    console.log(`FALLO sesión anónima — ${msg}${msg === 'OPERATION_NOT_ALLOWED' ? ' (activa «Anónimo» en Authentication)' : ''}`);
    process.exit(1);
  }
  return { token: j.idToken, uid: j.localId };
}

async function db(metodo, ruta, token, cuerpo) {
  const url = `${base}/${ruta}.json${token ? `?auth=${token}` : ''}`;
  const r = await fetch(url, { method: metodo, body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo) });
  return { estado: r.status, texto: await r.text() };
}

// Escucha en directo (Server-Sent Events). Devuelve { parar, estado }.
async function escuchar(ruta, token, alEvento) {
  const control = new AbortController();
  const url = `${base}/${ruta}.json${token ? `?auth=${token}` : ''}`;
  const r = await fetch(url, { headers: { Accept: 'text/event-stream' }, signal: control.signal });
  if (!r.ok) return { estado: r.status, parar: () => control.abort() };
  (async () => {
    const lector = r.body.getReader();
    const deco = new TextDecoder();
    let buf = '';
    try {
      for (;;) {
        const { value, done } = await lector.read();
        if (done) break;
        buf += deco.decode(value, { stream: true });
        let i;
        while ((i = buf.indexOf('\n\n')) >= 0) {
          const bloque = buf.slice(0, i);
          buf = buf.slice(i + 2);
          let evento = '', datos = '';
          for (const l of bloque.split('\n')) {
            if (l.startsWith('event:')) evento = l.slice(6).trim();
            else if (l.startsWith('data:')) datos += l.slice(5).trim();
          }
          let json = null;
          try { json = JSON.parse(datos); } catch { /* keep-alive u otro */ }
          alEvento({ evento, datos: json });
        }
      }
    } catch { /* cortado al parar */ }
  })();
  return { estado: r.status, parar: () => control.abort() };
}

const mediana = (a) => [...a].sort((x, y) => x - y)[Math.floor(a.length / 2)];

const id = `prueba-${Date.now()}`;
const [A, B, C] = [await sesionAnonima(), await sesionAnonima(), await sesionAnonima()];
console.log(`Partida de prueba: ${id}`);

let r = await db('PUT', `partidas/${id}/blancas`, A.token, A.uid);
resultado('A se anota como blancas', r.estado === 200, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${id}/negras`, B.token, B.uid);
resultado('B se anota como negras', r.estado === 200, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${id}/negras`, C.token, C.uid);
resultado('C no puede quitarle las negras a B', r.estado === 401, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${id}/jugadas/0`, A.token, 'e2e4');
resultado('A escribe la jugada 0', r.estado === 200, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${id}/jugadas/0`, A.token, 'd2d4');
resultado('A no puede cambiar una jugada ya escrita', r.estado === 401, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${id}/jugadas/1`, B.token, 'e7e5');
resultado('B escribe la jugada 1', r.estado === 200, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${id}/jugadas/2`, C.token, 'g1f3');
resultado('C (no es jugador) no puede escribir jugadas', r.estado === 401, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${id}/jugadas/2`, A.token, 'x'.repeat(20));
resultado('Jugada demasiado larga rechazada', r.estado === 401, `HTTP ${r.estado}`);
r = await db('GET', `partidas/${id}`, null);
resultado('Sin sesión no se puede leer', r.estado === 401, `HTTP ${r.estado}`);
r = await db('GET', `partidas/${id}`, A.token);
let jugadas = [];
try { jugadas = Object.values(JSON.parse(r.texto).jugadas ?? {}); } catch { /* vacío */ }
resultado('A lee la partida con sus jugadas', r.estado === 200 && jugadas.join(' ') === 'e2e4 e7e5', `jugadas: ${jugadas.join(' ')}`);
r = await db('GET', `otra/cosa`, A.token);
resultado('Fuera de «partidas» todo denegado', r.estado === 401, `HTTP ${r.estado}`);

// Escucha en directo.
const sinSesion = await escuchar(`partidas/${id}/jugadas`, null, () => {});
resultado('Escuchar sin sesión denegado', sinSesion.estado === 401, `HTTP ${sinSesion.estado}`);
sinSesion.parar();

const esperas = new Map();
const oyente = await escuchar(`partidas/${id}/jugadas`, B.token, ({ evento, datos }) => {
  if ((evento === 'put' || evento === 'patch') && datos?.path) {
    const f = esperas.get(datos.path);
    if (f) { esperas.delete(datos.path); f(); }
  }
});
resultado('B abre la escucha en directo', oyente.estado === 200, `HTTP ${oyente.estado}`);
await new Promise((ok) => setTimeout(ok, 1500));

const retrasos = [];
for (let n = 2; n <= 6; n++) {
  const t0 = performance.now();
  const llega = new Promise((ok, mal) => {
    esperas.set(`/${n}`, ok);
    setTimeout(() => mal(new Error('sin llegada')), 8000);
  });
  const w = await db('PUT', `partidas/${id}/jugadas/${n}`, A.token, `a2a${n}`);
  try {
    await llega;
    retrasos.push(performance.now() - t0);
  } catch {
    resultado(`Jugada ${n} llega a B`, false, `escritura HTTP ${w.estado}, sin evento en 8 s`);
  }
}
oyente.parar();
if (retrasos.length === 5) {
  resultado('5 jugadas llegan a B en directo', true,
    `retraso escritura→llegada: mediana ${Math.round(mediana(retrasos))} ms, máximo ${Math.round(Math.max(...retrasos))} ms`);
}

console.log(fallos === 0 ? 'RESULTADO: todo correcto' : `RESULTADO: ${fallos} fallo(s)`);
process.exit(fallos === 0 ? 0 : 1);
