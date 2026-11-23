#!/usr/bin/env python3
"""Vídeos del Campeonato (el rival saluda desde la mesa) con PixVerse v6 a través del estudio temporal.

Uso: ESTUDIO_URL=… ESTUDIO_CLAVE=… python3 videos.py lote_videos.json salida/
Cada elemento: {"nombre": "rivales/escuela/lucia", "foto": "rivales/escuela/lucia.jpg", "prompt": "…",
"quality": "1080p", "duration": 5}. Guarda <nombre>.mp4 (el original) y <nombre>.ogv (Theora, el que lee Godot).
"""
import base64
import io
import json
import os
import subprocess
import sys
import time
import urllib.request

from PIL import Image

UA = "achessway-estudio/1.0 (+github actions)"


def post(url, key, payload):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST",
                                 headers={"content-type": "application/json", "x-clave": key, "user-agent": UA})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())


def main():
    lote, out = sys.argv[1], sys.argv[2]
    url, key = os.environ["ESTUDIO_URL"], os.environ["ESTUDIO_CLAVE"]
    ok = 0
    items = json.load(open(lote))["items"]
    for it in items:
        im = Image.open(os.path.join(out, it["foto"])).convert("RGB")
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=92)
        payload = {"video": True, "prompt": it["prompt"], "negative_prompt": it.get("negative_prompt", ""),
                   "image": base64.b64encode(buf.getvalue()).decode(), "quality": it.get("quality", "1080p"),
                   "duration": it.get("duration", 5), "aspect_ratio": it.get("aspect_ratio", "9:16"), "seed": it.get("seed")}
        for attempt in range(3):
            try:
                t0 = time.time()
                res = post(url, key, payload)
                video = (res.get("result") or {}).get("video")
                if not video:
                    raise RuntimeError(json.dumps(res)[:400])
                dest = os.path.join(out, it["nombre"])
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                req = urllib.request.Request(video, headers={"user-agent": UA})
                with urllib.request.urlopen(req, timeout=300) as r, open(dest + ".mp4", "wb") as f:
                    f.write(r.read())
                subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", dest + ".mp4", "-an", "-vf", "scale=720:-2",
                                "-c:v", "libtheora", "-q:v", "7", dest + ".ogv"], check=True)
                info = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=width,height,duration",
                                       "-of", "csv=p=0", dest + ".mp4"], capture_output=True, text=True).stdout.strip()
                print(f"ok  {it['nombre']}  ({time.time() - t0:.0f} s; mp4 {info}; estado {res.get('state')})", flush=True)
                ok += 1
                break
            except Exception as e:  # noqa: BLE001
                body = e.read().decode()[:400] if hasattr(e, "read") else ""
                print(f"err {it['nombre']} (intento {attempt + 1}): {e} {body}", flush=True)
                time.sleep(10)
    print(f"{ok} de {len(items)} vídeos")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
