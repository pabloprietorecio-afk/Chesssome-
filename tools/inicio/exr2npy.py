# Convierte los EXR de Blender a .npy (RGBA lineal, premultiplicado, fila 0 arriba) usando el propio Blender para leerlos.
import sys, numpy as np, bpy
for p in sys.argv[1:]:
    img = bpy.data.images.load(p)
    w, h = img.size
    a = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(a)
    a = a.reshape(h, w, 4)[::-1].copy()
    np.save(p.rsplit(".", 1)[0] + ".npy", a)
    print(p, a.shape, "espacio:", img.colorspace_settings.name, "alfa:", img.alpha_mode, flush=True)
    bpy.data.images.remove(img)
