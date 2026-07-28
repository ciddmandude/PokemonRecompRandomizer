-- Public, pure generator boundary.
--
-- Deterministic primitives and species pools are available. Category
-- generation remains unavailable until its later gameplay milestones.
return function(Constants, Contracts, Foundation, Species)
  local Generator = {
    interfaceVersion = Constants.CONTRACT_VERSION,
    algorithmVersion = Constants.ALGORITHM_VERSION,
    available = false,
    foundationAvailable = true,
    hashVersion = Constants.HASH_VERSION,
    prngVersion = Constants.PRNG_VERSION,
  }

  function Generator.validate(request)
    return Contracts.validateGenerationRequest(request)
  end

  -- Returns result, nil on success or nil, structuredError on failure.
  -- Valid requests fail explicitly instead of producing data that could be
  -- mistaken for a complete randomized run.
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

    return nil, {
      code = "GENERATOR_UNAVAILABLE",
      message = "category generation is not available yet",
      details = {},
    }
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
