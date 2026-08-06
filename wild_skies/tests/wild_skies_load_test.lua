-- Loads wild_skies through the headless loader and asserts the load is
-- clean; the spawner only arms itself on game.ready, so a headless load
-- must leave the vanilla world untouched.
package.path = "./?.lua;./?/init.lua;" .. package.path

local os = require("os")
local T = require("tests.modkit")
local Data = require("src.core.Data"); Data:load()

local run = T.sdk.loadMod(os.getenv("MOD_DIR") or "mods/wild_skies", { data = Data })
-- discovery finding nothing also reports zero errors, so a vacuous run
-- must fail here rather than pass silently (MOD_DIR must be relative)
T.check(run.mod ~= nil, "mod discovered and loaded")
T.eq(#run.errors, 0, "loads clean")
run.release()
T.finish("wild_skies")
