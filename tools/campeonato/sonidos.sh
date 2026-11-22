#!/usr/bin/env bash
# Sonidos del Campeonato: los descarga y los deja listos (OGG Vorbis, mono, volumen igualado) en build/sonidos.
#  · BigSoundBank (Joseph Sardin, CC0): murmullo de sala y aplausos.
#  · BudgetPixel AI (CC BY 4.0, hay que citarlos: ver Licencias en la app): exclamaciones y lamento.
set -u
OUT=build/sonidos
mkdir -p "$OUT" /tmp/snd
get() {  # get <nombre> <url>…: el primer enlace que funcione
  local name=$1; shift
  for url in "$@"; do
    if curl -sfL -A "Mozilla/5.0 (A Chess Way)" -o "/tmp/snd/$name.src" "$url" && [ -s "/tmp/snd/$name.src" ]; then
      echo "OK  $name  ← $url"; return 0
    fi
  done
  echo "FALTA $name"; return 1
}
bsb() { get "$1" "https://bigsoundbank.com/UPLOAD/ogg/$2.ogg" "https://bigsoundbank.com/UPLOAD/wav/$2.wav" "https://bigsoundbank.com/UPLOAD/mp3/$2.mp3"; }
bsb murmullo_a 3515
bsb murmullo_b 3516
bsb aplausos_pequeno 3523
bsb aplausos_grande 0021
get exclamacion_1 "https://cdn.budgetpixel.com/audio-library/sfx/crowd-rising-vocal-awed-group-rpog9c.wav"
get exclamacion_2 "https://cdn.budgetpixel.com/audio-library/sfx/crisp-vocal-group-surprised-clean-w2nx20.wav"
get exclamacion_3 "https://cdn.budgetpixel.com/audio-library/sfx/collective-gasp-surprised-loud-clean-1j96lmo.mp3"
get lamento "https://cdn.budgetpixel.com/audio-library/sfx/collective-vocal-disappointed-crisp-onset-usrx74.wav"
for f in /tmp/snd/*.src; do
  n=$(basename "$f" .src)
  ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" | xargs printf "%s: %.1f s\n" "$n"
  case $n in
    murmullo_*)
      # Bucle: fundido de entrada y salida de 1,5 s, volumen bajo e igualado.
      d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
      ffmpeg -v error -y -i "$f" -ac 1 -ar 44100 -af "loudnorm=I=-26:TP=-3,afade=t=in:d=1.5,afade=t=out:st=$(echo "$d - 1.5" | bc):d=1.5" -c:a libvorbis -q:a 3 "$OUT/$n.ogg" ;;
    *)
      # Efectos: sin silencio al principio ni al final, volumen igualado.
      ffmpeg -v error -y -i "$f" -ac 1 -ar 44100 -af "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-18:TP=-2" -c:a libvorbis -q:a 4 "$OUT/$n.ogg" ;;
  esac
done
ls -l "$OUT"
