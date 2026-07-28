-- Milestone-8 generation for area slots, fishing, levels, and coverage.
return function(StableSort, SpeciesFilters, WildGlobal)
  local WildCategory = {}
  local TERRAIN_ORDER = { "grass", "water" }
  local ROD_ORDER = { "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }

  local function rules(settings, excluded)
    return {
      strengthPercent = tonumber(settings.similar_strength),
      legendary = settings.legendaries or "allow",
      excludeIds = excluded,
    }
  end

  local function choose(manifest, source, settings, rng, used)
    local unique = settings.duplicate_policy == "one_to_one"
    local candidates, diagnostics = SpeciesFilters.candidates(
      manifest, source, rules(settings, unique and used or nil))
    local reset = false
    if #candidates == 0 and unique and manifest.byId[source] then
      candidates, diagnostics = SpeciesFilters.candidates(
        manifest, source, rules(settings, nil))
      reset = #candidates > 0
      if reset then
        for id in pairs(used) do used[id] = nil end
      end
    end
    if #candidates == 0 then return nil, diagnostics, false end
    local destination = candidates[rng:nextInt(1, #candidates)].id
    if unique then used[destination] = true end
    return destination, diagnostics, reset
  end

  local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
  end

  local function levelFor(source, destination, level, settings, manifest, rng)
    if settings.wild_levels == "plus_minus_2" then
      return clamp(level + rng:nextInt(-2, 2), 2, 100)
    end
    if settings.wild_levels == "scaled" then
      local from, to = manifest.byId[source], manifest.byId[destination]
      if from and to and to.bst > 0 then
        return clamp(math.floor(
          level * math.sqrt(from.bst / to.bst) + 0.5), 2, 100)
      end
    end
    return level
  end

  local function isReachable(mapId)
    if mapId == "*" then return true end
    return not (mapId:match("^CERULEAN_CAVE")
      or mapId:match("^UNKNOWN_DUNGEON"))
  end

  local function addWarning(result, code, message, details)
    local row = { code = code, message = message }
    for key, value in pairs(details or {}) do row[key] = value end
    result.warnings[#result.warnings + 1] = row
  end

  local function ensurePath(root, first, second)
    root[first] = root[first] or {}
    if second == nil then return root[first] end
    root[first][second] = root[first][second] or {}
    return root[first][second]
  end

  local function encounterSlots(encounters)
    local rows = {}
    if type(encounters) ~= "table" then return rows, false end
    for _, mapId in ipairs(StableSort.keys(encounters)) do
      local encounter = encounters[mapId]
      for _, terrain in ipairs(TERRAIN_ORDER) do
        local definition = type(encounter) == "table" and encounter[terrain]
        local slots = type(definition) == "table"
            and type(definition.slots) == "table"
            and definition.slots or {}
        local identities = {}
        for _, slot in ipairs(slots) do
          local key = tostring(slot.species) .. "\0" .. tostring(slot.level)
          identities[key] = (identities[key] or 0) + 1
        end
        for index, slot in ipairs(slots) do
          if type(slot) == "table" and type(slot.species) == "string"
              and type(slot.level) == "number" then
            local key = slot.species .. "\0" .. tostring(slot.level)
            rows[#rows + 1] = {
              mapId = mapId,
              terrain = terrain,
              index = index,
              source = slot.species,
              level = slot.level,
              reachable = isReachable(mapId),
              identifiable = identities[key] == 1,
            }
          end
        end
      end
    end
    return rows, true
  end

  local function fishingSlots(field)
    local rows = {}
    if type(field) ~= "table" or type(field.fishing) ~= "table" then
      return rows, false
    end
    for _, rod in ipairs(ROD_ORDER) do
      local definition = field.fishing[rod]
      if type(definition) == "table" then
        if type(definition.always) == "table" then
          rows[#rows + 1] = {
            rod = rod, mapId = "*", index = 1,
            source = definition.always.species,
            level = definition.always.level,
            reachable = true,
          }
        elseif type(definition.pool) == "table" then
          local identities = {}
          for _, slot in ipairs(definition.pool) do
            local key = tostring(slot.species) .. "\0" .. tostring(slot.level)
            identities[key] = (identities[key] or 0) + 1
          end
          for index, slot in ipairs(definition.pool) do
            local key = tostring(slot.species) .. "\0" .. tostring(slot.level)
            rows[#rows + 1] = {
              rod = rod, mapId = "*", index = index,
              source = slot.species, level = slot.level, reachable = true,
              identifiable = identities[key] == 1,
            }
          end
        elseif type(definition.perMap) == "string" then
          local groups = field[definition.perMap]
          for _, mapId in ipairs(StableSort.keys(groups or {})) do
            local group = groups[mapId] or {}
            local identities = {}
            for _, slot in ipairs(group) do
              local key = tostring(slot.species) .. "\0" .. tostring(slot.level)
              identities[key] = (identities[key] or 0) + 1
            end
            for index, slot in ipairs(group) do
              local key = tostring(slot.species) .. "\0" .. tostring(slot.level)
              rows[#rows + 1] = {
                rod = rod, mapId = mapId, index = index,
                source = slot.species, level = slot.level,
                reachable = isReachable(mapId),
                identifiable = identities[key] == 1,
              }
            end
          end
        end
      end
    end
    return rows, true
  end

  local function repairCoverage(occurrences, manifest, result)
    local reachableCounts, totalCounts = {}, {}
    for _, row in ipairs(occurrences) do
      local id = row.record.species
      local entry = manifest.byId[id]
      if entry and not entry.legendary then
        totalCounts[id] = (totalCounts[id] or 0) + 1
        if row.reachable then
          reachableCounts[id] = (reachableCounts[id] or 0) + 1
        end
      end
    end

    for _, missing in ipairs(StableSort.keys(totalCounts)) do
      if not reachableCounts[missing] then
        local target
        for _, row in ipairs(occurrences) do
          if row.record.species == missing and not row.reachable then
            target = row
            break
          end
        end
        local donor
        for _, row in ipairs(occurrences) do
          local id = row.record.species
          local entry = manifest.byId[id]
          if row.reachable and entry and not entry.legendary
              and (reachableCounts[id] or 0) > 1 then
            donor = row
            break
          end
        end
        if target and donor then
          local donorId = donor.record.species
          target.record.species, donor.record.species =
            donor.record.species, target.record.species
          reachableCounts[donorId] = reachableCounts[donorId] - 1
          reachableCounts[missing] = 1
          result.coverageSwaps = result.coverageSwaps + 1
        else
          addWarning(result, "WILD_COVERAGE_UNSATISFIED",
            "a generated destination cannot be moved before the Elite Four",
            { species = missing })
          result.fallbackCount = result.fallbackCount + 1
        end
      end
    end
  end

  local function repairGlobalCoverage(units, manifest, result)
    local reachableCounts, totalCounts = {}, {}
    for _, unit in ipairs(units) do
      local id = unit.mapping[unit.key]
      local entry = manifest.byId[id]
      if entry and not entry.legendary then
        totalCounts[id] = (totalCounts[id] or 0) + 1
        if unit.reachable then
          reachableCounts[id] = (reachableCounts[id] or 0) + 1
        end
      end
    end
    for _, missing in ipairs(StableSort.keys(totalCounts)) do
      if not reachableCounts[missing] then
        local target
        for _, unit in ipairs(units) do
          if unit.mapping[unit.key] == missing and not unit.reachable then
            target = unit
            break
          end
        end
        local donor
        for _, unit in ipairs(units) do
          local id = unit.mapping[unit.key]
          local entry = manifest.byId[id]
          if unit.reachable and entry and not entry.legendary
              and (reachableCounts[id] or 0) > 1 then
            donor = unit
            break
          end
        end
        if target and donor then
          local donorId = donor.mapping[donor.key]
          target.mapping[target.key], donor.mapping[donor.key] =
            donor.mapping[donor.key], target.mapping[target.key]
          reachableCounts[donorId] = reachableCounts[donorId] - 1
          reachableCounts[missing] = 1
          result.coverageSwaps = result.coverageSwaps + 1
        else
          addWarning(result, "WILD_COVERAGE_UNSATISFIED",
            "a generated destination cannot be moved before the Elite Four",
            { species = missing })
          result.fallbackCount = result.fallbackCount + 1
        end
      end
    end
  end

  function WildCategory.generate(manifest, sources, settings, streams)
    local result = {
      wildGlobal = {},
      wildAreaSlots = {},
      fishing = {},
      warnings = {},
      fallbackCount = 0,
      coverageSwaps = 0,
    }
    if settings.wild_pokemon == "off" then return result end

    local encounterRows, encountersAvailable =
      encounterSlots(sources and sources.encounters)
    if not encountersAvailable then
      addWarning(result, "WILD_SOURCE_UNAVAILABLE",
        "merged encounter registry is unavailable; wild encounters are vanilla")
      result.fallbackCount = result.fallbackCount + 1
      return result
    end

    local occurrences = {}
    local globalUnits = {}
    local areaUsed = {}
    if settings.wild_pokemon == "global_map" then
      local global = WildGlobal.generate(
        manifest, sources.encounters, settings, streams.global)
      result.wildGlobal = global.mapping
      result.fallbackCount = result.fallbackCount + global.fallbackCount
      for _, row in ipairs(global.warnings) do
        result.warnings[#result.warnings + 1] = row
      end
      local reachableBySource = {}
      for _, slot in ipairs(encounterRows) do
        reachableBySource[slot.source] =
          reachableBySource[slot.source] or slot.reachable
      end
      for _, source in ipairs(StableSort.keys(result.wildGlobal)) do
        globalUnits[#globalUnits + 1] = {
          mapping = result.wildGlobal,
          key = source,
          reachable = reachableBySource[source] == true,
        }
      end
      for _, slot in ipairs(encounterRows) do
        local destination = result.wildGlobal[slot.source]
        if destination then
          if settings.wild_levels ~= "unchanged" and slot.identifiable then
            local record = {
              level = levelFor(slot.source, destination, slot.level,
                settings, manifest, streams.levels),
            }
            ensurePath(result.wildAreaSlots,
              slot.mapId, slot.terrain)[slot.index] = record
          elseif settings.wild_levels ~= "unchanged" then
            addWarning(result, "WILD_SLOT_IDENTITY_AMBIGUOUS",
              "duplicate source species and level prevent saved level lookup",
              { mapId = slot.mapId, terrain = slot.terrain, slot = slot.index })
            result.fallbackCount = result.fallbackCount + 1
          end
          occurrences[#occurrences + 1] = {
            record = { species = destination },
            reachable = slot.reachable,
          }
        end
      end
    else
      for _, slot in ipairs(encounterRows) do
        local destination, diagnostics, reset
        if slot.identifiable then
          destination, diagnostics, reset = choose(
            manifest, slot.source, settings, streams.area, areaUsed)
        else
          diagnostics = {
            error = {
              code = "SLOT_IDENTITY_AMBIGUOUS",
              message =
                "duplicate source species and level prevent stable slot lookup",
            },
          }
        end
        if reset then
          addWarning(result, "WILD_UNIQUENESS_POOL_RESET",
            "eligible destinations were exhausted; uniqueness pool restarted")
        end
        if destination then
          local record = {
            species = destination,
            level = levelFor(slot.source, destination, slot.level,
              settings, manifest, streams.levels),
          }
          ensurePath(result.wildAreaSlots,
            slot.mapId, slot.terrain)[slot.index] = record
          occurrences[#occurrences + 1] = {
            record = record, reachable = slot.reachable,
          }
        else
          addWarning(result, "WILD_"
              .. (diagnostics.error and diagnostics.error.code
                or "NO_CANDIDATES"),
            diagnostics.error and diagnostics.error.message
              or "wild slot has no eligible destination",
            { mapId = slot.mapId, terrain = slot.terrain, slot = slot.index })
          result.fallbackCount = result.fallbackCount + 1
        end
      end
    end

    local fishRows = {}
    if settings.fishing == "randomized" then
      local fishingAvailable
      fishRows, fishingAvailable = fishingSlots(sources and sources.field)
      if not fishingAvailable then
        addWarning(result, "FISHING_SOURCE_UNAVAILABLE",
          "merged fishing registry is unavailable; fishing is vanilla")
        result.fallbackCount = result.fallbackCount + 1
      else
        result.fishing = { global = {}, slots = {} }
        local fishUsed = {}
        for _, slot in ipairs(fishRows) do
          local destination, diagnostics, reset
          if settings.wild_pokemon == "global_map" then
            destination = result.fishing.global[slot.source]
            if not destination then
              destination, diagnostics, reset = choose(
                manifest, slot.source, settings, streams.global, fishUsed)
              if destination then
                result.fishing.global[slot.source] = destination
              end
            end
          else
            destination, diagnostics, reset = choose(
              manifest, slot.source, settings, streams.area, areaUsed)
          end
          if reset then
            addWarning(result, "FISHING_UNIQUENESS_POOL_RESET",
              "eligible fishing destinations were exhausted; pool restarted")
          end
          if destination and (settings.wild_pokemon == "global_map"
              or slot.identifiable ~= false) then
            local record = {
              level = levelFor(slot.source, destination, slot.level,
                settings, manifest, streams.levels),
            }
            if settings.wild_pokemon == "area_slots" then
              record.species = destination
            end
            if settings.wild_pokemon == "area_slots"
                or settings.wild_levels ~= "unchanged" then
              if slot.identifiable == false then
                addWarning(result, "FISHING_SLOT_IDENTITY_AMBIGUOUS",
                  "duplicate fishing candidates prevent saved level lookup",
                  { rod = slot.rod, mapId = slot.mapId, slot = slot.index })
                result.fallbackCount = result.fallbackCount + 1
              else
                ensurePath(result.fishing.slots,
                  slot.rod, slot.mapId)[slot.index] = record
              end
            end
            occurrences[#occurrences + 1] = {
              record = settings.wild_pokemon == "area_slots"
                  and record or { species = destination },
              reachable = slot.reachable,
            }
          else
            result.fallbackCount = result.fallbackCount + 1
            addWarning(result,
              slot.identifiable == false
                  and "FISHING_SLOT_IDENTITY_AMBIGUOUS"
                or "FISHING_NO_CANDIDATES",
              slot.identifiable == false
                  and "duplicate fishing candidates prevent stable slot lookup"
                or diagnostics and diagnostics.error
                  and diagnostics.error.message
                or "fishing slot has no eligible destination",
              { rod = slot.rod, mapId = slot.mapId, slot = slot.index })
          end
        end
        if settings.wild_pokemon == "global_map" then
          local reachableBySource = {}
          for _, slot in ipairs(fishRows) do
            reachableBySource[slot.source] =
              reachableBySource[slot.source] or slot.reachable
          end
          for _, source in ipairs(StableSort.keys(result.fishing.global)) do
            globalUnits[#globalUnits + 1] = {
              mapping = result.fishing.global,
              key = source,
              reachable = reachableBySource[source] == true,
            }
          end
        end
      end
    end

    if settings.catchability_guard == "on" then
      if settings.wild_pokemon == "area_slots" then
        repairCoverage(occurrences, manifest, result)
      else
        repairGlobalCoverage(globalUnits, manifest, result)
      end
      if settings.wild_levels == "scaled" then
        for _, slot in ipairs(encounterRows) do
          local record = result.wildAreaSlots[slot.mapId]
          record = type(record) == "table" and record[slot.terrain]
          record = type(record) == "table" and record[slot.index]
          local destination = settings.wild_pokemon == "global_map"
              and result.wildGlobal[slot.source]
            or type(record) == "table" and record.species
          if type(record) == "table" and destination then
            record.level = levelFor(slot.source, destination, slot.level,
              settings, manifest, streams.levels)
          end
        end
        for _, slot in ipairs(fishRows) do
          local records = result.fishing.slots
          records = type(records) == "table" and records[slot.rod]
          records = type(records) == "table" and records[slot.mapId]
          local record = type(records) == "table" and records[slot.index]
          local destination = settings.wild_pokemon == "global_map"
              and result.fishing.global[slot.source]
            or type(record) == "table" and record.species
          if type(record) == "table" and destination then
            record.level = levelFor(slot.source, destination, slot.level,
              settings, manifest, streams.levels)
          end
        end
      end
    end
    return result
  end

  WildCategory.encounterSlots = encounterSlots
  WildCategory.fishingSlots = fishingSlots
  WildCategory.isReachable = isReachable
  WildCategory.repairCoverage = repairCoverage
  WildCategory.repairGlobalCoverage = repairGlobalCoverage
  return WildCategory
end
