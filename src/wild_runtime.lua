-- Pure runtime resolver for the saved global wild mapping.
local WildRuntime = {}

local function copyRecord(record)
  local output = {}
  for key, value in pairs(record) do output[key] = value end
  return output
end

function WildRuntime.resolve(encounter, context, run)
  if type(encounter) ~= "table"
      or type(context) ~= "table"
      or (context.terrain ~= "grass" and context.terrain ~= "water"
        and context.terrain ~= "indoor")
      or type(run) ~= "table"
      or run.enabled ~= true
      or type(run.settings) ~= "table"
      or type(run.mappings) ~= "table"
      or type(run.mappings.wildGlobal) ~= "table"
      or type(run.mappings.wildAreaSlots) ~= "table" then
    return encounter
  end

  local terrain = context.terrain == "water" and "water" or "grass"
  local slot = run.mappings.wildAreaSlots[context.mapId]
  slot = type(slot) == "table" and slot[terrain]
  slot = type(slot) == "table" and slot[encounter.slotIndex]
  local replacement
  if run.settings.wild_pokemon == "global_map" then
    replacement = run.mappings.wildGlobal[encounter.species]
  elseif run.settings.wild_pokemon == "area_slots" and type(slot) == "table" then
    replacement = slot.species
  else
    return encounter
  end
  if type(replacement) ~= "string" or replacement == "" then return encounter end
  if type(run._speciesSet) == "table"
      and not run._speciesSet[replacement] then return encounter end
  local resolved = copyRecord(encounter)
  resolved.species = replacement
  if type(slot) == "table" and type(slot.level) == "number" then
    resolved.level = slot.level
  end
  return resolved
end

-- Calls the vanilla/prior roll exactly once, then annotates an unambiguous
-- selected slot. It never repeats the engine's probability-bucket logic.
function WildRuntime.roll(nextFn, encounterDefinition, context, run)
  if type(run) ~= "table" or run.enabled ~= true
      or type(run.settings) ~= "table"
      or run.settings.wild_pokemon == "off"
      or (run.settings.wild_pokemon == "global_map"
        and run.settings.wild_levels == "unchanged") then
    return nextFn(encounterDefinition, context)
  end
  local encounter = nextFn(encounterDefinition, context)
  if type(encounter) ~= "table" or type(context) ~= "table" then
    return encounter
  end
  if type(encounter.slotIndex) == "number" then return encounter end
  local definition = type(encounterDefinition) == "table"
    and encounterDefinition.grass
  local slots = type(definition) == "table" and definition.slots
  if type(slots) ~= "table" then return encounter end
  local matched
  for index, slot in ipairs(slots) do
    if slot.species == encounter.species and slot.level == encounter.level then
      if matched then return encounter end
      matched = index
    end
  end
  if not matched then return encounter end
  local resolved = copyRecord(encounter)
  resolved.slotIndex = matched
  return resolved
end

function WildRuntime.fishing(encounter, rod, mapId, candidates, run)
  if type(encounter) ~= "table" or type(run) ~= "table"
      or run.enabled ~= true or type(run.settings) ~= "table"
      or run.settings.wild_pokemon == "off"
      or run.settings.fishing ~= "randomized"
      or type(run.mappings) ~= "table"
      or type(run.mappings.fishing) ~= "table" then
    return encounter
  end
  local mapping = run.mappings.fishing
  if run.settings.wild_pokemon == "global_map"
      and run.settings.wild_levels == "unchanged" then
    local replacement = type(mapping.global) == "table"
      and mapping.global[encounter.species]
    if type(replacement) ~= "string" or replacement == "" then
      return encounter
    end
    if type(run._speciesSet) == "table"
        and not run._speciesSet[replacement] then return encounter end
    local resolved = copyRecord(encounter)
    resolved.species = replacement
    return resolved
  end
  local index
  if type(candidates) == "table" then
    for candidateIndex, candidate in ipairs(candidates) do
      if candidate.species == encounter.species
          and candidate.level == encounter.level then
        if index then return encounter end
        index = candidateIndex
      end
    end
  else
    index = 1
  end
  if not index then return encounter end
  local slots = type(mapping.slots) == "table" and mapping.slots[rod]
  slots = type(slots) == "table"
    and (slots[mapId] or slots["*"])
  local slot = type(slots) == "table" and slots[index]
  local replacement
  if run.settings.wild_pokemon == "global_map" then
    replacement = type(mapping.global) == "table"
      and mapping.global[encounter.species]
  elseif type(slot) == "table" then
    replacement = slot.species
  end
  if type(replacement) ~= "string" or replacement == "" then return encounter end
  if type(run._speciesSet) == "table"
      and not run._speciesSet[replacement] then return encounter end
  local resolved = copyRecord(encounter)
  resolved.species = replacement
  if type(slot) == "table" and type(slot.level) == "number" then
    resolved.level = slot.level
  end
  return resolved
end

return WildRuntime
