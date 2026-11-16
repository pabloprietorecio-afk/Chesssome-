// Prueba de las reglas de la base de datos (firebase/database.rules.json) contra el emulador de Firebase.
// Uso (desde firebase/test): npm ci && npx firebase emulators:exec --only database --project demo-chess "node --test"
// Lo lanza el CI (trabajo «Reglas de Firebase»): las reglas solo se publican si esto pasa.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { ref, set, update, get, remove, push, serverTimestamp } from 'firebase/database';

let env;
const db = (uid) => env.authenticatedContext(uid).database();
const ts = () => serverTimestamp();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-chess',
    database: { rules: readFileSync(new URL('../database.rules.json', import.meta.url), 'utf8'), host: '127.0.0.1', port: 9000 },
  });
});

after(async () => {
  await env.cleanup();
});

/** Partida g de A (creador) con B dentro y, si `listo`, ya empezada. */
async function game(g, rhythm = '5+3', listo = true) {
  await assertSucceeds(update(ref(db('a'), 'partidas/' + g), { creador: 'a', ritmo: rhythm }));
  await assertSucceeds(update(ref(db('b'), 'partidas/' + g), { rival: 'b', unidoEn: ts() }));
  if (listo) await assertSucceeds(set(ref(db('a'), `partidas/${g}/listo`), ts()));
}

test('espera: abrir un espacio con un ritmo válido', async () => {
  await env.clearDatabase();
  await assertSucceeds(update(ref(db('a'), 'espera/g1'), { creador: 'a', latido: ts(), ritmo: '5+3' }));
  await assertSucceeds(update(ref(db('a'), 'espera/g2'), { creador: 'a', latido: ts(), ritmo: '0+0' }));
  await assertSucceeds(update(ref(db('a'), 'espera/g3'), { creador: 'a', latido: ts(), ritmo: '180+60' }));
  for (const bad of ['0+3', '181+0', '5+61', '05+3', '5', 'x']) {
    await assertFails(update(ref(db('a'), 'espera/m' + bad.replace(/\W/g, '')), { creador: 'a', latido: ts(), ritmo: bad }));
  }
  await assertFails(update(ref(db('a'), 'espera/g4'), { creador: 'b', latido: ts(), ritmo: '5+3' }));
  await assertFails(update(ref(db('b'), 'espera/g1'), { latido: ts() }));
  await assertSucceeds(update(ref(db('a'), 'espera/g1'), { latido: ts() }));
  await assertSucceeds(get(ref(db('b'), 'espera')));
  // Bloqueados: solo los pone el creador.
  await assertSucceeds(set(ref(db('a'), 'espera/g1/no/c'), true));
  await assertFails(set(ref(db('b'), 'espera/g1/no/x'), true));
  // Abrir con jugadores bloqueados (un usuario lo vio fallar, «código 200/401», 16 nov): la app antigua manda la
  // lista entera en el mismo PATCH; la nueva, por rutas. Las dos valen, solo para el creador y solo con «true».
  await assertSucceeds(update(ref(db('a'), 'espera/g5'), { creador: 'a', latido: ts(), ritmo: '5+3', no: { c: true, d: true } }));
  await assertSucceeds(update(ref(db('a'), 'espera/g6'), { creador: 'a', latido: ts(), ritmo: '5+3', 'no/c': true, 'no/d': true }));
  await assertFails(update(ref(db('b'), 'espera/g7'), { creador: 'a', latido: ts(), ritmo: '5+3', no: { c: true } }));
  await assertFails(update(ref(db('a'), 'espera/g8'), { creador: 'a', latido: ts(), ritmo: '5+3', no: { c: 'x' } }));
  await assertFails(update(ref(db('b'), 'espera/g5'), { no: { b: true } }));
  await assertFails(set(ref(db('b'), 'espera/g5/no'), null));
  await assertFails(remove(ref(db('b'), 'espera/g1')));
  await assertSucceeds(remove(ref(db('a'), 'espera/g1')));
});

test('partidas: ritmo del creador, una sola vez', async () => {
  await env.clearDatabase();
  await assertSucceeds(update(ref(db('a'), 'partidas/p1'), { creador: 'a', ritmo: '10+5' }));
  await assertFails(set(ref(db('a'), 'partidas/p1/ritmo'), '5+3'));
  await assertFails(update(ref(db('b'), 'partidas/p2'), { creador: 'a', ritmo: '5+3' }));
  await assertFails(update(ref(db('a'), 'partidas/p3'), { creador: 'a', ritmo: '0+5' }));
});

test('unirse: solo uno, y la partida empieza con «listo» del creador', async () => {
  await env.clearDatabase();
  await game('p1', '5+3', false);
  await assertFails(update(ref(db('c'), 'partidas/p1'), { rival: 'c', unidoEn: ts() }));
  // Antes de «listo» no se juega.
  await assertFails(set(ref(db('b'), 'partidas/p1/jugadas/0'), 'e2e4'));
  await assertFails(set(ref(db('b'), 'partidas/p1/listo'), ts()));
  await assertFails(set(ref(db('a'), 'partidas/p1/listo'), 12345));
  await assertSucceeds(set(ref(db('a'), 'partidas/p1/listo'), ts()));
  await assertFails(set(ref(db('a'), 'partidas/p1/listo'), ts()));
  await assertSucceeds(set(ref(db('a'), 'partidas/p1/jugadas/0'), 'e2e4'));
  await assertFails(set(ref(db('c'), 'partidas/p1/jugadas/1'), 'e7e5'));
});

test('app antigua (sin ritmo ni «listo»): sigue pudiendo jugar', async () => {
  await env.clearDatabase();
  await assertSucceeds(update(ref(db('a'), 'abiertas/v1'), { creador: 'a', latido: ts() }));
  await assertSucceeds(set(ref(db('a'), 'partidas/v1/creador'), 'a'));
  await assertFails(set(ref(db('a'), 'partidas/v1/jugadas/0'), 'e2e4'));
  await assertSucceeds(update(ref(db('b'), 'partidas/v1'), { rival: 'b', unidoEn: ts() }));
  await assertSucceeds(set(ref(db('a'), 'partidas/v1/jugadas/0'), 'e2e4'));
  await assertSucceeds(set(ref(db('b'), 'partidas/v1/jugadas/1'), 'e7e5'));
  await assertSucceeds(push(ref(db('b'), 'partidas/v1/gestos'), { de: 'b', g: 'saludo', t: ts() }));
  await assertSucceeds(remove(ref(db('a'), 'abiertas/v1')));
  await assertSucceeds(remove(ref(db('b'), 'partidas/v1')));
});

test('reloj: pulsaciones con la hora del servidor, tras su jugada', async () => {
  await env.clearDatabase();
  await game('p1');
  await assertSucceeds(set(ref(db('a'), 'partidas/p1/jugadas/0'), 'e2e4'));
  await assertFails(set(ref(db('a'), 'partidas/p1/pulsos/0'), 123));
  await assertSucceeds(set(ref(db('a'), 'partidas/p1/pulsos/0'), ts()));
  await assertFails(set(ref(db('a'), 'partidas/p1/pulsos/0'), ts()));
  // Pulsar sin jugada: no.
  await assertFails(set(ref(db('b'), 'partidas/p1/pulsos/1'), ts()));
  // Jugada y pulsación a la vez (pulsado automático).
  await assertSucceeds(update(ref(db('b'), 'partidas/p1'), { 'jugadas/1': 'e7e5', 'pulsos/1': ts() }));
  const snap = await get(ref(db('a'), 'partidas/p1/pulsos'));
  assert.equal(Object.keys(snap.val()).length, 2);
});

test('fin por tiempo: lo apunta uno y después no se juega', async () => {
  await env.clearDatabase();
  await game('p1');
  await assertSucceeds(set(ref(db('a'), 'partidas/p1/jugadas/0'), 'e2e4'));
  await assertFails(set(ref(db('c'), 'partidas/p1/fin'), { tipo: 'tiempo', pierde: 1, de: 'c', t: ts() }));
  await assertFails(set(ref(db('b'), 'partidas/p1/fin'), { tipo: 'tiempo', pierde: 2, de: 'b', t: ts() }));
  await assertFails(set(ref(db('b'), 'partidas/p1/fin'), { tipo: 'tiempo', pierde: 0, de: 'a', t: ts() }));
  await assertSucceeds(set(ref(db('b'), 'partidas/p1/fin'), { tipo: 'tiempo', pierde: 0, de: 'b', t: ts() }));
  await assertFails(set(ref(db('a'), 'partidas/p1/fin'), { tipo: 'tiempo', pierde: 1, de: 'a', t: ts() }));
  await assertFails(set(ref(db('b'), 'partidas/p1/jugadas/1'), 'e7e5'));
  await assertFails(set(ref(db('a'), 'partidas/p1/pulsos/0'), ts()));
  // Al terminar, cualquiera de los dos la borra.
  await assertSucceeds(remove(ref(db('b'), 'partidas/p1')));
});

test('«Sigo aquí», fin por abandono y gesto «¡Tu tiempo!»', async () => {
  await env.clearDatabase();
  await game('p1', '0+0');
  await assertSucceeds(set(ref(db('a'), 'partidas/p1/jugadas/0'), 'e2e4'));
  // «Sigo aquí»: cada uno el suyo, con la hora del servidor, y nadie de fuera.
  await assertSucceeds(set(ref(db('b'), 'partidas/p1/sigo/b'), ts()));
  await assertSucceeds(set(ref(db('b'), 'partidas/p1/sigo/b'), ts()));
  await assertFails(set(ref(db('b'), 'partidas/p1/sigo/a'), ts()));
  await assertFails(set(ref(db('b'), 'partidas/p1/sigo/b'), 123));
  await assertFails(set(ref(db('c'), 'partidas/p1/sigo/c'), ts()));
  // Gesto nuevo.
  await assertSucceeds(push(ref(db('a'), 'partidas/p1/gestos'), { de: 'a', g: 'tiempo', t: ts() }));
  await assertFails(push(ref(db('a'), 'partidas/p1/gestos'), { de: 'a', g: 'prisa', t: ts() }));
  // A gana por abandono de B; después, ni jugadas ni «sigo».
  await assertFails(set(ref(db('a'), 'partidas/p1/fin'), { tipo: 'otro', pierde: 1, de: 'a', t: ts() }));
  await assertSucceeds(set(ref(db('a'), 'partidas/p1/fin'), { tipo: 'abandono', pierde: 1, de: 'a', t: ts() }));
  await assertFails(set(ref(db('b'), 'partidas/p1/jugadas/1'), 'e7e5'));
  await assertFails(set(ref(db('b'), 'partidas/p1/sigo/b'), ts()));
  await assertSucceeds(remove(ref(db('a'), 'partidas/p1')));
});

test('denuncias: se escriben, no se leen', async () => {
  await env.clearDatabase();
  await assertSucceeds(push(ref(db('a'), 'denuncias'), { de: 'a', contra: 'b', nombre: 'Pepe', partida: 'p1', motivo: 'trampas', t: ts() }));
  await assertFails(push(ref(db('a'), 'denuncias'), { de: 'b', contra: 'c', motivo: 'trampas', t: ts() }));
  await assertFails(push(ref(db('a'), 'denuncias'), { de: 'a', contra: 'b', motivo: 'insultos', t: ts() }));
  await assertFails(push(ref(db('a'), 'denuncias'), { de: 'a', contra: 'b', motivo: 'otro', t: ts(), extra: 1 }));
  await assertFails(get(ref(db('a'), 'denuncias')));
  await assertFails(get(ref(db('a'), 'vetados')));
});

test('vetados: no pueden abrir ni unirse', async () => {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await set(ref(ctx.database(), 'vetados/c'), true);
  });
  await assertFails(update(ref(db('c'), 'espera/v1'), { creador: 'c', latido: ts(), ritmo: '5+3' }));
  await assertFails(update(ref(db('c'), 'partidas/v1'), { creador: 'c', ritmo: '5+3' }));
  await assertSucceeds(update(ref(db('a'), 'partidas/v2'), { creador: 'a', ritmo: '5+3' }));
  await assertFails(update(ref(db('c'), 'partidas/v2'), { rival: 'c', unidoEn: ts() }));
  await assertSucceeds(update(ref(db('b'), 'partidas/v2'), { rival: 'b', unidoEn: ts() }));
});
