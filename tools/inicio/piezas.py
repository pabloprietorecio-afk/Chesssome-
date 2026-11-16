# Rey y peón del fondo de «A Chess Way», modelados por código y renderizados con Cycles (Blender como módulo).
# No usa ningún modelo, textura ni imagen externos: la geometría sale de los perfiles de este archivo.
#
# Uso:  python3 piezas.py --pieza rey --luz dia --alto 900 --muestras 96 --salida rey_dia.exr
import argparse, math, sys, os, json
import numpy as np
import bpy
from mathutils import Vector

# ----------------------------------------------------------------------------- perfiles (radio, altura, peso del festón)
REY = [
    (0.00, 0.00, 0), (0.86, 0.00, 0), (0.95, 0.03, 0), (0.96, 0.14, 0), (0.93, 0.24, 0),   # pie
    (0.80, 0.29, 0), (0.74, 0.33, 0), (0.77, 0.40, 0), (0.74, 0.47, 0), (0.66, 0.52, 0),   # anillo de la base
    (0.55, 0.70, 0), (0.47, 0.95, 0), (0.44, 1.18, 0), (0.45, 1.24, 0),                    # fuste
    (0.60, 1.27, 0), (0.82, 1.30, 0), (0.88, 1.40, 0), (0.82, 1.50, 0), (0.62, 1.53, 0),   # plato
    (0.54, 1.56, 0), (0.60, 1.62, 0), (0.60, 1.68, 0), (0.52, 1.73, 0),                    # anillo fino
    (0.47, 1.80, 0), (0.49, 1.98, 0), (0.60, 2.26, 0), (0.76, 2.50, 0.35),                 # cuello y copa
    (0.87, 2.66, 0.9), (0.89, 2.74, 1.0), (0.78, 2.77, 1.0), (0.72, 2.70, 0.8),            # borde de la corona
    (0.66, 2.60, 0.3), (0.56, 2.60, 0), (0.44, 2.72, 0), (0.30, 2.84, 0),                  # cúpula
    (0.17, 2.90, 0), (0.12, 2.94, 0), (0.115, 3.05, 0), (0.00, 3.05, 0),
]
CRUZ_Z = 3.34          # centro de la cruz
REY_ALTO = 3.74


def _cabeza(cz, R):
    return [(R * math.cos(math.radians(a)), cz + R * math.sin(math.radians(a)), 0) for a in range(-60, 91, 15)]


PEON = [
    (0.00, 0.00, 0), (0.56, 0.00, 0), (0.63, 0.03, 0), (0.64, 0.12, 0), (0.61, 0.20, 0),
    (0.50, 0.24, 0), (0.46, 0.28, 0), (0.48, 0.33, 0), (0.45, 0.39, 0), (0.38, 0.44, 0),
    (0.30, 0.62, 0), (0.24, 0.86, 0), (0.22, 1.00, 0), (0.24, 1.05, 0),
    (0.36, 1.07, 0), (0.44, 1.09, 0), (0.45, 1.15, 0), (0.38, 1.20, 0), (0.26, 1.22, 0), (0.22, 1.25, 0),
] + _cabeza(1.56, 0.37)[1:]
PEON_ALTO = 1.93


def chaikin(P, it=4):
    P = np.asarray(P, float)
    for _ in range(it):
        a, b = P[:-1], P[1:]
        Q = np.empty((2 * len(a) + 2, P.shape[1]))
        Q[0], Q[-1] = P[0], P[-1]
        Q[1:-1:2] = 0.75 * a + 0.25 * b
        Q[2:-1:2] = 0.25 * a + 0.75 * b
        P = Q
    return P


def torno(nombre, perfil, seg=256, lobulos=0, hondo=0.0, mete=0.0):
    """Sólido de revolución. Con lobulos>0, el borde marcado con peso se festonea (corona)."""
    P = chaikin(perfil)
    P = P[np.concatenate([[True], np.any(np.abs(np.diff(P[:, :2], axis=0)) > 1e-9, axis=1)])]
    r, z, w = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    th = np.linspace(0, 2 * math.pi, seg, endpoint=False)
    if lobulos:
        f = ((np.cos(lobulos / 2 * th) ** 2 + 0.03) / 1.03) ** 0.5       # 1 en la punta del pétalo, ~0.17 en el valle
        f = (f - f.min()) / (f.max() - f.min())
    else:
        f = np.ones(seg)
    verts = [(0.0, 0.0, float(z[0]))]
    for k in range(1, n - 1):
        rr = r[k] + mete * w[k] * (f - 1)
        zz = z[k] + hondo * w[k] * (f - 1)
        verts += [(float(a * math.cos(t)), float(a * math.sin(t)), float(b)) for a, b, t in zip(rr, zz, th)]
    verts.append((0.0, 0.0, float(z[-1])))
    top = len(verts) - 1
    ring = lambda k, j: 1 + (k - 1) * seg + (j % seg)
    faces = [(0, ring(1, j + 1), ring(1, j)) for j in range(seg)]
    for k in range(1, n - 2):
        faces += [(ring(k, j), ring(k, j + 1), ring(k + 1, j + 1), ring(k + 1, j)) for j in range(seg)]
    faces += [(ring(n - 2, j), ring(n - 2, j + 1), top) for j in range(seg)]
    return malla(nombre, verts, faces)


def malla(nombre, verts, faces):
    me = bpy.data.meshes.new(nombre)
    me.from_pydata(verts, [], faces)
    me.update()
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    ob = bpy.data.objects.new(nombre, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def cruz(nombre, zc):
    """Cruz patada, blanda: campo de distancias de un contorno extruido y redondeado, poligonizado."""
    from skimage.measure import marching_cubes
    from scipy.ndimage import gaussian_filter
    h0, h1, s0, L, bomba, grosor, redondeo = 0.098, 0.20, 0.10, 0.355, 0.032, 0.215, 0.062
    brazo = []
    ss = np.linspace(s0, L, 14)
    hw = h0 + (h1 - h0) * ((ss - s0) / (L - s0)) ** 1.7
    brazo += [(s, -h) for s, h in zip(ss, hw)]
    for a in np.linspace(-1, 1, 9)[1:-1]:
        brazo.append((L + bomba * (1 - a * a), a * h1))
    brazo += [(s, h) for s, h in zip(ss[::-1], hw[::-1])]
    poly = []
    for k in range(4):
        c, s = math.cos(k * math.pi / 2), math.sin(k * math.pi / 2)
        poly += [(c * x - s * y, s * x + c * y) for x, y in brazo]
    poly = np.array(poly)
    paso = 0.0045
    lim = L + bomba + 0.06
    xs = np.arange(-lim, lim + paso, paso)
    X, Z = np.meshgrid(xs, xs, indexing="ij")
    p = np.stack([X.ravel(), Z.ravel()], 1)
    a, b = poly, np.roll(poly, -1, axis=0)
    d2 = np.full(len(p), 1e9)
    dentro = np.zeros(len(p), bool)
    for A, B in zip(a, b):
        e = B - A
        t = np.clip(((p - A) @ e) / (e @ e), 0, 1)
        d2 = np.minimum(d2, np.hypot(*(p - (A + t[:, None] * e)).T))
        cruza = ((A[1] > p[:, 1]) != (B[1] > p[:, 1])) & (p[:, 0] < (B[0] - A[0]) * (p[:, 1] - A[1]) / (B[1] - A[1] + 1e-30) + A[0])
        dentro ^= cruza
    sd2 = np.where(dentro, -d2, d2).reshape(X.shape)
    ys = np.arange(-grosor / 2 - 0.05, grosor / 2 + 0.05 + paso, paso)
    qx = sd2[:, None, :] + redondeo
    qy = (np.abs(ys) - grosor / 2 + redondeo)[None, :, None]
    vol = np.minimum(np.maximum(qx, qy), 0) + np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) - redondeo
    vol = gaussian_filter(vol, 1.6)
    v, f, _, _ = marching_cubes(vol, 0.0, spacing=(paso, paso, paso))
    v = v + np.array([xs[0], ys[0], xs[0]])
    v[:, 2] += zc
    f = f[:, ::-1]
    # orientación: volumen con signo positivo = caras hacia fuera
    t = v[f]
    vol_s = np.einsum("ij,ij->i", t[:, 0], np.cross(t[:, 1], t[:, 2])).sum() / 6
    if vol_s < 0:
        f = f[:, ::-1]
    return malla(nombre, [tuple(map(float, q)) for q in v], [tuple(map(int, q)) for q in f])


# ----------------------------------------------------------------------------- materiales y luz
def material_blanco(luz):
    m = bpy.data.materials.new("porcelana")
    b = next(n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
    i = b.inputs
    i["Base Color"].default_value = (0.90, 0.865, 0.845, 1)
    i["Roughness"].default_value = 0.39
    i["Subsurface Weight"].default_value = 0.55
    i["Subsurface Radius"].default_value = (1.0, 0.62, 0.50)
    i["Subsurface Scale"].default_value = 0.11
    i["Specular IOR Level"].default_value = 0.5
    i["Coat Weight"].default_value = 0.0
    for k, v in json.loads(os.environ.get("MAT", "{}")).items():
        i[k].default_value = v
    return m


def luz_area(nombre, pos, hacia, tam, watts, color):
    L = bpy.data.lights.new(nombre, "AREA")
    L.shape = "DISK"
    L.size = tam
    L.energy = watts
    L.color = color
    ob = bpy.data.objects.new(nombre, L)
    ob.location = pos
    ob.rotation_euler = (Vector(hacia) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(ob)
    return ob


def mundo(abajo, arriba, fuerza):
    w = bpy.data.worlds.new("mundo")
    bpy.context.scene.world = w
    nt = w.node_tree
    nt.nodes.clear()
    co = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.55
    mr.inputs["From Max"].default_value = 0.75
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*abajo, 1)
    ramp.color_ramp.elements[1].color = (*arriba, 1)
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = fuerza
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(co.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])


LUCES = {
    # Día: casi todo es luz ambiente cálida (sombras rosadas, como la referencia) y una principal blanda desde arriba a la izquierda.
    "dia": dict(
        mundo=((1.00, 0.72, 0.66), (1.00, 0.83, 0.84), 0.62),
        luces=[
            ("principal", (-7.5, -7.0, 8.5), (0, 0, 2.0), 7.0, 1500, (1.0, 0.93, 0.85)),
            ("contra", (6.0, 5.0, 4.5), (0, 0, 2.2), 6.0, 350, (0.95, 0.88, 1.0)),
        ],
    ),
    # Noche: ambiente azul profundo, luna fría desde arriba a la izquierda y un resplandor naranja (el color de la app) desde abajo.
    "noche": dict(
        mundo=((0.060, 0.035, 0.075), (0.030, 0.040, 0.105), 1.0),
        luces=[
            ("luna", (-6.5, -7.5, 8.0), (0, 0, 2.0), 7.0, 760, (0.72, 0.80, 1.0)),
            ("brasa", (5.5, -3.0, 0.4), (0, 0, 1.6), 5.0, 520, (1.0, 0.46, 0.14)),
            ("contra", (4.0, 7.0, 5.0), (0, 0, 2.4), 5.0, 260, (0.62, 0.55, 1.0)),
        ],
    ),
}


def escena(pieza, luz, alto, muestras, salida, umbral=0.012):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    c = sc.cycles
    c.device = "CPU"
    c.samples = muestras
    c.use_adaptive_sampling = True
    c.adaptive_threshold = umbral
    c.use_denoising = True
    c.max_bounces = 6
    c.diffuse_bounces = 3
    c.glossy_bounces = 3
    c.transmission_bounces = 2
    c.volume_bounces = 0
    c.sample_clamp_indirect = 10
    c.filter_width = 1.5
    sc.render.film_transparent = True
    mat = material_blanco(luz)
    if pieza == "rey":
        obs = [torno("rey", REY, lobulos=8, hondo=0.21, mete=0.035), cruz("cruz", CRUZ_Z)]
        altura, ancho = REY_ALTO, 0.96
    else:
        obs = [torno("peon", PEON)]
        altura, ancho = PEON_ALTO, 0.64
    for o in obs:
        o.data.materials.append(mat)
    cfg = LUCES[luz]
    mw = cfg["mundo"]
    mundo(mw[0], mw[1], float(os.environ.get("MUNDO", mw[2])))
    k = altura / REY_ALTO
    for nombre, pos, hacia, tam, watts, color in cfg["luces"]:
        luz_area(nombre, pos, hacia, tam, watts, color)
    # cámara: tele suave, mirando un poco hacia abajo; encuadre con margen para que nada toque el borde
    margen = 1.16
    Hm = altura * margen
    Wm = 2 * ancho * margen * 1.10
    cabeceo = math.radians(9.0)
    D = 16.0
    zc = altura / 2
    cam = bpy.data.cameras.new("cam")
    cam.sensor_fit = "VERTICAL"
    cam.sensor_height = 24.0
    dist = D / math.cos(cabeceo)
    cam.lens = 12.0 / ((Hm / 2) / dist)
    cam.clip_start, cam.clip_end = 0.5, 200
    ob = bpy.data.objects.new("cam", cam)
    ob.location = (0, -D, zc + D * math.tan(cabeceo))
    ob.rotation_euler = (Vector((0, 0, zc)) - Vector(ob.location)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(ob)
    sc.camera = ob
    sc.render.resolution_y = alto
    sc.render.resolution_x = int(round(alto * Wm / Hm / 2)) * 2
    sc.render.resolution_percentage = 100
    im = sc.render.image_settings
    im.file_format = "OPEN_EXR"
    im.color_mode = "RGBA"
    im.color_depth = "32"
    sc.render.filepath = os.path.abspath(salida)
    return sc, dict(px_por_unidad=alto / Hm, alto_px=alto, ancho_px=sc.render.resolution_x, base_y=(Hm - altura) / 2 / Hm)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--pieza", default="rey")
    ap.add_argument("--luz", default="dia")
    ap.add_argument("--alto", type=int, default=720)
    ap.add_argument("--muestras", type=int, default=64)
    ap.add_argument("--umbral", type=float, default=0.012)
    ap.add_argument("--salida", default="prueba.exr")
    a = ap.parse_args()
    sc, info = escena(a.pieza, a.luz, a.alto, a.muestras, a.salida, a.umbral)
    print("INFO", info, flush=True)
    bpy.ops.render.render(write_still=True)
    print("HECHO", a.salida, flush=True)
