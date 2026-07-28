-- Player-facing seed normalization. Accepted seeds are deliberately ASCII so
-- character counts and hashes cannot vary with locale or Unicode libraries.
local Seed = {}

local MAX_LENGTH = 32

local function errorRow(code, message)
  return nil, { code = code, message = message }
end

function Seed.normalize(value)
  if type(value) ~= "string" then
    return errorRow("TYPE", "seed must be a string")
  end

  -- Normalize all ASCII whitespace runs to one ordinary space, then trim.
  local canonical = value:gsub("[%s]+", " ")
  canonical = canonical:match("^%s*(.-)%s*$") or ""
  canonical = string.upper(canonical)

  if canonical == "" then
    return errorRow("EMPTY", "seed must contain at least one character")
  end
  if #canonical > MAX_LENGTH then
    return errorRow("TOO_LONG",
      ("seed must be at most %d characters"):format(MAX_LENGTH))
  end
  if not canonical:match("^[A-Z0-9 _%-]+$") then
    return errorRow("INVALID_CHARACTER",
      "seed may contain only A-Z, 0-9, space, hyphen, and underscore")
  end

  return canonical, nil
end

function Seed.isCanonical(value)
  if type(value) ~= "string" then return false end
  local canonical = Seed.normalize(value)
  return canonical == value
end

Seed.MAX_LENGTH = MAX_LENGTH

return Seed
