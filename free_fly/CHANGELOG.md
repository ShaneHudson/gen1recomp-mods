# Changelog

## 0.9.2

- Migration: saves from before 0.9.0 re-mark the gift PIDGEY (first
  FLY-knowing Pidgey when the taken flag is set), so BADGE CHECKS keeps
  exempting it and FREEFLY reappears.

## 0.9.1

- The mount is sized by its dex height (0.85x-1.6x): a Charizard carries
  you visibly bigger than a Pidgey, the rider sits higher on a taller
  mount, and the shadow scales to match.

## 0.9.0

- BADGE CHECKS option (default on): FREEFLY wants the THUNDERBADGE and
  water landings want the SOULBADGE, like vanilla's field moves. The
  Pallet gift Pidgey is exempt from the fly check (marked on the mon, so
  it persists in the save); the surf check has no exemption.

## 0.8.1

- FREEFLY only appears on mons whose species can learn HM02 FLY (the same
  tmhm list the machine-teach path checks), on top of knowing the move. A
  save-edited or mod-injected FLY on an ineligible species no longer
  offers a ride.

## 0.8.0

- Sea-crossing confirm: an airborne seam whose landing tile is water asks
  "That looks dangerous!" once per map (CROSS / TURN BACK), remembered in
  the save. Story-gated maps still hard-refuse first.
- Mount identity: you ride the mon you picked. Its party-icon class maps
  to a real walker sheet (bird/monster/seel/fairy), so Charizard carries
  you as the monster sprite, works in voxel too. Icon-only classes keep
  the bird.
- Water landing: B over water with a SURF-knower in the party sets you
  down surfing. Taking off while surfing dismounts into the air, so
  fly-surf-fly round trips work.

## 0.7.0

- STORY GATES (default on): flying across a seam into a badge-gated map
  you haven't earned bounces you with "A fierce wind blows you back!".
  Driven by the engine's own field.badgeGates data (Route 23's guard
  ladder, gate-building badges), so modded gates are respected too. Turn
  the option off for full sandbox flight.

## 0.6.0

- Aerial interception: while airborne, brushing a wild_skies flyer starts
  that exact wild battle, consumed through wild_skies' exports API. Short
  cooldown so a battle can't chain-trigger.
- Options pane: ALTITUDE (LOW/MED/HIGH), FLY SPEED (NORMAL/FAST/TURBO),
  AIR ENCOUNTERS toggle, TRAINERS SPOT YOU hardcore toggle. Altitude
  changes apply mid-flight.
- Landing feedback: the shadow shrinks with height and turns green over
  ground you can land on; a refused landing bumps audibly.
- Performance: the voxel ground-height lookup is cached per cell, the
  wild_skies handle resolves once per load, and the trainer-sight gate is
  hot-reload-swappable.

## 0.5.0

- Airborne encounters filter to FLYING species instead of being fully
  suppressed: flying over grass can flush a Pidgey, never a Rattata. A
  battle you win or flee resumes the flight.

## 0.4.1

- Voxel: altitude is absolute now. The scene adds the ground height back
  under the card, so buildings no longer stack on top of the cruise
  height; the lift shrinks over roofs (min 10px clearance), read from the
  voxel mod's own TileShape data via its exports.lib.
- The camera (and with it the tilt-shift focus band) follows the bird
  instead of the ground point, so the rider stays sharp in voxel and
  centred in 2D. Cell-to-cell height changes ease instead of snapping.

## 0.4.0

- Cruise altitude raised 16 -> 56 px so flight clears voxel rooftops (a
  6-row house extrudes to 48px); climb rate raised to match.
- Blacking out ends the flight: you wake at the heal point grounded
  instead of still airborne. A battle survived mid-air keeps you flying,
  since force-landing could drop you on water.

## 0.3.1

- Fix crash on FREEFLY: the rider ghost entity lacked px/py, which the
  overworld's y-sort and the voxel capture both read.

## 0.3.0

- The ride now shows in voxel and tilt modes: the player's billboard
  becomes the flapping bird and a ghost rider entity carries the player
  figure seated above it. The flat 2D composite is unchanged.

## 0.2.0

- A Pidgey waits in Pallet Town: talk to it and it joins at L10 already
  knowing FLY, then despawns for that save.
- Riding look: airborne the player sits on the bird sheet (mount + rider
  composed from the player's own cache), with flapping wings.
- Flight crosses map seams over water; the connection landing check is
  gated while airborne.
- Takeoff plays the FLY jingle.
- FREEFLY no longer requires the THUNDERBADGE, only a mon that knows FLY.

## 0.1.0

- First proof of concept: FREEFLY party action, free-roam flight with lift
  and shadow, B to land on walkable ground, encounter/warp/trainer/save
  gating while airborne.
