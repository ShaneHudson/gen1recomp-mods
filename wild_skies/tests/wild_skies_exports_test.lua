-- wild_skies' public API through a real loader: the flyer handles stay
-- nil-safe with no world, and spawnFlyer refuses cleanly headless.
package.path = "./?.lua;./?/init.lua;" .. package.path

local os = require("os")
local T = require("tests.modkit")
local Data = require("src.core.Data"); Data:load()

local run = T.sdk.loadMod(os.getenv("MOD_DIR") or "mods/wild_skies",
  { data = Data })
T.eq(#run.errors, 0, "loads clean")

local api = run.loader.exports.wild_skies
T.check(api ~= nil, "exports registered")
T.eq(api.flyerAt(0, 0, 99), nil, "flyerAt nil-safe with no world")
T.eq(api.takeFlyer(0, 0, 99), nil, "takeFlyer nil-safe with no world")

local id, why = api.spawnFlyer("PIDGEY", 5)
T.eq(id, nil, "spawnFlyer refuses with no overworld")
T.eq(why, "no overworld", "and says why")

-- species mods can join the ambient sky
T.eq(select(1, api.registerSkySpecies(nil)), false,
  "sky species needs an id")
T.eq(select(1, api.registerSkySpecies("")), false,
  "empty species id rejected")
T.eq(api.registerSkySpecies("NOCTOWL",
  { pool = "night", nightOnly = true, weight = 2, levels = { 12, 30 } }),
  true, "night species registers")
T.eq(api.registerSkySpecies("WINGULL", { pool = "sea" }), true,
  "sea species registers")

T.eq(select(1, api.registerSpriteSource({})), false,
  "invalid source rejected via export")
T.eq(api.registerSpriteSource({ id = "t", resolve = function() end }), true,
  "valid source accepted via export")
T.eq(api.unregisterSpriteSource("t"), true, "unregister via export")

run.release()
T.finish("wild_skies_exports")
