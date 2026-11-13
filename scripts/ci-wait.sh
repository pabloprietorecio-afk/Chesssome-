#!/usr/bin/env bash
# Espera a que termine la CI del último commit, enseña el resultado y descarga las capturas.
set -uo pipefail
cd "$(dirname "$0")/.."
REPO=pabloprietorecio-afk/chesssome-
SHA=$(git rev-parse HEAD)
for i in $(seq 1 60); do
  LINE=$(gh api "repos/$REPO/actions/runs?head_sha=$SHA&per_page=1" --jq '.workflow_runs[0] | "\(.id) \(.status) \(.conclusion // "")"' 2>/dev/null || true)
  case "$LINE" in *completed*) break;; esac
  sleep 15
done
echo "$LINE"
ID=${LINE%% *}
gh api "repos/$REPO/actions/runs/$ID/jobs" --jq '.jobs[] | "\(.name): \(.conclusion) " + ([.steps[] | select(.conclusion=="failure") | .name] | join(", "))'
./scripts/fetch-shots.sh > /dev/null 2>&1 && git log -1 --format='capturas: %s' origin/ci-shots
grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|^ERROR|FALLA|HAY FALLOS" shots/ci/*.log 2>/dev/null | cut -c1-220 | sort | uniq -c | head -20 || true
