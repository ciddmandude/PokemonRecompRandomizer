-- Pre-generation metadata contributed by this mod or other mods.
return function(StableSort)
  local Metadata = {}
  Metadata.__index = Metadata

  local ALLOWED_STAGES = { basic = true, middle = true, final = true }
  local ALLOWED_FIELDS = {
    legendary = true,
    stage = true,
  }
  local STAGE_RANK = { basic = 1, middle = 2, final = 3 }

  local function copyMetadata(value)
    local copy = {}
    for key, field in pairs(value) do copy[key] = field end
    return copy
  end

  local function validate(id, metadata)
    assert(type(id) == "string" and id:match("^[A-Z0-9_]+$"),
      "species metadata id must be an uppercase species id")
    assert(type(metadata) == "table", "species metadata must be a table")
    for key in pairs(metadata) do
      assert(ALLOWED_FIELDS[key],
        ("unknown species metadata field %s"):format(tostring(key)))
    end
    if metadata.legendary ~= nil then
      assert(type(metadata.legendary) == "boolean",
        "metadata.legendary must be boolean")
    end
    if metadata.stage ~= nil then
      assert(ALLOWED_STAGES[metadata.stage],
        "metadata.stage must be basic, middle, or final")
    end
    assert(metadata.legendary ~= nil or metadata.stage ~= nil,
      "species metadata must define at least one field")
  end

  function Metadata.new()
    return setmetatable({
      entries = {},
      observed = {},
      frozen = false,
    }, Metadata)
  end

  local function valueKey(value)
    return type(value) .. ":" .. tostring(value)
  end

  local function resolvedValue(field, values)
    if field == "legendary" then
      return values["boolean:true"] == true
    end
    local resolved, rank
    for _, value in pairs(values) do
      local candidate = STAGE_RANK[value]
      if candidate and (not rank or candidate > rank) then
        resolved, rank = value, candidate
      end
    end
    return resolved
  end

  function Metadata:register(id, metadata)
    assert(not self.frozen, "species metadata is frozen after mods.loaded")
    validate(id, metadata)
    self.entries[id] = self.entries[id] or {}
    self.observed[id] = self.observed[id] or {}
    for field, value in pairs(metadata) do
      self.observed[id][field] = self.observed[id][field] or {}
      self.observed[id][field][valueKey(value)] = value
      self.entries[id][field] =
        resolvedValue(field, self.observed[id][field])
    end
    return copyMetadata(self.entries[id])
  end

  function Metadata:freeze()
    self.frozen = true
  end

  function Metadata:isFrozen()
    return self.frozen
  end

  function Metadata:snapshot()
    local snapshot = {}
    for _, id in ipairs(StableSort.keys(self.entries)) do
      snapshot[id] = copyMetadata(self.entries[id])
    end
    return snapshot
  end

  function Metadata:diagnostics()
    local diagnostics = {}
    for _, id in ipairs(StableSort.keys(self.observed)) do
      for _, field in ipairs(StableSort.keys(self.observed[id])) do
        local observed = self.observed[id][field]
        local keys = StableSort.keys(observed)
        if #keys > 1 then
          local values = {}
          for index, key in ipairs(keys) do values[index] = observed[key] end
          diagnostics[#diagnostics + 1] = {
            code = "SPECIES_METADATA_CONFLICT_RESOLVED",
            species = id,
            field = field,
            values = values,
            resolved = self.entries[id][field],
            policy = field == "legendary"
                and "legendary_true_wins" or "most_evolved_stage_wins",
            message = "conflicting species metadata was resolved "
              .. "with a deterministic field policy",
          }
        end
      end
    end
    return diagnostics
  end

  return Metadata
end
