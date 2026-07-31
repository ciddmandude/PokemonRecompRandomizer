-- Cross-category progression checks and deterministic repair swaps.
return function(StableSort, Canonical, Progression, TradeCatalog)
  local Validation = {}

  local function addUnit(units, owner, key, species, source, access)
    if type(species) == "string" then
      units[#units + 1] = {
        owner = owner, key = key, species = species,
        source = source, access = access,
      }
    end
  end

  local function earliestEncounterAccess(source, encounters, version)
    local best
    for mapId, encounter in pairs(encounters or {}) do
      for _, terrain in ipairs({ "grass", "water" }) do
        local slots = type(encounter) == "table"
          and type(encounter[terrain]) == "table"
          and encounter[terrain].slots or {}
        for _, slot in ipairs(slots or {}) do
          if slot.species == source then
            local access = Progression.access(mapId,
              terrain == "water" and "surf" or "walk", nil, version)
            if access.available and (not best or access.stage < best.stage) then
              best = access
            end
          end
        end
      end
    end
    return best
  end

  local function earliestFishingAccess(source, field, version)
    local best
    local fishing = type(field) == "table" and field.fishing or {}
    for _, rod in ipairs({ "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }) do
      local definition = fishing and fishing[rod]
      local function consider(mapId, slot)
        if type(slot) == "table" and slot.species == source then
          local access = Progression.access(mapId, "fish", rod, version)
          if access.available and (not best or access.stage < best.stage) then
            best = access
          end
        end
      end
      if type(definition) == "table" and type(definition.always) == "table" then
        consider("*", definition.always)
      elseif type(definition) == "table" and type(definition.pool) == "table" then
        for _, slot in ipairs(definition.pool) do consider("*", slot) end
      elseif type(definition) == "table" and type(definition.perMap) == "string" then
        for mapId, slots in pairs(field[definition.perMap] or {}) do
          for _, slot in ipairs(slots or {}) do consider(mapId, slot) end
        end
      end
    end
    return best
  end

  local function wildUnits(mappings, sources)
    sources = sources or {}
    local version = sources.gameVersion or sources.version or "red"
    local units = {}
    for _, source in ipairs(StableSort.keys(mappings.wildGlobal or {})) do
      addUnit(units, mappings.wildGlobal, source, mappings.wildGlobal[source],
        source, earliestEncounterAccess(source, sources.encounters, version))
    end
    for _, mapId in ipairs(StableSort.keys(mappings.wildAreaSlots or {})) do
      local map = mappings.wildAreaSlots[mapId]
      for _, terrain in ipairs({ "grass", "water" }) do
        local slots = type(map) == "table" and map[terrain] or {}
        local access = Progression.access(mapId,
          terrain == "water" and "surf" or "walk", nil, version)
        for _, index in ipairs(StableSort.keys(slots or {})) do
          local record = slots[index]
          if type(record) == "table" then
            local encounter = type(sources.encounters) == "table"
              and sources.encounters[mapId]
            local sourceSlots = type(encounter) == "table"
              and type(encounter[terrain]) == "table"
              and encounter[terrain].slots
            local source = type(sourceSlots) == "table"
              and sourceSlots[index]
            addUnit(units, record, "species", record.species,
              type(source) == "table" and source.species, access)
          end
        end
      end
    end
    local fishing = mappings.fishing or {}
    for _, source in ipairs(StableSort.keys(fishing.global or {})) do
      addUnit(units, fishing.global, source, fishing.global[source],
        source, earliestFishingAccess(source, sources.field, version))
    end
    for _, rod in ipairs(StableSort.keys(fishing.slots or {})) do
      for _, mapId in ipairs(StableSort.keys(fishing.slots[rod] or {})) do
        local access = Progression.access(mapId, "fish", rod, version)
        for _, index in ipairs(StableSort.keys(fishing.slots[rod][mapId] or {})) do
          local record = fishing.slots[rod][mapId][index]
          if type(record) == "table" then
            addUnit(units, record, "species", record.species, nil, access)
          end
        end
      end
    end
    return units
  end

  local function mergeEarliest(found, species, stage)
    if type(species) == "string" and stage ~= nil
        and (found[species] == nil or stage < found[species]) then
      found[species] = stage
    end
  end

  local function earliestSpecies(mappings, sources)
    sources = sources or {}
    local found = {}
    local version = sources.gameVersion or sources.version or "red"
    for _, unit in ipairs(wildUnits(mappings, sources)) do
      if unit.access and unit.access.available then
        mergeEarliest(found, unit.species, unit.access.stage)
      end
    end
    for _, row in pairs(mappings.starters or {}) do
      mergeEarliest(found, type(row) == "table" and row.species or row,
        Progression.STAGES.START)
    end
    for _, category in ipairs({
      mappings.staticEncounters or {}, mappings.gifts or {},
    }) do
      for _, row in pairs(category) do
        if type(row) == "table" then
          local access = Progression.access(row.mapId, "walk", nil, version)
          if access.available then
            mergeEarliest(found, row.species, access.stage)
          end
        end
      end
    end
    for _, row in pairs(mappings.prizes or {}) do
      if type(row) == "table" then
        mergeEarliest(found, row.species, Progression.STAGES.LAVENDER_CELADON)
      end
    end
    return found
  end

  local function countsAt(units, stage)
    local counts = {}
    for _, unit in ipairs(units) do
      if Progression.isAvailableAt(unit.access, stage) then
        counts[unit.species] = (counts[unit.species] or 0) + 1
      end
    end
    return counts
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

  local function tradeRecord(id, version)
    for _, record in ipairs(TradeCatalog.tradesFor(version)) do
      if record.id == id then return record end
    end
    return nil
  end

  local function repairCompatible(
      sourceId, destinationId, manifest, strengthMode)
    if strengthMode ~= "same_stage"
        and strengthMode ~= "bst_50"
        and strengthMode ~= "bst_100" then return true end
    local source = type(manifest) == "table"
      and type(manifest.byId) == "table" and manifest.byId[sourceId]
    local destination = type(manifest) == "table"
      and type(manifest.byId) == "table" and manifest.byId[destinationId]
    if not source or not destination then return false end
    if strengthMode == "same_stage" then
      return source.stage == destination.stage
    end
    local points = strengthMode == "bst_50" and 50 or 100
    return math.abs(source.bst - destination.bst) <= points
  end

  function Validation.apply(mappings, settings, rng, context)
    assert(type(mappings) == "table", "saved mappings are required")
    assert(type(settings) == "table", "settings are required")
    assert(type(rng) == "table" and type(rng.nextInt) == "function",
      "validation swap RNG is required")
    context = context or {}
    local sources = context.sources or {}
    local manifest = context.manifest
    local result = {
      warnings = {}, fallbackCount = 0, repairSwaps = 0,
      reachableSpecies = 0,
      mappingEntries = countNodes(mappings),
      mappingBytes = #Canonical.encode(mappings),
    }
    local earliest = earliestSpecies(mappings, sources)
    for _, stage in pairs(earliest) do
      if stage <= Progression.PRE_ELITE_FOUR_MAX then
        result.reachableSpecies = result.reachableSpecies + 1
      end
    end

    if settings.catchability_guard == "on" then
      local units = wildUnits(mappings, sources)
      for _, tradeId in ipairs(StableSort.keys(mappings.trades or {})) do
        local trade = mappings.trades[tradeId]
        local requested = type(trade) == "table" and trade.requested
        local species = type(requested) == "table" and requested.species
        local record = tradeRecord(tradeId,
          sources.gameVersion or sources.version)
        local access = Progression.tradeAccess(record,
          sources.gameVersion or sources.version)
        local obtainable = type(species) == "string"
          and access.available
          and earliest[species] ~= nil
          and earliest[species] <= access.stage
        if type(species) == "string" and not obtainable then
          local counts = access.available and countsAt(units, access.stage) or {}
          local donors = {}
          for _, unit in ipairs(units) do
            local displaced = unit.owner[unit.key]
            local compatible = repairCompatible(
                unit.source, species, manifest, settings.similar_strength)
              and repairCompatible(
                requested.sourceSpecies, displaced,
                manifest, settings.similar_strength)
            if Progression.isAvailableAt(unit.access, access.stage)
                and compatible
                and (counts[unit.species] or 0) > 1 then
              donors[#donors + 1] = unit
            end
          end
          if #donors > 0 then
            local donor = donors[rng:nextInt(1, #donors)]
            local displaced = donor.owner[donor.key]
            donor.owner[donor.key] = species
            requested.species = displaced
            donor.species = species
            earliest = earliestSpecies(mappings, sources)
            result.repairSwaps = result.repairSwaps + 1
            result.warnings[#result.warnings + 1] = {
              code = "TRADE_REACHABILITY_REPAIRED",
              message = "requested species was placed in an encounter "
                .. "available before this trade",
              id = tradeId, mapId = record and record.mapId,
              location = access.locationName,
              stage = access.stage, stageName = access.stageName,
            }
          else
            result.fallbackCount = result.fallbackCount + 1
            result.warnings[#result.warnings + 1] = {
              code = "TRADE_REACHABILITY_UNSATISFIED",
              message = "no duplicate wild destination obtainable before "
                .. "this trade was available for a safe repair",
              id = tradeId, mapId = record and record.mapId,
              location = access and access.locationName,
              stage = access and access.stage,
              stageName = access and access.stageName,
            }
          end
        end
      end
    end
    result.mappingBytes = #Canonical.encode(mappings)
    return result
  end

  Validation.earliestSpecies = earliestSpecies
  Validation.reachableSpecies = earliestSpecies
  Validation.wildUnits = wildUnits
  return Validation
end
