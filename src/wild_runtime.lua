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
      or (context.terrain ~= "grass" and context.terrain ~= "water")
      or type(run) ~= "table"
      or run.enabled ~= true
      or type(run.settings) ~= "table"
      or run.settings.wild_pokemon ~= "global_map"
      or type(run.mappings) ~= "table"
      or type(run.mappings.wildGlobal) ~= "table" then
    return encounter
  end

  local replacement = run.mappings.wildGlobal[encounter.species]
  if type(replacement) ~= "string" or replacement == "" then
    return encounter
  end
  local resolved = copyRecord(encounter)
  resolved.species = replacement
  return resolved
end

return WildRuntime
