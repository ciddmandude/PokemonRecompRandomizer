-- Milestone-8 generation for area slots, fishing, levels, and coverage.
return function(StableSort, SpeciesFilters, WildGlobal, Matching, Progression)
  local WildCategory = {}
  local TERRAIN_ORDER = { "grass", "water" }
  local ROD_ORDER = { "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }

  local function rules(settings, excluded)
    return {
      strengthPercent = tonumber(settings.similar_strength),
      strengthPoints = settings.similar_strength == "bst_50" and 50
        or settings.similar_strength == "bst_100" and 100 or nil,
      sameStage = settings.similar_strength == "same_stage",
      legendary = settings.legendaries or "allow",
      excludeIds = excluded,
    }
  end

  local function matchRows(manifest, rows, settings, rng, category, code, idFor)
    local units = {}
    for index, row in ipairs(rows) do
      local candidates, diagnostics = SpeciesFilters.candidates(
        manifest, row.source, rules(settings, nil))
      units[#units + 1] = {
        id = idFor and idFor(row, index) or tostring(index),
        source = row.source,
        candidates = candidates,
        diagnostics = diagnostics,
        hardConstraints = {
          similarStrength = tonumber(settings.similar_strength),
          baseStatRange = settings.similar_strength == "bst_50" and 50
            or settings.similar_strength == "bst_100" and 100 or nil,
          sameStage = settings.similar_strength == "same_stage",
          legendary = settings.legendaries or "allow",
        },
      }
    end
    if settings.duplicate_policy == "one_to_one" then
      return Matching.assign(units, rng, {
        category = category, code = code,
      }), units
    end
    local output = { assignments = {}, resets = {}, unmatched = {} }
    for _, unit in ipairs(units) do
      if #unit.candidates == 0 then
        output.unmatched[#output.unmatched + 1] = unit
      else
        output.assignments[unit.id] =
          unit.candidates[rng:nextInt(1, #unit.candidates)].id
      end
    end
    return output, units
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

  local function accessFor(mapId, terrain, rod, version)
    local method = rod and "fish"
      or terrain == "water" and "surf" or "walk"
    return Progression.access(mapId, method, rod, version)
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

  local function encounterSlots(encounters, version)
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
            local access = accessFor(mapId, terrain, nil, version)
            rows[#rows + 1] = {
              mapId = mapId,
              terrain = terrain,
              index = index,
              source = slot.species,
              level = slot.level,
              access = access,
              reachable = Progression.isPreEliteFour(access),
              identifiable = identities[key] == 1,
            }
          end
        end
      end
    end
    return rows, true
  end

  local function fishingSlots(field, version)
    local rows = {}
    if type(field) ~= "table" or type(field.fishing) ~= "table" then
      return rows, false
    end
    for _, rod in ipairs(ROD_ORDER) do
      local definition = field.fishing[rod]
      if type(definition) == "table" then
        if type(definition.always) == "table" then
          local access = accessFor("*", nil, rod, version)
          rows[#rows + 1] = {
            rod = rod, mapId = "*", index = 1,
            source = definition.always.species,
            level = definition.always.level,
            access = access,
            reachable = Progression.isPreEliteFour(access),
          }
        elseif type(definition.pool) == "table" then
          local identities = {}
          for _, slot in ipairs(definition.pool) do
            local key = tostring(slot.species) .. "\0" .. tostring(slot.level)
            identities[key] = (identities[key] or 0) + 1
          end
          for index, slot in ipairs(definition.pool) do
            local key = tostring(slot.species) .. "\0" .. tostring(slot.level)
            local access = accessFor("*", nil, rod, version)
            rows[#rows + 1] = {
              rod = rod, mapId = "*", index = index,
              source = slot.species, level = slot.level,
              access = access,
              reachable = Progression.isPreEliteFour(access),
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
              local access = accessFor(mapId, nil, rod, version)
              rows[#rows + 1] = {
                rod = rod, mapId = mapId, index = index,
                source = slot.species, level = slot.level,
                access = access,
                reachable = Progression.isPreEliteFour(access),
                identifiable = identities[key] == 1,
              }
            end
          end
        end
      end
    end
    return rows, true
  end

  local function repairCompatible(sourceId, destinationId, manifest, mode)
    if mode == nil or mode == false
        or (mode ~= true and mode ~= "same_stage"
          and mode ~= "bst_50" and mode ~= "bst_100") then
      return true
    end
    local source = manifest.byId[sourceId]
    local destination = manifest.byId[destinationId]
    if not source or not destination then return false end
    if mode == true or mode == "same_stage" then
      return source.stage == destination.stage
    end
    local points = mode == "bst_50" and 50 or 100
    return math.abs(source.bst - destination.bst) <= points
  end

  local function repairCoverage(
      occurrences, manifest, result, strengthMode)
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
        local missingEntry = manifest.byId[missing]
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
              and (strengthMode ~= true
                or (missingEntry and entry.stage == missingEntry.stage))
              and repairCompatible(
                row.source, missing, manifest, strengthMode)
              and repairCompatible(
                target and target.source, id, manifest, strengthMode)
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

  local function repairGlobalCoverage(
      units, manifest, result, strengthMode)
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
        local missingEntry = manifest.byId[missing]
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
              and (strengthMode ~= true
                or (missingEntry and entry.stage == missingEntry.stage))
              and repairCompatible(
                unit.source, missing, manifest, strengthMode)
              and repairCompatible(
                target and target.source, id, manifest, strengthMode)
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
      reachability = { earliestBySpecies = {}, unknownLocations = {} },
    }
    if settings.wild_pokemon == "off" then return result end

    local version = sources and (sources.gameVersion or sources.version) or "red"
    local encounterRows, encountersAvailable =
      encounterSlots(sources and sources.encounters, version)
    if not encountersAvailable then
      addWarning(result, "WILD_SOURCE_UNAVAILABLE",
        "merged encounter registry is unavailable; wild encounters are vanilla")
      result.fallbackCount = result.fallbackCount + 1
      return result
    end

    local fishRows, fishingAvailable = {}, false
    if settings.fishing == "randomized" then
      fishRows, fishingAvailable = fishingSlots(sources and sources.field, version)
    end
    local occurrences = {}
    local globalUnits = {}
    local areaMatch, areaUnitById
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
          source = source,
          reachable = reachableBySource[source] == true,
        }
      end
      for _, slot in ipairs(encounterRows) do
        local destination = result.wildGlobal[slot.source]
        if destination then
          if settings.wild_levels ~= "unchanged" then
            local record = {
              level = levelFor(slot.source, destination, slot.level,
                settings, manifest, streams.levels),
            }
            ensurePath(result.wildAreaSlots,
              slot.mapId, slot.terrain)[slot.index] = record
          end
          occurrences[#occurrences + 1] = {
            record = { species = destination },
            source = slot.source,
            reachable = slot.reachable,
            access = slot.access,
          }
        end
      end
    else
      local combined = {}
      for _, slot in ipairs(encounterRows) do
        slot.matchId =
          "W:" .. slot.mapId .. ":" .. slot.terrain .. ":" .. slot.index
        combined[#combined + 1] = slot
      end
      if fishingAvailable then
        for _, slot in ipairs(fishRows) do
          slot.matchId =
            "F:" .. slot.rod .. ":" .. slot.mapId .. ":" .. slot.index
          combined[#combined + 1] = slot
        end
      end
      local areaUnits
      areaMatch, areaUnits = matchRows(
        manifest, combined, settings, streams.area, "wild.area_and_fishing",
        "WILD_UNIQUENESS_POOL_RESET", function(slot) return slot.matchId end)
      areaUnitById = {}
      for _, unit in ipairs(areaUnits) do areaUnitById[unit.id] = unit end
      for _, reset in ipairs(areaMatch.resets) do
        result.warnings[#result.warnings + 1] = Matching.warning(reset)
      end
      for _, slot in ipairs(encounterRows) do
        local unit = areaUnitById[slot.matchId]
        local destination = areaMatch.assignments[unit.id]
        local diagnostics = unit.diagnostics
        if destination then
          local record = {
            species = destination,
            level = levelFor(slot.source, destination, slot.level,
              settings, manifest, streams.levels),
          }
          ensurePath(result.wildAreaSlots,
            slot.mapId, slot.terrain)[slot.index] = record
          occurrences[#occurrences + 1] = {
            record = record, source = slot.source,
            reachable = slot.reachable, access = slot.access,
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

    if settings.fishing == "randomized" then
      if not fishingAvailable then
        addWarning(result, "FISHING_SOURCE_UNAVAILABLE",
          "merged fishing registry is unavailable; fishing is vanilla")
        result.fallbackCount = result.fallbackCount + 1
      else
        result.fishing = { global = {}, slots = {} }
        local fishMatch, fishUnits
        if settings.wild_pokemon == "global_map" then
          local uniqueRows, seen = {}, {}
          for _, slot in ipairs(fishRows) do
            if not seen[slot.source] then
              seen[slot.source] = true
              uniqueRows[#uniqueRows + 1] = slot
            end
          end
          fishMatch, fishUnits = matchRows(
            manifest, uniqueRows, settings, streams.global, "fishing.global",
            "FISHING_UNIQUENESS_POOL_RESET", function(slot)
              return slot.source
            end)
          for _, unit in ipairs(fishUnits) do
            result.fishing.global[unit.source] =
              fishMatch.assignments[unit.id]
          end
        else
          fishMatch, fishUnits = areaMatch, {}
          for _, slot in ipairs(fishRows) do
            fishUnits[#fishUnits + 1] = areaUnitById[slot.matchId]
          end
        end
        if settings.wild_pokemon == "global_map" then
          for _, reset in ipairs(fishMatch.resets) do
            result.warnings[#result.warnings + 1] = Matching.warning(reset,
              "eligible fishing destinations were proven exhausted; pool restarted")
          end
        end
        for index, slot in ipairs(fishRows) do
          local destination, diagnostics
          if settings.wild_pokemon == "global_map" then
            destination = result.fishing.global[slot.source]
            for _, unit in ipairs(fishUnits) do
              if unit.source == slot.source then
                diagnostics = unit.diagnostics
                break
              end
            end
          else
            local unit = fishUnits[index]
            destination = fishMatch.assignments[unit.id]
            diagnostics = unit.diagnostics
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
              source = slot.source,
              reachable = slot.reachable,
              access = slot.access,
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
              source = source,
              reachable = reachableBySource[source] == true,
            }
          end
        end
      end
    end

    if settings.catchability_guard == "on" then
      local strengthMode = settings.similar_strength
      if settings.wild_pokemon == "area_slots" then
        repairCoverage(occurrences, manifest, result, strengthMode)
      else
        repairGlobalCoverage(globalUnits, manifest, result, strengthMode)
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

    local finalReachabilityRows = {}
    for _, slot in ipairs(encounterRows) do
      local species
      if settings.wild_pokemon == "global_map" then
        species = result.wildGlobal[slot.source]
      else
        local record = result.wildAreaSlots[slot.mapId]
        record = type(record) == "table" and record[slot.terrain]
        record = type(record) == "table" and record[slot.index]
        species = type(record) == "table" and record.species
      end
      finalReachabilityRows[#finalReachabilityRows + 1] = {
        species = species, access = slot.access,
      }
    end
    for _, slot in ipairs(fishRows) do
      local species
      if settings.wild_pokemon == "global_map" then
        species = type(result.fishing) == "table"
          and type(result.fishing.global) == "table"
          and result.fishing.global[slot.source]
      else
        local record = type(result.fishing) == "table" and result.fishing.slots
        record = type(record) == "table" and record[slot.rod]
        record = type(record) == "table" and record[slot.mapId]
        record = type(record) == "table" and record[slot.index]
        species = type(record) == "table" and record.species
      end
      finalReachabilityRows[#finalReachabilityRows + 1] = {
        species = species, access = slot.access,
      }
    end
    for _, row in ipairs(finalReachabilityRows) do
      local species = row.species
      local access = row.access
      if type(species) == "string" and access and access.available then
        local previous = result.reachability.earliestBySpecies[species]
        if previous == nil or access.stage < previous then
          result.reachability.earliestBySpecies[species] = access.stage
        end
      elseif access and not access.known then
        result.reachability.unknownLocations[access.mapId] = true
      end
    end
    for _, mapId in ipairs(StableSort.keys(result.reachability.unknownLocations)) do
      addWarning(result, "PROGRESSION_MAP_UNKNOWN",
        "encounters on this map are excluded from catchability guarantees "
          .. "because its access requirements are unknown",
        { mapId = mapId, location = Progression.locationName(mapId) })
    end
    return result
  end

  WildCategory.encounterSlots = encounterSlots
  WildCategory.fishingSlots = fishingSlots
  WildCategory.accessFor = accessFor
  WildCategory.repairCoverage = repairCoverage
  WildCategory.repairGlobalCoverage = repairGlobalCoverage
  return WildCategory
end
