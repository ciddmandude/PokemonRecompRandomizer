-- Cross-category reachability checks and deterministic repair swaps.
return function(StableSort, Canonical)
  local Validation = {}

  local function addSpecies(found, value)
    if type(value) == "string" and value ~= "" then
      found[value] = (found[value] or 0) + 1
    elseif type(value) == "table" and type(value.species) == "string" then
      found[value.species] = (found[value.species] or 0) + 1
    end
  end

  local function wildUnits(mappings)
    local units = {}
    for _, source in ipairs(StableSort.keys(mappings.wildGlobal or {})) do
      units[#units + 1] = {
        owner = mappings.wildGlobal, key = source,
        species = mappings.wildGlobal[source],
      }
    end
    local function walk(value)
      if type(value) ~= "table" then return end
      if type(value.species) == "string" then
        units[#units + 1] = {
          owner = value, key = "species", species = value.species,
        }
        return
      end
      for _, key in ipairs(StableSort.keys(value)) do walk(value[key]) end
    end
    walk(mappings.wildAreaSlots or {})
    local fishing = mappings.fishing or {}
    for _, source in ipairs(StableSort.keys(fishing.global or {})) do
      units[#units + 1] = {
        owner = fishing.global, key = source,
        species = fishing.global[source],
      }
    end
    walk(fishing.slots or {})
    return units
  end

  local function reachableSpecies(mappings)
    local found = {}
    for _, unit in ipairs(wildUnits(mappings)) do addSpecies(found, unit.species) end
    local function walk(value)
      if type(value) ~= "table" then return end
      addSpecies(found, value)
      for _, child in pairs(value) do
        if type(child) == "table" then walk(child) end
      end
    end
    walk(mappings.starters or {})
    walk(mappings.staticEncounters or {})
    walk(mappings.gifts or {})
    walk(mappings.prizes or {})
    return found
  end

  local function countNodes(value, active)
    if type(value) ~= "table" then return 1 end
    active = active or {}
    if active[value] then return 0 end
    active[value] = true
    local count = 1
    for key, child in pairs(value) do
      count = count + countNodes(key, active) + countNodes(child, active)
    end
    active[value] = nil
    return count
  end

  function Validation.apply(mappings, settings, rng)
    assert(type(mappings) == "table", "saved mappings are required")
    assert(type(settings) == "table", "settings are required")
    assert(type(rng) == "table" and type(rng.nextInt) == "function",
      "validation swap RNG is required")
    local result = {
      warnings = {},
      fallbackCount = 0,
      repairSwaps = 0,
      reachableSpecies = 0,
      mappingEntries = countNodes(mappings),
      mappingBytes = #Canonical.encode(mappings),
    }
    local reachable = reachableSpecies(mappings)
    for _ in pairs(reachable) do
      result.reachableSpecies = result.reachableSpecies + 1
    end

    if settings.catchability_guard == "on" then
      local units = wildUnits(mappings)
      for _, tradeId in ipairs(StableSort.keys(mappings.trades or {})) do
        local trade = mappings.trades[tradeId]
        local requested = type(trade) == "table" and trade.requested
        local species = type(requested) == "table" and requested.species
        if type(species) == "string" and not reachable[species] then
          local donors = {}
          for _, unit in ipairs(units) do
            if type(unit.species) == "string"
                and (reachable[unit.species] or 0) > 1 then
              donors[#donors + 1] = unit
            end
          end
          if #donors > 0 then
            local donor = donors[rng:nextInt(1, #donors)]
            local displaced = donor.owner[donor.key]
            donor.owner[donor.key] = species
            requested.species = displaced
            reachable[displaced] = reachable[displaced] - 1
            reachable[species] = 1
            donor.species = species
            result.repairSwaps = result.repairSwaps + 1
            result.warnings[#result.warnings + 1] = {
              code = "TRADE_REACHABILITY_REPAIRED",
              message = "a saved wild destination was swapped with an "
                .. "unreachable requested trade species",
              id = tradeId,
            }
          else
            result.fallbackCount = result.fallbackCount + 1
            result.warnings[#result.warnings + 1] = {
              code = "TRADE_REACHABILITY_UNSATISFIED",
              message = "no duplicate reachable wild destination was "
                .. "available for a safe repair swap",
              id = tradeId,
            }
          end
        end
      end
    end
    return result
  end

  Validation.reachableSpecies = reachableSpecies
  Validation.wildUnits = wildUnits
  return Validation
end
