-- Public, pure generator boundary.
return function(Constants, Contracts, Foundation, Species, WildGlobal)
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

    if request.settings.wild_pokemon == "global_map" then
      local ok, category = pcall(
        WildGlobal.generate,
        manifest,
        request.sources and request.sources.encounters,
        request.settings,
        Foundation.Rng.fromSeed(request.seed.canonical, "wild.global"))
      if not ok then
        result.diagnostics.warnings[#result.diagnostics.warnings + 1] = {
          code = "WILD_GENERATION_FAILED",
          message = "wild category generation failed; wild encounters are vanilla",
        }
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + 1
      else
        result.mappings.wildGlobal = category.mapping
        for _, row in ipairs(category.warnings) do
          result.diagnostics.warnings[
            #result.diagnostics.warnings + 1] = row
        end
        result.diagnostics.fallbackCount =
          result.diagnostics.fallbackCount + category.fallbackCount
      end
    elseif request.settings.wild_pokemon == "area_slots" then
      result.diagnostics.warnings[#result.diagnostics.warnings + 1] = {
        code = "WILD_AREA_SLOTS_UNAVAILABLE",
        message = "area-slot wild mapping is scheduled for milestone 8",
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
