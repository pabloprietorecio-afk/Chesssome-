#!/usr/bin/env bash
# Descarga grabaciones candidatas de dominio público (CC0) para los sonidos de la partida.
# Se ejecuta en la CI (desde el entorno de desarrollo no hay acceso a esos sitios) y deja el resultado
# en build/sounds, que el flujo publica en la rama «assets-snd».
#
# Fuentes y licencias (verificadas el 13 nov 2026):
#   Kenney        — «Casino Audio» e «Impact Sounds», CC0 (https://kenney.nl/assets/casino-audio,
#                   https://kenney.nl/assets/impact-sounds).
#   OpenGameArt   — «Scrapes» (CC0, https://opengameart.org/content/scrapes) y «100 CC0 metal and wood SFX»,
#                   de rubberduck (CC0, https://opengameart.org/content/100-cc0-metal-and-wood-sfx).
# Freesound no se descarga aquí: sus condiciones prohíben el acceso automático y los originales exigen cuenta.
set -uo pipefail
UA="Chessome-dev/0.1 (github.com/pabloprietorecio-afk/Chesssome-; seleccion de sonidos CC0)"
OUT=build/sounds
mkdir -p "$OUT/zips" "$OUT/files"
get() { curl -sS -L --retry 3 --max-time 180 -A "$UA" "$@"; }

# Kenney: la página del recurso enlaza el zip (la ruta lleva un código que cambia con cada versión).
for asset in casino-audio impact-sounds; do
  get "https://kenney.nl/assets/$asset" -o "$OUT/kenney_$asset.html" || continue
  # El enlace puede venir absoluto o relativo.
  url=$(grep -o 'href="[^"]*\.zip"' "$OUT/kenney_$asset.html" | head -1 | sed 's/^href="//; s/"$//')
  case "$url" in
    http*) ;;
    //*) url="https:$url" ;;
    /*) url="https://kenney.nl$url" ;;
  esac
  echo "kenney $asset -> ${url:-sin enlace}"
  if [ -n "$url" ]; then get "$url" -o "$OUT/zips/kenney_$asset.zip" || true; fi
  # Lo que dice la propia página sobre la licencia.
  tr '\n' ' ' < "$OUT/kenney_$asset.html" | sed 's/<[^>]*>/ /g; s/  */ /g' | grep -o -i 'License.\{0,60\}' | head -3
  grep -o -i 'href="[^"]*"' "$OUT/kenney_$asset.html" | grep -i -E 'zip|download|media' | head -8
  rm -f "$OUT/kenney_$asset.html"
done

# OpenGameArt: primero la ruta habitual de los archivos; si falla, se busca el enlace en la página.
oga() { # oga <slug de la página> <nombre del zip>
  local page="https://opengameart.org/content/$1" file="$2"
  get -f "https://opengameart.org/sites/default/files/$file" -o "$OUT/zips/oga_$file" && return 0
  get "$page" -o "$OUT/oga_page.html" || return 1
  local url
  url=$(grep -o 'https\?://opengameart.org/sites/default/files/[^"]*\.zip' "$OUT/oga_page.html" | head -1)
  echo "oga $1 -> ${url:-sin enlace}"
  [ -n "$url" ] && get "$url" -o "$OUT/zips/oga_$file"
  rm -f "$OUT/oga_page.html"
}
oga scrapes scrapes.zip || true
oga 100-cc0-metal-and-wood-sfx 100-CC0-wood-metal-SFX.zip || true
# «Casino Audio» de Kenney, en la copia que el propio Kenney subió a OpenGameArt (su web no enlaza el zip en el HTML).
oga 54-casino-sound-effects-cards-dice-chips kenney_casino-audio.zip || true

ls -la "$OUT/zips"
for z in "$OUT"/zips/*.zip; do
  [ -f "$z" ] || continue
  name=$(basename "$z" .zip)
  if unzip -tq "$z" >/dev/null 2>&1; then
    mkdir -p "$OUT/files/$name" && unzip -q -o "$z" -d "$OUT/files/$name"
  else
    echo "no es un zip válido: $z"; head -c 300 "$z"; echo
  fi
done
rm -rf "$OUT/zips"
find "$OUT/files" -type f | sed 's/[0-9_]*\.[a-z0-9]*$//' | sort | uniq -c | head -150
find "$OUT/files" -type f \( -iname '*license*' -o -iname '*.txt' \) -exec sh -c 'echo "== $1"; head -20 "$1"' _ {} \;
du -sh "$OUT"
