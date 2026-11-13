// Genera los modelos .glb de una colección de piezas a partir de sus campos de distancia.
// Uso: node tools/pieces/generate.mjs [colección] [pieza…]   (por defecto: clasico, todas)
import { fileURLToPath } from 'node:url';
import { mesh } from './sdf.mjs';
import { writeGlb } from './glb.mjs';

const setName = process.argv[2] ?? 'clasico';
const only = process.argv.slice(3);
const { SET } = await import(`./${setName}.mjs`);
const outDir = fileURLToPath(new URL(`../../godot/sets/${SET.id}/`, import.meta.url));

let total = 0;
for (const [name, def] of Object.entries(SET.pieces)) {
  if (only.length && !only.includes(name)) continue;
  const t0 = performance.now();
  const body = mesh(def.field, def.bounds, def.cell, { aoStrength: def.ao ?? 1 });
  const surfaces = [{ name: 'cuerpo', mesh: body }];
  for (const extra of def.extras ?? []) surfaces.push({ name: extra.name, mesh: mesh(extra.field, extra.bounds ?? def.bounds, extra.cell ?? def.cell, { aoStrength: 0.6 }) });
  writeGlb(`${outDir}${name}.glb`, name, surfaces);
  const tris = surfaces.reduce((n, s) => n + s.mesh.indices.length / 3, 0);
  let top = 0;
  for (let v = 1; v < body.positions.length; v += 3) top = Math.max(top, body.positions[v]);
  total += tris * (name === 'pawn' ? 16 : name === 'queen' || name === 'king' ? 2 : 4);
  console.log(`${name.padEnd(7)} ${String(tris).padStart(6)} triángulos · altura ${top.toFixed(2)} · ${Math.round(performance.now() - t0)} ms`);
}
if (!only.length) console.log(`Tablero completo (32 piezas): ${total} triángulos`);
