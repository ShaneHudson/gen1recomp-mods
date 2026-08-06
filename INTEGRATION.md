# Integrating with these mods

This is the reference for other mod authors. Everything below is a
supported seam: we test against it and try hard not to break it between
versions. Anything not listed here is internal and fair game for us to
rearrange, so please don't reach past the exports.

Both mods follow gen1recomp's two inter-mod channels. Exports are plain
functions you call, fetched through `mod.find(id)`, which returns nil
when the other mod is missing, disabled or failed to load. Events are
broadcasts: a mod may emit under its own `mod.<id>.*` prefix and anyone
can listen with `mod.events:on(name, fn)`.

```lua
local ff = mod.find("free_fly")
if ff and ff.exports.isFlying() then
  -- the player is airborne right now
end
```

Load order note: free_fly loads at priority 100 and wild_skies at 110.
If your mod loads earlier, call `mod.find` lazily (inside a handler or
tick) rather than at load time.

## free_fly

### Flight state

| Export | Returns |
|---|---|
| `isFlying()` | true while the player is airborne, takeoff and landing included |
| `altitude()` | current lift in pixels, 0 on the ground |
| `mount()` | `{ species, level }` of the mon carrying the player, or nil |

Prefer these over reading `player.freeFlying`. The field still exists
and still gets stamped, but the exports are the contract.

### Events

`mod.free_fly.takeoff` fires once per takeoff with
`{ species, level }` of the mount.

`mod.free_fly.landed` fires once per flight end with
`{ reason, x, y, water }`. The reason tells you how it ended:

- `landed`: a normal landing. `x, y` is the cell, `water` is true when
  the player set down on water and went straight into surfing.
- `indoors`: the player crossed into a cave or building, which ends the
  flight on arrival.
- `blackout`: the party wiped mid-air.
- `save_loaded`: a save swap grounded the state machine. No position in
  the payload, since the flight belonged to the previous save.

```lua
mod.events:on("mod.free_fly.landed", function(ev)
  if ev.reason == "landed" and ev.water then
    -- the player is now surfing at ev.x, ev.y
  end
end)
```

### Follower mods

By default free_fly manages the follower during flight: a FLYING-type
follower gets lifted into the air and trails the player, anything else
is despawned until landing, and the mon currently being ridden is never
also shown trailing.

If your mod wants to own that behaviour instead, export
`freeFlyAware = true`. free_fly then leaves your follower completely
alone, and you react to the takeoff and landed events yourself.

## wild_skies

### Reading and consuming flyers

`exports.flyerAt(cellX, cellY, radius)` returns `{ species, level }`
for the nearest live flyer within the radius, or nil. Newborn flyers
are invisible to this for their first moments, so nothing can collide
with a bird the player hasn't had a chance to see.

`exports.takeFlyer(cellX, cellY, radius)` does the same lookup but also
despawns the flyer and hands you its identity. This is how free_fly
turns a mid-air interception into that exact bird's battle.

### Spawning flyers

`exports.spawnFlyer(species, level)` puts one flyer into the current
map on demand. Entry point, cruise height and behaviour roll the same
way ambient spawns do, but the ambient caps and cooldowns are not
consulted, so a scenario mod can crowd the sky if it wants to. Returns
the flyer id, or nil plus a reason ("no overworld" when there's no map
loaded, or the species has no usable sprite and no clear entry point).

### Events

`mod.wild_skies.flyer_bumped` fires when a low bird collides with the
walking player and starts its battle. Payload:
`{ species, level, cellX, cellY }`.

## Sprite sources: offering in-air art

Both mods draw airborne creatures (wild flyers, the mount, the lifted
follower) through one shared resolver. Out of the box it borrows Wilds
of Kanto's "levitates" sheets when that mod is enabled, and falls back
to the engine's generic bird/monster/seel/fairy sheets.

If your mod ships flying or hovering art, you can register it as a
source and both mods will wear it:

```lua
local target = mod.find("free_fly")   -- and again for "wild_skies"
if target then
  target.exports.registerSpriteSource({
    id = "my_pack",
    resolve = function(exports, game, species, dex)
      local sheet = myArtFor(dex)
      if not sheet then return nil end
      return { image = sheet, frames = 6, walker = true, trueColor = true }
    end,
  })
end
```

The rules:

- A source needs an `id` or a `mod`. With `mod`, the source only runs
  while that mod is enabled, and its exports are passed as the first
  argument to `resolve`. With only an `id`, resolve gets nil there.
- `resolve(exports, game, species, dex)` returns a SpriteRenderer def:
  an `image` path, `frames`, `walker = true` for the engine's 6-frame
  stand/walk layout, `trueColor = true` for full-colour art. Return nil
  for species you don't cover and the resolver moves on.
- Defs must be animated (more than one frame). Flyers need wing flap,
  so a static image falls through to the next source.
- Set `stripWater = true` on the source if your sheets are drawn over a
  waterline like the levitates set; the splash colour gets keyed out
  before the art is used in the sky.
- Registered sources are tried before the built-ins, first registered
  wins among yours, and re-registering an id replaces the old one.
- Each mod bundles its own copy of the resolver, so register with every
  mod you want to dress. There's no shared global registry.

Sources are re-consulted when a spawn happens and whenever the source
mod's options change, so art that depends on a setting updates live.

## What we consume

For symmetry, the other side of the fence:

- Wilds of Kanto (`overworld_wild_spawns`): we resolve its levitates
  sheets through `exports.render.waterSpriteRegistry`. Its Sprite Style
  setting is deliberately not consulted in the air, because all three
  styles are ground walk cycles; the style you pick shows on land.
- PokePC Followers (`PokePCFollowers_VoxelMerge`): we read
  `exports.activeMon` to know who's following, and wrap the engine's
  follower update to lift or hide it during flight. Export
  `freeFlyAware` as above to opt out.
- Quick Select (`jj_quick_select`): free_fly registers a FLY WHISTLE
  item through its exports when it's installed.

If you maintain one of these and change a surface we use, open an issue
on this repo and we'll follow.
