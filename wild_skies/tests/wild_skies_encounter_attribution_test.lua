-- A classic step encounter that rolls a species whose lookalike sits
-- perched or landing beside the player consumes that bird: its level
-- rides into the battle and the sprite despawns. Airborne, distant or
-- different-species birds are left alone.
package.path = "./?.lua;./?/init.lua;" .. package.path

local os = require("os")
local T = require("tests.modkit")
local Data = require("src.core.Data"); Data:load()

-- a hand-stitched overworld installed as the Game singleton before the
-- mod loads, so every lazy require("src.core.Game") lands here
local ow = {
  entities = {},
  camera = { x = 0, y = 0 },
  player = { cellX = 15, cellY = 15, px = 240, py = 240 },
  map = {
    id = "ROUTE_1",
    widthCells = 30, heightCells = 30,
    inBounds = function(_, x, y)
      return x >= 0 and y >= 0 and x < 30 and y < 30
    end,
    isWalkableCell = function() return true end,
  },
}
package.loaded["src.core.Game"] = {
  data = Data,
  overworld = ow,
  renderer = { worldViewSize = function() return 160, 144 end },
}

-- the ROM-free base can lack the bird sheet; any def keeps Flyer.new
-- happy under the love stub
Data.sprites = Data.sprites or {}
Data.sprites.SPRITE_BIRD = Data.sprites.SPRITE_BIRD
  or { image = "fixture_bird.png", frames = 6 }

local run = T.sdk.loadMod(os.getenv("MOD_DIR") or "mods/wild_skies",
  { data = Data })
T.check(run.mod ~= nil, "mod discovered and loaded")
T.eq(#run.errors, 0, "loads clean")

local api = run.loader.exports.wild_skies
local Runtime = require("src.mods.Runtime")

local function spawnAt(species, level, cellX, cellY, mode)
  for _ = 1, 8 do
    if api.spawnFlyer(species, level) then break end
  end
  local f = ow.entities[#ow.entities]
  T.check(f and f.species == species, species .. " spawned")
  f.mode = mode
  f.cellX, f.cellY = cellX, cellY
  return f
end

local function roll(species, level)
  return Runtime.call("encounter.roll",
    function() return { species = species, level = level } end,
    {}, { mapId = "ROUTE_1" })
end

-- a landing bird one cell away becomes the battle
spawnAt("PIDGEY", 7, 15, 16, "toLand")
local enc = roll("PIDGEY", 3)
T.eq(enc.species, "PIDGEY", "roll still returns the encounter")
T.eq(enc.level, 7, "the visible bird's level rides into the battle")
T.eq(#ow.entities, 0, "the bird left the world with its battle")
T.eq(api.flyerAt(15, 16, 2), nil, "the flyer registry agrees")

-- a different species leaves the perched bird alone
local spearow = spawnAt("SPEAROW", 9, 16, 15, "ground")
local other = roll("PIDGEY", 3)
T.eq(other.level, 3, "a mismatched roll keeps its own level")
T.eq(#ow.entities, 1, "the perched bird stays")

-- out of reach: left alone
spearow.cellX, spearow.cellY = 20, 20
local far = roll("SPEAROW", 3)
T.eq(far.level, 3, "a distant match keeps the roll's level")
T.eq(#ow.entities, 1, "the distant bird stays")

-- an airborne match beside the player is consumed too: a defeat or
-- capture must never leave it to visibly fly off
spearow.mode = "cross"
spearow.cellX, spearow.cellY = 16, 15
local airborne = roll("SPEAROW", 3)
T.eq(airborne.level, 9, "the airborne bird is the battle")
T.eq(#ow.entities, 0, "and it despawned")

-- with a grounded and a flying match both adjacent, the grounded one
-- is the battle: it is the bird the player is actually stood next to
local percher = spawnAt("PIDGEY", 11, 15, 16, "ground")
local crosser = spawnAt("PIDGEY", 12, 16, 15, "cross")
local both = roll("PIDGEY", 3)
T.eq(both.level, 11, "the perched bird outranks the flying one")
T.eq(#ow.entities, 1, "one bird consumed")
T.check(ow.entities[1] == crosser, "the flying one is still up there")
T.check(percher.dead, "the perched one went into the battle")
crosser.dead = true
table.remove(ow.entities, 1) -- retire the dead crosser from the fake world

-- takeFlyer broadcasts the consumption to every listener
local heard
run.loader.events:on("mod.wild_skies.flyer_taken", function(ev) heard = ev end)
local target = spawnAt("PIDGEY", 6, 16, 16, "cross")
target.t = 1     -- past the newborn grace the collision seam enforces
target.bold = true -- shy birds are scenery and invisible to takeFlyer
local got = api.takeFlyer(16, 16, 1)
T.eq(got and got.species, "PIDGEY", "takeFlyer hands back the identity")
T.check(heard ~= nil, "flyer_taken event heard")
T.eq(heard and heard.species, "PIDGEY", "event carries the species")
T.eq(heard and heard.level, 6, "event carries the level")
T.eq(heard and heard.cellX, 16, "event carries the cell")

-- a shy bird is invisible to the battle seams but real to attribution
local shy = spawnAt("PIDGEY", 4, 16, 16, "cross")
shy.t = 1
shy.bold = false
T.eq(api.takeFlyer(16, 16, 1), nil, "a shy bird cannot be taken")
T.eq(api.flyerAt(16, 16, 1), nil, "nor read by the collision seam")
shy.cellX, shy.cellY = 15, 16
local shyRoll = roll("PIDGEY", 3)
T.eq(shyRoll.level, 4, "but a classic roll still becomes it")
T.eq(#ow.entities, 0, "and it despawns into that battle")

run.release()
T.finish("wild_skies_encounter_attribution")
