// Genera el marco del tablero: una losa de esquinas y cantos redondeados (las casillas las pinta un shader encima).
// Uso: node tools/pieces/board.mjs [colección]
import { fileURLToPath } from 'node:url';
import { writeGlb } from './glb.mjs';

const setId = process.argv[2] ?? 'clasico';
// Marco fino: en un móvil cada milímetro de ancho cuenta, y las coordenadas van dentro de las casillas.
const H = 4.14; // semilado exterior: 8 casillas + 0,14 de marco por lado
const RC = 0.26; // radio de las esquinas
const T = 0.36; // grosor
const RT = 0.045; // radio del canto superior
const RB = 0.07; // radio del canto inferior

// Contorno (vista desde arriba), en sentido antihorario.
const path = [];
const corners = [[1, 1, 0], [-1, 1, 90], [-1, -1, 180], [1, -1, 270]];
for (const [sx, sz, a0] of corners) {
  for (let i = 0; i <= 12; i++) {
    const a = ((a0 + (90 * i) / 12) * Math.PI) / 180;
    path.push({ x: sx * (H - RC) + RC * Math.cos(a), z: sz * (H - RC) + RC * Math.sin(a), nx: Math.cos(a), nz: Math.sin(a) });
  }
}
// Perfil del canto: desplazamiento hacia fuera (o), altura (y) y normal (no, ny).
const profile = [];
for (let i = 0; i <= 6; i++) {
  const f = ((90 - (90 * i) / 6) * Math.PI) / 180;
  profile.push({ o: -RT + RT * Math.cos(f), y: -RT + RT * Math.sin(f), no: Math.cos(f), ny: Math.sin(f), ao: 1 });
}
for (let i = 0; i <= 4; i++) {
  const f = ((-(70 * i) / 4) * Math.PI) / 180;
  profile.push({ o: -RB + RB * Math.cos(f), y: -T + RB + RB * Math.sin(f), no: Math.cos(f), ny: Math.sin(f), ao: 0.72 - 0.12 * (i / 4) });
}

const P = [], N = [], C = [], I = [];
const n = path.length, m = profile.length;
for (const p of path) for (const q of profile) {
  P.push(p.x + p.nx * q.o, q.y, p.z + p.nz * q.o);
  N.push(p.nx * q.no, q.ny, p.nz * q.no);
  C.push(q.ao, q.ao, q.ao, 1);
}
for (let i = 0; i < n; i++) for (let j = 0; j < m - 1; j++) {
  const a = i * m + j, b = ((i + 1) % n) * m + j, c = ((i + 1) % n) * m + j + 1, d = i * m + j + 1;
  I.push(a, c, b, a, d, c);
}
// Tapa superior: abanico desde el centro hasta el primer anillo.
const center = P.length / 3;
P.push(0, 0, 0); N.push(0, 1, 0); C.push(1, 1, 1, 1);
for (let i = 0; i < n; i++) I.push(center, ((i + 1) % n) * m, i * m);

// Cada triángulo se orienta según las normales de sus vértices (Godot dibuja la cara de sentido horario).
let fixed = 0;
for (let t = 0; t < I.length; t += 3) {
  const [a, b, c] = [I[t], I[t + 1], I[t + 2]];
  const ux = P[3 * b] - P[3 * a], uy = P[3 * b + 1] - P[3 * a + 1], uz = P[3 * b + 2] - P[3 * a + 2];
  const vx = P[3 * c] - P[3 * a], vy = P[3 * c + 1] - P[3 * a + 1], vz = P[3 * c + 2] - P[3 * a + 2];
  const fx = uy * vz - uz * vy, fy = uz * vx - ux * vz, fz = ux * vy - uy * vx;
  const nx = N[3 * a] + N[3 * b] + N[3 * c], ny = N[3 * a + 1] + N[3 * b + 1] + N[3 * c + 1], nz = N[3 * a + 2] + N[3 * b + 2] + N[3 * c + 2];
  // glTF usa sentido antihorario para la cara frontal: la normal geométrica debe coincidir con la de los vértices.
  if (fx * nx + fy * ny + fz * nz < 0) {
    [I[t + 1], I[t + 2]] = [I[t + 2], I[t + 1]];
    fixed++;
  }
}

const out = fileURLToPath(new URL(`../../godot/sets/${setId}/board.glb`, import.meta.url));
writeGlb(out, 'board', [{ name: 'marco', mesh: { positions: Float32Array.from(P), normals: Float32Array.from(N), colors: Float32Array.from(C), indices: Uint32Array.from(I) } }]);
console.log(`board   ${I.length / 3} triángulos (${fixed} reorientados)`);
