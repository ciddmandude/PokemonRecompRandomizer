-- Pre-generation metadata contributed by this mod or other mods.
return function(StableSort)
  local Metadata = {}
  Metadata.__index = Metadata

  local ALLOWED_STAGES = { basic = true, middle = true, final = true }
  local ALLOWED_FIELDS = {
    legendary = true,
    stage = true,
  }

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
      frozen = false,
    }, Metadata)
  end

  function Metadata:register(id, metadata)
    assert(not self.frozen, "species metadata is frozen after mods.loaded")
    validate(id, metadata)
    assert(self.entries[id] == nil,
      ("species metadata already registered for %s"):format(id))
    self.entries[id] = copyMetadata(metadata)
    return copyMetadata(metadata)
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

  return Metadata
end
