"""Voz del nivel Kids en los demás idiomas: un OGG por frase de tools/voz/lineas_<idioma>.json (lo escribe
tools/voz/idiomas.py), en <salida>/voz_<idioma>/<id>.ogg. Las frases que ya tienen audio no se regeneran.

- Inglés, francés, italiano, japonés, portugués (Brasil) e hindi: Kokoro-82M (pesos Apache-2.0), con voces femeninas
  como la española (ef_dora). Kokoro usa espeak-ng (GPL-3.0), que solo se instala en la CI: en la app van los OGG.
- Alemán, ruso e indonesio (Kokoro no los habla): Supertonic 3 de Supertone Inc. con sherpa-onnx, como en A Tank Story.
  Licencia BigScience Open RAIL-M: uso libre de regalías, sin derechos del autor sobre el audio, con restricciones de
  uso y la OBLIGACIÓN de avisar de que la voz está hecha por una máquina (en la ficha de la tienda).

Solo se usa en la CI (.github/workflows/voz-idiomas.yml).
Uso: python tools/voz/generar_idiomas.py --idioma en --salida out [--supertonic CARPETA_DEL_MODELO]
"""
import argparse
import json
import os
import subprocess
import tempfile

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
# idioma -> (código de Kokoro, voz)
KOKORO = {"en": ("a", "af_heart"), "fr": ("f", "ff_siwis"), "it": ("i", "if_sara"), "ja": ("j", "jf_alpha"),
          "pt": ("p", "pf_dora"), "hi": ("h", "hf_alpha")}
# idioma -> voz de Supertonic (0-4 mujer F1..F5; 5-9 hombre) y velocidad. F3: la más clara en A Tank Story.
SUPERTONIC = {"de": (2, 1.0), "ru": (2, 1.0), "id": (2, 1.0)}
RATE = 24000


def to_ogg(samples, rate, path):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    try:
        sf.write(wav, samples, rate)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-ac", "1", "-ar", "24000", "-c:a", "libvorbis",
                        "-q:a", "3", path], check=True)
    finally:
        os.unlink(wav)


def kokoro_voice(lang):
    from kokoro import KPipeline
    code, voice = KOKORO[lang]
    pipeline = KPipeline(lang_code=code)

    def speak(text):
        chunks = [np.asarray(audio, dtype=np.float32) for _, _, audio in pipeline(text, voice=voice, speed=0.95)]
        if not chunks:
            raise RuntimeError("sin audio")
        pause = np.zeros(int(RATE * 0.12), dtype=np.float32)
        out = [pause]
        for c in chunks:
            out += [c, pause]
        return np.concatenate(out), RATE
    return speak


def supertonic_voice(lang, folder):
    import sherpa_onnx
    sid, speed = SUPERTONIC[lang]
    config = sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(
        supertonic=sherpa_onnx.OfflineTtsSupertonicModelConfig(
            duration_predictor=os.path.join(folder, "duration_predictor.int8.onnx"),
            text_encoder=os.path.join(folder, "text_encoder.int8.onnx"),
            vector_estimator=os.path.join(folder, "vector_estimator.int8.onnx"),
            vocoder=os.path.join(folder, "vocoder.int8.onnx"),
            tts_json=os.path.join(folder, "tts.json"),
            unicode_indexer=os.path.join(folder, "unicode_indexer.bin"),
            voice_style=os.path.join(folder, "voice.bin")),
        num_threads=2, provider="cpu"))
    if not config.validate():
        raise SystemExit("Modelo de Supertonic no válido: " + folder)
    tts = sherpa_onnx.OfflineTts(config)

    def speak(text):
        gen = sherpa_onnx.GenerationConfig()
        gen.sid = sid
        gen.num_steps = 16
        gen.speed = speed
        # Hay que asignar el diccionario entero (ver A Tank Story): si no, lee el texto como si fuera inglés.
        gen.extra = {"lang": lang}
        audio = tts.generate(text, gen)
        samples = np.array(audio.samples, dtype=np.float32)
        if samples.size == 0:
            raise RuntimeError("audio vacío")
        # Supertonic sale más bajo que Kokoro: el pico a 0,85 para igualar el volumen.
        return samples / max(1e-6, float(np.abs(samples).max())) * 0.85, audio.sample_rate
    return speak


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--idioma", required=True)
    ap.add_argument("--salida", required=True)
    ap.add_argument("--supertonic", default="")
    args = ap.parse_args()
    lines = json.load(open(os.path.join(HERE, "lineas_%s.json" % args.idioma), encoding="utf-8"))
    folder = os.path.join(args.salida, "voz_" + args.idioma)
    os.makedirs(folder, exist_ok=True)
    speak = kokoro_voice(args.idioma) if args.idioma in KOKORO else supertonic_voice(args.idioma, args.supertonic)
    done, failed = 0, []
    for line in lines:
        path = os.path.join(folder, line["id"] + ".ogg")
        if os.path.exists(path):
            continue
        try:
            samples, rate = speak(line["text"])
            to_ogg(samples, rate, path)
            done += 1
        except Exception as error:  # una frase que falla no para las demás
            failed.append(line["id"])
            print("FALLO", line["id"], line["text"], error, flush=True)
    print(f"{args.idioma}: {done} audios nuevos, {len(failed)} fallidos, {len(lines)} frases")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
