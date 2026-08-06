# Changelog

## 1.3.1

- A classic step encounter that rolls a species with a lookalike within
  two cells of the player now consumes that bird: it carries its own
  level into the battle, and a defeat or capture never leaves it
  perched there or flying off. When a grounded and a flying match are
  both close, the grounded one is the battle.
- For mod authors (see INTEGRATION.md in the repository):
  `exports.spawnFlyer(species, level)` spawns one flyer on demand, the
  `mod.wild_skies.flyer_bumped` event broadcasts ground-bump battles,
  and `exports.registerSpriteSource` lets sprite packs offer in-air
  art. The ground-bump gate now reads free_fly's exported flight state
  instead of the raw player field.

## 1.3.0

- Wilds of Kanto integration: with that mod enabled, flyers wear its
  per-species "levitates" art, so a crossing Fearow looks like a Fearow
  instead of the generic bird sheet. Only its in-air sheets are
  borrowed, never its Sprite Style selection: all three of its styles
  (HGSS/PokeMMO, Poke Followers, Pokedex) are ground walk cycles, and a
  walk cycle toggled in the sky reads as walking on air. The levitates
  sheets are that mod's only flying poses and are style-independent by
  its own design (its water Pokemon ignore Sprite Style the same way),
  so the chosen style shows on the ground and the flying pose rules the
  sky. Species without a levitates sheet (Pidgey, Spearow) keep the
  generic sheets, which are at least drawn mid-flight.
- Those levitates sheets are drawn hovering over water, splash included;
  the splash (one flat color across the whole set) is keyed out at load,
  so borrowed art carries no water into the sky.
- Big wings beat slower: the flap rate eases with dex size, so a Fearow
  flaps calmer than a Spearow.
- Sprite-source option changes re-dress live flyers immediately instead
  of waiting for the next spawn.

## 1.2.0

- Forest sky-life, sparse by design: Viridian Forest gets the ambient
  pool at one bird at a time with long cooldowns, cruising low to weave
  between the trunks. The Safari Zone needs no special case: its own
  encounter slots carry Doduo, so slot spawns work there as anywhere.
- Flyers survive seamless map crossings: they translate with the same
  coordinate rebase the player gets instead of despawning at the seam.
  Warps and doors still clear the sky as before.

## 1.0.0

- 1.0.0: first public release, lockstep with free_fly. MIT license.

## 0.5.0

- GROUND BUMPS (option, default on): a bird at or below 12px, perched,
  landing or freshly flushed, can collide with a WALKING player and
  start its battle (cry plays, 1-cell reach). High flyers never touch
  anyone at ground level; airborne players remain free_fly's business.

## 0.4.1

- Fix phantom encounters: ambient skies require the map to carry an
  encounter table (towns like Cinnabar stay quiet), airborne spawns
  refuse to materialize within 5 cells of the player, and newborn or
  dead flyers are invisible to the inter-mod collision API for 0.75s.

## 0.4.0

- Sea skies: outdoor maps with no flying grass slots (Routes 19-21) get a
  sparse ambient pool (Pidgey/Spearow lines by day, Zubat line at night)
  at a reduced cap and longer cooldown.
- Behavior repertoire: some flyers land mid-crossing and rest, some start
  perched and flush away when the player comes within 2 cells; resting
  birds stand and peck instead of flapping.
- Height variety: about a third fly high, and the shadow fades and
  tightens with altitude as a depth cue.

## 0.3.2

- Shared helpers (icon-class mounts, dex scale, type/move checks) moved
  to the monorepo's shared/skylib.lua, synced in as lib/shared/. No
  behavior change.

## 0.3.1

- Flyers are sized by their dex height (scaled 0.85x-1.6x around the foot
  anchor, shadow included): Pidgey reads small, a Charizard-class flyer
  reads big.

## 0.3.0 (Phase 2)

- Flyers glide in from just past the camera edge and cross the whole
  view; no more mid-screen pop-in (world edges are the one exception).
- Species identity: each flyer wears its party-icon class walker sheet
  (bird/monster/seel/fairy) with a per-class flight profile (speed band,
  altitude band, flap rate, bob depth).
- Time of day: Zubat and Golbat own the night sky and sit out daylight;
  the slot cache keys on (map, tod) so day/night mods drive rotation.
- SKY DENSITY option: LOW / MED / HIGH spawn caps and cooldowns.

## 0.2.0

- Inter-mod API: `exports.flyerAt(cellX, cellY, radius)` and
  `exports.takeFlyer(...)` let other mods (free_fly's aerial
  interception) read and consume flyers without touching internals.
- Performance: the FLYING-slot filter is cached per map instead of
  recomputed per frame, and flyer-less maps re-arm a long cooldown.

## 0.1.0

- Proof of concept: ambient flyers from the map's FLYING grass slots,
  shadow + bob + flap on the imported SPRITE_BIRD sheet, spawn cap and
  cooldown, despawn at map edge or timeout.
