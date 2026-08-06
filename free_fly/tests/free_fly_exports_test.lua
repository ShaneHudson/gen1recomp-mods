-- free_fly's public API through a real loader, alongside wild_skies so
-- the cross-mod seams load together the way they ship.
package.path = "./?.lua;./?/init.lua;" .. package.path

local os = require("os")
local T = require("tests.modkit")
local Data = require("src.core.Data"); Data:load()

local ffDir = os.getenv("MOD_DIR") or "mods/free_fly"
local wsDir = ffDir:gsub("free_fly", "wild_skies")

local run = T.sdk.loadMods({ ffDir, wsDir }, { data = Data })
T.eq(#run.errors, 0, "both mods load clean together")

local api = run.loader.exports.free_fly
T.check(api ~= nil, "free_fly exports registered")

-- flight state reads grounded before any game exists
T.eq(api.isFlying(), false, "not flying on load")
T.eq(api.altitude(), 0, "altitude 0 when grounded")
T.eq(api.mount(), nil, "no mount when grounded")

-- sprite-source registration comes through the exports
T.eq(select(1, api.registerSpriteSource("nope")), false,
  "invalid source rejected via export")
T.eq(api.registerSpriteSource({ id = "t", resolve = function() end }), true,
  "valid source accepted via export")
T.eq(api.unregisterSpriteSource("t"), true, "unregister via export")

-- wild_skies is visible on the same bus with its own surface intact
local ws = run.loader.exports.wild_skies
T.check(ws ~= nil, "wild_skies exports registered")
T.eq(ws.flyerAt(0, 0, 99), nil, "no flyers in a headless world")
T.eq(ws.takeFlyer(0, 0, 99), nil, "nothing to take in a headless world")

run.release()
T.finish("free_fly_exports")
