-- Stable merge sorting and deterministic map-key ordering.
local StableSort = {}

local function defaultLess(a, b)
  return a < b
end

local function merge(values, scratch, first, middle, last, less)
  local left, right, out = first, middle + 1, first
  while left <= middle and right <= last do
    -- Choose the right value only when it is strictly less. Equal values
    -- therefore retain their original order.
    if less(values[right], values[left]) then
      scratch[out], right = values[right], right + 1
    else
      scratch[out], left = values[left], left + 1
    end
    out = out + 1
  end
  while left <= middle do
    scratch[out], left, out = values[left], left + 1, out + 1
  end
  while right <= last do
    scratch[out], right, out = values[right], right + 1, out + 1
  end
  for index = first, last do values[index] = scratch[index] end
end

local function split(values, scratch, first, last, less)
  if first >= last then return end
  local middle = math.floor((first + last) / 2)
  split(values, scratch, first, middle, less)
  split(values, scratch, middle + 1, last, less)
  merge(values, scratch, first, middle, last, less)
end

function StableSort.sort(input, less)
  assert(type(input) == "table", "stable sort input must be an array")
  less = less or defaultLess
  assert(type(less) == "function", "stable sort comparator must be a function")

  local values = {}
  for index, value in ipairs(input) do values[index] = value end
  if #values > 1 then split(values, {}, 1, #values, less) end
  return values
end

function StableSort.keys(map)
  assert(type(map) == "table", "key source must be a table")
  local keys = {}
  for key in pairs(map) do
    local kind = type(key)
    assert(kind == "number" or kind == "string",
      "deterministic keys must be numbers or strings")
    keys[#keys + 1] = key
  end
  return StableSort.sort(keys, function(a, b)
    local at, bt = type(a), type(b)
    if at ~= bt then return at == "number" end
    return a < b
  end)
end

return StableSort
