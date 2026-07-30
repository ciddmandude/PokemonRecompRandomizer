-- Deterministic serialization for hash inputs. The format is internal and
-- versioned through the manifest schema that consumes it.
return function(StableSort)
  local Canonical = {}

  local function isDenseArray(value)
    local count = 0
    for key in pairs(value) do
      if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
        return false, 0
      end
      count = count + 1
    end
    for index = 1, count do
      if value[index] == nil then return false, 0 end
    end
    return true, count
  end

  local function numberText(value)
    assert(value == value and value ~= math.huge and value ~= -math.huge,
      "canonical numbers must be finite")
    if value == 0 then return "0" end
    if value == math.floor(value) then return ("%.0f"):format(value) end
    return ("%.17g"):format(value)
  end

  local function encode(value, active)
    local kind = type(value)
    if kind == "nil" then return "n" end
    if kind == "boolean" then return value and "b1" or "b0" end
    if kind == "number" then
      local text = numberText(value)
      return "d" .. #text .. ":" .. text
    end
    if kind == "string" then return "s" .. #value .. ":" .. value end
    assert(kind == "table", "canonical values must be data-only")
    assert(not active[value], "canonical values cannot contain cycles")
    active[value] = true

    local array, count = isDenseArray(value)
    local parts = {}
    if array then
      parts[#parts + 1] = "a" .. count .. "["
      for index = 1, count do
        parts[#parts + 1] = encode(value[index], active)
      end
      parts[#parts + 1] = "]"
    else
      local keys = StableSort.keys(value)
      parts[#parts + 1] = "m" .. #keys .. "{"
      for _, key in ipairs(keys) do
        parts[#parts + 1] = encode(key, active)
        parts[#parts + 1] = encode(value[key], active)
      end
      parts[#parts + 1] = "}"
    end

    active[value] = nil
    return table.concat(parts)
  end

  function Canonical.encode(value)
    return encode(value, {})
  end

  function Canonical.decode(input)
    assert(type(input) == "string", "canonical input must be a string")
    local position = 1

    local function countBefore(delimiter)
      local first = position
      while input:sub(position, position):match("%d") do
        position = position + 1
      end
      assert(position > first and input:sub(position, position) == delimiter,
        "malformed canonical length")
      local count = assert(tonumber(input:sub(first, position - 1)))
      position = position + 1
      return count
    end

    local parse
    parse = function()
      local tag = input:sub(position, position)
      assert(tag ~= "", "unexpected end of canonical input")
      position = position + 1
      if tag == "n" then return nil end
      if tag == "b" then
        local bit = input:sub(position, position)
        assert(bit == "0" or bit == "1", "malformed canonical boolean")
        position = position + 1
        return bit == "1"
      end
      if tag == "s" or tag == "d" then
        local length = countBefore(":")
        local last = position + length - 1
        assert(last <= #input, "truncated canonical scalar")
        local text = input:sub(position, last)
        position = last + 1
        if tag == "s" then return text end
        local number = tonumber(text)
        assert(number ~= nil, "malformed canonical number")
        return number
      end
      if tag == "a" then
        local count = countBefore("[")
        local output = {}
        for index = 1, count do output[index] = parse() end
        assert(input:sub(position, position) == "]",
          "malformed canonical array")
        position = position + 1
        return output
      end
      if tag == "m" then
        local count = countBefore("{")
        local output = {}
        for _ = 1, count do
          local key = parse()
          assert(type(key) == "number" or type(key) == "string",
            "canonical map keys must be numbers or strings")
          assert(output[key] == nil, "duplicate canonical map key")
          output[key] = parse()
        end
        assert(input:sub(position, position) == "}",
          "malformed canonical map")
        position = position + 1
        return output
      end
      error("unknown canonical tag")
    end

    local value = parse()
    assert(position == #input + 1, "trailing canonical data")
    assert(Canonical.encode(value) == input, "non-canonical encoded value")
    return value
  end

  return Canonical
end
