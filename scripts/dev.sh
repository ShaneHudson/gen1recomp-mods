#!/usr/bin/env bash
# Install every mod into the game's own save-directory mods/ folder (the
# same place MODS > Import mod .zip installs to). The gen1recomp checkout
# is never written to; the monorepo is canonical.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${GEN1RECOMP_MODS_DIR:-$HOME/Library/Application Support/LOVE/pokemon-love2d/mods}"

mkdir -p "$TARGET"

for mod in free_fly wild_skies; do
  rsync -a --delete --exclude '.git' "$ROOT/$mod/" "$TARGET/$mod/"
  echo "installed $mod -> $TARGET/$mod"
done
