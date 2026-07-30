-- Deterministic mod-only M12 generation for nine wired NPC trades and the
-- active version's six Celadon Game Corner Pokemon prize slots.
return function(StableSort, SpeciesFilters, Catalog)
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
      legendary = settings.legendaries or "allow",
      excludeIds = excluded,
    }
  end

  local function choose(candidates, rng)
    if #candidates == 0 then return nil end
    return candidates[rng:nextInt(1, #candidates)].id
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

  local function reachableCandidates(candidates, reachable)
    if type(reachable) ~= "table" or next(reachable) == nil then
      return candidates
    end
    local output = {}
    for _, row in ipairs(candidates) do
      if reachable[row.id] then output[#output + 1] = row end
    end
    return output
  end

  local function receivedCandidates(
      manifest, requested, settings, used, safety)
    local excluded = {}
    if settings.duplicate_policy == "one_to_one" then
      for id in pairs(used) do excluded[id] = true end
    end
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
    local usedGive, usedGet = {}, {}
    local both = settings.in_game_trades == "both_sides"
    local safety = settings.trade_evolution_safety ~= "off"

    for _, record in ipairs(Catalog.trades) do
      local source = sourceTrade(record, sources)
      if not manifest.byId[source.give] or not manifest.byId[source.get] then
        return {}, {
          warning("TRADE_GENERATION_FAILED",
            "a stock trade source is unavailable; NPC trades are vanilla",
            record.id),
        }, 1
      end

      local requested = source.give
      if both then
        local excluded = settings.duplicate_policy == "one_to_one"
          and usedGive or nil
        local candidates = SpeciesFilters.candidates(
          manifest, source.give, commonRules(settings, excluded))
        if settings.catchability_guard == "on" then
          local guarded = reachableCandidates(candidates, reachable)
          if #guarded > 0 then
            candidates = guarded
          else
            warnings[#warnings + 1] = warning(
              "TRADE_REACHABILITY_RELAXED",
              "no mapped reachable request candidate was available; "
                .. "the common pool was used", record.id)
          end
        end
        requested = choose(candidates, rng)
        if not requested then
          return {}, {
            warning("TRADE_GENERATION_FAILED",
              "a requested trade species has no valid candidate; "
                .. "NPC trades are vanilla", record.id),
          }, 1
        end
        usedGive[requested] = true
      end

      local candidates, fairnessRelaxed = receivedCandidates(
        manifest, requested, settings, usedGet, safety)
      local received = choose(candidates, rng)
      if not received then
        return {}, {
          warning("TRADE_GENERATION_FAILED",
            "a received trade species has no valid candidate; "
              .. "NPC trades are vanilla", record.id),
        }, 1
      end
      if fairnessRelaxed then
        warnings[#warnings + 1] = warning(
          "TRADE_NO_DOWNGRADE_RELAXED",
          "NO DOWNGRADE had no candidate and relaxed to the common pool",
          record.id)
      end
      usedGet[received] = true
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
    local version = type(sources) == "table"
      and (sources.gameVersion or sources.version) or "red"
    version = version == "blue" and "blue" or "red"
    local mappings, warnings, used = {}, {}, {}
    for _, record in ipairs(Catalog.prizes[version]) do
      local excluded = settings.duplicate_policy == "one_to_one"
        and used or nil
      local candidates = SpeciesFilters.candidates(
        manifest, record.species, commonRules(settings, excluded))
      local species = choose(candidates, rng)
      if not species then
        return {}, {
          warning("PRIZE_GENERATION_FAILED",
            "a Game Corner prize has no valid candidate; prizes are vanilla",
            record.id),
        }, 1
      end
      used[species] = true
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
