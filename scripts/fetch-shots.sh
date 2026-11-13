#!/usr/bin/env bash
# Descarga las capturas que la CI publica en la rama ci-shots a una carpeta local (por defecto, shots/ci).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-shots/ci}"
git fetch -q origin +ci-shots:refs/remotes/origin/ci-shots
mkdir -p "$OUT"
git archive origin/ci-shots | tar -x -C "$OUT"
git log -1 --format='%s' origin/ci-shots
ls "$OUT"
