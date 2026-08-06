# Development

The repo holds both mods with one shared version number. `shared/` is
copied into each mod as `lib/shared/` by the scripts, so packed zips are
self-contained; edit shared code only in `shared/`.

```sh
scripts/dev.sh    # install both mods into the gen1recomp checkout's mods/
scripts/test.sh   # dev.sh + run each headless suite on the installed copies
scripts/pack.sh   # validate + pack each mod into dist/<id>-<version>.zip
```

`dev.sh` targets the gen1recomp checkout's `mods/` folder (default
`~/Development/Projects/pokemon/gen1recomp/mods`, override with
`GEN1RECOMP_MODS_DIR`). `pack.sh` needs a gen1recomp checkout for modkit
(default `~/Development/Projects/pokemon/gen1recomp`, override
`GEN1RECOMP_DIR`).

In game, run with developer mode (`love . --developer` from a gen1recomp
checkout) and F5 hot-reloads the mods after `dev.sh`.

## Tests

Each mod has a headless load suite. `scripts/test.sh` syncs and runs them
all against the installed copies in the gen1recomp checkout's `mods/`
folder, the same files the game loads. To run one suite by hand:

```sh
cd ~/Development/Projects/pokemon/gen1recomp
MOD_DIR=mods/free_fly luajit mods/free_fly/tests/free_fly_load_test.lua
```

## Releases

Push to `main` (or run the workflow manually) and CI packs every mod and
publishes one release. The version is the highest manifest version (or a
`[release X.Y.Z]` commit-message override), and each asset is named
`<id>-<version>.zip`, which is how the game's updater picks the right
download per installed mod. Markdown-only pushes don't trigger releases.
