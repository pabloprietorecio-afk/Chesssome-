"""Frases de ánimo del nivel Kids con más expresión: Chatterbox Multilingual (Resemble AI, licencia MIT,
https://huggingface.co/ResembleAI/chatterbox), con su control de «exageración» de la emoción.

Para que suenen con la misma voz que el resto del nivel Kids (Kokoro, ef_dora), se le da como referencia una
frase dicha por Kokoro (voz sintética: no se imita a ninguna persona). También se genera cada frase con la voz por
defecto de Chatterbox, para comparar. Todas las salidas llevan la marca de agua inaudible PerTh de Resemble AI.

Uso (en la CI, .github/workflows/voz-expresiva.yml):
  python tools/voz/expresiva.py --salida out
Deja out/<clave>__ref.ogg (voz de referencia Kokoro) y out/<clave>__def.ogg (voz por defecto), y out/frases.json.
"""
import argparse
import inspect
import json
import os
import subprocess
import tempfile

import numpy as np
import soundfile as sf

FRASES = {
    "muy_bien": "¡Muy bien!",
    "genial": "¡Genial!",
    "lo_has_hecho_genial": "¡Lo has hecho genial!",
    "fantastico": "¡Fantástico!",
    "bravo": "¡Bravo!",
    "estupendo": "¡Estupendo!",
    "sigue_asi": "¡Sigue así!",
    "que_bien_lo_haces": "¡Qué bien lo haces!",
    "casi": "¡Casi! Inténtalo otra vez.",
    "prueba_otra_vez": "¡Uy! Prueba otra vez.",
    "no_pasa_nada": "¡No pasa nada! Vuelve a intentarlo.",
    "has_ganado": "¡Has ganado! ¡Enhorabuena!",
}
REFERENCIA = "Hola, soy tu entrenador de ajedrez. Hoy vamos a aprender a mover el caballo. Salta haciendo una ele, por encima de las demás piezas."


def to_ogg(wav_path, ogg_path):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav_path, "-af",
                    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse,loudnorm=I=-18:TP=-2",
                    "-ac", "1", "-ar", "24000", "-c:a", "libvorbis", "-q:a", "4", ogg_path], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--salida", required=True)
    ap.add_argument("--exageracion", type=float, default=0.75)
    args = ap.parse_args()
    os.makedirs(args.salida, exist_ok=True)

    # Referencia: Kokoro ef_dora, la voz del resto del nivel Kids.
    from kokoro import KPipeline
    kp = KPipeline(lang_code="e")
    ref = np.concatenate([np.asarray(a, dtype=np.float32) for _, _, a in kp(REFERENCIA, voice="ef_dora", speed=0.95)])
    ref_path = os.path.join(args.salida, "referencia_kokoro.wav")
    sf.write(ref_path, ref, 24000)

    import torch
    import torchaudio as ta
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
    try:
        model = ChatterboxMultilingualTTS.from_pretrained(device="cpu", t3_model="v3")
    except TypeError:
        model = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
    params = inspect.signature(model.generate).parameters
    print("generate():", list(params))
    torch.manual_seed(7)
    out = {}
    for key, text in FRASES.items():
        for tag, prompt in (("ref", ref_path), ("def", None)):
            kw = {"language_id": "es"}
            if "exaggeration" in params:
                kw["exaggeration"] = args.exageracion
            if "cfg_weight" in params:
                # Con una referencia de la misma lengua, un poco de guía; la documentación aconseja bajarla si no.
                kw["cfg_weight"] = 0.4
            if prompt and "audio_prompt_path" in params:
                kw["audio_prompt_path"] = prompt
            wav = model.generate(text, **kw)
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                tmp_path = tmp.name
            ta.save(tmp_path, wav, model.sr)
            ogg = os.path.join(args.salida, f"{key}__{tag}.ogg")
            to_ogg(tmp_path, ogg)
            os.unlink(tmp_path)
            print("hecho", ogg)
        out[key] = text
    json.dump({"frases": out, "exageracion": args.exageracion, "modelo": "ResembleAI/chatterbox (multilingüe)", "referencia": REFERENCIA},
              open(os.path.join(args.salida, "frases.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
