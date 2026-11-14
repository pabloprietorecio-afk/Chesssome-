"""Genera los audios del nivel Kids con Kokoro-82M (pesos Apache-2.0, https://huggingface.co/hexgrad/Kokoro-82M).

Lee tools/voz/lineas.json (lo escribe `npm run voice`) y deja un OGG por frase en la carpeta de salida:
<id>.ogg, mono, 24 kHz. Las frases que ya tienen audio no se regeneran.

Solo se usa en la CI de la voz (.github/workflows/voz.yml): la fonetización del español de Kokoro pasa por
espeak-ng (GPL-3.0), que se queda en la máquina de la CI. En la app solo van los OGG.

Uso: python tools/voz/generar.py --lineas tools/voz/lineas.json --salida voz --voz ef_dora [--muestras muestras]
"""
import argparse
import json
import os
import subprocess
import tempfile

import numpy as np
import soundfile as sf
from kokoro import KPipeline

RATE = 24000


def speak(pipeline, text, voice, speed):
    chunks = [np.asarray(audio, dtype=np.float32) for _, _, audio in pipeline(text, voice=voice, speed=speed)]
    if not chunks:
        raise RuntimeError(f"Sin audio para: {text}")
    pause = np.zeros(int(RATE * 0.12), dtype=np.float32)
    out = [pause]
    for c in chunks:
        out += [c, pause]
    return np.concatenate(out)


def to_ogg(samples, path):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    try:
        sf.write(wav, samples, RATE)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-ac", "1", "-ar", str(RATE), "-c:a", "libvorbis", "-q:a", "3", path], check=True)
    finally:
        os.unlink(wav)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lineas", required=True)
    ap.add_argument("--salida", required=True)
    ap.add_argument("--voz", default="ef_dora")
    ap.add_argument("--velocidad", type=float, default=0.95)
    ap.add_argument("--muestras", help="carpeta para una frase de prueba con cada voz española")
    args = ap.parse_args()
    lines = json.load(open(args.lineas, encoding="utf-8"))
    os.makedirs(args.salida, exist_ok=True)
    pipeline = KPipeline(lang_code="e")
    done = 0
    for line in lines:
        path = os.path.join(args.salida, line["id"] + ".ogg")
        if os.path.exists(path):
            continue
        to_ogg(speak(pipeline, line["text"], args.voz, args.velocidad), path)
        done += 1
    print(f"{done} audios nuevos, {len(lines)} frases en total, voz {args.voz}")
    if args.muestras:
        os.makedirs(args.muestras, exist_ok=True)
        sample = "¡Hola! Soy tu entrenador de ajedrez. El caballo salta haciendo una ele. ¡Jaque mate! ¡Has ganado!"
        for voice in ["ef_dora", "em_alex", "em_santa"]:
            to_ogg(speak(pipeline, sample, voice, args.velocidad), os.path.join(args.muestras, f"muestra-{voice}.ogg"))
        print("Muestras:", sorted(os.listdir(args.muestras)))


if __name__ == "__main__":
    main()
