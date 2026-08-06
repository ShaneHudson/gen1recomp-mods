# Development

The repo holds both mods with one shared version number. `shared/` is
copied into each mod as `lib/shared/` by the scripts, so packed zips are
self-contained; edit shared code only in `shared/`.

```sh
scripts/dev.sh    # install both mods into the game's save-dir mods folder
scripts/pack.sh   # validate + pack each mod into dist/<id>-<version>.zip
```

`dev.sh` targets `~/Library/Application Support/LOVE/pokemon-love2d/mods`
(override with `GEN1RECOMP_MODS_DIR`) and never writes to a gen1recomp
checkout. `pack.sh` needs a gen1recomp checkout for modkit (default
`~/Development/Projects/pokemon/gen1recomp`, override `GEN1RECOMP_DIR`).

In game, run with developer mode (`love . --developer` from a gen1recomp
checkout) and F5 hot-reloads the mods after `dev.sh`.

## Tests

Each mod has a headless load suite. Run from a gen1recomp checkout:

```sh
MOD_DIR=/path/to/gen1recomp-mods/free_fly \
  luajit /path/to/gen1recomp-mods/free_fly/tests/free_fly_load_test.lua
```

## Releases

Push to `main` (or run the workflow manually) and CI packs every mod and
publishes one release. The version is the highest manifest version (or a
`[release X.Y.Z]` commit-message override), and each asset is named
`<id>-<version>.zip`, which is how the game's updater picks the right
download per installed mod. Markdown-only pushes don't trigger releases.
