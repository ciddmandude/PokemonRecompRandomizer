-- Public, pure generator boundary.
return function(
    Constants, Contracts, Foundation, Species, WildCategory, StarterCategory,
    StaticGiftCategory, TradePrizeCategory, TrainerCategory)
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
        }, request.sources and request.sources.typeEffectiveness)
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
        })
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
      local reachable = {}
      for _, species in pairs(result.mappings.wildGlobal) do
        if type(species) == "string" then reachable[species] = true end
      end
      local function collectMapped(value)
        if type(value) == "string" then
          if manifest.byId[value] then reachable[value] = true end
          return
        end
        if type(value) ~= "table" then return end
        if type(value.species) == "string" then
          reachable[value.species] = true
        end
        for _, child in pairs(value) do collectMapped(child) end
      end
      collectMapped(result.mappings.wildAreaSlots)
      collectMapped(result.mappings.fishing)
      collectMapped(result.mappings.starters)
      collectMapped(result.mappings.staticEncounters)
      collectMapped(result.mappings.gifts)

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
        and request.settings.trainer_pokemon ~= "off" then
      local ok, category = pcall(TrainerCategory.generate,
        manifest, request.sources or {}, request.settings, {
          species = Foundation.Rng.fromSeed(
            request.seed.canonical, "trainers.species"),
          levels = Foundation.Rng.fromSeed(
            request.seed.canonical, "trainers.levels"),
          sizes = Foundation.Rng.fromSeed(
            request.seed.canonical, "trainers.sizes"),
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
