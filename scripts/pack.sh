#!/usr/bin/env bash
# Validate and pack every mod into dist/<id>-<version>.zip using the game
# repo's modkit. Local equivalent of the release workflow's build step.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${GEN1RECOMP_DIR:-$HOME/Development/Projects/pokemon/gen1recomp}"
MODKIT="$GAME/tools/modkit.py"

[ -f "$MODKIT" ] || { echo "modkit not found at $MODKIT (set GEN1RECOMP_DIR)"; exit 1; }

mkdir -p "$ROOT/dist"

for mod in free_fly wild_skies; do
  mkdir -p "$ROOT/$mod/lib/shared"
  rsync -a --delete --exclude 'README*' "$ROOT/shared/" "$ROOT/$mod/lib/shared/"
  version="$(python3 -c "import json;print(json.load(open('$ROOT/$mod/manifest.json'))['version'])")"
  python3 "$MODKIT" validate "$ROOT/$mod" --repo "$GAME" --base imported
  python3 "$MODKIT" pack "$ROOT/$mod" --repo "$GAME" \
    -o "$ROOT/dist/$mod-$version.zip"
  echo "packed dist/$mod-$version.zip"
done

(cd "$ROOT/dist" && shasum -a 256 ./*.zip > sha256sums.txt && cat sha256sums.txt)
