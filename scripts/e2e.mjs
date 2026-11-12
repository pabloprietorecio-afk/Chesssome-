// Prueba de extremo a extremo con Chrome sin interfaz: recorre el test y algunos problemas de entrenamiento,
// alternando aciertos y fallos, y guarda capturas. Uso: node scripts/e2e.mjs [ancho] [alto] [prefijo]
import puppeteer from 'puppeteer-core';
import { mkdirSync } from 'node:fs';

const W = Number(process.argv[2] ?? 1200);
const H = Number(process.argv[3] ?? 900);
const prefix = process.argv[4] ?? 'desk';
const out = new URL('../shots/', import.meta.url).pathname;
mkdirSync(out, { recursive: true });

const browser = await puppeteer.launch({ executablePath: '/usr/bin/google-chrome', headless: 'new', args: ['--no-sandbox', '--disable-gpu-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage();
await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
await page.goto('file://' + new URL('../dist/chessome.html', import.meta.url).pathname);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const clickText = async (text) => {
  const ok = await page.evaluate((t) => {
    const el = [...document.querySelectorAll('button')].find((b) => b.textContent.trim().startsWith(t));
    if (el) el.click();
    return !!el;
  }, text);
  if (!ok) throw new Error('No encuentro el botón: ' + text);
};
const shot = (name) => page.screenshot({ path: `${out}${prefix}-${name}.png` });

async function clickSquare(sq, orientation) {
  const box = await page.evaluate(() => { const r = document.querySelector('.cm-board svg').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width }; });
  const f = sq.charCodeAt(0) - 97, r = Number(sq[1]) - 1, s = box.w / 8;
  const col = orientation === 'w' ? f : 7 - f, row = orientation === 'w' ? 7 - r : r;
  await page.mouse.click(box.x + col * s + s / 2, box.y + row * s + s / 2);
}

async function playMove(uci, orientation) {
  await clickSquare(uci.slice(0, 2), orientation);
  await sleep(120);
  await clickSquare(uci.slice(2, 4), orientation);
  if (uci.length === 5) {
    await sleep(200);
    await page.evaluate((p) => { const b = document.querySelector(`.cm-promo button[aria-label="${p}"]`); if (b) b.click(); }, { q: 'dama', r: 'torre', b: 'alfil', n: 'caballo' }[uci[4]]);
  }
}

/** Resuelve el problema visible. Si `fail` es true, juega la peor jugada legal en el primer punto. */
async function solveCurrent(fail) {
  await page.waitForSelector('.cm-puzzle[data-stage="solving"]', { timeout: 8000 });
  for (;;) {
    const st = await page.evaluate(() => {
      const el = document.querySelector('.cm-puzzle');
      const p = window.__chessome.puzzle(el.dataset.puzzleId);
      const k = Number(el.dataset.point);
      const pt = p.points[k];
      return { stage: el.dataset.stage, k, sol: pt.solution, worst: pt.evals[pt.evals.length - 1].uci, turn: p.points[0].fen.split(' ')[1], n: p.points.length };
    });
    if (st.stage === 'feedback') return;
    if (st.stage !== 'solving') { await sleep(150); continue; }
    await playMove(fail ? st.worst : st.sol, st.turn);
    if (fail) break;
    await sleep(900);
    const stage = await page.evaluate(() => document.querySelector('.cm-puzzle').dataset.stage);
    if (stage === 'feedback' || st.k === st.n - 1) break;
  }
  await page.waitForSelector('.cm-puzzle[data-stage="feedback"]', { timeout: 8000 });
}

try {
await shot('01-welcome');
await clickText('Empezar');
await sleep(200);
await shot('02-experience');
await clickText('Juego de vez en cuando');
await sleep(1200);
await shot('03-placement-start');
let i = 0;
while (await page.evaluate(() => !!document.querySelector('.cm-puzzle'))) {
  await solveCurrent(i % 3 === 2);
  if (i === 2) await shot('04-placement-fail');
  await clickText('Siguiente');
  await sleep(300);
  i++;
  if (i > 14) break;
}
await shot('05-placement-result');
await clickText('Empezar a entrenar');
await sleep(1200);
for (let k = 0; k < 6; k++) {
  await solveCurrent(k % 2 === 0);
  await sleep(300);
  const fb = await page.evaluate(() => document.querySelector('.cm-why') ? 'explained' : 'plain');
  if (fb === 'explained') {
    await shot(`06-train-${k}-n1`);
    await clickText('Explícame por qué'); await sleep(250); await shot(`06-train-${k}-n2`);
    await clickText('Ver la variante'); await sleep(250);
    await page.evaluate(() => { const b = document.querySelector('.cm-stepper button[aria-label="Jugada siguiente"]'); b && b.click(); });
    await sleep(450); await shot(`06-train-${k}-n3`);
    await clickText('Ver el análisis'); await sleep(250); await shot(`06-train-${k}-n4`);
  } else {
    await shot(`06-train-${k}-plain`);
  }
  await clickText('Siguiente');
  await sleep(500);
}
const state = await page.evaluate(() => { const s = window.__chessome.getState(); return { rating: s.rating, trials: s.trials.length, events: s.events.length, placement: s.placement.attempts.length, fb: s.trials.map((t) => t.phase[0] + (t.correct ? '+' : '-') + t.feedback[0] + t.whyDepth).join(' ') }; });
await clickText('Progreso'); await sleep(300); await shot('07-profile');
await clickText('Estudio'); await sleep(300); await shot('08-study');
console.log(JSON.stringify({ state, errors }, null, 1));
} catch (e) {
  console.log('FALLO:', e.message);
  console.log(JSON.stringify(errors, null, 1).slice(0, 3000));
  await shot('99-failure');
}
await browser.close();
