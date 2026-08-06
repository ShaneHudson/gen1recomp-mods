#!/usr/bin/env bash
# Sync the mods into the gen1recomp checkout and run each headless suite
# against the installed copies in its mods/ folder, the same files the
# game loads, so a sync bug fails the tests too.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN1="${GEN1RECOMP_DIR:-$HOME/Development/Projects/pokemon/gen1recomp}"
TARGET="${GEN1RECOMP_MODS_DIR:-$GEN1/mods}"

"$ROOT/scripts/dev.sh"

cd "$GEN1"
for mod in free_fly wild_skies; do
  MOD_DIR="$TARGET/$mod" luajit "$TARGET/$mod/tests/${mod}_load_test.lua"
done
