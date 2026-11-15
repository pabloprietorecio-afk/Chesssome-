// Prueba de Firebase Realtime Database para las partidas online de Chessome (emparejamiento automático).
// Comprueba las reglas de seguridad (firebase/database.rules.json), la carrera entre dos jugadores que
// intentan unirse a la misma partida abierta, el borrado y el retraso de las jugadas en directo (SSE).
// Solo usa fetch de Node 22; no imprime tokens. Salida: 0 si todo va bien, 1 si algo falla.
import { readFileSync } from 'node:fs';

const cfg = JSON.parse(readFileSync(new URL('./firebase-config.json', import.meta.url), 'utf8'));
const base = cfg.databaseURL.replace(/\/$/, '');
const SV = { '.sv': 'timestamp' };
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

async function db(metodo, ruta, token, cuerpo, consulta = '') {
  const params = [consulta, token ? `auth=${token}` : ''].filter(Boolean).join('&');
  const url = `${base}/${ruta}.json${params ? '?' + params : ''}`;
  const r = await fetch(url, { method: metodo, body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo) });
  const texto = await r.text();
  let json = null;
  try { json = JSON.parse(texto); } catch { /* vacío */ }
  return { estado: r.status, json, fecha: r.headers.get('date') };
}

// Escucha en directo (Server-Sent Events). Devuelve { estado, parar }.
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

// Identificador: hora UTC con segundos + trozo aleatorio. Ordena cronológicamente por clave.
function nuevoId() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}-${p(d.getUTCHours())}${p(d.getUTCMinutes())}${p(d.getUTCSeconds())}-${Math.random().toString(36).slice(2, 8)}`;
}

// El creador abre partida: la partida y su anuncio en la lista de abiertas.
async function abrirPartida(U) {
  const id = nuevoId();
  const a = await db('PUT', `partidas/${id}/creador`, U.token, U.uid);
  const b = await db('PATCH', `abiertas/${id}`, U.token, { creador: U.uid, latido: SV });
  return { id, ok: a.estado === 200 && b.estado === 200, a: a.estado, b: b.estado };
}

// El jugador que entra intenta quedarse con el hueco de rival (atómico).
const unirse = (U, id) => db('PATCH', `partidas/${id}`, U.token, { rival: U.uid, unidoEn: SV });

const [A, B, C] = [await sesionAnonima(), await sesionAnonima(), await sesionAnonima()];

// 1. Abrir partida y verla en la lista.
const p1 = await abrirPartida(A);
resultado('A abre partida (partida + lista de abiertas)', p1.ok, `HTTP ${p1.a}/${p1.b}`);
let r = await db('GET', 'abiertas', B.token, undefined, 'orderBy=%22%24key%22&limitToFirst=5');
const fila = r.json?.[p1.id];
const dif = fila?.latido && r.fecha ? Math.abs(Date.parse(r.fecha) - fila.latido) : null;
resultado('B ve la partida abierta con su latido reciente', r.estado === 200 && !!fila && dif !== null && dif < 15000,
  `HTTP ${r.estado}, diferencia con el reloj del servidor: ${dif} ms`);
r = await db('GET', 'abiertas', null);
resultado('Sin sesión no se ve la lista', r.estado === 401, `HTTP ${r.estado}`);

// 2. A no puede jugar contra sí mismo; las jugadas no valen antes de empezar.
r = await unirse(A, p1.id);
resultado('El creador no puede unirse a su propia partida', r.estado === 401, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${p1.id}/jugadas/0`, A.token, 'e2e4');
resultado('Sin rival no se aceptan jugadas', r.estado === 401, `HTTP ${r.estado}`);

// 3. Carrera: B y C a la vez a la misma partida; exactamente uno debe entrar. Cinco rondas.
let carreraOk = true;
let ronda1 = null;
for (let k = 0; k < 5; k++) {
  const p = k === 0 ? p1 : await abrirPartida(A);
  const [rb, rc] = await Promise.all([unirse(B, p.id), unirse(C, p.id)]);
  const ganan = [rb.estado, rc.estado].filter((e) => e === 200).length;
  const pierden = [rb.estado, rc.estado].filter((e) => e === 401).length;
  if (ganan !== 1 || pierden !== 1) carreraOk = false;
  if (k === 0) {
    ronda1 = { p, ganador: rb.estado === 200 ? B : C, perdedor: rb.estado === 200 ? C : B };
  }
  console.log(`       ronda ${k + 1}: B=${rb.estado} C=${rc.estado}`);
  if (k > 0) {
    // limpieza de las rondas extra
    await db('DELETE', `abiertas/${p.id}`, A.token);
    await db('DELETE', `partidas/${p.id}`, A.token);
  }
}
resultado('Carrera: siempre entra exactamente uno (5 rondas)', carreraOk);

// 4. Estado tras unirse y color por la hora del servidor.
const { p, ganador, perdedor } = ronda1;
r = await db('GET', `partidas/${p.id}`, A.token);
const partida = r.json ?? {};
const unidoOk = partida.creador === A.uid && partida.rival === ganador.uid && typeof partida.unidoEn === 'number';
resultado('La partida queda con creador, rival y hora de unión', unidoOk);
if (unidoOk) {
  const blancas = partida.unidoEn % 2 === 0 ? 'creador' : 'rival';
  console.log(`       hora de unión ${partida.unidoEn} → blancas: ${blancas}`);
}

// 5. Jugadas en directo: A escribe, el rival escucha.
const esperas = new Map();
const oyente = await escuchar(`partidas/${p.id}/jugadas`, ganador.token, ({ evento, datos }) => {
  if ((evento === 'put' || evento === 'patch') && datos?.path) {
    const f = esperas.get(datos.path);
    if (f) { esperas.delete(datos.path); f(); }
  }
});
resultado('El rival abre la escucha en directo', oyente.estado === 200, `HTTP ${oyente.estado}`);
await new Promise((ok) => setTimeout(ok, 1500));
const retrasos = [];
for (let n = 0; n < 5; n++) {
  const t0 = performance.now();
  const llega = new Promise((ok, mal) => {
    esperas.set(`/${n}`, ok);
    setTimeout(() => mal(new Error('sin llegada')), 8000);
  });
  const w = await db('PUT', `partidas/${p.id}/jugadas/${n}`, A.token, `a2a${n}`);
  try { await llega; retrasos.push(performance.now() - t0); }
  catch { resultado(`Jugada ${n} llega al rival`, false, `escritura HTTP ${w.estado}, sin evento en 8 s`); }
}
oyente.parar();
if (retrasos.length === 5) {
  resultado('5 jugadas llegan al rival en directo', true,
    `escritura→llegada (incluye el envío): mediana ${Math.round(mediana(retrasos))} ms, máximo ${Math.round(Math.max(...retrasos))} ms`);
}
r = await db('PUT', `partidas/${p.id}/jugadas/0`, A.token, 'd2d4');
resultado('No se puede cambiar una jugada escrita', r.estado === 401, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${p.id}/jugadas/9`, perdedor.token, 'g1f3');
resultado('El jugador que no entró no puede escribir jugadas', r.estado === 401, `HTTP ${r.estado}`);
r = await db('PUT', `partidas/${p.id}/jugadas/9`, ganador.token, 'x'.repeat(20));
resultado('Jugada demasiado larga rechazada', r.estado === 401, `HTTP ${r.estado}`);

// 6. Lista de abiertas: latido y borrado.
r = await db('PUT', `abiertas/${p.id}/latido`, perdedor.token, SV);
resultado('Solo el creador actualiza el latido (otro, no)', r.estado === 401, `HTTP ${r.estado}`);
r = await db('PUT', `abiertas/${p.id}/latido`, A.token, SV);
resultado('El creador actualiza su latido', r.estado === 200, `HTTP ${r.estado}`);
r = await db('DELETE', `abiertas/${p.id}`, perdedor.token);
resultado('Otro jugador no puede quitar la partida de la lista', r.estado === 401, `HTTP ${r.estado}`);
r = await db('DELETE', `abiertas/${p.id}`, A.token);
resultado('El creador la quita de la lista al llegar el rival', r.estado === 200, `HTTP ${r.estado}`);

// 7. Borrado de la partida: solo participantes.
r = await db('DELETE', `partidas/${p.id}`, perdedor.token);
resultado('Quien no juega no puede borrar la partida', r.estado === 401, `HTTP ${r.estado}`);
r = await db('DELETE', `partidas/${p.id}`, ganador.token);
resultado('Un jugador borra la partida al terminar', r.estado === 200, `HTTP ${r.estado}`);
r = await db('GET', `partidas/${p.id}`, A.token);
resultado('La partida ya no existe', r.estado === 200 && r.json === null);

// 8. Fuera de las rutas permitidas, todo denegado.
r = await db('GET', 'otra/cosa', A.token);
resultado('Fuera de «partidas» y «abiertas» todo denegado', r.estado === 401, `HTTP ${r.estado}`);

console.log(fallos === 0 ? 'RESULTADO: todo correcto' : `RESULTADO: ${fallos} fallo(s)`);
process.exit(fallos === 0 ? 0 : 1);
