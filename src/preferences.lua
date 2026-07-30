-- Validated adapter over options.modOptions[pokemon_randomizer].
return function(Constants, Schema, General)
  local Preferences = {}
  Preferences.__index = Preferences

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

  function Preferences:pages()
    return copy(self.pageRows)
  end

  function Preferences:get(key, game)
    local row = assert(self.byKey[key], "unknown option " .. tostring(key))
    local value
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[Constants.MOD_ID]
    if bucket then value = bucket[key] end
    if value == nil then value = self.mod.options:get(key) end
    if not validValue(row, value) then value = row.default end
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

  function Preferences:set(key, value, game)
    local row = self.byKey[key]
    if not row then return nil, "unknown option" end
    if not validValue(row, value) then return nil, "invalid option value" end
    assert(type(game) == "table" and type(game.save) == "table",
      "setting an option requires a live game")
    if key == "preset" and value ~= "custom" then
      local expanded = General.applyPreset(self:snapshot(game), value)
      for _, presetKey in ipairs(General.presetKeys()) do
        persist(self, game, presetKey, expanded[presetKey], true)
      end
      persist(self, game, "preset", value, true)
      if game.writeOptions then game:writeOptions() end
      return value, nil
    end

    persist(self, game, key, value, true)
    if General.isPresetKey(key) then
      local detected = General.detectPreset(self:snapshot(game))
      persist(self, game, "preset", detected, true)
    end
    if game.writeOptions then game:writeOptions() end
    return value, nil
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
