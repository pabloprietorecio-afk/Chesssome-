#!/bin/sh
# Vídeos del caballo de las pantallas de espera (godot/espera/caballo_N.ogv), a partir de los MP4 de PixVerse que
# generó Pablo desde el logo (primer y último fotograma = el logo sobre el fondo lila; ver docs o LEEME).
# Uso: sh tools/espera/videos.sh uno.mp4 dos.mp4 tres.mp4
# - 720 × 720, 24 fps, sin sonido (en bucle, un sonido cansaría).
# - Ogg Theora: el único formato de vídeo que reproduce Godot. Godot no lo importa: va en el filtro de
#   exportación (espera/*.ogv) de export_presets.cfg.
set -e
out="$(dirname "$0")/../../godot/espera"
mkdir -p "$out"
n=0
for f in "$@"; do
	n=$((n + 1))
	ffmpeg -y -loglevel error -i "$f" -an -vf "scale=720:720:flags=lanczos,fps=24" -c:v libtheora -q:v 7 "$out/caballo_$n.ogv"
	echo "$out/caballo_$n.ogv: $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out/caballo_$n.ogv") s, $(du -k "$out/caballo_$n.ogv" | cut -f1) KB"
done
