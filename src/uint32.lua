-- Exact unsigned 32-bit operations implemented with Lua numbers.
--
-- Lua 5.1 numbers are IEEE-754 doubles. Every intermediate here stays below
-- 2^53, so results are exact on stock Lua 5.1 and LuaJIT regardless of the
-- presence or signedness of a native bit library.
local UInt32 = {}

local UINT16 = 65536
local UINT32_MOD = 4294967296
local XOR_NIBBLE = {}

for a = 0, 15 do
  XOR_NIBBLE[a] = {}
  for b = 0, 15 do
    local av, bv, result, place = a, b, 0, 1
    for _ = 1, 4 do
      if av % 2 ~= bv % 2 then result = result + place end
      av, bv, place = math.floor(av / 2), math.floor(bv / 2), place * 2
    end
    XOR_NIBBLE[a][b] = result
  end
end

local function assertInteger(value, name)
  assert(type(value) == "number" and value == math.floor(value),
    (name or "value") .. " must be an integer")
end

function UInt32.normalize(value)
  assertInteger(value)
  value = value % UINT32_MOD
  if value < 0 then value = value + UINT32_MOD end
  return value
end

function UInt32.xor(a, b)
  a, b = UInt32.normalize(a), UInt32.normalize(b)
  local result, place = 0, 1
  for _ = 1, 8 do
    result = result + XOR_NIBBLE[a % 16][b % 16] * place
    a = math.floor(a / 16)
    b = math.floor(b / 16)
    place = place * 16
  end
  return result
end

function UInt32.lshift(value, amount)
  value = UInt32.normalize(value)
  assertInteger(amount, "shift amount")
  if amount < 0 then return UInt32.rshift(value, -amount) end
  if amount >= 32 then return 0 end
  local keep = 2 ^ (32 - amount)
  return (value % keep) * (2 ^ amount)
end

function UInt32.rshift(value, amount)
  value = UInt32.normalize(value)
  assertInteger(amount, "shift amount")
  if amount < 0 then return UInt32.lshift(value, -amount) end
  if amount >= 32 then return 0 end
  return math.floor(value / (2 ^ amount))
end

function UInt32.rotl(value, amount)
  value = UInt32.normalize(value)
  assertInteger(amount, "rotate amount")
  amount = amount % 32
  if amount == 0 then return value end
  return UInt32.lshift(value, amount) + UInt32.rshift(value, 32 - amount)
end

function UInt32.mul(a, b)
  a, b = UInt32.normalize(a), UInt32.normalize(b)
  local alo, ahi = a % UINT16, math.floor(a / UINT16)
  local blo, bhi = b % UINT16, math.floor(b / UINT16)
  local low = alo * blo
  local cross = (alo * bhi + ahi * blo) % UINT16
  return (low + cross * UINT16) % UINT32_MOD
end

function UInt32.toHex(value)
  return ("%08X"):format(UInt32.normalize(value))
end

function UInt32.toBytesBE(value)
  value = UInt32.normalize(value)
  local b1 = math.floor(value / 16777216) % 256
  local b2 = math.floor(value / 65536) % 256
  local b3 = math.floor(value / 256) % 256
  local b4 = value % 256
  return string.char(b1, b2, b3, b4)
end

function UInt32.isInteger(value)
  return type(value) == "number" and value == math.floor(value)
end

UInt32.MODULUS = UINT32_MOD

return UInt32
