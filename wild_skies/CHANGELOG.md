# Changelog

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
