# gen1recomp-mods

Mods for [gen1recomp](https://github.com/bryanthaboi/gen1recomp).

Pokémon is a trademark of Nintendo; the Gen 1 games are © Nintendo /
Creatures Inc. / GAME FREAK inc. This is an unofficial fan project that
ships no ROMs and no copyrighted game content; see [NOTICE.md](NOTICE.md).

| Mod | What it does |
|---|---|
| [`free_fly`](free_fly/) | Ride a FLY user around the overworld and land wherever you like |
| [`wild_skies`](wild_skies/) | Flying Pokémon from the encounter tables cross the overworld |

## Install

1. Download the zip you want (`free_fly-<version>.zip` or
   `wild_skies-<version>.zip`) from the
   [releases page](https://github.com/ShaneHudson/gen1recomp-mods/releases).
2. In the game, open MODS from the pause menu (or press F10) and pick
   Import mod .zip.
3. Enable the mod in the same menu.

Each mod's own README covers what it does and its options. Updates show
up in the game's mod manager automatically once a mod is installed.

## Development

The repo holds both mods with one shared version number. `shared/` is
copied into each mod as `lib/shared/` by the scripts, so packed zips are
self-contained.

```sh
scripts/dev.sh    # install both mods into the game's save-dir mods folder
scripts/pack.sh   # validate + pack each mod into dist/<id>-<version>.zip
```

`dev.sh` targets `~/Library/Application Support/LOVE/pokemon-love2d/mods`
(override with `GEN1RECOMP_MODS_DIR`) and never writes to a gen1recomp
checkout. `pack.sh` needs a gen1recomp checkout for modkit (default
`~/Development/Projects/pokemon/gen1recomp`, override `GEN1RECOMP_DIR`).

Releases: push to `main` (or run the workflow manually) and CI packs
every mod and publishes one release; the version is the highest manifest
version, and each asset is named `<id>-<version>.zip`, which is how the
game's updater picks the right download per installed mod.
