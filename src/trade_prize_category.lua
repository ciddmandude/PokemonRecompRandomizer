-- Deterministic mod-only M12 generation for nine wired NPC trades and the
-- active version's six Celadon Game Corner Pokemon prize slots.
return function(StableSort, SpeciesFilters, Catalog, Matching, Progression)
  local Category = {}

  local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
  end

  local function warning(code, message, id)
    return { code = code, message = message, id = id }
  end

  local function commonRules(settings, excluded)
    return {
      strengthPercent = tonumber(settings.similar_strength),
      sameStage = settings.similar_strength == "same_stage",
      legendary = settings.legendaries or "allow",
      excludeIds = excluded,
    }
  end

  local function choose(candidates, rng)
    if #candidates == 0 then return nil end
    return candidates[rng:nextInt(1, #candidates)].id
  end

  local function assignUnits(units, rng, unique, category, code)
    if unique then
      return Matching.assign(units, rng, {
        category = category, code = code,
      })
    end
    local output = { assignments = {}, resets = {}, unmatched = {} }
    for _, unit in ipairs(units) do
      if #unit.candidates == 0 then
        output.unmatched[#output.unmatched + 1] = unit
      else
        output.assignments[unit.id] = choose(unit.candidates, rng)
      end
    end
    return output
  end

  local function sourceTrade(record, sources)
    local row = type(sources) == "table"
      and type(sources.field) == "table"
      and type(sources.field.trades) == "table"
      and sources.field.trades[record.index]
    if type(row) ~= "table" then row = record end
    return {
      give = type(row.give) == "string" and row.give or record.give,
      get = type(row.get) == "string" and row.get or record.get,
    }
  end

  local function reachableCandidates(candidates, reachable, tradeAccess)
    if type(reachable) ~= "table"
        or type(reachable.earliestBySpecies) ~= "table"
        or next(reachable.earliestBySpecies) == nil
        or not tradeAccess or not tradeAccess.available then
      return candidates
    end
    local output = {}
    for _, row in ipairs(candidates) do
      local stage = reachable.earliestBySpecies[row.id]
      if stage ~= nil and stage <= tradeAccess.stage then
        output[#output + 1] = row
      end
    end
    return output
  end

  local function receivedCandidates(
      manifest, requested, settings, safety)
    local excluded = {}
    if safety then excluded[requested] = true end

    if settings.trade_fairness == "no_downgrade" then
      local base = SpeciesFilters.candidates(
        manifest, requested, commonRules(settings, excluded))
      local request = manifest.byId[requested]
      local output = {}
      for _, row in ipairs(base) do
        if request and row.bst * 100 >= request.bst * 95 then
          output[#output + 1] = row
        end
      end
      if #output > 0 then return output, false end
      return base, true
    end

    local rules = commonRules(settings, excluded)
    if settings.trade_fairness == "any" then
      rules.strengthPercent = nil
      rules.sameStage = false
    end
    return SpeciesFilters.candidates(manifest, requested, rules), false
  end

  local function generateTrades(
      manifest, sources, settings, rng, reachable)
    if settings.in_game_trades == nil
        or settings.in_game_trades == "off" then
      return {}, {}, 0
    end
    local mappings, warnings = {}, {}
    local both = settings.in_game_trades == "both_sides"
    local safety = settings.trade_evolution_safety ~= "off"
    local sourceById, requestUnits = {}, {}
    for _, record in ipairs(Catalog.trades) do
      local source = sourceTrade(record, sources)
      sourceById[record.id] = source
      if not manifest.byId[source.give] or not manifest.byId[source.get] then
        return {}, {
          warning("TRADE_GENERATION_FAILED",
            "a stock trade source is unavailable; NPC trades are vanilla",
            record.id),
        }, 1
      end

      if both then
        local tradeAccess = Progression.tradeAccess(record,
          sources.gameVersion or sources.version)
        local candidates = SpeciesFilters.candidates(
          manifest, source.give, commonRules(settings, nil))
        if settings.catchability_guard == "on" then
          local guarded = reachableCandidates(candidates, reachable, tradeAccess)
          if #guarded > 0 then
            candidates = guarded
          else
            local row = warning(
              "TRADE_REACHABILITY_RELAXED",
              "no requested candidate is obtainable by this trade's "
                .. "progression stage; the common pool was used", record.id)
            row.mapId = record.mapId
            row.location = tradeAccess and tradeAccess.locationName
            row.stage = tradeAccess and tradeAccess.stage
            row.stageName = tradeAccess and tradeAccess.stageName
            warnings[#warnings + 1] = row
          end
        end
        requestUnits[#requestUnits + 1] = {
          id = record.id, source = source.give, candidates = candidates,
          hardConstraints = {
            similarStrength = tonumber(settings.similar_strength),
            sameStage = settings.similar_strength == "same_stage",
            legendary = settings.legendaries or "allow",
            reachable = settings.catchability_guard == "on",
          },
        }
      end
    end

    local unique = settings.duplicate_policy == "one_to_one"
    local requestedMatch = assignUnits(
      requestUnits, rng, unique, "trades.requested",
      "TRADE_REQUEST_UNIQUENESS_EXHAUSTED")
    if #requestedMatch.unmatched > 0 then
      return {}, { warning("TRADE_GENERATION_FAILED",
        "a requested trade species has no valid candidate; NPC trades are vanilla",
        requestedMatch.unmatched[1].id) }, 1
    end
    for _, reset in ipairs(requestedMatch.resets) do
      warnings[#warnings + 1] = Matching.warning(reset)
    end

    local receiveUnits, fairnessById = {}, {}
    for _, record in ipairs(Catalog.trades) do
      local source = sourceById[record.id]
      local requested = both
          and requestedMatch.assignments[record.id] or source.give
      local candidates, fairnessRelaxed = receivedCandidates(
        manifest, requested, settings, safety)
      fairnessById[record.id] = fairnessRelaxed
      receiveUnits[#receiveUnits + 1] = {
        id = record.id, source = source.get, candidates = candidates,
        hardConstraints = {
          similarStrength = settings.trade_fairness == "any"
              and nil or tonumber(settings.similar_strength),
          sameStage = settings.trade_fairness ~= "any"
            and settings.similar_strength == "same_stage",
          legendary = settings.legendaries or "allow",
          fairness = settings.trade_fairness,
          tradeEvolutionSafety = safety,
        },
      }
    end
    local receivedMatch = assignUnits(
      receiveUnits, rng, unique, "trades.received",
      "TRADE_RECEIVED_UNIQUENESS_EXHAUSTED")
    if #receivedMatch.unmatched > 0 then
      return {}, { warning("TRADE_GENERATION_FAILED",
        "a received trade species has no valid candidate; NPC trades are vanilla",
        receivedMatch.unmatched[1].id) }, 1
    end
    for _, reset in ipairs(receivedMatch.resets) do
      warnings[#warnings + 1] = Matching.warning(reset)
    end

    for _, record in ipairs(Catalog.trades) do
      local source = sourceById[record.id]
      local requested = both
          and requestedMatch.assignments[record.id] or source.give
      local received = receivedMatch.assignments[record.id]
      if fairnessById[record.id] then
        warnings[#warnings + 1] = warning(
          "TRADE_NO_DOWNGRADE_RELAXED",
          "NO DOWNGRADE had no candidate and relaxed to the common pool",
          record.id)
      end
      mappings[record.id] = {
        tradeId = record.id,
        tradeIndex = record.index,
        requested = {
          sourceSpecies = source.give,
          species = requested,
        },
        received = {
          sourceSpecies = source.get,
          species = received,
        },
      }
    end
    return mappings, warnings, 0
  end

  local function scaledLevel(record, species, manifest)
    local source = manifest.byId[record.species]
    local destination = manifest.byId[species]
    if not source or not destination or destination.bst <= 0 then
      return record.level
    end
    return clamp(math.floor(
      record.level * math.sqrt(source.bst / destination.bst) + 0.5),
      5, 30)
  end

  local function prizeLevel(record, species, settings, manifest)
    if settings.prize_levels == "fixed_15" then return 15 end
    if settings.prize_levels == "scaled" then
      return scaledLevel(record, species, manifest)
    end
    return record.level
  end

  local function roundTen(value)
    return math.floor(value / 10 + 0.5) * 10
  end

  local function prizeCost(record, species, settings, manifest, rng)
    if settings.prize_prices == "by_strength" then
      local source = manifest.byId[record.species]
      local destination = manifest.byId[species]
      if source and destination and source.bst > 0 then
        return clamp(roundTen(
          record.cost * destination.bst / source.bst), 10, 9999)
      end
    elseif settings.prize_prices == "random_25" then
      local percent = rng:nextInt(75, 125)
      return clamp(roundTen(record.cost * percent / 100), 10, 9999)
    end
    return record.cost
  end

  local function generatePrizes(manifest, sources, settings, rng)
    if settings.game_corner_pokemon == nil
        or settings.game_corner_pokemon == "off" then
      return {}, {}, 0
    end
    local sourceVersion = type(sources) == "table"
      and (sources.gameVersion or sources.version)
    local version = type(sourceVersion) == "string"
      and string.lower(sourceVersion) or nil
    if version ~= "red" and version ~= "blue" then
      local displayed = sourceVersion == nil and "(missing)"
        or tostring(sourceVersion)
      local row = warning(
        "PRIZE_VERSION_UNSUPPORTED",
        "Game Corner Pokemon prizes remain vanilla because version "
          .. displayed .. " is outside the supported Red/Blue catalog",
        "GAME_CORNER")
      row.version = sourceVersion
      return {}, { row }, 1
    end
    local mappings, warnings = {}, {}
    local units = {}
    for _, record in ipairs(Catalog.prizes[version]) do
      local candidates = SpeciesFilters.candidates(
        manifest, record.species, commonRules(settings, nil))
      units[#units + 1] = {
        id = record.id, source = record.species, candidates = candidates,
        hardConstraints = {
          similarStrength = tonumber(settings.similar_strength),
          sameStage = settings.similar_strength == "same_stage",
          legendary = settings.legendaries or "allow",
        },
      }
    end
    local matched = assignUnits(units, rng,
      settings.duplicate_policy == "one_to_one", "game_corner.prizes",
      "PRIZE_UNIQUENESS_EXHAUSTED")
    if #matched.unmatched > 0 then
      return {}, { warning("PRIZE_GENERATION_FAILED",
        "a Game Corner prize has no valid candidate; prizes are vanilla",
        matched.unmatched[1].id) }, 1
    end
    for _, reset in ipairs(matched.resets) do
      warnings[#warnings + 1] = Matching.warning(reset)
    end
    for _, record in ipairs(Catalog.prizes[version]) do
      local species = matched.assignments[record.id]
      mappings[record.id] = {
        prizeId = record.id,
        version = version,
        sourceSpecies = record.species,
        sourceLevel = record.level,
        sourceCost = record.cost,
        species = species,
        level = prizeLevel(record, species, settings, manifest),
        cost = prizeCost(record, species, settings, manifest, rng),
      }
    end
    return mappings, warnings, 0
  end

  function Category.generate(
      manifest, sources, settings, rngs, reachable)
    assert(type(manifest) == "table", "species manifest is required")
    assert(type(settings) == "table", "M12 settings are required")
    assert(type(rngs) == "table", "M12 RNG streams are required")
    local trades, tradeWarnings, tradeFallback = generateTrades(
      manifest, sources or {}, settings, assert(rngs.trades), reachable)
    local prizes, prizeWarnings, prizeFallback = generatePrizes(
      manifest, sources or {}, settings, assert(rngs.prizes))
    local warnings = {}
    for _, row in ipairs(tradeWarnings) do warnings[#warnings + 1] = row end
    for _, row in ipairs(prizeWarnings) do warnings[#warnings + 1] = row end
    return {
      trades = trades,
      prizes = prizes,
      warnings = warnings,
      fallbackCount = tradeFallback + prizeFallback,
    }
  end

  Category.catalog = Catalog
  return Category
end
