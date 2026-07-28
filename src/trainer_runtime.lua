-- O(1) projection of saved trainer parties through the v0.1.30 hook.
local TrainerRuntime = {}

local function copyArray(source)
  local output = {}
  for index, value in ipairs(source or {}) do output[index] = value end
  return output
end

local function validParty(party)
  if type(party) ~= "table" or #party < 1 or #party > 6 then return false end
  for index, slot in ipairs(party) do
    if type(slot) ~= "table" or type(slot.species) ~= "string"
        or slot.species == "" or type(slot.level) ~= "number"
        or slot.level < 2 or slot.level > 100
        or slot.level ~= math.floor(slot.level) then
      return false
    end
    if slot.moves ~= nil and type(slot.moves) ~= "table" then return false end
    if index > 6 then return false end
  end
  return true
end

function TrainerRuntime.party(party, oppClass, partyIndex, run)
  if type(party) ~= "table" or type(oppClass) ~= "string"
      or type(partyIndex) ~= "number" or partyIndex < 1
      or partyIndex ~= math.floor(partyIndex)
      or type(run) ~= "table" or type(run.mappings) ~= "table" then
    return party
  end
  local classes = run.mappings.trainerParties
  local saved = type(classes) == "table"
    and type(classes[oppClass]) == "table"
    and classes[oppClass][partyIndex] or nil
  if not validParty(saved) then return party end
  if type(run._speciesSet) == "table" then
    for _, slot in ipairs(saved) do
      if not run._speciesSet[slot.species] then return party end
    end
  end

  local output = {}
  for index, savedSlot in ipairs(saved) do
    local row = {
      species = savedSlot.species,
      level = savedSlot.level,
    }
    -- An earlier runtime hook's explicit moves are authoritative.
    local resolved = party[index]
    if type(resolved) == "table" and type(resolved.moves) == "table" then
      row.moves = copyArray(resolved.moves)
    elseif type(savedSlot.moves) == "table" then
      row.moves = copyArray(savedSlot.moves)
    end
    output[index] = row
  end
  return output
end

TrainerRuntime.validParty = validParty
return TrainerRuntime
