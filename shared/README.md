# shared/

Build-time shared Lua. Anything here (besides this README) is copied into
each mod as `lib/shared/` by `scripts/dev.sh`, `scripts/pack.sh` and the
release workflow, so packed zips stay self-contained.

`skylib.lua` holds the species helpers both mods use: icon-class lookup,
the mount sprite resolver, the dex-height draw scale, and type/move
checks.

The mount resolver first tries `Sky.SPRITE_SOURCES`, an ordered list of
adapters over other mods' exports (currently Wilds of Kanto,
`overworld_wild_spawns`). When such a mod is enabled, our flyers borrow
its per-species in-air art: everything we draw is airborne, so adapters
resolve flying or hovering sheets only (Wilds' animated "levitates"
sheets), never its ground walk cycles, which read as walking on air.
Species without in-air art keep the generic bird/monster/seel/fairy
mount sheets, which are drawn mid-flight. To support another sprite
mod, add an adapter with its mod id and a
`resolve(exports, game, species, dex)` returning a SpriteRenderer def.
