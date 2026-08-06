# Changelog

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
