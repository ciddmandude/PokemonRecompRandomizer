-- Validated adapter over options.modOptions[pokemon_randomizer].
return function(Constants, Schema, General, Seed)
  local Preferences = {}
  Preferences.__index = Preferences

  local SAVED_PRESETS_KEY = "saved_presets"
  local SAVED_PRESET_PREFIX = "saved:"
  local MAX_SAVED_PRESETS = 8
  local MAX_PRESET_NAME = 16
  local RESERVED_NAMES = {
    CUSTOM = true, CASUAL = true, STANDARD = true, CHAOS = true,
  }

  local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
  end

  local function validChoice(row, value)
    for _, choice in ipairs(row.choices or {}) do
      if choice[2] == value then return true end
    end
    return false
  end

  local function validValue(row, value)
    if row.type == "choice" then return validChoice(row, value) end
    if row.type == "number" then
      return type(value) == "number" and value % 1 == 0
        and value >= row.min and value <= row.max
    end
    if row.type == "text" then
      return type(value) == "string" and #value <= (row.maxLen or 32)
    end
    return false
  end

  local LEGACY_VALUES = {
    non_key_items = { off = "vanilla", on = "shuffled" },
    tms = { off = "vanilla", on = "shuffled" },
    hms = { off = "vanilla", safe = "shuffled", full_random = "shuffled" },
    key_items = {
      off = "vanilla", safe = "shuffled", full_random = "shuffled",
    },
    badges = { random = "mixed" },
    shops = { off = "vanilla", on = "randomized" },
  }

  local function normalizedOption(key, value, values)
    local migrated = LEGACY_VALUES[key]
    value = migrated and migrated[value] or value
    if key == "ensure_beatable" and values
        and (values.hms == "safe" or values.key_items == "safe") then
      return "on"
    end
    return value
  end

  local function normalizedSettings(values)
    local result = copy(values)
    for key, value in pairs(result) do
      result[key] = normalizedOption(key, value, values)
    end
    return result
  end

  local function normalizePresetName(value)
    if type(value) ~= "string" then return nil, "invalid preset name" end
    value = value:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    value = value:upper()
    if value == "" then return nil, "preset name is blank" end
    if #value > MAX_PRESET_NAME then return nil, "preset name is too long" end
    if value:find("[^A-Z0-9 _%-]") then
      return nil, "preset name has invalid characters"
    end
    if RESERVED_NAMES[value] then return nil, "preset name is reserved" end
    return value
  end

  local function savedToken(name)
    return SAVED_PRESET_PREFIX .. name
  end

  local function savedName(value)
    if type(value) ~= "string"
        or value:sub(1, #SAVED_PRESET_PREFIX) ~= SAVED_PRESET_PREFIX then
      return nil
    end
    return value:sub(#SAVED_PRESET_PREFIX + 1)
  end

  local function build()
    local rows, byKey, pages = {}, {}, {}
    local pageSize = Schema.rowsPerPage or 4
    for _, group in ipairs(Schema.groups) do
      local page
      for _, source in ipairs(group.rows) do
        local row = copy(source)
        assert(type(row.key) == "string" and row.key ~= "",
          "option row needs a key")
        assert(not byKey[row.key], "duplicate option key " .. row.key)
        assert(validValue(row, row.default),
          "invalid default for option " .. row.key)
        rows[#rows + 1] = row
        byKey[row.key] = row
        if not page or #page.rows >= pageSize then
          page = { name = group.name, rows = {} }
          pages[#pages + 1] = page
        end
        page.rows[#page.rows + 1] = row
      end
    end
    pages[#pages + 1] = {
      name = "ACTIONS",
      rows = {
        {
          kind = "action",
          key = "review_next_run",
          label = "REVIEW NEXT RUN",
          help = "SHOW SETTINGS AND WARNINGS.",
        },
        {
          kind = "action",
          key = "copy_active_seed",
          label = "COPY ACTIVE SEED",
          help = "COPY OR SHOW SEED AND RUN CODE.",
        },
        {
          kind = "action",
          key = "view_spoiler_log",
          label = "VIEW SPOILERS",
          help = "READ ACTIVE RUN LOG IN GAME.",
        },
        {
          kind = "action",
          key = "export_spoiler_log",
          label = "EXPORT SPOILERS",
          help = "WRITE ACTIVE RUN LOG.",
        },
      },
    }
    pages[#pages + 1] = {
      name = "ACTIONS",
      rows = {
        {
          kind = "action",
          key = "save_preset",
          label = "SAVE PRESET",
          help = "NAME AND SAVE CURRENT OPTIONS.",
        },
        {
          kind = "action",
          key = "delete_preset",
          label = "DELETE PRESET",
          help = "DELETE A SAVED PRESET.",
        },
        {
          kind = "action",
          key = "reset_defaults",
          label = "RESET DEFAULTS",
          help = "RESTORE STANDARD; CLEAR SEED TEXT.",
        },
      },
    }
    return rows, byKey, pages
  end

  function Preferences.new(mod)
    local rows, byKey, pages = build()
    return setmetatable({
      mod = mod,
      rows = rows,
      byKey = byKey,
      pageRows = pages,
    }, Preferences)
  end

  function Preferences:define()
    return self.mod.options:define(self.rows)
  end

  function Preferences:schema()
    return copy(self.rows)
  end

  local function optionBucket(self, game)
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[Constants.MOD_ID]
    if bucket then return bucket end
    local loader = game and game.mods and game.mods.modOptions
      and game.mods.modOptions[Constants.MOD_ID]
    if loader then return loader end
    if self.mod and self.mod.options and self.mod.options.get then
      local ok, result = pcall(
        self.mod.options.get, self.mod.options, SAVED_PRESETS_KEY)
      if ok and type(result) == "table" then
        return { [SAVED_PRESETS_KEY] = result }
      end
    end
    return nil
  end

  function Preferences:savedPresets(game)
    local bucket = optionBucket(self, game)
    local source = bucket and bucket[SAVED_PRESETS_KEY]
    local result, seen = {}, {}
    for _, entry in ipairs(type(source) == "table" and source or {}) do
      local name = type(entry) == "table" and normalizePresetName(entry.name)
      if name and not seen[name] and type(entry.settings) == "table" then
        seen[name] = true
        result[#result + 1] = {
          name = name,
          token = savedToken(name),
          settings = normalizedSettings(entry.settings),
        }
        if #result >= MAX_SAVED_PRESETS then break end
      end
    end
    return result
  end

  function Preferences:findSavedPreset(value, game)
    local name = savedName(value) or normalizePresetName(value)
    if not name then return nil end
    for _, entry in ipairs(self:savedPresets(game)) do
      if entry.name == name then return entry end
    end
    return nil
  end

  function Preferences:presetChoices(game)
    local choices = {
      { "CUSTOM", "custom" }, { "CASUAL", "casual" },
      { "STANDARD", "standard" }, { "CHAOS", "chaos" },
    }
    for _, entry in ipairs(self:savedPresets(game)) do
      choices[#choices + 1] = { entry.name, entry.token }
    end
    return choices
  end

  function Preferences:pages(game)
    local pages = copy(self.pageRows)
    for _, page in ipairs(pages) do
      for _, row in ipairs(page.rows) do
        if row.key == "preset" then row.choices = self:presetChoices(game) end
      end
    end
    return pages
  end

  function Preferences:get(key, game)
    local row = assert(self.byKey[key], "unknown option " .. tostring(key))
    local value
    local bucket = optionBucket(self, game)
    if bucket then value = bucket[key] end
    if value == nil then value = self.mod.options:get(key) end
    value = normalizedOption(key, value, bucket)
    if key == "seed_text" and type(value) == "string" and value ~= "" then
      value = Seed.normalize(value)
    end
    if key == "preset" and savedName(value) then
      if not self:findSavedPreset(value, game) then value = "custom" end
    elseif not validValue(row, value) then
      value = row.default
    end
    return copy(value)
  end

  local function persist(self, game, key, value, deferWrite)
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    local buckets = game.save.options.modOptions
    buckets[Constants.MOD_ID] = buckets[Constants.MOD_ID] or {}
    buckets[Constants.MOD_ID][key] = copy(value)

    local loader = game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[Constants.MOD_ID] =
        loader.modOptions[Constants.MOD_ID] or {}
      loader.modOptions[Constants.MOD_ID][key] = copy(value)
    end
    if not deferWrite and game.writeOptions then game:writeOptions() end
  end

  local function capturedRows(self)
    local result = {}
    for _, row in ipairs(self.rows) do
      if row.key ~= "randomizer" and row.key ~= "preset" then
        result[#result + 1] = row
      end
    end
    return result
  end

  local function savedPresetMatches(self, entry, game)
    for _, row in ipairs(capturedRows(self)) do
      local expected = entry.settings[row.key]
      expected = normalizedOption(row.key, expected, entry.settings)
      if not validValue(row, expected) then expected = row.default end
      if self:get(row.key, game) ~= expected then return false end
    end
    return true
  end

  local function detectedPreset(self, game, preferSaved)
    if preferSaved then
      for _, entry in ipairs(self:savedPresets(game)) do
        if savedPresetMatches(self, entry, game) then return entry.token end
      end
    end
    local builtIn = General.detectPreset(self:snapshot(game))
    if builtIn ~= "custom" then return builtIn end
    if not preferSaved then
      for _, entry in ipairs(self:savedPresets(game)) do
        if savedPresetMatches(self, entry, game) then return entry.token end
      end
    end
    return "custom"
  end

  function Preferences:set(key, value, game)
    local row = self.byKey[key]
    if not row then return nil, "unknown option" end
    if key == "seed_text" and type(value) == "string" then
      if value:match("^%s*$") then
        value = ""
      else
        local canonical, seedError = Seed.normalize(value)
        if not canonical then
          return nil, seedError and seedError.message or "invalid seed"
        end
        value = canonical
      end
    end
    assert(type(game) == "table" and type(game.save) == "table",
      "setting an option requires a live game")
    local saved = key == "preset" and self:findSavedPreset(value, game)
    if saved then
      for _, captured in ipairs(capturedRows(self)) do
        local nextValue = saved.settings[captured.key]
        nextValue = normalizedOption(captured.key, nextValue, saved.settings)
        if not validValue(captured, nextValue) then
          nextValue = captured.default
        end
        persist(self, game, captured.key, nextValue, true)
      end
      persist(self, game, "preset", saved.token, true)
      if game.writeOptions then game:writeOptions() end
      return saved.token, nil
    end
    if not validValue(row, value) then return nil, "invalid option value" end
    if key == "preset" and value ~= "custom" then
      local expanded = General.applyPreset(self:snapshot(game), value)
      for _, presetKey in ipairs(General.presetKeys()) do
        persist(self, game, presetKey, expanded[presetKey], true)
      end
      persist(self, game, "generate_spoiler_log", "on", true)
      persist(self, game, "preset", value, true)
      if game.writeOptions then game:writeOptions() end
      return value, nil
    end

    local previousPreset = self:get("preset", game)
    persist(self, game, key, value, true)
    if General.isPresetKey(key) then
      local detected = detectedPreset(
        self, game, savedName(previousPreset) ~= nil)
      persist(self, game, "preset", detected, true)
    elseif savedName(previousPreset) and key ~= "randomizer"
        and key ~= "preset" then
      persist(self, game, "preset", detectedPreset(self, game, true), true)
    end
    if game.writeOptions then game:writeOptions() end
    return value, nil
  end

  function Preferences:normalizePresetName(value)
    return normalizePresetName(value)
  end

  function Preferences:savePreset(value, game, overwrite)
    assert(type(game) == "table" and type(game.save) == "table",
      "saving a preset requires a live game")
    local name, err = normalizePresetName(value)
    if not name then return nil, err end
    local entries = self:savedPresets(game)
    local existing
    for index, entry in ipairs(entries) do
      if entry.name == name then existing = index break end
    end
    if existing and not overwrite then return nil, "preset exists" end
    if not existing and #entries >= MAX_SAVED_PRESETS then
      return nil, "preset limit reached"
    end
    local settings = {}
    for _, row in ipairs(capturedRows(self)) do
      settings[row.key] = self:get(row.key, game)
    end
    local record = { name = name, settings = settings }
    if existing then
      entries[existing] = record
    else
      entries[#entries + 1] = record
    end
    for _, entry in ipairs(entries) do entry.token = nil end
    persist(self, game, SAVED_PRESETS_KEY, entries, true)
    persist(self, game, "preset", savedToken(name), true)
    if game.writeOptions then game:writeOptions() end
    return savedToken(name), nil
  end

  function Preferences:deletePreset(value, game)
    assert(type(game) == "table" and type(game.save) == "table",
      "deleting a preset requires a live game")
    local target = self:findSavedPreset(value, game)
    if not target then return nil, "preset not found" end
    local wasActive = self:get("preset", game) == target.token
    local entries = {}
    for _, entry in ipairs(self:savedPresets(game)) do
      if entry.token ~= target.token then
        entries[#entries + 1] = {
          name = entry.name,
          settings = copy(entry.settings),
        }
      end
    end
    persist(self, game, SAVED_PRESETS_KEY, entries, true)
    if wasActive then
      persist(self, game, "preset", General.detectPreset(self:snapshot(game)),
        true)
    end
    if game.writeOptions then game:writeOptions() end
    return target.name, nil
  end

  function Preferences:reset(game)
    assert(type(game) == "table" and type(game.save) == "table",
      "resetting options requires a live game")
    for _, row in ipairs(self.rows) do
      persist(self, game, row.key, row.default, true)
    end
    if game.writeOptions then game:writeOptions() end
    return self:snapshot(game)
  end

  function Preferences:snapshot(game)
    local snapshot = {}
    for _, row in ipairs(self.rows) do
      snapshot[row.key] = self:get(row.key, game)
    end
    return snapshot
  end

  function Preferences:display(row, game)
    local value = self:get(row.key, game)
    if row.key == "preset" and savedName(value) then
      local entry = self:findSavedPreset(value, game)
      return entry and entry.name or "CUSTOM"
    end
    if row.type == "choice" then
      for _, choice in ipairs(row.choices) do
        if choice[2] == value then return choice[1] end
      end
    end
    if row.type == "text" then return value == "" and "(BLANK)" or value end
    return tostring(value)
  end

  function Preferences:step(row, direction, game)
    if row.type == "choice" then
      local index = 1
      local current = self:get(row.key, game)
      for i, candidate in ipairs(row.choices) do
        if candidate[2] == current then index = i break end
      end
      index = ((index - 1 + direction) % #row.choices) + 1
      return self:set(row.key, row.choices[index][2], game)
    elseif row.type == "number" then
      local value = self:get(row.key, game) + direction * (row.step or 1)
      value = math.max(row.min, math.min(row.max, value))
      return self:set(row.key, value, game)
    end
    return nil, "option cannot be stepped"
  end

  return Preferences
end
