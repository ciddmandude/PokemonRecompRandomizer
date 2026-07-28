-- Engine-facing bootstrap. This is the only milestone-1 module that knows
-- about the gen1recomp mod object.
return function(
    Constants, Contracts, Generator, Species, SaveState, SaveLifecycle,
    Options)
  local Bootstrap = {}

  local REQUIRED_TABLES = {
    "content",
    "events",
    "hooks",
    "save",
    "options",
    "migrations",
    "ui",
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
    assertFunction(mod.migrations, "add", "mod.migrations:add")
    assertFunction(mod.content.screens, "register",
      "mod.content.screens:register")
    assertFunction(mod.log, "info", "mod.log:info")
    assertFunction(mod.log, "warn", "mod.log:warn")
    assertFunction(mod.log, "error", "mod.log:error")
  end

  function Bootstrap.start(mod)
    validateModObject(mod)

    local function manifestOptions(options)
      local copy = {}
      for key, value in pairs(options or {}) do copy[key] = value end
      copy.metadata = Species.Metadata:snapshot()
      return copy
    end

    local function mergedSpeciesRecords()
      local registry = mod.content.pokemon
      assert(type(registry) == "table"
          and type(registry.each) == "function",
        "mod API 2 is missing mod.content.pokemon:each")
      local records = {}
      for id, record in registry:each() do records[id] = record end
      return records
    end

    local publicApi = {
      contractVersion = Constants.CONTRACT_VERSION,
      saveSchemaVersion = Constants.SAVE_SCHEMA_VERSION,
      algorithmVersion = Constants.ALGORITHM_VERSION,
      hashVersion = Constants.HASH_VERSION,
      prngVersion = Constants.PRNG_VERSION,
      gameVersionRange = Constants.GAME_VERSION_RANGE,
      generator = Generator,
      registerSpeciesMeta = function(id, metadata)
        return Species.Metadata:register(id, metadata)
      end,
      species = {
        manifestVersion = Constants.SPECIES_MANIFEST_VERSION,
        buildManifest = function(options)
          return Generator.buildSpeciesManifest(
            mergedSpeciesRecords(), manifestOptions(options))
        end,
        candidates = Generator.speciesCandidates,
        metadataSnapshot = function()
          return Species.Metadata:snapshot()
        end,
        metadataFrozen = function()
          return Species.Metadata:isFrozen()
        end,
      },
      contracts = {
        categoryKeys = Contracts.categoryKeys,
        mappingKeys = Contracts.mappingKeys,
        validateGenerationRequest = Contracts.validateGenerationRequest,
        validateGenerationResult = Contracts.validateGenerationResult,
      },
    }

    local preferences = Options.Preferences.new(mod)
    preferences:define()

    local lifecycle = SaveLifecycle.new({
      records = mergedSpeciesRecords,
      metadata = function() return Species.Metadata:snapshot() end,
      log = mod.log,
      settings = function() return preferences:snapshot() end,
    })
    publicApi.save = {
      checksumVersion = Constants.SAVE_CHECKSUM_VERSION,
      validate = SaveState.validate,
      checksum = SaveState.checksum,
      activeRun = function() return lifecycle:activeRun() end,
      status = function() return lifecycle:status() end,
    }
    publicApi.preferences = {
      schema = function() return preferences:schema() end,
      pages = function() return preferences:pages() end,
      snapshot = function() return preferences:snapshot() end,
    }

    for key, value in pairs(publicApi) do mod.exports[key] = value end

    local function screenStatus()
      local status = lifecycle:status()
      status.run = lifecycle:activeRun()
      return status
    end

    mod.content.screens:register(Constants.OPTIONS_SCREEN_ID, {
      new = function(game)
        return Options.Screen.new(
          game, preferences, mod.ui, screenStatus)
      end,
    })

    mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
      local output = nextFn(game, rows)
      if type(output) ~= "table" then return output end
      output[#output + 1] = {
        id = "pokemon_randomizer",
        label = "RANDOMIZER",
        value = function()
          return screenStatus().active and "LOCKED" or "OPEN"
        end,
        activate = function(activeGame)
          mod.ui.push(activeGame, Constants.OPTIONS_SCREEN_ID)
        end,
      }
      return output
    end)

    mod.migrations:add(Constants.FIRST_MIGRATION_VERSION, function(namespace)
      local migrated = SaveState.migrate(namespace)
      if migrated == namespace then return end
      local stamped, errors = SaveState.stamp(migrated)
      if not stamped then
        error(("schema migration failed validation (%d issue%s)"):format(
          #errors, #errors == 1 and "" or "s"))
      end
      for key in pairs(namespace) do namespace[key] = nil end
      for key, value in pairs(stamped) do namespace[key] = value end
    end)

    mod.events:on("save.created", function(event)
      lifecycle:onCreated(event)
    end)
    mod.events:on("save.loading", function(event)
      lifecycle:onLoading(event)
    end)
    mod.events:on("save.loaded", function(event)
      lifecycle:onLoaded(event)
    end)
    mod.events:on("save.writing", function(event)
      lifecycle:onWriting(event)
    end)

    mod.events:once("mods.loaded", function()
      Species.Metadata:freeze()
      mod.log:info(
        "milestone 5 ready (contract=%d, save=%d, species=%d, hash=%s, prng=%s)",
        Constants.CONTRACT_VERSION,
        Constants.SAVE_SCHEMA_VERSION,
        Constants.SPECIES_MANIFEST_VERSION,
        Constants.HASH_VERSION,
        Constants.PRNG_VERSION)
    end)

    return publicApi
  end

  return Bootstrap
end
