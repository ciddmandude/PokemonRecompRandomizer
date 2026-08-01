-- Filters engine registry records that share the item table but are not
-- obtainable inventory items. Generation and spoilers must use the same rule.
local ItemFilter = {}

local function normalized(value)
  if type(value) ~= "string" then return nil end
  return value:upper():gsub("%s+", "")
end

local function elevatorLabel(value)
  value = normalized(value)
  if not value then return false end
  return value:match("^B?%d+F$") ~= nil
    or value == "ROOF"
    or value:match("^FLOOR[_%-]?B?%d+F$") ~= nil
    or value:match("^ELEVATOR[_%-]?B?%d+F$") ~= nil
    or value:match("^FLOOR[_%-]?ROOF$") ~= nil
    or value:match("^ELEVATOR[_%-]?ROOF$") ~= nil
end

local function placeholderLabel(value)
  value = normalized(value)
  return value ~= nil and value:match("^%?+$") ~= nil
end

function ItemFilter.isElevatorEntry(id, record)
  if elevatorLabel(id) then return true end
  if type(record) ~= "table" then return false end
  return elevatorLabel(record.name) or elevatorLabel(record.label)
end

function ItemFilter.isPlaceholderEntry(id, record)
  if placeholderLabel(id) then return true end
  if type(record) ~= "table" then return false end
  return placeholderLabel(record.name) or placeholderLabel(record.label)
end

function ItemFilter.isUsable(id, record)
  return type(id) == "string" and type(record) == "table"
    and not ItemFilter.isElevatorEntry(id, record)
    and not ItemFilter.isPlaceholderEntry(id, record)
end

return ItemFilter
