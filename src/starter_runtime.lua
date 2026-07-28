-- Runtime projection of the saved rival counterpick into vanilla rival teams.
local StarterRuntime = {}

local RIVAL_CLASSES = {
  OPP_RIVAL1 = true,
  OPP_RIVAL2 = true,
  OPP_RIVAL3 = true,
}

local function copyParty(party)
  local output = {}
  for index, slot in ipairs(party) do
    local row = {}
    for key, value in pairs(slot) do row[key] = value end
    output[index] = row
  end
  return output
end

function StarterRuntime.party(party, oppClass, partyIndex, run)
  if not RIVAL_CLASSES[oppClass] or type(partyIndex) ~= "number"
      or partyIndex < 1 or partyIndex % 1 ~= 0
      or type(party) ~= "table" or #party == 0
      or type(run) ~= "table" or type(run.mappings) ~= "table" then
    return party
  end
  local starters = run.mappings.starters
  local flags = run.mappings.starterFlags
  local slots = type(flags) == "table" and flags.partyOffsetSlots
  if type(starters) ~= "table" or type(slots) ~= "table" then return party end
  local offset = ((partyIndex - 1) % 3) + 1
  local chosen = starters[slots[offset]]
  if type(chosen) ~= "table" or type(chosen.rivalSpecies) ~= "string"
      or chosen.rivalSpecies == "" then
    return party
  end
  local output = copyParty(party)
  output[#output].species = chosen.rivalSpecies
  return output
end

return StarterRuntime
