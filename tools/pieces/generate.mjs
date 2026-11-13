// Genera los modelos .glb de una colección de piezas a partir de sus campos de distancia.
// Uso: node tools/pieces/generate.mjs [colección] [pieza…]   (por defecto: clasico, todas)
import { fileURLToPath } from 'node:url';
import { mesh, latheMesh, merge } from './sdf.mjs';
import { writeGlb } from './glb.mjs';

const setName = process.argv[2] ?? 'clasico';
const only = process.argv.slice(3);
const { SET } = await import(`./${setName}.mjs`);
const outDir = fileURLToPath(new URL(`../../godot/sets/${SET.id}/`, import.meta.url));

let total = 0;
for (const [name, def] of Object.entries(SET.pieces)) {
  if (only.length && !only.includes(name)) continue;
  const t0 = performance.now();
  // Por debajo de «cut» la pieza es de revolución y se tornea (malla exacta); por encima, mallado por rejilla.
  const parts = [];
  if (def.cut === undefined) {
    parts.push(latheMesh(def.field, 0.004, def.top));
  } else {
    const axial = def.axial ?? def.field;
    parts.push(latheMesh(axial, 0.004, def.cut));
    const b = def.bounds.slice();
    b[1] = def.cut - 3 * def.cell; // se solapa con la parte torneada: el borde abierto del mallado encoge al relajarse
    parts.push(mesh(def.field, b, def.cell, { dropBottom: false }));
    // Comprobación: en el corte, el contorno de la pieza completa debe ser un círculo (si no, se vería la costura).
    let lo = Infinity, hi = -Infinity;
    for (let k = 0; k < 24; k++) {
      const a = (k / 24) * 2 * Math.PI;
      let r0 = 0.02, r1 = 0.45;
      for (let it = 0; it < 30; it++) {
        const rm = (r0 + r1) / 2;
        if (def.field(rm * Math.cos(a), def.cut, rm * Math.sin(a)) < 0) r0 = rm; else r1 = rm;
      }
      lo = Math.min(lo, r0); hi = Math.max(hi, r0);
    }
    if (hi - lo > 0.002) console.log(`  ¡ojo! ${name}: el corte en y=${def.cut} no es de revolución (radio ${lo.toFixed(4)}–${hi.toFixed(4)})`);
  }
  const body = merge(parts);
  const surfaces = [{ name: 'cuerpo', mesh: body }];
  writeGlb(`${outDir}${name}.glb`, name, surfaces);
  const tris = surfaces.reduce((n, s) => n + s.mesh.indices.length / 3, 0);
  let top = 0;
  for (let v = 1; v < body.positions.length; v += 3) top = Math.max(top, body.positions[v]);
  total += tris * (name === 'pawn' ? 16 : name === 'queen' || name === 'king' ? 2 : 4);
  console.log(`${name.padEnd(7)} ${String(tris).padStart(6)} triángulos · altura ${top.toFixed(2)} · ${Math.round(performance.now() - t0)} ms`);
}
if (!only.length) console.log(`Tablero completo (32 piezas): ${total} triángulos`);
