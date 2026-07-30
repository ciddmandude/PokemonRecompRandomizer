-- Deterministic generation for the explicitly scoped mod-only M11 catalog.
return function(StableSort, SpeciesFilters, Catalog, Matching)
  local Category = {}

  local function rules(settings, excluded)
    return {
      strengthPercent = tonumber(settings.similar_strength),
      legendary = settings.legendaries or "allow",
      excludeIds = excluded,
    }
  end

  local function assignments(
      records, manifest, settings, rng, unique, category, code)
    local units = {}
    for _, record in ipairs(records) do
      local candidates, diagnostics = SpeciesFilters.candidates(
        manifest, record.species, rules(settings, nil))
      units[#units + 1] = {
        id = record.id, source = record.species,
        candidates = candidates, diagnostics = diagnostics,
        hardConstraints = {
          similarStrength = tonumber(settings.similar_strength),
          legendary = settings.legendaries or "allow",
        },
      }
    end
    if unique then
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

  local function scaledLevel(record, species, manifest)
    local source = manifest.byId[record.species]
    local destination = manifest.byId[species]
    if not source or not destination or destination.bst <= 0 then
      return record.level
    end
    return clamp(math.floor(
      record.level * math.sqrt(source.bst / destination.bst) + 0.5),
      2, 100)
  end

  local function staticLevel(record, species, settings, manifest, rng)
    if settings.static_levels == "random_5" then
      return clamp(record.level + rng:nextInt(-5, 5), 2, 100)
    end
    if settings.static_levels == "scaled" then
      return scaledLevel(record, species, manifest)
    end
    return record.level
  end

  local function giftLevel(record, species, settings, manifest)
    if settings.gift_levels == "fixed_15" then return 15 end
    if settings.gift_levels == "scaled" then
      return scaledLevel(record, species, manifest)
    end
    return record.level
  end

  local function warning(code, message, id)
    return { code = code, message = message, id = id }
  end

  local function generateStatics(manifest, settings, rngs)
    if settings.static_pokemon == nil or settings.static_pokemon == "off" then
      return {}, {}, 0
    end
    local mappings, warnings = {}, {}
    local unique = settings.duplicate_policy == "one_to_one"
    local matched = assignments(Catalog.statics, manifest, settings,
      rngs.species, unique, "static.encounters",
      "STATIC_UNIQUENESS_EXHAUSTED")
    if #matched.unmatched > 0 then
      return {}, {
        warning("STATIC_GENERATION_FAILED",
          "a scoped static encounter has no valid candidate; statics are vanilla",
          matched.unmatched[1].id),
      }, 1
    end
    for _, reset in ipairs(matched.resets) do
      warnings[#warnings + 1] = Matching.warning(reset,
        "static destination pool was proven exhausted and restarted")
    end
    for _, record in ipairs(Catalog.statics) do
      local species = matched.assignments[record.id]
      mappings[record.id] = {
        encounterId = record.id,
        sourceSpecies = record.species,
        sourceLevel = record.level,
        species = species,
        level = staticLevel(
          record, species, settings, manifest, rngs.levels),
        mapId = record.mapId,
      }
    end
    return mappings, warnings, 0
  end

  local function generateGifts(manifest, settings, rngs)
    if settings.gift_pokemon == nil or settings.gift_pokemon == "off" then
      return {}, {}, 0
    end
    local mappings, warnings = {}, {}
    local unique = settings.gift_uniqueness == "unique"
    local matched = assignments(Catalog.gifts, manifest, settings,
      rngs.species, unique, "gifts", "GIFT_UNIQUENESS_EXHAUSTED")
    if #matched.unmatched > 0 then
      return {}, {
        warning("GIFT_GENERATION_FAILED",
          "a scoped gift has no valid candidate; gifts are vanilla",
          matched.unmatched[1].id),
      }, 1
    end
    for _, reset in ipairs(matched.resets) do
      warnings[#warnings + 1] = Matching.warning(reset,
        "gift destination pool was proven exhausted and restarted")
    end
    for _, record in ipairs(Catalog.gifts) do
      local species = matched.assignments[record.id]
      mappings[record.id] = {
        giftId = record.id,
        sourceSpecies = record.species,
        sourceLevel = record.level,
        species = species,
        level = giftLevel(record, species, settings, manifest),
        mapId = record.mapId,
        choiceGroup = record.choiceGroup,
        price = record.price,
      }
    end
    return mappings, warnings, 0
  end

  function Category.generate(manifest, settings, rngs)
    assert(type(manifest) == "table", "species manifest is required")
    assert(type(settings) == "table", "M11 settings are required")
    assert(type(rngs) == "table", "M11 RNG streams are required")
    local statics, staticWarnings, staticFallback = generateStatics(
      manifest, settings, {
        species = assert(rngs.staticSpecies),
        levels = assert(rngs.staticLevels),
      })
    local gifts, giftWarnings, giftFallback = generateGifts(
      manifest, settings, {
        species = assert(rngs.giftSpecies),
        levels = assert(rngs.giftLevels),
      })
    local warnings = {}
    for _, row in ipairs(staticWarnings) do warnings[#warnings + 1] = row end
    for _, row in ipairs(giftWarnings) do warnings[#warnings + 1] = row end
    return {
      staticEncounters = statics,
      gifts = gifts,
      warnings = warnings,
      fallbackCount = staticFallback + giftFallback,
    }
  end

  Category.catalog = Catalog
  return Category
end
