-- Public, pure generator boundary.
--
-- Milestone 1 defines and validates the interface. Milestone 2 will supply
-- deterministic seed normalization, hashing, named streams, and a PRNG.
return function(Constants, Contracts)
  local Generator = {
    interfaceVersion = Constants.CONTRACT_VERSION,
    algorithmVersion = Constants.ALGORITHM_VERSION,
    available = false,
  }

  function Generator.validate(request)
    return Contracts.validateGenerationRequest(request)
  end

  -- Returns result, nil on success or nil, structuredError on failure.
  -- Until milestone 2, valid requests fail explicitly instead of producing
  -- data that could be mistaken for a randomized run.
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
      message = "deterministic generation begins in milestone 2",
      details = {},
    }
  end

  function Generator.emptyResult()
    return Contracts.newGenerationResult()
  end

  return Generator
end
