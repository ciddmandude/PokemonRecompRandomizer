-- Engine-facing bootstrap. This is the only milestone-1 module that knows
-- about the gen1recomp mod object.
return function(
    Constants, Contracts, Generator, Species, SaveState, SaveLifecycle,
    Options, WildRuntime, StarterOffer, StarterCompat, StarterRuntime,
    StaticGiftCompat, TradePrizeCompat, TrainerRuntime)
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
    assertFunction(mod.content.map_scripts, "register",
      "mod.content.map_scripts:register")
    assertFunction(mod.content.commands, "get",
      "mod.content.commands:get")
    assertFunction(mod.content.commands, "register",
      "mod.content.commands:register")
    assertFunction(mod.content.field, "get",
      "mod.content.field:get")
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

    local function mergedEncounterRecords()
      local registry = mod.content.encounters
      assert(type(registry) == "table"
          and type(registry.each) == "function",
        "mod API 2 is missing mod.content.encounters:each")
      local records = {}
      for id, record in registry:each() do records[id] = record end
      return records
    end

    local function mergedTrainerRecords()
      local registry = mod.content.trainers
      assert(type(registry) == "table"
          and type(registry.each) == "function",
        "mod API 2 is missing mod.content.trainers:each")
      local records = {}
      for id, record in registry:each() do records[id] = record end
      return records
    end

    local function mergedFieldRecords(save)
      local registry = mod.content.field
      local fishing = registry:get("fishing")
      local records = {
        fishing = fishing,
        trades = registry:get("trades"),
      }
      for _, definition in pairs(fishing or {}) do
        if type(definition) == "table"
            and type(definition.perMap) == "string" then
          records[definition.perMap] = registry:get(definition.perMap)
        end
      end
      return records, save and save.version or "red"
    end

    local function mergedTypeEffectiveness()
      local registry = mod.content.type_chart
      if type(registry) ~= "table" or type(registry.each) ~= "function" then
        return {}
      end
      local chart = {}
      for id, record in registry:each() do
        local attacking, defending
        if type(id) == "string" then
          attacking, defending = id:match("^([^>]+)>(.+)$")
        end
        if attacking and defending and type(record) == "table"
            and type(record.multiplier) == "number" then
          chart[attacking] = chart[attacking] or {}
          chart[attacking][defending] = record.multiplier / 10
        end
      end
      return chart
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
      sources = function(save)
        local field, version = mergedFieldRecords(save)
        return {
          encounters = mergedEncounterRecords(),
          trainers = mergedTrainerRecords(),
          field = field,
          gameVersion = version,
          typeEffectiveness = mergedTypeEffectiveness(),
        }
      end,
    })
    mod.content.map_scripts:register(
      "OAKS_LAB",
      StarterCompat.contribution(
        function() return lifecycle:activeRun() end))
    StaticGiftCompat.install(
      mod, function() return lifecycle:activeRun() end)
    TradePrizeCompat.install(
      mod, function() return lifecycle:activeRun() end)
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
      preset = Options.General.preset,
      detectPreset = Options.General.detectPreset,
      behaviorSettings = Options.General.behaviorSettings,
    }
    publicApi.runCode = Options.General.runCode

    for key, value in pairs(publicApi) do mod.exports[key] = value end

    local function screenStatus()
      local status = lifecycle:status()
      status.run = lifecycle:activeRun()
      return status
    end

    mod.content.screens:register(Constants.OPTIONS_SCREEN_ID, {
      new = function(game)
        local function reviewNextRun(activeGame)
          local lines = {}
          local settings = preferences:snapshot(activeGame)
          lines[#lines + 1] = "SEED: "
            .. (settings.seed_mode == "auto"
              and "AUTO" or (settings.seed_text ~= ""
                and settings.seed_text or "(EMPTY)"))
          for _, row in ipairs(preferences:schema()) do
            lines[#lines + 1] =
              row.label .. ": " .. preferences:display(row, activeGame)
          end
          local manifest = Generator.buildSpeciesManifest(
            mergedSpeciesRecords(), {
              poolMode = Options.General.poolMode(settings),
              metadata = Species.Metadata:snapshot(),
            })
          lines[#lines + 1] = ("POOL: %d ELIGIBLE"):format(
            manifest.diagnostics.counts.eligible)
          if manifest.diagnostics.counts.excluded > 0 then
            lines[#lines + 1] = ("POOL EXCLUDED: %d"):format(
              manifest.diagnostics.counts.excluded)
          end
          for _, warning in ipairs(manifest.diagnostics.warnings) do
            lines[#lines + 1] = "WARNING " .. warning.code
          end
          local warnings = Options.General.reviewWarnings(settings)
          if #warnings == 0 then
            lines[#lines + 1] = "VALIDATION: OK"
          else
            for _, warning in ipairs(warnings) do
              lines[#lines + 1] =
                "WARNING " .. warning.code .. ": " .. warning.message
            end
          end
          mod.ui.push(activeGame, Constants.REVIEW_SCREEN_ID, {
            title = "NEXT RUN",
            lines = lines,
          })
        end

        local function copyActiveSeed(activeGame)
          local run = lifecycle:activeRun()
          if not run then return "NO ACTIVE RUN" end
          local code = Options.General.runCode(run)
          local text = "SEED: " .. run.seed.canonical
            .. "\nRUN CODE: " .. code
          local copied = false
          local system = love and love.system
          if system and type(system.setClipboardText) == "function" then
            local ok = pcall(system.setClipboardText, text)
            copied = ok
          end
          mod.ui.push(activeGame, Constants.REVIEW_SCREEN_ID, {
            title = "ACTIVE RUN",
            lines = {
              "SEED",
              run.seed.canonical,
              "RUN CODE",
              code,
              "ALGORITHM " .. run.algorithmVersion,
              "RUN SETTINGS: LOCKED",
              "WILD: " .. run.settings.wild_pokemon,
              "STARTERS: " .. run.settings.starters,
              "STATIC: " .. run.settings.static_pokemon,
              "GIFTS: " .. run.settings.gift_pokemon,
              "TRADES: " .. run.settings.in_game_trades,
              "PRIZES: " .. run.settings.game_corner_pokemon,
              "TRAINERS: " .. run.settings.trainer_pokemon,
            },
          })
          return copied and "SEED COPIED" or "COPY UNAVAILABLE"
        end

        return Options.Screen.new(
          game, preferences, mod.ui, screenStatus, {
            review_next_run = reviewNextRun,
            copy_active_seed = copyActiveSeed,
          })
      end,
    })

    mod.content.screens:register(Constants.REVIEW_SCREEN_ID, {
      new = function(game, model)
        return Options.ReviewScreen.new(game, model, mod.ui)
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

    mod.hooks:wrap("encounter.species",
      function(nextFn, encounter, context)
        local resolved = nextFn(encounter, context)
        return WildRuntime.resolve(
          resolved, context, lifecycle:activeRun())
      end)

    mod.hooks:wrap("encounter.roll",
      function(nextFn, encounterDefinition, context)
        return WildRuntime.roll(
          nextFn, encounterDefinition, context, lifecycle:activeRun())
      end)

    mod.hooks:wrap("encounter.fishing",
      function(nextFn, rod, mapId, candidates)
        local encounter = nextFn(rod, mapId, candidates)
        return WildRuntime.fishing(
          encounter, rod, mapId, candidates, lifecycle:activeRun())
      end)

    mod.hooks:wrap("trainer.party",
      function(nextFn, oppClass, partyIndex, party)
        local resolved = nextFn(oppClass, partyIndex, party)
        resolved = TrainerRuntime.party(
          resolved, oppClass, partyIndex, lifecycle:activeRun())
        return StarterRuntime.party(
          resolved, oppClass, partyIndex, lifecycle:activeRun())
      end)

    mod.migrations:add(Constants.FIRST_MIGRATION_VERSION, function(namespace)
      local migrated = SaveState.migrate(namespace)
      if migrated == namespace then return end
      if type(migrated.settings) == "table"
          and type(migrated.compatibility) == "table" then
        migrated.compatibility.settingsHash =
          SaveState.hashBehaviorSettings(migrated.settings)
      end
      local stamped, errors = SaveState.stamp(migrated)
      if not stamped then
        error(("schema migration failed validation (%d issue%s)"):format(
          #errors, #errors == 1 and "" or "s"))
      end
      for key in pairs(namespace) do namespace[key] = nil end
      for key, value in pairs(stamped) do namespace[key] = value end
    end)

    mod.migrations:add(
      Constants.SETTINGS_HASH_MIGRATION_VERSION, function(namespace)
        if type(namespace) ~= "table"
            or namespace.schemaVersion ~= Constants.SAVE_SCHEMA_VERSION
            or type(namespace.settings) ~= "table"
            or type(namespace.compatibility) ~= "table" then
          return
        end
        local migrated = SaveState.clone(namespace)
        migrated.compatibility.settingsHash =
          SaveState.hashBehaviorSettings(migrated.settings)
        local stamped, errors = SaveState.stamp(migrated)
        if not stamped then
          error(("settings-hash migration failed validation (%d issue%s)")
            :format(#errors, #errors == 1 and "" or "s"))
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
        "milestone 13 ready (contract=%d, save=%d, species=%d, hash=%s, prng=%s)",
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
