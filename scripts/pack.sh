#!/usr/bin/env bash
# Validate and pack mods into dist/<id>-<version>.zip using the game
# repo's modkit. Local equivalent of the release workflow's build step.
#
# Usage: scripts/pack.sh [mod ...]   (no args = every mod)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${GEN1RECOMP_DIR:-$HOME/Development/Projects/pokemon/gen1recomp}"
MODKIT="$GAME/tools/modkit.py"

[ -f "$MODKIT" ] || { echo "modkit not found at $MODKIT (set GEN1RECOMP_DIR)"; exit 1; }

mods=("$@")
if [ ${#mods[@]} -eq 0 ]; then
  for m in "$ROOT"/*/manifest.json; do
    [ -f "$m" ] || continue
    mods+=("$(basename "$(dirname "$m")")")
  done
fi

mkdir -p "$ROOT/dist"

for mod in "${mods[@]}"; do
  mkdir -p "$ROOT/$mod/lib/shared"
  rsync -a --delete --exclude 'README*' "$ROOT/shared/" "$ROOT/$mod/lib/shared/"
  version="$(python3 -c "import json;print(json.load(open('$ROOT/$mod/manifest.json'))['version'])")"
  # --base auto validates against the imported ROM cache when one exists
  # (local runs) and the ROM-free fixture otherwise (CI).
  python3 "$MODKIT" validate "$ROOT/$mod" --repo "$GAME" --base "${MODKIT_BASE:-auto}"
  python3 "$MODKIT" pack "$ROOT/$mod" --repo "$GAME" \
    -o "$ROOT/dist/$mod-$version.zip"
  echo "packed dist/$mod-$version.zip"
done
