// Prueba en Chrome sin interfaz de las películas GENERADAS del «Cine de finales» (aparcadas: solo se
// ven con el interruptor de desarrollo chessome.dev.generatedFilms): cartelera, reproducción, pausas y final.
// Uso: node scripts/e2e-cine.mjs [ancho] [alto] [prefijo]   (antes: npm run build:single)
import puppeteer from 'puppeteer-core';
import { mkdirSync } from 'node:fs';

const W = Number(process.argv[2] ?? 390);
const H = Number(process.argv[3] ?? 844);
const prefix = process.argv[4] ?? 'cine';
const out = new URL('../shots/', import.meta.url).pathname;
mkdirSync(out, { recursive: true });
const browser = await puppeteer.launch({ executablePath: '/usr/bin/google-chrome', headless: 'new', args: ['--no-sandbox'] });
const page = await browser.newPage();
await page.setViewport({ width: W, height: H, deviceScaleFactor: 2 });
if (process.env.COLOR_SCHEME) await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: process.env.COLOR_SCHEME }]);
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
// Las fuentes de Google no se alcanzan en entornos sin red: no cuentan como fallo de la app.
page.on('console', (m) => { if (m.type() === 'error' && !m.text().includes('ERR_TUNNEL_CONNECTION_FAILED') && !m.text().includes('ERR_NAME_NOT_RESOLVED')) errors.push(m.text()); });
const url = 'file://' + new URL('../dist/chessome.html', import.meta.url).pathname;
await page.goto(url);
// Jugador ya situado: se salta el test inicial.
await page.evaluate((anim) => {
  localStorage.setItem('chessome.dev.generatedFilms', '1');
  localStorage.setItem('chessome.v1', JSON.stringify({
    version: 1, seed: 'e2ecine', createdAt: Date.now(), screen: 'home', experience: 'some',
    placement: { done: true }, rating: { r: 1450, rd: 90, vol: 0.06 }, trials: [], events: [], reviews: [], themeFeedback: {},
    settings: { theme: 'auto', board: '2d', anim, studyAlternateBoard: false, coordinates: true, sound: false }, surveysDone: [],
  }));
}, process.env.ANIM ?? 'fast');
await page.reload();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const shot = (name) => page.screenshot({ path: `${out}${prefix}-${name}.png` });
const click = async (sel) => { await page.waitForSelector(sel, { timeout: 8000 }); await page.click(sel); };
const clickText = async (t) => {
  const ok = await page.evaluate((t) => { const b = [...document.querySelectorAll('button')].find((x) => x.textContent.trim().startsWith(t)); b?.click(); return !!b; }, t);
  if (!ok) throw new Error('No encuentro el botón: ' + t);
};
const phase = () => page.$eval('.cine', (e) => e.dataset.phase);
const waitPhase = async (p, ms = 60000) => { const t = Date.now(); while ((await phase()) !== p) { if (Date.now() - t > ms) throw new Error(`No llega la fase ${p} (está en ${await phase()})`); await sleep(150); } };
async function move(uci, orientation = 'w') {
  const box = await page.evaluate(() => { const r = document.querySelector('.cine-board svg').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width }; });
  const sq = async (s) => { const f = s.charCodeAt(0) - 97, r = Number(s[1]) - 1, z = box.w / 8; const c = orientation === 'w' ? f : 7 - f, w = orientation === 'w' ? 7 - r : r; await page.mouse.click(box.x + c * z + z / 2, box.y + w * z + z / 2); };
  await sq(uci.slice(0, 2)); await sleep(150); await sq(uci.slice(2, 4));
  if (uci[4]) { await sleep(250); await page.evaluate((p) => document.querySelector(`.cm-promo button[aria-label="${p}"]`)?.click(), { q: 'dama', r: 'torre' }[uci[4]]); }
  await sleep(300);
}

await page.waitForSelector('.cine-entry');
await shot('01-home');
await click('.cine-entry');
await page.waitForSelector('.vc-card');
await clickText('Películas generadas');
await page.waitForSelector('.cine-poster');
await shot('02-cartelera');
await click('.cine-poster[data-film="saavedra"]');
await shot('03-cartel');
await clickText('▶');
await sleep(2600);
await shot('04-rotulo');
await waitPhase('question');
await shot('05-pausa-1');
await move('b6c5');
await waitPhase('answered');
const t1 = await page.$eval('.cine-answer', (e) => e.textContent);
if (!/No es esa/.test(t1)) throw new Error('Esperaba «No es esa» tras Rc5: ' + t1);
await shot('06-respuesta-mala');
await clickText('Continuar');
await waitPhase('question');
await shot('07-pausa-2');
await clickText('Pista');
await move('c7c8r');
await waitPhase('answered');
const t2 = await page.$eval('.cine-answer', (e) => e.textContent);
if (!/¡Esa es!/.test(t2)) throw new Error('Esperaba «¡Esa es!» tras c8=T: ' + t2);
await shot('08-respuesta-buena');
await clickText('Continuar');
await waitPhase('end');
await shot('09-fin');
// Philidor: las negras abajo y una jugada que pierde.
await clickText('Volver a la cartelera');
await click('.cine-poster[data-film="philidor"]');
await clickText('▶');
await waitPhase('question');
await move('b6e6', 'b');
await waitPhase('answered');
const t3 = await page.$eval('.cine-answer', (e) => e.textContent);
if (!/pierde/.test(t3)) throw new Error('Esperaba «pierde» tras Txe6: ' + t3);
await shot('10-philidor');
console.log(errors.length ? 'ERRORES:\n' + errors.join('\n') : 'Sin errores de consola');
console.log({ t1, t2, t3 });
await browser.close();
if (errors.length) process.exit(1);
