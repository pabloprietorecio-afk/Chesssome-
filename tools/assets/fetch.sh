#!/usr/bin/env bash
# Descarga texturas candidatas de bibliotecas de dominio público (CC0) para elegirlas a ojo.
# Se ejecuta en la CI (desde el entorno de desarrollo no hay acceso a esos sitios) y deja el resultado
# en build/assets, que el flujo publica en la rama «assets-src».
#
# Fuentes y licencias (verificadas el 13 nov 2026):
#   Poly Haven  — todos los recursos son CC0 (https://polyhaven.com/license). La API es gratuita, también para
#                 uso comercial, y pide una cabecera User-Agent propia (https://polyhaven.com/our-api).
#   ambientCG   — todos los recursos son CC0 1.0 (https://docs.ambientcg.com/license).
set -uo pipefail
UA="Chessome-dev/0.1 (github.com/pabloprietorecio-afk/Chesssome-; seleccion de texturas CC0)"
OUT=build/assets
mkdir -p "$OUT/thumbs" "$OUT/files"
get() { curl -sS -L --retry 3 --max-time 120 -A "$UA" "$@"; }

# 1. Catálogos.
get "https://api.polyhaven.com/assets?type=textures" -o "$OUT/polyhaven_textures.json" || true
get "https://api.polyhaven.com/assets?type=hdris" -o "$OUT/polyhaven_hdris.json" || true
get "https://ambientcg.com/api/v2/full_json?type=Material&category=Wood&limit=250&include=downloadData%2CpreviewData&sort=Popular" -o "$OUT/ambientcg_wood.json" || true
ls -la "$OUT"
head -c 600 "$OUT/polyhaven_textures.json"; echo
head -c 900 "$OUT/ambientcg_wood.json"; echo

# 2. Miniaturas de las maderas y de los entornos de estudio de Poly Haven.
if [ "${STAGE:-thumbs}" = "thumbs" ] && [ ! -f tools/assets/want.txt ]; then
  jq -r 'to_entries[] | select(((.value.categories // []) | map(ascii_downcase) | index("wood")) != null) | "\(.key)\t\(.value.thumbnail_url // "")"' "$OUT/polyhaven_textures.json" > "$OUT/wood_ids.tsv" || true
  jq -r 'to_entries[] | select(((.value.categories // []) | map(ascii_downcase) | index("studio")) != null) | "\(.key)\t\(.value.thumbnail_url // "")"' "$OUT/polyhaven_hdris.json" > "$OUT/studio_ids.tsv" || true
  wc -l "$OUT"/*.tsv
  while IFS=$'\t' read -r id url; do
    [ -n "$url" ] || url="https://cdn.polyhaven.com/asset_img/thumbs/$id.png?width=256&height=256"
    get "$url" -o "$OUT/thumbs/tex_$id.img" || true
  done < "$OUT/wood_ids.tsv"
  while IFS=$'\t' read -r id url; do
    [ -n "$url" ] || url="https://cdn.polyhaven.com/asset_img/thumbs/$id.png?width=256&height=256"
    get "$url" -o "$OUT/thumbs/hdri_$id.img" || true
  done < "$OUT/studio_ids.tsv"
  ls "$OUT/thumbs" | wc -l
fi

# 3. Archivos elegidos (tools/assets/want.txt): «textura <id> <resolución> <mapa>…» o «hdri <id> <resolución>».
if [ -f tools/assets/want.txt ]; then
  grep -v '^#' tools/assets/want.txt | while read -r kind id res maps; do
    [ -n "${kind:-}" ] || continue
    get "https://api.polyhaven.com/files/$id" -o "$OUT/files/$id.files.json" || continue
    if [ "$kind" = "hdri" ]; then
      url=$(jq -r --arg r "$res" '.hdri[$r] | (.hdr // .exr) | .url' "$OUT/files/$id.files.json")
      [ "$url" != "null" ] && get "$url" -o "$OUT/files/${id}_${res}.${url##*.}"
    else
      for map in $maps; do
        url=$(jq -r --arg m "$map" --arg r "$res" 'to_entries[] | select((.key | ascii_downcase) == ($m | ascii_downcase)) | .value[$r] | (.jpg // .png) | .url' "$OUT/files/$id.files.json" | head -1)
        if [ -n "$url" ] && [ "$url" != "null" ]; then get "$url" -o "$OUT/files/${id}_${map}_${res}.${url##*.}"; else echo "sin mapa $map en $id"; jq -r 'keys | join(" ")' "$OUT/files/$id.files.json"; fi
      done
    fi
  done
fi

# 4. ambientCG (tools/assets/ambientcg.txt): «categoria <Nombre>» descarga las miniaturas de una categoría;
#    «zip <Id> <1K-JPG>» descarga ese paquete y saca los mapas de color, normales y rugosidad.
if [ -f tools/assets/ambientcg.txt ]; then
  grep -v '^#' tools/assets/ambientcg.txt | while read -r kind name attr; do
    [ -n "${kind:-}" ] || continue
    if [ "$kind" = "categoria" ]; then
      get "https://ambientcg.com/api/v2/full_json?type=Material&category=$name&limit=250&include=downloadData%2CpreviewData&sort=Popular" -o "$OUT/ambientcg_$name.json" || continue
      jq -r '.foundAssets[] | "\(.assetId)\t\(.previewImage["256-JPG-FFFFFF"] // .previewImage["256-PNG"] // "")"' "$OUT/ambientcg_$name.json" > "$OUT/ambientcg_$name.tsv" || true
      wc -l "$OUT/ambientcg_$name.tsv"
      while IFS=$'\t' read -r id url; do
        [ -n "$url" ] && get "$url" -o "$OUT/thumbs/acg_$id.img" || true
      done < "$OUT/ambientcg_$name.tsv"
    elif [ "$kind" = "zip" ]; then
      mkdir -p "$OUT/tmp" && get "https://ambientcg.com/get?file=${name}_${attr}.zip" -o "$OUT/tmp/$name.zip" || continue
      unzip -l "$OUT/tmp/$name.zip" || true
      unzip -q -o -j "$OUT/tmp/$name.zip" '*_Color.jpg' '*_NormalGL.jpg' '*_Roughness.jpg' -d "$OUT/files" || true
      rm -rf "$OUT/tmp"
    fi
  done
fi
du -sh "$OUT"; ls -la "$OUT/files" | head -80
