# Changelog

## 1.2.0

- Voxel: the rooftop compensation is applied instantly instead of eased,
  which removes the hop the rider did over every fence and small object
  (the scene snaps its ground height per cell; the ease lagged it).
- Seam prefetch: while airborne, the maps ahead (every connection of
  the current map, and their connections one hop further) are warmed
  into the engine's map cache at one load per tick, so fast flight
  crosses seams without the load hitch. In voxel, the same prefetch also
  queues each warmed map's chunk mesh through DRAMATIC_SHAPE's own build
  pump (the identical body-only request its scene makes for neighbours),
  so a flown-into map doesn't drop to the flat 2D fallback while it
  meshes.
- Very tall buildings are no-fly walls: an exterior door whose interior
  spans three or more floor maps (dept store, Silph Co, Pokemon Tower,
  Celadon Mansion) marks its building footprint as blocked while
  airborne, so you fly up to the facade and bump instead of clipping
  through. Derived from map data, never an authored list; small houses
  stay fly-over. Basements don't count as floors, cave interiors never
  qualify (Seafoam, Mt Moon, Victory Road stay flyable), and the bar is
  four floors above ground, so Cinnabar's mansion with its small drawn
  exterior stays fly-over while the true towers block.
- Fix: tapping SELECT with no bicycle no longer also shows Quick
  Select's "You don't have a BICYCLE" (its raw press-queue branch saw
  the tap before we consumed it).
- Ledges no longer hijack an airborne step into the vanilla hop (the
  arc used to stack on the flight lift); a flyer just crosses them.
- Voxel: visual flight height raised to 75% (was 60%), balanced by the
  camera tracking only part of the lift so the rider reads smaller and
  further away. An earlier build used a real zoom rung for this, which
  enlarged the rendered chunk set and stepped up the shadow-map
  resolution: that was the building lag while airborne, and it's gone.

## 1.1.0

- Eligibility defers to the engine and other mods: the species must be
  HM02-compatible per the MERGED data (so compatibility-expanding mods
  count), and "knows FLY" is decided through the engine's
  fieldmove.eligibility chain, so HM-relaxing mods like qol_toggles'
  FIELD MOVES ALL unlock FREEFLY exactly as they unlock FLY itself.
  Water landings route SURF through the same chain. This mod adds no
  eligibility rules of its own.
- Quick Select integration: with jj_quick_select installed (and only
  then), a FLY WHISTLE key item appears in the bag. Register it to a
  SELECT+direction slot and it toggles flight: takeoff with the first
  eligible partner, landing while airborne. With no BICYCLE in the bag,
  tap-SELECT defaults to flight instead of the "You don't have a
  BICYCLE" message (hold+direction slots keep working); owning a bicycle
  restores Quick Select's native tap. Without quick select none of this
  exists and nothing changes.

## 1.0.0

- 1.0.0: first public release. QUICK START option (default on) gates
  the Pallet Town gift Pidgey; MIT license.

## 0.12.0

- 2D riding reads as riding: the rider draws first, tucked low, and the
  mount draws over it, so the crop line hides behind the mount's body
  instead of a head floating above a gap.
- Voxel: the visual flight height runs at 60% while a voxel pipeline is
  active, so the card stops looming at the pitched camera; 2D keeps the
  full altitude, and rooftop clearance still applies on top.

## 0.11.3

- While airborne, the only wild battle that can start is one this mod
  asked for (interception). Ground roamers from other mods
  (overworld_encounters) collide by ground cell and were battling
  overflying players; their battles are now gated at BattleState.newWild
  until you land.

## 0.11.2

- Cockpit view keys off FirstPerson.hidePlayer() (true only when the eye
  hides your card) instead of engaged(), which was also true in third
  person; a one-shot log line reports why the overlay is or isn't
  drawing.
- AIR ENCOUNTERS now governs aerial interception. Airborne grass rolls
  ended with 0.11.1's step-trigger skip, so visible birds are the one
  source of airborne battles, and this option is their switch.

## 0.11.1

- Step triggers no longer fire under an airborne player: locked-door
  scripts ("The door is locked!"), gate guards, spinner tiles and poison
  step ticks all wait until you land.

## 0.11.0

- First-person rider view: while airborne with DRAMATIC_SHAPE's first
  person engaged, the mount draws bottom-center of the view, back-facing,
  flapping and bobbing, sized by its dex scale. First person hides the
  player card (which IS the mount), so this is how the rider sees their
  bird.

## 0.10.1

- Safety: loading a save always grounds the flight state machine, so a
  stale airborne phase can never follow the player into a fresh save.

## 0.10.0

- Voxel first/third person: movement works airborne (their FreeMove runs
  its own collision, now wrapped with a flight-scoped permissive window),
  and the mount is visible because it becomes the player's sprite sheet
  for the flight's duration; the walking sheet returns on landing.
- Hard guarantee against indoor flight: entering any non-outside map
  (caves included) while airborne ends the flight on arrival, on top of
  the existing takeoff and door gates.

## 0.9.6

- Flying over the Cycling Road no longer triggers the "You need a
  BICYCLE" alert or a mid-air force-mount; forced-movement tiles only
  apply again once you land on them.

## 0.9.5

- An aerial interception plays the caught species' cry, so a battle
  never starts without an audible cause.

## 0.9.4

- Shared helpers (icon-class mounts, dex scale, type/move checks) moved
  to the monorepo's shared/skylib.lua, synced in as lib/shared/. No
  behavior change.

## 0.9.3

- Fix: the sea-crossing ask's cooldown never decayed, so answering TURN
  BACK silently blocked all later attempts. It now re-asks on each try
  (1-2s apart) until the player says CROSS.

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
