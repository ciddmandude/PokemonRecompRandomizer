-- Public, pure generator boundary.
return function(
    Constants, Contracts, Foundation, Species, WildCategory, StarterCategory,
    StaticGiftCategory, TradePrizeCategory, TrainerCategory,
    Progression, ValidationCategory)
  local Generator = {
    interfaceVersion = Constants.CONTRACT_VERSION,
    algorithmVersion = Constants.ALGORITHM_VERSION,
    available = true,
    foundationAvailable = true,
    hashVersion = Constants.HASH_VERSION,
    prngVersion = Constants.PRNG_VERSION,
  }

  function Generator.validate(request)
    return Contracts.validateGenerationRequest(request)
  end

  function Generator.generate(request)
    local valid, validationErrors =
      Contracts.validateGenerationRequest(request)
    if not valid then
      return nil, {
        code = "INVALID_REQUEST",
        message = "generation request failed validation",
        details = validationErrors,
      }
    end

    local result = Contracts.newGenerationResult()
    local manifest = { entries = request.species, byId = {} }
    for _, entry in ipairs(request.species) do
      manifest.byId[entry.id] = entry
    end

    local wildReachability = { earliestBySpecies = {} }
    if request.settings.wild_pokemon ~= "off" then
      local ok, category = pcall(WildCategory.generate,
        manifest, request.sources or {}, request.settings, {
          global = Foundation.Rng.fromSeed(
            request.seed.canonical, "wild.global"),
          area = Foundation.Rng.fromSeed(
            request.seed.canonical, "wild.area"),
          levels = Foundation.Rng.fromSeed(
            request.seed.canonical, "wild.levels"),
        })
      if ok then
        wildReachability = category.reachability or wildReachability
        result.mappings.wildGlobal = category.wildGlobal
        result.mappings.wildAreaSlots = category.wildAreaSlots
        result.mappings.fishing = category.fishing
        for _, row in ipairs(category.warnings) do
          result.diagnostics.warnings[
            #result.diagnostics.warnings + 1] = row
        end
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + category.fallbackCount
      else
        result.mappings.wildGlobal = {}
        result.mappings.wildAreaSlots = {}
        result.mappings.fishing = {}
        result.diagnostics.warnings[#result.diagnostics.warnings + 1] = {
          code = "WILD_GENERATION_FAILED",
          message = "wild category generation failed; wild encounters are vanilla",
        }
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + 1
      end
    end

    if request.settings.starters ~= nil
        and request.settings.starters ~= "off" then
      local ok, category = pcall(StarterCategory.generate,
        manifest, request.settings, {
          starters = Foundation.Rng.fromSeed(
            request.seed.canonical, "starters"),
          rival = Foundation.Rng.fromSeed(
            request.seed.canonical, "rival.counterpick"),
        }, request.sources and request.sources.typeEffectiveness,
        request.sources and (request.sources.gameVersion
          or request.sources.version))
      if ok then
        result.mappings.starters = category.starters
        result.mappings.starterFlags = category.starterFlags
        for _, row in ipairs(category.warnings) do
          result.diagnostics.warnings[
            #result.diagnostics.warnings + 1] = row
        end
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + category.fallbackCount
      else
        result.mappings.starters = {}
        result.mappings.starterFlags = {}
        result.diagnostics.warnings[
          #result.diagnostics.warnings + 1] = {
            code = "STARTER_GENERATION_FAILED",
            message = "starter category generation failed; starters are vanilla",
          }
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + 1
      end
    end

    if (request.settings.static_pokemon ~= nil
          and request.settings.static_pokemon ~= "off")
        or (request.settings.gift_pokemon ~= nil
          and request.settings.gift_pokemon ~= "off") then
      local ok, category = pcall(StaticGiftCategory.generate,
        manifest, request.settings, {
          staticSpecies = Foundation.Rng.fromSeed(
            request.seed.canonical, "static.encounters"),
          staticLevels = Foundation.Rng.fromSeed(
            request.seed.canonical, "static.levels"),
          giftSpecies = Foundation.Rng.fromSeed(
            request.seed.canonical, "gifts"),
          giftLevels = Foundation.Rng.fromSeed(
            request.seed.canonical, "gift.levels"),
        }, request.sources or {})
      if ok then
        result.mappings.staticEncounters = category.staticEncounters
        result.mappings.gifts = category.gifts
        for _, row in ipairs(category.warnings) do
          result.diagnostics.warnings[
            #result.diagnostics.warnings + 1] = row
        end
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + category.fallbackCount
      else
        result.mappings.staticEncounters = {}
        result.mappings.gifts = {}
        result.diagnostics.warnings[
          #result.diagnostics.warnings + 1] = {
            code = "STATIC_GIFT_GENERATION_FAILED",
            message = "scoped M11 generation failed; statics and gifts are vanilla",
          }
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + 2
      end
    end

    if (request.settings.in_game_trades ~= nil
          and request.settings.in_game_trades ~= "off")
        or (request.settings.game_corner_pokemon ~= nil
          and request.settings.game_corner_pokemon ~= "off") then
      local reachable = {
        earliestBySpecies = {},
        unknownLocations = wildReachability.unknownLocations or {},
      }
      for species, stage in pairs(wildReachability.earliestBySpecies or {}) do
        reachable.earliestBySpecies[species] = stage
      end
      local function addEarliest(species, stage)
        if type(species) ~= "string" or stage == nil then return end
        local previous = reachable.earliestBySpecies[species]
        if previous == nil or stage < previous then
          reachable.earliestBySpecies[species] = stage
        end
      end
      for _, starter in pairs(result.mappings.starters or {}) do
        addEarliest(type(starter) == "table" and starter.species or starter,
          Progression.STAGES.START)
      end
      local version = request.sources
        and (request.sources.gameVersion or request.sources.version) or "red"
      local function collectLocated(rows)
        for _, row in pairs(rows or {}) do
          if type(row) == "table" and type(row.species) == "string" then
            local access = Progression.access(row.mapId, "walk", nil, version)
            if access.available then addEarliest(row.species, access.stage) end
          end
        end
      end
      collectLocated(result.mappings.staticEncounters)
      collectLocated(result.mappings.gifts)

      local ok, category = pcall(TradePrizeCategory.generate,
        manifest, request.sources or {}, request.settings, {
          trades = Foundation.Rng.fromSeed(
            request.seed.canonical, "trades"),
          prizes = Foundation.Rng.fromSeed(
            request.seed.canonical, "prizes"),
        }, reachable)
      if ok then
        result.mappings.trades = category.trades
        result.mappings.prizes = category.prizes
        for _, row in ipairs(category.warnings) do
          result.diagnostics.warnings[
            #result.diagnostics.warnings + 1] = row
        end
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + category.fallbackCount
      else
        result.mappings.trades = {}
        result.mappings.prizes = {}
        result.diagnostics.warnings[
          #result.diagnostics.warnings + 1] = {
            code = "TRADE_PRIZE_GENERATION_FAILED",
            message = "mod-only M12 generation failed; "
              .. "trades and prizes are vanilla",
          }
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + 2
      end
    end

    if request.settings.trainer_pokemon ~= nil
        or request.settings.rival_pokemon ~= nil then
      local trainerSources = {}
      for key, value in pairs(request.sources or {}) do
        trainerSources[key] = value
      end
      trainerSources.starters = result.mappings.starters
      trainerSources.starterFlags = result.mappings.starterFlags
      local ok, category = pcall(TrainerCategory.generate,
        manifest, trainerSources, request.settings, {
          species = Foundation.Rng.fromSeed(
            request.seed.canonical, "trainers.species"),
          levels = Foundation.Rng.fromSeed(
            request.seed.canonical, "trainers.levels"),
          sizes = Foundation.Rng.fromSeed(
            request.seed.canonical, "trainers.sizes"),
          rival = Foundation.Rng.fromSeed(
            request.seed.canonical, "trainers.rival"),
        })
      if ok then
        result.mappings.trainerParties = category.trainerParties
        for _, row in ipairs(category.warnings) do
          result.diagnostics.warnings[
            #result.diagnostics.warnings + 1] = row
        end
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + category.fallbackCount
      else
        result.mappings.trainerParties = {}
        result.diagnostics.warnings[
          #result.diagnostics.warnings + 1] = {
            code = "TRAINER_GENERATION_FAILED",
            message = "trainer generation failed; trainers are vanilla",
          }
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + 1
      end
    end

    local ok, validation = pcall(ValidationCategory.apply,
      result.mappings, request.settings, Foundation.Rng.fromSeed(
        request.seed.canonical, "validation.swaps"), {
          sources = request.sources or {},
          manifest = manifest,
          wildReachability = wildReachability,
        })
    if ok then
      for _, row in ipairs(validation.warnings) do
        result.diagnostics.warnings[
          #result.diagnostics.warnings + 1] = row
      end
      result.diagnostics.fallbackCount =
        result.diagnostics.fallbackCount + validation.fallbackCount
      result.diagnostics.validation = {
        repairSwaps = validation.repairSwaps,
        reachableSpecies = validation.reachableSpecies,
        mappingEntries = validation.mappingEntries,
        mappingBytes = validation.mappingBytes,
      }
    else
      result.diagnostics.warnings[
        #result.diagnostics.warnings + 1] = {
          code = "CROSS_CATEGORY_VALIDATION_FAILED",
          message = "cross-category validation failed; generated mappings "
            .. "were retained without final repair",
        }
      result.diagnostics.fallbackCount =
        result.diagnostics.fallbackCount + 1
    end
    return result, nil
  end

  function Generator.emptyResult()
    return Contracts.newGenerationResult()
  end

  function Generator.normalizeSeed(value)
    return Foundation.Seed.normalize(value)
  end

  function Generator.hashSeed(canonicalSeed)
    assert(Foundation.Seed.isCanonical(canonicalSeed),
      "hashSeed requires a canonical seed")
    return Foundation.Hash128.seed(canonicalSeed)
  end

  function Generator.newStream(canonicalSeed, streamName)
    assert(Foundation.Seed.isCanonical(canonicalSeed),
      "newStream requires a canonical seed")
    return Foundation.Rng.fromSeed(canonicalSeed, streamName)
  end

  function Generator.stableSort(values, less)
    return Foundation.StableSort.sort(values, less)
  end

  function Generator.sortedKeys(map)
    return Foundation.StableSort.keys(map)
  end

  function Generator.buildSpeciesManifest(records, options)
    return Species.Manifest.build(records, options)
  end

  function Generator.speciesCandidates(manifest, sourceId, rules)
    return Species.Filters.candidates(manifest, sourceId, rules)
  end

  return Generator
end
