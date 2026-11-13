// Modelado por campos de distancia con signo (SDF) y mallado para las colecciones de piezas de Chessome.
// Todo el código es propio: las piezas que salen de aquí no dependen de modelos ni licencias de terceros.
//
// Convenciones: 1 unidad = 1 casilla. Y hacia arriba, la pieza apoya en y = 0 y mira hacia +Z.
// Un «campo» es una función (x, y, z) → distancia con signo (negativa dentro).

// ---------- Operaciones ----------

/** Unión suave: el radio k redondea el encuentro entre dos formas (un «filete»). */
export const smin = (a, b, k) => {
  if (k <= 0) return Math.min(a, b);
  const h = Math.max(k - Math.abs(a - b), 0) / k;
  return Math.min(a, b) - h * h * k * 0.25;
};
/** Resta o intersección suave. */
export const smax = (a, b, k) => -smin(-a, -b, k);

export const union = (k, ...fs) => (x, y, z) => {
  let d = fs[0](x, y, z);
  for (let i = 1; i < fs.length; i++) d = smin(d, fs[i](x, y, z), k);
  return d;
};
export const subtract = (k, f, ...cuts) => (x, y, z) => {
  let d = f(x, y, z);
  for (const c of cuts) d = smax(d, -c(x, y, z), k);
  return d;
};
export const intersect = (k, f, g) => (x, y, z) => smax(f(x, y, z), g(x, y, z), k);

export const translate = (f, tx, ty, tz) => (x, y, z) => f(x - tx, y - ty, z - tz);
/** Gira la forma alrededor del eje Y (ángulo en radianes). */
export const rotateY = (f, a) => {
  const c = Math.cos(a), s = Math.sin(a);
  return (x, y, z) => f(c * x - s * z, y, s * x + c * z);
};
/** Gira la forma alrededor del eje X. */
export const rotateX = (f, a) => {
  const c = Math.cos(a), s = Math.sin(a);
  return (x, y, z) => f(x, c * y + s * z, -s * y + c * z);
};
/** Gira la forma alrededor del eje Z. */
export const rotateZ = (f, a) => {
  const c = Math.cos(a), s = Math.sin(a);
  return (x, y, z) => f(c * x + s * y, -s * x + c * y, z);
};
/** Escala no uniforme (aproximada: corrige la distancia con el factor menor). */
export const scale = (f, sx, sy, sz) => {
  const m = Math.min(sx, sy, sz);
  return (x, y, z) => f(x / sx, y / sy, z / sz) * m;
};
/** Repite la forma n veces alrededor del eje Y. */
export const radial = (f, n, phase = 0) => {
  const step = (2 * Math.PI) / n;
  return (x, y, z) => {
    let a = Math.atan2(z, x) - phase;
    a = a - step * Math.round(a / step);
    const r = Math.hypot(x, z);
    return f(r * Math.cos(a), y, r * Math.sin(a));
  };
};

// ---------- Primitivas ----------

export const sphere = (cx, cy, cz, r) => (x, y, z) => Math.hypot(x - cx, y - cy, z - cz) - r;

export const ellipsoid = (cx, cy, cz, rx, ry, rz) => (x, y, z) => {
  const px = (x - cx) / rx, py = (y - cy) / ry, pz = (z - cz) / rz;
  const k0 = Math.hypot(px, py, pz);
  if (k0 < 1e-9) return -Math.min(rx, ry, rz);
  const k1 = Math.hypot(px / rx, py / ry, pz / rz);
  return (k0 * (k0 - 1)) / k1;
};

/** Cilindro vertical de bordes redondeados: radio r, entre y0 e y1, con radio de canto e. */
export const roundCylinder = (r, y0, y1, e = 0.02) => (x, y, z) => {
  const dx = Math.hypot(x, z) - (r - e);
  const dy = Math.abs(y - (y0 + y1) / 2) - ((y1 - y0) / 2 - e);
  return Math.min(Math.max(dx, dy), 0) + Math.hypot(Math.max(dx, 0), Math.max(dy, 0)) - e;
};

/** Toro horizontal: centro en altura cy, radio mayor R y menor r. */
export const torus = (cy, R, r) => (x, y, z) => Math.hypot(Math.hypot(x, z) - R, y - cy) - r;

/** Anillo de sección elíptica (collarín): radio R, semiejes de la sección rw (radial) y rh (altura). */
export const ring = (cy, R, rw, rh) => (x, y, z) => {
  const px = (Math.hypot(x, z) - R) / rw, py = (y - cy) / rh;
  const k0 = Math.hypot(px, py);
  if (k0 < 1e-9) return -Math.min(rw, rh);
  const k1 = Math.hypot(px / rw, py / rh);
  return (k0 * (k0 - 1)) / k1;
};

/** Disco de canto redondo (collarín macizo): radio R, semialtura hh. */
export const disc = (cy, R, hh) => roundCylinder(R, cy - hh, cy + hh, Math.min(hh, R) * 0.98);

export const roundBox = (cx, cy, cz, hx, hy, hz, e = 0.01) => (x, y, z) => {
  const qx = Math.abs(x - cx) - (hx - e), qy = Math.abs(y - cy) - (hy - e), qz = Math.abs(z - cz) - (hz - e);
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0), Math.max(qz, 0)) + Math.min(Math.max(qx, qy, qz), 0) - e;
};

/** Cápsula de radio variable entre dos puntos (cono redondeado). */
export const roundCone = (a, b, r1, r2) => {
  const bax = b[0] - a[0], bay = b[1] - a[1], baz = b[2] - a[2];
  const l2 = bax * bax + bay * bay + baz * baz;
  const rr = r1 - r2;
  const a2 = l2 - rr * rr;
  const il2 = 1 / l2;
  return (x, y, z) => {
    const pax = x - a[0], pay = y - a[1], paz = z - a[2];
    const yy = pax * bax + pay * bay + paz * baz;
    const zz = yy - l2;
    const cx = pax * l2 - bax * yy, cy = pay * l2 - bay * yy, cz = paz * l2 - baz * yy;
    const x2 = cx * cx + cy * cy + cz * cz;
    const y2 = yy * yy * l2, z2 = zz * zz * l2;
    const k = Math.sign(rr) * rr * rr * x2;
    if (Math.sign(zz) * a2 * z2 > k) return Math.sqrt(x2 + z2) * il2 - r2;
    if (Math.sign(yy) * a2 * y2 < k) return Math.sqrt(x2 + y2) * il2 - r1;
    return (Math.sqrt(x2 * a2 * il2) + yy * rr) * il2 - r1;
  };
};

/** Semiespacio: dentro donde n·(p − p0) < 0. */
export const halfSpace = (p0, n) => {
  const l = Math.hypot(n[0], n[1], n[2]);
  const nx = n[0] / l, ny = n[1] / l, nz = n[2] / l;
  return (x, y, z) => (x - p0[0]) * nx + (y - p0[1]) * ny + (z - p0[2]) * nz;
};

// ---------- Torneado (perfil de revolución) ----------

/** Curva de Catmull-Rom centrípeta por los puntos [r, y, esquina?]. Las esquinas no se suavizan. */
export function smoothProfile(points, perSpan = 10, clampAxis = true) {
  const out = [];
  const P = points.map((p) => ({ r: p[0], y: p[1], corner: !!p[2] }));
  const n = P.length;
  for (let i = 0; i < n - 1; i++) {
    const p1 = P[i], p2 = P[i + 1];
    const p0 = p1.corner || i === 0 ? { r: 2 * p1.r - p2.r, y: 2 * p1.y - p2.y } : P[i - 1];
    const p3 = p2.corner || i === n - 2 ? { r: 2 * p2.r - p1.r, y: 2 * p2.y - p1.y } : P[i + 2];
    const d = (a, b) => Math.pow(Math.hypot(a.r - b.r, a.y - b.y), 0.5) || 1e-4;
    const t0 = 0, t1 = t0 + d(p0, p1), t2 = t1 + d(p1, p2), t3 = t2 + d(p2, p3);
    for (let s = 0; s < perSpan; s++) {
      const t = t1 + ((t2 - t1) * s) / perSpan;
      const lerp = (a, b, ta, tb) => ({ r: (a.r * (tb - t) + b.r * (t - ta)) / (tb - ta), y: (a.y * (tb - t) + b.y * (t - ta)) / (tb - ta) });
      const A1 = lerp(p0, p1, t0, t1), A2 = lerp(p1, p2, t1, t2), A3 = lerp(p2, p3, t2, t3);
      const B1 = lerp(A1, A2, t0, t2), B2 = lerp(A2, A3, t1, t3);
      const C = lerp(B1, B2, t1, t2);
      out.push([clampAxis ? Math.max(C.r, 0) : C.r, C.y]);
    }
  }
  const last = P[n - 1];
  out.push([last.r, last.y]);
  return out;
}

/** Sólido de revolución a partir de un perfil cerrado contra el eje (lista de [r, y]). */
export function lathe(profile) {
  const n = profile.length;
  const R = new Float64Array(n), Y = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    R[i] = profile[i][0];
    Y[i] = profile[i][1];
  }
  return (x, y, z) => {
    const r = Math.hypot(x, z);
    let d = Infinity;
    let inside = false;
    for (let i = 0, j = n - 1; i < n; j = i++) {
      const ex = R[j] - R[i], ey = Y[j] - Y[i];
      const wx = r - R[i], wy = y - Y[i];
      const l2 = ex * ex + ey * ey;
      const t = l2 > 0 ? Math.max(0, Math.min(1, (wx * ex + wy * ey) / l2)) : 0;
      const bx = wx - ex * t, by = wy - ey * t;
      const dd = bx * bx + by * by;
      if (dd < d) d = dd;
      if (Y[i] > y !== Y[j] > y && r < ((R[j] - R[i]) * (y - Y[i])) / (Y[j] - Y[i]) + R[i]) inside = !inside;
    }
    return (inside ? -1 : 1) * Math.sqrt(d);
  };
}

// ---------- Silueta inflada ----------

/** Distancia con signo a un polígono cerrado en 2D (lista de [u, v]). */
export function polygon2D(points) {
  const n = points.length;
  const U = new Float64Array(n), W = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    U[i] = points[i][0];
    W[i] = points[i][1];
  }
  return (u, v) => {
    let d = Infinity;
    let inside = false;
    for (let i = 0, j = n - 1; i < n; j = i++) {
      const ex = U[j] - U[i], ey = W[j] - W[i];
      const wx = u - U[i], wy = v - W[i];
      const l2 = ex * ex + ey * ey;
      const t = l2 > 0 ? Math.max(0, Math.min(1, (wx * ex + wy * ey) / l2)) : 0;
      const bx = wx - ex * t, by = wy - ey * t;
      const dd = bx * bx + by * by;
      if (dd < d) d = dd;
      if (W[i] > v !== W[j] > v && u < ((U[j] - U[i]) * (v - W[i])) / (W[j] - W[i]) + U[i]) inside = !inside;
    }
    return (inside ? -1 : 1) * Math.sqrt(d);
  };
}

/**
 * «Almohadilla»: una silueta dibujada en el plano Z–Y que gana grosor en X hacia dentro, con el canto redondo.
 * halfWidth(z, y) da el semigrosor máximo en cada zona y bevel la distancia en la que se alcanza.
 */
export function pillow(silhouette, halfWidth, bevel) {
  return (x, y, z) => {
    const s = silhouette(z, y);
    const w = halfWidth(z, y);
    // Sección elíptica: (x/w)² + (1 + s/bevel)² = 1 en el canto; plana (|x| = w) hacia dentro.
    // Es suave en x = 0, así el canto no tiembla al mallar.
    const e = Math.max(1 + s / bevel, 0);
    const g = (x * x) / (w * w) + e * e - 1;
    return g * 0.5 * Math.min(w, bevel);
  };
}

// ---------- Mallado ----------

/**
 * «Surface nets» sobre una rejilla regular, con los vértices proyectados después sobre la superficie real,
 * normales tomadas del gradiente del campo y oclusión ambiental horneada en el color de vértice.
 * Devuelve { positions, normals, colors, indices } (arrays tipados).
 */
export function mesh(field, bounds, cell, opts = {}) {
  const { ao = true, aoStrength = 1, dropBottom = true } = opts;
  const [x0, y0, z0, x1, y1, z1] = bounds;
  const nx = Math.ceil((x1 - x0) / cell) + 1, ny = Math.ceil((y1 - y0) / cell) + 1, nz = Math.ceil((z1 - z0) / cell) + 1;
  const V = new Float32Array(nx * ny * nz);
  const at = (i, j, k) => i + nx * (j + ny * k);
  for (let k = 0; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) V[at(i, j, k)] = field(x0 + i * cell, y0 + j * cell, z0 + k * cell);

  const cellVert = new Int32Array((nx - 1) * (ny - 1) * (nz - 1)).fill(-1);
  const cat = (i, j, k) => i + (nx - 1) * (j + (ny - 1) * k);
  const pos = [];
  const CORNERS = [[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0], [0, 0, 1], [1, 0, 1], [0, 1, 1], [1, 1, 1]];
  const EDGES = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]];
  const vals = new Float64Array(8);
  for (let k = 0; k < nz - 1; k++) for (let j = 0; j < ny - 1; j++) for (let i = 0; i < nx - 1; i++) {
    let neg = 0;
    for (let c = 0; c < 8; c++) {
      vals[c] = V[at(i + CORNERS[c][0], j + CORNERS[c][1], k + CORNERS[c][2])];
      if (vals[c] < 0) neg++;
    }
    if (neg === 0 || neg === 8) continue;
    let sx = 0, sy = 0, sz = 0, cnt = 0;
    for (const [a, b] of EDGES) {
      const va = vals[a], vb = vals[b];
      if (va < 0 === vb < 0) continue;
      const t = va / (va - vb);
      sx += CORNERS[a][0] + (CORNERS[b][0] - CORNERS[a][0]) * t;
      sy += CORNERS[a][1] + (CORNERS[b][1] - CORNERS[a][1]) * t;
      sz += CORNERS[a][2] + (CORNERS[b][2] - CORNERS[a][2]) * t;
      cnt++;
    }
    cellVert[cat(i, j, k)] = pos.length / 3;
    pos.push(x0 + (i + sx / cnt) * cell, y0 + (j + sy / cnt) * cell, z0 + (k + sz / cnt) * cell);
  }

  const idx = [];
  const quad = (a, b, c, d, flip) => {
    if (a < 0 || b < 0 || c < 0 || d < 0) return;
    if (flip) idx.push(a, d, c, a, c, b);
    else idx.push(a, b, c, a, c, d);
  };
  for (let k = 1; k < nz - 1; k++) for (let j = 1; j < ny - 1; j++) for (let i = 0; i < nx - 1; i++) {
    const a = V[at(i, j, k)], b = V[at(i + 1, j, k)];
    if (a < 0 !== b < 0) quad(cellVert[cat(i, j - 1, k - 1)], cellVert[cat(i, j, k - 1)], cellVert[cat(i, j, k)], cellVert[cat(i, j - 1, k)], a >= 0);
  }
  for (let k = 1; k < nz - 1; k++) for (let j = 0; j < ny - 1; j++) for (let i = 1; i < nx - 1; i++) {
    const a = V[at(i, j, k)], b = V[at(i, j + 1, k)];
    if (a < 0 !== b < 0) quad(cellVert[cat(i - 1, j, k - 1)], cellVert[cat(i - 1, j, k)], cellVert[cat(i, j, k)], cellVert[cat(i, j, k - 1)], a >= 0);
  }
  for (let k = 0; k < nz - 1; k++) for (let j = 1; j < ny - 1; j++) for (let i = 1; i < nx - 1; i++) {
    const a = V[at(i, j, k)], b = V[at(i, j, k + 1)];
    if (a < 0 !== b < 0) quad(cellVert[cat(i - 1, j - 1, k)], cellVert[cat(i, j - 1, k)], cellVert[cat(i, j, k)], cellVert[cat(i - 1, j, k)], a >= 0);
  }

  // Proyección sobre la superficie real, relajación de la malla y normales por gradiente.
  const nv = pos.length / 3;
  const P = new Float32Array(pos), N = new Float32Array(nv * 3), C = new Float32Array(nv * 4);
  const grad = (x, y, z, e) => [field(x + e, y, z) - field(x - e, y, z), field(x, y + e, z) - field(x, y - e, z), field(x, y, z + e) - field(x, y, z - e)];
  const project = (v, iters) => {
    let x = P[3 * v], y = P[3 * v + 1], z = P[3 * v + 2];
    for (let it = 0; it < iters; it++) {
      const d = field(x, y, z);
      const g = grad(x, y, z, 1e-3);
      const gl = Math.hypot(g[0], g[1], g[2]) / 2e-3;
      if (gl < 1e-6) break;
      const step = Math.max(-cell, Math.min(cell, d / gl));
      x -= (step * g[0]) / (gl * 2e-3);
      y -= (step * g[1]) / (gl * 2e-3);
      z -= (step * g[2]) / (gl * 2e-3);
    }
    P[3 * v] = x; P[3 * v + 1] = y; P[3 * v + 2] = z;
  };
  for (let v = 0; v < nv; v++) project(v, 4);
  // Relajar: cada vértice se acerca a la media de sus vecinos y se vuelve a llevar a la superficie.
  // Reparte los triángulos por igual y quita el temblor de las aristas cóncavas.
  const acc = new Float32Array(nv * 3), deg = new Uint16Array(nv);
  for (let pass = 0; pass < (opts.relax ?? 3); pass++) {
    acc.fill(0); deg.fill(0);
    for (let t = 0; t < idx.length; t += 3) for (let e = 0; e < 3; e++) {
      const a = idx[t + e], b = idx[t + ((e + 1) % 3)];
      acc[3 * a] += P[3 * b]; acc[3 * a + 1] += P[3 * b + 1]; acc[3 * a + 2] += P[3 * b + 2];
      deg[a]++;
    }
    for (let v = 0; v < nv; v++) {
      if (!deg[v]) continue;
      for (let k = 0; k < 3; k++) P[3 * v + k] += 0.6 * (acc[3 * v + k] / deg[v] - P[3 * v + k]);
      project(v, 3);
    }
  }
  for (let v = 0; v < nv; v++) {
    const x = P[3 * v], y = P[3 * v + 1], z = P[3 * v + 2];
    const g = grad(x, y, z, cell * 0.2);
    const gl = Math.hypot(g[0], g[1], g[2]) || 1;
    const nxv = g[0] / gl, nyv = g[1] / gl, nzv = g[2] / gl;
    N[3 * v] = nxv; N[3 * v + 1] = nyv; N[3 * v + 2] = nzv;
    // Oclusión ambiental: cuánto «se cierra» el campo al alejarse por la normal.
    let occ = 0;
    if (ao) {
      let w = 1;
      for (let s = 1; s <= 5; s++) {
        const h = 0.035 * s;
        occ += w * Math.max(0, h - field(x + nxv * h, y + nyv * h, z + nzv * h)) / h;
        w *= 0.62;
      }
    }
    C[4 * v] = Math.max(0.38, Math.min(1, 1 - 0.5 * aoStrength * occ));
  }
  // La oclusión se suaviza entre vértices vecinos: sin esto, en las aristas cóncavas sale punteada.
  if (ao) {
    const sum = new Float32Array(nv), cnt = new Uint16Array(nv);
    for (let pass = 0; pass < 3; pass++) {
      sum.fill(0); cnt.fill(0);
      for (let t = 0; t < idx.length; t += 3) {
        const a = idx[t], b = idx[t + 1], c = idx[t + 2];
        const m = (C[4 * a] + C[4 * b] + C[4 * c]) / 3;
        sum[a] += m; sum[b] += m; sum[c] += m;
        cnt[a]++; cnt[b]++; cnt[c]++;
      }
      for (let v = 0; v < nv; v++) if (cnt[v]) C[4 * v] = 0.35 * C[4 * v] + 0.65 * (sum[v] / cnt[v]);
    }
  }
  for (let v = 0; v < nv; v++) { C[4 * v + 1] = C[4 * v]; C[4 * v + 2] = C[4 * v]; C[4 * v + 3] = 1; }

  // La cara de apoyo no se ve nunca: fuera.
  let indices = idx;
  if (dropBottom) {
    indices = [];
    for (let t = 0; t < idx.length; t += 3) {
      const a = idx[t], b = idx[t + 1], c = idx[t + 2];
      const down = N[3 * a + 1] < -0.85 && N[3 * b + 1] < -0.85 && N[3 * c + 1] < -0.85;
      const low = P[3 * a + 1] < 0.012 && P[3 * b + 1] < 0.012 && P[3 * c + 1] < 0.012;
      if (!(down && low)) indices.push(a, b, c);
    }
  }
  return orient(compact({ positions: P, normals: N, colors: C, indices: Uint32Array.from(indices) }));
}

/** Quita los vértices que ya no usa ningún triángulo. */
function compact(m) {
  const nv = m.positions.length / 3;
  const map = new Int32Array(nv).fill(-1);
  let n = 0;
  for (const i of m.indices) if (map[i] < 0) map[i] = n++;
  const P = new Float32Array(n * 3), N = new Float32Array(n * 3), C = new Float32Array(n * 4);
  for (let v = 0; v < nv; v++) {
    const t = map[v];
    if (t < 0) continue;
    P.set(m.positions.subarray(3 * v, 3 * v + 3), 3 * t);
    N.set(m.normals.subarray(3 * v, 3 * v + 3), 3 * t);
    C.set(m.colors.subarray(4 * v, 4 * v + 4), 4 * t);
  }
  return { positions: P, normals: N, colors: C, indices: m.indices.map((i) => map[i]) };
}

// ---------- Mallado de las partes torneadas ----------

/**
 * Malla de revolución de un campo que es simétrico respecto al eje Y entre y0 e y1: se saca el contorno en el
 * plano (r, y), se simplifica y se hace girar. Da superficies perfectamente lisas con pocos triángulos
 * (el «surface nets» se reserva para lo que no es de revolución: caballo, almenas, corona, cruz…).
 */
export function latheMesh(field, y0, y1, opts = {}) {
  const { rMax = 0.46, step = 0.004, segments = 40, tolerance = 0.0009, maxEdge = 0.045, aoStrength = 1 } = opts;
  const f = (r, y) => field(r, y, 0);
  const nr = Math.ceil(rMax / step) + 1, ny = Math.ceil((y1 - y0) / step) + 1;
  const hy = (y1 - y0) / (ny - 1);
  const V = new Float32Array(nr * ny);
  for (let j = 0; j < ny; j++) for (let i = 0; i < nr; i++) V[i + nr * j] = f(i * step, y0 + j * hy);
  // «Marching squares»: cada segmento une dos aristas de la rejilla; se encadenan por el identificador de arista.
  const edgePoint = new Map();
  const link = new Map();
  const hKey = (i, j) => `h${i},${j}`, vKey = (i, j) => `v${i},${j}`;
  const cross = (key, ax, ay, bx, by, va, vb) => {
    if (!edgePoint.has(key)) {
      const t = va / (va - vb);
      edgePoint.set(key, [ax + (bx - ax) * t, ay + (by - ay) * t]);
    }
    return key;
  };
  const addSeg = (a, b) => {
    if (!link.has(a)) link.set(a, []);
    if (!link.has(b)) link.set(b, []);
    link.get(a).push(b);
    link.get(b).push(a);
  };
  for (let j = 0; j < ny - 1; j++) for (let i = 0; i < nr - 1; i++) {
    const a = V[i + nr * j], b = V[i + 1 + nr * j], c = V[i + 1 + nr * (j + 1)], d = V[i + nr * (j + 1)];
    const x0 = i * step, x1 = (i + 1) * step, ya = y0 + j * hy, yb = y0 + (j + 1) * hy;
    const pts = [];
    if (a < 0 !== b < 0) pts.push(cross(hKey(i, j), x0, ya, x1, ya, a, b));
    if (b < 0 !== c < 0) pts.push(cross(vKey(i + 1, j), x1, ya, x1, yb, b, c));
    if (d < 0 !== c < 0) pts.push(cross(hKey(i, j + 1), x0, yb, x1, yb, d, c));
    if (a < 0 !== d < 0) pts.push(cross(vKey(i, j), x0, ya, x0, yb, a, d));
    if (pts.length === 2) addSeg(pts[0], pts[1]);
    else if (pts.length === 4) {
      // Caso ambiguo: se decide con el valor del centro.
      const mid = (a + b + c + d) / 4;
      if (a < 0 === mid < 0) { addSeg(pts[0], pts[1]); addSeg(pts[2], pts[3]); } else { addSeg(pts[0], pts[3]); addSeg(pts[1], pts[2]); }
    }
  }
  // Cadenas: se parte de los extremos sueltos (borde de la rejilla o el eje) y se queda la más larga.
  const used = new Set();
  const chains = [];
  const walk = (start) => {
    const chain = [start];
    used.add(start);
    let cur = start;
    for (;;) {
      const next = (link.get(cur) ?? []).find((k) => !used.has(k));
      if (next === undefined) break;
      used.add(next);
      chain.push(next);
      cur = next;
    }
    return chain;
  };
  for (const [k, n] of link) if (n.length === 1 && !used.has(k)) chains.push(walk(k));
  for (const k of link.keys()) if (!used.has(k)) chains.push(walk(k));
  const lengthOf = (ch) => ch.reduce((s, k, i) => (i ? s + Math.hypot(edgePoint.get(k)[0] - edgePoint.get(ch[i - 1])[0], edgePoint.get(k)[1] - edgePoint.get(ch[i - 1])[1]) : 0), 0);
  chains.sort((p, q) => lengthOf(q) - lengthOf(p));
  let pts = chains[0].map((k) => edgePoint.get(k).slice());
  if (pts[0][1] > pts[pts.length - 1][1]) pts.reverse(); // de abajo arriba
  // Cada punto se lleva al contorno exacto.
  const g2 = (r, y, e) => [f(r + e, y) - f(r - e, y), f(r, y + e) - f(r, y - e)];
  for (const p of pts) {
    for (let it = 0; it < 3; it++) {
      const d = f(p[0], p[1]);
      const g = g2(p[0], p[1], 5e-4);
      const gl = Math.hypot(g[0], g[1]) / 1e-3;
      if (gl < 1e-6) break;
      p[0] = Math.max(0, p[0] - (d * g[0]) / (gl * gl * 1e-3));
      p[1] -= (d * g[1]) / (gl * gl * 1e-3);
    }
  }
  // Simplificación de Douglas–Peucker.
  const keep = new Uint8Array(pts.length);
  keep[0] = keep[pts.length - 1] = 1;
  const stack = [[0, pts.length - 1]];
  while (stack.length) {
    const [a, b] = stack.pop();
    let worst = 0, at = -1;
    const ex = pts[b][0] - pts[a][0], ey = pts[b][1] - pts[a][1];
    const el = Math.hypot(ex, ey) || 1e-9;
    for (let i = a + 1; i < b; i++) {
      const dist = Math.abs((pts[i][0] - pts[a][0]) * ey - (pts[i][1] - pts[a][1]) * ex) / el;
      if (dist > worst) { worst = dist; at = i; }
    }
    if (at >= 0 && (worst > tolerance || el > maxEdge)) {
      keep[at] = 1;
      stack.push([a, at], [at, b]);
    }
  }
  pts = pts.filter((_, i) => keep[i]);
  // La pared del pie se prolonga hasta el tablero.
  if (pts[0][1] < 0.02 && pts[0][0] > 0.05) pts.unshift([pts[0][0], 0]);

  const n = pts.length;
  const P = new Float32Array(n * segments * 3), N = new Float32Array(n * segments * 3), C = new Float32Array(n * segments * 4);
  for (let i = 0; i < n; i++) {
    const [r, y] = pts[i];
    const g = g2(Math.max(r, 2e-3), y, 2e-3);
    const gl = Math.hypot(g[0], g[1]) || 1;
    const nrn = g[0] / gl, nyn = g[1] / gl;
    let occ = 0, w = 1;
    for (let s = 1; s <= 5; s++) {
      const h = 0.035 * s;
      occ += (w * Math.max(0, h - f(Math.abs(r + nrn * h), y + nyn * h))) / h;
      w *= 0.62;
    }
    const ao = Math.max(0.38, Math.min(1, 1 - 0.5 * aoStrength * occ));
    for (let s = 0; s < segments; s++) {
      const a = (s / segments) * 2 * Math.PI, ca = Math.cos(a), sa = Math.sin(a);
      const v = i * segments + s;
      P.set([r * ca, y, r * sa], 3 * v);
      N.set([nrn * ca, nyn, nrn * sa], 3 * v);
      C.set([ao, ao, ao, 1], 4 * v);
    }
  }
  // La oclusión se suaviza a lo largo del perfil, como en el otro mallado.
  for (let pass = 0; pass < 2; pass++) {
    const prev = Float32Array.from({ length: n }, (_, i) => C[4 * i * segments]);
    for (let i = 0; i < n; i++) {
      const m = (prev[Math.max(0, i - 1)] + prev[i] * 2 + prev[Math.min(n - 1, i + 1)]) / 4;
      for (let s = 0; s < segments; s++) for (let k = 0; k < 3; k++) C[4 * (i * segments + s) + k] = m;
    }
  }
  const I = [];
  for (let i = 0; i < n - 1; i++) {
    if (pts[i][0] < 1e-5 && pts[i + 1][0] < 1e-5) continue;
    for (let s = 0; s < segments; s++) {
      const a = i * segments + s, b = i * segments + ((s + 1) % segments), c = (i + 1) * segments + ((s + 1) % segments), d = (i + 1) * segments + s;
      I.push(a, c, b, a, d, c);
    }
  }
  return orient({ positions: P, normals: N, colors: C, indices: Uint32Array.from(I) });
}

/** Deja cada triángulo con la cara frontal (antihoraria en glTF) hacia donde apuntan las normales. */
export function orient(m) {
  const { positions: P, normals: N, indices: I } = m;
  for (let t = 0; t < I.length; t += 3) {
    const a = I[t], b = I[t + 1], c = I[t + 2];
    const ux = P[3 * b] - P[3 * a], uy = P[3 * b + 1] - P[3 * a + 1], uz = P[3 * b + 2] - P[3 * a + 2];
    const vx = P[3 * c] - P[3 * a], vy = P[3 * c + 1] - P[3 * a + 1], vz = P[3 * c + 2] - P[3 * a + 2];
    const fx = uy * vz - uz * vy, fy = uz * vx - ux * vz, fz = ux * vy - uy * vx;
    const nx = N[3 * a] + N[3 * b] + N[3 * c], ny = N[3 * a + 1] + N[3 * b + 1] + N[3 * c + 1], nz = N[3 * a + 2] + N[3 * b + 2] + N[3 * c + 2];
    if (fx * nx + fy * ny + fz * nz < 0) { I[t + 1] = c; I[t + 2] = b; }
  }
  return m;
}

/** Une varias mallas en una sola superficie. */
export function merge(meshes) {
  const nv = meshes.reduce((s, m) => s + m.positions.length / 3, 0), ni = meshes.reduce((s, m) => s + m.indices.length, 0);
  const P = new Float32Array(nv * 3), N = new Float32Array(nv * 3), C = new Float32Array(nv * 4), I = new Uint32Array(ni);
  let v = 0, i = 0;
  for (const m of meshes) {
    P.set(m.positions, 3 * v); N.set(m.normals, 3 * v); C.set(m.colors, 4 * v);
    for (let k = 0; k < m.indices.length; k++) I[i + k] = m.indices[k] + v;
    v += m.positions.length / 3; i += m.indices.length;
  }
  return { positions: P, normals: N, colors: C, indices: I };
}
