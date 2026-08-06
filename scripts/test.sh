#!/usr/bin/env bash
# Sync the mods into the gen1recomp checkout and run each headless suite
# against the installed copies in its mods/ folder, the same files the
# game loads, so a sync bug fails the tests too.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN1="${GEN1RECOMP_DIR:-$HOME/Development/Projects/pokemon/gen1recomp}"
TARGET="${GEN1RECOMP_MODS_DIR:-$GEN1/mods}"

"$ROOT/scripts/dev.sh"

# The modkit SDK resolves mod paths relative to the engine checkout, so
# MOD_DIR must be relative; an absolute path makes discovery silently
# find nothing (the load tests assert against exactly that).
cd "$GEN1"
for mod in free_fly wild_skies; do
  for t in "mods/$mod"/tests/*.lua; do
    MOD_DIR="mods/$mod" luajit "$t"
  done
done
