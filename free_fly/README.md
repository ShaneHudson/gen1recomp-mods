# Free Fly

Ride a party member that knows FLY, freely. Take off anywhere outdoors,
soar over trees, water, fences and rooftops, cross route seams (the sea
included), and press B over open ground to land. That is the whole mod:
free flight, done carefully, with no dependencies.

Looking for a bigger mount system? Check out
[Dramatic Sky Ride](https://github.com/mfrtechconsult/dramatic-sky-ride):
it adds controllable flying, ground and surf mounts with stamina, boost
and airborne battles, and it depends on the
[Dramatic Shape Voxel Mod](https://github.com/DramaticShape/DramaticShapeVoxelMod)
plus a follower-sprite provider. Free Fly is the minimal alternative: one
mechanic, no dependencies, works in the flat 2D game and in voxel alike.

## Getting airborne

1. Have a party member that knows FLY (the species must be able to learn
   HM02, so a hacked-in FLY on the wrong species doesn't count).
2. Open its party submenu and pick FREEFLY.
3. Move as normal. The shadow under you turns green over ground you can
   land on; press B to set down. Blacking out also grounds you.

### The quick-start Pidgey

Vanilla makes you wait a long time for flight: HM02 sits in the Safari
Zone and FLY normally wants the THUNDERBADGE. As an optional shortcut, a
Pidgey waits in the middle of Pallet Town. Talk to it and it joins at
L10 already knowing FLY, exempt from the badge check, so you can fly
from the first minutes of a new game. One per save. If you'd rather earn
flight the long way, turn QUICK START off in the mod's options and the
bird never appears.

## Options

| Option | Default | What it does |
|---|---|---|
| ALTITUDE | MED | LOW / MED / HIGH cruise height (32 / 56 / 80 px) |
| FLY SPEED | NORMAL | NORMAL / FAST / TURBO ground speed |
| AIR ENCOUNTERS | ON | brushing a wild_skies flyer starts its battle |
| TRAINERS SPOT YOU | OFF | hardcore: trainer sight works on flyers |
| STORY GATES | ON | badge-gated areas (Route 23) refuse airborne entry |
| BADGE CHECKS | ON | vanilla badges: THUNDERBADGE to fly, SOULBADGE to land on water (the gift Pidgey is exempt from the fly check) |
| QUICK START | ON | the Pallet Town Pidgey |

## What flying changes, and what it doesn't

While airborne: terrain doesn't block you, doors don't pull you in,
trainers don't spot you (unless you opt in), step events (locked doors,
gate guards, spinners, poison) wait for you to land, the Cycling Road
doesn't demand a bicycle until you land on it, saving is blocked (so a
save can never strand you mid-air), and ground battles can't reach you.
Crossing a seam whose landing is open water asks "That looks dangerous!"
once per map. Landing on water with a SURF knower in the party puts you
straight into surfing; taking off from a surf works too.

You still cannot fly indoors or in caves (entering one ends the flight),
into badge-gated areas you haven't earned, or away from a battle.

You ride the Pokémon you picked: its menu-icon class chooses the mount
sprite from your own imported game data, sized by its Pokédex height, so
a Charizard carries you visibly bigger than a Pidgey.

## Works well with

Tested alongside these, with the versions noted (later versions may add
overlapping features of their own, so check their changelogs):

- [Dramatic Shape Voxel Mod](https://github.com/DramaticShape/DramaticShapeVoxelMod)
  (tested with 1.6.0): full support. Flight clears voxel rooftops at a
  fixed absolute altitude, the camera and tilt-shift focus follow the
  bird, first and third person movement work airborne, and first person
  gets a cockpit view of your mount.
- [Overworld Wild Encounters](https://github.com/gamecorner-033/Gen1PC-OverworldEncounters)
  (tested with 0.0.5): its roaming ground Pokémon cannot start battles
  against you while you fly over them; land and everything is vanilla.
- [wild_skies](../wild_skies): ambient flying Pokémon in the sky, which
  this mod lets you intercept mid-air for a battle.

## Install

Grab `free_fly-<version>.zip` from
[releases](https://github.com/ShaneHudson/gen1recomp-mods/releases) and
import it in game: MODS > Import mod .zip. Updates then appear in the
mod manager automatically.

Known rough edges are listed in `mod.card`.

Pokémon is a trademark of Nintendo; the Gen 1 games are © Nintendo /
Creatures Inc. / GAME FREAK inc. Unofficial fan mod; no ROMs, no
copyrighted game content. See the repository NOTICE.md.
