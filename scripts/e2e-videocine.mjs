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
  // Para probar los caminos «sin marcas», el clip se deja sin marcas en este dispositivo.
  localStorage.setItem('chessome.clipMarks.v1', JSON.stringify({ 'ding-gukesh-2024-g14': { start: null, end: null, stops: [null], duration: null } }));
});
await page.reload();

// ── A. Sin marcas: directo a la pregunta. No se carga nada de YouTube hasta pedir el vídeo. ──
await page.waitForSelector('.vc-card');
await shot('01-cartelera');
await page.click('.vc-card[data-clip="ding-gukesh-2024-g14"]');
await page.waitForSelector('.vc[data-phase="idle"]');
assert(!(await hasButton('Ver el vídeo: se para')), 'sin marcas no debe ofrecerse la pausa automática');
await shot('02-clip-sin-marcas');
// El botón ▶ del cartel carga el vídeo aunque no haya marcas: se ve entero y la pregunta queda a un toque.
assert(ytRequests.length === 0, 'no debe pedirse nada a YouTube antes de pulsar ▶');
await page.click('.vc-play');
await waitAttr('phase', 'reveal');
await waitAttr('player', 'ready');
assert(/Vídeo sin pausas/.test(await panel()), 'debe avisar de que no hay pausa: ' + (await panel()));
await page.evaluate(() => window.scrollTo(0, 0));
await shot('02b-video-sin-pausas');
await clickText('Ir a la pregunta');
await waitAttr('phase', 'asking');
await clickText('Volver a la cartelera');
await page.click('.vc-card[data-clip="ding-gukesh-2024-g14"]');
await page.waitForSelector('.vc[data-phase="idle"]');
ytRequests.length = 0;
await clickText('Ir directo a la pregunta');
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
await clickText('Poner las pausas estimadas');
await sleep(150);
const sugg = await page.$eval('.vc-mark[data-mark="0"] .vc-mark-head strong', (e) => e.textContent);
assert(sugg === '214.00 s', 'pausa estimada: ' + sugg);
await page.evaluate(() => document.querySelector('.vc-clock')?.scrollIntoView({ block: 'start' }));
await sleep(200);
await shot('08b-relojes');
await setTime(2); await markNow('start');
await setTime(8.4); await markNow('0');
await setTime(95); await markNow('end');
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

// ── E. Con las marcas del paquete (sin marcas locales): se para en 215,47 s, antes de 55…Txf2. ──
await page.evaluate(() => localStorage.removeItem('chessome.clipMarks.v1'));
await clickText('Volver a la cartelera');
await page.click('.vc-card[data-clip="ding-gukesh-2024-g14"]');
await page.waitForSelector('.vc[data-phase="idle"]');
await clickText('Ver el vídeo: se para');
await waitAttr('phase', 'watching');
await waitAttr('player', 'ready');
const cued = await fake(() => window.__fakeYT.last().time);
assert(Math.abs(cued - 200) < 0.5, `el clip debe empezar en 200 s (está en ${cued})`);
await fake(() => window.__fakeYT.tapPlay());
await waitAttr('phase', 'asking', 25000);
const packPause = await fake(() => window.__fakeYT.last().time);
assert(packPause >= 215.47 - 0.13 && packPause <= 215.47 + 0.2, `la pausa del paquete cayó en ${packPause}`);

console.log(errors.length ? 'ERRORES:\n' + errors.join('\n') : 'Sin errores de consola');
console.log('Clip con las marcas del paquete: empieza en', cued.toFixed(2), 's y se para en', packPause.toFixed(2), 's (marca 215,47).');
console.log('Pausa automática en', paused.time.toFixed(2), 's (marca 8,40). Prueba del editor en', tested, 's. Reproductor', Math.round(geom.w) + '×' + Math.round(geom.h), 'px.');
await browser.close();
server.close();
if (errors.length) process.exit(1);
