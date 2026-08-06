# gen1recomp-mods

Mods for [gen1recomp](https://github.com/bryanthaboi/gen1recomp), kept in
one repo with lockstep versions and per-mod release downloads.

Pokémon is a trademark of Nintendo; the Gen 1 games are © Nintendo /
Creatures Inc. / GAME FREAK inc. This is an unofficial fan project that
ships no ROMs and no copyrighted game content; see [NOTICE.md](NOTICE.md).

| Mod | What it does |
|---|---|
| [`free_fly`](free_fly/) | Ride a FLY user: free-roam flight, story gates, badge checks, aerial interception |
| [`wild_skies`](wild_skies/) | Ambient flying Pokémon cross the map, sized and timed by species |

## Dev loop

```sh
scripts/dev.sh    # rsync both mods into the game's save-dir mods/ folder
```

Target defaults to `~/Library/Application Support/LOVE/pokemon-love2d/mods`
(override with `GEN1RECOMP_MODS_DIR`). The gen1recomp checkout is never
written to. In-game, F5 hot-reloads while developer mode is on.

## Packing

```sh
scripts/pack.sh   # validate + pack each mod into dist/<id>-<version>.zip
```

Needs a gen1recomp checkout for modkit (default
`~/Development/Projects/pokemon/gen1recomp`, override `GEN1RECOMP_DIR`).

## Releases

Push to `main` (or run the workflow manually) and CI builds every mod's
zip and publishes ONE release: the version is the highest manifest
version, and each asset is named `<id>-<version>.zip`, which is exactly
how the game's updater picks the right download per installed mod.

## Shared code

`shared/` is copied into each mod as `lib/shared/` at pack time. Runtime
inter-mod APIs (like wild_skies' `exports.takeFlyer`) stay the preferred
seam; `shared/` is for build-time helpers only.
