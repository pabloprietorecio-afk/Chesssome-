"""Frases de ánimo del nivel Kids con más expresión: Chatterbox Multilingual (Resemble AI, licencia MIT), con el
ajuste fino de español de España (ResembleAI/Chatterbox-Multilingual-es-es, MIT) y su control de «exageración».

Voz: femenina joven, dulce y alegre, «de cuento». No se imita a ningún personaje ni a ninguna actriz: la voz de
referencia es la de Kokoro (ef_dora, sintética, Apache-2.0), subida de tono. Variantes para escuchar y elegir:
  __aguda   referencia Kokoro subida ~3 semitonos (la propuesta)
  __kokoro  referencia Kokoro tal cual (la misma voz que el resto del nivel Kids)
  __def     voz por defecto del modelo
Todas las salidas llevan la marca de agua inaudible PerTh de Resemble AI.

Uso (en la CI, .github/workflows/voz-expresiva.yml): python tools/voz/expresiva.py --salida out
"""
import argparse
import json
import os
import shutil
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
REFERENCIA = "¡Hola! Soy tu entrenadora de ajedrez. Hoy vamos a aprender a mover el caballo: salta haciendo una ele, por encima de las demás piezas. ¡Qué divertido!"


def ffmpeg(args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + args, check=True)


def to_ogg(wav_path, ogg_path):
    ffmpeg(["-i", wav_path, "-af",
            "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse,loudnorm=I=-18:TP=-2",
            "-ac", "1", "-ar", "24000", "-c:a", "libvorbis", "-q:a", "4", ogg_path])


def pitch_up(src, dst, ratio):
    """Sube el tono conservando los formantes si hay rubberband; si no, con cambio de frecuencia de muestreo."""
    try:
        ffmpeg(["-i", src, "-af", f"rubberband=pitch={ratio}:formant=preserved", dst])
        return "rubberband"
    except subprocess.CalledProcessError:
        ffmpeg(["-i", src, "-af", f"asetrate=24000*{ratio},aresample=24000,atempo={1 / ratio}", dst])
        return "asetrate"


def load_es_es(device):
    """Carga el multilingüe con el T3 ajustado a español de España. Prueba con el s3gen general y, si no encaja,
    con el que trae el ajuste (s3gen_v3.pt)."""
    from huggingface_hub import hf_hub_download, list_repo_files, snapshot_download
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
    base = snapshot_download(repo_id="ResembleAI/chatterbox", allow_patterns=["ve.pt", "s3gen.pt", "grapheme_mtl_merged_expanded_v1.json", "conds.pt", "Cangjie5_TC.json", "t3_mtl23ls_v3.safetensors"])
    files = list_repo_files("ResembleAI/Chatterbox-Multilingual-es-es")
    print("Archivos del ajuste es-es:", files)
    work = tempfile.mkdtemp(prefix="cb_es_")
    for f in os.listdir(base):
        os.symlink(os.path.join(base, f), os.path.join(work, f))
    t3 = next(f for f in files if f.startswith("t3") and f.endswith(".safetensors"))
    shutil.copy(hf_hub_download("ResembleAI/Chatterbox-Multilingual-es-es", t3), os.path.join(work, t3))
    for f in files:
        if f.endswith(".json") and "token" in f.lower():
            # El tokenizador del ajuste, si trae uno propio, sustituye al general.
            dst = os.path.join(work, "grapheme_mtl_merged_expanded_v1.json")
            os.remove(dst)
            shutil.copy(hf_hub_download("ResembleAI/Chatterbox-Multilingual-es-es", f), dst)
            print("Tokenizador del ajuste:", f)
    try:
        model = ChatterboxMultilingualTTS.from_local(work, device, t3_model=t3)
        model.generate("Hola.", language_id="es")
        print("Cargado con el s3gen general")
        return model
    except Exception as e:  # noqa: BLE001
        print("Con el s3gen general no va:", repr(e)[:300])
    s3 = next((f for f in files if f.startswith("s3gen") and f.endswith(".pt")), None)
    if s3:
        os.remove(os.path.join(work, "s3gen.pt"))
        shutil.copy(hf_hub_download("ResembleAI/Chatterbox-Multilingual-es-es", s3), os.path.join(work, "s3gen.pt"))
        model = ChatterboxMultilingualTTS.from_local(work, device, t3_model=t3)
        print("Cargado con", s3)
        return model
    raise RuntimeError("No se pudo cargar el ajuste es-es")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--salida", required=True)
    ap.add_argument("--exageracion", type=float, default=0.8)
    ap.add_argument("--tono", type=float, default=1.19)
    args = ap.parse_args()
    os.makedirs(args.salida, exist_ok=True)

    from kokoro import KPipeline
    kp = KPipeline(lang_code="e")
    ref = np.concatenate([np.asarray(a, dtype=np.float32) for _, _, a in kp(REFERENCIA, voice="ef_dora", speed=1.0)])
    ref_kokoro = os.path.join(args.salida, "referencia_kokoro.wav")
    sf.write(ref_kokoro, ref, 24000)
    ref_aguda = os.path.join(args.salida, "referencia_aguda.wav")
    how = pitch_up(ref_kokoro, ref_aguda, args.tono)
    print("Referencia aguda con", how)

    import torch
    import torchaudio as ta
    model = load_es_es("cpu")
    torch.manual_seed(11)
    for key, text in FRASES.items():
        for tag, prompt in (("aguda", ref_aguda), ("kokoro", ref_kokoro), ("def", None)):
            kw = {"language_id": "es", "exaggeration": args.exageracion, "cfg_weight": 0.4}
            if prompt:
                kw["audio_prompt_path"] = prompt
            wav = model.generate(text, **kw)
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                tmp_path = tmp.name
            ta.save(tmp_path, wav, model.sr)
            to_ogg(tmp_path, os.path.join(args.salida, f"{key}__{tag}.ogg"))
            os.unlink(tmp_path)
            print("hecho", key, tag)
    for wav in (ref_kokoro, ref_aguda):
        to_ogg(wav, wav[:-4] + ".ogg")
        os.remove(wav)
    json.dump({"frases": FRASES, "exageracion": args.exageracion, "tono": args.tono, "modelo": "ResembleAI/Chatterbox-Multilingual-es-es (MIT)", "referencia": REFERENCIA},
              open(os.path.join(args.salida, "frases.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
