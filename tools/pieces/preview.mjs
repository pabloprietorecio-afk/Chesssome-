// Renderiza vistas previas de una colección con Chrome sin interfaz (three.js) y las guarda en shots/.
// Uso: node tools/pieces/preview.mjs [colección] ["vista&param=valor" …]   p. ej.  clasico lineup top "one&piece=knight"
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { mkdirSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';

const root = fileURLToPath(new URL('../../', import.meta.url));
const set = process.argv[2] ?? 'clasico';
const views = process.argv.slice(3).length ? process.argv.slice(3) : ['lineup', 'top', 'game'];
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.glb': 'model/gltf-binary', '.json': 'application/json' };

const server = createServer(async (req, res) => {
  try {
    const path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname));
    const file = join(root, path);
    if (!file.startsWith(root)) throw new Error('fuera de la raíz');
    const data = await readFile(file);
    res.writeHead(200, { 'content-type': MIME[extname(file)] ?? 'application/octet-stream' });
    res.end(data);
  } catch {
    res.writeHead(404);
    res.end();
  }
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

mkdirSync(join(root, 'shots'), { recursive: true });
const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'new',
  args: ['--no-sandbox', '--disable-gpu-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--no-proxy-server'],
});
for (const v of views) {
  const [name, ...rest] = v.split('&');
  const page = await browser.newPage();
  const size = name === 'game' ? [900, 900] : name === 'one' ? [1100, 560] : [1300, 620];
  await page.setViewport({ width: size[0], height: size[1], deviceScaleFactor: 1 });
  page.on('pageerror', (e) => console.log('ERROR de página:', String(e)));
  await page.goto(`http://127.0.0.1:${port}/tools/pieces/preview.html?set=${set}&view=${name}${rest.length ? '&' + rest.join('&') : ''}`);
  await page.waitForFunction('window.__ready === true', { timeout: 60000 });
  const out = join(root, 'shots', `pieces-${set}-${v.replace(/[^a-z0-9]+/gi, '-')}.png`);
  await page.screenshot({ path: out });
  console.log(out);
  await page.close();
}
await browser.close();
server.close();
