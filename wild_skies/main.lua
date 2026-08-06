-- Wild Skies: flying Pokémon visibly cross the overworld.  Species come
-- from the map's own grass slots; outdoor maps with no flying slots (the
-- sea routes) get a sparse ambient pool instead, so the ocean sky is not
-- empty.  Flyers cruise at varied heights, and some land mid-crossing or
-- start perched on the ground and flush when the player gets close.
--
-- Flyers are lightweight entities inserted into the overworld's entity
-- list (drawn in the world pass, `passable` so they never block anyone)
-- but kept out of the NPC list, so scripts and talk targeting never see
-- them.  All art is the player's own imported cache; nothing ships.
return function(mod)
  -- shared helpers, synced in as lib/shared/ by the monorepo's scripts
  local function loadShared(file)
    local src = mod:read("lib/shared/" .. file)
    if not src then return nil end
    return assert((loadstring or load)(src, "@wild_skies/lib/shared/" .. file))()
  end
  local Sky = loadShared("skylib.lua")
  if not Sky then
    mod.log:error("lib/shared/skylib.lua is missing -- run scripts/dev.sh "
      .. "in the gen1recomp-mods repo to sync shared code; mod disabled")
    return
  end

  mod.options:define({
    { key = "density", label = "SKY DENSITY", type = "choice", default = "med",
      choices = { { "LOW", "low" }, { "MED", "med" }, { "HIGH", "high" } } },
    { key = "bumps", label = "GROUND BUMPS", type = "toggle", default = true },
  })

  -- a bird at or below this height can collide with a walking player;
  -- anything cruising higher is safe scenery from the ground
  local LOW_ALT = 12

  local DENSITY = {
    low  = { cap = 2, cooldown = 14 },
    med  = { cap = 3, cooldown = 8 },
    high = { cap = 5, cooldown = 5 },
  }
  local function density()
    return DENSITY[mod.options:get("density")] or DENSITY.med
  end

  local CLASS_PROFILE = {
    BIRD  = { speed = { 30, 46 }, alt = { 16, 24 }, flap = 8, bob = 2 },
    MON   = { speed = { 22, 34 }, alt = { 12, 18 }, flap = 5, bob = 3 },
    WATER = { speed = { 20, 30 }, alt = { 10, 14 }, flap = 4, bob = 2 },
    FAIRY = { speed = { 24, 36 }, alt = { 12, 18 }, flap = 6, bob = 2 },
  }
  local DEFAULT_PROFILE = CLASS_PROFILE.BIRD

  local CLIMB = 44            -- px/s vertical, both directions
  local FLUSH_CELLS = 2       -- a grounded bird flushes at this distance

  -- crepuscular species only fly the night sky
  local NIGHT_ONLY = { ZUBAT = true, GOLBAT = true }

  -- the sparse pool for outdoor maps whose slots offer no flyers (sea
  -- routes); repeats weight the roll, levels are rolled at spawn
  local AMBIENT_DAY  = { "PIDGEY", "PIDGEY", "PIDGEY", "SPEAROW", "SPEAROW",
                         "PIDGEOTTO", "FEAROW" }
  local AMBIENT_NITE = { "ZUBAT", "ZUBAT", "ZUBAT", "GOLBAT" }

  local flyers = {}
  local cooldown = 3
  local serial = 0
  local picksCache = { key = nil, picks = nil, ambient = false }

  local function detach(ow, flyer)
    if ow and ow.entities then
      for j = #ow.entities, 1, -1 do
        if ow.entities[j] == flyer then table.remove(ow.entities, j) end
      end
    end
  end

  local function clearAll(ow)
    for i = #flyers, 1, -1 do
      detach(ow, flyers[i])
      table.remove(flyers, i)
    end
  end

  -- ------- inter-mod API
  -- free_fly (or any mod) can read and consume flyers; this is the
  -- supported seam, so nothing reaches into this mod's internals

  -- newborns are excluded: a flyer must have existed long enough to be
  -- seen before anything may collide with it
  local function flyerNear(cellX, cellY, radius)
    radius = radius or 1
    for _, f in ipairs(flyers) do
      if not f.dead and f.t >= 0.75
         and math.abs(f.cellX - cellX) + math.abs(f.cellY - cellY) <= radius then
        return f
      end
    end
  end

  mod.exports.flyerAt = function(cellX, cellY, radius)
    local f = flyerNear(cellX, cellY, radius)
    if f then return { species = f.species, level = f.level } end
  end

  -- sprite packs with in-air art can register a source (shared/README
  -- in the repo documents the shape); this reaches only THIS mod's
  -- bundled resolver, so packs register with each mod they dress
  mod.exports.registerSpriteSource = Sky.registerSpriteSource
  mod.exports.unregisterSpriteSource = Sky.unregisterSpriteSource

  -- consume the flyer: despawns it and hands back its identity, or nil
  mod.exports.takeFlyer = function(cellX, cellY, radius)
    local f = flyerNear(cellX, cellY, radius)
    if not f then return nil end
    local Game = require("src.core.Game")
    f.dead = true
    detach(Game and Game.overworld, f)
    for i = #flyers, 1, -1 do
      if flyers[i] == f then table.remove(flyers, i) end
    end
    return { species = f.species, level = f.level }
  end

  -- a classic step encounter that rolls a species with a lookalike near
  -- the player IS that bird as far as anyone can tell, so the roll
  -- consumes it: the bird carries its own level into the battle, and a
  -- defeat or capture never leaves it perched there or flying off.  A
  -- grounded or landing bird outranks a flying one, being the one the
  -- player is actually stood next to.
  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local enc = next(encDef, ctx)
    if enc and enc.species then
      local Game = require("src.core.Game")
      local ow = Game and Game.overworld
      local p = ow and ow.player
      if p then
        local pick, pickIndex
        for i, f in ipairs(flyers) do
          if not f.dead and f.species == enc.species
             and math.abs(f.cellX - p.cellX)
               + math.abs(f.cellY - p.cellY) <= 2 then
            if f.mode == "ground" or f.mode == "toLand" then
              pick, pickIndex = f, i
              break
            end
            if not pick then pick, pickIndex = f, i end
          end
        end
        if pick then
          enc.level = pick.level or enc.level
          pick.dead = true
          detach(ow, pick)
          table.remove(flyers, pickIndex)
        end
      end
    end
    return enc
  end)

  -- free_fly's exported flight state when it is around, else the raw
  -- field it stamps on the player
  local function playerAirborne(p)
    local ff = mod.find("free_fly")
    local api = ff and ff.exports and ff.exports.isFlying
    if api then
      local ok, v = pcall(api)
      if ok then return v == true end
    end
    return p ~= nil and p.freeFlying == true
  end

  -- the map's grass slots filtered to FLYING types and the time of day;
  -- night-only species own the night sky and sit out the daylight
  local function flyingSlots(game, mapId, tod)
    local all, night = {}, {}
    local encDef = game.data.encounters and game.data.encounters[mapId]
    local slots = encDef and encDef.grass and encDef.grass.slots
    for _, slot in ipairs(slots or {}) do
      if Sky.hasType(game.data, slot.species, "FLYING") then
        local pick = { species = slot.species, level = slot.level }
        if NIGHT_ONLY[slot.species] then
          night[#night + 1] = pick
        else
          all[#all + 1] = pick
        end
      end
    end
    if tod == "NITE" then
      return #night > 0 and night or all
    end
    return all
  end

  local Flyer = {}
  Flyer.__index = Flyer

  local function mountFor(game, species)
    local sprite, class = Sky.mountSprite(game.data, species, "wild_skies")
    return sprite, CLASS_PROFILE[class] or DEFAULT_PROFILE
  end

  -- a walkable, unoccupied cell inside the camera view but away from the
  -- player: where a bird can sit
  local function findPerchCell(ow, game)
    local cam, map, p = ow.camera, ow.map, ow.player
    local vw, vh = game.renderer:worldViewSize()
    for _ = 1, 24 do
      local x = math.floor((cam.x + love.math.random(0, vw)) / 16)
      local y = math.floor((cam.y + love.math.random(0, vh)) / 16)
      if map:inBounds(x, y) and map:isWalkableCell(x, y)
         and math.abs(x - p.cellX) + math.abs(y - p.cellY) >= 4 then
        local Collision = require("src.world.Collision")
        if not Collision.occupied(ow.entities, x, y, nil) then
          return x, y
        end
      end
    end
    return nil
  end

  function Flyer.new(game, ow, pick)
    local sprite, profile = mountFor(game, pick.species)
    if not sprite then return nil end
    serial = serial + 1
    local self = setmetatable({}, Flyer)
    self.id = "wild_skies_" .. serial
    self.sprite = sprite
    self.species = pick.species
    self.level = pick.level or love.math.random(3, 10)
    self.passable = true
    self.bobAmp = profile.bob
    self.scale = Sky.dexScale(game.data, pick.species)
    -- big wings beat slower: the class rate eased by dex size
    self.flap = profile.flap / math.max(1, self.scale)

    local map, cam, p = ow.map, ow.camera, ow.player
    local vw, vh = game.renderer:worldViewSize()
    self.mapW = ((map.widthCells or (map.width or 10) * 2)) * 16
    self.mapH = ((map.heightCells or (map.height or 9) * 2)) * 16

    -- cruise height: the class band, with an occasional high flyer whose
    -- faded shadow reads as distance
    self.cruise = love.math.random(profile.alt[1], profile.alt[2])
    if love.math.random() < 0.3 then
      self.cruise = self.cruise + love.math.random(10, 22)
    end

    local speed = love.math.random(profile.speed[1], profile.speed[2])
    local roll = love.math.random()
    local perchX, perchY
    if roll < 0.45 then
      perchX, perchY = findPerchCell(ow, game)
    end

    if perchX and roll < 0.2 then
      -- perched: already on the ground, flushes when approached
      self.mode = "ground"
      self.groundT = love.math.random(6, 14)
      self.px, self.py = perchX * 16, perchY * 16
      self.alt = 0
      self.vx = (love.math.random() < 0.5 and 1 or -1) * speed
      self.vy = 0
    else
      -- airborne entry from just past the camera's near edge
      local margin = 24
      local dir = love.math.random() < 0.5 and 1 or -1
      local startX = dir == 1 and (cam.x - margin - 16) or (cam.x + vw + margin)
      self.px = math.max(0, math.min(self.mapW - 16, startX))
      self.py = math.max(0, math.min(self.mapH - 16,
                  cam.y + love.math.random(8, math.max(9, vh - 24))))
      -- a small map can clamp the "off-screen" entry right next to the
      -- player; refuse to materialize a bird on top of them
      if math.abs(math.floor((self.px + 8) / 16) - p.cellX)
         + math.abs(math.floor((self.py + 8) / 16) - p.cellY) < 5 then
        return nil
      end
      self.vx = dir * speed
      self.vy = love.math.random(-8, 8)
      self.alt = self.cruise
      if perchX then
        -- stopover: descend onto the perch when passing it, rest, move on
        self.mode = "toLand"
        self.landX, self.landY = perchX * 16, perchY * 16
        self.vy = math.max(-14, math.min(14, (self.landY - self.py) / 6))
      else
        self.mode = "cross"
      end
    end
    self.t = 0
    self.deadline = 6 + (vw + 96) / speed
    self.cellX = math.floor((self.px + 8) / 16)
    self.cellY = math.floor((self.py + 8) / 16)
    return self
  end

  function Flyer:tick(ow, dt)
    self.t = self.t + dt
    local p = ow.player

    if self.mode == "ground" then
      self.groundT = self.groundT - dt
      local near = p and (math.abs(p.cellX - self.cellX)
                        + math.abs(p.cellY - self.cellY)) <= FLUSH_CELLS
      if near or self.groundT <= 0 then
        self.mode = "rise"
        -- flush away from the player, otherwise keep heading
        if near and p then
          self.vx = (p.px > self.px and -1 or 1) * math.abs(self.vx)
        end
        self.vy = love.math.random(-6, 6)
        self.deadline = self.t + 6 + (400 / math.abs(self.vx))
      end
    elseif self.mode == "rise" then
      self.alt = math.min(self.cruise, self.alt + CLIMB * dt)
      self.px = self.px + self.vx * 0.4 * dt
      if self.alt >= self.cruise then self.mode = "cross" end
    elseif self.mode == "toLand" then
      self.px = self.px + self.vx * dt
      self.py = self.py + self.vy * dt
      local past = (self.vx > 0 and self.px >= self.landX)
                or (self.vx < 0 and self.px <= self.landX)
      if past then
        self.px, self.vy = self.landX, 0
        self.alt = self.alt - CLIMB * dt
        if self.alt <= 0 then
          self.alt = 0
          self.py = self.landY
          self.mode = "ground"
          self.groundT = love.math.random(3, 8)
        end
      end
    else -- cross
      self.px = self.px + self.vx * dt
      self.py = self.py + self.vy * dt
    end

    self.cellX = math.floor((self.px + 8) / 16)
    self.cellY = math.floor((self.py + 8) / 16)
    local grounded = self.mode == "ground" or self.mode == "toLand"
    if (not grounded and self.t >= self.deadline)
       or not ow.map:inBounds(self.cellX, self.cellY) then
      self.dead = true
    end
  end

  local function visualLift(self)
    if self.mode == "ground" then return 0 end
    local bob = self.mode == "cross"
      and math.sin(self.t * 3) * self.bobAmp or 0
    return self.alt + bob
  end

  local function flapPhase(self)
    if self.mode == "ground" then
      -- a resting bird mostly stands, with the odd peck
      return (math.floor(self.t * 2) % 5 == 0) and 1 or 0
    end
    return math.floor(self.t * self.flap) % 2
  end

  -- the overworld entity loop calls this in the world pass
  function Flyer:draw(camX, camY)
    local s = self.scale or 1
    local lift = visualLift(self)
    -- the shadow fades and tightens with height, a cheap depth cue
    local fade = math.max(0.35, 1 - lift / 90)
    local size = math.max(0.6, 1 - lift / 140)
    love.graphics.setColor(0, 0, 0, 0.3 * fade)
    love.graphics.ellipse("fill", self.px + 8 - camX, self.py + 14 - camY,
                          5 * s * size, 2 * s * size)
    love.graphics.setColor(1, 1, 1, 1)
    local facing = self.vx < 0 and "left" or "right"
    local sy = math.floor(self.py - lift + 0.5)
    if s ~= 1 then
      local fx = math.floor(self.px + 8 - camX)
      local fy = math.floor(sy + 12 - camY)
      love.graphics.push()
      love.graphics.translate(fx, fy)
      love.graphics.scale(s, s)
      love.graphics.translate(-fx, -fy)
    end
    self.sprite:draw(math.floor(self.px + 0.5), sy, camX, camY,
                     facing, flapPhase(self), false)
    if s ~= 1 then love.graphics.pop() end
  end

  -- same pose contract as NPC/Player, so render pipelines (voxel, tilt)
  -- can billboard a flyer without knowing what it is; the lift is baked
  -- into the returned y
  function Flyer:pose()
    return self.sprite, self.px, self.py - visualLift(self),
           (self.vx < 0 and "left" or "right"), flapPhase(self), false, false
  end

  -- spawn one flyer on demand (scenario mods, tests): entry, height and
  -- behaviour roll as usual; the ambient caps and cooldowns are not
  -- consulted.  Returns the flyer id, or nil and a reason.
  mod.exports.spawnFlyer = function(species, level)
    local Game = require("src.core.Game")
    local ow = Game and Game.overworld
    if not (ow and ow.map and ow.player) then return nil, "no overworld" end
    local flyer = Flyer.new(Game, ow, { species = species, level = level })
    if not flyer then
      return nil, "no sprite or no clear entry for " .. tostring(species)
    end
    flyers[#flyers + 1] = flyer
    table.insert(ow.entities, flyer)
    return flyer.id
  end

  -- a sprite-source mod changed its settings (e.g. Wilds of Kanto's
  -- Sprite Style): live flyers re-dress in the new art immediately
  mod.events:on("mod.options_changed", function(payload)
    if not Sky.spriteSourceChanged(payload) then return end
    local Game = require("src.core.Game")
    for _, f in ipairs(flyers) do
      local sprite = mountFor(Game, f.species)
      if sprite then f.sprite = sprite end
    end
  end)

  local keepThroughSeam = false

  mod.events:on("map.exited", function()
    if keepThroughSeam then
      keepThroughSeam = false
      return
    end
    local Game = require("src.core.Game")
    clearAll(Game and Game.overworld)
    cooldown = 3
  end)

  mod.events:on("game.ready", function()
    local Game = require("src.core.Game")
    local OC = require("src.world.OverworldController")
    local MapDef = require("src.world.Map")
    local FieldDefaults = require("src.world.FieldDefaults")

    local bumpCooldown = 0

    OC.__wildSkiesTick = function(ow, dt)
      if not (ow and ow.map and ow.player) then return end
      dt = dt or 1 / 60
      for i = #flyers, 1, -1 do
        local f = flyers[i]
        f:tick(ow, dt)
        if f.dead then
          detach(ow, f)
          table.remove(flyers, i)
        end
      end

      -- a LOW bird can bump a grounded player into its battle; high
      -- flyers never touch anyone below them.  Airborne players are
      -- free_fly's interception's business, not this one's.
      bumpCooldown = math.max(0, bumpCooldown - dt)
      local p = ow.player
      if bumpCooldown <= 0 and p and not playerAirborne(p)
         and mod.options:get("bumps") then
        local f = flyerNear(p.cellX, p.cellY, 1)
        if f and (f.alt or 0) <= LOW_ALT then
          local okQ = mod.world:queueScript({
            { "start_battle", "wild", f.species, f.level or 5 },
          })
          if okQ then
            bumpCooldown = 2
            pcall(function()
              require("src.core.Sound").playCry(Game.data, f.species)
            end)
            f.dead = true
            detach(ow, f)
            for i = #flyers, 1, -1 do
              if flyers[i] == f then table.remove(flyers, i) end
            end
            mod.log:info("bumped into %s!", tostring(f.species))
            pcall(function()
              mod.events:emit("mod.wild_skies.flyer_bumped", {
                species = f.species, level = f.level or 5,
                cellX = f.cellX, cellY = f.cellY,
              })
            end)
          end
        end
      end

      cooldown = cooldown - dt
      local d = density()
      -- ambient (slot-less) skies stay sparser than encounter-fed ones,
      -- and the forest canopy holds one bird at a time
      local cap = picksCache.ambient and math.max(1, d.cap - 1) or d.cap
      if picksCache.forest then cap = 1 end
      if cooldown > 0 or #flyers >= cap then return end
      local tod = ow.tod or "DAY"
      local key = ow.map.id .. "#" .. tod
      if picksCache.key ~= key then
        picksCache.key = key
        picksCache.ambient = false
        picksCache.picks = flyingSlots(Game, ow.map.id, tod)
        -- ambient skies only where the game itself hosts wildlife: the
        -- map must carry SOME encounter table (sea routes do; towns like
        -- Cinnabar and Pallet don't, and their skies stay quiet)
        local forest = ow.map.def and ow.map.def.tileset == "FOREST"
        picksCache.forest = forest or false
        if #picksCache.picks == 0 and ow.map.def
           and Game.data.encounters and Game.data.encounters[ow.map.id]
           and (forest or MapDef.isOutside(ow.map.def,
                 FieldDefaults.field(Game.data, "outsideTilesets"))) then
          local pool = tod == "NITE" and AMBIENT_NITE or AMBIENT_DAY
          for _, species in ipairs(pool) do
            picksCache.picks[#picksCache.picks + 1] = { species = species }
          end
          picksCache.ambient = true
        end
      end
      local picks = picksCache.picks
      if #picks == 0 then
        cooldown = d.cooldown
        return
      end
      cooldown = d.cooldown * (picksCache.forest and 2.5
        or picksCache.ambient and 1.8 or 1) + love.math.random() * 6
      local pick = picks[love.math.random(#picks)]
      local flyer = Flyer.new(Game, ow, pick)
      if flyer and picksCache.forest then
        -- weave between the trunks, not over the canopy
        flyer.cruise = math.min(flyer.cruise, 16)
        if flyer.alt > flyer.cruise then flyer.alt = flyer.cruise end
      end
      if flyer then
        flyers[#flyers + 1] = flyer
        table.insert(ow.entities, flyer)
        mod.log:info("%s (L%d) is crossing %s",
                     tostring(flyer.species), flyer.level or 0, ow.map.id)
      end
    end

    if not OC.__wildSkiesWrapped then
      OC.__wildSkiesWrapped = true
      local origUpdate = OC.update
      OC.update = function(self, dt)
        origUpdate(self, dt)
        if OC.__wildSkiesTick then
          local ok, err = pcall(OC.__wildSkiesTick, self, dt)
          if not ok then print("[wild_skies] tick failed: " .. tostring(err)) end
        end
      end
    end

    -- birds survive seamless connection crossings: translate them by the
    -- same coordinate rebase the player gets, and re-attach them to the
    -- rebuilt entity list.  Out-of-bounds ones despawn naturally.
    if not OC.__wildSkiesSeamWrapped then
      OC.__wildSkiesSeamWrapped = true
      local origCross = OC.crossConnection
      OC.crossConnection = function(self, dir, conn)
        local carry = OC.__wildSkiesCarry
        if not carry then return origCross(self, dir, conn) end
        return carry(self, dir, conn, origCross)
      end
    end
    OC.__wildSkiesCarry = function(self, dir, conn, origCross)
      local p = self.player
      local beforeX, beforeY = p.px, p.py
      keepThroughSeam = #flyers > 0
      local crossed = origCross(self, dir, conn)
      if not crossed then
        keepThroughSeam = false
        return crossed
      end
      local dx, dy = p.px - beforeX, p.py - beforeY
      for _, f in ipairs(flyers) do
        f.px, f.py = f.px + dx, f.py + dy
        if f.landX then f.landX, f.landY = f.landX + dx, f.landY + dy end
        f.cellX = math.floor((f.px + 8) / 16)
        f.cellY = math.floor((f.py + 8) / 16)
        f.mapW = ((self.map.widthCells or (self.map.width or 10) * 2)) * 16
        f.mapH = ((self.map.heightCells or (self.map.height or 9) * 2)) * 16
        table.insert(self.entities, f)
      end
      return crossed
    end
  end)
end
