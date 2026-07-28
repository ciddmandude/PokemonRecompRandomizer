-- Randomizer-side adapter for saved starter offers.
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
  local mappings = type(run) == "table"
      and type(run.mappings) == "table"
      and run.mappings.starters
  local resolved = type(mappings) == "table"
      and mappings[offer.slotId] or nil
  if StarterOffer.validate(resolved) then return copy(resolved) end
  return copy(offer)
end

return StarterOffer
