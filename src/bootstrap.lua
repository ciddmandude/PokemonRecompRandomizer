-- Engine-facing bootstrap. This is the only milestone-1 module that knows
-- about the gen1recomp mod object.
return function(Constants, Contracts, Generator)
  local Bootstrap = {}

  local REQUIRED_TABLES = {
    "content",
    "events",
    "hooks",
    "save",
    "options",
    "log",
    "exports",
  }

  local function assertFunction(owner, name, path)
    assert(type(owner) == "table" and type(owner[name]) == "function",
      ("mod API 2 is missing %s"):format(path))
  end

  local function validateModObject(mod)
    assert(type(mod) == "table", "mod API object must be a table")
    assert(mod.id == Constants.MOD_ID,
      ("manifest id mismatch: expected %s, got %s"):format(
        Constants.MOD_ID, tostring(mod.id)))
    assert(mod.version == Constants.MOD_VERSION,
      ("manifest version mismatch: expected %s, got %s"):format(
        Constants.MOD_VERSION, tostring(mod.version)))
    assert(type(mod.manifest) == "table"
        and mod.manifest.api == Constants.MOD_API,
      ("pokemon_randomizer requires mod API %d"):format(Constants.MOD_API))

    for _, key in ipairs(REQUIRED_TABLES) do
      assert(type(mod[key]) == "table",
        ("mod API 2 is missing mod.%s"):format(key))
    end

    assertFunction(mod.events, "on", "mod.events:on")
    assertFunction(mod.events, "once", "mod.events:once")
    assertFunction(mod.hooks, "wrap", "mod.hooks:wrap")
    assertFunction(mod.save, "get", "mod.save:get")
    assertFunction(mod.save, "set", "mod.save:set")
    assertFunction(mod.options, "define", "mod.options:define")
    assertFunction(mod.options, "get", "mod.options:get")
    assertFunction(mod.log, "info", "mod.log:info")
    assertFunction(mod.log, "warn", "mod.log:warn")
    assertFunction(mod.log, "error", "mod.log:error")
  end

  function Bootstrap.start(mod)
    validateModObject(mod)

    local publicApi = {
      contractVersion = Constants.CONTRACT_VERSION,
      saveSchemaVersion = Constants.SAVE_SCHEMA_VERSION,
      algorithmVersion = Constants.ALGORITHM_VERSION,
      hashVersion = Constants.HASH_VERSION,
      prngVersion = Constants.PRNG_VERSION,
      gameVersionRange = Constants.GAME_VERSION_RANGE,
      generator = Generator,
      contracts = {
        categoryKeys = Contracts.categoryKeys,
        validateGenerationRequest = Contracts.validateGenerationRequest,
        validateGenerationResult = Contracts.validateGenerationResult,
      },
    }

    for key, value in pairs(publicApi) do mod.exports[key] = value end

    mod.events:once("mods.loaded", function()
      mod.log:info(
        "milestone 2 ready (contract=%d, algorithm=%s, hash=%s, prng=%s)",
        Constants.CONTRACT_VERSION,
        Constants.ALGORITHM_VERSION,
        Constants.HASH_VERSION,
        Constants.PRNG_VERSION)
    end)

    return publicApi
  end

  return Bootstrap
end
