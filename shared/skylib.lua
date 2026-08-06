-- Shared helpers for the gen1recomp-mods family.  Synced into each mod as
-- lib/shared/skylib.lua (scripts/dev.sh, scripts/pack.sh, release CI) and
-- loaded through mod:read, so the same file works from a checkout, the
-- game's save directory and a packed zip alike.
local Sky = {}

-- the species' party-icon class, via the same resolution the party menu
-- uses: bySpecies override, the pokemon record's own icon, dex default
function Sky.iconClass(data, species)
  local icons = data.icons or {}
  local def = data.pokemon and data.pokemon[species]
  local entry = (icons.bySpecies and icons.bySpecies[species])
             or (def and def.icon)
             or (def and def.dex and icons.byDex and icons.byDex[def.dex])
  return type(entry) == "string" and entry or nil
end

-- icon classes with a real walker sheet in the imported cache
Sky.MOUNT_SPRITES = {
  BIRD = "SPRITE_BIRD", MON = "SPRITE_MONSTER",
  WATER = "SPRITE_SEEL", FAIRY = "SPRITE_FAIRY", PIKACHU = "SPRITE_FAIRY",
}

local mountCache = {}

-- a cached walker SpriteRenderer for the species' icon class, falling
-- back to the bird.  Returns renderer, class; renderer is nil only when
-- even the bird sheet is missing (e.g. the ROM-free fixture base).
function Sky.mountSprite(data, species, seedPrefix)
  local class = species and Sky.iconClass(data, species) or nil
  local spriteId = (class and Sky.MOUNT_SPRITES[class]) or "SPRITE_BIRD"
  local def = data.sprites and data.sprites[spriteId]
  if not def then return nil, class end
  local key = (seedPrefix or "shared") .. "#" .. spriteId
  if not mountCache[key] then
    local SpriteRenderer = require("src.render.SpriteRenderer")
    mountCache[key] = SpriteRenderer.new(def,
      (seedPrefix or "shared") .. "_" .. spriteId)
  end
  return mountCache[key], class
end

-- dex height -> draw scale: Pidgey reads small, Charizard reads big
function Sky.dexScale(data, species)
  local def = data.pokemon and data.pokemon[species]
  local dex = (def and def.dexEntry) or {}
  local feet = (dex.heightFt or 2) + (dex.heightIn or 0) / 12
  return math.max(0.85, math.min(1.6, 0.75 + feet * 0.14))
end

function Sky.hasType(data, species, wanted)
  local def = data.pokemon and data.pokemon[species]
  for _, t in ipairs((def and def.types) or {}) do
    if t == wanted then return true end
  end
  return false
end

function Sky.knowsMove(mon, moveId)
  for _, mv in ipairs((mon and mon.moves) or {}) do
    if (type(mv) == "table" and mv.id or mv) == moveId then return true end
  end
  return false
end

return Sky
