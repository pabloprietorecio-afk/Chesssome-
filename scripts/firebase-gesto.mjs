// Comprueba en la base de datos real que las reglas publicadas aceptan el gesto «pregunta» («¿Sigues ahí?», 22 nov)
// y siguen rechazando los gestos desconocidos. Dos sesiones anónimas, una partida de prueba que se borra al final.
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

async function sesion() {
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${cfg.apiKey}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ returnSecureToken: true }),
  });
  const j = await r.json();
  if (!r.ok) { console.log(`FALLO sesión anónima — ${j?.error?.message ?? r.status}`); process.exit(1); }
  return { token: j.idToken, uid: j.localId };
}

async function db(metodo, ruta, token, cuerpo) {
  const r = await fetch(`${base}/${ruta}.json?auth=${token}`, { method: metodo, body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo) });
  return r.status;
}

const [A, B] = [await sesion(), await sesion()];
const id = `prueba-gesto-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
resultado('Se abre una partida de prueba', (await db('PUT', `partidas/${id}/creador`, A.token, A.uid)) === 200);
resultado('El rival se une', (await db('PATCH', `partidas/${id}`, B.token, { rival: B.uid, unidoEn: SV })) === 200);
let s = await db('POST', `partidas/${id}/gestos`, A.token, { de: A.uid, g: 'pregunta', t: SV });
resultado('Las reglas publicadas aceptan el gesto «pregunta» (¿Sigues ahí?)', s === 200, `HTTP ${s}`);
s = await db('POST', `partidas/${id}/gestos`, B.token, { de: B.uid, g: 'saludo', t: SV });
resultado('Siguen aceptando los gestos de siempre («saludo»)', s === 200, `HTTP ${s}`);
s = await db('POST', `partidas/${id}/gestos`, A.token, { de: A.uid, g: 'prisa', t: SV });
resultado('Rechazan un gesto inventado («prisa»)', s === 401, `HTTP ${s}`);
s = await db('POST', `partidas/${id}/gestos`, A.token, { de: B.uid, g: 'pregunta', t: SV });
resultado('Nadie puede mandar un gesto en nombre del otro', s === 401, `HTTP ${s}`);
s = await db('DELETE', `partidas/${id}`, A.token);
resultado('La partida de prueba se borra', s === 200, `HTTP ${s}`);
console.log(fallos === 0 ? 'RESULTADO: todo correcto' : `RESULTADO: ${fallos} fallo(s)`);
process.exit(fallos === 0 ? 0 : 1);
