// Escritor mínimo de glTF binario (.glb): una malla con una o varias superficies, cada una con su material.
// Atributos: POSITION, NORMAL y COLOR_0 (la oclusión horneada va en el color de vértice).
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const pad4 = (n) => (n + 3) & ~3;

/**
 * @param {string} path
 * @param {string} name nombre del nodo y de la malla
 * @param {{name: string, color?: number[], mesh: {positions: Float32Array, normals: Float32Array, colors: Float32Array, indices: Uint32Array}}[]} surfaces
 */
export function writeGlb(path, name, surfaces) {
  const views = [];
  const accessors = [];
  const chunks = [];
  let offset = 0;
  const addView = (typed, target) => {
    const bytes = new Uint8Array(typed.buffer, typed.byteOffset, typed.byteLength);
    views.push({ buffer: 0, byteOffset: offset, byteLength: bytes.byteLength, target });
    chunks.push(bytes);
    const padded = pad4(bytes.byteLength);
    if (padded > bytes.byteLength) chunks.push(new Uint8Array(padded - bytes.byteLength));
    offset += padded;
    return views.length - 1;
  };
  const materials = [];
  const primitives = [];
  for (const s of surfaces) {
    const m = s.mesh;
    const nv = m.positions.length / 3;
    const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
    for (let v = 0; v < nv; v++) for (let k = 0; k < 3; k++) {
      const x = m.positions[3 * v + k];
      if (x < min[k]) min[k] = x;
      if (x > max[k]) max[k] = x;
    }
    const col = new Uint8Array(nv * 4);
    for (let i = 0; i < nv * 4; i++) col[i] = Math.round(Math.max(0, Math.min(1, m.colors[i])) * 255);
    const use16 = nv < 65535;
    const idx = use16 ? Uint16Array.from(m.indices) : m.indices;
    const vp = addView(m.positions, 34962), vn = addView(m.normals, 34962), vc = addView(col, 34962), vi = addView(idx, 34963);
    const a0 = accessors.length;
    accessors.push(
      { bufferView: vp, componentType: 5126, count: nv, type: 'VEC3', min, max },
      { bufferView: vn, componentType: 5126, count: nv, type: 'VEC3' },
      { bufferView: vc, componentType: 5121, normalized: true, count: nv, type: 'VEC4' },
      { bufferView: vi, componentType: use16 ? 5123 : 5125, count: idx.length, type: 'SCALAR' },
    );
    materials.push({ name: s.name, pbrMetallicRoughness: { baseColorFactor: [...(s.color ?? [0.8, 0.8, 0.8]), 1], metallicFactor: 0, roughnessFactor: 0.5 } });
    primitives.push({ attributes: { POSITION: a0, NORMAL: a0 + 1, COLOR_0: a0 + 2 }, indices: a0 + 3, material: materials.length - 1, mode: 4 });
  }
  const json = {
    asset: { version: '2.0', generator: 'Chessome tools/pieces' },
    scene: 0,
    scenes: [{ nodes: [0] }],
    nodes: [{ name, mesh: 0 }],
    meshes: [{ name, primitives }],
    materials,
    accessors,
    bufferViews: views,
    buffers: [{ byteLength: offset }],
  };
  let jsonBytes = Buffer.from(JSON.stringify(json), 'utf8');
  const jsonPad = pad4(jsonBytes.length) - jsonBytes.length;
  if (jsonPad) jsonBytes = Buffer.concat([jsonBytes, Buffer.alloc(jsonPad, 0x20)]);
  const bin = Buffer.concat(chunks.map((c) => Buffer.from(c.buffer, c.byteOffset, c.byteLength)));
  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jsonBytes.length + 8 + bin.length, 8);
  const jh = Buffer.alloc(8);
  jh.writeUInt32LE(jsonBytes.length, 0);
  jh.writeUInt32LE(0x4e4f534a, 4);
  const bh = Buffer.alloc(8);
  bh.writeUInt32LE(bin.length, 0);
  bh.writeUInt32LE(0x004e4942, 4);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, Buffer.concat([header, jh, jsonBytes, bh, bin]));
}
