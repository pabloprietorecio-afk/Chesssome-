#!/usr/bin/env python3
"""Prepara los sonidos de la partida a partir de grabaciones de dominio público (CC0).

Uso:  python3 -I tools/assets/prepare-sounds.py <dir. de la rama assets-snd>/files <copia de VSCO-2-CE> godot/sounds

Entradas (ver godot/sounds/LEEME.md para autores y licencias):
  oga_scrapes/                     «Scrapes» (OpenGameArt, CC0): un objeto arrastrado sobre un bloque de hormigón
  oga_100-CC0-wood-metal-SFX/      «100 CC0 metal and wood SFX», de rubberduck (OpenGameArt, CC0): golpes y caídas de madera
  VSCO-2-CE/Percussion/Timpani/    «VSCO 2: Community Edition», de Versilian Studios (CC0): timbales de orquesta

Lo único que se hace con las grabaciones es recortarlas, darles una entrada y una salida suaves, ajustar el nivel
y, en el aviso de jaque, juntar dos golpes de timbal. Necesita ffmpeg, numpy y scipy. No se usa síntesis.
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def onset(x, threshold_db=-32.0):
    """Primer instante en que la señal supera el umbral respecto a su pico."""
    level = np.abs(x) / (np.abs(x).max() + 1e-12)
    idx = np.where(level > 10 ** (threshold_db / 20.0))[0]
    return int(idx[0]) if len(idx) else 0


def fade(x, t_in, t_out):
    y = x.copy()
    n_in = max(1, int(SR * t_in))
    n_out = max(1, int(SR * t_out))
    y[:n_in] *= np.linspace(0.0, 1.0, n_in) ** 2
    y[-n_out:] *= np.linspace(1.0, 0.0, n_out) ** 2
    return y


def normalize(x, peak_db):
    return x * (10 ** (peak_db / 20.0) / (np.abs(x).max() + 1e-12))


def save(path, x):
    data = np.clip(x, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{os.path.basename(path):16s} {len(x) / SR:5.2f} s  pico {20 * np.log10(np.abs(data).max() + 1e-12):6.1f} dB  eficaz {20 * np.log10(np.sqrt(np.mean(data ** 2)) + 1e-12):6.1f} dB")


def hit(path, length, peak_db, pre=0.003, tail=0.05):
    """Un golpe: empieza justo antes del ataque y se apaga al final."""
    x = load(path)
    a = max(0, onset(x) - int(SR * pre))
    return normalize(fade(x[a:a + int(SR * length)], 0.001, tail), peak_db)


def excerpt(path, start, length, peak_db):
    """Un tramo de un arrastre largo, con entrada y salida suaves."""
    x = load(path)
    a = int(SR * start)
    return normalize(fade(x[a:a + int(SR * length)], 0.035, 0.14), peak_db)


def main():
    src, vsco, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    wood = os.path.join(src, "oga_100-CC0-wood-metal-SFX")
    scrapes = os.path.join(src, "oga_scrapes")
    timp = os.path.join(vsco, "Percussion", "Timpani")

    # Arrastre de la pieza: tres tramos de roce continuo (la app elige uno y lo corta cuando la pieza llega).
    save(os.path.join(out, "arrastre_1.wav"), excerpt(os.path.join(scrapes, "scrape-1.wav"), 0.22, 0.5, -9.0))
    save(os.path.join(out, "arrastre_2.wav"), excerpt(os.path.join(scrapes, "scrape-2.wav"), 0.30, 0.5, -9.0))
    save(os.path.join(out, "arrastre_3.wav"), excerpt(os.path.join(scrapes, "scrape-1.wav"), 0.56, 0.5, -9.0))

    # La pieza se asienta en su casilla: golpes secos de madera, graves y cortos.
    save(os.path.join(out, "posar_1.wav"), hit(os.path.join(wood, "wood_hit_07.ogg"), 0.22, -5.0))
    save(os.path.join(out, "posar_2.wav"), hit(os.path.join(wood, "wood_hit_03.ogg"), 0.24, -7.0))
    save(os.path.join(out, "posar_3.wav"), hit(os.path.join(wood, "wood_hit_06.ogg"), 0.20, -7.0))

    # Captura: un golpe con más ataque.
    save(os.path.join(out, "captura_1.wav"), hit(os.path.join(wood, "wood_hit_08.ogg"), 0.30, -3.0))
    save(os.path.join(out, "captura_2.wav"), hit(os.path.join(wood, "wood_hit_04.ogg"), 0.28, -3.0))

    # Caída del rey: un objeto de madera que cae y rebota.
    save(os.path.join(out, "caida_rey.wav"), hit(os.path.join(wood, "wood_falling_01.ogg"), 0.62, -2.0, tail=0.12))

    # Jaque: dos golpes de timbal a un semitono de distancia, el segundo más fuerte (la amenaza de siempre:
    # dos notas pegadas que suben). Son las grabaciones tal cual, una detrás de otra.
    low = load(os.path.join(timp, "Timpani4_Hit_v3_rr1_Sum.wav"))
    high = load(os.path.join(timp, "Timpani2_Hit_v3_rr1_Sum.wav"))
    low = normalize(low[max(0, onset(low) - 90):], -8.0)
    high = normalize(high[max(0, onset(high) - 90):], -2.5)
    gap = int(SR * 0.21)
    total = int(SR * 1.25)
    mix = np.zeros(total)
    mix[:min(total, len(low))] += low[:total]
    seg = high[:total - gap]
    mix[gap:gap + len(seg)] += seg
    mix = fade(mix, 0.001, 0.55)
    save(os.path.join(out, "jaque.wav"), normalize(mix, -2.0))


if __name__ == "__main__":
    main()
