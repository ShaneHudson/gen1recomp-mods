# Wild Skies

Adds flying Pokémon to the overworld. Species come from each map's own
encounter table, so Pidgey and Spearow cross the early routes and the
Zubat line comes out at night. They cast shadows, flap their wings, and
are sized by their Pokédex height. Sea routes get a few birds too, even
though their encounter slots have no flyers.

Flyers vary their behaviour: most cross the screen and leave, some land
on the grass for a few seconds before moving on, and some start perched
on the ground and fly off when you get close. If you reach a low one
before it gets away, a normal wild battle starts with that species and
level. High flyers never trigger battles from the ground. If you also
have [free_fly](../free_fly) installed, flying into one starts its
battle mid-air.

![Demo](https://raw.githubusercontent.com/ShaneHudson/gen1recomp-mods/main/.github/wild_skies-demo.gif)

## Options

| Option | Default | What it does |
|---|---|---|
| SKY DENSITY | MED | LOW / MED / HIGH flyer caps and spawn cooldowns |
| GROUND BUMPS | ON | low birds (perched, landing, flushed) can battle a walking player |

## Works well with

Tested alongside these, with the versions noted (later versions may add
overlapping features of their own, so check their changelogs):

- [Overworld Wild Encounters](https://github.com/gamecorner-033/Gen1PC-OverworldEncounters)
  (tested with 0.0.5): recommended. It puts visible roaming Pokémon on
  the ground while this mod handles the sky, and the flyers landing and
  taking off fit right in alongside its roamers. Battles don't overlap:
  its roamers handle the ground, this mod's birds handle the air.
- [Dramatic Shape Voxel Mod](https://github.com/DramaticShape/DramaticShapeVoxelMod)
  (tested with 1.6.0): flyers billboard in the 3D diorama with real
  altitude.
- [free_fly](../free_fly): aerial interception; also the source of the
  mount-riding flight this mod's birds share their sky with.

For a full mount system (controllable flying, ground and surf mounts),
see [Dramatic Sky Ride](https://github.com/mfrtechconsult/dramatic-sky-ride).
This mod only adds ambient wildlife.

## For mod authors

`exports.flyerAt(cellX, cellY, radius)` reads the nearest flyer,
`exports.takeFlyer(...)` consumes it and returns its species and level.
That is the supported seam free_fly's interception uses; nothing needs
to reach into this mod's internals.

## Install

1. Download `wild_skies-<version>.zip` from the
   [releases page](https://github.com/ShaneHudson/gen1recomp-mods/releases).
2. In the game, open MODS from the pause menu (or press F10) and pick
   Import mod .zip.
3. Enable the mod in the same menu.

Updates show up in the mod manager automatically once installed.

Known rough edges are listed in `mod.card`.

Pokémon is a trademark of Nintendo; the Gen 1 games are © Nintendo /
Creatures Inc. / GAME FREAK inc. Unofficial fan mod; no ROMs, no
copyrighted game content. See the repository NOTICE.md.
