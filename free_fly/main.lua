-- Free Fly: pick FREEFLY on a party member that knows FLY (outdoors, with
-- the THUNDERBADGE, same gate as vanilla FLY) and the player takes off.
-- Airborne you move over any terrain, doors and trainers ignore you, and
-- wild grass rolls are suppressed.  Press B over walkable ground to land.
--
-- Uses the internal seams the public API does not cover yet (player pose
-- lift, warp/trainer-sight gating), so the manifest declares
-- engine_internals.  Every wrap is guarded and keeps its live logic on the
-- module table so F5 hot reload swaps behavior without double-wrapping.
return function(mod)
  -- shared helpers, synced in as lib/shared/ by the monorepo's scripts
  local function loadShared(file)
    local src = mod:read("lib/shared/" .. file)
    if not src then return nil end
    return assert((loadstring or load)(src, "@free_fly/lib/shared/" .. file))()
  end
  local Sky = loadShared("skylib.lua")
  if not Sky then
    mod.log:error("lib/shared/skylib.lua is missing -- run scripts/dev.sh "
      .. "in the gen1recomp-mods repo to sync shared code; mod disabled")
    return
  end

  local RISE_SPEED = 72       -- px/s takeoff and landing lerp

  mod.options:define({
    -- voxel extrudes a 6-row house to 48px, so MED clears rooftops
    { key = "altitude", label = "ALTITUDE", type = "choice", default = "med",
      choices = { { "LOW", "low" }, { "MED", "med" }, { "HIGH", "high" } } },
    { key = "speed", label = "FLY SPEED", type = "choice", default = "normal",
      choices = { { "NORMAL", "normal" }, { "FAST", "fast" }, { "TURBO", "turbo" } } },
    { key = "encounters", label = "AIR ENCOUNTERS", type = "toggle", default = true },
    { key = "spotted", label = "TRAINERS SPOT YOU", type = "toggle", default = false },
    { key = "gates", label = "STORY GATES", type = "toggle", default = true },
    -- vanilla badge requirements: THUNDERBADGE to fly, SOULBADGE to set
    -- down on water.  The Pallet gift Pidgey is exempt from the fly check
    -- (never the surf one), so the quick start survives the option.
    { key = "badges", label = "BADGE CHECKS", type = "toggle", default = true },
    -- the Pallet Town gift Pidgey; off leaves a fully vanilla start
    { key = "quickstart", label = "QUICK START", type = "toggle", default = true },
  })

  -- with jj_quick_select installed (and only then), a FLY WHISTLE key
  -- item appears in the bag: register it to a SELECT+direction slot and
  -- flight toggles like the bicycle does.  The optional dependency in
  -- the manifest orders this mod after quick select, so find() is
  -- authoritative here.
  local quickSelect = mod.find("jj_quick_select")
  if quickSelect then
    mod.content.items:register("FLY_WHISTLE", {
      id = "FLY_WHISTLE",
      name = "FLY WHISTLE",
      price = 0,
      keyItem = true,
      tossable = false,
    })
  end

  local ALTS = { low = 32, med = 56, high = 80 }
  local SPEEDS = { normal = 8, fast = 6, turbo = 4 }   -- frames per step; bike is 8
  local function cruiseAlt() return ALTS[mod.options:get("altitude")] or 56 end
  local function flyFrames() return SPEEDS[mod.options:get("speed")] or 8 end

  local PIDGEY_LEVEL = 10
  local PIDGEY_TAKEN = "MOD_FREE_FLY_PIDGEY_TAKEN"
  local PIDGEY_TEXT = "TEXT_FREE_FLY_PIDGEY"

  local state = { phase = "idle", alt = 0, bob = 0, pidgeyNpcId = nil,
                  rider = nil }

  local function flying() return state.phase ~= "idle" end

  -- render pipelines (voxel, tilt) billboard every entity through pose();
  -- while flying the player's own card becomes the bird, and this ghost
  -- entity carries the player figure seated above it.  Invisible in the
  -- flat 2D view, where Player.draw composes the ride itself.
  local Rider = {}
  Rider.__index = Rider
  -- px/py/cellX/cellY are real fields, not conveniences: the overworld
  -- y-sorts entities on py and the voxel capture does arithmetic on it,
  -- so an entity without them crashes both passes
  function Rider.new(player)
    return setmetatable({ player = player, passable = true,
                          px = player.px, py = player.py,
                          cellX = player.cellX, cellY = player.cellY }, Rider)
  end
  function Rider:pose()
    local p = self.player
    local lift = math.floor((p.freeFlyAlt or 0) + 0.5)
    -- always the WALKING sheet: while airborne p.sprite is the mount
    return p.freeFlyWalkSprite or p.sprite, p.px, p.py - lift - 6,
           p.facing, 0, false, false
  end
  function Rider:draw() end

  local function knowsFly(mon) return Sky.knowsMove(mon, "FLY") end

  -- HM02 compatibility: the species' tmhm list is the same one the
  -- machine-teach path checks, so eligibility exactly matches "could this
  -- mon legitimately learn FLY"
  local function canLearnFly(game, mon)
    local def = mon and game.data.pokemon[mon.species]
    for _, m in ipairs((def and def.tmhm) or {}) do
      if m == "FLY" then return true end
    end
    return false
  end

  -- who may field-use a move is the ENGINE'S question, not this mod's:
  -- OverworldState:partyKnows routes through the fieldmove.eligibility
  -- hook chain, so HM-relaxing mods (qol_toggles' FIELD MOVES ALL) and
  -- anything else wrapping that hook decide alongside the vanilla check.
  -- Returns the mon the chain nominates, or nil.
  local function fieldMoveUser(ow, moveId)
    if ow and ow.partyKnows then
      local ok, user = pcall(ow.partyKnows, ow, moveId)
      if ok then return user end
    end
    return nil
  end

  -- a mon qualifies when its species can learn HM02 (the MERGED tmhm, so
  -- compatibility-expanding mods count) and it either knows FLY or a mod
  -- has relaxed the field-move rules through the engine's own chain
  local function eligibleFlyer(game, ow, mon)
    if not canLearnFly(game, mon) then return false end
    if knowsFly(mon) then return true end
    local Runtime = require("src.mods.Runtime")
    return Runtime.wantsHook("fieldmove.eligibility")
      and fieldMoveUser(ow, "FLY") ~= nil
  end

  local function badgeOk(game, mon)
    return not mod.options:get("badges")
      or (game.save.inventory and game.save.inventory.THUNDERBADGE)
      or mon.freeFlyGift
  end

  local function partyKnowsSurf(save)
    for _, mon in ipairs(save and save.party or {}) do
      if Sky.knowsMove(mon, "SURF") then return true end
    end
    return false
  end

  local function startFlight(game, mon)
    if flying() then return end
    local ow = mod.world and mod.world:overworld()
    if not (ow and ow.player) then
      mod.log:warn("no overworld to take off from; FREEFLY skipped")
      return
    end
    state.phase, state.alt, state.bob = "rising", 0, 0
    if state.resolveMount then state.resolveMount(mon) end
    -- taking off from a surf dismounts into the air
    ow.player.surfing = nil
    ow.player.freeFlying = true
    pcall(function()
      require("src.core.Sound").play(require("src.core.Game").data, "Fly")
    end)
    mod.log:info("took off; press B over walkable ground to land")
  end

  -- ------- public hooks, all pass-through unless airborne

  mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
    if flying() and ctx.mover and ctx.mover.freeFlying
       and (ctx.reason == "tile" or ctx.reason == "entity") then
      ctx.reason = nil
      return true
    end
    return next(allowed, ctx)
  end)

  -- airborne you can only flush other flyers: the vanilla roll stands,
  -- but a non-FLYING result becomes no encounter at all
  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local enc = next(encDef, ctx)
    if not (enc and flying()) then return enc end
    if not mod.options:get("encounters") then return nil end
    local game = require("src.core.Game")
    if Sky.hasType(game.data, enc.species, "FLYING") then return enc end
    return nil
  end)

  mod.hooks:wrap("movement.speed", function(next, frames, ctx)
    if flying() then return math.min(frames, flyFrames()) end
    return next(frames, ctx)
  end)

  mod.hooks:wrap("save.write", function(next, game)
    if flying() then
      mod.log:warn("can't save mid-flight; land first (press B)")
      return false
    end
    return next(game)
  end)

  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" then return out end
    local ow = ctx and ctx.overworld
    if not (ow and ow.map and ow.map.def) or flying() then return out end
    if not (eligibleFlyer(game, ow, mon) and badgeOk(game, mon)) then return out end
    if ow.player and ow.player.onBike then return out end
    local Map = require("src.world.Map")
    local FieldDefaults = require("src.world.FieldDefaults")
    if not Map.isOutside(ow.map.def,
                         FieldDefaults.field(game.data, "outsideTilesets")) then
      return out
    end
    table.insert(out, 1, { label = "FREEFLY", onSelect = function(m, g)
      -- unwind party menu / start menu back to the overworld, then lift off
      local stack = g.stack
      while stack:top() and not stack:top().isOverworld do stack:pop() end
      startFlight(g, m)
    end })
    return out
  end)

  -- ------- the Pallet Town Pidgey: a quick way to get a FLY user

  -- after give_pokemon lands the gift, put FLY in its move list
  mod.content.commands:register("free_fly:teach_fly", {
    foreground = true,
    fn = function(ctx)
      local function teach(mon)
        if not mon or mon.species ~= "PIDGEY" then return false end
        -- marks the gift so the BADGE CHECKS option exempts its flights;
        -- rides the mon table, so it survives in the save
        mon.freeFlyGift = true
        for _, mv in ipairs(mon.moves or {}) do
          if mv.id == "FLY" then return true end
        end
        local flyDef = ctx.game.data.moves.FLY
        local slot = { id = "FLY", pp = flyDef and flyDef.pp or 15 }
        mon.moves = mon.moves or {}
        if #mon.moves >= 4 then
          mon.moves[#mon.moves] = slot
        else
          table.insert(mon.moves, slot)
        end
        return true
      end
      for i = #ctx.save.party, 1, -1 do
        if teach(ctx.save.party[i]) then return end
      end
      for _, box in ipairs(ctx.save.boxes or {}) do
        for _, mon in ipairs(box) do
          if teach(mon) then return end
        end
      end
      mod.log:warn("gift PIDGEY not found; FLY not taught")
    end,
  })

  mod.content.commands:register("free_fly:pidgey_taken", {
    foreground = true,
    fn = function()
      if state.pidgeyNpcId then
        mod.world:removeNpc(state.pidgeyNpcId)
        state.pidgeyNpcId = nil
      end
    end,
  })

  -- the YES branch of the sea-crossing confirm; remembered per save so
  -- each map asks once
  mod.content.commands:register("free_fly:allow_crossing", {
    foreground = true,
    fn = function(_, mapId)
      local ok = mod.save:get("dangerOk")
      if type(ok) ~= "table" then ok = {} end
      ok[mapId] = true
      mod.save:set("dangerOk", ok)
    end,
  })

  mod.content.map_scripts:register("PALLET_TOWN", {
    talk = {
      [PIDGEY_TEXT] = {
        { "check_flag", PIDGEY_TAKEN },
        { "jump_if_true", "end" },
        { "show_text", "PIDGEY! It knows\nFLY, and it wants\nto travel!" },
        { "choice", { "TAKE IT", "LEAVE IT" } },
        { "jump_if_false", "refused" },
        { "set_flag", PIDGEY_TAKEN },
        { "give_pokemon", "PIDGEY", PIDGEY_LEVEL },
        { "free_fly:teach_fly" },
        { "free_fly:pidgey_taken" },
        { "show_text", "PIDGEY is happy to\ncarry you!\fPick FREEFLY in\nits party menu." },
        { "jump", "end" },

        { "label", "refused" },
        { "show_text", "PIDGEY tilts its\nhead." },
      },
    },
  })

  local function spawnPidgey()
    if not mod.options:get("quickstart") then return end
    local ow = mod.world and mod.world:overworld()
    if not (ow and ow.map and ow.map.id == "PALLET_TOWN") then return end
    if state.pidgeyNpcId then return end
    local game = require("src.core.Game")
    if game.save and game.save.flags and game.save.flags[PIDGEY_TAKEN] then return end
    -- first free walkable cell near the town center
    local Collision = require("src.world.Collision")
    local spots = { { 10, 10 }, { 9, 10 }, { 11, 10 }, { 10, 11 },
                    { 12, 9 }, { 8, 10 }, { 9, 11 }, { 12, 10 } }
    for _, s in ipairs(spots) do
      local x, y = s[1], s[2]
      if ow.map:isWalkableCell(x, y)
         and not Collision.occupied(ow.entities, x, y, nil) then
        state.pidgeyNpcId = mod.world:spawnNpc("PALLET_TOWN", {
          name = "FREE_FLY_PIDGEY",
          sprite = "SPRITE_BIRD",
          movement = "STAY",
          range = "DOWN",
          text = PIDGEY_TEXT,
          x = x, y = y,
        })
        return
      end
    end
    mod.log:warn("no free cell for the PALLET_TOWN PIDGEY this visit")
  end

  mod.events:on("map.entered", function(ev)
    state.pidgeyNpcId = nil
    if ev and ev.mapId == "PALLET_TOWN" then spawnPidgey() end
    -- hard guarantee: there is no indoor flight.  Whatever path leads
    -- into a cave or building while airborne, the flight ends on arrival.
    if flying() then
      local ow = mod.world and mod.world:overworld()
      if ow and ow.map and ow.map.def then
        local Map = require("src.world.Map")
        local FieldDefaults = require("src.world.FieldDefaults")
        local game = require("src.core.Game")
        if not Map.isOutside(ow.map.def,
              FieldDefaults.field(game.data, "outsideTilesets")) then
          state.phase, state.alt = "idle", 0
          mod.log:info("indoors; flight over")
        end
      end
    end
  end)

  -- a blackout wakes you at the heal point on solid ground, not mid-air;
  -- the next tick sees the idle phase and clears the player's flags/rider
  -- first person hides the player's card, and the mount is that card; a
  -- rider still expects to see their bird, so draw it into the HUD pass:
  -- bottom-center, back-facing, flapping, like a cockpit view
  local hudQuads = {}
  local hudLogged = false
  mod.hooks:wrap("render.hud", function(next, game, vp)
    local out = next(game, vp)
    if not flying() then return out end
    local ok, err = pcall(function()
      local exports = game.mods and game.mods.exports
      local V = exports and exports.DRAMATIC_SHAPE and exports.DRAMATIC_SHAPE.lib
      local FP = V and V.require and V.require("FirstPerson")
      -- hidePlayer() is true exactly when the first-person eye hides the
      -- player's card -- the one situation a rider needs a cockpit view
      -- (third person keeps showing the mount card itself)
      if not (FP and FP.hidePlayer and FP.hidePlayer()) then
        if not hudLogged then
          hudLogged = true
          mod.log:info("cockpit idle (%s)",
            not FP and "no DRAMATIC_SHAPE lib"
            or not FP.hidePlayer and "no hidePlayer api" or "card visible")
        end
        return
      end
      if not hudLogged then
        hudLogged = true
        mod.log:info("cockpit view active")
      end
      local Player = require("src.world.Player")
      local mount = Player.__freeFlyMount or Player.__freeFlyBird
      local img = mount and mount.image
      if not img then return end
      local SR = require("src.render.SpriteRenderer")
      local t = love.timer.getTime()
      local frame = (math.floor(t * 6) % 2 == 0) and SR.STAND.up or SR.WALK.up
      local key = tostring(img) .. "#" .. frame
      if not hudQuads[key] then
        local iw, ih = img:getDimensions()
        hudQuads[key] = love.graphics.newQuad(0, frame * 16, 16, 16, iw, ih)
      end
      local s = (vp.scale or 4) * 2.2 * (Player.__freeFlyMountScale or 1)
      local x = vp.gameX + vp.gameWidth / 2 - 8 * s
      local y = vp.gameY + vp.gameHeight - 10 * s + math.sin(t * 3) * 3
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(img, hudQuads[key], x, y, 0, s, s)
    end)
    if not ok and not hudLogged then
      hudLogged = true
      mod.log:warn("cockpit overlay failed: %s", tostring(err))
    end
    return out
  end)

  -- flight never survives into a loaded save (saving is vetoed mid-air),
  -- so a save swap always grounds the state machine; a stale "flying"
  -- phase could otherwise follow the player into a fresh save
  mod.events:on("save.loaded", function()
    state.phase, state.alt = "idle", 0
  end)

  mod.events:on("world.blacked_out", function()
    if flying() then
      state.phase, state.alt = "idle", 0
      mod.log:info("blacked out; flight over")
    end
  end)

  -- ------- engine wiring

  mod.events:on("game.ready", function()
    local Game = require("src.core.Game")
    local Player = require("src.world.Player")
    local OC = require("src.world.OverworldController")
    local Collision = require("src.world.Collision")
    local MapDef = require("src.world.Map")

    -- per-frame flight state, called from the guarded update wrap below
    local Pipelines = require("src.render.Pipelines")

    -- the ground height the voxel scene will ADD back under the card; 0
    -- whenever the voxel pipeline is off or its lib is unreachable.  This
    -- runs every fixed step, so everything resolvable once is resolved
    -- once and the answer is cached per (map, cell)
    local hasVoxel = Pipelines.get and Pipelines.get("voxel") ~= nil
    local tileShape        -- nil = not tried, false = unavailable
    local ghCache = {}
    -- returns gh, voxelActive
    local function voxelGroundHeight(ow, p)
      if not hasVoxel or Pipelines.level("voxel") <= 0 then return 0, false end
      if ghCache.map == ow.map and ghCache.x == p.cellX
         and ghCache.y == p.cellY then
        return ghCache.h, true
      end
      if tileShape == nil then
        tileShape = false
        local exports = Game.mods and Game.mods.exports
        local V = exports and exports.DRAMATIC_SHAPE and exports.DRAMATIC_SHAPE.lib
        if V and V.require then
          local ok, ts = pcall(V.require, "TileShape")
          if ok and ts and ts.forMap then tileShape = ts end
        end
      end
      local h = 0
      if tileShape then
        local ok, got = pcall(function()
          if not ow.map:inBounds(p.cellX, p.cellY) then return 0 end
          local s = tileShape.forMap(ow.map)[ow.map:cellTile(p.cellX, p.cellY)]
          if not s or s.art == "stair" then return 0 end
          return s.h > 0 and s.h or 0
        end)
        h = (ok and got) or 0
      end
      ghCache.map, ghCache.x, ghCache.y, ghCache.h = ow.map, p.cellX, p.cellY, h
      return h, true
    end

    -- does the badge-gate data forbid an airborne crossing into mapId?
    -- Reads the same field.badgeGates the walking checkpoints enforce, so
    -- any mod that adds its own gates is respected automatically.
    local function storyGateBlocks(mapId)
      local field = Game.data.field
      local entry = field and field.badgeGates and field.badgeGates[mapId]
      if not entry then return false end
      local save = Game.save
      local flags = (save and save.flags) or {}
      local bag = (save and save.inventory) or {}
      if flags[entry.passedFlag or ("PASSED_" .. tostring(mapId))] then
        return false
      end
      if entry.badge then return not bag[entry.badge] end
      for _, guard in ipairs(entry.guards or {}) do
        if not (flags[guard.event] or (guard.badge and bag[guard.badge])) then
          return true
        end
      end
      return false
    end

    local function windBack()
      if (state.windCooldown or 0) > 0 then return end
      state.windCooldown = 3
      pcall(function()
        require("src.core.Sound").play(Game.data, "Collision")
      end)
      mod.world:queueScript({
        { "show_text", "A fierce wind\nblows you back!" },
      })
    end

    local function dropRider(ow)
      if not state.rider then return end
      for i = #ow.entities, 1, -1 do
        if ow.entities[i] == state.rider then table.remove(ow.entities, i) end
      end
      state.rider = nil
    end

    local function syncRider(ow, p)
      local r = state.rider
      if not r or r.player ~= p then
        dropRider(ow)
        r = Rider.new(p)
        state.rider = r
      end
      r.px, r.py = p.px, p.py
      r.cellX, r.cellY = p.cellX, p.cellY
      for _, e in ipairs(ow.entities) do
        if e == r then return end
      end
      -- setMap rebuilds the entity list on every seam crossing, so the
      -- rider re-attaches here each time it goes missing
      table.insert(ow.entities, r)
    end

    local MapField = require("src.world.FieldDefaults")
    local MapLoader = require("src.world.MapLoader")

    -- a fast flyer hits seams constantly, and each crossing loads the
    -- destination plus its whole neighbor ring (rebuildNeighbors).  While
    -- airborne, warm the MapLoader cache ahead of time: the current map's
    -- connections and, one hop further, the neighbors of each of those.
    -- One load per tick, so the prefetch can never spike a frame itself.
    local function refillPrefetch(ow)
      state.prefetchQueue = {}
      local seen = {}
      local function push(id)
        if id and not seen[id] and not MapLoader.cached(id) then
          seen[id] = true
          state.prefetchQueue[#state.prefetchQueue + 1] = id
        end
      end
      local defs = Game.data.maps
      for _, conn in pairs((ow.map.def and ow.map.def.connections) or {}) do
        push(conn.map)
        local dest = conn.map and defs[conn.map]
        for _, conn2 in pairs((dest and dest.connections) or {}) do
          push(conn2.map)
        end
      end
    end

    local function tickPrefetch(ow)
      if state.prefetchFor ~= ow.map.id then
        state.prefetchFor = ow.map.id
        refillPrefetch(ow)
      end
      local id = table.remove(state.prefetchQueue)
      if not id then return end
      local okLoad, m = pcall(MapLoader.load, Game.data, id)
      if not okLoad then
        state.prefetchQueue = {}
        return
      end
      -- voxel: also queue the neighbour-grade chunk mesh, with exactly
      -- the call the scene makes for its own neighbours (body-only,
      -- non-urgent, consumed by DRAMATIC_SHAPE's own build pump), so a
      -- fast flyer's destination never drops to the flat 2D fallback
      if m and hasVoxel and Pipelines.level("voxel") > 0 then
        if state.mesher == nil then
          local exports = Game.mods and Game.mods.exports
          local V = exports and exports.DRAMATIC_SHAPE
            and exports.DRAMATIC_SHAPE.lib
          local okM, cm = pcall(function()
            return V and V.require("ChunkMesher")
          end)
          state.mesher = (okM and cm and cm.request and cm) or false
        end
        if state.mesher then pcall(state.mesher.request, m, true) end
      end
    end

    -- takeoff with the first eligible partner: the FLY WHISTLE's action,
    -- same gates as the FREEFLY menu entry.  Returns ok, failure text.
    local function partnerTakeoff(ow)
      local save = Game.save
      if not (save and ow.map and ow.map.def) then
        return false, "Not here."
      end
      if ow.player.onBike then
        return false, "Not while riding\nthe BICYCLE!"
      end
      if not MapDef.isOutside(ow.map.def,
            MapField.field(Game.data, "outsideTilesets")) then
        return false, "There's no open\nsky here!"
      end
      for _, mon in ipairs(save.party or {}) do
        if eligibleFlyer(Game, ow, mon) and badgeOk(Game, mon) then
          -- unwind any menus so the takeoff starts on the overworld
          while Game.stack:top() and not Game.stack:top().isOverworld do
            Game.stack:pop()
          end
          startFlight(Game, mon)
          return true
        end
      end
      return false, "No party member\ncan carry you!"
    end

    if quickSelect then
      -- the whistle's behavior lives in the item-use path, so the bag,
      -- quick select's slots and any other caller all agree
      local ItemEffects = require("src.inventory.ItemEffects")
      if not ItemEffects.__freeFlyWrapped then
        ItemEffects.__freeFlyWrapped = true
        local origUse = ItemEffects.use
        ItemEffects.use = function(data, save, itemId, target, battle, moveIndex, ow)
          local impl = ItemEffects.__freeFlyUse
          if impl then
            local kind, messages = impl(itemId, battle)
            if kind then return kind, messages end
          end
          return origUse(data, save, itemId, target, battle, moveIndex, ow)
        end
      end
      ItemEffects.__freeFlyUse = function(itemId, battle)
        if itemId ~= "FLY_WHISTLE" then return nil end
        if battle then
          return "failed", { "This isn't the\ntime to use that!" }
        end
        if flying() then
          state.landRequest = true
          return "kept", {}
        end
        local ow = mod.world and mod.world:overworld()
        if not ow then
          return "failed", { "This isn't the\ntime to use that!" }
        end
        local ok, why = partnerTakeoff(ow)
        if ok then return "kept", {} end
        return "failed", { why }
      end

      -- the whistle rides the save's bag; hand one over once per save
      local function grantWhistle()
        local save = Game.save
        if save and save.inventory and not save.inventory.FLY_WHISTLE then
          require("src.inventory.Bag").add(save, "FLY_WHISTLE", 1, Game.data)
          mod.log:info("FLY WHISTLE added to the bag (quick select found)")
        end
      end
      grantWhistle()
      mod.events:on("save.loaded", grantWhistle)

      -- With no BICYCLE in the bag, tap-SELECT means flight: Quick
      -- Select's tap is hardcoded to the bicycle and would only print
      -- "You don't have a BICYCLE".  This wrapper runs OUTER on the same
      -- hook (priority 600 vs its 500), takes over the SELECT gesture
      -- for exactly that case, blinds the inner chain to SELECT so Quick
      -- Select never arms, and hands hold+direction slots back through
      -- its public exports.  Own a bicycle and this is fully transparent.
      local DIRS = { "up", "down", "left", "right" }
      local function consumeQueued(input, buttons)
        local drop = {}
        for _, b in ipairs(buttons) do drop[b] = true end
        local kept = {}
        for _, b in ipairs(input.pressQueue or {}) do
          if not drop[b] then kept[#kept + 1] = b end
        end
        input.pressQueue = kept
      end

      mod.hooks:wrap("input.step", function(nextFn, game, dt)
        local input = game and game.input
        local inv = game and game.save and game.save.inventory
        local top = game and game.stack and game.stack:top()
        local takeover = input and inv and (inv.BICYCLE or 0) <= 0
          and top ~= nil and top.isOverworld
        if not takeover then
          state.qsArmed, state.qsHeld = nil, nil
          return nextFn(game, dt)
        end

        local down = input:isDown("select")
        local was = state.qsHeld
        state.qsHeld = down
        if down and not was then state.qsArmed = true end

        local slotDir
        if state.qsArmed and down then
          for _, d in ipairs(DIRS) do
            if input:wasPressed(d) then slotDir = d break end
          end
        end
        local tap = was and not down and state.qsArmed
        if slotDir or tap then state.qsArmed = nil end

        local origDown, origWas = input.isDown, input.wasPressed
        input.isDown = function(self, b)
          if b == "select" then return false end
          return origDown(self, b)
        end
        input.wasPressed = function(self, b)
          if b == "select" then return false end
          return origWas(self, b)
        end
        local ok, err = pcall(nextFn, game, dt)
        input.isDown, input.wasPressed = origDown, origWas
        if not ok then error(err, 0) end

        if slotDir then
          consumeQueued(input, { "select", slotDir })
          pcall(function() quickSelect.exports.activate(game, slotDir) end)
        elseif tap then
          consumeQueued(input, { "select" })
          local impl = ItemEffects.__freeFlyUse
          if impl then
            local kind, msgs = impl("FLY_WHISTLE", false)
            if kind == "failed" and msgs and msgs[1] then
              game.stack:push(mod.ui.TextBox.new(game, msgs[1]))
            end
          end
        end
      end, 600)
    end

    OC.__freeFlyTick = function(ow, dt)
      local p = ow.player
      if not p then return end
      if not flying() then
        if p.freeFlyAlt then p.freeFlyAlt, p.freeFlying = nil, nil end
        if p.freeFlyWalkSprite then
          p.sprite, p.freeFlyWalkSprite = p.freeFlyWalkSprite, nil
        end
        dropRider(ow)
        return
      end
      p.freeFlying = true
      -- the mount IS the player's sheet while airborne, so every renderer
      -- (voxel first/third person frame remaps included) shows it; the
      -- walking sheet is stashed for the rider overlay and the landing
      local mount = Player.__freeFlyMount or Player.__freeFlyBird
      if mount and p.sprite ~= mount then
        p.freeFlyWalkSprite = p.freeFlyWalkSprite or p.sprite
        p.sprite = mount
      end
      syncRider(ow, p)
      dt = dt or 1 / 60
      local groundOk = ow.map:isWalkableCell(p.cellX, p.cellY)
      -- SURF availability goes through the same engine chain, so
      -- HM-relaxing mods unlock water landings exactly as they unlock
      -- the SURF field move itself
      local waterOk = not groundOk and ow.map:isWaterCell(p.cellX, p.cellY)
        and (fieldMoveUser(ow, "SURF") ~= nil or partyKnowsSurf(Game.save))
        and (not mod.options:get("badges")
             or (Game.save.inventory and Game.save.inventory.SOULBADGE))
      local canLand = not p.moving and (groundOk or waterOk)
        and not Collision.occupied(ow.entities, p.cellX, p.cellY, p)
      p.freeFlyCanLand = state.phase == "flying" and canLand or false

      if state.phase == "rising" then
        local cruise = cruiseAlt()
        state.alt = math.min(cruise, state.alt + RISE_SPEED * dt)
        if state.alt >= cruise then state.phase = "flying" end
      elseif state.phase == "landing" then
        state.alt = math.max(0, state.alt - RISE_SPEED * dt)
        if state.alt <= 0 then
          state.phase = "idle"
          -- setting down on water hands you straight to a SURF-knower
          if ow.map:isWaterCell(p.cellX, p.cellY) then
            p.surfing = true
            mod.log:info("landed on the water; surfing")
          else
            mod.log:info("landed")
          end
          p.freeFlying, p.freeFlyAlt, p.freeFlyCanLand = nil, nil, nil
          if p.freeFlyWalkSprite then
            p.sprite, p.freeFlyWalkSprite = p.freeFlyWalkSprite, nil
          end
          return
        end
      elseif state.phase == "flying" then
        -- an ALTITUDE option change applies mid-flight
        state.alt = state.alt + (cruiseAlt() - state.alt) * math.min(1, dt * 2)

        if Game.input:wasPressed("b") or state.landRequest then
          state.landRequest = nil
          if canLand then
            state.phase = "landing"
          else
            pcall(function()
              require("src.core.Sound").play(Game.data, "Collision")
            end)
            mod.log:info("can't land here")
          end
        end

        -- aerial interception: brushing a wild_skies flyer starts that
        -- exact battle, through its exports rather than its internals
        if (state.interceptCooldown or 0) > 0 then
          state.interceptCooldown = state.interceptCooldown - dt
        elseif mod.options:get("encounters") then
          if state.skiesTake == nil then
            local skies = mod.find("wild_skies")
            state.skiesTake = (skies and skies.exports
                               and skies.exports.takeFlyer) or false
          end
          local take = state.skiesTake
          if take then
            local ok, hit = pcall(take, p.cellX, p.cellY, 1)
            if ok and hit and hit.species then
              state.interceptCooldown = 2
              state.expectBattle = 4
              pcall(function()
                require("src.core.Sound").playCry(Game.data, hit.species)
              end)
              mod.log:info("intercepted %s!", tostring(hit.species))
              mod.world:queueScript({
                { "start_battle", "wild", hit.species, hit.level or 5 },
              })
            end
          end
        end
      end
      tickPrefetch(ow)
      state.expectBattle = (state.expectBattle and state.expectBattle > dt)
        and (state.expectBattle - dt) or nil
      state.windCooldown = math.max(0, (state.windCooldown or 0) - dt)
      -- TURN BACK is never remembered: once this expires the next push
      -- into the seam asks again, until the player says CROSS
      state.askCooldown = math.max(0, (state.askCooldown or 0) - dt)
      state.bob = (state.bob + dt * 4) % (2 * math.pi)
      local hover = state.phase == "flying" and math.sin(state.bob) * 2 or 0
      -- altitude is absolute: the voxel scene adds the ground height back
      -- under the card, so standing geometry eats into the visual lift
      -- instead of stacking on top of it (min 10 keeps clearance)
      local lift = state.alt + hover
      local gh, voxelOn = voxelGroundHeight(ow, p)
      -- the pitched voxel camera makes a high card loom at the lens, so
      -- the visual lift shrinks there; 2D keeps the full height
      if voxelOn then lift = lift * 0.75 end
      -- the compensation must be INSTANT: the scene snaps its ground
      -- height at each cell boundary, and easing toward the new target
      -- read as the rider hopping over every fence
      p.freeFlyAlt = gh > 0 and math.max(10, lift - gh) or lift
      -- the camera tracks PART of the lift in voxel: the card rides a
      -- little above centre and reads smaller/further away, which is the
      -- zoom-out look without enlarging the rendered view (a real zoom
      -- rung grew the chunk set and stepped up the shadow-map resolution,
      -- which was the building lag while airborne)
      local follow = voxelOn and 0.65 or 1
      ow.camera:follow(p.px, p.py - p.freeFlyAlt * follow,
                       Game.renderer:worldViewSize())
    end

    if not OC.__freeFlyWrapped then
      OC.__freeFlyWrapped = true

      local origUpdate = OC.update
      OC.update = function(self, dt)
        origUpdate(self, dt)
        if OC.__freeFlyTick then
          local ok, err = pcall(OC.__freeFlyTick, self, dt)
          if not ok then print("[free_fly] tick failed: " .. tostring(err)) end
        end
      end

      -- doors and edge warps must not swallow a bird passing over them
      local origTakeWarp = OC.takeWarp
      OC.takeWarp = function(self, ...)
        if self.player and self.player.freeFlying then return end
        return origTakeWarp(self, ...)
      end

      -- trainers don't spot what flies over their head (unless the
      -- hardcore option says they do); the gate is swappable so hot
      -- reload always runs the latest logic
      local origSight = OC.checkTrainerSight
      OC.checkTrainerSight = function(self, ...)
        local gate = OC.__freeFlySightGate
        if gate and gate(self) then return end
        return origSight(self, ...)
      end
    end

    OC.__freeFlySightGate = function(ow)
      local p = ow.player
      return p and p.freeFlying and not mod.options:get("spotted")
    end

    local function dangerAllowed(mapId)
      local ok = mod.save:get("dangerOk")
      return type(ok) == "table" and ok[mapId] == true
    end

    -- crossing where only SURF could take a walker: confirm once per map
    local function dangerAsk(destMapId)
      if (state.askCooldown or 0) > 0 then return end
      state.askCooldown = 2
      mod.world:queueScript({
        { "show_text", "That looks\ndangerous!" },
        { "choice", { "CROSS", "TURN BACK" } },
        { "jump_if_false", "no" },
        { "free_fly:allow_crossing", destMapId },
        { "show_text", "You brace against\nthe sea wind!" },
        { "jump", "end" },
        { "label", "no" },
        { "show_text", "You circle back." },
      })
    end

    -- story gates and the sea-crossing confirm share the seam chokepoint.
    -- v2 guard flag: the 0.7.0 wrapper did not pass `dir`, so a hot reload
    -- from it installs this one and retires the old gate key.
    if not OC.__freeFlyCrossWrapped2 then
      OC.__freeFlyCrossWrapped2 = true
      local origCross = OC.crossConnection
      OC.crossConnection = function(self, dir, conn)
        local gate = OC.__freeFlyCrossGate2
        if gate and conn and gate(self, dir, conn.map) then return false end
        return origCross(self, dir, conn)
      end
    end
    OC.__freeFlyCrossGate = nil

    -- forced-movement tiles (Cycling Road's mount-or-refuse, forced surf
    -- currents) don't grab what flies over them; landing brings the
    -- vanilla check straight back.  Own guard flag so a hot reload from
    -- an older version still installs it.
    if not OC.__freeFlyForcedWrapped then
      OC.__freeFlyForcedWrapped = true
      local origForced = OC.checkForcedMovement
      OC.checkForcedMovement = function(self, ...)
        if self.player and self.player.freeFlying then return false end
        return origForced(self, ...)
      end
    end

    -- other mods (overworld_encounters' ground roamers above all) start
    -- wild battles by ground-cell collision and know nothing about
    -- altitude.  While airborne, the only wild battle allowed to start is
    -- one this mod just asked for (interception); everything else is a
    -- ground creature the flyer passes over.
    local BattleState = require("src.battle.BattleState")
    if not BattleState.__freeFlyWrapped then
      BattleState.__freeFlyWrapped = true
      local origNewWild = BattleState.newWild
      BattleState.newWild = function(...)
        local gate = BattleState.__freeFlyGate
        if gate and gate() then return nil end
        return origNewWild(...)
      end
    end
    BattleState.__freeFlyGate = function()
      return flying() and not state.expectBattle
    end

    mod.events:on("battle.started", function()
      state.expectBattle = nil
    end)

    -- the void border (tree fill beyond the map edges) is decoration and
    -- never interactable; while airborne it is simply not drawn, which
    -- removes the visible re-render when crossings flip its ownership.
    -- 2D: the beyond-ring backfill is a per-frame draw, skipped for free.
    local TileRenderer = require("src.render.TileRenderer")
    if not TileRenderer.__freeFlyWrapped then
      TileRenderer.__freeFlyWrapped = true
      local origFill = TileRenderer.drawBorderFill
      TileRenderer.drawBorderFill = function(self, ...)
        local gate = TileRenderer.__freeFlySkip
        if gate and gate() then return end
        return origFill(self, ...)
      end
    end
    TileRenderer.__freeFlySkip = function() return flying() end

    -- voxel: the ring is meshed into the current map's FULL mesh, so
    -- while airborne every full-mesh request answers with the ring-less
    -- BODY mesh instead -- but only once that body mesh is cached, so
    -- the scene never drops to the 2D fallback waiting for it.  Landing
    -- resumes full requests and the cached ring returns instantly.
    do
      local exports = Game.mods and Game.mods.exports
      local V = exports and exports.DRAMATIC_SHAPE and exports.DRAMATIC_SHAPE.lib
      local okM, CM = pcall(function() return V and V.require("ChunkMesher") end)
      if okM and CM and CM.request then
        if not CM.__freeFlyWrapped then
          CM.__freeFlyWrapped = true
          local origReq = CM.request
          CM.request = function(map, bodyOnly, masks, urgent)
            local gate = CM.__freeFlyBodyOnly
            if gate and gate() and not bodyOnly then
              local body = origReq(map, true, masks, false)
              if body then return body end
            end
            return origReq(map, bodyOnly, masks, urgent)
          end
        end
        CM.__freeFlyBodyOnly = function() return flying() end
      end
    end

    -- a flyer crossing a ledge just crosses it: the vanilla hop would
    -- hijack the step and stack its arc on top of the flight lift
    if not OC.__freeFlyLedgeWrapped then
      OC.__freeFlyLedgeWrapped = true
      local origLedge = OC.checkLedgeHop
      OC.checkLedgeHop = function(self, ...)
        if self.player and self.player.freeFlying then return false end
        return origLedge(self, ...)
      end
    end

    -- completed-step reactions (locked-door step scripts, gate guards,
    -- spinner tiles, poison ticks) belong to walkers; an airborne step
    -- touches nothing, and landing brings them all straight back
    if not OC.__freeFlyStepWrapped then
      OC.__freeFlyStepWrapped = true
      local origStep = OC.onStepComplete
      OC.onStepComplete = function(self, ...)
        if self.player and self.player.freeFlying then return end
        return origStep(self, ...)
      end
    end

    OC.__freeFlyCrossGate2 = function(ow, dir, destMapId)
      if not flying() then return false end
      if mod.options:get("gates") and storyGateBlocks(destMapId) then
        windBack()
        return true
      end
      if not dangerAllowed(destMapId) then
        local dest, ts, x, y = ow:connectionLanding(dir)
        if dest and MapDef.defIsWaterCell(dest, ts, x, y) then
          dangerAsk(destMapId)
          return true
        end
      end
      return false
    end

    -- thin wraps install once; the implementations live on the Player
    -- table and are reassigned on every load, so F5 hot reload always
    -- runs the latest logic
    if not Player.__freeFlyWrapped then
      Player.__freeFlyWrapped = true

      local origPose = Player.pose
      Player.pose = function(self)
        local impl = Player.__freeFlyPoseImpl
        if impl then return impl(self, origPose) end
        return origPose(self)
      end

      local origDraw = Player.draw
      Player.draw = function(self, camX, camY)
        local impl = Player.__freeFlyDrawImpl
        if impl then return impl(self, camX, camY, origDraw) end
        return origDraw(self, camX, camY)
      end
    end

    -- lift rides pose so every renderer (flat, tilt, pipelines) sees it;
    -- airborne the card itself becomes the flapping bird, and the Rider
    -- ghost entity above carries the player figure
    Player.__freeFlyPoseImpl = function(self, origPose)
      local sprite, px, py, facing, phase, flip, hopping = origPose(self)
      local lift = self.freeFlyAlt
      if lift and lift > 0 then
        py = py - math.floor(lift + 0.5)
        local mount = Player.__freeFlyMount or Player.__freeFlyBird
        if mount then
          sprite = mount
          phase = math.floor(love.timer.getTime() * 8) % 2
          flip = false
        end
      end
      return sprite, px, py, facing, phase, flip, hopping
    end

    -- airborne the player rides: the bird sheet as the mount, the
    -- player's own top half seated on its back.  Both images come out
    -- of the player's imported cache, so nothing ships.
    Player.__freeFlyDrawImpl = function(self, camX, camY, origDraw)
      local lift = self.freeFlyAlt
      local bird = Player.__freeFlyMount or Player.__freeFlyBird
      if not (lift and lift > 0 and bird) then
        return origDraw(self, camX, camY)
      end
      -- the shadow shrinks with height and turns green over landable
      -- ground, so B-to-land reads at a glance
      if self.freeFlyCanLand then
        love.graphics.setColor(0.1, 0.45, 0.15, 0.45)
      else
        love.graphics.setColor(0, 0, 0, 0.35)
      end
      local s = Player.__freeFlyMountScale or 1
      local r = math.max(3, 7 - lift / 16) * s
      love.graphics.ellipse("fill", self.px + 8 - camX, self.py + 13 - camY,
                            r, r * 0.4)
      love.graphics.setColor(1, 1, 1, 1)
      local ry = self.py - math.floor(lift + 0.5)
      local flap = math.floor(love.timer.getTime() * 8) % 2
      -- rider FIRST, tucked low, then the mount over it: the mount's body
      -- hides the crop line, so the figure reads as seated behind its
      -- neck instead of a head floating above it
      local walk = self.freeFlyWalkSprite or self.sprite
      walk:draw(self.px, ry - math.floor(1 + 2 * s + 0.5),
                camX, camY, self.facing, 0, false, true)
      if s ~= 1 then
        local fx = math.floor(self.px + 8 - camX)
        local fy = math.floor(ry + 12 - camY)
        love.graphics.push()
        love.graphics.translate(fx, fy)
        love.graphics.scale(s, s)
        love.graphics.translate(-fx, -fy)
      end
      bird:draw(self.px, ry, camX, camY, self.facing, flap, false)
      if s ~= 1 then love.graphics.pop() end
    end

    local SpriteRenderer = require("src.render.SpriteRenderer")
    if Game.data.sprites.SPRITE_BIRD then
      Player.__freeFlyBird = SpriteRenderer.new(Game.data.sprites.SPRITE_BIRD,
                                                "free_fly_mount")
    end

    -- mount identity: the chosen mon's party-icon class maps onto a real
    -- walker sheet where one exists (bird/monster/seel/fairy), sized by
    -- its dex height.  Icon-only classes keep the bird.
    state.resolveMount = function(mon)
      local species = mon and mon.species
      Player.__freeFlyMount = (species
        and Sky.mountSprite(Game.data, species, "free_fly"))
        or Player.__freeFlyBird
      Player.__freeFlyMountScale = species
        and Sky.dexScale(Game.data, species) or 1
    end

    -- crossConnection re-validates the landing tile on the neighbor map
    -- with Map.defPassable, outside the movement.collision hook; a flyer
    -- crosses any seam, water included
    local MapMod = require("src.world.Map")
    if not MapMod.__freeFlyWrapped then
      MapMod.__freeFlyWrapped = true
      local origPassable = MapMod.defPassable
      MapMod.defPassable = function(...)
        local active = MapMod.__freeFlyActive
        if active and active() then return true end
        return origPassable(...)
      end
    end
    MapMod.__freeFlyActive = function() return flying() end

    -- DRAMATIC_SHAPE's first/third-person FreeMove does its own collision
    -- (Map:isWalkableCell + Collision.occupied directly, never
    -- Collision.canMove), so the airborne pass-through above never
    -- reaches it.  Wrapping its tick opens a permissive window scoped to
    -- exactly that call while the player flies.
    do
      local exports = Game.mods and Game.mods.exports
      local V = exports and exports.DRAMATIC_SHAPE and exports.DRAMATIC_SHAPE.lib
      local okFM, FreeMove = pcall(function() return V and V.require("FreeMove") end)
      if okFM and FreeMove and FreeMove.tick then
        if not MapMod.__freeFlyWalkWrapped then
          MapMod.__freeFlyWalkWrapped = true
          local origWalkable = MapMod.isWalkableCell
          MapMod.isWalkableCell = function(self, cx, cy)
            if MapMod.__freeFlyPermissive then return self:inBounds(cx, cy) end
            return origWalkable(self, cx, cy)
          end
          local origOccupied = Collision.occupied
          Collision.occupied = function(...)
            if MapMod.__freeFlyPermissive then return false end
            return origOccupied(...)
          end
        end
        if not FreeMove.__freeFlyWrapped then
          FreeMove.__freeFlyWrapped = true
          local origTick = FreeMove.tick
          FreeMove.tick = function(fmState, ...)
            local p = fmState and fmState.player
            if not (p and p.freeFlying) then return origTick(fmState, ...) end
            MapMod.__freeFlyPermissive = true
            local ok, err = pcall(origTick, fmState, ...)
            MapMod.__freeFlyPermissive = false
            if not ok then error(err, 0) end
          end
        end
      end
    end

    -- saves from before 0.9.0 have a taken gift but no marker on the mon;
    -- re-mark the first FLY-knowing PIDGEY so BADGE CHECKS keeps exempting
    -- it (runs on load and on every save swap)
    local function migrateGiftMarker()
      local save = Game.save
      if not (save and save.flags and save.flags[PIDGEY_TAKEN]) then return end
      local lists = { save.party }
      for _, box in ipairs(save.boxes or {}) do lists[#lists + 1] = box end
      for _, list in ipairs(lists) do
        for _, mon in ipairs(list or {}) do
          if mon.freeFlyGift then return end
        end
      end
      for _, list in ipairs(lists) do
        for _, mon in ipairs(list or {}) do
          if mon.species == "PIDGEY" and knowsFly(mon) then
            mon.freeFlyGift = true
            mod.log:info("marked the gift PIDGEY from an older save")
            return
          end
        end
      end
    end
    migrateGiftMarker()
    mod.events:on("save.loaded", migrateGiftMarker)

    -- a save loaded while already standing in Pallet Town gets its bird too
    spawnPidgey()
  end)
end
