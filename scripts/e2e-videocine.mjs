// Prueba en Chrome sin interfaz del «Cine de finales» con vídeo.
// YouTube no es accesible desde los entornos de prueba, así que su API se sustituye por una simulación
// con las mismas funciones (playVideo, pauseVideo, seekTo, cueVideoById, getCurrentTime, getDuration,
// getPlayerState y los eventos onReady y onError). Esto comprueba NUESTRO código (director, pantalla y
// editor de marcas), no el comportamiento real de YouTube: eso hay que probarlo en una web publicada.
// Uso: npm run build:single && node scripts/e2e-videocine.mjs [ancho] [alto] [prefijo]
import puppeteer from 'puppeteer-core';
import { createServer } from 'node:http';
import { mkdirSync, readFileSync } from 'node:fs';

const W = Number(process.argv[2] ?? 390);
const H = Number(process.argv[3] ?? 844);
const prefix = process.argv[4] ?? 'video';
const out = new URL('../shots/', import.meta.url).pathname;
mkdirSync(out, { recursive: true });

const html = readFileSync(new URL('../dist/chessome.html', import.meta.url));
const server = createServer((_, res) => { res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); res.end(html); });
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}/`;

const FAKE_API = `(() => {
  const players = [];
  class Player {
    constructor(el, opts) {
      this.el = el; this.events = (opts && opts.events) || {}; this.state = 5; this.time = 0;
      const m = /[?&]start=(\\d+)/.exec(el.src || ''); if (m) this.time = Number(m[1]);
      this.src = el.src; players.push(this);
      this.timer = setInterval(() => { if (this.state === 1) this.time += 0.05 * window.__fakeYT.rate; }, 50);
      setTimeout(() => this.events.onReady && this.events.onReady({ target: this }), 150);
    }
    playVideo() { this.state = 1; window.__fakeYT.calls.push('play'); }
    pauseVideo() { if (this.state !== 0) this.state = 2; window.__fakeYT.calls.push('pause@' + this.time.toFixed(2)); }
    seekTo(s) { this.time = s; window.__fakeYT.calls.push('seek@' + s); }
    cueVideoById(o) { this.time = o.startSeconds || 0; this.state = 5; window.__fakeYT.calls.push('cue@' + this.time); }
    getCurrentTime() { return window.__fakeYT.ad ? 3 : this.time; }
    getDuration() { return window.__fakeYT.ad ? 15 : window.__fakeYT.duration; }
    getPlayerState() { return this.state; }
    destroy() { clearInterval(this.timer); this.el.remove(); }
  }
  window.__fakeYT = { players, calls: [], duration: 437, rate: 1, ad: false,
    last() { return players[players.length - 1]; },
    tapPlay() { this.last().state = 1; }, tapPause() { this.last().state = 2; },
    error(code) { const p = this.last(); p.events.onError && p.events.onError({ data: code }); } };
  window.YT = { Player };
  setTimeout(() => window.onYouTubeIframeAPIReady && window.onYouTubeIframeAPIReady(), 60);
})();`;

const browser = await puppeteer.launch({ executablePath: '/usr/bin/google-chrome', headless: 'new', args: ['--no-sandbox'] });
const page = await browser.newPage();
await page.setViewport({ width: W, height: H, deviceScaleFactor: 2 });
if (process.env.COLOR_SCHEME) await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: process.env.COLOR_SCHEME }]);
const errors = [];
const ytRequests = [];
await page.setRequestInterception(true);
page.on('request', (req) => {
  const u = req.url();
  if (u.startsWith('https://www.youtube.com/iframe_api')) { ytRequests.push(u); return req.respond({ status: 200, contentType: 'text/javascript', body: FAKE_API }); }
  if (u.startsWith('https://www.youtube-nocookie.com/embed/')) {
    ytRequests.push(u);
    return req.respond({ status: 200, contentType: 'text/html', body: '<meta charset="utf-8"><body style="margin:0;background:#101418;color:#9fb0c8;font:16px sans-serif;display:grid;place-items:center;height:100vh">Vídeo simulado</body>' });
  }
  if (u.startsWith(base) || u.startsWith('data:') || u.startsWith('blob:')) return req.continue();
  return req.abort();
});
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error' && !/ERR_FAILED|ERR_TUNNEL|ERR_NAME_NOT_RESOLVED|Failed to load resource/.test(m.text())) errors.push(m.text()); });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const shot = (name) => page.screenshot({ path: `${out}${prefix}-${name}.png` });
const assert = (cond, msg) => { if (!cond) throw new Error('FALLO: ' + msg); };
const clickText = async (t) => {
  const ok = await page.evaluate((t) => { const b = [...document.querySelectorAll('button')].find((x) => x.textContent.trim().startsWith(t) && !x.disabled); b?.click(); return !!b; }, t);
  if (!ok) throw new Error('No encuentro el botón: ' + t);
};
const hasButton = (t) => page.evaluate((t) => [...document.querySelectorAll('button')].some((x) => x.textContent.trim().startsWith(t)), t);
const attr = (name) => page.$eval('.vc', (e, n) => e.dataset[n], name);
const waitAttr = async (name, value, ms = 20000) => { const t = Date.now(); while ((await attr(name)) !== String(value)) { if (Date.now() - t > ms) throw new Error(`No llega ${name}=${value} (está en ${await attr(name)})`); await sleep(80); } };
const panel = () => page.$$eval('.vc-panel', (els) => els.map((e) => e.textContent).join(' | '));
const fake = (fn, ...args) => page.evaluate(fn, ...args);
async function move(uci, orientation = 'b') {
  const box = await page.evaluate(() => { const r = document.querySelector('.vc-board svg').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width }; });
  const sq = async (s) => { const f = s.charCodeAt(0) - 97, r = Number(s[1]) - 1, z = box.w / 8; const c = orientation === 'w' ? f : 7 - f, w = orientation === 'w' ? 7 - r : r; await page.mouse.click(box.x + c * z + z / 2, box.y + w * z + z / 2); };
  await sq(uci.slice(0, 2)); await sleep(150); await sq(uci.slice(2, 4)); await sleep(350);
}
// Tras desplazar se espera a que termine el desplazamiento suave de la propia app antes de medir el tablero.
// En la cartelera, cada clip tiene «Comenzar» y «Ir directo a la pregunta».
const openClip = (label) => page.evaluate((t) => [...document.querySelectorAll('.vc-card[data-clip="ding-gukesh-2024-g14"] button')].find((b) => b.textContent.trim().startsWith(t)).click(), label);
const cardText = () => page.$eval('.vc-card[data-clip="ding-gukesh-2024-g14"]', (e) => e.textContent);
const scrollTo = async (sel) => { await sleep(500); await page.evaluate((s) => document.querySelector(s)?.scrollIntoView({ block: 'center' }), sel); await sleep(350); };

// ── 0. Enlace directo …/#cine sin haber hecho el test de nivel. ──
await page.goto(base + '#cine');
await page.waitForSelector('.vc-card', { timeout: 10000 });
await page.evaluate(() => localStorage.clear());
await page.goto(base);
await page.waitForSelector('.cine-entry', { timeout: 10000 }); // también desde la bienvenida
await page.evaluate(() => {
  localStorage.setItem('chessome.v1', JSON.stringify({
    version: 1, seed: 'e2evideo', createdAt: Date.now(), screen: 'cinema', experience: 'some',
    placement: { done: true }, rating: { r: 1450, rd: 90, vol: 0.06 }, trials: [], events: [], reviews: [], themeFeedback: {},
    settings: { theme: 'auto', board: '2d', anim: 'fast', studyAlternateBoard: false, coordinates: true, sound: false }, surveysDone: [],
  }));
  // Para probar los caminos «sin marcas» y el editor, se permiten marcas locales aunque el clip esté verificado
  // y el clip se deja sin marcas en este dispositivo.
  localStorage.setItem('chessome.dev.localMarks', '1');
  localStorage.setItem('chessome.clipMarks.v1', JSON.stringify({ 'ding-gukesh-2024-g14': { start: null, end: null, stops: [null], duration: null } }));
});
await page.reload();

// ── A. Sin marcas: directo a la pregunta. No se carga nada de YouTube hasta pedir el vídeo. ──
await page.waitForSelector('.vc-card');
await shot('01-cartelera');
assert(/Sin pausa marcada/.test(await cardText()), 'sin marcas, la tarjeta debe decir que el vídeo se ve entero: ' + (await cardText()));
// «Comenzar» carga el vídeo aunque no haya marcas: se ve entero y la pregunta queda a un toque.
assert(ytRequests.length === 0, 'no debe pedirse nada a YouTube antes de pulsar «Comenzar»');
await openClip('Comenzar');
await waitAttr('phase', 'reveal');
await waitAttr('player', 'ready');
assert(/Vídeo sin pausas/.test(await panel()), 'debe avisar de que no hay pausa: ' + (await panel()));
await page.evaluate(() => window.scrollTo(0, 0));
await shot('02b-video-sin-pausas');
await clickText('Ir a la pregunta');
await waitAttr('phase', 'asking');
await clickText('Volver a la cartelera');
await page.waitForSelector('.vc-card');
ytRequests.length = 0;
await openClip('Ir directo a la pregunta');
await waitAttr('phase', 'asking');
assert(ytRequests.length === 0, 'no debe pedirse nada a YouTube antes de elegir ver el vídeo');
await sleep(900);
await shot('03-pregunta-1');
await scrollTo('.vc-board');
await move('b2b1');
assert(/No es esa/.test(await panel()), 'Tb1+ debe darse por mala: ' + (await panel()));
await page.evaluate(() => document.querySelector('.vc-answer')?.scrollIntoView({ block: 'start' }));
await sleep(200);
await shot('04-respuesta-mala');
// «Repetir»: vuelve a la posición de la pregunta y deja probar otra jugada.
await clickText('Repetir');
await sleep(300);
assert(await page.$('.vc-ask .vc-question'), 'tras «Repetir» debe volver la pregunta');
assert(!(await hasButton('Repetir')), 'sin respuesta no hay «Repetir»');
await move('b2f2');
assert(/¡Esa es!/.test(await panel()), 'tras repetir, Txf2 debe darse por buena: ' + (await panel()));
assert(!(await hasButton('Repetir')), 'con la buena no se ofrece «Repetir»');
await clickText('Siguiente pregunta');
await waitAttr('question', 1);
await sleep(300);
await move('e6d5');
assert(/¡Esa es!/.test(await panel()), 'Ad5 debe ser la buena: ' + (await panel()));
await clickText('Siguiente pregunta');
await waitAttr('question', 2, 12000);
await sleep(300);
await shot('05-pregunta-3');
await move('d5e5');
assert(/¡Esa es!/.test(await panel()), 'Re5 debe ser la buena: ' + (await panel()));
await clickText('Ver cómo ocurrió en el vídeo');
await waitAttr('phase', 'reveal');
await waitAttr('player', 'ready');
assert(ytRequests.some((u) => u.includes('youtube-nocookie.com/embed/W9JtcW_0Sr8')), 'el vídeo debe cargarse en modo de privacidad mejorada');
assert(/Pulsa ▶ en el vídeo/.test(await panel()), 'debe pedirse pulsar ▶: ' + (await panel()));
assert((await fake(() => window.__fakeYT.last().state)) !== 1, 'el vídeo no debe arrancar solo en modo directo');
await fake(() => window.__fakeYT.tapPlay());
await sleep(400);
assert(/En la partida se jugó Re5/.test(await panel()), 'texto de revelación: ' + (await panel()));
await page.evaluate(() => window.scrollTo(0, 0));
await shot('06-revelacion');
// Nada delante del reproductor y tamaño mínimo de 200 × 200.
const geom = await page.evaluate(() => {
  const f = document.querySelector('.vc-player iframe'); const r = f.getBoundingClientRect();
  const top = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2);
  const corner = document.elementFromPoint(r.x + 3, r.y + 3);
  return { w: r.width, h: r.height, centerIsIframe: top === f, cornerIsIframe: corner === f };
});
assert(geom.w >= 200 && geom.h >= 200, `reproductor demasiado pequeño: ${geom.w}×${geom.h}`);
assert(geom.centerIsIframe && geom.cornerIsIframe, 'hay algo dibujado delante del reproductor');
await clickText('Terminar');
await waitAttr('phase', 'ended');
await scrollTo('.vc-panel');
await shot('07-fin');

// ── B. Editor de marcas: marcar, probar y guardar en este dispositivo. ──
await clickText('Editor de marcas');
await page.waitForSelector('.vc-editor');
await clickText('Cargar el vídeo');
await page.waitForSelector('.vc-editor[data-player="ready"]');
const setTime = (t) => fake((t) => { const p = window.__fakeYT.last(); p.time = t; p.state = 2; }, t);
const markNow = async (key) => { await sleep(260); await page.evaluate((k) => document.querySelector(`.vc-mark[data-mark="${k}"] button`).click(), key); await sleep(120); };
// Estimación con los relojes: ancla en 55…Txf2 a los 217 s → pausa sugerida a los 214 s.
await setTime(217);
await sleep(260);
await page.evaluate(() => [...document.querySelectorAll('.vc-clock button')].find((b) => b.textContent.trim() === '= ahora').click());
await page.waitForSelector('.vc-clock-list li[data-ply="116"]');
const est = await page.$$eval('.vc-clock-list li', (els) => els.map((e) => e.textContent));
assert(est.some((t) => t.includes('58…Re5') && t.includes('293.0 s')), 'estimación de 58…Re5: ' + est.join(' | '));
await clickText('Poner las marcas estimadas');
await sleep(150);
const head = (k) => page.$eval(`.vc-mark[data-mark="${k}"] .vc-mark-head strong`, (e) => e.textContent);
const sugg = await head('0');
assert(sugg === '214.00 s', 'pausa estimada: ' + sugg);
assert((await head('start')) === '79.50 s', 'inicio estimado (5 s antes de 55.Tf2): ' + (await head('start')));
await page.evaluate(() => document.querySelector('.vc-clock')?.scrollIntoView({ block: 'start' }));
await sleep(200);
await shot('08b-relojes');
await setTime(2); await markNow('start');
await setTime(8.4); await markNow('0');
await setTime(95); await markNow('end');
// Estas marcas de prueba no son las del vídeo: se quita el tablero estimado.
await page.evaluate(() => [...document.querySelectorAll('.vc-mark[data-sync-ply="109"] button')].find((b) => b.textContent.trim() === 'Quitar').click());
await sleep(120);
await page.evaluate(() => [...document.querySelectorAll('.vc-mark[data-mark="0"] button')].find((b) => b.textContent.trim() === 'Probar').click());
await page.waitForFunction(() => /Se ha parado en/.test(document.body.textContent), { timeout: 15000 });
const tested = await page.evaluate(() => Number(/Se ha parado en ([\d.]+)/.exec(document.body.textContent)[1]));
assert(tested >= 8.4 - 0.13 && tested <= 8.4 + 0.2, `la prueba del editor paró en ${tested}`);
await page.evaluate(() => window.scrollTo(0, 0));
await shot('08-editor');
await clickText('Guardar en este dispositivo');
await sleep(200);
await clickText('Volver al clip');

// ── C. Con marcas: el vídeo se para solo antes de la jugada. ──
await page.waitForSelector('.vc[data-phase="idle"]');
assert(await hasButton('Ver el vídeo: se para'), 'con marcas debe ofrecerse la pausa automática');
await fake(() => { window.__fakeYT.calls.length = 0; });
await clickText('Ver el vídeo: se para');
await waitAttr('phase', 'watching');
await waitAttr('player', 'ready');
assert(/Pulsa ▶ en el vídeo/.test(await panel()), 'debe pedirse pulsar ▶: ' + (await panel()));
await shot('09-esperando-play');
// Un anuncio antes del vídeo: el director no debe hacer nada.
await fake(() => { window.__fakeYT.ad = true; window.__fakeYT.tapPlay(); });
await sleep(900);
assert((await attr('phase')) === 'watching', 'durante un anuncio no debe pasar nada');
assert(/Anuncio de YouTube/.test(await panel()), 'debe avisar del anuncio: ' + (await panel()));
await fake(() => { window.__fakeYT.ad = false; });
await waitAttr('phase', 'asking', 20000);
const paused = await fake(() => ({ state: window.__fakeYT.last().state, time: window.__fakeYT.last().time, calls: window.__fakeYT.calls.slice() }));
assert(paused.state === 2, 'el vídeo debe quedar en pausa');
assert(paused.time >= 8.4 - 0.13 && paused.time <= 8.4 + 0.2, `la pausa cayó en ${paused.time}, no junto a 8,4`);
await sleep(900); // la app coloca sola el vídeo arriba, con la pregunta y el tablero debajo
await shot('10-pausa-automatica');
// El jugador pulsa ▶ en el reproductor durante la pregunta: no se le vuelve a parar.
await sleep(1700);
await fake(() => window.__fakeYT.tapPlay());
await waitAttr('phase', 'reveal');
await sleep(700);
assert((await fake(() => window.__fakeYT.last().state)) === 1, 'si el jugador pulsa ▶, el vídeo debe seguir');
assert(/Has seguido viendo el vídeo/.test(await panel()), 'aviso de que siguió viendo: ' + (await panel()));
await shot('11-siguio-viendo');
await clickText('Volver a la pregunta');
await waitAttr('phase', 'asking');
await sleep(300);
assert((await fake(() => window.__fakeYT.last().state)) === 2, 'al volver a la pregunta el vídeo debe pararse');
await scrollTo('.vc-board');
await move('b2f2');
assert(/¡Esa es!/.test(await panel()), 'Txf2 debe ser la buena: ' + (await panel()));
await clickText('Siguiente pregunta');
await waitAttr('question', 1);
await clickText('Seguir viendo sin responder');
await waitAttr('phase', 'reveal');
await sleep(900);
const afterReveal = await fake(() => ({ state: window.__fakeYT.last().state, calls: window.__fakeYT.calls.slice(-3) }));
assert(afterReveal.state === 1, 'tras revelar, el vídeo debe reproducirse: ' + JSON.stringify(afterReveal));
await fake(() => { window.__fakeYT.rate = 25; });
await waitAttr('phase', 'ended', 20000);
await fake(() => { window.__fakeYT.rate = 1; });
assert((await fake(() => window.__fakeYT.last().state)) === 2, 'al acabar el clip el vídeo debe pararse');

// ── D. El vídeo deja de estar disponible: la pregunta sigue funcionando. ──
await clickText('Otra vez');
await waitAttr('phase', 'watching');
await waitAttr('player', 'ready');
await fake(() => window.__fakeYT.error(150));
await waitAttr('phase', 'asking');
await page.evaluate(() => window.scrollTo(0, 0));
await sleep(200);
assert(await page.evaluate(() => /no permite ver este vídeo fuera de YouTube/.test(document.querySelector('.vc-poster')?.textContent ?? '')), 'debe explicarse el error');
assert(await page.evaluate(() => !!document.querySelector('.vc-poster a[href*="youtube.com/watch?v=W9JtcW_0Sr8"]')), 'debe haber enlace a YouTube');
await shot('12-video-no-disponible');

// ── E. Marcas del paquete, estimadas con los relojes y verificadas. En este dispositivo quedan las marcas
// antiguas de Pablo (inicio 3:20), guardadas sobre otra versión del clip: deben ignorarse. ──
await page.evaluate(() => {
  localStorage.removeItem('chessome.dev.localMarks');
  localStorage.setItem('chessome.clipMarks.v1', JSON.stringify({ 'ding-gukesh-2024-g14': { start: 200.14, end: 233.07, stops: [215.47], duration: 437 } }));
});
await clickText('Volver a la cartelera');
await page.waitForSelector('.vc-card');
assert(/Se para solo antes de la jugada$/.test(await page.$eval('.vc-card[data-clip="ding-gukesh-2024-g14"] .vc-chip', (e) => e.textContent)), 'el clip debe figurar con pausa automática verificada');
assert(/versión anterior del clip/.test(await cardText()), 'debe avisar de que las marcas antiguas del dispositivo ya no se usan: ' + (await cardText()));
await page.evaluate(() => window.scrollTo(0, 0));
await shot('01b-cartelera-con-pausa');
await openClip('Comenzar');
await waitAttr('phase', 'watching');
assert(!(await hasButton('Editor de marcas')), 'un clip verificado y con tablero no ofrece el editor');

// ── F. El ancla de Pablo (55…Txf2: reloj en 2:21) reproduce las marcas del paquete; el tablero sigue al vídeo.
// El editor de un clip verificado solo se abre con el interruptor de desarrollo. ──
await page.evaluate(() => { localStorage.removeItem('chessome.clipMarks.v1'); localStorage.setItem('chessome.dev.localMarks', '1'); });
await clickText('Volver a la cartelera');
await page.waitForSelector('.vc-card');
await openClip('Comenzar');
await waitAttr('phase', 'watching');
await clickText('Editor de marcas');
await page.waitForSelector('.vc-editor .vc-sync');
assert(await page.$('.vc-mark[data-mark="start"]'), 'con el interruptor se editan también inicio, pausas y fin');
assert(!(await page.$('.vc-clock .vc-warn')), 'no debe avisar de cortes: no se sabe si los hay');
const before = await page.$eval('.vc-json', (e) => e.value);
await clickText('Cargar el vídeo');
await page.waitForSelector('.vc-editor[data-player="ready"]');
const markPly = async (p) => { await sleep(260); await page.evaluate((p) => document.querySelector(`.vc-mark[data-sync-ply="${p}"] button`).click(), p); await sleep(150); };
const syncButton = (p, t) => page.evaluate((p, t) => [...document.querySelectorAll(`.vc-mark[data-sync-ply="${p}"] button`)].find((b) => b.textContent.trim() === t).click(), p, t);
const warnings = () => page.$$eval('.vc-warn', (els) => els.map((e) => e.textContent).join(' | '));
const saveDisabled = () => page.evaluate(() => [...document.querySelectorAll('button')].find((b) => b.textContent.trim() === 'Guardar en este dispositivo').disabled);
const syncTimes = () => page.$$eval('.vc-mark[data-sync-ply]', (els) => Object.fromEntries(els.map((e) => [e.dataset.syncPly, e.querySelector('strong').textContent])));
const previewPly = () => page.$eval('.vc-sync-preview', (e) => e.dataset.ply);
await setTime(141);
await sleep(260);
await page.evaluate(() => [...document.querySelectorAll('.vc-clock button')].find((b) => b.textContent.trim() === '= ahora').click());
await page.waitForSelector('.vc-clock-list li[data-ply="116"]');
await clickText('Poner las marcas estimadas');
await sleep(150);
const after = await page.$eval('.vc-json', (e) => e.value);
assert(after === before.replace(/"duration":[\d.]+/, after.match(/"duration":[\d.]+/)[0]), 'el ancla en 2:21 debe dar justo las marcas del paquete:\n' + before + '\n' + after);
assert((await head('start')) === '3.50 s' && (await head('0')) === '138.00 s' && (await head('end')) === '233.07 s', `inicio ${await head('start')}, pausa ${await head('0')}, fin ${await head('end')}`);
let times = await syncTimes();
assert(times['109'] === '8.50 s' && times['110'] === '140.50 s' && times['111'] === '142.50 s' && times['116'] === '216.50 s', 'tablero estimado: ' + JSON.stringify(times));
// Destripe: 55…Txf2 no puede aparecer antes de la pausa (138 s).
await setTime(137); await markPly(110);
assert(/antes de la pausa/.test(await warnings()), 'debe avisar del destripe: ' + (await warnings()));
assert(await saveDisabled(), 'no debe dejar guardar un tablero que destripa la pregunta');
await setTime(140.5); await markPly(110);
// «Quitar» borra esa jugada y las siguientes; marcar una posterior rellena las que faltan con el mismo segundo.
await syncButton(115, 'Quitar');
await sleep(150);
times = await syncTimes();
assert(times['114'] === '156.50 s' && times['115'] === '—' && times['116'] === '—', 'quitar: ' + JSON.stringify(times));
await setTime(216.5); await markPly(116);
times = await syncTimes();
assert(times['115'] === '216.50 s' && times['116'] === '216.50 s', 'rellenar: ' + JSON.stringify(times));
await setTime(209.5); await markPly(115);
assert((await page.$eval('.vc-json', (e) => e.value)) === after, 'tras rehacer 58.Re3, las marcas deben volver a ser las del paquete');
assert((await warnings()) === '', 'no debe haber avisos: ' + (await warnings()));
for (const [t, ply] of [[5, '108'], [100, '109'], [141, '110'], [143, '111']]) {
  await setTime(t);
  await sleep(300);
  assert((await previewPly()) === ply, `vista previa en ${t} s: ${await previewPly()} (esperado ${ply})`);
}
await page.evaluate(() => document.querySelector('.vc-sync')?.scrollIntoView({ block: 'start' }));
await sleep(200);
await shot('14-editor-tablero');
await clickText('Volver al clip');
await page.waitForSelector('.vc[data-phase="idle"]');
// Pantalla útil del móvil de Pablo con el navegador abierto: unos 386 × 708 px.
await page.setViewport({ width: 386, height: 708, deviceScaleFactor: 2 });
const layout = () => page.evaluate(() => {
  const v = (document.querySelector('.vc-player iframe') || document.querySelector('.vc-video')).getBoundingClientRect();
  const b = document.querySelector('.vc-board .cm-board')?.getBoundingClientRect();
  const nav = document.querySelector('.cm-top nav');
  return { video: [Math.round(v.top), Math.round(v.bottom)], board: b ? [Math.round(b.top), Math.round(b.bottom), Math.round(b.width)] : null, h: innerHeight, nav: nav ? getComputedStyle(nav).display : 'none' };
});
const assertFits = async (what) => {
  await sleep(800); // desplazamiento suave de la app
  const l = await layout();
  assert(l.board && l.video[0] >= -1 && l.board[1] <= l.h + 1 && l.board[2] >= 270 && l.nav === 'none', `${what}: el vídeo y el tablero no caben a la vez: ${JSON.stringify(l)}`);
  return l;
};
await clickText('Ver el vídeo: se para');
await waitAttr('phase', 'watching');
await waitAttr('player', 'ready');
const fitWatching = await assertFits('viendo el vídeo');
const cued = await fake(() => window.__fakeYT.last().time);
assert(Math.abs(cued - 3.5) < 1, `el clip debe empezar en 3,5 s (está en ${cued})`);
// Mientras se ve el vídeo, debajo va el tablero del vídeo.
const boardInfo = () => page.$eval('.vc-board', (e) => ({ kind: e.dataset.board, ply: e.dataset.ply, label: e.querySelector('.vc-board-label')?.textContent ?? '' }));
const waitPly = async (ply, ms = 8000) => { const t0 = Date.now(); while ((await boardInfo()).ply !== ply) { if (Date.now() - t0 > ms) throw new Error(`El tablero no llega a ${ply}: ${JSON.stringify(await boardInfo())}`); await sleep(60); } };
let bi = await boardInfo();
assert(bi.kind === 'video' && bi.ply === '108' && /tras 54…Re5/.test(bi.label), 'tablero del vídeo al empezar: ' + JSON.stringify(bi));
await shot('13-viendo-con-tablero');
await fake(() => { window.__fakeYT.rate = 25; window.__fakeYT.tapPlay(); });
await waitPly('109');
assert(/tras 55\.Tf2/.test((await boardInfo()).label), 'Ding juega 55.Tf2 en el vídeo: ' + (await boardInfo()).label);
while ((await fake(() => window.__fakeYT.last().time)) < 125) await sleep(40);
await fake(() => { window.__fakeYT.rate = 1; });
assert((await boardInfo()).ply === '109', 'antes de la pausa, el tablero no pasa de la posición de la pregunta');
await waitAttr('phase', 'asking', 25000);
const syncPause = await fake(() => window.__fakeYT.last().time);
assert(syncPause >= 138 - 0.13 && syncPause <= 138 + 0.2, `la pausa cayó en ${syncPause}, no junto a 138`);
assert((await boardInfo()).kind === 'question', 'en la pausa, el tablero es el de la pregunta');
const fitAsking = await assertFits('en la pausa');
await shot('13b-pausa-con-tablero');
await clickText('Seguir viendo sin responder');
await waitAttr('phase', 'reveal');
await waitPly('110');
bi = await boardInfo();
assert(bi.kind === 'video' && /tras 55…Txf2/.test(bi.label), 'tras la pausa, el tablero sigue al vídeo: ' + JSON.stringify(bi));
await waitPly('111');
assert(/tras 56\.Rxf2/.test((await boardInfo()).label), 'etiqueta: ' + (await boardInfo()).label);
const fitReveal = await assertFits('al revelar');
await shot('15-tablero-sigue-al-video');
await fake(() => { window.__fakeYT.rate = 25; });
await waitAttr('phase', 'ended', 20000);
await fake(() => { window.__fakeYT.rate = 1; });
bi = await boardInfo();
assert(bi.kind === 'video' && bi.ply === '116' && /tras 58…Re5/.test(bi.label), 'al final, la última jugada marcada: ' + JSON.stringify(bi));
assert((await page.evaluate(() => document.documentElement.dataset.immersive)) === undefined, 'al acabar, vuelve la barra de secciones');
await page.setViewport({ width: W, height: H, deviceScaleFactor: 2 });

// ── G. Gukesh–Carlsen: el tablero se gira hacia quien juega y un error histórico se enseña como tal. ──
// Para probar el caso «sin marcas», este dispositivo deja el clip sin marcas (interruptor de desarrollo).
await page.evaluate(() => {
  localStorage.setItem('chessome.dev.localMarks', '1');
  localStorage.setItem('chessome.clipMarks.v1', JSON.stringify({ 'gukesh-carlsen-2025-norway-r6': { start: null, end: null, stops: [null], duration: null, sync: null } }));
});
await clickText('Volver a la cartelera');
await page.waitForSelector('.vc-card[data-clip="gukesh-carlsen-2025-norway-r6"]');
const openGC = (t) => page.evaluate((t) => [...document.querySelectorAll('.vc-card[data-clip="gukesh-carlsen-2025-norway-r6"] button')].find((b) => b.textContent.trim().startsWith(t)).click(), t);
// Sin marcas ni tablero sincronizado: el vídeo se ve entero y el aviso va justo debajo, sin hueco.
await openGC('Comenzar');
await waitAttr('phase', 'reveal');
await waitAttr('player', 'ready');
await sleep(800);
const gap = await page.evaluate(() => document.querySelector('.vc-panel').getBoundingClientRect().top - document.querySelector('.vc-video').getBoundingClientRect().bottom);
assert(gap < 80, `el aviso queda muy separado del vídeo (${Math.round(gap)} px)`);
await shot('15b-sin-marcas-sin-hueco');
await page.evaluate(() => { localStorage.removeItem('chessome.clipMarks.v1'); localStorage.removeItem('chessome.dev.localMarks'); });
await clickText('Volver a la cartelera');
assert(/Se para solo · marcas sin comprobar/.test(await page.$eval('.vc-card[data-clip="gukesh-carlsen-2025-norway-r6"] .vc-chip', (e) => e.textContent)), 'el clip lleva marcas medidas, pendientes de comprobar');
await page.waitForSelector('.vc-card[data-clip="gukesh-carlsen-2025-norway-r6"]');
await openGC('Ir directo');
await waitAttr('phase', 'asking');
await sleep(400);
await move('f4e2', 'b'); // 52…Ce2+??, lo que jugó Carlsen (negras abajo)
assert(/Fue un error en la partida/.test(await panel()), 'Ce2+ debe presentarse como error de la partida: ' + (await panel()));
await clickText('Repetir');
await sleep(300);
await clickText('Ver la respuesta');
await sleep(300);
assert(/La respuesta/.test(await panel()) && !/¡Esa es!/.test(await panel()), '«Ver la respuesta» no es «¡Esa es!»: ' + (await panel()));
await shot('16-error-historico');
await clickText('Siguiente pregunta');
await waitAttr('question', 1, 12000);
await sleep(400);
await move('c5a4', 'w'); // 57.Ca4 (blancas abajo)
assert(/¡Esa es!/.test(await panel()), '57.Ca4 debe ser la buena: ' + (await panel()));
await clickText('Siguiente pregunta');
await waitAttr('question', 2, 15000);
await sleep(400);
await move('b2c4', 'w'); // 61.Cc4+
assert(/¡Esa es!/.test(await panel()), '61.Cc4+ debe ser la buena: ' + (await panel()));
await shot('17-gukesh-carlsen-pregunta-3');

// ── H. Marcado rápido: un botón que se pulsa mientras corre el vídeo; «Saltar» y «Deshacer». ──
await page.evaluate(() => {
  // El marcado rápido se prueba desde cero: este dispositivo deja el clip sin marcas.
  localStorage.setItem('chessome.dev.localMarks', '1');
  localStorage.setItem('chessome.clipMarks.v1', JSON.stringify({ 'gukesh-carlsen-2025-norway-r6': { start: null, end: null, stops: [null], duration: null, sync: null } }));
});
await clickText('Volver a la cartelera');
await page.waitForSelector('.vc-card[data-clip="gukesh-carlsen-2025-norway-r6"]');
await openGC('Comenzar');
await waitAttr('phase', 'reveal');
await clickText('Editor de marcas');
await page.waitForSelector('.vc-quick');
await clickText('Cargar el vídeo');
await page.waitForSelector('.vc-editor[data-player="ready"]');
const quick = () => page.$eval('.vc-quick-mark', (b) => b.textContent.trim()).catch(() => null);
const tap = async (t) => { await setTime(t); await sleep(260); await page.click('.vc-quick-mark'); await sleep(150); };
assert((await quick()) === 'Empieza el clip', 'primer paso: ' + (await quick()));
await tap(2);
assert(/Pausa: justo antes de 52…Ce2\+/.test(await quick()), 'segundo paso: ' + (await quick()));
await tap(30);
await tap(31); // 52…Ce2+
await clickText('Saltar'); // 53.Txe2+ no se ve
await tap(33); // 53…Rxe2 (y 53.Txe2+ con ella)
await clickText('Deshacer');
await clickText('Deshacer');
await sleep(150);
assert(/Se ve 53\.Txe2\+/.test(await quick()), 'tras deshacer dos veces vuelve a 53.Txe2+: ' + (await quick()));
await tap(32);
await tap(33);
const qm = await page.$eval('.vc-json', (e) => JSON.parse(e.value));
assert(qm.start === 2 && qm.stops[0] === 30 && JSON.stringify(qm.sync.marks) === JSON.stringify([{ ply: 104, at: 31 }, { ply: 105, at: 32 }, { ply: 106, at: 33 }]), 'marcado rápido: ' + JSON.stringify(qm));
await page.evaluate(() => document.querySelector('.vc-quick')?.scrollIntoView({ block: 'start' }));
await sleep(200);
await shot('18-marcado-rapido');
await clickText('Empezar de nuevo');
await sleep(150);
const qr = await page.$eval('.vc-json', (e) => JSON.parse(e.value));
assert(qr.start === null && qr.stops[0] === null && qr.sync.marks.length === 0 && (await quick()) === 'Empieza el clip', 'empezar de nuevo: ' + JSON.stringify(qr));

console.log(errors.length ? 'ERRORES:\n' + errors.join('\n') : 'Sin errores de consola');
console.log('Clip con las marcas del paquete (ancla 2:21 y relojes): empieza en', cued.toFixed(2), 's, se para en', syncPause.toFixed(2), 's (marca 138) y el tablero llega a 58…Re5.');
console.log('En 386 × 708, con el vídeo a la vista: tablero de', fitWatching.board[2], 'px viendo,', fitAsking.board[2], 'px en la pausa y', fitReveal.board[2], 'px al revelar.');
console.log('Pausa automática en', paused.time.toFixed(2), 's (marca 8,40). Prueba del editor en', tested, 's. Reproductor', Math.round(geom.w) + '×' + Math.round(geom.h), 'px.');
await browser.close();
server.close();
if (errors.length) process.exit(1);
