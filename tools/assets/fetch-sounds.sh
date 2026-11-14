#!/usr/bin/env bash
# Descarga las grabaciones de dominio público (CC0) de las que salen los sonidos de la partida.
# Se ejecuta en la CI (desde el entorno de desarrollo no hay acceso a esos sitios), al empujar a la rama
# «sonidos-fetch», y deja el resultado en la rama «assets-snd». Con eso y una copia de VSCO-2-CE,
# tools/assets/prepare-sounds.py genera godot/sounds/.
#
# Fuentes y licencias (verificadas el 13 nov 2026; ver godot/sounds/LEEME.md):
#   OpenGameArt   — «Scrapes» (CC0, https://opengameart.org/content/scrapes) y «100 CC0 metal and wood SFX»,
#                   de rubberduck (CC0, https://opengameart.org/content/100-cc0-metal-and-wood-sfx).
#   VSCO 2 CE     — no se descarga aquí: está en GitHub (https://github.com/sgossner/VSCO-2-CE, CC0).
# Freesound tiene grabaciones CC0 de piezas de ajedrez de verdad, pero no se pueden bajar de forma
# automática: sus condiciones lo prohíben y los originales exigen iniciar sesión.
set -uo pipefail
UA="Chessome-dev/0.1 (github.com/pabloprietorecio-afk/Chesssome-; seleccion de sonidos CC0)"
OUT=build/sounds
mkdir -p "$OUT/zips" "$OUT/files"
get() { curl -sS -L --retry 3 --max-time 180 -A "$UA" "$@"; }

# OpenGameArt: primero la ruta habitual de los archivos; si falla, se busca el enlace en la página.
oga() { # oga <nombre de la página> <nombre del zip>
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
find "$OUT/files" -type f | sed 's/[0-9_]*\.[a-z0-9]*$//' | sort | uniq -c | head -80
find "$OUT/files" -type f \( -iname '*license*' -o -iname '*.txt' \) -exec sh -c 'echo "== $1"; head -8 "$1"' _ {} \;
du -sh "$OUT"
