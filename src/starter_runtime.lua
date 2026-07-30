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
  local keep = type(run.settings) ~= "table"
    or run.settings.rival_keep_pokemon ~= "no"
  local firstBattle = oppClass == "OPP_RIVAL1" and partyIndex <= 3
  if not keep and not firstBattle then return party end
  local offset = ((partyIndex - 1) % 3) + 1
  local chosen = starters[slots[offset]]
  if type(chosen) ~= "table" or type(chosen.rivalSpecies) ~= "string"
      or chosen.rivalSpecies == ""
      or (type(run._speciesSet) == "table"
        and not run._speciesSet[chosen.rivalSpecies]) then
    return party
  end
  local projected = chosen.rivalSpecies
  local trainerParties = run.mappings.trainerParties
  local classMappings = type(trainerParties) == "table"
    and trainerParties[oppClass]
  local rivalStarters = type(classMappings) == "table"
    and classMappings.rivalStarters
  local saved = type(rivalStarters) == "table"
    and rivalStarters[partyIndex]
  if type(saved) == "table" and type(saved.species) == "string"
      and saved.species ~= "" then
    projected = saved.species
  end
  if type(run._speciesSet) == "table"
      and not run._speciesSet[projected] then return party end
  local output = copyParty(party)
  output[#output].species = projected
  return output
end

return StarterRuntime
