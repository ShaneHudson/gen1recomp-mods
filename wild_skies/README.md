# Wild Skies (proof of concept)

FLYING-type Pokémon from the local encounter table visibly fly across the
map: shadow on the ground, bobbing flight, flapping wings. Ambient only in
this version; the full plan (species art, interception battles, voxel
altitude) lives in the project notes.

Try it:

```sh
python3 tools/modkit.py validate mods/wild_skies --base imported
love . --developer
# console (`): warp ROUTE_1 -- birds start crossing within a few seconds
```

Spawns only happen on maps whose grass slots contain a FLYING type (routes
get Pidgey/Spearow, caves get Zubat), capped at 3 at a time.
