// Convierte dist/ en un único fichero dist/chessome.html con el JS y el CSS incrustados.
// Sirve para publicar el prototipo como una sola página.
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const dist = new URL('../dist/', import.meta.url).pathname;
let html = readFileSync(join(dist, 'index.html'), 'utf8');

html = html.replace(/<script type="module" crossorigin src="\.\/([^"]+)"><\/script>/g, (_, src) => {
  const js = readFileSync(join(dist, src), 'utf8').replace(/<\/script/g, '<\\/script');
  return `<script type="module">${js}</script>`;
});
html = html.replace(/<link rel="stylesheet" crossorigin href="\.\/([^"]+)">/g, (_, href) => {
  const css = readFileSync(join(dist, href), 'utf8');
  return `<style>${css}</style>`;
});
html = html.replace(/<link rel="modulepreload"[^>]*>/g, '');

if (/src="\.\/assets|href="\.\/assets/.test(html)) {
  console.error('Quedan referencias a assets sin incrustar:', readdirSync(join(dist, 'assets')));
  process.exit(1);
}
writeFileSync(join(dist, 'chessome.html'), html);
console.log(`dist/chessome.html · ${(html.length / 1024).toFixed(0)} KB`);
