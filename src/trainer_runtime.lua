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
    if type(slot) ~= "table" then
      return false
    end
    if slot.fallback == true then
      if type(slot.sourceSlot) ~= "number"
          or slot.sourceSlot < 1 or slot.sourceSlot > 6
          or slot.sourceSlot ~= math.floor(slot.sourceSlot) then
        return false
      end
    elseif type(slot.species) ~= "string"
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

local function priorSlot(party, index)
  local slot = type(party) == "table" and party[index]
  if type(slot) ~= "table" or type(slot.species) ~= "string"
      or slot.species == "" or type(slot.level) ~= "number"
      or slot.level < 2 or slot.level > 100
      or slot.level ~= math.floor(slot.level) then
    return nil
  end
  local copy = {
    species = slot.species,
    level = slot.level,
  }
  if type(slot.moves) == "table" then
    copy.moves = copyArray(slot.moves)
  end
  return copy
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
      if slot.fallback ~= true
          and not run._speciesSet[slot.species] then return party end
    end
  end

  local output = {}
  for index, savedSlot in ipairs(saved) do
    local sourceIndex = type(savedSlot.sourceSlot) == "number"
      and savedSlot.sourceSlot or index
    local resolved = priorSlot(party, sourceIndex)
    if savedSlot.fallback == true then
      if not resolved then return party end
      output[index] = resolved
    else
    local row = {
      species = savedSlot.species,
      level = savedSlot.level,
    }
    -- An earlier runtime hook's explicit moves are authoritative.
    if type(resolved) == "table" and type(resolved.moves) == "table" then
      row.moves = copyArray(resolved.moves)
    elseif type(savedSlot.moves) == "table" then
      row.moves = copyArray(savedSlot.moves)
    end
    output[index] = row
    end
  end
  return output
end

TrainerRuntime.validParty = validParty
return TrainerRuntime
