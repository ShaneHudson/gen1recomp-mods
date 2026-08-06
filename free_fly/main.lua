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
  })

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
    return p.sprite, p.px, p.py - lift - 6, p.facing, 0, false, false
  end
  function Rider:draw() end

  local function knowsMove(mon, moveId)
    for _, mv in ipairs(mon and mon.moves or {}) do
      if (type(mv) == "table" and mv.id or mv) == moveId then return true end
    end
    return false
  end

  local function knowsFly(mon) return knowsMove(mon, "FLY") end

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

  local function partyKnowsSurf(save)
    for _, mon in ipairs(save and save.party or {}) do
      if knowsMove(mon, "SURF") then return true end
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
    local def = game.data and game.data.pokemon[enc.species]
    for _, t in ipairs((def and def.types) or {}) do
      if t == "FLYING" then return enc end
    end
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
    if not (knowsFly(mon) and canLearnFly(game, mon)) then return out end
    if mod.options:get("badges") and not game.save.inventory.THUNDERBADGE
       and not mon.freeFlyGift then
      return out
    end
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
  end)

  -- a blackout wakes you at the heal point on solid ground, not mid-air;
  -- the next tick sees the idle phase and clears the player's flags/rider
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
    local function voxelGroundHeight(ow, p)
      if not hasVoxel or Pipelines.level("voxel") <= 0 then return 0 end
      if ghCache.map == ow.map and ghCache.x == p.cellX
         and ghCache.y == p.cellY then
        return ghCache.h
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
      return h
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

    OC.__freeFlyTick = function(ow, dt)
      local p = ow.player
      if not p then return end
      if not flying() then
        if p.freeFlyAlt then p.freeFlyAlt, p.freeFlying = nil, nil end
        dropRider(ow)
        return
      end
      p.freeFlying = true
      syncRider(ow, p)
      dt = dt or 1 / 60
      local groundOk = ow.map:isWalkableCell(p.cellX, p.cellY)
      local waterOk = not groundOk and ow.map:isWaterCell(p.cellX, p.cellY)
        and partyKnowsSurf(Game.save)
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
          return
        end
      elseif state.phase == "flying" then
        -- an ALTITUDE option change applies mid-flight
        state.alt = state.alt + (cruiseAlt() - state.alt) * math.min(1, dt * 2)

        if Game.input:wasPressed("b") then
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
        else
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
              mod.log:info("intercepted %s!", tostring(hit.species))
              mod.world:queueScript({
                { "start_battle", "wild", hit.species, hit.level or 5 },
              })
            end
          end
        end
      end
      state.windCooldown = math.max(0, (state.windCooldown or 0) - dt)
      state.bob = (state.bob + dt * 4) % (2 * math.pi)
      local hover = state.phase == "flying" and math.sin(state.bob) * 2 or 0
      -- altitude is absolute: the voxel scene adds the ground height back
      -- under the card, so standing geometry eats into the visual lift
      -- instead of stacking on top of it (min 10 keeps clearance)
      local lift = state.alt + hover
      local gh = voxelGroundHeight(ow, p)
      local target = gh > 0 and math.max(10, lift - gh) or lift
      local cur = p.freeFlyAlt or 0
      p.freeFlyAlt = cur + (target - cur) * math.min(1, dt * 10)
      -- centre the view (and the tilt-shift focus band) on the bird, not
      -- on the ground point far below it
      ow.camera:follow(p.px, p.py - p.freeFlyAlt,
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
      -- the rider sits higher on a taller mount
      self.sprite:draw(self.px, ry - math.floor(3 + 3 * s + 0.5),
                       camX, camY, self.facing, 0, false, true)
    end

    local SpriteRenderer = require("src.render.SpriteRenderer")
    if Game.data.sprites.SPRITE_BIRD then
      Player.__freeFlyBird = SpriteRenderer.new(Game.data.sprites.SPRITE_BIRD,
                                                "free_fly_mount")
    end

    -- mount identity: the chosen mon's party-icon class maps onto a real
    -- walker sheet where one exists (bird/monster/seel/fairy), so a
    -- Charizard carries you as the monster sprite and a Pidgey as the
    -- bird.  Icon-only classes (bug/plant/quadruped/snake) keep the bird.
    local MOUNT_BY_CLASS = {
      BIRD = "SPRITE_BIRD", MON = "SPRITE_MONSTER",
      WATER = "SPRITE_SEEL", FAIRY = "SPRITE_FAIRY",
      PIKACHU = "SPRITE_FAIRY",
    }
    local mountCache = {}
    state.resolveMount = function(mon)
      local mount = Player.__freeFlyBird
      local species = mon and mon.species
      if species then
        local icons = Game.data.icons or {}
        local def = Game.data.pokemon[species]
        local entry = (icons.bySpecies and icons.bySpecies[species])
                   or (def and def.icon)
                   or (def and def.dex and icons.byDex and icons.byDex[def.dex])
        local spriteId = type(entry) == "string" and MOUNT_BY_CLASS[entry]
        local spriteDef = spriteId and Game.data.sprites[spriteId]
        if spriteDef then
          mountCache[spriteId] = mountCache[spriteId]
            or SpriteRenderer.new(spriteDef, "free_fly_mount_" .. spriteId)
          mount = mountCache[spriteId]
        end
      end
      -- dex height sizes the mount: a Charizard dwarfs a Pidgey
      local dex = (species and Game.data.pokemon[species]
                   and Game.data.pokemon[species].dexEntry) or {}
      local feet = (dex.heightFt or 2) + (dex.heightIn or 0) / 12
      Player.__freeFlyMountScale = math.max(0.85, math.min(1.6, 0.75 + feet * 0.14))
      Player.__freeFlyMount = mount
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
