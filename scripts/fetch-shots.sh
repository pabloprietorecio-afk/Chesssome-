#!/usr/bin/env bash
# Descarga las capturas que la CI publica en la rama ci-shots a una carpeta local (por defecto, shots/ci).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-shots/ci}"
# main publica en ci-shots; las demás ramas, en ci-shots-<rama>.
BRANCH=$(git rev-parse --abbrev-ref HEAD)
SHOTS=ci-shots
if [ "$BRANCH" != "main" ]; then SHOTS="ci-shots-${BRANCH//\//-}"; fi
git fetch -q origin "+$SHOTS:refs/remotes/origin/$SHOTS"
mkdir -p "$OUT"
# Fuera las capturas de la tanda anterior (solo imágenes y registros de esa carpeta).
find "$OUT" -maxdepth 1 -type f \( -name '*.png' -o -name '*.log' \) -delete
git archive "origin/$SHOTS" | tar -x -C "$OUT"
git log -1 --format='%s' "origin/$SHOTS"
ls "$OUT"
