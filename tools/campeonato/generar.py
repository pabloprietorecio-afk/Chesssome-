#!/usr/bin/env python3
"""Genera las imágenes de un lote del Campeonato con el estudio temporal (estudio/index.js).

Uso: ESTUDIO_URL=… ESTUDIO_CLAVE=… python3 generar.py lote_1.json salida/
Cada elemento del lote: {"nombre": "salas/escuela", "prompt": "…", "width": 1024, "height": 1792, "steps": 28,
"seed": 7, "refs": ["retratos/lucia"]} — «refs»: imágenes ya generadas en este lote o en salida/ que se pasan como
referencia (para que una persona salga igual en otra escena). Guarda JPEG (calidad 92) y un índice con los textos.
"""
import base64
import io
import json
import os
import sys
import time
import urllib.request

from PIL import Image


def call(url, key, payload):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST",
                                 headers={"content-type": "application/json", "x-clave": key})
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.loads(r.read())


def ref_b64(path):
    im = Image.open(path).convert("RGB")
    im.thumbnail((512, 512))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    return base64.b64encode(buf.getvalue()).decode()


def main():
    lote, out = sys.argv[1], sys.argv[2]
    url, key = os.environ["ESTUDIO_URL"], os.environ["ESTUDIO_CLAVE"]
    items = json.load(open(lote))["items"]
    index = {}
    ok = 0
    for it in items:
        dest = os.path.join(out, it["nombre"] + ".jpg")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        payload = {k: it[k] for k in ("prompt", "width", "height", "steps", "seed", "modelo") if k in it}
        payload["refs"] = [ref_b64(os.path.join(out, r + ".jpg")) for r in it.get("refs", [])]
        for attempt in range(4):
            try:
                t0 = time.time()
                res = call(url, key, payload)
                if "image" not in res:
                    raise RuntimeError(res.get("error", "sin imagen"))
                Image.open(io.BytesIO(base64.b64decode(res["image"]))).convert("RGB").save(dest, "JPEG", quality=92)
                print(f"ok  {it['nombre']}  ({time.time() - t0:.0f} s)", flush=True)
                index[it["nombre"]] = {k: it[k] for k in it if k != "refs"} | {"refs": it.get("refs", [])}
                ok += 1
                break
            except Exception as e:  # noqa: BLE001
                body = e.read().decode()[:300] if hasattr(e, "read") else ""
                print(f"err {it['nombre']} (intento {attempt + 1}): {e} {body}", flush=True)
                time.sleep(5 * (attempt + 1))
    json.dump(index, open(os.path.join(out, "indice.json"), "w"), ensure_ascii=False, indent=1)
    print(f"{ok} de {len(items)} imágenes")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
