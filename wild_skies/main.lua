-- Wild Skies: FLYING-type species from the current map's own grass
-- encounter slots cross the screen overhead, casting a shadow and bobbing
-- as they go.  Phase 2: flyers glide in from off-screen, wear their own
-- icon-class sprite (bird/monster/seel/fairy walker sheets), fly a
-- per-class profile, and respect time of day (Zubat crosses at night).
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
  })

  local DENSITY = {
    low  = { cap = 2, cooldown = 14 },
    med  = { cap = 3, cooldown = 8 },
    high = { cap = 5, cooldown = 5 },
  }
  local function density()
    return DENSITY[mod.options:get("density")] or DENSITY.med
  end

  -- flight character per party-icon class; classes without a walker sheet
  -- ride the bird look (sheet resolution lives in shared skylib)
  local CLASS_PROFILE = {
    BIRD  = { speed = { 30, 46 }, alt = { 16, 24 }, flap = 8, bob = 2 },
    MON   = { speed = { 22, 34 }, alt = { 12, 18 }, flap = 5, bob = 3 },
    WATER = { speed = { 20, 30 }, alt = { 10, 14 }, flap = 4, bob = 2 },
    FAIRY = { speed = { 24, 36 }, alt = { 12, 18 }, flap = 6, bob = 2 },
  }
  local DEFAULT_PROFILE = CLASS_PROFILE.BIRD

  -- crepuscular species only fly the night sky
  local NIGHT_ONLY = { ZUBAT = true, GOLBAT = true }

  local flyers = {}
  local cooldown = 3
  local serial = 0
  local picksCache = { key = nil, picks = nil }

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

  local function flyerNear(cellX, cellY, radius)
    radius = radius or 1
    for _, f in ipairs(flyers) do
      if math.abs(f.cellX - cellX) + math.abs(f.cellY - cellY) <= radius then
        return f
      end
    end
  end

  mod.exports.flyerAt = function(cellX, cellY, radius)
    local f = flyerNear(cellX, cellY, radius)
    if f then return { species = f.species, level = f.level } end
  end

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

  -- the map's grass slots, filtered to FLYING types and the time of day:
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

  function Flyer.new(game, ow, pick)
    local sprite, profile = mountFor(game, pick.species)
    if not sprite then return nil end
    serial = serial + 1
    local self = setmetatable({}, Flyer)
    self.id = "wild_skies_" .. serial
    self.sprite = sprite
    self.species, self.level = pick.species, pick.level
    self.passable = true
    self.flap = profile.flap
    self.bobAmp = profile.bob
    -- dex height sets the on-screen size: Pidgey small, Charizard big
    self.scale = Sky.dexScale(game.data, pick.species)

    -- glide in from just past the camera's near edge, crossing the view;
    -- clamped to the map, so at a world edge the entry is the edge itself
    local map = ow.map
    local cam = ow.camera
    local vw, vh = game.renderer:worldViewSize()
    local wpx = ((map.widthCells or (map.width or 10) * 2)) * 16
    local hpx = ((map.heightCells or (map.height or 9) * 2)) * 16
    local margin = 24
    local dir = love.math.random() < 0.5 and 1 or -1
    local startX = dir == 1 and (cam.x - margin - 16) or (cam.x + vw + margin)
    self.px = math.max(0, math.min(wpx - 16, startX))
    self.py = math.max(0, math.min(hpx - 16,
                cam.y + love.math.random(8, math.max(9, vh - 24))))
    self.vx = dir * love.math.random(profile.speed[1], profile.speed[2])
    self.vy = love.math.random(-8, 8)
    self.alt = love.math.random(profile.alt[1], profile.alt[2])
    self.t = 0
    self.ttl = (vw + 2 * margin + 64) / math.abs(self.vx)
    self.cellX = math.floor((self.px + 8) / 16)
    self.cellY = math.floor((self.py + 8) / 16)
    return self
  end

  function Flyer:tick(ow, dt)
    self.t = self.t + dt
    self.px = self.px + self.vx * dt
    self.py = self.py + self.vy * dt
    self.cellX = math.floor((self.px + 8) / 16)
    self.cellY = math.floor((self.py + 8) / 16)
    if self.t >= self.ttl or not ow.map:inBounds(self.cellX, self.cellY) then
      self.dead = true
    end
  end

  -- the overworld entity loop calls this in the world pass
  function Flyer:draw(camX, camY)
    local s = self.scale or 1
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", self.px + 8 - camX, self.py + 14 - camY,
                          5 * s, 2 * s)
    love.graphics.setColor(1, 1, 1, 1)
    local facing = self.vx < 0 and "left" or "right"
    local flap = math.floor(self.t * self.flap) % 2
    local bob = math.sin(self.t * 3) * self.bobAmp
    local sy = math.floor(self.py - self.alt - bob + 0.5)
    if s ~= 1 then
      -- scale around the sprite's foot-center so the anchor holds
      local fx = math.floor(self.px + 8 - camX)
      local fy = math.floor(sy + 12 - camY)
      love.graphics.push()
      love.graphics.translate(fx, fy)
      love.graphics.scale(s, s)
      love.graphics.translate(-fx, -fy)
    end
    self.sprite:draw(math.floor(self.px + 0.5), sy, camX, camY,
                     facing, flap, false)
    if s ~= 1 then love.graphics.pop() end
  end

  -- same pose contract as NPC/Player, so render pipelines (voxel, tilt)
  -- can billboard a flyer without knowing what it is; the lift is baked
  -- into the returned y
  function Flyer:pose()
    local bob = math.sin(self.t * 3) * self.bobAmp
    return self.sprite, self.px, self.py - self.alt - bob,
           (self.vx < 0 and "left" or "right"),
           math.floor(self.t * self.flap) % 2, false, false
  end

  mod.events:on("map.exited", function()
    local Game = require("src.core.Game")
    clearAll(Game and Game.overworld)
    cooldown = 3
  end)

  mod.events:on("game.ready", function()
    local Game = require("src.core.Game")
    local OC = require("src.world.OverworldController")

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
      cooldown = cooldown - dt
      local d = density()
      if cooldown > 0 or #flyers >= d.cap then return end
      -- per-(map, time-of-day) cache: the slot filter runs once per
      -- visit, not per frame; flyer-less skies re-arm a long cooldown
      local tod = ow.tod or "DAY"
      local key = ow.map.id .. "#" .. tod
      if picksCache.key ~= key then
        picksCache.key = key
        picksCache.picks = flyingSlots(Game, ow.map.id, tod)
      end
      local picks = picksCache.picks
      if #picks == 0 then
        cooldown = d.cooldown
        return
      end
      cooldown = d.cooldown + love.math.random() * 6
      local pick = picks[love.math.random(#picks)]
      local flyer = Flyer.new(Game, ow, pick)
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
  end)
end
