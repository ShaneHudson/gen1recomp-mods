# Wild Skies

The sky over Kanto is alive. Flying Pokémon from each map's own
encounter table visibly cross the overworld: shadows tracking on the
ground, wings flapping, sized by their Pokédex height. Pidgey and
Spearow sweep the early routes, Fearow rides high with a faded distant
shadow, and after dark the Zubat line takes over. Sea routes get a
sparse gull-life of their own even though their encounter slots hold no
flyers.

They behave like birds, not screensavers: most cross the whole view,
some descend mid-flight to rest on the grass before moving on, and some
start perched in a field and flush away when you run at them. Corner a
low one fast enough and it turns into a real wild battle (its actual
species and level); anything cruising high is safe scenery from the
ground. With [free_fly](../free_fly) installed, you can chase the sky
itself: brushing a flyer mid-air starts its battle.

## Options

| Option | Default | What it does |
|---|---|---|
| SKY DENSITY | MED | LOW / MED / HIGH flyer caps and spawn cooldowns |
| GROUND BUMPS | ON | low birds (perched, landing, flushed) can battle a walking player |

## Works well with

Tested alongside these, with the versions noted (later versions may add
overlapping features of their own, so check their changelogs):

- [Overworld Wild Encounters](https://github.com/gamecorner-033/Gen1PC-OverworldEncounters)
  (tested with 0.0.5): the natural companion. It fills the ground with
  visible roaming Pokémon while this mod fills the sky, and the flyers'
  landings and takeoffs read as part of the same living ecosystem: a
  bird settling in the grass beside its roamers, then lifting off again.
  Battles stay cleanly separated: its roamers own the ground game, this
  mod's birds own the air.
- [Dramatic Shape Voxel Mod](https://github.com/DramaticShape/DramaticShapeVoxelMod)
  (tested with 1.6.0): flyers billboard in the 3D diorama with real
  altitude.
- [free_fly](../free_fly): aerial interception; also the source of the
  mount-riding flight this mod's birds share their sky with.

For a full mount system (controllable flying, ground and surf mounts),
see [Dramatic Sky Ride](https://github.com/mfrtechconsult/dramatic-sky-ride);
this mod deliberately stays ambient.

## For mod authors

`exports.flyerAt(cellX, cellY, radius)` reads the nearest flyer,
`exports.takeFlyer(...)` consumes it and returns its species and level.
That is the supported seam free_fly's interception uses; nothing needs
to reach into this mod's internals.

## Install

Grab `wild_skies-<version>.zip` from
[releases](https://github.com/ShaneHudson/gen1recomp-mods/releases) and
import it in game: MODS > Import mod .zip. Updates then appear in the
mod manager automatically.

Known rough edges are listed in `mod.card`.

Pokémon is a trademark of Nintendo; the Gen 1 games are © Nintendo /
Creatures Inc. / GAME FREAK inc. Unofficial fan mod; no ROMs, no
copyrighted game content. See the repository NOTICE.md.
