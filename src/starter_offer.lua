-- Randomizer-side adapter for the API-2 starter.offer seam.
-- M9 deliberately preserves the resolved downstream offer; M10 will project
-- saved starter mappings through this validated boundary.
local StarterOffer = {}

local REQUIRED_STRINGS = {
  "slotId",
  "species",
  "choseFlag",
  "ballObject",
  "rivalBall",
}

local function copy(value)
  local result = {}
  for key, child in pairs(value) do result[key] = child end
  return result
end

function StarterOffer.validate(offer)
  if type(offer) ~= "table" then
    return false, "starter offer must be a table"
  end
  for _, key in ipairs(REQUIRED_STRINGS) do
    if type(offer[key]) ~= "string" or offer[key] == "" then
      return false, key .. " must be a non-empty string"
    end
  end
  if type(offer.level) ~= "number" or offer.level % 1 ~= 0
      or offer.level < 1 or offer.level > 100 then
    return false, "level must be an integer from 1 through 100"
  end
  return true, nil
end

function StarterOffer.resolve(offer, context, run)
  local valid = StarterOffer.validate(offer)
  if not valid then return offer end
  -- Keep M9 behavior vanilla even for an active randomizer save. M10 owns
  -- generation and projection of starter mappings.
  return copy(offer)
end

return StarterOffer
