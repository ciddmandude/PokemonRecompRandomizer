-- Engine save-event adapter. All schema logic remains in save_state.lua.
return function(Constants, Generator, SaveState, General)
  local Lifecycle = {}
  Lifecycle.__index = Lifecycle

  local autoCounter = 0

  local function speciesSet(manifest)
    local result = {}
    for id in pairs(manifest.byId or {}) do result[id] = true end
    return result
  end

  local function entropy(save)
    autoCounter = autoCounter + 1
    return table.concat({
      tostring(os.time()),
      tostring(os.clock()),
      tostring(save),
      tostring(save and save.player and save.player.id or ""),
      tostring(autoCounter),
    }, "\0")
  end

  function Lifecycle.new(dependencies)
    assert(type(dependencies) == "table", "lifecycle dependencies required")
    assert(type(dependencies.records) == "function",
      "species records provider required")
    return setmetatable({
      records = dependencies.records,
      metadata = dependencies.metadata,
      log = dependencies.log,
      settings = dependencies.settings or function() return {} end,
      sources = dependencies.sources or function() return {} end,
      seed = dependencies.seed,
      session = {
        active = nil,
        report = nil,
        phase = "idle",
      },
    }, Lifecycle)
  end

  function Lifecycle:manifest(settings)
    return Generator.buildSpeciesManifest(self.records(), {
      poolMode = General.poolMode(settings or {}),
      metadata = self.metadata(),
    })
  end

  function Lifecycle:onCreated(event)
    assert(type(event) == "table" and type(event.save) == "table",
      "save.created requires event.save")
    local settings = SaveState.clone(self.settings())
    local manifest = self:manifest(settings)
    local seed, seedError
    if self.seed then
      seed, seedError = self.seed(event.save, settings)
    else
      seed, seedError = General.resolveSeed(settings, entropy(event.save))
    end
    local set = speciesSet(manifest)
    local input = {
      seed = seed,
      settings = settings,
      compatibility = SaveState.compatibility(
        event.save, manifest.poolHash, settings,
        event.save.meta and event.save.meta.mods,
        General.settingsHash(settings)),
      species = manifest.entries,
      speciesSet = set,
      sources = self.sources(event.save, settings),
      enabled = settings.randomizer == "on" and seedError == nil,
      disableReason = seedError,
    }
    local namespace, report = SaveState.create(input, Generator.generate)
    if not namespace then
      self.session.active = nil
      self.session.report = report
      self.session.phase = "created-invalid"
      self.log:error("new run configuration could not be created")
      return nil, report
    end

    event.save.modData = event.save.modData or {}
    -- The only assignment occurs after generation, validation, and checksum.
    event.save.modData[Constants.MOD_ID] = namespace
    self.session.active = namespace.enabled and SaveState.clone(namespace) or nil
    self.session.report = report
    self.session.phase = namespace.enabled and "created" or "created-vanilla"
    if not namespace.enabled and report.error then
      if report.error.code == "INVALID_MANUAL_SEED" then
        self.log:warn("manual seed is invalid; new save uses vanilla")
      else
        self.log:warn(
          "randomizer generation unavailable; new save uses vanilla")
      end
    end
    return namespace, report
  end

  function Lifecycle:onLoading(event)
    self.session.active = nil
    self.session.report = nil
    self.session.phase = "loading"
    return type(event) == "table" and type(event.raw) == "table"
  end

  function Lifecycle:onLoaded(event)
    assert(type(event) == "table" and type(event.save) == "table",
      "save.loaded requires event.save")
    local namespace = event.save.modData
      and event.save.modData[Constants.MOD_ID]
    if namespace == nil then
      self.session.active = nil
      self.session.report = { code = "VANILLA_SAVE", errors = {} }
      self.session.phase = "vanilla"
      return true, self.session.report
    end

    local manifest = self:manifest(namespace.settings)
    local valid, errors = SaveState.validate(namespace, nil, true)
    if not valid then
      self.session.active = nil
      self.session.report = {
        code = "RANDOMIZER_SAVE_DISABLED",
        errors = errors,
      }
      self.session.phase = "quarantined"
      self.log:error(
        "saved randomizer state failed validation (%d issue%s); "
          .. "disabled for this session",
        #errors, #errors == 1 and "" or "s")
      return false, self.session.report
    end

    local _, contentErrors = SaveState.validate(
      namespace, speciesSet(manifest), true)
    local missing = {}
    for _, row in ipairs(contentErrors) do
      if row.code == "MISSING_SPECIES" then
        missing[row.path] = true
      end
    end
    local currentMods = event.meta and event.meta.mods
      or event.save.meta and event.save.meta.mods or {}
    local compatibilityReport = SaveState.compareRelevantMods(
      namespace.compatibility.relevantMods, currentMods)
    self.session.active = namespace.enabled and SaveState.clone(namespace) or nil
    if self.session.active and next(missing) then
      self.session.active._missingSpeciesPaths = missing
      self.session.active._speciesSet = speciesSet(manifest)
      self.session.report = {
        code = compatibilityReport.code == "RELEVANT_MODS_CHANGED"
          and "COMPATIBILITY_AND_CONTENT_CHANGED"
          or "MISSING_CONTENT_FALLBACK",
        missingCount = #contentErrors,
        compatibility = compatibilityReport,
        errors = {},
      }
      self.log:warn(
        "saved mappings reference %d unavailable content path%s; "
          .. "runtime uses vanilla lookup fallbacks",
        #contentErrors, #contentErrors == 1 and "" or "s")
    elseif compatibilityReport.code == "RELEVANT_MODS_CHANGED" then
      self.session.report = {
        code = "COMPATIBILITY_CHANGED",
        compatibility = compatibilityReport,
        errors = {},
      }
      self.log:warn(
        "current relevant mods differ from the New Game snapshot "
          .. "(%d added, %d removed, %d changed); saved mappings retained",
        #compatibilityReport.added, #compatibilityReport.removed,
        #compatibilityReport.changed)
    else
      self.session.report = {
        code = "OK",
        compatibility = compatibilityReport,
        errors = {},
      }
    end
    self.session.phase = namespace.enabled and "loaded" or "loaded-vanilla"
    return true, self.session.report
  end

  function Lifecycle:onWriting(event)
    assert(type(event) == "table" and type(event.save) == "table",
      "save.writing requires event.save")
    local namespace = event.save.modData
      and event.save.modData[Constants.MOD_ID]
    if namespace == nil then return true, nil end

    local currentValid, currentErrors =
      SaveState.validate(namespace, nil, true)
    if not currentValid then
      self.log:error(
        "randomizer state failed pre-write validation (%d issue%s); "
          .. "stored data left unchanged",
        #currentErrors, #currentErrors == 1 and "" or "s")
      return false, currentErrors
    end
    local candidate
    local copied, copyError = pcall(function()
      candidate = SaveState.clone(namespace)
    end)
    if not copied then
      self.log:error("randomizer state is not serializable: %s",
        tostring(copyError))
      return false, {{ code = "NON_DATA_VALUE", path = "$" }}
    end
    candidate.compatibility.engineVersion = tostring(
      event.meta and event.meta.engine
        or event.save.meta and event.save.meta.engine
        or candidate.compatibility.engineVersion)
    local stamped, errors = SaveState.stamp(candidate)
    if not stamped then
      self.log:error(
        "randomizer state failed pre-write validation (%d issue%s)",
        #errors, #errors == 1 and "" or "s")
      return false, errors
    end
    -- Replace only after the copied candidate is fully valid and stamped.
    event.save.modData[Constants.MOD_ID] = stamped
    return true, nil
  end

  function Lifecycle:activeRun()
    return self.session.active and SaveState.clone(self.session.active) or nil
  end

  function Lifecycle:replaceActive(namespace)
    self.session.active = type(namespace) == "table" and namespace.enabled
      and SaveState.clone(namespace) or nil
    if self.session.active then self.session.phase = "updated" end
    return self:activeRun()
  end

  function Lifecycle:status()
    return {
      phase = self.session.phase,
      active = self.session.active ~= nil,
      report = self.session.report and SaveState.clone(self.session.report) or nil,
    }
  end

  return Lifecycle
end
